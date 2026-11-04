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

import pygame  # noqa: E402  (after the SDL driver env vars)

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from map_editor import config  # noqa: E402
from map_editor import staging  # noqa: E402
from map_editor import view  # noqa: E402


def pygame_surfarray(surface):
    """Surface -> HxWx3 numpy array (pygame.surfarray is x-major, so transpose)."""
    import numpy as np
    return np.transpose(np.array(pygame.surfarray.array3d(surface)), (1, 0, 2))


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


class ViewerTestBase(unittest.TestCase):
    """A real Viewer on a private tree, so no test can write the repository."""

    @classmethod
    def setUpClass(cls):
        from map_editor.editor import Viewer
        pygame.init()
        cls.pygame = pygame
        cls.Viewer = Viewer

    def setUp(self):
        # NEVER write the real sidecar tree from a test: the Viewer's edit paths
        # (warp drag, NPC drop, expansion) call commands.* with write=True. Each
        # test gets its own tree so a save in one cannot leak into the next.
        self._tmp = TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self._root = patch.object(staging, "ROOT", Path(self._tmp.name))
        self._root.start()
        self.addCleanup(self._root.stop)
        # The Viewer opens a staging session; leaving it open would redirect the
        # next test's writes into this one's scratch tree.
        self.addCleanup(staging.end)
        # An expansion changes the port dimensions, and pret_maps caches them.
        # Clear it or the next test composes against the expanded header.
        from gfx_core import pret_maps as pm
        self.addCleanup(pm.map_info.cache_clear)
        self.addCleanup(pm._constants.cache_clear)

    def viewer(self, **overrides):
        settings = dict(config.DEFAULTS)
        settings.update(overrides)
        return self.Viewer("PALLET_TOWN", 1.0, settings)

    def tree(self, rel):
        """Path inside this test's private repository root."""
        return Path(self._tmp.name) / rel

    def image_point(self, v, screen_point):
        return ((screen_point[0] - v.pan[0]) / v.scale,
                (screen_point[1] - v.pan[1]) / v.scale)


