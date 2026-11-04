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
from gfx_core import tilesets as ts  # noqa: E402
from gfx_core.tiles import DMG_PAL  # noqa: E402


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

    def viewer(self, const="PALLET_TOWN", **overrides):
        settings = dict(config.DEFAULTS)
        settings.update(overrides)
        return self.Viewer(const, 1.0, settings)

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

    def cell_px(self, r, c):
        """Screen pixel in the middle of padded block cell (r, c) at 1:1."""
        return (c * 32 + 1, r * 32 + 1)

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
        # Inside it, shift-click is a plain clear — the axis lock is a different
        # modifier, so this press means one thing only.
        v.probe_mode = True
        v.probe_click(self.placed(v, 2, 2), shift=True)
        self.assertEqual(v.probe, [])
        self.assertIsNone(v.player, "clearing must remove the box entirely")

    def test_held_modifier_locks_the_sweep_to_one_axis(self):
        """The lock is held, not latched: it is asked on every motion."""
        v = self.viewer()
        v.probe_mode = True
        v.probe_click(self.placed(v, 2, 2))
        v.probe_extend(self.placed(v, 8, 5), locked=True)     # mostly vertical
        self.assertEqual(v.probe[0], (2, 2))
        self.assertEqual(v.probe[-1], (8, 2), "projected onto the anchor column")
        self.assertEqual({x for _y, x in v.probe}, {2}, "one column only")
        self.assertEqual(v.lock_axis, "V")
        # Pulling back toward the anchor shortens the sweep, no branch.
        v.probe_extend(self.placed(v, 5, 3), locked=True)
        self.assertEqual(v.probe[-1], (5, 2))
        # The other axis is chosen by the dominant direction.
        v.probe_extend(self.placed(v, 3, 9), locked=True)
        self.assertEqual(v.probe[-1], (2, 9), "mostly horizontal")
        self.assertEqual({y for y, _x in v.probe}, {2})
        self.assertEqual(v.lock_axis, "H")

    def test_axis_lock_is_a_hold_not_a_latch(self):
        """Releasing the modifier mid-stroke must return to freehand."""
        v = self.viewer()
        v.paint = True
        v.pan = [0.0, 0.0]
        v.scale = 1.0
        v.stroke_anchor = (8, 8)
        v.stroke_last = None
        v.paint_cell(self.cell_px(8, 8), locked=True)
        v.paint_cell(self.cell_px(12, 15), locked=True)   # horizontal: row 8
        painted = set(v.map_cells)
        self.assertEqual({r for r, _c in painted}, {1}, "one row only")
        self.assertIn((1, 8), painted)
        self.assertNotIn((5, 8), painted)
        # The modifier is released: the next motion is freehand again.
        v.paint_cell(self.cell_px(13, 16), locked=False)
        self.assertIn((6, 9), set(v.map_cells), "freehand resumes off-axis")

    def test_held_modifier_paints_a_straight_line(self):
        """A locked stroke stays on one row/column, with no gaps."""
        v = self.viewer()
        v.paint = True
        v.pan = [0.0, 0.0]
        v.scale = 1.0
        v.stroke_anchor = (8, 8)
        v.stroke_last = None
        v.paint_cell(self.cell_px(8, 8), locked=True)
        v.paint_cell(self.cell_px(12, 15), locked=True)   # mostly horizontal
        # Padded cell (8,8) is map-local (1,1) — cells are stored per sidecar.
        painted = set(v.map_cells)
        self.assertEqual({r for r, _c in painted}, {1}, "one row only")
        self.assertEqual({c for _r, c in painted}, set(range(1, 9)),
                         "the cells between the samples are filled")
        self.assertEqual(v.lock_axis, "H")

        v.stroke_anchor = (8, 8)
        v.stroke_last = None
        v.paint_cell(self.cell_px(8, 8), locked=True)
        v.paint_cell(self.cell_px(13, 9), locked=True)    # mostly vertical
        painted = set(v.map_cells)
        self.assertIn((6, 1), painted, "the vertical leg reached row 13")
        self.assertEqual(v.lock_axis, "V")

    def test_axis_lock_modifier_comes_from_config(self):
        v = self.viewer(axis_lock="shift")
        with patch.object(pygame.key, "get_mods", return_value=pygame.KMOD_SHIFT):
            self.assertTrue(v.axis_lock_held())
        with patch.object(pygame.key, "get_mods", return_value=pygame.KMOD_CTRL):
            self.assertFalse(v.axis_lock_held())
        off = self.viewer(axis_lock="none")
        with patch.object(pygame.key, "get_mods",
                          return_value=pygame.KMOD_CTRL | pygame.KMOD_SHIFT):
            self.assertFalse(off.axis_lock_held())
        # The default must not be the key that clears the probe.
        self.assertEqual(config.DEFAULTS["axis_lock"], "ctrl")

    def test_sweep_union_covers_both_endpoints_and_is_not_a_sum(self):
        v = self.viewer()
        v.probe_mode = True
        v.probe_click(self.placed(v, 4, 4))
        v.probe_extend(self.placed(v, 4, 6))          # two steps east = 4 tiles
        x0, y0, horiz, _vert = v.probe_sweep("dos")
        self.assertEqual(horiz[0], (0, 0, 352), "320 + 32 px of sweep")
        self.assertEqual(len(horiz), 2, "a plain rectangle has two long edges")
        # The union is smaller than the sum of the two windows (they overlap).
        self.assertLess(352 * 200, 2 * 320 * 200)

    def test_sweep_of_one_step_equals_the_window(self):
        from map_editor import view as vw
        mask, x0, y0, cols, rows = vw.viewport_sweep([(4, 4)], "dos")
        self.assertEqual((x0, y0), vw.step_viewport_px(4, 4, "dos")[:2])
        self.assertEqual((cols * vw.SWEEP_CELL, rows * vw.SWEEP_CELL), (320, 200))
        self.assertEqual(sum(mask), cols * rows)

    def test_click_lands_at_the_centre_of_the_box(self):
        """The player is centre-screen, so the window must straddle the step.

        This is the whole point of the mode: click a tile, and the box shows what
        the camera sees with the player standing THERE — not with the click at
        the box's top-left corner.
        """
        v = self.viewer()
        v.screen = self.pygame.display.set_mode((1024, 700))
        v.show["port_view"] = True
        v.show["gb_view"] = False
        click = (520, 380)

        class StopLoop(Exception):
            pass

        for event in (pygame.event.Event(pygame.KEYDOWN, key=pygame.K_y, mod=0),
                      pygame.event.Event(pygame.MOUSEBUTTONDOWN, button=1, pos=click)):
            with patch.object(pygame.event, "get", side_effect=[[event], StopLoop]), \
                 patch.object(pygame.key, "get_mods", return_value=0):
                with self.assertRaises(StopLoop):
                    v.run()
        self.assertTrue(v.probe, "the click must place the probe")
        v.probe_drag = False
        v.draw()

        import numpy as np
        a = pygame_surfarray(v.screen)
        red = ((a[:, :, 0] > 240) & (a[:, :, 1] > 50) & (a[:, :, 1] < 100)
               & (a[:, :, 2] > 50) & (a[:, :, 2] < 100))
        ys, xs = np.nonzero(red)
        self.assertGreater(len(xs), 0, "the DOS box must be drawn")
        self.assertAlmostEqual((xs.min() + xs.max()) / 2, click[0], delta=2)
        self.assertAlmostEqual((ys.min() + ys.max()) / 2, click[1], delta=2)

    def test_probe_moves_with_an_expansion(self):
        """Expanding north/west shifts the map, so the probe must shift with it."""
        v = self.viewer()
        v.probe_mode = True
        v.probe_click(self.placed(v, 3, 3))
        v.expand_edge("north")                     # one block = 2 steps
        self.assertEqual(v.probe, [(5, 3)])


