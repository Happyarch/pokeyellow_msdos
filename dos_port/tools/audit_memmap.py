#!/usr/bin/env python3
"""Blast-radius audit of the emulated GB address space.

Motivation (2026-07-10): growing MAP_BORDER 6->7 and repacking the ROM window
moved/greW several port-invented regions, and each collision was found one
user-visible crash at a time (wTileMapBackup2 clobber, header blob over the
indoor .blk slot AND over VRAM). This tool makes that class of bug a check:

  1. Parse every `NAME equ 0x....` in include/gb_memmap.inc and
     assets/rom_window.inc (GB-space addresses only).
  2. Attach an EXTENT to every region whose size is machine-knowable:
     - `<NAME>_SIZE` / `<NAME>_SLOT_SIZE` equ pairs (incl. the generated
       per-map .blk sizes in rom_window.inc),
     - a curated table for port-invented buffers whose size lives only in
       comments or code (kept small and load-bearing; grep the symbol before
       trusting it blindly).
  3. Report:
     - EXTENT vs EXTENT overlaps,
     - any point symbol that lands strictly INSIDE a foreign extent,
     - ROM-window blob end vs VRAM ($8000).

Aliasing is legal in pret WRAM (unions like hDividend/hQuotient are original
game design), so checks are limited to PORT-INVENTED space where aliasing is
never intentional: the ROM window ($0100-$7FFF), the echo-RAM custom layout
($E000-$FDFF), and the curated WRAM scratch buffers. A finding therefore means
"someone moved/grew a region without re-checking its neighbours".

Known-legal aliases go in ALIASES; add a comment saying why.

Usage:  tools/audit_memmap.py           (from dos_port/)
Exit:   0 clean, 1 findings.
"""
import re
import sys
from pathlib import Path

DOS_PORT = Path(__file__).resolve().parent.parent
INC_FILES = [
    DOS_PORT / "include" / "gb_memmap.inc",
    DOS_PORT / "assets" / "rom_window.inc",
]

EQU_RE = re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s+equ\s+0x([0-9A-Fa-f]+)\s*(?:;.*)?$")

# ---------------------------------------------------------------------------
# Curated extents: port-invented buffers whose size is not an equ.
# name -> size in bytes. KEEP THIS SHORT; prefer teaching the inc a _SIZE equ.
# ---------------------------------------------------------------------------
CURATED_SIZES = {
    "W_SURROUNDING_TILES": 48 * 36,   # 1728 B; DrawTileBlock's decode surface
    "W_TILEMAP_BACKUP2":   1000,      # wTileMap copy (40x25)
    "NPC_DIALOG_BUF":      256,       # ShowTextStream bounds copies to <256 B
    "GB_VRAM0":            0x2000,    # $8000-$9FFF hardware VRAM
    "GB_OAM":              160,
}

# Symbols that legally share/alias an extent (why matters — keep the comments).
ALIASES = {
    "W_TILEMAP_BACKUP",        # == W_SURROUNDING_TILES by design (pret union)
    "GB_ECHO",                 # region marker for $E000, not a buffer
    "GB_VCHARS0", "GB_VFONT", "GB_VCHARS2",      # VRAM sub-regions
    "GB_TILEMAP0", "GB_TILEMAP1",                # VRAM sub-regions
    "OW_MAP_GBADDR",           # legacy alias of OW_PALLET_BLK_GBADDR
}

# Region markers: address-space landmarks, not buffers — never treated as
# points *inside* another extent, and never given extents themselves.
MARKERS = {"GB_WRAM0", "GB_ECHO", "GB_IO", "GB_HRAM", "GB_VRAM0"}


def parse_symbols():
    syms = {}
    for f in INC_FILES:
        if not f.exists():
            sys.exit(f"missing {f} — run `make assets` first")
        for line in f.read_text().splitlines():
            m = EQU_RE.match(line)
            if m:
                name, val = m.group(1), int(m.group(2), 16)
                if val <= 0xFFFF:
                    syms.setdefault(name, val)   # first def wins (guarded incs)
    return syms


def build_extents(syms):
    """[(name, start, end_exclusive)] for every region with a knowable size."""
    extents = []
    for name, addr in syms.items():
        if name.endswith("_SIZE") or name in MARKERS:
            continue
        size = None
        for suffix in ("_SIZE", "_SLOT_SIZE"):
            s = syms.get(name.rstrip() + suffix) or syms.get(
                name.replace("_GBADDR", "") + suffix)
            if s:
                size = s
                break
        # generated pattern: FOO_GBADDR + FOO_GBADDR_SIZE
        if size is None:
            size = syms.get(name + "_SIZE")
        if size is None:
            size = CURATED_SIZES.get(name)
        if size:
            extents.append((name, addr, addr + size))
    return sorted(extents, key=lambda e: e[1])


def main():
    syms = parse_symbols()
    extents = build_extents(syms)
    findings = []

    # 1. extent vs extent
    for i, (n1, s1, e1) in enumerate(extents):
        for n2, s2, e2 in extents[i + 1:]:
            if s2 < e1 and s1 < e2 and n2 not in ALIASES and n1 not in ALIASES:
                findings.append(
                    f"OVERLAP: {n1} [{s1:#06x},{e1:#06x}) and {n2} [{s2:#06x},{e2:#06x})")

    # 2. point symbol inside a foreign extent — only in port-invented space:
    #    ROM window and echo RAM. pret WRAM ($C000-$DFFF) unions are legal.
    def port_invented(a):
        return 0x0100 <= a < 0x8000 or 0xE000 <= a < 0xFE00

    ext_names = {n for n, _, _ in extents}
    for name, addr in sorted(syms.items(), key=lambda kv: kv[1]):
        if (name.endswith("_SIZE") or name in ALIASES or name in MARKERS
                or name in ext_names or not port_invented(addr)):
            continue
        for n, s, e in extents:
            if s < addr < e:
                findings.append(
                    f"INSIDE: {name} ({addr:#06x}) lies inside {n} [{s:#06x},{e:#06x})")

    # 3. ROM window blob end vs VRAM
    blob_end = syms.get("ROM_WINDOW_BLOB_END")
    if blob_end is None:
        findings.append("MISSING: ROM_WINDOW_BLOB_END not in rom_window.inc "
                        "(regenerate assets with the size-emitting generator)")
    elif blob_end > 0x8000:
        findings.append(f"VRAM OVERRUN: ROM window blob ends {blob_end:#06x} > 0x8000")

    print(f"{len(syms)} symbols, {len(extents)} sized regions")
    if findings:
        print(f"\n{len(findings)} finding(s):")
        for f in findings:
            print(f"  {f}")
        return 1
    print("clean: no overlaps, no strays inside port-invented extents")
    return 0


if __name__ == "__main__":
    sys.exit(main())
