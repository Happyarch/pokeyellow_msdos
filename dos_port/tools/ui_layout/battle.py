#!/usr/bin/env python3
"""battle.py — launch the layout editor on the battle sidecar.

Usage (from dos_port/):
  python3 tools/ui_layout/battle.py [--bg FRAME.BIN] [--zoom 3]

Same editor as editor.py (see its docstring for controls); this just fixes
the sidecar to assets/ui_layout_battle_sidecar.json and defaults --bg to a
DEBUG_BATTLE FRAME.BIN dump next to the assets if one exists.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

DOS_PORT = Path(__file__).resolve().parent.parent.parent
SIDECAR = DOS_PORT / "assets" / "ui_layout_battle_sidecar.json"
DEFAULT_BG = DOS_PORT / "FRAME.BIN"


def main() -> None:
    argv = [str(SIDECAR)] + sys.argv[1:]
    if "--bg" not in argv and DEFAULT_BG.exists():
        argv += ["--bg", str(DEFAULT_BG)]
    sys.argv = [sys.argv[0]] + argv
    from ui_layout.editor import main as editor_main
    editor_main()


if __name__ == "__main__":
    main()
