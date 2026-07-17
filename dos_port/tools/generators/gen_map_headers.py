#!/usr/bin/env python3
"""Generate dos_port/assets/map_headers.inc from pret source files.

Parses:
  constants/map_constants.asm    → map name → (id, w, h)
  data/maps/headers/*.asm        → map label → (map_const, tileset_name)
  data/maps/objects/*.asm        → map label → (border, warp_list, signs, sprites)
  scripts/*.asm                  → map label → text-pointer names (sign text ids)

Emits:
  - Tileset dispatch tables (TilesetGfxPtrs, TilesetBlocksPtrs, TilesetCollPtrs,
    TilesetGfxSizes, TilesetBlocksSizes) — flat DS, indexed 0-24
  - Indoor map block dispatch tables (IndoorMapBlkPtrs, IndoorMapBlkSizes)
    — flat DS, indexed by (map_id - FIRST_INDOOR_MAP_ID)
  - MapHeaderPointers table — flat DS, 2-byte EBP-relative addresses
  - map_headers_data blob (copied to EBP+OW_TILESET_HDR_GBADDR at startup):
      OVERWORLD tileset header (12 bytes)
      Map headers + object data for all maps

Run from repo root:
    python3 tools/generators/gen_map_headers.py
"""
import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent.parent
ASSETS = ROOT / "dos_port" / "assets"
MAP_HEADERS_DIR = ROOT / "data" / "maps" / "headers"
MAP_OBJECTS_DIR = ROOT / "data" / "maps" / "objects"
MAP_CONSTANTS   = ROOT / "constants" / "map_constants.asm"
MAPS_DIR        = ROOT / "maps"
SCRIPTS_DIR     = ROOT / "scripts"

# ---------------------------------------------------------------------------
# ROM-window allocator (the single source of truth for the EBP "ROM" layout).
#
# The window is GB $0000-$7FFF; VRAM starts at $8000. Everything below is packed
# contiguously and asserted to end before VRAM. It used to be a hand-maintained
# table of magic addresses, and it had silently overflowed: the map-headers blob
# ran $5400-$8D72, over INDOOR_BLK_GBADDR ($7600) AND 3442 bytes into VRAM. The
# generator printed a WARNING about it on every run and nothing failed, so the
# indoor .blk slot held header bytes -> bogus block IDs -> clamped to block 0 ->
# tile $00, absent from every collision list -> the player was walled in on any
# indoor-slot map (Viridian Forest). Now the layout is computed, the addresses are
# emitted to assets/rom_window.inc, and an overflow is a hard error.
#
# Order matters: map-header emission needs the outdoor .blk addresses (connection
# strip_src points into them), so the .blk pool is laid out first and the blob,
# whose size is not known until it is emitted, goes last against the VRAM wall.
# ---------------------------------------------------------------------------
ROM_WINDOW_BASE  = 0x0100   # leave the RST/interrupt page alone; 0 doubles as "null ptr"
ROM_WINDOW_END   = 0x8000   # GB_VRAM0 — nothing may touch or cross this
OW_GFX_SIZE      = 0x0600   # largest tileset 2bpp (1536 B)
OW_BLOCKS_SIZE   = 0x0900   # largest blockset (2048 B) + slack
OW_COLL_SIZE     = 0x0040   # passable-tile list ($FF-terminated, copied as 64 B)
INDOOR_BLK_SIZE  = 0x0200   # largest indoor .blk is VIRIDIAN_FOREST (17x24 = 408 B)

FIRST_INDOOR_MAP_ID    = 0x25     # REDS_HOUSE_1F

# Outdoor maps get a permanently-resident .blk (connection strips read across
# them). Order is the allocation order; the addresses are computed, not written.
OUTDOOR_BLK_MAPS = (
    "PALLET_TOWN", "VIRIDIAN_CITY", "PEWTER_CITY", "CERULEAN_CITY",
    "LAVENDER_TOWN", "VERMILION_CITY", "CELADON_CITY", "FUCHSIA_CITY",
    "CINNABAR_ISLAND", "SAFFRON_CITY",
    "ROUTE_1", "ROUTE_2", "ROUTE_3", "ROUTE_4", "ROUTE_5", "ROUTE_6",
    "ROUTE_7", "ROUTE_8", "ROUTE_9", "ROUTE_10", "ROUTE_11", "ROUTE_12",
    "ROUTE_13", "ROUTE_14", "ROUTE_15", "ROUTE_16", "ROUTE_17", "ROUTE_18",
    "ROUTE_19", "ROUTE_20", "ROUTE_21", "ROUTE_22", "ROUTE_24", "ROUTE_25",
    "ROUTE_23", "INDIGO_PLATEAU",
)

# gb_memmap.inc's historical equ names are not uniform; keep them exactly.
_BLK_EQU_OVERRIDE = {
    "PALLET_TOWN": "OW_PALLET_BLK_GBADDR",
    "ROUTE_1":     "OW_ROUTE1_BLK_GBADDR",
    "ROUTE_21":    "OW_ROUTE21_BLK_GBADDR",
}


def blk_equ_name(const: str) -> str:
    return _BLK_EQU_OVERRIDE.get(const, f"OW_{const}_BLK_GBADDR")


def _align(addr: int, n: int = 16) -> int:
    return (addr + n - 1) & ~(n - 1)


# Filled in by allocate_rom_window(); read by the header emitter.
OUTDOOR_BLK_ADDRS: dict[str, int] = {}
OUTDOOR_BLK_SIZES: dict[str, int] = {}
OW_GFX_GBADDR = OW_BLOCKS_GBADDR = OW_COLL_GBADDR = 0
INDOOR_BLK_GBADDR = OW_TILESET_HDR_GBADDR = OW_MAP_HEADERS_GBADDR = 0


def allocate_rom_window(map_info: dict) -> None:
    """Lay out the ROM window. map_info: const -> (id, width, height)."""
    global OW_GFX_GBADDR, OW_BLOCKS_GBADDR, OW_COLL_GBADDR
    global INDOOR_BLK_GBADDR, OW_TILESET_HDR_GBADDR, OW_MAP_HEADERS_GBADDR

    addr = ROM_WINDOW_BASE
    for const in OUTDOOR_BLK_MAPS:
        _id, w, h = map_info[const]
        OUTDOOR_BLK_ADDRS[const] = addr
        OUTDOOR_BLK_SIZES[const] = w * h
        addr = _align(addr + w * h)

    OW_GFX_GBADDR    = addr;  addr = _align(addr + OW_GFX_SIZE)
    OW_BLOCKS_GBADDR = addr;  addr = _align(addr + OW_BLOCKS_SIZE)
    OW_COLL_GBADDR   = addr;  addr = _align(addr + OW_COLL_SIZE)
    INDOOR_BLK_GBADDR = addr; addr = _align(addr + INDOOR_BLK_SIZE)

    OW_TILESET_HDR_GBADDR = addr
    OW_MAP_HEADERS_GBADDR = addr + 12          # tileset header is 12 bytes


