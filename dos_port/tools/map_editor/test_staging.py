"""Staging layer: an edit must reach the tree only when it is committed.

These tests are about the path layer alone — no pygame, no map data — because
that is where the "Ctrl+S or nothing" guarantee actually lives.
"""
from pathlib import Path
import sys
from tempfile import TemporaryDirectory
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from map_editor import staging


class StagingTest(unittest.TestCase):
    def setUp(self):
        self._tmp = TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.root = Path(self._tmp.name)
        self.addCleanup(staging.end)

    def tree(self, rel: str) -> Path:
        return self.root / rel

    def seed(self, rel: str, text: str) -> Path:
        path = self.tree(rel)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        return path

    def test_no_session_is_transparent(self):
        """Without a session the layer must not change any path at all."""
        layer = staging.Staging(self.root)
        self.assertIsNone(layer.read_path("a/b.txt"))
        self.assertEqual(layer.write_path("a/b.txt"), self.tree("a/b.txt"))
        layer.write_path("a/b.txt").write_text("x")
        self.assertEqual(layer.read_path("a/b.txt"), self.tree("a/b.txt"))
        self.assertEqual(layer.changed(), [])

    def test_writes_are_staged_until_commit(self):
        self.seed("a/b.txt", "original")
        layer = staging.begin(self.root)
        staged = layer.write_path("a/b.txt")
        self.assertNotEqual(staged, self.tree("a/b.txt"))
        staged.write_text("edited")
        # Reads follow the edit; the tree still holds the original bytes.
        self.assertEqual(layer.read_path("a/b.txt").read_text(), "edited")
        self.assertEqual(self.tree("a/b.txt").read_text(), "original")
        self.assertEqual(layer.changed(), ["a/b.txt"])
        self.assertEqual(layer.commit(), ["a/b.txt"])
        self.assertEqual(self.tree("a/b.txt").read_text(), "edited")
        self.assertEqual(layer.changed(), [])

    def test_write_materialises_the_tree_copy_first(self):
        """A read-modify-write command must start from the committed bytes."""
        self.seed("a/b.txt", "original")
        layer = staging.begin(self.root)
        staged = layer.write_path("a/b.txt")
        self.assertEqual(staged.read_text(), "original")

    def test_removing_a_staged_file_deletes_the_tree_copy(self):
        self.seed("a/b.txt", "original")
        layer = staging.begin(self.root)
        layer.remove("a/b.txt")
        self.assertIsNone(layer.read_path("a/b.txt"))
        self.assertEqual(layer.changed(), ["a/b.txt"])
        layer.commit()
        self.assertFalse(self.tree("a/b.txt").exists())

    def test_rewriting_identical_bytes_is_not_a_change(self):
        self.seed("a/b.txt", "same")
        layer = staging.begin(self.root)
        layer.write_path("a/b.txt").write_text("same")
        self.assertEqual(layer.changed(), [])
        self.assertEqual(layer.commit(), [])

    def test_discard_drops_everything(self):
        self.seed("a/b.txt", "original")
        layer = staging.begin(self.root)
        layer.write_path("a/b.txt").write_text("edited")
        layer.discard()
        self.assertEqual(self.tree("a/b.txt").read_text(), "original")
        self.assertEqual(staging.current().changed(), [])

    def test_new_file_and_deletion_together(self):
        self.seed("a/old.txt", "gone")
        layer = staging.begin(self.root)
        layer.remove("a/old.txt")
        layer.write_path("a/new.txt").write_text("fresh")
        self.assertEqual(sorted(layer.changed()), ["a/new.txt", "a/old.txt"])
        layer.commit()
        self.assertFalse(self.tree("a/old.txt").exists())
        self.assertEqual(self.tree("a/new.txt").read_text(), "fresh")

    def test_rel_helpers_point_at_the_three_staged_trees(self):
        self.assertEqual(staging.overrides_rel("PalletTown"),
                         "dos_port/assets/map_overrides/PalletTown.json")
        self.assertEqual(staging.borders_rel("PALLET_TOWN"),
                         "dos_port/assets/map_borders/PALLET_TOWN.json")
        self.assertEqual(staging.script_rel("PalletTown"),
                         "dos_port/src/scripts/PalletTown.asm")


if __name__ == "__main__":
    unittest.main()
