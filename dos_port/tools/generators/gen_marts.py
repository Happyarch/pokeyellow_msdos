#!/usr/bin/env python3
"""gen_marts.py — generate dos_port/assets/marts.inc from pret data/items/marts.asm.

pret's data/items/marts.asm defines 16 `script_mart`-shaped labels: each one is
a TX_SCRIPT_MART (0xFE) text-command stream that the mart clerk's dialog text
runs through, dispatched at runtime by TX_SCRIPT_MART handling in
dos_port/src/home/text_script.asm. The RGBDS macro (macros/scripts/text.asm):

    MACRO script_mart
        db TX_SCRIPT_MART
        db _NARG        ; number of items
        IF _NARG
            db \\#        ; all item ids
        ENDC
        db -1            ; end
    ENDM

is reproduced here exactly: this generator PARSES marts.asm (never transcribes
it by hand) and emits the same byte stream per label, with item ids as their
NAMED constants (POKE_BALL, TM_DOUBLE_TEAM, ...) rather than numeric literals —
the constants already live in dos_port/include/gb_constants.inc or
dos_port/assets/script_constants.inc, both %included by the carrier
(dos_port/src/data/items/marts.asm) ahead of this .inc, so referencing them by
name here costs nothing at assemble time.

Every pret label is preserved verbatim, INCLUDING the two marked
`; unreferenced` by pret itself (UnusedBikeShopClerkText, UnusedMartClerkText)
— "Preserve pret Labels" is unconditional; pret's own disassembly comment
travels with the label into the generated output.

This .inc does NOT open a section and does NOT emit `global` lines — the
carrier (src/data/items/marts.asm) does both, exactly like the
map_script_tables.inc / map_script_tables.asm pattern.

Run from repo root or dos_port/.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SRC = ROOT / "data" / "items" / "marts.asm"
MACRO_FILE = ROOT / "macros" / "scripts" / "text.asm"
OUT = ROOT / "dos_port" / "assets" / "marts.inc"

# Sanity anchor: the number of script_mart-shaped labels marts.asm defines
# today. If this changes, the source moved out from under us — refuse rather
# than silently emit a different table shape.
EXPECTED_LABEL_COUNT = 16

LABEL_RE = re.compile(r"^(\w+)::(\s*;\s*(.*))?$")
SCRIPT_MART_RE = re.compile(r"^\s*script_mart\s+(.*)$")


def check_macro_shape():
    """Confirm the script_mart macro still emits exactly what we assume:
    db TX_SCRIPT_MART / db _NARG / db item ids... / db -1. If the macro
    changes shape, this generator's output would silently stop matching it."""
    text = MACRO_FILE.read_text()
    m = re.search(r"MACRO script_mart\n(.*?)\nENDM", text, re.S)
    if not m:
        sys.exit("gen_marts: could not find 'MACRO script_mart ... ENDM' in "
                  f"{MACRO_FILE}")
    body = m.group(1)
    want_lines = [
        r"db TX_SCRIPT_MART",
        r"db _NARG",
        r"IF _NARG",
        "db \\#",
        r"ENDC",
        r"db -1",
    ]
    for want in want_lines:
        if want not in body:
            sys.exit(f"gen_marts: script_mart macro no longer contains "
                      f"{want!r} — macro shape changed, refusing to guess. "
                      f"Body was:\n{body}")


def parse_marts():
    """Parse data/items/marts.asm into an ordered list of
    (label, unreferenced_comment_or_None, [item_name, ...])."""
    lines = SRC.read_text().splitlines()
    entries = []
    i = 0
    n = len(lines)
    while i < n:
        line = lines[i]
        stripped = line.strip()
        if not stripped or stripped.startswith(";"):
            i += 1
            continue
        lm = LABEL_RE.match(stripped)
        if not lm:
            sys.exit(f"gen_marts: unrecognised line {i + 1} in {SRC}, expected "
                      f"a label or blank/comment line: {line!r}")
        label, _full_comment, comment = lm.group(1), lm.group(2), lm.group(3)
        # Next non-blank line must be the script_mart invocation.
        i += 1
        while i < n and not lines[i].strip():
            i += 1
        if i >= n:
            sys.exit(f"gen_marts: label {label!r} at line {i} has no following "
                      f"script_mart line")
        sm = SCRIPT_MART_RE.match(lines[i])
        if not sm:
            sys.exit(f"gen_marts: expected 'script_mart ...' right after label "
                      f"{label!r}, got: {lines[i]!r}")
        items_raw = sm.group(1).strip()
        # Trim a trailing comment on the script_mart line, if any.
        items_raw = items_raw.split(";", 1)[0].strip()
        items = [x.strip() for x in items_raw.split(",")] if items_raw else []
        if not items:
            sys.exit(f"gen_marts: script_mart for {label!r} has no items — "
                      f"refusing to emit an empty mart")
        for item in items:
            if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", item):
                sys.exit(f"gen_marts: item token {item!r} for {label!r} is not "
                          f"a bare constant name — cannot parse: {items_raw!r}")
        entries.append((label, comment, items))
        i += 1
    return entries


def main():
    check_macro_shape()
    entries = parse_marts()

    if len(entries) != EXPECTED_LABEL_COUNT:
        sys.exit(f"gen_marts: parsed {len(entries)} script_mart label(s) from "
                  f"{SRC}, expected {EXPECTED_LABEL_COUNT} — the source file "
                  f"changed shape; update EXPECTED_LABEL_COUNT only after "
                  f"confirming why")

    out = []
    out.append("; AUTO-GENERATED by tools/generators/gen_marts.py — do not edit.")
    out.append("; Poke Mart inventories: pret data/items/marts.asm, `script_mart`")
    out.append("; macro (macros/scripts/text.asm). Each label is a TX_SCRIPT_MART")
    out.append("; (0xFE) text-command stream: db TX_SCRIPT_MART, db <item count>,")
    out.append("; db <item id>..., db -1 — dispatched by TX_SCRIPT_MART handling")
    out.append("; in src/home/text_script.asm.")
    out.append(";")
    out.append("; The .inc does NOT open a section and does NOT `global` its")
    out.append("; labels — carrier src/data/items/marts.asm does both, exactly")
    out.append("; like the map_script_tables.inc / map_script_tables.asm pattern.")
    out.append("")

    for label, comment, items in entries:
        if comment:
            out.append(f"{label}: ; {comment}")
        else:
            out.append(f"{label}:")
        out.append(f"    db TX_SCRIPT_MART")
        out.append(f"    db {len(items)}")
        for item in items:
            out.append(f"    db {item}")
        out.append(f"    db -1")
        out.append("")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(out).rstrip("\n") + "\n")

    total_items = sum(len(items) for _label, _comment, items in entries)
    unreferenced = sum(1 for _l, c, _i in entries if c)
    print(f"gen_marts: wrote {OUT} ({len(entries)} marts, {total_items} item "
          f"entries total, {unreferenced} pret-marked unreferenced)")


if __name__ == "__main__":
    main()
