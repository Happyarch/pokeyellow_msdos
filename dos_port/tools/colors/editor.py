#!/usr/bin/env python3
"""C2 shade editor — palette-family RGB editing with Pokémon/battle previews.

Controls: [/] choose palette, ,/. choose species (or trainer), t toggle
mon/trainer battle mock, 1-4 choose shade, arrow keys adjust R/G, PgUp/PgDn
adjust B, S saves sidecar deltas, Esc quits.

The battle mock shows the active palette on real sprites: mon mode = enemy
front sprite + the player-mon back sprite; trainer mode = enemy trainer front
pic + Red's back sprite.
"""
from __future__ import annotations

import argparse
from pathlib import Path
import sys
import pygame

HERE = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(HERE))
from colors import render, schema
from gfx_core import palettes, sprites


class Editor:
    def __init__(self, path: Path, zoom: int):
        self.path, self.zoom = path, zoom
        self.sidecar = schema.load(path)
        self.base = palettes.parse_cgb_base_palettes()
        self.pals = list(self.base)
        self.species = sprites.previewable_species()   # dex order, no MISSINGNO
        self.trainers = sprites.trainer_pngs()          # (label, path) list
        self.mode = "mon"                               # "mon" | "trainer"
        self.pi = self.si = self.ti = self.shade = 0
        pygame.init(); self.screen = pygame.display.set_mode((640, 520))
        self.font = pygame.font.SysFont("monospace", 17)

    def active(self):
        name = self.pals[self.pi]
        return [tuple(c) for c in self.sidecar.pal_overrides.get(name, self.base[name])]

    def save(self):
        schema.save(self.sidecar, self.path)
        print(f"saved {self.path}; run tools/colorize.py --gen")

    def subject(self):
        """(render subject, display name) for the active mock mode."""
        if self.mode == "trainer":
            label, path = self.trainers[self.ti]
            return path, label
        name = self.species[self.si]
        return name, name

    def cycle_subject(self, step: int):
        if self.mode == "trainer":
            self.ti = (self.ti + step) % len(self.trainers)
        else:
            self.si = (self.si + step) % len(self.species)

    def draw(self):
        pal = self.active(); subj, name = self.subject()
        slots = [pal, pal, pal, pal]
        image = render.battle_mock(subj, slots, self.mode)
        surf = pygame.image.fromstring(image.tobytes(), image.size, "RGB")
        self.screen.fill((22, 22, 28)); self.screen.blit(surf, (0, 0))
        x, y = 332, 16
        subj_kind = "trainer" if self.mode == "trainer" else "species"
        lines = [f"palette {self.pals[self.pi]}", f"{subj_kind} {name}",
                 "[/] palette  [,/.] subject", "t mon/trainer battle",
                 "1-4 shade  arrows R/G  Pg B", "S save  Esc quit"]
        for line in lines:
            self.screen.blit(self.font.render(line, True, (230, 230, 230)), (x, y)); y += 24
        y += 8
        for i, color in enumerate(pal):
            rgb = tuple(v * 255 // 63 for v in color)
            pygame.draw.rect(self.screen, rgb, (x, y, 80, 32))
            pygame.draw.rect(self.screen, (255, 80, 80) if i == self.shade else (220,220,220), (x, y, 80, 32), 2)
            self.screen.blit(self.font.render(f"{i+1}: {color}", True, (230,230,230)), (x+92, y+7)); y += 40
        pygame.display.flip()

    def key(self, key):
        if key == pygame.K_LEFT: delta = (-1, 0, 0)
        elif key == pygame.K_RIGHT: delta = (1, 0, 0)
        elif key == pygame.K_UP: delta = (0, 1, 0)
        elif key == pygame.K_DOWN: delta = (0, -1, 0)
        elif key == pygame.K_PAGEUP: delta = (0, 0, 1)
        elif key == pygame.K_PAGEDOWN: delta = (0, 0, -1)
        else: return
        colors = self.active(); old = colors[self.shade]
        colors[self.shade] = tuple(max(0, min(63, old[i] + delta[i])) for i in range(3))
        self.sidecar.pal_overrides[self.pals[self.pi]] = tuple(colors)

    def run(self):
        while True:
            for ev in pygame.event.get():
                if ev.type == pygame.QUIT or (ev.type == pygame.KEYDOWN and ev.key == pygame.K_ESCAPE): return
                if ev.type != pygame.KEYDOWN: continue
                if ev.key in (pygame.K_LEFT, pygame.K_RIGHT, pygame.K_UP, pygame.K_DOWN, pygame.K_PAGEUP, pygame.K_PAGEDOWN): self.key(ev.key)
                elif ev.key == pygame.K_LEFTBRACKET: self.pi = (self.pi - 1) % len(self.pals)
                elif ev.key == pygame.K_RIGHTBRACKET: self.pi = (self.pi + 1) % len(self.pals)
                elif ev.key == pygame.K_COMMA: self.cycle_subject(-1)
                elif ev.key == pygame.K_PERIOD: self.cycle_subject(1)
                elif ev.key == pygame.K_t: self.mode = "trainer" if self.mode == "mon" else "mon"
                elif pygame.K_1 <= ev.key <= pygame.K_4: self.shade = ev.key - pygame.K_1
                elif ev.key == pygame.K_s: self.save()
            self.draw(); pygame.time.wait(16)


def main():
    ap = argparse.ArgumentParser(); ap.add_argument("sidecar", nargs="?", type=Path, default=HERE.parent / "assets/colors/palettes.json")
    ap.add_argument("--zoom", type=int, default=1); args = ap.parse_args()
    Editor(args.sidecar, args.zoom).run(); pygame.quit()


if __name__ == "__main__": main()