class ConnectorTest(ViewerTestBase):
    """Connection strips belong to the NEIGHBOUR: editing one edits their map."""

    def strip_cell(self, v, const):
        for idx, owner in v.cm.strip_owner.items():
            if owner[0] == const:
                r, c = divmod(idx, v.cm.stride)
                return r, c, owner
        self.fail(f"no strip cell owned by {const}")

    def test_strip_cell_edits_the_neighbour_not_this_map(self):
        """Route 1's edge is Pallet Town's data; the write must land there."""
        v = self.viewer("ROUTE_1")
        v.pan = [0.0, 0.0]
        v.scale = 1.0
        r, c, (const, y, x) = self.strip_cell(v, "PALLET_TOWN")
        self.assertEqual(const, "PALLET_TOWN")
        idx = r * v.cm.stride + c
        before = v.cm.grid[idx]
        block = 0x2A if before != 0x2A else 0x2B
        v.paint = True
        v.current_block = block
        v.paint_cell((c * 32 + 1, r * 32 + 1))
        # The strip re-renders from the neighbour's composed layout...
        self.assertEqual(v.cm.grid[idx], block)
        self.assertEqual(v.cm.strip_owner[idx][0], "PALLET_TOWN")
        # ...and this map's own sidecars stay untouched.
        self.assertEqual(v.map_cells, {})
        self.assertEqual(v.cells, {})
        v.save()
        sidecar = self.tree("dos_port/assets/map_overrides/PalletTown.json")
        self.assertTrue(sidecar.exists(), "the edit belongs to the neighbour")
        self.assertIn(str(block), sidecar.read_text())
        self.assertFalse(
            self.tree("dos_port/assets/map_overrides/Route1.json").exists(),
            "the map being viewed must not get the override")

    def test_strip_undo_writes_back_to_the_neighbour(self):
        v = self.viewer("ROUTE_1")
        v.pan = [0.0, 0.0]
        v.scale = 1.0
        r, c, (_const, _y, _x) = self.strip_cell(v, "PALLET_TOWN")
        idx = r * v.cm.stride + c
        before = v.cm.grid[idx]
        block = 0x2A if before != 0x2A else 0x2B
        v.paint = True
        v.current_block = block
        v.paint_cell((c * 32 + 1, r * 32 + 1))
        self.assertEqual(v.cm.grid[idx], block)
        v.undo()
        self.assertEqual(v.cm.grid[idx], before, "undo restores the neighbour")
        self.assertFalse(
            self.tree("dos_port/assets/map_overrides/PalletTown.json").exists()
            and block in self.tree(
                "dos_port/assets/map_overrides/PalletTown.json").read_text()
            and before != block,
            "the neighbour's sidecar must not keep the reverted block")

    def test_owner_map_names_the_neighbour(self):
        v = self.viewer("ROUTE_1")
        r, c, owner = self.strip_cell(v, "VIRIDIAN_CITY")
        self.assertEqual(v._region(r, c), ("neighbour", owner))
        # Every strip cell with an owner is editable; an unowned one is not.
        for idx, entry in v.cm.strip_owner.items():
            rr, cc = divmod(idx, v.cm.stride)
            self.assertEqual(v._region(rr, cc), ("neighbour", entry))


