"""Read palette metadata from the read-only pret source tree.

The color editor and ``gen_palettes.py`` share these parsers so neither has a
second, hand-maintained copy of Yellow's CGB palette assignments.
"""
from __future__ import annotations

import re
from pathlib import Path

from .tiles import ROOT


def _consts(path: Path, prefix: str, start: int = 0) -> dict[str, int]:
    """Parse RGBDS ``const`` declarations in their source order."""
    value = start
    out: dict[str, int] = {}
    active = False
    for raw in path.read_text().splitlines():
        line = raw.split(";", 1)[0].strip()
        if line == "const_def" or line.startswith("const_def "):
            active = True
            m = re.search(r"const_def\s+(\d+)", line)
            value = int(m.group(1)) if m else start
            continue
        if not active:
            continue
        m = re.match(r"const\s+(%s\w+)" % re.escape(prefix), line)
        if m:
            out[m.group(1)] = value
            value += 1
    return out


def palette_enums() -> tuple[dict[str, int], dict[str, int]]:
    """Return ``(PAL_*, SET_PAL_*)`` name-to-byte maps."""
    path = ROOT / "constants" / "palette_constants.asm"
    return _consts(path, "PAL_"), _consts(path, "SET_PAL_")


def parse_cgb_base_palettes() -> dict[str, list[tuple[int, int, int]]]:
    """``CGBBasePalettes`` as VGA six-bit RGB, keyed by PAL_* name."""
    path = ROOT / "data" / "sgb" / "sgb_palettes.asm"
    pals, _ = palette_enums()
    section = path.read_text().split("CGBBasePalettes:", 1)[1].split(
        "assert_table_length", 1)[0]
    rows: list[list[tuple[int, int, int]]] = []
    for raw in section.splitlines():
        line = raw.split(";", 1)[0]
        nums = [int(n) for n in re.findall(r"\b\d+\b", line)]
        if "RGB" in line:
            if len(nums) != 12:
                raise ValueError(f"bad RGB row in {path}: {raw}")
            rows.append([tuple(round(v * 63 / 31) for v in nums[i:i + 3])
                         for i in range(0, 12, 3)])
    by_index = sorted(pals.items(), key=lambda item: item[1])
    if len(rows) != len(by_index):
        raise ValueError(f"CGBBasePalettes has {len(rows)} rows, expected {len(by_index)}")
    return {name: rows[i] for i, (name, _) in enumerate(by_index)}


def parse_monster_palettes() -> dict[str, str]:
    """Pokédex species (including MISSINGNO) to its ``PAL_*`` family."""
    path = ROOT / "data" / "pokemon" / "palettes.asm"
    out: dict[str, str] = {}
    for raw in path.read_text().splitlines():
        m = re.match(r"\s*db\s+(PAL_\w+)\s*;\s*(\w+)", raw)
        if m:
            out[m.group(2)] = m.group(1)
    if len(out) != 152:
        raise ValueError(f"MonsterPalettes has {len(out)} rows, expected 152")
    return out


def parse_pal_packets() -> dict[str, list[str | int]]:
    """``PalPacket_*`` rows as their four palette ids/names."""
    path = ROOT / "data" / "sgb" / "sgb_packets.asm"
    out: dict[str, list[str | int]] = {}
    for raw in path.read_text().splitlines():
        m = re.match(r"\s*(PalPacket_\w+):\s+PAL_SET\s+(.+)", raw)
        if not m:
            continue
        vals = [v.strip() for v in m.group(2).split(",")]
        if len(vals) != 4:
            raise ValueError(f"bad PAL_SET: {raw}")
        out[m.group(1)] = [int(v, 0) if v[0].isdigit() else v for v in vals]
    return out


def parse_blk_packets() -> dict[str, list[dict[str, int]]]:
    """``BlkPacket_*`` ATTR_BLK rectangles in pret-native tile coordinates."""
    path = ROOT / "data" / "sgb" / "sgb_packets.asm"
    out: dict[str, list[dict[str, int]]] = {}
    current: str | None = None
    for raw in path.read_text().splitlines():
        label = re.match(r"\s*(BlkPacket_\w+):", raw)
        if label:
            current = label.group(1)
            out[current] = []
            continue
        if current is None:
            continue
        m = re.search(r"ATTR_BLK_DATA\s+%[01]+,\s*(\d+),(\d+),\d+,\s*"
                      r"(\d+),(\d+),\s*(\d+),(\d+)", raw)
        if m:
            p0, p1, x1, y1, x2, y2 = map(int, m.groups())
            out[current].append({"pal0": p0, "pal1": p1, "x1": x1,
                                 "y1": y1, "x2": x2, "y2": y2})
    return out
