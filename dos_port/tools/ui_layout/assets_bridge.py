"""assets_bridge.py — decode the real font/border tiles for pixel-accurate previews.

Sources (committed PNGs, same ones the gen_font*_inc.py generators embed):
  gfx/font/font.png        128 tiles, 1bpp  -> char codes $80-$FF (code - $80)
  gfx/font/font_extra.png   32 tiles, 2bpp  -> char codes $60-$7F (code - $60)
                            (includes box-drawing tiles $79-$7E and space $7F)

Tiles are returned as 8x8 lists of GB color indices 0..3 (0 = lightest).
Palette matches tools/render_frame.py's DMG debug ramp.
"""
from __future__ import annotations

from functools import lru_cache
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent.parent.parent  # repo root
FONT_PNG = ROOT / "gfx" / "font" / "font.png"
FONT_EXTRA_PNG = ROOT / "gfx" / "font" / "font_extra.png"

TILE = 8
TILES_PER_ROW = 16

# DMG green ramp — keep identical to tools/render_frame.py PAL[0..3].
DMG_PAL = [(224, 248, 208), (136, 192, 112), (52, 104, 86), (8, 24, 32)]

BOX_TL, BOX_H, BOX_TR = 0x79, 0x7A, 0x7B
BOX_V, BOX_BL, BOX_BR = 0x7C, 0x7D, 0x7E
TILE_SPC = 0x7F


def _slice(img: Image.Image, index: int) -> list[list[int]]:
    tx, ty = index % TILES_PER_ROW, index // TILES_PER_ROW
    tile = []
    for y in range(TILE):
        row = []
        for x in range(TILE):
            lum = img.getpixel((tx * TILE + x, ty * TILE + y))
            # grayscale -> GB color: darkest = 3, lightest = 0
            row.append(3 - min(3, round(lum / 85)))
        tile.append(row)
    return tile


@lru_cache(maxsize=None)
def _font() -> Image.Image:
    return Image.open(FONT_PNG).convert("L")


@lru_cache(maxsize=None)
def _font_extra() -> Image.Image:
    return Image.open(FONT_EXTRA_PNG).convert("L")


@lru_cache(maxsize=512)
def tile_for_code(code: int) -> list[list[int]]:
    """8x8 GB-color tile for a charmap code; blank (color 0) if unknown."""
    if 0x80 <= code <= 0xFF:
        return _slice(_font(), code - 0x80)
    if 0x60 <= code <= 0x7F:
        return _slice(_font_extra(), code - 0x60)
    return [[0] * TILE for _ in range(TILE)]


def encode_label(s: str) -> list[int]:
    """Preview-only text encoding via tools/gb_text.py (single-char charmap).

    Falls back to space tiles if the charmap isn't generated yet — the editor
    must render without a full asset build.
    """
    try:
        import sys
        sys.path.insert(0, str(ROOT / "dos_port" / "tools"))
        import gb_text
        return gb_text.encode(s)
    except Exception:
        return [TILE_SPC] * len(s)
