"""Tests for narrowly scoped checked script-coordinate edits."""
from pathlib import Path
from tempfile import TemporaryDirectory
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from map_editor import scripts


class ScriptTest(unittest.TestCase):
    def test_comment_not_scanned_and_checked_edit(self):
        with TemporaryDirectory() as directory:
            path = Path(directory) / 'map.asm'
            path.write_text('; dbmapcoord 2, 3\nlabel: dbmapcoord 7, 9 ; keep\n')
            binding, = scripts.scan_coordinate_macros(path)
            self.assertEqual(binding.tile, scripts.TileYX(9, 7))
            scripts.translate_binding(binding, dy=1, dx=2, write=True)
            self.assertEqual(path.read_text(), '; dbmapcoord 2, 3\nlabel: dbmapcoord 9, 10 ; keep\n')
            with self.assertRaisesRegex(ValueError, 'changed since scan'):
                scripts.translate_binding(binding, dy=1, dx=2, write=True)


if __name__ == '__main__':
    unittest.main()
