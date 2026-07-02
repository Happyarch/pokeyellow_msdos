"""render.py — rasterize a Layout to a 320x200 PIL image with the real tiles.

Shared by the pygame editor (converted to a surface) and by `gen_ui_layout.py
--atlas` (reference PNG reviewers diff against FRAME.BIN dumps). A `textbox`
or `window` element renders as the exact frame TextBoxBorder draws (corner /
edge / space tiles $79-$7F); `text` labels render through the charmap font.

Pixel-level rasterizing lives in tools/gfx_core/ (shared with the map
editor); this module keeps only the Layout-schema-aware composition.
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from gfx_core import battle_tiles as bt     # noqa: E402
from gfx_core import surface as sf          # noqa: E402
from gfx_core.tiles import DMG_PAL, TILE    # noqa: E402

from . import canvas as cv                  # noqa: E402

# Re-exported for existing callers (editor background toggle, atlas diffing).
load_frame_bin = sf.load_frame_bin

CHAR_CURSOR = 0xED                          # charmap "▶"


def _draw_mon_pic(img: Image.Image, col: int, row: int, w: int,
                  h: int) -> None:
    """7x7 mon-pic placeholder: mid-shade checker inside a dark outline."""
    px = img.load()
    x0, y0 = col * TILE, row * TILE
    for y in range(h * TILE):
        for x in range(w * TILE):
            if x0 + x >= img.width or y0 + y >= img.height:
                continue
            edge = x in (0, w * TILE - 1) or y in (0, h * TILE - 1)
            shade = 3 if edge else 1 + ((x // TILE + y // TILE) & 1)
            px[x0 + x, y0 + y] = DMG_PAL[shade]


def _draw_hud_frame(img: Image.Image, col: int, row: int, h: int,
                    variant: str, tile_fn) -> None:
    """battle_hud.asm place_hud_frame: $73 connector column above one end of
    a corner + 8 underline + triangle shelf (width 10) on the bottom row."""
    shelf = row + h - 1
    if variant == "enemy":               # connector top-LEFT, marches right
        sf.blit_code(img, bt.T_HUD_73, col, row, tile_fn)
        sf.blit_code(img, bt.T_ECORNER, col, shelf, tile_fn)
        for i in range(8):
            sf.blit_code(img, bt.T_HUD_LINE, col + 1 + i, shelf, tile_fn)
        sf.blit_code(img, bt.T_ETRI, col + 9, shelf, tile_fn)
    else:                                # player: 2 connectors top-RIGHT
        for r in range(row, shelf):
            sf.blit_code(img, bt.T_HUD_73, col + 9, r, tile_fn)
        sf.blit_code(img, bt.T_PCORNER, col + 9, shelf, tile_fn)
        for i in range(8):
            sf.blit_code(img, bt.T_HUD_LINE, col + 8 - i, shelf, tile_fn)
        sf.blit_code(img, bt.T_PTRI, col, shelf, tile_fn)


def render_layout(layout, background: Image.Image | None = None,
                  only_ids: set[str] | None = None) -> Image.Image:
    w = layout.canvas["cols"] * cv.TILE
    h = layout.canvas["rows"] * cv.TILE
    # battle previews use the battle-VRAM charset (font_battle_extra + HUD
    # overlays at $62-$7F); everything else the menu font_extra charset.
    tile_fn = bt.tile_for_code if layout.subsystem == "battle" else None
    if background is not None:
        img = background.convert("RGB").resize((w, h))
    else:
        img = Image.new("RGB", (w, h), DMG_PAL[0])
    for el in layout.elements:
        if only_ids is not None and el.id not in only_ids:
            continue
        p = cv.project(el)
        if el.kind in ("textbox", "window", "sprite_popup"):
            sf.draw_box_border(img, p.col, p.row, el.gb_w, el.gb_h, tile_fn)
        elif el.kind == "hp_gauge":
            codes = [bt.HPB_HP, bt.HPB_LEFT] + [bt.HPB_FULL] * 6 + [bt.HPB_END]
            for i, code in enumerate(codes):
                sf.blit_code(img, code, p.col + i, p.row, tile_fn)
        elif el.kind == "mon_pic":
            _draw_mon_pic(img, p.col, p.row, el.gb_w, el.gb_h)
        elif el.kind == "hud_frame":
            variant = "enemy" if "enemy" in el.notes else "player"
            _draw_hud_frame(img, p.col, p.row, el.gb_h, variant, tile_fn)
        elif el.kind == "oam_row":
            for i in range(el.gb_w):
                sf.blit_gb_tile(img, bt.ball_tile(), p.col + i, p.row)
        elif el.kind == "cursor":
            sf.blit_code(img, CHAR_CURSOR, p.col, p.row, tile_fn)
        if el.text_label and p.text_col is not None:
            sf.draw_label(img, el.text_label, p.text_col, p.text_row, tile_fn)
        elif el.kind == "text" and el.text_label:
            sf.draw_label(img, el.text_label, p.col, p.row, tile_fn)
    return img
