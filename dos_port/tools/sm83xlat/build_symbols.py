#!/usr/bin/env python3
"""build_symbols.py — map the port's gb_memmap.inc names to pret's RAM label names.

Produces `tables/symbols.json`, the shared symbol mapping consumed by TWO
workstreams:

  * docs/current_plan_memmap_pret_names.md  — renames the port's SCREAMING_SNAKE
    equs to their pret counterparts. Reads port name -> pret name.
  * docs/current_plan_script_transpiler.md  — lowers pret script source to x86.
    Reads pret name -> port name.

Same table, read in both directions.


METHOD: normalized NAME match, with the ADDRESS as an independent cross-check
----------------------------------------------------------------------------
Three sources were measured before settling on this (2026-08-16):

  * trailing comments in gb_memmap.inc -- DEAD. Only 312 of 1426 equ lines carry
    a pret label in a comment (21.9%), and the oldest block (lines 80-86, holding
    W_CUR_MAP / W_Y_COORD / W_X_COORD) has none at all.

  * address join against the port's own pret-style equs -- WEAK, and unsafe on
    its own. It matched 67 of 619 and produced wrong pairs: MAX_WINDOWS (= 6, a
    window count) matched a pret *_SIZE constant that also equals 6, and every
    HRAM scratch address matched 3-4 names at once because pret's hram.asm is
    built from UNION / NEXTU blocks (45 in hram.asm, 130 in wram.asm) where
    several names share one address BY DESIGN.

  * normalized name match against pret's ram/*.asm labels -- STRONG. 209 unique
    matches, 5 ambiguous. It also needs no address arithmetic at all, which
    sidesteps the real blocker: pret's 11 WRAM SECTION directives carry no
    explicit addresses, so deriving them from source means reproducing rgbasm's
    section allocator.

So: match on the normalized name, then use the address -- where both sides
happen to have one -- purely to CONFIRM or CONTRADICT. A name match whose
addresses disagree is reported as `addr_conflict` and is the most interesting
output this tool produces: it means the port symbol and the pret symbol it looks
like are not the same storage.


RENAME INVARIANCE
-----------------
Matching keys on the normalized name, so it yields the same pairing before or
after the rename workstream lands. Afterwards there are simply no
SCREAMING_SNAKE candidates left and `confirmed`/`name_only` go empty -- that is
the completion signal, and what tests/test_rename_invariance.py asserts.

Usage:
    python3 dos_port/tools/sm83xlat/build_symbols.py            # write tables/symbols.json
    python3 dos_port/tools/sm83xlat/build_symbols.py --report   # human summary, no write
"""
import argparse
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
MEMMAP = ROOT / "dos_port" / "include" / "gb_memmap.inc"
RAM_FILES = ("ram/wram.asm", "ram/hram.asm", "ram/sram.asm", "ram/vram.asm")
OUT = Path(__file__).resolve().parent / "tables" / "symbols.json"

EQU_RE = re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s+equ\s+(.+?)\s*(?:;\s*(.*))?$")
PRET_LABEL_RE = re.compile(r"^([a-z][A-Za-z0-9_]*)::", re.M)

# GB regions a symbol may legitimately name. Used only for the cross-check and
# for labelling; a value outside every range is a count/size/bit/offset.
ADDRESS_REGIONS = (
    (0x8000, 0x9FFF, "vram"), (0xA000, 0xBFFF, "sram"), (0xC000, 0xDFFF, "wram"),
    (0xFE00, 0xFE9F, "oam"),  (0xFF00, 0xFF7F, "io"),   (0xFF80, 0xFFFE, "hram"),
)


def region_of(addr):
    for lo, hi, name in ADDRESS_REGIONS:
        if lo <= addr <= hi:
            return name
    return None


def normalize(name):
    """Fold a port or pret RAM name to a comparable key.

    W_NPC_PLAYER_Y_DISTANCE -> npcplayerydistance
    hNPCPlayerYDistance     -> npcplayerydistance
    """
    n = re.sub(r"^[WHSV]_", "", name)          # port prefix: W_ / H_ / S_ / V_
    n = re.sub(r"^[whsv](?=[A-Z])", "", n)     # pret prefix: w / h / s / v
    return n.lower().replace("_", "")


