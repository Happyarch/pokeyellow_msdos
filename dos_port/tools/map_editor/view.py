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
from dataclasses import dataclass, field
from typing import NamedTuple
from functools import lru_cache
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
                               # strips (drawn from the neighbour, not this map)
    strip_owner: dict = field(default_factory=dict)
                               # padded idx -> (neighbour CONST, its final y, x)

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


def copy_strips(grid: bytearray, stride: int, const: str, info) -> tuple:
    """Copy every connection strip into `grid`; returns (cells, owners, anomalies).

    The runtime does exactly this (`LoadNorthSouth/EastWestConnectionsTileMap`):
    MAP_BORDER rows/columns of the CONNECTED map's .blk are copied into the
    current map's wOverworldMap buffer. The bytes live in the neighbour, so a
    strip cell belongs to the neighbour, not to this map — `owners` maps each
    padded cell to (neighbour CONST, that neighbour's final block y, x) so the
    editor can edit the seam from either side and write to the real owner.
    """
    strips: set[int] = set()
    owners: dict[int, tuple[str, int, int]] = {}
    anomalies: list[str] = []
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
                strips.add(d + i)
                if 0 <= s + i < len(nblk):
                    grid[d + i] = nblk[s + i]
                    owners[d + i] = (nconst, (s + i) // ninfo.w,
                                     (s + i) % ninfo.w)
                else:
                    oob += 1
        if oob:
            anomalies.append(
                f"{const} {direction}->{nconst} (offset {offset}): {oob} "
                f"strip bytes outside the neighbour blk (src {src})")
    return strips, owners, anomalies


def refresh_strips(cm) -> set[int]:
    """Re-copy the strips after a neighbour edit; returns the cells that changed."""
    before = {i: cm.grid[i] for i in cm.strip_cells}
    strips, owners, anomalies = copy_strips(cm.grid, cm.stride,
                                           cm.info.const, cm.info)
    cm.strip_cells = strips
    cm.strip_owner = owners
    cm.anomalies = anomalies
    return {i for i, block in before.items() if cm.grid[i] != block}


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

    strip_cells, strip_owner, anomalies = copy_strips(grid, stride, const, info)

    # the map's own blocks (centre)
    for y in range(info.h):
        d = (y + BORDER) * stride + BORDER
        grid[d:d + info.w] = blk[y * info.w:(y + 1) * info.w]
    if map_overrides:
        for (y, x), block in map_overrides.items():
            if 0 <= x < info.w and 0 <= y < info.h:
                grid[(y + BORDER) * stride + (x + BORDER)] = block

    cm = ComposedMap(info, grid, stride, rows, border_block,
                     warps, signs, sprites, anomalies, strip_cells, strip_owner)
    if overrides:
        editable = cm.editable_cells()
        for (row, col), block in overrides.items():
            idx = row * stride + col
            if idx in editable:
                grid[idx] = block
    return cm


def render(cm: ComposedMap, palette=DMG_PAL,
           stem: str | None = None) -> Image.Image:
    """Padded grid -> RGB image ((w+12)*32 x (h+12)*32).

    `stem` renders the SAME block ids through another tileset. That is the
    neighbour preview: on the GB the current map's tileset expands every block on
    screen, including the strip copied from the neighbour, so re-expanding with
    the neighbour's tileset shows exactly what changes when the player crosses.
    """
    stem = stem or cm.info.tileset_stem
    tiles = ts.load_tileset_2bpp(stem)
    blocks = ts.load_blockset(stem)
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
    x, y, w, h = viewport_px(py, px_, "dos")
    win = (x, y, w, h)
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
    return viewport_px(py, px_, "gb")


# ── viewport probe: what the camera shows from a step ───────────────────────
#
# The camera keeps the player's 16 px step at the CENTRE of the screen, so the
# visible window is the step's centre +/- half the screen. Both window sizes are
# even, so this is exact in pixels; the DOS window is 25 tiles (200 px) tall, an
# ODD number of tiles, which is why the geometry is done in pixels and the sweep
# mask uses 4 px cells instead of 8 px tiles.

VIEWPORT_PX = {"dos": (320, 200), "gb": (160, 144)}
SWEEP_CELL = 4                      # px per mask cell; divides every origin


