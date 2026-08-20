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



# ---------------------------------------------------------------------------
# GAP SEALED 2026-08-19: the pret-address comparison above cannot speak to a
# PORT-ONLY symbol, because it has no pret address to compare. That left 17
# shared-address groups unevaluable and, worse, said nothing at all about a
# port-only buffer parked in the MIDDLE of a pret one -- which is squatting just
# as surely as a shared start address, and is how W_CHECK_FOR_TURN and
# NPC_DIALOG_BUF came to sit inside pret's printer buffers.
#
# Extents come free from pokeyellow.sym ordering (next distinct address minus
# this one), so this needs no curated size table either.
#
# An EXACT address match is an alias and is handled by the group check above; only
# landing STRICTLY INSIDE another buffer is reported here.
GB_WRAM_END = 0xE000        # cap extents here: pret's last WRAM symbol (wStack)
                            # otherwise runs to the first HRAM symbol and swallows
                            # every legitimate port-only region above the expansion.


def pret_extents(pret):
    addrs = sorted({a for a in pret.values() if a < GB_WRAM_END})
    out = {}
    for i, a in enumerate(addrs):
        nxt = addrs[i + 1] if i + 1 < len(addrs) else GB_WRAM_END
        out[a] = nxt - a
    return out


def strays(port, pret, shift):
    """port-only symbols landing strictly inside a pret buffer's port extent."""
    ext = pret_extents(pret)
    spans = sorted((shift(a), shift(a) + n, a) for a, n in ext.items() if n > 0)
    owners = {}
    for n, a in pret.items():
        owners.setdefault(a, []).append(n)
    out = []
    for name, val in sorted(port.items(), key=lambda kv: kv[1]):
        if name in pret or not (0xC000 <= val < 0xFE00):
            continue
        if name.startswith("GB_"):      # region markers, not storage
            continue
        for lo, hi, pa in spans:
            if lo < val < hi:
                out.append((name, val, pa, lo, hi, owners.get(pa, [])))
                break
    return out


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

    import json as _json
    _g = _json.loads((DOS_PORT / "tools" / "wram_growth.json").read_text())["growths"]
    _R = [(int(e["pret"], 16), e["pret_size"], e["port_size"] - e["pret_size"])
          for e in _g]

    def _shift(a):
        return a if a >= 0xFE00 else a + sum(g for q, sz, g in _R if q + sz <= a)

    stray = strays(port, pret, _shift)
    for name, val, pa, lo, hi, own in stray:
        print(f"  STRAY 0x{val:04X}  {name} sits INSIDE "
              f"{', '.join(own[:2])} (pret 0x{pa:04X} -> port "
              f"0x{lo:04X}-0x{hi - 1:04X})")

    if "--verbose" in sys.argv:
        print(f"check_ram_collisions: {len(port)} port symbols, "
              f"{authorised} authorised pret unions, "
              f"{len(unevaluable)} unevaluable (port-only names)")

    for addr, known in unauthorised:
        print(f"  COLLISION 0x{addr:04X}  " + ", ".join(
            f"{n} (pret 0x{v:04X})" for n, v in sorted(known.items(),
                                                       key=lambda kv: kv[1])))

    if unauthorised or stray:
        print(f"check_ram_collisions: {len(unauthorised)} port-introduced "
              f"collision(s), {len(stray)} stray(s) inside a pret buffer.")
        print("  Fix the address; do not add an allowlist. A free address is "
              "DERIVED from pokeyellow.sym, never asserted.")
        return 1

    print(f"check_ram_collisions: clean — 0 port-introduced collisions "
          f"({authorised} faithful pret unions, "
          f"{len(unevaluable)} unevaluable)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
