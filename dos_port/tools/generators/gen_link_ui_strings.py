#!/usr/bin/env python3
"""gen_link_ui_strings.py — generate dos_port/assets/link_ui_strings.inc.

Every rendered string the link-cable setup UI needs: the transport-select
menu ("HOW WILL YOU LINK?" / SERIAL / IPX / TCP/IP / CANCEL) and the
per-transport connection-book screens (CONNECT / NEW / EDIT / DELETE /
DIRECT / AUTO / status + prompt strings). docs/current_plan_link_cable.md
Stage 5 step 2; consumed by step 3's src/net/link_ui.asm (not written by
this step — this generator only produces the data it will %include).

None of these strings have a pret counterpart (link setup over a real cable
never showed a book UI — LinkMenu/CableClubNPC are the closest pret analogs
but neither has this vocabulary), so every label is a port-only `LinkUIStr_*`
name (CLAUDE.md "New port-only routines... get descriptive names"; the same
rule extends to port-only DATA labels here). All strings are plain single-
char charmap runs (letters, digits, space, '?', '!', '/' — all present in
assets/gb_charmap.txt), so gb_text.encode (the unicode_converter submodule's
single-char pass) is sufficient; none of them need pret's greedy longest-
match encoder (no apostrophe contractions, no <TOKEN> text commands).

CANCEL appears twice in the plan-doc wording (once on the transport menu,
once on every book screen) — it is the same literal string in both places,
so it gets ONE generated label (LinkUIStr_Cancel) shared by both screens,
rather than two byte-identical copies. Every other entry is one label.

Three entries are LONGER than the step-3 UI's box interior width (13
columns, reused from link_menu.asm's UI_LINK_MENU geometry — see
src/net/link_ui.asm): "HOW WILL YOU LINK?" (19), "NO MODEM/PORT!" (14, the
NetInit-failure error step 3 adds) and "NOT IN THIS BUILD!" (19, the
link_ui_connect_attempt stand-in error step 3 adds). Each is split into two
lines with an embedded <NEXT> ($4E) control tile — the same
list-of-parts-with-NEXT pattern gen_menu_strings.py uses (its own
`encode_parts`) — rather than widening the box: PlaceString does not wrap
automatically, and an unsplit 19-char run drawn into a 13-wide interior would
overwrite the box border. <NEXT> double-spaces by default (PlaceString,
home/text.asm), so each split header prints on rows N and N+2 of the box.

Run from repo root or dos_port/.
"""
import os
import sys
from pathlib import Path

from gen_globals import insert_globals

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gb_text  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
ASSETS = ROOT / "dos_port" / "assets"
TERMINATOR = 0x50  # '@' — PlaceString terminator
NEXT = 0x4E         # "<NEXT>" — line break (double-spaced by default in PlaceString)


def encode_parts(parts):
    """str -> charmap-encoded run; int -> one raw tile byte. (gen_menu_strings.py)"""
    out = []
    for p in parts:
        if isinstance(p, int):
            out.append(p)
        else:
            out.extend(gb_text.encode(p))
    return out