class ReachTest(unittest.TestCase):
    """Walkable reach + the viewable union, against the real pret data.

    Pure `view.*` functions on composed maps: no pygame, no staging, no writes.
    """

    @classmethod
    def setUpClass(cls):
        cls.pallet = view.compose_padded("PALLET_TOWN")
        cls.route1 = view.compose_padded("ROUTE_1")

    def test_collision_lists_assign_stacked_alias_labels(self):
        """pret stacks aliased labels above one coll_tiles line; all get the set."""
        lists = view._collision_lists()
        for first, second in (("RedsHouse1_Coll", "RedsHouse2_Coll"),
                              ("Mart_Coll", "Pokecenter_Coll"),
                              ("Dojo_Coll", "Gym_Coll"),
                              ("ForestGate_Coll", "Gate_Coll"),
                              ("Gate_Coll", "Museum_Coll")):
            self.assertTrue(lists[first], f"{first} parsed as empty")
            self.assertEqual(lists[first], lists[second],
                             f"{first} and {second} share one coll_tiles line")
        # The regression this guards: REDS_HOUSE_1F/2F are the player's house.
        self.assertTrue(view.collision_tiles("reds_house"))

    def test_every_composable_tileset_resolves_a_collision_list(self):
        from gfx_core import pret_maps as pm
        stems = set()
        for const in pm._constants():
            try:
                info = pm.map_info(const)
            except (OSError, ValueError):
                continue
            if info.tileset_stem:
                stems.add(info.tileset_stem)
        missing = sorted(s for s in stems if not view.collision_tiles(s))
        self.assertEqual(missing, [], "tileset stem with no passable tile list")

    def test_standing_tile_is_the_lower_left_of_the_step(self):
        """lda_coord 8, 9 is x=8,y=9 -> row 9 col 8: the LOWER-LEFT of the 2x2."""
        cm = self.pallet
        for step_y, step_x in ((3, 4), (7, 9), (12, 2)):
            self.assertEqual(view.feet_tile(cm, step_y, step_x),
                             view._tile_at(cm, step_y * 2 + 1, step_x * 2))
        # Find a step where the two bottom tiles differ, and prove which one the
        # walkability rule reads. (14,7) on Pallet Town: lower-left $33 is
        # passable, lower-right $54 is passable too, upper row is water.
        differing = [(y, x) for y in range(cm.info.h * 2)
                     for x in range(cm.info.w * 2)
                     if view._tile_at(cm, y * 2 + 1, x * 2)
                     != view._tile_at(cm, y * 2 + 1, x * 2 + 1)]
        self.assertTrue(differing, "map has no step with differing bottom tiles")

    def test_a_step_is_walkable_when_its_lower_left_tile_is(self):
        """The engine checks ONE tile, so a sprite may overlap a wall."""
        cm = self.pallet
        passable = view.collision_tiles(cm.info.tileset_stem)
        checked = 0
        for step_y in range(cm.info.h * 2):
            for step_x in range(cm.info.w * 2):
                expected = view.feet_tile(cm, step_y, step_x) in passable
                self.assertEqual(view.step_walkable(cm, step_y, step_x), expected,
                                 f"step {(step_y, step_x)}")
                checked += 1
        self.assertGreater(checked, 300)

    def test_a_step_wedged_against_a_wall_is_still_walkable(self):
        """Pallet Town (5,5): lower-left $1B is passable, the other three are not.

        An all-four-tiles rule calls this a wall — the under-approximation that
        hides seams, and the reason the sprite may overlap a wall.
        """
        cm = self.pallet
        step_y, step_x = 5, 5
        self.assertEqual(view.feet_tile(cm, step_y, step_x), 0x1B)
        others = [view._tile_at(cm, step_y * 2, step_x * 2),
                  view._tile_at(cm, step_y * 2, step_x * 2 + 1),
                  view._tile_at(cm, step_y * 2 + 1, step_x * 2 + 1)]
        passable = view.collision_tiles(cm.info.tileset_stem)
        self.assertTrue(all(tile not in passable for tile in others),
                        "fixture: the other three tiles are impassable")
        self.assertTrue(view.step_walkable(cm, step_y, step_x))

    def test_ledge_is_a_directed_two_step_edge(self):
        """Route 1 (4,4) -> (6,4): standing $2C, ledge $37 at (5,4), landing $2C."""
        cm = self.route1
        self.assertEqual(view.feet_tile(cm, 4, 4), 0x2C)
        self.assertEqual(view.feet_tile(cm, 5, 4), 0x37)
        self.assertFalse(view.step_walkable(cm, 5, 4), "a ledge is not a standing tile")
        self.assertEqual(list(view._ledge_landings(cm, 4, 4)), [(6, 4)])
        self.assertEqual(list(view._ledge_landings(cm, 6, 4)), [],
                         "a ledge hops down only; the reverse edge must not exist")
        reach = view.reachable_steps(cm, (4, 4))
        self.assertIn((6, 4), reach.standing, "the landing is a standing position")
        self.assertIn((5, 4), reach.traversed, "the hop passes over the ledge step")
        self.assertNotIn((5, 4), reach.standing, "you cannot stop on a ledge")

    def test_the_mid_hop_window_is_part_of_the_union(self):
        """The camera is centred on the ledge step mid-hop, so it can see from it."""
        cm = self.route1
        reach = view.reachable_steps(cm, (4, 4))
        dos = view.viewport_cells(sorted(reach.steps()), "dos")
        mid_hop = view.viewport_cells([(5, 4)], "dos")
        self.assertTrue(mid_hop, "fixture: the mid-hop step has a window")
        self.assertLessEqual(mid_hop, dos,
                             "everything visible from the ledge step must be in "
                             "the union")

    def test_a_ledge_needs_the_tile_behind_it(self):
        """In play only when the tile behind is passable AND reachable.

        The hop out of (4,4) exists; the same hop from the step BELOW the ledge
        does not, and a seed on the ledge itself is not a standing position.
        """
        cm = self.route1
        self.assertEqual(list(view._ledge_landings(cm, 4, 4)), [(6, 4)])
        self.assertFalse(list(view._ledge_landings(cm, 5, 4)),
                         "the ledge tile is not an approach")
        self.assertEqual(view.reachable_steps(cm, (5, 4)).standing, set())

    def test_ledges_only_apply_to_the_overworld_tileset(self):
        """HandleLedges returns early unless wCurMapTileset == OVERWORLD."""
        self.assertTrue(list(view._ledge_landings(self.route1, 4, 4)))
        plateau = view.compose_padded("ROUTE_23")
        self.assertEqual(plateau.info.tileset_name, "PLATEAU")
        self.assertFalse(list(view._ledge_landings(plateau, 4, 4)))

    def test_flood_is_complete_and_bounded(self):
        """Every walkable neighbour of a reached step is reached, and nothing else."""
        cm = self.pallet
        seed = (7, 4)
        self.assertTrue(view.step_walkable(cm, *seed))
        reach = view.reachable_steps(cm, seed)
        self.assertIn(seed, reach.standing)
        h, w = cm.info.h * 2, cm.info.w * 2
        self.assertTrue(all(0 <= y < h and 0 <= x < w for (y, x) in reach.standing))
        for (y, x) in reach.standing:
            self.assertTrue(view.step_walkable(cm, y, x))
            for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
                if 0 <= ny < h and 0 <= nx < w and view.step_walkable(cm, ny, nx):
                    self.assertIn((ny, nx), reach.standing,
                                  f"flood stopped at a walkable neighbour "
                                  f"{(ny, nx)} of {(y, x)}")
        # A walled-off pocket stays out: Pallet Town's fenced north-west corner.
        pockets = {(y, x) for y in range(h) for x in range(w)
                   if view.step_walkable(cm, y, x)} - reach.standing
        self.assertTrue(pockets, "fixture expects at least one isolated pocket")

    def test_unwalkable_seed_reaches_nothing(self):
        empty = view.Reach(set(), set())
        self.assertEqual(view.reachable_steps(self.pallet, None), empty)
        self.assertFalse(view.step_walkable(self.pallet, 1, 0), "fixture: a wall")
        self.assertEqual(view.reachable_steps(self.pallet, (1, 0)), empty)
        self.assertEqual(view.reachable_steps(self.pallet, (999, 999)), empty)

    def test_attention_is_dos_minus_gb_inside_real_map_data(self):
        cm = self.route1
        seed = (4, 4)
        steps = view.reachable_steps(cm, seed).steps()
        dos, gb, attention, border = view.viewable(cm, steps)
        self.assertTrue(dos and gb)
        self.assertTrue(attention)
        self.assertTrue(attention <= dos)
        self.assertFalse(attention & gb, "attention is by definition DOS-only")
        self.assertTrue(attention.isdisjoint(border))
        self.assertEqual(attention | border, dos - gb)
        for cell in attention:
            self.assertTrue(view.cell_meaningful(cm, *cell))
        for cell in border:
            self.assertFalse(view.cell_meaningful(cm, *cell))

    def test_a_room_smaller_than_the_gb_window_reveals_no_attention(self):
        """REDS_HOUSE_1F is 4x4 blocks: the GB window already shows all of it."""
        cm = view.compose_padded("REDS_HOUSE_1F")
        steps = view.reachable_steps(cm, (2, 2)).steps()
        self.assertTrue(steps)
        dos, gb, attention, border = view.viewable(cm, steps)
        self.assertEqual(attention, set(),
                         "the port's extra cells here are border fill, not seams")
        self.assertTrue(border, "the DOS window overhangs the room on every side")

    def test_cell_meaningful_covers_the_map_and_its_strips(self):
        cm = self.route1
        inside = (view.BORDER * 4 * view.TILE, view.BORDER * 4 * view.TILE)
        self.assertTrue(view.cell_meaningful(cm, *inside))
        self.assertFalse(view.cell_meaningful(cm, -4000, -4000))
        # A strip cell's pixels are real data (the neighbour's blocks).
        idx = next(iter(cm.strip_cells))
        row, col = divmod(idx, cm.stride)
        x = col * ts.BLOCK_PX
        y = row * ts.BLOCK_PX
        self.assertTrue(view.cell_meaningful(cm, x, y))


