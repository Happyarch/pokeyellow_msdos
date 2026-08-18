#!/usr/bin/env python3
"""gen_trades.py — generate dos_port/assets/trades.inc (Tier 1 data).

pret keeps the in-game trade table in data/events/trades.asm and pulls it into
engine/events/in_game_trades.asm with `INCLUDE`. Each row is

    npctrade GIVE, GET, DIALOGSET, "NICK"

which expands (macros/data.asm) to

    db GIVE, GET, DIALOGSET
    dname "NICK", NAME_LENGTH

`dname` emits the charmap-encoded name and then pads to exactly NAME_LENGTH
bytes with the string terminator '@' ($50) — see macros/data.asm:

    MACRO? dname
        IF _NARG == 2 / DEF n = \\2 / ELSE / DEF n = NAME_LENGTH - 1 / ENDC
        db \\1
        ds n - CHARLEN(\\1), '@'
    ENDM

so with the explicit `NAME_LENGTH` argument n = 11 and each row is 3 + 11 = 14
bytes ($e — the stride DoInGameTradeDialogue passes to AddNTimes).

The nicknames are human-rendered text, so per CLAUDE.md's two-tier rule they are
Tier-1 DATA and must never be hand-encoded as charmap hex in a .asm. This
generator PARSES data/events/trades.asm (it does not transcribe it) and encodes
the names through tools/generators/gb_text.py (the unicode_converter submodule).

InGameTrade_TrainerString — engine/events/in_game_trades.asm's
`dname "<TRAINER>", NAME_LENGTH` — is the same kind of data and is emitted here
too. Its text is the multi-char charmap TOKEN "<TRAINER>" ($5d), which
gb_text.encode (single-char charmap only, by design) cannot express, so this
generator resolves named `<...>` tokens straight out of constants/charmap.asm.
RGBDS CHARLEN counts charmap tokens, so "<TRAINER>" is ONE character and the row
is 1 encoded byte + 10 '@' pad bytes.

Species and dialogset bytes are emitted as their pret constant NAMES; they
resolve from assets/script_constants.inc / include/gb_constants.inc, which
in_game_trades.asm %includes.

Run from repo root or dos_port/.
"""
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gb_text  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
ASSETS = ROOT / "dos_port" / "assets"
SRC = ROOT / "data" / "events" / "trades.asm"
CHARMAP = ROOT / "constants" / "charmap.asm"
# TWO OUTPUTS, because the two labels have DIFFERENT pret homes and the port
# mirrors pret paths exactly (lint_pret_labels `aux_misplaced`):
#   TradeMons                 -> pret data/events/trades.asm
#                             -> carrier dos_port/src/data/events/trades.asm
#   InGameTrade_TrainerString -> pret engine/events/in_game_trades.asm
#                             -> stays in dos_port/src/engine/events/in_game_trades.asm
# Emitting both into one .inc put TradeMons in the engine file's TU and tripped
# `aux_misplaced` (measured 2026-08-17). The split is not cosmetic: it is the
# mirror rule.
OUT = ASSETS / "trades.inc"
OUT_TRAINER = ASSETS / "trade_trainer_string.inc"

NAME_LENGTH = 11          # constants/text_constants.asm
TERMINATOR = 0x50         # charmap "@" — dname's pad byte

# engine/events/in_game_trades.asm:InGameTrade_TrainerString
TRAINER_STRING = "<TRAINER>"

NPCTRADE_RE = re.compile(
    r'^\s*npctrade\s+(\w+)\s*,\s*(\w+)\s*,\s*(\w+)\s*,\s*"([^"]*)"'
)


def load_named_tokens() -> dict:
    """`charmap "<FOO>", $xx` entries from constants/charmap.asm.

    Only the angle-bracket TOKENS — the single-char entries are gb_text's job.
    """
    toks = {}
    for line in CHARMAP.read_text(encoding="utf-8").splitlines():
        m = re.match(r'\s+charmap\s+"(<[^"]+>)",\s*\$([0-9a-fA-F]+)', line)
        if m:
            toks[m.group(1)] = int(m.group(2), 16)
    return toks


