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
  G  block grid    T  tile grid            W  warp + sign events
  N  NPC markers   V/H/R port/GB/reach frames (click sets the staged player tile)
  I  coordinate inspector   C  toggle palette   O  cycle route preview
  X  connections: assemble neighbouring maps at their real offsets (read-only)
  click a W marker  select a warp; the panel edits dest / target warp / kind
  [ / ] select route step; 1-4 set down/up/left/right (edits the port script)
  Ctrl+Shift+arrow  expand that edge by one 32px block
  Tab              cycle to the next map with a usable header
  Esc / close      quit (warns if unsaved paint)

Zoom anchoring is set by `zoom_anchor` in config.json (`cursor` by default, or
`center`). Ctrl is a held shift, not a toggle: while it is down the other anchor
mode is used, and releasing it returns to the configured default.

Paint mode (P toggles):
  left click/drag  paint the selected block (border ring or map interior)
  right click      eyedropper (pick block under cursor)
  click palette    select block                F  flood fill
  Ctrl+Z           undo                        S  save sidecar
  Connection strips are locked (drawn dimmed); map blocks and the border ring
  are editable. Connections always win at runtime.

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
from map_editor import objects                                                  # noqa: E402

MARK_WARP = (0, 150, 170)      # teal: distinct from the cyan render-reach frame
MARK_NPC = (60, 120, 255)
MARK_TRAINER = (255, 160, 0)
MARK_ITEM = (0, 200, 120)
PORT_VIEW = (255, 72, 72)
GB_VIEW = (60, 220, 100)
RENDER_REACH = (0, 220, 220)
# Paired-cutscene onion skins. Close violet tones, with a stronger violet where
# both MoveSprite2 walkers occupy the same cell.
NPCMV1 = (168, 92, 230)
NPCMV2 = (120, 132, 240)
NPCMV12 = (236, 120, 255)
# Connection-assembly review view: this map vs its neighbours.
CONN_SELF = (255, 60, 200)
CONN_OTHER = (90, 190, 255)
GRID_BLOCK = (0, 0, 0)
GRID_TILE = (70, 70, 70)
PAINTED = (255, 120, 220)
MAP_PAINTED = (0, 220, 255)
LOCKED_DIM = (0, 0, 0, 110)
SEL_BLOCK = (255, 64, 64)
PANEL_H = 22
PAL_COLS = 8
PAL_W = PAL_COLS * ts.BLOCK_PX + 12


