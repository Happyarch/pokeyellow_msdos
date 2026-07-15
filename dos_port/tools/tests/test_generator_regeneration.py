#!/usr/bin/env python3
"""Deterministic regeneration and pret-parser coverage gates."""

import contextlib
import importlib.util
import io
import re
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
TOOLS = ROOT / "dos_port" / "tools"
ASSETS = ROOT / "dos_port" / "assets"


def load(name):
    spec = importlib.util.spec_from_file_location(name, TOOLS / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def source_rows(path, pattern):
    regex = re.compile(pattern)
    return sum(bool(regex.match(line.split(";", 1)[0]))
               for line in path.read_text(encoding="utf-8").splitlines())


class GeneratorRegenerationTests(unittest.TestCase):
    OUTPUTS = {
        "gen_items": "items.inc",
        "gen_moves": "moves.inc",
        "gen_field_moves": "field_moves.inc",
        "gen_alphabets": "alphabets.inc",
    }

    def test_temporary_regeneration_matches_working_assets(self):
        with tempfile.TemporaryDirectory() as directory:
            temporary = Path(directory)
            for name, output in self.OUTPUTS.items():
                with self.subTest(generator=name):
                    module = load(name)
                    module.ASSETS = temporary
                    with contextlib.redirect_stdout(io.StringIO()):
                        self.assertEqual(module.main(), 0)
                    self.assertEqual((temporary / output).read_bytes(),
                                     (ASSETS / output).read_bytes())

    def test_move_parser_covers_every_pret_record(self):
        expected = source_rows(ROOT / "data/moves/moves.asm", r"\s*move\s+")
        emitted = source_rows(ASSETS / "moves.inc", r"\s*db\s+")
        self.assertGreater(expected, 0)
        self.assertEqual(emitted, expected)

    def test_item_parsers_cover_names_and_prices(self):
        generated = (ASSETS / "items.inc").read_text(encoding="utf-8")
        names = source_rows(ROOT / "data/items/names.asm", r'\s*li\s+"')
        prices = source_rows(ROOT / "data/items/prices.asm", r"\s*bcd3\s+")
        name_block = generated.split("\nItemNames:\n", 1)[1].split("ItemNames_end:", 1)[0]
        price_block = generated.split("\nItemPrices:\n", 1)[1].split("ItemPrices_end:", 1)[0]
        self.assertEqual(source_rows_from_text(name_block), names)
        self.assertEqual(source_rows_from_text(price_block), prices)

    def test_required_labels_have_single_identity(self):
        requirements = {
            "items.inc": ("ItemNames", "ItemPrices", "TechnicalMachines"),
            "moves.inc": ("Moves", "Moves_end"),
            "field_moves.inc": ("FieldMoveDisplayData", "FieldMoveNames"),
            "alphabets.inc": ("UpperCaseAlphabet", "LowerCaseAlphabet"),
        }
        for filename, labels in requirements.items():
            text = (ASSETS / filename).read_text(encoding="utf-8")
            for label in labels:
                with self.subTest(file=filename, label=label):
                    self.assertEqual(len(re.findall(rf"(?m)^{label}:\s*", text)), 1)

    def test_field_move_name_stream_matches_pret_bytes(self):
        module = load("gen_field_moves")
        cmap = module.load_charmap(ROOT / "constants/charmap.asm")
        names = module.parse_names(ROOT / "data/moves/field_move_names.asm")
        expected = b"".join(module.encode(name, cmap) for name in names)
        generated = (ASSETS / "field_moves.inc").read_text(encoding="utf-8")
        block = generated.split("\nFieldMoveNames:\n", 1)[1].split(
            "FieldMoveNames_end:", 1)[0]
        actual = bytes(int(value, 16) for value in
                       re.findall(r"0x([0-9A-Fa-f]{2})", block))
        self.assertEqual(actual, expected)


def source_rows_from_text(text):
    return sum(bool(re.match(r"\s*db\s+", line)) for line in text.splitlines())


if __name__ == "__main__":
    unittest.main()
