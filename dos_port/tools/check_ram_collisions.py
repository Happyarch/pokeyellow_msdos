#!/usr/bin/env python3
"""Detect PORT-INTRODUCED RAM collisions, and only those.

The original game deliberately reuses RAM: pret's `NEXTU` unions put several
names on one address because the contexts are mutually exclusive. That is
faithful and must not be flagged. What must be flagged is the port inventing its
OWN aliasing -- two buffers that pret keeps apart, hand-relocated onto a single
address because somebody asserted the destination was "free" without checking.

The distinction is mechanically decidable and needs no curated size table:

    group port symbols by PORT address
    for each group, look up every name's PRET address (pokeyellow.sym)
        all pret addresses equal  -> pret unions them        -> AUTHORISED
        pret addresses differ     -> we collapsed two buffers -> UNAUTHORISED

Motivation (2026-08-19): `wShadowOAMBackup` (pret $C508) and `wLYOverrides`
(pret $C700) both sat at $F500, and every existing gate was green -- because
`check_ram_addresses.py` ratchets DRIFT (did a baselined address move?) and says
nothing about whether the hand-picked address was sane. Both symbols were in the
baseline, at that address, recorded as deliberate. Seven such collisions existed
tree-wide; five shared one root cause, an address asserted "free" rather than
derived from the symbol table.

There is no allowlist and no baseline by design. A port-introduced collision is
a defect, not a debt tier: fix the address. If a collision is ever genuinely
intended, it needs a union comment at BOTH sites saying so and a maintainer
decision -- not a row in a file that makes the gate quiet.

Usage:  tools/check_ram_collisions.py [--verbose] [--self-test]
Exit:   0 clean, 1 findings, 2 could not run (missing pokeyellow.sym).
"""
import re
import sys
import collections
from pathlib import Path

DOS_PORT = Path(__file__).resolve().parent.parent
PRET = DOS_PORT.parent
SYM = PRET / "pokeyellow.sym"

# Both spellings: gb_memmap.inc declares constants as %define, older entries as equ.
EQU_RE = re.compile(
    r"^\s*(?:%define\s+([A-Za-z_]\w*)\s+|([A-Za-z_]\w*)\s+equ\s+)"
    r"0x([0-9A-Fa-f]+)\s*(?:;.*)?$")

# pokeyellow.sym line: `bank:addr name`
SYM_RE = re.compile(r"^([0-9A-Fa-f]{2}):([0-9A-Fa-f]{4})\s+(\S+)\s*$")

PORT_INCS = ["include/gb_memmap.inc", "assets/pret_ram.inc"]


def port_symbols():
    """name -> port address, for everything the port declares centrally."""
    syms = {}
    for rel in PORT_INCS:
        p = DOS_PORT / rel
        if not p.exists():
            continue
        for line in p.read_text(errors="ignore").splitlines():
            m = EQU_RE.match(line)
            if m:
                name = m.group(1) or m.group(2)
                syms.setdefault(name, int(m.group(3), 16))
    return syms


def pret_symbols():
    """name -> pret address, bank 00 RAM/HRAM only."""
    syms = {}
    for line in SYM.read_text(errors="ignore").splitlines():
        m = SYM_RE.match(line.split(";")[0].strip())
        if not m:
            continue
        bank, addr, name = m.group(1), int(m.group(2), 16), m.group(3)
        if bank == "00" and addr >= 0xC000:
            syms.setdefault(name, addr)
    return syms


def classify(port, pret):
    """-> (unauthorised, authorised_count, unevaluable)."""
    groups = collections.defaultdict(list)
    for name, addr in port.items():
        if 0xC000 <= addr < 0x10000:          # the GB window only
            groups[addr].append(name)

    unauthorised, authorised, unevaluable = [], 0, []
    for addr, names in sorted(groups.items()):
        if len(names) < 2:
            continue
        known = {n: pret[n] for n in names if n in pret}
        if len(known) < 2:
            # A port-only symbol has no pret address, so this test cannot speak
            # to it. Reported, never silently dropped -- extents are what would
            # close this half, and pret extents are derivable from sym ordering.
            unevaluable.append((addr, names))
            continue
        if len(set(known.values())) == 1:
            authorised += 1
        else:
            unauthorised.append((addr, known))
    return unauthorised, authorised, unevaluable


def self_test(port, pret):
    """False-witness test: the detector must FIRE on a synthetic collision and
    must STAY SILENT on a synthetic faithful union. A gate that cannot be shown
    to fail is not evidence."""
    ok = True

    # Probes must land on addresses NO port symbol already occupies, or the
    # injected pair joins an existing group and the result proves nothing. The
    # first draft of this test hardcoded two addresses, and its "fire" case
    # passed for the wrong reason -- derive the slots instead.
    occupied = set(port.values())
    free = [a for a in range(0xC000, 0x10000) if a not in occupied]
    if len(free) < 2:
        print("SELF-TEST FAIL: no unoccupied probe addresses")
        return False
    fire_at, quiet_at = free[0], free[1]

    # Two symbols pret keeps apart, forced onto one port address -> must fire.
    a = min(pret, key=lambda n: pret[n])
    b = max(pret, key=lambda n: pret[n])
    assert pret[a] != pret[b], "self-test needs two distinct pret addresses"
    probe = dict(port)
    probe[a] = probe[b] = fire_at
    found, _, _ = classify(probe, pret)
    if not any(addr == fire_at for addr, _ in found):
        print("SELF-TEST FAIL: detector did not fire on a synthetic collision")
        ok = False

    # Two names pret itself unions, on one port address -> must stay silent.
    by_addr = collections.defaultdict(list)
    for n, v in pret.items():
        by_addr[v].append(n)
    union = next((ns for ns in by_addr.values() if len(ns) >= 2), None)
    if union:
        probe = dict(port)
        probe[union[0]] = probe[union[1]] = quiet_at
        found, _, _ = classify(probe, pret)
        if any(addr == quiet_at for addr, _ in found):
            print("SELF-TEST FAIL: detector fired on a faithful pret union")
            ok = False

    print("self-test: %s" % ("PASS" if ok else "FAIL"))
    return ok


def main():
    if not SYM.exists():
        print(f"check_ram_collisions: {SYM} not found — run `make` at the repo "
              f"root first (rgblink writes it).", file=sys.stderr)
        return 2

    port, pret = port_symbols(), pret_symbols()

    if "--self-test" in sys.argv:
        return 0 if self_test(port, pret) else 1

    unauthorised, authorised, unevaluable = classify(port, pret)

    if "--verbose" in sys.argv:
        print(f"check_ram_collisions: {len(port)} port symbols, "
              f"{authorised} authorised pret unions, "
              f"{len(unevaluable)} unevaluable (port-only names)")

    for addr, known in unauthorised:
        print(f"  COLLISION 0x{addr:04X}  " + ", ".join(
            f"{n} (pret 0x{v:04X})" for n, v in sorted(known.items(),
                                                       key=lambda kv: kv[1])))

    if unauthorised:
        print(f"check_ram_collisions: {len(unauthorised)} PORT-INTRODUCED "
              f"collision(s) — two buffers pret keeps apart share one address.")
        print("  Fix the address; do not add an allowlist. A free address is "
              "DERIVED from pokeyellow.sym, never asserted.")
        return 1

    print(f"check_ram_collisions: clean — 0 port-introduced collisions "
          f"({authorised} faithful pret unions, "
          f"{len(unevaluable)} unevaluable)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
