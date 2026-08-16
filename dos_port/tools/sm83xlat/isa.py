#!/usr/bin/env python3
"""isa.py — the SM83 instruction table for the subset pret's `scripts/` uses.

This table is the tool's set of AXIOMS. Every later stage — the CFG, the flag
liveness, the lowering, the differential oracle — is downstream of it, so a
single wrong row is wrong across all 251 files at once. It is therefore written
to be *enumerated and hand-reviewable* rather than derived, and each row states
its flag effects explicitly instead of leaving them implied.

SCOPE, MEASURED
---------------
`scripts/` uses 23 distinct instruction mnemonics and 40 `ld` operand shapes.
`daa`, `cpl`, `rst`, `halt`, `di`, `ei` and `add sp, e8` never occur. Anything
outside the table is a BAIL (`unknown-operand-shape`), never a guess: an
unrecognised shape that got lowered "plausibly" is exactly the failure mode the
whole design is built to make impossible.

THE FLAG COLUMN IS THE POINT
----------------------------
x86 sets flags on different instructions than SM83 does, so a translation that
is correct instruction-by-instruction can still break a branch by writing a flag
the SM83 form left alone. Two effects carry the load here:

  * `res` / `set` / `ld` are **flag-transparent** on SM83. `CeruleanGym_Script`
    relies on exactly that — `bit` sets ZF, `res` leaves it, and `call nz` two
    lines later still reads the `bit`. The obvious x86 `and byte [...], ~MASK`
    writes ZF and destroys it.
  * `bit` writes Z and H and N but leaves **C** alone, while x86 `test` clears
    CF. Asymmetries like that one are why each flag gets its own cell rather
    than a single "writes flags" boolean.

Cell values:
    "-"  unaffected      "0" reset      "1" set      "*" computed from result
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Dict, Optional, Tuple

R8 = {"a", "b", "c", "d", "e", "h", "l"}
R16 = {"bc", "de", "hl", "sp", "af"}
CONDITIONS = {"z", "nz", "c", "nc"}
MEM_R16 = {"[hl]", "[hli]", "[hld]", "[hl+]", "[hl-]", "[bc]", "[de]"}

# Operand classes used as table keys.
CLS_R8 = "r8"
CLS_R16 = "r16"
CLS_MEMHL = "[hl]"
CLS_MEMHLI = "[hli]"
CLS_MEMBCDE = "[r16]"
CLS_MEM = "[n]"       # absolute memory operand, e.g. [wFoo], [wEventFlags + 3]
CLS_IMM = "n"         # immediate / expression / label
CLS_COND = "cc"


def classify_operand(op: str) -> Tuple[str, str]:
    """Return (class, normalised text) for one operand.

    Condition codes are ambiguous with register `c` by spelling alone, so the
    caller resolves that from position: only the first operand of a branch can
    be a condition. This function reports register `c` and leaves the
    disambiguation to `decode`.
    """
    t = op.strip()
    lo = t.lower()
    if lo in R8:
        return CLS_R8, lo
    if lo in R16:
        return CLS_R16, lo
    if lo in ("[hl]",):
        return CLS_MEMHL, lo
    if lo in ("[hli]", "[hl+]"):
        return CLS_MEMHLI, "[hli]"
    if lo in ("[hld]", "[hl-]"):
        return CLS_MEMHLI, "[hld]"
    if lo in ("[bc]", "[de]"):
        return CLS_MEMBCDE, lo
    if t.startswith("[") and t.endswith("]"):
        return CLS_MEM, t[1:-1].strip()
    return CLS_IMM, t


@dataclass(frozen=True)
class Effect:
    """What one instruction form does, at the granularity later stages need."""

    z: str      # "-" unaffected, "0", "1", "*" computed
    n: str
    h: str
    c: str
    kind: str   # move / alu / bitop / branch / call / ret / stack / nop / data
    # Registers whose VALUE this form writes. "a", "hl", "mem", "sp", ...
    writes: Tuple[str, ...] = ()
    reads: Tuple[str, ...] = ()
    # True when a later branch may legitimately read a flag written before this
    # instruction — i.e. the form writes no flag at all.
    @property
    def flag_transparent(self) -> bool:
        return self.z == "-" and self.n == "-" and self.h == "-" and self.c == "-"

    @property
    def writes_z(self) -> bool:
        return self.z != "-"

    @property
    def writes_c(self) -> bool:
        return self.c != "-"


def _e(z, n, h, c, kind, writes=(), reads=()):
    return Effect(z, n, h, c, kind, tuple(writes), tuple(reads))


# --------------------------------------------------------------------------
# The table. Key: (mnemonic, tuple-of-operand-classes).
# --------------------------------------------------------------------------
# Loads and stores. All flag-transparent — this is load-bearing, not incidental:
# pret separates a flag producer from its consumer with `ld` constantly, and a
# lowering that clobbers a flag here breaks branches with no textual tell.
_LD_MOVE = _e("-", "-", "-", "-", "move")

TABLE: Dict[Tuple[str, Tuple[str, ...]], Effect] = {}


def _row(mnemonic: str, classes: Tuple[str, ...], eff: Effect) -> None:
    TABLE[(mnemonic, classes)] = eff


# ---- ld ------------------------------------------------------------------
for _dst, _src in [
    (CLS_R8, CLS_IMM), (CLS_R8, CLS_R8), (CLS_R8, CLS_MEM),
    (CLS_R8, CLS_MEMHL), (CLS_R8, CLS_MEMHLI), (CLS_R8, CLS_MEMBCDE),
    (CLS_R16, CLS_IMM),
    (CLS_MEM, CLS_R8), (CLS_MEMHL, CLS_R8), (CLS_MEMHLI, CLS_R8),
    (CLS_MEMBCDE, CLS_R8), (CLS_MEMHL, CLS_IMM),
]:
    _row("ld", (_dst, _src), _LD_MOVE)

# `ldh` is the $FF00-page load/store. Same semantics as `ld` for our purposes;
# the HRAM-vs-WRAM distinction matters to the symbol mapping, not to flags.
_row("ldh", (CLS_R8, CLS_MEM), _LD_MOVE)
_row("ldh", (CLS_MEM, CLS_R8), _LD_MOVE)

# ---- 8-bit ALU -----------------------------------------------------------
# xor/or reset C and H; and sets H and resets C; all three set Z from the result.
for _m, _eff in (("xor", ("*", "0", "0", "0")), ("or", ("*", "0", "0", "0")),
                 ("and", ("*", "0", "1", "0"))):
    for _cls in (CLS_R8, CLS_IMM, CLS_MEMHL):
        _row(_m, (_cls,), _e(*_eff, "alu", writes=("a",), reads=("a",)))

# add/adc/sub/sbc set every flag; cp is sub with the result discarded, which is
# why `cp` is the corpus's dominant comparison and maps to x86 `cmp` cleanly.
for _m, _n in (("add", "0"), ("adc", "0"), ("sub", "1"), ("sbc", "1")):
    for _cls in (CLS_R8, CLS_IMM, CLS_MEMHL):
        _row(_m, (_cls,), _e("*", _n, "*", "*", "alu", writes=("a",), reads=("a",)))
for _cls in (CLS_R8, CLS_IMM, CLS_MEMHL):
    _row("cp", (_cls,), _e("*", "1", "*", "*", "alu", reads=("a",)))

# 16-bit add leaves Z ALONE. A lowering that uses x86 `add esi, edx` writes ZF
# and would break any branch reading a Z set before it.
_row("add", (CLS_R16, CLS_R16), _e("-", "0", "*", "*", "alu", writes=("hl",), reads=("hl",)))

# inc/dec on an 8-bit register or [hl] preserve C but write Z. The C-preserving
# property is what lets pret step a pointer inside a borrow chain; x86 inc/dec
# happen to preserve CF too, which is the one place the two architectures agree
# for free.
for _cls in (CLS_R8, CLS_MEMHL):
    _row("inc", (_cls,), _e("*", "0", "*", "-", "alu"))
    _row("dec", (_cls,), _e("*", "1", "*", "-", "alu"))
# 16-bit inc/dec touch nothing at all.
_row("inc", (CLS_R16,), _e("-", "-", "-", "-", "alu"))
_row("dec", (CLS_R16,), _e("-", "-", "-", "-", "alu"))

# ---- rotates / shifts ----------------------------------------------------
for _m in ("srl", "sla", "sra", "rr", "rl", "rrc", "rlc"):
    for _cls in (CLS_R8, CLS_MEMHL):
        _row(_m, (_cls,), _e("*", "0", "0", "*", "alu"))
# `swap` sets Z and clears C. x86 `rol r8, 4` sets neither, so this row is one
# of the three asymmetric cases the lowering has to repair explicitly.
for _cls in (CLS_R8, CLS_MEMHL):
    _row("swap", (_cls,), _e("*", "0", "0", "0", "alu"))
_row("scf", (), _e("-", "0", "0", "1", "alu"))
_row("ccf", (), _e("-", "0", "0", "*", "alu"))

# ---- bit ops -------------------------------------------------------------
# bit: writes Z (and N, H), PRESERVES C.  set/res: write NOTHING.
for _cls in (CLS_R8, CLS_MEMHL):
    _row("bit", (CLS_IMM, _cls), _e("*", "0", "1", "-", "bitop"))
    _row("set", (CLS_IMM, _cls), _e("-", "-", "-", "-", "bitop"))
    _row("res", (CLS_IMM, _cls), _e("-", "-", "-", "-", "bitop"))

# ---- control flow --------------------------------------------------------
# Branches consume flags and write none.
_row("jp", (CLS_IMM,), _e("-", "-", "-", "-", "branch"))
_row("jp", (CLS_COND, CLS_IMM), _e("-", "-", "-", "-", "branch"))
_row("jp", (CLS_R16,), _e("-", "-", "-", "-", "branch"))     # jp hl
_row("jr", (CLS_IMM,), _e("-", "-", "-", "-", "branch"))
_row("jr", (CLS_COND, CLS_IMM), _e("-", "-", "-", "-", "branch"))
_row("call", (CLS_IMM,), _e("-", "-", "-", "-", "call"))
_row("call", (CLS_COND, CLS_IMM), _e("-", "-", "-", "-", "call"))
_row("ret", (), _e("-", "-", "-", "-", "ret"))
_row("ret", (CLS_COND,), _e("-", "-", "-", "-", "ret"))
_row("reti", (), _e("-", "-", "-", "-", "ret"))

# ---- stack ---------------------------------------------------------------
# `pop af` RESTORES all four flags — it is a flag WRITER, and the only stack
# form that is. Treating push/pop uniformly as transparent would let a branch
# read a flag that `pop af` overwrote.
_row("push", (CLS_R16,), _e("-", "-", "-", "-", "stack"))
_row("pop", (CLS_R16,), _e("-", "-", "-", "-", "stack"))
TABLE[("pop", (CLS_R16,) + ("af",))] = _e("*", "*", "*", "*", "stack")


@dataclass(frozen=True)
class Decoded:
    mnemonic: str
    classes: Tuple[str, ...]
    operands: Tuple[str, ...]      # normalised operand text
    effect: Effect
    condition: Optional[str] = None   # "z"/"nz"/"c"/"nc" for a conditional form


def decode(mnemonic: str, operands) -> Optional[Decoded]:
    """Decode one instruction. Returns None when the form is not in the table.

    None is a BAIL signal (`unknown-operand-shape`), never a licence to
    approximate.
    """
    m = mnemonic.lower()
    ops = [o.strip() for o in operands]
    classes = []
    norm = []
    condition = None

    for i, op in enumerate(ops):
        cls, text = classify_operand(op)
        # Condition codes only ever occupy the first operand of jp/jr/call/ret,
        # which is what disentangles `jr c, .foo` (carry) from register `c`.
        if i == 0 and m in ("jp", "jr", "call", "ret") and text.lower() in CONDITIONS:
            if m == "ret" or len(ops) > 1:
                cls, text = CLS_COND, text.lower()
                condition = text
        classes.append(cls)
        norm.append(text)

    key = (m, tuple(classes))
    # `pop af` is the one form whose flag effect depends on the register.
    if m == "pop" and norm and norm[0] == "af":
        eff = TABLE[("pop", (CLS_R16, "af"))]
    else:
        eff = TABLE.get(key)
    if eff is None:
        return None
    return Decoded(m, tuple(classes), tuple(norm), eff, condition)


# Mnemonics the corpus is known to contain. A mnemonic outside this set is not
# necessarily wrong — it is unmeasured, and gets a bail rather than a lowering.
KNOWN_MNEMONICS = {
    "ld", "ldh", "call", "ret", "jp", "jr", "xor", "cp", "and", "or", "bit",
    "set", "res", "push", "pop", "inc", "dec", "add", "sub", "adc", "swap",
    "srl", "scf",
}
