"""Composition of pret object records with port-side map diffs."""
from __future__ import annotations

import hashlib

from map_editor import schema


def source_id(label: str, source: str, occurrence: int) -> str:
    digest = hashlib.sha256((label + "\0" + source.strip()).encode()).hexdigest()[:16]
    return f"base:{digest}:{occurrence}"


# Warp "kinds" are EDITOR METADATA. pret has no warp-type field: what a warp does
# (door, hole, stairs, warp carpet) is decided by the tiles it stands on and by the
# destination map's scripts, not by the event record. Recording a kind here is for
# authoring/review only — it is never emitted into the map-header binary, so it
# cannot change runtime behaviour. Pretending otherwise would be a silent lie in
# the generated data.
WARP_KINDS = ("door", "hole", "stairs", "carpet", "ledge", "other")


def lower(label, border, warps, signs, sprites, tables):
    """Return fresh lowered records; sprite MAP coordinates include GB's +4."""
    diff = schema.load(label)
    # Game object/event bytes count 16px map squares, not 8px graphics tiles.
    # Extents count 32px blocks; authored manual deltas count 8px tiles.
    tile_dy, tile_dx = diff.extents.tile_delta()
    dy, dx = tile_dy // 2, tile_dx // 2
    result_warps = []
    seen_warps = set()
    for base in warps:
        warp = dict(base)
        ident = warp['stable_id']
        seen_warps.add(ident)
        override = diff.warps.get(ident, {})
        if not isinstance(override, dict):
            raise ValueError(f"{label}: warp override {ident} must be an object")
        unknown = set(override) - {'manual_delta_tile', 'dest', 'warp_id', 'kind'}
        if unknown:
            raise ValueError(f"{label}: unknown warp fields: {sorted(unknown)}")
        manual = override.get('manual_delta_tile', [0, 0])
        if not isinstance(manual, list) or len(manual) != 2 or any(type(v) is not int for v in manual):
            raise ValueError(f"{label}: invalid manual_delta_tile for warp {ident}")
        if any(v % 2 for v in manual):
            raise ValueError(f"{label}: warp {ident} manual offsets must align to 16px map squares")
        y, x = warp['y'] + dy + manual[0] // 2, warp['x'] + dx + manual[1] // 2
        if not (0 <= y <= 255 and 0 <= x <= 255):
            raise ValueError(f"{label}: warp {ident} position outside byte range")
        warp['y'], warp['x'] = y, x
        if 'dest' in override:
            if not isinstance(override['dest'], str) or not override['dest']:
                raise ValueError(f"{label}: warp {ident} dest must be a map constant")
            warp['dest'] = override['dest']
        if 'warp_id' in override:
            warp_id = override['warp_id']
            if type(warp_id) is not int or not 1 <= warp_id <= 255:
                raise ValueError(f"{label}: warp {ident} warp_id must be 1..255")
            warp['warp_id'] = warp_id
        if 'kind' in override:
            if override['kind'] not in WARP_KINDS:
                raise ValueError(f"{label}: warp {ident} kind {override['kind']!r} "
                                 f"is not one of {WARP_KINDS}")
            warp['kind'] = override['kind']
        warp['trace'] = {'base': [(base['y'] - 0) * 2, (base['x'] - 0) * 2],
                         'manual_delta': manual, 'automatic_delta': [tile_dy, tile_dx],
                         'final': [y * 2, x * 2]}
        result_warps.append(warp)
    missing_warps = set(diff.warps) - seen_warps
    if missing_warps:
        raise ValueError(f"{label}: warp overrides refer to missing sources: "
                         f"{sorted(missing_warps)}")
    result_signs = [{**s, 'y': s['y'] + dy, 'x': s['x'] + dx} for s in signs]
    result_sprites = []
    seen = set()
    for base in sprites:
        npc = dict(base)
        ident = npc['stable_id']
        seen.add(ident)
        override = diff.objects.get(ident, {})
        if not isinstance(override, dict):
            raise ValueError(f"{label}: override {ident} must be an object")
        unknown = set(override) - {'manual_delta_tile', 'sprite', 'movement', 'facing'}
        if unknown:
            raise ValueError(f"{label}: unknown object fields: {sorted(unknown)}")
        manual = override.get('manual_delta_tile', [0, 0])
        if not isinstance(manual, list) or len(manual) != 2 or any(type(v) is not int for v in manual):
            raise ValueError(f"{label}: invalid manual_delta_tile for {ident}")
        if any(v % 2 for v in manual):
            raise ValueError(f"{label}: {ident} manual offsets must align to 16px map squares")
        y, x = npc['mapy'] + dy + manual[0] // 2, npc['mapx'] + dx + manual[1] // 2
        if not (0 <= y <= 255 and 0 <= x <= 255):
            raise ValueError(f"{label}: {ident} MAPY/MAPX outside byte range")
        npc['mapy'], npc['mapx'] = y, x
        for field, dest in (('sprite', 'sprite_id'), ('movement', 'mov'), ('facing', 'dir')):
            if field in override:
                name = override[field]
                if name not in tables[field]:
                    raise ValueError(f"{label}: invalid {field} {name!r}")
                npc[dest] = tables[field][name]
        npc['trace'] = {'base': [(base['mapy'] - 4) * 2, (base['mapx'] - 4) * 2],
                        'manual_delta': manual, 'automatic_delta': [tile_dy, tile_dx],
                        'final': [(y - 4) * 2, (x - 4) * 2]}
        result_sprites.append(npc)
    missing = set(diff.objects) - seen
    if missing:
        raise ValueError(f"{label}: object overrides refer to missing sources: {sorted(missing)}")
    for sign in result_signs:
        if not (0 <= sign['y'] <= 255 and 0 <= sign['x'] <= 255):
            raise ValueError(f"{label}: sign position outside byte range")
    return border, result_warps, result_signs, result_sprites
