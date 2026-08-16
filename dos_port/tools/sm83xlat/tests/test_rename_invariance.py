#!/usr/bin/env python3
"""Assert build_symbols.py works BEFORE and AFTER the gb_memmap rename.

Why this test exists
--------------------
Two workstreams consume tables/symbols.json and they run at different times:

  * docs/current_plan_memmap_pret_names.md renames the port's SCREAMING_SNAKE
    equs to pret names.
  * docs/current_plan_script_transpiler.md lowers pret script source to x86.

They are explicitly allowed to run in parallel, which is only safe if the
mapping tool is insensitive to whether the rename has landed. That is not a
hopeful assumption -- it is a property of matching on the normalized NAME rather
than on anything the rename changes, and this test pins it.

The check: synthesize the post-rename memmap by rewriting every resolved
candidate to its pret name, re-run the builder, and assert the work queue is
empty and nothing became a conflict. An empty queue IS the completion signal for
the rename workstream, so this doubles as its acceptance test.

Run:  python3 -m pytest dos_port/tools/sm83xlat/tests/ -q
      python3 dos_port/tools/sm83xlat/tests/test_rename_invariance.py   (standalone)
"""
import re
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
TOOL = HERE.parent / "build_symbols.py"
ROOT = HERE.parents[3]
MEMMAP = ROOT / "dos_port" / "include" / "gb_memmap.inc"

sys.path.insert(0, str(HERE.parent))
import build_symbols as bs  # noqa: E402


def _build(memmap_path):
    rows = bs.parse_memmap(memmap_path)
    return bs.build(rows, bs.parse_pret_labels(ROOT))


def _synthesize_renamed(text, data):
    """Rewrite every resolved candidate to its pret name, word-boundary anchored.

    Word boundaries are the point: W_CUR_MAP is a strict prefix of
    W_CUR_MAP_HEADER and 7 others, and `_` is a word character, so \\b stops the
    substitution from eating the longer names. If this ever regresses, the
    post-rename build reports unmatched garbage names and the test fails.
    """
    pairs = {}
    for section in ("confirmed", "name_only"):
        for port, info in data[section].items():
            pairs[port] = info["pret"]
    for port, pret in sorted(pairs.items(), key=lambda kv: -len(kv[0])):
        text = re.sub(rf"\b{re.escape(port)}\b", pret, text)
    return text, pairs


def _rename_invariance():
    """Body shared by the pytest case and the standalone runner."""
    before = _build(MEMMAP)
    n_before = before["counts"]["confirmed"] + before["counts"]["name_only"]
    assert n_before > 0, "no rename candidates found; the matcher is broken"
    assert before["counts"]["addr_conflict"] == 0, (
        f"pre-rename address conflicts: {list(before['addr_conflict'])}")

    text, pairs = _synthesize_renamed(MEMMAP.read_text(), before)
    with tempfile.NamedTemporaryFile("w", suffix=".inc", delete=False) as fh:
        fh.write(text)
        synth = Path(fh.name)
    try:
        after = _build(synth)
    finally:
        synth.unlink()

    a = after["counts"]
    # The work queue must be empty: every candidate now IS its pret name, so no
    # SCREAMING_SNAKE candidate remains for the matcher to pair.
    assert a["confirmed"] + a["name_only"] == 0, (
        f"{a['confirmed'] + a['name_only']} candidates survived the rename: "
        f"{list(after['confirmed'])[:5] + list(after['name_only'])[:5]}")
    assert a["addr_conflict"] == 0, f"rename introduced conflicts: {list(after['addr_conflict'])}"
    assert a["ambiguous"] == 0, f"rename introduced ambiguity: {list(after['ambiguous'])}"
    return n_before, len(pairs)


def test_rename_invariance():
    _rename_invariance()


def test_prefix_disambiguation():
    """The storage-class prefix must resolve the h/w/s collisions, not guess."""
    data = _build(MEMMAP)
    assert data["counts"]["ambiguous"] == 0, (
        f"unresolved ambiguity: {list(data['ambiguous'])}")
    both = {**data["confirmed"], **data["name_only"]}
    for port, info in both.items():
        m = re.match(r"^([WHSV])_", port)
        if m:
            assert info["pret"][0] == m.group(1).lower(), (
                f"{port} -> {info['pret']}: storage class disagrees")


def test_no_address_conflicts():
    """Every name match that CAN be cross-checked against an address must agree."""
    data = _build(MEMMAP)
    assert data["counts"]["addr_conflict"] == 0, (
        "a port symbol and the pret symbol it looks like name different storage: "
        f"{ {k: (v.get('addr'), v['pret_addr']) for k, v in data['addr_conflict'].items()} }")
    assert data["counts"]["confirmed"] > 0, "nothing was address-confirmed; cross-check is inert"


def test_tool_runs_clean():
    r = subprocess.run([sys.executable, str(TOOL), "--report"],
                       capture_output=True, text=True)
    assert r.returncode == 0, r.stderr


if __name__ == "__main__":
    n, pairs = _rename_invariance()
    test_prefix_disambiguation()
    test_no_address_conflicts()
    test_tool_runs_clean()
    print(f"OK — {n} candidates before the rename, 0 after ({pairs} substitutions); "
          f"no address conflicts, no ambiguity")
