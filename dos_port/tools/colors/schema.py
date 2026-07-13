"""Stable palette-sidecar model and validation."""
from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path

from gfx_core.palettes import palette_enums, parse_monster_palettes

RGB = tuple[int, int, int]


def _rgb(value: object, where: str) -> RGB:
    if not isinstance(value, list) or len(value) != 3 or any(
            not isinstance(v, int) or not 0 <= v <= 63 for v in value):
        raise ValueError(f"{where}: RGB must be three 0..63 integers")
    return tuple(value)  # type: ignore[return-value]


def _palette(value: object, where: str) -> tuple[RGB, RGB, RGB, RGB]:
    if not isinstance(value, list) or len(value) != 4:
        raise ValueError(f"{where}: palette must contain four RGB colors")
    return tuple(_rgb(v, f"{where}[{i}]") for i, v in enumerate(value))  # type: ignore[return-value]


@dataclass
class Sidecar:
    pal_overrides: dict[str, tuple[RGB, RGB, RGB, RGB]] = field(default_factory=dict)
    species_overrides: dict[str, dict] = field(default_factory=dict)
    screen_overrides: dict[str, dict] = field(default_factory=dict)
    repaint: dict[str, dict] = field(default_factory=dict)

    def validate(self) -> None:
        pals, screens = palette_enums()
        known_species = parse_monster_palettes()
        for name in self.pal_overrides:
            if name not in pals:
                raise ValueError(f"pal_overrides: unknown palette {name}")
        for species, row in self.species_overrides.items():
            if species not in known_species:
                raise ValueError(f"species_overrides: unknown species {species}")
            if not isinstance(row, dict) or set(row) - {"pal", "colors"}:
                raise ValueError(f"species_overrides.{species}: expected pal and/or colors")
            if "pal" in row and row["pal"] not in pals:
                raise ValueError(f"species_overrides.{species}: unknown palette {row['pal']}")
            if "colors" in row:
                _palette(row["colors"], f"species_overrides.{species}.colors")
        for screen, row in self.screen_overrides.items():
            if screen not in screens:
                raise ValueError(f"screen_overrides: unknown command {screen}")
            if not isinstance(row, dict):
                raise ValueError(f"screen_overrides.{screen}: expected object")
            for slot, pal in row.items():
                if slot not in {f"slot{i}" for i in range(8)} or pal not in pals:
                    raise ValueError(f"screen_overrides.{screen}.{slot}: bad slot or palette")
        for asset, row in self.repaint.items():
            if not isinstance(row, dict):
                raise ValueError(f"repaint.{asset}: expected object")
            grid = row.get("tile_pal", [])
            if grid and (not isinstance(grid, list) or any(not isinstance(v, int) or not 0 <= v <= 7 for v in grid)):
                raise ValueError(f"repaint.{asset}.tile_pal: slot ids must be 0..7")
            extra = row.get("extra_palettes", [])
            if not isinstance(extra, list) or len(extra) > 4:
                raise ValueError(f"repaint.{asset}.extra_palettes: at most four palettes")
            for i, pal in enumerate(extra):
                _palette(pal, f"repaint.{asset}.extra_palettes[{i}]")


def load(path: str | Path) -> Sidecar:
    raw = json.loads(Path(path).read_text())
    if raw.get("version") != 1:
        raise ValueError(f"{path}: expected version 1")
    sidecar = Sidecar(
        pal_overrides={k: _palette(v, f"pal_overrides.{k}")
                       for k, v in raw.get("pal_overrides", {}).items()},
        species_overrides=raw.get("species_overrides", {}),
        screen_overrides=raw.get("screen_overrides", {}),
        repaint=raw.get("repaint", {}),
    )
    sidecar.validate()
    return sidecar


def save(sidecar: Sidecar, path: str | Path) -> None:
    """Write stable, delta-only JSON after validating editor changes."""
    sidecar.validate()
    out = {"version": 1, "pal_overrides": sidecar.pal_overrides,
           "species_overrides": sidecar.species_overrides,
           "screen_overrides": sidecar.screen_overrides,
           "repaint": sidecar.repaint}
    Path(path).write_text(json.dumps(out, indent=2) + "\n")
