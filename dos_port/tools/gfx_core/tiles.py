"""tiles.py — tile primitives: sizes, palette, PNG slicing, raw GB decode.

Tiles are 8x8 lists of GB color indices 0..3 (0 = lightest), the same
convention as tools/render_frame.py and the whole software PPU.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent.parent.parent  # repo root

TILE = 8
TILES_PER_ROW = 16

# DMG green ramp — keep identical to tools/render_frame.py PAL[0..3].
DMG_PAL = [(224, 248, 208), (136, 192, 112), (52, 104, 86), (8, 24, 32)]

Tile = list[list[int]]


def blank_tile(color: int = 0) -> Tile:
    return [[color] * TILE for _ in range(TILE)]


def slice_png_tile(img: Image.Image, index: int,
                   tiles_per_row: int = TILES_PER_ROW) -> Tile:
    """8x8 GB-color tile from a grayscale tile-sheet PNG (pret gfx sources)."""
    tx, ty = index % tiles_per_row, index // tiles_per_row
    tile = []
    for y in range(TILE):
        row = []
        for x in range(TILE):
            lum = img.getpixel((tx * TILE + x, ty * TILE + y))
            # grayscale -> GB color: darkest = 3, lightest = 0
            row.append(3 - min(3, round(lum / 85)))
        tile.append(row)
    return tile


def decode_2bpp(data: bytes) -> list[Tile]:
    """Raw GB 2bpp tile data (16 bytes/tile) -> tiles.

    Per pixel row: byte 0 = low bitplane, byte 1 = high bitplane; bit 7 is
    the leftmost pixel (Pan Docs "Tile Data"). This is the format of the
    built gfx/**/*.2bpp files and of blockset tile graphics.
    """
    tiles = []
    for base in range(0, len(data) - 15, 16):
        tile = []
        for y in range(TILE):
            lo = data[base + y * 2]
            hi = data[base + y * 2 + 1]
            tile.append([(((hi >> b) & 1) << 1) | ((lo >> b) & 1)
                         for b in range(7, -1, -1)])
        tiles.append(tile)
    return tiles


def decode_1bpp(data: bytes) -> list[Tile]:
    """Raw GB 1bpp tile data (8 bytes/tile) -> tiles (0 or 3, font-style)."""
    tiles = []
    for base in range(0, len(data) - 7, 8):
        tile = []
        for y in range(TILE):
            bits = data[base + y]
            tile.append([3 if (bits >> b) & 1 else 0
                         for b in range(7, -1, -1)])
        tiles.append(tile)
    return tiles
