"""Overworld palette selection and render contract."""
from pathlib import Path
import sys
from tempfile import TemporaryDirectory
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from gfx_core import palettes, pret_maps as pm
from map_editor import commands, palette


class PaletteTest(unittest.TestCase):
    def test_pallet_palette_and_interior_context(self):
        name, colors, warning = palette.resolve(pm.map_info('PALLET_TOWN'))
        self.assertEqual(name, 'PAL_PALLET')
        expected = palettes.parse_cgb_base_palettes()[name][0]
        self.assertEqual(colors[0], tuple(round(c * 255 / 63) for c in expected))
        self.assertIsNone(warning)
        name, _, warning = palette.resolve(pm.map_info('REDS_HOUSE_1F'))
        self.assertEqual(name, 'PAL_ROUTE')
        self.assertIn('unknown', warning)
        name, _, warning = palette.resolve(pm.map_info('REDS_HOUSE_1F'), 'PALLET_TOWN')
        self.assertEqual(name, 'PAL_PALLET')
        self.assertIsNone(warning)

    def test_cli_render_manifest(self):
        with TemporaryDirectory() as directory:
            output = Path(directory) / 'map.png'
            result = commands.render('PALLET_TOWN', out=output, palette_mode='port-cgb')
            self.assertEqual(result['palette_name'], 'PAL_PALLET')
            self.assertTrue(output.is_file())
            self.assertTrue(output.with_suffix('.png.json').is_file())


if __name__ == '__main__':
    unittest.main()
