#!/usr/bin/env python3
"""ir.py — regions, CFG, and the two dataflow analyses the lowering depends on.

Stage 2. Nothing here emits x86; it answers the two questions the emitter cannot
answer locally, both of which are invisible in the source text:

  1. **Is a flag live across this instruction?** SM83 `set`/`res`/`ld` write no
     flags, so pret separates a producer from its consumer freely. Their obvious
     x86 lowerings (`or`, `and`, sometimes `inc`) DO write flags. The emitter
     needs to know, per site, whether it must wrap the lowering in
     `pushfd`/`popfd` — and wrapping everything would be both noisy and a lie
     about which sites are load-bearing.
  2. **Is the pointer in HL a GB address or a host address?** `ld hl, wFoo`
     dereferences `[ebp+esi]`; `ld hl, .Text` dereferences `[esi]`. Same
     instruction shape, different memory.

REGIONS, NOT ROUTINES
---------------------
A "routine" here is a maximal fall-through-connected run of items carrying every
pret label that lands in it. `CeruleanGymMistyPostBattleScript` runs straight
into `CeruleanGymReceiveTM11` with no branch, so the two names describe one
region. Splitting at labels would emit a `ret` pret does not have — a behaviour
change with no textual tell, produced by a tidy-looking structural choice.

THE ANALYSES ARE DELIBERATELY PESSIMISTIC
-----------------------------------------
Unknown means live, and unknown means `⊤`. A flag that might be live gets
preserved; a pointer whose domain is not proven bails. Both directions cost
output — a preserved flag is two extra instructions, a bailed site is human work
— and both are cheaper than the alternative, which is a program that assembles,
runs, and quietly reads the wrong byte.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Dict, List, Optional, Sequence, Set, Tuple

import isa
import macros
import parser as sparser

# Pointer-domain lattice.
BOT = "bot"      # no value yet
GB = "GB"        # an address in the emulated GB space -> [ebp+esi]
HOST = "HOST"    # a host/link-time address -> [esi]
TOP = "top"      # two paths disagree, or it came from somewhere unmodelled


def join(a: str, b: str) -> str:
    if a == BOT:
        return b
    if b == BOT:
        return a
    return a if a == b else TOP


@dataclass
class Region:
    """A maximal fall-through-connected run of items.

    `is_data` marks a run of table/text-stream bytes rather than instructions.
    Data regions are emitted too — not because the transpiler owns the data, but
    because the CODE references their labels, and a label that is neither
    defined nor `extern` is an ASSEMBLY error, which is a different and much
    less useful failure than the intended link error.
    """

    file: str
    items: List[sparser.Item]
    labels: List[str] = field(default_factory=list)   # every pret label inside
    entry_labels: List[str] = field(default_factory=list)  # labels at the head
    is_data: bool = False

    @property
    def name(self) -> str:
        return self.entry_labels[0] if self.entry_labels else f"{self.file}:anon"


@dataclass
class Analysis:
    """Per-item results, keyed by the item's identity."""

    #: item id -> set of flags ("z"/"c") that some later reader may read before
    #: any writer overwrites them.
    live_flags: Dict[int, Set[str]] = field(default_factory=dict)
    #: item id -> pointer domain of HL on ENTRY to the item.
    hl_domain: Dict[int, str] = field(default_factory=dict)
    #: item id -> True when AL is read after this item before being written.
    a_live_after: Dict[int, bool] = field(default_factory=dict)
    #: branches whose flag has no modelled producer on some path.
    unresolved_branches: List[Tuple[str, str]] = field(default_factory=list)
    #: census, comparable with the Stage 0 local walk.
    census: Dict[str, int] = field(default_factory=dict)


