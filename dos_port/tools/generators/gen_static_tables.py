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


def gen_copyright_text() -> None:
    """assets/copyright_text.inc — CopyrightTextString from pret engine/movie/title.asm.

    The port carried these bytes as a hand-typed `db` run under a comment arguing
    it was not two-tier debt, because they are tile INDICES into the Nintendo /
    Creatures / GAME FREAK logo graphic rather than gb_text-encodable glyphs, and
    pret writes them raw too. That reasoning is sound as far as it goes — there is
    no charmap encoding to do here — but it answers the wrong question. The bytes
    are still a deterministic function of a pret source file, and lint_pret_labels
    flagged them [hand_encoded_text]. Deriving them removes the transcription risk
    for the same reason the tileset and card-key tables were generated.

    pret shape (engine/movie/title.asm):
        CopyrightTextString:
            db   $60,...        ; line 1
            next $60,...        ; line 2
            next $60,...        ; line 3
            db   "@"
    `next X` emits the $4E newline control byte and then X; `db "@"` is the $50
    terminator. So the flat stream is line1, $4E, line2, $4E, line3, $50 — which is
    exactly what the port hand-wrote, with each $4E parked at the end of the
    preceding line instead of the start of the next one.
    """
    path = PRET / "engine/movie/title.asm"
    if not path.is_file():
        sys.exit(f"gen_static_tables: missing pret source {path}")

    out, seen = [], False
    for raw in path.read_text(encoding="utf-8").splitlines():
        s = raw.strip()
        if s.startswith("CopyrightTextString:"):
            seen = True
            continue
        if not seen:
            continue
        body = s.split(";")[0].strip()
        if not body:
            continue
        m = re.match(r"^(db|next)\s+(.*)$", body)
        if not m:
            break                                   # next label ends the block
        op, args = m.group(1), m.group(2).strip()
        if op == "next":
            out.append(0x4E)                        # the `next` control byte
        if args == '"@"':
            out.append(0x50)                        # charmap terminator
            continue
        for p in (x.strip() for x in args.split(",")):
            if re.fullmatch(r"\$[0-9a-fA-F]+", p):
                out.append(int(p[1:], 16))
            else:
                sys.exit(f"gen_static_tables: CopyrightTextString: unexpected operand {p!r}")

    if not out or out[-1] != 0x50:
        sys.exit("gen_static_tables: CopyrightTextString did not parse to a $50-terminated stream")

    # Re-split on the $4E control bytes so the emitted rows read like the screen.
    rows, cur = [], []
    for b in out:
        cur.append(b)
        if b in (0x4E, 0x50):
            rows.append(cur); cur = []
    if cur:
        rows.append(cur)

    NOTES = ["©1995-1999  Nintendo", "©1995-1999  Creatures inc.", "©1995-1999  GAME FREAK inc."]
    lines = [
        "; copyright_text.inc — generated by tools/generators/gen_static_tables.py."
        " DO NOT EDIT BY HAND.",
        "; CopyrightTextString — pret engine/movie/title.asm. Tile indices ($60-$7F) into",
        "; the Nintendo/Creatures/GAME FREAK logo graphic + font_extra, NOT charmap glyphs.",
        "; $4E = next (newline), $50 = terminator. Placed at surface coord (2,7) by",
        "; LoadCopyrightTiles via PlaceString.",
        "",
        "global CopyrightTextString",
        "",
        "CopyrightTextString:",
    ]
    for i, row in enumerate(rows):
        note = f"    ; {NOTES[i]}" if i < len(NOTES) else ""
        lines.append("    db " + ", ".join(f"0x{b:02X}" for b in row) + note)
    lines.append("")
    (ASSETS / "copyright_text.inc").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"gen_static_tables: assets/copyright_text.inc — {len(out)} bytes")


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

    gen_copyright_text()


if __name__ == "__main__":
    main()
