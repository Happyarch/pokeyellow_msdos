#!/usr/bin/env python3
"""gen_pret_ram.py — emit every pret WRAM/HRAM label as an EBP-relative equ.

WHY THIS EXISTS
There was no single source of truth for the emulated GB memory map. Addresses
lived in hand-written include/gb_memmap.inc, and any pret label it did not carry
got re-declared ad hoc in whichever .asm needed it. A NASM `equ` is FILE-LOCAL,
so two files could declare the same label at DIFFERENT addresses and everything
still assembled, linked and passed every gate. That shipped six wrong addresses
(see the header of assets/pret_ram.inc consumers, and commits eb09fb18d /
this one): four sprite-position HRAM vars parked inside pret's hDMARoutine, a
mart flag on top of a battle-AI byte, and a union alias resolved to the wrong
byte. All six were found by diffing declarations against rgblink's own symbol
file, which is exactly what this generator makes unnecessary.

SOURCE OF TRUTH: pokeyellow.sym, produced by rgblink from the pret build. NOT
inferred from wram.asm ordering — pret uses UNION blocks, so several labels
deliberately share one byte (wSavedCoordIndex / wOakWalkedToPlayer /
wNextSafariZoneGateScript are all 0xCF0D) and sequential assignment gets them
wrong. That mistake is precisely one of the bugs this replaces.

ADDITIVE BY CONSTRUCTION, decided at GENERATION time. Any symbol already declared
in include/gb_memmap.inc or in a src/**/*.asm is SKIPPED, so:
  * a symbol gb_memmap.inc already defines KEEPS its value, and
  * the port's DELIBERATE relocations survive untouched, and
  * no existing local declaration is turned into a redefinition error.
(NASM `%ifndef` tests PREPROCESSOR MACROS, not `equ` labels, so it cannot be used
to guard these — an %ifndef-guarded equ still redefines. Filtering here is the
only mechanism that actually works.)
The port genuinely relocates buffers that do not fit the GB layout (wOverworldMap
grown to 0x900 for MAP_BORDER=7, wLYOverrides, the wAnimatedObject* block, the
`flat-adapted: 4 bytes` pointer widenings). This generator must never fight
those — it only fills the gaps.
"""
import re, sys, pathlib

PRET = pathlib.Path(__file__).resolve().parents[3]
OUT  = pathlib.Path(__file__).resolve().parents[2] / "assets" / "pret_ram.inc"


# --- the prefix-sum WRAM expansion -----------------------------------------
# The port is a Game Boy with more WRAM: a grown buffer keeps its pret address and
# everything ABOVE it shifts up by the growth (docs/current_plan_wram_expansion.md).
# The growth table is tools/wram_growth.json -- the SINGLE source, also read by
# check_ram_straddle.py. Addresses at or above GB_OAM never move, which is what
# keeps every OAM/IO/HRAM symbol at its pret address.
import json

_GROWTH = [(int(g["pret"], 16), g["pret_size"], g["port_size"] - g["pret_size"])
           for g in json.loads(
               (pathlib.Path(__file__).resolve().parents[2] /
                "tools" / "wram_growth.json").read_text())["growths"]]
_GB_OAM = 0xFE00


def _shift(addr):
    """pret address -> port address under the prefix-sum expansion."""
    if addr >= _GB_OAM:
        return addr
    # A growth applies only at or ABOVE the END of the grown region. `p < addr`
    # tears the region apart: a symbol INSIDE it accrues the region's own growth.
    return addr + sum(g for p, sz, g in _GROWTH if p + sz <= addr)


