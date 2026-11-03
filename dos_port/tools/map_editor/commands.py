"""Non-interactive map-editor operations shared by the CLI and pygame UI."""
from __future__ import annotations

from dataclasses import asdict
from difflib import SequenceMatcher
from pathlib import Path
import re
from typing import Any

from gfx_core import pret_maps as pm
from map_editor import schema, view


def resolve_map(ref: str) -> str:
    """Resolve names safely: exact, unique substring, then unambiguous typo."""
    def normalize(value: str) -> str:
        return re.sub(r"[^a-z0-9]", "", value.lower())

    want = normalize(ref)
    if not want:
        raise ValueError("map name must not be empty")
    names = {const: {normalize(const), normalize(pm.gmh.const_to_pascal(const))}
             for const in pm.all_map_consts()}
    exact = sorted(c for c, stems in names.items() if want in stems)
    if len(exact) == 1:
        return exact[0]
    matches = exact or sorted(c for c, stems in names.items()
                              if any(want in stem for stem in stems))
    if len(matches) == 1:
        return matches[0]
    if len(matches) > 1:
        raise ValueError(f"ambiguous map {ref!r}; matches: " + ", ".join(matches))
    scores = sorted(((max(SequenceMatcher(None, want, s).ratio() for s in stems), c)
                     for c, stems in names.items()), reverse=True)
    if scores and scores[0][0] >= 0.7:
        best = [c for score, c in scores if score >= 0.7 and score >= scores[0][0] - 0.03]
        if len(best) == 1:
            return best[0]
        raise ValueError(f"ambiguous map {ref!r}; close matches: " + ", ".join(sorted(best)))
    raise ValueError(f"no map matches {ref!r}")


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
        "objects": (pm.objects(info) or (0, [], [], []))[3],
        "overrides": {"base_blocks": len(diff.base_blocks),
                      "added_blocks": len(diff.added_blocks),
                      "recipes": len(diff.recipes), "objects": len(diff.objects)},
    }


def set_object(ref: str, object_id: str, *, y: int | None = None,
               x: int | None = None, sprite: str | None = None,
               movement: str | None = None, facing: str | None = None,
               write: bool = False) -> dict[str, Any]:
    const = resolve_map(ref)
    info = pm.map_info(const)
    if not info.label:
        raise ValueError(f"{const}: no object file")
    parsed = pm.objects(info)
    if parsed is None:
        raise ValueError(f"{const}: no object file")
    npc = next((s for s in parsed[3] if s['stable_id'] == object_id), None)
    if npc is None:
        raise ValueError(f"{const}: unknown object {object_id!r}")
    if (y is None) != (x is None):
        raise ValueError("--y and --x must be supplied together")
    diff = schema.load(info.label)
    override = dict(diff.objects.get(object_id, {}))
    if y is not None:
        if not (0 <= y <= 251 and 0 <= x <= 251):
            raise ValueError("object coordinates must fit MAPY/MAPX after +4")
        by, bx = npc['trace']['base']
        dy, dx = diff.extents.tile_delta()
        override['manual_delta_tile'] = [y - by - dy, x - bx - dx]
    for field, value, table in (
            ('sprite', sprite, pm.gmh._SPRITE_CONSTS),
            ('movement', movement, pm.gmh._MOV_CONSTS),
            ('facing', facing, pm.gmh._DIR_CONSTS)):
        if value is not None:
            if value not in table:
                raise ValueError(f"invalid {field} {value!r}")
            override[field] = value
    if not override:
        raise ValueError("no object changes specified")
    diff.objects[object_id] = override
    if write:
        schema.write(diff)
    return {'schema': 1, 'written': write, 'map': _identity(const),
            'object': object_id, 'changes': override,
            'units': {'coordinate': 'tile [y,x]'}}


def scan_scripts(ref: str) -> dict[str, Any]:
    from map_editor import scripts
    const = resolve_map(ref)
    info = pm.map_info(const)
    if not info.label:
        raise ValueError(f"{const}: no script label")
    path = schema.ROOT / 'dos_port' / 'src' / 'scripts' / f'{info.label}.asm'
    if not path.is_file():
        raise ValueError(f"{const}: script file not found: {path}")
    bindings = scripts.scan_coordinate_macros(path)
    return {'schema': 1, 'written': False, 'map': _identity(const),
            'path': str(path), 'coverage': {'adapter': 'coordinate macros only',
            'complete': False}, 'bindings': [
                {'index': i, 'kind': b.kind, 'coordinate': [b.tile.y, b.tile.x],
                 'span': [b.span.start, b.span.end], 'sha256': b.span.digest}
                for i, b in enumerate(bindings)]}


def set_block(ref: str, *, y: int, x: int, block: int, write: bool) -> dict[str, Any]:
    const = resolve_map(ref)
    info = pm.map_info(const)
    pascal = info.label or pm.gmh.const_to_pascal(const)
    diff = schema.load(pascal)
    if not 0 <= block <= 0xff:
        raise ValueError("block must be in 0..255")
    if not (0 <= y < info.h and 0 <= x < info.w):
        raise ValueError(f"block ({y},{x}) outside port map {info.h}x{info.w}")
    base = schema.final_to_base(diff, y, x, info.base_w, info.base_h)
    if base is not None:
        diff.base_blocks[base] = block
        diff.added_blocks.pop((y, x), None)
        space = "base"
    else:
        diff.added_blocks[(y, x)] = block
        space = "added"
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
    if write and (north != diff.extents.north or west != diff.extents.west):
        raise ValueError("north/west expansion cannot be written yet: map events and "
                         "script coordinates are not automatically relocated")
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
