#!/usr/bin/env python3
"""probe.py — Stage 0 coverage counter: the reason-code histogram and the censuses.

Stage 0 emits NO code. It answers one question — *what would have to be decided
before any of these 251 files could be lowered* — and answers it as a histogram
with a named site list behind every bucket. That histogram is the work queue and
the go/no-go, so it is built to be pessimistic: every question that has not been
answered counts as a bail, and nothing is credited as `ok` on the strength of
looking routine.

WHAT "ok" MEANS HERE, EXACTLY
-----------------------------
`ok` means: the item's form is in the ISA or macro table, every symbol it names
resolves, and its lowering is fixed by the register map alone — no callee
contract, no pointer domain, no assembly-time state, no projection. It does NOT
mean "already correct"; flag exactness is a dataflow property and is Stage 2's
gate, reported here only as a census.

THREE CENSUSES ACCOMPANY THE HISTOGRAM
--------------------------------------
* **Branch census** — every conditional branch, bucketed by how far away the
  instruction that wrote the flag it reads is. Stage 2's acceptance gate is that
  a real CFG + liveness pass independently reproduces these proportions; a
  mismatch then means the CFG or the flag table is wrong, and it is found before
  any output exists. Measured LOCALLY here on purpose — the two measurements
  have to be independent to be worth comparing.
* **Callee inventory** — distinct call/jump/farcall/predef targets with site
  counts and whether the port already defines the name. This is the concrete
  size of the `abi.json` job, which the plan predicts will be the largest reason
  code and the single biggest chunk of real work. Discovering it now rather than
  at Stage 5 is the whole point of probing first.
* **Symbol inventory** — distinct memory-operand symbols, resolved against the
  shared `tables/symbols.json`, pret's `constants/`, and the port's own memmap.

Run:  python3 dos_port/tools/sm83xlat/stage0.py
"""
from __future__ import annotations

import json
import re
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Sequence, Set

import isa
import lexer
import macros
import parser as sparser
import pretsyms

HERE = Path(__file__).resolve().parent

# How far back the branch census looks for a flag producer. 12 matches the
# corpus measurement this census is meant to be comparable against.
CENSUS_WINDOW = 12

# Reason codes. Ordered by the priority in which they are assigned, so one site
# lands in exactly one bucket and the histogram sums to the site count.
OK = "ok"
R_SCREEN_COORD = "screen-coord-projection"
R_SCREEN_STRIDE = "screen-stride-projection"
R_EVENT_RANGE = "event-range-macro"
R_CHECKEVENT_CARRY = "checkevent-carry-form"
R_EVENT_BYTE_STATE = "event-byte-assembly-state"
R_UNKNOWN_CALLEE = "unknown-callee-abi"
R_UNRESOLVED_SYM = "unresolved-symbol"
R_POINTER_DOMAIN = "pointer-domain-unknown"
R_BANK_EXPR = "bank-expression"
R_UNKNOWN_MACRO = "unknown-macro"
R_UNKNOWN_SHAPE = "unknown-operand-shape"
R_MACRO_ARITY = "macro-arity-unmodelled"
R_HN_FLAG = "hn-flag-consumer"

# Data-side codes, counted separately from the imperative histogram.
D_INLINE_TEXT = "inline-text-db"

# An identifier, but NOT one that is really part of something else. The three
# false positives this excludes were each worth hundreds of phantom "unresolved"
# reports in the first run of this probe:
#   `$ff`   -> a hex literal, not a symbol named `ff`
#   `.done` -> a local label, resolved by scope, not by the symbol tables
#   `%1010` -> a binary literal
_IDENT = re.compile(r"(?<![\w.$%])[A-Za-z_][A-Za-z0-9_]*")


@dataclass
class SymbolTables:
    """Everything the probe needs to answer 'does this name resolve?'"""

    pret_ram: Dict[str, str] = field(default_factory=dict)   # pret name -> port equ
    port_equs: Set[str] = field(default_factory=set)         # names defined in gb_memmap.inc
    pret_constants: Set[str] = field(default_factory=set)    # EVENT_*, PAD_*, SPRITE_* ...
    port_globals: Set[str] = field(default_factory=set)      # labels the port already defines
    script_labels: Set[str] = field(default_factory=set)     # every label defined in scripts/
    script_constants: Set[str] = field(default_factory=set)  # TEXT_*/SCRIPT_* from dw_const
    pret_labels: Set[str] = field(default_factory=set)       # code/data labels in pret
    over_generated: Set[str] = field(default_factory=set)    # see pretsyms.Universe

    def resolves(self, name: str) -> bool:
        return (name in self.pret_ram or name in self.port_equs
                or name in self.pret_constants or name in self.port_globals
                or name in self.script_labels or name in self.script_constants
                or name in self.pret_labels or name in pretsyms.BUILTINS)


