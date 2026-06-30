#!/usr/bin/env python3
"""Generate dos_port/assets/battle_hud_2bpp.inc from the three
gfx/battle/battle_hud_{1,2,3}.png (pret BattleHudTiles1/2/3).

These are the battle HUD "frame"/divider tiles — the underline + corner pieces the
HP bar and the party pokeballs sit on. pret stores them 1bpp and expands 1bpp->2bpp
at load time via FarCopyDataDouble (both bitplanes = the 1bpp byte, so each pixel is
GB color 0 or 3). LoadHudTilePatterns (engine/battle/core.asm) loads:
  BattleHudTiles1        -> vChars2 tile $6d   (3 tiles: $6d-$6f)
  BattleHudTiles2 + 3    -> vChars2 tile $73   (6 tiles: $73-$78)
overwriting the font_extra placeholders ("ID No.") that otherwise sit at $73/$74.

Emits two labels (matching that split):
  battle_hud_tiles1_2bpp   — 3 tiles (battle_hud_1)        -> loaded at $6d
  battle_hud_tiles23_2bpp  — 6 tiles (battle_hud_2 + _3)   -> loaded at $73

Pixel convention (same as gen_font_battle_extra_inc.py): PNG dark pixel -> on.
Requires Pillow.  Run from the repo root: python3 dos_port/tools/gen_battle_hud_inc.py
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
DST = ROOT / "dos_port" / "assets" / "battle_hud_2bpp.inc"
TILE_W = TILE_H = 8


def png_to_2bpp_doubled(path):
    from PIL import Image
    img = Image.open(path).convert("L")
    w, h = img.size
    if h != TILE_H or w % TILE_W:
        sys.exit(f"{path}: expected an 8px-tall row of tiles, got {w}x{h}")
    data = bytearray()
    for tx in range(w // TILE_W):
        for row in range(TILE_H):
            byte = 0
            for col in range(TILE_W):
                L = img.getpixel((tx * TILE_W + col, row))
                if L < 128:                  # dark pixel -> on
                    byte |= 0x80 >> col
            data.append(byte)                # low bitplane
            data.append(byte)                # high bitplane (doubled -> color 0/3)
    return data


def emit(out, label, data, comment):
    out.append(f"{label}:   {comment}")
    for i in range(0, len(data), 16):
        out.append("    db " + ", ".join(f"0x{b:02X}" for b in data[i:i + 16]))


def main():
    try:
        import PIL  # noqa: F401
    except ImportError:
        sys.exit("Pillow required: pip install Pillow")
    t1 = png_to_2bpp_doubled(ROOT / "gfx/battle/battle_hud_1.png")
    t2 = png_to_2bpp_doubled(ROOT / "gfx/battle/battle_hud_2.png")
    t3 = png_to_2bpp_doubled(ROOT / "gfx/battle/battle_hud_3.png")
    t23 = t2 + t3

    out = [
        "; battle_hud_2bpp.inc — generated from gfx/battle/battle_hud_{1,2,3}.png",
        "; via dos_port/tools/gen_battle_hud_inc.py.  DO NOT EDIT BY HAND.",
        "; pret BattleHudTiles1/2/3 (1bpp) expanded 1bpp->2bpp (FarCopyDataDouble).",
        "; The battle HUD frame/divider tiles; LoadHudTilePatterns puts tiles1 at",
        "; vChars2 $6d and tiles2+3 at $73, over the font_extra 'ID No.' placeholders.",
        "",
    ]
    emit(out, "battle_hud_tiles1_2bpp", t1, "; 3 tiles -> vChars2 tile $6d")
    out.append("BATTLE_HUD_TILES1_SIZE equ $ - battle_hud_tiles1_2bpp")
    out.append("")
    emit(out, "battle_hud_tiles23_2bpp", t23, "; 6 tiles -> vChars2 tile $73")
    out.append("BATTLE_HUD_TILES23_SIZE equ $ - battle_hud_tiles23_2bpp")
    out.append("")

    DST.parent.mkdir(parents=True, exist_ok=True)
    DST.write_text("\n".join(out) + "\n")
    print(f"wrote {DST} (tiles1 {len(t1)}B, tiles23 {len(t23)}B)")


if __name__ == "__main__":
    main()
