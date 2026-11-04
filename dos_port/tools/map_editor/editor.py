#!/usr/bin/env python3
"""editor.py — pygame overworld map and cutscene editor.

Usage (from the repo root):
  python3 dos_port/tools/map_editor/editor.py PALLET_TOWN [--zoom N]

`--zoom` defaults to the largest integer zoom that fits the composed map.

View controls:
  left click       place: paint a block, pick/drag an NPC, set the staging tile
  middle drag      pan                     arrows  pan too
  wheel            smooth zoom (continuous scale)  Ctrl+wheel  other anchor
  Ctrl + = / -     zoom in / out
  G  step grid (16px, one movement step)   B  block grid (32px)   T  tile grid (8px)
  W  warp + sign events
  N  NPC markers   J  trigger tiles (where ArePlayerCoordsInArray fires)
  V/H/R port/GB/reach frames (click sets the staged player tile)
  I  coordinate inspector   C  toggle palette   O  cycle route preview
  X  connections: assemble neighbouring maps at their real offsets (read-only)
  Y  viewport probe: click a step to box what the DOS (V, red) and GB (H, blue)
     camera sees from there; drag to sweep a path; shift-click clears
  Ctrl-drag (hold) lock a paint stroke or a probe sweep to one axis
  click a W marker  select a warp; drag it to move; panel edits dest / target / kind
  [ / ] select route step; 1-4 set down/up/left/right (edits the port script)
  Ctrl+Shift+arrow  expand that edge by one 32px block
  Tab              cycle to the next map with a usable header
  Ctrl+S           save: commit every staged edit to the tree
  Esc / close      quit without saving (discards staged edits)

Edits are STAGED, never written as you go: a paint stroke, an NPC drag, a warp
move, a route byte or an expansion lands in a scratch copy and reaches the
repository only when you press Ctrl+S (see staging.py). That makes an accidental
drag harmless, and it is why quitting never saves anything.

Zoom anchoring is set by `zoom_anchor` in config.json (`cursor` by default, or
`center`). Ctrl is a held shift, not a toggle: while it is down the other anchor
mode is used, and releasing it returns to the configured default.

UI chrome (HUD font, side panels, bottom bar) scales with the window; set
`ui_scale` in config.json to "auto" (default) or pin it with a number.

Paint mode (P toggles):
  left click/drag  paint the selected block (border ring or map interior)
  right click      eyedropper (pick block under cursor)
  O                arm the picker: the next left click CLONES that cell's block
                   into the palette instead of painting it; O again cancels
  click palette    select block                F  flood fill
  Ctrl+Z           undo                        Ctrl+S  save
  Palette blocks this map does not place anywhere (own blocks, connection strips
  or border fill) are onion-skinned orange: they cannot change what this map
  looks like, so they are free to repurpose.
  Connection strips are editable and write through to the map that owns them.

The composition is runtime-faithful: border fill -> connection strips from
the neighbours' real .blk (via gen_map_headers.get_connection) -> the map's own
blocks composed with its schema-2 sidecar -> editable border overrides.

See README.md in this directory for the coordinate units, sidecar schema, CLI
and the coverage limits of expansion and script adapters.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import pygame

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from gfx_core import pret_maps as pm            # noqa: E402
from gfx_core import tilesets as ts             # noqa: E402
from gfx_core.surface import to_pygame          # noqa: E402
from gfx_core.tiles import DMG_PAL, TILE        # noqa: E402
from map_editor import borders, overrides, view, palette, sprites, schema, config  # noqa: E402
from map_editor import objects, staging                                         # noqa: E402

MARK_WARP = (0, 150, 170)      # teal: distinct from the cyan render-reach frame
MARK_NPC = (60, 120, 255)
MARK_TRAINER = (255, 160, 0)
MARK_ITEM = (0, 200, 120)
PORT_VIEW = (255, 72, 72)      # red: the port's 320x200 window
GB_VIEW = (90, 150, 255)       # blue: the GB's 160x144 window
RENDER_REACH = (0, 220, 220)
REACH_BAND = (255, 190, 40)    # amber: cells the port shows and the GB never did
PALETTE_UNUSED = (255, 140, 0, 110)  # onion skin: block not placed anywhere here
# Connection strips belong to the NEIGHBOUR, so they get their own tints rather
# than the "locked" dim: the colour tells you whose edge you are looking at.
STRIP_TINTS = ((255, 150, 0), (0, 200, 220), (200, 120, 255), (130, 220, 90))
# Paired-cutscene onion skins. Close violet tones, with a stronger violet where
# both MoveSprite2 walkers occupy the same cell.
NPCMV1 = (168, 92, 230)
NPCMV2 = (120, 132, 240)
NPCMV12 = (236, 120, 255)
# Encounter/trigger tiles from an ArePlayerCoordsInArray table. Yellow so it
# reads as "standing here fires something", not as an object.
TRIGGER_TILE = (255, 235, 60)
# Connection-assembly review view: this map vs its neighbours.
CONN_SELF = (255, 60, 200)
CONN_OTHER = (90, 190, 255)
GRID_STEP = (0, 0, 0)          # 16 px: one movement step (primary grid)
GRID_BLOCK = (255, 140, 0)     # 32 px: one .blk cell (2x2 steps) — accent colour
GRID_TILE = (70, 70, 70)       # 8 px: one GB tile (half a step)
PAINTED = (255, 120, 220)
MAP_PAINTED = (0, 220, 255)
LOCKED_DIM = (0, 0, 0, 110)
SEL_BLOCK = (255, 64, 64)
PANEL_H = 22
# Palette defaults; both are config keys (`palette_cell`, `palette_cols`).
# 32 px is a whole map block at 1:1 pixels — the clearest the swatches can get —
# and "auto" columns make the column LONGER as the cells grow, so the strip stays
# narrow instead of eating the map.
PAL_CELL = ts.BLOCK_PX
PAL_MAX_COLS = 16


# Modifier held during a drag to constrain the stroke to one axis. Ctrl by
# default: shift already clears the probe, and one modifier doing two jobs is how
# a mis-click clears an overlay you were still using.
AXIS_LOCK_MODS = {"ctrl": pygame.KMOD_CTRL, "shift": pygame.KMOD_SHIFT,
                  "alt": pygame.KMOD_ALT, "none": 0}


def _axis_lock(anchor, target):
    """Project `target` onto the dominant axis from `anchor` (shift-drag).

    Returns (point, axis) with axis "H" or "V". This is the constraint every
    other pixel editor has: hold shift and the stroke stays on one axis instead
    of following the pointer.
    """
    ay, ax = anchor
    ty, tx = target
    if abs(tx - ax) >= abs(ty - ay):
        return (ay, tx), "H"
    return (ty, ax), "V"


def _cell_runs(cells):
    """Merge 4 px cells into horizontal runs: [(x, y, width)] for cheap fills."""
    by_row: dict[int, list[int]] = {}
    for x, y in cells:
        by_row.setdefault(y, []).append(x)
    runs = []
    for y, xs in by_row.items():
        xs.sort()
        start = prev = xs[0]
        for x in xs[1:]:
            if x == prev + view.SWEEP_CELL:
                prev = x
                continue
            runs.append((start, y, prev - start + view.SWEEP_CELL))
            start = prev = x
        runs.append((start, y, prev - start + view.SWEEP_CELL))
    return runs


def _grid_line(a, b):
    """Points from `a` (exclusive) to `b` (inclusive), Bresenham on a 2D grid.

    Used for both map steps and padded paint cells, so a fast drag draws an
    unbroken line instead of the cells the mouse happened to sample.
    """
    y0, x0 = a
    y1, x1 = b
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx = 1 if x0 < x1 else -1
    sy = 1 if y0 < y1 else -1
    err = dx + dy
    out = []
    y, x = y0, x0
    while (y, x) != (y1, x1):
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x += sx
        if e2 <= dx:
            err += dx
            y += sy
        out.append((y, x))
    return out


class Viewer:
    def __init__(self, const: str, zoom: float | None = None, settings: dict | None = None):
        self.settings = settings if settings is not None else config.load()
        # Every edit lands in a scratch tree until Ctrl+S (see map_editor/
        # staging.py). Opening the session here means nothing below can reach the
        # repository by accident — a command that writes is staged, not committed.
        self.stage = staging.begin()
        # Continuous scale, not an integer zoom: the wheel produces fractional
        # steps so the zoom is smooth instead of snapping between 1x/2x.
        self.scale = float(zoom) if zoom else 1.0
        self.pan = [0, 0]
        # Grids stay OFF by default, as before: `G` is the step grid, `B` the
        # 32 px block grid, `T` the 8 px tile grid.
        self.show = {"steps": False, "blocks": False, "tiles": False, "warps": True,
                     "npcs": True, "port_view": False, "gb_view": False,
                     "render_reach": False, "inspector": False,
                     "connections": False, "triggers": True}
        self.paint = False
        self.palette_mode = 'port-cgb'
        self.player = None          # map-local tile (x, y) for frame references
        self.cursor_tile = None     # map-local (x, y), updated from mouse motion
        self.drag = None
        self.object_drag = None
        self.selected_object = None
        self.object_menu = None
        self.menu_offset = 0
        self.selected_warp = None
        self.warp_drag = None
        self.warp_menu = None
        self.warp_menu_offset = 0
        self.route_index = -1
        self.route_step = 0
        self.route_sha = None
        self.route_options = []
        self.painting = False
        # One drag = one stroke. The anchor is where it started; whether the
        # stroke is axis-locked is asked of the live modifier on every motion.
        self.stroke_anchor = None
        self.stroke_last = None
        self.lock_axis = None
        # Viewport probe: steps whose camera window is drawn, and the mode that
        # places them. The overlay outlives the mode on purpose — it is an
        # annotation you keep while painting, not a transient cursor.
        self.probe = []
        self.reach = None        # view.Reach from the probe: standing + mid-hop
        self.reach_stats = None  # (steps, hops, dos, gb, attention, border)
        self._reach_runs = []    # merged attention cells, for the fill
        self._reach_outline = {} # kind -> (x0, y0, horizontal, vertical)
        self._reach_surf = None  # reusable translucent overlay
        self._reach_cells = set()  # the whole band, for the look comparison
        self._border_runs = []   # merged border-fill cells, drawn fainter
        self.pick_mode = False   # O in paint mode: next click clones a block
        self.triggers = []       # ArePlayerCoordsInArray tables for this map
        self._unused_skin = None # cached onion-skin tile for the palette
        self._unused_count = 0
        self.view_as = None      # const whose tileset+palette we render with
        self.look_stats = None   # (const, cells, changed, shape, colour)
        self.probe_mode = False
        self.probe_drag = False
        self._probe_cache = {}
        self.conn_view = None
        self.conn_surf = None
        self.conn_scale = None
        pygame.init()
        self.screen = pygame.display.set_mode((1024, 700),
                                              pygame.RESIZABLE)
        self._font = pygame.font.SysFont("monospace", 13)
        self._font_size = 13
        self._ui_key = None
        self._ui_value = 1.0
        self.load(const)

    # ── data ─────────────────────────────────────────────────────────────────

    def load(self, const: str):
        self.cells = borders.load(const)
        info = pm.map_info(const)
        self.map_cells = overrides.load(info.label, info) if info.label else {}
        self.initial_map_cells = dict(self.map_cells)
        self.initial_cells = dict(self.cells)
        base = view.compose_padded(const)          # pre-override
        self.base_grid = bytes(base.grid)
        self.cm = view.compose_padded(const, self.cells, self.map_cells)
        self.editable = self.cm.editable_cells()
        self.view_as = None
        self.pick_mode = False
        self.tiles = ts.load_tileset_2bpp(self.cm.info.tileset_stem)
        self.blocks = ts.load_blockset(self.cm.info.tileset_stem)
        self.nblocks = len(self.blocks) // ts.BLOCK_BYTES
        self.refresh_palette()
        self.invalidate_assembly()
        self.undo_stack = []
        self._probe_cache = {}
        self.clear_reach()
        self.painted = False
        # "Unsaved" covers both layers: an in-memory paint stroke, and a staged
        # sidecar/script edit from an earlier action in this session.
        self.dirty = self.stage.pending() > 0
        self.center_view()
        self.current_block = self.cm.border_block
        self.save_error = ""
        self.selected_object = None
        self.object_drag = None
        self.object_menu = None
        self.selected_warp = None
        self.warp_drag = None
        self.warp_menu = None
        self.warp_menu_offset = 0
        self.route_index = -1
        self.route_step = 0
        try:
            from map_editor import commands
            scanned = commands.scan_routes(const)
            self.route_options = scanned['routes']
            self.route_sha = scanned['sha256']
        except (ValueError, OSError):
            self.route_options = []
            self.route_sha = None
        try:
            from map_editor import commands
            self.triggers = commands.scan_triggers(const)['triggers']
        except (ValueError, OSError):
            self.triggers = []
        pygame.display.set_caption(
            f"map_editor — {const} ({self.cm.info.w}x{self.cm.info.h} blocks,"
            f" {self.cm.info.tileset_name})")

    def surface(self):
        """The map raster at the current scale, rebuilt only when the scale moves.

        The PIL render stays at 1x and is nearest-neighbour scaled here, so pixel
        art stays crisp while the zoom itself is continuous.
        """
        if self.surf is None or self._surf_scale != self.scale:
            self.surf = to_pygame(self.img, self.scale)
            self._surf_scale = self.scale
        return self.surf

    def invalidate_assembly(self):
        """Drop the connection assembly and every cached raster.

        The assembly depends on THIS map's dimensions AND blocks: `get_connection`
        is called with the current width/height, so expanding an edge moves every
        neighbour's origin. Rebuilding it is therefore required after a load, an
        expansion, or a palette change — otherwise the seam picture keeps showing
        the pre-expansion geometry, which is worse than showing nothing.
        """
        self.conn_view = None
        self.conn_surf = None
        self.conn_scale = None
        self._core_surf = None
        self._core_scale = None
        self.surf = None
        self.pal_surf = None
        self._pal_key = None

    def invalidate_map_blocks(self):
        """Drop only what a block edit changes.

        Painting rewrites this map's own blocks, so its core raster and the padded
        raster go stale — but the neighbours have not moved, and recomposing them
        (which re-reads every neighbour .blk) on each painted cell would stall a
        paint drag. The assembly draws the current map UNDER map_core_surface(),
        so its baked copy is always covered.
        """
        self._core_surf = None
        self._core_scale = None
        self.surf = None
        self.pal_surf = None
        self._pal_key = None

    def viewport_center(self) -> tuple[float, float]:
        """Screen centre of the map area (the bottom bar is excluded)."""
        return (self.screen.get_width() / 2.0,
                (self.screen.get_height() - self.panel_h()) / 2.0)

    def zoom_anchor(self, ctrl: bool) -> str:
        """Effective anchor mode.

        Ctrl is a shift key, not a toggle: while it is held the OTHER mode is in
        force, and releasing it returns to whatever the config says. So the
        default stays what the config sets and Ctrl is a momentary override.
        """
        default = self.settings['zoom_anchor']
        if not ctrl:
            return default
        return 'center' if default == 'cursor' else 'cursor'

    def set_scale(self, new_scale: float, anchor: tuple[float, float]) -> None:
        """Scale about a screen point, keeping the map point under it fixed."""
        low, high = self.settings['zoom_min'], self.settings['zoom_max']
        new_scale = max(low, min(high, new_scale))
        if abs(new_scale - self.scale) < 1e-9:
            return
        # Image coords under the anchor, before and after.
        img_x = (anchor[0] - self.pan[0]) / self.scale
        img_y = (anchor[1] - self.pan[1]) / self.scale
        self.scale = new_scale
        self.pan = [anchor[0] - img_x * new_scale,
                    anchor[1] - img_y * new_scale]
        self.surf = None
        self.conn_surf = None

    def zoom_by(self, factor: float, ctrl: bool, cursor: tuple[int, int]) -> None:
        mode = self.zoom_anchor(ctrl)
        anchor = cursor if mode == 'cursor' else self.viewport_center()
        self.set_scale(self.scale * factor, anchor)

    def center_view(self):
        """Frame the authored map, not the padding ring.

        The render is the padded grid, so panning to (0, 0) shows only border
        blocks and the map sits off-screen. Centre the padded image instead: the
        border is symmetric, so its centre is the map's centre.

        In connections mode the thing on screen is the ASSEMBLY, which extends
        past the ring, so centre that instead or the neighbours fall off-screen.
        """
        if self.show["connections"]:
            cv = self.conn_view or view.compose_connections(self.cm.info.const)
            self.conn_view = cv
            surf = self.connection_surface()
            off_x, off_y = self.connection_offset(self.scale)
            self.pan = [(self.screen.get_width() - surf.get_width()) // 2 - off_x,
                        (self.screen.get_height() - self.panel_h() - surf.get_height()) // 2 - off_y]
            return
        surf = self.surface()
        self.pan = [(self.screen.get_width() - surf.get_width()) // 2,
                    (self.screen.get_height() - self.panel_h() - surf.get_height()) // 2]

    def view_info(self):
        """The MapInfo whose tileset + palette the canvas is drawn with.

        Normally the map itself. `K` points this at a connected neighbour, which
        is how a seam is checked: the runtime expands every block on screen
        through the CURRENT map's tileset and paints it with the current map's
        palette (SetPal_Overworld), so re-rendering the same block ids with the
        neighbour's pair shows exactly what changes at the crossing.
        """
        return pm.map_info(self.view_as) if self.view_as else self.cm.info

    def look_of(self, info):
        """(tileset stem, colours) — one renderable, hashable 'look' for a map."""
        if self.palette_mode != 'port-cgb':
            return (info.tileset_stem, tuple(tuple(c) for c in DMG_PAL))
        return (info.tileset_stem,
                tuple(tuple(c) for c in palette.resolve(info)[1]))

    def refresh_palette(self):
        info = self.view_info()
        if self.palette_mode == 'port-cgb':
            self.palette_name, self.colors, self.palette_warning = palette.resolve(info)
        else:
            self.palette_name, self.colors, self.palette_warning = 'DMG', DMG_PAL, None
        self.img = view.render(self.cm, self.colors, stem=info.tileset_stem)
        # Colours changed: every raster is stale, but the assembly's GEOMETRY is
        # not, so only the surfaces are dropped here.
        self.conn_surf = None
        self.conn_scale = None
        self._core_surf = None
        self._core_scale = None
        self.surf = None
        self.pal_surf = None
        self._pal_key = None

    # ── painting ─────────────────────────────────────────────────────────────

    def cell_at(self, pos) -> tuple[int, int] | None:
        bx = (pos[0] - self.pan[0]) // (ts.BLOCK_PX * self.scale)
        by = (pos[1] - self.pan[1]) // (ts.BLOCK_PX * self.scale)
        if 0 <= bx < self.cm.stride and 0 <= by < self.cm.rows:
            return int(by), int(bx)
        return None

    def tile_at(self, pos) -> tuple[int, int] | None:
        """Mouse pixel -> map-local (x, y) tile, excluding the padded ring."""
        tx = (pos[0] - self.pan[0]) // (TILE * self.scale)
        ty = (pos[1] - self.pan[1]) // (TILE * self.scale)
        x, y = int(tx - view.BORDER * 4), int(ty - view.BORDER * 4)
        if 0 <= x < self.cm.info.w * 4 and 0 <= y < self.cm.info.h * 4:
            return x, y
        return None

    # ── viewport probe ───────────────────────────────────────────────────────

    def step_at(self, pos) -> tuple[int, int] | None:
        """Mouse pixel -> map-square step (y, x), or None outside the map.

        The player only exists on whole 16 px steps, so a probe anchor is always
        snapped to one: step (y, x) is tiles (2y..2y+1, 2x..2x+1).
        """
        tile = self.tile_at(pos)
        if tile is None:
            return None
        return tile[1] // 2, tile[0] // 2

    def set_player_tile(self, pos):
        """Stage the player tile on the step under the cursor (always even)."""
        step = self.step_at(pos)
        if step is None:
            self.player = None
            return
        sy, sx = step
        self.player = (sx * 2, sy * 2)

    def sync_player(self):
        """Keep the staged player tile on the probe's last step (the frames use it)."""
        if self.probe:
            sy, sx = self.probe[-1]
            self.player = (sx * 2, sy * 2)

    def probe_steps(self):
        """Steps to draw: the probed path, else the single staged player tile."""
        if self.probe:
            return self.probe
        if self.player:
            return [(self.player[1] // 2, self.player[0] // 2)]
        return []

    def outline(self, steps, kind):
        """(x0, y0, horizontal, vertical) outline of the viewport union, in px.

        Only the boundary is kept, so a 400-step sweep costs one outline rather
        than 400 overlapping rectangles.
        """
        mask, x0, y0, cols, rows = view.viewport_sweep(list(steps), kind)
        horizontal, vertical = view.mask_edges(mask, cols, rows)
        cell = view.SWEEP_CELL
        return (x0, y0,
                [(r * cell, c0 * cell, c1 * cell) for (r, c0, c1) in horizontal],
                [(c * cell, r0 * cell, r1 * cell) for (c, r0, r1) in vertical])

    def sweep_outline(self, steps, kind):
        """Cached outline for the probe path; only one path is live at a time."""
        key = (kind, tuple(steps))
        hit = self._probe_cache.get(key)
        if hit is None:
            hit = self.outline(steps, kind)
            self._probe_cache = {key: hit}
        return hit

    def compute_reach(self, seed=None):
        """Flood the walkable area from the probe; cache the viewable union.

        Everything the map can ever put on screen is the union of the camera
        window over every position the player can stand on. The DOS window is
        40x25 tiles and the GB's is 20x18, so their difference is exactly the
        area the port reveals and the original hardware never did — masked to
        real map data, because past the map edge the port paints its border
        clamp block and that is not a seam.
        """
        if seed is None:
            steps = self.probe_steps()
            seed = steps[-1] if steps else None
        if seed is None:
            self.save_error = "reach: place the probe on a step first"
            return False
        reach = view.reachable_steps(self.cm, seed)
        if not reach.standing:
            self.save_error = (f"reach: step {seed} is not walkable "
                               f"(impassable, or a ledge)")
            return False
        # The union is over every position the CAMERA occupies, which includes
        # the step a ledge hop passes through, not just where the player stops.
        steps = reach.steps()
        dos, gb, attention, border = view.viewable(self.cm, steps)
        self.reach = reach
        self.reach_stats = (len(reach.standing), len(reach.traversed),
                            len(dos), len(gb), len(attention), len(border))
        self._reach_runs = _cell_runs(attention)
        self._border_runs = _cell_runs(border)
        self._reach_cells = attention | border
        self.look_stats = self.measure_look()
        # Outlines are stored, not recomputed: a whole-map union is thousands of
        # 4 px cells and this must not run once per frame.
        self._reach_outline = {kind: self.outline(steps, kind)
                               for kind in ("dos", "gb")}
        self.save_error = ""
        return True

    def toggle_reach(self):
        """`U`: flood from the probe, or clear the overlay if it is showing."""
        if self.reach_stats is not None:
            self.clear_reach()
            return
        self.compute_reach()

    def look_candidates(self):
        """[None] + one entry per DISTINCT neighbour look, in connection order."""
        seen = {}
        for _direction, nconst, _offset in pm.CONNECTIONS.get(self.cm.info.const, []):
            info = pm.map_info(nconst)
            key = (info.tileset_stem, self.look_of(info)[1])
            seen.setdefault(key, nconst)
        return [None] + list(seen.values())

    def cycle_view_as(self):
        """`K`: render this map with the own look, then each neighbour's, then back."""
        options = self.look_candidates()
        if not options:
            return
        try:
            index = options.index(self.view_as)
        except ValueError:
            index = 0
        self.apply_view_as(options[(index + 1) % len(options)])

    def apply_view_as(self, const=None):
        """Render the same block ids through another map's tileset + palette."""
        self.view_as = const
        info = self.view_info()
        self.tiles = ts.load_tileset_2bpp(info.tileset_stem)
        self.blocks = ts.load_blockset(info.tileset_stem)
        self.nblocks = len(self.blocks) // ts.BLOCK_BYTES
        self.refresh_palette()
        self.look_stats = self.measure_look()

    @staticmethod
    def border_block_of(info):
        """A map's border block (wMapBackgroundTile) without composing it."""
        obj = pm.objects(info)
        return obj[0] if obj else 0

    def measure_look(self):
        """What changes in the band under the viewed look — by class.

        Two independent effects, and only one of them is about the tileset:

          real    the map's own blocks and the connection strip. The strip IS the
                  neighbour's own byte, so with a shared tileset these cannot
                  change graphic (measured: 0 of 6825 strip cells). The palette
                  can change, and it is per map.
          border  border fill past the map edge. The port clamps out-of-map reads
                  to wMapBackgroundTile, so it shows THIS map's border block and
                  the neighbour has its own — Route 1 $0B (grass) vs Viridian
                  City $0F (trees). Every border cell changes on crossing, and
                  the GB never showed that fill at all.
        """
        if self.view_as is None or not self._reach_cells:
            return None
        other_info = pm.map_info(self.view_as)
        own = self.look_of(self.cm.info)
        other = self.look_of(other_info)
        real = {c for c in self._reach_cells if view.cell_meaningful(self.cm, *c)}
        border = self._reach_cells - real
        both, shape, colour = view.look_changes(self.cm, real, own, other)
        own_border = self.cm.border_block
        other_border = self.border_block_of(other_info)
        return {
            "const": self.view_as,
            "real": len(real), "real_changed": both,
            "shape": shape, "colour": colour,
            "border": len(border),
            "border_changed": len(border) if own_border != other_border else 0,
            "own_border": own_border, "other_border": other_border,
        }

    def clear_reach(self):
        self.reach = None
        self.reach_stats = None
        self._reach_runs = []
        self._border_runs = []
        self._reach_cells = set()
        self.look_stats = None
        self._reach_outline = {}

    def probe_sweep(self, kind):
        """Cached (x0, y0, horizontal, vertical) outline for one channel, in px."""
        key = (kind, tuple(self.probe_steps()))
        hit = self._probe_cache.get(key)
        if hit is None:
            mask, x0, y0, cols, rows = view.viewport_sweep(key[1], kind)
            horizontal, vertical = view.mask_edges(mask, cols, rows)
            cell = view.SWEEP_CELL
            hit = (x0, y0,
                   [(r * cell, c0 * cell, c1 * cell) for (r, c0, c1) in horizontal],
                   [(c * cell, r0 * cell, r1 * cell) for (c, r0, r1) in vertical])
            self._probe_cache = {key: hit}      # only one path is live at a time
        return hit

    def probe_click(self, pos, shift=False):
        """Place the probe on a step, or clear it (shift). Returns handled?

        Only meaningful in probe mode: outside it a left click still belongs to
        warp/NPC/paint selection, so the mode guard lives here as well as in the
        event routing. Shift means two things — clear on a CLICK, lock the sweep
        to one axis on a DRAG — and which one it is is only known on release.
        """
        if not self.probe_mode:
            return False
        if shift:
            self.clear_probe()
            return True
        step = self.step_at(pos)
        if step is None:
            return False
        self.stroke_anchor = step
        self.stroke_last = None
        self.lock_axis = None
        self.probe_drag = True
        self.probe = [step]
        self.sync_player()
        self._probe_cache = {}
        return True

    def probe_extend(self, pos, locked=False):
        """Grow the swept path to the step under the cursor, filling the gap.

        MOUSEMOTION can skip several steps between events, so consecutive samples
        are joined with a straight line; otherwise a fast drag would leave holes
        and the union would be wrong exactly where the path is fastest. With an
        axis lock the path is recomputed from the anchor, so pulling back toward
        it shortens the sweep instead of growing a branch.
        """
        step = self.step_at(pos)
        if step is None or self.stroke_anchor is None:
            return
        if locked:
            step, self.lock_axis = _axis_lock(self.stroke_anchor, step)
            self.probe = [self.stroke_anchor] + _grid_line(self.stroke_anchor, step)
        else:
            self.lock_axis = None
            if not self.probe:
                self.probe = [self.stroke_anchor]
            for s in _grid_line(self.probe[-1], step):
                if s != self.probe[-1]:
                    self.probe.append(s)
        self.sync_player()
        self._probe_cache = {}

    def end_stroke(self):
        """Finish a paint/probe drag; the axis lock is only ever held."""
        self.painting = False
        self.probe_drag = False
        self.stroke_anchor = None
        self.stroke_last = None
        self.lock_axis = None

    def clear_probe(self):
        self.probe = []
        self.probe_drag = False
        self.player = None
        self._probe_cache = {}

    def _region(self, r, c):
        """Where a paint at padded cell (r, c) belongs, or None if it is locked.

            ("border", (r, c))              this map's border-ring override
            ("map", (y, x))                 this map's own block, map-local
            ("neighbour", (CONST, y, x))    a connection strip cell

        A strip cell is the NEIGHBOUR's block: the runtime copies it out of the
        neighbour's .blk into this map's wOverworldMap, so this map never stores
        it. Editing one therefore writes to the neighbour's sidecar and the seam
        updates on both sides — which is the whole point, since a transition is
        two maps' edges agreeing.

        In CONNECTIONS mode the ring stays locked (the neighbours are drawn there
        purely so the seam can be watched), but strip cells are editable: that is
        exactly where a transition lives.
        """
        idx = r * self.cm.stride + c
        if idx in self.editable:
            if self.show["connections"]:
                return None
            return ("border", (r, c))
        b = view.BORDER
        if b <= c < self.cm.stride - b and b <= r < self.cm.rows - b:
            return ("map", (r - b, c - b))
        owner = self.cm.strip_owner.get(idx)
        if owner is not None:
            return ("neighbour", owner)
        return None                 # strip reading outside the neighbour's blk

    def strip_colors(self) -> dict:
        """A stable tint per connected neighbour, for the strip overlay."""
        consts = [entry[1] for entry in pm.CONNECTIONS.get(self.cm.info.const, [])]
        return {const: STRIP_TINTS[i % len(STRIP_TINTS)]
                for i, const in enumerate(consts)}

    def refresh_after_neighbour(self):
        """Re-copy the strips after a neighbour write and re-blit what moved."""
        changed = view.refresh_strips(self.cm)
        for idx in changed:
            r, c = divmod(idx, self.cm.stride)
            ts._blit_block(self.img, self.tiles, self.blocks,
                           self.cm.grid[idx], c, r, self.colors)
        if changed:
            self.invalidate_map_blocks()

    def _apply(self, r, c, block):
        """Set one cell; returns an undo record or None."""
        idx = r * self.cm.stride + c
        region = self._region(r, c)
        if region is None or self.cm.grid[idx] == block:
            return None
        kind, payload = region
        if kind == "neighbour":
            from map_editor import commands
            const, y, x = payload
            prev = self.cm.grid[idx]
            try:
                commands.set_block(const, y=y, x=x, block=block, write=True)
            except (ValueError, OSError) as exc:
                self.save_error = str(exc)
                return None
            self.refresh_after_neighbour()
            self.dirty = True
            return (kind, payload, prev)
        target = self.map_cells if kind == "map" else self.cells
        rec = (kind, payload, target.get(payload))
        if block == self.base_grid[idx]:
            initial = self.initial_map_cells if kind == "map" else self.initial_cells
            if payload in initial:
                target[payload] = initial[payload]
            else:
                target.pop(payload, None)
        else:
            target[payload] = block
        self.cm.grid[idx] = block
        ts._blit_block(self.img, self.tiles, self.blocks, block, c, r,
                       self.colors)
        return rec

    def axis_lock_held(self) -> bool:
        """True while the axis-lock modifier is down — a HOLD, never a toggle.

        Read at every motion event, not latched at mouse-down, so pressing the
        modifier mid-stroke starts constraining and releasing it stops.
        """
        mask = AXIS_LOCK_MODS.get(self.settings.get('axis_lock', 'ctrl'), 0)
        return bool(mask and pygame.key.get_mods() & mask)

    def touch_paint(self):
        """Mark an in-memory paint edit.

        Kept apart from `dirty` because `stage_paint` is not free: it re-derives
        the whole block sidecar from `self.map_cells`, so a save that only
        committed an NPC move must not rewrite a block document it never touched.
        """
        self.dirty = True
        self.painted = True
        # The reach is derived from the live grid, so any edit invalidates it —
        # a stale overlay would claim the port shows cells it no longer does.
        self.clear_reach()

    def paint_cell(self, pos, locked=False):
        """Paint at `pos`; while the lock modifier is held, paint a straight line.

        Freehand by default. The caller passes the LIVE modifier state on every
        motion, so holding it mid-stroke starts constraining and releasing it
        stops. The cells between motion samples are filled in, so a fast drag
        draws an unbroken line rather than a dotted one.
        """
        cell = self.cell_at(pos)
        if cell is None:
            return
        if locked and self.stroke_anchor is not None:
            cell, self.lock_axis = _axis_lock(self.stroke_anchor, cell)
            start = self.stroke_last if self.stroke_last is not None \
                else self.stroke_anchor
            cells = [start] + _grid_line(start, cell)
        else:
            self.lock_axis = None       # released mid-stroke: stop advertising
            cells = [cell]
        for r, c in cells:
            rec = self._apply(r, c, self.current_block)
            if rec:
                self.undo_stack.append([rec])
                self.touch_paint()
        self.stroke_last = cell
        self.invalidate_map_blocks()

    def flood_fill(self, pos):
        cell = self.cell_at(pos)
        if cell is None:
            return
        r0, c0 = cell
        idx0 = r0 * self.cm.stride + c0
        if self._region(r0, c0) is None:
            return
        target = self.cm.grid[idx0]
        if target == self.current_block:
            return
        # A fill stops at an ownership boundary: crossing into a strip cell would
        # start writing to the neighbour, which a fill should never do silently.
        start_kind = self._region(r0, c0)[0]
        op, seen, todo = [], {(r0, c0)}, [(r0, c0)]
        while todo:
            r, c = todo.pop()
            idx = r * self.cm.stride + c
            region = self._region(r, c)
            if region is None or region[0] != start_kind \
                    or self.cm.grid[idx] != target:
                continue
            rec = self._apply(r, c, self.current_block)
            if rec:
                op.append(rec)
            for nr, nc in ((r-1, c), (r+1, c), (r, c-1), (r, c+1)):
                if (nr, nc) not in seen and 0 <= nr < self.cm.rows \
                        and 0 <= nc < self.cm.stride:
                    seen.add((nr, nc))
                    todo.append((nr, nc))
        if op:
            self.undo_stack.append(op)
            self.touch_paint()
            self.invalidate_map_blocks()

    def undo(self):
        if not self.undo_stack:
            return
        from map_editor import commands
        b = view.BORDER
        for kind, payload, prev in reversed(self.undo_stack.pop()):
            if kind == "neighbour":
                # The cell belongs to the neighbour, so the undo is a write there
                # too — otherwise the seam would silently keep the new block.
                const, y, x = payload
                try:
                    commands.set_block(const, y=y, x=x, block=prev, write=True)
                except (ValueError, OSError) as exc:
                    self.save_error = str(exc)
                    continue
                self.refresh_after_neighbour()
                self.dirty = True
                continue
            r, c = (payload[0] + b, payload[1] + b) if kind == "map" else payload
            idx = r * self.cm.stride + c
            target = self.map_cells if kind == "map" else self.cells
            if prev is None:
                target.pop(payload, None)
                block = self.base_grid[idx]
            else:
                target[payload] = prev
                block = prev
            self.cm.grid[idx] = block
            ts._blit_block(self.img, self.tiles, self.blocks, block, c, r,
                           self.colors)
        self.touch_paint()
        self.invalidate_map_blocks()

    def toggle_pick(self) -> bool:
        """`O` in paint mode arms the picker; returns False outside paint mode.

        Paint mode only, by request: outside it `O` keeps cycling the route
        preview, so the picker never competes with the paint cursor.
        """
        if not self.paint:
            return False
        self.pick_mode = not self.pick_mode
        return True

    def pick_cell(self, pos):
        """Clone the block under the cursor into the palette; disarm the picker.

        Same target as the right-click eyedropper, but on the LEFT button and
        explicitly armed, so a pick can never be a mis-painted cell. Works on a
        connection strip too — that cell is the neighbour's block, and picking it
        is read-only (the write path is `_apply`).
        """
        cell = self.cell_at(pos)
        if cell is None:
            return
        r, c = cell
        idx = r * self.cm.stride + c
        self.current_block = self.cm.grid[idx]
        self.pal_surf = None            # re-mark the selection in the palette
        self.pick_mode = False

    def eyedrop(self, pos):
        cell = self.cell_at(pos)
        if cell:
            self.current_block = self.cm.grid[cell[0] * self.cm.stride
                                              + cell[1]]
            self.pal_surf = None

    def stage_paint(self):
        """Flush in-memory paint into the staged sidecars (no commit).

        Paint lives in `self.cells` / `self.map_cells` so it renders immediately;
        this is what turns it into the same staged JSON an object or warp edit
        produces. Called before a commit, and before anything that reloads the
        map (expansion, switching maps) so the stroke is not lost.
        """
        borders.save(self.cm.info.const, self.cells, self.cm)
        if self.cm.info.label:
            overrides.save(self.cm.info.label, self.map_cells,
                           self.cm.info, self.nblocks)

    def save(self):
        """Ctrl+S: commit every staged edit (sidecars and port scripts) to the tree."""
        try:
            if self.painted:
                self.stage_paint()
        except ValueError as e:
            self.save_error = str(e)
            print(f"SAVE REFUSED: {e}")
            return
        written = self.stage.commit()
        self.save_error = ""
        self.dirty = False
        self.painted = False
        if not written:
            print("nothing to save")
            return
        for rel in written:
            print(f"saved {self.stage.root / rel}")
        print(f"{len(written)} file(s) written")
        print("regenerate with: make -C dos_port assets")

    # ── palette panel ────────────────────────────────────────────────────────

    def palette_cell(self) -> int:
        """Pixel size of one palette cell: `palette_cell` base px, UI-scaled."""
        base = self.settings.get('palette_cell', PAL_CELL)
        return max(8, int(round(base * self.ui_scale())))

    def palette_cols(self) -> int:
        """Tiles per palette row.

        `palette_cols` is a number or "auto" (default). Auto fits as many ROWS as
        the window is tall, so a bigger cell makes the column longer instead of
        either running off the bottom or eating the map with a very wide strip.
        """
        setting = self.settings.get('palette_cols', 'auto')
        if setting != 'auto':
            return max(1, min(PAL_MAX_COLS, int(setting)))
        cell = self.palette_cell()
        room = max(cell, self.screen.get_height() - self.panel_h() - 12)
        rows_fit = max(1, room // cell)
        cols = -(-self.nblocks // rows_fit)
        return max(1, min(PAL_MAX_COLS, self.nblocks, cols))

    def palette_rows(self) -> int:
        return -(-self.nblocks // self.palette_cols())

    def palette_width(self) -> int:
        return self.palette_cols() * self.palette_cell() + 12

    def palette_surface(self):
        """The block picker: one cell per block, sized by `palette_cell` x UI scale.

        The blocks are rendered at their true 32 px first and then resized to the
        cell, so at a 32 px cell the preview is exact 1:1 pixels and larger cells
        are crisp integer-scaled pixels; smaller cells are a clean nearest-
        neighbour reduction rather than a blur.
        """
        cell = self.palette_cell()
        cols = self.palette_cols()
        rows = self.palette_rows()
        key = (cell, cols, self.palette_mode, self.nblocks)
        if self.pal_surf is None or self._pal_key != key:
            from PIL import Image
            img = Image.new("RGB", (cols * ts.BLOCK_PX,
                                    rows * ts.BLOCK_PX), (30, 30, 36))
            for b in range(self.nblocks):
                ts._blit_block(img, self.tiles, self.blocks, b,
                               b % cols, b // cols, self.colors)
            if cell != ts.BLOCK_PX:
                img = img.resize((cols * cell, rows * cell), Image.NEAREST)
            self.pal_surf = to_pygame(img, 1)
            self._pal_key = key
        return self.pal_surf

    def unused_blocks(self):
        """Block ids of this tileset that the composed map does not place anywhere.

        "Anywhere" is the whole padded grid: the map's own blocks, the connection
        strips copied from the neighbours, and the border ring. All three are on
        screen, so a block outside that set cannot change what this map looks
        like — which makes it a safe candidate to repurpose into a different
        graphic when the tileset is full or a tile needs swapping.

        It is a per-map answer, not a per-tileset one: the same block can be
        unused here and load-bearing three maps away.
        """
        used = set(self.cm.grid)
        return [b for b in range(self.nblocks) if b not in used]

    def palette_click(self, pos) -> bool:
        x0 = self.screen.get_width() - self.palette_width()
        if not self.paint or pos[0] < x0 + 6:
            return False
        cell = self.palette_cell()
        b = ((pos[1] - 6) // cell) * self.palette_cols() \
            + (pos[0] - x0 - 6) // cell
        if 0 <= b < self.nblocks:
            self.current_block = b
        return True

    def object_fields(self):
        """Dropdown values from the generator's supported constants."""
        return {'sprite': sorted(pm.gmh._SPRITE_CONSTS),
                'movement': ['WALK', 'STAY'],
                'facing': ['ANY_DIR', 'UP_DOWN', 'LEFT_RIGHT', 'DOWN',
                           'UP', 'LEFT', 'RIGHT', 'NONE', 'BOULDER_MOVEMENT_BYTE_2']}

    def object_panel_click(self, pos):
        if self.paint or not self.selected_object:
            return False
        geo = self.panel_geo()
        left = self.screen.get_width() - geo['w']
        if pos[0] < left or pos[1] >= geo['h']:
            return False
        if self.object_menu:
            index = (pos[1] - geo['list']) // geo['item_h'] + self.menu_offset
            options = self.object_fields()[self.object_menu]
            list_end = geo['list'] + geo['item_h'] * 12
            if geo['list'] <= pos[1] < list_end and 0 <= index < len(options):
                from map_editor import commands
                try:
                    commands.set_object(self.cm.info.const, self.selected_object,
                                        write=True, **{self.object_menu: options[index]})
                    self.cm.sprites = pm.objects(self.cm.info)[3]
                    self.dirty = True
                    self.save_error = ''
                except (ValueError, OSError) as exc:
                    self.save_error = str(exc)
                self.object_menu = None
                return True
        row_end = geo['rows'] + geo['row_h'] * 3
        if geo['rows'] <= pos[1] < row_end:
            self.object_menu = ('sprite', 'movement', 'facing')[
                (pos[1] - geo['rows']) // geo['row_h']]
            self.menu_offset = 0
        else:
            self.object_menu = None
        return True

    def draw_route_overlay(self, ox, oy, z):
        """Draw recognized movement streams as onion skins.

        NPCMV1 = first walker, NPCMV2 = second walker of a MoveSprite2 pair,
        NPCMV12 = a cell both streams visit. Anchors come from the sprite slot
        the script arms (slot N is the map's Nth object, 1-based), falling back
        to the selected NPC when the call site does not name one.
        """
        from map_editor import routes, scripts
        route = self.route_options[self.route_index]
        pair = route.get('pair')
        group = [r for r in self.route_options
                 if pair is not None and r.get('pair') == pair] or [route]
        colors = {0: NPCMV1, 1: NPCMV2}
        traces = {}
        for member in group:
            anchor = self.route_anchor(member)
            if anchor is None:
                continue
            channel = member.get('channel') or 0
            traces[channel] = routes.preview(
                scripts.TileYX(anchor[0], anchor[1]),
                routes.decode(bytes(member['bytes'])))
        seen = {}
        for channel, trace in traces.items():
            points = [(ox + (p.x + view.BORDER * 4 + 1) * TILE * z,
                       oy + (p.y + view.BORDER * 4 + 1) * TILE * z) for p in trace]
            if len(points) > 1:
                pygame.draw.lines(self.screen, colors[channel], False, points, 3)
            for point in points:
                pygame.draw.circle(self.screen, colors[channel], point, max(2, 2 * z))
            for cell in trace:
                seen.setdefault((cell.y, cell.x), []).append(channel)
        for (y, x), channels in seen.items():
            if len(channels) > 1:
                px = ox + (x + view.BORDER * 4 + 1) * TILE * z
                py = oy + (y + view.BORDER * 4 + 1) * TILE * z
                pygame.draw.rect(self.screen, NPCMV12, (px - 2, py - 2, 4, 4))
        overlap = [cell for cell, channels in seen.items() if len(channels) > 1]
        if overlap:
            y, x = overlap[0]
            px = ox + (x + view.BORDER * 4 + 1) * TILE * z
            py = oy + (y + view.BORDER * 4 + 1) * TILE * z
            self.screen.blit(self.font.render('NPCMV12', True, NPCMV12), (px + 6, py - 14))

    def route_anchor(self, route):
        """(y, x) 8px-tile anchor for a stream, from its sprite slot."""
        slot = route.get('slot')
        if isinstance(slot, int) and 1 <= slot <= len(self.cm.sprites):
            return tuple(self.cm.sprites[slot - 1]['trace']['final'])
        if self.selected_object:
            actor = next((s for s in self.cm.sprites
                          if s['stable_id'] == self.selected_object), None)
            if actor:
                return tuple(actor['trace']['final'])
        return None

    def draw_object_panel(self):
        if self.paint or not self.selected_object:
            return
        npc = next((s for s in self.cm.sprites if s['stable_id'] == self.selected_object), None)
        if not npc:
            return
        geo = self.panel_geo()
        x = self.screen.get_width() - geo['w']
        panel = pygame.Surface((geo['w'], geo['h']), pygame.SRCALPHA)
        panel.fill((25, 25, 33, 225))
        panel.blit(self.font.render('NPC properties (saved on select)', True,
                                    (255, 255, 255)), (geo['pad'], 2))
        tables = self.object_fields()
        for index, (field, key, values) in enumerate((
                ('sprite', 'sprite_id', pm.gmh._SPRITE_CONSTS),
                ('movement', 'mov', pm.gmh._MOV_CONSTS),
                ('facing', 'dir', pm.gmh._DIR_CONSTS))):
            name = next((s for s in tables[field] if values.get(s) == npc[key]), str(npc[key]))
            top = geo['rows'] + index * geo['row_h']
            pygame.draw.rect(panel, (65, 65, 78),
                             (geo['pad'] - 2, top, geo['w'] - 2 * geo['pad'] + 4,
                              geo['row_h'] - 2))
            # Source field "facing" is movement byte 2, not initial facing.
            # Pret zeroes sprite state on load, then this byte constrains motion.
            display = 'movement rule' if field == 'facing' else field
            panel.blit(self.font.render(f'{display}: {name} ▾', True, (235, 235, 235)),
                       (geo['pad'], top + 1))
        if self.object_menu:
            for i, name in enumerate(tables[self.object_menu][self.menu_offset:self.menu_offset + 12]):
                top = geo['list'] + i * geo['item_h']
                pygame.draw.rect(panel, (55, 60, 76),
                                 (geo['pad'] - 2, top, geo['w'] - 2 * geo['pad'] + 4,
                                  geo['item_h'] - 1))
                panel.blit(self.font.render(name, True, (235, 235, 235)),
                           (geo['pad'], top + 1))
            panel.blit(self.font.render('Mouse wheel: scroll', True, (220, 220, 220)),
                       (geo['pad'], geo['h'] - geo['item_h'] * 2))
        if self.route_index >= 0:
            self.draw_route_timeline(panel, geo)
        self.screen.blit(panel, (x, 0))

    def draw_route_timeline(self, panel, geo):
        """Compact step timeline for the selected stream: [ ] navigate, 1-4 edit."""
        route = self.route_options[self.route_index]
        operations = route['operations']
        s = self.ui_scale()
        size = max(6, int(round(12 * s)))
        gap = max(1, int(round(2 * s)))
        columns = max(1, (geo['w'] - 2 * geo['pad'] + gap) // (size + gap))
        top0 = geo['rows'] + 4 * geo['row_h']
        panel.blit(self.font.render(f"Route {route['label'][:34]}", True,
                                    (235, 235, 235)), (geo['pad'], top0))
        grid_top = top0 + self.font.get_linesize()
        limit = geo['h'] - geo['item_h'] * 3
        for i, op in enumerate(operations):
            row, col = divmod(i, columns)
            left = geo['pad'] + col * (size + gap)
            top = grid_top + row * (size + gap)
            if top > limit:
                panel.blit(self.font.render(f'+{len(operations) - i} more', True,
                                            (200, 200, 200)), (left, top))
                break
            if op['kind'] in ('step', 'quick_step'):
                color = (110, 190, 255) if op['kind'] == 'step' else (90, 150, 210)
            elif op['kind'] == 'end':
                color = (90, 90, 100)
            else:
                color = (230, 150, 60)
            pygame.draw.rect(panel, color, (left, top, size, size))
            if i == self.route_step:
                pygame.draw.rect(panel, (255, 255, 255),
                                 (left - 1, top - 1, size + 2, size + 2), 1)
        if operations:
            current = operations[self.route_step]
            label = f"{self.route_step + 1}/{len(operations)} {current['kind']}"
            if current['direction']:
                label += f" {current['direction']}"
            panel.blit(self.font.render(label, True, (235, 235, 235)),
                       (geo['pad'], geo['h'] - geo['item_h'] * 2 - 4))

    def edit_route_step(self, direction):
        """Edit an existing recognized move without changing the stream length."""
        from map_editor import commands, routes
        if self.route_index < 0 or not self.route_sha:
            return
        route = self.route_options[self.route_index]
        values = list(route['bytes'])
        if not (0 <= self.route_step < len(values) - 1):
            return
        op = routes.decode(bytes(values))[self.route_step]
        if op.kind not in ('step', 'quick_step'):
            self.save_error = 'Selected route operation is not a recognized movement step'
            return
        table = ((0x00, 0x40, 0x80, 0xC0) if op.kind == 'step'
                 else (0x04, 0x05, 0x06, 0x07))
        values[self.route_step] = table[direction]
        try:
            result = commands.set_route(self.cm.info.const, route['label'], self.route_sha,
                                        values, write=True)
            for warning in result['diagnostics']:
                print(f'ROUTE: {warning}')
            scanned = commands.scan_routes(self.cm.info.const)
            self.route_options, self.route_sha = scanned['routes'], scanned['sha256']
            self.route_index = next(i for i, item in enumerate(self.route_options)
                                    if item['label'] == route['label'])
            self.dirty = True
            self.save_error = ''
        except (ValueError, OSError, StopIteration) as exc:
            self.save_error = str(exc)

    # ── drawing ──────────────────────────────────────────────────────────────

    def connection_surface(self):
        """Neighbouring maps assembled at their real connection offsets.

        Cached per scale: the assembly is static until the map or its sidecar
        changes, so scrolling must not rebuild it.
        """
        if self.conn_view is None:
            self.conn_view = view.compose_connections(self.cm.info.const)
        if self.conn_surf is None or self.conn_scale != self.scale:
            img = view.render_grid(self.conn_view.info, self.conn_view.grid,
                                   self.conn_view.stride, self.conn_view.rows,
                                   self.colors)
            self.conn_surf = to_pygame(img, self.scale)
            self.conn_scale = self.scale
        return self.conn_surf

    def connection_offset(self, z):
        """Screen offset that puts the assembly on the map raster's padded coords.

        The assembly canvas is shifted by however far a neighbour overflows the
        border ring, so undo that shift. With this applied, the neighbour blocks
        land exactly where compose_padded already put the connection strips —
        which is the whole point: the seam can be inspected, not inferred.
        """
        cv = self.conn_view
        return ((view.BORDER - cv.origin[1]) * ts.BLOCK_PX * z,
                (view.BORDER - cv.origin[0]) * ts.BLOCK_PX * z)

    def map_core_surface(self):
        """The current map's own blocks only — no border ring.

        In connections mode the ring is exactly what the neighbour maps are there
        to fill, so drawing the padded raster (which paints border blocks over the
        ring) would hide the seam being inspected.
        """
        if getattr(self, '_core_surf', None) is not None and self._core_scale == self.scale:
            return self._core_surf
        info = self.cm.info
        core = bytearray(info.w * info.h)
        for y in range(info.h):
            src = (y + view.BORDER) * self.cm.stride + view.BORDER
            core[y * info.w:(y + 1) * info.w] = self.cm.grid[src:src + info.w]
        img = view.render_grid(info, core, info.w, info.h, self.colors)
        self._core_surf = to_pygame(img, self.scale)
        self._core_scale = self.scale
        return self._core_surf

    def connection_at_player(self):
        """Which connected map the staged player tile is standing at the edge of.

        A hint for watching a transition: the band is one block (4 tiles) inside
        each edge, matching how the port's connection strips are laid out.
        """
        if self.player is None:
            return None
        x, y = self.player
        info = self.cm.info
        band = 4
        edges = []
        if y < band:
            edges.append("NORTH")
        if y >= info.h * 4 - band:
            edges.append("SOUTH")
        if x < band:
            edges.append("WEST")
        if x >= info.w * 4 - band:
            edges.append("EAST")
        for direction, nconst, offset in pm.CONNECTIONS.get(self.cm.info.const, []):
            if direction in edges:
                return f"{direction} -> {nconst} (offset {offset:+d})"
        return None

    def blit_connections(self, ox, oy, z):
        """Neighbours under the map, then the map's own blocks over its footprint."""
        cv = self.conn_view
        if cv is None:
            cv = self.conn_view = view.compose_connections(self.cm.info.const)
        off_x, off_y = self.connection_offset(z)
        self.screen.blit(self.connection_surface(), (ox + off_x, oy + off_y))
        self.screen.blit(self.map_core_surface(),
                         (ox + view.BORDER * ts.BLOCK_PX * z,
                          oy + view.BORDER * ts.BLOCK_PX * z))

    def draw_connection_outlines(self, ox, oy, z):
        cv = self.conn_view
        if cv is None:
            return
        off_x, off_y = self.connection_offset(z)
        own = (int(round(ox + (cv.origin[1] * ts.BLOCK_PX) * z + off_x)),
               int(round(oy + (cv.origin[0] * ts.BLOCK_PX) * z + off_y)),
               int(round(cv.info.w * ts.BLOCK_PX * z)),
               int(round(cv.info.h * ts.BLOCK_PX * z)))
        pygame.draw.rect(self.screen, CONN_SELF, own, 2)
        for entry in cv.neighbours:
            r, c = entry['canvas_origin']
            rect = (int(round(ox + (c * ts.BLOCK_PX) * z + off_x)),
                    int(round(oy + (r * ts.BLOCK_PX) * z + off_y)),
                    int(round(entry['w'] * ts.BLOCK_PX * z)),
                    int(round(entry['h'] * ts.BLOCK_PX * z)))
            pygame.draw.rect(self.screen, CONN_OTHER, rect, 1)
            label = self.font.render(
                f"{entry['direction']} {entry['const']} ({entry['offset']:+d})",
                True, CONN_OTHER)
            lx = max(0, rect[0] + max(3, (rect[2] - label.get_width()) // 2))
            ly = max(0, min(self.screen.get_height() - self.panel_h() - 18,
                            rect[1] + 3))
            chip = pygame.Surface((label.get_width() + 4, label.get_height()),
                                  pygame.SRCALPHA)
            chip.fill((0, 0, 0, 170))
            chip.blit(label, (2, 0))
            self.screen.blit(chip, (lx, ly))
        for i, note in enumerate(cv.anomalies):
            self.screen.blit(self.font.render(note[:96], True, (255, 170, 90)),
                             (8, self.screen.get_height() - self.panel_h() - 18 - i * 16))

    def finish_warp_drag(self, pos):
        """Drop a dragged warp on the tile under the cursor.

        Warps address 16px map squares, so the landing tile is snapped to an even
        tile coordinate; `set_warp` re-checks that and the byte range.
        """
        from map_editor import commands
        tile = self.tile_at(pos)
        if tile is None:
            return
        try:
            commands.set_warp(self.cm.info.const, self.warp_drag, write=True,
                              y=tile[1] // 2 * 2, x=tile[0] // 2 * 2)
            self.cm.warps = pm.objects(self.cm.info)[1]
            self.dirty = True
            self.save_error = ''
        except (ValueError, OSError) as exc:
            self.save_error = str(exc)

    def draw_warp_skin(self, px, py, z, ox, oy, selected):
        """Translucent onion skin over a warp block with a centred W.

        The fill marks the 2x2 map square the warp occupies; the letter is drawn
        with the HUD font rather than scaled pixel art, so it stays legible at any
        zoom.
        """
        w = max(1, int(round(TILE * 2 * z)))
        h = max(1, int(round(TILE * 2 * z)))
        sx, sy = int(round(ox + px * z)), int(round(oy + py * z))
        skin = pygame.Surface((w, h), pygame.SRCALPHA)
        skin.fill((*MARK_WARP, 110))
        self.screen.blit(skin, (sx, sy))
        pygame.draw.rect(self.screen, MARK_WARP, (sx, sy, w, h),
                         2 if selected else 1)
        # The glyph needs its own contrast: a plain white W vanishes over light
        # tiles (doors, floors) and a plain dark one vanishes over dark tiles.
        glyph = self.font.render('W', True, (255, 255, 255))
        chip = pygame.Surface((glyph.get_width() + 2, glyph.get_height()),
                              pygame.SRCALPHA)
        chip.fill((10, 30, 36, 200))
        chip.blit(glyph, (1, 0))
        self.screen.blit(chip, (sx + (w - chip.get_width()) // 2,
                                sy + (h - chip.get_height()) // 2))

    def draw_triggers(self, ox, oy, z):
        """Mark the tiles that fire a script when the player stands on them.

        Source coords are game map squares (16 px); the editor draws in 8 px
        tiles, so they double here — the same conversion every other adapter
        does. A marker is one map square, not a block: the player triggers it by
        standing on that square.
        """
        if not self.triggers:
            return
        side = max(2, int(round(TILE * 2 * z)))
        for trigger in self.triggers:
            for coord in trigger['coords']:
                px, py = view.warp_px(self.cm, coord['y'] * 2, coord['x'] * 2)
                sx, sy = int(round(ox + px * z)), int(round(oy + py * z))
                pygame.draw.rect(self.screen, TRIGGER_TILE, (sx, sy, side, side), 2)
                glyph = self.font.render('T', True, TRIGGER_TILE)
                chip = pygame.Surface((glyph.get_width() + 2, glyph.get_height()),
                                      pygame.SRCALPHA)
                chip.fill((10, 20, 30, 190))
                chip.blit(glyph, (1, 0))
                self.screen.blit(chip, (sx + (side - chip.get_width()) // 2,
                                        sy + (side - chip.get_height()) // 2))

    def draw_reach(self, ox, oy, z):
        """The viewable union: amber = DOS-only cells showing real map data.

        `U` floods the walkable area from the probe. The union of the camera
        window over those steps is everything the map can ever put on screen;
        the part the GB's 160x144 window never showed is the seam-audit band.
        Border-clamp fill past the map edge is excluded — it is not a seam.
        """
        if self.reach is None:
            return
        width, height = self.screen.get_size()
        if self._reach_surf is None or self._reach_surf.get_size() != (width, height):
            self._reach_surf = pygame.Surface((width, height), pygame.SRCALPHA)
        surf = self._reach_surf
        surf.fill((0, 0, 0, 0))
        span = max(1, int(round(view.SWEEP_CELL * z)))
        for runs, alpha in ((self._border_runs, 45), (self._reach_runs, 90)):
            colour = (*REACH_BAND, alpha)
            for (x, y, run) in runs:
                surf.fill(colour, (int(round(ox + x * z)),
                                   int(round(oy + y * z)),
                                   max(1, int(round(run * z))), span))
        self.screen.blit(surf, (0, 0))
        # The two unions the band is derived from, as their shared boundary.
        for kind, colour in (("dos", PORT_VIEW), ("gb", GB_VIEW)):
            hit = self._reach_outline.get(kind)
            if hit is None:
                continue
            x0, y0, horizontal, vertical = hit
            for (r, c0, c1) in horizontal:
                pygame.draw.line(
                    self.screen, colour,
                    (int(round(ox + (x0 + c0) * z)), int(round(oy + (y0 + r) * z))),
                    (int(round(ox + (x0 + c1) * z)), int(round(oy + (y0 + r) * z))), 1)
            for (c, r0, r1) in vertical:
                pygame.draw.line(
                    self.screen, colour,
                    (int(round(ox + (x0 + c) * z)), int(round(oy + (y0 + r0) * z))),
                    (int(round(ox + (x0 + c) * z)), int(round(oy + (y0 + r1) * z))), 1)

    def draw_probe(self, ox, oy, z):
        """Box what the camera shows from the probed step(s).

        `V` is the port's 320x200 window (red), `H` the GB's 160x144 one (blue);
        either, both or neither. With a swept path the outline is the UNION along
        it — everything that is on screen at some point while walking that route.
        The anchor is the player's 16 px step, so the boxes are always positioned
        from a legal player position.
        """
        steps = self.probe_steps()
        if not steps:
            return

        # Everything below is in padded-image PIXELS, so a window whose centre
        # falls on a half tile (the DOS window is 200 px = 12.5 tiles tall) still
        # lands exactly on the step's centre.
        def edge(x0, y0, x1, y1, color, width):
            pygame.draw.line(
                self.screen, color,
                (int(round(ox + x0 * z)), int(round(oy + y0 * z))),
                (int(round(ox + x1 * z)), int(round(oy + y1 * z))), width)

        def box(x, y, w, h, color, width):
            pygame.draw.rect(
                self.screen, color,
                (int(round(ox + x * z)), int(round(oy + y * z)),
                 max(1, int(round(w * z))), max(1, int(round(h * z)))), width)

        for kind, enabled, color in (("dos", self.show["port_view"], PORT_VIEW),
                                     ("gb", self.show["gb_view"], GB_VIEW)):
            if not enabled:
                continue
            x0, y0, horizontal, vertical = self.probe_sweep(kind)
            for (r, c0, c1) in horizontal:
                edge(x0 + c0, y0 + r, x0 + c1, y0 + r, color, 2)
            for (c, r0, r1) in vertical:
                edge(x0 + c, y0 + r0, x0 + c, y0 + r1, color, 2)

        if self.show["render_reach"] and self.player:
            _win, sur = view.viewport_rect(self.cm, self.player[1],
                                           self.player[0])
            box(*sur, RENDER_REACH, 1)
        if self.player:
            px = (self.player[0] + view.BORDER * 4) * TILE
            py = (self.player[1] + view.BORDER * 4) * TILE
            box(px, py, TILE * 2, TILE * 2, (255, 100, 190), 2)
            self.screen.blit(self.font.render('PT', True, (255, 100, 190)),
                             (ox + px * z, oy + py * z))

    def draw_warp_drag_ghost(self, ox, oy, z):
        """Show where a dragged warp would land (snapped to its 2x2 map square)."""
        if not self.warp_drag or not self.cursor_tile:
            return
        tx, ty = self.cursor_tile
        px = (tx // 2 * 2 + view.BORDER * 4) * TILE
        py = (ty // 2 * 2 + view.BORDER * 4) * TILE
        w = max(1, int(round(TILE * 2 * z)))
        h = max(1, int(round(TILE * 2 * z)))
        rect = (int(round(ox + px * z)), int(round(oy + py * z)), w, h)
        ghost = pygame.Surface((w, h), pygame.SRCALPHA)
        ghost.fill((*MARK_WARP, 60))
        self.screen.blit(ghost, rect[:2])
        pygame.draw.rect(self.screen, MARK_WARP, rect, 2)

    def warp_at_tile(self, tile):
        """The warp whose 2x2 map square contains an editor tile, if any."""
        if tile is None:
            return None
        tx, ty = tile
        for warp in self.cm.warps:
            if (warp['x'] * 2 <= tx < warp['x'] * 2 + 2
                    and warp['y'] * 2 <= ty < warp['y'] * 2 + 2):
                return warp
        return None

    def warp_fields(self):
        """Dropdown values for the warp properties panel."""
        return {'dest': sorted(pm.all_map_consts()) + ['LAST_MAP'],
                'warp_id': [str(i) for i in range(1, 17)],
                'kind': list(objects.WARP_KINDS)}

    def draw_warp_panel(self):
        """Warp properties: destination map, target warp id and kind.

        Same panel geometry as the NPC panel so the two read as one UI. `kind` is
        labelled as editor metadata because pret has no warp-type byte — it is not
        written into the generated map header.
        """
        if self.paint or not self.selected_warp:
            return
        warp = next((w for w in self.cm.warps
                     if w['stable_id'] == self.selected_warp), None)
        if not warp:
            return
        geo = self.panel_geo()
        x = self.screen.get_width() - geo['w']
        panel = pygame.Surface((geo['w'], geo['h']), pygame.SRCALPHA)
        panel.fill((25, 25, 33, 225))
        panel.blit(self.font.render('Warp properties (saved on select)', True,
                                    (255, 255, 255)), (geo['pad'], 2))
        rows = (('dest', f"dest: {warp['dest']}"),
                ('warp_id', f"target warp: {warp['warp_id']}"),
                ('kind', f"kind: {warp['kind'] or '(unset)'}"))
        for index, (field, text) in enumerate(rows):
            top = geo['rows'] + index * geo['row_h']
            pygame.draw.rect(panel, (65, 65, 78),
                             (geo['pad'] - 2, top, geo['w'] - 2 * geo['pad'] + 4,
                              geo['row_h'] - 2))
            panel.blit(self.font.render(text + ' ▾', True, (235, 235, 235)),
                       (geo['pad'], top + 1))
        panel.blit(self.font.render(f"at (Y:{warp['y']*2}, X:{warp['x']*2}) tiles",
                                    True, (200, 200, 200)),
                   (geo['pad'], geo['rows'] + 3 * geo['row_h']))
        if self.warp_menu:
            options = self.warp_fields()[self.warp_menu]
            for i, name in enumerate(options[self.warp_menu_offset:
                                             self.warp_menu_offset + 12]):
                top = geo['list'] + i * geo['item_h']
                pygame.draw.rect(panel, (55, 60, 76),
                                 (geo['pad'] - 2, top, geo['w'] - 2 * geo['pad'] + 4,
                                  geo['item_h'] - 1))
                panel.blit(self.font.render(name, True, (235, 235, 235)),
                           (geo['pad'], top + 1))
            panel.blit(self.font.render('Mouse wheel: scroll', True,
                                        (220, 220, 220)),
                       (geo['pad'], geo['h'] - geo['item_h'] * 3))
        panel.blit(self.font.render('kind is editor metadata, not emitted',
                                    True, (200, 190, 150)),
                   (geo['pad'], geo['h'] - geo['item_h'] - 4))
        self.screen.blit(panel, (x, 0))

    def warp_panel_click(self, pos) -> bool:
        if self.paint or not self.selected_warp:
            return False
        geo = self.panel_geo()
        left = self.screen.get_width() - geo['w']
        if pos[0] < left or pos[1] >= geo['h']:
            return False
        options = self.warp_fields()
        if self.warp_menu:
            index = (pos[1] - geo['list']) // geo['item_h'] + self.warp_menu_offset
            values = options[self.warp_menu]
            list_end = geo['list'] + geo['item_h'] * 12
            if geo['list'] <= pos[1] < list_end and 0 <= index < len(values):
                self.apply_warp_field(self.warp_menu, values[index])
                self.warp_menu = None
                return True
        row_end = geo['rows'] + geo['row_h'] * 3
        if geo['rows'] <= pos[1] < row_end:
            self.warp_menu = ('dest', 'warp_id', 'kind')[
                (pos[1] - geo['rows']) // geo['row_h']]
            self.warp_menu_offset = 0
        else:
            self.warp_menu = None
        return True

    def apply_warp_field(self, field, value):
        from map_editor import commands
        kwargs = {'dest': 'dest', 'warp_id': 'target_warp', 'kind': 'kind'}[field]
        if field == 'warp_id':
            value = int(value)
        try:
            commands.set_warp(self.cm.info.const, self.selected_warp,
                              write=True, **{kwargs: value})
            self.cm.warps = pm.objects(self.cm.info)[1]
            self.dirty = True
            self.save_error = ''
        except (ValueError, OSError) as exc:
            self.save_error = str(exc)

    def panel_geo(self) -> dict:
        """Metrics for the right-hand properties panel, in pixels.

        Derived from the live font so the panel keeps working when the UI scale
        changes on a window resize: rows that assume a 13 px font overlap as soon
        as the font grows.
        """
        s = self.ui_scale()
        line = self.font.get_linesize()
        return {'w': self.ui_panel_width(),
                'h': int(round(400 * s)),
                'pad': max(3, int(round(6 * s))),
                'rows': int(round(20 * s)),      # first row's top
                'row_h': line + 8,               # dropdown rows
                'list': int(round(94 * s)),      # first dropdown item's top
                'item_h': line + 6}

    @property
    def font(self):
        """HUD font at the current UI scale (cheap: recreated only on resize)."""
        size = max(9, int(round(13 * self.ui_scale())))
        if self._font_size != size:
            self._font = pygame.font.SysFont("monospace", size)
            self._font_size = size
        return self._font

    def ui_scale(self) -> float:
        """UI chrome scale, driven by the window size so it follows a resize.

        `ui_scale` in config.json is either "auto" (the default: derive from the
        window) or a number (pin it). The auto formula uses the SMALLER of the two
        axis ratios against the reference window, so a short window shrinks the
        chrome instead of letting it overflow — text growing past the bottom bar
        is worse than text being small.
        """
        width, height = self.screen.get_width(), self.screen.get_height()
        if self._ui_key == (width, height):
            return self._ui_value
        setting = self.settings.get('ui_scale', 'auto')
        low = self.settings['ui_scale_min']
        high = self.settings['ui_scale_max']
        if setting == 'auto':
            ref_w, ref_h = self.settings['ui_reference']
            value = min(width / ref_w, height / ref_h)
        else:
            value = float(setting)
        self._ui_value = max(low, min(high, value))
        self._ui_key = (width, height)
        return self._ui_value

    def panel_h(self) -> int:
        return max(PANEL_H, int(round(PANEL_H * self.ui_scale())))

    def ui_panel_width(self) -> int:
        return int(round(290 * self.ui_scale()))

    def draw(self):
        self.screen.fill((24, 24, 28))
        z = self.scale
        ox, oy = self.pan
        if self.show["connections"]:
            # Neighbours first, so the current map's raster draws over the seam.
            self.blit_connections(ox, oy, z)
        else:
            self.screen.blit(self.surface(), self.pan)

        def rect_px(x, y, w, h, color, width=1):
            pygame.draw.rect(self.screen, color,
                             (int(round(ox + x * z)), int(round(oy + y * z)),
                              max(1, int(round(w * z))),
                              max(1, int(round(h * z)))), width)

        if self.paint:
            # dim the locked connection strips; badge painted cells
            # (ring = pink, real-map overrides = cyan)
            dim_w = max(1, int(round(ts.BLOCK_PX * z)))
            dim = pygame.Surface((dim_w, dim_w), pygame.SRCALPHA)
            dim.fill(LOCKED_DIM)
            tints = {}
            for const, colour in self.strip_colors().items():
                surf = pygame.Surface((dim_w, dim_w), pygame.SRCALPHA)
                surf.fill((*colour, 40))
                tints[const] = surf
            for idx in self.cm.strip_cells:
                bx, by = idx % self.cm.stride, idx // self.cm.stride
                owner = self.cm.strip_owner.get(idx)
                surf = dim if owner is None else tints[owner[0]]
                self.screen.blit(surf, (int(round(ox + bx * ts.BLOCK_PX * z)),
                                        int(round(oy + by * ts.BLOCK_PX * z))))
            for (r, c) in self.cells:
                rect_px(c * ts.BLOCK_PX, r * ts.BLOCK_PX,
                        ts.BLOCK_PX, ts.BLOCK_PX, PAINTED, 2)
            b = view.BORDER
            for (y, x) in self.map_cells:
                rect_px((x + b) * ts.BLOCK_PX, (y + b) * ts.BLOCK_PX,
                        ts.BLOCK_PX, ts.BLOCK_PX, MAP_PAINTED, 2)

        if self.show["connections"]:
            self.draw_connection_outlines(ox, oy, z)
        if self.show["steps"]:
            # ONE CELL PER MOVEMENT STEP (16 px). This is the grid that matches how
            # NPC/warp/script coordinates are counted, so it is the default. The
            # 32 px block grid is a separate toggle because a .blk cell is 2x2
            # steps — useful for map data, useless for judging a step.
            for sx in range(0, self.cm.stride * 4 + 1, 2):
                x = ox + sx * TILE * z
                pygame.draw.line(self.screen, GRID_STEP, (x, oy),
                                 (x, oy + self.img.height * z))
            for sy in range(0, self.cm.rows * 4 + 1, 2):
                y = oy + sy * TILE * z
                pygame.draw.line(self.screen, GRID_STEP, (ox, y),
                                 (ox + self.img.width * z, y))
        if self.show["blocks"]:
            for bx in range(self.cm.stride + 1):
                x = ox + bx * ts.BLOCK_PX * z
                pygame.draw.line(self.screen, GRID_BLOCK, (x, oy),
                                 (x, oy + self.img.height * z))
            for by in range(self.cm.rows + 1):
                y = oy + by * ts.BLOCK_PX * z
                pygame.draw.line(self.screen, GRID_BLOCK, (ox, y),
                                 (ox + self.img.width * z, y))
        if self.show["tiles"]:
            for tx in range(0, self.cm.stride * 4 + 1):
                x = ox + tx * TILE * z
                pygame.draw.line(self.screen, GRID_TILE, (x, oy),
                                 (x, oy + self.img.height * z))
            for ty in range(0, self.cm.rows * 4 + 1):
                y = oy + ty * TILE * z
                pygame.draw.line(self.screen, GRID_TILE, (ox, y),
                                 (ox + self.img.width * z, y))
        if self.show["warps"]:
            for warp in self.cm.warps:
                px, py = view.warp_px(self.cm, warp['y'], warp['x'])
                selected = warp['stable_id'] == self.selected_warp
                self.draw_warp_skin(px, py, z, ox, oy, selected)
            for sign in self.cm.signs:
                px, py = view.warp_px(self.cm, sign['y'], sign['x'])
                rect_px(px, py, TILE * 2, TILE * 2, (255, 220, 80), 2)
        if self.show["npcs"]:
            for s in self.cm.sprites:
                px, py = view.sprite_px(self.cm, s["mapy"], s["mapx"])
                thumbnail = sprites.thumbnail(s['sprite_id'], tuple(self.colors))
                if thumbnail is not None:
                    surf = pygame.image.fromstring(thumbnail.tobytes(), thumbnail.size, 'RGBA')
                    if z != 1:
                        surf = pygame.transform.scale(surf, (16 * z, 16 * z))
                    self.screen.blit(surf, (ox + px * z, oy + py * z))
                color = MARK_TRAINER if s["is_trainer"] else \
                    MARK_ITEM if s["is_item"] else MARK_NPC
                rect_px(px, py, TILE * 2, TILE * 2, color, 2)
                if s['stable_id'] == self.selected_object:
                    rect_px(px - 1, py - 1, TILE * 2 + 2, TILE * 2 + 2, (255, 255, 255), 1)
        if self.show["triggers"]:
            self.draw_triggers(ox, oy, z)
        if self.route_index >= 0:
            self.draw_route_overlay(ox, oy, z)
        self.draw_reach(ox, oy, z)
        self.draw_probe(ox, oy, z)

        if self.paint:
            width = self.palette_width()
            cell = self.palette_cell()
            x0 = self.screen.get_width() - width
            pygame.draw.rect(self.screen, (40, 40, 48),
                             (x0, 0, width, self.screen.get_height()))
            self.screen.blit(self.palette_surface(), (x0 + 6, 6))
            b = self.current_block
            cols = self.palette_cols()
            # Onion-skin every block this map does not place: the swatch stays
            # readable underneath, so the palette still works while telling you
            # which ids are free to repurpose.
            unused = self.unused_blocks()
            if unused:
                if self._unused_skin is None or self._unused_skin.get_size() != (cell, cell):
                    self._unused_skin = pygame.Surface((cell, cell), pygame.SRCALPHA)
                    self._unused_skin.fill(PALETTE_UNUSED)
                for u in unused:
                    self.screen.blit(self._unused_skin,
                                     (x0 + 6 + (u % cols) * cell,
                                      6 + (u // cols) * cell))
            pygame.draw.rect(
                self.screen, SEL_BLOCK,
                (x0 + 6 + (b % cols) * cell,
                 6 + (b // cols) * cell, cell, cell), 2)
            self._unused_count = len(unused)

        self.draw_warp_drag_ghost(ox, oy, z)
        self.draw_hud()
        self.draw_object_panel()
        self.draw_warp_panel()
        state = "*UNSAVED* Ctrl+S" if self.dirty else "saved"
        lock = f" LOCK {self.lock_axis}" if self.lock_axis else ""
        mode = (f"PAINT block 0x{self.current_block:02X} "
                f"{len(self.cells)} cells {state}{lock} | [F]ill Ctrl+Z"
                if self.paint else
                f"{state} | [G]step grid [B]lock grid [T]iles [W]arps [N]pcs "
                "[V/H/R] frames [Y]probe [I]nspect [C]olor [O] route [X]conn")
        info = (f"{self.cm.info.const}  warps:{len(self.cm.warps)} "
                f"npcs:{len(self.cm.sprites)}  [P]aint  {mode}")
        if self.save_error:
            info = f"SAVE REFUSED: {self.save_error[:80]}"
        bar = pygame.Surface((self.screen.get_width(), self.panel_h()))
        bar.fill((40, 40, 48))
        bar.blit(self.font.render(info[:120], True,
                                  (255, 120, 120) if self.save_error
                                  else (220, 220, 220)), (8, 4))
        self.screen.blit(bar, (0, self.screen.get_height() - self.panel_h()))
        pygame.display.flip()

    def draw_hud(self):
        """Persistent top-left final-coordinate HUD; I expands its trace view."""
        cursor = "F: —"
        block = ""
        if self.cursor_tile:
            x, y = self.cursor_tile
            bx, by = x // 4, y // 4
            cursor = f"F (Y:{y}, X:{x})"
            idx = (by + view.BORDER) * self.cm.stride + bx + view.BORDER
            block = f" B(Y:{by},X:{bx})=${self.cm.grid[idx]:02X}"
            owner = self.cm.strip_owner.get(idx)
            if owner is not None:
                # Strip cells are the neighbour's blocks: say whose, so an edit
                # made here is never a surprise write to another map.
                const, oy, ox_ = owner
                block += f" ← {const}(Y:{oy},X:{ox_})"
        layers = " ".join(name for name, enabled in (
            ("PROBE", self.probe_mode),
            ("STEP", self.show["steps"]), ("BLK", self.show["blocks"]),
            ("TILE", self.show["tiles"]),
            ("EVT", self.show["warps"]), ("NPC", self.show["npcs"]),
            ("TRG", self.show["triggers"]),
            ("PV", self.show["port_view"]), ("GB", self.show["gb_view"]),
            ("RR", self.show["render_reach"]),
            ("CONN", self.show["connections"])) if enabled)
        anchor = self.settings['zoom_anchor']
        lines = [f"{self.cm.info.const} id:${self.cm.info.map_id:02X}  {self.palette_name}",
                 f"Size W×H {self.cm.info.base_w}×{self.cm.info.base_h} → "
                 f"{self.cm.info.w}×{self.cm.info.h} B",
                 f"{cursor}{block}", f"Layers: {layers or '—'}",
                 f"Zoom {self.scale:.2f}x  anchor:{anchor} (Ctrl inverts)"]
        if self.probe:
            sy, sx = self.probe[-1]
            span = (f"Y:{sy} X:{sx}" if len(self.probe) == 1
                    else f"Y:{sy} X:{sx} sweep:{len(self.probe)}")
            lines.append(f"Probe {span}  V:DOS H:GB  shift-click clears"
                         + (f"  LOCK {self.lock_axis}" if self.lock_axis else ""))
        elif self.probe_mode:
            lines.append("Probe: click a step (shift-click clears)  V:DOS H:GB")
        if self.view_as is not None:
            info = pm.map_info(self.view_as)
            lines.append(f"View as {self.view_as} "
                         f"({info.tileset_name} · {palette.resolve(info)[0]})"
                         f"  K cycles  — this is a PREVIEW, edits still belong "
                         f"to {self.cm.info.const}")
        if self.look_stats is not None:
            s = self.look_stats
            # Two separate answers, because they have different causes: `real`
            # cells can only recolour (the strip is the neighbour's own bytes),
            # `border` cells change outright because each map has its own border
            # block and the port paints that fill across the whole band.
            lines.append(
                f"Swap at {s['const']}: real {s['real_changed']}/{s['real']} "
                f"(shape {s['shape']}, colour {s['colour']}) · "
                f"border {s['border_changed']}/{s['border']} "
                f"(${s['own_border']:02X} → ${s['other_border']:02X})")
        elif self.reach_stats is not None and self.view_as is None:
            lines.append("K: preview this map with a neighbour's tileset+palette")
        if self.triggers:
            # Squares, because that is what the source says; say so rather than
            # letting them be read as tiles or blocks.
            parts = [f"{t['label']} " + " ".join(f"({c['x']},{c['y']})"
                                                 for c in t['coords'])
                     for t in self.triggers]
            lines.append("Triggers (map squares): " + " | ".join(parts))
        if self.pick_mode:
            lines.append(f"PICK: click a cell to clone block "
                         f"${self.current_block:02X} into the palette  O cancels")
        if self.paint:
            lines.append(f"Palette: {self._unused_count} of {self.nblocks} blocks "
                         f"unused here (orange = free to repurpose)")
        if self.reach_stats is not None:
            steps, hops, dos, gb, attention, border = self.reach_stats
            # Units are load-bearing: 4 px cells, not tiles, so nobody reads the
            # numbers as a tile count. The border remainder is reported rather
            # than dropped — it is the DOS-only area that is not real map data.
            # "+N hop" is the mid-hop positions a ledge carries the camera over.
            lines.append(f"Reach {steps} steps (+{hops} hop) · DOS {dos} · "
                         f"GB {gb} · band {attention + border} = {attention} "
                         f"real + {border} border fill (4px cells)  U clears")
        elif self.probe_mode:
            lines.append("Reach: U floods the walkable area from the probe")
        if self.palette_warning:
            lines.append(self.palette_warning)
        if self.show["connections"]:
            lines.append("CONN: neighbours drawn around the edge — strip cells "
                         "edit the neighbour")
            crossing = self.connection_at_player()
            if crossing:
                lines.append(f"At edge: {crossing}")
        if self.show["inspector"]:
            selected = next((s for s in self.cm.sprites
                             if s['stable_id'] == self.selected_object), None)
            if selected:
                trace = selected['trace']
                lines += [f"Object {selected['stable_id']}",
                          f"P: {trace['base']} UΔ: {trace['manual_delta']}",
                          f"AΔ: {trace['automatic_delta']} F: {trace['final']}"]
            else:
                lines += ["Inspector", "Select an NPC or move over the map"]
        if self.route_index >= 0:
            route = self.route_options[self.route_index]
            lines.append('Preview (selected NPC): ' + route['label'])
            operations = route['operations']
            if operations:
                step = operations[self.route_step]
                lines.append(f"Step {self.route_step + 1}/{len(operations)}: "
                             f"{step['kind']} {step['direction'] or ''} [ ] 1-4")
        line_h = self.font.get_linesize()
        pad = max(3, int(round(6 * self.ui_scale())))
        width = max(self.font.size(line)[0] for line in lines) + pad * 2
        panel = pygame.Surface((width, len(lines) * line_h + pad), pygame.SRCALPHA)
        panel.fill((20, 20, 26, 205))
        for i, line in enumerate(lines):
            panel.blit(self.font.render(line, True, (235, 235, 235)),
                       (pad, pad // 2 + i * line_h))
        self.screen.blit(panel, (pad, pad))

    def next_map(self):
        consts = [c for c in pm.all_map_consts()
                  if pm.map_info(c).tileset_stem is not None
                  and view.can_compose(c)]
        i = consts.index(self.cm.info.const)
        # Staged sidecar edits survive a switch (they live in the session); the
        # in-memory paint does not, so flush it into the staging tree first.
        if self.painted:
            try:
                self.stage_paint()
                self.painted = False
            except ValueError as exc:
                self.save_error = str(exc)
                return
        self.clear_probe()
        self.load(consts[(i + 1) % len(consts)])

    def expand_edge(self, edge):
        from map_editor import commands
        # Expansion reads the staged sidecar, so an uncommitted paint stroke has
        # to be flushed into it first — otherwise the growth would be applied to
        # a stale layout and the new cells would land in the wrong place.
        if self.painted:
            try:
                self.stage_paint()
                self.painted = False
            except ValueError as exc:
                self.save_error = str(exc)
                return
        info = self.cm.info
        diff = schema.load(info.label or pm.gmh.const_to_pascal(info.const))
        totals = {name: getattr(diff.extents, name) for name in ('north', 'west', 'south', 'east')}
        totals[edge] += 1
        try:
            result = commands.set_extents(info.const, **totals, write=True)
            for message in result['diagnostics']:
                print(f'EXPANSION REVIEW: {message}')
            if self.player:
                self.player = (self.player[0] + result['automatic_delta'][1],
                               self.player[1] + result['automatic_delta'][0])
            if self.probe:
                # Steps are 2 tiles, so a block of growth moves them by 2.
                dy = result['automatic_delta'][0] // 2
                dx = result['automatic_delta'][1] // 2
                self.probe = [(y + dy, x + dx) for (y, x) in self.probe]
                self._probe_cache = {}
            self.load(info.const)
        except (ValueError, OSError) as exc:
            self.save_error = str(exc)

    # ── event loop ───────────────────────────────────────────────────────────

    def quit(self):
        """Close WITHOUT saving: leaving the editor is not a save.

        Anything staged is discarded, which is the whole point of the staging
        layer — an edit never commits itself.
        """
        changed = self.stage.changed()
        if self.dirty or changed:
            bits = []
            if changed:
                bits.append(f"{len(changed)} staged file(s)")
            if self.painted:
                bits.append("in-memory paint")
            print(f"WARNING: quit with unsaved changes "
                  f"({', '.join(bits) or 'edits'} discarded, Ctrl+S saves)")
            for rel in changed:
                print(f"  discarded {rel}")
        staging.end()

    def run(self):
        clock = pygame.time.Clock()
        while True:
            for ev in pygame.event.get():
                if ev.type == pygame.QUIT:
                    self.quit()
                    return
                if ev.type == pygame.KEYDOWN:
                    mods = pygame.key.get_mods()
                    if ev.key == pygame.K_ESCAPE:
                        self.quit()
                        return
                    elif (mods & pygame.KMOD_CTRL and mods & pygame.KMOD_SHIFT
                          and ev.key in (pygame.K_UP, pygame.K_DOWN, pygame.K_LEFT, pygame.K_RIGHT)):
                        self.expand_edge({pygame.K_UP: 'north', pygame.K_DOWN: 'south',
                                          pygame.K_LEFT: 'west', pygame.K_RIGHT: 'east'}[ev.key])
                    elif ev.key == pygame.K_p:
                        self.paint = not self.paint
                        if self.paint:
                            self.probe_mode = False
                            self.probe_drag = False
                        else:
                            self.pick_mode = False
                    elif ev.key == pygame.K_y:
                        self.probe_mode = not self.probe_mode
                        if self.probe_mode:
                            self.paint = False
                        self.probe_drag = False
                    elif ev.key == pygame.K_k:
                        # Preview the same block ids through a neighbour's
                        # tileset + palette: the crossing, before crossing.
                        self.cycle_view_as()
                    elif ev.key == pygame.K_u:
                        # Flood the walkable area from the probe anchor and show
                        # what the port reveals; a second U clears it. The click
                        # still places a single step, so the point probe works.
                        self.toggle_reach()
                    elif ev.key == pygame.K_s and mods & pygame.KMOD_CTRL:
                        self.save()
                    elif ev.key == pygame.K_z and mods & pygame.KMOD_CTRL:
                        self.undo()
                    elif ev.key == pygame.K_f and self.paint:
                        self.flood_fill(pygame.mouse.get_pos())
                    elif ev.key == pygame.K_g:
                        self.show["steps"] = not self.show["steps"]
                    elif ev.key == pygame.K_b:
                        self.show["blocks"] = not self.show["blocks"]
                    elif ev.key == pygame.K_t:
                        self.show["tiles"] = not self.show["tiles"]
                    elif ev.key == pygame.K_w:
                        self.show["warps"] = not self.show["warps"]
                    elif ev.key == pygame.K_n:
                        self.show["npcs"] = not self.show["npcs"]
                    elif ev.key == pygame.K_j:
                        # Encounter/trigger tiles: where ArePlayerCoordsInArray
                        # fires for this map. Not a block or an object, so it
                        # gets its own layer.
                        self.show["triggers"] = not self.show["triggers"]
                    elif ev.key == pygame.K_v:
                        self.show["port_view"] = not self.show["port_view"]
                    elif ev.key == pygame.K_h:
                        self.show["gb_view"] = not self.show["gb_view"]
                    elif ev.key == pygame.K_r:
                        self.show["render_reach"] = not self.show["render_reach"]
                    elif ev.key == pygame.K_i:
                        self.show["inspector"] = not self.show["inspector"]
                    elif ev.key == pygame.K_c:
                        self.palette_mode = 'dmg' if self.palette_mode == 'port-cgb' else 'port-cgb'
                        self.refresh_palette()
                    elif ev.key == pygame.K_o:
                        if not self.toggle_pick():
                            self.route_index += 1
                            if self.route_index >= len(self.route_options):
                                self.route_index = -1
                            self.route_step = 0
                    elif ev.key in (pygame.K_LEFTBRACKET, pygame.K_RIGHTBRACKET) and self.route_index >= 0:
                        count = len(self.route_options[self.route_index]['operations'])
                        if count:
                            delta = -1 if ev.key == pygame.K_LEFTBRACKET else 1
                            self.route_step = max(0, min(count - 1, self.route_step + delta))
                    elif ev.key in (pygame.K_1, pygame.K_2, pygame.K_3, pygame.K_4) and self.route_index >= 0:
                        self.edit_route_step(ev.key - pygame.K_1)
                    elif ev.key == pygame.K_TAB:
                        self.next_map()
                    elif ev.key in (pygame.K_PLUS, pygame.K_EQUALS, pygame.K_KP_PLUS) \
                            and mods & pygame.KMOD_CTRL:
                        self.zoom_by(self.settings['zoom_key_step'],
                                     bool(mods & pygame.KMOD_CTRL),
                                     pygame.mouse.get_pos())
                    elif ev.key in (pygame.K_MINUS, pygame.K_KP_MINUS) \
                            and mods & pygame.KMOD_CTRL:
                        self.zoom_by(1.0 / self.settings['zoom_key_step'],
                                     bool(mods & pygame.KMOD_CTRL),
                                     pygame.mouse.get_pos())
                    elif ev.key == pygame.K_x:
                        self.show["connections"] = not self.show["connections"]
                        self.center_view()
                    elif ev.key == pygame.K_LEFT:
                        self.pan[0] += 64
                    elif ev.key == pygame.K_RIGHT:
                        self.pan[0] -= 64
                    elif ev.key == pygame.K_UP:
                        self.pan[1] += 64
                    elif ev.key == pygame.K_DOWN:
                        self.pan[1] -= 64
                elif ev.type == pygame.MOUSEBUTTONDOWN and ev.button == 1:
                    # LEFT CLICK PLACES. Panning lives on the middle button (see
                    # the MOUSEBUTTONDOWN branch below) so a click never has to
                    # mean "maybe drag the view".
                    if self.warp_panel_click(ev.pos):
                        pass
                    elif self.object_panel_click(ev.pos):
                        pass
                    elif self.palette_click(ev.pos):
                        pass
                    elif self.probe_mode:
                        self.probe_click(
                            ev.pos, bool(pygame.key.get_mods() & pygame.KMOD_SHIFT))
                    elif self.paint and self.pick_mode:
                        self.pick_cell(ev.pos)
                    elif self.paint:
                        self.painting = True
                        self.stroke_anchor = self.cell_at(ev.pos)
                        self.stroke_last = None
                        self.lock_axis = None
                        self.paint_cell(ev.pos, self.axis_lock_held())
                    elif self.show["warps"] and self.warp_at_tile(self.tile_at(ev.pos)):
                        warp = self.warp_at_tile(self.tile_at(ev.pos))
                        self.selected_warp = warp['stable_id']
                        self.warp_drag = warp['stable_id']
                        self.warp_menu = None
                        self.selected_object = None
                    elif self.show["npcs"] and self.tile_at(ev.pos) is not None and any(
                            (s['mapx'] - 4, s['mapy'] - 4) == tuple(v // 2 for v in self.tile_at(ev.pos))
                            for s in self.cm.sprites):
                        self.object_drag = next(s['stable_id'] for s in self.cm.sprites
                                                if (s['mapx'] - 4, s['mapy'] - 4)
                                                == tuple(v // 2 for v in self.tile_at(ev.pos)))
                        self.selected_object = self.object_drag
                        self.selected_warp = None
                    elif (self.show["port_view"] or self.show["gb_view"]
                          or self.show["render_reach"]):
                        self.set_player_tile(ev.pos)
                    else:
                        self.selected_object = None
                        self.selected_warp = None
                        self.warp_menu = None
                        self.set_player_tile(ev.pos)
                elif ev.type == pygame.MOUSEBUTTONDOWN and ev.button == self.settings['pan_button']:
                    self.drag = (ev.pos, tuple(self.pan))
                elif ev.type == pygame.MOUSEBUTTONDOWN and ev.button == 3:
                    if self.paint:
                        self.eyedrop(ev.pos)
                elif ev.type == pygame.MOUSEWHEEL:
                    if self.object_menu:
                        count = len(self.object_fields()[self.object_menu])
                        self.menu_offset = max(0, min(max(0, count - 12),
                                                      self.menu_offset - ev.y))
                    elif self.warp_menu:
                        count = len(self.warp_fields()[self.warp_menu])
                        self.warp_menu_offset = max(
                            0, min(max(0, count - 12),
                                   self.warp_menu_offset - ev.y))
                    else:
                        # Smooth zoom: one notch multiplies the scale, so the
                        # zoom is continuous rather than snapping 1x/2x/3x.
                        # Ctrl is a held shift, not a toggle — it swaps the
                        # anchor mode for as long as it is down.
                        ctrl = bool(pygame.key.get_mods() & pygame.KMOD_CTRL)
                        self.zoom_by(self.settings['zoom_step'] ** ev.y, ctrl,
                                     pygame.mouse.get_pos())
                elif ev.type == pygame.MOUSEBUTTONUP:
                    if ev.button == 1:
                        if self.warp_drag:
                            self.finish_warp_drag(ev.pos)
                            self.warp_drag = None
                        if self.object_drag:
                            tile = self.tile_at(ev.pos)
                            if tile is not None:
                                from map_editor import commands
                                try:
                                    commands.set_object(self.cm.info.const, self.object_drag,
                                                        y=tile[1] // 2 * 2, x=tile[0] // 2 * 2, write=True)
                                    self.cm.sprites = pm.objects(self.cm.info)[3]
                                    self.dirty = True
                                    self.save_error = ""
                                except (ValueError, OSError) as exc:
                                    self.save_error = str(exc)
                            self.object_drag = None
                        self.end_stroke()
                    if ev.button == self.settings['pan_button']:
                        self.drag = None
                elif ev.type == pygame.MOUSEMOTION:
                    self.cursor_tile = self.tile_at(ev.pos)
                    if self.probe_drag:
                        # A lost button-up must not leave the sweep armed: the
                        # motion event carries the real button state.
                        if not ev.buttons[0]:
                            self.end_stroke()
                        else:
                            self.probe_extend(ev.pos, self.axis_lock_held())
                    elif self.painting:
                        self.paint_cell(ev.pos, self.axis_lock_held())
                    elif self.drag:
                        (sx, sy), (px, py) = self.drag
                        self.pan = [px + ev.pos[0] - sx, py + ev.pos[1] - sy]
            self.draw()
            clock.tick(60)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("map_const", nargs="?", default="PALLET_TOWN")
    ap.add_argument("--zoom", type=float, default=None,
                    help="initial scale; default picks the largest that fits the window")
    ap.add_argument("--config", type=Path, default=None,
                    help="settings JSON (default: map_editor/config.json if present)")
    args = ap.parse_args()
    from map_editor.commands import resolve_map
    try:
        const = resolve_map(args.map_const)
        settings = config.load(args.config)
    except (ValueError, OSError) as exc:
        print(f"map editor: {exc}", file=sys.stderr)
        return 2
    zoom = args.zoom if args.zoom else best_zoom(const)
    try:
        Viewer(const, zoom, settings).run()
    except ValueError as exc:
        # e.g. a map whose pret .blk cannot be used as a standalone grid.
        print(f"map editor: {exc}", file=sys.stderr)
        return 2
    finally:
        pygame.quit()
    return 0


def best_zoom(const, size=(1024, 700)):
    """Largest integer scale that fits the padded map, capped at 2.

    A fixed default of 2 cropped every map bigger than ~15 blocks; a fixed 1
    wasted space on small interiors. Fit the actual composed size instead.
    """
    info = pm.map_info(const)
    width = (info.w + 2 * view.BORDER) * ts.BLOCK_PX
    height = (info.h + 2 * view.BORDER) * ts.BLOCK_PX
    for zoom in (2.0, 1.0):
        if width * zoom <= size[0] and height * zoom <= size[1] - PANEL_H:
            return zoom
    return 1.0


if __name__ == "__main__":
    raise SystemExit(main())
