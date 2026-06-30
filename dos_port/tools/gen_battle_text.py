#!/usr/bin/env python3
"""gen_battle_text.py — generate dos_port/assets/battle_text.inc (Tier 1 data).

The battle engine prints messages through the unified text engine (PrintText →
TextCommandProcessor) on '@'/control-terminated command streams. pret stores these
as `text_far`-wrapped labels in engine/battle/*.asm pointing at `_*Text` definitions
in data/text/*.asm. This generator flattens that indirection (our DJGPP flat model
has no banks) and emits each battle wrapper label as a literal `db` byte stream, with
the pret control codes intact so the runtime resolves dynamic fields:

    text "..."          -> TX_START($00) + charmap bytes
    line/next/para/cont  -> "<LINE>"/"<NEXT>"/"<PARA>"/"<CONT>" charmap byte + chars
    prompt / done        -> $58 / $57            (terminate; drive the ▼ arrow)
    text_end             -> $50
    text_ram  addr       -> $01, <lo,hi of addr>             (e.g. wEnemyMonNick)
    text_bcd  addr,flags -> $02, <lo,hi>, flags              (money)
    text_decimal a,b,d   -> $09, <lo,hi>, (b<<4)|d           (EXP/level numbers)
    text_far  _far       -> the _far stream, inlined recursively

`addr` symbols (wEnemyMonNick, wExpAmountGained, …) are resolved to the port's WRAM
offsets from dos_port/include/gb_memmap.inc, so a generated stream points at the same
RAM the engine reads. DO NOT EDIT the output by hand — re-run this generator.

Run from repo root or dos_port/.
"""
import re
import sys
from pathlib import Path

ROOT   = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "dos_port" / "assets"
MEMMAP = ROOT / "dos_port" / "include" / "gb_memmap.inc"
OUT    = ASSETS / "battle_text.inc"

# Control-code byte values (constants/text_constants.asm / charmap.asm)
TX_START, TX_RAM, TX_BCD, TX_NUM, TX_FAR, TX_END = 0x00, 0x01, 0x02, 0x09, 0x17, 0x50

# Battle .asm files that define `XxxText:` wrapper labels we want to emit.
BATTLE_SRC = [
    "engine/battle/core.asm",
    "engine/battle/used_move_text.asm",
    "engine/battle/experience.asm",
    "engine/battle/effects.asm",
    "engine/battle/misc.asm",
    "engine/battle/end_of_battle.asm",
    "engine/battle/print_type.asm",
] + sorted(
    str(p.relative_to(ROOT)) for p in (ROOT / "engine" / "battle" / "move_effects").glob("*.asm")
) + [
    # dos_port-only split-outs of core.asm logic; not present in pret root, so
    # these resolve to no-ops via the `if not p.exists()` guard below — kept
    # here so the scan list stays self-documenting if pret ever grows them.
    "engine/battle/building_rage.asm",
    "engine/battle/residual_damage.asm",
]
# data/text files that hold the `_XxxText::` far definitions.
TEXT_SRC = sorted((ROOT / "data" / "text").glob("text_*.asm"))

# ---------------------------------------------------------------------------
# charmap (greedy, longest key first — handles "<PLAYER>", 'd contractions, etc.)
# ---------------------------------------------------------------------------
def load_charmap() -> list:
    cm = []
    for line in (ROOT / "constants" / "charmap.asm").read_text(encoding="utf-8").splitlines():
        m = re.match(r'\s+charmap\s+"((?:[^"\\]|\\.)*)",\s*\$([0-9a-fA-F]+)', line)
        if m:
            cm.append((m.group(1).replace('\\"', '"'), int(m.group(2), 16)))
    cm.sort(key=lambda x: -len(x[0]))
    return cm

def encode(s: str, cm: list) -> list:
    out, i = [], 0
    while i < len(s):
        for key, val in cm:
            if key and s.startswith(key, i):
                out.append(val); i += len(key); break
        else:
            raise ValueError(f"unmapped char at {i}: {s[i:i+8]!r}")
    return out