def load_symbol_tables(root: Path, port: Path) -> SymbolTables:
    st = SymbolTables()

    tbl = HERE / "tables" / "symbols.json"
    if tbl.exists():
        data = json.loads(tbl.read_text())
        for bucket in ("confirmed", "name_only"):
            for port_name, row in data.get(bucket, {}).items():
                pret_name = row.get("pret")
                if pret_name:
                    st.pret_ram[pret_name] = port_name

    memmap = port / "include" / "gb_memmap.inc"
    if memmap.exists():
        for m in re.finditer(r"^\s*%define\s+([A-Za-z_][A-Za-z0-9_]*)|"
                             r"^([A-Za-z_][A-Za-z0-9_]*)\s+equ\b",
                             memmap.read_text(), re.M | re.I):
            st.port_equs.add(m.group(1) or m.group(2))

    # pret's constants, RAM labels (including the generated struct fields and
    # FOR-loop siblings) and per-map object ids. See pretsyms.py — three of the
    # definition mechanisms are easy to miss, and missing them makes the probe
    # report its own blind spot as the corpus's largest problem.
    uni = pretsyms.build(root)
    st.pret_constants |= uni.constants
    st.pret_labels |= uni.labels
    for name in uni.ram:
        st.pret_ram.setdefault(name, "")
    st.over_generated = uni.over_generated

    for p in sorted((port / "src").rglob("*.asm")):
        text = p.read_text(encoding="utf-8", errors="replace")
        for m in re.finditer(r"^\s*global\s+([A-Za-z_][A-Za-z0-9_.]*)", text, re.M):
            st.port_globals.add(m.group(1))
        for m in re.finditer(r"^([A-Za-z_][A-Za-z0-9_]*):", text, re.M):
            st.port_globals.add(m.group(1))

    return st


@dataclass
class Site:
    where: str
    reason: str
    text: str
    detail: str = ""


@dataclass
class ProbeResult:
    files: int = 0
    total_lines: int = 0
    active_items: int = 0
    inactive_items: int = 0
    imperative: int = 0
    insn_lines: int = 0
    code_macro_lines: int = 0
    data_lines: int = 0
    control_lines: int = 0

    histogram: Counter = field(default_factory=Counter)
    sites: List[Site] = field(default_factory=list)
    per_file: Dict[str, Counter] = field(default_factory=lambda: defaultdict(Counter))

    branch_census: Counter = field(default_factory=Counter)
    branch_census_crude: Counter = field(default_factory=Counter)
    branch_detail: List[dict] = field(default_factory=list)

    callees: Counter = field(default_factory=Counter)
    callee_defined: Dict[str, bool] = field(default_factory=dict)
    callee_kind: Dict[str, Counter] = field(default_factory=lambda: defaultdict(Counter))

    symbols: Counter = field(default_factory=Counter)
    unresolved_symbols: Counter = field(default_factory=Counter)
    pointer_domain: Counter = field(default_factory=Counter)

    data_histogram: Counter = field(default_factory=Counter)
    inline_text_sites: List[Site] = field(default_factory=list)

    mnemonics: Counter = field(default_factory=Counter)
    macro_uses: Counter = field(default_factory=Counter)
    text_asm_bodies: int = 0
    includes: List[str] = field(default_factory=list)


_QUOTED = re.compile(r'"[^"]*"')


def _idents(text: str) -> List[str]:
    """Identifiers in an expression, minus literals, strings and register names.

    Quoted runs are removed first: `cp BANK("Audio Engine 3")` takes the bank of
    a SECTION NAME, and the words inside it are not symbols. That one line was
    the last unresolved-symbol report in this probe.
    """
    out = []
    for m in _IDENT.finditer(_QUOTED.sub('""', text)):
        tok = m.group(0)
        if tok.lower() in isa.R8 or tok.lower() in isa.R16:
            continue
        out.append(tok)
    return out


def _is_call_like(item: sparser.Item) -> Optional[str]:
    """Return the callee's symbol text if this item transfers control externally."""
    if item.kind == sparser.KIND_MACRO and item.macro is not None:
        if item.macro.cls == macros.CODE_CALL and item.line.operands:
            return item.line.operands[0].strip()
        return None
    if item.kind != sparser.KIND_INSN or item.decoded is None:
        return None
    d = item.decoded
    if d.effect.kind in ("call", "branch") and d.operands:
        target = d.operands[-1]
        if d.classes[-1] == isa.CLS_IMM:
            return target
    return None


