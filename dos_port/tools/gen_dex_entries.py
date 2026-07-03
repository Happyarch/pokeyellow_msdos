#!/usr/bin/env python3
"""gen_dex_entries.py — generate assets/dex_entries.inc.

PokedexEntryPointers + one inlined entry blob per internal index (190 total:
151 real mon + 39 MissingNo, all sharing MissingNoDexEntry — exactly pret's
data/pokemon/dex_entries.asm dw table).

Per-entry byte layout (THE CONTRACT — G2/I2 read fields against this):
    +0                : species/category name, GB-charmap encoded, '@' (0x50)
                        terminated. VARIABLE length.
    after '@'  +0     : feet   (1 byte)      ; height
               +1     : inches (1 byte)
               +2..+3 : weight (2 bytes, little-endian, tenths of a pound)
               +4 ..  : INLINED flavor-text stream (see below), or absent for
                        MissingNo (see DEVIATION).
Flavor stream (pret's `text_far _<Mon>DexEntry` inlined; DEVIATION: text_far ->
inline, so the port's flat TextCommandProcessor can read it in place):
    TX_START(0x00) + charmap text, with <NEXT>(0x4E)/<PAGE>(0x49) separators,
    terminated by <DEXEND>(0x5F) '@' (0x50).  Mirrors data/pokemon/dex_text.asm's
    text/next/page/dex macros byte-for-byte.

DEVIATION (MissingNo): pret's MissingNoDexEntry is `db "???@"`, a single height
byte, `dw 100`, then an untranslatable JP placeholder string (no text_far). It
is glitch data never rendered faithfully (G2 gates HT/WT/flavor on `owned`), so
we emit `"???@"`, `db 10, 0`, `dw 100`, and an empty flavor stream
(TX_START <DEXEND> '@'). Kept for label/index parity only.

Source of truth (read-only): data/pokemon/dex_entries.asm (fixed fields + dw
order) + data/pokemon/dex_text.asm (flavor) + constants/charmap.asm. Tier-1
machine output (CLAUDE.md two-tier rule) — DO NOT EDIT BY HAND. Consumed by
src/engine/menus/pokedex.asm / pokedex_entry.asm (S8 pkg G) and the PetitCup
height/weight gate in link_cups.asm (S8 pkg I2).
"""
import re
import sys
from pathlib import Path

DOS = Path(__file__).resolve().parent.parent          # dos_port/
ROOT = DOS.parent                                      # repo root (pret)
ENTRIES = ROOT / "data" / "pokemon" / "dex_entries.asm"
DEXTEXT = ROOT / "data" / "pokemon" / "dex_text.asm"
CHARMAP = ROOT / "constants" / "charmap.asm"
OUT = DOS / "assets" / "dex_entries.inc"

TX_START = 0x00
CH_TERM = 0x50   # '@'


def load_charmap():
    cm = {}
    for line in CHARMAP.read_text(encoding="utf-8").splitlines():
        m = re.match(r'\s*charmap\s+"((?:[^"\\]|\\.)*)"\s*,\s*(\$[0-9A-Fa-f]+|-?\d+)', line)
        if m:
            key = m.group(1).replace('\\"', '"')
            v = m.group(2)
            cm[key] = int(v[1:], 16) if v.startswith("$") else int(v)
    return cm


def encode(s, cm):
    keys = sorted(cm, key=len, reverse=True)  # longest match first (e.g. "<NEXT>")
    out, i = bytearray(), 0
    while i < len(s):
        for k in keys:
            if s.startswith(k, i):
                out.append(cm[k]); i += len(k); break
        else:
            raise KeyError(f"unmapped char {s[i]!r} in {s!r}")
    return out


def parse_pointer_order():
    """Ordered list of DexEntry labels from PokedexEntryPointers (internal-index order)."""
    labels = []
    in_table = False
    for raw in ENTRIES.read_text(encoding="utf-8").splitlines():
        s = raw.split(";")[0].strip()
        if s.startswith("PokedexEntryPointers"):
            in_table = True
            continue
        if not in_table:
            continue
        if s.startswith("table_width"):
            continue
        m = re.match(r'dw\s+(\w+)$', s)
        if m:
            labels.append(m.group(1))
            continue
        if s == "":
            continue
        break  # first non-dw line ends the table
    return labels


def parse_fixed_fields():
    """label -> (name_str, feet, inches, weight) from each <Mon>DexEntry: block."""
    text = ENTRIES.read_text(encoding="utf-8")
    fields = {}
    cur = None
    st = 0  # 0=name 1=height 2=weight
    for raw in text.splitlines():
        s = raw.split(";")[0].strip()
        m = re.match(r'(\w+DexEntry):$', s)
        if m:
            cur = m.group(1); st = 0
            fields[cur] = {"name": None, "feet": 0, "inches": 0, "weight": 0}
            continue
        if cur is None:
            continue
        if st == 0:
            m = re.match(r'db\s+"((?:[^"\\]|\\.)*)"$', s)
            if m:
                fields[cur]["name"] = m.group(1); st = 1
            continue
        if st == 1:
            m = re.match(r'db\s+(\d+)\s*,\s*(\d+)$', s)
            if m:
                fields[cur]["feet"] = int(m.group(1))
                fields[cur]["inches"] = int(m.group(2)); st = 2; continue
            m = re.match(r'db\s+(\d+)$', s)   # MissingNo: single height byte
            if m:
                fields[cur]["feet"] = int(m.group(1))
                fields[cur]["inches"] = 0; st = 2; continue
            continue
        if st == 2:
            m = re.match(r'dw\s+(\d+)$', s)
            if m:
                fields[cur]["weight"] = int(m.group(1)); cur = None
            continue
    return fields


