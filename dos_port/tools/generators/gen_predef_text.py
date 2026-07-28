#!/usr/bin/env python3
"""gen_predef_text.py — generate dos_port/assets/predef_text.inc (Tier 1 data).

pret's `TextPredefs` table (data/text_predef_pointers.asm) has **68** entries,
indices $01..$44, dispatched by PrintPredefTextID (home/predef_text.asm). Each
entry names a text-stream label defined in an engine/ file. Measured against the
pret tree, those 68 split four ways:

    50  plain `text_far` wrappers          -> Tier-1 data, generated HERE
    14  `text_asm` wrappers                -> Tier-2 code (multi-page readers,
                                              the Cinnabar quiz, SFX tails,
                                              event-flag branches). NOT data.
     3  `script_*` dispatch markers        -> single script-opcode bytes
                                              (script_players_pc / _pokecenter_pc
                                              / _bills_pc), owned by the
                                              text-script dispatcher, not by a
                                              text generator.
     1  `db "@"`  (UnusedPredefText)       -> a bare terminator; generated HERE
                                              because it IS pure data.

So this generator emits **51** labels and deliberately emits nothing for the
other 17. That split is asserted below: if the pret tree ever changes shape, this
generator fails loudly rather than silently emitting a different set.

Each emitted label becomes a flattened, self-terminating byte stream (text_far
inlined, matching the port's flat TX_FAR model) plus a `{ptr, len}` `<Label>_ref`
pair — the same shape gen_pickup_text.py / gen_item_text.py produce, and the
idiom the consuming code uses because a cross-object label is not a link-time
immediate.

Reuses gen_battle_text.py's charmap/memmap/far-text machinery rather than
re-deriving it; only the wrapper collector is specific to this table (pret's
predef labels are not uniformly `*Text`-suffixed — TMNotebook, CinnabarGymQuiz,
IndigoPlateauStatues and friends — so collection is driven by the actual
add_tx_pre list, not by a name pattern).

*** THIS DATA IS NOT YET CONSUMED. *** src/home/predef_text.asm cannot link
until DisplayTextID's TEXT_PREDEF branch can address a flat table; see
docs/current_plan_predef_text.md for the measured blocker.

DO NOT EDIT the output by hand — re-run this generator. Run from repo root or
dos_port/.
"""
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_battle_text as gbt  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "dos_port" / "assets" / "predef_text.inc"
PREDEF_TABLE = ROOT / "data" / "text_predef_pointers.asm"

# Expected shape of pret's table. Asserted, not assumed.
EXPECT_ENTRIES = 68
EXPECT_EMITTED = 51

# The 17 entries this generator deliberately does NOT emit, with the reason.
# Kept explicit so a reader can see the whole 68 accounted for, and so a pret
# change that moves a label between classes trips the assertion below.
NOT_DATA = {
    # `text_asm` — the message IS code (page loops, branches, SFX tails).
    "SaffronCityPokecenterBenchGuyText": "text_asm: EVENT_BEAT_SILPH_CO_GIOVANNI branch",
    "ViridianSchoolNotebook":            "text_asm: 5-page TurnPageSchoolNotebook loop",
    "ViridianSchoolBlackboard":          "text_asm: paged blackboard reader",
    "FoundHiddenItemText":               "text_asm: item-award tail after the far intro",
    "BillsHouseInitiatedText":           "text_asm: StopAllMusic/SFX_SWITCH sequence",
    "BillsHousePokemonList":             "text_asm: HandleMenuInput + DisplayPokedex menu",
    "CinnabarGymQuiz":                   "text_asm: quiz state machine",
    "LinkCableHelp":                     "text_asm: paged help reader",
    "IndigoPlateauStatues":              "text_asm: badge-count branch",
    "VermilionGymTrashSuccessText1":     "text_asm: WaitForSoundToFinish tail",
    "VermilionGymTrashSuccessText3":     "text_asm: WaitForSoundToFinish tail",
    "VermilionGymTrashFailText":         "text_asm: WaitForSoundToFinish tail",
    "TownMapText":                       "text_asm: opens the town map",
    "BookOrSculptureText":               "text_asm: wCurMapTileset branch",
    # `script_*` macros — one script-opcode byte, dispatched by DisplayTextID.
    "RedBedroomPCText":                  "script_players_pc dispatch marker",
    "PokemonCenterPCText":               "script_pokecenter_pc dispatch marker",
    "OpenBillsPCText":                   "script_bills_pc dispatch marker",
}


