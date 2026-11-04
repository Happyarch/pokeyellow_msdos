"""Map-authoring sidecars and shared block-layout composition.

The map editor and asset generators use this module so a port-expanded map has
one definition of its dimensions and bytes.  Sidecars retain pret map files as
their immutable base; schema 2 adds edge extents and sparse authored cells.
"""
from __future__ import annotations

from dataclasses import dataclass, field
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
ASSETS = ROOT / "dos_port" / "assets"
OVERRIDES = ASSETS / "map_overrides"


@dataclass(frozen=True)
class Extents:
    north: int = 0
    west: int = 0
    south: int = 0
    east: int = 0

    def dimensions(self, width: int, height: int) -> tuple[int, int]:
        return width + self.west + self.east, height + self.north + self.south

    def tile_delta(self) -> tuple[int, int]:
        """Automatic map-local (Y, X) tile translation for north/west growth."""
        return self.north * 4, self.west * 4


@dataclass
class MapDiff:
    pascal: str
    extents: Extents = field(default_factory=Extents)
    base_blocks: dict[tuple[int, int], int] = field(default_factory=dict)
    added_blocks: dict[tuple[int, int], int] = field(default_factory=dict)
    recipes: list[dict] = field(default_factory=list)
    objects: dict[str, dict] = field(default_factory=dict)
    warps: dict[str, dict] = field(default_factory=dict)
    extra: dict = field(default_factory=dict)
    schema_version: int = 1

    @property
    def is_v2(self) -> bool:
        return bool(self.schema_version == 2 or self.extents != Extents()
                    or self.added_blocks or self.recipes or self.objects
                    or self.warps or self.extra)


def path_for(pascal: str) -> Path:
    return OVERRIDES / f"{pascal}.json"


def _cells(raw: object, field_name: str) -> dict[tuple[int, int], int]:
    if raw is None:
        return {}
    if not isinstance(raw, list):
        raise ValueError(f"{field_name}: expected [[y,x,block], ...]")
    result = {}
    for cell in raw:
        if not (isinstance(cell, list) and len(cell) == 3
                and all(isinstance(v, int) for v in cell)):
            raise ValueError(f"{field_name}: invalid cell {cell!r}")
        y, x, block = cell
        result[(y, x)] = block
    return result


def load(pascal: str) -> MapDiff:
    p = path_for(pascal)
    if not p.exists():
        return MapDiff(pascal)
    raw = json.loads(p.read_text())
    if raw.get("schema") != 2:
        # Existing map overrides are a v1 subset, retained verbatim.
        return MapDiff(pascal, base_blocks=_cells(raw.get("cells", []), "cells"))
    if raw.get("map") != pascal:
        raise ValueError(f"{p}: map is {raw.get('map')!r}, expected {pascal!r}")
    ext = raw.get("extent_blocks", {})
    if not isinstance(ext, dict):
        raise ValueError(f"{p}: extent_blocks must be an object")
    keys = ("north", "west", "south", "east")
    if any(k not in keys for k in ext) or any(
            not isinstance(ext.get(k, 0), int) or ext.get(k, 0) < 0 for k in keys):
        raise ValueError(f"{p}: extents must be non-negative integer block counts")
    recipes = raw.get("recipes", [])
    if not isinstance(recipes, list):
        raise ValueError(f"{p}: recipes must be a list")
    objects = raw.get("objects", {})
    if not isinstance(objects, dict):
        raise ValueError(f"{p}: objects must be an object")
    warps = raw.get("warps", {})
    if not isinstance(warps, dict):
        raise ValueError(f"{p}: warps must be an object")
    if any(not isinstance(v, dict) for v in warps.values()):
        raise ValueError(f"{p}: every warps entry must be an object")
    return MapDiff(
        pascal,
        Extents(**{k: ext.get(k, 0) for k in keys}),
        _cells(raw.get("base_blocks", []), "base_blocks"),
        _cells(raw.get("added_blocks", []), "added_blocks"),
        recipes,
        objects,
        warps,
        {key: value for key, value in raw.items() if key not in
         {"schema", "map", "extent_blocks", "base_blocks", "added_blocks",
          "recipes", "objects", "warps"}},
        2,
    )


def write(diff: MapDiff) -> None:
    """Write a stable schema-2 document, deleting an empty legacy-equivalent one."""
    OVERRIDES.mkdir(parents=True, exist_ok=True)
    p = path_for(diff.pascal)
    if not diff.is_v2:
        if not diff.base_blocks:
            if p.exists():
                p.unlink()
            return
        out = {"map": diff.pascal,
               "cells": [[y, x, b] for (y, x), b in sorted(diff.base_blocks.items())]}
    else:
        out = {
            **diff.extra,
            "schema": 2,
            "map": diff.pascal,
            "extent_blocks": {"north": diff.extents.north, "west": diff.extents.west,
                              "south": diff.extents.south, "east": diff.extents.east},
            "base_blocks": [[y, x, b] for (y, x), b in sorted(diff.base_blocks.items())],
            "added_blocks": [[y, x, b] for (y, x), b in sorted(diff.added_blocks.items())],
            "recipes": diff.recipes,
            "objects": diff.objects,
            "warps": diff.warps,
        }
    p.write_text(json.dumps(out, indent=1) + "\n")


def expanded_dims(pascal: str, width: int, height: int) -> tuple[int, int]:
    return load(pascal).extents.dimensions(width, height)


def base_to_final(diff: MapDiff, y: int, x: int, base_w: int) -> tuple[int, int]:
    """Map a base block to its final canvas location, including insert recipes."""
    e = diff.extents
    if x == base_w - 1:
        for recipe in diff.recipes:
            if recipe.get("kind") == "repeat_base_column" and recipe.get("edge") == "east":
                x += recipe.get("count", 0)
    return y + e.north, x + e.west