def build_regions(f: sparser.ScriptFile) -> List[Region]:
    """Split a file into regions at every point where control cannot fall through.

    The cut is made AFTER an unconditional transfer (`jp`, `jr`, `ret`,
    `predef_jump`, `farjp`), never at a label — see the module docstring.
    """
    regions: List[Region] = []
    cur: List[sparser.Item] = []
    # Labels waiting to be attached to the next code item. `text_asm` is the
    # data->code seam and carries the routine's NAME: pret writes
    # `PewterMartYoungsterText:` / `text_asm` / <code>, so the label sits on the
    # marker, not on the first instruction. Dropping the marker without carrying
    # its labels would emit an anonymous routine and lose the pret name that the
    # text table dispatches through.
    carry: List[str] = []

    data: List[sparser.Item] = []

    def flush():
        if not cur:
            return
        labels = [l for it in cur for l in it.labels]
        entry = list(cur[0].labels)
        regions.append(Region(f.path, list(cur), labels, entry))
        cur.clear()

    def flush_data():
        if not data:
            return
        labels = [l for it in data for l in it.labels]
        entry = list(data[0].labels)
        regions.append(Region(f.path, list(data), labels, entry, is_data=True))
        data.clear()

    for item in f.items:
        if not item.active or item.kind == sparser.KIND_CONTROL:
            continue
        if item.kind == sparser.KIND_MACRO and item.macro is not None:
            if item.macro.cls == macros.TEXT_MARKER:
                # TX_START_ASM itself is a byte in a TEXT stream, which
                # gen_npc_dialogs.py owns. Here it only means "code starts now".
                flush()
                flush_data()
                carry = list(item.labels)
                continue
            # A data item (text stream / table) ends any code region: bytes are
            # not instructions and control does not flow through them.
            if item.macro.cls in macros.DATA_CLASSES:
                flush()
                if carry:
                    item.labels = carry + list(item.labels)
                    carry = []
                data.append(item)
                continue
        flush_data()
        if carry:
            item.labels = carry + list(item.labels)
            carry = []
        cur.append(item)
        if _terminates(item):
            flush()
    flush()
    flush_data()
    return regions


def _terminates(item: sparser.Item) -> bool:
    if item.kind == sparser.KIND_INSN and item.decoded is not None:
        d = item.decoded
        return d.effect.kind in ("branch", "ret") and d.condition is None
    if item.kind == sparser.KIND_MACRO and item.macro is not None:
        return item.head in ("predef_jump", "farjp", "jpfar", "tx_pre_jump")
    return False


# ---------------------------------------------------------------------------
# CFG over one file
# ---------------------------------------------------------------------------

def _label_index(items: Sequence[sparser.Item]) -> Dict[str, int]:
    out: Dict[str, int] = {}
    for i, it in enumerate(items):
        for lab in it.labels:
            out.setdefault(lab, i)
            # local labels are referenced by their bare spelling too
            if "." in lab:
                out.setdefault("." + lab.split(".")[-1], i)
    return out


def _successors(items: Sequence[sparser.Item], i: int,
                labels: Dict[str, int]) -> List[int]:
    it = items[i]
    fall = i + 1 if i + 1 < len(items) else None
    if it.kind != sparser.KIND_INSN or it.decoded is None:
        return [fall] if fall is not None else []
    d = it.decoded
    if d.effect.kind == "ret":
        return [fall] if (d.condition and fall is not None) else []
    if d.effect.kind in ("branch", "call"):
        target = d.operands[-1] if d.classes and d.classes[-1] == isa.CLS_IMM else None
        tgt = labels.get(target) if target else None
        if d.effect.kind == "call":
            # A call returns, so the successor is the next item; the callee is
            # analysed separately (or, more honestly, not at all — see abi.json).
            return [fall] if fall is not None else []
        out = []
        if tgt is not None:
            out.append(tgt)
        elif target is not None and not target.startswith("."):
            pass  # a jump out of the file: leaves this CFG
        if d.condition and fall is not None:
            out.append(fall)
        return out
    return [fall] if fall is not None else []


