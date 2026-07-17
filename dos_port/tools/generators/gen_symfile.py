#!/usr/bin/env python3
"""Generate pkmn.sym from the linked EXE's COFF symbol table.

Usage:  i586-pc-msdosdjgpp-objdump -t PKMN.EXE | tools/generators/gen_symfile.py > pkmn.sym

The EXE is the single always-fresh source of truth for symbols: unlike the ld
-Map file (globals only), the COFF symbol table keeps every NASM local label
(`_AdvancePlayerSprite.scroll`, ...) at its final linked VMA. This filter keeps
only defined section symbols and emits one sorted line per symbol:

    <8-hex-digit VMA> <kind> <name>

kind mirrors nm(1): T/D/B for .text/.data/.bss, uppercase = global (COFF
storage class 2), lowercase = local/static (storage class 3). Consumed by
tools/dosbox_mcp/symbol_map.py and the dosbox-x-mcp SYMF debugger command.

Dropped: absolute symbols (every .o re-embeds all `equ` constants — ~300k
junk entries), file/section/debug entries, and undefined references.
"""
import re
import sys

# [351250](sec  1)(fl 0x00)(ty   0)(scl   2) (nx 0) 0x00007b1c OverworldLoop
SYM_RE = re.compile(
    r'^\[\s*\d+\]\(sec\s+(-?\d+)\)\(fl [^)]*\)\(ty\s+[^)]*\)\(scl\s+(\d+)\)\s*'
    r'\(nx \d+\)\s+0x([0-9a-fA-F]+)\s+(\S+)\s*$'
)

SEC_KIND = {1: 'T', 2: 'D', 3: 'B'}
GLOBAL_SCL = 2   # C_EXT
LOCAL_SCL = 3    # C_STAT


def main() -> int:
    entries = set()
    for line in sys.stdin:
        m = SYM_RE.match(line)
        if not m:
            continue
        sec, scl, addr, name = int(m.group(1)), int(m.group(2)), int(m.group(3), 16), m.group(4)
        if sec not in SEC_KIND or scl not in (GLOBAL_SCL, LOCAL_SCL):
            continue
        if name.startswith('.'):     # section symbols (.text/.data/.bss)
            continue
        kind = SEC_KIND[sec]
        if scl == LOCAL_SCL:
            kind = kind.lower()
        entries.add((addr, kind, name))

    if not entries:
        print("gen_symfile.py: no symbols matched — wrong input?", file=sys.stderr)
        return 1

    out = sys.stdout
    for addr, kind, name in sorted(entries):
        out.write(f"{addr:08x} {kind} {name}\n")
    print(f"gen_symfile.py: {len(entries)} symbols", file=sys.stderr)
    return 0


if __name__ == '__main__':
    sys.exit(main())
