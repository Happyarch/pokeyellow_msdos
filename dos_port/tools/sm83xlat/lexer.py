#!/usr/bin/env python3
"""lexer.py — line-level lexer for pret's rgbasm `scripts/*.asm`.

Turns every physical line of a pret script into exactly one `Line` record with
structured fields. It does NOT interpret anything: no macro expansion, no
constant folding, no flag reasoning. Its whole contract is that the 29,673 lines
of `scripts/` come out the other side categorised, with operands split, and with
**zero** lines it cannot categorise.

WHY A PARSE FAILURE IS A TOOL BUG, NOT A BAIL
---------------------------------------------
The transpiler bails on anything it cannot lower *with certainty*, and a bail is
a legitimate, expected outcome — a human then does that site by hand. A parse
failure is different in kind: it means the tool did not even establish what the
line SAYS, so its reason-code histogram is not a work queue, it is a work queue
with an unknown-size hole in it. Stage 0's acceptance is therefore zero parse
errors, and every parse error found is fixed here rather than routed to a bail.

LEXICAL FACTS THIS CORPUS ACTUALLY CONTAINS (measured, not assumed)
------------------------------------------------------------------
* Labels sit at column 0 and the colon is OPTIONAL. `CeruleanGym.asm` has
  `.BagFull` and `.gymVictory` with no colon at all, right next to
  `CeruleanGymReceiveTM11:` with one. A lexer that requires the colon loses two
  branch targets per gym.
* `::` is an exported label; `.foo` is local to the preceding global label.
* Strings can contain `;`, so comment stripping must be string-aware.
  `db "¥1000000@"` (BikeShop) is also non-ASCII, so the corpus is read as UTF-8.
* Operands are comma-separated at bracket/paren/quote depth 0. `dw_const` and
  `trainer` carry commas inside `(...)`; `ld a, [wEventFlags + n]` carries one
  inside `[...]`.
* Conditional assembly appears at column 0: `IF DEF(_DEBUG)` / `ELSE` / `ENDC`,
  plus one `INCLUDE`. These are structure, not instructions.

Everything above is a statement about what was found in the tree, so re-measure
rather than trusting the list if the pret submodule moves.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import List, Optional

# Line kinds. Exactly one applies to any physical line.
BLANK = "blank"          # empty or whitespace only
COMMENT = "comment"      # comment only, no code
LABEL = "label"          # global, exported or local label definition
ITEM = "item"            # an indented mnemonic/macro/directive with operands
DIRECTIVE = "directive"  # column-0 assembler control (IF/ELSE/ENDC/INCLUDE/...)

# Column-0 tokens that are assembler control flow rather than a label.
# Anything here would otherwise lex as a label named "IF" and silently swallow
# the conditional structure.
COL0_DIRECTIVES = {
    "IF", "ELIF", "ELSE", "ENDC", "INCLUDE", "SECTION", "DEF", "REDEF",
    "EXPORT", "ASSERT", "FAIL", "MACRO", "ENDM", "REPT", "ENDR", "FOR",
    "PURGE", "UNION", "NEXTU", "ENDU", "LOAD", "ENDL", "CHARMAP", "OPT",
}

_LABEL_RE = re.compile(r"^(?P<name>[A-Za-z_.@][A-Za-z0-9_.@#]*)(?P<colons>::?)?\s*$")


@dataclass
class Line:
    """One physical source line, categorised."""

    file: str            # path relative to the pret root, e.g. "scripts/PewterMart.asm"
    lineno: int          # 1-based
    raw: str             # the original text, newline stripped
    kind: str            # one of BLANK / COMMENT / LABEL / ITEM / DIRECTIVE
    comment: Optional[str] = None   # trailing comment text, ';' stripped

    # LABEL
    label: Optional[str] = None
    exported: bool = False          # `::`
    local: bool = False             # leading '.'

    # ITEM / DIRECTIVE
    head: Optional[str] = None      # mnemonic, macro name or directive keyword
    operands: List[str] = field(default_factory=list)
    argtext: str = ""               # everything after `head`, comment stripped

    # filled in by the parser
    active: bool = True             # False inside a false conditional branch
    scope: Optional[str] = None     # enclosing global label, for local labels

    @property
    def where(self) -> str:
        return f"{self.file}:{self.lineno}"


class LexError(Exception):
    """A line the lexer could not categorise. Always a tool bug — see module docstring."""

    def __init__(self, line: "Line | str", message: str):
        where = line.where if isinstance(line, Line) else str(line)
        super().__init__(f"{where}: {message}")
        self.where = where
        self.message = message


def split_comment(text: str) -> tuple[str, Optional[str]]:
    """Split a line into (code, comment), respecting quoted strings.

    `db "TWO;THREE@"` must not lose half its string to the comment stripper.
    rgbasm strings are double-quoted with no escape processing that matters here.
    """
    in_string = False
    for i, ch in enumerate(text):
        if ch == '"':
            in_string = not in_string
        elif ch == ";" and not in_string:
            return text[:i], text[i + 1:]
    return text, None


def split_operands(argtext: str) -> List[str]:
    """Split on commas at depth 0. Brackets, parens and quotes all nest.

    `ld a, [wEventFlags + event_byte]`  -> ["a", "[wEventFlags + event_byte]"]
    `dw_const Foo, TEXT_BAR`            -> ["Foo", "TEXT_BAR"]
    `trainer EVENT_X, 3, A, B, C`       -> five operands even when one holds
                                           `(1 << BIT) | 2`.
    """
    out: List[str] = []
    depth = 0
    in_string = False
    cur = []
    for ch in argtext:
        if in_string:
            cur.append(ch)
            if ch == '"':
                in_string = False
            continue
        if ch == '"':
            in_string = True
            cur.append(ch)
        elif ch in "([{":
            depth += 1
            cur.append(ch)
        elif ch in ")]}":
            depth -= 1
            cur.append(ch)
        elif ch == "," and depth == 0:
            out.append("".join(cur).strip())
            cur = []
        else:
            cur.append(ch)
    tail = "".join(cur).strip()
    if tail or out:
        out.append(tail)
    return [o for o in out if o != ""] if len(out) == 1 and out[0] == "" else out


def lex_line(file: str, lineno: int, raw: str) -> Line:
    code, comment = split_comment(raw.rstrip("\n"))
    comment = comment.strip() if comment is not None else None
    stripped = code.strip()

    if not stripped:
        return Line(file, lineno, raw.rstrip("\n"),
                    COMMENT if comment is not None else BLANK, comment)

    indented = code[:1] in (" ", "\t")

    if not indented:
        head = stripped.split(None, 1)[0]
        # Column-0 assembler control. Checked before the label shape because
        # `ELSE` and `ENDC` are valid label names as far as the regex cares.
        bare = head.rstrip(":")
        if bare.upper() in COL0_DIRECTIVES and bare.upper() == bare:
            rest = stripped[len(head):].strip()
            return Line(file, lineno, raw.rstrip("\n"), DIRECTIVE, comment,
                        head=bare.upper(), argtext=rest,
                        operands=split_operands(rest))
        m = _LABEL_RE.match(stripped)
        if m:
            name = m.group("name")
            return Line(file, lineno, raw.rstrip("\n"), LABEL, comment,
                        label=name,
                        exported=m.group("colons") == "::",
                        local=name.startswith("."))
        # A label with an instruction on the same line would land here. pret
        # never writes one in scripts/; if that changes it is a real lexer gap
        # and must be handled, not guessed at.
        raise LexError(Line(file, lineno, raw, ITEM),
                       f"column-0 line is neither a label nor a known directive: {stripped!r}")

    parts = stripped.split(None, 1)
    head = parts[0]
    argtext = parts[1].strip() if len(parts) > 1 else ""
    return Line(file, lineno, raw.rstrip("\n"), ITEM, comment,
                head=head, argtext=argtext, operands=split_operands(argtext))


def lex_file(path: Path, root: Path) -> List[Line]:
    rel = str(path.relative_to(root))
    text = path.read_text(encoding="utf-8")
    if "\\\n" in text:
        # rgbasm line continuations. None occur in scripts/ (measured), and
        # silently joining them would misreport line numbers in the bail report.
        raise LexError(rel, "line continuation (\\) present — lexer does not join lines")
    return [lex_line(rel, i, raw) for i, raw in enumerate(text.splitlines(), 1)]
