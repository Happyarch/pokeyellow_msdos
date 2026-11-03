"""Tests for narrowly scoped checked script-coordinate edits."""
from pathlib import Path
from tempfile import TemporaryDirectory
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from map_editor import scripts, commands, schema


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

    def test_annotated_native_bytes(self):
        with TemporaryDirectory() as directory:
            path = Path(directory) / 'map.asm'
            path.write_text('    db 8, 10  ; dbmapcoord 10, 8\n')
            binding, = scripts.scan_coordinate_macros(path)
            self.assertEqual(binding.tile, scripts.TileYX(8, 10))
            scripts.translate_binding(binding, dy=1, dx=2, write=True)
            self.assertEqual(path.read_text(), '    db 9, 12  ; dbmapcoord 12, 9\n')
            path.write_text('db 8, 10 ; dbmapcoord 11, 8\n')
            with self.assertRaisesRegex(ValueError, 'annotation disagrees'):
                scripts.scan_coordinate_macros(path)

    def test_cli_command_checks_file_revision(self):
        with TemporaryDirectory() as directory, patch.object(schema, 'ROOT', Path(directory)):
            path = Path(directory) / 'dos_port/src/scripts/PalletTown.asm'
            path.parent.mkdir(parents=True)
            path.write_text('db 8, 10 ; dbmapcoord 10, 8\n')
            scan = commands.scan_scripts('PALLET_TOWN')
            commands.move_script_coordinate('PALLET_TOWN', 0, scan['sha256'], 7, 6, write=True)
            self.assertEqual(path.read_text(), 'db 7, 6 ; dbmapcoord 6, 7\n')
            with self.assertRaisesRegex(ValueError, 'changed since scan'):
                commands.move_script_coordinate('PALLET_TOWN', 0, scan['sha256'], 1, 2, write=True)


if __name__ == '__main__':
    unittest.main()
