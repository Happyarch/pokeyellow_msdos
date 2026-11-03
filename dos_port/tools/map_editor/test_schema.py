"""Focused regression tests for map-authoring composition.

Run with: python3 tools/map_editor/test_schema.py
"""
from __future__ import annotations

import sys
from pathlib import Path
import unittest
from tempfile import TemporaryDirectory
from types import SimpleNamespace
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from gfx_core import pret_maps as pm
from map_editor import schema, overrides, view, commands


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

    def test_growth_preserves_added_cells(self):
        diff = schema.MapDiff("Example", added_blocks={(2, 3): 9})
        schema.set_absolute_extents(diff, north=2, west=1, south=0, east=0)
        self.assertEqual(diff.added_blocks, {(4, 4): 9})
        schema.set_absolute_extents(diff, north=2, west=1, south=0, east=0)
        self.assertEqual(diff.added_blocks, {(4, 4): 9})

    def test_paint_save_preserves_recipe_and_other_fields(self):
        with TemporaryDirectory() as directory, patch.object(schema, "OVERRIDES", Path(directory)), \
             patch.object(overrides, "MAP_OVERRIDES_DIR", Path(directory)):
            diff = schema.MapDiff("Test", schema.Extents(east=2),
                                  recipes=[{"kind": "repeat_base_column", "edge": "east",
                                            "source_x": 0, "count": 2}],
                                  extra={"new_objects": [{"id": "human"}]})
            schema.write(diff)
            info = SimpleNamespace(w=4, h=1, base_w=2, base_h=1)
            overrides.save("Test", {(0, 1): 3, (0, 3): 4}, info, 8)
            saved = schema.load("Test")
            self.assertEqual(saved.extents.east, 2)
            self.assertEqual(saved.recipes, diff.recipes)
            self.assertEqual(saved.extra, diff.extra)
            self.assertEqual(saved.base_blocks, {(0, 1): 4})
            self.assertEqual(saved.added_blocks, {(0, 1): 3})
            self.assertEqual(overrides.load("Test", info), {(0, 1): 3, (0, 3): 4})

    def test_overlay_uses_four_tiles_per_border_block(self):
        self.assertEqual(view.warp_px(None, 0, 0), (view.BORDER * 32,) * 2)
        self.assertEqual(view.sprite_px(None, 4, 4), (view.BORDER * 32,) * 2)

    def test_north_west_write_rejected_until_events_are_relocated(self):
        with self.assertRaisesRegex(ValueError, "not automatically relocated"):
            commands.set_extents("PALLET_TOWN", north=1, west=0,
                                 south=0, east=0, write=True)


if __name__ == "__main__":
    unittest.main()
