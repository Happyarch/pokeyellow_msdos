"""Resolve program symbols from pkmn.sym (always fresh) and GB constants from gb_memmap.inc.

pkmn.sym is generated at every link by tools/gen_symfile.py from PKMN.EXE's own
COFF symbol table, so it contains every label — including NASM local labels
(`_AdvancePlayerSprite.scroll`) that the ld -Map file never had — at the final
linked VMAs.

Freshness contract (kills the stale-breakpoint bug class):
  * every resolve()/search()/nearest() call stats pkmn.sym and transparently
    reloads when it changed (the MCP server process outlives rebuilds);
  * if PKMN.EXE is newer than pkmn.sym (a link ran without the sym rule),
    StaleSymbolsError is raised instead of silently resolving old addresses.
"""

import os
import re
from typing import Optional

# "0000875c t _AdvancePlayerSprite.scroll"
_SYM_LINE = re.compile(r'^([0-9a-fA-F]+)\s+([TtDdBb])\s+(\S+)\s*$')
# Matches both $XXXX and 0xXXXX hex literals (gb_memmap.inc uses 0x prefix)
_HEX_VAL  = r'(?:0x|0X|\$)([0-9a-fA-F]+)'
_INC_EQU  = re.compile(r'^\s*(\w+)\s+EQU\s+' + _HEX_VAL, re.IGNORECASE)
_INC_DEF  = re.compile(r'^\s*%define\s+(\w+)\s+' + _HEX_VAL, re.IGNORECASE)

# a fresh EXE may legitimately be a fraction of a second older than the sym
# file written right after it in the same make rule
_STALE_SLACK_S = 1.0


class StaleSymbolsError(RuntimeError):
    """PKMN.EXE is newer than pkmn.sym — refusing to resolve stale addresses."""


class SymbolMap:
    def __init__(self, sym_file: str, memmap_inc: Optional[str] = None,
                 exe_file: Optional[str] = None):
        self._sym_file = sym_file
        self._memmap_inc = memmap_inc
        self._exe_file = exe_file
        self._syms: dict[str, int] = {}
        self._kinds: dict[str, str] = {}
        self._sorted: list[tuple[int, str, str]] = []  # (addr, kind, name), by addr
        self._gb: dict[str, int] = {}
        self._sym_stamp: Optional[tuple[float, int]] = None
        self._inc_stamp: Optional[tuple[float, int]] = None
        try:
            self._ensure_fresh()
        except StaleSymbolsError:
            pass   # don't kill the server at startup; queries re-raise

    # -- freshness ---------------------------------------------------------

    @staticmethod
    def _stamp(path: str) -> Optional[tuple[float, int]]:
        try:
            st = os.stat(path)
        except OSError:
            return None
        return (st.st_mtime, st.st_size)

    def _ensure_fresh(self) -> None:
        """Reload source files when they changed; raise on a stale sym file."""
        sym_stamp = self._stamp(self._sym_file)
        if self._exe_file:
            exe_stamp = self._stamp(self._exe_file)
            if exe_stamp and sym_stamp and exe_stamp[0] - sym_stamp[0] > _STALE_SLACK_S:
                raise StaleSymbolsError(
                    f"{self._exe_file} is newer than {self._sym_file} — the EXE was "
                    "linked without regenerating the symbol file. Rebuild via make "
                    "(the link rule writes pkmn.sym) before resolving symbols.")
            if exe_stamp and not sym_stamp:
                raise StaleSymbolsError(
                    f"{self._sym_file} does not exist but {self._exe_file} does — "
                    "rebuild via make (the link rule writes pkmn.sym).")
        if sym_stamp != self._sym_stamp:
            self._load_syms()
            self._sym_stamp = sym_stamp
        if self._memmap_inc:
            inc_stamp = self._stamp(self._memmap_inc)
            if inc_stamp != self._inc_stamp:
                self._load_memmap()
                self._inc_stamp = inc_stamp

    def _load_syms(self) -> None:
        self._syms.clear()
        self._kinds.clear()
        self._sorted = []
        if not os.path.exists(self._sym_file):
            return
        with open(self._sym_file) as f:
            for line in f:
                m = _SYM_LINE.match(line)
                if not m:
                    continue
                addr = int(m.group(1), 16)
                kind = m.group(2)
                name = m.group(3)
                # first definition wins (duplicate static names across objects)
                self._syms.setdefault(name, addr)
                self._kinds.setdefault(name, kind)
                self._sorted.append((addr, kind, name))
        self._sorted.sort()

    def _load_memmap(self) -> None:
        self._gb.clear()
        if not (self._memmap_inc and os.path.exists(self._memmap_inc)):
            return
        with open(self._memmap_inc) as f:
            for line in f:
                for pat in (_INC_EQU, _INC_DEF):
                    m = pat.match(line)
                    if m:
                        self._gb[m.group(1)] = int(m.group(2), 16)
                        break

    # -- queries (all freshness-checked) ------------------------------------

    def resolve(self, name_or_addr: str) -> Optional[int]:
        """Return the program (VMA) address for a symbol name, or parse hex."""
        self._ensure_fresh()
        if name_or_addr.startswith(('0x', '0X')):
            return int(name_or_addr, 16)
        if name_or_addr in self._syms:
            return self._syms[name_or_addr]
        try:
            return int(name_or_addr, 16)
        except ValueError:
            return None

    def gb_offset(self, name: str) -> Optional[int]:
        """Return GB memory offset for a wRAM/HRAM constant name."""
        self._ensure_fresh()
        return self._gb.get(name)

    def all_symbols(self) -> dict[str, int]:
        self._ensure_fresh()
        return dict(self._syms)

    def search(self, pattern: str) -> list[tuple[str, int]]:
        self._ensure_fresh()
        pat = re.compile(pattern, re.IGNORECASE)
        return [(n, a) for n, a in self._syms.items() if pat.search(n)]

    def nearest(self, addr: int, code_only: bool = True
                ) -> Optional[tuple[str, int, str]]:
        """Nearest symbol at or below addr: (name, delta, kind) or None."""
        self._ensure_fresh()
        if not self._sorted:
            return None
        import bisect
        idx = bisect.bisect_right(self._sorted, (addr, '\xff', '\xff'))
        while idx > 0:
            saddr, kind, name = self._sorted[idx - 1]
            if not code_only or kind in 'Tt':
                return (name, addr - saddr, kind)
            idx -= 1
        return None
