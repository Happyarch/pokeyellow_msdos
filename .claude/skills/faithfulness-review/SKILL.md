---
name: faithfulness-review
description: Pret-fidelity review gate for the Pokémon Yellow DOS port. Invoke BEFORE committing any change that touches a pret-labeled routine (any routine whose name comes from the pret disassembly), when reviewing such a change, or when asked to check a translation's faithfulness. Provides the faithdiff / lint_pret_labels / label_status / golden-differ workflow and the justification rules for added or dropped calls. Triggers: "review this translation", "is this faithful to pret", "faithdiff", "lint labels", "pre-commit fidelity check", "goldencheck".
---

# Faithfulness Review Gate

The last four status-screen bugs (sprite bleed-in, HUD tile-slot clobber, missing
PTile, spurious ▼) shared one root cause: generalizing from the port's own code
instead of reading pret's specific routine. All four were mechanically detectable.
This gate makes that class of divergence fail a check instead of surviving to the
user. All tools live in `dos_port/tools/`; they read `translation.db`, which is
**always rescan-derived — never edit it by hand or write it from an agent.**

## Two automated gates exist. Know which is which before you start.

This skill used to describe only the hand-run tools below, which left two things
invisible: that a **pre-commit hook already runs a whole-tree ratchet on every
commit**, and that the per-change evidence chain and the relocation move battery
are a tool, not a manual procedure.

    tools/static_gate     WHOLE-TREE structural ratchet against the checked-in
                          per-class baseline (tools/static_gate_baseline.json).
                          No arguments. **Invoked by .githooks/pre-commit**, so it
                          runs whether or not you remember it — install with
                          `make -C dos_port install-hooks`. It runs both
                          lint_pret_labels modes, the label-DB pytest suite, and
                          validate_scenarios.py. THE RATCHET GOES BOTH WAYS: a
                          class that shrank fails too, until the baseline is
                          lowered deliberately with a stated reason.
                          It exits 0 when nothing under `dos_port/` is staged.
    tools/fidelity_gate   PER-CHANGE, PER-LABEL: derives the pret labels a diff
                          touched and runs lint / project_state / faithdiff over
                          them — the automated form of steps 1-2 below. It ALSO
                          carries the relocation move battery:
                            fidelity_gate --move-baseline DIR file...   (BEFORE editing)
                            fidelity_gate --move-verify   DIR [--gates LIST|auto]
                          Use the battery for any mirror move; it decomposes the
                          diff into moved / new / dropped, hard-fails a non-
                          declaration line that appears or vanishes, and builds
                          the `%ifdef`-only link paths you name.

Neither replaces step 3: **a green gate proves no structural or bookkeeping
drift and NOTHING about behaviour.** Both print that caveat on every pass.
Design notes, non-vacuity proofs and traps: stigmergy memory
`static-gate-and-ci-wiring`.

## The gate (run before committing a change that touches a pret-labeled routine)

0. **Annotate the divergence in the source, structurally.** Before the tools:
   every sanctioned divergence carries a machine-parsed
   `DEVIATION{class=…; pret=…; behavior=…; evidence=…; lifetime=…}` (or
   `BUG{}` / `GLITCH{}` / `STUB{}` — those four kinds and no others). `lint_pret_labels`
   parses them strictly, so a malformed one or an unknown `class` **fails the gate**.
   A commit message is not a substitute: it is not queryable, and a cold `faithdiff`
   run months later re-discovers the divergence with no pointer to the reasoning.
   Full schema, the legal `class` values, and the "no `;` inside a value" trap →
   skill **`project-conventions`**.

   **New relocations are not allowed.** A pret counterpart's complete routine and
   every pret entry point belong in `dos_port/src/<pret path>`. The relocation
   registry is legacy debt, not authority or precedent. An agent whose work trips
   the mirror rule must move the routine to its mirrored path, never add an
   allowlist entry or structural finding. Registry edits may only retire or
   reclassify audited debt and are content-hash locked outside the worktree.