def probe(root: Path, port: Path) -> ProbeResult:
    st = load_symbol_tables(root, port)
    files = sparser.parse_corpus(root)

    # Every label defined anywhere in scripts/, so a cross-file jump target is
    # recognised as script code rather than reported as an unknown callee.
    #
    # And every constant the scripts define THEMSELVES: `dw_const Foo, TEXT_BAR`
    # expands to `dw Foo` + `const TEXT_BAR`, so the whole TEXT_*/SCRIPT_*
    # namespace — 379 references — is defined by the pointer tables that use it
    # and appears nowhere under constants/.
    for f in files:
        for lab in f.labels:
            st.script_labels.add(lab.name)
            st.script_labels.add(lab.qualified)
        for item in f.items:
            if item.head == "dw_const" and len(item.line.operands) >= 2:
                st.script_constants.add(item.line.operands[1].strip())

    res = ProbeResult(files=len(files))

    for f in files:
        res.total_lines += len(f.lines)
        res.includes.extend(f.includes)
        local_labels = {lab.name for lab in f.labels}

        for idx, item in enumerate(f.items):
            if not item.active:
                res.inactive_items += 1
                continue
            res.active_items += 1

            if item.kind == sparser.KIND_INSN:
                res.insn_lines += 1
                res.mnemonics[item.head.lower()] += 1
            elif item.kind == sparser.KIND_MACRO and item.macro is not None:
                res.macro_uses[item.head] += 1
                if item.macro.cls in macros.CODE_CLASSES:
                    res.code_macro_lines += 1
                else:
                    res.data_lines += 1
                if item.macro.cls == macros.TEXT_MARKER:
                    res.text_asm_bodies += 1
            elif item.kind == sparser.KIND_CONTROL:
                res.control_lines += 1
                continue

            if not item.imperative:
                _probe_data_item(item, res)
                continue

            res.imperative += 1
            reason, detail = _reason_for(item, st, local_labels, res)
            res.histogram[reason] += 1
            res.per_file[f.path][reason] += 1
            if reason != OK:
                res.sites.append(Site(item.where, reason,
                                      item.line.raw.strip(), detail))

        _branch_census(f, res)

    return res


def _probe_data_item(item: sparser.Item, res: ProbeResult) -> None:
    """Classify a data line. The only question here is Tier: a quoted glyph run
    inside a script is pret violating its own text/-vs-scripts/ split, and it
    must be routed to a generator rather than passed through as `db` bytes.
    Hand-encoded charmap bytes in a `.asm` are the port's most-repeated Tier-1
    violation, and a transpiler is a very efficient way to commit 810 of them."""
    if item.kind != sparser.KIND_MACRO or item.macro is None:
        return
    if item.macro.cls != macros.DATA_BYTES:
        res.data_histogram[item.macro.cls] += 1
        return
    if '"' in item.line.argtext:
        res.data_histogram[D_INLINE_TEXT] += 1
        res.inline_text_sites.append(
            Site(item.where, D_INLINE_TEXT, item.line.raw.strip(),
                 "quoted glyph run — must be generated, never emitted as db bytes"))
    else:
        res.data_histogram["numeric-db"] += 1


