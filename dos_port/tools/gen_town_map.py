#!/usr/bin/env python3
"""gen_town_map.py — generate the town-map data + graphics includes from pret.

Writes two files consumed by src/engine/items/town_map.asm:

  assets/town_map_data.inc
    ExternalMapEntries  — one 5-byte entry per outdoor map id (< FIRST_INDOOR_MAP):
                          db coord (y<<4|x), dd NameLabel.
    InternalMapEntries  — one 6-byte entry per indoor map group:
                          db INDOORGROUP_threshold, db coord, dd NameLabel; 0xFF end.
    TownMapOrder/End    — the up/down browse order (db map ids) for DisplayTownMap.
    <name string table> — PalletTownName: … , GB-charmap encoded, 0x50-terminated.

    NOTE (port adaptation): pret stores name pointers as `dw` (2-byte GB pointer).
    The port's name strings are host labels, so entries use `dd NameLabel` (4-byte).
    Entry stride therefore widens to 5 (external) / 6 (internal); LoadTownMapEntry
    in the port uses those strides. Coordinate packing and lookup are unchanged.

  assets/town_map_gfx.inc
    CompressedMap, WorldMapTileGraphics(+End), TownMapCursor(+End),
    TownMapUpArrow(+End), MonNestIcon(+End) — raw INCBIN blobs.

Run from repo root or dos_port/.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]          # repo root
ASSETS = ROOT / "dos_port" / "assets"
GFX = ROOT / "gfx" / "town_map"
SPRITES = ROOT / "gfx" / "sprites"


# --------------------------------------------------------------------------- #
# charmap (shared with gen_items.py's encoder)
# --------------------------------------------------------------------------- #
def load_charmap() -> list:
    cm = []
    for line in (ROOT / "constants/charmap.asm").read_text(encoding="utf-8").splitlines():
        m = re.match(r'\s+charmap\s+"((?:[^"\\]|\\.)*)",\s*\$([0-9a-fA-F]+)', line)
        if m:
            cm.append((m.group(1), int(m.group(2), 16)))
    cm.sort(key=lambda x: -len(x[0]))
    return cm


def encode(s: str, charmap: list) -> bytes:
    out, i = [], 0
    while i < len(s):
        for key, val in charmap:
            if key and s[i:].startswith(key):
                out.append(val)
                i += len(key)
                break
        else:
            raise ValueError(f"Unrecognised char at {i}: {s[i:i+4]!r} in {s!r}")
    return bytes(out)


# --------------------------------------------------------------------------- #
# constants/map_constants.asm — map ids, indoor-group thresholds, key constants
# --------------------------------------------------------------------------- #
def parse_map_meta() -> dict:
    maps, groups = {}, {}
    num_city = first_indoor = None
    val = 0
    for line in (ROOT / "constants/map_constants.asm").read_text().splitlines():
        s = line.split(";", 1)[0].strip()
        m = re.match(r"const_def(?:\s+(-?\d+))?$", s)
        if m:
            val = int(m.group(1)) if m.group(1) else 0
            continue
        m = re.match(r"map_const\s+(\w+)\s*,", s)
        if m:
            maps[m.group(1)] = val
            val += 1
            continue
        m = re.match(r"end_indoor_group\s+(\w+)$", s)
        if m:
            groups[m.group(1)] = val          # ascending threshold, no increment
            continue
        if re.match(r"DEF\s+NUM_CITY_MAPS\s+EQU\s+const_value", s):
            num_city = val
        elif re.match(r"DEF\s+FIRST_INDOOR_MAP\s+EQU\s+const_value", s):
            first_indoor = val
    return {
        "maps": maps,
        "groups": groups,
        "NUM_CITY_MAPS": num_city,
        "FIRST_INDOOR_MAP": first_indoor,
        "NUM_INDOOR_MAP_GROUPS": len(groups),
    }


# --------------------------------------------------------------------------- #
# data/maps/town_map_entries.asm — outdoor_map / indoor_map tables
# --------------------------------------------------------------------------- #
def parse_entries(meta: dict) -> tuple:
    external, internal = [], []
    for line in (ROOT / "data/maps/town_map_entries.asm").read_text().splitlines():
        s = line.split(";", 1)[0].strip()
        m = re.match(r"outdoor_map\s+(\d+)\s*,\s*(\d+)\s*,\s*(\w+)$", s)
        if m:
            x, y, name = int(m.group(1)), int(m.group(2)), m.group(3)
            external.append(((y << 4) | x, name))
            continue
        m = re.match(r"indoor_map\s+(\w+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\w+)$", s)
        if m:
            grp, x, y, name = m.group(1), int(m.group(2)), int(m.group(3)), m.group(4)
            internal.append((meta["groups"][grp], (y << 4) | x, name))
    return external, internal


def parse_order(meta: dict) -> list:
    order = []
    started = False
    for line in (ROOT / "data/maps/town_map_order.asm").read_text().splitlines():
        s = line.split(";", 1)[0].strip()
        if s.startswith("TownMapOrder:"):
            started = True
            continue
        if s.startswith("TownMapOrderEnd"):
            break
        m = re.match(r"db\s+(\w+)$", s)
        if started and m:
            order.append(meta["maps"][m.group(1)])
    return order


def parse_names(charmap: list) -> list:
    names = []
    for line in (ROOT / "data/maps/names.asm").read_text().splitlines():
        m = re.match(r'(\w+):\s*db\s+"((?:[^"\\]|\\.)*)"', line)
        if m:
            names.append((m.group(1), encode(m.group(2), charmap) + b"\x50"))
    return names


# --------------------------------------------------------------------------- #
# emit
# --------------------------------------------------------------------------- #
def hexrow(data: bytes) -> str:
    return "    db " + ", ".join(f"0x{b:02X}" for b in data)


def emit_data(meta, external, internal, order, names, inline) -> str:
    out = [
        "; town_map_data.inc — generated by tools/gen_town_map.py. DO NOT EDIT BY HAND.",
        "; Consumed by src/engine/items/town_map.asm (LoadTownMapEntry, DisplayTownMap).",
        f"; FIRST_INDOOR_MAP={meta['FIRST_INDOOR_MAP']} NUM_CITY_MAPS={meta['NUM_CITY_MAPS']}"
        f" NUM_INDOOR_MAP_GROUPS={meta['NUM_INDOOR_MAP_GROUPS']}",
        "; Name pointers widened to 4-byte host labels (dd); strides = 5 (ext) / 6 (int).",
        "",
        "ExternalMapEntries:",
    ]
    for coord, name in external:
        out.append(f"    db 0x{coord:02X}")
        out.append(f"    dd {name}")
    assert len(external) == meta["FIRST_INDOOR_MAP"], (
        f"external count {len(external)} != FIRST_INDOOR_MAP {meta['FIRST_INDOOR_MAP']}")

    out += ["", "InternalMapEntries:"]
    for group, coord, name in internal:
        out.append(f"    db 0x{group:02X}, 0x{coord:02X}")
        out.append(f"    dd {name}")
    out.append("    db 0xFF        ; end")
    assert len(internal) == meta["NUM_INDOOR_MAP_GROUPS"], (
        f"internal count {len(internal)} != NUM_INDOOR_MAP_GROUPS "
        f"{meta['NUM_INDOOR_MAP_GROUPS']}")

    out += ["", "TownMapOrder:"]
    for i in range(0, len(order), 12):
        out.append("    db " + ", ".join(str(b) for b in order[i:i + 12]))
    out += ["TownMapOrderEnd:", ""]

    out.append("; Region-name string table (GB-charmap encoded, 0x50-terminated).")
    for label, data in names:
        out.append(f"{label}:")
        out.append(hexrow(data))
    out.append("")

    out.append("; Inline town-map text (GB-charmap encoded; pret keeps these in town_map.asm).")
    for label, data in inline:
        out.append(f"{label}:")
        out.append(hexrow(data))
    out.append("")
    return "\n".join(out) + "\n"


# Inline '@'-terminated texts that pret defines alongside the routines.
INLINE_TEXTS = [
    ("MonsNestText", "'s NEST@"),
    ("ToText", "To@"),
    ("AreaUnknownText", " AREA UNKNOWN@"),
]


def emit_gfx() -> str:
    blobs = [
        ("CompressedMap", GFX / "town_map.rle", None),
        ("WorldMapTileGraphics", GFX / "town_map.2bpp", "WorldMapTileGraphicsEnd"),
        ("TownMapCursor", GFX / "town_map_cursor.1bpp", "TownMapCursorEnd"),
        ("TownMapUpArrow", GFX / "up_arrow.1bpp", "TownMapUpArrowEnd"),
        ("MonNestIcon", GFX / "mon_nest_icon.1bpp", "MonNestIconEnd"),
        # The Fly screen's bird cursor. Not a town-map asset in pret either — it
        # lives with the overworld sprites, and LoadTownMap_Fly copies 12 of its
        # tiles to vSprites.
        ("BirdSprite", SPRITES / "bird.2bpp", "BirdSpriteEnd"),
    ]
    out = [
        "; town_map_gfx.inc — generated by tools/gen_town_map.py. DO NOT EDIT BY HAND.",
        "; Raw town-map graphics blobs (INCBIN equivalents from gfx/town_map/,",
        "; plus BirdSprite from gfx/sprites/).",
        "",
    ]
    for label, path, end in blobs:
        data = path.read_bytes()
        out.append(f"{label}:")
        for i in range(0, len(data), 16):
            out.append(hexrow(data[i:i + 16]))
        if end:
            out.append(f"{end}:")
        out.append("")
    return "\n".join(out) + "\n"


def main() -> int:
    charmap = load_charmap()
    meta = parse_map_meta()
    external, internal = parse_entries(meta)
    order = parse_order(meta)
    names = parse_names(charmap)
    inline = [(label, encode(text, charmap)) for label, text in INLINE_TEXTS]

    ASSETS.mkdir(parents=True, exist_ok=True)
    (ASSETS / "town_map_data.inc").write_text(
        emit_data(meta, external, internal, order, names, inline))
    (ASSETS / "town_map_gfx.inc").write_text(emit_gfx())
    print(f"wrote town_map_data.inc (ext {len(external)}, int {len(internal)}, "
          f"order {len(order)}, names {len(names)}) + town_map_gfx.inc")
    return 0


if __name__ == "__main__":
    sys.exit(main())
