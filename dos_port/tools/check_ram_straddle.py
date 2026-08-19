#!/usr/bin/env python3
"""Prove no symbol-difference expression spans a WRAM growth point.

The port is a Game Boy with more WRAM: a grown buffer keeps its pret address and
everything above it shifts up (tools/wram_growth.json,
docs/current_plan_wram_expansion.md). A UNIFORM shift is invisible to pret's own
code, because pret measures with symbol arithmetic -- `wMainDataEnd -
wMainDataStart`, `wPartyMon2 - wPartyMon1` -- and both operands move together.

What breaks is a growth landing BETWEEN the two operands. Then the difference
silently changes value, and pret's routine copies/clears the wrong number of
bytes. That is not hypothetical: `wLYOverridesBufferEnd - wLYOverrides` is 0x200
in pret (adjacent buffers) and became 0x5A0 in the port (relocated apart), which
zeroed 928 bytes of unrelated state on every surf-minigame init for months
(fixed b5b4efbae). This gate is that bug's permanent form.

TWO CLASSES OF FINDING
  * STRADDLE -- a growth point lies strictly inside the span. The difference
    changes; the code that uses it is now wrong. Always a failure.
  * SAVE-SPAN -- a growth point lies inside `wMainDataStart..wMainDataEnd`,
    the block save.asm copies to SRAM. That changes the .dsv payload layout. It
    is CONVERTIBLE (tools/saveconv.py already does .sav<->.dsv) but it must be a
    decision someone makes, not a discovery someone has later.

Usage:  tools/check_ram_straddle.py [--verbose]
Exit:   0 clean, 1 findings, 2 could not run.
"""
import json
import re
import sys
from pathlib import Path

DOS_PORT = Path(__file__).resolve().parent.parent
PRET = DOS_PORT.parent
SYM = PRET / "pokeyellow.sym"
GROWTH_JSON = DOS_PORT / "tools" / "wram_growth.json"

SYM_RE = re.compile(r"^([0-9A-Fa-f]{2}):([0-9A-Fa-f]{4})\s+(\S+)\s*$")
# `wFooEnd - wFoo`, `hX - hY`. Deliberately narrow: pret's RAM naming convention.
DIFF_RE = re.compile(r"\b([wh][A-Za-z0-9_]{3,})\s*-\s*([wh][A-Za-z0-9_]{3,})\b")


def pret_symbols():
    syms = {}
    for line in SYM.read_text(errors="ignore").splitlines():
        m = SYM_RE.match(line.split(";")[0].strip())
        if m and m.group(1) == "00" and int(m.group(2), 16) >= 0xC000:
            syms.setdefault(m.group(3), int(m.group(2), 16))
    return syms


def growth_points():
    g = json.loads(GROWTH_JSON.read_text())["growths"]
    return {int(e["pret"], 16): e["port_size"] - e["pret_size"] for e in g}


def differences():
    """(file, line, a, b) for every symbol-difference expression in src/."""
    out = []
    for p in sorted((DOS_PORT / "src").rglob("*.asm")):
        # debug/ dumps the map by construction and is not shipped logic
        if p.relative_to(DOS_PORT / "src").parts[0] == "debug":
            continue
        for i, line in enumerate(p.read_text(errors="ignore").splitlines(), 1):
            if line.lstrip().startswith(";"):
                continue
            for a, b in DIFF_RE.findall(line):
                out.append((p.relative_to(DOS_PORT), i, a, b))
    return out


def main():
    if not SYM.exists():
        print(f"check_ram_straddle: {SYM} not found — run `make` at the repo root "
              f"first (rgblink writes it).", file=sys.stderr)
        return 2

    pret = pret_symbols()
    growth = growth_points()
    diffs = differences()

    save_lo = pret.get("wMainDataStart")
    save_hi = pret.get("wMainDataEnd")

    straddles, evaluated, unevaluable = [], 0, 0
    for f, i, a, b in diffs:
        if a not in pret or b not in pret:
            unevaluable += 1
            continue
        evaluated += 1
        lo, hi = sorted((pret[a], pret[b]))
        hit = [g for g in growth if lo <= g < hi]
        if hit:
            straddles.append((f, i, a, b, lo, hi, hit))

    save_span = []
    if save_lo is not None and save_hi is not None:
        save_span = [g for g in growth if save_lo <= g < save_hi]

    for f, i, a, b, lo, hi, hit in straddles:
        print(f"  STRADDLE {f}:{i}  {a} - {b}  spans 0x{lo:04X}-0x{hi:04X}, "
              f"crosses " + ", ".join(f"0x{g:04X}(+{growth[g]})" for g in hit))
    for g in save_span:
        print(f"  SAVE-SPAN growth 0x{g:04X}(+{growth[g]}) lies inside "
              f"wMainDataStart..wMainDataEnd — this CHANGES the .dsv payload "
              f"layout. Convertible via saveconv.py, but it must be a decision.")

    if straddles or save_span:
        print(f"check_ram_straddle: {len(straddles)} straddle(s), "
              f"{len(save_span)} save-span growth(s)")
        return 1

    if "--verbose" in sys.argv:
        print(f"check_ram_straddle: {len(growth)} growth points, "
              f"{evaluated} both-pret differences evaluated, "
              f"{unevaluable} unevaluable (a port-only name)")
        below = sum(1 for _, _, a, b in diffs
                    if a in pret and b in pret
                    and min(pret[a], pret[b]) < max(growth))
        print(f"  {below} of the evaluated spans START inside the growth zone, "
              f"so the zero is not vacuous")
    print("check_ram_straddle: clean — no difference expression spans a growth "
          "point, and no growth lies in the saved WRAM block")
    return 0


if __name__ == "__main__":
    sys.exit(main())