class ZoomTest(ViewerTestBase):

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

    def test_step_grid_is_one_cell_per_movement_step(self):
        """The grid must be 16 px: a 32 px cell is 2x2 steps and reads as wrong."""
        v = self.viewer()
        self.assertFalse(v.show["steps"], "grids stay off by default")
        v.show["steps"] = True
        v.show["blocks"] = False
        v.center_view()
        v.draw()
        import numpy as np
        a = pygame_surfarray(v.screen)
        black = (a[:, :, 0] == 0) & (a[:, :, 1] == 0) & (a[:, :, 2] == 0)
        cols = black.sum(axis=0)
        lines = [x for x in range(len(cols)) if cols[x] > 100]
        self.assertGreater(len(lines), 4)
        pitches = {b - a for a, b in zip(lines, lines[1:])}
        self.assertEqual(pitches, {16}, f"step grid pitch {pitches}")

    def test_block_grid_stays_32px_and_is_distinct(self):
        v = self.viewer()
        v.show["steps"] = False
        v.show["blocks"] = True
        v.center_view()
        v.draw()
        import numpy as np
        a = pygame_surfarray(v.screen)
        orange = ((a[:, :, 0] > 200) & (a[:, :, 1] > 100)
                  & (a[:, :, 1] < 180) & (a[:, :, 2] < 60))
        cols = orange.sum(axis=0)
        lines = [x for x in range(len(cols)) if cols[x] > 100]
        pitches = {b - a for a, b in zip(lines, lines[1:])}
        self.assertEqual(pitches, {32}, f"block grid pitch {pitches}")

        v = self.viewer()
        v.player = (0, 0)
        self.assertIn("NORTH", v.connection_at_player() or "")
        v.player = (v.cm.info.w * 4 - 1, v.cm.info.h * 4 - 1)
        self.assertIn("SOUTH", v.connection_at_player() or "")
        v.player = (20, 20)
        self.assertIsNone(v.connection_at_player())

    def test_ui_scale_follows_the_window_and_can_be_pinned(self):
        v = self.viewer()
        self.assertEqual(v.settings["ui_scale"], "auto")
        v.screen = self.pygame.display.set_mode((1024, 700))
        self.assertAlmostEqual(v.ui_scale(), 1.0, places=3)
        small = v.ui_scale()
        v.screen = self.pygame.display.set_mode((1600, 1000))
        big = v.ui_scale()
        self.assertGreater(big, small, "a bigger window must scale the UI up")
        self.assertGreater(v.font.get_height(), 13, "font must follow the scale")
        self.assertGreater(v.ui_panel_width(), 290)

        pinned = self.viewer(ui_scale=2.0)
        self.assertAlmostEqual(pinned.ui_scale(), 2.0, places=3)
        self.assertEqual(self.viewer(ui_scale=99.0).ui_scale(),
                         config.DEFAULTS["ui_scale_max"])
        self.assertEqual(self.viewer(ui_scale=0.01).ui_scale(),
                         config.DEFAULTS["ui_scale_min"])
        v.screen = self.pygame.display.set_mode((1024, 700))

    def test_panel_rows_never_overlap_when_scaled_up(self):
        v = self.viewer(ui_scale=2.5)
        geo = v.panel_geo()
        self.assertGreaterEqual(geo["row_h"], v.font.get_height())
        self.assertGreaterEqual(geo["item_h"], v.font.get_height())
        self.assertGreaterEqual(geo["list"], geo["rows"] + 3 * geo["row_h"])
        v.draw()

    def test_ui_scale_config_is_validated(self):
        with TemporaryDirectory() as directory:
            path = Path(directory) / "config.json"
            path.write_text(json.dumps({"ui_scale": "huge"}))
            with self.assertRaisesRegex(ValueError, "ui_scale"):
                config.load(path)
            path.write_text(json.dumps({"ui_scale": 0}))
            with self.assertRaisesRegex(ValueError, "positive"):
                config.load(path)
            path.write_text(json.dumps({"ui_reference": [1024]}))
            with self.assertRaisesRegex(ValueError, "ui_reference"):
                config.load(path)
            path.write_text(json.dumps({"ui_scale": 1.5, "ui_reference": [1280, 720]}))
            loaded = config.load(path)
            self.assertEqual(loaded["ui_scale"], 1.5)
            self.assertEqual(loaded["ui_reference"], [1280, 720])

    def test_left_click_does_not_start_a_pan(self):
        """The pan drag must never be armed by button 1."""
        v = self.viewer()
        v.drag = None
        v.object_panel_click = lambda pos: False
        v.palette_click = lambda pos: False
        # The branch that arms `drag` is keyed on settings['pan_button'].
        self.assertNotEqual(v.settings["pan_button"], 1)

    # ── paint palette: readable swatches that follow the window ─────────────

    def test_palette_cell_is_block_sized_and_follows_the_window(self):
        v = self.viewer()
        v.screen = self.pygame.display.set_mode((1024, 700))
        self.assertEqual(v.palette_cell(), 32, "a cell is one block at 1x, 1:1")
        v.screen = self.pygame.display.set_mode((1600, 1000))
        cell = v.palette_cell()
        self.assertGreater(cell, 32, "the palette must scale with the UI")
        self.assertEqual(v.palette_width(), v.palette_cols() * cell + 12)
        self.assertEqual(v.palette_surface().get_size(),
                         (v.palette_cols() * cell, v.palette_rows() * cell))

    def test_palette_cols_shrink_as_the_cells_grow(self):
        """Auto columns trade width for height: a bigger cell means a longer column."""
        v = self.viewer()
        v.screen = self.pygame.display.set_mode((1024, 700))
        small = (v.palette_cell(), v.palette_cols(), v.palette_rows())
        v.screen = self.pygame.display.set_mode((2560, 1440))
        big = (v.palette_cell(), v.palette_cols(), v.palette_rows())
        self.assertGreater(big[0], small[0])
        self.assertLessEqual(big[1], small[1], "fewer tiles per row")
        self.assertGreaterEqual(big[2], small[2], "a longer column")
        # The strip must still fit the window it is drawn in.
        self.assertLessEqual(v.palette_rows() * v.palette_cell(),
                             v.screen.get_height() - v.panel_h())

    def test_palette_cell_and_cols_are_configurable(self):
        v = self.viewer(palette_cell=64, palette_cols=4)
        v.screen = self.pygame.display.set_mode((1024, 700))
        self.assertEqual(v.palette_cell(), 64)
        self.assertEqual(v.palette_cols(), 4)
        self.assertEqual(v.palette_width(), 4 * 64 + 12)
        # A fixed column count does not follow the window height.
        v.screen = self.pygame.display.set_mode((1600, 1000))
        self.assertEqual(v.palette_cols(), 4)

    def test_palette_click_uses_the_scaled_cell(self):
        """The hit test must follow the drawn size, not a hard-coded 32 px."""
        v = self.viewer()
        v.screen = self.pygame.display.set_mode((1600, 1000))
        v.paint = True
        cell, cols = v.palette_cell(), v.palette_cols()
        x0 = v.screen.get_width() - v.palette_width()
        for block in (0, cols - 1, cols + 3):
            col, row = block % cols, block // cols
            pos = (x0 + 6 + col * cell + cell // 2, 6 + row * cell + cell // 2)
            self.assertTrue(v.palette_click(pos))
            self.assertEqual(v.current_block, block, f"block {block} at {pos}")

    def test_palette_config_is_validated(self):
        with TemporaryDirectory() as directory:
            path = Path(directory) / "config.json"
            path.write_text(json.dumps({"palette_cell": 0}))
            with self.assertRaisesRegex(ValueError, "palette_cell"):
                config.load(path)
            path.write_text(json.dumps({"palette_cell": 24}))
            self.assertEqual(config.load(path)["palette_cell"], 24)
            path.write_text(json.dumps({"palette_cols": "wide"}))
            with self.assertRaisesRegex(ValueError, "palette_cols"):
                config.load(path)
            path.write_text(json.dumps({"palette_cols": 0}))
            with self.assertRaisesRegex(ValueError, "palette_cols"):
                config.load(path)
            path.write_text(json.dumps({"palette_cols": 5}))
            self.assertEqual(config.load(path)["palette_cols"], 5)

    # ── save semantics: Ctrl+S commits, an edit never does ───────────────────

    def drag_warp(self, v):
        """Move the selected warp one map square: a real sidecar edit."""
        v.pan = [0.0, 0.0]
        v.scale = 1.0
        v.warp_drag = v.cm.warps[0]['stable_id']
        v.selected_warp = v.warp_drag
        v.finish_warp_drag(((22 + view.BORDER * 4) * 8 + 1,
                            (12 + view.BORDER * 4) * 8 + 1))
        v.warp_drag = None
        return v.cm.warps[0]

    def test_a_warp_move_is_staged_not_written(self):
        v = self.viewer()
        sidecar = self.tree("dos_port/assets/map_overrides/PalletTown.json")
        self.assertFalse(sidecar.exists(), "nothing should exist before an edit")
        self.drag_warp(v)
        self.assertTrue(v.dirty, "an edit must mark the session unsaved")
        self.assertIn("dos_port/assets/map_overrides/PalletTown.json",
                      v.stage.changed())
        self.assertFalse(sidecar.exists(),
                         "an edit must not write the tree — Ctrl+S does that")

    def test_save_commits_the_staged_edit(self):
        v = self.viewer()
        moved = self.drag_warp(v)
        v.save()
        sidecar = self.tree("dos_port/assets/map_overrides/PalletTown.json")
        self.assertTrue(sidecar.exists(), "Ctrl+S must commit the sidecar")
        self.assertFalse(v.dirty)
        self.assertEqual(v.stage.changed(), [], "commit must clear the staging")
        self.assertIn(f'"warps"', sidecar.read_text())
        # The committed warp really moved (the drag targets map square 6,11).
        self.assertEqual((moved['y'], moved['x']), (6, 11))

    def test_quit_discards_staged_edits(self):
        v = self.viewer()
        self.drag_warp(v)
        scratch = Path(v.stage.tmp)
        v.quit()
        self.assertFalse(
            self.tree("dos_port/assets/map_overrides/PalletTown.json").exists(),
            "quitting must not save")
        self.assertFalse(scratch.exists(), "scratch tree must be gone")
        staging.end()

    def test_paint_is_staged_until_saved(self):
        v = self.viewer()
        v.paint = True
        v.pan = [0.0, 0.0]
        v.scale = 1.0
        v.current_block = v.cm.grid[0] ^ 1        # a different block than the cell
        self.assertIsNotNone(v._region(0, 0), "ring cell should be paintable")
        v.paint_cell((1, 1))                      # padded block (0, 0)
        border = self.tree("dos_port/assets/map_borders/PALLET_TOWN.json")
        self.assertTrue(v.dirty)
        self.assertFalse(border.exists(), "paint must not write the tree")
        v.save()
        self.assertTrue(border.exists(), "Ctrl+S must commit the paint")
        self.assertIn('"cells"', border.read_text())

    def test_expansion_is_staged_and_commits_with_save(self):
        """Expansion rewrites a sidecar AND a port script — both must be staged."""
        v = self.viewer()
        before = v.cm.info.h
        v.expand_edge('north')
        self.assertEqual(v.cm.info.h, before + 1, "the view must grow immediately")
        sidecar = self.tree("dos_port/assets/map_overrides/PalletTown.json")
        self.assertFalse(sidecar.exists(), "expansion must not write the tree")
        self.assertTrue(v.stage.changed())
        v.save()
        self.assertTrue(sidecar.exists(), "Ctrl+S must commit the expansion")
        self.assertIn('"north": 1', sidecar.read_text())

    def test_a_save_with_no_edits_writes_nothing(self):
        """Ctrl+S with nothing staged must not rewrite (and churn) a sidecar."""
        repo = Path(__file__).resolve().parents[3]
        rel = "dos_port/assets/map_overrides/VermilionDock.json"
        committed = repo / rel
        target = self.tree(rel)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(committed.read_text())
        before = target.read_text()
        v = self.Viewer("VERMILION_DOCK", 1.0, dict(config.DEFAULTS))
        self.assertFalse(v.dirty)
        v.save()
        self.assertEqual(v.stage.changed(), [])
        self.assertEqual(target.read_text(), before,
                         "an untouched save must not rewrite the sidecar")

    def test_ctrl_s_is_the_save_key_and_plain_s_is_not(self):
        """The binding is the requirement: no bare `S` save may come back."""
        v = self.viewer()
        saved = []
        v.save = lambda: saved.append(1)

        class StopLoop(Exception):
            pass

        def press(key, mods):
            event = pygame.event.Event(pygame.KEYDOWN, key=key, mod=mods)
            with patch.object(pygame.event, "get", side_effect=[[event], StopLoop]), \
                 patch.object(pygame.key, "get_mods", return_value=mods):
                with self.assertRaises(StopLoop):
                    v.run()

        press(pygame.K_s, 0)
        self.assertEqual(saved, [], "a bare S must not save")
        press(pygame.K_s, pygame.KMOD_CTRL)
        self.assertEqual(saved, [1], "Ctrl+S must save")


class ProbeTest(ViewerTestBase):
    """Viewport probe: a step-anchored box (or swept union) for DOS and GB."""

    def placed(self, v, step_y, step_x, dx=0, dy=0):
        """Screen pixel inside a step, with the map pinned at 1:1."""
        v.pan = [0.0, 0.0]
        v.scale = 1.0
        return (step_x * 16 + view.BORDER * 4 * 8 + dx,
                step_y * 16 + view.BORDER * 4 * 8 + dy)

    def test_click_snaps_to_a_legal_player_step(self):
        v = self.viewer()
        v.probe_mode = True
        # Every pixel inside one step must give the same anchor, and the anchor
        # must be an even tile: the player only exists on whole 16 px steps.
        for dx, dy in ((0, 0), (7, 0), (0, 7), (7, 7), (15, 15)):
            v.probe_click(self.placed(v, 3, 4, dx, dy))
            self.assertEqual(v.probe, [(3, 4)], f"offset {dx},{dy}")
            self.assertEqual(v.player, (8, 6), "player tile = step * 2")
        # The next step over is a different anchor.
        v.probe_click(self.placed(v, 3, 5))
        self.assertEqual(v.probe, [(3, 5)])

    def test_drag_sweeps_a_contiguous_path(self):
        """A fast drag skips steps between events; the path must not have holes."""
        v = self.viewer()
        v.probe_mode = True
        v.probe_click(self.placed(v, 1, 1))
        v.probe_extend(self.placed(v, 9, 5))
        self.assertEqual(v.probe[0], (1, 1))
        self.assertEqual(v.probe[-1], (9, 5))
        for (y0, x0), (y1, x1) in zip(v.probe, v.probe[1:]):
            self.assertLessEqual(abs(y1 - y0), 1, "no gap in y")
            self.assertLessEqual(abs(x1 - x0), 1, "no gap in x")
        self.assertEqual(v.player, (5 * 2, 9 * 2))

    def test_shift_click_clears_only_in_probe_mode(self):
        v = self.viewer()
        v.probe_mode = True
        v.probe_click(self.placed(v, 2, 2))
        self.assertTrue(v.probe)
        # Outside probe mode a click (shift or not) belongs to the other tools.
        v.probe_mode = False
        self.assertFalse(v.probe_click(self.placed(v, 2, 2), shift=True))
        self.assertEqual(v.probe, [(2, 2)])
        # Inside it, it is a clear.
        v.probe_mode = True
        v.probe_click(self.placed(v, 2, 2), shift=True)
        self.assertEqual(v.probe, [])
        self.assertIsNone(v.player, "clearing must remove the box entirely")

    def test_probe_survives_leaving_the_mode(self):
        v = self.viewer()
        v.probe_mode = True
        v.probe_click(self.placed(v, 3, 3))
        v.probe_mode = False
        self.assertEqual(v.probe, [(3, 3)], "the overlay is an annotation")
        v.draw()          # and it still draws outside the mode

    def test_y_toggles_probe_mode_and_paint_is_exclusive(self):
        v = self.viewer()
        v.save = lambda: None

        class StopLoop(Exception):
            pass

        def press(key, mods=0):
            event = pygame.event.Event(pygame.KEYDOWN, key=key, mod=mods)
            with patch.object(pygame.event, "get", side_effect=[[event], StopLoop]), \
                 patch.object(pygame.key, "get_mods", return_value=mods):
                with self.assertRaises(StopLoop):
                    v.run()

        press(pygame.K_y)
        self.assertTrue(v.probe_mode)
        press(pygame.K_p)
        self.assertTrue(v.paint)
        self.assertFalse(v.probe_mode, "paint and probe cannot share a click")
        press(pygame.K_y)
        self.assertTrue(v.probe_mode)
        self.assertFalse(v.paint)

    def test_v_and_h_select_the_channel(self):
        from map_editor.editor import GB_VIEW, PORT_VIEW
        v = self.viewer()
        v.probe_mode = True
        v.probe_click(self.placed(v, 4, 4))
        v.show["port_view"] = True
        v.show["gb_view"] = True
        dos = v.probe_sweep("dos")
        gb = v.probe_sweep("gb")
        # One step: the union is exactly the window, 40x25 vs 20x18 tiles.
        self.assertEqual((dos[2][0][2], len(dos[3])), (40, 2))
        self.assertEqual((gb[2][0][2], len(gb[3])), (20, 2))
        self.assertTrue(PORT_VIEW[0] > PORT_VIEW[2], "DOS is red")
        self.assertTrue(GB_VIEW[2] > GB_VIEW[0], "GB is blue")
        v.draw()

    def test_sweep_union_covers_both_endpoints_and_is_not_a_sum(self):
        v = self.viewer()
        v.probe_mode = True
        v.probe_click(self.placed(v, 4, 4))
        v.probe_extend(self.placed(v, 4, 6))          # two steps east = 4 tiles
        x0, y0, horiz, _vert = v.probe_sweep("dos")
        self.assertEqual(horiz[0], (0, 0, 44), "40 + 4 tiles of sweep")
        self.assertEqual(len(horiz), 2, "a plain rectangle has two long edges")
        # The union is smaller than the sum of the two windows (they overlap).
        self.assertLess(44 * 25, 2 * 40 * 25)

    def test_sweep_of_one_step_equals_the_window(self):
        from map_editor import view as vw
        mask, x0, y0, cols, rows = vw.viewport_sweep([(4, 4)], "dos")
        self.assertEqual((x0, y0, cols, rows), vw.step_viewport_tile_rect(4, 4, "dos"))
        self.assertEqual(sum(mask), 40 * 25)

    def test_probe_moves_with_an_expansion(self):
        """Expanding north/west shifts the map, so the probe must shift with it."""
        v = self.viewer()
        v.probe_mode = True
        v.probe_click(self.placed(v, 3, 3))
        v.expand_edge("north")                     # one block = 2 steps
        self.assertEqual(v.probe, [(5, 3)])


if __name__ == "__main__":
    unittest.main()
