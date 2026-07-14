#!/usr/bin/env python3
"""Cross-generator contracts for pret charmap handling."""

import importlib.util
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[3]
TOOLS = ROOT / 'dos_port' / 'tools'
CHARMAP = ROOT / 'constants' / 'charmap.asm'


def load(name):
    path = TOOLS / f'{name}.py'
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class GreedyCharmapContracts(unittest.TestCase):
    """Every pret-derived encoder must prefer the longest token."""

    TEXT = "<PLAYER>#'s"
    EXPECTED = [0x52, 0x54, 0xBD]

    def test_list_based_generators(self):
        for name in ('gen_items', 'gen_move_names', 'gen_field_moves'):
            with self.subTest(generator=name):
                module = load(name)
                cmap = module.load_charmap(CHARMAP)
                self.assertEqual(list(module.encode(self.TEXT, cmap)), self.EXPECTED)

    def test_battle_text_generator(self):
        module = load('gen_battle_text')
        self.assertEqual(module.encode(self.TEXT, module.load_charmap()), self.EXPECTED)

    def test_alphabet_generator(self):
        module = load('gen_alphabets')
        self.assertEqual(module.encode(self.TEXT, module.load_charmap()), self.EXPECTED)

    def test_unknown_input_fails(self):
        module = load('gen_items')
        with self.assertRaises(ValueError):
            module.encode('\u2603', module.load_charmap(CHARMAP))


if __name__ == '__main__':
    unittest.main()
