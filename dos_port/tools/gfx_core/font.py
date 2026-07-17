"""font.py — the real charmap font/border tiles for pixel-accurate previews.

Sources (committed PNGs, same ones the gen_font*_inc.py generators embed):
  gfx/font/font.png        128 tiles, 1bpp  -> char codes $80-$FF (code - $80)
  gfx/font/font_extra.png   32 tiles, 2bpp  -> char codes $60-$7F (code - $60)
                            (includes box-drawing tiles $79-$7E and space $7F)
"""
from __future__ import annotations

from functools import lru_cache

from PIL import Image

from .tiles import ROOT, TILE, Tile, blank_tile, slice_png_tile

FONT_PNG = ROOT / "gfx" / "font" / "font.png"
FONT_EXTRA_PNG = ROOT / "gfx" / "font" / "font_extra.png"

BOX_TL, BOX_H, BOX_TR = 0x79, 0x7A, 0x7B
BOX_V, BOX_BL, BOX_BR = 0x7C, 0x7D, 0x7E
TILE_SPC = 0x7F

# HP-gauge tiles (battle previews): left cap ":", partial fills, "HP", end cap.
HPB_LEFT, HPB_EMPTY, HPB_FULL = 0x62, 0x63, 0x6B
HPB_END, HPB_HP = 0x6C, 0x71


@lru_cache(maxsize=None)
def _font() -> Image.Image:
    return Image.open(FONT_PNG).convert("L")


@lru_cache(maxsize=None)
def _font_extra() -> Image.Image:
    return Image.open(FONT_EXTRA_PNG).convert("L")


@lru_cache(maxsize=512)
def tile_for_code(code: int) -> Tile:
    """8x8 GB-color tile for a charmap code; blank (color 0) if unknown."""
    if 0x80 <= code <= 0xFF:
        return slice_png_tile(_font(), code - 0x80)
    if 0x60 <= code <= 0x7F:
        return slice_png_tile(_font_extra(), code - 0x60)
    return blank_tile()


def encode_label(s: str) -> list[int]:
    """Preview-only text encoding via tools/generators/gb_text.py (single-char charmap).

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