def final_to_base(diff: MapDiff, y: int, x: int, base_w: int,
                  base_h: int) -> tuple[int, int] | None:
    """Inverse of base_to_final, or None for an authored expansion cell."""
    for by in range(base_h):
        for bx in range(base_w):
            if base_to_final(diff, by, bx, base_w) == (y, x):
                return by, bx
    return None


def recipe_cells(diff: MapDiff, base_w: int, base_h: int) -> set[tuple[int, int]]:
    """Final-canvas cells a recipe writes, so callers can avoid clobbering them.

    Recipes run before `added_blocks` in compose_layout, so an explicit added
    cell would silently overwrite a recipe's generated content.  The map
    expander uses this set to fill only genuinely uncovered new cells.
    """
    e = diff.extents
    covered: set[tuple[int, int]] = set()
    for recipe in diff.recipes:
        if recipe.get("kind") != "repeat_base_column" or recipe.get("edge") != "east":
            continue
        count = recipe.get("count")
        if not isinstance(count, int):
            continue
        edge = e.west + base_w - 1
        for y in range(e.north, e.north + base_h):
            for x in range(edge, edge + count + 1):
                covered.add((y, x))
    return covered


def _apply_recipe(canvas: bytearray, width: int, height: int, base: bytes,
                  base_w: int, base_h: int, ext: Extents, recipe: dict) -> None:
    """Apply compact authored expansion recipes before explicit cells.

    `repeat_base_column` intentionally inserts before the east edge.  It exists
    for the Dock migration but is generally useful for water/road continuation.
    """
    if recipe.get("kind") != "repeat_base_column" or recipe.get("edge") != "east":
        raise ValueError(f"unsupported map recipe {recipe!r}")
    source_x = recipe.get("source_x")
    count = recipe.get("count")
    if not isinstance(source_x, int) or not isinstance(count, int):
        raise ValueError(f"invalid repeat_base_column recipe {recipe!r}")
    if not (0 <= count <= ext.east) or not 0 <= source_x < base_w - 1:
        raise ValueError(f"recipe does not match east extent/base width: {recipe!r}")
    row_overrides = recipe.get("row_overrides", [])
    if not isinstance(row_overrides, list):
        raise ValueError("recipe.row_overrides must be [[base_y,block], ...]")
    overrides: dict[int, int] = {}
    for row in row_overrides:
        if not (isinstance(row, list) and len(row) == 2
                and all(isinstance(v, int) for v in row)):
            raise ValueError(f"invalid recipe row override {row!r}")
        overrides[row[0]] = row[1]
    for y in range(base_h):
        edge = ext.west + base_w - 1
        # Recipes insert before the existing edge rather than replacing it.
        canvas[(y + ext.north) * width + edge + count] = \
            canvas[(y + ext.north) * width + edge]
        value = overrides.get(y, base[y * base_w + source_x])
        for x in range(count):
            # The original edge occupies final x = west + base_w - 1.
            canvas[(y + ext.north) * width + edge + x] = value


def compose_layout(pascal: str, base: bytes, base_w: int, base_h: int,
                   extra_base_blocks: dict[tuple[int, int], int] | None = None
                   ) -> tuple[bytearray, int, int, MapDiff]:
    """Compose raw pret layout plus its authored diff into final block bytes."""
    if len(base) != base_w * base_h:
        raise ValueError(f"{pascal}: base layout has {len(base)} bytes, expected "
                         f"{base_w}x{base_h}")
    diff = load(pascal)
    width, height = diff.extents.dimensions(base_w, base_h)
    canvas = bytearray(width * height)
    e = diff.extents
    for y in range(base_h):
        d = (y + e.north) * width + e.west
        canvas[d:d + base_w] = base[y * base_w:(y + 1) * base_w]
    base_blocks = dict(diff.base_blocks)
    if extra_base_blocks:
        base_blocks.update(extra_base_blocks)
    for (y, x), block in base_blocks.items():
        if not (0 <= y < base_h and 0 <= x < base_w):
            raise ValueError(f"{pascal}: base block ({y},{x}) outside "
                             f"{base_w}x{base_h}")
        if not 0 <= block <= 0xff:
            raise ValueError(f"{pascal}: block {block} outside byte range")
        canvas[(y + e.north) * width + x + e.west] = block
    for recipe in diff.recipes:
        _apply_recipe(canvas, width, height, base, base_w, base_h, e, recipe)
    for (y, x), block in diff.added_blocks.items():
        if not (0 <= y < height and 0 <= x < width):
            raise ValueError(f"{pascal}: added block ({y},{x}) outside {width}x{height}")
        if not 0 <= block <= 0xff:
            raise ValueError(f"{pascal}: block {block} outside byte range")
        canvas[y * width + x] = block
    return canvas, width, height, diff


def set_absolute_extents(diff: MapDiff, *, north: int, west: int,
                         south: int, east: int) -> tuple[MapDiff, tuple[int, int]]:
    """Set absolute block extents and return the newly applied (Y,X) tile delta."""
    values = (north, west, south, east)
    if any(not isinstance(v, int) or v < 0 for v in values):
        raise ValueError("extents must be non-negative integer block counts")
    old = diff.extents
    if north < old.north or west < old.west or south < old.south or east < old.east:
        raise ValueError("shrinking map extents is not implemented")
    delta = ((north - old.north) * 4, (west - old.west) * 4)
    dy, dx = north - old.north, west - old.west
    diff.added_blocks = {(y + dy, x + dx): block
                         for (y, x), block in diff.added_blocks.items()}
    diff.extents = Extents(north, west, south, east)
    return diff, delta
