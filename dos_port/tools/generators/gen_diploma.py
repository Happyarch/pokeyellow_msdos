#!/usr/bin/env python3
"""gen_diploma.py — generate dos_port/assets/diploma_text.inc and diploma_tiles.inc.

Generates Tier-1 data assets for the Hall of Fame diploma:
  - dos_port/assets/diploma_text.inc:
      DiplomaText, DiplomaPlayer, DiplomaCongrats, DiplomaGameFreak strings,
      charmap-encoded via tools/generators/gb_text.py (unicode_converter submodule).
  - dos_port/assets/diploma_tiles.inc:
      DiplomaGraphics (127 tiles from gfx/diploma/diploma.2bpp) with DiplomaGraphicsEnd.

Both are %included by dos_port/src/engine/events/diploma2.asm inside section .data.
Parses pret engine/events/diploma2.asm for the string definitions.

Run from repo root or dos_port/.
"""
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gb_text  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
ASSETS = ROOT / "dos_port" / "assets"
SRC_ASM = ROOT / "engine" / "events" / "diploma2.asm"
SRC_GFX = ROOT / "gfx" / "diploma" / "diploma.2bpp"

OUT_TEXT = ASSETS / "diploma_text.inc"
OUT_TILES = ASSETS / "diploma_tiles.inc"

NEXT_BYTE = 0x4E   # <NEXT> line break
TERM_BYTE = 0x50   # '@' string terminator
TILE_SIZE = 16
EXPECTED_TILES = 127  # 2032 bytes / 16


def parse_diploma_text() -> list[tuple[str, list[int], str]]:
    """Parse DiplomaText, DiplomaPlayer, DiplomaCongrats, DiplomaGameFreak from diploma2.asm."""
    lines = SRC_ASM.read_text(encoding="utf-8").splitlines()

    # Parse DEF constants (e.g. DEF CIRCLE_TILE_ID EQU $10)
    constants = {}
    for line in lines:
        m = re.match(r"^\s*DEF\s+(\w+)\s+EQU\s+\$([0-9a-fA-F]+)", line)
        if m:
            constants[m.group(1)] = int(m.group(2), 16)

    # In-scope string labels in DisplayDiplomaTop
    target_labels = ["DiplomaText", "DiplomaPlayer", "DiplomaCongrats", "DiplomaGameFreak"]
    results = []

    i = 0
    n = len(lines)
    while i < n:
        line = lines[i].strip()
        label_match = re.match(r"^(\w+):", line)
        if label_match and label_match.group(1) in target_labels:
            label = label_match.group(1)
            bytes_out = []
            comment_parts = []
            i += 1
            while i < n:
                cur_line = lines[i].strip()
                if not cur_line or cur_line.startswith(";"):
                    i += 1
                    continue
                # Next label ends the current string definition
                if re.match(r"^\w+:", cur_line):
                    break

                # Handle 'next' macro: <NEXT> byte ($4E) followed by a string
                next_match = re.match(r'^next\s+"([^"]*)"', cur_line)
                if next_match:
                    text = next_match.group(1)
                    bytes_out.append(NEXT_BYTE)
                    bytes_out.extend(gb_text.encode(text))
                    comment_parts.append(f'next "{text}"')
                    i += 1
                    continue

                # Handle 'db' directive
                db_match = re.match(r"^db\s+(.*)$", cur_line)
                if db_match:
                    raw_items = db_match.group(1).split(";", 1)[0].strip()
                    comment_parts.append(f"db {raw_items}")
                    # Tokenize commas outside quotes
                    tokens = []
                    tok = ""
                    in_quote = False
                    for ch in raw_items:
                        if ch == '"':
                            in_quote = not in_quote
                            tok += ch
                        elif ch == ',' and not in_quote:
                            tokens.append(tok.strip())
                            tok = ""
                        else:
                            tok += ch
                    if tok.strip():
                        tokens.append(tok.strip())

                    for token in tokens:
                        if token.startswith('"') and token.endswith('"'):
                            s = token[1:-1]
                            bytes_out.extend(gb_text.encode(s))
                        elif token in constants:
                            bytes_out.append(constants[token])
                        elif token.startswith("$"):
                            bytes_out.append(int(token[1:], 16))
                        elif token.isdigit():
                            bytes_out.append(int(token))
                        else:
                            raise ValueError(f"Unknown token {token!r} in {label} ({cur_line})")
                    i += 1
                    continue

                break

            results.append((label, bytes_out, " / ".join(comment_parts)))
        else:
            i += 1

    if len(results) != len(target_labels):
        found = [r[0] for r in results]
        raise ValueError(f"Expected {target_labels}, found {found} in {SRC_ASM}")

    return results


