#!/usr/bin/env python3
"""gen_credits_data.py — generate dos_port/assets/credits_data.inc (Tier 1 data).

The credits roll is almost entirely data: a command stream (CreditsOrder), the
species parade (CreditsMons), a pointer table (CreditsTextPointers) and ~90 short
name strings (CreditsText_*). All of it is transcribed out of pret rather than
retyped — the names in particular are rendered text, which the two-tier rule says
must never be hand-encoded as charmap bytes.

Sources, all read-only pret:
  constants/credits_constants.asm   CRED_* ids (two const_def blocks: the string
                                    ids from 0, and the four command bytes from -1
                                    downward, i.e. $FF..$FC)
  data/credits/credits_order.asm    the command stream
  data/credits/credits_mons.asm     one species per CRED_TEXT*_MON, REPT expanded
  data/credits/credits_text.asm     the pointer table's ORDER, then each string as
                                    `db <signed x-offset>, "NAME@"`

The x-offset byte is not decoration: PlaceCreditsText loads it into c, sets b=-1
and does `add hl, bc`, so it is a SIGNED left-shift of the print position that
centres each name. It is emitted verbatim, ahead of the encoded text.

pret's CreditsTextPointers is `dw` (bank-relative); this emits `dd`, the port's
flat 32-bit convention for every pointer table.

DO NOT EDIT the output by hand — re-run this generator.
Run from repo root or dos_port/.
"""
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_battle_text as gbt  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
CONSTS = ROOT / "constants" / "credits_constants.asm"
ORDER = ROOT / "data" / "credits" / "credits_order.asm"
MONS = ROOT / "data" / "credits" / "credits_mons.asm"
TEXT = ROOT / "data" / "credits" / "credits_text.asm"
CREDITS_ASM = ROOT / "engine" / "movie" / "credits.asm"
# Species ids live in both generated script_constants.inc and the hand-written
# gb_constants.inc (DITTO is only in the latter), so both are scanned.
SPECIES = [ROOT / "dos_port" / "assets" / "script_constants.inc",
           ROOT / "dos_port" / "include" / "gb_constants.inc"]
OUT = ROOT / "dos_port" / "assets" / "credits_data.inc"

# pret text macros that emit one control byte then more text (charmap.asm).
CONTROL = {"next": 0x4E, "line": 0x4F, "cont": 0x55, "para": 0x51}


def load_cred_constants() -> dict:
    """Walk the two const_def blocks. `const_def` resets the counter (optionally to
    a start value and step), `const NAME` assigns and advances."""
    out, value, step = {}, 0, 1
    for raw in CONSTS.read_text(encoding="utf-8").splitlines():
        line = raw.split(";")[0].strip()
        if not line:
            continue
        m = re.match(r"const_def(?:\s+(-?\d+)\s*(?:,\s*(-?\d+))?)?$", line)
        if m:
            value = int(m.group(1)) if m.group(1) else 0
            step = int(m.group(2)) if m.group(2) else 1
            continue
        m = re.match(r"const\s+(\w+)$", line)
        if m:
            out[m.group(1)] = value & 0xFF
            value += step
    return out


def load_species() -> dict:
    out = {}
    for path in SPECIES:
        for line in path.read_text(encoding="utf-8").splitlines():
            m = re.match(r"%define\s+(\w+)\s+(0x[0-9A-Fa-f]+|\d+)\s*(?:;.*)?$", line)
            if m:
                out.setdefault(m.group(1), int(m.group(2), 0))
    return out


def parse_db_list(path: Path, label: str, names: dict) -> list:
    """Collect every `db A, B, ...` under `label`, expanding REPT n / ENDR."""
    rows, started, rept = [], False, None
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.split(";")[0].strip()
        if not line:
            continue
        if line.startswith(label + ":"):
            started = True
            continue
        if not started:
            continue
        m = re.match(r"REPT\s+(\d+)$", line)
        if m:
            rept = (int(m.group(1)), [])
            continue
        if line == "ENDR":
            n, body = rept
            rows.extend(body * n)
            rept = None
            continue
        m = re.match(r"db\s+(.*)$", line)
        if not m:
            if re.match(r"^\w+:", line):
                break          # next label ends the list
            continue
        vals = []
        for tok in (t.strip() for t in m.group(1).split(",")):
            if re.fullmatch(r"-?\d+", tok):
                vals.append(int(tok) & 0xFF)
            elif tok in names:
                vals.append(names[tok])
            else:
                raise SystemExit(f"gen_credits_data: unresolved token {tok!r} in {path.name}")
        (rept[1] if rept else rows).extend(vals)
    if not rows:
        raise SystemExit(f"gen_credits_data: {label} came back empty")
    return rows


