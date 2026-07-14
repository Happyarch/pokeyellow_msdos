#!/usr/bin/env python3
import importlib.machinery
import importlib.util
import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[3]
LINTER = ROOT / "dos_port" / "tools" / "lint_pret_labels"
loader = importlib.machinery.SourceFileLoader("lint_pret_labels", str(LINTER))
spec = importlib.util.spec_from_loader(loader.name, loader)
module = importlib.util.module_from_spec(spec)
loader.exec_module(module)


class StructuredAnnotationTests(unittest.TestCase):
    def test_complete_deviation(self):
        parsed = module.parse_annotation(
            "; DEVIATION{class=projection; pret=home/foo.asm:Foo; "
            "behavior=canvas mapping; evidence=golden:menu; lifetime=permanent}")
        self.assertEqual(parsed[0], "DEVIATION")
        self.assertEqual(parsed[2], [])

    def test_missing_evidence_fails(self):
        parsed = module.parse_annotation(
            "; BUG{class=temporary; pret=home/foo.asm:Foo; behavior=guard; "
            "lifetime=until battle scenario}")
        self.assertTrue(any("evidence" in error for error in parsed[2]))

    def test_glitch_requires_safety(self):
        parsed = module.parse_annotation(
            "; GLITCH{class=data-model; pret=engine/foo.asm:Foo; behavior=underflow; "
            "evidence=pret bytes; lifetime=permanent}")
        self.assertIn("GLITCH requires safety", parsed[2])

    def test_stub_class_is_bounded(self):
        parsed = module.parse_annotation(
            "; STUB{class=HAL; pret=home/foo.asm:Foo; behavior=no-op; "
            "evidence=label_status; lifetime=until provider lands}")
        self.assertIn("STUB class must be stub or temporary", parsed[2])


if __name__ == "__main__":
    unittest.main()
