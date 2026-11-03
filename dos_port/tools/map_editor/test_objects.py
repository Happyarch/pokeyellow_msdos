"""Object lowering and command tests without editing project sidecars."""
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
from tempfile import TemporaryDirectory

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from map_editor import objects, schema, commands
from gfx_core import pret_maps as pm


class ObjectTest(unittest.TestCase):
    def test_trace_and_lowering(self):
        base = {'stable_id': 'base:one', 'mapy': 10, 'mapx': 14,
                'sprite_id': 1, 'mov': 0, 'dir': 0}
        diff = schema.MapDiff('Test', schema.Extents(north=1, west=2),
                              objects={'base:one': {'manual_delta_tile': [2, -2],
                                                    'sprite': 'SPRITE_ROCKET'}})
        tables = {'sprite': {'SPRITE_ROCKET': 24}, 'movement': {}, 'facing': {}}
        with patch.object(schema, 'load', return_value=diff):
            _, warps, signs, sprites = objects.lower('Test', 0, [(1, 2, 'MAP', 1)],
                                                      [{'y': 3, 'x': 4}], [base], tables)
        self.assertEqual(warps, [(3, 6, 'MAP', 1)])
        self.assertEqual((signs[0]['y'], signs[0]['x']), (5, 8))
        self.assertEqual((sprites[0]['mapy'], sprites[0]['mapx']), (13, 17))
        self.assertEqual(sprites[0]['trace']['final'], [18, 26])
        self.assertEqual(sprites[0]['sprite_id'], 24)
        self.assertEqual(base['mapy'], 10)

    def test_rejects_stale_id(self):
        with patch.object(schema, 'load', return_value=schema.MapDiff('Test', objects={'base:stale': {}})):
            with self.assertRaisesRegex(ValueError, 'missing sources'):
                objects.lower('Test', 0, [], [], [], {})

    def test_dry_run_uses_final_coordinate(self):
        info = pm.map_info('PALLET_TOWN')
        npc = pm.objects(info)[3][0]
        result = commands.set_object('PALLET_TOWN', npc['stable_id'], y=4, x=6)
        self.assertFalse(result['written'])
        base = npc['trace']['base']
        self.assertEqual(result['changes']['manual_delta_tile'], [4-base[0], 6-base[1]])

    def test_write_then_generator_parser_reads_same_object(self):
        info = pm.map_info('PALLET_TOWN')
        with TemporaryDirectory() as directory, patch.object(schema, 'OVERRIDES', Path(directory)):
            npc = pm.objects(info)[3][0]
            commands.set_object('PALLET_TOWN', npc['stable_id'], y=18, x=22,
                                sprite='SPRITE_ROCKET', write=True)
            generated = pm.gmh.parse_object_file(info.label)[3][0]
            self.assertEqual((generated['mapy'], generated['mapx']), (13, 15))
            self.assertEqual(generated['sprite_id'], pm.gmh._SPRITE_CONSTS['SPRITE_ROCKET'])
            self.assertEqual(generated['trace']['final'], [18, 22])

    def test_rejects_half_map_square_position(self):
        npc = pm.objects(pm.map_info('PALLET_TOWN'))[3][0]
        with self.assertRaisesRegex(ValueError, 'must be even'):
            commands.set_object('PALLET_TOWN', npc['stable_id'], y=3, x=6)


if __name__ == '__main__':
    unittest.main()
