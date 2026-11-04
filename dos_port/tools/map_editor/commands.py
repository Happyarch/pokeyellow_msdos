"""Non-interactive map-editor operations shared by the CLI and pygame UI."""
from __future__ import annotations

from dataclasses import asdict
from difflib import SequenceMatcher
from pathlib import Path
import re
from typing import Any

from gfx_core import pret_maps as pm
from map_editor import schema, staging, view


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
        "warps": (pm.objects(info) or (0, [], [], []))[1],
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
        if not (0 <= y <= 502 and 0 <= x <= 502 and y % 2 == 0 and x % 2 == 0):
            raise ValueError("object tile coordinates must be even and fit MAPY/MAPX after +4")
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


def set_warp(ref: str, warp_id: str, *, y: int | None = None,
             x: int | None = None, dest: str | None = None,
             target_warp: int | None = None, kind: str | None = None,
             write: bool = False) -> dict[str, Any]:
    """Override a warp event. Positions are 8px tiles; warp ids are pret's 1-based."""
    from map_editor import objects
    const = resolve_map(ref)
    info = pm.map_info(const)
    if not info.label:
        raise ValueError(f"{const}: no object file")
    parsed = pm.objects(info)
    if parsed is None:
        raise ValueError(f"{const}: no object file")
    warp = next((w for w in parsed[1] if w['stable_id'] == warp_id), None)
    if warp is None:
        raise ValueError(f"{const}: unknown warp {warp_id!r}")
    if (y is None) != (x is None):
        raise ValueError("--y and --x must be supplied together")
    diff = schema.load(info.label)
    override = dict(diff.warps.get(warp_id, {}))
    if y is not None:
        if not (0 <= y <= 510 and 0 <= x <= 510 and y % 2 == 0 and x % 2 == 0):
            raise ValueError("warp tile coordinates must be even and fit in a byte")
        by, bx = warp['trace']['base']
        dy, dx = diff.extents.tile_delta()
        override['manual_delta_tile'] = [y - by - dy, x - bx - dx]
    if dest is not None:
        if dest not in pm.all_map_consts() and dest != 'LAST_MAP':
            raise ValueError(f"unknown destination map {dest!r}")
        override['dest'] = dest
    if target_warp is not None:
        if not 1 <= target_warp <= 255:
            raise ValueError("target warp id must be 1..255")
        override['warp_id'] = target_warp
    if kind is not None:
        if kind not in objects.WARP_KINDS:
            raise ValueError(f"kind must be one of {objects.WARP_KINDS}")
        override['kind'] = kind
    if not override:
        raise ValueError("no warp changes specified")
    diff.warps[warp_id] = override
    if write:
        schema.write(diff)
    return {'schema': 1, 'written': write, 'map': _identity(const),
            'warp': warp_id, 'changes': override,
            'units': {'coordinate': 'tile [y,x]', 'warp_id': '1-based, as pret'},
            'note': 'kind is editor metadata; pret has no warp-type field and it '
                    'is not emitted into the map-header binary'}


def _script_rel(const: str) -> str:
    """Repo-relative path of the port script that owns `const`'s map data."""
    info = pm.map_info(const)
    if not info.label:
        raise ValueError(f"{const}: no script label")
    return staging.script_rel(info.label)


def scan_scripts(ref: str) -> dict[str, Any]:
    from map_editor import scripts
    import hashlib
    const = resolve_map(ref)
    rel = _script_rel(const)
    # `path` is the file that was actually read: the staged copy while an editor
    # session is open, the tree file otherwise. Callers that WRITE resolve their
    # own write path through staging (a read path may still be the tree file).
    path = staging.current().read_path(rel)
    if path is None:
        raise ValueError(f"{const}: script file not found: {staging.ROOT / rel}")
    bindings = scripts.scan_coordinate_macros(path)
    return {'schema': 1, 'written': False, 'map': _identity(const),
            'path': str(path),
            'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
            'coverage': {'adapter': 'coordinate macros and annotated dbmapcoord bytes',
            'complete': False}, 'bindings': [
                {'index': i, 'kind': b.kind, 'coordinate': [b.tile.y, b.tile.x],
                 'span': [b.span.start, b.span.end], 'sha256': b.span.digest}
                for i, b in enumerate(bindings)]}


