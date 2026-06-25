"""gb_text.py — GB charmap text encoding via the unicode_converter submodule.

Thin wrapper around the MPL-2.0 bidirectional converter vendored as the
`unicode_converter` git submodule (Happyarch/Pokemon_Bootleg_Green_Scripts). It
loads the generated GB charmap (assets/gb_charmap.txt — see gen_charmap.py) once
and exposes encode(): Unicode string -> list of GB byte values.

LIMITATION (by design): the converter maps a single Unicode char to a single
byte. It does NOT implement pret's greedy multi-char tokens — the 'd/'s/'t
apostrophe contractions, <PLAYER>/<RIVAL>, "#" -> "POKé", etc. Use this only for
strings authored in the single-char charset (e.g. the START-menu labels). pret-
derived data that contains those tokens (item names like "OAK's PARCEL", monster
names like "FARFETCH'D") must keep the greedy encoder in its own generator, or it
would silently encode to different bytes.
"""
import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_CONVERTER = os.path.join(_HERE, "unicode_converter")
if _CONVERTER not in sys.path:
    sys.path.insert(0, _CONVERTER)

# From the submodule — this is the actual integration point.
from data_manipulation_logic import file_init, unicode_to_raw  # noqa: E402

CHARMAP_PATH = os.path.normpath(os.path.join(_HERE, "..", "assets", "gb_charmap.txt"))

_charmap = None


def _load():
    global _charmap
    if _charmap is None:
        if not os.path.exists(CHARMAP_PATH):
            raise FileNotFoundError(
                f"{CHARMAP_PATH} missing — run tools/gen_charmap.py "
                "(Makefile target: assets/gb_charmap.txt)."
            )
        _charmap = file_init(CHARMAP_PATH)
    return _charmap


def encode(s: str) -> list:
    """Unicode string -> list[int] of GB bytes (no terminator).

    Raises ValueError if any character is not in the single-char charmap (the
    converter substitutes U+FFFD for misses; we turn that into a hard error so a
    typo never slips a replacement glyph into generated game data).
    """
    cmap = _load()
    raw = unicode_to_raw(s, cmap, False)   # concatenated 2-digit hex, e.g. "8F8E8A"
    if "�" in raw:
        missing = sorted({c for c in s if c not in cmap})
        raise ValueError(f"unmapped char(s) {missing!r} in {s!r}")
    return [int(raw[i:i + 2], 16) for i in range(0, len(raw), 2)]