# ---------------------------------------------------------------------------
# gb_memmap.inc symbol -> WRAM offset (for text_ram/text_bcd/text_decimal addrs)
# ---------------------------------------------------------------------------
def load_memmap() -> dict:
    syms = {}
    for line in MEMMAP.read_text(encoding="utf-8").splitlines():
        m = re.match(r'\s*(\w+)\s+equ\s+0x([0-9A-Fa-f]+)', line)
        if m:
            syms[m.group(1)] = int(m.group(2), 16)
    return syms

# ---------------------------------------------------------------------------
# Parse one text-macro body (list of source lines) into a byte stream.
# `far_db` maps _FarLabel -> already-encoded bytes (for text_far inlining).
# ---------------------------------------------------------------------------
def parse_body(lines, cm, mem, far_db):
    out = []
    def addr(sym):
        sym = sym.strip()
        if sym not in mem:
            raise KeyError(f"text addr symbol {sym!r} not in gb_memmap.inc")
        a = mem[sym]
        return [a & 0xFF, (a >> 8) & 0xFF]
    for raw in lines:
        s = raw.split(";", 1)[0].strip()
        if not s:
            continue
        m = re.match(r'(text|line|next|para|cont)\s+"((?:[^"\\]|\\.)*)"', s)
        if m:
            kind, txt = m.group(1), m.group(2).replace('\\"', '"')
            tok = {"text": "", "line": "<LINE>", "next": "<NEXT>",
                   "para": "<PARA>", "cont": "<CONT>"}[kind]
            if kind == "text":
                out.append(TX_START)
            else:
                out += encode(tok, cm)
            out += encode(txt, cm)
            continue
        if s == "prompt":   out += encode("<PROMPT>", cm); continue
        if s == "done":     out += encode("<DONE>", cm);   continue
        if s == "text_end": out.append(TX_END);            continue
        if s == "text_start": out.append(TX_START);        continue
        m = re.match(r'text_ram\s+(\w+)', s)
        if m: out += [TX_RAM] + addr(m.group(1)); continue
        m = re.match(r'text_bcd\s+(\w+)\s*,\s*(.+)', s)
        if m: out += [TX_BCD] + addr(m.group(1)) + [parse_flags(m.group(2))]; continue
        m = re.match(r'text_decimal\s+(\w+)\s*,\s*(\d+)\s*,\s*(\d+)', s)
        if m:
            out += [TX_NUM] + addr(m.group(1)) + [((int(m.group(2)) & 0xF) << 4) | (int(m.group(3)) & 0xF)]
            continue
        m = re.match(r'text_far\s+(_\w+)', s)
        if m:
            far = m.group(1)
            if far not in far_db:
                raise KeyError(f"text_far target {far!r} not found")
            out += far_db[far]
            continue
        # tolerated no-ops in our model:
        if s in ("text_promptbutton", "text_waitbutton", "text_scroll", "text_low", "text_pause"):
            out.append({"text_promptbutton": 0x06, "text_waitbutton": 0x0D,
                        "text_scroll": 0x07, "text_low": 0x05, "text_pause": 0x0A}[s]); continue
        if s == "text_asm":
            raise ValueError("text_asm body cannot be generated (translate as code)")
        # bare `db "..."` raw string (e.g. WhichTechniqueString)
        m = re.match(r'db\s+"((?:[^"\\]|\\.)*)"', s)
        if m:
            out += encode(m.group(1).replace('\\"', '"'), cm); continue
        raise ValueError(f"unhandled text line: {s!r}")
    return out

def parse_flags(expr: str) -> int:
    # e.g. "3 | LEADING_ZEROES | LEFT_ALIGN", "%10000011", "$83".
    # constants/text_constants.asm bit positions.
    CONST = {"MONEY_SIGN": 1 << 5, "LEFT_ALIGN": 1 << 6, "LEADING_ZEROES": 1 << 7}
    val = 0
    for part in expr.split("|"):
        p = part.strip()
        if not p:
            continue
        if p in CONST:
            val |= CONST[p]
        elif p.startswith("%"):
            val |= int(p[1:], 2)
        elif p.startswith("$"):
            val |= int(p[1:], 16)
        else:
            val |= int(p, 0)
    return val & 0xFF

