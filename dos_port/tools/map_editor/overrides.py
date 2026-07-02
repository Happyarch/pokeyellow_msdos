"""overrides.py — real-map block-edit sidecars (map-tool plan C5).

One JSON per map: dos_port/assets/map_overrides/<Pascal>.json
  {"map": "<Pascal>", "cells": [[y, x, block], ...]}

Coordinates are MAP-LOCAL blocks (x 0..w-1, y 0..h-1). gen_all_assets.py
merges these into the emitted assets/<snake>_blk.inc — the pret maps/*.blk
stay untouched (read-only spec), and regen is idempotent because the sidecar
is an explicit committed file (two-tier rule). Editor-owned: save only via
map_editor/editor.py paint mode. Stable (y, x) sort keeps diffs reviewable.
"""
from __future__ import annotations

import json
from pathlib import Path

MAP_OVERRIDES_DIR = Path(__file__).resolve().parent.parent.parent \
    / "assets" / "map_overrides"


def path_for(pascal: str) -> Path:
    return MAP_OVERRIDES_DIR / f"{pascal}.json"


def load(pascal: str) -> dict[tuple[int, int], int]:
    p = path_for(pascal)
    if not p.exists():
        return {}
    raw = json.loads(p.read_text())
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
    MAP_OVERRIDES_DIR.mkdir(parents=True, exist_ok=True)
    p = path_for(pascal)
    if not cells:
        if p.exists():
            p.unlink()          # no overrides = no sidecar
        return
    out = {"map": pascal,
           "cells": [[y, x, b] for (y, x), b in sorted(cells.items())]}
    p.write_text(json.dumps(out, indent=1) + "\n")