def encode_name(text: str, toks: dict) -> list:
    """Charmap-encode `text`, honouring `<TOKEN>` names, then dname-pad to
    NAME_LENGTH with '@'. Raises if the result does not fit."""
    out = []
    i = 0
    while i < len(text):
        if text[i] == "<":
            j = text.find(">", i)
            if j < 0:
                raise ValueError(f"unterminated <token> in {text!r}")
            tok = text[i:j + 1]
            if tok not in toks:
                raise ValueError(f"unknown charmap token {tok!r}")
            out.append(toks[tok])
            i = j + 1
            continue
        # run of plain characters up to the next '<'
        nxt = text.find("<", i)
        run = text[i:] if nxt < 0 else text[i:nxt]
        out.extend(gb_text.encode(run))
        i += len(run)
    if "@" in text:
        raise ValueError(f'string terminator "@" in name: {text!r}')
    if len(out) > NAME_LENGTH:
        raise ValueError(f"name longer than {NAME_LENGTH} characters: {text!r}")
    out += [TERMINATOR] * (NAME_LENGTH - len(out))
    return out


def main() -> int:
    toks = load_named_tokens()

    rows = []
    for line in SRC.read_text(encoding="utf-8").splitlines():
        m = NPCTRADE_RE.match(line.split(";", 1)[0])
        if m:
            give, get, dialogset, nick = m.groups()
            rows.append((give, get, dialogset, nick, encode_name(nick, toks)))
    if not rows:
        sys.stderr.write(f"gen_trades: no npctrade rows parsed from {SRC}\n")
        return 1

    out = [
        "; trades.inc — generated by tools/generators/gen_trades.py. DO NOT EDIT BY HAND.",
        "; pret: data/events/trades.asm (TradeMons). Carrier:",
        "; dos_port/src/data/events/trades.asm — pret's own path, per the mirror rule.",
        "; InGameTrade_TrainerString is NOT here: pret defines it in",
        "; engine/events/in_game_trades.asm, so it goes to trade_trainer_string.inc.",
        "; Nicknames are GB-charmap",
        f"; encoded and '@'-padded ($50) to NAME_LENGTH={NAME_LENGTH}, exactly as",
        "; RGBDS `dname` does; species and dialogset stay as their pret constant",
        "; names (assets/script_constants.inc / include/gb_constants.inc).",
        f"; Row stride: 3 + {NAME_LENGTH} = {3 + NAME_LENGTH} bytes ($e).",
        "",
        "; entries correspond to TRADE_FOR_* constants",
        "TradeMons:",
    ]
    for give, get, dialogset, nick, enc in rows:
        out.append(f"    db {give}, {get}, {dialogset}")
        out.append("    db " + ", ".join(f"0x{b:02X}" for b in enc)
                   + f'   ; dname "{nick}", NAME_LENGTH')
    out.append("")

    trainer = [
        "; trade_trainer_string.inc — generated by tools/generators/gen_trades.py. DO NOT EDIT BY HAND.",
        "; pret: engine/events/in_game_trades.asm:InGameTrade_TrainerString — the OT",
        "; name every in-game-trade mon is stamped with. Kept OUT of trades.inc because",
        "; that file's home is the data/events/ mirror and this label's is the engine",
        "; file; %included by src/engine/events/in_game_trades.asm inside section .data.",
        f"; GB-charmap encoded and '@'-padded ($50) to NAME_LENGTH={NAME_LENGTH}, as `dname` does.",
        ";",
        "; This .inc declares its OWN `global`, unlike trades.inc next door, and the",
        "; difference is load-bearing rather than stylistic. InGameTrade_TrainerString",
        "; is a pret ENGINE label, so it lives in lint_pret_labels' `labels` table and",
        "; is subject to the `local_shadow` rule: a pret label defined non-global in a",
        "; file other than its selected provider is a strict-claims violation. TradeMons",
        "; is a pret DATA label, so it lives in `aux_labels`, which that rule does not",
        "; cover -- which is why its carrier may declare the global instead. Same",
        "; def-site-global pattern as map_script_tables.inc and 34 other assets/*.inc.",
        "",
        "global InGameTrade_TrainerString",
        "",
        "InGameTrade_TrainerString:",
        "    db " + ", ".join(f"0x{b:02X}" for b in encode_name(TRAINER_STRING, toks))
        + f'   ; dname "{TRAINER_STRING}", NAME_LENGTH',
        "",
    ]

    ASSETS.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(out))
    OUT_TRAINER.write_text("\n".join(trainer))
    print(f"wrote {OUT} ({len(rows)} npctrade rows)")
    print(f"wrote {OUT_TRAINER} (InGameTrade_TrainerString)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