def write_rom_window_inc(blob_end: int) -> None:
    if blob_end > ROM_WINDOW_END:
        sys.exit(f"ROM window overflow: map-headers blob ends 0x{blob_end:04X}, "
                 f"past 0x{ROM_WINDOW_END:04X} (VRAM). Free space by shrinking a "
                 f"region above, or move the blob out of GB space.")
    L = ["; rom_window.inc — generated by tools/generators/gen_map_headers.py. DO NOT EDIT BY HAND.",
         "; EBP-space \"ROM window\" ($0000-$7FFF). Every address is allocated by",
         "; allocate_rom_window(); the blob end is asserted against VRAM ($8000).",
         "%ifndef ROM_WINDOW_INC", "%define ROM_WINDOW_INC", "",
         f"OW_GFX_GBADDR            equ 0x{OW_GFX_GBADDR:04X}",
         f"OW_GFX_SIZE              equ 0x{OW_GFX_SIZE:04X}",
         f"OW_BLOCKS_GBADDR         equ 0x{OW_BLOCKS_GBADDR:04X}",
         f"OW_BLOCKS_SIZE           equ 0x{OW_BLOCKS_SIZE:04X}",
         f"OW_COLL_GBADDR           equ 0x{OW_COLL_GBADDR:04X}",
         f"OW_COLL_SIZE             equ 0x{OW_COLL_SIZE:04X}",
         f"INDOOR_BLK_GBADDR        equ 0x{INDOOR_BLK_GBADDR:04X}",
         f"INDOOR_BLK_SLOT_SIZE     equ 0x{INDOOR_BLK_SIZE:04X}",
         f"OW_TILESET_HDR_GBADDR    equ 0x{OW_TILESET_HDR_GBADDR:04X}",
         f"OW_MAP_HEADERS_GBADDR    equ 0x{OW_MAP_HEADERS_GBADDR:04X}",
         f"ROM_WINDOW_BLOB_END      equ 0x{blob_end:04X}",
         f"FIRST_INDOOR_MAP_ID      equ 0x{FIRST_INDOOR_MAP_ID:02X}", ""]
    for const in OUTDOOR_BLK_MAPS:
        L.append(f"{blk_equ_name(const):28s} equ 0x{OUTDOOR_BLK_ADDRS[const]:04X}")
        L.append(f"{blk_equ_name(const) + '_SIZE':28s} equ 0x{OUTDOOR_BLK_SIZES[const]:04X}")
    L += ["", "OW_MAP_GBADDR            equ OW_PALLET_BLK_GBADDR ; legacy alias",
          "", f"; map-headers blob: 0x{OW_TILESET_HDR_GBADDR:04X}-0x{blob_end:04X} "
          f"({blob_end - OW_TILESET_HDR_GBADDR} bytes); "
          f"{ROM_WINDOW_END - blob_end} bytes free below VRAM.", "%endif"]
    (ASSETS / "rom_window.inc").write_text("\n".join(L) + "\n")
    print(f"Wrote {ASSETS / 'rom_window.inc'} "
          f"(blob 0x{OW_TILESET_HDR_GBADDR:04X}-0x{blob_end:04X}, "
          f"{ROM_WINDOW_END - blob_end} B free below VRAM)")


# Tileset name → id (must match constants/tileset_constants.asm)
TILESET_IDS = {
    "OVERWORLD":   0,
    "REDS_HOUSE_1":1,
    "MART":        2,
    "FOREST":      3,
    "REDS_HOUSE_2":4,
    "DOJO":        5,
    "POKECENTER":  6,
    "GYM":         7,
    "HOUSE":       8,
    "FOREST_GATE": 9,
    "MUSEUM":     10,
    "UNDERGROUND":11,
    "GATE":       12,
    "SHIP":       13,
    "SHIP_PORT":  14,
    "CEMETERY":   15,
    "INTERIOR":   16,
    "CAVERN":     17,
    "LOBBY":      18,
    "MANSION":    19,
    "LAB":        20,
    "CLUB":       21,
    "FACILITY":   22,
    "PLATEAU":    23,
    "BEACH_HOUSE":24,
}

# Canonical gfx/blocks/coll label prefix per tileset id (from gen_all_assets.py TILESETS)
TILESET_CANONICAL = [
    "overworld",    # 0
    "reds_house",   # 1 REDS_HOUSE_1
    "pokecenter",   # 2 MART → shared pokecenter gfx
    "forest",       # 3
    "reds_house",   # 4 REDS_HOUSE_2 → shared
    "gym",          # 5 DOJO → gym gfx
    "pokecenter",   # 6 POKECENTER
    "gym",          # 7 GYM
    "house",        # 8
    "gate",         # 9 FOREST_GATE
    "gate",         # 10 MUSEUM
    "underground",  # 11
    "gate",         # 12 GATE
    "ship",         # 13
    "ship_port",    # 14
    "cemetery",     # 15
    "interior",     # 16
    "cavern",       # 17
    "lobby",        # 18
    "mansion",      # 19
    "lab",          # 20
    "club",         # 21
    "facility",     # 22
    "plateau",      # 23
    "beach_house",  # 24
]

# ---------------------------------------------------------------------------
# NPC object-event constant resolution tables
# Source: constants/sprite_constants.asm, constants/map_object_constants.asm
# ---------------------------------------------------------------------------
_SPRITE_CONSTS = {
    'SPRITE_NONE': 0x00, 'SPRITE_RED': 0x01, 'SPRITE_BLUE': 0x02,
    'SPRITE_OAK': 0x03, 'SPRITE_YOUNGSTER': 0x04, 'SPRITE_MONSTER': 0x05,
    'SPRITE_COOLTRAINER_F': 0x06, 'SPRITE_COOLTRAINER_M': 0x07,
    'SPRITE_LITTLE_GIRL': 0x08, 'SPRITE_BIRD': 0x09,
    'SPRITE_MIDDLE_AGED_MAN': 0x0A, 'SPRITE_GAMBLER': 0x0B,
    'SPRITE_SUPER_NERD': 0x0C, 'SPRITE_GIRL': 0x0D, 'SPRITE_HIKER': 0x0E,
    'SPRITE_BEAUTY': 0x0F, 'SPRITE_GENTLEMAN': 0x10, 'SPRITE_DAISY': 0x11,
    'SPRITE_BIKER': 0x12, 'SPRITE_SAILOR': 0x13, 'SPRITE_COOK': 0x14,
    'SPRITE_BIKE_SHOP_CLERK': 0x15, 'SPRITE_MR_FUJI': 0x16,
    'SPRITE_GIOVANNI': 0x17, 'SPRITE_ROCKET': 0x18, 'SPRITE_CHANNELER': 0x19,
    'SPRITE_WAITER': 0x1A, 'SPRITE_SILPH_WORKER_F': 0x1B,
    'SPRITE_MIDDLE_AGED_WOMAN': 0x1C, 'SPRITE_BRUNETTE_GIRL': 0x1D,
    'SPRITE_LANCE': 0x1E, 'SPRITE_UNUSED_RED_1': 0x1F,
    'SPRITE_SCIENTIST': 0x20, 'SPRITE_ROCKER': 0x21, 'SPRITE_SWIMMER': 0x22,
    'SPRITE_SAFARI_ZONE_WORKER': 0x23, 'SPRITE_GYM_GUIDE': 0x24,
    'SPRITE_GRAMPS': 0x25, 'SPRITE_CLERK': 0x26, 'SPRITE_FISHING_GURU': 0x27,
    'SPRITE_GRANNY': 0x28, 'SPRITE_NURSE': 0x29,
    'SPRITE_LINK_RECEPTIONIST': 0x2A, 'SPRITE_SILPH_PRESIDENT': 0x2B,
    'SPRITE_SILPH_WORKER_M': 0x2C, 'SPRITE_WARDEN': 0x2D,
    'SPRITE_CAPTAIN': 0x2E, 'SPRITE_FISHER': 0x2F,
    'SPRITE_KOGA': 0x30, 'SPRITE_GUARD': 0x31, 'SPRITE_UNUSED_RED_2': 0x32,
    'SPRITE_MOM': 0x33, 'SPRITE_BALDING_GUY': 0x34, 'SPRITE_LITTLE_BOY': 0x35,
    'SPRITE_UNUSED_RED_3': 0x36, 'SPRITE_GAMEBOY_KID': 0x37,
    'SPRITE_FAIRY': 0x38, 'SPRITE_AGATHA': 0x39, 'SPRITE_BRUNO': 0x3A,
    'SPRITE_LORELEI': 0x3B, 'SPRITE_SEEL': 0x3C, 'SPRITE_PIKACHU': 0x3D,
    'SPRITE_OFFICER_JENNY': 0x3E, 'SPRITE_SANDSHREW': 0x3F,
    'SPRITE_ODDISH': 0x40, 'SPRITE_BULBASAUR': 0x41, 'SPRITE_JIGGLYPUFF': 0x42,
    'SPRITE_CLEFAIRY': 0x43, 'SPRITE_CHANSEY': 0x44,
    'SPRITE_JESSIE': 0x45, 'SPRITE_JAMES': 0x46,
    'SPRITE_POKE_BALL': 0x47, 'SPRITE_FOSSIL': 0x48, 'SPRITE_BOULDER': 0x49,
    'SPRITE_PAPER': 0x4A, 'SPRITE_POKEDEX': 0x4B, 'SPRITE_CLIPBOARD': 0x4C,
    'SPRITE_SNORLAX': 0x4D, 'SPRITE_UNUSED_OLD_AMBER': 0x4E,
    'SPRITE_OLD_AMBER': 0x4F, 'SPRITE_UNUSED_GAMBLER_ASLEEP_1': 0x50,
    'SPRITE_UNUSED_GAMBLER_ASLEEP_2': 0x51, 'SPRITE_GAMBLER_ASLEEP': 0x52,
}
_MOV_CONSTS = {'WALK': 0xFE, 'STAY': 0xFF}
_DIR_CONSTS = {
    'NONE': 0xFF, 'ANY_DIR': 0x00, 'UP_DOWN': 0x01, 'LEFT_RIGHT': 0x02,
    'DOWN': 0xD0, 'UP': 0xD1, 'LEFT': 0xD2, 'RIGHT': 0xD3,
}
_TRAINER_FLAG = 0x40   # constants/map_object_constants.asm: TRAINER = 1 << BIT_TRAINER
_ITEM_FLAG    = 0x80   # constants/map_object_constants.asm: ITEM    = 1 << BIT_ITEM
# The text byte's low 6 bits are the text id; bits 6/7 are the flags above, so an id
# must fit in $3F (LoadSprite recovers it with `and $3f`). The game's real maximum is
# 25, so this is headroom, not a limit — but a silent overflow would corrupt an id
# into the TRAINER flag, so it is checked rather than assumed.
_TEXT_ID_MAX  = 0x3F


