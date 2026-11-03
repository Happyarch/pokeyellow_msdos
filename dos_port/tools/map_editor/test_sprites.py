from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from map_editor import sprites


class SpriteTest(unittest.TestCase):
    def test_oak_sheet_and_transparency(self):
        self.assertEqual(sprites.sprite_paths()[3].name, 'oak.png')
        colors = ((255, 255, 255), (160, 160, 160), (80, 80, 80), (0, 0, 0))
        img = sprites.thumbnail(3, colors)
        self.assertEqual(img.size, (16, 16))
        self.assertIn(0, img.getchannel('A').tobytes())
        self.assertIn(255, img.getchannel('A').tobytes())


if __name__ == '__main__':
    unittest.main()
