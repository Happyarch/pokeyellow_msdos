#!/usr/bin/env python3
"""symfile.py — read `pokeyellow.sym`, rgblink's own symbol table.

This retires the hard part of the address problem. `build_symbols.py`'s README
records that deriving pret's WRAM addresses from source means reproducing
rgbasm's section allocator, because the 11 WRAM `SECTION` directives carry no
explicit addresses — "fragile, and wrong quietly". That is true of the SOURCE.
It is not true of the BUILD: `make` at the repository root emits
`pokeyellow.sym`, 23,510 `bank:addr name` rows written by the linker that placed
them. No allocator to reproduce and nothing to infer.

This is also why the root-then-dos_port build order is load-bearing: without the
root build there is no `.sym`, and this module has nothing to read. Several
existing generators (`gen_map_script_tables.py`, `gen_symfile.py`, …) already
depend on it the same way.

CROSS-CHECKING THE PORT'S MEMMAP IS FREE, SO DO IT
--------------------------------------------------
684 of the port's `gb_memmap.inc` equs are spelled exactly like a pret label, and
comparing the two addresses costs nothing. Measured 2026-08-16: 684 agree and 55
differ, and every one of the 55 decomposes into a documented deviation rather
than a defect — see `audit_memmap()`. Report the decomposition, never the bare
"55 disagree": an aggregate is not evidence until you say what it is made of.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, Optional, Tuple

_ROW = re.compile(r"^([0-9A-Fa-f]{2}):([0-9A-Fa-f]{4})\s+(\S+)$")

#: The port maps SRAM banks 1-3 flat at 0x22000-0x27FFF (CLAUDE.md, the
#: `class=banking` deviation), so a pret `01:aXXX` becomes 0x22000 + 0xXXX.
SRAM_FLAT_BASE = 0x22000


@dataclass
class SymFile:
    path: Path
    #: name -> (bank, address) exactly as the linker wrote it
    entries: Dict[str, Tuple[int, int]] = field(default_factory=dict)
    #: SECTION name -> bank, read from pokeyellow.map. pret writes
    #: `BANK("Audio Engine 3")` — a bank named by its SECTION rather than by a
    #: symbol, which the .sym file cannot answer because it lists symbols only.
    sections: Dict[str, int] = field(default_factory=dict)

    def bank(self, name: str) -> Optional[int]:
        """The ROM bank the linker placed this symbol in."""
        got = self.entries.get(name)
        return None if got is None else got[0]

    def address(self, name: str) -> Optional[int]:
        """The address the PORT should use for this pret symbol.

        Bank 0 (WRAM/HRAM/ROM home) is the address as written. SRAM banks 1-3
        are rebased onto the port's flat window, which is a deviation the port
        already carries everywhere else — reproducing it here rather than
        emitting a bare `0xa598` is what keeps an emitted equ pointing at the
        same storage the rest of the port uses.
        """
        got = self.entries.get(name)
        if got is None:
            return None
        bank, addr = got
        if bank == 0:
            return addr
        if 1 <= bank <= 3 and 0xA000 <= addr < 0xC000:
            return SRAM_FLAT_BASE + (bank - 1) * 0x2000 + (addr - 0xA000)
        # A ROM bank. Not an address the port can use — code lives at link-time
        # symbols, not GB addresses — so the caller must not treat this as one.
        return None

    def is_ram(self, name: str) -> bool:
        got = self.entries.get(name)
        if got is None:
            return False
        bank, addr = got
        return (bank == 0 and addr >= 0xC000) or (1 <= bank <= 3 and 0xA000 <= addr < 0xC000)


def load(root: Path, name: str = "pokeyellow.sym") -> SymFile:
    path = root / name
    sf = SymFile(path)
    if not path.exists():
        raise FileNotFoundError(
            f"{path} not found. Build the pret ROM first: `make` in the repository "
            f"root, BEFORE `make -C dos_port`. The build order is load-bearing.")
    for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw.split(";")[0].strip()
        m = _ROW.match(line)
        if m:
            # setdefault: rgblink emits aliases at one address (UNION members,
            # `.` locals). First wins, which is the outermost/most-named one.
            sf.entries.setdefault(m.group(3), (int(m.group(1), 16), int(m.group(2), 16)))
    _load_sections(root, sf)
    return sf


_BANK_HDR = re.compile(r"^(ROMX|ROM0) bank #(\d+)", re.I)
_SECTION = re.compile(r'SECTION: \$[0-9A-Fa-f]+-\$[0-9A-Fa-f]+ \([^)]*\) \["([^"]+)"\]')


def _load_sections(root: Path, sf: SymFile, name: str = "pokeyellow.map") -> None:
    """SECTION name -> bank, from rgblink's map file.

    Optional: the map is a build product like the .sym, but only ONE construct
    needs it (`BANK("<section>")`), so its absence degrades that single site to a
    bail rather than failing the run.
    """
    path = root / name
    if not path.exists():
        return
    bank = 0
    for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
        h = _BANK_HDR.match(raw.strip())
        if h:
            bank = int(h.group(2))
            continue
        s = _SECTION.search(raw)
        if s:
            sf.sections.setdefault(s.group(1), bank)


def audit_memmap(sf: SymFile, memmap: Path) -> dict:
    """Compare same-spelled port equs against the linker's addresses.

    Returns the DECOMPOSITION, not a verdict. Three buckets:
      agree            same name, same address
      sram_flat        differs only by the port's flat SRAM-bank rebase
      relocated        the port moved it deliberately, and gb_memmap.inc says so
                       in a comment (pret UNION overlays cannot overlay in a flat
                       model, so they were given free addresses)
      unexplained      anything else — this is the bucket that would be a finding
    """
    text = memmap.read_text(encoding="utf-8")
    lines = text.splitlines()
    port: Dict[str, Tuple[int, int]] = {}
    for i, ln in enumerate(lines):
        m = re.match(r"^([A-Za-z_]\w*)\s+equ\s+(0x[0-9A-Fa-f]+|\d+)", ln)
        if m:
            port.setdefault(m.group(1), (int(m.group(2), 0), i))

    out = {"agree": [], "sram_flat": [], "relocated": [], "unexplained": []}
    for name, (value, idx) in port.items():
        raw = sf.entries.get(name)
        if raw is None:
            continue
        want = sf.address(name)
        if want is not None and value == want:
            out["sram_flat" if raw[0] != 0 else "agree"].append(name)
            continue
        # A deliberate move is documented in a `RELOCATED (port-only)` comment
        # heading the block, which is the convention gb_memmap.inc already
        # follows. The window is 60 lines because ONE such header covers a whole
        # relocated struct — the animated-object block is 20 equs under a single
        # comment, and a 25-line window credited only the first four of them.
        context = "\n".join(lines[max(0, idx - 60):idx + 1]).upper()
        if "RELOCATED" in context or "CANNOT LIVE" in context:
            out["relocated"].append(name)
        else:
            out["unexplained"].append((name, hex(value), hex(raw[1]), raw[0]))
    return out