def analyse(f: sparser.ScriptFile, resolver=None) -> Analysis:
    items = [it for it in f.items
             if it.active and it.kind != sparser.KIND_CONTROL
             and not (it.kind == sparser.KIND_MACRO and it.macro is not None
                      and it.macro.cls in macros.DATA_CLASSES)]
    labels = _label_index(items)
    an = Analysis()
    n = len(items)
    succ = [_successors(items, i, labels) for i in range(n)]
    pred: List[List[int]] = [[] for _ in range(n)]
    for i, ss in enumerate(succ):
        for s in ss:
            if s is not None and 0 <= s < n:
                pred[s].append(i)

    # --- backward flag liveness -------------------------------------------
    # live-out[i] = union over successors of live-in[s]
    # live-in[i]  = (live-out[i] - written[i]) + read[i]
    live_in: List[Set[str]] = [set() for _ in range(n)]
    changed = True
    while changed:
        changed = False
        for i in range(n - 1, -1, -1):
            out: Set[str] = set()
            for s in succ[i]:
                if s is not None and 0 <= s < n:
                    out |= live_in[s]
            reads, writes = _flag_use(items[i])
            new = (out - writes) | reads
            if new != live_in[i]:
                live_in[i] = new
                changed = True
    for i in range(n):
        out = set()
        for s in succ[i]:
            if s is not None and 0 <= s < n:
                out |= live_in[s]
        an.live_flags[id(items[i])] = out

    # --- forward pointer-domain propagation over HL ------------------------
    dom_in: List[str] = [BOT] * n
    # Entry points (a label with no fall-through predecessor) start at TOP: the
    # caller decided what is in HL and we cannot see the caller.
    for i in range(n):
        if not pred[i]:
            dom_in[i] = TOP
    changed = True
    guard = 0
    while changed and guard < 10000:
        guard += 1
        changed = False
        for i in range(n):
            d = _domain_out(items[i], dom_in[i], resolver)
            for s in succ[i]:
                if s is None or not (0 <= s < n):
                    continue
                merged = join(dom_in[s], d)
                if merged != dom_in[s]:
                    dom_in[s] = merged
                    changed = True
    for i in range(n):
        an.hl_domain[id(items[i])] = dom_in[i]

    # --- is AL read before it is written, after each item? -----------------
    # Used for one specific question: pret's `predef` leaves the predef id in A,
    # and the port's direct-call lowering does not. If A is dead after the call
    # that is harmless; if it is live, the lowering is wrong and must bail.
    a_live_in = [False] * n
    changed = True
    while changed:
        changed = False
        for i in range(n - 1, -1, -1):
            out = False
            for s in succ[i]:
                if s is not None and 0 <= s < n and a_live_in[s]:
                    out = True
            reads_a, writes_a = _a_use(items[i])
            new = reads_a or (out and not writes_a)
            if new != a_live_in[i]:
                a_live_in[i] = new
                changed = True
    for i in range(n):
        out = False
        for s in succ[i]:
            if s is not None and 0 <= s < n and a_live_in[s]:
                out = True
        an.a_live_after[id(items[i])] = out

    _census(items, succ, pred, an)
    return an


def _flag_use(item: sparser.Item) -> Tuple[Set[str], Set[str]]:
    """(flags this item READS, flags this item WRITES)."""
    reads: Set[str] = set()
    writes: Set[str] = set()
    if item.kind == sparser.KIND_INSN and item.decoded is not None:
        d = item.decoded
        if d.condition:
            reads.add("z" if d.condition in ("z", "nz") else "c")
        eff = d.effect
        if eff.z != "-":
            writes.add("z")
        if eff.c != "-":
            writes.add("c")
        if eff.kind == "call":
            # A callee may return a flag and may clobber both. Neither is
            # knowable here, so nothing is credited as preserved: writes stay
            # empty, which keeps anything live ACROSS the call live, and the
            # emitter is told to ask abi.json.
            writes.clear()
        return reads, writes
    if item.kind == sparser.KIND_MACRO and item.macro is not None:
        mi = item.macro
        if mi.z != "-":
            writes.add("z")
        if mi.c != "-":
            writes.add("c")
        if mi.cls == macros.CODE_CALL:
            writes.clear()
    return reads, writes


def _a_use(item: sparser.Item) -> Tuple[bool, bool]:
    """(reads AL, writes AL)."""
    if item.kind == sparser.KIND_INSN and item.decoded is not None:
        d = item.decoded
        reads = "a" in d.effect.reads or (
            d.mnemonic in ("ld", "ldh") and len(d.operands) > 1
            and d.operands[1] == "a")
        writes = "a" in d.effect.writes or (
            d.mnemonic in ("ld", "ldh") and d.operands and d.operands[0] == "a")
        if d.mnemonic in ("inc", "dec") and d.operands and d.operands[0] == "a":
            reads = writes = True
        if d.mnemonic in ("cp", "bit") and "a" in d.operands:
            reads = True
        if d.mnemonic == "xor" and d.operands and d.operands[0] == "a":
            reads, writes = False, True   # `xor a` is a zeroing idiom
        if d.effect.kind == "call":
            # Conservative both ways: a callee may consume A and may return one.
            return True, True
        return reads, writes
    if item.kind == sparser.KIND_MACRO and item.macro is not None:
        mi = item.macro
        if mi.cls == macros.CODE_CALL:
            return True, True
        return False, "a" in mi.clobbers
    return False, False


