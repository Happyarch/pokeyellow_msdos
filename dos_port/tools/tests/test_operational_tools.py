#!/usr/bin/env python3
import importlib.machinery
import importlib.util
import os
import pathlib
import re
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
    """pret scripts/<Map>.asm -> dos_port/src/scripts/<Map>.asm naming.

    REWRITTEN 2026-08-20. The port's script files were snake_case
    (dos_port/src/scripts/pallet_town.asm) and this class tested the conversion
    and its two tolerances. The files now carry pret's EXACT names, so the
    mapping is an identity and the tolerances are gone — which is the point:
    consistency with home/ and engine/, where the port has always mirrored pret's
    own file names, and one placement rule for the whole tree.
    """

    def test_port_file_is_prets_exact_name(self):
        for pret, expect in (
                ("scripts/Route3.asm", "Route3"),
                ("scripts/PalletTown.asm", "PalletTown"),
                ("scripts/CeladonMart1F.asm", "CeladonMart1F"),
                ("scripts/SSAnne1FRooms.asm", "SSAnne1FRooms"),
                ("scripts/SilphCo11F.asm", "SilphCo11F"),
                ("scripts/MtMoonB1F.asm", "MtMoonB1F"),
                ("scripts/UndergroundPathRoute7Copy.asm",
                 "UndergroundPathRoute7Copy")):
            with self.subTest(pret=pret):
                self.assertEqual(uld.script_port_stems(pret)[0], expect)
                self.assertEqual(uld.script_port_file(pret),
                                 "dos_port/src/scripts/" + expect + ".asm")

    def test_only_one_legal_path_per_pret_file(self):
        # There used to be two accepted stems (mt_moon_b1f / mt_moon_b_1f).
        # A tolerance is a place where two answers are both "right", which is
        # exactly where the mirror rule and script_misplaced drifted apart.
        for pret in ("scripts/MtMoonB1F.asm", "scripts/Route3.asm",
                     "scripts/Route1_2.asm"):
            with self.subTest(pret=pret):
                self.assertEqual(len(uld.script_port_stems(pret)[1]), 1)

    def test_bank_split_keeps_prets_path_so_the_allowlist_is_consulted(self):
        # pret splits a map's script across banks (Route1_2.asm); THE PORT IS
        # FLAT BY DESIGN, so both halves live in one file. That merge is declared
        # in pret_label_allowlist.json's relocated_files, which requires the
        # mirror here to stay pret's RAW path — collapsing `_N` would make the
        # row read `translated` and the declaration would never be consulted.
        self.assertEqual(uld.script_port_file("scripts/Route1_2.asm"),
                         "dos_port/src/scripts/Route1_2.asm")
        self.assertNotEqual(uld.script_port_file("scripts/Route1_2.asm"),
                            uld.script_port_file("scripts/Route1.asm"))

    def test_split_suffix_is_not_confused_with_a_numbered_map(self):
        self.assertNotEqual(uld.script_port_file("scripts/Route1_2.asm"),
                            uld.script_port_file("scripts/Route12.asm"))

    def test_every_bank_split_is_declared_in_the_allowlist(self):
        # The 27 `_N` files are the ONLY structural difference left between the
        # port's script layer and pret's. If pret gains another one, this fails
        # rather than the mirror rule failing later with no explanation.
        import json
        allow = json.loads((pathlib.Path(uld.__file__).resolve().parent
                            / "pret_label_allowlist.json").read_text())
        declared = set(allow.get("relocated_files", {}))
        splits = {f"scripts/{f}" for f in os.listdir(
            pathlib.Path(uld.REPO_ROOT) / "scripts")
            if re.search(r"_\d+\.asm$", f)}
        self.assertTrue(splits, "expected pret bank-split script files")
        self.assertEqual(splits - declared, set(),
                         "undeclared pret bank-split script file(s)")


class ScriptProvenanceLintTests(unittest.TestCase):
    """The rules fire on a seeded violation (the tree itself is clean)."""

    def _lint(self, seed_defs, move_label=None):
        """seed_defs adds port_defs rows; move_label=(name, port_file) rewrites a
        `labels` row's provider, which is what the mirror rule actually reads."""
        with tempfile.TemporaryDirectory() as tmp:
            db = pathlib.Path(tmp) / "seeded.db"
            shutil.copy(DB, db)
            con = sqlite3.connect(db)
            for name, file in seed_defs:
                con.execute(
                    "INSERT INTO port_defs VALUES (?,?,?,0,1,1,3,0,'.text')",
                    (name, file, 1))
            if move_label:
                con.execute("UPDATE labels SET port_file=? WHERE name=?",
                            (move_label[1], move_label[0]))
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
        # script_misplaced was RETIRED 2026-08-20 when the port's script files
        # were renamed to pret's exact names: the generic `mirror` rule now judges
        # placement for the script tier too, so keeping a second expectation was
        # how the two came to disagree. A label in the wrong map file is still a
        # violation — it is a `mirror` one, raised from the labels table rather
        # than from script_labels.
        # A TRANSLATED label, moved to another map's file. Route3SignText (the
        # old fixture) is `missing` — no port definition — so the mirror rule
        # correctly skips it and the test would pass on a broken linter.
        code, out = self._lint(
            [("AgathaScriptWalkIntoRoom", "dos_port/src/scripts/PalletTown.asm")],
            move_label=("AgathaScriptWalkIntoRoom",
                        "dos_port/src/scripts/PalletTown.asm"))
        self.assertEqual(code, 1, out)
        self.assertIn("mirror", out)
        self.assertIn("AgathaScriptWalkIntoRoom", out)
        self.assertNotIn("script_misplaced", out)

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
