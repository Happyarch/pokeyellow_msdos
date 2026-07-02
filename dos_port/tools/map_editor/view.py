"""view.py — runtime-faithful map composition + rendering + overlays.

compose_padded() replicates the port's wOverworldMap build (overworld.asm):
  1. fill the (w+12) x (h+12) padded block grid with the border block
  2. copy each connection strip from the neighbour's real .blk
     (6 rows x len for N/S, len rows x 6 cols for W/E — MAP_BORDER=6),
     using the exact src/dest indices gen_map_headers.get_connection() emits
  3. copy the map's own blk into the centre
Connections are applied before the centre copy (same net result as the
runtime; the centre never overlaps strips).
"""
from __future__ import annotations

import sys
from dataclasses import dataclass
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from gfx_core import pret_maps as pm          # noqa: E402
from gfx_core import tilesets as ts           # noqa: E402
from gfx_core.tiles import DMG_PAL, TILE      # noqa: E402

BORDER = pm.MAP_BORDER_BLOCKS                 # 6 blocks each side
BLOCK_PX = ts.BLOCK_PX                        # 32


@dataclass
class ComposedMap:
    info: pm.MapInfo
    grid: bytearray            # (w+12) x (h+12) block IDs, row-major
    stride: int                # w + 12
    rows: int                  # h + 12
    border_block: int
    warps: list                # [(y, x, dest_const, warp_id)] map-local tiles
    sign_count: int
    sprites: list              # gmh sprite dicts (mapy/mapx include +4)
    anomalies: list            # connection strips reading outside the
                               # neighbour's blk (candidate C4 re-tune bugs)


def compose_padded(const: str) -> ComposedMap:
    info = pm.map_info(const)
    if info.tileset_stem is None:
        raise ValueError(f"{const}: no header/tileset")
    blk = pm.load_blk(info)
    obj = pm.objects(info) or (0, [], 0, [])
    border_block, warps, sign_count, sprites = obj

    stride, rows = info.w + 2 * BORDER, info.h + 2 * BORDER
    grid = bytearray(bytes([border_block]) * (stride * rows))

    # connection strips (runtime: LoadNorthSouth/EastWestConnectionsTileMap).
    # A source index outside the neighbour's blk means the RUNTIME reads
    # adjacent GB memory (get_connection can emit src = -1 for offset -5
    # connections) — we render the border block there and record an anomaly
    # for the C4 connection re-tune pass.
    anomalies = []
    for direction, nconst, offset in pm.CONNECTIONS.get(const, []):
        ninfo = pm.map_info(nconst)
        nblk = pm.load_blk(ninfo)
        c = pm.get_connection(direction, ninfo.map_id, offset,
                              info.w, info.h, ninfo.w, ninfo.h)
        src, dst = c["blk"], c["map"]
        if direction in ("NORTH", "SOUTH"):
            rows_n, cols_n = BORDER, c["len"]
        else:
            rows_n, cols_n = c["len"], BORDER
        oob = 0
        for r in range(rows_n):
            s = src + r * ninfo.w
            d = dst + r * stride
            for i in range(cols_n):
                if d + i < 0 or d + i >= len(grid):
                    oob += 1
                    continue
                if 0 <= s + i < len(nblk):
                    grid[d + i] = nblk[s + i]
                else:
                    oob += 1
        if oob:
            anomalies.append(
                f"{const} {direction}->{nconst} (offset {offset}): {oob} "
                f"strip bytes outside the neighbour blk (src {src})")

    # the map's own blocks (centre)
    for y in range(info.h):
        d = (y + BORDER) * stride + BORDER
        grid[d:d + info.w] = blk[y * info.w:(y + 1) * info.w]

    return ComposedMap(info, grid, stride, rows, border_block,
                       warps, sign_count, sprites, anomalies)


def render(cm: ComposedMap) -> Image.Image:
    """Padded grid -> RGB image ((w+12)*32 x (h+12)*32)."""
    tiles = ts.load_tileset_2bpp(cm.info.tileset_stem)
    blocks = ts.load_blockset(cm.info.tileset_stem)
    img = Image.new("RGB", (cm.stride * BLOCK_PX, cm.rows * BLOCK_PX),
                    DMG_PAL[0])
    for by in range(cm.rows):
        for bx in range(cm.stride):
            ts._blit_block(img, tiles, blocks, cm.grid[by * cm.stride + bx],
                           bx, by, DMG_PAL)
    return img


# ── overlay geometry (pixel coords on the padded render) ────────────────────

def warp_px(cm: ComposedMap, y: int, x: int) -> tuple[int, int]:
    """Map-local tile coords -> padded-image px (warps/signs use tiles)."""
    return ((x + BORDER * 2) * TILE, (y + BORDER * 2) * TILE)


def sprite_px(cm: ComposedMap, mapy: int, mapx: int) -> tuple[int, int]:
    """Object MAPY/MAPX (map tile + 4) -> padded-image px."""
    return ((mapx - 4 + BORDER * 2) * TILE, (mapy - 4 + BORDER * 2) * TILE)


def viewport_rect(cm: ComposedMap, py: int, px_: int):
    """The 40x25-tile screen window for a player standing at map-local tile
    (px_, py): the player is pinned at screen tile (17, 24)/2... — concretely
    the window's top-left tile = player tile - (19, 11) in padded coords
    (40/2-1, 25/2 rounded), plus the 12-tile pad. Returns (x, y, w, h) px.
    Also returns the 12x9-block wSurroundingTiles reach as a second rect."""
    ptx, pty = px_ + BORDER * 2, py + BORDER * 2      # padded tile coords
    win = ((ptx - 19) * TILE, (pty - 11) * TILE, 40 * TILE, 25 * TILE)
    # LoadCurrentMapView reads SCREEN_BLOCK_WIDTH x SCREEN_BLOCK_HEIGHT
    # (12x9) blocks starting one block up-left of the view pointer; approximate
    # centred on the player block:
    pbx, pby = ptx // 4, pty // 4
    sur = ((pbx - 5) * BLOCK_PX, (pby - 4) * BLOCK_PX,
           12 * BLOCK_PX, 9 * BLOCK_PX)
    return win, sur
