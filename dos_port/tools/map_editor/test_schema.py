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
from map_editor import schema, overrides, staging, view, commands


DOCK_RECIPE = {"kind": "repeat_base_column", "edge": "east",
               "source_x": 12, "count": 8, "row_overrides": [[1, 13]]}


class MapDiffTest(unittest.TestCase):
    def test_dock_recipe_matches_legacy_widening(self):
        """The sanctioned widening RULE, composed without the authored sidecar.

        The committed sidecar also carries hand-painted cells over the generated
        columns (deliberate aesthetic edits), so composing the sidecar would test
        those, not the recipe. Build the recipe-only diff and compose that.
        """
        info = pm.map_info("VERMILION_DOCK")
        raw = pm.load_blk(info)
        recipe_only = schema.MapDiff("VermilionDock", schema.Extents(east=8),
                                     recipes=[dict(DOCK_RECIPE)])
        with patch.object(schema, "load", return_value=recipe_only):
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

    def test_authored_cells_win_over_the_recipe(self):
        """A hand-painted cell on a generated column overrides what the recipe fills.

        The recipe widens the map; painting on the new columns afterwards is
        allowed and takes precedence. schema.recipe_cells still stops the
        EXPANDER from writing there, which is a different thing.
        """
        info = pm.map_info("VERMILION_DOCK")
        raw = pm.load_blk(info)
        authored = schema.load("VermilionDock").added_blocks
        composed, width, _height, _diff = schema.compose_layout(
            "VermilionDock", raw, info.base_w, info.base_h)
        self.assertTrue(authored, "fixture: the dock sidecar carries painted cells")
        for (y, x), block in authored.items():
            self.assertEqual(composed[y * width + x], block,
                             f"authored cell ({y},{x}) must survive composition")

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
        with TemporaryDirectory() as directory, patch.object(staging, "ROOT", Path(directory)):
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

    def test_unusable_pret_maps_report_a_reason_not_a_traceback(self):
        """Two pret maps are data-broken; the editor must skip, not crash."""
        self.assertTrue(view.can_compose("PALLET_TOWN"))
        for const in ("UNDERGROUND_PATH_NORTH_SOUTH", "UNDERGROUND_PATH_ROUTE_7_COPY"):
            self.assertFalse(view.can_compose(const), const)
            with self.assertRaisesRegex(ValueError, "cannot load pret block layout"):
                view.compose_padded(const)

    def test_recipe_cells_protect_generated_columns(self):
        """The expander must not add explicit cells over a recipe's output."""
        diff = schema.MapDiff("VermilionDock", schema.Extents(east=8),
                              recipes=[{"kind": "repeat_base_column", "edge": "east",
                                        "source_x": 12, "count": 8,
                                        "row_overrides": [[1, 13]]}])
        covered = schema.recipe_cells(diff, 14, 6)
        self.assertEqual(len(covered), 6 * 9)
        self.assertIn((0, 13), covered)
        self.assertIn((0, 21), covered)
        self.assertNotIn((0, 22), covered)
        self.assertNotIn((0, 12), covered)

    def test_expansion_fills_new_cells_with_border_block(self):
        info = pm.map_info("PALLET_TOWN")
        raw = pm.load_blk(info)
        border = pm.objects(info)[0]
        with TemporaryDirectory() as directory:
            root = Path(directory)
            with patch.object(staging, "ROOT", root):
                commands.set_extents("PALLET_TOWN", north=1, west=0,
                                     south=0, east=0, write=True)
                diff = schema.load("PalletTown")
                self.assertEqual(diff.extents.north, 1)
                composed, width, height, _ = schema.compose_layout(
                    "PalletTown", raw, info.base_w, info.base_h)
            self.assertEqual((width, height), (info.base_w, info.base_h + 1))
            # Original map intact one block down; the new top row is the border.
            for y in range(info.base_h):
                row = bytes(composed[(y + 1) * width:(y + 2) * width])
                self.assertEqual(row, raw[y * info.base_w:(y + 1) * info.base_w])
            self.assertEqual(bytes(composed[:width]), bytes([border]) * width)
        pm._constants.cache_clear()
        pm.map_info.cache_clear()

    def test_generator_sees_expanded_dimensions_and_objects(self):
        """Header generation and object lowering share the one expansion diff."""
        info = pm.map_info("PALLET_TOWN")
        npc_before = pm.gmh.parse_object_file(info.label)[3][0]
        with TemporaryDirectory() as directory:
            root = Path(directory)
            with patch.object(staging, "ROOT", root):
                commands.set_extents("PALLET_TOWN", north=1, west=2,
                                     south=0, east=0, write=True)
                dims = pm.gmh.parse_map_constants()
                raw = pm.gmh.parse_map_constants(expand=False)
                npc_after = pm.gmh.parse_object_file(info.label)[3][0]
            self.assertEqual(dims["PALLET_TOWN"][1:], (12, 10))
            self.assertEqual(raw["PALLET_TOWN"][1:], (10, 9))
        # north 1 block = 2 map squares; west 2 blocks = 4 map squares.
        self.assertEqual(npc_after["mapy"], npc_before["mapy"] + 2)
        self.assertEqual(npc_after["mapx"], npc_before["mapx"] + 4)
        pm._constants.cache_clear()
        pm.map_info.cache_clear()

    def test_expansion_script_edit_is_staged_until_commit(self):
        """A script rewrite is the riskiest write: it must not land until saved."""
        with TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / 'dos_port/src/scripts/PalletTown.asm'
            path.parent.mkdir(parents=True)
            path.write_text('db 8, 10 ; dbmapcoord 10, 8\n')
            with patch.object(staging, 'ROOT', root):
                staging.begin()
                try:
                    commands.set_extents('PALLET_TOWN', north=1, west=2,
                                         south=0, east=0, write=True)
                    self.assertEqual(path.read_text(),
                                     'db 8, 10 ; dbmapcoord 10, 8\n',
                                     'the tree script must be untouched before save')
                    staged = staging.current().read_path(
                        'dos_port/src/scripts/PalletTown.asm')
                    self.assertIn('db 10, 14', staged.read_text())
                    written = staging.current().commit()
                    self.assertIn('dos_port/src/scripts/PalletTown.asm', written)
                    self.assertEqual(path.read_text(),
                                     'db 10, 14 ; dbmapcoord 14, 10\n')
                finally:
                    staging.end()
            pm._constants.cache_clear()
            pm.map_info.cache_clear()

    def test_north_west_expansion_moves_classified_script_once(self):
        with TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / 'dos_port/src/scripts/PalletTown.asm'
            path.parent.mkdir(parents=True)
            path.write_text('db 8, 10 ; dbmapcoord 10, 8\n; dbmapcoord 9, 9\n')
            with patch.object(staging, 'ROOT', root):
                result = commands.set_extents('PALLET_TOWN', north=1, west=2,
                                              south=0, east=0, write=True)
                self.assertEqual(result['automatic_delta'], [4, 8])
                self.assertEqual((pm.map_info('PALLET_TOWN').w, pm.map_info('PALLET_TOWN').h), (12, 10))
                self.assertEqual(path.read_text(), 'db 10, 14 ; dbmapcoord 14, 10\n; dbmapcoord 9, 9\n')
                self.assertEqual(result['script_changes'][0]['before'], [16, 20])
                self.assertFalse(result['coverage']['script_coordinates_complete'])
                self.assertTrue(schema.load('PalletTown').added_blocks)
                repeated = commands.set_extents('PALLET_TOWN', north=1, west=2,
                                                south=0, east=0, write=True)
                self.assertEqual(repeated['automatic_delta'], [0, 0])
                self.assertEqual(path.read_text(), 'db 10, 14 ; dbmapcoord 14, 10\n; dbmapcoord 9, 9\n')
            pm._constants.cache_clear()
            pm.map_info.cache_clear()


if __name__ == "__main__":
    unittest.main()
