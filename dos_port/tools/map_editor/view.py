"""view.py — runtime-faithful map composition + rendering + overlays.

compose_padded() replicates the port's wOverworldMap build (overworld.asm):
  1. fill the (w+12) x (h+12) padded block grid with the border block
  2. copy each connection strip from the neighbour's real .blk
     (MAP_BORDER rows x len for N/S, len rows x MAP_BORDER cols for W/E),
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
from map_editor import schema                 # noqa: E402

BORDER = pm.MAP_BORDER_BLOCKS                 # blocks each side (parsed from gb_memmap.inc)
BLOCK_PX = ts.BLOCK_PX                        # 32


@dataclass
class ComposedMap:
    info: pm.MapInfo
    grid: bytearray            # (w+12) x (h+12) block IDs, row-major
    stride: int                # w + 12
    rows: int                  # h + 12
    border_block: int
    warps: list                # [(y, x, dest_const, warp_id)] map-local tiles
    signs: list                # [{y, x, text_id, text_name}] map squares
    sprites: list              # gmh sprite dicts (mapy/mapx include +4)
    anomalies: list            # connection strips reading outside the
                               # neighbour's blk (candidate C4 re-tune bugs)
    strip_cells: set           # padded-grid indices covered by connection
                               # strips (locked: connections always win)

    def editable_cells(self) -> set[int]:
        """Paintable indices: the border ring minus connection strips."""
        cells = set()
        for by in range(self.rows):
            for bx in range(self.stride):
                in_map = (BORDER <= bx < self.stride - BORDER
                          and BORDER <= by < self.rows - BORDER)
                idx = by * self.stride + bx
                if not in_map and idx not in self.strip_cells:
                    cells.add(idx)
        return cells


def can_compose(const: str) -> bool:
    """True when this map's pret data is usable as a standalone block grid.

    Cheap enough for the Tab cycle: it only touches the .blk header, not the
    tile cache.
    """
    try:
        info = pm.map_info(const)
        if info.tileset_stem is None:
            return False
        pm.load_blk(info)
        return True
    except (OSError, ValueError, KeyError):
        return False


def neighbour_origin(direction: str, offset: int, cur_w: int, cur_h: int,
                     conn_w: int, conn_h: int) -> tuple[int, int]:
    """Where a connected map's block (0,0) sits, in this map's padded block coords.

    Derived from the same indices gen_map_headers.get_connection() emits, not
    guessed: the strip's neighbour origin and its padded destination pin the two
    grids together. For NORTH/SOUTH the `offset` slides the neighbour
    horizontally, for WEST/EAST vertically, and `get_connection`'s clamp keeps the
    relative placement identical when it rewrites `_tgt`/`_src`.

    Returns (row, col) in padded block coordinates (the current map's own blocks
    start at (BORDER, BORDER)).
    """
    if direction == "NORTH":
        # The neighbour's BOTTOM BORDER rows sit in the ring's top BORDER rows,
        # so neighbour row 0 is (conn_h - BORDER) rows above padded row 0.
        return (BORDER - conn_h, BORDER + offset)
    if direction == "SOUTH":
        return (BORDER + cur_h, BORDER + offset)
    if direction == "WEST":
        return (BORDER + offset, BORDER - conn_w)
    if direction == "EAST":
        return (BORDER + offset, BORDER + cur_w)
    raise ValueError(f"unknown connection direction {direction!r}")


@dataclass
class ConnectionView:
    """The current map plus every connected map, assembled at its real offset."""
    info: pm.MapInfo
    grid: bytearray            # block IDs over the whole union canvas
    stride: int
    rows: int
    origin: tuple[int, int]    # where this map's (0,0) block sits in the canvas
    neighbours: list           # [{const, direction, offset, origin, w, h}]
    anomalies: list


def compose_connections(const: str) -> ConnectionView:
    """Assemble the current map and its neighbours the way the runtime joins them.

    This is a REVIEW view, not a runtime surface: the port never holds two maps'
    full grids at once. It exists so a widened edge, a shifted object or a
    re-tuned connection offset can be eyeballed as an actual seam rather than
    inferred from a border ring.
    """
    info = pm.map_info(const)
    if info.tileset_stem is None:
        raise ValueError(f"{const}: no header/tileset")
    own, w, h, _ = schema.compose_layout(
        info.label or pm.gmh.const_to_pascal(const), pm.load_blk(info),
        info.base_w, info.base_h)

    entries = []
    anomalies = []
    for direction, nconst, offset in pm.CONNECTIONS.get(const, []):
        ninfo = pm.map_info(nconst)
        if ninfo.tileset_stem is None:
            anomalies.append(f"{direction} -> {nconst}: no header/tileset")
            continue
        try:
            nblk, nw, nh, _ = schema.compose_layout(
                ninfo.label or pm.gmh.const_to_pascal(nconst), pm.load_blk(ninfo),
                ninfo.base_w, ninfo.base_h)
        except (OSError, ValueError) as exc:
            anomalies.append(f"{direction} -> {nconst}: {exc}")
            continue
        if ninfo.tileset_stem != info.tileset_stem:
            # The two maps do not share a tileset, so their block IDs are not
            # comparable; drawing them on one canvas would be a lie.
            anomalies.append(
                f"{direction} -> {nconst}: tileset {ninfo.tileset_stem} differs "
                f"from {info.tileset_stem}, assembly preview skipped")
            continue
        origin = neighbour_origin(direction, offset, info.w, info.h, nw, nh)
        entries.append({'const': nconst, 'direction': direction, 'offset': offset,
                        'origin': origin, 'w': nw, 'h': nh, 'blk': nblk})

    own_origin = (BORDER, BORDER)
    min_r = min([own_origin[0]] + [e['origin'][0] for e in entries])
    min_c = min([own_origin[1]] + [e['origin'][1] for e in entries])
    max_r = max([own_origin[0] + info.h] + [e['origin'][0] + e['h'] for e in entries])
    max_c = max([own_origin[1] + info.w] + [e['origin'][1] + e['w'] for e in entries])
    stride, rows = max_c - min_c, max_r - min_r
    grid = bytearray(stride * rows)

    for entry in entries:
        r0, c0 = entry['origin'][0] - min_r, entry['origin'][1] - min_c
        entry['canvas_origin'] = (r0, c0)
        for y in range(entry['h']):
            dst = (r0 + y) * stride + c0
            src = y * entry['w']
            grid[dst:dst + entry['w']] = entry['blk'][src:src + entry['w']]
        entry.pop('blk')

    own_r, own_c = own_origin[0] - min_r, own_origin[1] - min_c
    for y in range(info.h):
        dst = (own_r + y) * stride + own_c
        grid[dst:dst + info.w] = own[y * w:(y + 1) * w]

    return ConnectionView(info, grid, stride, rows, (own_r, own_c), entries,
                          anomalies)


def render_grid(info: pm.MapInfo, grid: bytearray, stride: int, rows: int,
                palette=DMG_PAL) -> Image.Image:
    """Block grid -> RGB image. Shared by the padded and connection renders."""
    tiles = ts.load_tileset_2bpp(info.tileset_stem)
    blocks = ts.load_blockset(info.tileset_stem)
    img = Image.new("RGB", (stride * BLOCK_PX, rows * BLOCK_PX), palette[0])
    for by in range(rows):
        for bx in range(stride):
            ts._blit_block(img, tiles, blocks, grid[by * stride + bx],
                           bx, by, palette)
    return img


def compose_padded(const: str, overrides: dict | None = None,
                   map_overrides: dict | None = None) -> ComposedMap:
    """overrides: {(row, col): block} painted border-ring cells (map_borders
    sidecar, padded coords); map_overrides: {(y, x): block} real-map edits
    (map_overrides sidecar, map-local coords, merged into <map>_blk.inc by
    gen_all_assets.py)."""
    info = pm.map_info(const)
    if info.tileset_stem is None:
        raise ValueError(f"{const}: no header/tileset")
    try:
        raw_blk = pm.load_blk(info)
    except (OSError, ValueError) as exc:
        # Two pret maps are genuinely unusable as standalone grids and this is a
        # data fact, not an editor failure: UNDERGROUND_PATH_ROUTE_7_COPY is a
        # COPY map with no .blk of its own, and UNDERGROUND_PATH_NORTH_SOUTH
        # declares 4x24 while pret's own comment notes the file is 4x23.
        # Report it as a clean diagnostic so callers can skip the map instead of
        # dying with a traceback.
        raise ValueError(f"{const}: cannot load pret block layout ({exc})") from exc
    blk, port_w, port_h, _diff = schema.compose_layout(
        info.label or pm.gmh.const_to_pascal(const), raw_blk, info.base_w,
        info.base_h)
    if (port_w, port_h) != (info.w, info.h):
        raise ValueError(f"{const}: composed dimensions {port_w}x{port_h} "
                         f"do not match map-header dimensions {info.w}x{info.h}")
    obj = pm.objects(info) or (0, [], [], [])
    border_block, warps, signs, sprites = obj

    stride, rows = info.w + 2 * BORDER, info.h + 2 * BORDER
    grid = bytearray(bytes([border_block]) * (stride * rows))

    # connection strips (runtime: LoadNorthSouth/EastWestConnectionsTileMap).
    # A source index outside the neighbour's blk means the RUNTIME reads
    # adjacent GB memory (get_connection can emit src = -1 for offset -5
    # connections) — we render the border block there and record an anomaly
    # for the C4 connection re-tune pass.
    anomalies = []
    all_strips: set[int] = set()
    for direction, nconst, offset in pm.CONNECTIONS.get(const, []):
        ninfo = pm.map_info(nconst)
        nraw = pm.load_blk(ninfo)
        nblk, nw, nh, _ndiff = schema.compose_layout(
            ninfo.label or pm.gmh.const_to_pascal(nconst), nraw,
            ninfo.base_w, ninfo.base_h)
        if (nw, nh) != (ninfo.w, ninfo.h):
            raise ValueError(f"{nconst}: composed dimensions disagree with header")
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
                all_strips.add(d + i)
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
    if map_overrides:
        for (y, x), block in map_overrides.items():
            if 0 <= x < info.w and 0 <= y < info.h:
                grid[(y + BORDER) * stride + (x + BORDER)] = block

    cm = ComposedMap(info, grid, stride, rows, border_block,
                     warps, signs, sprites, anomalies, all_strips)
    if overrides:
        editable = cm.editable_cells()
        for (row, col), block in overrides.items():
            idx = row * stride + col
            if idx in editable:
                grid[idx] = block
    return cm


def render(cm: ComposedMap, palette=DMG_PAL) -> Image.Image:
    """Padded grid -> RGB image ((w+12)*32 x (h+12)*32)."""
    tiles = ts.load_tileset_2bpp(cm.info.tileset_stem)
    blocks = ts.load_blockset(cm.info.tileset_stem)
    img = Image.new("RGB", (cm.stride * BLOCK_PX, cm.rows * BLOCK_PX),
                    palette[0])
    for by in range(cm.rows):
        for bx in range(cm.stride):
            ts._blit_block(img, tiles, blocks, cm.grid[by * cm.stride + bx],
                           bx, by, palette)
    return img


# ── overlay geometry (pixel coords on the padded render) ────────────────────

def warp_px(cm: ComposedMap, y: int, x: int) -> tuple[int, int]:
    """Map-local tile coords -> padded-image px (warps/signs use tiles)."""
    return ((x * 2 + BORDER * 4) * TILE, (y * 2 + BORDER * 4) * TILE)


def sprite_px(cm: ComposedMap, mapy: int, mapx: int) -> tuple[int, int]:
    """Object MAPY/MAPX (map tile + 4) -> padded-image px."""
    return (((mapx - 4) * 2 + BORDER * 4) * TILE,
            ((mapy - 4) * 2 + BORDER * 4) * TILE)


def viewport_rect(cm: ComposedMap, py: int, px_: int):
    """The 40x25-tile screen window for a player standing at map-local tile
    (px_, py): the player is pinned at screen tile (17, 24)/2... — concretely
    the window's top-left tile = player tile - (19, 11) in padded coords
    (40/2-1, 25/2 rounded), plus the 12-tile pad. Returns (x, y, w, h) px.
    Also returns the 12x9-block wSurroundingTiles reach as a second rect."""
    x, y, w, h = viewport_tile_rect(py, px_, "dos")
    win = (x * TILE, y * TILE, w * TILE, h * TILE)
    # LoadCurrentMapView reads SCREEN_BLOCK_WIDTH x SCREEN_BLOCK_HEIGHT
    # (12x9) blocks starting one block up-left of the view pointer; approximate
    # centred on the player block:
    ptx, pty = px_ + BORDER * 4, py + BORDER * 4
    pbx, pby = ptx // 4, pty // 4
    sur = ((pbx - 5) * BLOCK_PX, (pby - 4) * BLOCK_PX,
           12 * BLOCK_PX, 9 * BLOCK_PX)
    return win, sur


def gb_viewport_rect(cm: ComposedMap, py: int, px_: int):
    """20x18-tile GB-sized reference frame around a map-local player tile.

    This is intentionally a size/frame reference for staging, not an emulation
    of the original GB camera's edge scroll rules.
    """
    x, y, w, h = viewport_tile_rect(py, px_, "gb")
    return (x * TILE, y * TILE, w * TILE, h * TILE)


# ── viewport probe: what the camera shows from a step ───────────────────────
#
# The player stands on a 16 px STEP (2x2 tiles) and the camera keeps that step
# near the screen centre, so the visible window is a fixed-size rectangle at a
# fixed tile offset from the step's top-left tile. "dos" is the port's 320x200
# window (40x25 tiles); "gb" is the 160x144 reference (20x18 tiles).

VIEWPORT_TILES = {"dos": (40, 25), "gb": (20, 18)}
VIEWPORT_OFFSET = {"dos": (19, 11), "gb": (9, 8)}


def viewport_tile_rect(tile_y: int, tile_x: int, kind: str):
    """Padded-TILE rect the camera shows with the player tile at (tile_x, tile_y)."""
    off_x, off_y = VIEWPORT_OFFSET[kind]
    w, h = VIEWPORT_TILES[kind]
    return (tile_x + BORDER * 4 - off_x, tile_y + BORDER * 4 - off_y, w, h)


def step_viewport_tile_rect(step_y: int, step_x: int, kind: str):
    """Same rect for a player standing on the map-square step (step_y, step_x)."""
    return viewport_tile_rect(step_y * 2, step_x * 2, kind)


def viewport_sweep(steps, kind: str):
    """Union of the viewport over a path of (y, x) steps, as a padded-TILE mask.

    Returns (mask, x0, y0, cols, rows): `mask` is row-major over TILE cells whose
    top-left is padded tile (x0, y0). The union is the point of the sweep — it is
    everything that is on screen at SOME point along the path, not one position
    at a time.
    """
    if not steps:
        return bytearray(), 0, 0, 0, 0
    rects = [step_viewport_tile_rect(y, x, kind) for (y, x) in steps]
    x0 = min(r[0] for r in rects)
    y0 = min(r[1] for r in rects)
    cols = max(r[0] + r[2] for r in rects) - x0
    rows = max(r[1] + r[3] for r in rects) - y0
    mask = bytearray(cols * rows)
    for (rx, ry, w, h) in rects:
        left = rx - x0
        run = b"\x01" * w
        for r in range(ry - y0, ry - y0 + h):
            start = r * cols + left
            mask[start:start + w] = run
    return mask, x0, y0, cols, rows


def mask_edges(mask: bytearray, cols: int, rows: int):
    """Outline of a tile mask as merged segments, relative to the mask origin.

    Horizontal entries are (row, col0, col1) and vertical are (col, row0, row1),
    with half-open ranges. Only edges bordering an uncovered cell are emitted, so
    this is the boundary of the UNION rather than a pile of overlapping boxes.
    """
    def filled(r: int, c: int) -> bool:
        return 0 <= r < rows and 0 <= c < cols and mask[r * cols + c]

    horizontal, vertical = [], []
    for r in range(rows):
        for above in (True, False):
            start = None
            for c in range(cols + 1):
                edge = (c < cols and filled(r, c)
                        and not (filled(r - 1, c) if above else filled(r + 1, c)))
                if edge and start is None:
                    start = c
                elif not edge and start is not None:
                    horizontal.append((r if above else r + 1, start, c))
                    start = None
    for c in range(cols):
        for left in (True, False):
            start = None
            for r in range(rows + 1):
                edge = (r < rows and filled(r, c)
                        and not (filled(r, c - 1) if left else filled(r, c + 1)))
                if edge and start is None:
                    start = r
                elif not edge and start is not None:
                    vertical.append((c if left else c + 1, start, r))
                    start = None
    return horizontal, vertical
