#!/usr/bin/env python3
"""Generate dos_port/assets/ptile_2bpp.inc from gfx/font/P.1bpp (pret PTile).

PTile is the bold "P" of the status screen's "PP" label. pret loads it in
engine/pokemon/status_screen.asm:StatusScreen via a fourth CopyVideoDataDouble
to vChars2 tile $72 — it is NOT part of the battle LoadHudTilePatterns bundle
(engine/battle/core.asm), which loads only BattleHudTiles1/2/3.

It used to be emitted into assets/battle_hud_2bpp.inc alongside those HUD tiles.
That coupling was the obstruction that kept LoadHudTilePatterns out of its pret
mirror: the routine needs BATTLE_HUD_TILES*_SIZE at assembly time (you cannot do
arithmetic on an extern), so the HUD blob has to be %included by whichever file
defines the routine — and that would have dragged PTile, which belongs to the
status screen, into engine/battle/core.asm. Splitting the blob in two lets each
consumer %include only what pret says is its own.

Emits one label:
  ptile_2bpp   — 1 tile -> loaded at vChars2 tile $72

Run from anywhere: python3 dos_port/tools/generators/gen_ptile_inc.py
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent.parent
DST = ROOT / "dos_port" / "assets" / "ptile_2bpp.inc"
TILE_H = 8


def onebpp_to_2bpp_doubled(path):
    """Expand a raw .1bpp tile blob (8 bytes/tile) to 2bpp by writing each byte to
    both bitplanes (pret CopyVideoDataDouble / FarCopyDataDouble: color 0 or 3)."""
    raw = Path(path).read_bytes()
    if len(raw) % TILE_H:
        sys.exit(f"{path}: expected a multiple of {TILE_H} bytes (1bpp tiles)")
    data = bytearray()
    for b in raw:
        data.append(b)   # low bitplane
        data.append(b)   # high bitplane (doubled -> color 0/3)
    return data


def emit(out, label, data, comment):
    out.append(f"{label}:   {comment}")
    for i in range(0, len(data), 16):
        out.append("    db " + ", ".join(f"0x{b:02X}" for b in data[i:i + 16]))


def main():
    ptile = onebpp_to_2bpp_doubled(ROOT / "gfx/font/P.1bpp")

    out = [
        "; ptile_2bpp.inc — generated from gfx/font/P.1bpp",
        "; via dos_port/tools/generators/gen_ptile_inc.py.  DO NOT EDIT BY HAND.",
        "; pret PTile (1bpp) expanded 1bpp->2bpp (CopyVideoDataDouble).",
        "; The bold 'P' of the status screen's 'PP' label; StatusScreen loads it to",
        "; vChars2 $72. Not part of the battle LoadHudTilePatterns bundle.",
        "",
    ]
    emit(out, "ptile_2bpp", ptile, "; 1 tile -> vChars2 tile $72 (bold P for PP)")
    out.append("PTILE_2BPP_SIZE equ $ - ptile_2bpp")
    out.append("")

    DST.parent.mkdir(parents=True, exist_ok=True)
    DST.write_text("\n".join(out) + "\n")
    print(f"wrote {DST} (ptile {len(ptile)}B)")


if __name__ == "__main__":
    main()
