"""Focused regression tests for map-authoring composition.

Run with: python3 tools/map_editor/test_schema.py
"""
from __future__ import annotations

import sys
from pathlib import Path
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from gfx_core import pret_maps as pm
from map_editor import schema


class MapDiffTest(unittest.TestCase):
    def test_dock_recipe_matches_legacy_widening(self):
        info = pm.map_info("VERMILION_DOCK")
        raw = pm.load_blk(info)
        composed, width, height, diff = schema.compose_layout(
            "VermilionDock", raw, info.base_w, info.base_h)
        self.assertEqual((width, height), (22, 6))
        self.assertEqual(diff.extents.east, 8)
        expected = bytearray()
        for y in range(info.base_h):
            row = raw[y * info.base_w:(y + 1) * info.base_w]
            fill = 0x0D if y == 1 else row[12]
            expected += row[:13] + bytes([fill]) * 8 + row[13:]
        self.assertEqual(bytes(composed), bytes(expected))

    def test_absolute_extent_is_idempotent(self):
        diff = schema.MapDiff("Example")
        diff, delta = schema.set_absolute_extents(
            diff, north=1, west=2, south=0, east=0)
        self.assertEqual(delta, (4, 8))
        diff, repeat = schema.set_absolute_extents(
            diff, north=1, west=2, south=0, east=0)
        self.assertEqual(repeat, (0, 0))


if __name__ == "__main__":
    unittest.main()
