#!/usr/bin/env python3
"""C2 shade editor — palette-family RGB editing with Pokémon/battle previews.

Controls: [/] choose palette, ,/. choose species (or trainer), t toggle
mon/trainer battle mock, 2-4 choose shade (shade 1 is the shared white
background and is read-only), arrow keys adjust R/G, PgUp/PgDn adjust B, S saves
sidecar deltas, Esc quits.

Every palette starts from pret's CGB colours auto-mapped to VGA (six-bit); the
sidecar only stores manual deltas on top, so an untouched palette reads "auto
GBC->VGA". In mon mode each species previews in ITS OWN palette (pret
MonsterPalettes, base unless overridden), so cycling species shows real
per-species colours and the edited palette follows the sprite; [/] steps palette
families directly and snaps to a species that uses the one you land on. The
battle mock shows real sprites: mon mode = enemy front sprite + the player-mon
back sprite; trainer mode = enemy trainer front pic + Red's back sprite.
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

# Shade 0 is the shared white background across every pret CGB palette (all 40
# rows of CGBBasePalettes are 31,31,31 at index 0). The battle BG and OBJ colour
# 0 come from it, so it is read-only here — editing it per-palette would recolour
# the whole battle background and diverge from the GBC. (When a mon genuinely
# reuses that white for its own body, it is shared with the background and is
# likewise left alone — same slot, same rule.)
BG_SHADE = 0


class Editor:
    def __init__(self, path: Path, zoom: int):
        self.path, self.zoom = path, zoom
        self.sidecar = schema.load(path)
        self.base = palettes.parse_cgb_base_palettes()
        self.pals = list(self.base)
        self.species = sprites.previewable_species()   # dex order, no MISSINGNO
        self.trainers = sprites.trainer_pngs()          # (label, path) list
        self.mon_pal = palettes.parse_monster_palettes()  # species -> PAL_* family
        self.mode = "mon"                               # "mon" | "trainer"
        self.pi = self.si = self.ti = 0
        self.shade = BG_SHADE + 1                        # start on an editable slot
        self.sync_pal_to_species()                       # each mon shows its own palette
        pygame.init(); self.screen = pygame.display.set_mode((720, 520))
        self.font = pygame.font.SysFont("monospace", 17)

    def species_pal_name(self) -> str:
        """The PAL_* family the current species uses (its sidecar remap, else the
        pret MonsterPalettes default)."""
        sp = self.species[self.si]
        return self.sidecar.species_overrides.get(sp, {}).get("pal", self.mon_pal[sp])

    def sync_pal_to_species(self):
        """In mon mode the edited palette IS the species' palette, so a mon always
        previews in its own colours (base unless overridden) instead of whatever
        family the cursor last sat on."""
        if self.mode == "mon":
            name = self.species_pal_name()
            if name in self.pals:
                self.pi = self.pals.index(name)

    def snap_species_to_pal(self):
        """After a raw palette step in mon mode, jump to a species that actually
        uses it so the sprite matches the palette being edited; leave the sprite
        as-is for a non-mon palette (route/UI) that no species uses."""
        if self.mode != "mon":
            return
        target = self.pals[self.pi]
        for i, sp in enumerate(self.species):
            if self.mon_pal[sp] == target:
                self.si = i
                return

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
            self.sync_pal_to_species()

    def draw(self):
        pal = self.active(); subj, name = self.subject()
        slots = [pal, pal, pal, pal]
        image = render.battle_mock(subj, slots, self.mode)
        surf = pygame.image.fromstring(image.tobytes(), image.size, "RGB")
        self.screen.fill((22, 22, 28)); self.screen.blit(surf, (0, 0))
        x, y = 332, 16
        subj_kind = "trainer" if self.mode == "trainer" else "species"
        # Every palette starts from pret's CGB colours auto-mapped to VGA; the
        # sidecar only holds manual deltas. Show which the active palette is so
        # the automap default is visible, not mistaken for hand-entered values.
        src = "override" if self.pals[self.pi] in self.sidecar.pal_overrides else "auto"
        lines = [f"palette {self.pals[self.pi]} ({src})", f"{subj_kind} {name}",
                 "[/] palette  [,/.] subject", "t mon/trainer battle",
                 "2-4 shade  arrows R/G  Pg B", "1 = bg (locked)", "S save  Esc quit"]
        for line in lines:
            self.screen.blit(self.font.render(line, True, (230, 230, 230)), (x, y)); y += 24
        y += 8
        for i, color in enumerate(pal):
            rgb = tuple(v * 255 // 63 for v in color)
            locked = i == BG_SHADE
            pygame.draw.rect(self.screen, rgb, (x, y, 80, 32))
            border = (110, 110, 120) if locked else \
                     (255, 80, 80) if i == self.shade else (220, 220, 220)
            pygame.draw.rect(self.screen, border, (x, y, 80, 32), 2)
            label = f"{i+1}: {color}" + ("  bg lock" if locked else "")
            tint = (150, 150, 160) if locked else (230, 230, 230)
            self.screen.blit(self.font.render(label, True, tint), (x + 92, y + 7)); y += 40
        pygame.display.flip()

    def key(self, key):
        if self.shade == BG_SHADE:
            return                                       # shared bg white — read-only
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
                elif ev.key == pygame.K_LEFTBRACKET: self.pi = (self.pi - 1) % len(self.pals); self.snap_species_to_pal()
                elif ev.key == pygame.K_RIGHTBRACKET: self.pi = (self.pi + 1) % len(self.pals); self.snap_species_to_pal()
                elif ev.key == pygame.K_COMMA: self.cycle_subject(-1)
                elif ev.key == pygame.K_PERIOD: self.cycle_subject(1)
                elif ev.key == pygame.K_t:
                    self.mode = "trainer" if self.mode == "mon" else "mon"; self.sync_pal_to_species()
                elif pygame.K_1 <= ev.key <= pygame.K_4: self.shade = ev.key - pygame.K_1
                elif ev.key == pygame.K_s: self.save()
            self.draw(); pygame.time.wait(16)


def main():
    ap = argparse.ArgumentParser(); ap.add_argument("sidecar", nargs="?", type=Path, default=HERE.parent / "assets/colors/palettes.json")
    ap.add_argument("--zoom", type=int, default=1); args = ap.parse_args()
    Editor(args.sidecar, args.zoom).run(); pygame.quit()


if __name__ == "__main__": main()