class Viewer:
    def __init__(self, const: str, zoom: float | None = None, settings: dict | None = None):
        self.settings = settings if settings is not None else config.load()
        # Continuous scale, not an integer zoom: the wheel produces fractional
        # steps so the zoom is smooth instead of snapping between 1x/2x.
        self.scale = float(zoom) if zoom else 1.0
        self.pan = [0, 0]
        self.show = {"blocks": False, "tiles": False, "warps": True,
                     "npcs": True, "port_view": False, "gb_view": False,
                     "render_reach": False, "inspector": False,
                     "connections": False}
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
        self.warp_menu = None
        self.warp_menu_offset = 0
        self.route_index = -1
        self.route_step = 0
        self.route_sha = None
        self.route_options = []
        self.painting = False
        self.conn_view = None
        self.conn_surf = None
        self.conn_scale = None
        pygame.init()
        self.screen = pygame.display.set_mode((1024, 700),
                                              pygame.RESIZABLE)
        self.font = pygame.font.SysFont("monospace", 13)
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
        self.tiles = ts.load_tileset_2bpp(self.cm.info.tileset_stem)
        self.blocks = ts.load_blockset(self.cm.info.tileset_stem)
        self.nblocks = len(self.blocks) // ts.BLOCK_BYTES
        self.refresh_palette()
        self.invalidate_assembly()
        self.undo_stack = []
        self.dirty = False
        self.center_view()
        self.current_block = self.cm.border_block
        self.save_error = ""
        self.selected_object = None
        self.object_drag = None
        self.object_menu = None
        self.selected_warp = None
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

    def viewport_center(self) -> tuple[float, float]:
        """Screen centre of the map area (the bottom bar is excluded)."""
        return (self.screen.get_width() / 2.0,
                (self.screen.get_height() - PANEL_H) / 2.0)

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
                        (self.screen.get_height() - PANEL_H - surf.get_height()) // 2 - off_y]
            return
        surf = self.surface()
        self.pan = [(self.screen.get_width() - surf.get_width()) // 2,
                    (self.screen.get_height() - PANEL_H - surf.get_height()) // 2]

    def refresh_palette(self):
        if self.palette_mode == 'port-cgb':
            self.palette_name, self.colors, self.palette_warning = palette.resolve(self.cm.info)
        else:
            self.palette_name, self.colors, self.palette_warning = 'DMG', DMG_PAL, None
        self.img = view.render(self.cm, self.colors)
        # Colours changed: every raster is stale, but the assembly's GEOMETRY is
        # not, so only the surfaces are dropped here.
        self.conn_surf = None
        self.conn_scale = None
        self._core_surf = None
        self._core_scale = None
        self.surf = None
        self.pal_surf = None

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

    def _region(self, r, c) -> tuple[dict, tuple[int, int]] | None:
        """(target sidecar dict, its key) for a paintable cell, else None.
        Border ring -> map_borders cells (padded coords); real map area ->
        map_overrides cells (map-local coords); strips are locked.

        In CONNECTIONS mode the ring is deliberately not editable: the neighbour
        maps are drawn there purely so the seam can be watched, and painting a
        ring cell under a neighbour's pixels would silently edit something the
        user is not looking at. Only this map's own blocks stay placeable.
        """
        idx = r * self.cm.stride + c
        if idx in self.editable:
            if self.show["connections"]:
                return None
            return self.cells, (r, c)
        b = view.BORDER
        if b <= c < self.cm.stride - b and b <= r < self.cm.rows - b:
            return self.map_cells, (r - b, c - b)
        return None                          # connection strip: locked

    def _apply(self, r, c, block) -> tuple | None:
        """Set one cell (grid+img+sidecar); returns an undo record or None."""
        idx = r * self.cm.stride + c
        region = self._region(r, c)
        if region is None or self.cm.grid[idx] == block:
            return None
        target, key = region
        rec = (r, c, target is self.map_cells, target.get(key))
        if block == self.base_grid[idx]:
            initial = self.initial_map_cells if target is self.map_cells else self.initial_cells
            if key in initial:
                target[key] = initial[key]
            else:
                target.pop(key, None)
        else:
            target[key] = block
        self.cm.grid[idx] = block
        ts._blit_block(self.img, self.tiles, self.blocks, block, c, r,
                       self.colors)
        return rec

    def paint_cell(self, pos):
        cell = self.cell_at(pos)
        if cell is None:
            return
        rec = self._apply(*cell, self.current_block)
        if rec:
            self.undo_stack.append([rec])
            self.dirty = True
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
        op, seen, todo = [], {(r0, c0)}, [(r0, c0)]
        while todo:
            r, c = todo.pop()
            idx = r * self.cm.stride + c
            if self._region(r, c) is None or self.cm.grid[idx] != target:
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
            self.dirty = True
            self.invalidate_map_blocks()

    def undo(self):
        if not self.undo_stack:
            return
        b = view.BORDER
        for r, c, is_map, prev in reversed(self.undo_stack.pop()):
            idx = r * self.cm.stride + c
            target = self.map_cells if is_map else self.cells
            key = (r - b, c - b) if is_map else (r, c)
            if prev is None:
                target.pop(key, None)
                block = self.base_grid[idx]
            else:
                target[key] = prev
                block = prev
            self.cm.grid[idx] = block
            ts._blit_block(self.img, self.tiles, self.blocks, block, c, r,
                           self.colors)
        self.dirty = True
        self.invalidate_map_blocks()

    def eyedrop(self, pos):
        cell = self.cell_at(pos)
        if cell:
            self.current_block = self.cm.grid[cell[0] * self.cm.stride
                                              + cell[1]]
            self.pal_surf = None

    def save(self):
        try:
            borders.save(self.cm.info.const, self.cells, self.cm)
            if self.cm.info.label:
                overrides.save(self.cm.info.label, self.map_cells,
                               self.cm.info, self.nblocks)
        except ValueError as e:
            self.save_error = str(e)
            print(f"SAVE REFUSED: {e}")
            return
        self.save_error = ""
        self.dirty = False
        print(f"saved {borders.path_for(self.cm.info.const)} "
              f"({len(self.cells)} ring cells) + "
              f"{overrides.path_for(self.cm.info.label or '?')} "
              f"({len(self.map_cells)} map cells)")
        print("regenerate with: make -C dos_port assets")

    # ── palette panel ────────────────────────────────────────────────────────

    def palette_surface(self):
        if self.pal_surf is None:
            rows = (self.nblocks + PAL_COLS - 1) // PAL_COLS
            from PIL import Image
            img = Image.new("RGB", (PAL_COLS * ts.BLOCK_PX,
                                    rows * ts.BLOCK_PX), (30, 30, 36))
            for b in range(self.nblocks):
                ts._blit_block(img, self.tiles, self.blocks, b,
                               b % PAL_COLS, b // PAL_COLS, self.colors)
            self.pal_surf = to_pygame(img, 1)
        return self.pal_surf

    def palette_click(self, pos) -> bool:
        x0 = self.screen.get_width() - PAL_W
        if not self.paint or pos[0] < x0 + 6:
            return False
        b = ((pos[1] - 6) // ts.BLOCK_PX) * PAL_COLS \
            + (pos[0] - x0 - 6) // ts.BLOCK_PX
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
        left = self.screen.get_width() - 290
        if pos[0] < left or pos[1] >= 400:
            return False
        if self.object_menu:
            index = (pos[1] - 94) // 20 + self.menu_offset
            options = self.object_fields()[self.object_menu]
            if 94 <= pos[1] < 334 and 0 <= index < len(options):
                from map_editor import commands
                try:
                    commands.set_object(self.cm.info.const, self.selected_object,
                                        write=True, **{self.object_menu: options[index]})
                    self.cm.sprites = pm.objects(self.cm.info)[3]
                    self.save_error = ''
                except (ValueError, OSError) as exc:
                    self.save_error = str(exc)
                self.object_menu = None
                return True
        if 20 <= pos[1] < 86:
            index = (pos[1] - 20) // 22
            self.object_menu = ('sprite', 'movement', 'facing')[index]
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
        x = self.screen.get_width() - 290
        panel = pygame.Surface((290, 400), pygame.SRCALPHA)
        panel.fill((25, 25, 33, 225))
        panel.blit(self.font.render('NPC properties (saved on select)', True, (255, 255, 255)), (6, 2))
        tables = self.object_fields()
        for index, (field, key, values) in enumerate((
                ('sprite', 'sprite_id', pm.gmh._SPRITE_CONSTS),
                ('movement', 'mov', pm.gmh._MOV_CONSTS),
                ('facing', 'dir', pm.gmh._DIR_CONSTS))):
            name = next((s for s in tables[field] if values.get(s) == npc[key]), str(npc[key]))
            pygame.draw.rect(panel, (65, 65, 78), (4, 20 + index * 22, 282, 20))
            # Source field "facing" is movement byte 2, not initial facing.
            # Pret zeroes sprite state on load, then this byte constrains motion.
            display = 'movement rule' if field == 'facing' else field
            panel.blit(self.font.render(f'{display}: {name} ▾', True, (235, 235, 235)),
                       (8, 22 + index * 22))
        if self.object_menu:
            for i, name in enumerate(tables[self.object_menu][self.menu_offset:self.menu_offset + 12]):
                pygame.draw.rect(panel, (55, 60, 76), (4, 94 + i * 20, 282, 19))
                panel.blit(self.font.render(name, True, (235, 235, 235)), (8, 95 + i * 20))
            panel.blit(self.font.render('Mouse wheel: scroll', True, (220, 220, 220)), (8, 340))
        if self.route_index >= 0:
            self.draw_route_timeline(panel)
        self.screen.blit(panel, (x, 0))

    def draw_route_timeline(self, panel):
        """Compact step timeline for the selected stream: [ ] navigate, 1-4 edit."""
        route = self.route_options[self.route_index]
        operations = route['operations']
        panel.blit(self.font.render(f"Route {route['label'][:34]}", True, (235, 235, 235)), (6, 108))
        columns, size, gap = 22, 12, 2
        for i, op in enumerate(operations):
            row, col = divmod(i, columns)
            left = 6 + col * (size + gap)
            top = 126 + row * (size + gap)
            if top > 380:
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
                pygame.draw.rect(panel, (255, 255, 255), (left - 1, top - 1, size + 2, size + 2), 1)
        if operations:
            current = operations[self.route_step]
            label = f"{self.route_step + 1}/{len(operations)} {current['kind']}"
            if current['direction']:
                label += f" {current['direction']}"
            panel.blit(self.font.render(label, True, (235, 235, 235)), (6, 386))

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
            ly = max(0, min(self.screen.get_height() - PANEL_H - 18,
                            rect[1] + 3))
            chip = pygame.Surface((label.get_width() + 4, label.get_height()),
                                  pygame.SRCALPHA)
            chip.fill((0, 0, 0, 170))
            chip.blit(label, (2, 0))
            self.screen.blit(chip, (lx, ly))
        for i, note in enumerate(cv.anomalies):
            self.screen.blit(self.font.render(note[:96], True, (255, 170, 90)),
                             (8, self.screen.get_height() - PANEL_H - 18 - i * 16))

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
        x = self.screen.get_width() - 290
        panel = pygame.Surface((290, 400), pygame.SRCALPHA)
        panel.fill((25, 25, 33, 225))
        panel.blit(self.font.render('Warp properties (saved on select)', True,
                                    (255, 255, 255)), (6, 2))
        rows = (('dest', f"dest: {warp['dest']}"),
                ('warp_id', f"target warp: {warp['warp_id']}"),
                ('kind', f"kind: {warp['kind'] or '(unset)'}"))
        for index, (field, text) in enumerate(rows):
            pygame.draw.rect(panel, (65, 65, 78), (4, 20 + index * 22, 282, 20))
            panel.blit(self.font.render(text + ' ▾', True, (235, 235, 235)),
                       (8, 22 + index * 22))
        panel.blit(self.font.render(f"at (Y:{warp['y']*2}, X:{warp['x']*2}) tiles",
                                    True, (200, 200, 200)), (6, 88))
        if self.warp_menu:
            options = self.warp_fields()[self.warp_menu]
            for i, name in enumerate(options[self.warp_menu_offset:
                                             self.warp_menu_offset + 12]):
                pygame.draw.rect(panel, (55, 60, 76), (4, 108 + i * 20, 282, 19))
                panel.blit(self.font.render(name, True, (235, 235, 235)),
                           (8, 109 + i * 20))
            panel.blit(self.font.render('Mouse wheel: scroll', True,
                                        (220, 220, 220)), (8, 356))
        panel.blit(self.font.render('kind is editor metadata, not emitted',
                                    True, (200, 190, 150)), (6, 380))
        self.screen.blit(panel, (x, 0))

    def warp_panel_click(self, pos) -> bool:
        if self.paint or not self.selected_warp:
            return False
        left = self.screen.get_width() - 290
        if pos[0] < left or pos[1] >= 400:
            return False
        options = self.warp_fields()
        if self.warp_menu:
            index = (pos[1] - 108) // 20 + self.warp_menu_offset
            values = options[self.warp_menu]
            if 108 <= pos[1] < 348 and 0 <= index < len(values):
                self.apply_warp_field(self.warp_menu, values[index])
                self.warp_menu = None
                return True
        if 20 <= pos[1] < 86:
            self.warp_menu = ('dest', 'warp_id', 'kind')[(pos[1] - 20) // 22]
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
            self.save_error = ''
        except (ValueError, OSError) as exc:
            self.save_error = str(exc)

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
            for idx in self.cm.strip_cells:
                bx, by = idx % self.cm.stride, idx // self.cm.stride
                self.screen.blit(dim, (int(round(ox + bx * ts.BLOCK_PX * z)),
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
        if self.route_index >= 0:
            self.draw_route_overlay(ox, oy, z)
        if (self.show["port_view"] or self.show["gb_view"]
                or self.show["render_reach"]) and self.player:
            win, sur = view.viewport_rect(self.cm, self.player[1],
                                           self.player[0])
            if self.show["port_view"]:
                rect_px(*win, PORT_VIEW, 2)
            if self.show["gb_view"]:
                rect_px(*view.gb_viewport_rect(self.cm, self.player[1],
                                                self.player[0]), GB_VIEW, 2)
            if self.show["render_reach"]:
                rect_px(*sur, RENDER_REACH, 1)
            px = (self.player[0] + view.BORDER * 4) * TILE
            py = (self.player[1] + view.BORDER * 4) * TILE
            rect_px(px, py, TILE * 2, TILE * 2, (255, 100, 190), 2)
            self.screen.blit(self.font.render('PT', True, (255, 100, 190)),
                             (ox + px * z, oy + py * z))

        if self.paint:
            x0 = self.screen.get_width() - PAL_W
            pygame.draw.rect(self.screen, (40, 40, 48),
                             (x0, 0, PAL_W, self.screen.get_height()))
            self.screen.blit(self.palette_surface(), (x0 + 6, 6))
            b = self.current_block
            pygame.draw.rect(
                self.screen, SEL_BLOCK,
                (x0 + 6 + (b % PAL_COLS) * ts.BLOCK_PX,
                 6 + (b // PAL_COLS) * ts.BLOCK_PX,
                 ts.BLOCK_PX, ts.BLOCK_PX), 2)

        self.draw_hud()
        self.draw_object_panel()
        self.draw_warp_panel()
        state = "*UNSAVED*" if self.dirty else "saved"
        mode = (f"PAINT block 0x{self.current_block:02X} "
                f"{len(self.cells)} cells {state} | [F]ill Ctrl+Z [S]ave"
                if self.paint else
                "[G]rid [T]iles [W]arps [N]pcs [V/H/R] frames [I]nspect [C]olor [O] route [X]conn")
        info = (f"{self.cm.info.const}  warps:{len(self.cm.warps)} "
                f"npcs:{len(self.cm.sprites)}  [P]aint  {mode}")
        if self.save_error:
            info = f"SAVE REFUSED: {self.save_error[:80]}"
        bar = pygame.Surface((self.screen.get_width(), PANEL_H))
        bar.fill((40, 40, 48))
        bar.blit(self.font.render(info[:120], True,
                                  (255, 120, 120) if self.save_error
                                  else (220, 220, 220)), (8, 4))
        self.screen.blit(bar, (0, self.screen.get_height() - PANEL_H))
        pygame.display.flip()

    def draw_hud(self):
        """Persistent top-left final-coordinate HUD; I expands its trace view."""
        cursor = "F: —"
        block = ""
        if self.cursor_tile:
            x, y = self.cursor_tile
            bx, by = x // 4, y // 4
            cursor = f"F (Y:{y}, X:{x})"
            block_id = self.cm.grid[(by + view.BORDER) * self.cm.stride
                                    + bx + view.BORDER]
            block = f" B(Y:{by},X:{bx})=${block_id:02X}"
        layers = " ".join(name for name, enabled in (
            ("EVT", self.show["warps"]), ("NPC", self.show["npcs"]),
            ("PV", self.show["port_view"]), ("GB", self.show["gb_view"]),
            ("RR", self.show["render_reach"]),
            ("CONN", self.show["connections"])) if enabled)
        anchor = self.settings['zoom_anchor']
        lines = [f"{self.cm.info.const} id:${self.cm.info.map_id:02X}  {self.palette_name}",
                 f"Size W×H {self.cm.info.base_w}×{self.cm.info.base_h} → "
                 f"{self.cm.info.w}×{self.cm.info.h} B",
                 f"{cursor}{block}", f"Layers: {layers or '—'}",
                 f"Zoom {self.scale:.2f}x  anchor:{anchor} (Ctrl inverts)"]
        if self.palette_warning:
            lines.append(self.palette_warning)
        if self.show["connections"]:
            lines.append("CONN: render-only — neighbours are not editable")
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
        width = max(self.font.size(line)[0] for line in lines) + 12
        panel = pygame.Surface((width, len(lines) * 16 + 8), pygame.SRCALPHA)
        panel.fill((20, 20, 26, 205))
        for i, line in enumerate(lines):
            panel.blit(self.font.render(line, True, (235, 235, 235)), (6, 4 + i * 16))
        self.screen.blit(panel, (6, 6))

    def next_map(self):
        consts = [c for c in pm.all_map_consts()
                  if pm.map_info(c).tileset_stem is not None
                  and view.can_compose(c)]
        i = consts.index(self.cm.info.const)
        self.load(consts[(i + 1) % len(consts)])

    def expand_edge(self, edge):
        from map_editor import commands
        if self.dirty:
            self.save()
            if self.save_error:
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
            self.load(info.const)
        except (ValueError, OSError) as exc:
            self.save_error = str(exc)

    # ── event loop ───────────────────────────────────────────────────────────

    def run(self):
        clock = pygame.time.Clock()
        while True:
            for ev in pygame.event.get():
                if ev.type == pygame.QUIT:
                    if self.dirty:
                        print("WARNING: quit with unsaved paint")
                    return
                if ev.type == pygame.KEYDOWN:
                    mods = pygame.key.get_mods()
                    if ev.key == pygame.K_ESCAPE:
                        if self.dirty:
                            print("WARNING: quit with unsaved paint")
                        return
                    elif (mods & pygame.KMOD_CTRL and mods & pygame.KMOD_SHIFT
                          and ev.key in (pygame.K_UP, pygame.K_DOWN, pygame.K_LEFT, pygame.K_RIGHT)):
                        self.expand_edge({pygame.K_UP: 'north', pygame.K_DOWN: 'south',
                                          pygame.K_LEFT: 'west', pygame.K_RIGHT: 'east'}[ev.key])
                    elif ev.key == pygame.K_p:
                        self.paint = not self.paint
                    elif ev.key == pygame.K_s:
                        if self.paint:
                            self.save()
                    elif ev.key == pygame.K_z and mods & pygame.KMOD_CTRL:
                        self.undo()
                    elif ev.key == pygame.K_f and self.paint:
                        self.flood_fill(pygame.mouse.get_pos())
                    elif ev.key == pygame.K_g:
                        self.show["blocks"] = not self.show["blocks"]
                    elif ev.key == pygame.K_t:
                        self.show["tiles"] = not self.show["tiles"]
                    elif ev.key == pygame.K_w:
                        self.show["warps"] = not self.show["warps"]
                    elif ev.key == pygame.K_n:
                        self.show["npcs"] = not self.show["npcs"]
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
                        if self.dirty:
                            print("WARNING: switching map with unsaved paint")
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
                    elif self.paint:
                        self.painting = True
                        self.paint_cell(ev.pos)
                    elif self.show["warps"] and self.warp_at_tile(self.tile_at(ev.pos)):
                        warp = self.warp_at_tile(self.tile_at(ev.pos))
                        self.selected_warp = warp['stable_id']
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
                        self.player = self.tile_at(ev.pos)
                    else:
                        self.selected_object = None
                        self.selected_warp = None
                        self.warp_menu = None
                        self.player = self.tile_at(ev.pos)
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
                        if self.object_drag:
                            tile = self.tile_at(ev.pos)
                            if tile is not None:
                                from map_editor import commands
                                try:
                                    commands.set_object(self.cm.info.const, self.object_drag,
                                                        y=tile[1] // 2 * 2, x=tile[0] // 2 * 2, write=True)
                                    self.cm.sprites = pm.objects(self.cm.info)[3]
                                    self.save_error = ""
                                except (ValueError, OSError) as exc:
                                    self.save_error = str(exc)
                            self.object_drag = None
                        self.painting = False
                    if ev.button == self.settings['pan_button']:
                        self.drag = None
                elif ev.type == pygame.MOUSEMOTION:
                    self.cursor_tile = self.tile_at(ev.pos)
                    if self.painting:
                        self.paint_cell(ev.pos)
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
