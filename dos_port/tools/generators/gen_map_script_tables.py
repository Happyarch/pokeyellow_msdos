#!/usr/bin/env python3
"""gen_map_script_tables.py — generate dos_port/assets/map_script_tables.inc.

Map-script fidelity plan, Stage 2. A "standard trainer map" in pret is a map whose
whole script layer is boilerplate:

    <Map>_Script:                       <Map>_ScriptPointers:
        call EnableAutoTextBoxDrawing       def_script_pointers
        ld hl, <Map>TrainerHeaders          dw_const CheckFightingMapTrainers, ..._DEFAULT
        ld de, <Map>_ScriptPointers         dw_const DisplayEnemyTrainerTextAndStartBattle, ..._START_BATTLE
        ld a, [w<Map>CurScript]             dw_const EndTrainerBattle, ..._END_BATTLE
        call ExecuteCurMapScriptInTable
        ld [w<Map>CurScript], a
        ret

Seventeen maps are exactly this and nothing else. Hand-porting seventeen copies of
the same seven instructions is the surface the fidelity gate would then have to
police, so instead the skeleton becomes ONE port-only routine (TrainerMapScript,
src/scripts/trainer_map_script.asm) parameterised by a generated per-map block:

    MapScriptParams:  NUM_MAPS x MSP_SIZE(12) — dd headers, dd script_pointers,
                      dd cur_script (GB WRAM offset). All-zero for a map with no
                      standard script; TrainerMapScript refuses to run on those.
    <Map>_ScriptPointers: the three-entry flat dd jumptable, keeping pret's label
                      name (this is Tier-1 data with a pret name, exactly like
                      <Map>TrainerHeaders — its home is its carrier file).
    w<Map>CurScript:  `equ` for every per-map script byte in pret ram/wram.asm,
                      derived by walking the wGameProgressFlags block from a single
                      anchor. This retires the hand-pulled `wRoute3CurScript equ`
                      that route_3.asm carried (a golden-.sym value typed in by hand).

WIRING IS NOT AUTOMATIC. Emitting a map's parameter block costs nothing at runtime;
what makes a map live is MapScriptPointers (gen_map_scripts.py), which reads
WIRED_MAPS below. Per the faithfulness-review skill's standing rule, a map is wired
only once it has a must-hit golden scenario. Maps that are standard-shaped but not
yet wired are printed on every run — never silently dropped.

Run from repo root (or dos_port/); paths resolve relative to the repo root.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
ASSETS = ROOT / "dos_port" / "assets"
SCRIPTS = ROOT / "scripts"
WRAM = ROOT / "ram" / "wram.asm"
MAP_CONSTANTS = ROOT / "constants" / "map_constants.asm"

# Flat trainer-header stride — mirrors TH_SIZE in src/home/trainers.asm and the
# tables gen_trainer_headers.py emits.
TH_SIZE = 22
# MapScriptParams entry: dd headers, dd script_pointers, dd cur_script.
MSP_SIZE = 12

# wGameProgressFlags's GB address. The port anchors this block at pret's own
# layout; wPalletTownCurScript (= this + 1) is the value already baked into
# include/gb_memmap.inc, and the golden pokeyellow.sym agrees
# (wOaksLabCurScript = $D5EF). Everything else in the block is derived by walking
# ram/wram.asm from here, so adding a map costs no new hand-typed address.
WGAMEPROGRESSFLAGS = 0xD5EF

# Maps whose script layer is LIVE (MapScriptPointers -> TrainerMapScript). Each
# entry must have a golden scenario exercising at least its default script path;
# see the faithfulness-review skill, "Map scripts: no scenario, no wire".
WIRED_MAPS = {
    "ROUTE_3": "route3_sight",
}


# ---------------------------------------------------------------------------
# pret parsing
# ---------------------------------------------------------------------------

def parse_map_order():
    """Ordered list of map const names from constants/map_constants.asm (= wCurMap)."""
    maps = []
    for line in MAP_CONSTANTS.read_text().splitlines():
        m = re.match(r"\s*map_const\s+(\w+)\s*,", line)
        if m:
            maps.append(m.group(1))
    return maps


def const_to_pascal(const):
    """ROUTE_3 -> Route3, SS_ANNE_1F -> SsAnne1F (pret's own script basename is
    the authority, so this is only a candidate — resolve_pascal picks the file)."""
    return "".join(w.capitalize() for w in const.split("_"))


def parse_cur_script_addresses():
    """{label: GB address} for every w*CurScript in pret's wGameProgressFlags block.

    Walks ram/wram.asm from wGameProgressFlags, accumulating `db` (1) and `ds N`
    (N) so the padding pret leaves between maps is honoured. Stops at the next
    section/`::`-labelled non-CurScript symbol that is not part of the block.
    """
    lines = WRAM.read_text().splitlines()
    start = next(i for i, ln in enumerate(lines) if ln.startswith("wGameProgressFlags::"))
    addrs, offset = {}, 0
    pending = []
    for ln in lines[start + 1:]:
        text = ln.split(";", 1)[0].rstrip()
        if not text.strip():
            continue
        m = re.match(r"^(\w+)::\s*(db|ds\s+.*)?$", text)
        if m and not text.startswith((" ", "\t")):
            name, rest = m.group(1), (m.group(2) or "").strip()
            if not name.endswith("CurScript") and not pending:
                # A non-CurScript symbol at column 0 ends the block only once we
                # have collected some — pret puts wGameProgressFlags itself first.
                if addrs:
                    break
            pending.append(name)
            if not rest:
                continue
            text = rest
        text = text.strip()
        if text == "db":
            for name in pending:
                addrs[name] = WGAMEPROGRESSFLAGS + offset
            pending = []
            offset += 1
        elif text.startswith("ds "):
            if pending:
                for name in pending:
                    addrs[name] = WGAMEPROGRESSFLAGS + offset
                pending = []
            offset += eval_ds(text[3:])
        elif re.match(r"^\w+::", text):
            continue
        else:
            # Anything else in this block would silently shift every later
            # address — refuse rather than guess.
            sys.exit(f"gen_map_script_tables: unhandled wram line in the "
                     f"wGameProgressFlags block: {ln!r}")
    return addrs


def eval_ds(expr):
    """Evaluate a `ds` size expression. Only integer arithmetic appears here."""
    expr = expr.strip()
    if not re.fullmatch(r"[0-9\s+*/()-]+", expr):
        sys.exit(f"gen_map_script_tables: non-numeric ds expression {expr!r}")
    return int(eval(expr))  # noqa: S307 — pattern-restricted to arithmetic above


SKELETON = [
    "call EnableAutoTextBoxDrawing",
    "ld hl, {name}TrainerHeaders",
    "ld de, {name}_ScriptPointers",
    "ld a, [w{name}CurScript]",
    "call ExecuteCurMapScriptInTable",
    "ld [w{name}CurScript], a",
    "ret",
]
POINTER_TABLE = [
    "def_script_pointers",
    "CheckFightingMapTrainers",
    "DisplayEnemyTrainerTextAndStartBattle",
    "EndTrainerBattle",
]


def body_of(text, label):
    m = re.search(r"^" + re.escape(label) + r":\n((?:\t.*\n)+)", text, re.M)
    return [ln.strip() for ln in m.group(1).strip().splitlines()] if m else None


def classify_scripts():
    """Return (standard, near_miss, bespoke) over every pret map with a `_Script`.

    standard  = {pret map name: script file stem} — driver-eligible.
    near_miss = {name: why} — the skeleton body with a non-standard pointer table;
                these are the candidates for a future driver extension, so they
                are enumerated.
    bespoke   = [name] — an ordinary hand-written map script. Counted, not listed:
                it is not debt, it is just a map with real logic.
    """
    standard, rejected, bespoke = {}, {}, []
    for path in sorted(SCRIPTS.glob("*.asm")):
        text = path.read_text()
        m = re.search(r"^(\w+)_Script:$", text, re.M)
        if not m:
            continue
        name = m.group(1)
        body = body_of(text, f"{name}_Script")
        want = [ln.format(name=name) for ln in SKELETON]
        if body != want:
            bespoke.append(name)
            continue
        ptrs = body_of(text, f"{name}_ScriptPointers")
        if not ptrs or len(ptrs) != len(POINTER_TABLE) or ptrs[0] != POINTER_TABLE[0] \
           or not all(want_ptr in got for want_ptr, got in
                      zip(POINTER_TABLE[1:], ptrs[1:])):
            # NEAR MISS: the skeleton body with extra/other sub-scripts. These are
            # the maps the driver could cover if it grew a per-map tail, so they
            # are named individually; a fully bespoke _Script is just an ordinary
            # map, counted but not enumerated.
            rejected[name] = (f"skeleton body but {len(ptrs) - 1 if ptrs else 0} "
                              f"script pointers (standard is 3)")
            continue
        # Keep pret's own SCRIPT_* constant spelling for the emitted comments: the
        # names are declared implicitly by dw_const in the script file itself
        # (def_script_pointers is just const_def), so there is no constants/ file
        # to look them up in and no derivable rule (SCRIPT_ROUTE3_DEFAULT, not
        # SCRIPT_ROUTE_3_DEFAULT).
        standard[name] = (path.stem,
                          [ln.split(",")[-1].strip() for ln in ptrs[1:]])
    return standard, rejected, bespoke


def map_const_for(script_name, maps):
    """Match a pret script basename to its map constant (Route3 -> ROUTE_3)."""
    key = script_name.lower()
    for const in maps:
        if const.replace("_", "").lower() == key:
            return const
    return None


# ---------------------------------------------------------------------------
# emit
# ---------------------------------------------------------------------------

def check_against_gb_memmap(cur_scripts):
    """Cross-check the derivation against the addresses already in gb_memmap.inc.

    Two per-map script bytes were hand-pulled from the golden .sym long before this
    generator existed (wPalletTownCurScript, wSafariZoneGateCurScript). They are an
    independent witness: if walking ram/wram.asm from WGAMEPROGRESSFLAGS does not
    reproduce them, the walk is wrong and EVERY address it emits is suspect.
    """
    inc = (ROOT / "dos_port" / "include" / "gb_memmap.inc").read_text()
    checked = 0
    for m in re.finditer(r"^(w\w*CurScript)\s+equ\s+(0x[0-9A-Fa-f]+)", inc, re.M):
        label, addr = m.group(1), int(m.group(2), 16)
        if label not in cur_scripts:
            continue
        if cur_scripts[label] != addr:
            sys.exit(f"gen_map_script_tables: derived {label} = "
                     f"0x{cur_scripts[label]:04X} but gb_memmap.inc says "
                     f"0x{addr:04X} — the wram.asm walk is wrong")
        checked += 1
    if not checked:
        sys.exit("gen_map_script_tables: gb_memmap.inc has no w*CurScript equ to "
                 "cross-check the derivation against")
    return checked


def main():
    maps = parse_map_order()
    cur_scripts = parse_cur_script_addresses()
    cross_checked = check_against_gb_memmap(cur_scripts)
    standard, near_miss, bespoke = classify_scripts()

    # Resolve each standard script to its map constant + per-map CurScript byte.
    rows, unresolved = {}, []
    for name in sorted(standard):
        const = map_const_for(name, maps)
        label = f"w{name}CurScript"
        if const is None:
            unresolved.append(f"{name}: no map_const matches the script basename")
            continue
        if label not in cur_scripts:
            unresolved.append(f"{name}: {label} not found in ram/wram.asm")
            continue
        rows[const] = (name, cur_scripts[label], standard[name][1])

    unknown = set(WIRED_MAPS) - set(rows)
    if unknown:
        sys.exit(f"gen_map_script_tables: WIRED_MAPS names maps with no standard "
                 f"script: {sorted(unknown)}")

    out = []
    out.append("; AUTO-GENERATED by tools/generators/gen_map_script_tables.py — do not edit.")
    out.append("; Map-script fidelity plan Stage 2: per-map parameter blocks for the generic")
    out.append("; TrainerMapScript driver (src/scripts/trainer_map_script.asm).")
    out.append(";")
    out.append("; MapScriptParams entry (MSP_SIZE = %d):" % MSP_SIZE)
    out.append(";   +0 dd <Map>TrainerHeaders    flat header table (stride %d)" % TH_SIZE)
    out.append(";   +4 dd <Map>_ScriptPointers   flat dd jumptable (pret def_script_pointers order)")
    out.append(";   +8 dd w<Map>CurScript        GB WRAM offset of the map's persistent script byte")
    out.append("; An all-zero entry means 'no standard script'; TrainerMapScript returns.")
    out.append(";")
    out.append("; The .inc does NOT open a section; carrier src/data/map_script_tables.asm")
    out.append("; opens section .data before %include-ing it (map_scripts.asm pattern).")
    out.append("")
    out.append(f"MSP_SIZE equ {MSP_SIZE}")
    out.append("")

    out.append("; ── script-pointer jumptable targets (src/home/trainers.asm) ──────────")
    for label in POINTER_TABLE[1:]:
        out.append(f"extern {label}")
    out.append("")
    out.append("; ── per-map trainer-header tables (assets/trainer_headers.inc) ────────")
    for const in sorted(rows):
        out.append(f"extern {rows[const][0]}TrainerHeaders")
    out.append("")

    out.append("; ── per-map script-pointer tables (pret label names preserved) ────────")
    for const in sorted(rows):
        name, _addr, consts = rows[const]
        out.append(f"global {name}_ScriptPointers")
        out.append(f"{name}_ScriptPointers:")
        for i, (target, script_const) in enumerate(zip(POINTER_TABLE[1:], consts)):
            out.append(f"    dd {target:<40} ; {script_const} ({i})")
    out.append("")

    out.append("; ── MapScriptParams: NUM_MAPS entries, indexed by wCurMap ─────────────")
    out.append("align 4")
    out.append("MapScriptParams:")
    for i, const in enumerate(maps):
        if const in rows:
            name, addr, _consts = rows[const]
            wired = "LIVE" if const in WIRED_MAPS else "table-only"
            out.append(f"    dd {name}TrainerHeaders, {name}_ScriptPointers, "
                       f"0x{addr:04X}  ; 0x{i:02X} {const} ({wired}, "
                       f"w{name}CurScript)")
        else:
            out.append(f"    dd 0, 0, 0  ; 0x{i:02X} {const}")
    out.append("")

    dst = ASSETS / "map_script_tables.inc"
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_text("\n".join(out) + "\n")

    # Report — no silent caps. Every pret map with a _Script lands in exactly one
    # bucket, and the buckets are printed with their sizes.
    print(f"wrote {dst} ({len(maps)} MapScriptParams entries, "
          f"{len(rows)} standard trainer map(s), {len(WIRED_MAPS)} wired; "
          f"{len(cur_scripts)} CurScript addresses derived, "
          f"{cross_checked} cross-checked vs gb_memmap.inc)")
    not_wired = sorted(set(rows) - set(WIRED_MAPS))
    if not_wired:
        print(f"  standard-shape, table emitted, NOT wired ({len(not_wired)}): "
              f"{', '.join(not_wired)}", file=sys.stderr)
        print("  -> add to WIRED_MAPS once the map has a must-hit golden scenario "
              "(faithfulness-review skill: 'no scenario, no wire')", file=sys.stderr)
    if near_miss:
        print(f"  NEAR MISS — skeleton body, non-standard pointer table "
              f"({len(near_miss)}); driver-extension candidates:", file=sys.stderr)
        for name in sorted(near_miss):
            print(f"    {name}: {near_miss[name]}", file=sys.stderr)
    print(f"  bespoke map scripts, hand-port territory: {len(bespoke)}",
          file=sys.stderr)
    if unresolved:
        print(f"  UNRESOLVED ({len(unresolved)}):", file=sys.stderr)
        for line in unresolved:
            print(f"    {line}", file=sys.stderr)


if __name__ == "__main__":
    main()
