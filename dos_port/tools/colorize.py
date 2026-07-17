#!/usr/bin/env python3
"""Palette tool entry point (C0 data pipeline; later modes reserve this CLI)."""
from __future__ import annotations

import argparse
from pathlib import Path
import subprocess
import sys

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE / "generators"))

from colors import schema

SIDECAR = HERE.parent / "assets" / "colors" / "palettes.json"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    actions = parser.add_mutually_exclusive_group(required=True)
    actions.add_argument("--gen", action="store_true", help="regenerate palettes.inc")
    actions.add_argument("--verify", action="store_true", help="validate sidecar and generated output")
    actions.add_argument("--edit", action="store_true", help="launch the palette editor (C2)")
    actions.add_argument("--export-png", metavar="ASSET", help="export repaint PNG (C3)")
    actions.add_argument("--import-png", metavar="PNG", help="import repaint PNG (C3)")
    args = parser.parse_args()
    if args.gen:
        subprocess.run([sys.executable, str(HERE / "generators" / "gen_palettes.py")], check=True)
        return
    if args.verify:
        schema.load(SIDECAR)
        generated = (HERE.parent / "assets" / "colors" / "palettes.inc")
        if not generated.exists():
            raise SystemExit("palettes.inc is missing; run colorize.py --gen")
        from gen_palettes import emit
        if generated.read_text() != emit():
            raise SystemExit("palettes.inc is stale; run colorize.py --gen")
        print("palette sidecar and generated table are valid")
        return
    if args.edit:
        from colors.editor import main as edit
        sys.argv = [sys.argv[0]]
        edit()
        return
    from colors import repaint
    sidecar = schema.load(SIDECAR)
    if args.export_png:
        print(repaint.export_png(args.export_png, sidecar))
        return
    print("imported " + repaint.import_png(args.import_png, sidecar, SIDECAR))


if __name__ == "__main__":
    main()
