#!/usr/bin/env python3
"""Generate dos_port/assets/mon_icons.inc — the party-menu mon icon tiles and
the internal-index -> icon lookup, from the pret graphics + data.

Faithful to pret engine/gfx/mon_icons.asm:
  - Each icon is a 16x16 (2x2 tile) animated party sprite with two frames.
  - Non-helix icons have a vertical line of symmetry: the original stores only a
    left column (top + bottom tile) and X-flips it for the right half via OAM.
    This port renders icons as window-layer BG tiles (which have no per-tile flip),
    so we bake the right column here as a horizontal mirror of the left, emitting a
    full 2x2 (TL, TR, BL, BR) per frame.
  - Frame tile pairs come from the same sprite sheets / icon files and offsets the
    pret MonPartySpritePointers table uses (see ICON_SRC below).
  - Species -> icon: PokedexOrder (internal index -> national dex) composed with
    MonPartyData (national dex -> ICON_*), producing one byte per internal index.

Output (NASM, .data):
  mon_icon_data:        11 icons x 2 frames x 4 tiles x 16 bytes, icon-major.
                        offset(icon,frame) = icon*MON_ICON_BYTES + frame*MON_ICON_FRAME_BYTES
  mon_icon_by_index:    one ICON_* id per internal index (1-based -> [i-1]).

Requires nothing beyond the stdlib. Run from repo root:
  python3 dos_port/tools/gen_mon_icons_inc.py
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DST = ROOT / "dos_port" / "assets" / "mon_icons.inc"

TILE = 16  # bytes per 2bpp 8x8 tile


def parse_consts(rel_path: str) -> dict:
    """Parse an rgbds const_def/const enum into {NAME: value} (subset)."""
    out = {}
    val = 0
    for line in (ROOT / rel_path).read_text().splitlines():
        s = line.split(";", 1)[0].strip()
        if not s:
            continue
        m = re.match(r"const_def(?:\s+(-?\w+))?$", s)
        if m:
            val = int(m.group(1), 0) if m.group(1) else 0
            continue
        m = re.match(r"const_skip(?:\s+(\w+))?$", s)
        if m:
            val += int(m.group(1), 0) if m.group(1) else 1
            continue
        m = re.match(r"const\s+(\w+)$", s)
        if m:
            out[m.group(1)] = val
            val += 1
    return out


# icon name -> (2bpp file, kind, frameA_tile_offset, frameB_tile_offset)
#   kind '4': 4-tile sprite-sheet frame; left column = tiles [off], [off+2]
#   kind '2': 2-tile local icon frame;   left column = tiles [off], [off+1]
ICON_SRC = {
    "ICON_MON":       ("gfx/sprites/monster.2bpp",  "4", 12, 0),
    "ICON_BALL":      ("gfx/sprites/poke_ball.2bpp", "4", 0, 0),
    "ICON_HELIX":     ("gfx/sprites/monster.2bpp",  "4", 12, 0),  # no party gfx; fallback
    "ICON_FAIRY":     ("gfx/sprites/fairy.2bpp",    "4", 12, 0),
    "ICON_BIRD":      ("gfx/sprites/bird.2bpp",     "4", 12, 0),
    "ICON_WATER":     ("gfx/sprites/seel.2bpp",     "4", 0, 12),
    "ICON_BUG":       ("gfx/icons/bug.2bpp",        "2", 2, 0),
    "ICON_GRASS":     ("gfx/icons/plant.2bpp",      "2", 2, 0),
    "ICON_SNAKE":     ("gfx/icons/snake.2bpp",      "2", 0, 2),
    "ICON_QUADRUPED": ("gfx/icons/quadruped.2bpp",  "2", 0, 2),
    "ICON_PIKACHU":   ("gfx/sprites/pikachu.2bpp",  "4", 0, 12),
}
NUM_ICONS = 11  # ICON_MON (0) .. ICON_PIKACHU (10), contiguous

_FLIP = [int(f"{b:08b}"[::-1], 2) for b in range(256)]


def hflip_tile(t: bytes) -> bytes:
    """Horizontally mirror a 2bpp tile (reverse the 8 bits of each plane byte)."""
    return bytes(_FLIP[b] for b in t)


def tile(data: bytes, idx: int) -> bytes:
    return data[idx * TILE:(idx + 1) * TILE]


def frame_2x2(path: str, kind: str, off: int) -> bytes:
    """Return a frame's 4 tiles TL,TR,BL,BR (right = mirror of left)."""
    data = (ROOT / path).read_bytes()
    top = tile(data, off)
    bottom = tile(data, off + (2 if kind == "4" else 1))
    return top + hflip_tile(top) + bottom + hflip_tile(bottom)


