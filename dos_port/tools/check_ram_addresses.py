#!/usr/bin/env python3
"""check_ram_addresses.py — every pret RAM/HRAM label must sit where rgblink put it.

WHY. A NASM `equ` is FILE-LOCAL. Two files could declare the same pret label at
DIFFERENT addresses and the build would still assemble, link, and pass every gate,
because nothing compared declarations to pret. Six wrong addresses shipped that way:

  hSpriteScreenYCoord/XCoord, hSpriteMapYCoord/XCoord  parked inside pret's
      hDMARoutine, breaking the GetSpritePosition1/SetSpritePosition1 handoff with
      four map scripts                                              (eb09fb18d)
  wBoughtOrSoldItemInMart  on top of wAILayer2Encouragement, a battle-AI byte
  wOakWalkedToPlayer       one byte past its pret UNION, landing on
                           wTilePlayerStandingOn and corrupting it

All six were found by diffing declarations against pokeyellow.sym. This makes that
diff a gate instead of a lucky afternoon.

RATCHET, NOT A WALL. The port DELIBERATELY relocates buffers that do not fit the GB
layout — wOverworldMap grown for MAP_BORDER=7, wLYOverrides and the wAnimatedObject*
block moved into free echo RAM, HRAM scratch assigned to free bytes, `flat-adapted:
4 bytes` pointer widenings. Those live in the baseline with the address they use.
The gate fails on a NEW divergence, or on a baselined symbol whose address MOVES.

Baseline entries are reviewed port relocations. Do NOT add one to make your own
change pass: if a label you touched is suddenly divergent, you moved it by mistake
— that is the bug this catches.

Usage:  tools/check_ram_addresses.py [--update-baseline]
"""
import json, re, pathlib, sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
PRET = ROOT.parent
BASELINE = ROOT / "tools" / "ram_address_baseline.json"

def pret_symbols():
    sym = PRET / "pokeyellow.sym"
    if not sym.exists():
        return None
    out = {}
    for line in sym.read_text(errors="ignore").splitlines():
        m = re.match(r"^00:([0-9a-fA-F]{4})\s+(\S+)\s*$", line)
        if m and re.match(r"^[wh][A-Z]", m.group(2)):
            out.setdefault(m.group(2), int(m.group(1), 16))
    return out

def declarations():
    """label -> {addr: [sites]}, over every hand-owned declaration in the port.
    assets/pret_ram.inc is generated FROM pokeyellow.sym, so it is skipped."""
    decls = {}
    files = [ROOT / "include" / "gb_memmap.inc"] + sorted((ROOT / "src").rglob("*.asm"))
    # both spellings: constants are declared %define so they emit no COFF symbol,
    # but hand-written entries may still use equ.
    pat = re.compile(
        r"^\s*(?:%define\s+([wh][A-Za-z0-9_]+)\s+|([wh][A-Za-z0-9_]+)\s+equ\s+)"
        r"(0[xX][0-9A-Fa-f]+|\$[0-9A-Fa-f]+)\s*(?:;.*)?$")
    for f in files:
        for i, line in enumerate(f.read_text(errors="ignore").splitlines(), 1):
            m = pat.match(line)
            if not m:
                continue
            addr = int(m.group(3).replace("$", "0x"), 0)
            decls.setdefault(m.group(1) or m.group(2), {}).setdefault(addr, []).append(
                f"{f.relative_to(ROOT)}:{i}")
    return decls

def main():
    sym = pret_symbols()
    if sym is None:
        print("check_ram_addresses: SKIP — pokeyellow.sym not present "
              "(run `make` at the repo root to build it)")
        return 0
    decls = decls_ = declarations()
    baseline = json.loads(BASELINE.read_text()) if BASELINE.exists() else {}

    conflicts, divergent = [], {}
    for label, addrs in sorted(decls.items()):
        # (1) one label, two addresses, inside the port itself — always an error
        if len(addrs) > 1:
            conflicts.append((label, addrs))
        if label not in sym:
            continue
        for addr in addrs:
            if addr != sym[label]:
                divergent[label] = addr

    if "--update-baseline" in sys.argv:
        BASELINE.write_text(json.dumps(
            {k: f"0x{v:04X}" for k, v in sorted(divergent.items())}, indent=2) + "\n")
        print(f"check_ram_addresses: baseline written with {len(divergent)} "
              f"reviewed port relocations")
        return 0

    base = {k: int(v, 16) for k, v in baseline.items()}
    new    = {k: v for k, v in divergent.items() if k not in base}
    moved  = {k: (v, base[k]) for k, v in divergent.items() if k in base and base[k] != v}
    healed = [k for k in base if k not in divergent]

    fail = False
    for label, addrs in conflicts:
        fail = True
        print(f"  CONFLICT  {label} declared at "
              + ", ".join(f"{hex(a)} ({addrs[a][0]})" for a in sorted(addrs)))
    for label, addr in sorted(new.items()):
        fail = True
        print(f"  NEW DIVERGENCE  {label} = {hex(addr)} but pret has "
              f"{hex(sym[label])}  ({decls[label][addr][0]})")
    for label, (addr, was) in sorted(moved.items()):
        fail = True
        print(f"  MOVED  {label} was baselined at {hex(was)}, now {hex(addr)} "
              f"(pret {hex(sym[label])})")
    if healed:
        print(f"  note: {len(healed)} baselined relocation(s) now match pret "
              f"({', '.join(sorted(healed)[:5])}...) — re-run with "
              f"--update-baseline to shrink the baseline")

    total = len(decls)
    if fail:
        print(f"check_ram_addresses: FAIL — {len(conflicts)} conflict(s), "
              f"{len(new)} new divergence(s), {len(moved)} moved")
        return 1
    print(f"check_ram_addresses: PASS — {total} declared pret RAM/HRAM labels, "
          f"0 conflicts, {len(base)} reviewed port relocations at baseline")
    return 0

if __name__ == "__main__":
    sys.exit(main())
