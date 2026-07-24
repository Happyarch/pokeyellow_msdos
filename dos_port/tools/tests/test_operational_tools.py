#!/usr/bin/env python3
import importlib.machinery
import importlib.util
import pathlib
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[3]
LINTER = ROOT / "dos_port" / "tools" / "lint_pret_labels"
SCANNER = ROOT / "dos_port" / "tools" / "update_label_db"
DB = ROOT / "dos_port" / "tools" / "translation.db"


def _load(name, path):
    loader = importlib.machinery.SourceFileLoader(name, str(path))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


module = _load("lint_pret_labels", LINTER)
uld = _load("update_label_db", SCANNER)


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


class ScriptProvenanceMappingTests(unittest.TestCase):
    """pret scripts/<Map>.asm -> dos_port/src/scripts/<map>.asm naming."""

    def test_canonical_snake_case(self):
        for pret, expect in (
                ("scripts/Route3.asm", "route_3"),
                ("scripts/PalletTown.asm", "pallet_town"),
                ("scripts/CeladonMart1F.asm", "celadon_mart_1f"),
                ("scripts/SSAnne1FRooms.asm", "ss_anne_1f_rooms"),
                ("scripts/SilphCo11F.asm", "silph_co_11f"),
                ("scripts/UndergroundPathRoute7Copy.asm",
                 "underground_path_route_7_copy")):
            with self.subTest(pret=pret):
                self.assertEqual(uld.script_port_stems(pret)[0], expect)

    def test_bank_split_continuations_map_to_the_same_map_file(self):
        # pret splits a map's script across banks (Route1_2.asm); the port has
        # no banks, so both halves belong in one file.
        self.assertEqual(uld.script_port_file("scripts/Route1_2.asm"),
                         uld.script_port_file("scripts/Route1.asm"))
        self.assertEqual(uld.script_port_file("scripts/CinnabarGym_3.asm"),
                         "dos_port/src/scripts/cinnabar_gym.asm")

    def test_split_suffix_is_not_confused_with_a_numbered_map(self):
        # The reason matching is stem-exact rather than underscore-insensitive:
        # "route1_2" and "route12" would otherwise collide.
        self.assertNotEqual(uld.script_port_file("scripts/Route1_2.asm"),
                            uld.script_port_file("scripts/Route12.asm"))

    def test_floor_token_spelling_is_tolerated(self):
        self.assertEqual(uld.script_port_stems("scripts/MtMoonB1F.asm")[1],
                         ["mt_moon_b1f", "mt_moon_b_1f"])


class ScriptProvenanceLintTests(unittest.TestCase):
    """The rules fire on a seeded violation (the tree itself is clean)."""

    def _lint(self, seed_defs):
        with tempfile.TemporaryDirectory() as tmp:
            db = pathlib.Path(tmp) / "seeded.db"
            shutil.copy(DB, db)
            con = sqlite3.connect(db)
            for name, file in seed_defs:
                con.execute(
                    "INSERT INTO port_defs VALUES (?,?,?,0,1,1,3,0,'.text')",
                    (name, file, 1))
            con.commit()
            con.close()
            r = subprocess.run(
                [sys.executable, str(LINTER), "--no-scan", "--db", str(db)],
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            return r.returncode, r.stdout

    def test_clean_tree_has_no_script_findings(self):
        code, out = self._lint([])
        self.assertNotIn("script_collision", out)
        self.assertNotIn("script_misplaced", out)
        self.assertEqual(code, 0, out)

    def test_collision_outside_the_script_layer(self):
        code, out = self._lint(
            [("Route3SignText", "dos_port/src/engine/overworld/oddball.asm")])
        self.assertEqual(code, 1)
        self.assertIn("script_collision", out)
        self.assertIn("Route3SignText", out)

    def test_misplaced_inside_the_script_layer(self):
        code, out = self._lint(
            [("Route3SignText", "dos_port/src/scripts/pallet_town.asm")])
        self.assertEqual(code, 1)
        self.assertIn("script_misplaced", out)

    def test_stub_files_are_exempt(self):
        # hidden_object_stubs.asm legitimately holds the Mansion*Script_Switches
        # stubs; the stub convention owns placement of link-time stand-ins.
        con = sqlite3.connect(DB)
        rows = con.execute(
            "SELECT d.file FROM script_labels s JOIN port_defs d "
            "ON d.name = s.name WHERE d.is_stub = 1").fetchall()
        con.close()
        self.assertTrue(rows, "expected the stubbed pret scripts/ labels")
        code, _out = self._lint([])
        self.assertEqual(code, 0)


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
