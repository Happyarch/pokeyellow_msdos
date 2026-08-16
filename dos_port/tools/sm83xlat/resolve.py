#!/usr/bin/env python3
"""resolve.py — one answer to "what does the port call this pret name?"

Stage 1. Every pret name a script mentions falls into exactly one of four
namespaces, and each has a different port-side answer:

| namespace | example | port-side answer |
|---|---|---|
| RAM symbol | `wCurrentMapScriptFlags` | a `gb_memmap.inc` equ, via `tables/symbols.json` |
| constant | `EVENT_BEAT_MISTY` | the same name if the port defines it, else its literal value |
| pret code/data label | `TalkToTrainer` | the same name, as an `extern` |
| script-local | `.BagFull`, `TEXT_PEWTERMART_CLERK` | emitted by this tool |

The table is built once and read by both the Stage 1 report and the Stage 3
emitter, so the two cannot disagree about what a name means.

WHY A CONSTANT MAY BECOME A LITERAL, AND WHY THAT IS NOT A LICENCE
------------------------------------------------------------------
The port defines 653 of the 962 constants `scripts/` references. For the other
309 there is no port symbol to name, so the emitter writes the evaluated value
with the pret spelling in a trailing comment — which is exactly what the port
already does elsewhere (`db 0x02 ; SPRITE_BLUE`). That is sound for a *constant*
and only for a constant: a number whose meaning is fixed at assembly time on both
sides. It is emphatically not a precedent for inlining anything the two-tier rule
covers — a glyph run stays Tier-1 data and goes to a generator, no matter how
convenient a `db` would be.

A constant with neither a port symbol nor an evaluable value BAILS. There is no
third option: guessing a number is the one failure the whole design exists to
prevent, and it would be invisible in review because the output would look
perfectly ordinary.

FAIL-CLOSED, AND WHAT THAT COSTS
--------------------------------
`resolve()` returns `None` rather than a best effort. Every caller treats `None`
as a bail. That is deliberately expensive — it is what makes an unrecognised name
a loud link error instead of a plausible wrong lowering.
"""
from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, Optional, Set

import pretsyms
import symfile

HERE = Path(__file__).resolve().parent

#: Header line every emitted file carries. Used to tell the tool's own output
#: apart from hand-written port source when scanning for already-defined labels.
TOOL_OUTPUT_MARKER = "by dos_port/tools/sm83xlat"

# Namespaces, as returned in Resolution.kind.
NS_RAM = "ram"
NS_CONST = "constant"
NS_LABEL = "label"
NS_LOCAL = "script-local"


@dataclass(frozen=True)
class Resolution:
    """How one pret name is written in the port."""

    pret: str
    kind: str
    text: str              # what the emitter writes
    literal: bool = False  # True when `text` is a number, not a symbol
    value: Optional[int] = None
    note: str = ""