1. **`tools/faithdiff <Label>`** for every pret-labeled routine you touched.
   It diffs the pret vs port call graph and named-WRAM/HRAM store set.
   - Every unsuppressed **ADDED/DROPPED** line must be either (a) fixed, or
     (b) justified — in the **source annotation** (step 0) for anything durable, and
     restated in the commit message. The annotation is the record that survives.
   - **Known blind spots — do not "fix" a phantom.** `faithdiff` counts `call`/`jmp`
     to a label; it does **not** count conditional jumps (`jz`/`jne`/`jnz` to a pret
     label read as DROPPED though the routine is reached), and it matches stores
     **by name**, so pret's pointer-indirect writes (`set BIT_x, [hl]` where `hl` is a
     named symbol) surface as an ADDED named store on the port side. Confirm against
     the source before acting.
   - **It has no model of call-site relocation, routine decomposition, or a routine
     inlined into a differently-named host.** A call that legitimately moved between
     routines shows up as disconnected ADDED/`missing`/DROPPED lines, and an inlined
     routine gets a *confident wrong provider* pointing at whatever dead file still
     carries the label. See stigmergy memories `faithdiff-no-call-relocation-model`
     and `label-db-wrong-provider-on-inlined-routines` before concluding "unported".
   - Global translation boundaries (DelayFrame plumbing, TODO-HW, banking,
     scroll-register mirrors) are already suppressed in
     `tools/faithdiff_suppress.json` — add there only symbols that are expected
     on one side of *every* routine, with a why. Routine-specific divergence
     never goes in the suppression file; it goes in the commit message.
2. **`tools/lint_pret_labels`** — must exit 0 before committing. It rescans the
   tree (so it sees your change) and enforces: pret-named globals live in the
   path-mirrored file or a `*_stubs.asm`; and — for names taken from pret
   `scripts/*.asm`, which have **no** call-graph/status model — the provenance
   rules `script_collision` / `script_misplaced` (see "Map scripts" below). A `mirror` finding means move the
   complete routine to the mirrored file; it is not an instruction to edit the
   relocation registry. Existing registered relocations are printed loudly as
   legacy debt and must be moved when touched; stubs stay
   ret-only; no duplicate global defs (silent-shadow trap); extern comments
   point at stub files that still define the symbol.
3. **Run every golden scenario whose compared surface could observe the change.**
   Use `make -C dos_port goldencheck SCENARIO=<name>` for targeted coverage,
   `make -C dos_port fidelity` for the core pre-commit tier, and
   `make -C dos_port fidelity-full` when the change can affect long-tail
   scenarios. Do not select scenarios only by whether the routine draws pixels:
   WRAM datastruct flows are first-class fidelity evidence.

   Subsystem guide:
   - Status, START, overworld, party, bag, options, trainer card, pokédex, naming,
     battle HUD/menu, and streamed dialog changes need their matching rendered
     scenario(s).
   - Party/bag/dex/add-mon/item-effect data mutations need the relevant
     **datastruct** scenario(s), even if the changed path renders nothing.
   - Text printers and NPC/sign dialog need `sign_pallet` or a new
     dialog-bearing scenario if `sign_pallet` does not exercise the path.
   - Battle UI/menu changes need the relevant battle/menu tier
     (`battle_intro`, `battle_menu`, `move_selection`, `ball_catch`, or the
     core/full target that covers them).
   - **Map scripts: no scenario, no wire.** A newly wired per-map script layer
     (a `<Map>_Script` reached from `MapScriptPointers`, whether hand-written or
     a `map_script_tables.inc` row) lands together with a must-hit scenario that
     exercises at least its default script path — `route3_sight` is the
     template. Static checks cannot see a wrong flag bit or a swapped text
     pointer, and the mGBA differential is also the only check that validates
     the *generated* trainer-header data behind the script.

   A new legitimate divergence needs a mask **with a written justification** in
   `tools/golden_diff.py` — never a bare mask. If an OPEN finding owns the
   divergence, the mask's why-string must carry that finding id so retiring the
   finding greps to the masks that must be deleted.

## Unmodeled pret dirs — provenance, not call graph

`update_label_db` models pret `home/` + `engine/` only, so a name the port takes
from pret `scripts/*.asm` is `port_only`: `faithdiff` answers "not a pret label"
and the mirror rule cannot fire. What *does* cover them:

- **`script_labels`** — a names-only side table of every pret `scripts/*.asm`
  global (3.7k names, no status, no headline-count impact).
- **`script_collision`** — a port symbol borrowing one of those names is defined
  outside `dos_port/src/scripts/`. Either the port symbol means something else
  (rename it) or a map's script layer landed in the wrong subsystem.