def is_pret_style(name):
    return re.match(r"^[whsv][A-Z]", name) is not None


def is_screaming_snake(name):
    return re.match(r"^[A-Z][A-Z0-9_]*$", name) is not None


def parse_memmap(path):
    rows = []
    for lineno, line in enumerate(path.read_text().splitlines(), 1):
        m = EQU_RE.match(line)
        if m:
            rows.append((m.group(1), m.group(2).strip(), (m.group(3) or "").strip(), lineno))
    return rows


def parse_pret_labels(root):
    """pret RAM label names. Names only -- no address arithmetic (see METHOD)."""
    names = {}
    for rel in RAM_FILES:
        p = root / rel
        if not p.exists():
            continue
        for m in PRET_LABEL_RE.finditer(p.read_text()):
            names.setdefault(m.group(1), rel)
    return names


def resolve_values(rows):
    """Resolve equs to ints where possible: literals, then one alias pass."""
    lit = {}
    for name, val, _c, _l in rows:
        v = val.strip()
        if re.fullmatch(r"0x[0-9A-Fa-f]+", v):
            lit[name] = int(v, 16)
        elif re.fullmatch(r"\$[0-9A-Fa-f]+", v):
            lit[name] = int(v[1:], 16)
        elif re.fullmatch(r"\d+", v):
            lit[name] = int(v)
    for name, val, _c, _l in rows:
        v = val.strip()
        if name not in lit and re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", v) and v in lit:
            lit[name] = lit[v]
    return lit


def build(rows, pret_labels):
    values = resolve_values(rows)

    # pret name -> address, for the cross-check. Sourced from the port's OWN
    # pret-style equs, which are the only place both a pret name and an address
    # sit together in-tree.
    pret_addr = {}
    for name, _v, _c, _l in rows:
        if is_pret_style(name):
            a = values.get(name)
            if a is not None and region_of(a) is not None:
                pret_addr.setdefault(name, a)

    by_norm = defaultdict(list)
    for pname in pret_labels:
        by_norm[normalize(pname)].append(pname)

    confirmed, name_only, addr_conflict, ambiguous, unmatched = {}, {}, {}, {}, {}
    seen = set()
    for name, val, comment, lineno in rows:
        if not is_screaming_snake(name) or name in seen:
            continue
        seen.add(name)
        a = values.get(name)
        entry = {"line": lineno, "value": val, "comment": comment}
        if a is not None:
            entry["addr"] = f"0x{a:04X}"
            entry["region"] = region_of(a)

        cands = by_norm.get(normalize(name), [])
        # The normalizer drops the storage-class prefix, so hSpriteIndex and
        # wSpriteIndex collide. The port keeps that prefix (H_ / W_ / S_ / V_),
        # so it disambiguates: prefer the pret name in the same storage class.
        if len(cands) > 1:
            pfx = name[0].lower() if re.match(r"^[WHSV]_", name) else None
            if pfx:
                same = [c for c in cands if c[0] == pfx]
                if len(same) == 1:
                    cands = same
                    entry["disambiguated_by"] = "storage-class prefix"

        if not cands:
            unmatched[name] = entry
        elif len(cands) > 1:
            ambiguous[name] = dict(entry, candidates=sorted(cands))
        else:
            pret = cands[0]
            e = dict(entry, pret=pret, pret_file=pret_labels[pret])
            pa = pret_addr.get(pret)
            if a is not None and pa is not None:
                if a == pa:
                    confirmed[name] = e
                else:
                    addr_conflict[name] = dict(e, pret_addr=f"0x{pa:04X}")
            else:
                name_only[name] = e

    counts = defaultdict(list)
    for name, _v, _c, lineno in rows:
        counts[name].append(lineno)
    duplicates = {n: ls for n, ls in counts.items() if len(ls) > 1}

    return {
        "_comment": "GENERATED by dos_port/tools/sm83xlat/build_symbols.py. "
                    "Matched on NORMALIZED NAME against pret ram/*.asm labels, with "
                    "the address as an independent cross-check. Review `ambiguous` "
                    "and `addr_conflict` by hand before renaming anything.",
        "sources": {"port": "dos_port/include/gb_memmap.inc", "pret": list(RAM_FILES)},
        "counts": {
            "equ_lines": len(rows),
            "pret_ram_labels": len(pret_labels),
            "screaming_snake": len(seen),
            "confirmed": len(confirmed),
            "name_only": len(name_only),
            "addr_conflict": len(addr_conflict),
            "ambiguous": len(ambiguous),
            "unmatched": len(unmatched),
            "duplicate_names": len(duplicates),
        },
        "confirmed": dict(sorted(confirmed.items())),
        "name_only": dict(sorted(name_only.items())),
        "addr_conflict": dict(sorted(addr_conflict.items())),
        "ambiguous": dict(sorted(ambiguous.items())),
        "unmatched": dict(sorted(unmatched.items())),
        "duplicates": dict(sorted(duplicates.items())),
    }