# (NASM label, parts, where it is drawn) — the wording is the ROOT's, verbatim
# from the Stage 5 step 2/3 specs. `parts` is a list of str (charmap-encoded)
# and/or the raw NEXT control byte, joined by encode_parts.
STRINGS = [
    # --- transport-select menu ---
    ("LinkUIStr_HowWillYouLink", ["HOW WILL", NEXT, "YOU LINK?"],
     "transport menu header (2 lines, box interior is 13 cols wide)"),
    ("LinkUIStr_Serial",         ["SERIAL"],  "transport menu entry"),
    ("LinkUIStr_IPX",            ["IPX"],     "transport menu entry"),
    ("LinkUIStr_TCPIP",          ["TCP/IP"],  "transport menu entry"),
    ("LinkUIStr_Cancel",         ["CANCEL"],  "transport menu entry + every book screen"),

    # --- SERIAL sub-menu (COM port pick) ---
    ("LinkUIStr_Com1", ["COM1"], "COM-pick menu entry"),
    ("LinkUIStr_Com2", ["COM2"], "COM-pick menu entry"),
    ("LinkUIStr_Com3", ["COM3"], "COM-pick menu entry"),
    ("LinkUIStr_Com4", ["COM4"], "COM-pick menu entry"),
    ("LinkUIStr_NoPort", ["NO MODEM/", NEXT, "PORT!"],
     "COM-pick menu: NetInit bound no UART on the selected port (2 lines)"),

    # --- connection-book screens ---
    ("LinkUIStr_Connect",       ["CONNECT"],       "book entry action"),
    ("LinkUIStr_New",           ["NEW"],           "book entry action"),
    ("LinkUIStr_Edit",          ["EDIT"],          "book entry action"),
    ("LinkUIStr_Delete",        ["DELETE"],        "book entry action"),
    ("LinkUIStr_Direct",        ["DIRECT"],        "book screen: connect without saving"),
    ("LinkUIStr_Auto",          ["AUTO"],          "book screen: IPX auto-discovery"),
    ("LinkUIStr_Full",          ["FULL!"],         "book screen: all 5 slots occupied, NEW unavailable"),
    ("LinkUIStr_DeleteConfirm", ["DELETE?"],       "book screen: DELETE confirmation prompt"),
    ("LinkUIStr_NamePrompt",    ["NAME?"],         "book screen: NEW entry-name text-entry prompt"),
    ("LinkUIStr_AddressPrompt", ["ADDRESS?"],      "book screen: NEW entry-address text-entry prompt"),
    ("LinkUIStr_BadAddress",    ["BAD ADDRESS!"],  "book screen: address failed validation"),
    ("LinkUIStr_Saved",         ["SAVED!"],        "book screen: NEW/EDIT/DELETE commit confirmation"),
    ("LinkUIStr_Empty",         ["EMPTY"],         "book screen: no entries in this family's book"),
    ("LinkUIStr_NotInBuild",    ["NOT IN THIS", NEXT, "BUILD!"],
     "link_ui_connect_attempt: no IPX/TCP transport exists yet (2 lines)"),
]


def main() -> int:
    lines = [
        "; link_ui_strings.inc — generated by tools/generators/gen_link_ui_strings.py.",
        "; DO NOT EDIT BY HAND.",
        ";",
        "; Link-cable setup UI strings (docs/current_plan_link_cable.md Stage 5): the",
        "; transport-select menu and the per-transport connection-book screens. Every",
        "; label is port-only (LinkUIStr_*) — no pret counterpart draws this UI. GB-",
        "; charmap encoded via the unicode_converter submodule (gb_text.encode) and",
        "; '@'-terminated ($50), the same convention as menu_strings.inc. A few",
        "; entries embed a raw <NEXT> ($4E) control tile between two encoded runs",
        "; (encode_parts, mirroring gen_menu_strings.py) to line-wrap within the",
        "; step-3 UI's 13-column box interior (src/net/link_ui.asm).",
        ";",
        "; section .data so the labels never land in an orphaned section (see link.ld).",
        "",
        "section .data",
        "",
    ]
    for label, parts, where in STRINGS:
        data = encode_parts(parts) + [TERMINATOR]
        hexs = ", ".join(f"0x{b:02X}" for b in data)
        rendered = "".join(p if isinstance(p, str) else "<NEXT>" for p in parts)
        lines.append(f"; {where}")
        lines.append(f'{label}: db {hexs}   ; "{rendered}@"')
        lines.append("")

    insert_globals(lines, [label for label, _, _ in STRINGS])

    ASSETS.mkdir(parents=True, exist_ok=True)
    dst = ASSETS / "link_ui_strings.inc"
    dst.write_text("\n".join(lines))
    print(f"wrote {dst} ({len(STRINGS)} labels)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
