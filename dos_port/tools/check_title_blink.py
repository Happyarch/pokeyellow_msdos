#!/usr/bin/env python3
"""check_title_blink.py — verify the eye-blink timing against the golden ROM.

menu-intro A2.5, the blink half. Same shape as check_title_timing.py: the golden
ROM supplies the reference sequence, and the port is measured through PIXELS
rather than registers, because wTitleScreenScene is in no dump the port writes
and because what matters is the frame the eyes actually changed on screen.

ALIGNMENT IS THE WHOLE PROBLEM HERE. The reference must be indexed from .loop,
which is marked by wTitleScreenScene+4 becoming $0F (pret's idle loop writes it
first thing). Indexing from the hWY settle instead puts the origin ~54 frames
early -- it lands in the PCM/music sequence that precedes .loop -- and the blink
then appears to start at frame 54 when it actually starts one frame after .loop.
A sweep aimed at 50..63 on that mistaken alignment finds "all open" on both
sides and looks like agreement. It is not; it is sampling the long open window.

THE ONE-FRAME LAG, again. .titleScreenLoop runs DelayFrame BEFORE
DoTitleScreenFunction, so the buffer captured at iteration N was rendered before
that iteration's tile mutation. Port iteration N therefore shows the reference's
.loop-relative frame N-1. This is the same ordering fact the bounce check found;
it is a property of the code, not a fitted offset.

Capture first (each is a full boot, ~40 s):

    for n in $(seq 1 13); do
        TITLE_DUMP_LOOP=$n tools/pixelcheck.sh title -o /tmp/blink/l$n.bin
    done
    tools/check_title_blink.py /tmp/blink --trace /tmp/mgba_title.csv \\
        --open /tmp/title_eyes.bin --half /tmp/title_s2.bin --closed /tmp/title_s5.bin
"""

import argparse
import csv
import os
import sys

RENDER_W = 320
# The 8 canonical eye OAM records (Y, X) from TitleScreenPikachuEyesOAMData,
# converted to canvas boxes: screen = (OAM_Y - 16, OAM_X - 8), projected +(80,24).
EYE_OAM = [(0x60, 0x40), (0x60, 0x48), (0x68, 0x40), (0x68, 0x48),
           (0x60, 0x60), (0x60, 0x68), (0x68, 0x60), (0x68, 0x68)]
EYE_BOXES = [(ox - 8 + 80, oy - 16 + 24) for oy, ox in EYE_OAM]

# wTitleScreenScene dispatch -> the eye tiles that dispatch installs. The scene
# value OBSERVED after a frame is one AHEAD of the dispatch that ran, because
# .BlinkWait increments before anything can sample it.
DISPATCH_STATE = {
    0: "open",     # .Nop / steady state
    1: "half",     # .BlinkHalf
    2: "half", 3: "half",          # .BlinkWait holds
    4: "closed",   # .BlinkClosed
    5: "closed", 6: "closed",      # .BlinkWait holds
    7: "half",     # .BlinkHalf
    8: "half", 9: "half",          # .BlinkWait holds
    10: "open",    # .BlinkOpen
    11: "open",    # .GoBackToStart
}


def eye_pixels(buf):
    return bytes(
        buf[y * RENDER_W + x]
        for bx, by in EYE_BOXES
        for y in range(by, by + 8)
        for x in range(bx, bx + 8)
    )


def reference_states(csv_path):
    """Eye state per .loop-relative frame, from the golden trace."""
    rows = [(int(r["frame"]), int(r["scene"]), int(r["marker"]))
            for r in csv.DictReader(open(csv_path))]
    marked = [f for f, _, m in rows if m == 0x0F]
    if not marked:
        raise SystemExit("trace has no .loop marker ($0F in wTitleScreenScene+4) "
                         "— re-record with the current title_trace.lua")
    loop0 = min(marked)
    out = {}
    for f, scene, _ in rows:
        if f < loop0:
            continue
        # `scene` is the value AFTER the frame, so the dispatch that ran was
        # scene-1 (and scene 0 means .GoBackToStart wrapped it, i.e. open).
        ran = (scene - 1) if scene > 0 else 11
        out[f - loop0] = DISPATCH_STATE[ran]
    # The marker frame itself precedes any blink dispatch.
    out[0] = "open"
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dir", help="directory of lN.bin idle-loop captures")
    ap.add_argument("--trace", required=True, help="golden-ROM trace CSV")
    ap.add_argument("--open", required=True, dest="s_open")
    ap.add_argument("--half", required=True)
    ap.add_argument("--closed", required=True)
    args = ap.parse_args()

    refs = {}
    for name, path in (("open", args.s_open), ("half", args.half),
                       ("closed", args.closed)):
        with open(path, "rb") as fh:
            refs[name] = eye_pixels(fh.read())
    if len(set(refs.values())) != 3:
        raise SystemExit("the three reference eye states are not distinct — "
                         "captures are mislabelled or the harness dumped the "
                         "same frame three times")

    expected = reference_states(args.trace)

    frames = sorted(int(f[1:-4]) for f in os.listdir(args.dir)
                    if f.startswith("l") and f.endswith(".bin"))
    if not frames:
        raise SystemExit(f"no lN.bin captures in {args.dir}")

    print(f"{'iter':>4} {'ref frame':>9} {'expected':>9} {'measured':>9}  ok")
    good = bad = unknown = 0
    for n in frames:
        with open(os.path.join(args.dir, f"l{n}.bin"), "rb") as fh:
            got = eye_pixels(fh.read())
        names = [k for k, v in refs.items() if v == got]
        measured = names[0] if names else "UNKNOWN"
        rel = n - 1                      # the one-frame lag, see docstring
        want = expected.get(rel)
        if want is None:
            print(f"{n:4d} {rel:9d} {'--':>9} {measured:>9}  (past the trace)")
            continue
        hit = measured == want
        print(f"{n:4d} {rel:9d} {want:>9} {measured:>9}  {'yes' if hit else 'NO'}")
        if measured == "UNKNOWN":
            unknown += 1
        elif hit:
            good += 1
        else:
            bad += 1

    print(f"\nmatch={good} mismatch={bad} unclassifiable={unknown}")
    if bad or unknown:
        print("FAIL: the blink does not track the reference", file=sys.stderr)
        return 1
    if good == 0:
        print("FAIL: nothing was actually compared", file=sys.stderr)
        return 1
    # A run that never leaves "open" proves nothing: it is what a sweep aimed at
    # the wrong window looks like. Require the blink itself to be in evidence.
    seen = {refs and expected.get(n - 1) for n in frames}
    if not {"half", "closed"} <= seen:
        print("FAIL: the sampled range contains no blink — half and closed must "
              "both appear, or this is the wrong window", file=sys.stderr)
        return 1
    print("PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