def build_index_table(ICON: dict) -> list:
    """internal index (0-based) -> ICON_* id."""
    DEX = parse_consts("constants/pokedex_constants.asm")

    # MonPartyData: national-dex-ordered ICON_* names (Bulbasaur first).
    party_data = []
    for line in (ROOT / "data/pokemon/menu_icons.asm").read_text().splitlines():
        m = re.match(r"nybble\s+(ICON_\w+)", line.split(";", 1)[0].strip())
        if m:
            party_data.append(ICON[m.group(1)])

    # PokedexOrder: internal-index-ordered national dex numbers.
    order = []
    for line in (ROOT / "data/pokemon/dex_order.asm").read_text().splitlines():
        s = line.split(";", 1)[0].strip()
        m = re.match(r"db\s+(\w+)$", s)
        if not m:
            continue
        tok = m.group(1)
        dexnum = DEX.get(tok, int(tok, 0) if re.match(r"\$?\d", tok) else 0)
        order.append(dexnum)

    table = []
    for dexnum in order:
        if 1 <= dexnum <= len(party_data):
            table.append(party_data[dexnum - 1])
        else:
            table.append(ICON["ICON_MON"])  # MissingNo / unknown -> generic
    return table


def main():
    ICON = parse_consts("constants/icon_constants.asm")
    inv = {v: k for k, v in ICON.items()}

    # Icon tile data, icon-major (0..10), 2 frames each, 4 tiles each.
    blob = bytearray()
    for icon_id in range(NUM_ICONS):
        name = inv[icon_id]
        path, kind, fa, fb = ICON_SRC[name]
        blob += frame_2x2(path, kind, fa)
        blob += frame_2x2(path, kind, fb)

    index_table = build_index_table(ICON)

    out = []
    out.append("; mon_icons.inc — generated by dos_port/tools/gen_mon_icons_inc.py.")
    out.append("; DO NOT EDIT BY HAND.  Party-menu mon icons (2x2, 2 frames) + index map.")
    out.append("MON_ICON_FRAME_BYTES equ 64    ; 4 tiles * 16 bytes")
    out.append("MON_ICON_BYTES       equ 128   ; 2 frames")
    out.append(f"MON_ICON_COUNT       equ {NUM_ICONS}")
    out.append("")
    out.append("mon_icon_data:")
    for icon_id in range(NUM_ICONS):
        out.append(f"  ; {inv[icon_id]} ({icon_id})")
        base = icon_id * 128
        for f in range(2):
            for t in range(4):
                o = base + f * 64 + t * 16
                row = blob[o:o + 16]
                out.append("    db " + ", ".join(f"0x{b:02X}" for b in row))
    out.append("")
    out.append(f"MON_ICON_BY_INDEX_LEN equ {len(index_table)}")
    out.append("mon_icon_by_index:")
    for i in range(0, len(index_table), 16):
        chunk = index_table[i:i + 16]
        out.append("    db " + ", ".join(str(v) for v in chunk))
    out.append("")

    DST.parent.mkdir(parents=True, exist_ok=True)
    DST.write_text("\n".join(out) + "\n")
    print(f"wrote {DST}: {len(blob)} icon bytes ({NUM_ICONS} icons), "
          f"{len(index_table)} index entries")


if __name__ == "__main__":
    main()
