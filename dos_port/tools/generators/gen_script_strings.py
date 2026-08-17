#!/usr/bin/env python3
"""gen_script_strings.py — generate dos_port/assets/script_strings.inc.

Every human-rendered string written INLINE in a pret map script, GB-charmap
encoded through the unicode_converter submodule (gb_text.encode). By the
project's two-tier rule these are Tier-1 DATA and belong to a generator; the
sm83xlat transpiler refuses to encode them itself (`inline-text-db`), which is
that rule working rather than a gap in the tool.

Supersedes gen_gym_names.py, which owned only the eight gyms. ONE generator owns
all of them so there is a single writer for tools/sm83xlat/tables/text_assets.json
— two writers would race for that file and drift apart silently.

WHY MACROS RATHER THAN LABELS. Several of these labels are LOCAL
(`FuchsiaGoodRodHouseFishingGuruText.UnusedText`, `CeladonGym_Script.CityName`),
scoped to their script's global label, and a local label cannot be a NASM global
that other files extern. A macro lets the transpiled script keep pret's own label
and pull only the BYTES from here:

    .CityName:
        TEXT_CeladonGym_Script_CityName

so the label structure stays line-for-line with pret and no symbol is defined
twice across the 224 script files. Macros emit nothing until invoked.

THE STRINGS ARE READ OUT OF PRET, never transcribed. A generator that CAN
disagree with the disassembly it mirrors will eventually do so silently, and a
wrong glyph is invisible to every gate the project has.

SPAN. A label may cover SEVERAL source lines — `db "BICYCLE" / next "CANCEL@"`,
or the seven-line `para`/`line`/`done` run of .UnusedText. The macro emits the
whole run as one blob, so the table records how many source items it replaces and
the transpiler skips exactly that many. The transpiler additionally refuses to
skip any item carrying a label, so a span that ever disagreed with the source
fails closed instead of silently dropping bytes.

Run from repo root or dos_port/.
"""
import json
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gb_text  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
ASSETS = ROOT / "dos_port" / "assets"
TABLES = ROOT / "dos_port" / "tools" / "sm83xlat" / "tables"

# Control codes that may lead a text line (constants/charmap.asm, mirrored in
# dos_port/include/gb_text.inc). `db` contributes no prefix of its own.
LEAD = {
    "db": [], "next": [0x4E], "line": [0x4F], "para": [0x51], "cont": [0x55],
    "text": [0x00],
}
#: operand-less control words
BARE = {"done": [0x57], "prompt": [0x58], "page": [0x49], "dex": [0x5F]}

# (pret file, full pret label). Labels containing '.' are LOCAL to the global
# label named before the dot. Discovered by scanning scripts/ for a label whose
# following run contains a quoted text operand; listed explicitly so this file
# stays reviewable and deterministic rather than depending on a scan at run time.
TARGETS = [
    # The eight gyms: city + leader names, read by LoadGymLeaderAndCityName.
    ("scripts/PewterGym.asm",    "PewterGym_Script.CityName"),
    ("scripts/PewterGym.asm",    "PewterGym_Script.LeaderName"),
    ("scripts/CeruleanGym.asm",  "CeruleanGym_Script.CityName"),
    ("scripts/CeruleanGym.asm",  "CeruleanGym_Script.LeaderName"),
    ("scripts/VermilionGym.asm", "VermilionGym_Script.CityName"),
    ("scripts/VermilionGym.asm", "VermilionGym_Script.LeaderName"),
    ("scripts/CeladonGym.asm",   "CeladonGym_Script.CityName"),
    ("scripts/CeladonGym.asm",   "CeladonGym_Script.LeaderName"),
    ("scripts/FuchsiaGym.asm",   "FuchsiaGym_Script.CityName"),
    ("scripts/FuchsiaGym.asm",   "FuchsiaGym_Script.LeaderName"),
    ("scripts/SaffronGym.asm",   "SaffronGym_Script.CityName"),
    ("scripts/SaffronGym.asm",   "SaffronGym_Script.LeaderName"),
    ("scripts/CinnabarGym.asm",  "CinnabarGymSetMapAndTiles.CityName"),
    ("scripts/CinnabarGym.asm",  "CinnabarGymSetMapAndTiles.LeaderName"),
    ("scripts/ViridianGym.asm",  "ViridianGym_Script.CityName"),
    ("scripts/ViridianGym.asm",  "ViridianGym_Script.LeaderName"),
    # Bike shop menu (two-line string) and its price.
    ("scripts/BikeShop.asm",     "BikeShopMenuText"),
    ("scripts/BikeShop.asm",     "BikeShopMenuPrice"),
    # Game Corner HUD labels.
    ("scripts/GameCorner.asm",   "GameCornerMoneyText"),
    ("scripts/GameCorner.asm",   "GameCornerCoinText"),
    ("scripts/GameCorner.asm",   "GameCornerBlankText1"),
    ("scripts/GameCorner.asm",   "GameCornerBlankText2"),
    # Victory Road badge-check names, indexed through BadgeTextPointers.
    ("scripts/Route23.asm",      "CascadeBadgeText"),
    ("scripts/Route23.asm",      "ThunderBadgeText"),
    ("scripts/Route23.asm",      "RainbowBadgeText"),
    ("scripts/Route23.asm",      "SoulBadgeText"),
    ("scripts/Route23.asm",      "MarshBadgeText"),
    ("scripts/Route23.asm",      "VolcanoBadgeText"),
    ("scripts/Route23.asm",      "EarthBadgeText"),
    # pret marks this one unused; it is Japanese, and the charmap encodes it.
    ("scripts/FuchsiaGoodRodHouse.asm",
     "FuchsiaGoodRodHouseFishingGuruText.UnusedText"),
]