def read_table():
    """The add_tx_pre labels, in pret order. Index i (0-based) is predef id i+1."""
    out = []
    for line in PREDEF_TABLE.read_text(encoding="utf-8").splitlines():
        s = line.strip()
        if s.startswith("add_tx_pre"):
            out.append(s.split()[1])
    return out


def find_definitions(labels):
    """label -> (path, line index, file lines) for its `Label::` definition."""
    want = set(labels)
    defs = {}
    for sub in ("engine", "home"):
        for path in sorted((ROOT / sub).rglob("*.asm")):
            lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
            for i, ln in enumerate(lines):
                m = re.match(r'(\w+)::?\s*$', ln.strip())
                if m and m.group(1) in want and m.group(1) not in defs:
                    defs[m.group(1)] = (path, i, lines)
    return defs


def body_of(lines, i):
    """Source lines of the wrapper starting after the label at index i."""
    body = []
    for j in range(i + 1, len(lines)):
        t = lines[j].split(";", 1)[0].strip()
        if not t:
            continue
        if re.match(r'^[A-Za-z_]\w*::?$', t):     # next label — stop
            break
        body.append(lines[j])
        if t.startswith("text_end") or t == "done":
            break
    return body


def classify(body):
    """'data' if this wrapper is a pure printable stream, else why not."""
    stripped = [l.split(";", 1)[0].strip() for l in body]
    stripped = [s for s in stripped if s]
    if any(s == "text_asm" for s in stripped):
        return "text_asm"
    if not stripped:
        return "empty"
    head = stripped[0]
    if head.startswith("script_"):
        return "script"
    if head.startswith("text_far") or head.startswith("db"):
        return "data"
    return "other:" + head.split()[0]


def main() -> int:
    charmap = gbt.load_charmap()
    memmap = gbt.load_memmap()
    far_db = gbt.collect_far(charmap, memmap)

    entries = read_table()
    if len(entries) != EXPECT_ENTRIES:
        raise SystemExit(
            f"gen_predef_text: TextPredefs has {len(entries)} entries, expected "
            f"{EXPECT_ENTRIES}. pret's table changed shape — re-audit the class "
            f"split before regenerating.")

    defs = find_definitions(entries)
    undefined = [e for e in entries if e not in defs]
    if undefined:
        raise SystemExit(f"gen_predef_text: no definition found for {undefined}")

    emitted, skipped = {}, {}
    for label in entries:
        path, i, lines = defs[label]
        body = body_of(lines, i)
        kind = classify(body)
        if kind != "data":
            skipped[label] = kind
            continue
        try:
            emitted[label] = gbt.parse_body(body, charmap, memmap, far_db)
        except (KeyError, ValueError) as e:
            skipped[label] = f"unparsable: {e}"

    # The class split is a measured claim about the pret tree. Assert it both
    # ways so drift is loud: the skip set must be exactly NOT_DATA.
    if set(skipped) != set(NOT_DATA):
        unexpected = sorted(set(skipped) - set(NOT_DATA))
        vanished = sorted(set(NOT_DATA) - set(skipped))
        raise SystemExit(
            "gen_predef_text: class split changed.\n"
            f"  newly non-data (expected to generate): {unexpected}\n"
            f"  newly data (expected to skip):         {vanished}\n"
            "Re-audit against pret before regenerating.")
    if len(emitted) != EXPECT_EMITTED:
        raise SystemExit(
            f"gen_predef_text: emitted {len(emitted)}, expected {EXPECT_EMITTED}")

    labels = sorted(emitted)
    out = [
        "; predef_text.inc — generated by tools/generators/gen_predef_text.py. DO NOT EDIT BY HAND.",
        "; TextPredefs message streams (pret data/text_predef_pointers.asm, 68 entries).",
        f"; {len(labels)} of 68 emitted as data; {len(skipped)} are Tier-2 code or script",
        "; dispatch markers (see the generator's NOT_DATA table for the per-label reason).",
        "; text_far flattened to the port's flat TX_FAR model. section .data (see link.ld).",
        "",
        "section .data",
        "",
    ]
    for label in labels:
        b = emitted[label]
        out.append(f"global {label}")
        out.append(f"{label}:")
        for i in range(0, len(b), 16):
            out.append("    db " + ", ".join(f"0x{x:02X}" for x in b[i:i + 16]))
        out.append(f"global {label}_ref")
        out.append(f"{label}_ref: dd {label}, {len(b)}   ; flat ptr + byte count")
    out.append("")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(out))
    print(f"wrote {OUT}")
    print(f"  {len(labels)} labels emitted, {len(skipped)} skipped (Tier-2 / script)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
