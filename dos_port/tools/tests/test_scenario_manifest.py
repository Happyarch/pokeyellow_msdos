#!/usr/bin/env python3
import importlib.util
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[3]
PATH = ROOT / 'dos_port' / 'tools' / 'validate_scenarios.py'
spec = importlib.util.spec_from_file_location('validate_scenarios', PATH)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ScenarioManifestTests(unittest.TestCase):
    def test_registries_do_not_drift(self):
        self.assertEqual(module.validate(), [])

    def test_ids_are_unique_and_nonzero(self):
        scenarios = module.load_manifest()
        ids = [item['id'] for item in scenarios]
        self.assertNotIn(0, ids)
        self.assertEqual(len(ids), len(set(ids)))

    def test_datastruct_is_not_ui_verification(self):
        for item in module.load_manifest():
            if item['scenario_class'] == 'datastruct':
                self.assertIn('not UI verification', item['verification'])


if __name__ == '__main__':
    unittest.main()