def _resolve_const(name, table, context=''):
    """Resolve a named constant or hex/decimal literal to an integer."""
    if name in table:
        return table[name]
    if name.startswith('$'):
        return int(name[1:], 16)
    if name.lower().startswith('0x'):
        return int(name, 16)
    try:
        return int(name)
    except ValueError:
        print(f"  WARNING: unknown constant '{name}' {context}, using 0x00", file=sys.stderr)
        return 0


# Connection data for outdoor maps (preserved exactly from Phase 2)
# (direction, target_const, offset)
CONNECTIONS = {
    "PALLET_TOWN":    [("NORTH", "ROUTE_1",        0),
                       ("SOUTH", "ROUTE_21",       0)],
    "VIRIDIAN_CITY":  [("NORTH", "ROUTE_2",        5),
                       ("SOUTH", "ROUTE_1",        5),
                       ("WEST",  "ROUTE_22",       4)],
    "PEWTER_CITY":    [("SOUTH", "ROUTE_2",        5),
                       ("EAST",  "ROUTE_3",        4)],
    "CERULEAN_CITY":  [("NORTH", "ROUTE_24",       5),
                       ("SOUTH", "ROUTE_5",        5),
                       ("WEST",  "ROUTE_4",        4),
                       ("EAST",  "ROUTE_9",        4)],
    "LAVENDER_TOWN":  [("NORTH", "ROUTE_10",       0),
                       ("SOUTH", "ROUTE_12",       0),
                       ("WEST",  "ROUTE_8",        0)],
    "VERMILION_CITY": [("NORTH", "ROUTE_6",        5),
                       ("EAST",  "ROUTE_11",       4)],
    "CELADON_CITY":   [("WEST",  "ROUTE_16",       4),
                       ("EAST",  "ROUTE_7",        4)],
    "FUCHSIA_CITY":   [("SOUTH", "ROUTE_19",       5),
                       ("WEST",  "ROUTE_18",       4),
                       ("EAST",  "ROUTE_15",       4)],
    "CINNABAR_ISLAND":[("NORTH", "ROUTE_21",       0),
                       ("EAST",  "ROUTE_20",       0)],
    "SAFFRON_CITY":   [("NORTH", "ROUTE_5",        5),
                       ("SOUTH", "ROUTE_6",        5),
                       ("WEST",  "ROUTE_7",        4),
                       ("EAST",  "ROUTE_8",        4)],
    "ROUTE_1":        [("NORTH", "VIRIDIAN_CITY", -5),
                       ("SOUTH", "PALLET_TOWN",    0)],
    "ROUTE_2":        [("NORTH", "PEWTER_CITY",   -5),
                       ("SOUTH", "VIRIDIAN_CITY", -5)],
    "ROUTE_3":        [("NORTH", "ROUTE_4",       25),
                       ("WEST",  "PEWTER_CITY",   -4)],
    "ROUTE_4":        [("SOUTH", "ROUTE_3",      -25),
                       ("EAST",  "CERULEAN_CITY", -4)],
    "ROUTE_5":        [("NORTH", "CERULEAN_CITY", -5),
                       ("SOUTH", "SAFFRON_CITY",  -5)],
    "ROUTE_6":        [("NORTH", "SAFFRON_CITY",  -5),
                       ("SOUTH", "VERMILION_CITY",-5)],
    "ROUTE_7":        [("WEST",  "CELADON_CITY",  -4),
                       ("EAST",  "SAFFRON_CITY",  -4)],
    "ROUTE_8":        [("WEST",  "SAFFRON_CITY",  -4),
                       ("EAST",  "LAVENDER_TOWN",  0)],
    "ROUTE_9":        [("WEST",  "CERULEAN_CITY", -4),
                       ("EAST",  "ROUTE_10",       0)],
    "ROUTE_10":       [("SOUTH", "LAVENDER_TOWN",  0),
                       ("WEST",  "ROUTE_9",        0)],
    "ROUTE_11":       [("WEST",  "VERMILION_CITY",-4),
                       ("EAST",  "ROUTE_12",     -27)],
    "ROUTE_12":       [("NORTH", "LAVENDER_TOWN",  0),
                       ("SOUTH", "ROUTE_13",     -20),
                       ("WEST",  "ROUTE_11",      27)],
    "ROUTE_13":       [("NORTH", "ROUTE_12",      20),
                       ("WEST",  "ROUTE_14",       0)],
    "ROUTE_14":       [("WEST",  "ROUTE_15",      18),
                       ("EAST",  "ROUTE_13",       0)],
    "ROUTE_15":       [("WEST",  "FUCHSIA_CITY",  -4),
                       ("EAST",  "ROUTE_14",     -18)],
    "ROUTE_16":       [("SOUTH", "ROUTE_17",       0),
                       ("EAST",  "CELADON_CITY",  -4)],
    "ROUTE_17":       [("NORTH", "ROUTE_16",       0),
                       ("SOUTH", "ROUTE_18",       0)],
    "ROUTE_18":       [("NORTH", "ROUTE_17",       0),
                       ("EAST",  "FUCHSIA_CITY",  -4)],
    "ROUTE_19":       [("NORTH", "FUCHSIA_CITY",  -5),
                       ("WEST",  "ROUTE_20",      18)],
    "ROUTE_20":       [("WEST",  "CINNABAR_ISLAND", 0),
                       ("EAST",  "ROUTE_19",     -18)],
    "ROUTE_21":       [("NORTH", "PALLET_TOWN",    0),
                       ("SOUTH", "CINNABAR_ISLAND",0)],
    "ROUTE_22":       [("EAST",  "VIRIDIAN_CITY", -4)],   # NORTH Route23 omitted (PLATEAU tileset)
    "ROUTE_24":       [("SOUTH", "CERULEAN_CITY", -5),
                       ("EAST",  "ROUTE_25",       0)],
    "ROUTE_25":       [("WEST",  "ROUTE_24",       0)],
    # Route 23 and Indigo Plateau: added with no connections (PLATEAU tileset, isolated)
    "ROUTE_23":       [],
    "INDIGO_PLATEAU": [],
}