@dataclass
class Resolver:
    ram_pret_to_port: Dict[str, str] = field(default_factory=dict)
    port_symbols: Set[str] = field(default_factory=set)
    #: symbol -> the %include that defines it, so an emitted file can pull in
    #: exactly the headers it needs instead of a fixed guess.
    symbol_include: Dict[str, str] = field(default_factory=dict)
    #: labels to treat as NOT-already-defined for the file currently being
    #: emitted. Set only when shadowing a hand-written port file, where the
    #: output is a comparison artifact rather than something that will link.
    shadow_exempt: Set[str] = field(default_factory=set)
    #: labels the port's GENERATED assets already define. Emitting one here would
    #: put the same data under two owners; the region bails and the label is
    #: EXTERNED — never %included, because a label links and a constant does not.
    asset_labels: Set[str] = field(default_factory=set)
    uni: Optional[pretsyms.Universe] = None
    sym: Optional[symfile.SymFile] = None
    script_labels: Set[str] = field(default_factory=set)
    script_constants: Set[str] = field(default_factory=set)
    #: constants with no port symbol AND no evaluable value — always a bail
    unresolvable: Set[str] = field(default_factory=set)
    #: port equs whose address contradicts the linker's, with no documented
    #: reason. Referencing one emits a wrong-byte access that looks perfect in
    #: review, so they bail. See `memmap_conflicts`.
    memmap_conflicts: Dict[str, tuple] = field(default_factory=dict)
    #: RAM symbols the port has no equ for at all; the emitter supplies them
    #: from the linker's addresses (see `missing_ram`).
    missing_ram: Dict[str, int] = field(default_factory=dict)

    def legacy_alias(self, name: str) -> Optional[str]:
        """The port's legacy SCREAMING_SNAKE name for a pret RAM symbol, if the
        port does not yet define the pret spelling itself."""
        if name in self.port_symbols:
            return None
        return self.ram_pret_to_port.get(name)

    def resolve(self, name: str) -> Optional[Resolution]:
        if name.startswith("."):
            return Resolution(name, NS_LOCAL, name)
        if name in self.script_labels or name in self.script_constants:
            return Resolution(name, NS_LOCAL, name)

        # RAM first: the port renames these, so a pret RAM name must never fall
        # through to "same spelling" — it would assemble against a port symbol
        # that does not exist, or worse, one that does and means something else.
        if self.uni and name in self.uni.ram:
            if name in self.memmap_conflicts:
                # The port defines this name at an address the linker's own
                # table contradicts, with no documented reason. Emitting the
                # symbol would compile and run and touch the wrong byte.
                return None
            if name in self.port_symbols:
                return Resolution(name, NS_RAM, name,
                                  note="port uses the pret spelling; address "
                                       "confirmed against pokeyellow.sym")
            port = self.ram_pret_to_port.get(name)
            if port:
                # The port's own current spelling, deliberately.
                #
                # THIS OUTPUT IS NOT RENAME-INVARIANT, and it cannot be made so.
                # 268 sites across 61 emitted files name a SCREAMING_SNAKE equ
                # that Workstream B deletes. Emitting the pret spelling with a
                # guarded alias was tried and DOES NOT WORK: `%ifndef` tests
                # preprocessor %defines, and gb_memmap.inc uses `equ`, which is
                # an assembly-time label the preprocessor cannot see. The guard
                # never fires, so the alias becomes a redefinition the moment the
                # rename lands. NASM has no guard for an `equ`.
                #
                # Measured by simulating the rename over the whole memmap and
                # re-assembling: it also breaks `events.inc`, which references
                # W_EVENT_FLAGS itself. So the rename ALREADY has to sweep its
                # consumers, and these files are simply more consumers. The
                # plan's "safe alongside the rename" claim is true of the symbol
                # MAPPING (which joins on the normalized name) and was never true
                # of emitted output. See README.md, "Merge order".
                return Resolution(name, NS_RAM, port, note="gb_memmap.inc equ")
            if name in self.missing_ram:
                return Resolution(name, NS_RAM, name,
                                  note="supplied by the emitted script_symbols.inc")
            return None

        if self.uni and name in self.uni.constants:
            if name in self.port_symbols:
                return Resolution(name, NS_CONST, name)
            value = self.uni.values.get(name)
            if value is not None:
                return Resolution(name, NS_CONST, str(value), literal=True,
                                  value=value, note=f"no port symbol; {name} = {value}")
            return None

        if self.uni and name in self.uni.labels:
            return Resolution(name, NS_LABEL, name, note="extern")

        if name in self.port_symbols:
            return Resolution(name, NS_CONST, name)
        return None


