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

    def test_intervening_call_does_not_bind_route(self):
        with TemporaryDirectory() as directory:
            path = Path(directory) / 'test.asm'
            path.write_text('PathA:\n db 0x06\n db 0xFF\n'
                            'Start:\n mov edi, PathA\n call SomeOtherRoutine\n call MoveSprite\n')
            self.assertEqual(routes.scan(path), [])

    def test_move_sprite2_pair_captures_both_channels_and_slots(self):
        with TemporaryDirectory() as directory:
            path = Path(directory) / 'pair.asm'
            path.write_text(
                'First:\n db 0x06\n db 0xFF\n'
                'Second:\n db 0x06\n db 0xFF\n'
                'Start:\n'
                '    mov al, 2\n'
                '    mov [ebp + hSpriteIndex], al\n'
                '    mov edi, First\n'
                '    mov bl, 6\n'
                '    mov edx, Second\n'
                '    call MoveSprite2\n')
            found = {b.label: b for b in routes.scan(path)}
            self.assertEqual(set(found), {'First', 'Second'})
            self.assertEqual(found['First'].channel, 0)
            self.assertEqual(found['First'].slot, 2)
            self.assertEqual(found['Second'].channel, 1)
            self.assertEqual(found['Second'].slot, 6)
            self.assertEqual(found['First'].pair, found['Second'].pair)

    def test_single_walker_has_no_pair_or_second_channel(self):
        with TemporaryDirectory() as directory:
            path = Path(directory) / 'single.asm'
            path.write_text('Only:\n db 0x06\n db 0xFF\n'
                            'Start:\n    mov al, 3\n    mov edi, Only\n    call MoveSprite\n')
            binding, = routes.scan(path)
            self.assertIsNone(binding.pair)
            self.assertIsNone(binding.channel)
            self.assertEqual(binding.slot, 3)

    def test_symbolic_stream_keeps_its_style_on_write(self):
        """`db NPC_MOVEMENT_UP` must not become `db 0x40` after an edit."""
        with TemporaryDirectory() as directory:
            path = Path(directory) / 'symbolic.asm'
            path.write_text('PathA:\n'
                            '    db NPC_MOVEMENT_UP\n'
                            '    db NPC_MOVEMENT_UP\n'
                            '    db -1\n'
                            'Start:\n    mov edi, PathA\n    call MoveSprite\n')
            binding, = routes.scan(path)
            self.assertEqual(list(binding.values), [0x40, 0x40, 0xFF])
            self.assertEqual(binding.tokens, ('NPC_MOVEMENT_UP', 'NPC_MOVEMENT_UP', '-1'))
            self.assertEqual(routes.render_token('NPC_MOVEMENT_UP', 0x80), 'NPC_MOVEMENT_LEFT')
            self.assertEqual(routes.render_token('NPC_MOVEMENT_UP', 0x04), '0x04')
            self.assertEqual(routes.render_token('-1', 0xFF), '-1')
            self.assertEqual(routes.render_token('$40', 0x80), '$80')
            self.assertEqual(routes.render_token('0x40', 0x80), '0x80')
            self.assertEqual(routes.render_token('64', 0x80), '128')
            self.assertEqual(routes.resolve_token('NPC_MOVEMENT_RIGHT'), 0xC0)
            self.assertEqual(routes.resolve_token('bogus_operand'), None)

    def test_paired_traces_share_cells_when_paths_overlap(self):
        """Two identical streams must report a shared cell for the NPCMV12 skin."""
        left = [0x06, 0x06, 0xFF]
        first = routes.preview(scripts.TileYX(10, 20), routes.decode(bytes(left)))
        second = routes.preview(scripts.TileYX(10, 20), routes.decode(bytes(left)))
        shared = set((p.y, p.x) for p in first) & set((p.y, p.x) for p in second)
        self.assertEqual(len(shared), 3)
        # Different rows must not be reported as overlapping.
        apart = routes.preview(scripts.TileYX(12, 20), routes.decode(bytes(left)))
        self.assertEqual(set((p.y, p.x) for p in first) & set((p.y, p.x) for p in apart), set())


if __name__ == '__main__':
    unittest.main()