def move_script_coordinate(ref: str, index: int, digest: str, y: int, x: int,
                           write: bool = False) -> dict[str, Any]:
    from map_editor import scripts
    scan = scan_scripts(ref)
    # The edit path, not the read path: a write must land in the staged copy so
    # the session can commit it later (see map_editor/staging.py).
    path = staging.current().write_path(_script_rel(scan['map']['const']))
    bindings = scripts.scan_coordinate_macros(path)
    if index < 0 or index >= len(bindings):
        raise ValueError(f"binding index {index} is out of range")
    binding = bindings[index]
    if scan['sha256'] != digest:
        raise ValueError("script changed since scan; rescan before writing")
    updated = scripts.translate_binding(binding, dy=y-binding.tile.y,
                                        dx=x-binding.tile.x, write=write)
    return {'schema': 1, 'written': write, 'map': scan['map'], 'index': index,
            'path': scan['path'], 'before': [binding.tile.y, binding.tile.x],
            'after': [updated.tile.y, updated.tile.x], 'file_sha256': digest,
            'span_sha256': binding.span.digest}


def scan_routes(ref: str) -> dict[str, Any]:
    from map_editor import routes
    script = scan_scripts(ref)
    bindings = routes.scan(Path(script['path']))
    return {'schema': 1, 'written': False, 'map': script['map'],
            'path': script['path'], 'sha256': script['sha256'],
            'coverage': {'complete': False, 'adapter': 'direct literal streams only'},
            'routes': [{'label': b.label, 'drivers': b.drivers,
                        'pair': b.pair, 'channel': b.channel, 'slot': b.slot,
                        'bytes': list(b.values),
                        'operations': [asdict(op) for op in routes.decode(b.values)]}
                       for b in bindings]}


