import sys
from pathlib import Path
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from map_editor import routes, scripts


class RouteTest(unittest.TestCase):
    def test_square_to_tile_and_special_codes(self):
        ops = routes.decode(bytes([0xc0, 0x05, 0x11, 0xe0, 0xff]))
        self.assertEqual([op.kind for op in ops],
                         ['step', 'quick_step', 'unsafe_special', 'change_facing_unknown', 'end'])
        self.assertEqual(routes.preview(scripts.TileYX(10, 10), ops),
                         [scripts.TileYX(10, 10), scripts.TileYX(10, 12), scripts.TileYX(8, 12)])


if __name__ == '__main__':
    unittest.main()
