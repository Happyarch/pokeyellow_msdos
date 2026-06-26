#!/usr/bin/env python3
"""gen_items.py — generate dos_port/assets/items.inc from pret source.

Emits two item data tables (no UI; the mart/bag screens that consume them are
deferred):

  ItemNames  — data/items/names.asm `li "NAME"`: each name GB-charmap encoded and
               '@'-terminated ($50), concatenated (variable length, as pret).
  ItemPrices — data/items/prices.asm `bcd3 N`: 3-byte BCD price per item id.

Run from repo root or dos_port/.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "dos_port" / "assets"


def load_charmap(path: Path) -> list:
    cm = []
    for line in path.read_text(encoding="utf-8").splitlines():
        m = re.match(r'\s+charmap\s+"((?:[^"\\]|\\.)*)",\s*\$([0-9a-fA-F]+)', line)
        if m:
            cm.append((m.group(1), int(m.group(2), 16)))
    cm.sort(key=lambda x: -len(x[0]))
    return cm


def encode(s: str, charmap: list) -> bytes:
    out, i = [], 0
    while i < len(s):
        for key, val in charmap:
            if key and s[i:].startswith(key):
                out.append(val)
                i += len(key)
                break
        else:
            raise ValueError(f"Unrecognised char at {i}: {s[i:i+4]!r}")
    return bytes(out)


def bcd3(v: int) -> bytes:
    """3-byte BCD, matching pret's bcd3 macro (dn packs two nibbles)."""
    digits = [(v // 10**e) % 10 for e in (5, 4, 3, 2, 1, 0)]
    return bytes(((digits[0] << 4) | digits[1],
                  (digits[2] << 4) | digits[3],
                  (digits[4] << 4) | digits[5]))


def load_item_ids(path: Path) -> dict:
    """Map every item-constant name -> numeric id from constants/item_constants.asm.

    Each `const NAME`, `add_tm NAME`, `add_hm NAME` line carries a trailing
    `; $XX` comment with the resolved id (the macros compute it via const_value);
    we read that rather than re-implement the const_def/const_next bookkeeping.
    add_tm/add_hm define the item as TM_NAME / HM_NAME respectively.
    """
    ids = {}
    pat = re.compile(r"\s*(const|add_tm|add_hm)\s+(\w+)\s*;\s*\$([0-9A-Fa-f]+)")
    for line in path.read_text().splitlines():
        m = pat.match(line)
        if not m:
            continue
        kind, name, hexval = m.group(1), m.group(2), int(m.group(3), 16)
        if kind == "add_tm":
            name = "TM_" + name
        elif kind == "add_hm":
            name = "HM_" + name
        ids[name] = hexval
    return ids


def load_marts(path: Path, ids: dict) -> list:
    """Parse `script_mart ITEM, ITEM, ...` entries from data/items/marts.asm.

    Returns [(clerk_label, [item_id, ...]), ...] in source order. The mart's
    text-script label (e.g. ViridianMartClerkText) is the line above; the
    TX_SCRIPT_MART dispatch byte is script-engine territory and omitted — we
    keep only the inventory (count, ids, $FF terminator).
    """
    marts, label = [], None
    for line in path.read_text().splitlines():
        m = re.match(r"(\w+)::", line)
        if m:
            label = m.group(1)
            continue
        m = re.match(r"\s*script_mart\s+(.*?)\s*(?:;.*)?$", line)
        if m:
            toks = [t.strip() for t in m.group(1).split(",") if t.strip()]
            marts.append((label, [ids[t] for t in toks]))
    return marts


def main() -> int:
    charmap = load_charmap(ROOT / "constants/charmap.asm")

    names, namebytes = [], bytearray()
    for line in (ROOT / "data/items/names.asm").read_text(encoding="utf-8").splitlines():
        m = re.match(r'\s*li\s+"((?:[^"\\]|\\.)*)"', line)
        if m:
            names.append(m.group(1))
            namebytes += encode(m.group(1), charmap) + b"\x50"

    prices = []
    for line in (ROOT / "data/items/prices.asm").read_text().splitlines():
        s = line.split(";", 1)[0].strip()
        m = re.match(r"bcd3\s+(\d+)$", s)
        if m:
            prices.append(int(m.group(1)))

    # KeyItemFlags bit array (data/items/key_items.asm): one bit per item id,
    # LSB-first (bit i = byte i//8, bit i&7), TRUE = key item (can't be tossed).
    keybits = []
    for line in (ROOT / "data/items/key_items.asm").read_text().splitlines():
        m = re.match(r"\s*dbit\s+(TRUE|FALSE)", line)
        if m:
            keybits.append(1 if m.group(1) == "TRUE" else 0)
    keyflags = bytearray((len(keybits) + 7) // 8)
    for i, b in enumerate(keybits):
        if b:
            keyflags[i // 8] |= 1 << (i & 7)

    item_ids = load_item_ids(ROOT / "constants/item_constants.asm")
    marts = load_marts(ROOT / "data/items/marts.asm", item_ids)

    # TechnicalMachinePrices (data/items/tm_prices.asm): one nybble per TM (price
    # in thousands), packed two-per-byte high-nybble-first as rgbds' nybble_array
    # does — byte = (even << 4) | odd. 50 TMs -> 25 bytes.
    tm_nybbles = []
    for line in (ROOT / "data/items/tm_prices.asm").read_text().splitlines():
        m = re.match(r"\s*nybble\s+(\d+)", line)
        if m:
            tm_nybbles.append(int(m.group(1)))
    tm_pricebytes = bytearray()
    for i in range(0, len(tm_nybbles), 2):
        hi = tm_nybbles[i]
        lo = tm_nybbles[i + 1] if i + 1 < len(tm_nybbles) else 0
        tm_pricebytes.append((hi << 4) | lo)

    pricebytes = bytearray()
    for p in prices:
        pricebytes += bcd3(p)

    out = [
        "; items.inc — generated by tools/gen_items.py. DO NOT EDIT BY HAND.",
        f"; ItemNames: {len(names)} '@'-terminated charmap names (variable length).",
        f"; ItemPrices: {len(prices)} x 3-byte BCD prices, item-id order.",
        "",
        "ItemNames:",
    ]
    o = 0
    for nm in names:
        enc = encode(nm, charmap)
        rec = namebytes[o:o + len(enc) + 1]
        o += len(enc) + 1
        out.append("    db " + ", ".join(f"0x{b:02X}" for b in rec) + f'    ; {nm}')
    out += ["ItemNames_end:", "", "ItemPrices:"]
    for i, p in enumerate(prices):
        rec = pricebytes[i * 3:i * 3 + 3]
        out.append("    db " + ", ".join(f"0x{b:02X}" for b in rec) + f"    ; item {i+1}: {p}")
    out += ["ItemPrices_end:", ""]

    out += [
        f"; KeyItemFlags: {len(keybits)}-bit array (LSB-first), TRUE = key item",
        "; (untossable). Test bit (item_id - 1). HMs ($C4-$C8) are key via a",
        "; separate range check, not this table.",
        "KeyItemFlags:",
        "    db " + ", ".join(f"0x{b:02X}" for b in keyflags),
        "",
    ]

    # Mart inventories (data/items/marts.asm). Each entry: db count, item ids,
    # $FF terminator — mirroring script_mart's body (count, ids, -1) minus the
    # TX_SCRIPT_MART dispatch byte. MartPointers is a flat dd table indexed in
    # source order; clerk label kept as a comment for the future script engine.
    out += [
        f"; MartInventories: {len(marts)} marts, each = db count, item ids, 0xFF.",
        "; MartPointers: dd per mart (source order). NUM_MARTS exposed below.",
        "MartInventories:",
    ]
    martlabels = []
    for label, items in marts:
        sub = f"Mart_{label}"
        martlabels.append(sub)
        body = ", ".join([f"{len(items)}"] + [f"0x{i:02X}" for i in items] + ["0xFF"])
        out.append(f"{sub}:")
        out.append(f"    db {body}    ; {label}")
    out += ["MartInventories_end:", "", "MartPointers:"]
    for sub in martlabels:
        out.append(f"    dd {sub}")
    out += ["MartPointers_end:", "", f"NUM_MARTS equ {len(marts)}", ""]

    out += [
        f"; TechnicalMachinePrices: {len(tm_nybbles)} TM prices (thousands), packed",
        "; two nybbles per byte, high nybble first (GetMachinePrice indexes this).",
        "TechnicalMachinePrices:",
        "    db " + ", ".join(f"0x{b:02X}" for b in tm_pricebytes),
        "",
    ]

    ASSETS.mkdir(parents=True, exist_ok=True)
    dst = ASSETS / "items.inc"
    dst.write_text("\n".join(out))
    print(f"wrote {dst} (ItemNames {len(names)} names / {len(namebytes)} bytes, "
          f"ItemPrices {len(prices)} x 3 = {len(pricebytes)} bytes, "
          f"KeyItemFlags {len(keyflags)} bytes / {len(keybits)} items, "
          f"MartInventories {len(marts)} marts, "
          f"TechnicalMachinePrices {len(tm_pricebytes)} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
