#!/usr/bin/env python3
"""gen_wild_encounters.py — generate dos_port/assets/wild_data.inc from pret source.

Emits the wild-encounter data tables (battle engine plan, Stage 9), resolving all
symbolic species constants from the pret disassembly so the byte layout matches the
original ROM exactly:

  WildDataPointers:          NUM_MAPS flat (dd) pointers, indexed by wCurMap, each
                             pointing at that map's wild-data blob (mirrors
                             data/wild/grass_water.asm:WildDataPointers, but as the
                             port's flat 32-bit pointer model, like EvosMovesPointerTable).
  <Map>WildMons / NothingWildMons:
                             per-map blob: [grass_rate (+20 mon bytes if rate!=0)]
                             [water_rate (+20 mon bytes if rate!=0)]. A "mon byte"
                             pair is (level, internal-index species). This matches
                             data/wild/maps/*.asm exactly (LoadWildData reads it).
  WildMonEncounterSlotChances:
                             10 (cumulative_chance-1, slot*2) pairs
                             (data/wild/probabilities.asm).

Run from repo root (or dos_port/); paths resolve relative to the repo root.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]          # repo root
ASSETS = ROOT / "dos_port" / "assets"


def parse_consts(rel_path: str) -> dict:
    """Parse an rgbds const_def/const enum file into {NAME: value}."""
    out = {}
    val = 0
    for line in (ROOT / rel_path).read_text().splitlines():
        s = line.split(";", 1)[0].strip()
        if not s:
            continue
        m = re.match(r"const_def(?:\s+(-?\w+))?$", s)
        if m:
            val = int(m.group(1)) if m.group(1) else 0
            continue
        m = re.match(r"const_next\s+(-?\w+)$", s)
        if m:
            val = int(m.group(1))
            continue
        m = re.match(r"const_skip(?:\s+(\w+))?$", s)
        if m:
            val += int(m.group(1)) if m.group(1) else 1
            continue
        m = re.match(r"const\s+(\w+)$", s)
        if m:
            out[m.group(1)] = val
            val += 1
    return out


SPECIES = parse_consts("constants/pokemon_constants.asm")


def parse_blobs() -> dict:
    """Parse every data/wild/maps/*.asm into {label: bytes}.

    A blob label is a line `Foo:` at column 0. Within it, def_/db/end_ lines build
    the byte sequence in file order, which is exactly the ROM layout consumed by
    LoadWildData.
    """
    blobs = {}
    for path in sorted((ROOT / "data/wild/maps").glob("*.asm")):
        cur = None
        for raw in path.read_text().splitlines():
            s = raw.split(";", 1)[0].strip()
            if not s:
                continue
            m = re.match(r"(\w+):$", s)
            if m:
                cur = m.group(1)
                blobs[cur] = bytearray()
                continue
            if cur is None:
                continue
            m = re.match(r"def_(?:grass|water)_wildmons\s+(\w+)$", s)
            if m:
                blobs[cur].append(int(m.group(1), 0) & 0xFF)
                continue
            if s.startswith("end_grass_wildmons") or s.startswith("end_water_wildmons"):
                continue
            m = re.match(r"db\s+(\w+)\s*,\s*(\w+)$", s)
            if m:
                level = int(m.group(1), 0)
                species = SPECIES[m.group(2)]
                blobs[cur].append(level & 0xFF)
                blobs[cur].append(species & 0xFF)
                continue
            sys.exit(f"gen_wild_encounters: unparsed line in {path.name}: {raw!r}")
    return blobs


def parse_pointers() -> list:
    """Ordered list of map blob labels from grass_water.asm:WildDataPointers."""
    labels = []
    in_table = False
    for raw in (ROOT / "data/wild/grass_water.asm").read_text().splitlines():
        s = raw.split(";", 1)[0].strip()
        if s == "WildDataPointers:":
            in_table = True
            continue
        if not in_table:
            continue
        m = re.match(r"dw\s+(\w+)$", s)
        if m:
            labels.append(m.group(1))
            continue
        if re.match(r"dw\s+-1$", s):  # end marker
            break
    return labels


def parse_slot_chances() -> list:
    """(cumulative-1, slot*2) pairs, faithfully reproducing the wild_chance macro."""
    chances = []
    for raw in (ROOT / "data/wild/probabilities.asm").read_text().splitlines():
        s = raw.split(";", 1)[0].strip()
        m = re.match(r"wild_chance\s+(\d+)$", s)
        if m:
            chances.append(int(m.group(1)))
    rows = []
    total = 0
    for slot, c in enumerate(chances):
        total += c
        rows.append((total - 1, slot * 2))
    assert total == 256, f"WildMonEncounterSlotChances sum {total} != 256"
    return rows


def main():
    blobs = parse_blobs()
    pointers = parse_pointers()
    slot_chances = parse_slot_chances()

    missing = [lbl for lbl in pointers if lbl not in blobs]
    if missing:
        sys.exit(f"gen_wild_encounters: pointer labels with no blob: {sorted(set(missing))}")

    out = []
    out.append("; AUTO-GENERATED by tools/gen_wild_encounters.py — do not edit.")
    out.append("; Wild-encounter data (battle engine plan, Stage 9), from data/wild/.")
    out.append(f"; WildDataPointers: {len(pointers)} flat (dd) pointers, indexed by wCurMap.")
    out.append("")

    # Pointer table (flat dd, like EvosMovesPointerTable).
    out.append("WildDataPointers:")
    for lbl in pointers:
        out.append(f"    dd {lbl}")
    # End label: pret terminates the table with `dw -1` and walks it until that
    # sentinel (FindWildLocationsOfMon). The flat dd table has no sentinel, so the
    # port bounds the same loop with this label instead.
    out.append("WildDataPointersEnd:")
    out.append("")

    # Encounter-slot cumulative chance table.
    out.append("WildMonEncounterSlotChances:")
    for cum, slot2 in slot_chances:
        out.append(f"    db {cum}, {slot2}")
    out.append("")

    # The unique blobs, each labelled. Emit in first-reference order for readability.
    emitted = set()
    for lbl in pointers:
        if lbl in emitted:
            continue
        emitted.add(lbl)
        data = blobs[lbl]
        out.append(f"{lbl}:")
        out.append("    db " + ", ".join(str(b) for b in data))
    out.append("")

    dst = ASSETS / "wild_data.inc"
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_text("\n".join(out) + "\n")
    print(f"wrote {dst} (WildDataPointers {len(pointers)} entries, "
          f"{len(emitted)} unique blobs, {len(slot_chances)} encounter slots)")


if __name__ == "__main__":
    main()