def parse_flavor(cm):
    """flavor-label (_<Mon>DexEntry) -> encoded byte stream (TX_START..<DEXEND>@)."""
    flavor = {}
    cur = None
    body = None
    for raw in DEXTEXT.read_text(encoding="utf-8").splitlines():
        s = raw.rstrip("\n")
        st = s.split(";")[0].strip()
        m = re.match(r'(_\w+DexEntry)::$', st)
        if m:
            if cur is not None:
                flavor[cur] = bytes(body)
            cur = m.group(1)
            body = bytearray([TX_START])
            continue
        if cur is None:
            continue
        m = re.match(r'(text|next|page)\s+"((?:[^"\\]|\\.)*)"$', st)
        if m:
            macro, txt = m.group(1), m.group(2)
            if macro == "next":
                body += encode("<NEXT>", cm)
            elif macro == "page":
                body += encode("<PAGE>", cm)
            body += encode(txt, cm)
            continue
        if st == "dex":
            body += encode("<DEXEND>", cm)
            body.append(CH_TERM)
            continue
    if cur is not None:
        flavor[cur] = bytes(body)
    return flavor


def entry_bytes(label, fields, flavor, cm):
    f = fields[label]
    out = bytearray()
    out += encode(f["name"], cm)          # includes trailing '@' from source string
    out.append(f["feet"])
    out.append(f["inches"])
    out.append(f["weight"] & 0xFF)
    out.append((f["weight"] >> 8) & 0xFF)
    if label == "MissingNoDexEntry":
        out += bytes([TX_START]) + encode("<DEXEND>", cm) + bytes([CH_TERM])
    else:
        fl = "_" + label
        if fl not in flavor:
            sys.exit(f"gen_dex_entries: no flavor text for {label} ({fl})")
        out += flavor[fl]
    return bytes(out)


def bytes_to_db(data, indent="    "):
    lines = []
    for i in range(0, len(data), 16):
        chunk = ", ".join(f"0x{b:02x}" for b in data[i:i + 16])
        lines.append(f"{indent}db {chunk}")
    return lines


def main():
    cm = load_charmap()
    order = parse_pointer_order()
    fields = parse_fixed_fields()
    flavor = parse_flavor(cm)

    if len(order) != 190:
        sys.exit(f"gen_dex_entries: expected 190 pointers, got {len(order)}")

    # unique entry labels in first-seen order (MissingNo appears many times)
    seen = []
    for lbl in order:
        if lbl not in seen:
            seen.append(lbl)

    out = [
        "; assets/dex_entries.inc — DO NOT EDIT BY HAND (generated by",
        "; tools/gen_dex_entries.py from data/pokemon/dex_entries.asm +",
        "; data/pokemon/dex_text.asm + constants/charmap.asm).",
        ";",
        "; Per-entry layout (contract for pokedex_entry.asm G2 + link_cups.asm I2):",
        ";   +0        name (charmap, '@'=$50 terminated, variable length)",
        ";   after @   feet(1), inches(1), weight(2 LE, tenths lb)",
        ";   +4..      inlined flavor stream: $00 <text/next=$4e/page=$49> $5f $50",
        ";             (DEVIATION: pret text_far -> inline; MissingNo flavor empty)",
        ";   PokedexEntryPointers is `dd` (flat 32-bit .data pointers, not pret's",
        ";   `dw`): read PokedexEntryPointers + index*4 -> flat ptr (PlaceString EAX).",
        f";   {len(order)} pointer entries; {len(seen)} unique blobs.",
        "",
        "PokedexEntryPointers:",
    ]
    # DEVIATION: pret uses `dw` (GB 16-bit); the port is flat 32-bit, so the
    # pointer table is `dd` of flat .data labels (WideTypeNames convention).
    # G2/I2 read a 4-byte flat pointer: PokedexEntryPointers + index*4.
    for i in range(0, len(order), 8):
        chunk = ", ".join(order[i:i + 8])
        out.append(f"    dd {chunk}")
    out.append("")

    for lbl in seen:
        blob = entry_bytes(lbl, fields, flavor, cm)
        out.append(f"{lbl}:")
        out += bytes_to_db(blob)
        out.append("")

    OUT.write_text("\n".join(out), encoding="utf-8")
    print(f"gen_dex_entries: wrote {OUT} "
          f"({len(order)} pointers, {len(seen)} unique blobs)")


if __name__ == "__main__":
    main()
