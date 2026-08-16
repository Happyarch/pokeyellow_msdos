#!/usr/bin/env python3
"""parser.py — structure over the lexed lines of one pret `scripts/*.asm`.

Adds the three things the lexer deliberately does not know:

1. **Which lines are actually in the build.** `scripts/` carries column-0
   `IF DEF(_DEBUG)` and `IF DEF(_YELLOW_VC)` blocks. The port builds neither
   symbol, so those bodies are dead code — but they are still parsed and still
   reported, marked inactive. Silently dropping them would understate the corpus
   and hide a `_YELLOW_VC` body that differs from the one we translate.

2. **Label scope.** A local label (`.BagFull`) belongs to the last global label
   above it, and pret reuses `.Text` in dozens of files. Every label is
   qualified here so downstream stages can key on a name that is unique
   tree-wide, while the emitted output keeps pret's spelling (Preserve pret
   Labels).

3. **What each item IS.** Every ITEM line is resolved against isa.py and
   macros.py into one `Item` carrying its decode or its macro row — or neither,
   which is a bail with a reason, never a pass-through.

FALL-THROUGH IS FIRST-CLASS
---------------------------
`CeruleanGymMistyPostBattleScript` runs straight into `CeruleanGymReceiveTM11`
with no branch between them, so the two pret labels name one region of code.
The parser therefore never treats a label as a routine boundary; it records
labels as annotations on a line, and the region structure is built on top in a
later stage. Splitting at labels would emit a `ret` pret does not have.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Sequence

import isa
import lexer
import macros

# Symbols the port's build does NOT define. `_DEBUG` gates pret's debug hooks
# and `_YELLOW_VC` gates the Virtual Console patches; the port builds the plain
# retail ROM, so both are absent and the ELSE branch is the live one.
BUILD_DEFINES: frozenset = frozenset()

# What an item is, at the granularity the coverage counter reports.
KIND_INSN = "insn"        # a decoded SM83 instruction
KIND_MACRO = "macro"      # a classified macro invocation
KIND_CONTROL = "control"  # assembler control that emits nothing
KIND_UNKNOWN = "unknown"  # neither — a bail, with `reason` set


@dataclass
class Item:
    line: lexer.Line
    kind: str
    decoded: Optional[isa.Decoded] = None
    macro: Optional[macros.MacroInfo] = None
    reason: Optional[str] = None      # set when kind == KIND_UNKNOWN
    labels: List[str] = field(default_factory=list)  # labels attached above it

    @property
    def head(self) -> str:
        return self.line.head or ""

    @property
    def where(self) -> str:
        return self.line.where

    @property
    def active(self) -> bool:
        return self.line.active

    @property
    def imperative(self) -> bool:
        """True when this item contributes executable code to the build.

        The definition is stated rather than assumed because the corpus's
        headline "imperative lines" figure depends entirely on where this line
        is drawn — see coverage.md, which reports the decomposition instead of a
        bare total.
        """
        if not self.line.active:
            return False
        if self.kind == KIND_INSN:
            return True
        if self.kind == KIND_MACRO and self.macro is not None:
            return self.macro.cls in macros.CODE_CLASSES
        if self.kind == KIND_UNKNOWN:
            # An unrecognised head could be either. Counted as imperative so the
            # coverage denominator can never be flattered by a parse gap.
            return True
        return False


@dataclass
class LabelDef:
    name: str            # as pret spells it, e.g. ".BagFull"
    qualified: str       # "CeruleanGymReceiveTM11.BagFull"
    file: str
    lineno: int
    local: bool
    exported: bool
    scope: Optional[str]


@dataclass
class ScriptFile:
    path: str
    lines: List[lexer.Line]
    items: List[Item]
    labels: List[LabelDef]
    conditional_blocks: int = 0
    inactive_lines: int = 0
    includes: List[str] = field(default_factory=list)


def _eval_if(argtext: str, defines: frozenset) -> Optional[bool]:
    """Evaluate the conditional forms that actually occur in `scripts/`.

    Only `DEF(x)` and `!DEF(x)` appear (measured). Anything else returns None,
    which the caller turns into a hard parse error rather than a guess — a
    mis-evaluated conditional silently swaps which of two program texts gets
    translated, and neither side would look wrong in review.
    """
    t = argtext.strip()
    negate = False
    if t.startswith("!"):
        negate, t = True, t[1:].strip()
    if t.upper().startswith("DEF") and t.endswith(")") and "(" in t:
        name = t[t.index("(") + 1:-1].strip()
        val = name in defines
        return (not val) if negate else val
    return None


def parse_file(path: Path, root: Path, defines: frozenset = BUILD_DEFINES) -> ScriptFile:
    lines = lexer.lex_file(path, root)
    rel = str(path.relative_to(root))

    items: List[Item] = []
    labels: List[LabelDef] = []
    pending: List[str] = []
    scope: Optional[str] = None
    includes: List[str] = []

    # Conditional stack: (this_branch_live, any_branch_taken_yet, parent_live)
    cond: List[list] = []
    n_blocks = 0

    def live() -> bool:
        return all(fr[0] for fr in cond)

    for ln in lines:
        ln.active = live()

        if ln.kind in (lexer.BLANK, lexer.COMMENT):
            continue

        if ln.kind == lexer.DIRECTIVE:
            head = ln.head or ""
            if head == "IF":
                n_blocks += 1
                val = _eval_if(ln.argtext, defines)
                if val is None:
                    raise lexer.LexError(ln, f"unmodelled IF condition: {ln.argtext!r}")
                parent = live()
                cond.append([parent and val, val, parent])
                continue
            if head == "ELIF":
                if not cond:
                    raise lexer.LexError(ln, "ELIF without IF")
                val = _eval_if(ln.argtext, defines)
                if val is None:
                    raise lexer.LexError(ln, f"unmodelled ELIF condition: {ln.argtext!r}")
                fr = cond[-1]
                fr[0] = fr[2] and (not fr[1]) and val
                fr[1] = fr[1] or val
                continue
            if head == "ELSE":
                if not cond:
                    raise lexer.LexError(ln, "ELSE without IF")
                fr = cond[-1]
                fr[0] = fr[2] and not fr[1]
                fr[1] = True
                continue
            if head == "ENDC":
                if not cond:
                    raise lexer.LexError(ln, "ENDC without IF")
                cond.pop()
                continue
            if head == "INCLUDE":
                # RocketHideoutB2F pulls in engine/overworld/spinners.asm, which
                # is engine/ code and therefore NOT this tool's output. Recorded
                # so the omission is visible rather than silent.
                includes.append(ln.argtext.strip().strip('"'))
                items.append(Item(ln, KIND_CONTROL, labels=pending))
                pending = []
                continue
            # Other column-0 control (EXPORT/ASSERT/...) emits nothing.
            items.append(Item(ln, KIND_CONTROL, labels=pending))
            pending = []
            continue

        if ln.kind == lexer.LABEL:
            name = ln.label or ""
            if name.startswith("."):
                qualified = f"{scope}{name}" if scope else name
            else:
                qualified = name
                scope = name
            ln.scope = scope
            labels.append(LabelDef(name, qualified, rel, ln.lineno,
                                   ln.local, ln.exported, scope))
            pending.append(qualified)
            continue

        # ITEM
        ln.scope = scope
        head = ln.head or ""
        item = _classify_item(ln)
        item.labels = pending
        pending = []
        items.append(item)

    if cond:
        raise lexer.LexError(rel, f"{len(cond)} unterminated IF block(s)")

    inactive = sum(1 for l in lines if not l.active and l.kind in (lexer.ITEM, lexer.LABEL))
    return ScriptFile(rel, lines, items, labels, n_blocks, inactive, includes)


def _classify_item(ln: lexer.Line) -> Item:
    head = ln.head or ""
    lo = head.lower()

    if lo in isa.KNOWN_MNEMONICS:
        dec = isa.decode(lo, ln.operands)
        if dec is None:
            return Item(ln, KIND_UNKNOWN, reason="unknown-operand-shape")
        return Item(ln, KIND_INSN, decoded=dec)

    info = macros.lookup(head, len(ln.operands))
    if info is None:
        if macros.known(head):
            return Item(ln, KIND_UNKNOWN, reason="macro-arity-unmodelled")
        return Item(ln, KIND_UNKNOWN, reason="unknown-macro")
    if info.cls == macros.CONTROL:
        return Item(ln, KIND_CONTROL, macro=info)
    return Item(ln, KIND_MACRO, macro=info)


def parse_corpus(root: Path, subdir: str = "scripts",
                 defines: frozenset = BUILD_DEFINES) -> List[ScriptFile]:
    return [parse_file(p, root, defines)
            for p in sorted((root / subdir).glob("*.asm"))]