def db_lines(data: bytes, stride: int = 16) -> list[str]:
    return [
        "    db " + ", ".join(f"0x{b:02X}" for b in data[i:i + stride])
        for i in range(0, len(data), stride)
    ]


def main() -> int:
    # 1. Generate diploma_text.inc
    text_entries = parse_diploma_text()
    out_text_lines = [
        "; diploma_text.inc — generated by tools/generators/gen_diploma.py. DO NOT EDIT BY HAND.",
        "; Diploma text strings, GB-charmap encoded via gb_text.encode (unicode_converter submodule).",
        "; pret ref: engine/events/diploma2.asm: DiplomaText, DiplomaPlayer, DiplomaCongrats, DiplomaGameFreak.",
        "; Each label declares its own `global` HERE, at its definition site. These are",
        "; pret ENGINE labels, so lint_pret_labels' `local_shadow` rule applies to them: a",
        "; pret label defined non-global in a file other than its selected provider is a",
        "; strict-claims violation. Same def-site-global pattern as map_script_tables.inc.",
        "",
    ]
    out_text_lines += [f"global {label}" for label, _b, _c in text_entries]
    out_text_lines.append("")
    for label, byte_list, comment in text_entries:
        hex_str = ", ".join(f"0x{b:02X}" for b in byte_list)
        out_text_lines.append(f"; {comment}")
        out_text_lines.append(f"{label}:")
        out_text_lines.append(f"    db {hex_str}")
        out_text_lines.append("")

    # 2. Generate diploma_tiles.inc
    gfx_data = SRC_GFX.read_bytes()
    if len(gfx_data) != EXPECTED_TILES * TILE_SIZE:
        raise SystemExit(
            f"{SRC_GFX}: expected {EXPECTED_TILES * TILE_SIZE} bytes ({EXPECTED_TILES} tiles), "
            f"got {len(gfx_data)}"
        )

    out_tiles_lines = [
        "; diploma_tiles.inc — generated by tools/generators/gen_diploma.py. DO NOT EDIT BY HAND.",
        f"; DiplomaGraphics: {EXPECTED_TILES} tiles (gfx/diploma/diploma.2bpp) -> vChars2.",
        "; pret ref: engine/events/diploma2.asm:DiplomaGraphics.",
        "; Def-site `global`s: see the note in diploma_text.inc (local_shadow rule).",
        "",
        "global DiplomaGraphics",
        "global DiplomaGraphicsEnd",
        "",
        "DiplomaGraphics:",
        *db_lines(gfx_data, stride=16),
        "DiplomaGraphicsEnd:",
        "",
    ]

    ASSETS.mkdir(parents=True, exist_ok=True)
    OUT_TEXT.write_text("\n".join(out_text_lines) + "\n", encoding="utf-8")
    print(f"wrote {OUT_TEXT} ({len(text_entries)} labels)")

    OUT_TILES.write_text("\n".join(out_tiles_lines) + "\n", encoding="utf-8")
    print(f"wrote {OUT_TILES} ({len(gfx_data)} bytes, {EXPECTED_TILES} tiles)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
