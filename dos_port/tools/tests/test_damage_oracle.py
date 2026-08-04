#!/usr/bin/env python3
import importlib.util
import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[3]
PATH = ROOT / "dos_port" / "tools" / "golden_diff.py"
spec = importlib.util.spec_from_file_location("golden_diff", PATH)
golden_diff = importlib.util.module_from_spec(spec)
spec.loader.exec_module(golden_diff)


class DamageOracleTests(unittest.TestCase):
    def test_player_stab_and_super_effective_roll_set(self):
        record = (0, 10, 0x54, 40, 0x17, 0x54, 5, 12, 0x17, 0x17,
                  0x24, 0, 15, 0x00, 0x02)
        self.assertEqual(golden_diff.gen1_damage_rolls(record, 20), {10, 11, 12})

    def test_critical_doubles_level_before_formula(self):
        record = (1, 39, 0xA3, 70, 0x00, 0x24, 13, 19, 0x00, 0x02,
                  0x54, 0, 11, 0x17, 0x17)
        rolls = golden_diff.gen1_damage_rolls(record, 10)
        self.assertEqual((min(rolls), max(rolls)), (39, 46))

    def test_randomization_is_skipped_below_two_damage(self):
        record = (0, 1, 1, 1, 0, 1, 1, 1, 1, 1, 2, 0, 255, 2, 2)
        self.assertEqual(golden_diff.gen1_damage_rolls(record, 1), {0})

    def test_zero_formula_input_is_rejected(self):
        record = (0,) * golden_diff.DAMAGE_ORACLE_RECORD_SIZE
        with self.assertRaisesRegex(ValueError, "nonzero"):
            golden_diff.gen1_damage_rolls(record, 10)


if __name__ == "__main__":
    unittest.main()
