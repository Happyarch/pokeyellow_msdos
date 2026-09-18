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
    mt32_cleanup_msgs = None

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
            setup_msgs = build_messages(yaml.safe_load(TIMBRES.read_text()) or {},
                                        system=False)
        sess = midi_renderer.MidiSession(song_label, target, port, sysex_setup=setup_msgs)
        if target == "mt32":
            from gen_mt32_patches import load_custom_timbres
            from midi_to_stream import find_song_custom_patches, build_song_sysex
            custom_timbres = load_custom_timbres()
            song_patches = find_song_custom_patches(sess.song_label, custom_timbres)
            song_setup, song_cleanup = build_song_sysex(song_patches)
            if song_setup:
                for msg in song_setup:
                    sess.midi.send(msg)
                # Re-latch programs AFTER the remap: the MT-32 consults
                # Patch Memory at Program Change time, so the PCs
                # MidiSession init just sent latched the factory occupants.
                sess.send_init()
            mt32_cleanup_msgs = song_cleanup
        rate = 48000
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
                aplay_proc = None

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
    print("          [G] GB Mode On/Off  [Space] Enh On/Off  [M] Solo Enh")
    print("          [P] Pause / Resume   [ [ ] / [ ] ] Revisions  [U] Revert on Disk  [Q] Quit\n")

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
                elif key in ("g", "G"):
                    if hasattr(sess, "toggle_gb_sound"):
                        is_gb = sess.toggle_gb_sound()
                        status_msg = f"⚡ GB Mode: {'ON (Real Game Boy APU)' if is_gb else 'OFF (Target Synth)'}"
                        status_timer = 90
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
                        if hasattr(sess, "resume_playback"):
                            sess.resume_playback()
                        elif hasattr(sess, "send_init"):
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
                    frame_len = (rate // 60) * 4
                    if target == "opl3" or getattr(sess, "gb_sound", False):
                        frame_pcm = b"\x00" * frame_len
                    else:
                        frame_pcm = None

                if frame_pcm:
                    if wav_file:
                        wav_file.writeframes(frame_pcm)
                    elif aplay_proc and aplay_proc.stdin:
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

                # Status line rendering (~4 Hz update or immediately on pause)
                if total_frames_played % 15 == 0 or paused:
                    curr_sec = sess.current_frame // 60
                    tot_sec = sess.total_frames // 60
                    is_gb = getattr(sess, "gb_sound", False)
                    if is_gb:
                        gb_tag = "\033[92m[G: ON]\033[0m"
                        enh_tag = "\033[90m[Enh: MUTED]\033[0m"
                    else:
                        gb_tag = "\033[91m[G: OFF]\033[0m"
                        if sess.solo_enh:
                            enh_tag = "\033[93m[Enh: SOLO]\033[0m"
                        elif sess.enable_enh:
                            enh_tag = "\033[92m[Enh: ON]\033[0m"
                        else:
                            enh_tag = "\033[91m[Enh: OFF]\033[0m"

                    tag_a = f"A*:{slot_a['label']}" if active_slot == "A" else f"A:{slot_a['label']}"
                    tag_b = f"B*:{slot_b['label']}" if active_slot == "B" else f"B:{slot_b['label']}"
                    tab_display = f"[{tag_a} | {tag_b}]"
                    play_sym = "⏸" if paused else "▶"
                    banner = f"\r{play_sym} {curr_sec:02d}:{sess.current_frame%60:02d}/{tot_sec:02d}:00 | {target.upper():<4} | {gb_tag} | {enh_tag} | Tab: {tab_display}"
                    if status_timer > 0:
                        banner += f" | {status_msg}"
                        status_timer -= 15
                    sys.stdout.write(f"{banner}\033[K")
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
        if hasattr(sess, "silence_all"):
            sess.silence_all()
        if mt32_cleanup_msgs and hasattr(sess, "midi"):
            for msg in mt32_cleanup_msgs:
                sess.midi.send(msg)


# ---------------------------------------------------------------------------
# Interactive SFX audition loop (OPL3 host synthesis)
# ---------------------------------------------------------------------------
def run_interactive_sfx_audition(
    sfx_query: str,
    delay_seconds: float = 2.5,
    seconds: float | None = None,
    out_wav: Path | None = None,
):
    import opl_renderer
    sess = opl_renderer.SfxSession(sfx_query, delay_seconds=delay_seconds)
    rate = sess.engine.samplerate
    wav_file = None
    aplay_proc = None

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

    print(f"\n🔊 [SFX Audition] {sess.canonical_name} ({sess.header_label})")
    print(f"   Duration: {sess.sfx_frames} frames ({sess.sfx_frames/60:.2f}s) | Replay Delay: {sess.delay_seconds:.1f}s")
    if sess.yaml_path and sess.yaml_path.exists():
        print(f"   Tuned YAML: {sess.yaml_path.name}")
        for ch, cfg in sess.profile.items():
            print(f"     - Channel {ch}: patch={cfg.get('patch')}, vol={cfg.get('volume', 100)}%")
    else:
        print("   Tuned YAML: (None on disk yet — playing raw default)")

    print("\nControls: [Tab] A/B Toggle (Point A: Tuned ↔ Point B: Raw)   [X] Auto-Alternate A↔B")
    print("          [G] GB Mode On/Off   [Space] Retrigger immediately   [ [ ] / [ ] ] Replay Delay ±0.5s")
    print("          [P] Pause / Resume   [Q] Quit\n")

    total_frames = 0
    max_frames = int(seconds * 60) if seconds else None
    last_mtime = sess.yaml_path.stat().st_mtime if sess.yaml_path and sess.yaml_path.exists() else 0.0
    status_msg = ""
    status_timer = 0
    next_tick = time.perf_counter()

    try:
        with RawTerminal() as term:
            while True:
                if max_frames and total_frames >= max_frames:
                    break

                # Watch for YAML modifications on disk
                if sess.yaml_path and sess.yaml_path.exists():
                    try:
                        mtime = sess.yaml_path.stat().st_mtime
                        if mtime > last_mtime:
                            last_mtime = mtime
                            time.sleep(0.02)
                            sess.load_yaml(sess.yaml_path)
                            sess.retrigger()
                            status_msg = f"⚡ Hot-reloaded {sess.yaml_path.name} and retriggered!"
                            status_timer = 120
                    except Exception as e:
                        status_msg = f"⚠ Hot-reload error: {e}"
                        status_timer = 120

                key = term.get_key()
                if key:
                    if key.upper() == "Q" or key == "ESC":
                        break
                    elif key == " ":
                        sess.retrigger()
                        status_msg = "⚡ Retriggered SFX!"
                        status_timer = 60
                    elif key == "\t":
                        slot = sess.toggle_slot()
                        label = sess.slot_a_label if slot == "A" else sess.slot_b_label
                        status_msg = f"⚡ Switched to Point {slot}: {label}"
                        status_timer = 90
                    elif key in ("g", "G"):
                        is_gb = sess.toggle_gb_sound()
                        status_msg = f"⚡ GB Mode: {'ON (Real Game Boy APU)' if is_gb else 'OFF (OPL3 FM)'}"
                        status_timer = 90
                    elif key.upper() == "X":
                        auto_alt = sess.toggle_auto_alternate()
                        status_msg = f"⚡ Auto-Alternating A↔B: {'ON' if auto_alt else 'OFF'}"
                        status_timer = 90
                    elif key == "[":
                        sess.set_delay(sess.delay_seconds - 0.5)
                        status_msg = f"⚡ Replay delay set to {sess.delay_seconds:.1f}s"
                        status_timer = 60
                    elif key == "]":
                        sess.set_delay(sess.delay_seconds + 0.5)
                        status_msg = f"⚡ Replay delay set to {sess.delay_seconds:.1f}s"
                        status_timer = 60
                    elif key in ("p", "P"):
                        sess.paused = not sess.paused
                        if sess.paused:
                            sess.silence_all()
                        status_msg = "⏸ Paused" if sess.paused else "▶ Resumed"
                        status_timer = 60

                frame_pcm = sess.tick()
                total_frames += 1

                if wav_file:
                    wav_file.writeframes(frame_pcm)
                elif aplay_proc and aplay_proc.stdin:
                    try:
                        aplay_proc.stdin.write(frame_pcm)
                        aplay_proc.stdin.flush()
                    except BrokenPipeError:
                        break

                # Progress display
                if total_frames % 6 == 0 or sess.paused:
                    cf = sess.current_frame
                    sf = sess.sfx_frames
                    tf = sess.total_cycle_frames

                    gb_tag = "\033[92m[G: ON]\033[0m" if sess.gb_sound else "\033[91m[G: OFF]\033[0m"
                    tag_a = f"A*:{sess.slot_a_label}" if sess.active_slot == "A" else f"A:{sess.slot_a_label}"
                    tag_b = f"B*:{sess.slot_b_label}" if sess.active_slot == "B" else f"B:{sess.slot_b_label}"
                    tab_tag = f"Tab: [{tag_a} | {tag_b}]"

                    if sess.auto_alternate:
                        alt_tag = "\033[92m[Auto A↔B: ON]\033[0m"
                    else:
                        alt_tag = "\033[91m[Auto A↔B: OFF]\033[0m"

                    play_sym = "⏸" if sess.paused else "▶"
                    if sess.paused:
                        state_str = f"Paused [{cf:02d}/{sf:02d}f]"
                    elif cf < sf:
                        state_str = f"Playing [{cf:02d}/{sf:02d}f]"
                    else:
                        rem_s = (tf - cf) / 60.0
                        state_str = f"Delay [{rem_s:.1f}s]"

                    extra = f" | {status_msg}" if status_timer > 0 else ""
                    if status_timer > 0:
                        status_timer -= 6

                    sys.stdout.write(f"\r{play_sym} {gb_tag} | {tab_tag} {alt_tag} {state_str:<18} (Delay: {sess.delay_seconds:.1f}s){extra}\033[K")
                    sys.stdout.flush()

                if not wav_file:
                    next_tick += (1.0 / 60.0)
                    now = time.perf_counter()
                    if next_tick > now:
                        time.sleep(next_tick - now)
                    elif now - next_tick > 0.1:
                        next_tick = now
    finally:
        sys.stdout.write("\n")
        sys.stdout.flush()
        if wav_file:
            wav_file.close()
        if aplay_proc:
            if aplay_proc.stdin:
                aplay_proc.stdin.close()
            aplay_proc.terminate()
            aplay_proc.wait()


# ---------------------------------------------------------------------------
# Track Catalog & Fuzzy Matching
# ---------------------------------------------------------------------------
def get_audio_catalog() -> tuple[dict[str, str], dict[str, str]]:
    """Returns (music_const_to_header, sfx_const_to_header) dynamically parsed from pret.

    Both music tracks and sound effects are declared identically in
    constants/music_constants.asm via `music_const <CONST>, <Header_Label>`.
    """
    from pret_audio import AudioROM
    from gen_audio_data import parse_music_constants
    rom = AudioROM(ROOT)
    consts, _ = parse_music_constants()
    music = {name: lbl for name, lbl in consts.items()
             if name.startswith("MUSIC_") and lbl in rom.symtab}
    sfx = {name: lbl for name, lbl in consts.items()
           if name.startswith("SFX_") and lbl in rom.symtab}
    return music, sfx


def get_all_tracks() -> list[str]:
    music, _ = get_audio_catalog()
    return sorted(set(music.values()))


def get_all_sfx() -> list[str]:
    _, sfx = get_audio_catalog()
    return sorted(set(sfx.keys()))


def resolve_audio_label(
    query: str,
    music_map: dict[str, str],
    sfx_map: dict[str, str],
    force_sfx: bool = False,
) -> tuple[str, str]:
    """Resolves query string to ('music', canonical_track_label) or ('sfx', canonical_sfx_const).

    Derived entirely from pret constants and headers (no hardcoded alias tables):
    - Exact match on constant name or header label
    - Case-insensitive exact match
    - Normalized stem match (stripping 'music_', 'sfx_', and '_')
    - Substring match across stems
    - difflib fuzzy match across all audio symbols
    """
    import difflib

    query_str = query.strip()
    if not query_str:
        raise SystemExit("Empty sound or music query.")

    music_headers = {lbl: lbl for lbl in music_map.values()}
    sfx_headers_to_const = {lbl: name for name, lbl in sfx_map.items()}

    def normalize(s: str) -> str:
        return s.lower().replace("music_", "").replace("sfx_", "").replace("_", "")

    q_upper = query_str.upper()
    q_norm = normalize(query_str)

    # 1. Exact constant or header match
    if not force_sfx:
        if q_upper in music_map:
            return "music", music_map[q_upper]
        if query_str in music_headers:
            return "music", query_str
        if f"MUSIC_{q_upper}" in music_map:
            return "music", music_map[f"MUSIC_{q_upper}"]

    if q_upper in sfx_map:
        return "sfx", q_upper
    if query_str in sfx_headers_to_const:
        return "sfx", sfx_headers_to_const[query_str]
    if f"SFX_{q_upper}" in sfx_map:
        return "sfx", f"SFX_{q_upper}"

    # 2. Case-insensitive exact match against header labels or constant names
    if not force_sfx:
        for c, h in music_map.items():
            if query_str.lower() in (c.lower(), h.lower()):
                return "music", h

    for c, h in sfx_map.items():
        if query_str.lower() in (c.lower(), h.lower()):
            return "sfx", c

    # 3. Normalized stem matching (stripping music_/sfx_ and underscores)
    music_stems: dict[str, str] = {}
    for c, h in music_map.items():
        music_stems[normalize(c)] = h
        music_stems[normalize(h)] = h

    sfx_stems: dict[str, str] = {}
    for c, h in sfx_map.items():
        sfx_stems[normalize(c)] = c
        sfx_stems[normalize(h)] = c

    if force_sfx:
        if q_norm in sfx_stems:
            return "sfx", sfx_stems[q_norm]
    else:
        if q_norm in music_stems and q_norm not in sfx_stems:
            return "music", music_stems[q_norm]
        if q_norm in sfx_stems and q_norm not in music_stems:
            return "sfx", sfx_stems[q_norm]
        if q_norm in music_stems and q_norm in sfx_stems:
            raise SystemExit(
                f"Query '{query_str}' matches both MUSIC ({music_stems[q_norm]}) and SFX ({sfx_stems[q_norm]}).\n"
                f"Use --sfx to select the sound effect, or specify the full constant name."
            )

    # 4. Substring matching across stems
    matched_music = set()
    if not force_sfx:
        matched_music = {h for stem, h in music_stems.items() if q_norm in stem}
    matched_sfx = {c for stem, c in sfx_stems.items() if q_norm in stem}

    if len(matched_music) == 1 and not matched_sfx:
        chosen = next(iter(matched_music))
        print(f"💡 Substring matched '{query_str}' -> '{chosen}' (MUSIC)")
        return "music", chosen
    if len(matched_sfx) == 1 and not matched_music:
        chosen = next(iter(matched_sfx))
        print(f"💡 Substring matched '{query_str}' -> '{chosen}' (SFX)")
        return "sfx", chosen

    # 5. Fuzzy matching via difflib across normalized stems
    all_stems: dict[str, tuple[str, str]] = {}
    if not force_sfx:
        for s, h in music_stems.items():
            all_stems[s] = ("music", h)
    for s, c in sfx_stems.items():
        all_stems[s] = ("sfx", c)

    close = difflib.get_close_matches(q_norm, list(all_stems.keys()), n=1, cutoff=0.38)
    if close:
        kind, item = all_stems[close[0]]
        print(f"💡 Fuzzy matched '{query_str}' -> '{item}' ({kind.upper()})")
        return kind, item

    # 6. Ambiguous matches report
    combined_subs = [f"{m} (MUSIC)" for m in sorted(matched_music)] + [f"{s} (SFX)" for s in sorted(matched_sfx)]
    if len(combined_subs) > 1:
        raise SystemExit(
            f"Ambiguous query '{query_str}'. Matches:\n" +
            "\n".join(f"  - {m}" for m in combined_subs)
        )

    # 7. Suggestions on failure
    all_names = (list(music_map.values()) if not force_sfx else []) + list(sfx_map.keys())
    close_full = difflib.get_close_matches(query_str.lower(), [x.lower() for x in all_names], n=4, cutoff=0.25)
    suggestion_str = ""
    if close_full:
        lower_to_orig = {x.lower(): x for x in all_names}
        suggestions = [lower_to_orig[c] for c in close_full]
        suggestion_str = "\nDid you mean:\n" + "\n".join(f"  - {s}" for s in suggestions)

    raise SystemExit(
        f"No song or sound effect matching '{query_str}' found.{suggestion_str}\n"
        f"(Run 'audition.py --list-music' or 'audition.py --list-sfx' to inspect available audio)"
    )


def print_song_list(tracks: list[str]):
    import re
    overrides_dir = AUDIO_DIR / "overrides"
    print(f"\n🎵 Available Music Tracks ({len(tracks)} total):")
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
    print("\nUsage: tools/audio/audition.py <SongName or SFX_Name> [--delay 2.5]  (or --list-sfx for sound effects)\n")


def print_sfx_list(sfx_list: list[str]):
    sfx_dir = AUDIO_DIR / "sfx"
    tuned_count = 0
    lines = []
    for idx, s in enumerate(sfx_list, 1):
        clean_name = s.lower().replace("sfx_", "").replace("_", "")
        yaml_name = "-"
        if sfx_dir.exists():
            for p in sfx_dir.glob("*.yaml"):
                if p.stem.lower().replace("sfx_", "").replace("_", "") == clean_name:
                    yaml_name = p.name
                    tuned_count += 1
                    break
        lines.append(f"  {idx:<4} {s:<32} {yaml_name:<20}")

    print(f"\n🔊 Available Sound Effects ({len(sfx_list)} total, {tuned_count} tuned with OPL3 YAML):")
    print(f"  {'#':<4} {'SFX Constant':<32} {'YAML Profile':<20}")
    print("  " + "-" * 60)
    for line in lines:
        print(line)
    print("\nUsage: tools/audio/audition.py <SFX_Name> [--delay 2.5]  (fuzzy search supported)\n")


# ---------------------------------------------------------------------------
# Pre-caching authentic Game Boy audio for instant audition startup
# ---------------------------------------------------------------------------
def precache_all_gb_audio(samplerate: int = 48000):
    cache_dir = AUDIO_DIR / ".gb_cache"
    music_dir = cache_dir / "music"
    sfx_dir = cache_dir / "sfx"
    music_dir.mkdir(parents=True, exist_ok=True)
    sfx_dir.mkdir(parents=True, exist_ok=True)

    print("⚡ Initializing Game Boy APU sound emulator...")
    t_start = time.time()
    from opl_renderer import (
        GbApuEngine, DRUM_PARAMS, midi_key_to_gb_freq, midi_key_to_gb_wave_freq,
        sfx_from_headers, simulate_sfx_events
    )
    from pret_audio import AudioROM
    from gen_audio_data import parse_music_constants
    from gb_to_midi import simulate_song, build_addr_map, songs_from_headers

    engine = GbApuEngine(samplerate=samplerate)
    rom = AudioROM(ROOT)
    amap = build_addr_map(rom)
    music_headers = songs_from_headers(rom)
    sfx_headers = sfx_from_headers(rom)
    consts, _ = parse_music_constants()

    print("🔊 Pre-caching all Sound Effects...")
    sfx_items = [
        (c, h) for c, h in consts.items()
        if c.startswith("SFX_") and h in sfx_headers
    ]
    sfx_items.sort()
    sfx_bytes = 0
    manifest_sfx = {}

    for idx, (c, h) in enumerate(sfx_items, 1):
        ch_list = sfx_headers[h]
        events, sfx_frames = simulate_sfx_events(rom, amap, ch_list)
        engine.reset()
        pcm = []
        for f in range(sfx_frames + 15):
            for ev in events.get(f, []):
                ev_type = ev[0]
                v = ev[1]
                if ev_type == "noise":
                    nr43, vol, fade_p, fade_d = ev[3]
                    engine.trigger_noise(nr43, vol=vol, fade_period=fade_p, fade_dir=fade_d)
                elif ev_type == "square":
                    freq, duty, vol, fade_p, fade_d = ev[3]
                    if v in (0, 1):
                        engine.trigger_pulse(v, freq, duty=duty, vol=vol, fade_period=fade_p, fade_dir=fade_d)
                    elif v == 2:
                        engine.trigger_wave(freq, vol_code=1)
                elif ev_type == "sweep":
                    if v == 0:
                        engine.write_reg(0xFF10, ev[3])
                elif ev_type == "off":
                    engine.silence_channel(v)
            pcm.append(engine.generate_frame())
        buf = b"".join(pcm)
        sfx_file = sfx_dir / f"{c}.pcm"
        sfx_file.write_bytes(buf)
        sfx_bytes += len(buf)
        manifest_sfx[c] = {
            "header": h,
            "frames": sfx_frames + 15,
            "bytes": len(buf),
        }
        print(f"\r  [{idx}/{len(sfx_items)}] {c:<32} ({len(buf) // 1024} KB)", end="", flush=True)
    print()

    print("🎵 Pre-caching all Music Tracks...")
    music_items = sorted(music_headers.items())
    music_bytes = 0
    manifest_music = {}

    for idx, (h, addr) in enumerate(music_items, 1):
        song = simulate_song(rom, amap, h, addr)
        loop_end = song.end or max((n.frame + n.dur for n in song.notes), default=600)
        base_events = {}
        for n in song.notes:
            v = n.chan - 1
            is_drum = (n.chan == 4)
            fade = getattr(n, "fade", 0)
            base_events.setdefault(n.frame, []).append(("on", v, (n.key, n.vel, fade, is_drum)))
            off_f = min(n.frame + n.dur, loop_end)
            base_events.setdefault(off_f, []).append(("off", v, None))

        engine.reset()
        pcm = []
        for f in range(loop_end):
            for ev_type, v, args in base_events.get(f, []):
                if ev_type == "on":
                    key, vel, fade, is_drum = args
                    if is_drum or v == 3:
                        p = DRUM_PARAMS.get(key, (8, 1, 34))
                        engine.trigger_noise(p[2], vol=p[0], fade_period=p[1], fade_dir=0)
                    elif v in (0, 1):
                        gb_vol = min(15, max(1, (vel - 15) // 7))
                        fade_p = abs(fade) if fade != 0 else 0
                        fade_d = 1 if fade < 0 else 0
                        freq = midi_key_to_gb_freq(key)
                        engine.trigger_pulse(v, freq, duty=2, vol=gb_vol, fade_period=fade_p, fade_dir=fade_d)
                    elif v == 2:
                        freq = midi_key_to_gb_wave_freq(key)
                        engine.trigger_wave(freq, vol_code=1)
                elif ev_type == "off":
                    engine.silence_channel(v)
            pcm.append(engine.generate_frame())
        buf = b"".join(pcm)
        mus_file = music_dir / f"{h}.pcm"
        mus_file.write_bytes(buf)
        music_bytes += len(buf)
        manifest_music[h] = {
            "loop_start": song.loop_start or 0,
            "loop_end": loop_end,
            "bytes": len(buf),
        }
        print(f"\r  [{idx}/{len(music_items)}] {h:<32} ({len(buf) // (1024*1024)} MB)", end="", flush=True)
    print()

    manifest = {
        "samplerate": samplerate,
        "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "total_sfx": len(sfx_items),
        "total_music": len(music_items),
        "sfx": manifest_sfx,
        "music": manifest_music,
    }
    import json
    (cache_dir / "manifest.json").write_text(json.dumps(manifest, indent=2))

    total_time = time.time() - t_start
    total_mb = (sfx_bytes + music_bytes) / (1024 * 1024)
    print(f"\n✅ Successfully pre-cached {len(sfx_items)} SFX and {len(music_items)} music tracks ({total_mb:.1f} MB total) in {total_time:.1f}s.")
    print(f"📁 Cache directory: {cache_dir}\n")


# ---------------------------------------------------------------------------
# Main CLI
# ---------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument(
        "song",
        nargs="?",
        help="song or SFX label, substring, or fuzzy name (e.g. PalletTown, SFX_GO_OUTSIDE, Go_Outside)",
    )
    ap.add_argument(
        "--init",
        action="store_true",
        help="precache authentic Game Boy APU reference audio for all sounds and music",
    )
    ap.add_argument(
        "-l", "--list", "--list-music",
        dest="list_music",
        action="store_true",
        help="list all available music tracks and their enhancement/override status",
    )
    ap.add_argument(
        "--list-sfx",
        action="store_true",
        help="list all available sound effects and their YAML profile status",
    )
    ap.add_argument(
        "--list-all",
        action="store_true",
        help="list both music tracks and sound effects",
    )
    ap.add_argument(
        "--sfx",
        action="store_true",
        help="force interpretation of query as a sound effect",
    )
    ap.add_argument(
        "--delay",
        type=float,
        default=2.5,
        help="delay in seconds between SFX replays (default: 2.5s)",
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

    if args.init:
        precache_all_gb_audio()
        return

    music_map, sfx_map = get_audio_catalog()
    all_tracks = sorted(set(music_map.values()))
    all_sfx = sorted(set(sfx_map.keys()))

    if args.list_sfx:
        print_sfx_list(all_sfx)
        return

    if args.list_all:
        print_song_list(all_tracks)
        print_sfx_list(all_sfx)
        return

    if args.list_music or not args.song:
        print_song_list(all_tracks)
        return

    kind, canonical_label = resolve_audio_label(
        query=args.song,
        music_map=music_map,
        sfx_map=sfx_map,
        force_sfx=args.sfx,
    )

    if kind == "sfx":
        run_interactive_sfx_audition(
            sfx_query=canonical_label,
            delay_seconds=args.delay,
            seconds=args.seconds,
            out_wav=args.out,
        )
    else:
        run_interactive_audition(
            target=args.target,
            song_label=canonical_label,
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

