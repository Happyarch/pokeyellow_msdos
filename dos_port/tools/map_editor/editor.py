#!/usr/bin/env python3
"""editor.py — overworld map viewer + border-ring painter (map-tool C1+C2).

Usage (from dos_port/):
  python3 tools/map_editor/editor.py PALLET_TOWN [--zoom 2]

View controls:
  drag / arrows    pan                     + / -   zoom
  G  block grid    T  tile grid            W  warp markers
  N  NPC markers   V  viewport ghost (click sets the player tile)
  Tab              cycle to the next map with a header
  Esc / close      quit (warns if unsaved paint)

Paint mode (P toggles; edits the map_borders/<CONST>.json sidecar):
  left click/drag  paint the border ring with the selected block
  right click      eyedropper (pick block under cursor)
  click palette    select block                F  flood fill
  Ctrl+Z           undo                        S  save sidecar
  Connection strips and the real map area are locked (drawn dimmed) —
  connections always win at runtime; the generator re-validates on regen.

The composition is runtime-faithful: border fill -> connection strips from
the neighbours' real .blk (via gen_map_headers.get_connection) -> centre ->
border overrides (editable ring only).
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
from map_editor import borders, overrides, view  # noqa: E402

MARK_WARP = (255, 60, 60)
MARK_NPC = (60, 120, 255)
MARK_TRAINER = (255, 160, 0)
MARK_ITEM = (0, 200, 120)
GHOST_WIN = (255, 220, 0)
GHOST_SUR = (0, 220, 220)
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
    def __init__(self, const: str, zoom: int):
        self.zoom = zoom
        self.pan = [0, 0]
        self.show = {"blocks": False, "tiles": False, "warps": True,
                     "npcs": True, "ghost": False}
        self.paint = False
        self.player = None          # map-local tile (x, y) for the ghost
        self.drag = None
        self.painting = False
        pygame.init()
        self.screen = pygame.display.set_mode((1024, 700),
                                              pygame.RESIZABLE)
        self.font = pygame.font.SysFont("monospace", 13)
        self.load(const)

    # ── data ─────────────────────────────────────────────────────────────────

    def load(self, const: str):
        self.cells = borders.load(const)
        info = pm.map_info(const)
        self.map_cells = overrides.load(info.label) if info.label else {}
        base = view.compose_padded(const)          # pre-override
        self.base_grid = bytes(base.grid)
        self.cm = view.compose_padded(const, self.cells, self.map_cells)
        self.editable = self.cm.editable_cells()
        self.tiles = ts.load_tileset_2bpp(self.cm.info.tileset_stem)
        self.blocks = ts.load_blockset(self.cm.info.tileset_stem)
        self.nblocks = len(self.blocks) // ts.BLOCK_BYTES
        self.img = view.render(self.cm)
        self.surf = None
        self.pal_surf = None
        self.pan = [0, 0]
        self.undo_stack = []
        self.dirty = False
        self.current_block = self.cm.border_block
        self.save_error = ""
        pygame.display.set_caption(
            f"map_editor — {const} ({self.cm.info.w}x{self.cm.info.h} blocks,"
            f" {self.cm.info.tileset_name})")

    def surface(self):
        if self.surf is None:
            self.surf = to_pygame(self.img, self.zoom)
        return self.surf

    # ── painting ─────────────────────────────────────────────────────────────

    def cell_at(self, pos) -> tuple[int, int] | None:
        bx = (pos[0] - self.pan[0]) // (ts.BLOCK_PX * self.zoom)
        by = (pos[1] - self.pan[1]) // (ts.BLOCK_PX * self.zoom)
        if 0 <= bx < self.cm.stride and 0 <= by < self.cm.rows:
            return int(by), int(bx)
        return None

    def _region(self, r, c) -> tuple[dict, tuple[int, int]] | None:
        """(target sidecar dict, its key) for a paintable cell, else None.
        Border ring -> map_borders cells (padded coords); real map area ->
        map_overrides cells (map-local coords); strips are locked."""
        idx = r * self.cm.stride + c
        if idx in self.editable:
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
            target.pop(key, None)            # painting back = remove override
        else:
            target[key] = block
        self.cm.grid[idx] = block
        ts._blit_block(self.img, self.tiles, self.blocks, block, c, r,
                       DMG_PAL)
        return rec

    def paint_cell(self, pos):
        cell = self.cell_at(pos)
        if cell is None:
            return
        rec = self._apply(*cell, self.current_block)
        if rec:
            self.undo_stack.append([rec])
            self.dirty = True
            self.surf = None

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
            self.surf = None

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
                           DMG_PAL)
        self.dirty = True
        self.surf = None

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
                               b % PAL_COLS, b // PAL_COLS, DMG_PAL)
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

    # ── drawing ──────────────────────────────────────────────────────────────

    def draw(self):
        self.screen.fill((24, 24, 28))
        z = self.zoom
        self.screen.blit(self.surface(), self.pan)
        ox, oy = self.pan

        def rect_px(x, y, w, h, color, width=1):
            pygame.draw.rect(self.screen, color,
                             (ox + x * z, oy + y * z, w * z, h * z), width)

        if self.paint:
            # dim the locked connection strips; badge painted cells
            # (ring = pink, real-map overrides = cyan)
            dim = pygame.Surface((ts.BLOCK_PX * z, ts.BLOCK_PX * z),
                                 pygame.SRCALPHA)
            dim.fill(LOCKED_DIM)
            for idx in self.cm.strip_cells:
                bx, by = idx % self.cm.stride, idx // self.cm.stride
                self.screen.blit(dim, (ox + bx * ts.BLOCK_PX * z,
                                       oy + by * ts.BLOCK_PX * z))
            for (r, c) in self.cells:
                rect_px(c * ts.BLOCK_PX, r * ts.BLOCK_PX,
                        ts.BLOCK_PX, ts.BLOCK_PX, PAINTED, 2)
            b = view.BORDER
            for (y, x) in self.map_cells:
                rect_px((x + b) * ts.BLOCK_PX, (y + b) * ts.BLOCK_PX,
                        ts.BLOCK_PX, ts.BLOCK_PX, MAP_PAINTED, 2)

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
            for (y, x, dest, wid) in self.cm.warps:
                px, py = view.warp_px(self.cm, y, x)
                rect_px(px, py, TILE, TILE, MARK_WARP, 2)
        if self.show["npcs"]:
            for s in self.cm.sprites:
                px, py = view.sprite_px(self.cm, s["mapy"], s["mapx"])
                color = MARK_TRAINER if s["is_trainer"] else \
                    MARK_ITEM if s["is_item"] else MARK_NPC
                rect_px(px, py, TILE, TILE, color, 2)
        if self.show["ghost"] and self.player:
            win, sur = view.viewport_rect(self.cm, self.player[1],
                                          self.player[0])
            rect_px(*win, GHOST_WIN, 2)
            rect_px(*sur, GHOST_SUR, 1)

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

        state = "*UNSAVED*" if self.dirty else "saved"
        mode = (f"PAINT block 0x{self.current_block:02X} "
                f"{len(self.cells)} cells {state} | [F]ill Ctrl+Z [S]ave"
                if self.paint else
                "[G]rid [T]iles [W]arps [N]pcs [V]iewport Tab next")
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

    def next_map(self):
        consts = [c for c in pm.all_map_consts()
                  if pm.map_info(c).tileset_stem is not None]
        i = consts.index(self.cm.info.const)
        self.load(consts[(i + 1) % len(consts)])

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
                        self.show["ghost"] = not self.show["ghost"]
                    elif ev.key == pygame.K_TAB:
                        if self.dirty:
                            print("WARNING: switching map with unsaved paint")
                        self.next_map()
                    elif ev.key in (pygame.K_PLUS, pygame.K_EQUALS):
                        self.zoom = min(6, self.zoom + 1)
                        self.surf = None
                    elif ev.key == pygame.K_MINUS:
                        self.zoom = max(1, self.zoom - 1)
                        self.surf = None
                    elif ev.key == pygame.K_LEFT:
                        self.pan[0] += 64
                    elif ev.key == pygame.K_RIGHT:
                        self.pan[0] -= 64
                    elif ev.key == pygame.K_UP:
                        self.pan[1] += 64
                    elif ev.key == pygame.K_DOWN:
                        self.pan[1] -= 64
                elif ev.type == pygame.MOUSEBUTTONDOWN and ev.button == 1:
                    if self.palette_click(ev.pos):
                        pass
                    elif self.paint:
                        self.painting = True
                        self.paint_cell(ev.pos)
                    elif self.show["ghost"]:
                        tx = (ev.pos[0] - self.pan[0]) // (TILE * self.zoom)
                        ty = (ev.pos[1] - self.pan[1]) // (TILE * self.zoom)
                        self.player = (tx - view.BORDER * 2,
                                       ty - view.BORDER * 2)
                    else:
                        self.drag = (ev.pos, tuple(self.pan))
                elif ev.type == pygame.MOUSEBUTTONDOWN and ev.button == 3:
                    if self.paint:
                        self.eyedrop(ev.pos)
                elif ev.type == pygame.MOUSEBUTTONUP and ev.button == 1:
                    self.drag = None
                    self.painting = False
                elif ev.type == pygame.MOUSEMOTION:
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
    ap.add_argument("--zoom", type=int, default=2)
    args = ap.parse_args()
    Viewer(args.map_const.upper(), args.zoom).run()
    pygame.quit()


if __name__ == "__main__":
    main()
