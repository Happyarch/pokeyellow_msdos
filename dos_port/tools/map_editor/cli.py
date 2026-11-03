#!/usr/bin/env python3
"""JSON CLI for deterministic map-editor reads, writes, and renders."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from map_editor import commands


def _json(value: dict) -> None:
    print(json.dumps(value, indent=1, sort_keys=True))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="map_editor_cli")
    subs = parser.add_subparsers(dest="command", required=True)
    inspect = subs.add_parser("inspect")
    inspect.add_argument("map")
    blocks = subs.add_parser("blocks")
    bsub = blocks.add_subparsers(dest="blocks_command", required=True)
    set_block = bsub.add_parser("set")
    set_block.add_argument("map")
    set_block.add_argument("--y", type=int, required=True)
    set_block.add_argument("--x", type=int, required=True)
    set_block.add_argument("--block", type=lambda s: int(s, 0), required=True)
    set_block.add_argument("--write", action="store_true")
    objects = subs.add_parser("objects")
    osub = objects.add_subparsers(dest="objects_command", required=True)
    set_object = osub.add_parser("set")
    set_object.add_argument("map")
    set_object.add_argument("--object", required=True)
    set_object.add_argument("--y", type=int)
    set_object.add_argument("--x", type=int)
    set_object.add_argument("--sprite")
    set_object.add_argument("--movement")
    set_object.add_argument("--facing")
    set_object.add_argument("--write", action="store_true")
    script = subs.add_parser("scripts")
    ssub = script.add_subparsers(dest="scripts_command", required=True)
    scan = ssub.add_parser("scan")
    scan.add_argument("map")
    expand = subs.add_parser("expand")
    expand.add_argument("map")
    for edge in ("north", "west", "south", "east"):
        expand.add_argument(f"--{edge}-total", type=int, required=True)
    expand.add_argument("--write", action="store_true")
    render = subs.add_parser("render")
    render.add_argument("map")
    render.add_argument("--out", type=Path, required=True)
    render.add_argument("--zoom", type=int, default=1)
    args = parser.parse_args(argv)
    try:
        if args.command == "inspect":
            result = commands.inspect_map(args.map)
        elif args.command == "blocks":
            result = commands.set_block(args.map, y=args.y, x=args.x,
                                        block=args.block, write=args.write)
        elif args.command == "expand":
            result = commands.set_extents(args.map, north=args.north_total,
                                          west=args.west_total,
                                          south=args.south_total,
                                          east=args.east_total, write=args.write)
        elif args.command == "objects":
            result = commands.set_object(args.map, args.object, y=args.y, x=args.x,
                                         sprite=args.sprite, movement=args.movement,
                                         facing=args.facing, write=args.write)
        elif args.command == "scripts":
            result = commands.scan_scripts(args.map)
        else:
            result = commands.render(args.map, out=args.out, zoom=args.zoom)
    except (ValueError, OSError) as exc:
        _json({"schema": 1, "written": False, "error": str(exc)})
        return 2
    _json(result)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
