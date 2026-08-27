#!/usr/bin/env python3
"""tile_inspector.py — interactive tile & step coordinate inspector for the DOS port.

Features:
  - Robust non-blocking clipboard copy using xclip/wl-copy (prevents freezes with clipboard managers).
  - Multi-selection support: hold Ctrl while clicking or dragging to select multiple points & ranges.
  - Formatted Cartesian product output:
      Points: P: (Y1, X1); (Y2, X2)
      Ranges: R: [Y_min, Y_max]×[X_min, X_max]
      Combined: P: (Y1, X1) | R: [Y_0, Y_9]×[X_0, X_9]
  - Smooth zoom in/out centered on mouse cursor without resizing OS window.
  - Smooth panning with Middle-Click drag, Space+Left-Click drag, or Arrow keys.
  - Toggles for 8x8 tile grid (T/G), 16x16 step grid (S), and 20x18 GB viewport box (V).
  - Supports loading PNG/BMP/JPG images or raw FRAME.BIN / PAL.BIN framebuffer dumps.
  - Resizable application window (drag window edges or maximize).

Usage:
  python3 dos_port/tools/tile_inspector.py [image_or_FRAME.BIN] [--zoom 3]

Controls:
  Mouse Wheel      Smooth zoom in / out centered on cursor
  Middle-Drag      Pan canvas around
  Space + Drag     Pan canvas around
  Right-Click      Copy single tile coordinate P: (y, x) (hold Ctrl to add to selection)
  Left-Drag        Select rectangular tile range R: [y0, y1]×[x0, x1] (hold Ctrl to add)
  Left-Click       Select/toggle single tile (hold Ctrl to add, click without Ctrl to clear)
  Ctrl + Click     Add/toggle point or range in multi-selection
  C / Ctrl+C       Copy current selection (or hovered tile) to clipboard
  Delete / Esc     Clear current selections (Esc again to quit)
  T / G            Toggle 8x8 tile grid
  S                Toggle 16x16 step grid
  V                Toggle 20x18 classic GB viewport guide box
  + / -            Zoom in / out
  0 / R / Home     Reset zoom & center image in window
  Arrows           Pan canvas
  Q                Quit
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path
from typing import Tuple, Optional, List, Set

import pygame

# Default canvas dimensions for Pokémon Yellow DOS port (Mode 13h)
CANVAS_W = 320
CANVAS_H = 200
TILE_SIZE = 8
STEP_SIZE = 16
TILES_X = CANVAS_W // TILE_SIZE  # 40
TILES_Y = CANVAS_H // TILE_SIZE  # 25

# Standard palette for debug rendering of raw FRAME.BIN when PAL.BIN is absent
DMG_PAL = {
    0: (224, 248, 208),  # Lightest
    1: (136, 192, 112),
    2: (52, 104, 86),
    3: (8, 24, 32),      # Darkest
    4: (255, 64, 64),
    5: (255, 128, 0),
    6: (255, 255, 0),
    7: (0, 255, 0),
    8: (0, 255, 255),
    9: (0, 128, 255),
    10: (128, 0, 255),
    11: (255, 0, 255),
}

# Color definitions
COLOR_BG = (24, 26, 32)
COLOR_CANVAS_BORDER = (70, 75, 90)
COLOR_GRID_TILE = (255, 60, 60, 170)       # Red semi-transparent
COLOR_GRID_STEP = (60, 180, 255, 210)      # Cyan semi-transparent
COLOR_GB_BOX = (255, 220, 0, 230)          # Yellow semi-transparent
COLOR_HOVER_BORDER = (255, 255, 0)         # Bright Yellow
COLOR_HOVER_FILL = (255, 255, 0, 70)
COLOR_SEL_BORDER = (0, 255, 128)           # Bright Green
COLOR_SEL_FILL = (0, 255, 128, 75)
COLOR_POINT_BORDER = (0, 220, 255)         # Cyan Point
COLOR_POINT_FILL = (0, 220, 255, 90)
COLOR_HUD_BG = (16, 18, 24, 240)
COLOR_HUD_TEXT = (240, 240, 240)
COLOR_HUD_ACCENT = (255, 215, 0)
COLOR_HUD_MUTED = (160, 170, 190)
COLOR_TOAST_BG = (35, 130, 55, 245)
COLOR_TOAST_TEXT = (255, 255, 255)


def copy_to_clipboard(text: str) -> bool:
    """Copy text to system clipboard cleanly using xclip/wl-copy without freezing."""
    text_str = str(text)
    print(f"[Tile Inspector] Copied to clipboard: {text_str}")

    is_wayland = bool(os.environ.get("WAYLAND_DISPLAY"))

    if is_wayland:
        try:
            subprocess.run(
                ["wl-copy"],
                input=text_str.encode("utf-8"),
                timeout=0.4,
                check=True
            )
            return True
        except Exception:
            pass

    # Try xclip (standard on Linux X11 and XWayland)
    try:
        subprocess.run(
            ["xclip", "-selection", "clipboard"],
            input=text_str.encode("utf-8"),
            timeout=0.4,
            check=True
        )
        return True
    except Exception:
        pass

    # Try xsel fallback
    try:
        subprocess.run(
            ["xsel", "--clipboard", "--input"],
            input=text_str.encode("utf-8"),
            timeout=0.4,
            check=True
        )
        return True
    except Exception:
        pass

    # Fallback to pygame.scrap only if external tools fail
    try:
        if pygame.scrap.get_init():
            pygame.scrap.put(pygame.SCRAP_TEXT, text_str.encode("utf-8"))
            return True
    except Exception:
        pass

    return False


def build_selection_string(points: Set[Tuple[int, int]], ranges: List[Tuple[int, int, int, int]]) -> str:
    """Build standardized output string with Cartesian product ranges using Unicode ×."""
    parts = []

    if points:
        sorted_points = sorted(points, key=lambda p: (p[0], p[1]))
        p_strs = [f"({y}, {x})" for y, x in sorted_points]
        parts.append(f"P: {'; '.join(p_strs)}")

    if ranges:
        sorted_ranges = sorted(ranges, key=lambda r: (r[0], r[1], r[2], r[3]))
        r_strs = [f"[{min_y}, {max_y}]×[{min_x}, {max_x}]" for min_y, min_x, max_y, max_x in sorted_ranges]
        parts.append(f"R: {'; '.join(r_strs)}")

    return " | ".join(parts)


def load_pal(path: Path) -> dict[int, tuple[int, int, int]]:
    """Read PAL.BIN (PAL0 v1 debug format) or return DMG_PAL."""
    if not path.exists():
        return DMG_PAL
    try:
        data = path.read_bytes()
        if len(data) >= 16 + 64 * 3 and data[:4] == b"PAL0" and data[4] == 1:
            rgb6 = data[16:16 + 64 * 3]
            return {
                i: tuple(round(component * 255 / 63) for component in rgb6[i * 3:i * 3 + 3])
                for i in range(64)
            }
    except Exception as e:
        print(f"Warning: Failed to parse palette {path}: {e}")
    return DMG_PAL


def load_image_or_frame(path: Path | None) -> pygame.Surface:
    """Load image from file or parse raw FRAME.BIN framebuffer dump."""
    surface = pygame.Surface((CANVAS_W, CANVAS_H))
    surface.fill((48, 52, 64))

    if path is None:
        for y in range(CANVAS_H):
            for x in range(CANVAS_W):
                if ((x // 8) + (y // 8)) % 2 == 0:
                    surface.set_at((x, y), (36, 40, 50))
        return surface

    if not path.exists():
        print(f"File not found: {path}, using default canvas.")
        return surface

    # Check if raw FRAME.BIN (64000 bytes)
    if path.name.upper() == "FRAME.BIN" or path.suffix.upper() == ".BIN":
        try:
            data = path.read_bytes()
            if len(data) >= CANVAS_W * CANVAS_H:
                pal_path = path.with_name("PAL.BIN")
                pal = load_pal(pal_path)
                px_array = pygame.PixelArray(surface)
                for y in range(CANVAS_H):
                    for x in range(CANVAS_W):
                        val = data[y * CANVAS_W + x]
                        color = pal.get(val, (255, 0, 255))
                        px_array[x, y] = surface.map_rgb(color)
                del px_array
                print(f"Loaded raw frame buffer from {path}")
                return surface
        except Exception as e:
            print(f"Failed to load binary frame {path}: {e}")

    try:
        loaded = pygame.image.load(str(path)).convert()
        if loaded.get_size() != (CANVAS_W, CANVAS_H):
            print(f"Notice: Image size is {loaded.get_size()}, target canvas is ({CANVAS_W}, {CANVAS_H})")
            surface = pygame.transform.scale(loaded, (CANVAS_W, CANVAS_H))
        else:
            surface = loaded
        print(f"Loaded image from {path}")
    except Exception as e:
        print(f"Failed to load image {path}: {e}")

    return surface


class TileInspector:
    def __init__(self, image_path: Path | None = None, initial_zoom: float = 3.0):
        pygame.init()
        try:
            pygame.scrap.init()
        except Exception:
            pass

        self.win_w = 1060
        self.win_h = 720
        self.status_bar_h = 32

        self.screen = pygame.display.set_mode((self.win_w, self.win_h), pygame.RESIZABLE)
        pygame.display.set_caption("Pokémon Yellow DOS Port — Tile & Coordinate Inspector")

        self.image_path = image_path
        self.raw_surface = load_image_or_frame(image_path)

        self.zoom: float = float(max(0.5, min(16.0, initial_zoom)))
        self.pan_x: float = 0.0
        self.pan_y: float = 0.0
        self.center_canvas()

        self.show_tile_grid = True
        self.show_step_grid = False
        self.show_gb_viewport = False

        self.hover_tile: Optional[Tuple[int, int]] = None
        self.hover_pixel: Optional[Tuple[int, int]] = None

        # Multi-Selection state
        self.selected_points: Set[Tuple[int, int]] = set()  # {(ty, tx), ...}
        self.selected_ranges: List[Tuple[int, int, int, int]] = []  # [(min_y, min_x, max_y, max_x), ...]

        # Drag state
        self.is_dragging = False
        self.drag_start_tile: Optional[Tuple[int, int]] = None
        self.drag_current_tile: Optional[Tuple[int, int]] = None

        # Panning state
        self.is_panning = False
        self.pan_start_mouse = (0, 0)
        self.pan_start_pos = (0.0, 0.0)
        self.space_down = False
        self.ctrl_down = False

        # Toast notification
        self.toast_message = ""
        self.toast_timer = 0

        self.font = pygame.font.SysFont("monospace", 13, bold=True)
        self.font_small = pygame.font.SysFont("monospace", 11)

    def center_canvas(self):
        """Center the canvas within the current window viewport."""
        viewport_h = self.win_h - self.status_bar_h
        scaled_w = CANVAS_W * self.zoom
        scaled_h = CANVAS_H * self.zoom
        self.pan_x = (self.win_w - scaled_w) / 2.0
        self.pan_y = (viewport_h - scaled_h) / 2.0

    def zoom_to(self, new_zoom: float, pivot_screen_x: float, pivot_screen_y: float):
        """Zoom to new_zoom keeping the canvas point under (pivot_screen_x, pivot_screen_y) fixed."""
        new_zoom = max(0.5, min(16.0, new_zoom))
        if abs(new_zoom - self.zoom) < 1e-4:
            return

        canvas_x = (pivot_screen_x - self.pan_x) / self.zoom
        canvas_y = (pivot_screen_y - self.pan_y) / self.zoom

        self.zoom = new_zoom
        self.pan_x = pivot_screen_x - canvas_x * self.zoom
        self.pan_y = pivot_screen_y - canvas_y * self.zoom

    def show_toast(self, text: str):
        self.toast_message = text
        self.toast_timer = pygame.time.get_ticks() + 2800

    def screen_to_canvas(self, mouse_x: float, mouse_y: float) -> Tuple[float, float]:
        cx = (mouse_x - self.pan_x) / self.zoom
        cy = (mouse_y - self.pan_y) / self.zoom
        return (cx, cy)

    def get_tile_at(self, mouse_x: float, mouse_y: float) -> Optional[Tuple[int, int]]:
        """Convert mouse screen coordinates to tile coordinates (tile_y, tile_x)."""
        if mouse_y >= self.win_h - self.status_bar_h:
            return None
        cx, cy = self.screen_to_canvas(mouse_x, mouse_y)
        if 0 <= cx < CANVAS_W and 0 <= cy < CANVAS_H:
            tx = int(cx // TILE_SIZE)
            ty = int(cy // TILE_SIZE)
            if 0 <= tx < TILES_X and 0 <= ty < TILES_Y:
                return (ty, tx)
        return None

    def get_pixel_at(self, mouse_x: float, mouse_y: float) -> Optional[Tuple[int, int]]:
        """Convert mouse screen coordinates to canvas pixel coordinates (px_y, px_x)."""
        if mouse_y >= self.win_h - self.status_bar_h:
            return None
        cx, cy = self.screen_to_canvas(mouse_x, mouse_y)
        if 0 <= cx < CANVAS_W and 0 <= cy < CANVAS_H:
            return (int(cy), int(cx))
        return None

    def copy_current_selection(self):
        """Build and copy active selection string (or hovered tile) to clipboard."""
        if self.selected_points or self.selected_ranges:
            text = build_selection_string(self.selected_points, self.selected_ranges)
            copy_to_clipboard(text)
            self.show_toast(f"Copied: {text}")
        elif self.hover_tile:
            text = f"P: ({self.hover_tile[0]}, {self.hover_tile[1]})"
            copy_to_clipboard(text)
            self.show_toast(f"Copied: {text}")

    def draw_canvas_and_overlays(self):
        # 1. Scaled Canvas Image
        scaled_w = int(round(CANVAS_W * self.zoom))
        scaled_h = int(round(CANVAS_H * self.zoom))

        if scaled_w > 0 and scaled_h > 0:
            scaled_img = pygame.transform.scale(self.raw_surface, (scaled_w, scaled_h))
            self.screen.blit(scaled_img, (int(round(self.pan_x)), int(round(self.pan_y))))

            # Canvas border
            canvas_rect = pygame.Rect(
                int(round(self.pan_x)), int(round(self.pan_y)),
                scaled_w, scaled_h
            )
            pygame.draw.rect(self.screen, COLOR_CANVAS_BORDER, canvas_rect, 1)

        # 2. Overlay Layer for grids and highlights
        overlay = pygame.Surface((self.win_w, self.win_h), pygame.SRCALPHA)
        ox, oy, z = self.pan_x, self.pan_y, self.zoom

        # 8x8 Tile Grid
        if self.show_tile_grid:
            for tx in range(TILES_X + 1):
                sx = int(round(ox + tx * TILE_SIZE * z))
                sy_start = int(round(oy))
                sy_end = int(round(oy + CANVAS_H * z))
                pygame.draw.line(overlay, COLOR_GRID_TILE, (sx, sy_start), (sx, sy_end))
            for ty in range(TILES_Y + 1):
                sy = int(round(oy + ty * TILE_SIZE * z))
                sx_start = int(round(ox))
                sx_end = int(round(ox + CANVAS_W * z))
                pygame.draw.line(overlay, COLOR_GRID_TILE, (sx_start, sy), (sx_end, sy))

        # 16x16 Step Grid
        if self.show_step_grid:
            step_w = max(1, int(round(z / 2.0)))
            for sx_idx in range(CANVAS_W // STEP_SIZE + 1):
                sx = int(round(ox + sx_idx * STEP_SIZE * z))
                sy_start = int(round(oy))
                sy_end = int(round(oy + CANVAS_H * z))
                pygame.draw.line(overlay, COLOR_GRID_STEP, (sx, sy_start), (sx, sy_end), step_w)
            for sy_idx in range(CANVAS_H // STEP_SIZE + 1):
                sy = int(round(oy + sy_idx * STEP_SIZE * z))
                sx_start = int(round(ox))
                sx_end = int(round(ox + CANVAS_W * z))
                pygame.draw.line(overlay, COLOR_GRID_STEP, (sx_start, sy), (sx_end, sy), step_w)

        # 20x18 Classic GB Viewport guide box
        if self.show_gb_viewport:
            gb_rect = pygame.Rect(
                int(round(ox + 10 * TILE_SIZE * z)),
                int(round(oy + 3 * TILE_SIZE * z)),
                int(round(20 * TILE_SIZE * z)),
                int(round(18 * TILE_SIZE * z))
            )
            pygame.draw.rect(overlay, COLOR_GB_BOX, gb_rect, max(2, int(z)))

        # Draw Selected Ranges
        for min_y, min_x, max_y, max_x in self.selected_ranges:
            r_rect = pygame.Rect(
                int(round(ox + min_x * TILE_SIZE * z)),
                int(round(oy + min_y * TILE_SIZE * z)),
                int(round((max_x - min_x + 1) * TILE_SIZE * z)),
                int(round((max_y - min_y + 1) * TILE_SIZE * z))
            )
            pygame.draw.rect(overlay, COLOR_SEL_FILL, r_rect)
            pygame.draw.rect(overlay, COLOR_SEL_BORDER, r_rect, max(1, int(z)))

        # Draw Selected Points
        for py_tile, px_tile in self.selected_points:
            p_rect = pygame.Rect(
                int(round(ox + px_tile * TILE_SIZE * z)),
                int(round(oy + py_tile * TILE_SIZE * z)),
                int(round(TILE_SIZE * z)),
                int(round(TILE_SIZE * z))
            )
            pygame.draw.rect(overlay, COLOR_POINT_FILL, p_rect)
            pygame.draw.rect(overlay, COLOR_POINT_BORDER, p_rect, max(1, int(z)))

        # Draw Active Drag Selection Box
        if self.is_dragging and self.drag_start_tile and self.drag_current_tile:
            y1, x1 = self.drag_start_tile
            y2, x2 = self.drag_current_tile
            min_y, max_y = min(y1, y2), max(y1, y2)
            min_x, max_x = min(x1, x2), max(x1, x2)
            drag_rect = pygame.Rect(
                int(round(ox + min_x * TILE_SIZE * z)),
                int(round(oy + min_y * TILE_SIZE * z)),
                int(round((max_x - min_x + 1) * TILE_SIZE * z)),
                int(round((max_y - min_y + 1) * TILE_SIZE * z))
            )
            pygame.draw.rect(overlay, COLOR_SEL_FILL, drag_rect)
            pygame.draw.rect(overlay, COLOR_SEL_BORDER, drag_rect, max(1, int(z)))

        # Draw Hover Box
        if self.hover_tile and not self.is_dragging and not self.is_panning:
            ty, tx = self.hover_tile
            hover_rect = pygame.Rect(
                int(round(ox + tx * TILE_SIZE * z)),
                int(round(oy + ty * TILE_SIZE * z)),
                int(round(TILE_SIZE * z)),
                int(round(TILE_SIZE * z))
            )
            pygame.draw.rect(overlay, COLOR_HOVER_FILL, hover_rect)
            pygame.draw.rect(overlay, COLOR_HOVER_BORDER, hover_rect, max(1, int(z)))

        self.screen.blit(overlay, (0, 0))

    def draw_hud(self):
        # Top-left HUD card
        pad = 8
        lines = []

        if self.hover_tile:
            ty, tx = self.hover_tile
            py, px = self.hover_pixel if self.hover_pixel else (ty * 8, tx * 8)
            sy, sx = ty // 2, tx // 2

            primary_str = f"Tile (Y, X) = ({ty}, {tx})"
            sec_str = f"Px (Y, X): ({py:>3}, {px:>3}) | Step (Y, X): ({sy:>2}, {sx:>2})"
            lines.append((primary_str, COLOR_HUD_ACCENT))
            lines.append((sec_str, COLOR_HUD_TEXT))
        else:
            lines.append(("Hover over canvas to inspect (Y, X) coordinates", COLOR_HUD_TEXT))

        # Show active selection summary
        if self.selected_points or self.selected_ranges:
            sel_str = build_selection_string(self.selected_points, self.selected_ranges)
            lines.append((f"Selection: {sel_str}", COLOR_SEL_BORDER))
        elif self.is_dragging and self.drag_start_tile and self.drag_current_tile:
            y1, x1 = self.drag_start_tile
            y2, x2 = self.drag_current_tile
            min_y, max_y = min(y1, y2), max(y1, y2)
            min_x, max_x = min(x1, x2), max(x1, x2)
            lines.append((f"Selecting: R: [{min_y}, {max_y}]×[{min_x}, {max_x}]", COLOR_SEL_BORDER))

        rendered_lines = []
        max_w = 0
        total_h = pad * 2
        for text, color in lines:
            surf = self.font.render(text, True, color)
            rendered_lines.append(surf)
            max_w = max(max_w, surf.get_width())
            total_h += surf.get_height() + 3

        hud_w = max_w + pad * 2
        hud_h = total_h

        hud_surf = pygame.Surface((hud_w, hud_h), pygame.SRCALPHA)
        hud_surf.fill(COLOR_HUD_BG)
        pygame.draw.rect(hud_surf, (80, 90, 110, 200), (0, 0, hud_w, hud_h), 1)

        y_offset = pad
        for surf in rendered_lines:
            hud_surf.blit(surf, (pad, y_offset))
            y_offset += surf.get_height() + 3

        self.screen.blit(hud_surf, (10, 10))

        # Bottom status bar
        status_y = self.win_h - self.status_bar_h
        status_bar = pygame.Surface((self.win_w, self.status_bar_h))
        status_bar.fill((20, 22, 28))
        pygame.draw.line(status_bar, (50, 54, 66), (0, 0), (self.win_w, 0), 1)

        # Controls info text
        zoom_str = f"{self.zoom:.2f}x" if self.zoom % 1 != 0 else f"{int(self.zoom)}x"
        ctrl_text = f"Grid [T]: {'ON' if self.show_tile_grid else 'OFF'} | Step [S]: {'ON' if self.show_step_grid else 'OFF'} | GB-Box [V]: {'ON' if self.show_gb_viewport else 'OFF'} | Zoom: {zoom_str}"
        ctrl_surf = self.font_small.render(ctrl_text, True, (170, 175, 190))
        status_bar.blit(ctrl_surf, (10, 9))

        # Tips text
        tip_text = "R-Click: P:(y,x) | L-Drag: R:[y0,y1]×[x0,x1] | Ctrl: Multi-Select | Mid-Drag/Space: Pan | C: Copy"
        tip_surf = self.font_small.render(tip_text, True, (130, 140, 155))
        tip_x = self.win_w - tip_surf.get_width() - 10
        if tip_x > ctrl_surf.get_width() + 20:
            status_bar.blit(tip_surf, (tip_x, 9))

        self.screen.blit(status_bar, (0, status_y))

        # Toast notification
        if pygame.time.get_ticks() < self.toast_timer and self.toast_message:
            toast_surf = self.font.render(self.toast_message, True, COLOR_TOAST_TEXT)
            tw, th = toast_surf.get_width() + 24, toast_surf.get_height() + 12
            toast_box = pygame.Surface((tw, th), pygame.SRCALPHA)
            toast_box.fill(COLOR_TOAST_BG)
            pygame.draw.rect(toast_box, (200, 255, 200), (0, 0, tw, th), 1)
            toast_box.blit(toast_surf, (12, 6))
            tx = (self.win_w - tw) // 2
            ty = self.win_h - 70
            self.screen.blit(toast_box, (tx, ty))

    def run(self):
        clock = pygame.time.Clock()
        running = True

        while running:
            mouse_x, mouse_y = pygame.mouse.get_pos()
            self.hover_tile = self.get_tile_at(mouse_x, mouse_y)
            self.hover_pixel = self.get_pixel_at(mouse_x, mouse_y)
            mods = pygame.key.get_mods()
            self.ctrl_down = bool(mods & pygame.KMOD_CTRL)

            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    running = False

                elif event.type == pygame.VIDEORESIZE:
                    self.win_w = max(400, event.w)
                    self.win_h = max(300, event.h)
                    self.screen = pygame.display.set_mode((self.win_w, self.win_h), pygame.RESIZABLE)

                elif event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_ESCAPE:
                        if self.selected_points or self.selected_ranges:
                            self.selected_points.clear()
                            self.selected_ranges.clear()
                            self.show_toast("Selections Cleared")
                        else:
                            running = False
                    elif event.key == pygame.K_q:
                        running = False
                    elif event.key == pygame.K_SPACE:
                        self.space_down = True
                    elif event.key in (pygame.K_DELETE, pygame.K_BACKSPACE):
                        self.selected_points.clear()
                        self.selected_ranges.clear()
                        self.show_toast("Selections Cleared")
                    elif event.key in (pygame.K_t, pygame.K_g):
                        self.show_tile_grid = not self.show_tile_grid
                    elif event.key == pygame.K_s:
                        self.show_step_grid = not self.show_step_grid
                    elif event.key == pygame.K_v:
                        self.show_gb_viewport = not self.show_gb_viewport
                    elif event.key in (pygame.K_0, pygame.K_r, pygame.K_HOME):
                        self.zoom = 3.0
                        self.center_canvas()
                        self.show_toast("Zoom & Pan Reset")
                    elif event.key == pygame.K_c:
                        self.copy_current_selection()
                    elif event.key in (pygame.K_PLUS, pygame.K_EQUALS, pygame.K_KP_PLUS):
                        self.zoom_to(self.zoom * 1.25, self.win_w / 2.0, (self.win_h - self.status_bar_h) / 2.0)
                    elif event.key in (pygame.K_MINUS, pygame.K_KP_MINUS):
                        self.zoom_to(self.zoom / 1.25, self.win_w / 2.0, (self.win_h - self.status_bar_h) / 2.0)
                    elif event.key == pygame.K_LEFT:
                        self.pan_x += 32
                    elif event.key == pygame.K_RIGHT:
                        self.pan_x -= 32
                    elif event.key == pygame.K_UP:
                        self.pan_y += 32
                    elif event.key == pygame.K_DOWN:
                        self.pan_y -= 32

                elif event.type == pygame.KEYUP:
                    if event.key == pygame.K_SPACE:
                        self.space_down = False
                        if not pygame.mouse.get_pressed()[1]:
                            self.is_panning = False

                elif event.type == pygame.MOUSEWHEEL:
                    factor = 1.18 if event.y > 0 else (1.0 / 1.18)
                    self.zoom_to(self.zoom * factor, mouse_x, mouse_y)

                elif event.type == pygame.MOUSEBUTTONDOWN:
                    tile = self.get_tile_at(event.pos[0], event.pos[1])

                    if event.button == 2 or (event.button == 1 and self.space_down):  # Middle click or Space+Left: Pan
                        self.is_panning = True
                        self.pan_start_mouse = event.pos
                        self.pan_start_pos = (self.pan_x, self.pan_y)

                    elif event.button == 1 and not self.space_down:  # Left click: Start drag selection or point select
                        if not (mods & pygame.KMOD_CTRL):
                            # Clicking without Ctrl resets existing selections unless clicking outside
                            if tile is None:
                                self.selected_points.clear()
                                self.selected_ranges.clear()
                            else:
                                self.selected_points.clear()
                                self.selected_ranges.clear()

                        if tile:
                            self.is_dragging = True
                            self.drag_start_tile = tile
                            self.drag_current_tile = tile

                    elif event.button == 3:  # Right click: Single point copy / toggle
                        if tile:
                            if not (mods & pygame.KMOD_CTRL):
                                self.selected_points.clear()
                                self.selected_ranges.clear()
                                self.selected_points.add(tile)
                            else:
                                if tile in self.selected_points:
                                    self.selected_points.remove(tile)
                                else:
                                    self.selected_points.add(tile)

                            self.copy_current_selection()

                elif event.type == pygame.MOUSEBUTTONUP:
                    if event.button == 2 or event.button == 1:
                        if self.is_panning:
                            self.is_panning = False

                        if self.is_dragging:
                            self.is_dragging = False
                            tile = self.get_tile_at(event.pos[0], event.pos[1])
                            if tile and self.drag_start_tile:
                                self.drag_current_tile = tile
                                y1, x1 = self.drag_start_tile
                                y2, x2 = self.drag_current_tile
                                min_y, max_y = min(y1, y2), max(y1, y2)
                                min_x, max_x = min(x1, x2), max(x1, x2)

                                if min_y == max_y and min_x == max_x:
                                    # Single tile clicked
                                    if (mods & pygame.KMOD_CTRL):
                                        if (min_y, min_x) in self.selected_points:
                                            self.selected_points.remove((min_y, min_x))
                                        else:
                                            self.selected_points.add((min_y, min_x))
                                    else:
                                        self.selected_points.add((min_y, min_x))
                                else:
                                    # Range box dragged
                                    new_range = (min_y, min_x, max_y, max_x)
                                    if not (mods & pygame.KMOD_CTRL):
                                        self.selected_ranges = [new_range]
                                    else:
                                        self.selected_ranges.append(new_range)

                                self.copy_current_selection()

                elif event.type == pygame.MOUSEMOTION:
                    if self.is_panning:
                        dx = event.pos[0] - self.pan_start_mouse[0]
                        dy = event.pos[1] - self.pan_start_mouse[1]
                        self.pan_x = self.pan_start_pos[0] + dx
                        self.pan_y = self.pan_start_pos[1] + dy
                    elif self.is_dragging:
                        tile = self.get_tile_at(event.pos[0], event.pos[1])
                        if tile:
                            self.drag_current_tile = tile

            # --- Rendering ---
            self.screen.fill(COLOR_BG)
            self.draw_canvas_and_overlays()
            self.draw_hud()

            pygame.display.flip()
            clock.tick(60)

        pygame.quit()


def find_default_image() -> Optional[Path]:
    """Look for default image candidates in repository."""
    candidates = [
        Path("dos_port/FRAME.BIN"),
        Path("dos_port/FRAME_BASELINE.BIN"),
        Path("dos_port/capture/debug_images/grid_tile_8x8.png"),
    ]
    for c in candidates:
        if c.exists():
            return c
    return None


def main():
    parser = argparse.ArgumentParser(description="Pokémon Yellow DOS Port Tile & Coordinate Inspector")
    parser.add_argument("image", nargs="?", help="Path to image (PNG/BMP/JPG) or FRAME.BIN framebuffer")
    parser.add_argument("--zoom", "-z", type=float, default=3.0, help="Initial zoom scale factor (default 3.0)")
    args = parser.parse_args()

    image_path = Path(args.image) if args.image else find_default_image()
    app = TileInspector(image_path=image_path, initial_zoom=args.zoom)
    app.run()


if __name__ == "__main__":
    main()
