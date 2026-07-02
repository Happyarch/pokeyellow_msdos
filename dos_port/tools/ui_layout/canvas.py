"""canvas.py — the anchor-rule projection (docs/ui_projection.md), in ONE place.

Both the pygame editor and gen_ui_layout.py import this module, so the pixel
preview and the emitted equates cannot drift.

    our_col = gb_col + H_SHIFT     H_SHIFT = 0 (left) | 10 (center) | 20 (right)
    our_row = gb_row + V_SHIFT     V_SHIFT = 0 (top)  | 3 (center)  | 7 (bottom)

    wx     = our_col * 8 + 7       ; render_window left edge is WX-7
    wy     = our_row * 8
    clip_w = width  * 8
    max_y  = (our_row + height) * 8
"""
from __future__ import annotations

from dataclasses import dataclass

TILE = 8
H_SHIFTS = {"left": 0, "center": 10, "right": 20}
V_SHIFTS = {"top": 0, "center": 3, "bottom": 7}


@dataclass(frozen=True)
class Projection:
    col: int          # projected top-left tile col on the 40x25 canvas
    row: int
    x2: int           # projected lower-right tile (pret corner-pair form)
    y2: int
    wx: int           # window-descriptor form
    wy: int
    clip: int
    max_y: int
    text_col: int | None = None   # projected text cursor (TextAndCoord entries)
    text_row: int | None = None


def shifts(el) -> tuple[int, int]:
    sx = el.shift_x if el.anchor_x == "custom" else H_SHIFTS[el.anchor_x]
    sy = el.shift_y if el.anchor_y == "custom" else V_SHIFTS[el.anchor_y]
    return sx, sy


def project(el) -> Projection:
    sx, sy = shifts(el)
    col, row = el.gb_x + sx, el.gb_y + sy
    tc = el.text_x + sx if el.text_x is not None else None
    tr = el.text_y + sy if el.text_y is not None else None
    return Projection(
        col=col, row=row,
        x2=col + el.gb_w - 1, y2=row + el.gb_h - 1,
        wx=col * TILE + 7, wy=row * TILE,
        clip=el.gb_w * TILE, max_y=(row + el.gb_h) * TILE,
        text_col=tc, text_row=tr,
    )


def proj_tag(subsystem: str, el) -> str:
    """The exact `; PROJ` comment string for this element (copy-paste ready)."""
    p = project(el)
    sx, sy = shifts(el)
    op = f"anchor={el.anchor_x}/{el.anchor_y}, X+{sx}, Y+{sy}"
    return (f"; PROJ {subsystem}: GB({el.gb_x},{el.gb_y}) {el.gb_w}x{el.gb_h} "
            f"--({op})--> wx={p.wx} wy={p.wy} clip={p.clip} max_y={p.max_y} "
            f"[UI_{el.id}_*]")
