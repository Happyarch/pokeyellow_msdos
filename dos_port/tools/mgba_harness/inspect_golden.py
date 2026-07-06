#!/usr/bin/env python3
"""Read back a harness golden (GOLDEN.BIN + JSON sidecar) for eyeballing.

Prints the sidecar's region table, then renders the wTileMap region as a
20x18 glyph grid decoded via pret's constants/charmap.asm — the quick
plausibility check the fidelity plan's Session B exit gate asks for
(nonzero tile IDs, charmap-decodable text). Not the differ; that's
golden_diff.py (Session E).

Usage: inspect_golden.py dos_port/tests/goldens/smoke_title.json
"""

import argparse
import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]

TILEMAP_COLS = 20


def load_charmap(path: Path) -> dict[int, str]:
    """byte -> display glyph from pret's charmap.asm (1-cell strings only;
    control/multi-char entries render as their byte's fallback)."""
    table: dict[int, str] = {}
    pattern = re.compile(r'charmap\s+"(.+?)",\s+\$([0-9a-fA-F]+)')
    for line in path.read_text(encoding="utf-8").splitlines():
        m = pattern.search(line)
        if not m:
            continue
        text, byte = m.group(1), int(m.group(2), 16)
        # first-wins: the primary (Latin) block precedes the Japanese block,
        # which reuses the same byte range (charmap.asm:274 vs :105)
        if len(text) == 1 and byte not in table:
            table[byte] = text
    return table


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("sidecar", type=Path, help="path to <scenario>.json")
    parser.add_argument(
        "--charmap",
        type=Path,
        default=REPO_ROOT / "constants" / "charmap.asm",
        help="pret charmap.asm (default: repo root constants/charmap.asm)",
    )
    args = parser.parse_args()

    sidecar = json.loads(args.sidecar.read_text())
    blob = args.sidecar.with_suffix(".bin").read_bytes()

    print(f"scenario:  {sidecar['scenario']}")
    print(f"rom_title: {sidecar.get('rom_title', '?')}   frame: {sidecar.get('frame', '?')}")
    if sidecar.get("description"):
        print(f"desc:      {sidecar['description']}")
    print(f"binary:    {len(blob)} bytes (sidecar says {sidecar['total_size']})")
    if len(blob) != sidecar["total_size"]:
        print("ERROR: binary size does not match sidecar", file=sys.stderr)
        return 1

    print(f"\n{'region':<12} {'gb_addr':>8} {'size':>6} {'offset':>7}  nonzero")
    regions = {}
    for r in sidecar["regions"]:
        data = blob[r["file_offset"] : r["file_offset"] + r["size"]]
        regions[r["name"]] = data
        nonzero = sum(1 for b in data if b)
        print(f"{r['name']:<12} {r['gb_addr']:>8} {r['size']:>6} {r['file_offset']:>7}  {nonzero}/{len(data)}")

    tilemap = regions.get("wTileMap")
    if tilemap is None:
        print("\n(no wTileMap region — skipping decode)")
        return 0

    charmap = load_charmap(args.charmap)
    print(f"\nwTileMap decode ({args.charmap.name}: {len(charmap)} single-glyph entries; '·' = non-text tile):")
    for row_start in range(0, len(tilemap), TILEMAP_COLS):
        row = tilemap[row_start : row_start + TILEMAP_COLS]
        glyphs = "".join(charmap.get(b, "·") for b in row)
        hexes = " ".join(f"{b:02X}" for b in row)
        print(f"  |{glyphs}|  {hexes}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