def _port_symbols_with_source(port: Path):
    """Names the port's headers and generated assets define.

    Both `.inc` trees are scanned: `include/` is hand-written and `assets/` is
    generated, but a name is equally usable from either and the emitter has no
    reason to care which produced it.
    """
    out: Set[str] = set()
    src: Dict[str, str] = {}
    asset_labels: Set[str] = set()
    for d in ("include", "assets"):
        base = port / d
        if not base.is_dir():
            continue
        for p in sorted(base.rglob("*.inc")):
            try:
                text = p.read_text(encoding="utf-8", errors="replace")
            except OSError:
                continue
            names = set(re.findall(r"^\s*%define\s+([A-Za-z_]\w*)", text, re.M))
            names |= set(re.findall(r"^\s*%assign\s+([A-Za-z_]\w*)", text, re.M))
            names |= set(re.findall(r"^([A-Za-z_]\w*)\s+equ\b", text, re.M | re.I))
            # LABELS, not just equs. assets/trainer_headers.inc DEFINES the
            # battle-text streams (AgathaAfterBattleText and 900-odd siblings);
            # emitting them here too put the same data under two owners and the
            # static gate reported 914 dup_defs. They are externed instead.
            # A LABEL is not a constant. It is recorded so the emitter knows the
            # data is already owned, but deliberately NOT added to `src`: a
            # constant must be textually %included, whereas a label LINKS. The
            # first version conflated them and auto-included generated DATA files
            # (assets/map_headers.inc) into script sources, which fails to
            # assemble on symbols that file needs and this one has no business
            # supplying.
            asset_labels |= set(re.findall(r"^([A-Za-z_]\w*):", text, re.M))
            # `-I include/ -I .` from dos_port/, so an include/ header is named
            # bare and an assets/ file keeps its directory.
            inc = p.name if d == "include" else f"assets/{p.name}"
            for nm in names:
                src.setdefault(nm, inc)
            out |= names
    return out, src, asset_labels


def build(root: Path, port: Path, script_labels: Set[str] = frozenset(),
          script_constants: Set[str] = frozenset()) -> Resolver:
    uni = pretsyms.build(root)
    syms, sym_src, asset_labels = _port_symbols_with_source(port)
    r = Resolver(uni=uni, port_symbols=syms, symbol_include=sym_src,
                 asset_labels=asset_labels,
                 script_labels=set(script_labels),
                 script_constants=set(script_constants))

    tbl = HERE / "tables" / "symbols.json"
    if tbl.exists():
        data = json.loads(tbl.read_text())
        for bucket in ("confirmed", "name_only"):
            for port_name, row in data.get(bucket, {}).items():
                pret_name = row.get("pret")
                if pret_name:
                    r.ram_pret_to_port[pret_name] = port_name

    for name in uni.constants:
        if name not in r.port_symbols and uni.values.get(name) is None:
            r.unresolvable.add(name)

    # The linker's own symbol table. Two uses, both of which have to happen
    # before the emitter can trust a RAM name:
    #   1. every port equ spelled like a pret label is cross-checked against it;
    #   2. every pret RAM symbol the port has NO equ for gets its address from
    #      it, so the emitter can supply the equ instead of bailing on 175
    #      symbols whose addresses were never in doubt.
    # Labels the PORT already defines anywhere under src/ — including ret-stubs
    # in *_stubs.asm. Emitting a body for one of those is a duplicate definition,
    # not a retirement: retiring a stub means DELETING it and repointing every
    # extern comment, which is a deliberate act and not something a transpiler
    # gets to do as a side effect. The four Mansion*Script_Switches stubs are the
    # live example.
    for p_ in sorted((port / "src").rglob("*.asm")):
        try:
            text = p_.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        # SKIP THE TOOL'S OWN OUTPUT. Once emitted, those files sit in
        # dos_port/src/scripts/ and a re-run would read them back as proof that
        # every label is "already owned by the port" — self-poisoning. Measured:
        # it took coverage from 68.3% to 11.5% and 268 owned-by-generated-assets
        # bails to 1,608, on the second run only, which is exactly the shape of
        # bug that hides behind a clean first run. The marker is the emitted
        # header; hand-written files under src/scripts/ (pallet_town.asm,
        # trainer_map_script.asm) do not carry it and are still respected.
        if TOOL_OUTPUT_MARKER in text[:1024]:
            continue
        r.asset_labels |= set(re.findall(r"^\s*global\s+([A-Za-z_]\w*)", text, re.M))
        r.asset_labels |= set(re.findall(r"^([A-Za-z_]\w*):", text, re.M))

    r.sym = symfile.load(root)
    audit = symfile.audit_memmap(r.sym, port / "include" / "gb_memmap.inc")
    for name, port_value, sym_value, bank in audit["unexplained"]:
        r.memmap_conflicts[name] = (port_value, sym_value, bank)
    for name in uni.ram:
        if name in r.port_symbols or name in r.ram_pret_to_port:
            continue
        addr = r.sym.address(name)
        if addr is not None and r.sym.is_ram(name):
            r.missing_ram[name] = addr
    return r
