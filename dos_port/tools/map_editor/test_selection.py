"""Map selection and command-line error handling regression tests."""
import json
from pathlib import Path
import subprocess
import sys
import unittest

TOOLS = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(TOOLS))
from map_editor.commands import resolve_map


class SelectionTest(unittest.TestCase):
    def test_names_and_typo(self):
        for name in ("VERMILION_DOCK", "VermilionDock", "vermilion dock",
                     "vermiliondoc", "vermillion dock"):
            with self.subTest(name=name):
                self.assertEqual(resolve_map(name), "VERMILION_DOCK")

    def test_ambiguous_and_no_match(self):
        with self.assertRaisesRegex(ValueError, "ambiguous map"):
            resolve_map("route")
        with self.assertRaisesRegex(ValueError, "no map matches"):
            resolve_map("zzzzzzzzzzzzzz")
        with self.assertRaisesRegex(ValueError, "must not be empty"):
            resolve_map(" ")

    def test_entrypoints_no_traceback(self):
        editor = TOOLS / "map_editor"
        for argv in ([str(editor / "cli.py"), "inspect", "zzzzzzzzzzzzzz"],
                     [str(editor / "editor.py"), "zzzzzzzzzzzzzz"]):
            with self.subTest(argv=argv):
                result = subprocess.run([sys.executable, *argv], text=True,
                                        capture_output=True)
                self.assertEqual(result.returncode, 2)
                self.assertNotIn("Traceback", result.stdout + result.stderr)
                self.assertIn("no map matches", result.stdout + result.stderr)
                if "cli.py" in argv[0]:
                    self.assertFalse(json.loads(result.stdout)["written"])


if __name__ == "__main__":
    unittest.main()