# ---------------------------------------------------------------------------
# Collect `_FarLabel:: <body>` definitions from data/text/*.asm
# ---------------------------------------------------------------------------
def collect_far(cm, mem):
    # First pass: capture raw line blocks per label (defer encoding for text_far order).
    blocks = {}
    for path in TEXT_SRC:
        cur, buf = None, []
        for raw in path.read_text(encoding="utf-8").splitlines():
            m = re.match(r'(\w+)::\s*$', raw.strip())
            if m:
                if cur: blocks[cur] = buf
                cur, buf = m.group(1), []
                continue
            if cur is not None:
                buf.append(raw)
        if cur: blocks[cur] = buf
    # Encode with simple dependency handling: retry until all text_far refs resolve.
    far_db, pending = {}, dict(blocks)
    for _ in range(8):
        if not pending: break
        progressed = False
        for label, body in list(pending.items()):
            try:
                far_db[label] = parse_body(body, cm, mem, far_db)
                del pending[label]; progressed = True
            except KeyError:
                pass            # a text_far dep not yet encoded — retry next round
            except ValueError:
                del pending[label]; progressed = True  # not generatable (vc_patch,
                                                       # text_asm, …) — drop; only
                                                       # battle labels we emit matter
        if not progressed:
            break
    return far_db

# ---------------------------------------------------------------------------
# Collect `XxxText:` wrapper labels from the battle .asm files.
# A wrapper is either `Label:` + `text_far _Far` (+ text_end), or `Label:` + raw db.
# ---------------------------------------------------------------------------
def collect_wrappers(cm, mem, far_db):
    out = {}
    for rel in BATTLE_SRC:
        p = ROOT / rel
        if not p.exists():
            continue
        lines = p.read_text(encoding="utf-8").splitlines()
        i = 0
        while i < len(lines):
            m = re.match(r'([A-Z]\w*Text):', lines[i].strip())
            if not m:
                i += 1; continue
            label = m.group(1)
            body = []
            j = i + 1
            while j < len(lines):
                t = lines[j].split(";", 1)[0].strip()
                if not t:
                    j += 1; continue
                if re.match(r'[A-Za-z_.]\w*:', t) and not t.startswith(("text", "db", "done", "prompt")):
                    break  # next label
                if t == "text_asm":
                    body = None; break  # grammar-driven, not generatable
                body.append(lines[j])
                if t in ("text_end",) or t.startswith("text_far") or re.match(r'db\s+"', t):
                    j += 1; break
                j += 1
            if body:
                try:
                    out[label] = parse_body(body, cm, mem, far_db)
                except (KeyError, ValueError):
                    pass  # text_asm / unresolved — skip (translated as code)
            i = j
    return out

def fmt(label, data):
    rows = []
    for k in range(0, len(data), 16):
        rows.append("    db " + ", ".join(f"0x{b:02X}" for b in data[k:k+16]))
    return f"global {label}\n{label}:\n" + "\n".join(rows)

def main():
    cm  = load_charmap()
    mem = load_memmap()
    far = collect_far(cm, mem)
    wr  = collect_wrappers(cm, mem, far)
    lines = [
        "; battle_text.inc — generated by tools/gen_battle_text.py. DO NOT EDIT BY HAND.",
        "; Battle message command streams (pret data/text + engine/battle wrappers),",
        f"; text_far indirection flattened for the flat model. {len(wr)} labels.",
        "; section .data so labels never land in an orphaned section (see link.ld).",
        "",
        "section .data",
        "",
    ]
    for label in sorted(wr):
        lines.append(fmt(label, wr[label]))
    lines.append("")
    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"  wrote {OUT.relative_to(ROOT)} ({len(wr)} battle text labels)")

if __name__ == "__main__":
    sys.exit(main())