- **`script_misplaced`** — right layer, wrong map file. Expected path is
  `dos_port/src/scripts/<snake_case map>.asm`; pret's bank-split continuations
  (`Route1_2.asm`) belong in the same file as the main half.
- Exempt: `*_stubs.asm` (the stub convention owns stand-in placement), and
  labels defined inside a generated `assets/*.inc` (the scan walks `.asm` only —
  placement of generated Tier-1 data is governed by its carrier file).

The same blind spot covered `audio/`, `data/`, `gfx/` and `ram/` until 2026-07-27.
It is now closed the same way:

- **`aux_labels`** — names-only side table for those four dirs (5.7k names, no
  status, no headline-count impact), built by `update_label_db.scan_pret_aux`.
- **`aux_misplaced`** — the placement rule, and it is deliberately per-dir
  because the port's conventions differ:
  - `audio/` mirrors pret's path exactly (`dos_port/src/audio/<file>.asm`) —
    measured 22/22 conformant (2026-07-28, after upstream moved
    `PlayPikachuSoundClip` from `engine/pikachu/` into `audio/`), so this
    ratchets a convention that already holds.
  - `data/` is grouped by SUBSYSTEM in the port (`battle_data.asm`,
    `item_data.asm`, `pokemon_data.asm`), not by pret path, so a path mirror
    would be wrong. The checkable invariant is that the label lives in the data
    layer at all — under `dos_port/src/data/` or a generated `assets/*.inc`. A
    pret data table buried in `engine/` or `home/` code is hand-copied Tier-1
    data that `make assets` cannot protect. **Baseline 14** (pre-existing debt:
    `LedgeTiles`, `TilePairCollisions{Land,Water}`, `CardKeyTable1-3`,
    `BikeRidingTilesets`, `MapHeaderPointers`, `MapSongBanks`, …) — ratchet it
    down, never up.
  - `gfx/` and `ram/` are exempt: `gfx/` is generated assets and `ram/` names are
    WRAM addresses owned by `gb_memmap.inc`, so neither has a port mirror.

**`route3_sight` is the worked example, and it earned its keep on run one:** it
caught `EngageMapTrainer` reading a WRAM address the port never writes (the
port's `wMapSpriteExtraData` is a flat `.bss` array, but
`m8_2_pending_symbols.inc` binds the pret name to pret's WRAM address `$D503` —
so a file including that `.inc` cannot reach the array by its pret name), and it
caught every trainer's class byte being `0` in the generated map-object binaries
(`gen_map_headers.py` resolved `OPP_*` against an empty table and swallowed 470
"unknown constant, using 0x00" warnings). Neither is visible to any static check.

Deliberate non-goal: no faithdiff for script labels. Per-map pret scripts are
macro-heavy (`dw_const`, `def_script_pointers`, `CheckEvent`), so a call-graph
model would need per-map suppressions everywhere. The intended protection is to
shrink the hand-written surface instead — see the `TrainerMapScript` driver and
`gen_map_script_tables.py`, which turn a standard trainer map's script layer
into a generated table row with no per-map assembly at all. Revisit only if
hand-written lines under `src/scripts/` grow anyway.

## While translating (before writing code)

- `tools/label_status --callees <Label>` — classifies every call target of the
  pret routine as translated / relocated / stub / missing, so you know what to
  extern vs stub before writing a line. Detail: `asm-translation` skill, step 2.
- Retiring a stub? `tools/label_status --callers <Label>` is the retirement
  checklist (repoint extern comments; audit callers translated against stub-era
  behavior). Detail: `project-conventions` skill, stub rule 5.

## After the change lands

Run `tools/update_label_db` so the DB reflects the tree. Skipping it is
self-healing (the next scan fixes it), never corrupting — but the next session's
`label_status` answers will be stale until someone rescans.

## Reviewer's checklist for justifications

A commit that adds/drops a call on a pret-labeled routine must say, per label:
- the pret line(s) it diverges from (file:label reference),
- why the divergence is forced (HAL boundary, unported dependency, documented
  port deviation) — "the port's other screens do it this way" is exactly the
  reasoning this gate exists to reject,
- what retires it, if it's interim (which plan/wave, or "permanent, by design").
