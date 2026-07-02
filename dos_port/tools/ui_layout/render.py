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

from gfx_core import surface as sf          # noqa: E402
from gfx_core.tiles import DMG_PAL          # noqa: E402

from . import canvas as cv                  # noqa: E402

# Re-exported for existing callers (editor background toggle, atlas diffing).
load_frame_bin = sf.load_frame_bin


def render_layout(layout, background: Image.Image | None = None,
                  only_ids: set[str] | None = None) -> Image.Image:
    w = layout.canvas["cols"] * cv.TILE
    h = layout.canvas["rows"] * cv.TILE
    if background is not None:
        img = background.convert("RGB").resize((w, h))
    else:
        img = Image.new("RGB", (w, h), DMG_PAL[0])
    for el in layout.elements:
        if only_ids is not None and el.id not in only_ids:
            continue
        p = cv.project(el)
        if el.kind in ("textbox", "window", "sprite_popup"):
            sf.draw_box_border(img, p.col, p.row, el.gb_w, el.gb_h)
        if el.text_label and p.text_col is not None:
            sf.draw_label(img, el.text_label, p.text_col, p.text_row)
        elif el.kind == "text" and el.text_label:
            sf.draw_label(img, el.text_label, p.col, p.row)
    return img
