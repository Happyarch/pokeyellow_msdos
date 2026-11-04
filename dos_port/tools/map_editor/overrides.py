"""overrides.py — real-map block-edit sidecars (map-tool plan C5).

One JSON per map: dos_port/assets/map_overrides/<Pascal>.json
  {"map": "<Pascal>", "cells": [[y, x, block], ...]}

Coordinates are MAP-LOCAL blocks (x 0..w-1, y 0..h-1). gen_all_assets.py
merges these into the emitted assets/<snake>_blk.inc — the pret maps/*.blk
stay untouched (read-only spec), and regen is idempotent because the sidecar
is an explicit committed file (two-tier rule). Editor-owned: written only on
Ctrl+S in map_editor/editor.py (edits are staged — see map_editor/staging.py).
Stable (y, x) sort keeps diffs reviewable.
"""
from __future__ import annotations

import json
from pathlib import Path

from map_editor import staging

MAP_OVERRIDES_DIR = Path(__file__).resolve().parent.parent.parent \
    / "assets" / "map_overrides"


def path_for(pascal: str) -> Path:
    """The tree path — display only; reads/writes go via staging."""
    return MAP_OVERRIDES_DIR / f"{pascal}.json"


def load(pascal: str, info=None) -> dict[tuple[int, int], int]:
    p = staging.current().read_path(staging.overrides_rel(pascal))
    if p is None:
        return {}
    raw = json.loads(p.read_text())
    if raw.get("schema") == 2:
        if info is None:
            raise ValueError("map dimensions are required for schema-2 paint")
        from map_editor import schema
        diff = schema.load(pascal)
        cells = {schema.base_to_final(diff, y, x, info.base_w): b
                 for (y, x), b in diff.base_blocks.items()}
        cells.update(diff.added_blocks)
        return cells
    return {(y, x): b for y, x, b in raw["cells"]}


def validate(cells: dict[tuple[int, int], int], info, nblocks: int) -> list[str]:
    errs = []
    for (y, x), b in cells.items():
        if not (0 <= x < info.w and 0 <= y < info.h):
            errs.append(f"({y},{x}): outside the {info.w}x{info.h} map")
        if not (0 <= b < nblocks):
            errs.append(f"({y},{x}): block 0x{b:02X} outside the blockset")
    return errs


def save(pascal: str, cells: dict[tuple[int, int], int], info,
         nblocks: int) -> None:
    errs = validate(cells, info, nblocks)
    if errs:
        raise ValueError("; ".join(errs))
    from map_editor import schema
    diff = schema.load(pascal)
    if diff.is_v2:
        diff.base_blocks.clear()
        diff.added_blocks.clear()
        for (y, x), block in cells.items():
            base = schema.final_to_base(diff, y, x, info.base_w, info.base_h)
            if base is None:
                diff.added_blocks[y, x] = block
            else:
                diff.base_blocks[base] = block
        schema.write(diff)
        return
    rel = staging.overrides_rel(pascal)
    if not cells:
        staging.current().remove(rel)     # no overrides = no sidecar
        return
    out = {"map": pascal,
           "cells": [[y, x, b] for (y, x), b in sorted(cells.items())]}
    staging.current().write_path(rel).write_text(json.dumps(out, indent=1) + "\n")
