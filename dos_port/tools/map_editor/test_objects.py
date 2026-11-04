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
        warp_base = {'stable_id': 'base:warp', 'y': 1, 'x': 2,
                     'dest': 'MAP', 'warp_id': 1, 'kind': None}
        with patch.object(schema, 'load', return_value=diff):
            _, warps, signs, sprites = objects.lower('Test', 0, [warp_base],
                                                      [{'y': 3, 'x': 4}], [base], tables)
        self.assertEqual((warps[0]['y'], warps[0]['x']), (3, 6))
        self.assertEqual((warps[0]['dest'], warps[0]['warp_id']), ('MAP', 1))
        self.assertEqual(warp_base['y'], 1)
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


class WarpTest(unittest.TestCase):
    def setUp(self):
        self.info = pm.map_info('PALLET_TOWN')
        self.warp = pm.objects(self.info)[1][0]

    def test_warp_ids_are_stable_and_distinct(self):
        warps = pm.objects(self.info)[1]
        ids = [w['stable_id'] for w in warps]
        self.assertEqual(len(ids), len(set(ids)))
        self.assertTrue(all(i.startswith('base:') for i in ids))

    def test_dest_warp_and_kind_are_recorded(self):
        result = commands.set_warp('PALLET_TOWN', self.warp['stable_id'],
                                   dest='ROUTE_1', target_warp=3, kind='door')
        self.assertFalse(result['written'])
        self.assertEqual(result['changes'],
                         {'dest': 'ROUTE_1', 'warp_id': 3, 'kind': 'door'})
        # The note must not overclaim: pret has no warp-type field.
        self.assertIn('not emitted', result['note'])

    def test_invalid_values_are_refused(self):
        sid = self.warp['stable_id']
        with self.assertRaisesRegex(ValueError, 'unknown destination'):
            commands.set_warp('PALLET_TOWN', sid, dest='NOT_A_MAP')
        with self.assertRaisesRegex(ValueError, 'kind must be one of'):
            commands.set_warp('PALLET_TOWN', sid, kind='teleporter')
        with self.assertRaisesRegex(ValueError, '1..255'):
            commands.set_warp('PALLET_TOWN', sid, target_warp=0)
        with self.assertRaisesRegex(ValueError, 'must be even'):
            commands.set_warp('PALLET_TOWN', sid, y=3, x=4)

    def test_override_reaches_the_generated_warp_bytes(self):
        before = pm.gmh.parse_object_file(self.info.label)[1][0]
        with TemporaryDirectory() as directory, \
             patch.object(schema, 'OVERRIDES', Path(directory)):
            commands.set_warp('PALLET_TOWN', self.warp['stable_id'],
                              dest='ROUTE_1', target_warp=4, kind='hole', write=True)
            after = pm.gmh.parse_object_file(self.info.label)[1][0]
        self.assertEqual(after['dest'], 'ROUTE_1')
        self.assertEqual(after['warp_id'], 4)
        self.assertEqual(after['kind'], 'hole')
        # Position untouched by a destination-only edit.
        self.assertEqual((after['y'], after['x']), (before['y'], before['x']))

    def test_kind_is_not_emitted_into_the_header_binary(self):
        """The kind must stay authoring metadata, never a generated byte."""
        source = Path(__file__).resolve().parent.parent / 'generators' / 'gen_map_headers.py'
        text = source.read_text()
        self.assertIn("warp['y'], warp['x'], warp['warp_id'] - 1", text)
        self.assertNotIn("warp['kind']", text)

    def test_position_override_moves_the_generated_warp(self):
        """Dragging a warp must change the emitted Y/X bytes, not just the sidecar."""
        before = pm.gmh.parse_object_file(self.info.label)[1][0]
        with TemporaryDirectory() as directory, \
             patch.object(schema, 'OVERRIDES', Path(directory)):
            # editor tiles (22, 12) -> pret map square (Y 6, X 11)
            commands.set_warp('PALLET_TOWN', self.warp['stable_id'],
                              y=22, x=12, write=True)
            after = pm.gmh.parse_object_file(self.info.label)[1][0]
        self.assertEqual((after["y"], after["x"]), (11, 6))
        self.assertNotEqual((after['y'], after['x']), (before['y'], before['x']))
        # Destination untouched by a position-only edit.
        self.assertEqual(after['dest'], before['dest'])
        self.assertEqual(after['warp_id'], before['warp_id'])



if __name__ == '__main__':
    unittest.main()
