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

The KBD_NAMING picker charset (link cable plan Stage 5 step 4) is also
emitted here: KbdPickerChars, the Gen-1 naming-grid members (PK/MN/male-
female glyphs, brackets, etc.) that no key in KbdScancodeMap/
KbdScancodeMapShift can type. See build_kbd_naming_picker() below — it is
DERIVED (diffed against the grid's real source, data/text/alphabets.asm via
gen_alphabets.py), never a hand-picked list. Both the table and the `global`
markers letting a different object file (src/engine/menus/naming_screen.o)
link against it are gated behind `%if KBD_NAMING` in the emitted .inc, so the
KBD_NAMING=0 (default) build's src/input/kbd_text.o — which always links,
regardless of this flag — stays byte-for-byte what it was before this step.

Idempotent: fixed scancode->char table, sorted iteration, no timestamps —
running this twice produces byte-identical output.

Run from repo root or dos_port/.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gb_text  # noqa: E402
import gen_alphabets  # noqa: E402 -- reuse its pret-source parse for the picker diff

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


# ALPHABET_ED_CHAR / CHAR_TERMINATOR mirror the same-named constants
# gen_alphabets.py bakes into assets/alphabets.inc and
# src/engine/menus/naming_screen.asm respectively -- excluded here as a
# structural rule (control tiles, not nameable glyphs), not a hand-picked
# character.
ALPHABET_ED_CHAR = 0xF0   # "<ED>" -- a submit gesture (pret's own .pressedA
                           # never reaches .addLetter for it either; Enter
                           # already reaches the same submit path directly)
CHAR_TERMINATOR = 0x50    # '@' -- only appears via the grid's own toggle-
                           # label text ("UPPER CASE@"/"lower case@"), not a
                           # selectable cell
PICKER_TERMINATOR = 0xFF  # sentinel: no digit ('9' = $FF) appears anywhere
                           # in the naming grid, so $FF safely marks the end
                           # of this list without colliding with a real entry


def build_kbd_naming_picker(unshifted, shifted):
    """Return the KBD_NAMING special-character picker charset: every GB
    charmap byte that appears in the naming screen's letter grid
    (UpperCaseAlphabet/LowerCaseAlphabet, parsed the same way
    gen_alphabets.py does -- NOT the generated assets/alphabets.inc, so this
    runs correctly regardless of `make assets` ordering) but is unreachable
    through any key + shift combination in the tables above.

    This is a DIFF, not a hand-picked list -- the exact set (parentheses,
    brackets, semicolon, <PK>/<MN>, '?'/'!', the gender symbols, chi-cross
    '×', '<DOT>', ...) falls out of comparing the two data sources and is
    never enumerated by name here. Sorted for deterministic output.
    """
    cmap = gen_alphabets.load_charmap()
    upper = gen_alphabets.load_alphabet_blob("UpperCaseAlphabet", cmap)
    lower = gen_alphabets.load_alphabet_blob("LowerCaseAlphabet", cmap)
    grid_bytes = set(upper) | set(lower)
    reachable = {b for b in unshifted if b} | {b for b in shifted if b}
    picker = sorted(grid_bytes - reachable - {ALPHABET_ED_CHAR, CHAR_TERMINATOR})
    if PICKER_TERMINATOR in picker:
        raise SystemExit(
            f"picker charset collides with its own $FF terminator: {picker!r}"
        )
    return picker


def db_lines(name: str, data: list, comment: str) -> list:
    out = [f"{name}:  ; {comment}"]
    for i in range(0, len(data), 16):
        chunk = data[i:i + 16]
        out.append("    db " + ", ".join(f"0x{x:02X}" for x in chunk))
    return out


def main() -> int:
    unshifted, shifted = build_kbd_scancode_map()
    picker = build_kbd_naming_picker(unshifted, shifted)

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
        "; Self-default the build flag: the Makefile passes -D KBD_NAMING=$(KBD_NAMING)",
        "; on full builds, but the per-file `nasm -f coff -I include/ -I .` check",
        "; recipe (and any future includer built outside make) does not -- without",
        "; this guard the `%if KBD_NAMING` blocks below fail to assemble standalone.",
        "%ifndef KBD_NAMING",
        "%define KBD_NAMING 0",
        "%endif",
        "",
        f"KBD_SCANCODE_MAP_SIZE equ {TABLE_SIZE}",
        "",
    ]
    out += db_lines("KbdScancodeMap", unshifted, "unshifted layout")
    out.append("")
    out += db_lines("KbdScancodeMapShift", shifted, "shifted layout")
    out.append("")

    # KBD_NAMING (link cable plan Stage 5 step 4): src/engine/menus/
    # naming_screen.o needs to link against the three tables above from a
    # DIFFERENT object file (src/input/kbd_text.o defines them, and always
    # links regardless of this flag). `global` is therefore additive linkage
    # metadata, not new data -- but it must stay gated exactly like the new
    # KbdPickerChars table below it, or kbd_text.o's symbol table (and hence
    # PKMN.EXE, which is unstripped by default -- see dos_port/Makefile) would
    # change even in the KBD_NAMING=0 build.
    out.append("%if KBD_NAMING")
    out.append("global KbdScancodeMap")
    out.append("global KbdScancodeMapShift")
    out.append("%endif")
    out.append("")

    out.append("; KbdPickerChars -- the KBD_NAMING special-character picker: Gen-1")
    out.append("; naming-grid glyphs (data/text/alphabets.asm via gen_alphabets.py)")
    out.append("; that no entry above can type. See build_kbd_naming_picker(). $FF-")
    out.append("; terminated (see PICKER_TERMINATOR in this generator).")
    out.append("%if KBD_NAMING")
    out.append("global KbdPickerChars")
    out += db_lines(
        "KbdPickerChars",
        picker + [PICKER_TERMINATOR],
        f"{len(picker)} entries, $FF-terminated",
    )
    out.append("%endif")
    out.append("")

    ASSETS.mkdir(parents=True, exist_ok=True)
    dst = ASSETS / "kbd_scancode_map.inc"
    dst.write_text("\n".join(out) + "\n")
    covered_un = sum(1 for b in unshifted if b)
    covered_sh = sum(1 for b in shifted if b)
    print(
        f"wrote {dst}: unshifted={covered_un} shifted={covered_sh} mapped entries, "
        f"picker={len(picker)} chars"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
