#!/usr/bin/env python3
"""editor.py — drag/resize menu windows on the port's 40x25 canvas (pygame).

Usage (from dos_port/):
  python3 tools/ui_layout/editor.py assets/ui_layout_menus_sidecar.json \
      [--bg FRAME.BIN] [--zoom 3]

Controls:
  click            select (topmost)          Tab        cycle selection
  drag             move (tile snap)          drag edge/corner  resize (resizable)
  arrows           nudge 1 tile              Shift+arrows      grow/shrink
  X / Y            cycle anchor_x/anchor_y (marks anchor confirmed)
  G                toggle GB 20x18 ghost for the selected element's anchor
  H / Shift+H      hide selected element / unhide all (editor-only, not saved)
  O                solo mode: show only the selected element
  W                toggle overlap warnings   B          toggle background
  Ctrl+S           save sidecar              Esc/close  quit (warns if unsaved)

What you see is what ships: the preview and gen_ui_layout.py share the same
projection (canvas.py) and tile rasterizer (render.py).
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import pygame

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from ui_layout import canvas as cv          # noqa: E402
from ui_layout import render, schema        # noqa: E402
from ui_layout.canvas import TILE           # noqa: E402

PANEL_W = 340
SEL = (255, 64, 64)
GHOST = (255, 200, 0)
WARN = (255, 0, 128)
HANDLE = 6


class Editor:
    def __init__(self, sidecar: Path, bg: Path | None, zoom: int):
        self.sidecar = sidecar
        self.layout = schema.load(sidecar)
        self.zoom = zoom
        self.bg_img = render.load_frame_bin(str(bg)) if bg else None
        self.show_bg = bg is not None
        self.show_ghost = False
        self.show_overlap = False
        self.hidden: set[str] = set()   # editor-only, never saved to the sidecar
        self.solo = False               # show only the selected element
        self.sel: int | None = 0 if self.layout.elements else None
        self.dirty = False          # unsaved changes
        self.drag = None            # (mode, start_mouse, start_geom)
        self.cw = self.layout.canvas["cols"] * TILE
        self.ch = self.layout.canvas["rows"] * TILE
        pygame.init()
        self.screen = pygame.display.set_mode(
            (self.cw * zoom + PANEL_W, max(self.ch * zoom, 560)))
        self.font = pygame.font.SysFont("monospace", 13)
        self._surface_stale = True
        self._canvas_surf = None

    # ── rendering ────────────────────────────────────────────────────────────

    def visible_ids(self) -> set[str]:
        if self.solo:
            return ({self.layout.elements[self.sel].id}
                    if self.sel is not None else set())
        return {el.id for el in self.layout.elements} - self.hidden

    def is_visible(self, el) -> bool:
        return el.id in self.visible_ids()

    def canvas_surface(self) -> pygame.Surface:
        vis = self.visible_ids()
        if vis != getattr(self, "_last_vis", None):
            self._surface_stale = True
            self._last_vis = vis
        if self._surface_stale or self._canvas_surf is None:
            img = render.render_layout(
                self.layout, self.bg_img if self.show_bg else None,
                only_ids=vis)
            surf = pygame.image.fromstring(img.tobytes(), img.size, "RGB")
            self._canvas_surf = pygame.transform.scale(
                surf, (self.cw * self.zoom, self.ch * self.zoom))
            self._surface_stale = False
        return self._canvas_surf

    def el_rect(self, el) -> pygame.Rect:
        p = cv.project(el)
        z = self.zoom
        return pygame.Rect(p.col * TILE * z, p.row * TILE * z,
                           el.gb_w * TILE * z, el.gb_h * TILE * z)

    def draw(self):
        self.screen.fill((24, 24, 24))
        self.screen.blit(self.canvas_surface(), (0, 0))
        if self.show_overlap:
            rects = [(el, self.el_rect(el)) for el in self.layout.elements
                     if self.is_visible(el)]
            for i, (ea, ra) in enumerate(rects):
                for eb, rb in rects[i + 1:]:
                    if ra.colliderect(rb):
                        pygame.draw.rect(self.screen, WARN, ra, 2)
                        pygame.draw.rect(self.screen, WARN, rb, 2)
        if self.sel is not None and self.is_visible(self.layout.elements[self.sel]):
            el = self.layout.elements[self.sel]
            r = self.el_rect(el)
            pygame.draw.rect(self.screen, SEL, r, 2)
            if el.resizable:
                for hx, hy in self._handles(r):
                    pygame.draw.rect(
                        self.screen, SEL,
                        (hx - HANDLE // 2, hy - HANDLE // 2, HANDLE, HANDLE))
            if self.show_ghost:
                sx, sy = cv.shifts(el)
                g = pygame.Rect(sx * TILE * self.zoom, sy * TILE * self.zoom,
                                self.layout.gb_canvas["cols"] * TILE * self.zoom,
                                self.layout.gb_canvas["rows"] * TILE * self.zoom)
                pygame.draw.rect(self.screen, GHOST, g, 1)
        self._draw_panel()
        pygame.display.flip()

    def _handles(self, r: pygame.Rect):
        return [(r.left, r.top), (r.centerx, r.top), (r.right, r.top),
                (r.left, r.centery), (r.right, r.centery),
                (r.left, r.bottom), (r.centerx, r.bottom), (r.right, r.bottom)]

    def _draw_panel(self):
        x0 = self.cw * self.zoom
        pygame.draw.rect(self.screen, (40, 40, 48),
                         (x0, 0, PANEL_W, self.screen.get_height()))
        y = 8

        def line(s, color=(220, 220, 220)):
            nonlocal y
            self.screen.blit(self.font.render(s[:46], True, color), (x0 + 8, y))
            y += 16

        title = self.layout.subsystem \
            + ("  [SOLO]" if self.solo else "") \
            + ("  *UNSAVED*" if self.dirty else "")
        line(title, (255, 255, 128) if self.dirty else (160, 255, 160))
        line("-" * 44, (90, 90, 100))
        for i, el in enumerate(self.layout.elements):
            mark = ">" if i == self.sel else " "
            conf = "" if el.anchor_source == "confirmed" else "?"
            hid = "  [hidden]" if el.id in self.hidden and not self.solo else ""
            color = (255, 200, 120) if i == self.sel else \
                (110, 110, 120) if not self.is_visible(el) else (200, 200, 200)
            line(f"{mark}{el.id[:34]}{conf}{hid}", color)
        line("-" * 44, (90, 90, 100))
        if self.sel is not None:
            el = self.layout.elements[self.sel]
            p = cv.project(el)
            line(f"GB({el.gb_x},{el.gb_y}) {el.gb_w}x{el.gb_h}  {el.kind}")
            line(f"anchor {el.anchor_x}/{el.anchor_y} [{el.anchor_source}]")
            line(f"-> tile({p.col},{p.row})  corner({p.x2},{p.y2})")
            line(f"wx={p.wx} wy={p.wy} clip={p.clip} maxy={p.max_y}")
            if el.notes:
                line(f"note: {el.notes[:60]}", (170, 170, 255))
            y += 8
            for chunk in _wrap(cv.proj_tag(self.layout.subsystem, el), 44):
                line(chunk, (140, 220, 140))

    # ── interaction ──────────────────────────────────────────────────────────

    def pick(self, pos) -> int | None:
        hit = None
        for i, el in enumerate(self.layout.elements):
            if self.is_visible(el) and self.el_rect(el).collidepoint(pos):
                hit = i  # last hit = painter's-order topmost
        return hit

    def _resize_mode(self, el, pos) -> str | None:
        if not el.resizable:
            return None
        r = self.el_rect(el)
        names = ("tl", "t", "tr", "l", "r", "bl", "b", "br")
        for name, (hx, hy) in zip(names, self._handles(r)):
            if abs(pos[0] - hx) <= HANDLE and abs(pos[1] - hy) <= HANDLE:
                return name
        return None

    def mouse_down(self, pos):
        if pos[0] >= self.cw * self.zoom:
            row = (pos[1] - 40) // 16  # panel element list click
            if 0 <= row < len(self.layout.elements):
                self.sel = row
            return
        if self.sel is not None:
            el = self.layout.elements[self.sel]
            mode = self._resize_mode(el, pos)
            if mode:
                self.drag = (mode, pos, (el.gb_x, el.gb_y, el.gb_w, el.gb_h))
                return
            # a selected element keeps priority under the cursor, so overlapped
            # elements stay draggable after picking them from the panel/Tab
            if self.is_visible(el) and self.el_rect(el).collidepoint(pos) \
                    and el.movable:
                self.drag = ("move", pos, (el.gb_x, el.gb_y, el.gb_w, el.gb_h))
                return
        hit = self.pick(pos)
        if hit is not None:
            self.sel = hit
            el = self.layout.elements[hit]
            if el.movable:
                self.drag = ("move", pos, (el.gb_x, el.gb_y, el.gb_w, el.gb_h))
        else:
            self.sel = None

    def mouse_move(self, pos):
        if not self.drag or self.sel is None:
            return
        mode, start, (gx, gy, gw, gh) = self.drag
        dtx = round((pos[0] - start[0]) / (TILE * self.zoom))
        dty = round((pos[1] - start[1]) / (TILE * self.zoom))
        el = self.layout.elements[self.sel]
        if mode == "move":
            el.gb_x, el.gb_y = gx + dtx, gy + dty
        else:
            if "l" in mode:
                el.gb_x, el.gb_w = gx + dtx, gw - dtx
            if "r" in mode:
                el.gb_w = gw + dtx
            if "t" in mode:
                el.gb_y, el.gb_h = gy + dty, gh - dty
            if "b" in mode:
                el.gb_h = gh + dty
            el.gb_w = max(el.min_w, el.gb_w)
            el.gb_h = max(el.min_h, el.gb_h)
        self._clamp(el)
        self.dirty = True
        self._surface_stale = True

    def _clamp(self, el):
        """Keep the projected box inside the canvas by adjusting gb origin."""
        sx, sy = cv.shifts(el)
        el.gb_x = max(-sx, min(el.gb_x,
                               self.layout.canvas["cols"] - el.gb_w - sx))
        el.gb_y = max(-sy, min(el.gb_y,
                               self.layout.canvas["rows"] - el.gb_h - sy))

    def key(self, ev):
        if self.sel is None and ev.key not in (pygame.K_TAB, pygame.K_s,
                                               pygame.K_b, pygame.K_w,
                                               pygame.K_h, pygame.K_o):
            return
        el = self.layout.elements[self.sel] if self.sel is not None else None
        mods = pygame.key.get_mods()
        shift, ctrl = mods & pygame.KMOD_SHIFT, mods & pygame.KMOD_CTRL
        moved = False
        if ev.key == pygame.K_TAB:
            n = len(self.layout.elements)
            self.sel = 0 if self.sel is None else (self.sel + 1) % n
        elif ev.key == pygame.K_s and ctrl:
            self.save()
        elif ev.key == pygame.K_g:
            self.show_ghost = not self.show_ghost
        elif ev.key == pygame.K_w:
            self.show_overlap = not self.show_overlap
        elif ev.key == pygame.K_o:
            self.solo = not self.solo
        elif ev.key == pygame.K_h:
            if shift:
                self.hidden.clear()
            elif el is not None:
                self.hidden.symmetric_difference_update({el.id})
        elif ev.key == pygame.K_b:
            self.show_bg = not self.show_bg and self.bg_img is not None
            self._surface_stale = True
        elif el is None:
            return
        elif ev.key == pygame.K_x:
            order = schema.ANCHORS_X[:3]  # left/center/right (custom via JSON)
            el.anchor_x = order[(order.index(el.anchor_x) + 1) % 3] \
                if el.anchor_x in order else "left"
            el.anchor_source = "confirmed"
            moved = True
        elif ev.key == pygame.K_y:
            order = schema.ANCHORS_Y[:3]
            el.anchor_y = order[(order.index(el.anchor_y) + 1) % 3] \
                if el.anchor_y in order else "top"
            el.anchor_source = "confirmed"
            moved = True
        elif ev.key in (pygame.K_LEFT, pygame.K_RIGHT, pygame.K_UP,
                        pygame.K_DOWN):
            dx = (ev.key == pygame.K_RIGHT) - (ev.key == pygame.K_LEFT)
            dy = (ev.key == pygame.K_DOWN) - (ev.key == pygame.K_UP)
            if shift and el.resizable:
                el.gb_w = max(el.min_w, el.gb_w + dx)
                el.gb_h = max(el.min_h, el.gb_h + dy)
            elif el.movable:
                el.gb_x += dx
                el.gb_y += dy
            moved = True
        if moved:
            self._clamp(el)
            self.dirty = True
            self._surface_stale = True

    def save(self):
        schema.save(self.layout, self.sidecar)
        self.dirty = False
        print(f"saved {self.sidecar}")
        print("regenerate with: python3 tools/gen_ui_layout.py "
              f"{self.layout.subsystem}")

    def run(self):
        clock = pygame.time.Clock()
        while True:
            for ev in pygame.event.get():
                if ev.type == pygame.QUIT:
                    if self.dirty:
                        print("WARNING: quit with unsaved changes")
                    return
                if ev.type == pygame.MOUSEBUTTONDOWN and ev.button == 1:
                    self.mouse_down(ev.pos)
                elif ev.type == pygame.MOUSEBUTTONUP and ev.button == 1:
                    self.drag = None
                elif ev.type == pygame.MOUSEMOTION:
                    self.mouse_move(ev.pos)
                elif ev.type == pygame.KEYDOWN:
                    if ev.key == pygame.K_ESCAPE:
                        if self.dirty:
                            print("WARNING: quit with unsaved changes")
                        return
                    self.key(ev)
            self.draw()
            clock.tick(60)


def _wrap(s: str, width: int) -> list[str]:
    return [s[i:i + width] for i in range(0, len(s), width)]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("sidecar", type=Path)
    ap.add_argument("--bg", type=Path, help="FRAME.BIN underlay")
    ap.add_argument("--zoom", type=int, default=3)
    args = ap.parse_args()
    pygame.display.set_caption(f"ui_layout — {args.sidecar.name}")
    Editor(args.sidecar, args.bg, args.zoom).run()
    pygame.quit()


if __name__ == "__main__":
    main()