def _reason_for(item: sparser.Item, st: SymbolTables,
                local_labels: Set[str], res: ProbeResult) -> tuple[str, str]:
    ln = item.line

    if item.kind == sparser.KIND_UNKNOWN:
        return item.reason or R_UNKNOWN_MACRO, ""

    if item.kind == sparser.KIND_MACRO and item.macro is not None:
        mi = item.macro
        if mi.always_bail:
            return mi.always_bail, mi.note
        if mi.state_dependent:
            return (R_EVENT_BYTE_STATE,
                    "expansion depends on the assembly-time event_byte DEF set "
                    "by an earlier line")

    # Control transfer: record the callee, then bail on its ABI.
    target = _is_call_like(item)
    if target is not None:
        is_local = target.startswith(".") or target in local_labels
        if not is_local:
            res.callees[target] += 1
            res.callee_kind[target][item.head.lower()] += 1
            res.callee_defined.setdefault(target, target in st.port_globals)
            # abi.json is fail-closed and currently empty by construction: no
            # callee contract has been established yet, so every external
            # transfer is an open question. This is the bucket the plan predicts
            # will dominate, and its DISTINCT-callee count is the real job size.
            return R_UNKNOWN_CALLEE, f"callee {target}"

    # Screen-geometry constants used as arithmetic, not through a coord macro.
    # `ld bc, SCREEN_WIDTH * 2` is a row-stride advance, and the port's stride is
    # not pret's — the same context-dependence that makes the 16 coord-macro
    # sites unlowerable by rule. Both sites sit one line after an `hlcoord` in a
    # file already on the bail list, which is how they stayed invisible: the
    # plan's "16 lines in 5 files" counted the macro, not the arithmetic.
    if any(n in ("SCREEN_WIDTH", "SCREEN_HEIGHT", "TILEMAP_WIDTH",
                 "TILEMAP_HEIGHT", "wTileMap")
           for n in _idents(ln.argtext)):
        return R_SCREEN_STRIDE, ln.argtext

    # BANK(x) asks which ROM bank a symbol lives in. Banking is a no-op in the
    # port's flat DPMI model, but the answer is not simply "delete it": the hand
    # port renders `ld a, BANK(x)` / `ld c, a` as `mov bl, X_BANK`, so a port-side
    # bank constant has to exist for each target. And one site — SSAnneCaptainsRoom's
    # `cp BANK("Audio Engine 3")` — takes the bank of a SECTION NAME and COMPARES
    # it, which is a different question again. Neither is mechanical, so both are
    # surfaced rather than credited as ok.
    if "BANK(" in ln.argtext or "BANK (" in ln.argtext:
        return R_BANK_EXPR, ln.argtext

    # Symbol resolution over every memory operand and immediate.
    if item.kind == sparser.KIND_INSN and item.decoded is not None:
        d = item.decoded
        for cls, text in zip(d.classes, d.operands):
            if cls not in (isa.CLS_MEM, isa.CLS_IMM):
                continue
            for name in _idents(text):
                if name.startswith("."):
                    continue
                res.symbols[name] += 1
                if not st.resolves(name):
                    res.unresolved_symbols[name] += 1
                    return R_UNRESOLVED_SYM, name

        # Pointer domain. `ld hl, wCurrentMapScriptFlags` puts a GB address in
        # ESI (dereferenced `[ebp+esi]`); `ld hl, .Text` puts a HOST address in
        # ESI (dereferenced `[esi]`). Nothing in the source distinguishes them —
        # this is one of the plan's two hazards with no textual tell — so the
        # classification is recorded per site and any name that lands in BOTH
        # namespaces, or in neither, is an open question rather than a default.
        if d.mnemonic == "ld" and d.classes == (isa.CLS_R16, isa.CLS_IMM):
            text = d.operands[1]
            if text.startswith("."):
                res.pointer_domain["HOST (local label)"] += 1
            else:
                names = [n for n in _idents(text)]
                gb = [n for n in names if n in st.pret_ram]
                host = [n for n in names if n in st.script_labels
                        or n in st.pret_labels or n in st.port_globals]
                if gb and host:
                    res.pointer_domain["AMBIGUOUS (name is in both namespaces)"] += 1
                    return R_POINTER_DOMAIN, ", ".join(sorted(set(gb) & set(host)))
                if gb:
                    res.pointer_domain["GB"] += 1
                elif host:
                    res.pointer_domain["HOST"] += 1
                elif names and all(n in st.pret_constants for n in names):
                    # `ld bc, NAME_LENGTH`, `ld bc, MON_MAXHP - MON_HP`. Not a
                    # pointer at all — a byte count or a struct offset headed
                    # for a copy loop. Named separately so "0 unknown" is not
                    # bought by quietly filing counts as pointers.
                    res.pointer_domain["constant (a count or offset, not a pointer)"] += 1
                elif names:
                    res.pointer_domain["UNKNOWN"] += 1
                    return R_POINTER_DOMAIN, ", ".join(names)
                else:
                    # A bare integer: `ld hl, $1234`. Domain is whatever the
                    # dereference says, which Stage 2's propagation decides.
                    res.pointer_domain["literal (deferred to dataflow)"] += 1

    return OK, ""


