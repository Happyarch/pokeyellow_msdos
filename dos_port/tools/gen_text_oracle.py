#!/usr/bin/env python3
"""gen_text_oracle.py — generate dos_port/assets/text_oracle.inc.

The text-engine oracle's command streams (docs/current_plan_text_engine.md,
Stage 0). Consumed by src/debug/debug_dump.asm:RunTextTest under DEBUG_TEXT=<n>.

These are not game text — they are probe streams, one per TX_* command, chosen so
that a single FRAME.BIN capture says unambiguously whether that command still
works. They exist because NO golden scenario and no other harness renders a text
stream directly: the previous attempt at the flat-pointer refactor passed
`make fidelity` 6/6 while rendering garbage in a live dialog.

The strings are still rendered glyphs, so they are Tier-1 data and get charmap
encoded here (gb_text.encode) rather than hand-written as `db 0x..` in the .asm.

Stream shape, since it is easy to get wrong:
  TX_START ($00) renders an inline string that PlaceString ends at "@" ($50) —
  the SAME byte as TX_END. So "@" ends the *string* and hands control back to
  TextCommandProcessor, which then reads the next command byte. To end the whole
  stream from inside a string, use <DONE> ($57): PlaceString redirects the stream
  pointer at the TX_END sentinel (text_engine_init) and TCP exits.

Run from repo root or dos_port/.
"""
import os
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gb_text  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "dos_port" / "assets"

# Text-command bytes (mirror of include/gb_text.inc).
TX_START, TX_RAM, TX_BCD, TX_NUM, TX_DOTS, TX_FAR, TX_END = (
    0x00, 0x01, 0x02, 0x09, 0x0C, 0x17, 0x50)
CHAR_LINE, CHAR_PARA, CHAR_DONE = 0x4F, 0x51, 0x57


def s(text):
    """An encoded glyph run (no terminator — the caller appends one)."""
    return gb_text.encode(text)


# Each case is a list of items: an int (raw byte), a str (encoded glyph run), or
# a ("dw"|"dd", "symbol expr") tuple emitted as a NASM operand.
CASES = {
    # 1 — plain text + <LINE>. The baseline: if this breaks, everything is broken.
    "txt_oracle_plain": [
        TX_START, s("TEXT ORACLE"), CHAR_LINE, s("PLAIN AND LINE"), CHAR_DONE,
    ],
    # 2 — <PARA>: page break. Waits for A (manual_text_scroll) → needs an autokey
    # press; the capture lands on whichever page AUTOKEY_DUMP_FRAME reaches.
    "txt_oracle_para": [
        TX_START, s("PAGE ONE HERE"), CHAR_PARA, s("PAGE TWO HERE"), CHAR_DONE,
    ],
    # 3 — TX_RAM: splice an '@'-terminated string from WRAM (the harness seeds
    # wStringBuffer). This is the command battle text leans on for nicknames.
    "txt_oracle_ram": [
        TX_START, s("RAM"), TX_END,
        TX_RAM, ("dw", "wStringBuffer"),
        TX_START, s("END"), CHAR_DONE,
    ],
    # 4 — TX_NUM: 2-byte BIG-endian value, 5 digits (the harness seeds 4242).
    "txt_oracle_num": [
        TX_START, s("NUM"), TX_END,
        TX_NUM, ("dw", "wStringBuffer + 20"), (2 << 4) | 5,
        TX_START, s("END"), CHAR_DONE,
    ],
    # 5 — TX_BCD: 3-byte BCD money (the harness seeds 123456).
    "txt_oracle_bcd": [
        TX_START, s("BCD"), TX_END,
        TX_BCD, ("dw", "wStringBuffer + 16"), 3,
        TX_START, s("END"), CHAR_DONE,
    ],
    # 6 — TX_FAR: the whole point. The `text_far` macro emits a 32-bit FLAT label
    # (gb_text.inc), so the operand is a `dd`, not pret's 3-byte addr+bank. TCP
    # must recurse into the target and RESUME the outer stream after it — hence
    # the "END" after the command: if the splice desyncs, that word is corrupted
    # or missing, which is exactly the failure mode this case exists to catch.
    "txt_oracle_far": [
        TX_START, s("FAR"), TX_END,
        TX_FAR, ("dd", "txt_oracle_far_target"),
        TX_START, s("END"), CHAR_DONE,
    ],
    # The far target is itself a command stream: TX_END returns from the recursion.
    "txt_oracle_far_target": [
        TX_START, s("SPLICED"), TX_END,
        TX_END,
    ],
    # The string the harness copies into wStringBuffer for the TX_RAM case.
    "txt_oracle_ramstr": [
        s("PIKACHU"), TX_END,   # '@'-terminated, as PlaceString expects
    ],
    # 7 — TX_DOTS: N '…' glyphs, one per ~10 frames.
    "txt_oracle_dots": [
        TX_START, s("DOTS"), TX_END,
        TX_DOTS, 3,
        TX_START, s("END"), CHAR_DONE,
    ],
}

# The order matters: RunTextTest indexes this table by DEBUG_TEXT=<n>, so the
# pointer table in the .inc is generated from it too. far_target is not a case.
CASE_ORDER = [
    "txt_oracle_plain",
    "txt_oracle_para",
    "txt_oracle_ram",
    "txt_oracle_num",
    "txt_oracle_bcd",
    "txt_oracle_far",
    "txt_oracle_dots",
]


def emit(label, items):
    lines = [f"{label}:"]
    pending = []

    def flush():
        if pending:
            lines.append("    db " + ", ".join(pending))
            pending.clear()

    for it in items:
        if isinstance(it, tuple):
            flush()
            lines.append(f"    {it[0]} {it[1]}")
        elif isinstance(it, int):
            pending.append(f"0x{it:02X}")
        else:  # encoded glyph run
            pending.extend(f"0x{b:02X}" for b in it)
    flush()
    return lines


def main() -> int:
    out = [
        "; text_oracle.inc — generated by tools/gen_text_oracle.py.",
        "; DO NOT EDIT BY HAND.",
        ";",
        "; Text-engine oracle probe streams — one per TX_* command. Driven by",
        "; src/debug/debug_dump.asm:RunTextTest (make DEBUG_TEXT=<n>). See",
        "; docs/current_plan_text_engine.md, Stage 0.",
        "",
    ]
    for label in CASE_ORDER + ["txt_oracle_far_target", "txt_oracle_ramstr"]:
        out += emit(label, CASES[label]) + [""]

    out += [
        "; DEBUG_TEXT=<n> indexes this table (1-based; n=0 is rejected by the harness).",
        "align 4",
        "txt_oracle_cases:",
    ]
    out += [f"    dd {label}" for label in CASE_ORDER]
    out += [f"txt_oracle_case_count equ {len(CASE_ORDER)}", ""]

    ASSETS.mkdir(parents=True, exist_ok=True)
    dst = ASSETS / "text_oracle.inc"
    dst.write_text("\n".join(out) + "\n")
    print(f"wrote {dst} ({len(CASE_ORDER)} cases)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
