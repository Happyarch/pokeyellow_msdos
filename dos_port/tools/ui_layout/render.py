"""render.py — rasterize a Layout to a 320x200 PIL image with the real tiles.

Shared by the pygame editor (converted to a surface) and by `gen_ui_layout.py
--atlas` (reference PNG reviewers diff against FRAME.BIN dumps). A `textbox`
or `window` element renders as the exact frame TextBoxBorder draws (corner /
edge / space tiles $79-$7F); `text` labels render through the charmap font.
"""
from __future__ import annotations

from PIL import Image

from . import assets_bridge as ab
from . import canvas as cv


def _blit_tile(img: Image.Image, code: int, col: int, row: int) -> None:
    tile = ab.tile_for_code(code)
    px = img.load()
    ox, oy = col * cv.TILE, row * cv.TILE
    if ox < 0 or oy < 0 or ox + cv.TILE > img.width or oy + cv.TILE > img.height:
        return
    for y in range(cv.TILE):
        for x in range(cv.TILE):
            px[ox + x, oy + y] = ab.DMG_PAL[tile[y][x]]


def _draw_border(img: Image.Image, col: int, row: int, w: int, h: int) -> None:
    """TextBoxBorder-identical frame: w x h OUTER tiles (w,h >= 3)."""
    _blit_tile(img, ab.BOX_TL, col, row)
    _blit_tile(img, ab.BOX_TR, col + w - 1, row)
    _blit_tile(img, ab.BOX_BL, col, row + h - 1)
    _blit_tile(img, ab.BOX_BR, col + w - 1, row + h - 1)
    for x in range(1, w - 1):
        _blit_tile(img, ab.BOX_H, col + x, row)
        _blit_tile(img, ab.BOX_H, col + x, row + h - 1)
    for y in range(1, h - 1):
        _blit_tile(img, ab.BOX_V, col, row + y)
        _blit_tile(img, ab.BOX_V, col + w - 1, row + y)
        for x in range(1, w - 1):
            _blit_tile(img, ab.TILE_SPC, col + x, row + y)


def _draw_label(img: Image.Image, s: str, col: int, row: int) -> None:
    # pret `next` = newline advancing 2 rows (double-spaced menu text)
    r = row
    for line in s.split("\n"):
        for i, code in enumerate(ab.encode_label(line)):
            _blit_tile(img, code, col + i, r)
        r += 2


def render_layout(layout, background: Image.Image | None = None,
                  only_ids: set[str] | None = None) -> Image.Image:
    w = layout.canvas["cols"] * cv.TILE
    h = layout.canvas["rows"] * cv.TILE
    if background is not None:
        img = background.convert("RGB").resize((w, h))
    else:
        img = Image.new("RGB", (w, h), ab.DMG_PAL[0])
    for el in layout.elements:
        if only_ids is not None and el.id not in only_ids:
            continue
        p = cv.project(el)
        if el.kind in ("textbox", "window", "sprite_popup"):
            _draw_border(img, p.col, p.row, el.gb_w, el.gb_h)
        if el.text_label and p.text_col is not None:
            _draw_label(img, el.text_label, p.text_col, p.text_row)
        elif el.kind == "text" and el.text_label:
            _draw_label(img, el.text_label, p.col, p.row)
    return img


def load_frame_bin(path: str) -> Image.Image:
    """320x200 palette-indexed FRAME.BIN -> RGB image (render_frame.py palette)."""
    data = open(path, "rb").read()
    img = Image.new("RGB", (320, 200))
    px = img.load()
    extra = {4: (255, 0, 0), 5: (255, 128, 0), 6: (255, 255, 0), 7: (0, 255, 0),
             8: (0, 255, 255), 9: (0, 128, 255), 10: (128, 0, 255),
             11: (255, 0, 255)}
    pal = {i: c for i, c in enumerate(ab.DMG_PAL)} | extra
    for y in range(200):
        for x in range(320):
            i = y * 320 + x
            v = data[i] if i < len(data) else 0
            px[x, y] = pal.get(v, (255, 0, 255))
    return img