def set_route(ref: str, label: str, digest: str, values: list[int],
              write: bool = False) -> dict[str, Any]:
    from map_editor import routes
    result = scan_routes(ref)
    if result['sha256'] != digest:
        raise ValueError('script changed since scan; rescan before writing')
    path = staging.current().write_path(_script_rel(result['map']['const']))
    binding = next((b for b in routes.scan(path) if b.label == label), None)
    if binding is None:
        raise ValueError(f'no recognized direct route {label!r}')
    if (not isinstance(values, list) or not values or any(type(v) is not int or not 0 <= v <= 255 for v in values)
            or values[-1] != 255 or 255 in values[:-1]):
        raise ValueError('route must contain byte values with one final 255 terminator')
    if len(values) != len(binding.values):
        raise ValueError('route edit must retain its length to preserve source labels and comments')
    if 'MoveSprite2' in binding.drivers and len(values) > 90:
        raise ValueError('MoveSprite2 stream exceeds its 90-byte channel')
    text = path.read_text()
    tokens = binding.tokens or tuple(f'0x{v:02X}' for v in binding.values)
    for (start, end), original, value in reversed(
            list(zip(binding.spans, tokens, values))):
        text = text[:start] + routes.render_token(original, value) + text[end:]
    if write:
        import hashlib
        if hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            raise ValueError('script changed since scan; rescan before writing')
        path.write_text(text)
    return {'schema': 1, 'written': write, 'map': result['map'], 'path': str(path),
            'label': label, 'before': list(binding.values), 'after': values,
            'diagnostics': ['Inline comments are preserved and may need review after byte changes.']}


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
    from map_editor import scripts
    import hashlib
    const = resolve_map(ref)
    info = pm.map_info(const)
    pascal = info.label or pm.gmh.const_to_pascal(const)
    diff = schema.load(pascal)
    old = asdict(diff.extents)
    old_width, old_height = diff.extents.dimensions(info.base_w, info.base_h)
    _diff, tile_delta = schema.set_absolute_extents(
        diff, north=north, west=west, south=south, east=east)
    width, height = diff.extents.dimensions(info.base_w, info.base_h)
    border = pm.MAP_BORDER_BLOCKS
    footprint = (width + 2 * border) * (height + 2 * border)
    if footprint > 2304:
        raise ValueError(f"expanded padded map consumes {footprint} bytes, limit is 2304")
    # New cells get an explicit initial fill rather than implicitly becoming
    # block zero, but never over a recipe: recipes run before added_blocks in
    # compose_layout, so an explicit cell there would erase generated content
    # (the Dock's inserted sea columns are exactly this case).
    shift_y, shift_x = tile_delta[0] // 4, tile_delta[1] // 4
    border_block = (pm.objects(info) or (0, [], [], []))[0]
    covered = schema.recipe_cells(diff, info.base_w, info.base_h)
    for y in range(height):
        for x in range(width):
            in_old = (shift_y <= y < shift_y + old_height
                      and shift_x <= x < shift_x + old_width)
            if not in_old and (y, x) not in covered:
                diff.added_blocks.setdefault((y, x), border_block)

    script_rel = staging.script_rel(pascal)
    script_read = staging.current().read_path(script_rel)
    original = replacement = None
    source_hash = None
    changes = []
    diagnostics = []
    if tile_delta != (0, 0):
        if script_read is not None:
            original = script_read.read_text()
            source_hash = hashlib.sha256(original.encode()).hexdigest()
            bindings = scripts.scan_coordinate_macros(script_read)
            replacement = original
            for binding in reversed(bindings):
                edited = scripts.translate_binding(binding, dy=tile_delta[0], dx=tile_delta[1])
                replacement = (replacement[:binding.span.start] + edited.source
                               + replacement[binding.span.end:])
                changes.append({'kind': binding.kind,
                                'before': [binding.tile.y, binding.tile.x],
                                'after': [edited.tile.y, edited.tile.x],
                                'span': [binding.span.start, binding.span.end]})
            changes.reverse()
            diagnostics.append('Only classified script coordinates are updated; review unparsed script code manually.')
        else:
            diagnostics.append('No matching port script file was found; script coordinate coverage is unavailable.')
    if pm.CONNECTIONS.get(const):
        diagnostics.append('Connection seams are not automatically rewritten.')
    if write:
        script_path = staging.current().write_path(script_rel)
        if original is not None and replacement != original:
            if hashlib.sha256(script_path.read_bytes()).hexdigest() != source_hash:
                raise ValueError('script changed since scan; expansion was not written')
            script_path.write_text(replacement)
            try:
                schema.write(diff)
            except Exception:
                # Roll back only if the exact text we wrote remains present.
                if script_path.read_text() == replacement:
                    script_path.write_text(original)
                raise
        else:
            schema.write(diff)
        # Metadata is cached by the shared viewer/parser. Dimensions changed in
        # this process, so subsequent commands must see the new extents.
        pm._constants.cache_clear()
        pm.map_info.cache_clear()
    return {"schema": 1, "written": write, "map": _identity(const),
            "units": {"extents": "blocks", "automatic_delta": "tiles [y,x]"},
            "old_extents": old, "new_extents": asdict(diff.extents),
            "automatic_delta": list(tile_delta),
            "port_blocks": {"width": width, "height": height},
            "script_changes": changes, "diagnostics": diagnostics,
            "coverage": {"script_coordinates_complete": False}}


def render(ref: str, *, out: Path, zoom: int = 1, palette_mode: str = 'dmg',
           last_map: str | None = None) -> dict[str, Any]:
    const = resolve_map(ref)
    cm = view.compose_padded(const)
    if zoom < 1:
        raise ValueError('zoom must be at least 1')
    palette_name, warning = 'dmg', None
    if palette_mode == 'port-cgb':
        from map_editor import palette
        palette_name, colors, warning = palette.resolve(
            cm.info, resolve_map(last_map) if last_map else None)
        image = view.render(cm, colors)
    elif palette_mode == 'dmg':
        image = view.render(cm)
    else:
        raise ValueError(f'unknown palette mode {palette_mode!r}')
    if zoom > 1:
        image = image.resize((image.width * zoom, image.height * zoom))
    image.save(out)
    manifest = {"schema": 1, "written": True, "map": _identity(const),
                "palette": palette_mode, "palette_name": palette_name,
                "diagnostics": [warning] if warning else [], "zoom": zoom,
                "layers": ["blocks"], "png": str(out)}
    out.with_suffix(out.suffix + ".json").write_text(__import__("json").dumps(manifest, indent=1) + "\n")
    return manifest
