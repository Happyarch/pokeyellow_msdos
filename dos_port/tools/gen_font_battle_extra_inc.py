#!/usr/bin/env python3
"""Generate dos_port/assets/font_battle_extra_2bpp.inc from
gfx/font/font_battle_extra.png.

font_battle_extra.2bpp (pret: HpBarAndStatusGraphics) is an rgbgfx build
artifact (gitignored), so the DOS port embeds a committed NASM data copy
generated from the committed PNG source.

font_battle_extra.png is 120×16 (2-bit grayscale), containing 30 tiles (15×2):
  tiles $62–$7F — the HP-bar gauge segments ($62-$6c), the ":L" level tile
  ($6e), the narrow "HP"/"to" tiles, and the status-icon glyphs ($7d-$7e).
  Loaded over vChars2 tile $62 (clobbering the box-drawing tiles $79-$7E that
  LoadTextBoxTilePatterns supplies — restore them after).

Pixel convention: 0=darkest/black → GB color 3, 3=lightest/white → GB color 0.
GB 2bpp row encoding: two bytes per row, low bitplane then high bitplane.
Bit (7-col) of each byte corresponds to pixel column col (0=leftmost).

Requires Pillow: pip install Pillow
Run from the repo root: python3 dos_port/tools/gen_font_battle_extra_inc.py
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
SRC_PNG = ROOT / "gfx" / "font" / "font_battle_extra.png"
DST = ROOT / "dos_port" / "assets" / "font_battle_extra_2bpp.inc"

TILE_W, TILE_H = 8, 8
TILES_PER_ROW = 15
EXPECTED_TILES = 30    # 120 / 8 wide × 16 / 8 tall


def main():
    try:
        from PIL import Image
    except ImportError:
        sys.exit("Pillow required: pip install Pillow")

    img = Image.open(SRC_PNG).convert("L")
    w, h = img.size
    tiles_x = w // TILE_W
    tiles_y = h // TILE_H
    num_tiles = tiles_x * tiles_y
    if num_tiles != EXPECTED_TILES:
        sys.exit(f"expected {EXPECTED_TILES} tiles, got {num_tiles} from {w}×{h}")

    data = bytearray()
    for ty in range(tiles_y):
        for tx in range(TILES_PER_ROW):
            for row in range(TILE_H):
                low_byte = 0
                high_byte = 0
                for col in range(TILE_W):
                    L = img.getpixel((tx * TILE_W + col, ty * TILE_H + row))
                    # L=0 (black in PNG) → gb_color=3 (dark); L=255 → gb_color=0 (white)
                    gc = 3 - round(L / 85)
                    gc = max(0, min(3, gc))
                    bit = 0x80 >> col
                    if gc & 1:
                        low_byte |= bit
                    if gc & 2:
                        high_byte |= bit
                data.append(low_byte)
                data.append(high_byte)

    out = [
        "; font_battle_extra_2bpp.inc — generated from gfx/font/font_battle_extra.png",
        "; via dos_port/tools/gen_font_battle_extra_inc.py.  DO NOT EDIT BY HAND.",
        "; 30 tiles (chars $62–$7F), 2bpp GB format, 16 bytes per tile.",
        "; Loaded by LoadHpBarAndStatusTilePatterns to vChars2 tile $62 (EBP $9620).",
        "",
        "font_battle_extra_2bpp_data:",
    ]
    for i in range(0, len(data), 16):
        out.append("    db " + ", ".join(f"0x{b:02X}" for b in data[i:i + 16]))
    out += [
        "font_battle_extra_2bpp_data_end:",
        "FONT_BATTLE_EXTRA_2BPP_SIZE equ font_battle_extra_2bpp_data_end - font_battle_extra_2bpp_data",
        "",
    ]
    DST.parent.mkdir(parents=True, exist_ok=True)
    DST.write_text("\n".join(out) + "\n")
    print(f"wrote {DST} ({len(data)} bytes, {num_tiles} tiles)")


if __name__ == "__main__":
    main()