def parse_text(cm) -> tuple:
    """Return (pointer order, {label: bytes}) from credits_text.asm."""
    order, strings, cur = [], {}, None
    for raw in TEXT.read_text(encoding="utf-8").splitlines():
        line = raw.split(";")[0].strip()
        if not line:
            continue
        m = re.match(r"dw\s+(\w+)$", line)
        if m:
            order.append(m.group(1))
            continue
        m = re.match(r"^(CreditsText_\w+):$", line)
        if m:
            cur = m.group(1)
            strings[cur] = []
            continue
        m = re.match(r'db\s+(-?\d+)\s*,\s*"(.*)"$', line)
        if m and cur:
            strings[cur] = [int(m.group(1)) & 0xFF] + gbt.encode(m.group(2), cm)
            continue
        # CONTINUATION LINES. Several strings are two rows — CreditsText_Version is
        # `db -6, "YELLOW VERSION"` + `next "    STAFF@"`. Dropping the second line
        # does not merely lose text: it takes the '@' with it, so PlaceString runs
        # off the end into whatever data follows. Measured 2026-08-23 — the credits
        # roll printed a name twice, the second time off the right edge.
        m = re.match(r'(next|line|cont|para)\s+"(.*)"$', line)
        if m and cur:
            strings[cur].append(CONTROL[m.group(1)])
            strings[cur].extend(gbt.encode(m.group(2), cm))
    missing = [n for n in order if not strings.get(n)]
    if missing:
        raise SystemExit(f"gen_credits_data: no string body for {missing}")
    # THE CHECK THAT WOULD HAVE CAUGHT THE ABOVE AT GENERATION TIME. Every string
    # PlaceString consumes must end with '@'; an unterminated one is not a shorter
    # string, it is a buffer overrun waiting for a screen to show it.
    unterminated = [n for n in order if strings[n][-1] != 0x50]
    if unterminated:
        raise SystemExit(f"gen_credits_data: unterminated string(s) {unterminated}")
    return order, strings


def parse_the_end_string(cm) -> list:
    """TheEndTextString, from engine/movie/credits.asm itself.

    It is TWO rows of the big "THE END" art in ONE blob: tile ids interleaved with
    spaces, each row '@'-terminated. ShowTheEndGFX PlaceStrings the first row, then
    does `inc de` past that '@' and PlaceStrings the second — so the two must stay
    adjacent, in this order, with both terminators present.

    Mixed tile ids and charmap text, so it is generated rather than hand-written:
    the ids are raw bytes, the spaces go through the charmap like any other glyph.
    """
    rows, started = [], False
    for raw in CREDITS_ASM.read_text(encoding="utf-8").splitlines():
        line = raw.split(";")[0].strip()
        if line.startswith("TheEndTextString:"):
            started = True
            continue
        if not started:
            continue
        m = re.match(r"db\s+(.*)$", line)
        if not m:
            if line:
                break
            continue
        for tok in (t.strip() for t in m.group(1).split(",")):
            if not tok:
                continue
            if tok.startswith("$"):
                rows.append(int(tok[1:], 16))
            elif tok.startswith('"') and tok.endswith('"'):
                rows.extend(gbt.encode(tok[1:-1], cm))
            else:
                raise SystemExit(f"gen_credits_data: odd TheEndTextString token {tok!r}")
    if rows.count(0x50) != 2:
        raise SystemExit("gen_credits_data: TheEndTextString should carry exactly two '@'")
    return rows


def rows_of(data, per=16):
    return ["    db " + ", ".join(f"0x{b:02X}" for b in data[k:k + per])
            for k in range(0, len(data), per)]


def main() -> int:
    cm = gbt.load_charmap()
    creds = load_cred_constants()
    species = load_species()

    order = parse_db_list(ORDER, "CreditsOrder", creds)
    the_end = parse_the_end_string(cm)
    mons = parse_db_list(MONS, "CreditsMons", species)
    ptr_order, strings = parse_text(cm)

    out = [
        "; credits_data.inc — generated by tools/generators/gen_credits_data.py.",
        "; DO NOT EDIT BY HAND.",
        "; pret data/credits/{credits_order,credits_mons,credits_text}.asm +",
        "; constants/credits_constants.asm.",
        f"; {len(order)} command bytes, {len(mons)} parade species, "
        f"{len(ptr_order)} name strings.",
        "",
        "; CRED_* ids, so the roll's command stream and this table cannot disagree.",
    ]
    for name in ("CRED_TEXT_FADE_MON", "CRED_TEXT_MON", "CRED_TEXT_FADE",
                 "CRED_TEXT", "CRED_COPYRIGHT", "CRED_THE_END"):
        if name not in creds:
            sys.stderr.write(f"gen_credits_data: {name} missing from constants\n")
            return 1
        out.append(f"%define {name} 0x{creds[name]:02X}")
    out += [
        "",
        "global CreditsOrder",
        "CreditsOrder:",
        *rows_of(order),
        "",
        "global CreditsMons",
        "CreditsMons:",
        *rows_of(mons),
        "",
        "; pret's CreditsTextPointers is dw (bank-relative); dd here, flat.",
        "global CreditsTextPointers",
        "align 4",
        "CreditsTextPointers:",
    ]
    out += [f"    dd {n}" for n in ptr_order]
    out += [
        "",
        "global TheEndTextString",
        "TheEndTextString:",
        *rows_of(the_end),
        "",
    ]
    for name in ptr_order:
        out.append(f"{name}:")
        out += rows_of(strings[name])
    out.append("")
    OUT.write_text("\n".join(out))
    print(f"wrote {OUT} ({len(order)} order, {len(mons)} mons, {len(ptr_order)} strings)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
