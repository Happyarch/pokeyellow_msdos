#!/usr/bin/env python3
"""gen_static_tables.py — generate the small pret static tables that were
hand-transcribed into port CODE files.

Emits two assets from the read-only pret tree:

  assets/tileset_tables.inc   TilePairCollisionsLand / TilePairCollisionsWater
                              (data/tilesets/pair_collision_tile_ids.asm)
                              LedgeTiles
                              (data/tilesets/ledge_tiles.asm)
                              BikeRidingTilesets
                              (data/tilesets/bike_riding_tilesets.asm)

  assets/card_key_coords.inc  CardKeyTable1 / CardKeyTable2 / CardKeyTable3
                              (data/events/card_key_coords.asm)

WHY THIS EXISTS. All seven tables lived as hand-typed `db` rows inside port code
files (src/engine/overworld/ledges.asm, src/home/player_gfx.asm,
src/engine/items/item_effects.asm) and were reported by lint_pret_labels as
[aux_misplaced]: a pret data/ label must live in the data layer. Relocating them
would have cleared the finding, but the real defect was that they were
TRANSCRIBED BY HAND — pret's `$2C` had been retyped as `0x2C`, `db -1` as
`db 0xFF`, and nothing regenerated them if pret changed. A typo would have been
silent. Generating them makes the port's copy a deterministic function of the
pret source, which is what the two-tier rule asks for.

FAITHFULNESS. The transform is deliberately narrow: keep pret's row order, keep
its symbolic constant names (CAVERN, FOREST, SPRITE_FACING_DOWN, PAD_DOWN,
SILPH_CO_2F ...) so the tables stay enum-synced rather than frozen to today's
numbering, and rewrite only the literal syntax RGBDS `$XX` -> NASM `0xXX` and the
`-1` terminator -> `0xFF` (identical byte; NASM would accept -1 too, spelled out
because every other port table spells its terminator).

Run from repo root or dos_port/.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
PRET = ROOT
ASSETS = ROOT / "dos_port" / "assets"

# (pret source, [labels to extract], output asset, blurb)
JOBS = [
    (
        "assets/tileset_tables.inc",
        "Tileset static tables (pret data/tilesets/*.asm).",
        [
            ("data/tilesets/pair_collision_tile_ids.asm",
             ["TilePairCollisionsLand", "TilePairCollisionsWater"],
             "FORMAT: tileset id, tile 1, tile 2. $FF-terminated. The player may\n"
             "; not cross between tile 1 and tile 2 (simulates elevation)."),
            ("data/tilesets/ledge_tiles.asm",
             ["LedgeTiles"],
             "FORMAT: player facing, tile stood on, ledge tile, input required.\n"
             "; $FF-terminated."),
            ("data/tilesets/bike_riding_tilesets.asm",
             ["BikeRidingTilesets"],
             "Tilesets the bike may be ridden on. $FF-terminated."),
        ],
    ),
    (
        "assets/card_key_coords.inc",
        "Silph Co. card-key door coordinates (pret data/events/card_key_coords.asm).\n"
        "; pret's own comment: these are probably door locations, but they are UNUSED,\n"
        "; and the reason there are three tables is unknown. Ported for completeness.",
        [
            ("data/events/card_key_coords.asm",
             ["CardKeyTable1", "CardKeyTable2", "CardKeyTable3"],
             "Format: map id, Y, X, gate id."),
        ],
    ),
]

LABEL_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)::?\s*$")


def extract(path: Path, want: list) -> dict:
    """Pull each requested label's `db` rows out of a pret data file."""
    out, cur = {}, None
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.rstrip()
        stripped = line.strip()
        m = LABEL_RE.match(stripped)
        if m:
            cur = m.group(1) if m.group(1) in want else None
            if cur:
                out[cur] = []
            continue
        if cur is None or not stripped or stripped.startswith(";"):
            continue
        if not stripped.startswith("db "):
            # A non-db line ends the table (next label, macro, whatever).
            cur = None
            continue
        out[cur].append(stripped)
    missing = [w for w in want if w not in out]
    if missing:
        sys.exit(f"gen_static_tables: {path}: labels not found: {missing}")
    for label, rows in out.items():
        if not rows:
            sys.exit(f"gen_static_tables: {path}: {label} extracted zero rows")
    return out


def convert(row: str) -> str:
    """RGBDS db row -> NASM db row. Literal syntax only; names untouched."""
    body = row[3:].split(";")[0].strip()          # drop 'db ' and any trailing comment
    parts = [p.strip() for p in body.split(",")]
    conv = []
    for p in parts:
        if re.fullmatch(r"\$[0-9a-fA-F]+", p):
            conv.append("0x" + p[1:].upper())
        elif p == "-1":
            conv.append("0xFF")
        else:
            conv.append(p)                        # symbolic constant or plain decimal
    return "    db " + ", ".join(conv)


def main() -> None:
    ASSETS.mkdir(parents=True, exist_ok=True)
    for asset, blurb, sources in JOBS:
        lines = [
            f"; {Path(asset).name} — generated by tools/generators/gen_static_tables.py."
            " DO NOT EDIT BY HAND.",
            f"; {blurb}",
            "",
        ]
        total = 0
        for src, want, note in sources:
            path = PRET / src
            if not path.is_file():
                sys.exit(f"gen_static_tables: missing pret source {path}")
            tables = extract(path, want)
            for label in want:                     # emit in the requested order
                rows = tables[label]
                lines.append(f"; {src}")
                lines.append(f"; {note}")
                lines.append(f"{label}:")
                lines.extend(convert(r) for r in rows)
                lines.append("")
                total += len(rows)
        (ASSETS / Path(asset).name).write_text("\n".join(lines) + "\n", encoding="utf-8")
        print(f"gen_static_tables: {asset} — {total} rows")


if __name__ == "__main__":
    main()
