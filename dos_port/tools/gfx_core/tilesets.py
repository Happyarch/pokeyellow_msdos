"""tilesets.py — decode map tilesets/blocksets and render whole maps.

Data formats (same binaries gen_all_assets.py embeds):
  gfx/tilesets/<stem>.2bpp   8x8 tiles, 16 bytes each (GB 2bpp)
  gfx/blocksets/<stem>.bst   16 bytes per block = a 4x4 grid of tile IDs
  maps/<Pascal>.blk          one byte per block cell, row-major, w x h blocks

One block = 4x4 tiles = 32x32 pixels. Tile IDs index the tileset directly
(the runtime loads the tileset at VRAM $9000 and block IDs address from 0).
"""
from __future__ import annotations

from functools import lru_cache

from PIL import Image

from .tiles import DMG_PAL, ROOT, TILE, Tile, blank_tile, decode_2bpp

BLOCK_TILES = 4                      # 4x4 tiles per block
BLOCK_PX = BLOCK_TILES * TILE        # 32x32 px per block
BLOCK_BYTES = 16


@lru_cache(maxsize=None)
def load_tileset_2bpp(stem: str) -> tuple[Tile, ...]:
    """Decoded tiles of gfx/tilesets/<stem>.2bpp (build the .2bpp first)."""
    data = (ROOT / "gfx" / "tilesets" / f"{stem}.2bpp").read_bytes()
    return tuple(decode_2bpp(data))


@lru_cache(maxsize=None)
def load_blockset(stem: str) -> bytes:
    """Raw gfx/blocksets/<stem>.bst — len // 16 blocks."""
    return (ROOT / "gfx" / "blocksets" / f"{stem}.bst").read_bytes()


def expand_block(blockset: bytes, block_id: int) -> list[list[int]]:
    """Block ID -> 4x4 grid of tile IDs (row-major, as DrawTileBlock reads)."""
    base = block_id * BLOCK_BYTES
    if base + BLOCK_BYTES > len(blockset):
        block_id, base = 0, 0        # mirror DrawTileBlock's block-ID clamp
    return [list(blockset[base + r * BLOCK_TILES:
                          base + (r + 1) * BLOCK_TILES])
            for r in range(BLOCK_TILES)]


def _blit_block(img: Image.Image, tiles: tuple[Tile, ...], blockset: bytes,
                block_id: int, bx: int, by: int, pal) -> None:
    px = img.load()
    for tr, row in enumerate(expand_block(blockset, block_id)):
        for tc, tile_id in enumerate(row):
            tile = tiles[tile_id] if tile_id < len(tiles) else blank_tile()
            ox = bx * BLOCK_PX + tc * TILE
            oy = by * BLOCK_PX + tr * TILE
            for y in range(TILE):
                for x in range(TILE):
                    px[ox + x, oy + y] = pal[tile[y][x]]


def render_map(blk: bytes, w: int, h: int, blockset: bytes,
               tiles: tuple[Tile, ...], border_block: int = 0,
               pad: int = 0, pal=DMG_PAL) -> Image.Image:
    """Compose a map to pixels: pad-block border ring around the real w x h
    .blk grid. Returns a ((w+2*pad)*32) x ((h+2*pad)*32) RGB image."""
    cols, rows = w + 2 * pad, h + 2 * pad
    img = Image.new("RGB", (cols * BLOCK_PX, rows * BLOCK_PX), pal[0])
    for by in range(rows):
        for bx in range(cols):
            mx, my = bx - pad, by - pad
            if 0 <= mx < w and 0 <= my < h:
                block_id = blk[my * w + mx]
            else:
                block_id = border_block
            _blit_block(img, tiles, blockset, block_id, bx, by, pal)
    return img
