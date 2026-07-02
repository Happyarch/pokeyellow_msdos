#!/usr/bin/env python3
"""editor.py — read-only overworld map viewer (map-tool plan C1).

Usage (from dos_port/):
  python3 tools/map_editor/editor.py PALLET_TOWN [--zoom 2]

Controls:
  drag / arrows    pan                     + / -   zoom
  G  block grid    T  tile grid            W  warp markers
  S  sign count    N  NPC markers          V  viewport ghost (click sets
                                              the player tile for it)
  Tab              cycle to the next map with a header
  Esc / close      quit

The composition is runtime-faithful: border fill -> connection strips from
the neighbours' real .blk (via gen_map_headers.get_connection) -> centre.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import pygame

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from gfx_core import pret_maps as pm            # noqa: E402
from gfx_core.surface import to_pygame          # noqa: E402
from gfx_core.tiles import TILE                 # noqa: E402
from map_editor import view                     # noqa: E402

MARK_WARP = (255, 60, 60)
MARK_NPC = (60, 120, 255)
MARK_TRAINER = (255, 160, 0)
MARK_ITEM = (0, 200, 120)
GHOST_WIN = (255, 220, 0)
GHOST_SUR = (0, 220, 220)
GRID_BLOCK = (0, 0, 0)
GRID_TILE = (70, 70, 70)
PANEL_H = 22


class Viewer:
    def __init__(self, const: str, zoom: int):
        self.zoom = zoom
        self.pan = [0, 0]
        self.show = {"blocks": False, "tiles": False, "warps": True,
                     "npcs": True, "ghost": False}
        self.player = None          # map-local tile (x, y) for the ghost
        self.drag = None
        pygame.init()
        self.screen = pygame.display.set_mode((1024, 700),
                                              pygame.RESIZABLE)
        self.font = pygame.font.SysFont("monospace", 13)
        self.load(const)

    def load(self, const: str):
        self.cm = view.compose_padded(const)
        self.img = view.render(self.cm)
        self.surf = None
        self.pan = [0, 0]
        pygame.display.set_caption(
            f"map_editor — {const} ({self.cm.info.w}x{self.cm.info.h} blocks,"
            f" {self.cm.info.tileset_name})")

    def surface(self):
        if self.surf is None:
            self.surf = to_pygame(self.img, self.zoom)
        return self.surf

    def draw(self):
        self.screen.fill((24, 24, 28))
        z = self.zoom
        self.screen.blit(self.surface(), self.pan)
        ox, oy = self.pan

        def rect_px(x, y, w, h, color, width=1):
            pygame.draw.rect(self.screen, color,
                             (ox + x * z, oy + y * z, w * z, h * z), width)

        if self.show["blocks"]:
            for bx in range(self.cm.stride + 1):
                x = ox + bx * view.BLOCK_PX * z
                pygame.draw.line(self.screen, GRID_BLOCK, (x, oy),
                                 (x, oy + self.img.height * z))
            for by in range(self.cm.rows + 1):
                y = oy + by * view.BLOCK_PX * z
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

        info = (f"{self.cm.info.const}  warps:{len(self.cm.warps)} "
                f"signs:{self.cm.sign_count} npcs:{len(self.cm.sprites)}  "
                f"[G]rid [T]iles [W]arps [N]pcs [V]iewport +/- zoom "
                f"Tab next map")
        bar = pygame.Surface((self.screen.get_width(), PANEL_H))
        bar.fill((40, 40, 48))
        bar.blit(self.font.render(info, True, (220, 220, 220)), (8, 4))
        self.screen.blit(bar, (0, self.screen.get_height() - PANEL_H))
        pygame.display.flip()

    def next_map(self):
        consts = [c for c in pm.all_map_consts()
                  if pm.map_info(c).tileset_stem is not None]
        i = consts.index(self.cm.info.const)
        self.load(consts[(i + 1) % len(consts)])

    def run(self):
        clock = pygame.time.Clock()
        while True:
            for ev in pygame.event.get():
                if ev.type == pygame.QUIT:
                    return
                if ev.type == pygame.KEYDOWN:
                    if ev.key == pygame.K_ESCAPE:
                        return
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
                    if self.show["ghost"]:
                        tx = (ev.pos[0] - self.pan[0]) // (TILE * self.zoom)
                        ty = (ev.pos[1] - self.pan[1]) // (TILE * self.zoom)
                        self.player = (tx - view.BORDER * 2,
                                       ty - view.BORDER * 2)
                    else:
                        self.drag = (ev.pos, tuple(self.pan))
                elif ev.type == pygame.MOUSEBUTTONUP and ev.button == 1:
                    self.drag = None
                elif ev.type == pygame.MOUSEMOTION and self.drag:
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