def report(d):
    c = d["counts"]
    print(f"port gb_memmap.inc : {c['equ_lines']} equ lines, "
          f"{c['screaming_snake']} SCREAMING_SNAKE")
    print(f"pret ram/*.asm     : {c['pret_ram_labels']} RAM labels")
    print()
    print(f"  confirmed      {c['confirmed']:4d}  name matches AND address agrees")
    print(f"  name_only      {c['name_only']:4d}  name matches, no address on both sides to check")
    print(f"  addr_conflict  {c['addr_conflict']:4d}  name matches but ADDRESSES DIFFER -- review each")
    print(f"  ambiguous      {c['ambiguous']:4d}  several pret names normalize the same")
    print(f"  unmatched      {c['unmatched']:4d}  no pret RAM label (constants, port-only HAL)")
    print(f"  duplicate names in memmap: {c['duplicate_names']}")
    total = c["confirmed"] + c["name_only"]
    print(f"\n  => {total} rename candidates ready, "
          f"{c['addr_conflict'] + c['ambiguous']} needing review")
    if d["addr_conflict"]:
        print("\nADDR_CONFLICT (name looks equal, storage is not -- read each):")
        for n, v in list(d["addr_conflict"].items())[:15]:
            print(f"  {n:34s} port {v.get('addr','?')} vs pret {v['pret_addr']}  ({v['pret']})")
        if len(d["addr_conflict"]) > 15:
            print(f"  ... {len(d['addr_conflict']) - 15} more")
    if d["ambiguous"]:
        print("\nAMBIGUOUS:")
        for n, v in list(d["ambiguous"].items())[:10]:
            print(f"  {n:34s} -> {v['candidates']}")
    if d["duplicates"]:
        print("\nDUPLICATE DEFINITIONS (fold during the rename):")
        for n, ls in d["duplicates"].items():
            print(f"  {n:34s} lines {ls}")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--report", action="store_true", help="print a summary, write nothing")
    ap.add_argument("--memmap", type=Path, default=MEMMAP,
                    help="override the memmap path (used by the invariance test)")
    ap.add_argument("--out", type=Path, default=OUT)
    args = ap.parse_args()

    if not args.memmap.exists():
        sys.exit(f"build_symbols: no such file: {args.memmap}")
    pret_labels = parse_pret_labels(ROOT)
    if not pret_labels:
        sys.exit(f"build_symbols: no pret RAM labels found under {ROOT}/ram/")
    data = build(parse_memmap(args.memmap), pret_labels)

    if args.report:
        report(data)
        return 0
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(data, indent=2, sort_keys=False) + "\n")
    c = data["counts"]
    print(f"wrote {args.out.relative_to(ROOT)}: {c['confirmed']} confirmed, "
          f"{c['name_only']} name-only, {c['addr_conflict']} conflicts, "
          f"{c['ambiguous']} ambiguous, {c['unmatched']} unmatched")
    return 0


if __name__ == "__main__":
    sys.exit(main())
