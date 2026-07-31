#!/usr/bin/env python3
"""Decode PERF.BIN — the DEBUG_PERF per-stage frame profile.

The port (src/debug/perf.asm) latches PIT channel 0 around each stage of
DelayFrame and accumulates elapsed PIT counts. This converts those counts to
milliseconds and prints a per-stage budget, so a stage's share of the frame is
directly comparable across DOSBox-X cycle settings and real hardware.

Usage:
    tools/read_perf.py [PERF.BIN] [--baseline OTHER.BIN]

With --baseline, prints the delta against an earlier capture (the before/after
check every stage of docs/plans/compositor_perf.md must pass).
"""

import argparse
import math
import struct
import sys
from pathlib import Path

PIT_HZ = 1193181.666

# Must match the PERF_* stage ids in src/home/vblank.asm.
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
    if version not in (1, 2, 3):
        sys.exit(f"{path}: unsupported PERF.BIN version {version}")
    acc = struct.unpack_from(f"<{stages}I", data, 0x14)
    mx = struct.unpack_from(f"<{stages}I", data, 0x14 + stages * 4)
    # v2 appends the per-frame WORK series after the accumulators. It is what
    # makes median / p95 / deadline-miss COUNT derivable at all: sums and
    # maxima cannot express a distribution, and two opposing stage regressions
    # cancel in a mean.
    series = []
    events = []
    if version >= 2:
        off = 0x14 + stages * 8
        (count,) = struct.unpack_from("<I", data, off)
        series = list(struct.unpack_from(f"<{count}I", data, off + 4))
        off += 4 + count * 4
        # v3 appends one-shot EVENT records (the stage-7 save-commit
        # sub-spans): event count, then count x EVT_SPANS dwords.
        if version >= 3:
            (ecount,) = struct.unpack_from("<I", data, off)
            flat = struct.unpack_from(f"<{ecount * len(EVT_SPAN_NAMES)}I",
                                      data, off + 4)
            n = len(EVT_SPAN_NAMES)
            events = [flat[i * n:(i + 1) * n] for i in range(ecount)]
    return {"frames": frames, "divisor": divisor, "acc": acc, "max": mx,
            "stages": stages, "version": version, "series": series,
            "events": events, "path": str(path)}


# Must match PERF_EVT_SPANS + the lap sites in src/engine/menus/save.asm and
# src/save/dsv_io.asm (sram plan stage 7 save-commit sub-spans).
EVT_SPAN_NAMES = [
    "(a) WRAM→SRAM slices+cksums",
    "(b) gather + image checksum",
    "(c) AH=3Ch create",
    "(d) AH=40h write + close",
]


def event_report(p):
    """Per-sub-span median/max table over the v3 event records."""
    events = p.get("events") or []
    if not events:
        return
    print()
    print(f"save-commit events ({len(events)} recorded)")
    header = (f"{'sub-span':<32}{'median ms':>12}{'max ms':>10}"
              f"{'% of total':>12}")
    print("-" * len(header))
    n = len(EVT_SPAN_NAMES)
    med_total = 0.0
    meds = []
    for i in range(n):
        vals = sorted(ms(e[i]) for e in events)
        meds.append((pct(vals, 0.50), vals[-1]))
        med_total += meds[-1][0]
    for i, name in enumerate(EVT_SPAN_NAMES):
        med, mx = meds[i]
        share = 100.0 * med / med_total if med_total else 0.0
        print(f"{name:<32}{med:>12.3f}{mx:>10.3f}{share:>11.1f}%")
    print("-" * len(header))
    print(f"{'TOTAL (median)':<32}{med_total:>12.3f}")


def pct(sorted_vals, q):
    """Nearest-rank percentile (q in 0..1) over a non-empty sorted list."""
    k = max(1, math.ceil(q * len(sorted_vals)))
    return sorted_vals[k - 1]


def work_stats(p, start=0):
    """Distribution of per-frame WORK, in ms, over frames [start:].

    `start` selects the steady-state interval. It exists because a scenario's
    own navigation transient (menu opens, first tile decodes) produces real
    budget overruns that are not steady-state behavior: in the A1 baseline,
    party_menu misses at frames 62-104 while frames 150+ are miss-free. Compare
    like-for-like intervals across captures, and state the interval alongside
    any zero-miss claim. None if the capture is v1.
    """
    if not p["series"]:
        return None
    budget = ms(p["divisor"])
    window = p["series"][start:]
    if not window:
        return None
    vals = sorted(ms(v) for v in window)
    n = len(vals)
    return {
        "n": n,
        "budget": budget,
        "median": pct(vals, 0.50),
        "p95": pct(vals, 0.95),
        "max": vals[-1],
        "misses": sum(1 for v in vals if v > budget),
    }


def ms(counts):
    return counts * 1000.0 / PIT_HZ


def report(p, base=None, start=0):
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
        print("\n*** OVERRUN: mean work exceeds the frame budget — music will drag.")

    st = work_stats(p, start)
    if st is None:
        print("\nper-frame WORK distribution: unavailable (PERF.BIN v1 — "
              "recapture with a DEBUG_PERF build for median/p95/misses)")
        return
    bst = work_stats(base, start) if base else None
    print()
    interval = f"frames {start}..{start + st['n'] - 1}" if start else f"{st['n']} frames"
    print(f"per-frame WORK distribution ({interval}, "
          f"budget {st['budget']:.3f} ms)")
    rows = [("median", "median"), ("p95", "p95"), ("max", "max")]
    width = 32 + 10 + 10 + 10
    print("-" * width)
    for label, key in rows:
        line = f"{label:<32}{st[key]:>10.3f}{100.0 * st[key] / st['budget']:>9.1f}%"
        if bst:
            delta = st[key] - bst[key]
            rel = (100.0 * delta / bst[key]) if bst[key] else 0.0
            line += f"{delta:>+10.3f}{rel:>+9.1f}%"
        print(line)
    miss_line = f"{'deadline misses':<32}{st['misses']:>10d}"
    if bst:
        miss_line += f"{'':>10}{st['misses'] - bst['misses']:>+10d}"
    print(miss_line)
    print("-" * width)
    if st["misses"]:
        print(f"*** {st['misses']} frame(s) exceeded the budget.")
    event_report(p)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("perf", nargs="?", default="PERF.BIN")
    ap.add_argument("--baseline", help="earlier PERF.BIN to diff against")
    ap.add_argument("--from", dest="start", type=int, default=0, metavar="N",
                    help="steady-state interval: ignore the first N frames of "
                         "the per-frame series (skips a scenario's navigation "
                         "transient). Use the same N on both sides of a compare.")
    args = ap.parse_args()
    base = load(args.baseline) if args.baseline else None
    report(load(args.perf), base, args.start)


if __name__ == "__main__":
    main()
