#!/usr/bin/env python3
"""gen_charmap.py — generate dos_port/assets/gb_charmap.txt from pret source.

Emits the Gen-1 character map in the format the unicode_converter submodule
(Pokemon_Bootleg_Green_Scripts) expects: one `<char>;<HH>` line per mapping,
where <char> is a single Unicode character and <HH> is its 2-digit GB byte.

Only SINGLE-character entries from constants/charmap.asm are emitted — the
converter maps one Unicode char to one byte and cannot represent pret's
multi-char tokens (the 'd/'s/'t contractions, <PLAYER>, "#" -> POKé, etc.). Those
are intentionally excluded; data that needs them keeps its own greedy encoder.

Run from repo root or dos_port/.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "dos_port" / "assets"

# charmap "<key>", $HH   — key may contain escaped chars; capture it verbatim.
_CHARMAP_RE = re.compile(r'\s*charmap\s+"((?:[^"\\]|\\.)*)",\s*\$([0-9a-fA-F]+)')


def main() -> int:
    src = ROOT / "constants" / "charmap.asm"
    rows = []
    for line in src.read_text(encoding="utf-8").splitlines():
        m = _CHARMAP_RE.match(line)
        if not m:
            continue
        key, val = m.group(1), int(m.group(2), 16)
        if len(key) != 1:          # single Unicode char only (see module docstring)
            continue
        rows.append((key, val))

    out = [f"{key};{val:02X}" for key, val in rows]

    ASSETS.mkdir(parents=True, exist_ok=True)
    dst = ASSETS / "gb_charmap.txt"
    dst.write_text("\n".join(out) + "\n", encoding="utf-8")
    print(f"wrote {dst} ({len(rows)} single-char mappings)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
