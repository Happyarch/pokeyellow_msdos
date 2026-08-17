#!/usr/bin/env python3
"""emit.py — the lowering table and the NASM emitter.

Stage 3. The lowering is a table, small enough to read end to end, because
rule 1 of the plan (flag exactness) makes any clever, general scheme
unreviewable. Each row states what it emits and, where the two architectures
disagree about flags, what it does about it.

THREE STRUCTURAL INVARIANTS, ENFORCED AFTER EMISSION
----------------------------------------------------
* **No widening instruction is emitted at all.** The register map already gives
  an 8-bit name to every GB register (AL, BH, BL, DH, DL), so a site that looks
  like it needs `movzx` is a site the tool misunderstood. Asserting the absence
  of the instruction makes the project's most-repeated defect — a widened loop
  counter turning a bounded 256-iteration wrap into a 4-billion-iteration page
  fault — inexpressible rather than merely avoided.
* **No zero-guard is synthesizable.** No path emits `test r,r / jz` around a
  loop. The `DelayFrames` regression was a guard that got *added*; a tool with
  no way to add one cannot reproduce it.
* **No `db` byte >= 0x7F outside a manifest-routed include.** Glyph runs are
  Tier-1 data and go to a generator. A transpiler is a very efficient way to
  commit the port's most-repeated Tier-1 violation several hundred times in one
  commit, so the check runs over the emitted text.

BAILING EMITS NO SYMBOL
-----------------------
A region the tool cannot lower with certainty is emitted as its verbatim pret
source, commented out, under a `; BAIL[<reason>]` banner — and its labels are
NOT defined. Anything referencing it therefore fails to LINK. That is the entire
safety argument: the failure mode is a loud missing symbol, never a plausible
wrong behaviour that assembles, runs, and reads the wrong byte.

`BAIL` is deliberately not one of the four sanctioned annotation kinds. It is not
a claim about behaviour — it is the absence of one — and `lint_pret_labels` must
not see it as an annotation.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Sequence, Set, Tuple

import ir
import isa
import macros
import parser as sparser
import resolve

# SM83 -> x86 register map (CLAUDE.md's fixed table).
REG = {"a": "al", "b": "bh", "c": "bl", "d": "dh", "e": "dl"}
REG16 = {"bc": "bx", "de": "dx", "hl": "esi"}

# Condition -> x86 jump, and its inverse. ONE table, shared by every site that
# needs either direction: `call cc` and `ret cc` both synthesize a skip over an
# inverted condition, and a polarity error here would be silent and everywhere.
COND = {
    "z":  ("jz",  "jnz"),
    "nz": ("jnz", "jz"),
    "c":  ("jb",  "jae"),   # SM83 cp is UNSIGNED: jr c/nc -> jb/jae
    "nc": ("jae", "jb"),
}

# rgbasm number syntax NASM does not share.
_HEX = re.compile(r"\$([0-9A-Fa-f]+)")
_BIN = re.compile(r"%([01][01_]*)")
_LOCAL_REF = re.compile(r"\.[A-Za-z_]\w*")

WIDENING = re.compile(r"\b(movzx|movsx|cbw|cwde|cdq|cwd)\b")
SELF_TEST = re.compile(r"^\s*test\s+(\w+)\s*,\s*\1\s*$", re.M)


@dataclass
class Bail(Exception):
    reason: str
    detail: str = ""

    def __str__(self):
        return f"{self.reason}: {self.detail}" if self.detail else self.reason


@dataclass
class Emitted:
    lines: List[str] = field(default_factory=list)
    data_lines: List[str] = field(default_factory=list)
    externs: Set[str] = field(default_factory=set)
    globals_: List[str] = field(default_factory=list)
    equs: Dict[str, str] = field(default_factory=dict)
    bails: List[dict] = field(default_factory=list)
    ok_regions: int = 0
    bailed_regions: int = 0
    emitted_locals: Set[str] = field(default_factory=set)
    emitted_globals: Set[str] = field(default_factory=set)
    #: how many lowered items legitimately produce a `test r, r` — see
    #: check_invariants. Counted at the source, not recognised in the output.
    self_tests: int = 0


def reg8(name: str) -> str:
    """The x86 8-bit register for an SM83 8-bit register.

    H and L have NO 8-bit x86 name here. HL maps to ESI, and in 32-bit mode
    ESI's low byte is not addressable without REX, so `ld l, a` has no
    one-instruction form and every multi-instruction form (shift/mask, or a
    spill) clobbers flags or a register that is already mapped. 37 sites across
    the corpus; they are hand work, not a lowering rule.
    """
    if name in ("h", "l"):
        raise Bail("hl-half-register-access",
                   f"`{name}` is a half of ESI and has no flag-safe 8-bit x86 form")
    try:
        return REG[name]
    except KeyError:
        raise Bail("unknown-operand-shape", name)


class Emitter:
    def __init__(self, resolver: resolve.Resolver, abi: dict):
        self.R = resolver
        self.abi = abi
        #: the callee this item's register load is FOR, if one is in range.
        #: Set by the driver before each item; see transpile.transpile_file.
        self.pending_callee: str = None
        #: local labels whose defining region bailed. A NASM local label cannot
        #: be `extern`, so referencing one has no honest lowering.
        self.dead_locals: Set[str] = set()

    # -- operand rendering -------------------------------------------------

    def expr(self, text: str, out: Emitted) -> str:
        """Rewrite a pret expression into port spelling, one identifier at a time.

        Every name goes through the resolver, so a name that does not resolve
        raises rather than passing through — a pret RAM name that reached the
        output unrewritten would assemble against nothing, or worse, against a
        port symbol that means something else.
        """
        text = _HEX.sub(lambda m: "0x" + m.group(1), text)
        text = _BIN.sub(lambda m: "0b" + m.group(1).replace("_", ""), text)

        def sub(m):
            name = m.group(0)
            if name in ("BANK", "HIGH", "LOW"):
                raise Bail("bank-expression", text)
            r = self.R.resolve(name)
            if r is None:
                raise Bail("unresolved-symbol", name)
            if r.kind == resolve.NS_LABEL:
                out.externs.add(r.text)
            return r.text

        def guard_local(t: str) -> str:
            if t in self.dead_locals:
                raise Bail("target-region-bailed",
                           f"{t} is defined in a region that bailed")
            return t
        for loc in _LOCAL_REF.findall(text):
            guard_local(loc)
        return ir._IDENT_RE.sub(
            lambda m: sub(m) if not _is_reg(m.group(0)) else m.group(0), text)

    def mem(self, text: str, out: Emitted) -> str:
        return f"[ebp + {self.expr(text, out)}]"

    def hl_mem(self, domain: str) -> str:
        if domain == ir.GB:
            return "[ebp + esi]"
        if domain == ir.HOST:
            return "[esi]"
        raise Bail("pointer-domain-unknown",
                   f"HL domain is {domain} at a dereference")

    # -- one item ----------------------------------------------------------

    def item(self, it: sparser.Item, an: ir.Analysis, out: Emitted) -> List[str]:
        if it.kind == sparser.KIND_UNKNOWN:
            raise Bail(it.reason or "unknown-item")
        if it.kind == sparser.KIND_MACRO:
            return self.macro(it, an, out)
        if it.kind != sparser.KIND_INSN or it.decoded is None:
            raise Bail("unknown-item")
        return self.insn(it, an, out)

    def insn(self, it: sparser.Item, an: ir.Analysis, out: Emitted) -> List[str]:
        d = it.decoded
        m, ops, cls = d.mnemonic, d.operands, d.classes
        live = an.live_flags.get(id(it), set())
        dom = an.hl_domain.get(id(it), ir.TOP)

        # ---- loads and stores. Flag-transparent on BOTH sides: `mov` writes no
        # flags, which is the one place the two architectures agree for free.
        if m in ("ld", "ldh"):
            return self._load(d, dom, out)

        # ---- 8-bit ALU
        if m in ("xor", "or", "and", "add", "adc", "sub", "sbc", "cp"):
            if m == "add" and cls == (isa.CLS_R16, isa.CLS_R16):
                # `add hl, r16`: SM83 leaves Z ALONE and sets C from the 16-bit
                # carry. ESI is 32 bits wide here, so no x86 form reproduces both
                # the flag behaviour and the 16-bit wrap. 11 sites; hand them.
                raise Bail("add-hl-r16", " ".join(ops))
            src = self._alu_src(d, dom, out)
            x86 = {"xor": "xor", "or": "or", "and": "and", "add": "add",
                   "adc": "adc", "sub": "sub", "sbc": "sbb", "cp": "cmp"}[m]
            if m in ("and", "or") and cls == (isa.CLS_R8,) and ops[0] == "a":
                # `and a` / `or a` is pret's "test A for zero" idiom. `test al, al`
                # is the exact match: Z from the result, CF cleared, and unlike
                # `and al, al` it does not pretend to write AL.
                out.self_tests += 1
                return ["test al, al"]
            return [f"{x86} al, {src}"]

        if m in ("srl", "sla", "sra", "rr", "rl", "rrc", "rlc"):
            if cls != (isa.CLS_R8,):
                raise Bail("shift-on-memory", " ".join(ops))
            x86 = {"srl": "shr", "sla": "shl", "sra": "sar", "rr": "rcr",
                   "rl": "rcl", "rrc": "ror", "rlc": "rol"}[m]
            return [f"{x86} {reg8(ops[0])}, 1"]

        if m == "swap":
            # SM83 `swap` sets Z from the result and clears C. x86 `rol r8,4`
            # sets neither, so the flags are rebuilt explicitly: `test` gives Z
            # from the result AND clears CF, which is exactly the pair wanted.
            r = reg8(ops[0])
            out.self_tests += 1
            return [f"rol {r}, 4", f"test {r}, {r}   ; swap sets Z, clears C"]

        if m == "scf":
            return ["stc"]

        if m in ("inc", "dec"):
            return self._incdec(d, live, out)

        if m == "bit":
            n = self.expr(ops[0], out)
            target = reg8(ops[1]) if cls[1] == isa.CLS_R8 else \
                f"byte {self.hl_mem(dom)}"
            line = f"test {target}, (1 << ({n}))"
            # SM83 `bit` writes Z but PRESERVES C; x86 `test` writes Z and
            # CLEARS C. There is no short x86 sequence that produces the new Z
            # and the old C without a scratch register, and every 8-bit scratch
            # is already a mapped GB register. So: bail, rather than invent a
            # spill. Preserving BOTH flags with pushfd/popfd would be worse than
            # wrong — it would discard the Z the `bit` is being executed for.
            if "c" in live:
                raise Bail("bit-clobbers-live-carry", it.line.raw.strip())
            return [line]

        if m in ("set", "res"):
            n = self.expr(ops[0], out)
            if cls[1] == isa.CLS_R8:
                r = reg8(ops[1])
                body = (f"or {r}, (1 << ({n}))" if m == "set"
                        else f"and {r}, ~(1 << ({n})) & 0xFF")
            else:
                loc = f"byte {self.hl_mem(dom)}"
                body = (f"or {loc}, (1 << ({n}))" if m == "set"
                        else f"and {loc}, ~(1 << ({n})) & 0xFF")
            # THE CeruleanGym HAZARD. `set`/`res` write no flags on SM83; the
            # x86 forms do. If anything downstream reads a flag, sandwich it.
            return self._preserve(body, live)

        if m in ("push", "pop"):
            return self._stack(d, out)

        if m in ("jp", "jr"):
            if cls == (isa.CLS_R16,):
                raise Bail("indirect-jump", "jp hl")
            target = self.target(ops[-1], out)
            if d.condition:
                return [f"{COND[d.condition][0]} {target}"]
            return [f"jmp {target}"]

        if m == "call":
            target = self.target(ops[-1], out)
            call = f"call {target}"
            if d.condition:
                # x86 has no conditional call. Skip over it on the INVERSE
                # condition — the single most likely place to invert a polarity,
                # which is why both directions come from the one COND table.
                skip = f".sk_{it.line.lineno}"
                return [f"{COND[d.condition][1]} {skip}", f"    {call}", f"{skip}:"]
            return [call]

        if m == "ret":
            if d.condition:
                skip = f".nr_{it.line.lineno}"
                return [f"{COND[d.condition][1]} {skip}", "    ret", f"{skip}:"]
            return ["ret"]

        raise Bail("unknown-operand-shape", f"{m} {', '.join(ops)}")

    # -- instruction families ---------------------------------------------

    def _load(self, d: isa.Decoded, dom: str, out: Emitted) -> List[str]:
        cls, ops = d.classes, d.operands
        dst, src = cls
        step: List[str] = []

        def operand(c: str, text: str) -> str:
            nonlocal step
            if c == isa.CLS_R8:
                return reg8(text)
            if c == isa.CLS_R16:
                return REG16[text]
            if c == isa.CLS_MEM:
                return self.mem(text, out)
            if c == isa.CLS_MEMHL:
                return self.hl_mem(dom)
            if c == isa.CLS_MEMHLI:
                # `lea`, not `inc`: the pointer step must not disturb a flag,
                # and on SM83 `ld [hli], a` writes none.
                step = [f"lea esi, [esi{'+' if text == '[hli]' else '-'}1]"]
                return self.hl_mem(dom)
            if c == isa.CLS_MEMBCDE:
                reg = "bx" if text == "[bc]" else "dx"
                raise Bail("ld-via-bc-de", f"[{reg}] needs a 16-bit GB pointer")
            return self.expr(text, out)

        if dst == isa.CLS_R16 and src == isa.CLS_IMM:
            value = self.expr(ops[1], out)
            if ops[0] == "hl":
                return [f"mov esi, {value}"]
            # BC and DE map to BX and DX -- 16 bits. A GB address fits; a HOST
            # (link-time) address does not, and COFF rejects the relocation
            # rather than truncating it. pret can put a routine pointer in DE
            # because every GB address is 16 bits; the port cannot.
            if _domain_of(ops[1], self.R) == ir.HOST:
                # pret puts a pointer in DE and never had to care that DE is 16
                # bits, because every GB address is. A port HOST address is 32
                # bits, so the receiving routine had to put it somewhere else —
                # a per-callee decision, recorded in abi.json at the callee's own
                # signature comment. No entry means no answer, and no answer
                # means bail: a guess here assembles, links, runs, and reads the
                # wrong memory.
                reg = self.abi.get(self.pending_callee or "", {}).get(ops[0])
                if reg is None:
                    raise Bail("host-pointer-in-16bit-reg",
                               f"{ops[0]} cannot hold the 32-bit address of "
                               f"{ops[1]}; callee "
                               f"{self.pending_callee or '<none in range>'} has "
                               f"no abi.json entry")
                return [f"mov {reg}, {value}"
                        f"   ; pret: ld {ops[0]}, {ops[1]} — "
                        f"{self.pending_callee} takes it in {reg.upper()}"]
            return [f"mov {REG16[ops[0]]}, {value}"]

        d_txt = operand(dst, ops[0])
        s_txt = operand(src, ops[1])
        size = ""
        if dst in (isa.CLS_MEM, isa.CLS_MEMHL, isa.CLS_MEMHLI) and src == isa.CLS_IMM:
            size = "byte "
        return [f"mov {size}{d_txt}, {s_txt}"] + step

    def _alu_src(self, d: isa.Decoded, dom: str, out: Emitted) -> str:
        cls, ops = d.classes, d.operands
        if cls[0] == isa.CLS_R8:
            return reg8(ops[0])
        if cls[0] == isa.CLS_MEMHL:
            return f"byte {self.hl_mem(dom)}"
        return self.expr(ops[0], out)

    def _incdec(self, d: isa.Decoded, live: Set[str], out: Emitted) -> List[str]:
        m, cls, ops = d.mnemonic, d.classes, d.operands
        if cls == (isa.CLS_R16,):
            # SM83 16-bit inc/dec write NO flags. `lea` reproduces that exactly
            # for HL; BC/DE have no flag-free 16-bit form, so they are wrapped
            # only when a flag is actually live.
            if ops[0] == "hl":
                return [f"lea esi, [esi{'+' if m == 'inc' else '-'}1]"]
            reg = REG16[ops[0]]
            return self._preserve(f"{m} {reg}", live)
        if cls == (isa.CLS_R8,):
            # 8-BIT, DELIBERATELY. `dec bl`, never `dec ecx`: the loop bound in
            # pret comes from the register WIDTH, not from any instruction, so
            # widening turns a bounded 256-iteration wrap into a page fault.
            return [f"{m} {reg8(ops[0])}"]
        return [f"{m} byte {self.hl_mem(ir.GB)}"]

    def _stack(self, d: isa.Decoded, out: Emitted) -> List[str]:
        m, reg = d.mnemonic, d.operands[0]
        if reg == "af":
            # AF is the accumulator AND the flags. Both must survive.
            return ["pushfd", "push eax"] if m == "push" else ["pop eax", "popfd"]
        if reg == "hl":
            return [f"{m} esi"]
        if reg in ("bc", "de"):
            return [f"{m} e{REG16[reg]}"]
        raise Bail("unknown-operand-shape", f"{m} {reg}")

    def _preserve(self, body: str, live: Set[str]) -> List[str]:
        """Wrap a flag-writing lowering of a flag-transparent SM83 op.

        `pushfd`/`popfd` is the obvious fallback and it is chosen on purpose: it
        is always correct, it is two instructions, and it reads line-for-line
        against the pret source. Reordering would be cheaper and would cost the
        1:1 review property, which is the whole point of the exercise.
        """
        if not live:
            return [body]
        return ["pushfd    ; SM83 form writes no flags", f"    {body}", "popfd"]

    # -- macros ------------------------------------------------------------

    def macro(self, it: sparser.Item, an: ir.Analysis, out: Emitted) -> List[str]:
        mi = it.macro
        live = an.live_flags.get(id(it), set())
        name = it.head
        args = it.line.operands

        if mi.always_bail:
            raise Bail(mi.always_bail, it.line.raw.strip())
        if mi.state_dependent:
            raise Bail("event-byte-assembly-state", it.line.raw.strip())

        if name in ("CheckEvent", "SetEvent", "ResetEvent", "CheckAndSetEvent",
                    "CheckAndResetEvent", "SetEvents", "ResetEvents",
                    "SetEventRange", "ResetEventRange"):
            rendered = f"{name} {', '.join(self.expr(a, out) for a in args)}"
            # The port's SetEvent/ResetEvent macros are NOT flag-transparent
            # (they lower to `or`/`and`), while pret's are. Where a flag is live
            # across one, wrap it rather than depending on the shared macro's
            # internals — which this tool does not own and must not assume.
            if mi.flag_transparent:
                return self._preserve(rendered, live)
            return [rendered]

        if name in ("CheckBothEventsSet", "CheckEitherEventSet"):
            # Both exist as port macros with pret's spelling and pret's
            # (counter-intuitive) polarity — CheckBothEventsSet sets Z when the
            # events ARE set, the inverse of every other Check*.
            return [f"{name} {', '.join(self.expr(a, out) for a in args)}"]

        if name == "CheckEventHL":
            ev = self.expr(args[0], out)
            return [f"mov esi, wEventFlags + EVENT_BYTE({ev})",
                    f"test byte [ebp + esi], EVENT_MASK({ev})"]

        if name == "EventFlagAddress":
            ev = self.expr(args[1], out)
            reg = REG16.get(args[0])
            if reg is None:
                raise Bail("unknown-operand-shape", it.line.raw.strip())
            dst = "esi" if args[0] == "hl" else reg
            return [f"mov {dst}, wEventFlags + EVENT_BYTE({ev})"]

        if name == "EventFlagBit":
            ev = self.expr(args[1], out)
            if len(args) > 2:
                rel = self.expr(args[2], out)
                bit = (f"(({rel}) - (({rel}) / 8) * 8) + (({ev}) - ({rel}))")
            else:
                bit = f"({ev}) - (({ev}) / 8) * 8"
            return [f"mov {reg8(args[0])}, {bit}"]

        if name == "lb":
            hi = self.expr(args[1], out)
            lo = self.expr(args[2], out)
            reg = REG16.get(args[0])
            if reg is None:
                raise Bail("unknown-operand-shape", it.line.raw.strip())
            return [f"mov {reg}, (({hi}) << 8) | ({lo})"]

        if name in ("ldpikacry", "ldpikaemotion"):
            # pret computes an INDEX: `ld e, (X_id - PikachuEmotionTable) / 2`.
            # Loading the label itself would truncate a 32-bit address into an
            # 8-bit register (COFF rejects the relocation) AND pass the wrong
            # value. The index cannot be computed here either: it is non-linear
            # assembly-time arithmetic on symbols from another object file,
            # which is the one thing a NASM `equ` genuinely cannot cross.
            raise Bail("pikachu-table-index",
                       f"{name} needs (X_id - Table) / N across object files")

        if name in ("farcall", "callfar", "farjp", "jpfar"):
            target = self.target(args[0], out)
            verb = "jmp" if name in ("farjp", "jpfar") else "call"
            return [
                f"; DEVIATION{{class=banking; pret=macros/farcall.asm:{name}; "
                f"behavior=bank switch dropped, {verb} goes straight to the target; "
                f"evidence=the DPMI model is flat so every routine is always "
                f"addressable, and Bankswitch has no port counterpart; "
                f"lifetime=permanent}}",
                f"{verb} {target}",
            ]

        if name in ("predef", "predef_jump"):
            target = self.target(args[0], out)
            if an.a_live_after.get(id(it), True):
                # pret's `predef` leaves the predef id in A. A direct call does
                # not, so a reader of A downstream would see a different value.
                raise Bail("predef-leaves-id-in-a", it.line.raw.strip())
            verb = "jmp" if name == "predef_jump" else "call"
            return [
                f"; DEVIATION{{class=banking; pret=macros/predef.asm:{name}; "
                f"behavior=Predef dispatch replaced by a direct {verb}, and the "
                f"predef id is not left in A because no reader is live; "
                f"evidence=PredefPointers is unported and the flat model needs no "
                f"bank switch, dataflow shows A dead after this site; "
                f"lifetime=retired when PredefPointers is ported}}",
                f"{verb} {target}",
            ]

        raise Bail("unknown-macro", it.line.raw.strip())

    def data(self, it: sparser.Item, out: Emitted) -> List[str]:
        """Lower one DATA item — text-stream bytes and pointer tables.

        Emitted for one reason only: the code references these labels, and a
        label that is neither defined nor `extern` is an assembly error rather
        than the intended link error. Nothing here encodes a glyph: `text_far`
        emits a pointer, `dw_const` emits a pointer, and a quoted `db` run BAILS
        because it is Tier-1 data that belongs to a generator.
        """
        name, args = it.head, it.line.operands

        if name in PASSTHROUGH_DATA:
            if len(args) != PASSTHROUGH_DATA[name]:
                raise Bail("macro-arity-unmodelled", it.line.raw.strip())
            rendered = ", ".join(self.expr(a, out) for a in args)
            return [f"{name} {rendered}".strip()]

        if name in SOUND_COMMANDS:
            raise Bail("text-sound-command-unported", it.line.raw.strip())

        if name in ("dw_const",):
            # pret emits `dw <label>` here; the port is flat, so a pointer is 32
            # bits. The constant half is emitted as a file-local equ elsewhere.
            return [f"dd {self.expr(args[0], out)}"]

        if name in ("dw", "dd"):
            return [f"dd {', '.join(self.expr(a, out) for a in args)}"]

        if name == "db":
            if '"' in it.line.argtext:
                raise Bail("inline-text-db", it.line.raw.strip())
            return [f"db {', '.join(self.expr(a, out) for a in args)}"]

        if name == "map_coord_movement":
            # dbmapcoord x, y + dw <movement stream>. The coordinate is a MAP
            # coordinate — identical on both sides, no projection — and the
            # stream is a pointer, so `dd` where pret has `dw`.
            return [f"db {self.expr(args[1], out)}, {self.expr(args[0], out)}",
                    f"dd {self.expr(args[2], out)}"]

        if name == "trainer":
            # The trainer-header tables are ALREADY generated, by
            # gen_map_script_tables.py into assets/map_script_tables.inc. Emitting
            # them here would create a second definition of <Map>TrainerHeaders
            # and put the same data under two owners. The label is externed by
            # the caller instead.
            raise Bail("owned-by-gen_map_script_tables", it.line.raw.strip())

        if name in ("script_pokecenter_nurse", "script_mart", "script_bills_pc",
                    "script_players_pc", "script_pokecenter_pc",
                    "script_prize_vendor", "script_cable_club_receptionist",
                    "script_vending_machine"):
            # A one-byte TX_SCRIPT_* command handing the whole box to a named
            # engine routine. The port's gb_text.inc defines no TX_SCRIPT_*
            # constant, so there is nothing faithful to emit — same subset gap as
            # the sound commands.
            raise Bail("text-script-command-unported", it.line.raw.strip())

        if name == "dbmapcoord":
            # `db y, x` -- a MAP coordinate, identical on both sides. No
            # projection: the port's map grid is pret's map grid.
            return [f"db {self.expr(args[1], out)}, {self.expr(args[0], out)}"]

        if name in ("def_text_pointers", "def_script_pointers", "def_trainers"):
            return []      # const_def only; emits no bytes

        raise Bail("unknown-data-macro", it.line.raw.strip())

    def target(self, text: str, out: Emitted) -> str:
        t = text.strip()
        if t.startswith("."):
            if t in self.dead_locals:
                raise Bail("target-region-bailed",
                           f"{t} is defined in a region that bailed")
            return t
        r = self.R.resolve(t)
        if r is None:
            raise Bail("unresolved-symbol", t)
        if r.kind == resolve.NS_LABEL:
            out.externs.add(r.text)
        return r.text


# Data macros that pass straight through to a port macro of the same name and
# arity. gb_text.inc already defines these, including `text_far`, which the port
# renders as `db TX_FAR / dd <label>` -- a POINTER, not glyph bytes. That is what
# lets the transpiler emit text streams while owning no charmap knowledge: the
# glyphs stay in text/, generated, and the stream just points at them.
PASSTHROUGH_DATA = {
    "text_far": 1, "text_end": 0, "text_start": 0, "text_asm": 0,
    "text_waitbutton": 0, "text_promptbutton": 0, "text_low": 0,
    "text_pause": 0, "text_scroll": 0, "text_dots": 1, "text_ram": 1,
    "text_move": 1, "text_bcd": 2, "text_box": 3, "text_decimal": 3,
}

# The text-stream SOUND commands (TX_SOUND_GET_ITEM_1 and friends) have no port
# counterpart: gb_text.inc stops at TX_DOTS/TX_WAIT_BUTTON/TX_FAR and defines no
# TX_SOUND_* at all. Emitting the raw byte would be inventing a text command the
# port's engine does not implement, so these BAIL -- which is the honest report
# that the port's text command set is a subset of pret's, and the plan's
# "realign TX_ASM with pret's text commands" item is what closes it.
SOUND_COMMANDS = {
    "sound_get_item_1", "sound_get_item_2", "sound_get_key_item",
    "sound_level_up", "sound_caught_mon", "sound_dex_page_added",
    "sound_pokedex_rating", "sound_cry_pikachu", "sound_cry_pidgeot",
    "sound_cry_dewgong", "sound_get_item_1_duplicate",
}


def _domain_of(text: str, R) -> str:
    """The pointer domain of an immediate, for the 16-bit-register check."""
    return ir._domain_of_immediate(text, R)


def _is_reg(tok: str) -> bool:
    return tok.lower() in isa.R8 or tok.lower() in isa.R16


def check_invariants(text: str, expected_self_tests: int = None) -> List[str]:
    """The structural assertions, run over the emitted text.

    These are not style checks. Each corresponds to a defect class the project
    has actually shipped, and each is phrased so the tool has no way to express
    the defect rather than merely being careful about it.

    A NOTE ON THE ZERO-GUARD CHECK, because the obvious version of it is wrong.
    The first version grepped for `test r,r` near a `jz` and fired on the very
    first file — on a faithful lowering of pret's own `and a` / `jr z`. A text
    pattern cannot tell a synthesized guard from a translated one, and a check
    that cannot make that distinction is worse than none: it trains you to
    silence it. So the check is a COUNT instead. The emitter produces
    `test r, r` from exactly two places — `and a` (pret's test-for-zero idiom)
    and `swap` (rebuilding the flags SM83 sets) — and every one is accounted
    for against the items that produced it. An unaccounted self-test is a
    synthesis path that should not exist.
    """
    findings = []
    for m in WIDENING.finditer(text):
        findings.append(f"widening instruction emitted: {m.group(0)}")
    if expected_self_tests is not None:
        got = len(SELF_TEST.findall(text))
        if got != expected_self_tests:
            findings.append(
                f"{got} `test r, r` emitted but only {expected_self_tests} pret "
                f"items (and a / or a / swap) account for one — the difference "
                f"is synthesized, which is how the DelayFrames zero-guard "
                f"regression was introduced")
    # THE TIER-1 CHECK. The first version of this flagged any `db` byte >= 0x7F,
    # copying the port linter's heuristic — and fired immediately on `db 0xFF`,
    # a movement-list terminator. High bytes are not glyphs; a QUOTED RUN is,
    # and that is what the port's own detector really keys on (a high byte PLUS
    # a quoted string or a *Text*-ish label).
    #
    # The emitter's guarantee is stronger and simpler than the heuristic: it
    # bails on any `db` whose source carries a quote, so no glyph can reach the
    # output by any path. This asserts that guarantee directly — no string
    # literal survives anywhere outside a comment.
    for line in text.splitlines():
        code = line.split(";")[0]
        if '"' in code and not code.lstrip().startswith("%include"):
            findings.append(f"a string literal reached the output: {line.strip()}")
    return findings