CONN_BITS = {"NORTH": 0x08, "SOUTH": 0x04, "WEST": 0x02, "EAST": 0x01}


# ---------------------------------------------------------------------------
# Parsing helpers
# ---------------------------------------------------------------------------

def to_snake(pascal: str) -> str:
    """PascalCase → snake_case (matches gen_all_assets.py)."""
    s = re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", pascal)
    return s.lower()


def const_to_pascal(const: str) -> str:
    """CONST_NAME → PascalCase.  REDS_HOUSE_1F → RedsHouse1F"""
    return "".join(w.capitalize() for w in const.split("_"))


def parse_map_constants():
    """Return {const_name: (id, w, h)}."""
    result = {}
    for line in MAP_CONSTANTS.read_text().splitlines():
        m = re.match(r"\s*map_const\s+(\w+),\s*(\d+),\s*(\d+)\s*;\s*\$([0-9A-Fa-f]+)", line)
        if m:
            name, w, h, hex_id = m.groups()
            result[name] = (int(hex_id, 16), int(w), int(h))
    return result


def parse_all_headers():
    """Return (const_to_label: {const→label}, label_tileset: {label→tileset}).

    First occurrence of each const wins (handles shared-const COPY files).
    Also tries to find labels for COPY maps by pascal name.
    """
    const_to_label = {}
    label_tileset  = {}
    for f in sorted(MAP_HEADERS_DIR.glob("*.asm")):
        text = f.read_text()
        m = re.search(r"map_header\s+(\w+),\s*(\w+),\s*(\w+)", text)
        if m:
            label, const, tileset = m.groups()
            label_tileset[label] = tileset
            if const not in const_to_label:          # first occurrence wins
                const_to_label[const] = label
    return const_to_label, label_tileset


def strip_debug_blocks(text: str) -> str:
    """Remove IF DEF(_DEBUG) ... ENDC conditional blocks from RGBASM source."""
    out = []
    depth = 0
    debug_depth = None
    for line in text.splitlines(keepends=True):
        stripped = line.strip().upper()
        if stripped.startswith("IF DEF(_DEBUG)"):
            if debug_depth is None:
                debug_depth = depth
            depth += 1
            continue
        elif stripped == "IF" or stripped.startswith("IF "):
            depth += 1
        elif stripped == "ENDC":
            if depth > 0:
                depth -= 1
            if debug_depth is not None and depth < debug_depth:
                debug_depth = None
            continue
        if debug_depth is None:
            out.append(line)
    return "".join(out)


def text_pointer_names(label: str) -> list:
    """scripts/<label>.asm → the map's `dw_const` text-pointer NAMES, in order.

    The text id of entry k (0-based here) is pret's const **k + 1**: pret's
    `def_text_pointers` macro is `const_def 1` (macros/scripts/maps.asm), so the first
    `dw` in the table carries const value 1, and `DisplayTextID` subtracts one before
    indexing (home/text_script.asm: `dec a`).

    Consumed by both generators, which must agree on that numbering:
      * here — a bg_event's text id (its name's index in this list, + 1)
      * gen_npc_dialogs.py — <Map>TextTable row k holds text id k + 1

    KNOWN GAP (pre-existing, not introduced here): a few maps open their table with
    bare `dw` rows before a `const_def` (e.g. ViridianMart), and this parser stops at
    the first non-`dw_const` line. Those maps' NPCs fall back to stub text. The
    object_event cross-check below reports them rather than letting them stay silent.
    """
    path = SCRIPTS_DIR / f"{label}.asm"
    if not path.exists():
        return []
    names, in_table = [], False
    for line in path.read_text(encoding="utf-8").splitlines():
        s = line.strip()
        if s == f"{label}_TextPointers:":
            in_table = True
            continue
        if not in_table:
            continue
        if not s or s.startswith(';') or s == 'def_text_pointers':
            continue
        m = re.match(r'dw_const\s+\w+\s*,\s*(\w+)', s)
        if not m:
            break
        names.append(m.group(1))
    return names


def parse_object_file(label: str, debug_warps: bool = False):
    """Parse objects/<label>.asm → (border_byte, warp_list, signs, sprites).

    warp_list = [(y, x, dest_const, warp_id), ...]
    signs     = list of dicts: {y, x, text_id, text_name}  (one per bg_event)
    sprites   = list of dicts:
                  {sprite_id, mapy, mapx, mov, dir,
                   is_trainer, trainer_class, trainer_num,
                   is_item, item_id}
    Returns None if file not found.
    """
    obj_file = MAP_OBJECTS_DIR / f"{label}.asm"
    if not obj_file.exists():
        return None
    raw = obj_file.read_text()
    text = raw if debug_warps else strip_debug_blocks(raw)

    # Border byte: "db $XX ; border block"
    border = 0
    bm = re.search(r"db\s+\$([0-9A-Fa-f]+)\s*;\s*border block", text)
    if bm:
        border = int(bm.group(1), 16)

    # Warp events: warp_event X, Y, DEST, WARP_ID
    warps = []
    for wm in re.finditer(r"warp_event\s+(\d+),\s*(\d+),\s*(\w+),\s*(\d+)", text):
        x, y, dest_const, warp_id = int(wm.group(1)), int(wm.group(2)), wm.group(3), int(wm.group(4))
        warps.append((y, x, dest_const, warp_id))

    # Sign (bg_event) events: bg_event X, Y, TEXT_ID  → binary record (Y, X, text_id).
    # The text id is resolved by NAME against the map's dw_const text-pointer list, not
    # by position: bg_events follow the object_events in that list, but nothing in the
    # source guarantees it, and a positional guess would silently mis-address a sign.
    # The id is pret's 1-based const (= list index + 1); see the emission site.
    text_names = text_pointer_names(label)
    signs = []
    for sm in re.finditer(r"bg_event\s+(\d+),\s*(\d+),\s*(\w+)", text):
        x, y, text_name = int(sm.group(1)), int(sm.group(2)), sm.group(3)
        if text_name in text_names:
            text_id = text_names.index(text_name) + 1   # pret's 1-based dw_const value
        else:
            # No resolvable text pointer → id 0, which is a GENUINE "no text" sentinel
            # now that ids are 1-based (it was not when they were 0-based — see F-10).
            # The sign is walked into and says nothing; never a garbage glyph or an
            # out-of-bounds table index.
            text_id = 0
            print(f"[map_headers] {label}: bg_event text {text_name} not in "
                  f"{label}_TextPointers — emitting id 0 (silent sign)", file=sys.stderr)
        signs.append({'y': y, 'x': x, 'text_id': text_id, 'text_name': text_name})

    # NPC object events: object_event x, y, sprite, mov, dir, text [, arg7 [, arg8]]
    # Binary layout per macro:  sprite_id, y+4, x+4, mov, dir, text_byte [, extra...]
    # text_byte: plain text_id (std), ITEM|text_id (item, 7 args), TRAINER|text_id (trainer, 8 args)
    sprites = []
    for om in re.finditer(
            r"\bobject_event\b\s+"
            r"([^,\n]+),\s*([^,\n]+),\s*([^,\n]+),\s*([^,\n]+),\s*([^,\n]+),\s*([^,\n]+)"
            r"(?:,\s*([^,\n]+)(?:,\s*([^,\n\s]+))?)?",
            text):
        x_s   = om.group(1).strip()
        y_s   = om.group(2).strip()
        spr_s = om.group(3).strip()
        mov_s = om.group(4).strip()
        dir_s = om.group(5).strip()
        # group 6 = text_const (name only — text byte = sequential index, not resolved here)
        arg7  = om.group(7)   # item_id (7-arg) or trainer_class (8-arg) or None
        arg8  = om.group(8)   # trainer_num (8-arg) or None

        x         = int(x_s)
        y         = int(y_s)
        sprite_id = _resolve_const(spr_s, _SPRITE_CONSTS, f"sprite in {label}")
        mov_byte  = _resolve_const(mov_s, _MOV_CONSTS,    f"mov in {label}")
        dir_byte  = _resolve_const(dir_s, _DIR_CONSTS,    f"dir in {label}")

        is_trainer = (arg7 is not None and arg8 is not None)
        is_item    = (arg7 is not None and arg8 is None)
        trainer_class = _resolve_const(arg7.strip(), {}, f"trainer_class in {label}") if is_trainer else 0
        trainer_num   = _resolve_const(arg8.strip(), {}, f"trainer_num in {label}")   if is_trainer else 0
        item_id       = _resolve_const(arg7.strip(), {}, f"item_id in {label}")       if is_item    else 0

        sprites.append({
            'sprite_id':     sprite_id,
            'mapy':          y + 4,
            'mapx':          x + 4,
            'mov':           mov_byte,
            'dir':           dir_byte,
            'is_trainer':    is_trainer,
            'trainer_class': trainer_class,
            'trainer_num':   trainer_num,
            'is_item':       is_item,
            'item_id':       item_id,
        })

    return border, warps, signs, sprites