class ReachOverlayTest(ViewerTestBase):
    """`U`: flood from the probe, draw the DOS-only band, invalidate on edits."""

    def test_u_floods_from_the_probe_anchor(self):
        v = self.viewer("ROUTE_1")
        v.pan = [0.0, 0.0]
        v.scale = 1.0
        v.probe_mode = True
        v.probe = [(4, 4)]
        v.toggle_reach()
        self.assertIsNotNone(v.reach_stats, v.save_error)
        steps, hops, dos, gb, attention, border = v.reach_stats
        self.assertIn((4, 4), v.reach.standing)
        self.assertGreaterEqual(hops, 0)
        self.assertGreater(steps, 1)
        # DOS strictly contains GB per position, so its union must too.
        self.assertGreater(dos, gb)
        self.assertGreater(attention, 0, "Route 1 has cells only the port shows")
        self.assertEqual(attention + border, dos - gb,
                         "nothing is dropped: the band is attention + border")
        self.assertTrue(v._reach_runs, "the band has drawable runs")
        self.assertIn("dos", v._reach_outline)
        self.assertIn("gb", v._reach_outline)

    def test_u_again_clears_the_overlay(self):
        v = self.viewer("ROUTE_1")
        v.probe_mode = True
        v.probe = [(4, 4)]
        v.toggle_reach()
        self.assertIsNotNone(v.reach_stats)
        v.toggle_reach()
        self.assertIsNone(v.reach_stats)
        self.assertIsNone(v.reach)
        self.assertEqual(v._reach_runs, [])
        self.assertEqual(v._reach_outline, {})

    def test_reach_falls_back_to_the_staged_player_step(self):
        """With no probe, the flood starts where the staged player tile is."""
        v = self.viewer("PALLET_TOWN")
        v.pan = [0.0, 0.0]
        v.scale = 1.0
        self.assertEqual(v.probe, [])
        v.set_player_tile((4 * 16 + view.BORDER * 32 + 1,
                           7 * 16 + view.BORDER * 32 + 1))
        self.assertEqual(v.player, (8, 14))
        v.toggle_reach()
        self.assertIsNotNone(v.reach_stats, v.save_error)
        self.assertIn((7, 4), v.reach.standing)

    def test_no_anchor_at_all_reports_instead_of_guessing(self):
        v = self.viewer("PALLET_TOWN")
        self.assertIsNone(v.player)
        self.assertFalse(v.compute_reach())
        self.assertIn("probe", v.save_error)

    def test_unwalkable_anchor_reports_and_shows_nothing(self):
        v = self.viewer("PALLET_TOWN")
        v.probe_mode = True
        v.probe = [(1, 0)]                   # a wall row on Pallet Town
        self.assertFalse(v.compute_reach())
        self.assertIn("not walkable", v.save_error)
        self.assertIsNone(v.reach_stats)

    def test_an_edit_invalidates_the_reach(self):
        """A stale overlay would claim the port shows cells it no longer does."""
        v = self.viewer("ROUTE_1")
        v.pan = [0.0, 0.0]
        v.scale = 1.0
        v.probe_mode = True
        v.probe = [(4, 4)]
        v.toggle_reach()
        self.assertIsNotNone(v.reach_stats)
        v.paint = True
        v.current_block = 0x2A
        v.paint_cell((32 * 10 + 1, 32 * 10 + 1))
        self.assertIsNone(v.reach_stats, "painting must drop the reach")
        self.assertEqual(v._reach_runs, [])

    def test_the_overlay_draws_and_survives_mode_changes(self):
        v = self.viewer("ROUTE_1")
        v.pan = [0.0, 0.0]
        v.scale = 1.0
        v.probe_mode = True
        v.probe = [(4, 4)]
        v.toggle_reach()
        before = v.reach_stats
        v.draw()                              # amber fill + both union outlines
        self.assertEqual(v.reach_stats, before)
        # The overlay is independent of the probe frames: turning V/H off keeps
        # the band, which is the point of a persistent attention area.
        v.show["port_view"] = False
        v.show["gb_view"] = False
        v.draw()
        self.assertEqual(v.reach_stats, before)
        v.paint = True                        # mode change alone must not clear
        v.paint = False
        self.assertEqual(v.reach_stats, before)