def _domain_out(item: sparser.Item, dom_in: str, resolver) -> str:
    """The domain of HL after this item, given its domain before."""
    if item.kind == sparser.KIND_INSN and item.decoded is not None:
        d = item.decoded
        if d.mnemonic == "ld" and d.classes == (isa.CLS_R16, isa.CLS_IMM) \
                and d.operands[0] == "hl":
            return _domain_of_immediate(d.operands[1], resolver)
        if d.mnemonic in ("inc", "dec") and d.operands and d.operands[0] == "hl":
            return dom_in
        if d.mnemonic == "ld" and d.classes and d.classes[0] == isa.CLS_MEMHLI:
            return dom_in
        if d.mnemonic == "add" and d.operands and d.operands[0] == "hl":
            return dom_in
        if d.mnemonic == "pop" and d.operands and d.operands[0] == "hl":
            return TOP
        if d.effect.kind == "call":
            return TOP     # the callee may have loaded HL
        if d.mnemonic == "ld" and d.operands and d.operands[0] in ("h", "l"):
            return TOP     # a half-load: the pair is now half-known
        return dom_in
    if item.kind == sparser.KIND_MACRO and item.macro is not None:
        mi = item.macro
        if "hl" in mi.clobbers:
            # Every event macro that touches HL points it at wEventFlags.
            return GB if mi.cls == macros.CODE_EVENT else TOP
        if mi.cls == macros.CODE_CALL:
            return TOP
        return dom_in
    return dom_in


def _domain_of_immediate(text: str, resolver) -> str:
    if text.startswith("."):
        return HOST
    # `ld bc, EndLabel - StartLabel` is a SIZE, not a pointer: label arithmetic
    # yields a count. Classifying it as HOST made four `CopyData` byte-counts
    # look like 32-bit pointers being stuffed into BX.
    if any(op in text for op in ("-", "+", "*", "/")) and len(_ident_list(text)) > 1:
        return TOP
    if resolver is None:
        return TOP
    names = [t for t in _ident_list(text)]
    if not names:
        return TOP          # a bare literal: the dereference decides, not us
    gb = host = False
    for n in names:
        r = resolver.resolve(n)
        if r is None:
            return TOP
        if r.kind == "ram":
            gb = True
        elif r.kind in ("label", "script-local"):
            host = True
    if gb and not host:
        return GB
    if host and not gb:
        return HOST
    return TOP


import re as _re
_IDENT_RE = _re.compile(r"(?<![\w.$%])[A-Za-z_][A-Za-z0-9_]*")


def _ident_list(text: str):
    out = []
    for m in _IDENT_RE.finditer(_re.sub(r'"[^"]*"', '""', text)):
        tok = m.group(0)
        if tok.lower() in isa.R8 or tok.lower() in isa.R16:
            continue
        if tok in ("BANK", "HIGH", "LOW"):
            continue
        out.append(tok)
    return out


def _census(items, succ, pred, an: Analysis) -> None:
    """The Stage 2 acceptance census, over the same buckets as Stage 0.

    Same definitions, computed from the CFG instead of a straight-line backward
    walk. Where they disagree, the CFG is right and the disagreement is the
    interesting number: it counts branches whose apparent producer is not
    actually on every path into them.
    """
    counts = {"adjacent": 0, "separated": 0, "callee-flag-contract": 0,
              "cross-block": 0, "multiple-producers": 0}
    for i, it in enumerate(items):
        if it.kind != sparser.KIND_INSN or it.decoded is None:
            continue
        cond = it.decoded.condition
        if cond is None:
            continue
        flag = "z" if cond in ("z", "nz") else "c"
        producers = _find_producers(items, pred, i, flag)
        if not producers:
            counts["cross-block"] += 1
            an.unresolved_branches.append((it.where, cond))
        elif len(producers) > 1:
            counts["multiple-producers"] += 1
        else:
            j, kind = producers[0]
            if kind == "call":
                counts["callee-flag-contract"] += 1
            elif j == i - 1:
                counts["adjacent"] += 1
            else:
                counts["separated"] += 1
    an.census = counts


def _find_producers(items, pred, i: int, flag: str, depth: int = 0,
                    seen=None) -> List[Tuple[int, str]]:
    """Walk predecessors until each path reaches a writer of `flag`."""
    if seen is None:
        seen = set()
    out: List[Tuple[int, str]] = []
    stack = [(p, 0) for p in pred[i]]
    while stack:
        j, d = stack.pop()
        if j in seen or d > 24:
            continue
        seen.add(j)
        it = items[j]
        if it.kind == sparser.KIND_INSN and it.decoded is not None \
                and it.decoded.effect.kind == "call":
            out.append((j, "call"))
            continue
        if it.kind == sparser.KIND_MACRO and it.macro is not None \
                and it.macro.cls == macros.CODE_CALL:
            out.append((j, "call"))
            continue
        _, writes = _flag_use(it)
        if flag in writes:
            out.append((j, "insn"))
            continue
        for p in pred[j]:
            stack.append((p, d + 1))
    # Deduplicate on the producing index, keeping "call" if any path saw one.
    best: Dict[int, str] = {}
    for j, kind in out:
        best[j] = kind if kind == "call" else best.get(j, kind)
    return sorted(best.items())
