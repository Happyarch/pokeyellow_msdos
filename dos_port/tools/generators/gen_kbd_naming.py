#!/usr/bin/env python3
"""gen_kbd_naming.py — generate dos_port/assets/kbd_scancode_map.inc.

Tier-1 data for the port-only keyboard text-entry widget (link cable plan,
Stage 5 step 1: src/input/kbd_text.asm). This is NOT a pret asset — there is no
pret source for a US-keyboard scancode table, so this generator has no pret
input files. What makes it a generator rather than a hand-typed table is that
the byte VALUES still must come from tools/generators/gb_text.py's
`encode()` (the GB charmap), not hand-transcribed charmap hex — the "text
strings are DATA, never hand-encode charmap bytes" rule applies to a single
key's glyph exactly as it does to a whole string.

Emits two 128-entry tables (index = IBM PC/AT scancode set 1 MAKE code,
0-127; value = GB charmap byte, or 0 if the key has no mapping in text-entry
mode):

  KbdScancodeMap       — unshifted layout
  KbdScancodeMapShift  — shifted layout

Coverage is deliberately narrow — the Gen-1 typable subset used by link-cable
address/name entry: letters A-Z (shift = uppercase, unshifted = lowercase),
digits 0-9, space, hyphen, period, colon, comma, apostrophe, slash. A key
outside that set (Enter/Backspace/Esc — handled by kbd_text_edit as raw
scancodes, not through this table; or a symbol like '!'/'@'/'('/')' that GB
charmap CAN represent but which isn't in the Gen-1 typable subset) emits 0 in
both tables. US QWERTY set-1 layout only.

The KBD_NAMING picker charset (the naming-screen special-character list:
PK/MN/male-female glyphs/etc.) is a LATER function, not emitted by this
version — see build_kbd_naming_picker() below, a deliberately-unwired stub
documenting where it plugs in so a later step doesn't need to restructure
main().

Idempotent: fixed scancode->char table, sorted iteration, no timestamps —
running this twice produces byte-identical output.

Run from repo root or dos_port/.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gb_text  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
ASSETS = ROOT / "dos_port" / "assets"

TABLE_SIZE = 128  # scancodes 0x00-0x7F (make codes only; break codes set bit 7)

# ---------------------------------------------------------------------------
# US QWERTY set-1 scancode -> (unshifted char, shifted char). `None` means "no
# mapping at this position in text-entry mode" (either the key has nothing
# useful here, or its shifted/unshifted glyph falls outside the Gen-1 typable
# subset this table exists to cover, e.g. '!' on the '1' key). A key entirely
# absent from this dict (Enter 0x1C, Backspace 0x0E, Esc 0x01, the arrow keys,
# ...) is left at 0 in both tables — kbd_text_edit checks those scancodes
# directly before ever consulting this table.
# ---------------------------------------------------------------------------
LAYOUT = {
    # number row: digit unshifted; shifted symbols (!@#$%^&*()) are not in the
    # covered subset
    0x02: ("1", None), 0x03: ("2", None), 0x04: ("3", None), 0x05: ("4", None),
    0x06: ("5", None), 0x07: ("6", None), 0x08: ("7", None), 0x09: ("8", None),
    0x0A: ("9", None), 0x0B: ("0", None),
    0x0C: ("-", None),   # hyphen key; shifted '_' not covered

    # QWERTY row
    0x10: ("q", "Q"), 0x11: ("w", "W"), 0x12: ("e", "E"), 0x13: ("r", "R"),
    0x14: ("t", "T"), 0x15: ("y", "Y"), 0x16: ("u", "U"), 0x17: ("i", "I"),
    0x18: ("o", "O"), 0x19: ("p", "P"),

    # ASDF row
    0x1E: ("a", "A"), 0x1F: ("s", "S"), 0x20: ("d", "D"), 0x21: ("f", "F"),
    0x22: ("g", "G"), 0x23: ("h", "H"), 0x24: ("j", "J"), 0x25: ("k", "K"),
    0x26: ("l", "L"),
    0x27: (None, ":"),    # ';' key: unshifted ';' not covered, shifted ':' is
    0x28: ("'", None),    # apostrophe key: shifted '"' not covered

    # ZXCV row
    0x2C: ("z", "Z"), 0x2D: ("x", "X"), 0x2E: ("c", "C"), 0x2F: ("v", "V"),
    0x30: ("b", "B"), 0x31: ("n", "N"), 0x32: ("m", "M"),
    0x33: (",", None),    # comma key: shifted '<' not covered
    0x34: (".", None),    # period key: shifted '>' not covered
    0x35: ("/", None),    # slash key: shifted '?' not covered (see file header)

    0x39: (" ", " "),     # spacebar: no distinct shifted glyph
}


def _char_to_byte(ch):
    """Single Unicode char -> GB charmap byte via gb_text.encode(), or 0 if
    ch is None (no mapping at this scancode/shift position)."""
    if ch is None:
        return 0
    encoded = gb_text.encode(ch)
    if len(encoded) != 1:
        raise SystemExit(f"expected a single-byte encode for {ch!r}, got {encoded!r}")
    return encoded[0]


def build_kbd_scancode_map():
    """Return (unshifted[128], shifted[128]) byte arrays."""
    unshifted = [0] * TABLE_SIZE
    shifted = [0] * TABLE_SIZE
    for sc in sorted(LAYOUT):  # sorted iteration -> deterministic, no timestamp
        un_ch, sh_ch = LAYOUT[sc]
        unshifted[sc] = _char_to_byte(un_ch)
        shifted[sc] = _char_to_byte(sh_ch)
    return unshifted, shifted


def build_kbd_naming_picker():
    """PLACEHOLDER for a later step: the KBD_NAMING special-character picker
    (PK/MN/male-female/etc. glyphs the naming screen's grid offers that a US
    keyboard can't type). Not implemented this step — see the module
    docstring. Kept as its own function (rather than inlined into main()) so
    adding it later is additive: call it from main() and extend the emitted
    .inc, without restructuring the scancode-map generation above it."""
    raise NotImplementedError("KBD_NAMING picker charset is not this step")


def db_lines(name: str, data: list, comment: str) -> list:
    out = [f"{name}:  ; {comment}"]
    for i in range(0, len(data), 16):
        chunk = data[i:i + 16]
        out.append("    db " + ", ".join(f"0x{x:02X}" for x in chunk))
    return out


def main() -> int:
    unshifted, shifted = build_kbd_scancode_map()

    out = [
        "; kbd_scancode_map.inc — generated by tools/generators/gen_kbd_naming.py.",
        "; DO NOT EDIT BY HAND.",
        ";",
        "; Port-only US-keyboard scancode -> GB charmap byte tables for the",
        "; keyboard text-entry widget (src/input/kbd_text.asm). No pret",
        "; counterpart exists for this data (see this generator's docstring).",
        ";",
        "; Index = IBM PC/AT scancode set 1 MAKE code (0-127). Value = GB",
        "; charmap byte, or 0 = untypable in text-entry mode (either the key has",
        "; no glyph here, or its glyph falls outside the covered Gen-1 typable",
        "; subset: A-Z/a-z, 0-9, space, hyphen, period, colon, comma, apostrophe,",
        "; slash). Control keys (Enter/Backspace/Esc/arrows) are NOT looked up",
        "; through this table -- kbd_text_edit checks those scancodes directly.",
        "",
        f"KBD_SCANCODE_MAP_SIZE equ {TABLE_SIZE}",
        "",
    ]
    out += db_lines("KbdScancodeMap", unshifted, "unshifted layout")
    out.append("")
    out += db_lines("KbdScancodeMapShift", shifted, "shifted layout")
    out.append("")

    ASSETS.mkdir(parents=True, exist_ok=True)
    dst = ASSETS / "kbd_scancode_map.inc"
    dst.write_text("\n".join(out) + "\n")
    covered_un = sum(1 for b in unshifted if b)
    covered_sh = sum(1 for b in shifted if b)
    print(f"wrote {dst}: unshifted={covered_un} shifted={covered_sh} mapped entries")
    return 0


if __name__ == "__main__":
    sys.exit(main())