def viewport_px(tile_y: int, tile_x: int, kind: str):
    """Padded-IMAGE pixel rect the camera shows with the player on that tile.

    The player occupies a 16 px step, so its centre is the tile + TILE.
    """
    w, h = VIEWPORT_PX[kind]
    cx = (tile_x + BORDER * 4) * TILE + TILE
    cy = (tile_y + BORDER * 4) * TILE + TILE
    return (cx - w // 2, cy - h // 2, w, h)


def step_viewport_px(step_y: int, step_x: int, kind: str):
    """Same rect for a player standing on the map-square step (step_y, step_x)."""
    return viewport_px(step_y * 2, step_x * 2, kind)


def viewport_sweep(steps, kind: str):
    """Union of the viewport over a path of (y, x) steps, as a SWEEP_CELL mask.

    Returns (mask, x0, y0, cols, rows) with the origin in padded-image pixels.
    The union is the point of the sweep — everything that is on screen at SOME
    point along the path, not one position at a time.
    """
    if not steps:
        return bytearray(), 0, 0, 0, 0
    rects = [step_viewport_px(y, x, kind) for (y, x) in steps]
    x0 = min(r[0] for r in rects)
    y0 = min(r[1] for r in rects)
    cols = (-(-(max(r[0] + r[2] for r in rects) - x0)) // SWEEP_CELL)
    rows = (-(-(max(r[1] + r[3] for r in rects) - y0)) // SWEEP_CELL)
    mask = bytearray(cols * rows)
    for (rx, ry, w, h) in rects:
        c0 = (rx - x0) // SWEEP_CELL
        r0 = (ry - y0) // SWEEP_CELL
        cw, ch = w // SWEEP_CELL, h // SWEEP_CELL
        run = b"\x01" * cw
        for r in range(r0, r0 + ch):
            start = r * cols + c0
            mask[start:start + cw] = run
    return mask, x0, y0, cols, rows


# ── walkable reach + the viewable union ─────────────────────────────────────
#
# The player only exists on 16 px steps: _AdvancePlayerSprite adds a +-1 step
# vector to wXCoord/wYCoord and GetTileSpriteStandsOn turns a map-coord delta
# into tile rows with `* 2`, so a step is 2x2 tiles and no odd position exists.
#
# Collision is a SINGLE tile, not the four under the sprite. The player's
# standing tile is the LOWER-LEFT of its 2x2 (`lda_coord 8, 9` is x=8, y=9 ->
# row 9, col 8, and GetTileSpriteStandsOn says so outright: "this is always the
# lower left tile of the 2x2 tile blocks all sprites are snapped to"), and
# _GetTileAndCoordsInFrontOfPlayer reads exactly one tile two tiles ahead, which
# CheckTilePassable hands to IsTilePassable. So a step is walkable when its
# LOWER-LEFT tile is passable — which is why the player can stand at a water's
# edge with the sprite overlapping the water. Maps are enclosed by impassable
# tiles or the map edge, so a flood fill from any walkable step enumerates every
# position the player can occupy, and the union of the camera window over those
# steps is everything the map can ever put on screen.

COLLISION_SRC = schema.ROOT / "data" / "tilesets" / "collision_tile_ids.asm"
LEDGE_SRC = schema.ROOT / "data" / "tilesets" / "ledge_tiles.asm"

# SPRITE_FACING_* -> the step delta the jump travels.
LEDGE_DIRECTIONS = {
    "SPRITE_FACING_DOWN": (1, 0),
    "SPRITE_FACING_UP": (-1, 0),
    "SPRITE_FACING_LEFT": (0, -1),
    "SPRITE_FACING_RIGHT": (0, 1),
}


@lru_cache(maxsize=None)
def _collision_lists() -> dict[str, frozenset[int]]:
    """{Label: {passable tile ids}} from pret's collision_tile_ids.asm.

    pret stacks ALIASED labels on one `coll_tiles` line::

        RedsHouse1_Coll::
        RedsHouse2_Coll::
            coll_tiles $01, $02, ...

    so every label seen since the last list is pending until the line arrives and
    the set belongs to ALL of them. Assigning it to the last label only left
    RedsHouse1, Mart, Dojo, ForestGate and Museum empty — and `reds_house`
    (REDS_HOUSE_1F/2F, COPYCATS_HOUSE) then reported zero walkable steps.
    """
    lists: dict[str, set[int]] = {}
    pending: list[str] = []
    for line in COLLISION_SRC.read_text().splitlines():
        s = line.split(";", 1)[0].strip()      # trailing comments are not data
        if s.endswith("_Coll::"):
            pending.append(s[:-2])
        elif pending and s.startswith("coll_tiles"):
            args = s.split("coll_tiles", 1)[1]
            ids = {int(token.strip().replace("$", "0x"), 16)
                   for token in args.split(",") if token.strip()}
            for name in pending:
                lists[name] = set(ids)
            pending = []
    for name in pending:                       # label with no list at all
        lists.setdefault(name, set())
    return {name: frozenset(ids) for name, ids in lists.items()}


@lru_cache(maxsize=None)
def collision_tiles(stem: str | None) -> frozenset[int]:
    """Passable tile ids for a tileset stem (e.g. "overworld" -> Overworld_Coll)."""
    if not stem:
        return frozenset()
    lists = _collision_lists()
    want = "".join(ch for ch in stem.lower() if ch.isalnum())
    for name, ids in lists.items():
        if "".join(ch for ch in name.lower() if ch.isalnum()) == want:
            return ids
    for name, ids in lists.items():
        if "".join(ch for ch in name.lower() if ch.isalnum()).startswith(want):
            return ids
    return frozenset()


@lru_cache(maxsize=None)
def _ledge_table() -> tuple[tuple[str, int, int], ...]:
    """(facing, standing tile, ledge tile) from pret's ledge_tiles.asm."""
    entries = []
    for line in LEDGE_SRC.read_text().splitlines():
        s = line.split(";", 1)[0].strip()
        if not s.startswith("db "):
            continue
        tokens = [t.strip() for t in s[3:].split(",")]
        if len(tokens) != 4 or tokens[0] not in LEDGE_DIRECTIONS:
            continue
        entries.append((tokens[0],
                        int(tokens[1].replace("$", "0x"), 16),
                        int(tokens[2].replace("$", "0x"), 16)))
    return tuple(entries)


@lru_cache(maxsize=None)
def _expanded_block(stem: str, block: int) -> tuple[tuple[int, ...], ...]:
    """4x4 tile ids of one block, cached — the flood reads this per step."""
    return tuple(tuple(row) for row in ts.expand_block(
        ts.load_blockset(stem), block))


def _tile_at(cm, tile_y: int, tile_x: int) -> int:
    """Tile id of one map-local tile, or -1 outside the map.

    -1 is never a valid tile id, so an out-of-range read can never be mistaken
    for a passable tile; indexing a negative coordinate into the padded grid
    would otherwise wrap into an unrelated block.
    """
    if not (0 <= tile_y < cm.info.h * 4 and 0 <= tile_x < cm.info.w * 4):
        return -1
    block = cm.grid[(tile_y // 4 + BORDER) * cm.stride + tile_x // 4 + BORDER]
    return _expanded_block(cm.info.tileset_stem, block)[tile_y % 4][tile_x % 4]


def feet_tile(cm, step_y: int, step_x: int) -> int:
    """The tile the player stands on: the LOWER-LEFT of the 2x2 step."""
    return _tile_at(cm, step_y * 2 + 1, step_x * 2)


def step_walkable(cm, step_y: int, step_x: int) -> bool:
    """True when the player's standing (lower-left) tile here is passable."""
    passable = collision_tiles(cm.info.tileset_stem)
    if not passable:
        return False
    if not (0 <= step_y < cm.info.h * 2 and 0 <= step_x < cm.info.w * 2):
        return False
    return feet_tile(cm, step_y, step_x) in passable


def _ledge_landings(cm, step_y: int, step_x: int):
    """Landing steps for a hop out of this standing step, if any.

    A ledge is in play when the tile BEHIND it is passable and reachable — above
    a downward ledge, to the right of a leftward one, to the left of a rightward
    one — and the tile in front is the ledge tile pret lists for that facing.
    Reachability is what the flood has already established, so this is only ever
    asked about a step the player can actually stand on.

    pret also pins the approach tile to $2C/$39, and measured across every
    OVERWORLD map that pins exactly the same 756 transitions as "approach tile is
    passable" (0 disagreements), so the two rules agree today. The table is kept
    because it is what HandleLedges actually matches: paint a ledge whose
    approach tile is not one of those two and the hop really will not happen
    in-game, which is worth the editor telling you.
    """
    if (cm.info.tileset_name or "").upper() != "OVERWORLD":
        return
    stand = feet_tile(cm, step_y, step_x)
    h, w = cm.info.h * 2, cm.info.w * 2
    for facing, stand_id, ledge_id in _ledge_table():
        if stand_id != stand:
            continue
        dy, dx = LEDGE_DIRECTIONS[facing]
        if not (0 <= step_y + dy < h and 0 <= step_x + dx < w):
            continue
        # the tile in front must BE the ledge tile for this facing
        if _tile_at(cm, (step_y + dy) * 2 + 1, (step_x + dx) * 2) != ledge_id:
            continue
        land = (step_y + 2 * dy, step_x + 2 * dx)
        if 0 <= land[0] < h and 0 <= land[1] < w:
            yield land


class Reach(NamedTuple):
    """What the flood found.

    standing  — positions the player can stop on, and turn from.
    traversed — positions the camera passes over mid-hop. HandleLedges queues
                TWO simulated steps, so the player's sprite sits ON the ledge
                tile before clearing it: not a standing position (no stopping,
                no turning, so the flood never expands from it), but the camera
                is centred there and that viewport is real.
    """

    standing: set
    traversed: set

    def steps(self) -> set:
        """Every position the camera occupies: standing plus mid-hop."""
        return self.standing | self.traversed


def _flood(cm, seed, standing: set) -> list:
    """Plain 4-connectivity from `seed` into `standing`; returns what it added.

    Deliberately knows nothing about ledges: this is the cheap part and it
    answers most of the map, so ledge logic is kept out of its inner loop.
    """
    h, w = cm.info.h * 2, cm.info.w * 2
    added = []
    todo = [seed]
    while todo:
        y, x = todo.pop()
        for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if (ny, nx) in standing or not (0 <= ny < h and 0 <= nx < w):
                continue
            if step_walkable(cm, ny, nx):
                standing.add((ny, nx))
                added.append((ny, nx))
                todo.append((ny, nx))
    return added


def reachable_steps(cm, seed) -> Reach:
    """Flood every step the player can reach from `seed`.

    Two phases per round, in the order that keeps the common case cheap:

      1. plain 4-connectivity from every step reached so far — no ledge logic;
      2. then resolve the ledges of those steps, from a queue. A hop that lands
         somewhere new opens a region, so its landing goes back through phase 1.

    Every reached step has its ledge checked exactly once, so the cost is
    proportional to what the flood actually covers rather than to the whole map.

    Undirected on purpose: this answers "can the player ever stand here", not
    "can they get here from the map entrance". Sprites are ignored (they move),
    warps are ordinary passable tiles, and tile-pair collisions (CAVERN/FOREST
    elevation edges) are unmodelled — ignoring them lets the flood cross an edge
    the game forbids, which over-marks. Over-marking is the safe direction for an
    audit; under-marking would hide a seam.
    """
    empty = Reach(set(), set())
    if seed is None:
        return empty
    h, w = cm.info.h * 2, cm.info.w * 2
    if not (0 <= seed[0] < h and 0 <= seed[1] < w):
        return empty
    if not step_walkable(cm, *seed):
        return empty
    standing = {seed}
    traversed: set = set()
    queue = [seed]                     # reached steps whose ledge is unchecked
    while queue:
        fresh = []
        for step in queue:             # phase 1: plain walking
            fresh.extend(_flood(cm, step, standing))
        batch, queue = queue + fresh, []
        for (y, x) in batch:           # phase 2: the ledges of what we reached
            for land in _ledge_landings(cm, y, x):
                # The hop is two steps, so the camera passes over the midpoint.
                traversed.add(((y + land[0]) // 2, (x + land[1]) // 2))
                if land not in standing:
                    standing.add(land)
                    queue.append(land)
    return Reach(standing, traversed - standing)


def block_at_cell(cm, x: int, y: int) -> int:
    """Block id shown under a 4 px cell (works for strip cells too).

    Past the padded grid the port's LoadCurrentMapView clamp yields
    wMapBackgroundTile, so an out-of-grid cell shows the BORDER block — which is
    the whole point of the border class: it is the map's border block, not
    nothing, and it changes when the neighbouring map's border block differs.
    """
    tx = x // TILE - BORDER * 4
    ty = y // TILE - BORDER * 4
    idx = (ty // 4 + BORDER) * cm.stride + (tx // 4 + BORDER)
    if not (0 <= idx < len(cm.grid)):
        return cm.border_block
    return cm.grid[idx]


@lru_cache(maxsize=None)
def _block_rgb(stem: str, block: int, colors: tuple) -> bytes:
    """32x32 RGB bytes for one block under one tileset + palette.

    The palette is part of the key because a colour-only difference is exactly
    what a route/city seam produces (see SetPal_Overworld: a town's palette id is
    its map id + 1, every route shares PAL_ROUTE).
    """
    img = Image.new("RGB", (ts.BLOCK_PX, ts.BLOCK_PX))
    ts._blit_block(img, ts.load_tileset_2bpp(stem), ts.load_blockset(stem),
                   block, 0, 0, colors)
    return img.tobytes()


def appearance(cm, cells, stem: str, colors) -> dict:
    """{(x, y): rendered 32x32 bytes} for 4 px cells under one look.

    A look is a (tileset, palette) pair: the tileset decides how a block ID
    expands into tiles, the palette decides what those tile pixels become. Two
    cells with the same signature look identical to the player.
    """
    key = tuple(tuple(c) for c in colors)
    return {(x, y): _block_rgb(stem, block_at_cell(cm, x, y), key)
            for (x, y) in cells}


def look_changes(cm, cells, own, other) -> tuple[int, int, int]:
    """(both, shape-only, colour-only) counts of cells that change appearance.

    `own`/`other` are (stem, colours). The decomposition is the useful part:
    `shape` compares the two tilesets under the SAME palette, `colour` the two
    palettes under the same tileset. A route/city seam is colour-only; a
    cross-tileset seam changes shape.
    """
    base = appearance(cm, cells, *own)
    both = appearance(cm, cells, *other)
    shape = appearance(cm, cells, other[0], own[1])
    colour = appearance(cm, cells, own[0], other[1])
    return (sum(1 for c in cells if base[c] != both[c]),
            sum(1 for c in cells if base[c] != shape[c]),
            sum(1 for c in cells if base[c] != colour[c]))


def viewport_cells(steps, kind: str) -> set[tuple[int, int]]:
    """Union of the camera window over `steps`, as absolute 4 px cells."""
    mask, x0, y0, cols, rows = viewport_sweep(steps, kind)
    if not mask:
        return set()
    cell = SWEEP_CELL
    return {(x0 + c * cell, y0 + r * cell)
            for r in range(rows)
            for c in range(cols) if mask[r * cols + c]}


def cell_meaningful(cm, x: int, y: int) -> bool:
    """True when this 4 px cell shows real map data: the map or a strip.

    Everything else inside the window is the port's border clamp block
    (`LoadCurrentMapView`), which is a rendering decision, not a seam. An
    unmasked attention band is mostly border noise on any reach that touches an
    edge, so the band is masked — and the excluded count is reported instead of
    being dropped silently.
    """
    tx = x // TILE - BORDER * 4
    ty = y // TILE - BORDER * 4
    if 0 <= tx < cm.info.w * 4 and 0 <= ty < cm.info.h * 4:
        return True
    idx = (ty // 4 + BORDER) * cm.stride + (tx // 4 + BORDER)
    return idx in cm.strip_cells


def viewable(cm, steps):
    """(dos, gb, attention, border) as absolute 4 px-cell sets.

    Both windows are centred on the same step and DOS strictly contains GB, so
    the per-position difference is the frame and the union difference is
    "ever on DOS, never on GB". The band splits into two classes, and BOTH are
    part of it:

      attention  real map data — the map's own blocks or a connection strip.
                 Measured: the strip is the neighbour's own byte, so these cells
                 do NOT change when the player crosses (same tileset).
      border     border fill past the map edge. The port clamps out-of-map reads
                 to wMapBackgroundTile, so these cells show THIS map's border
                 block — and the neighbouring map has its own. Route 1's border
                 is $0B (grass) and Viridian City's is $0F (trees), so crossing
                 swaps the picture across the whole band. The GB never showed
                 this fill at all; the port's wider viewport does.

    An earlier version masked the band to real data and reported the border
    remainder as an aside. That was backwards: the border class is the one that
    actually changes at a transition.
    """
    dos = viewport_cells(steps, "dos")
    gb = viewport_cells(steps, "gb")
    only = dos - gb
    attention = {cell for cell in only if cell_meaningful(cm, *cell)}
    return dos, gb, attention, only - attention


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
