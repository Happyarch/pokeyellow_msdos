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
# Interactive audition loop (OPL3, MT-32, and General MIDI)
# ---------------------------------------------------------------------------
def run_interactive_audition(
    target: str,
    song_label: str,
    port_override: str | None = None,
    compare_path: Path | None = None,
    no_enh: bool = False,
    solo_enh: bool = False,
    seconds: float | None = None,
    out_wav: Path | None = None,
    setup: bool = False,
):
    wav_file = None
    aplay_proc = None

    if target == "opl3":
        import opl_renderer
        sess = opl_renderer.SongSession(song_label)
        rate = sess.engine.samplerate
        if out_wav:
            import wave
            wav_file = wave.open(str(out_wav), "wb")
            wav_file.setnchannels(2)
            wav_file.setsampwidth(2)
            wav_file.setframerate(rate)
        else:
            aplay_cmd = ["aplay", "-r", str(rate), "-f", "S16_LE", "-c", "2", "-q"]
            try:
                aplay_proc = subprocess.Popen(aplay_cmd, stdin=subprocess.PIPE)
            except FileNotFoundError:
                raise SystemExit("aplay not found — install alsa-utils or pass --out <file.wav>")
            # Pre-buffer ~4 frames (approx 67 ms) on startup
            for _ in range(4):
                aplay_proc.stdin.write(sess.tick())
            aplay_proc.stdin.flush()
    else:
        import midi_renderer
        port = port_override or pick_port(target)
        setup_msgs = None
        if target == "mt32" and setup:
            setup_msgs = build_messages(yaml.safe_load(TIMBRES.read_text()) or {})
        sess = midi_renderer.MidiSession(song_label, target, port, sysex_setup=setup_msgs)

    canonical_name = sess.song_label
    yaml_path = ENHANCE_DIR / f"{canonical_name}.yaml"
    overrides_path = AUDIO_DIR / "overrides" / f"{canonical_name}.yaml"

    rev_history: list[tuple[int, str, Path]] = []
    current_rev_idx = -1
    browse_rev_idx = -1
    last_mtime = 0.0
    last_ov_mtime = 0.0

    if yaml_path.exists():
        initial_text = yaml_path.read_text(encoding="utf-8")
        last_mtime = yaml_path.stat().st_mtime
        init_id, init_path = revisions.save_snapshot(canonical_name, initial_text, "session_start")
        rev_history = revisions.list_revisions(canonical_name)
        current_rev_idx = len(rev_history) - 1
        browse_rev_idx = current_rev_idx
        sess.load_enhancement(yaml_path)
    elif compare_path and compare_path.exists():
        sess.load_enhancement(compare_path)

    if overrides_path.exists():
        last_ov_mtime = overrides_path.stat().st_mtime

    # Explicit comparison points: Point A and Point B for [Tab] toggling.
    # Point A defaults to the live Working Copy on disk.
    slot_a = {
        "label": "Working Copy",
        "content": None,
        "is_live": True,
        "rev_id": rev_history[-1][0] if rev_history else None,
    }

    # Point B defaults to compare_path if passed, or Rev 1 (Session Start).
    if compare_path and compare_path.exists():
        slot_b = {
            "label": f"Compare ({compare_path.name})",
            "content": compare_path.read_text(encoding="utf-8"),
            "is_live": False,
            "rev_id": None,
        }
    elif rev_history:
        slot_b = {
            "label": f"Rev {rev_history[0][0]} (Session Start)",
            "content": revisions.get_revision_content(canonical_name, rev_history[0][0]),
            "is_live": False,
            "rev_id": rev_history[0][0],
        }
    else:
        slot_b = {
            "label": "Empty",
            "content": None,
            "is_live": False,
            "rev_id": None,
        }

    active_slot = "A"  # "A" or "B"

    if no_enh:
        sess.enable_enh = False
    if solo_enh:
        sess.solo_enh = True

    print(f"\n🎵 [{target.upper()}] Auditioning: {canonical_name}")
    print("Controls: [Tab] A/B Toggle  [A] Set Point A  [B]/[C] Set Point B (Checkpoint)")
    print("          [Space] Enh On/Off  [M] Solo Enh   [ [ ] / [ ] ] Revisions  [U] Revert on Disk  [Q] Quit\n")

    paused = False
    total_frames_played = 0
    max_frames = int(seconds * 60) if seconds else None
    status_msg = ""
    status_timer = 0
    next_tick = time.perf_counter()

    try:
        with RawTerminal() as term:
            while True:
                if max_frames and total_frames_played >= max_frames:
                    break

                # Watch for enhancement modifications on disk
                if yaml_path.exists():
                    try:
                        mtime = yaml_path.stat().st_mtime
                        if mtime > last_mtime:
                            last_mtime = mtime
                            time.sleep(0.02)  # short settle window for editor write
                            new_text = yaml_path.read_text(encoding="utf-8")
                            new_id, new_path = revisions.save_snapshot(canonical_name, new_text, "live_tweak")
                            rev_history = revisions.list_revisions(canonical_name)
                            current_rev_idx = len(rev_history) - 1
                            browse_rev_idx = current_rev_idx

                            # Update Point A if it is live tracking the working copy
                            if slot_a["is_live"]:
                                slot_a["rev_id"] = new_id
                                if active_slot == "A":
                                    sess.load_enhancement(yaml_path)
                                    status_msg = f"⚡ Hot-reloaded Rev {new_id}! [Tab] A: Working Copy ↔ B: {slot_b['label']}"
                                    status_timer = 180
                                else:
                                    status_msg = f"⚡ Saved Rev {new_id} to Point A (playing Point B: {slot_b['label']})"
                                    status_timer = 150
                            # Point B is preserved untouched!
                    except Exception as e:
                        status_msg = f"⚠ Hot-reload error: {e}"
                        status_timer = 120

                # Watch for channel overrides modifications on disk
                if overrides_path.exists():
                    try:
                        ov_mtime = overrides_path.stat().st_mtime
                        if ov_mtime > last_ov_mtime:
                            last_ov_mtime = ov_mtime
                            time.sleep(0.02)
                            if hasattr(sess, "reload_overrides"):
                                sess.reload_overrides()
                            status_msg = "⚡ Hot-reloaded channel overrides!"
                            status_timer = 150
                    except Exception as e:
                        status_msg = f"⚠ Overrides reload error: {e}"
                        status_timer = 120

                # Keystroke handling
                key = term.get_key()
                if key in ("q", "Q", "ESC", "\x03"):
                    break
                elif key in ("\t",):  # Tab: A/B toggle
                    if active_slot == "A":
                        active_slot = "B"
                        target_slot = slot_b
                    else:
                        active_slot = "A"
                        target_slot = slot_a

                    if target_slot["is_live"]:
                        sess.load_enhancement(yaml_path)
                    else:
                        sess.load_enhancement(target_slot["content"])
                    status_msg = f"▶ [Tab] Point {active_slot}: {target_slot['label']}"
                    status_timer = 120
                elif key in ("b", "B", "c", "C"):  # Set Point B / Checkpoint
                    if rev_history and browse_rev_idx != current_rev_idx:
                        rev_num = rev_history[browse_rev_idx][0]
                        content = revisions.get_revision_content(canonical_name, rev_num)
                        slot_b["label"] = f"Rev {rev_num}"
                        slot_b["content"] = content
                        slot_b["is_live"] = False
                        slot_b["rev_id"] = rev_num
                        status_msg = f"📌 Point B set to Rev {rev_num} (Checkpoint)!"
                    else:
                        current_text = yaml_path.read_text(encoding="utf-8") if yaml_path.exists() else ""
                        chk_id, _ = revisions.save_snapshot(canonical_name, current_text, "checkpoint")
                        rev_history = revisions.list_revisions(canonical_name)
                        current_rev_idx = len(rev_history) - 1
                        browse_rev_idx = current_rev_idx
                        slot_b["label"] = f"Rev {chk_id} (Checkpoint)"
                        slot_b["content"] = current_text
                        slot_b["is_live"] = False
                        slot_b["rev_id"] = chk_id
                        status_msg = f"📌 Point B (Checkpoint) set to Rev {chk_id}!"
                    status_timer = 150
                elif key in ("a", "A"):  # Set Point A
                    if rev_history and browse_rev_idx != current_rev_idx:
                        rev_num = rev_history[browse_rev_idx][0]
                        content = revisions.get_revision_content(canonical_name, rev_num)
                        slot_a["label"] = f"Rev {rev_num}"
                        slot_a["content"] = content
                        slot_a["is_live"] = False
                        slot_a["rev_id"] = rev_num
                        status_msg = f"📌 Point A locked to Rev {rev_num}!"
                    else:
                        slot_a["label"] = "Working Copy"
                        slot_a["content"] = None
                        slot_a["is_live"] = True
                        slot_a["rev_id"] = rev_history[-1][0] if rev_history else None
                        if active_slot == "A":
                            sess.load_enhancement(yaml_path)
                        status_msg = "📌 Point A set to Working Copy (Live)!"
                    status_timer = 150
                elif key in (" ", "e", "E"):
                    sess.enable_enh = not sess.enable_enh
                    if not sess.enable_enh:
                        sess.silence_enhancements()
                    elif hasattr(sess, "send_init"):
                        sess.send_init()
                    status_msg = f"Enhancements: {'ON' if sess.enable_enh else 'OFF'}"
                    status_timer = 90
                elif key in ("1",):
                    if hasattr(sess, "tier_filter"):
                        if 1 in sess.tier_filter:
                            sess.tier_filter.remove(1)
                        else:
                            sess.tier_filter.add(1)
                        active_content = yaml_path if (active_slot == "A" and slot_a["is_live"]) else (slot_a["content"] if active_slot == "A" else slot_b["content"])
                        sess.load_enhancement(active_content)
                        status_msg = f"Tier 1: {'ON' if 1 in sess.tier_filter else 'OFF'}"
                        status_timer = 90
                elif key in ("m", "M"):
                    sess.solo_enh = not sess.solo_enh
                    if sess.solo_enh:
                        sess.silence_base()
                    elif hasattr(sess, "send_init"):
                        sess.send_init()
                    status_msg = f"Solo Enhancements: {'ON' if sess.solo_enh else 'OFF'}"
                    status_timer = 90
                elif key == "[":  # previous revision
                    if rev_history and browse_rev_idx > 0:
                        browse_rev_idx -= 1
                        rev_num = rev_history[browse_rev_idx][0]
                        content = revisions.get_revision_content(canonical_name, rev_num)
                        sess.load_enhancement(content)
                        status_msg = f"Listening: Rev {rev_num} ({browse_rev_idx+1}/{len(rev_history)}) — Press [A] or [B] to assign"
                        status_timer = 150
                elif key == "]":  # next revision
                    if rev_history and browse_rev_idx < len(rev_history) - 1:
                        browse_rev_idx += 1
                        rev_num = rev_history[browse_rev_idx][0]
                        if browse_rev_idx == current_rev_idx and slot_a["is_live"]:
                            sess.load_enhancement(yaml_path)
                            status_msg = f"Listening: Working Copy (Rev {rev_num}) — Press [A] or [B] to assign"
                        else:
                            content = revisions.get_revision_content(canonical_name, rev_num)
                            sess.load_enhancement(content)
                            status_msg = f"Listening: Rev {rev_num} ({browse_rev_idx+1}/{len(rev_history)}) — Press [A] or [B] to assign"
                        status_timer = 150
                elif key in ("u", "U"):  # Revert on disk
                    if rev_history:
                        rev_num = rev_history[browse_rev_idx][0]
                        if revisions.revert_to_revision(canonical_name, rev_num):
                            last_mtime = yaml_path.stat().st_mtime
                            slot_a["label"] = "Working Copy"
                            slot_a["content"] = None
                            slot_a["is_live"] = True
                            slot_a["rev_id"] = rev_num
                            active_slot = "A"
                            browse_rev_idx = current_rev_idx
                            sess.load_enhancement(yaml_path)
                            status_msg = f"↺ Reverted disk file to Rev {rev_num}!"
                            status_timer = 180
                elif key in ("p", "P"):
                    paused = not paused
                    if paused:
                        if hasattr(sess, "silence_all"):
                            sess.silence_all()
                    else:
                        if hasattr(sess, "send_init"):
                            sess.send_init()
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
                    if target == "opl3":
                        frame_pcm = b"\x00" * (sess.engine.samplerate // 60 * 4)
                    else:
                        frame_pcm = None

                if target == "opl3":
                    if wav_file and frame_pcm:
                        wav_file.writeframes(frame_pcm)
                    elif aplay_proc and aplay_proc.stdin and frame_pcm:
                        try:
                            aplay_proc.stdin.write(frame_pcm)
                            aplay_proc.stdin.flush()
                        except BrokenPipeError:
                            break

                # Frame pacing for real-time playback
                if not out_wav:
                    next_tick += 1.0 / 60.0
                    sleep_dur = next_tick - time.perf_counter()
                    if sleep_dur > 0:
                        time.sleep(sleep_dur)
                    elif sleep_dur < -0.1:
                        next_tick = time.perf_counter()

                # Status line rendering (~4 Hz update)
                if total_frames_played % 15 == 0:
                    curr_sec = sess.current_frame // 60
                    tot_sec = sess.total_frames // 60
                    enh_state = "SOLO" if sess.solo_enh else ("ON" if sess.enable_enh else "OFF")
                    tag_a = f"A*:{slot_a['label']}" if active_slot == "A" else f"A:{slot_a['label']}"
                    tag_b = f"B*:{slot_b['label']}" if active_slot == "B" else f"B:{slot_b['label']}"
                    tab_display = f"[{tag_a} | {tag_b}]"
                    banner = f"\r▶ {curr_sec:02d}:{sess.current_frame%60:02d}/{tot_sec:02d}:00 | {target.upper():<4} | Enh: {enh_state:<4} | Tab: {tab_display}"
                    if status_timer > 0:
                        banner += f" | {status_msg}"
                        status_timer -= 15
                    sys.stdout.write(f"{banner:<95}")
                    sys.stdout.flush()

    finally:
        sys.stdout.write("\n")
        if target == "opl3":
            if wav_file:
                wav_file.close()
                print(f"Wrote audio to {out_wav}")
            if aplay_proc:
                if aplay_proc.stdin:
                    aplay_proc.stdin.close()
                aplay_proc.terminate()
                aplay_proc.wait()
        else:
            if hasattr(sess, "silence_all"):
                sess.silence_all()


# ---------------------------------------------------------------------------
# Track Catalog & Fuzzy Matching
# ---------------------------------------------------------------------------
def get_all_tracks() -> list[str]:
    from pret_audio import AudioROM
    from gen_audio_data import parse_music_constants
    rom = AudioROM(ROOT)
    consts, _ = parse_music_constants()
    return sorted({lbl for name, lbl in consts.items()
                   if name.startswith("MUSIC_") and lbl in rom.symtab})


def resolve_song_label(query: str, tracks: list[str]) -> str:
    import difflib

    query_str = query.strip()
    if not query_str:
        raise SystemExit("Empty song query.")

    # 1. Exact match
    if query_str in tracks:
        return query_str

    # 2. Case-insensitive exact match
    lower_map = {t.lower(): t for t in tracks}
    if query_str.lower() in lower_map:
        return lower_map[query_str.lower()]

    # 3. Substring matches
    subs = [t for t in tracks if query_str.lower() in t.lower()]
    if len(subs) == 1:
        return subs[0]
    elif len(subs) > 1:
        # Prefer exact stem match e.g. "PalletTown" matching "Music_PalletTown"
        stem_matches = [t for t in subs if t.lower() == f"music_{query_str.lower()}"]
        if len(stem_matches) == 1:
            return stem_matches[0]

    # 4. Normalized match (strip "music_" and "_")
    clean_map = {t.lower().replace("music_", "").replace("_", ""): t for t in tracks}
    q_clean = query_str.lower().replace("music_", "").replace("_", "")
    if q_clean in clean_map:
        return clean_map[q_clean]

    # 5. Fuzzy matching via difflib
    close = difflib.get_close_matches(q_clean, list(clean_map.keys()), n=1, cutoff=0.45)
    if close:
        matched = clean_map[close[0]]
        print(f"💡 Fuzzy matched '{query_str}' -> '{matched}'")
        return matched

    # 6. Ambiguous substring matches
    if len(subs) > 1:
        raise SystemExit(
            f"Ambiguous song query '{query_str}'. Matches:\n" +
            "\n".join(f"  - {m}" for m in subs)
        )

    # 7. Close matches for suggestion
    close_full = difflib.get_close_matches(query_str.lower(), [t.lower() for t in tracks], n=3, cutoff=0.3)
    suggestion_str = ""
    if close_full:
        suggestions = [lower_map[c] for c in close_full]
        suggestion_str = "\nDid you mean:\n" + "\n".join(f"  - {s}" for s in suggestions)

    raise SystemExit(f"No song matching '{query_str}' found.{suggestion_str}\n(Run 'audition.py --list' to see all tracks)")


def print_song_list(tracks: list[str]):
    import re
    overrides_dir = AUDIO_DIR / "overrides"
    print(f"\nAvailable Music Tracks ({len(tracks)} total):")
    print(f"  {'#':<3} {'Track Name':<28} {'Enhancements':<22} {'Overrides':<10}")
    print("  " + "-" * 66)
    for idx, t in enumerate(tracks, 1):
        enh_path = ENHANCE_DIR / f"{t}.yaml"
        enh_info = "-"
        if enh_path.exists():
            text = enh_path.read_text(encoding="utf-8")
            tiers = sorted(set(re.findall(r"tier:\s*([123])", text)))
            if tiers:
                enh_info = f"Tier {', '.join(tiers)}"
            else:
                enh_info = "Yes"

        ov_path = overrides_dir / f"{t}.yaml"
        ov_info = "Yes" if ov_path.exists() else "-"

        print(f"  {idx:<3} {t:<28} {enh_info:<22} {ov_info:<10}")
    print("\nUsage: tools/audio/audition.py <SongName>  (fuzzy search supported)\n")


# ---------------------------------------------------------------------------
# Main CLI
# ---------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument(
        "song",
        nargs="?",
        help="header label, substring, or fuzzy name (e.g. PalletTown, palet, vermillion)",
    )
    ap.add_argument(
        "-l", "--list",
        action="store_true",
        help="list all available music tracks and their enhancement status",
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

    all_tracks = get_all_tracks()

    if args.list or not args.song:
        print_song_list(all_tracks)
        return

    canonical_song = resolve_song_label(args.song, all_tracks)

    run_interactive_audition(
        target=args.target,
        song_label=canonical_song,
        port_override=args.port,
        compare_path=args.compare,
        no_enh=args.no_enh,
        solo_enh=args.solo_enh,
        seconds=args.seconds,
        out_wav=args.out,
        setup=args.setup,
    )


if __name__ == "__main__":
    main()

