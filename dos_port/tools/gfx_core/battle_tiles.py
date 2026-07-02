"""battle_tiles.py — the charmap as battle VRAM sees it, for previews.

In battle, LoadHpBarAndStatusTilePatterns copies gfx/font/font_battle_extra
(30 tiles) over vChars2 $62-$7F — replacing the font_extra glyphs AND the
box-drawing tiles $79-$7E with the battle set's own — then LoadHudTilePatterns
overlays the real HUD frame pieces: battle_hud_1 (3 tiles) at $6d-$6f and
battle_hud_2+3 (6 tiles) at $73-$78. tile_for_code() reproduces exactly that
layered state so editor previews match the in-battle screen.
"""
from __future__ import annotations

from functools import lru_cache

from PIL import Image

from .font import _font, tile_for_code as _font_code
from .tiles import ROOT, Tile, blank_tile, slice_png_tile

FBE_PNG = ROOT / "gfx" / "font" / "font_battle_extra.png"   # 30 tiles at $62
HUD1_PNG = ROOT / "gfx" / "battle" / "battle_hud_1.png"     # 3 tiles at $6d
HUD2_PNG = ROOT / "gfx" / "battle" / "battle_hud_2.png"     # \ 6 tiles
HUD3_PNG = ROOT / "gfx" / "battle" / "battle_hud_3.png"     # / at $73
BALLS_PNG = ROOT / "gfx" / "battle" / "balls.png"           # 4 party-status balls

# Tile codes (mirror battle_hud.asm / pokeballs.asm defines).
HPB_LEFT, HPB_EMPTY, HPB_FULL = 0x62, 0x63, 0x6B
HPB_END, TILE_LV, HPB_HP = 0x6C, 0x6E, 0x71
T_HUD_73, T_HUD_LINE = 0x73, 0x76
T_PCORNER, T_PTRI = 0x77, 0x6F
T_ECORNER, T_ETRI = 0x74, 0x78


def _sheet(path, count) -> list[Tile]:
    img = Image.open(path).convert("L")
    per_row = img.width // 8
    return [slice_png_tile(img, i, per_row) for i in range(count)]


@lru_cache(maxsize=None)
def _overlay() -> dict[int, Tile]:
    codes: dict[int, Tile] = {}
    for i, t in enumerate(_sheet(FBE_PNG, 30)):
        codes[0x62 + i] = t
    for i, t in enumerate(_sheet(HUD1_PNG, 3)):
        codes[0x6D + i] = t
    hud23 = _sheet(HUD2_PNG, 3) + _sheet(HUD3_PNG, 3)
    for i, t in enumerate(hud23):
        codes[0x73 + i] = t
    return codes


@lru_cache(maxsize=512)
def tile_for_code(code: int) -> Tile:
    """Battle-VRAM charmap tile: font $80+, battle set $62-$7F, else blank."""
    if 0x80 <= code <= 0xFF:
        return slice_png_tile(_font(), code - 0x80)
    ov = _overlay().get(code)
    if ov is not None:
        return ov
    if 0x60 <= code <= 0x61:
        return _font_code(code)          # untouched font_extra pair
    return blank_tile()


@lru_cache(maxsize=None)
def ball_tile() -> Tile:
    """Full party-status pokéball (balls.png tile 0), for oam_row previews."""
    return _sheet(BALLS_PNG, 1)[0]
