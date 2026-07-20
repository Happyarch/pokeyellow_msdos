#!/usr/bin/env python3
"""check_projection.py — verify a DEBUG_CINEMATIC_MARKERS FRAME.BIN.

A1.6 of docs/current_plan_menu_intro.md. The marker harness
(src/debug/debug_dump.asm:RunCinematicMarkersTest) renders a synthetic cinematic
surface; this asserts what the plan's acceptance criteria actually require.

Why pixels and not a register trace: a trace records the scroll value the game
WROTE, which matches ground truth even when the renderer mis-samples it. Correct
GB mod-256 wrap and a linear read differ ONLY in rendered pixels, and only on
wrapped frames. So the wrap check here is the sole evidence that the sampling is
right.

Usage:
    tools/check_projection.py FRAME.BIN [--sx N] [--sy N]
    tools/check_projection.py --sweep DIR      # cross-frame motion + wrap checks
"""

import argparse
import sys
from collections import Counter
from pathlib import Path

W, H = 320, 200

# Projected surface: canvas tile (10,3), pixel (80,24), exclusive end (240,168).
X0, Y0, X1, Y1 = 80, 24, 240, 168

MARK_SOLID_PX = 3      # tile 1 -> color 3
MARK_WRAP_PX = 2       # tile 2 -> color 2
MARK_POISON_PX = 1     # tile 3 -> color 1; sampling this means a LINEAR read
MATTE_PX = 0
OBJ_BAND = 32          # OBJ pixels are written as 32+ (DAC bands 32..63)


def load(path):
    d = Path(path).read_bytes()
    if len(d) != W * H:
        sys.exit(f"{path}: expected {W*H} bytes, got {len(d)}")
    return d


def px(d, x, y):
    return d[y * W + x]


def check_frame(d, name, sx, sy):
    """Assertions that hold at every offset. Returns a list of failures."""
    bad = []

    # 1. The matte carries only the colour-zero field — no scene content, no OBJ.
    #    This is what catches a sprite leaking outside the projected rectangle.
    for y in range(H):
        for x in range(W):
            if X0 <= x < X1 and Y0 <= y < Y1:
                continue
            v = px(d, x, y)
            if v != MATTE_PX:
                bad.append(f"matte contaminated at ({x},{y}) = {v}")
                break
        if bad:
            break

    # 2. No poison. Poison lives only in the ADJACENT tilemap, so a single
    #    poison pixel proves the renderer walked past the map boundary instead
    #    of wrapping within it.
    n_poison = sum(1 for v in d if v == MARK_POISON_PX)
    if n_poison:
        bad.append(f"{n_poison} POISON pixels — sampled the adjacent tilemap "
                   f"(linear read) instead of wrapping within the map")

    # 3. OBJ stay inside the projected rectangle.
    for i, v in enumerate(d):
        if v >= OBJ_BAND:
            x, y = i % W, i // W
            if not (X0 <= x < X1 and Y0 <= y < Y1):
                bad.append(f"OBJ pixel outside the surface at ({x},{y})")
                break

    # 4. Edge-straddling OBJ are clipped to exactly half: 4 markers x 32 px.
    #    The 4 GB-hidden markers (OAM_Y=0/160, OAM_X=0/168) must contribute
    #    nothing, so any count above 128 means a hidden marker was drawn and any
    #    count below means clipping ate too much.
    n_obj = sum(1 for v in d if v >= OBJ_BAND)
    if n_obj != 128:
        bad.append(f"OBJ pixel count {n_obj}, expected 128 "
                   f"(4 edge-straddling markers x 32 visible px; the 4 hidden "
                   f"markers must draw nothing)")

    return bad


def describe(d):
    c = Counter(d)
    return {"solid": c.get(MARK_SOLID_PX, 0), "wrap": c.get(MARK_WRAP_PX, 0),
            "poison": c.get(MARK_POISON_PX, 0),
            "obj": sum(n for v, n in c.items() if v >= OBJ_BAND)}


def sweep(d_dir):
    """Cross-frame checks: motion must be real, and wrap must reach the origin."""
    bad = []
    frames = {}
    for p in sorted(Path(d_dir).glob("sx*_sy*.bin")):
        stem = p.stem                       # sxNNN_syNNN
        sx = int(stem[2:5])
        sy = int(stem[8:11])
        frames[(sx, sy)] = load(p)

    if not frames:
        sys.exit(f"{d_dir}: no sxNNN_syNNN.bin frames found")

    # Sub-tile motion: consecutive fine offsets must render DIFFERENT frames.
    # A renderer that ignored the offset entirely would emit identical frames and
    # would otherwise pass every single-frame assertion above.
    for axis, key in (("X", lambda n: (n, 0)), ("Y", lambda n: (0, n))):
        seen = [(n, frames[key(n)]) for n in range(8) if key(n) in frames]
        for (a, fa), (b, fb) in zip(seen, seen[1:]):
            if fa == fb:
                bad.append(f"{axis}: offsets {a} and {b} render identically — "
                           f"the fine source offset is being ignored")

    # Wrap: at 252..255 the surface must still show the source map's own row 0 /
    # column 0 content (MARK_WRAP), not blank and not poison.
    for axis, key in (("X", lambda n: (n, 0)), ("Y", lambda n: (0, n))):
        for n in (252, 253, 254, 255):
            f = frames.get(key(n))
            if f is None:
                continue
            st = describe(f)
            if st["poison"]:
                bad.append(f"{axis}={n}: {st['poison']} poison px — wrapped read "
                           f"escaped into the adjacent tilemap")
            if st["wrap"] == 0:
                bad.append(f"{axis}={n}: no wrap-marker content — wrapped samples "
                           f"did not reach the source map's origin")

    return bad, frames


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("frame", nargs="?")
    ap.add_argument("--sx", type=int, default=0)
    ap.add_argument("--sy", type=int, default=0)
    ap.add_argument("--sweep", metavar="DIR")
    args = ap.parse_args()

    failures = []

    if args.sweep:
        cross, frames = sweep(args.sweep)
        failures += cross
        for (sx, sy), d in sorted(frames.items()):
            f = check_frame(d, f"sx{sx}_sy{sy}", sx, sy)
            st = describe(d)
            status = "ok " if not f else "FAIL"
            print(f"  {status} sx={sx:<3} sy={sy:<3} "
                  f"solid={st['solid']:<5} wrap={st['wrap']:<5} "
                  f"obj={st['obj']:<4} poison={st['poison']}")
            failures += [f"sx{sx}_sy{sy}: {m}" for m in f]
    else:
        if not args.frame:
            sys.exit("need a FRAME.BIN or --sweep DIR")
        d = load(args.frame)
        failures += check_frame(d, args.frame, args.sx, args.sy)
        print(describe(d))

    print()
    if failures:
        print(f"FAIL — {len(failures)} problem(s):")
        for m in failures:
            print(f"  - {m}")
        return 1
    print("PASS — projection, matte, OBJ clipping and wrap sampling all verified")
    return 0


if __name__ == "__main__":
    sys.exit(main())
