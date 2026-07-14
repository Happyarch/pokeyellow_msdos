"""surface.py — tile-grid compositing onto PIL images + FRAME.BIN loading.

The pixel-level half of ui_layout/render.py, factored out so the battle
launcher and the map editor draw with the exact same rasterizer.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

from . import font as ft
from .tiles import DMG_PAL, TILE, Tile

# FRAME.BIN sprite-debug colors (values 4-11), same as tools/render_frame.py.
FRAME_EXTRA = {i: (255, 0, 255) for i in range(4, 64)}


def load_pal_bin(path: Path) -> dict[int, tuple[int, int, int]]:
    """Read debug_dump.asm's PAL0 v1 live-DAC snapshot."""
    data = path.read_bytes()
    if len(data) < 208 or data[:4] != b"PAL0" or data[4] != 1:
        raise ValueError(f"{path}: not a PAL0 v1 palette dump")
    return {i: tuple(round(c * 255 / 63) for c in data[16 + i * 3:19 + i * 3])
            for i in range(64)}


def blit_gb_tile(img: Image.Image, tile: Tile, col: int, row: int,
                 pal=DMG_PAL) -> None:
    """Blit one decoded 8x8 GB tile at tile coords; off-canvas is skipped."""
    px = img.load()
    ox, oy = col * TILE, row * TILE
    if ox < 0 or oy < 0 or ox + TILE > img.width or oy + TILE > img.height:
        return
    for y in range(TILE):
        for x in range(TILE):
            px[ox + x, oy + y] = pal[tile[y][x]]


def blit_code(img: Image.Image, code: int, col: int, row: int,
              tile_fn=None) -> None:
    """Blit a charmap-coded font/border tile (the old render._blit_tile).

    tile_fn maps code -> decoded tile; defaults to the menu charset
    (gfx_core.font). Pass gfx_core.battle_tiles.tile_for_code for the
    battle-VRAM charset.
    """
    blit_gb_tile(img, (tile_fn or ft.tile_for_code)(code), col, row)


def draw_box_border(img: Image.Image, col: int, row: int, w: int,
                    h: int, tile_fn=None) -> None:
    """TextBoxBorder-identical frame: w x h OUTER tiles (w,h >= 3)."""
    blit_code(img, ft.BOX_TL, col, row, tile_fn)
    blit_code(img, ft.BOX_TR, col + w - 1, row, tile_fn)
    blit_code(img, ft.BOX_BL, col, row + h - 1, tile_fn)
    blit_code(img, ft.BOX_BR, col + w - 1, row + h - 1, tile_fn)
    for x in range(1, w - 1):
        blit_code(img, ft.BOX_H, col + x, row, tile_fn)
        blit_code(img, ft.BOX_H, col + x, row + h - 1, tile_fn)
    for y in range(1, h - 1):
        blit_code(img, ft.BOX_V, col, row + y, tile_fn)
        blit_code(img, ft.BOX_V, col + w - 1, row + y, tile_fn)
        for x in range(1, w - 1):
            blit_code(img, ft.TILE_SPC, col + x, row + y, tile_fn)


def draw_label(img: Image.Image, s: str, col: int, row: int,
               tile_fn=None) -> None:
    """Charmap text; pret `next` = newline advancing 2 rows (menu spacing)."""
    r = row
    for line in s.split("\n"):
        for i, code in enumerate(ft.encode_label(line)):
            blit_code(img, code, col + i, r, tile_fn)
        r += 2


def load_frame_bin(path: str, pal_path: str | None = None) -> Image.Image:
    """320x200 FRAME.BIN -> RGB, using its sibling PAL.BIN when available."""
    frame_path = Path(path)
    data = frame_path.read_bytes()
    img = Image.new("RGB", (320, 200))
    px = img.load()
    candidate = Path(pal_path) if pal_path else frame_path.with_name("PAL.BIN")
    pal = load_pal_bin(candidate) if candidate.exists() else {i: c for i, c in enumerate(DMG_PAL)} | FRAME_EXTRA
    for y in range(200):
        for x in range(320):
            i = y * 320 + x
            v = data[i] if i < len(data) else 0
            px[x, y] = pal.get(v, (255, 0, 255))
    return img


def to_pygame(img: Image.Image, zoom: int = 1):
    """PIL RGB image -> pygame surface, integer-zoomed (editor blit helper).

    pygame is imported lazily so headless PIL-only consumers (gen_ui_layout
    --atlas, map render sweeps) never pull it in.
    """
    import pygame
    surf = pygame.image.fromstring(img.tobytes(), img.size, "RGB")
    if zoom != 1:
        surf = pygame.transform.scale(
            surf, (img.width * zoom, img.height * zoom))
    return surf
