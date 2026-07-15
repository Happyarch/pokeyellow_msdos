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


def source(relative):
    return (ROOT / relative).read_text(encoding="utf-8")


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
        self.assertIn("STUB requires label", parsed[2])

    def test_complete_stub_names_label(self):
        parsed = module.parse_annotation(
            "; STUB{class=stub; label=DeferredRoutine; pret=home/foo.asm:DeferredRoutine; "
            "behavior=return carry clear; evidence=label_status; lifetime=until wave 4}")
        self.assertEqual(parsed[2], [])

    def test_legacy_annotation_is_distinct_from_structured(self):
        self.assertEqual(module.legacy_annotation_kind("; BUG(cosmetic): old form"), "BUG")
        self.assertIsNone(module.legacy_annotation_kind(
            "; BUG{class=temporary; pret=home/foo.asm:Foo; behavior=x; "
            "evidence=golden:y; lifetime=until z}"))

    def test_hand_encoded_rendered_text(self):
        self.assertTrue(module.looks_hand_encoded_text(
            'StatusText: db 0x8f, 0x92, 0x8d ; "PSN"', 'StatusText'))

    def test_binary_table_is_not_text(self):
        self.assertFalse(module.looks_hand_encoded_text(
            'DecodeTable: db 0xfe, 0xcd, 0x89, 0xba', 'DecodeTable'))


class DebugAssertionContractTests(unittest.TestCase):
    def test_projection_rejects_full_window_list_before_append(self):
        ppu = source("dos_port/src/ppu/ppu.asm")
        block = ppu.split("add_window:", 1)[1].split("push ebp", 1)[0]
        self.assertIn("%ifdef DEBUG_ASSERT_PROJECTION", block)
        self.assertRegex(block, r"cmp dword \[g_window_count\], MAX_WINDOWS\s+jae \.assert_projection")
        self.assertIn("int3", block)

    def test_scratch_rejects_every_stride_except_20_or_canvas_width(self):
        text = source("dos_port/src/home/text.asm")
        for label in ("TextBoxBorder:", "PlaceString:"):
            block = text.split(label, 1)[1].split("%endif", 1)[0]
            self.assertIn("%ifdef DEBUG_ASSERT_SCRATCH", block)
            self.assertIn("cmp dword [text_row_stride], 20", block)
            self.assertIn("cmp dword [text_row_stride], SCREEN_WIDTH", block)
            self.assertRegex(block, r"jne \.assert_bad_stride")
            self.assertIn("int3", block)

    def test_lifecycle_rejects_count_overflow_and_non_boolean_state(self):
        ppu = source("dos_port/src/ppu/ppu.asm")
        block = ppu.split("render_window:", 1)[1].split("%endif", 1)[0]
        self.assertIn("%ifdef DEBUG_ASSERT_LIFECYCLE", block)
        self.assertRegex(block, r"cmp dword \[g_window_count\], MAX_WINDOWS\s+ja \.assert_lifecycle")
        for flag in ("g_obj_over_window", "g_bg_whiteout"):
            self.assertRegex(block, rf"cmp dword \[{flag}\], 1\s+ja \.assert_lifecycle")
        self.assertIn("int3", block)

    def test_reentrancy_rejects_nested_owner_and_releases_depth(self):
        window = source("dos_port/src/home/window.asm")
        block = window.split("PrintText:", 1)[1].split("PrintText_NoCreatingTextBox:", 1)[0]
        self.assertIn("cmp byte [print_text_depth], 0", block)
        self.assertIn("jne .assert_reentrant", block)
        self.assertIn("inc byte [print_text_depth]", block)
        self.assertIn("int3", block)
        release = window.split("PrintText_NoCreatingTextBox:", 1)[1].split("PlaceMenuCursor", 1)[0]
        self.assertIn("dec byte [print_text_depth]", release)

    def test_assertion_umbrella_selects_all_families(self):
        makefile = source("dos_port/Makefile")
        umbrella = makefile.split("ifdef DEBUG_ASSERTIONS", 1)[1].split("endif", 1)[0]
        for family in ("PROJECTION", "SCRATCH", "LIFECYCLE", "REENTRANCY"):
            self.assertIn(f"DEBUG_ASSERT_{family} := 1", umbrella)


if __name__ == "__main__":
    unittest.main()
