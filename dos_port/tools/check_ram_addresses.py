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


# --- the prefix-sum WRAM expansion -----------------------------------------
# The port is a Game Boy with more WRAM (docs/current_plan_wram_expansion.md), so
# the invariant this gate enforces is NOT `port == pret` any more -- it is
# `port == pret + sum(growths strictly below it)`. Addresses at or above GB_OAM
# never shift, which is what keeps every OAM/IO/HRAM symbol at its pret address.
# The growth table (tools/wram_growth.json) is the single source, shared with
# gen_pret_ram.py and check_ram_straddle.py.
_GROWTH = [(int(g["pret"], 16), g["pret_size"], g["port_size"] - g["pret_size"])
           for g in json.loads(
               (ROOT / "tools" / "wram_growth.json").read_text())["growths"]]
_GB_OAM = 0xFE00


def _expected(pret_addr):
    """Where a pret symbol should live in the port."""
    if pret_addr >= _GB_OAM:
        return pret_addr
    # A growth applies only at or ABOVE the END of the grown region. `p < addr`
    # tears the region apart: a symbol INSIDE it accrues the region's own growth.
    return pret_addr + sum(g for p, sz, g in _GROWTH if p + sz <= pret_addr)



# ---------------------------------------------------------------------------
# GAP SEALED 2026-08-19: file-local ALIASES of pret addresses.
#
# The scan above only sees names matching pret's own [wh]Foo convention, so a
# port-invented UPPERCASE alias of a pret address -- W_PLAY_TIME_HOURS,
# W_HIDDEN_EVENT_X, W_DISABLE_VBLANK_WY_UPDATE, W_COORD_INDEX, W_D472 -- was
# completely ungated. Sixteen of them silently held pre-expansion addresses
# through the WRAM shift and were found BY HAND, which is exactly the failure
# this file exists to prevent.
#
# The pairing rule is the alias's own trailing comment: these are written as
#     W_PLAY_TIME_HOURS  equ 0xE80E   ; wPlayTimeHours
# so the first pret RAM/HRAM symbol named in the comment IS the alias target.
# That is a convention, not a guarantee, so a site that means something else
# opts out with `; no-ram-alias-check`.
_ALIAS_RE = re.compile(r"^\s*([A-Za-z_]\w*)\s+equ\s+0x([0-9A-Fa-f]{4})\b(.*)$")
_ALIAS_SYM_RE = re.compile(r"\b([wh][A-Za-z0-9_]{3,})\b")


def alias_findings(sym):
    """[(file, line, alias, value, target, expected)] for stale pret aliases."""
    out = []
    for f in sorted((ROOT / "src").rglob("*.asm")):
        for n, line in enumerate(f.read_text(errors="ignore").splitlines(), 1):
            m = _ALIAS_RE.match(line)
            if not m or "no-ram-alias-check" in line:
                continue
            val = int(m.group(2), 16)
            if not (0xC000 <= val <= 0xFFFF):
                continue
            for cand in _ALIAS_SYM_RE.findall(m.group(3)):
                if cand in sym:
                    want = _expected(sym[cand])
                    if val != want:
                        out.append((f.relative_to(ROOT), n, m.group(1),
                                    val, cand, want))
                    break
    return out


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
            if addr != _expected(sym[label]):
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
    aliases = alias_findings(sym)
    for f, n, alias, val, target, want in aliases:
        print(f"  STALE ALIAS  {f}:{n}  {alias} = 0x{val:04X}, but {target} "
              f"(pret 0x{sym[target]:04X}) is at 0x{want:04X} in the port")
    if aliases:
        fail = True
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
