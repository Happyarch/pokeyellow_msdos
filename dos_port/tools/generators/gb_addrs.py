"""Single source of GB addresses for the asset generators.

WHY THIS EXISTS (2026-08-19). Four generators carried GB addresses as Python
literals -- `wOverworldMap = 0xE800`, `WEVENTFLAGS = 0xD746`, and so on -- each
with a comment promising it matched `include/gb_memmap.inc`. A comment is not a
link: when the port's WRAM layout moves, a literal does not move with it, and the
generator keeps emitting perfectly well-formed data pointed at the OLD address.
Nothing faults. You get wrong map headers and wrong event flags, silently.

That hazard became concrete with the prefix-sum WRAM expansion
(`docs/current_plan_wram_expansion.md`), which moves `wOverworldMap` 0xE800 ->
0xCE48 and `wEventFlags` 0xD746 -> 0xE512.

So: generators ASK for an address by name, and get whatever the port's headers
currently say. `tools/check_generator_literals.py` gates against regressing to a
literal.

    from gb_addrs import addr
    wOverworldMap = addr("wOverworldMap")

Reads `include/gb_memmap.inc` first (the hand-owned map, whose defines win) and
then `assets/pret_ram.inc` (the generated pret addresses), matching the
precedence the assembler itself sees.
"""
import re
from pathlib import Path

DOS_PORT = Path(__file__).resolve().parents[2]

_EQU_RE = re.compile(
    r"^\s*(?:%define\s+([A-Za-z_]\w*)\s+|([A-Za-z_]\w*)\s+equ\s+)"
    r"0x([0-9A-Fa-f]+)\s*(?:;.*)?$")

# gb_memmap.inc first: its defines win over the generated pret addresses, which
# is the same precedence NASM sees (gen_pret_ram.py only fills the gaps).
_SOURCES = ["include/gb_memmap.inc", "assets/pret_ram.inc"]

_cache = None


def _load():
    global _cache
    if _cache is None:
        _cache = {}
        for rel in _SOURCES:
            p = DOS_PORT / rel
            if not p.exists():
                continue
            for line in p.read_text(errors="ignore").splitlines():
                m = _EQU_RE.match(line)
                if m:
                    _cache.setdefault(m.group(1) or m.group(2),
                                      int(m.group(3), 16))
    return _cache


def addr(name):
    """GB address of `name`, from the port's own headers. Raises if unknown --
    a generator must never fall back to a guess."""
    syms = _load()
    if name not in syms:
        raise KeyError(
            f"gb_addrs: {name!r} is not declared in "
            f"{' or '.join(_SOURCES)}. Do not substitute a literal; add the "
            f"symbol to the memory map, or fix the name.")
    return syms[name]
