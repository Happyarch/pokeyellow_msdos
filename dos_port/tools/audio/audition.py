#!/usr/bin/env python3
"""audition.py — host-side fast audition loop for the MIDI music path.

Plays a generated song (assets/midi/<target>/<Song>.mid) on an ALSA MIDI
port without booting DOS: MUNT (mt32emu-qt) for --target mt32, fluidsynth
(or any GM synth) for --target gm. For MT-32 the current setup SysEx from
tools/audio/mt32/timbres.yaml is prepended, paced, so what you hear matches
what mt32_upload programs at boot — edit timbres.yaml / overrides/*.yaml,
`make assets`, re-run, listen.

Typical loop:
    mt32emu-qt &                      # MUNT with an ALSA input port
    tools/audio/audition.py Music_PalletTown
    tools/audio/audition.py --target gm --port 128:0 Music_PalletTown

End-to-end verification (real driver, MPU-401 → DOSBox-X's built-in MUNT):
    dos_port/run-mt32                 # see that script for ROM setup

The played file is the .mid itself (intro + one loop pass).
"""

from __future__ import annotations

import argparse
import struct
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen_mt32_patches import build_messages  # noqa: E402
import yaml  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
MIDI_DIR = ROOT / "dos_port" / "assets" / "midi"
TIMBRES = Path(__file__).resolve().parent / "mt32" / "timbres.yaml"

SYSEX_GAP_TICKS = 4               # ~66 ms between setup messages @60 tps


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
    data += vlq(60) + b"\xff\x2f\x00"     # 1 s settle before the song
    return b"MTrk" + struct.pack(">I", len(data)) + bytes(data)


def with_setup(mid: bytes, msgs: list[bytes]) -> bytes:
    """Insert the SysEx track after the tempo track of a format-1 SMF."""
    fmt, ntrk, div = struct.unpack(">HHH", mid[8:14])
    assert mid[:4] == b"MThd" and fmt == 1
    # track 0 ends where track 1 begins
    t0_len = struct.unpack(">I", mid[18:22])[0]
    cut = 14 + 8 + t0_len
    hdr = b"MThd" + struct.pack(">IHHH", 6, 1, ntrk + 1, div)
    return hdr + mid[14:cut] + sysex_track(msgs) + mid[cut:]


def pick_port(target: str) -> str:
    """First ALSA writable port whose client name matches the synth."""
    want = ("mt32", "munt") if target == "mt32" else ("fluid", "synth", "timid")
    out = subprocess.run(["aplaymidi", "-l"], capture_output=True, text=True,
                         check=True).stdout
    for line in out.splitlines()[1:]:
        parts = line.split(None, 2)
        if len(parts) == 3 and any(w in parts[2].lower() for w in want):
            return parts[0]
    raise SystemExit(
        f"no ALSA port matching {want} — is the synth running? "
        f"(aplaymidi -l to inspect, --port to override)\n{out}")


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("song", help="header label or unique substring "
                                 "(e.g. Music_PalletTown or PalletTown)")
    ap.add_argument("--target", choices=("mt32", "gm"), default="mt32")
    ap.add_argument("--port", help="ALSA port (default: auto-detect)")
    ap.add_argument("--no-setup", action="store_true",
                    help="skip the MT-32 setup SysEx")
    args = ap.parse_args()

    mdir = MIDI_DIR / args.target
    if not mdir.is_dir():
        raise SystemExit(f"{mdir} missing — run `make assets` "
                         f"(or gb_to_midi.py --target {args.target})")
    hits = sorted(p for p in mdir.glob("*.mid") if args.song in p.stem)
    exact = [p for p in hits if p.stem == args.song]
    if exact:
        hits = exact
    if len(hits) != 1:
        raise SystemExit(f"song {args.song!r} matches "
                         f"{[p.stem for p in hits] or 'nothing'}")
    mid = hits[0].read_bytes()

    if args.target == "mt32" and not args.no_setup:
        msgs = build_messages(yaml.safe_load(TIMBRES.read_text()) or {})
        mid = with_setup(mid, msgs)
        print(f"prepended {len(msgs)} setup SysEx messages")

    port = args.port or pick_port(args.target)
    with tempfile.NamedTemporaryFile(suffix=".mid") as tmp:
        tmp.write(mid)
        tmp.flush()
        print(f"playing {hits[0].stem} -> port {port}")
        subprocess.run(["aplaymidi", "-p", port, tmp.name], check=True)


if __name__ == "__main__":
    main()
