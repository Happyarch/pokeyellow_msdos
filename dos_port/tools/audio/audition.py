#!/usr/bin/env python3
"""audition.py — host-side fast audition loop and A/B testing suite.

Supports:
  - --target opl3 (default): Live 49.7 kHz OPL3 synthesis via NukedOPL, streaming
    directly to aplay with zero DOS booting. Includes live hot-reload, position-locked
    A/B switching, and disk-persisted revision tracking (.revisions/<Song>/).
  - --target mt32 / --target gm: Plays generated SMF MIDI to an ALSA port
    (MUNT mt32emu-qt or fluidsynth).

Controls (OPL3 interactive mode):
  [Tab]         Toggle A/B (Working Copy ↔ Previous Revision)
  [Space] / [E] Toggle Enhancements On / Off (Pure GB ↔ Enhanced)
  [1]           Toggle Tier 1
  [M]           Solo Enhancements (mute base GB channels)
  [C]           Save manual checkpoint to disk
  [ [ ] / [ ] ] Step backward / forward through disk revisions
  [U]           Revert file on disk to currently selected revision
  [P]           Pause / Resume playback
  [Left]/[Right] Seek -4s / +4s
  [Q]           Quit
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
import os
from pathlib import Path
import select
import struct
import subprocess
import sys
import tempfile
import time

AUDIO_DIR = Path(__file__).resolve().parent
ROOT = AUDIO_DIR.parents[2]
MIDI_DIR = ROOT / "dos_port" / "assets" / "midi"
TIMBRES = AUDIO_DIR / "mt32" / "timbres.yaml"
ENHANCE_DIR = AUDIO_DIR / "enhancements"

sys.path.insert(0, str(AUDIO_DIR))
sys.path.insert(0, str(AUDIO_DIR / "audition"))
from gen_mt32_patches import build_messages  # noqa: E402
import yaml  # noqa: E402
import revisions  # noqa: E402

SYSEX_GAP_TICKS = 4  # ~66 ms between setup messages @60 tps


# ---------------------------------------------------------------------------
# Terminal raw mode input helper (stdlib only)
# ---------------------------------------------------------------------------
class RawTerminal:
    def __init__(self):
        self.is_tty = sys.stdin.isatty()
        self.old_settings = None

    def __enter__(self):
        if self.is_tty:
            import termios
            import tty
            self.old_settings = termios.tcgetattr(sys.stdin)
            tty.setcbreak(sys.stdin.fileno())
        return self

    def __exit__(self, *args):
        if self.is_tty and self.old_settings:
            import termios
            termios.tcsetattr(sys.stdin, termios.TCSADRAIN, self.old_settings)

    def get_key(self) -> str | None:
        if not self.is_tty:
            return None
        if select.select([sys.stdin], [], [], 0)[0]:
            ch = sys.stdin.read(1)
            if ch == "\x1b":  # Escape sequence
                if select.select([sys.stdin], [], [], 0.05)[0]:
                    ch2 = sys.stdin.read(1)
                    if ch2 == "[":
                        ch3 = sys.stdin.read(1)
                        if ch3 == "D":
                            return "LEFT"
                        elif ch3 == "C":
                            return "RIGHT"
                return "ESC"
            return ch
        return None


# ---------------------------------------------------------------------------
# MIDI helpers (for MT-32 / GM)
# ---------------------------------------------------------------------------
def vlq(n: int) -> bytes:
    out = [n & 0x7F]
    n >>= 7
    while n:
        out.append(0x80 | (n & 0x7F))
        n >>= 7
    return bytes(reversed(out))


def sysex_track(msgs: list[bytes]) -> bytes:
    """One SMF track carrying the setup SysEx, paced, ending after a beat."""
    data = bytearray()
    delta = 0
    for msg in msgs:
        assert msg[0] == 0xF0
        data += vlq(delta) + bytes((0xF0,)) + vlq(len(msg) - 1) + msg[1:]
        delta = SYSEX_GAP_TICKS
    data += vlq(60) + b"\xff\x2f\x00"  # 1 s settle before the song
    return b"MTrk" + struct.pack(">I", len(data)) + bytes(data)


def with_setup(mid: bytes, msgs: list[bytes]) -> bytes:
    """Insert the SysEx track after the tempo track of a format-1 SMF."""
    fmt, ntrk, div = struct.unpack(">HHH", mid[8:14])
    assert mid[:4] == b"MThd" and fmt == 1
    t0_len = struct.unpack(">I", mid[18:22])[0]
    cut = 14 + 8 + t0_len
    hdr = b"MThd" + struct.pack(">IHHH", 6, 1, ntrk + 1, div)
    return hdr + mid[14:cut] + sysex_track(msgs) + mid[cut:]


def pick_port(target: str) -> str:
    """First ALSA writable port whose client name matches the synth."""
    want = (
        ("mt32", "munt", "Munt MT-32")
        if target == "mt32"
        else ("fluid", "synth", "timid")
    )
    out = subprocess.run(
        ["aplaymidi", "-l"], capture_output=True, text=True, check=True
    ).stdout
    for line in out.splitlines()[1:]:
        parts = line.split(None, 1)
        if len(parts) == 2 and any(w in line.lower() for w in want):
            return parts[0]
    raise SystemExit(
        f"no ALSA port matching {want} — is the synth running? "
        f"(aplaymidi -l to inspect, --port to override)\n{out}"
    )


# ---------------------------------------------------------------------------
# OPL3 interactive audition loop
# ---------------------------------------------------------------------------
def run_opl3_audition(song_label: str, compare_path: Path | None,
                      no_enh: bool, solo_enh: bool,
                      seconds: float | None, out_wav: Path | None):
    import opl_renderer

    sess = opl_renderer.SongSession(song_label)
    canonical_name = sess.song_label
    yaml_path = ENHANCE_DIR / f"{canonical_name}.yaml"

    rev_history: list[tuple[int, str, Path]] = []
    current_rev_idx = -1
    ab_target_idx = -1
    showing_working_copy = True
    manual_checkpoint_yaml: str | None = None
    last_mtime = 0.0

    if yaml_path.exists():
        initial_text = yaml_path.read_text(encoding="utf-8")
        last_mtime = yaml_path.stat().st_mtime
        init_id, init_path = revisions.save_snapshot(canonical_name, initial_text, "session_start")
        rev_history = revisions.list_revisions(canonical_name)
        current_rev_idx = len(rev_history) - 1
        # Baseline A/B target: revision before current if available, else current
        ab_target_idx = max(0, current_rev_idx - 1)
        sess.load_enhancement(yaml_path)
    elif compare_path and compare_path.exists():
        sess.load_enhancement(compare_path)

    if no_enh:
        sess.enable_enh = False
    if solo_enh:
        sess.solo_enh = True

    # Output destination
    wav_file = None
    aplay_proc = None
    if out_wav:
        import wave
        wav_file = wave.open(str(out_wav), "wb")
        wav_file.setnchannels(2)
        wav_file.setsampwidth(2)
        wav_file.setframerate(49716)
    else:
        aplay_cmd = ["aplay", "-r", "49716", "-f", "S16_LE", "-c", "2", "-q"]
        try:
            aplay_proc = subprocess.Popen(aplay_cmd, stdin=subprocess.PIPE)
        except FileNotFoundError:
            raise SystemExit("aplay not found — install alsa-utils or pass --out <file.wav>")

    print(f"\n🎵 [OPL3] Auditioning: {canonical_name}")
    print("Controls: [Tab] A/B Toggle  [Space] Enh On/Off  [M] Solo Enh")
    print("          [ [ ] / [ ] ] Revisions  [C] Checkpoint  [U] Revert on Disk  [Q] Quit\n")

    paused = False
    total_frames_played = 0
    max_frames = int(seconds * 60) if seconds else None
    status_msg = ""
    status_timer = 0

    try:
        with RawTerminal() as term:
            while True:
                if max_frames and total_frames_played >= max_frames:
                    break

                # Watch for file modifications on disk
                if yaml_path.exists():
                    try:
                        mtime = yaml_path.stat().st_mtime
                        if mtime > last_mtime:
                            last_mtime = mtime
                            time.sleep(0.02)  # short settle window for editor write
                            new_text = yaml_path.read_text(encoding="utf-8")
                            new_id, new_path = revisions.save_snapshot(canonical_name, new_text, "live_tweak")
                            rev_history = revisions.list_revisions(canonical_name)
                            ab_target_idx = current_rev_idx  # prior version becomes A/B target
                            current_rev_idx = len(rev_history) - 1
                            showing_working_copy = True
                            sess.load_enhancement(yaml_path)
                            status_msg = f"⚡ Hot-reloaded Rev {new_id}! (Press [Tab] for A/B)"
                            status_timer = 180
                    except Exception as e:
                        status_msg = f"⚠ Hot-reload error: {e}"
                        status_timer = 120

                # Keystroke handling
                key = term.get_key()
                if key in ("q", "Q", "ESC", "\x03"):
                    break
                elif key in ("\t",):  # Tab: A/B toggle
                    if compare_path and compare_path.exists():
                        showing_working_copy = not showing_working_copy
                        target_p = yaml_path if showing_working_copy else compare_path
                        sess.load_enhancement(target_p)
                        status_msg = f"Swapped to: {target_p.name}"
                        status_timer = 120
                    elif manual_checkpoint_yaml is not None:
                        showing_working_copy = not showing_working_copy
                        if showing_working_copy:
                            sess.load_enhancement(yaml_path)
                            status_msg = "A/B: Working Copy"
                        else:
                            sess.load_enhancement(manual_checkpoint_yaml)
                            status_msg = "A/B: Checkpoint"
                        status_timer = 120
                    elif rev_history and len(rev_history) >= 2:
                        showing_working_copy = not showing_working_copy
                        if showing_working_copy:
                            sess.load_enhancement(yaml_path)
                            status_msg = f"A/B: Working Copy (Rev {rev_history[current_rev_idx][0]})"
                        else:
                            ab_content = revisions.get_revision_content(canonical_name, rev_history[ab_target_idx][0])
                            sess.load_enhancement(ab_content)
                            status_msg = f"A/B: Comparing against Rev {rev_history[ab_target_idx][0]}"
                        status_timer = 120
                    else:
                        status_msg = "No prior revision yet for A/B (save file to create Rev 2)"
                        status_timer = 120
                elif key in (" ", "e", "E"):
                    sess.enable_enh = not sess.enable_enh
                    status_msg = f"Enhancements: {'ON' if sess.enable_enh else 'OFF'}"
                    status_timer = 90
                elif key in ("1",):
                    if 1 in sess.tier_filter:
                        sess.tier_filter.remove(1)
                    else:
                        sess.tier_filter.add(1)
                    sess.load_enhancement(yaml_path if showing_working_copy else None)
                    status_msg = f"Tier 1: {'ON' if 1 in sess.tier_filter else 'OFF'}"
                    status_timer = 90
                elif key in ("m", "M"):
                    sess.solo_enh = not sess.solo_enh
                    status_msg = f"Solo Enhancements: {'ON' if sess.solo_enh else 'OFF'}"
                    status_timer = 90
                elif key in ("c", "C"):
                    if yaml_path.exists():
                        manual_checkpoint_yaml = yaml_path.read_text(encoding="utf-8")
                        status_msg = "📌 Checkpoint saved to memory! [Tab] will toggle against it."
                        status_timer = 150
                elif key == "[":  # previous revision
                    if rev_history and ab_target_idx > 0:
                        ab_target_idx -= 1
                        rev_num = rev_history[ab_target_idx][0]
                        ab_content = revisions.get_revision_content(canonical_name, rev_num)
                        showing_working_copy = False
                        sess.load_enhancement(ab_content)
                        status_msg = f"Loaded Rev {rev_num} ({ab_target_idx+1}/{len(rev_history)})"
                        status_timer = 120
                elif key == "]":  # next revision
                    if rev_history and ab_target_idx < len(rev_history) - 1:
                        ab_target_idx += 1
                        rev_num = rev_history[ab_target_idx][0]
                        if ab_target_idx == current_rev_idx:
                            showing_working_copy = True
                            sess.load_enhancement(yaml_path)
                            status_msg = f"Loaded Current Working Copy (Rev {rev_num})"
                        else:
                            showing_working_copy = False
                            ab_content = revisions.get_revision_content(canonical_name, rev_num)
                            sess.load_enhancement(ab_content)
                            status_msg = f"Loaded Rev {rev_num} ({ab_target_idx+1}/{len(rev_history)})"
                        status_timer = 120
                elif key in ("u", "U"):  # Revert on disk
                    if rev_history and not showing_working_copy:
                        rev_num = rev_history[ab_target_idx][0]
                        if revisions.revert_to_revision(canonical_name, rev_num):
                            last_mtime = yaml_path.stat().st_mtime
                            showing_working_copy = True
                            status_msg = f"↺ Reverted disk file to Rev {rev_num}!"
                            status_timer = 180
                elif key in ("p", "P"):
                    paused = not paused
                    status_msg = "PAUSED" if paused else "RESUMED"
                    status_timer = 60
                elif key == "LEFT":
                    sess.seek_relative(-240)  # -4s
                    status_msg = "Seek -4s"
                    status_timer = 60
                elif key == "RIGHT":
                    sess.seek_relative(240)   # +4s
                    status_msg = "Seek +4s"
                    status_timer = 60

                # Audio rendering
                if not paused:
                    frame_pcm = sess.tick()
                    total_frames_played += 1
                else:
                    frame_pcm = b"\x00" * (828 * 4)

                if wav_file:
                    wav_file.writeframes(frame_pcm)
                elif aplay_proc and aplay_proc.stdin:
                    try:
                        aplay_proc.stdin.write(frame_pcm)
                        aplay_proc.stdin.flush()
                    except BrokenPipeError:
                        break

                # Status line rendering (~4 Hz update)
                if total_frames_played % 15 == 0:
                    curr_sec = sess.current_frame // 60
                    tot_sec = sess.total_frames // 60
                    enh_state = "SOLO" if sess.solo_enh else ("ON" if sess.enable_enh else "OFF")
                    active_rev = f"Rev {rev_history[ab_target_idx][0]}" if not showing_working_copy and rev_history else "Working"
                    banner = f"\r▶ {curr_sec:02d}:{sess.current_frame%60:02d}/{tot_sec:02d}:00 | Enh: {enh_state:<4} | Layer: {active_rev:<8}"
                    if status_timer > 0:
                        banner += f" | {status_msg}"
                        status_timer -= 15
                    sys.stdout.write(f"{banner:<80}")
                    sys.stdout.flush()

    finally:
        sys.stdout.write("\n")
        if wav_file:
            wav_file.close()
            print(f"Wrote audio to {out_wav}")
        if aplay_proc:
            if aplay_proc.stdin:
                aplay_proc.stdin.close()
            aplay_proc.terminate()
            aplay_proc.wait()


# ---------------------------------------------------------------------------
# Main CLI
# ---------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument(
        "song",
        help="header label or unique substring (e.g. Music_PalletTown or PalletTown)",
    )
    ap.add_argument(
        "--target",
        choices=("opl3", "mt32", "gm"),
        default="opl3",
        help="target synth: opl3 (default, native host FM), mt32 (MUNT), or gm (fluidsynth)",
    )
    ap.add_argument("--no-enh", action="store_true", help="start with enhancements disabled")
    ap.add_argument("--solo-enh", action="store_true", help="start in solo-enhancements mode")
    ap.add_argument("--compare", type=Path, help="alternate YAML file to compare against via [Tab]")
    ap.add_argument("--seconds", type=float, help="stop playback after N seconds (headless/testing)")
    ap.add_argument("--out", type=Path, help="render output to WAV file instead of playing to speakers")
    ap.add_argument("--port", help="ALSA MIDI port for mt32/gm (default: auto-detect)")
    ap.add_argument(
        "--setup",
        action="store_true",
        help="prepend the MT-32 setup SysEx (reverb/reserves/routing/vol)",
    )
    args = ap.parse_args()

    # OPL3 target
    if args.target == "opl3":
        run_opl3_audition(
            song_label=args.song,
            compare_path=args.compare,
            no_enh=args.no_enh,
            solo_enh=args.solo_enh,
            seconds=args.seconds,
            out_wav=args.out,
        )
        return

    # MIDI targets (MT-32 / GM)
    mdir = MIDI_DIR / args.target
    if not mdir.is_dir():
        raise SystemExit(
            f"{mdir} missing — run `make assets` "
            f"(or gb_to_midi.py --target {args.target})"
        )
    hits = sorted(p for p in mdir.glob("*.mid") if args.song in p.stem)
    exact = [p for p in hits if p.stem == args.song]
    if exact:
        hits = exact
    if len(hits) != 1:
        raise SystemExit(
            f"song {args.song!r} matches {[p.stem for p in hits] or 'nothing'}"
        )
    mid = hits[0].read_bytes()

    if args.target == "mt32" and args.setup:
        msgs = build_messages(yaml.safe_load(TIMBRES.read_text()) or {})
        mid = with_setup(mid, msgs)
        print(
            f"prepended {len(msgs)} setup SysEx messages "
            "(--setup: expect shifted part routing on standalone MUNT)"
        )

    port = args.port or pick_port(args.target)
    with tempfile.NamedTemporaryFile(suffix=".mid") as tmp:
        tmp.write(mid)
        tmp.flush()
        print(f"playing {hits[0].stem} -> port {port}")
        subprocess.run(["aplaymidi", "-p", port, tmp.name], check=True)


if __name__ == "__main__":
    main()
