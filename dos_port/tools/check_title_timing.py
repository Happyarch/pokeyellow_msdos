#!/usr/bin/env python3
"""check_title_timing.py — verify the title bounce frame by frame, through pixels.

menu-intro A2.5. The contract is that the port's bounce matches the golden ROM
"record by record". A register trace cannot show that here, for two reasons:

  1. GBSTATE.BIN has no HRAM region, so hSCY is not in any dump the port already
     writes, and adding a region would change the region count for every
     existing golden.
  2. A register trace proves what the game WROTE, not what the renderer drew.
     The projection is exactly the layer in between, so it is the layer under
     test.

So this compares rendered geometry instead. hSCY drives WIN_SRC_Y, which shifts
the BG sample point, which moves the logo. Measuring the logo's bottom edge in a
mid-bounce FRAME.BIN therefore recovers the hSCY that actually reached the
screen.

THE ONE-FRAME LAG IS REAL, NOT A FUDGE. pret's .ScrollTitleScreenPokemonLogo is
`call DelayFrame` and THEN `ld [bc], a` -- the frame is rendered before hSCY is
updated -- and the port keeps that order. So the buffer captured at bounce frame
N shows the hSCY of step N-1. Predicting with step N instead produces a constant
non-zero residual equal to the current run's delta, which is how this was found.

Capture the frames first (each is a full boot through the intro, ~40 s):

    for n in 4 8 12 16 17 18 20 21 24 25 28 30 32; do
        TITLE_DUMP_FRAME=$n tools/pixelcheck.sh title -o /tmp/bounce/f$n.bin
    done
    tools/check_title_timing.py /tmp/bounce

Optionally pass --mgba-csv to re-derive the expected sequence from a golden-ROM
trace (tools/mgba_harness/scenarios/title_trace.lua) instead of from pret's
table, so the expectation itself is measured rather than assumed.
"""

import argparse
import csv
import os
import sys

RENDER_W = 320
SURFACE_X0, SURFACE_X1 = 80, 240
SURFACE_Y0 = 24
# The bounce window pins everything from y=88 down (hWY=64 -> 24+64). Only the
# band above it moves, so only that band may be measured.
BAND_Y1 = 88
# The logo occupies tilemap rows 1..7, i.e. BG y 8..63. Its bottom edge sits at
# surface y = 63 - hSCY, and the surface starts at canvas y = SURFACE_Y0.
LOGO_BOTTOM_BG_Y = 63

# pret engine/movie/title.asm:DisplayTitleScreen.TitleScreenPokemonLogoYScrolls
YSCROLL_TABLE = [(-4, 16), (3, 4), (-3, 4), (2, 2), (-2, 2), (1, 2), (-1, 2)]


def expected_scy():
    """hSCY after each bounce step; index 0 is the pre-bounce value."""
    scy, seq = 0x40, [0x40]
    for delta, count in YSCROLL_TABLE:
        for _ in range(count):
            scy = (scy + delta) & 0xFF
            seq.append(scy)
    return seq


def scy_from_mgba(path):
    rows = [int(r["scy"]) for r in csv.DictReader(open(path))]
    start = next(i for i, s in enumerate(rows) if s != 0x40)
    return rows[start - 1:start - 1 + len(expected_scy())]


def logo_bottom(frame):
    """Lowest inked scanline in the moving band, or None if nothing is there."""
    rows = [
        y for y in range(SURFACE_Y0, BAND_Y1)
        if any(frame[y * RENDER_W + x] for x in range(SURFACE_X0, SURFACE_X1))
    ]
    return max(rows) if rows else None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dir", help="directory of fN.bin captures")
    ap.add_argument("--mgba-csv", help="derive expectations from a golden trace")
    args = ap.parse_args()

    seq = scy_from_mgba(args.mgba_csv) if args.mgba_csv else expected_scy()
    if args.mgba_csv:
        if seq != expected_scy():
            print("MISMATCH: the golden trace disagrees with pret's table", file=sys.stderr)
            return 1
        print("golden trace and pret's table agree on all "
              f"{len(seq)} hSCY values")

    frames = sorted(
        int(f[1:-4]) for f in os.listdir(args.dir)
        if f.startswith("f") and f.endswith(".bin")
    )
    if not frames:
        print(f"no fN.bin captures in {args.dir}", file=sys.stderr)
        return 2

    print(f"{'frame':>5} {'hSCY':>5} {'predict':>8} {'measured':>9}  delta")
    exact = skipped = bad = 0
    for n in frames:
        with open(os.path.join(args.dir, f"f{n}.bin"), "rb") as fh:
            buf = fh.read()
        if n - 1 >= len(seq):
            print(f"{n:5d}  frame is past the end of the bounce", file=sys.stderr)
            return 2
        scy = seq[n - 1]                       # the one-frame lag, see docstring
        predicted = LOGO_BOTTOM_BG_Y - scy + SURFACE_Y0
        measured = logo_bottom(buf)
        if predicted < SURFACE_Y0 or measured is None:
            # The logo has scrolled entirely above the viewport; whatever is the
            # lowest inked row is not the logo, so this frame carries no signal.
            print(f"{n:5d} {scy:5d} {predicted:8d} {'--':>9}  logo above the view")
            skipped += 1
            continue
        delta = measured - predicted
        print(f"{n:5d} {scy:5d} {predicted:8d} {measured:9d}  {delta:+d}")
        exact += delta == 0
        bad += delta != 0

    print(f"\nexact={exact} mismatch={bad} unmeasurable={skipped}")
    if bad:
        print("FAIL: the rendered bounce does not track the reference hSCY",
              file=sys.stderr)
        return 1
    if exact == 0:
        print("FAIL: nothing was actually measured", file=sys.stderr)
        return 1
    print("PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
