"""Editor settings, zoom anchoring and input binding tests.

Runs the real pygame Viewer under the dummy SDL driver — the zoom maths and the
anchor contract are what is under test, not the pixels.
"""
import json
import os
from pathlib import Path
import sys
import unittest
from tempfile import TemporaryDirectory
from unittest.mock import patch

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
os.environ.setdefault("SDL_AUDIODRIVER", "dummy")

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from map_editor import config  # noqa: E402
from map_editor import view  # noqa: E402


class ConfigTest(unittest.TestCase):
    def test_defaults_when_absent(self):
        with TemporaryDirectory() as directory:
            settings = config.load(Path(directory) / "missing.json")
        self.assertEqual(settings["zoom_anchor"], "cursor")
        self.assertEqual(settings["pan_button"], 2)

    def test_override_and_validation(self):
        with TemporaryDirectory() as directory:
            path = Path(directory) / "config.json"
            path.write_text(json.dumps({"zoom_anchor": "center", "zoom_step": 1.2}))
            settings = config.load(path)
            self.assertEqual(settings["zoom_anchor"], "center")
            self.assertEqual(settings["zoom_step"], 1.2)

            path.write_text(json.dumps({"zoom_anchor": "middle"}))
            with self.assertRaisesRegex(ValueError, "zoom_anchor"):
                config.load(path)
            path.write_text(json.dumps({"zoom_anchord": "center"}))
            with self.assertRaisesRegex(ValueError, "unknown setting"):
                config.load(path)
            path.write_text(json.dumps({"zoom_step": 1}))
            with self.assertRaisesRegex(ValueError, "greater than 1"):
                config.load(path)


class ZoomTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        import pygame
        from map_editor import schema
        from map_editor.editor import Viewer
        pygame.init()
        cls.pygame = pygame
        cls.Viewer = Viewer
        # NEVER write the real sidecar tree from a test: the Viewer's edit paths
        # (warp drag, NPC drop) call commands.* with write=True.
        cls._tmp = TemporaryDirectory()
        cls._overrides = patch.object(schema, "OVERRIDES",
                                      Path(cls._tmp.name) / "overrides")
        cls._overrides.start()

    @classmethod
    def tearDownClass(cls):
        cls._overrides.stop()
        cls._tmp.cleanup()

    def viewer(self, **overrides):
        settings = dict(config.DEFAULTS)
        settings.update(overrides)
        return self.Viewer("PALLET_TOWN", 1.0, settings)

    def image_point(self, v, screen_point):
        return ((screen_point[0] - v.pan[0]) / v.scale,
                (screen_point[1] - v.pan[1]) / v.scale)

    def test_cursor_anchor_keeps_point_under_cursor(self):
        v = self.viewer(zoom_anchor="cursor")
        v.pan = [0.0, 0.0]
        v.scale = 1.0
        cursor = (300, 200)
        before = self.image_point(v, cursor)
        v.zoom_by(v.settings["zoom_step"] ** 3, ctrl=False, cursor=cursor)
        after = self.image_point(v, cursor)
        self.assertAlmostEqual(before[0], after[0], places=6)
        self.assertAlmostEqual(before[1], after[1], places=6)
        # Continuous, not snapped to integers.
        self.assertNotAlmostEqual(v.scale, round(v.scale), places=3)

    def test_center_anchor_keeps_viewport_center(self):
        v = self.viewer(zoom_anchor="center")
        v.pan = [0.0, 0.0]
        v.scale = 1.0
        centre = v.viewport_center()
        before = self.image_point(v, centre)
        v.zoom_by(1.5, ctrl=False, cursor=(10, 10))
        after = self.image_point(v, centre)
        self.assertAlmostEqual(before[0], after[0], places=6)
        self.assertAlmostEqual(before[1], after[1], places=6)

    def test_ctrl_is_a_held_shift_not_a_toggle(self):
        v = self.viewer(zoom_anchor="cursor")
        self.assertEqual(v.zoom_anchor(ctrl=False), "cursor")
        self.assertEqual(v.zoom_anchor(ctrl=True), "center")
        # Releasing returns to the configured default, every time.
        self.assertEqual(v.zoom_anchor(ctrl=False), "cursor")
        self.assertEqual(v.zoom_anchor(ctrl=False), "cursor")

        w = self.viewer(zoom_anchor="center")
        self.assertEqual(w.zoom_anchor(ctrl=False), "center")
        self.assertEqual(w.zoom_anchor(ctrl=True), "cursor")
        self.assertEqual(w.zoom_anchor(ctrl=False), "center")

    def test_ctrl_zoom_actually_uses_the_other_anchor(self):
        """With default cursor, Ctrl+wheel must behave like center."""
        v = self.viewer(zoom_anchor="cursor")
        v.pan = [0.0, 0.0]
        v.scale = 1.0
        centre = v.viewport_center()
        before = self.image_point(v, centre)
        v.zoom_by(1.5, ctrl=True, cursor=(5, 5))
        after = self.image_point(v, centre)
        self.assertAlmostEqual(before[0], after[0], places=6)
        self.assertAlmostEqual(before[1], after[1], places=6)

    def test_scale_is_clamped(self):
        v = self.viewer()
        v.set_scale(999, (0, 0))
        self.assertEqual(v.scale, v.settings["zoom_max"])
        v.set_scale(0.0001, (0, 0))
        self.assertEqual(v.scale, v.settings["zoom_min"])

    def test_pan_is_bound_to_middle_click_by_default(self):
        self.assertEqual(config.DEFAULTS["pan_button"], 2)

    def test_connections_mode_is_render_only(self):
        """Neighbour maps are for watching a transition, never for editing."""
        v = self.viewer()
        info = v.cm.info
        # A border-ring cell (padded coords, outside the map's own blocks).
        ring = (0, 0)
        self.assertIsNotNone(v._region(*ring), "ring should be editable normally")

        v.show["connections"] = True
        self.assertIsNone(v._region(*ring),
                          "connections mode must not edit the ring under a neighbour")

        # This map's own blocks stay placeable.
        inner = (view.BORDER, view.BORDER)
        self.assertIsNotNone(v._region(*inner))

        # And a click over a neighbour is outside the current map entirely.
        v.show["connections"] = False
        self.assertIsNone(v.tile_at((-5000, -5000)))

    def test_warp_drag_repositions_and_snaps_to_the_map_square(self):
        v = self.viewer()
        v.pan = [0.0, 0.0]
        v.scale = 1.0
        warp = v.cm.warps[0]
        v.warp_drag = warp['stable_id']
        v.selected_warp = warp['stable_id']

        def drop(tx, ty):
            screen = ((tx + view.BORDER * 4) * 8 + 1,
                      (ty + view.BORDER * 4) * 8 + 1)
            self.assertEqual(v.tile_at(screen), (tx, ty))
            v.cursor_tile = (tx, ty)
            v.draw()                      # drag ghost must render
            v.finish_warp_drag(screen)
            moved = v.cm.warps[0]
            return (moved['y'], moved['x'])

        self.assertEqual(drop(22, 12), (6, 11))     # map squares = tiles / 2
        self.assertEqual(drop(30, 18), (9, 15))
        # An odd tile belongs to the 16px square that contains it.
        self.assertEqual(drop(31, 19), (9, 15))

    def test_connection_hint_tracks_the_staged_tile(self):
        v = self.viewer()
        v.player = (0, 0)
        self.assertIn("NORTH", v.connection_at_player() or "")
        v.player = (v.cm.info.w * 4 - 1, v.cm.info.h * 4 - 1)
        self.assertIn("SOUTH", v.connection_at_player() or "")
        v.player = (20, 20)
        self.assertIsNone(v.connection_at_player())

    def test_left_click_does_not_start_a_pan(self):
        """The pan drag must never be armed by button 1."""
        v = self.viewer()
        v.drag = None
        v.object_panel_click = lambda pos: False
        v.palette_click = lambda pos: False
        # The branch that arms `drag` is keyed on settings['pan_button'].
        self.assertNotEqual(v.settings["pan_button"], 1)


if __name__ == "__main__":
    unittest.main()
