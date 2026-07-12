#!/usr/bin/env python3
"""Decode PERF.BIN — the DEBUG_PERF per-stage frame profile.

The port (src/debug/perf.asm) latches PIT channel 0 around each stage of
DelayFrame and accumulates elapsed PIT counts. This converts those counts to
milliseconds and prints a per-stage budget, so a stage's share of the frame is
directly comparable across DOSBox-X cycle settings and real hardware.

Usage:
    tools/read_perf.py [PERF.BIN] [--baseline OTHER.BIN]

With --baseline, prints the delta against an earlier capture (the before/after
check every stage of docs/current_plan_compositor_perf.md must pass).
"""

import argparse
import struct
import sys
from pathlib import Path

PIT_HZ = 1193181.666

# Must match the PERF_* stage ids in src/video/frame.asm.
STAGE_NAMES = [
    "wait (vblank+PIT)",
    "commit (regs/pal/bgcopy/anim)",
    "oam (PrepareOAMData+DMA)",
    "audio_tick",
    "render_bg",
    "render_sprites",
    "present_windows",
    "present (→VGA)",
    "misc (joypad/RNG/clock)",
]


def load(path):
    data = Path(path).read_bytes()
    if data[:4] != b"PERF":
        sys.exit(f"{path}: not a PERF.BIN (bad magic {data[:4]!r})")
    version, stages, frames, divisor = struct.unpack_from("<4I", data, 4)
    if version != 1:
        sys.exit(f"{path}: unsupported PERF.BIN version {version}")
    acc = struct.unpack_from(f"<{stages}I", data, 0x14)
    mx = struct.unpack_from(f"<{stages}I", data, 0x14 + stages * 4)
    return {"frames": frames, "divisor": divisor, "acc": acc, "max": mx,
            "stages": stages}


def ms(counts):
    return counts * 1000.0 / PIT_HZ


def report(p, base=None):
    frames = p["frames"] or 1
    frame_budget_ms = ms(p["divisor"])
    print(f"frames measured : {p['frames']}")
    print(f"PIT divisor     : {p['divisor']}  "
          f"({PIT_HZ / p['divisor']:.4f} Hz → {frame_budget_ms:.3f} ms/frame budget)")
    print()
    header = f"{'stage':<32}{'ms/frame':>10}{'% budget':>10}{'worst ms':>10}"
    if base:
        header += f"{'Δ ms/frame':>12}"
    print(header)
    print("-" * len(header))

    total = 0.0
    busy = 0.0
    for i in range(p["stages"]):
        avg = ms(p["acc"][i]) / frames
        worst = ms(p["max"][i])
        total += avg
        if i != 0:  # stage 0 is the pacing spin, not work
            busy += avg
        line = (f"{STAGE_NAMES[i]:<32}{avg:>10.3f}"
                f"{100.0 * avg / frame_budget_ms:>9.1f}%{worst:>10.3f}")
        if base:
            bavg = ms(base["acc"][i]) / (base["frames"] or 1)
            line += f"{avg - bavg:>+12.3f}"
        print(line)
    print("-" * len(header))
    print(f"{'TOTAL (incl. wait)':<32}{total:>10.3f}"
          f"{100.0 * total / frame_budget_ms:>9.1f}%")
    print(f"{'WORK (excl. wait)':<32}{busy:>10.3f}"
          f"{100.0 * busy / frame_budget_ms:>9.1f}%")
    if busy > frame_budget_ms:
        print("\n*** OVERRUN: work exceeds the frame budget — music will drag.")


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("perf", nargs="?", default="PERF.BIN")
    ap.add_argument("--baseline", help="earlier PERF.BIN to diff against")
    args = ap.parse_args()
    base = load(args.baseline) if args.baseline else None
    report(load(args.perf), base)


if __name__ == "__main__":
    main()