_LABEL = re.compile(r"^([.A-Za-z_][\w.]*):")
_OP = re.compile(r'^(\w+)\s*(.*)$')
_QUOTED = re.compile(r'^"(.*)"$')


def macro_name(label: str) -> str:
    return "TEXT_" + label.replace(".", "_")


def read_run(path: Path, label: str):
    """The byte run and item count for `label`, read from the pret source.

    Strict on purpose: an unrecognised operand, an unquoted argument or a missing
    label is a hard error. Emitting approximate bytes for human-visible text is
    exactly the failure nothing downstream would catch.
    """
    want = label.split(".")[-1]
    want = ("." + want) if "." in label else want
    lines = path.read_text(encoding="utf-8").splitlines()
    start = None
    for i, ln in enumerate(lines):
        m = _LABEL.match(ln.strip())
        if m and m.group(1) == want:
            start = i + 1
            break
    if start is None:
        raise SystemExit(f"{path}: no label {want!r}")

    data, items = [], 0
    for ln in lines[start:]:
        s = ln.strip()
        if not s or s.startswith(";"):
            continue
        if _LABEL.match(s):
            break
        m = _OP.match(s)
        if not m:
            break
        op, arg = m.group(1), m.group(2).strip()
        if op in BARE and not arg:
            data += BARE[op]
            items += 1
            continue
        if op not in LEAD:
            break                      # run ends at the first non-text operand
        q = _QUOTED.match(arg)
        if not q:
            raise SystemExit(f"{path}: {want}: expected a quoted operand, got {s!r}")
        data += LEAD[op] + gb_text.encode(q.group(1))
        items += 1
    if not items:
        raise SystemExit(f"{path}: {want}: no text lines follow it")
    return data, items


def main() -> int:
    out = [
        "; script_strings.inc — generated by tools/generators/gen_script_strings.py.",
        "; DO NOT EDIT BY HAND.",
        ";",
        "; Inline human-rendered strings from pret's map scripts, GB-charmap encoded",
        "; via the unicode_converter submodule (gb_text.encode). Emitted as MACROS so",
        "; each transpiled script keeps pret's own label and pulls only the bytes.",
        "; Nothing here emits anything until invoked.",
        "",
        "%ifndef SCRIPT_STRINGS_INC",
        "%define SCRIPT_STRINGS_INC",
        "",
    ]
    mapping = {}
    for rel, label in TARGETS:
        data, items = read_run(ROOT / rel, label)
        name = macro_name(label)
        if label in mapping:
            raise SystemExit(f"duplicate target {label}")
        mapping[label] = {"macro": name, "span": items}
        out.append(f"; pret: {rel}:{label}   ({items} source line(s))")
        out.append(f"%macro {name} 0")
        for k in range(0, len(data), 16):
            out.append("    db " + ", ".join(f"0x{b:02X}" for b in data[k:k + 16]))
        out.append("%endmacro")
        out.append("")
    out.append("%endif ; SCRIPT_STRINGS_INC")

    ASSETS.mkdir(parents=True, exist_ok=True)
    dst = ASSETS / "script_strings.inc"
    dst.write_text("\n".join(out) + "\n")

    TABLES.mkdir(parents=True, exist_ok=True)
    tbl = TABLES / "text_assets.json"
    tbl.write_text(json.dumps({
        "_comment": [
            "pret label -> the NASM macro emitting its bytes, and how many source",
            "items that macro replaces. WRITTEN BY",
            "tools/generators/gen_script_strings.py; do not hand-edit, and do not",
            "add a row whose macro no generator emits — the transpiler trusts this",
            "map and would call a macro that does not exist.",
            "",
            "Consumed by sm83xlat: a quoted text operand under one of these labels",
            "lowers to the macro instead of bailing inline-text-db, and the next",
            "span-1 items are skipped. The transpiler refuses to skip an item that",
            "carries a label, so a stale span fails closed.",
        ],
        "include": "assets/script_strings.inc",
        "labels": mapping,
    }, indent=1) + "\n")

    print(f"wrote {dst} ({len(mapping)} macros) and {tbl}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