def _branch_census(f: sparser.ScriptFile, res: ProbeResult) -> None:
    """Bucket every conditional branch by what wrote the flag it reads.

    Deliberately LOCAL: it walks backwards over the item list in source order
    and stops at `CENSUS_WINDOW`, with no CFG and no join points. That is the
    point — the dataflow engine Stage 2 builds must reproduce these proportions
    as an INDEPENDENT measurement. Two measurements sharing machinery agree for
    reasons that have nothing to do with either being right.

    Four buckets, and the definitions matter more than the numbers:

      adjacent               the immediately preceding instruction writes the flag
      separated              a writer is in range, only flag-transparent items between
      callee-flag-contract   the nearest candidate is a CALL, so the flag comes
                             from a callee's contract (`call GiveItem` / `jr nc`).
                             This is not a distance question at all — it is the
                             abi.json question wearing a different hat.
      cross-block            no straight-line predecessor: the walk hit an
                             unconditional transfer (the code above does not fall
                             through to here) or ran out of window

    `call` is treated as OPAQUE rather than transparent. Marking it transparent
    would let the walk read straight through `call GiveItem` and credit some
    earlier `cp` as the producer of the CF that `jr nc` actually reads from the
    callee — silently converting the corpus's most dangerous flag question into
    a clean-looking result.
    """
    items = [i for i in f.items if i.active]
    label_at = {id(i): bool(i.labels) for i in items}

    for idx, item in enumerate(items):
        cond = None
        if item.kind == sparser.KIND_INSN and item.decoded is not None:
            cond = item.decoded.condition
        if cond is None:
            continue

        flag = "z" if cond in ("z", "nz") else "c"
        bucket = "cross-block"
        distance = None
        crossed_label = False
        producer = None

        for back in range(1, CENSUS_WINDOW + 1):
            j = idx - back
            if j < 0:
                break
            prev = items[j]
            if label_at.get(id(prev)):
                crossed_label = True

            if _is_unconditional_transfer(prev):
                # Nothing above falls through to here.
                bucket = "cross-block"
                distance = back
                producer = prev.line.raw.strip()
                break

            if _is_call_like(prev) is not None:
                bucket = "callee-flag-contract"
                distance = back
                producer = prev.line.raw.strip()
                break

            writes = _writes_flag(prev, flag)
            if writes is None:
                bucket = "unmodelled-producer"
                distance = back
                producer = prev.line.raw.strip()
                break
            if writes:
                bucket = "adjacent" if back == 1 else "separated"
                distance = back
                producer = prev.line.raw.strip()
                break

        res.branch_census[bucket] += 1
        if crossed_label and bucket in ("adjacent", "separated"):
            res.branch_census["(of those, a label intervenes)"] += 1

        # Second bucketing under a deliberately CRUDER definition, kept because
        # the plan's Stage 2 acceptance gate quotes proportions (48.4 / 20.5 /
        # 31.1) whose definition was not recorded. A gate against a number that
        # cannot be reproduced is not a gate, so this variant tests the most
        # likely earlier definition: only a bare SM83 instruction counts as a
        # producer, macros and calls are skipped as if transparent, and there is
        # no unconditional-transfer stop.
        crude = "cross-block"
        for back in range(1, CENSUS_WINDOW + 1):
            j = idx - back
            if j < 0:
                break
            prev = items[j]
            if prev.kind != sparser.KIND_INSN or prev.decoded is None:
                continue
            eff = prev.decoded.effect
            if (eff.z != "-") if flag == "z" else (eff.c != "-"):
                crude = "adjacent" if back == 1 else "separated"
                break
        res.branch_census_crude[crude] += 1
        res.branch_detail.append({
            "where": item.where, "cond": cond, "flag": flag,
            "bucket": bucket, "distance": distance,
            "label_between": crossed_label,
            "producer": producer,
            "text": item.line.raw.strip(),
        })


def _is_unconditional_transfer(item: sparser.Item) -> bool:
    if item.kind == sparser.KIND_INSN and item.decoded is not None:
        d = item.decoded
        return d.effect.kind in ("branch", "ret") and d.condition is None
    if item.kind == sparser.KIND_MACRO and item.macro is not None:
        return item.head in ("predef_jump", "farjp", "jpfar", "tx_pre_jump")
    return False


def _writes_flag(item: sparser.Item, flag: str) -> Optional[bool]:
    """True/False, or None when the item's effect on `flag` is not modelled."""
    if item.kind == sparser.KIND_INSN and item.decoded is not None:
        eff = item.decoded.effect
        return (eff.z != "-") if flag == "z" else (eff.c != "-")
    if item.kind == sparser.KIND_MACRO and item.macro is not None:
        mi = item.macro
        if mi.cls in (macros.DATA_TEXT, macros.DATA_TABLE, macros.DATA_BYTES,
                      macros.TEXT_MARKER):
            # Data between two instructions means the branch and its supposed
            # producer are not even in the same stream.
            return None
        return (mi.z != "-") if flag == "z" else (mi.c != "-")
    if item.kind == sparser.KIND_CONTROL:
        return False
    return None
