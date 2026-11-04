"""borders.py — map border-override sidecars (map-tool plan C2).

One JSON per map: dos_port/assets/map_borders/<MAP_CONST>.json
  {"map": "<CONST>", "cells": [[row, col, block], ...]}

Coordinates are PADDED-grid blocks (col 0..w+11, row 0..h+11). Only cells in
the editable ring — the 6-block border minus connection strips — are legal;
connections always win (the runtime applies overrides before strip copies).
Sidecars are editor-owned: written only on Ctrl+S in map_editor/editor.py
(edits are staged in a scratch tree — see map_editor/staging.py).
Stable (row, col) sort keeps diffs reviewable.
"""
from __future__ import annotations

import json
from pathlib import Path

from map_editor import staging

BORDERS_DIR = Path(__file__).resolve().parent.parent.parent \
    / "assets" / "map_borders"


def path_for(const: str) -> Path:
    """The tree path — display and the generators; reads/writes go via staging."""
    return BORDERS_DIR / f"{const}.json"


def load(const: str) -> dict[tuple[int, int], int]:
    p = staging.current().read_path(staging.borders_rel(const))
    if p is None:
        return {}
    raw = json.loads(p.read_text())
    return {(r, c): b for r, c, b in raw["cells"]}


def validate(cells: dict[tuple[int, int], int], cm) -> list[str]:
    """cm = view.ComposedMap for the same map (pre-override)."""
    errs = []
    editable = cm.editable_cells()
    nblocks = _blockset_len(cm)
    for (r, c), b in cells.items():
        idx = r * cm.stride + c
        if not (0 <= c < cm.stride and 0 <= r < cm.rows):
            errs.append(f"({r},{c}): outside the padded grid")
        elif idx not in editable:
            errs.append(f"({r},{c}): not editable (map area or connection "
                        "strip)")
        if not (0 <= b < nblocks):
            errs.append(f"({r},{c}): block 0x{b:02X} outside the blockset")
    return errs


def save(const: str, cells: dict[tuple[int, int], int], cm) -> None:
    errs = validate(cells, cm)
    if errs:
        raise ValueError("; ".join(errs))
    rel = staging.borders_rel(const)
    if not cells:
        staging.current().remove(rel)     # empty override set = no sidecar
        return
    out = {"map": const,
           "cells": [[r, c, b] for (r, c), b in sorted(cells.items())]}
    staging.current().write_path(rel).write_text(json.dumps(out, indent=1) + "\n")


def _blockset_len(cm) -> int:
    from gfx_core import tilesets as ts
    return len(ts.load_blockset(cm.info.tileset_stem)) // ts.BLOCK_BYTES