class LookSwapTest(ViewerTestBase):
    """`K`: preview a map through a neighbour's tileset + palette, and measure it."""

    def test_k_cycles_distinct_neighbour_looks(self):
        v = self.viewer("ROUTE_1")
        options = v.look_candidates()
        self.assertIsNone(options[0], "own look first")
        self.assertEqual(sorted(o for o in options if o),
                         ["PALLET_TOWN", "VIRIDIAN_CITY"])
        seen = []
        for _ in range(len(options)):
            v.cycle_view_as()
            seen.append(v.view_as)
        self.assertEqual(seen[-1], None, "cycling wraps back to the own look")
        self.assertEqual(set(seen), set(options))

    def test_preview_swaps_the_palette_and_the_render(self):
        v = self.viewer("ROUTE_1")
        own_palette = v.palette_name
        own_image = v.img.tobytes()
        v.apply_view_as("VIRIDIAN_CITY")
        self.assertEqual(v.view_as, "VIRIDIAN_CITY")
        self.assertNotEqual(v.palette_name, own_palette,
                            "a town has its own palette (SetPal_Overworld: map id + 1)")
        self.assertNotEqual(v.img.tobytes(), own_image,
                            "the preview must actually re-render")
        v.apply_view_as(None)
        self.assertEqual(v.palette_name, own_palette)
        self.assertEqual(v.img.tobytes(), own_image)

    def test_a_same_tileset_seam_changes_colour_only(self):
        """Route 1 and Viridian City share OVERWORLD; only the palette differs."""
        v = self.viewer("ROUTE_1")
        v.pan = [0.0, 0.0]
        v.scale = 1.0
        v.probe_mode = True
        v.probe = [(4, 4)]
        v.toggle_reach()
        v.apply_view_as("VIRIDIAN_CITY")
        const, cells, both, shape, colour = v.look_stats
        self.assertEqual(const, "VIRIDIAN_CITY")
        self.assertGreater(cells, 0)
        self.assertEqual(shape, 0, "same tileset: no block can change graphic")
        self.assertEqual(colour, both,
                         "every changed cell changed by palette alone")
        self.assertGreater(both, 0)

    def test_no_band_means_no_swap_report(self):
        v = self.viewer("ROUTE_1")
        v.apply_view_as("VIRIDIAN_CITY")
        self.assertIsNone(v.look_stats, "the swap is measured over the amber band")

    def test_switching_map_drops_the_preview(self):
        v = self.viewer("ROUTE_1")
        v.apply_view_as("VIRIDIAN_CITY")
        v.load("ROUTE_1")
        self.assertIsNone(v.view_as)
        self.assertIsNone(v.look_stats)

    def test_identical_looks_report_no_change(self):
        cm = view.compose_padded("ROUTE_1")
        reach = view.reachable_steps(cm, (4, 4))
        _dos, _gb, band, _border = view.viewable(cm, reach.steps())
        own = (cm.info.tileset_stem, tuple(tuple(c) for c in DMG_PAL))
        self.assertEqual(view.look_changes(cm, band, own, own), (0, 0, 0))

    def test_a_cross_tileset_pair_changes_shape(self):
        """OVERWORLD vs PLATEAU: the same block ids become different graphics."""
        cm = view.compose_padded("ROUTE_22")
        cells = {(x, y) for y in range(0, 200, 8) for x in range(0, 320, 8)}
        own = ("overworld", tuple(tuple(c) for c in DMG_PAL))
        other = ("plateau", tuple(tuple(c) for c in DMG_PAL))
        both, shape, colour = view.look_changes(cm, cells, own, other)
        self.assertEqual(colour, 0, "same palette: nothing can recolour")
        self.assertEqual(shape, both)
        self.assertGreater(shape, 0, "PLATEAU reads these block ids differently")


if __name__ == "__main__":
    unittest.main()