def get_connection(direction, conn_map_id, offset,
                   cur_width, cur_height, conn_width, conn_height):
    """Compute connection strip parameters (preserved from Phase 2)."""
    BORDER = 7
    stride = conn_width + 2 * BORDER

    _src = 0
    _tgt = offset + BORDER
    # DIVERGENCE (border): pret's `connection` macro (macros/scripts/maps.asm) writes
    # `IF _tgt < 2` with MAP_BORDER = 3. No connection in the game uses offset -1 or -2,
    # so at border 3 that test is exactly equivalent to `_tgt < 0` on all real data. At
    # the port's border 6 it is NOT: offset -5 yields _tgt = 1, which trips the clamp and
    # produces _src = -1 — a negative source row, so _blk indexes one block-row before the
    # connected map's data and strip_length overruns by one. Nine connections use offset -5
    # (Route1/2/5/6/19/24). The clamp exists to stop a negative *destination* row, so the
    # faithful generalization of pret's intent is `_tgt < 0`.
    if _tgt < 0:
        _src = -_tgt
        _tgt = 0

    if direction == "NORTH":
        _blk = conn_width * (conn_height - BORDER) + _src
        _map = _tgt
        view_start_row = conn_height + BORDER - 5
        view_start_col = BORDER - 6
        _win = view_start_row * stride + view_start_col
        _y = conn_height * 2 - 1
        _x = offset * -2
        _len = cur_width + BORDER - offset
        if _len > conn_width: _len = conn_width
    elif direction == "SOUTH":
        _blk = _src
        _map = (cur_width + 2 * BORDER) * (cur_height + BORDER) + _tgt
        view_start_row = BORDER - 4
        view_start_col = BORDER - 6
        _win = view_start_row * stride + view_start_col
        _y = 0
        _x = offset * -2
        _len = cur_width + BORDER - offset
        if _len > conn_width: _len = conn_width
    elif direction == "WEST":
        _blk = conn_width * _src + conn_width - BORDER
        _map = (cur_width + 2 * BORDER) * _tgt
        view_start_row = BORDER - 4
        view_start_col = conn_width + BORDER - 7
        _win = view_start_row * stride + view_start_col
        _y = offset * -2
        _x = conn_width * 2 - 1
        _len = cur_height + BORDER - offset
        if _len > conn_height: _len = conn_height
    elif direction == "EAST":
        _blk = conn_width * _src
        _map = (cur_width + 2 * BORDER) * _tgt + cur_width + BORDER
        view_start_row = BORDER - 4
        view_start_col = BORDER - 6
        _win = view_start_row * stride + view_start_col
        _y = offset * -2
        _x = 0
        _len = cur_height + BORDER - offset
        if _len > conn_height: _len = conn_height

    strip_length = _len - _src
    return {
        "conn_map_id": conn_map_id,
        "blk": _blk,
        "map": _map,
        "win": _win,
        "y": _y,
        "x": _x,
        "len": strip_length,
        "conn_width": conn_width,
    }


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main(debug_warps=None):
    # debug_warps=None → parse argv (CLI use); otherwise use the passed value
    # (so gen_all_assets.py can chain this generator without argument parsing).
    if debug_warps is None:
        ap = argparse.ArgumentParser(description="Generate dos_port/assets/map_headers.inc")
        ap.add_argument("--debug-warps", action="store_true",
                        help="Include IF DEF(_DEBUG) warp entries (e.g. REDS_HOUSE_2F teleports)")
        args = ap.parse_args()
        debug_warps = args.debug_warps

    ASSETS.mkdir(parents=True, exist_ok=True)
    out_path = ASSETS / "map_headers.inc"

    # ---- Parse pret source ----
    MAP_INFO = parse_map_constants()            # const → (id, w, h)
    allocate_rom_window(MAP_INFO)               # fills OUTDOOR_BLK_ADDRS + the OW_* addrs
    const_to_label, label_tileset = parse_all_headers()

    # Reverse: id → const_name
    id_to_const = {v[0]: k for k, v in MAP_INFO.items()}

    # For warp dest resolution: const_name → id
    const_to_id = {k: v[0] for k, v in MAP_INFO.items()}
    const_to_id["LAST_MAP"] = 0xFF

    # Parse all object files keyed by label
    label_objects = {}   # label → (border, warps, signs, sprites)
    for f in MAP_OBJECTS_DIR.glob("*.asm"):
        label = f.stem
        result = parse_object_file(label, debug_warps=debug_warps)
        if result:
            label_objects[label] = result

    # ---- Build per-map database (sorted by ID) ----
    # maps_db[id] = {const, label, w, h, tileset_id, tileset_name,
    #                blk_addr, is_outdoor, conns, border, warps,
    #                sign_count, sprite_count}
    maps_db = {}
    for const, (id_, w, h) in MAP_INFO.items():
        if id_ > 0xF8:
            continue  # LAST_MAP sentinel
        if w == 0 and h == 0:
            # Unused map — emit null entry
            maps_db[id_] = None
            continue

        label = const_to_label.get(const)
        if label is None:
            # Try pascal name (for COPY maps like CERULEAN_TRASHED_HOUSE_COPY)
            guessed = const_to_pascal(const)
            if (MAP_HEADERS_DIR / f"{guessed}.asm").exists():
                # Found header file by name; parse it for tileset
                result = parse_object_file(guessed, debug_warps=debug_warps)
                if result:
                    label_objects[guessed] = result
                # Read tileset from the header file
                hf_text = (MAP_HEADERS_DIR / f"{guessed}.asm").read_text()
                hm = re.search(r"map_header\s+(\w+),\s*(\w+),\s*(\w+)", hf_text)
                if hm:
                    label_tileset[guessed] = hm.group(3)
                label = guessed
            else:
                # No header at all; emit stub
                maps_db[id_] = None
                continue

        tileset_name = label_tileset.get(label, "HOUSE")
        tileset_id   = TILESET_IDS.get(tileset_name, 8)   # default HOUSE
        is_outdoor   = const in OUTDOOR_BLK_ADDRS   # populated by allocate_rom_window()

        if is_outdoor:
            blk_addr = OUTDOOR_BLK_ADDRS[const]
        else:
            blk_addr = INDOOR_BLK_GBADDR

        # Get object data
        obj = label_objects.get(label)
        if obj:
            border, raw_warps, signs, sprites = obj
        else:
            border, raw_warps, signs, sprites = 0, [], [], []
        sprite_count = len(sprites)

        # Resolve warp dest bytes
        warps_bytes = []
        for (wy, wx, dest_const, warp_id) in raw_warps:
            dest_id = const_to_id.get(dest_const, 0xFF)
            warps_bytes.append((wy, wx, warp_id - 1, dest_id))

        maps_db[id_] = {
            "const":         const,
            "label":         label,
            "w":             w,
            "h":             h,
            "tileset_id":    tileset_id,
            "tileset_name":  tileset_name,
            "blk_addr":      blk_addr,
            "is_outdoor":    is_outdoor,
            "border":        border,
            "warps":         warps_bytes,
            "signs":         signs,
            "sprite_count":  sprite_count,
            "sprites":       sprites,
        }

    # ---- Emit output ----
    lines = [
        "; map_headers.inc — generated by tools/generators/gen_map_headers.py. DO NOT EDIT BY HAND.",
        "; Source: constants/map_constants.asm, data/maps/headers/*.asm, data/maps/objects/*.asm",
        "",
        "; ==========================================================================",
        "; TILESET DISPATCH TABLES (flat DS addresses, not EBP-relative)",
        "; Indexed by W_CUR_MAP_TILESET (0-24). Used by LoadTilesetHeader.",
        "; Tileset gfx/blocks/coll labels come from dos_port/assets/*_gfx.inc etc.",
        "; SIZE constants are defined in those same inc files.",
        "; ==========================================================================",
        "",
        "TilesetGfxPtrs:",
    ]
    tileset_comments = [
        "OVERWORLD","REDS_HOUSE_1","MART(→pokecenter)","FOREST",
        "REDS_HOUSE_2(→reds_house)","DOJO(→gym)","POKECENTER","GYM",
        "HOUSE","FOREST_GATE(→gate)","MUSEUM(→gate)","UNDERGROUND",
        "GATE","SHIP","SHIP_PORT","CEMETERY","INTERIOR","CAVERN","LOBBY",
        "MANSION","LAB","CLUB","FACILITY","PLATEAU","BEACH_HOUSE",
    ]
    for i, can in enumerate(TILESET_CANONICAL):
        lines.append(f"    dd {can}_gfx        ; {i} {tileset_comments[i]}")
    lines.append("")

    lines.append("TilesetBlocksPtrs:")
    for i, can in enumerate(TILESET_CANONICAL):
        lines.append(f"    dd {can}_blocks      ; {i}")
    lines.append("")

    lines.append("TilesetCollPtrs:")
    for i, can in enumerate(TILESET_CANONICAL):
        lines.append(f"    dd {can}_coll        ; {i}")
    lines.append("")

    lines.append("TilesetGfxSizes:")
    for i, can in enumerate(TILESET_CANONICAL):
        lines.append(f"    dd {can.upper()}_GFX_SIZE    ; {i}")
    lines.append("")

    lines.append("TilesetBlocksSizes:")
    for i, can in enumerate(TILESET_CANONICAL):
        lines.append(f"    dd {can.upper()}_BLOCKS_SIZE  ; {i}")
    lines.append("")

    # ---- Indoor map block dispatch tables ----
    lines.extend([
        "; ==========================================================================",
        "; INDOOR MAP BLOCK DISPATCH TABLES (flat DS addresses)",
        "; Indexed by (map_id - FIRST_INDOOR_MAP_ID) where FIRST_INDOOR_MAP_ID = 0x25",
        "; Labels like reds_house1f_blk come from dos_port/assets/*_blk.inc.",
        "; null_indoor_blk (defined below) used for maps with no .blk file.",
        "; ==========================================================================",
        "",
        "; Null fallback blk: 256 zero bytes — safe for maps with missing .blk data.",
        "null_indoor_blk:",
        "    times 256 db 0",
        "null_indoor_blk_end:",
        "NULL_INDOOR_BLK_SIZE equ null_indoor_blk_end - null_indoor_blk",
        "",
    ])

    max_map_id = max(k for k in maps_db)
    first_indoor = FIRST_INDOOR_MAP_ID

    # Collect indoor map IDs in order
    indoor_ids = sorted(id_ for id_ in range(first_indoor, max_map_id + 1)
                        if id_ in maps_db)

    # Build label → blk label mapping for indoor maps
    def indoor_blk_label(id_):
        """Return the NASM label for this indoor map's blk data."""
        m = maps_db.get(id_)
        if m is None:
            return "null_indoor_blk", "NULL_INDOOR_BLK_SIZE"
        label = m["label"]
        snake  = to_snake(label)
        blk_label  = f"{snake}_blk"
        size_label = f"{snake.upper()}_BLK_SIZE"
        # Check if .blk file exists for this label
        blk_file = MAPS_DIR / f"{label}.blk"
        if blk_file.exists():
            return blk_label, size_label
        # Try stripping "Copy" suffix and fall back to original
        if label.endswith("Copy"):
            orig_label = label[:-4]
            orig_blk   = MAPS_DIR / f"{orig_label}.blk"
            if orig_blk.exists():
                orig_snake     = to_snake(orig_label)
                return f"{orig_snake}_blk", f"{orig_snake.upper()}_BLK_SIZE"
        return "null_indoor_blk", "NULL_INDOOR_BLK_SIZE"

    lines.append("IndoorMapBlkPtrs:")
    for id_ in range(first_indoor, max_map_id + 1):
        blk_lbl, _ = indoor_blk_label(id_)
        const = id_to_const.get(id_, f"MAP_{id_:02X}")
        lines.append(f"    dd {blk_lbl:<40s}; 0x{id_:02X} {const}")
    lines.append("")

    lines.append("IndoorMapBlkSizes:")
    for id_ in range(first_indoor, max_map_id + 1):
        _, size_lbl = indoor_blk_label(id_)
        const = id_to_const.get(id_, f"MAP_{id_:02X}")
        lines.append(f"    dd {size_lbl:<40s}; 0x{id_:02X} {const}")
    lines.append("")

    # ---- Map header data blob ----
    lines.extend([
        "; ==========================================================================",
        "; MAP HEADER DATA BLOB",
        "; Copied to EBP+OW_TILESET_HDR_GBADDR (rom_window.inc) by LoadOverworldAssets.",
        "; All dw/db values are EBP-relative (GB address space) unless noted.",
        "; ==========================================================================",
        "",
        "map_headers_data:",
        "; --- OVERWORLD tileset header (12 bytes, kept for layout compatibility) ---",
        "tileset_header_OVERWORLD:",
        "    db 0x01                 ; bank",
        "    dw OW_BLOCKS_GBADDR     ; blocks ptr",
        "    dw OW_GFX_GBADDR        ; gfx ptr",
        "    dw OW_COLL_GBADDR       ; collision ptr",
        "    db 0xFF, 0xFF, 0xFF     ; counters",
        "    db 0x52                 ; grass tile",
        "    db 0x02                 ; tile animations",
        "",
    ])

    W_OVERWORLD_MAP = 0xE800
    current_addr = OW_MAP_HEADERS_GBADDR

    # MapHeaderPointers entries computed as we go
    map_hdr_ptrs = {}    # id → EBP addr of its header (or 0 for stubs)

    # Two-pass: first compute all header addrs, then emit
    # (Since we emit inline, just track current_addr)

    def emit_map_header(const: str, m: dict, my_conns: list) -> list:
        """Emit lines for one map's header + object data. Returns lines list."""
        nonlocal current_addr

        id_ = MAP_INFO[const][0]
        map_hdr_ptrs[id_] = current_addr

        conn_flags = sum(CONN_BITS[d] for d, _, _ in my_conns)

        hdr_lines = []
        hdr_lines.append(f"OW_MAP_HDR_{const} equ 0x{current_addr:04X}")
        hdr_lines.append(f"map_header_{const}:")
        hdr_lines.append(f"    db 0x{m['tileset_id']:02X}       ; tileset {m['tileset_name']}")
        hdr_lines.append(f"    db {m['h']}, {m['w']}  ; height, width")
        hdr_lines.append(f"    dw 0x{m['blk_addr']:04X} ; blocks_ptr")
        hdr_lines.append(f"    dw 0x0000         ; text_ptr (stub)")
        hdr_lines.append(f"    dw 0x0000         ; script_ptr (stub)")
        hdr_lines.append(f"    db 0x{conn_flags:02X}   ; connections bitmask")
        current_addr += 10

        # Connection headers (N, S, W, E order)
        for check_d in ["NORTH", "SOUTH", "WEST", "EAST"]:
            for (d, tname, offset) in my_conns:
                if d != check_d:
                    continue
                t_id, t_w, t_h = MAP_INFO[tname]
                c = get_connection(d, t_id, offset,
                                   m["w"], m["h"], t_w, t_h)
                strip_src  = OUTDOOR_BLK_ADDRS[tname] + c["blk"]
                strip_dest = W_OVERWORLD_MAP + c["map"]
                view_ptr   = W_OVERWORLD_MAP + c["win"]
                hdr_lines.append(f"    ; {d} connection to {tname}")
                hdr_lines.append(f"    db 0x{c['conn_map_id']:02X}       ; map id")
                hdr_lines.append(f"    dw 0x{strip_src:04X}     ; strip src")
                hdr_lines.append(f"    dw 0x{strip_dest:04X}    ; strip dest")
                hdr_lines.append(f"    db {c['len']}            ; strip length")
                hdr_lines.append(f"    db {c['conn_width']}     ; connected map width")
                hdr_lines.append(f"    db {c['y']}, {c['x']}   ; Y, X align")
                hdr_lines.append(f"    dw 0x{view_ptr:04X}      ; view ptr")
                current_addr += 11

        # object_data_ptr (points to object data immediately following)
        hdr_lines.append(f"    dw 0x{current_addr + 2:04X} ; object_data_ptr")
        current_addr += 2

        # Object data
        hdr_lines.append(f"map_object_{const}:")
        hdr_lines.append(f"    db 0x{m['border']:02X} ; border block")
        current_addr += 1

        warps = m["warps"]
        hdr_lines.append(f"    db {len(warps)} ; warp count")
        current_addr += 1
        for (wy, wx, dest_id_minus1, dest_map) in warps:
            hdr_lines.append(f"    db {wy}, {wx}, {dest_id_minus1}, 0x{dest_map:02X}")
            current_addr += 4

        # Signs: count, then one 3-byte (Y, X, text_id) record each — the layout
        # LoadMapHeader/CopySignData copies into wSignCoords/wSignTextIDs and SignLoop
        # searches. (These used to be `times n*3 db 0` STUBS, so every sign in the game
        # read as Y=0 X=0 id=0 and no sign could ever be matched — F-6.)
        signs = m["signs"]
        hdr_lines.append(f"    db {len(signs)} ; sign count")
        current_addr += 1
        for s in signs:
            hdr_lines.append(f"    db {s['y']}, {s['x']}, 0x{s['text_id']:02X}"
                             f"  ; {s['text_name']}")
            current_addr += 3

        hdr_lines.append(f"    db {m['sprite_count']} ; sprite count")
        current_addr += 1

        # Per-NPC binary records (6 bytes standard, 7 bytes item, 8 bytes trainer).
        #
        # The text byte carries pret's 1-BASED text id (slot i → id i+1), with the
        # TRAINER/ITEM flags OR'd into bits 6/7 exactly as pret's `object_event` macro
        # does (macros/scripts/maps.asm: `db TRAINER | \6`, where \6 is the 1-based
        # TEXT_* const). LoadSprite recovers the id with `and $3f`.
        #
        # It is 1-based because pret's text ids are: `def_text_pointers` is `const_def 1`
        # (macros/scripts/maps.asm), and DisplayTextID subtracts one AT THE LOOKUP
        # (home/text_script.asm: `dec a` before indexing TextPointers). The port used to
        # fold that `dec a` in here, emitting 0-based ids — which collided with the
        # `id 0 == no text` sentinel the consumers still used, silently swallowing every
        # text id 0 in the game. The `-1` now lives at the lookup, as it does in pret.
        for i, npc in enumerate(m.get('sprites', [])):
            text_id = i + 1
            if text_id > _TEXT_ID_MAX:
                raise SystemExit(
                    f"[map_headers] {label}: NPC slot {i} needs text id {text_id}, but the"
                    f" text byte only has {_TEXT_ID_MAX} usable ids — bits 6/7 are the"
                    f" TRAINER/ITEM flags (LoadSprite masks with `and $3f`)."
                )
            if npc['is_trainer']:
                text_byte = _TRAINER_FLAG | text_id
                hdr_lines.append(
                    f"    db 0x{npc['sprite_id']:02X}, 0x{npc['mapy']:02X}, 0x{npc['mapx']:02X},"
                    f" 0x{npc['mov']:02X}, 0x{npc['dir']:02X}, 0x{text_byte:02X},"
                    f" 0x{npc['trainer_class']:02X}, 0x{npc['trainer_num']:02X}"
                    f"  ; slot {i+1}: trainer sprite=0x{npc['sprite_id']:02X}"
                )
                current_addr += 8
            elif npc['is_item']:
                text_byte = _ITEM_FLAG | text_id
                hdr_lines.append(
                    f"    db 0x{npc['sprite_id']:02X}, 0x{npc['mapy']:02X}, 0x{npc['mapx']:02X},"
                    f" 0x{npc['mov']:02X}, 0x{npc['dir']:02X}, 0x{text_byte:02X},"
                    f" 0x{npc['item_id']:02X}"
                    f"  ; slot {i+1}: item sprite=0x{npc['sprite_id']:02X}"
                )
                current_addr += 7
            else:
                hdr_lines.append(
                    f"    db 0x{npc['sprite_id']:02X}, 0x{npc['mapy']:02X}, 0x{npc['mapx']:02X},"
                    f" 0x{npc['mov']:02X}, 0x{npc['dir']:02X}, 0x{text_id:02X}"
                    f"  ; slot {i+1}: npc sprite=0x{npc['sprite_id']:02X} mapy={npc['mapy']} mapx={npc['mapx']}"
                )
                current_addr += 6

        hdr_lines.append("")
        return hdr_lines

    # Emit outdoor maps (in ID order)
    lines.append("; --- Outdoor map headers (OVERWORLD-tileset, pre-loaded blk data) ---")
    outdoor_ids = sorted(const for const in OUTDOOR_BLK_ADDRS
                         if const in MAP_INFO)

    for const in sorted(outdoor_ids, key=lambda c: MAP_INFO[c][0]):
        m = maps_db.get(MAP_INFO[const][0])
        if m is None:
            continue
        my_conns = CONNECTIONS.get(const, [])
        lines.extend(emit_map_header(const, m, my_conns))

    # Emit indoor maps (id >= FIRST_INDOOR_MAP_ID, in ID order)
    lines.append("; --- Indoor map headers (non-OVERWORLD tileset, shared INDOOR_BLK_GBADDR) ---")
    for id_ in range(FIRST_INDOOR_MAP_ID, max_map_id + 1):
        m = maps_db.get(id_)
        if m is None:
            # Stub: no header data, just record null in ptr table
            map_hdr_ptrs[id_] = 0x0000
            continue
        lines.extend(emit_map_header(m["const"], m, []))

    lines.append(f"MAP_HEADERS_DATA_SIZE equ $ - map_headers_data")
    lines.append("")

    # ---- MapHeaderPointers table ----
    # Inserted BEFORE map_headers_data in the file (but we prepend it now)
    ptr_lines = [
        "; ==========================================================================",
        "; MapHeaderPointers — flat DS label; entries are 16-bit EBP-relative addrs.",
        "; LoadMapHeader: movzx ebx, word [MapHeaderPointers + map_id*2]; add ebx, ebp",
        "; ==========================================================================",
        "",
        "MapHeaderPointers:",
    ]
    for i in range(max_map_id + 1):
        addr = map_hdr_ptrs.get(i, 0x0000)
        const = id_to_const.get(i, f"MAP_{i:02X}")
        if addr:
            ptr_lines.append(f"    dw 0x{addr:04X}   ; 0x{i:02X} {const}")
        else:
            ptr_lines.append(f"    dw 0x0000   ; 0x{i:02X} {const} (stub/unused)")
    ptr_lines.append("")

    # Combine: dispatch tables, then MapHeaderPointers, then map_headers_data
    # (dispatch tables already in lines[]; insert ptr_lines before map_headers_data)
    # Find insertion point (just before map_headers_data:)
    insert_idx = next(i for i, l in enumerate(lines) if l.strip() == "map_headers_data:")
    lines[insert_idx:insert_idx] = ptr_lines

    out_path.write_text("\n".join(lines) + "\n")
    print(f"Wrote {out_path}")

    # The blob is allocated last, against the VRAM wall. write_rom_window_inc
    # hard-errors if it crosses $8000 (this used to be a WARNING that nothing read).
    write_rom_window_inc(current_addr)

    # ---- Generate extra_includes.inc ----
    # Contains %include lines for all NEW tileset inc files (non-overworld)
    # and all indoor/extra blk inc files not already in overworld.asm.
    # overworld.asm adds one line: %include "assets/extra_includes.inc"
    already_included = {
        "pallet_town_blk", "route1_blk", "route21_blk",
        "viridian_city_blk", "pewter_city_blk", "cerulean_city_blk",
        "lavender_town_blk", "vermilion_city_blk", "celadon_city_blk",
        "fuchsia_city_blk", "cinnabar_island_blk", "saffron_city_blk",
        "route2_blk", "route3_blk", "route4_blk", "route5_blk",
        "route6_blk", "route7_blk", "route8_blk", "route9_blk",
        "route10_blk", "route11_blk", "route12_blk", "route13_blk",
        "route14_blk", "route15_blk", "route16_blk", "route17_blk",
        "route18_blk", "route19_blk", "route20_blk",
        "route22_blk", "route24_blk", "route25_blk",
        "overworld_gfx", "overworld_blocks", "overworld_coll",
    }

    extra_lines = [
        "; extra_includes.inc — generated by tools/generators/gen_map_headers.py. DO NOT EDIT BY HAND.",
        "; Included from overworld.asm to bring in non-overworld tileset assets",
        "; and indoor/extra outdoor map blk data.",
        "",
        "; --- Non-OVERWORLD tileset gfx / blocks / coll inc files ---",
    ]
    seen_canonical = set()
    for can in TILESET_CANONICAL:
        if can == "overworld" or can in seen_canonical:
            continue
        seen_canonical.add(can)
        extra_lines.append(f'%include "assets/{can}_gfx.inc"')
        extra_lines.append(f'%include "assets/{can}_blocks.inc"')
        extra_lines.append(f'%include "assets/{can}_coll.inc"')
    extra_lines.append("")

    extra_lines.append("; --- Extra outdoor blk inc files (Route 23, Indigo Plateau) ---")
    extra_lines.append('%include "assets/route23_blk.inc"')
    extra_lines.append('%include "assets/indigo_plateau_blk.inc"')
    extra_lines.append("")

    extra_lines.append("; --- Indoor map blk inc files ---")
    # Collect all unique blk labels used in IndoorMapBlkPtrs (excluding null_indoor_blk)
    seen_blk = set()
    for id_ in range(FIRST_INDOOR_MAP_ID, max_map_id + 1):
        blk_lbl, _ = indoor_blk_label(id_)
        if blk_lbl == "null_indoor_blk" or blk_lbl in seen_blk or blk_lbl in already_included:
            continue
        seen_blk.add(blk_lbl)
        extra_lines.append(f'%include "assets/{blk_lbl}.inc"')
    extra_lines.append("")

    extra_inc_path = ASSETS / "extra_includes.inc"
    extra_inc_path.write_text("\n".join(extra_lines) + "\n")
    print(f"Wrote {extra_inc_path}")

    # ---- Generate map_dims.inc ----
    # Pret map-id + _WIDTH/_HEIGHT constants (exact pret names, block units)
    # plus the tileset-id constants. Consumed by hand-written .asm that mirrors
    # pret data built from <MAP>_WIDTH constants (e.g. data/maps/
    # special_warps.asm's fly_warp / event_displacement tables), so those
    # values are never re-encoded by hand.
    dims_lines = [
        "; map_dims.inc — generated by tools/generators/gen_map_headers.py. DO NOT EDIT BY HAND.",
        "; Source: constants/map_constants.asm (map_const NAME, width, height ; $id)",
        ";         constants/tileset_constants.asm (tileset ids, via TILESET_IDS)",
        "%ifndef MAP_DIMS_INC",
        "%define MAP_DIMS_INC",
        "",
        "; --- map id / width / height (pret names; width/height in blocks) ---",
    ]
    for const, (id_, w, h) in sorted(MAP_INFO.items(), key=lambda kv: kv[1][0]):
        dims_lines.append(f"{const:<34} equ 0x{id_:02X}")
        dims_lines.append(f"{const + '_WIDTH':<34} equ {w}")
        dims_lines.append(f"{const + '_HEIGHT':<34} equ {h}")
    dims_lines += ["", "; --- tileset ids (constants/tileset_constants.asm) ---"]
    for tname, tid in sorted(TILESET_IDS.items(), key=lambda kv: kv[1]):
        dims_lines.append(f"{tname:<34} equ {tid}")
    dims_lines += ["", "%endif ; MAP_DIMS_INC"]
    dims_path = ASSETS / "map_dims.inc"
    dims_path.write_text("\n".join(dims_lines) + "\n")
    print(f"Wrote {dims_path}")


if __name__ == "__main__":
    main()
