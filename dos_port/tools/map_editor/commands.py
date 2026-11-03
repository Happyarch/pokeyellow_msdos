"""Non-interactive map-editor operations shared by the CLI and pygame UI."""
from __future__ import annotations

from dataclasses import asdict
from pathlib import Path
from typing import Any

from gfx_core import pret_maps as pm
from map_editor import schema, view


def resolve_map(ref: str) -> str:
    token = ref.upper()
    if token in pm.all_map_consts():
        return token
    want = ref.replace("_", "").lower()
    for const in pm.all_map_consts():
        if pm.gmh.const_to_pascal(const).lower() == want:
            return const
    raise ValueError(f"unknown map {ref!r}")


def _identity(const: str) -> dict[str, Any]:
    info = pm.map_info(const)
    return {"const": info.const, "label": info.label, "id": info.map_id,
            "base_blocks": {"width": info.base_w, "height": info.base_h},
            "port_blocks": {"width": info.w, "height": info.h}}


def inspect_map(ref: str) -> dict[str, Any]:
    const = resolve_map(ref)
    info = pm.map_info(const)
    diff = schema.load(info.label or pm.gmh.const_to_pascal(const))
    return {
        "schema": 1,
        "written": False,
        "map": _identity(const),
        "units": {"coordinates": "[y,x]", "blocks": "32x32 px",
                  "tiles": "8x8 px"},
        "extent_blocks": asdict(diff.extents),
        "overrides": {"base_blocks": len(diff.base_blocks),
                      "added_blocks": len(diff.added_blocks),
                      "recipes": len(diff.recipes), "objects": len(diff.objects)},
    }


def set_block(ref: str, *, y: int, x: int, block: int, write: bool) -> dict[str, Any]:
    const = resolve_map(ref)
    info = pm.map_info(const)
    pascal = info.label or pm.gmh.const_to_pascal(const)
    diff = schema.load(pascal)
    if not 0 <= block <= 0xff:
        raise ValueError("block must be in 0..255")
    if 0 <= y < info.base_h and 0 <= x < info.base_w:
        diff.base_blocks[(y, x)] = block
        space = "base"
    elif 0 <= y < info.h and 0 <= x < info.w:
        diff.added_blocks[(y, x)] = block
        space = "added"
    else:
        raise ValueError(f"block ({y},{x}) outside port map {info.h}x{info.w}")
    if write:
        schema.write(diff)
    return {"schema": 1, "written": write, "map": _identity(const),
            "units": {"coordinate": "block [y,x]"},
            "changes": [{"kind": "block", "space": space, "y": y, "x": x,
                         "block": block}]}


def set_extents(ref: str, *, north: int, west: int, south: int, east: int,
                write: bool) -> dict[str, Any]:
    const = resolve_map(ref)
    info = pm.map_info(const)
    pascal = info.label or pm.gmh.const_to_pascal(const)
    diff = schema.load(pascal)
    old = asdict(diff.extents)
    _diff, tile_delta = schema.set_absolute_extents(
        diff, north=north, west=west, south=south, east=east)
    width, height = diff.extents.dimensions(info.base_w, info.base_h)
    border = pm.MAP_BORDER_BLOCKS
    footprint = (width + 2 * border) * (height + 2 * border)
    if footprint > 2304:
        raise ValueError(f"expanded padded map consumes {footprint} bytes, limit is 2304")
    if write:
        schema.write(diff)
    return {"schema": 1, "written": write, "map": _identity(const),
            "units": {"extents": "blocks", "automatic_delta": "tiles [y,x]"},
            "old_extents": old, "new_extents": asdict(diff.extents),
            "automatic_delta": list(tile_delta),
            "port_blocks": {"width": width, "height": height},
            "diagnostics": ["connection seams are not automatically rewritten"]
            if pm.CONNECTIONS.get(const) else []}


def render(ref: str, *, out: Path, zoom: int = 1) -> dict[str, Any]:
    const = resolve_map(ref)
    cm = view.compose_padded(const)
    image = view.render(cm)
    if zoom > 1:
        image = image.resize((image.width * zoom, image.height * zoom))
    image.save(out)
    manifest = {"schema": 1, "written": True, "map": _identity(const),
                "palette": "dmg", "zoom": zoom,
                "layers": ["blocks"], "png": str(out)}
    out.with_suffix(out.suffix + ".json").write_text(__import__("json").dumps(manifest, indent=1) + "\n")
    return manifest
