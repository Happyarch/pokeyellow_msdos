import sys
from pathlib import Path
import unittest
from tempfile import TemporaryDirectory
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from map_editor import routes, scripts, commands, schema


class RouteTest(unittest.TestCase):
    def test_square_to_tile_and_special_codes(self):
        ops = routes.decode(bytes([0xc0, 0x05, 0x11, 0xe0, 0xff]))
        self.assertEqual([op.kind for op in ops],
                         ['step', 'quick_step', 'unsafe_special', 'change_facing_unknown', 'end'])
        self.assertEqual(routes.preview(scripts.TileYX(10, 10), ops),
                         [scripts.TileYX(10, 10), scripts.TileYX(10, 12), scripts.TileYX(8, 12)])

    def test_bound_route_edit_preserves_labels_and_comments(self):
        with TemporaryDirectory() as directory, patch.object(schema, 'ROOT', Path(directory)):
            path = Path(directory) / 'dos_port/src/scripts/PalletTown.asm'
            path.parent.mkdir(parents=True)
            path.write_text('PathA:\nAlias:\n    db 0x06 ; left\n    db 0xFF\n'
                            'Start:\n    mov edi, PathA\n    call MoveSprite\n')
            scan = commands.scan_routes('PALLET_TOWN')
            self.assertEqual(scan['routes'][0]['label'], 'PathA')
            commands.set_route('PALLET_TOWN', 'PathA', scan['sha256'], [7, 255], write=True)
            self.assertIn('Alias:\n    db 0x07 ; left\n', path.read_text())
            with self.assertRaisesRegex(ValueError, 'changed since scan'):
                commands.set_route('PALLET_TOWN', 'PathA', scan['sha256'], [6, 255], write=True)


if __name__ == '__main__':
    unittest.main()
