#!/usr/bin/env python3
"""Generate dos_port/assets/mon_icons.inc — the party-mon icon tile patterns,
the ICON_* enum, and MonPartyData, from the pret graphics + data.

Tier-1 data (project-conventions): this file is the deterministic function of
the read-only pret sources listed below; it holds no hand-authored information.
The code that consumes it is src/engine/gfx/mon_icons.asm (pret
engine/gfx/mon_icons.asm), which owns MonPartySpritePointers — a pointer table,
i.e. Tier-2 code — and reads the labels emitted here.

Sources:
  constants/icon_constants.asm   → the ICON_* enum + ICONOFFSET
  gfx/sprites/*.2bpp             → MonsterSprite / PokeBallSprite / FossilSprite /
                                   FairySprite / BirdSprite / SeelSprite /
                                   PikachuSprite (overworld sheets whose spare
                                   tiles are the icon frames)
  gfx/icons/*.2bpp               → Bug/Plant/Snake/Quadruped icon frames
  gfx/trade/bubble.2bpp          → TradeBubbleIconGFX
  data/pokemon/menu_icons.asm    → MonPartyData (nybble array, dex order)

Layout notes carried over from pret verbatim (they are load-bearing):
  - PokeBallSprite's header copies 8 tiles from a 4-tile file: the read runs off
    the end of poke_ball.2bpp straight into FossilSprite, which is exactly how
    the helix icon (ICON_HELIX, tiles 4 past the ball) gets its graphics. The two
    blobs are therefore emitted BACK TO BACK and must stay adjacent.
  - Icons are NOT mirrored here. The right column of every non-helix icon is the
    left column X-flipped at draw time (OAM_XFLIP, WriteSymmetricMonPartySpriteOAM);
    only ICON_HELIX ships all four tiles.

Run from the repo root (wired into `make -C dos_port assets`):
  python3 dos_port/tools/gen_mon_icons_inc.py
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DST = ROOT / "dos_port" / "assets" / "mon_icons.inc"


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


def parse_iconoffset() -> int:
    for line in (ROOT / "constants/icon_constants.asm").read_text().splitlines():
        m = re.match(r"DEF\s+ICONOFFSET\s+EQU\s+\$([0-9a-fA-F]+)", line.strip())
        if m:
            return int(m.group(1), 16)
    raise SystemExit("ICONOFFSET not found in constants/icon_constants.asm")


# The blobs mon_icons.asm's MonPartySpritePointers indexes, in pret's ROM order.
# (label, source file, byte offset, byte length) — length None = whole file.
BLOBS = [
    ("MonsterSprite",       "gfx/sprites/monster.2bpp",   0, None),
    ("PokeBallSprite",      "gfx/sprites/poke_ball.2bpp", 0, None),
    ("FossilSprite",        "gfx/sprites/fossil.2bpp",    0, None),  # ICON_HELIX (see header)
    ("FairySprite",         "gfx/sprites/fairy.2bpp",     0, None),
    ("BirdSprite",          "gfx/sprites/bird.2bpp",      0, None),
    ("SeelSprite",          "gfx/sprites/seel.2bpp",      0, None),
    ("PikachuSprite",       "gfx/sprites/pikachu.2bpp",   0, None),
    # pret: DEF INC_FRAME_1 EQUS "0, $20" / INC_FRAME_2 EQUS "$20, $20"
    ("BugIconFrame1",       "gfx/icons/bug.2bpp",         0x00, 0x20),
    ("PlantIconFrame1",     "gfx/icons/plant.2bpp",       0x00, 0x20),
    ("BugIconFrame2",       "gfx/icons/bug.2bpp",         0x20, 0x20),
    ("PlantIconFrame2",     "gfx/icons/plant.2bpp",       0x20, 0x20),
    ("SnakeIconFrame1",     "gfx/icons/snake.2bpp",       0x00, 0x20),
    ("QuadrupedIconFrame1", "gfx/icons/quadruped.2bpp",   0x00, 0x20),
    ("SnakeIconFrame2",     "gfx/icons/snake.2bpp",       0x20, 0x20),
    ("QuadrupedIconFrame2", "gfx/icons/quadruped.2bpp",   0x20, 0x20),
    ("TradeBubbleIconGFX",  "gfx/trade/bubble.2bpp",      0, None),
]


def build_mon_party_data(ICON: dict) -> list:
    """data/pokemon/menu_icons.asm's nybble_array → the packed bytes.

    rgbds macros/asserts.asm: byte = (first_nybble << 4) | second_nybble, and a
    trailing odd nybble is shifted into the high half. GetPartyMonSpriteID indexes
    it by (dexnum - 1) >> 1 and takes the HIGH nybble for an odd dex number.
    """
    nybbles = []
    for line in (ROOT / "data/pokemon/menu_icons.asm").read_text().splitlines():
        m = re.match(r"nybble\s+(ICON_\w+)", line.split(";", 1)[0].strip())
        if m:
            nybbles.append(ICON[m.group(1)])
    out = []
    for i in range(0, len(nybbles), 2):
        hi = nybbles[i]
        lo = nybbles[i + 1] if i + 1 < len(nybbles) else 0
        out.append((hi << 4) | lo)
    return out, len(nybbles)


def emit_bytes(lines: list, data: bytes, indent: str = "    "):
    for i in range(0, len(data), 16):
        row = data[i:i + 16]
        lines.append(indent + "db " + ", ".join(f"0x{b:02X}" for b in row))


def main():
    ICON = parse_consts("constants/icon_constants.asm")
    iconoffset = parse_iconoffset()
    mon_party_data, n_nybbles = build_mon_party_data(ICON)

    out = [
        "; mon_icons.inc — generated by dos_port/tools/gen_mon_icons_inc.py.",
        "; DO NOT EDIT BY HAND.  Party-mon icon tile patterns + ICON_* enum + MonPartyData.",
        ";",
        "; %included by src/engine/gfx/mon_icons.asm (pret engine/gfx/mon_icons.asm),",
        "; which owns MonPartySpritePointers — the pointer table that reads these labels.",
        "; The icons are OBJ tile patterns: the right column of every non-helix icon is",
        "; the left column X-flipped at draw time (OAM_XFLIP), never baked here.",
        "",
        "; --- ICON_* enum (constants/icon_constants.asm) -----------------------------",
    ]
    for name, val in sorted(ICON.items(), key=lambda kv: kv[1]):
        out.append(f"{name:<22} equ 0x{val:02X}")
    out.append(f"{'ICONOFFSET':<22} equ 0x{iconoffset:02X}   ; tile-id delta between animation frames")
    out.append("")
    out.append("; --- icon tile patterns (2bpp) ----------------------------------------------")
    out.append("; PokeBallSprite / FossilSprite MUST stay adjacent: the ball header copies 8")
    out.append("; tiles from a 4-tile file, running into the fossil — that is the helix icon.")

    for label, path, off, length in BLOBS:
        data = (ROOT / path).read_bytes()
        blob = data[off:off + length] if length is not None else data[off:]
        assert blob, f"{path}: empty slice"
        out.append("")
        out.append(f"{label}:   ; {path}"
                   + (f" +0x{off:X}, {len(blob)} bytes" if length is not None
                      else f" ({len(blob)} bytes)"))
        emit_bytes(out, blob)

    out.append("")
    out.append("; --- MonPartyData (data/pokemon/menu_icons.asm nybble_array) -----------------")
    out.append(f"; {n_nybbles} nybbles, national-dex order; GetPartyMonSpriteID indexes it by")
    out.append("; (dexnum - 1) >> 1 and takes the high nybble when the dex number is odd.")
    out.append("MonPartyData:")
    emit_bytes(out, bytes(mon_party_data))
    out.append("")

    DST.parent.mkdir(parents=True, exist_ok=True)
    DST.write_text("\n".join(out) + "\n")
    print(f"wrote {DST}: {len(BLOBS)} gfx blobs, "
          f"{len(mon_party_data)} MonPartyData bytes ({n_nybbles} nybbles)")


if __name__ == "__main__":
    main()