def main():
    sym = PRET / "pokeyellow.sym"
    if not sym.exists():
        sys.exit(f"gen_pret_ram: {sym} not found — run `make` at the repo root first "
                 f"(rgblink writes it).")
    # bank:addr name — WRAM/HRAM are bank 00. Keep the FIRST spelling of an address
    # but emit every distinct NAME, so pret's union aliases all resolve alike.
    seen = {}
    for line in sym.read_text(errors="ignore").splitlines():
        m = re.match(r"^([0-9a-fA-F]{2}):([0-9a-fA-F]{4})\s+(\S+)\s*$", line)
        if not m:
            continue
        bank, addr, name = m.group(1), int(m.group(2), 16), m.group(3)
        if bank != "00":
            continue
        # wFoo / hFoo is pret's usual RAM convention, but pret also names a byte it
        # never gave a meaning after its own ADDRESS — wd474, wc6ea, hff8c. Those are
        # pret RAM labels too, and excluding them is what forced five .asm files to
        # declare them by hand, which is exactly the file-local-equ hazard this
        # generator exists to remove (a src equ is FILE-LOCAL, so two files can
        # disagree about an address and still assemble, link and pass every gate).
        if not re.match(r"^[wh]([A-Z]|[0-9a-f]{2,4}$)", name):
            continue
        if not (0xC000 <= addr <= 0xFFFF):          # WRAM, echo, OAM, HRAM
            continue
        seen.setdefault(name, _shift(addr))

    # Skip anything already declared anywhere in the port: gb_memmap.inc carries the
    # deliberate relocations, and src/ still holds per-file declarations. Emitting a
    # second equ for either is a hard NASM error, and silently overriding a relocation
    # would be worse than the gap this closes.
    root = pathlib.Path(__file__).resolve().parents[2]
    declared = set()
    # gb_memmap.inc is the CENTRAL hand-owned map: its equs win (they carry the port's
    # deliberate relocations). A src-file `equ` must NOT suppress emission -- NASM equs
    # are FILE-LOCAL, so skipping on one starves every other file of the symbol. Any
    # src-file equ of a pret symbol is a duplicate and should be deleted instead.
    _mm = (root / "include" / "gb_memmap.inc").read_text(errors="ignore")
    for m in re.finditer(r"^\s*([wh][A-Za-z0-9_]+)\s+equ\s", _mm, re.M):
        declared.add(m.group(1))
    # gb_memmap.inc declares constants as %define (an equ emits a COFF symbol into
    # every including object). Both spellings must suppress emission here.
    for m in re.finditer(r"^\s*%define\s+([wh][A-Za-z0-9_]+)\s", _mm, re.M):
        declared.add(m.group(1))
    srcs = list((root / "src").rglob("*.asm"))
    for f in srcs:
        t = f.read_text(errors="ignore")
        # ... and REAL LABELS: a few pret names are port-side storage allocated in the
        # port's own sections rather than emulated GB RAM (e.g. wMapSpriteData,
        # wMapSpriteExtraData in engine/overworld/map_sprites.asm). Emitting an equ for
        # those collides with the label itself.
        for m in re.finditer(r"^\s*global\s+([wh][A-Za-z0-9_]+)\s*$", t, re.M):
            declared.add(m.group(1))
        for m in re.finditer(r"^([wh][A-Za-z0-9_]+):", t, re.M):
            declared.add(m.group(1))
    skipped = len(set(seen) & declared)
    for n in list(seen):
        if n in declared:
            del seen[n]

    lines = [
        "; assets/pret_ram.inc — GENERATED by tools/generators/gen_pret_ram.py.",
        "; DO NOT EDIT BY HAND.",
        ";",
        "; Every pret WRAM/HRAM label, at the address rgblink assigned (pokeyellow.sym),",
        "; as %define (a preprocessor macro) rather than equ -- see gen_pret_ram.py.",
        "; Each equ is %ifndef-guarded and this file is included at the END of",
        "; gb_memmap.inc, so anything gb_memmap.inc defines itself WINS — the port's",
        "; deliberate relocations are unaffected. This only fills the gaps, which is why",
        "; it cannot silently move a buffer the port moved on purpose.",
        ";",
        "; pret UNIONS several names onto one byte; all such names appear here with the",
        "; SAME address, which is the point — do not 'fix' duplicates by spreading them.",
        "",
        "%ifndef PRET_RAM_INC",
        "%define PRET_RAM_INC",
        "",
    ]
    width = max((len(n) for n in seen), default=8)
    for name in sorted(seen):
        # %define, NOT equ. NASM emits every `equ` as a local ABSOLUTE COFF symbol --
        # even without `global`, even if unused -- so 2193 equs here landed in EVERY
        # object that includes gb_memmap.inc (i.e. all of them), 552 times over. A
        # %define is a preprocessor macro: it expands textually, emits no symbol, and
        # generates byte-identical code for both `[ebp + name]` and arithmetic.
        # These are constants, not code addresses, so nothing in pkmn.sym wants them.
        lines.append(f"%define {name:<{width}} 0x{seen[name]:04X}")
    lines += ["", "%endif ; PRET_RAM_INC", ""]
    OUT.write_text("\n".join(lines))
    print(f"gen_pret_ram: {len(seen)} pret RAM/HRAM symbols emitted "
          f"({skipped} already declared in the port, skipped) -> assets/pret_ram.inc")

if __name__ == "__main__":
    main()
