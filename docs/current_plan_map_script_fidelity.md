# Map-Script Fidelity — closing the `scripts/` gate gap

**Status: STAGES 1-3 DONE** (2026-07-24 autonomous implementation session;
direction maintainer-approved in the M8.3 session). `route3_sight` is live in the
`full` fidelity tier and PASSES — and it earned its keep immediately by catching
two real defects on its first run (see Stage 3).
**Owner topic:** the per-map script layer (`src/scripts/*.asm` + the generators
that feed it). **Prerequisites landed:** M8.2 trainer-engine promotion
(`5806ecf8`), M8.3 trainer-header data + Route 3 pilot (`7e8f31ad`).

## The problem

`update_label_db` scans pret `home/` + `engine/` only (its header says so; pret
`data/` and `scripts/` are outside its universe). Consequence: every label the
port takes from pret `scripts/*.asm` — `PalletTownOakText`, `Route3_Script`,
`Route3_ScriptPointers`, the eight Route 3 talk hooks — is classified
`port_only`, and **none of the gates fire on it**:

- `faithdiff <Label>` answers "not a pret label" — no call-graph/store diff.
- `lint_pret_labels`' mirror rule never checks that the file placement or the
  label's existence matches pret.
- Nothing detects a pret `scripts/` name silently meaning something *different*
  in the port, or a hand-translation drifting from pret structure.

The only protections today are convention (keep pret names, mirror pret
structure by hand — which `pallet_town.asm` and `route_3.asm` do) and review.
That was tolerable at one map; the trainer-header work makes per-map script
porting a recurring activity (each of the 7 TRUNCATED-TAIL streams in
`assets/trainer_headers.inc` is owed a hand-ported script layer), so the
unchecked surface grows unless we act.

Related standing debt this plan also retires opportunistically:
- The 7 truncated battle-text tails (inventory in the
  `assets/trainer_headers.inc` header; 3 behavioral `SetEvent` tails —
  `EVENT_BEAT_LANCE`, `EVENT_ROCKET_DROPPED_LIFT_KEY` + `ShowObject`,
  `EVENT_BEAT_ROCKET_HIDEOUT_1_TRAINER_4` — and 3 cosmetic `PlayCry` tails).
- The per-map `w<Map>CurScript` addresses are being pulled from the golden
  `.sym` one at a time by hand (`wRoute3CurScript` 0xD5F7); a generator should
  own them.

## Design principle

**Shrink the hand-written surface first; check what remains second; prove
behavior third.** A fidelity gate over thousands of hand-written script lines
is the expensive path — the cheap path is making most of those lines cease to
exist as hand-written code. Precedent: `MapScriptPointers`, the map text
tables, `trainer_headers.inc` — structure-as-generated-data is already this
port's idiom, and the two-tier rule stays intact (generators emit only
`assets/*.inc`; the generic drivers are hand-written once, live in mirrored
engine/home files, and get full gate coverage there).

---

## Stage 1 — Provenance lint for `scripts/` labels  `[x]`  (commit `3bb2d443`)

The cheapest check that catches the worst failure (name collision / wrong
provider), without dragging thousands of script labels into the DB's
missing/translated counts.

- `[x]` Teach `tools/lint_pret_labels` (or `update_label_db`, whichever owns
  the scan) a **names-only side table** of pret `scripts/*.asm` global labels
  (plus their owning map file). No status bookkeeping, no headline-count
  impact.
- `[x]` New lint rule: any port-defined global whose name appears in that side
  table must be defined in `src/scripts/<snake_case map>.asm` (the
  `pallet_town.asm` / `route_3.asm` naming), exactly once. Violations:
  `script_collision` (name used by a non-scripts port file) and
  `script_misplaced` (wrong scripts file).
- `[x]` Run tree-wide: 26 borrowed names, all correctly placed, lint exits 0.
  Two exemptions were needed and are documented in the rule: `*_stubs.asm` (the
  four `Mansion*Script_Switches` stubs) and labels defined inside a generated
  `assets/*.inc` — `scan_port` walks `.asm` only, so a generator-emitted `global`
  such as `<Map>TrainerHeaders` never reaches `port_defs` at all. That last one is
  a standing blind spot of the scan, not of this rule.
- `[x]` Update the `faithfulness-review` skill + `route_3.asm`/
  `pallet_town.asm` headers to name the new rule (they currently say "the
  mirror linter never fires on these").

Non-goal: faithdiff for script labels. Per-map pret scripts are macro-heavy
(`dw_const`, `def_script_pointers`, `CheckEvent`…), so the call-graph model
would need per-map suppressions everywhere — poor return while Stage 2 shrinks
the surface anyway. Revisit only if hand-written script code grows despite
Stage 2 (measure: count of hand-written lines under `src/scripts/`).

## Stage 2 — Data-driven drivers for the formulaic script shapes  `[x]`

Replace the copy-paste majority of a map's script layer with one generic
driver + generated Tier-1 tables. Hand-written per-map `.asm` remains only for
genuinely bespoke logic (Oak walk-up, Route 22 rival, the truncated tails).

- `[x]` **`TrainerMapScript` driver** (port-only routine; lives with the script
  engine, gets normal gate coverage): parameterized by
  `(flat header table, flat script-pointer table, per-map CurScript GB addr)`,
  it performs the universal skeleton — `EnableAutoTextBoxDrawing`,
  `ExecuteCurMapScriptInTable(ESI=headers, EDI=table, AL=[CurScript])`, store
  AL back. Exactly what `Route3_Script` hand-writes today.
- `[x]` **`gen_map_script_tables.py`** → `assets/map_script_tables.inc`: for
  every "standard trainer map" (a `_Script` that is *only* the skeleton, and a
  `_ScriptPointers` table that is *only*
  `CheckFightingMapTrainers / DisplayEnemyTrainerTextAndStartBattle /
  EndTrainerBattle`), emit the per-map parameter block + script-pointer table,
  keeping pret label names on the tables. Emit the per-map `w<Map>CurScript`
  addresses from the golden `pokeyellow.sym` (single source; retires the
  hand-pulled `wRoute3CurScript equ`). Maps that don't match the standard
  shape are listed in the generator output as hand-port debt (no silent caps).
- `[x]` **Generic `TrainerTalkHook`**: one routine + a generated
  (map, text-id) → header-ptr table replaces the N per-map
  `ld hl, HeaderN / call TalkToTrainer / jp TextScriptEnd` hooks. Needs a
  small extension to the `gen_npc_dialogs` SCRIPT_OVERRIDES mechanism (a
  parameterized-hook entry form) — design against `CheckNPCInteraction`'s
  `call edi` dispatch.
- `[x]` Convert Route 3 to the driver — `src/scripts/route_3.asm` is **deleted**
  outright (153 lines → zero); its `_Script`, its `_ScriptPointers` table, its
  hand-pulled `wRoute3CurScript equ` and all eight talk hooks are now generated
  data plus the two shared routines.
- `[~]` **The other 16 standard maps are NOT wired yet.** Their parameter blocks
  and `_ScriptPointers` tables are emitted, so wiring one is a one-line
  `WIRED_MAPS` edit plus its own sight scenario — and now that `route3_sight`
  works, that scenario is a near-copy (the gate is already parameterised by
  `MAPSCRIPT_MAP/Y/X`). The generator prints the 16 on every run so they cannot
  be silently forgotten.
- `[ ]` **Truncated-tail retirement path** (untouched — no affected map is wired
  yet, and the plan defers the decision to the first one that is): extend the trainer-header
  generator with an optional per-header "post-end-battle event" field (data
  representation of the 3 behavioral `SetEvent` tails) consumed by the engine
  after `PrintEndBattleText`, OR schedule those 3 maps for bespoke hand-ports.
  Decide when the first affected map (Rocket Hideout / Lance) is wired.
  `PlayCry` tails ride on the existing text-stream sound-command model.

## Stage 3 — Behavioral goldens: one must-hit scenario per scripted map  `[x]`

Static checks can't see a wrong flag bit or swapped text pointer; the mGBA
differential harness can — and it's the only check that also validates the
*generated* header data.

- `[x]` Port-side gate `DEBUG_MAPSCRIPT_SIGHT` (`RunMapScriptSightTest`,
  `src/debug/debug_dump.asm`; spawn seeding in `EnterMap`). Defaults to Route 3
  with the player at (Y=6, X=12) — two tiles inside `ROUTE3_YOUNGSTER1`'s view
  range 2 — and is parameterised (`MAPSCRIPT_MAP/Y/X`) so any wired map reuses
  it. Drives `UpdateSprites` + `RunMapScript` per frame until the map's `_Script`
  engages, then dumps.
  It deliberately does **not** enter `OverworldLoop`: the port still carries a
  bespoke `CheckTrainerSight`/`TrainerEncounterFlow` pair with no pret
  counterpart, and running both engages the trainer twice.
- `[x]` Golden scenario `tools/mgba_harness/scenarios/route3_sight.lua` +
  `tests/goldens/route3_sight.{bin,json}`, registered in
  `scenario_manifest.json` (id 30, `full` tier, datastruct class) and
  `golden_diff.SCENARIOS`. Two consecutive generations are byte-identical.
  The trainer-flow WRAM rows are scenario-local `%ifdef DEBUG_MAPSCRIPT_SIGHT`
  `gbregion`s: putting them in the shared set would change every committed
  golden's `.bin` layout and force a full `make goldens`.
- `[x]` **Getting the golden onto Route 3.** The map is six maps and a Viridian
  Forest maze past the start, so the scenario uses the game's own script warp:
  `wDestinationWarpID = $FF` (so `LoadTilesetHeader` skips
  `LoadDestinationWarpPosition` and hand-set coords survive),
  `hWarpDestinationMap = ROUTE_3`, `wStatusFlags3 BIT_WARP_FROM_CUR_SCRIPT`,
  plus `wCurrentTileBlockMapViewPointer` computed with pret's own
  `event_displacement` formula.
  **The load-bearing detail is *when* you arm it.** `navigate.walk_until_map`
  returns while the door step-out is still simulating and an `EnterMap` is in
  flight; anything armed then is consumed by *that* `EnterMap` (which clears
  `BIT_FLY_WARP` and never re-enters a map), and `hWarpDestinationMap` is `$FF8B`
  — a union shared with `hDownArrowBlinkCount1`, `hSpriteInterlaceCounter` and
  ~12 others — so a value left sitting for a dozen frames gets overwritten
  (measured: wrote `$0E`, the warp consumed `$0A`). Armed after a settle, the
  check runs two frames after the write and it lands first time. Three earlier
  probes failed purely on this sequencing, not on any game limitation.
- `[x]` **Two real defects caught on the scenario's first run**, both fixed:
  1. **`EngageMapTrainer` read a WRAM address nothing writes.**
     `m8_2_pending_symbols.inc` defines `wMapSpriteExtraData equ 0xD503` (pret's
     WRAM home) while the port's actual array is flat `.bss`, written by
     `LoadSprite`. So the routine read unwritten emulated RAM and the engaged
     trainer's class/set came back `$00/$00`. Fixed by externing the sanctioned
     flat alias `map_sprite_extra_data` (pret name stays primary on the array).
  2. **Every trainer's class byte in the generated map-object binaries was 0.**
     `gen_map_headers.py` resolved `object_event`'s trainer-class argument
     against an *empty* dict, so all 470 `OPP_*` names fell through
     `_resolve_const`'s "unknown constant, using 0x00" warning. Fixed with an
     `_OPP_CONSTS` table parsed positionally from
     `constants/trainer_constants.asm` (`OPP_BUG_CATCHER` = `$CA`, matching the
     golden exactly). Nothing consumed that byte until the trainer engine did,
     which is why it survived this long.
- `[x]` **Standing rule** written into the `faithfulness-review` skill's
  subsystem guide: a newly wired map script lands with a must-hit scenario
  exercising at least its default script path.
- `[x]` Known blocker recorded in the scenario's masks: the battle handoff is
  seeded-only (`TRAINER_BATTLE_LIVE` gate), so the scenario gates on the
  pre-battle WRAM state, not battle entry.
- `[ ]` `route3_talk` (the `TalkToTrainer` / `SaveEndBattleTextPointers` path)
  is still unwritten. The mechanism is now proven, so it is ordinary work: warp
  in facing a trainer and press A.

### Same-shape defects found but NOT fixed (out of this change's scope)

Both are the identical "unresolved constant / wrong array" pattern, found while
chasing the two above. Neither is touched here; they want their own change and
their own scenario:
- `src/engine/events/pick_up_item.asm:71` reads `[ebp + wMapSpriteExtraData]`,
  i.e. the same never-written WRAM address — so `PickUpItem` resolves an item
  ball's item id from garbage.
- `gen_map_headers.py` still emits 141 "unknown constant" warnings: the
  `object_event` **item-id** field (`RARE_CANDY`, `POTION`, …) and
  `BOULDER_MOVEMENT_BYTE_2` are resolved against empty tables the same way, so
  those bytes are all 0 too. The fix is the same shape as `_OPP_CONSTS`.

## Sequencing & interactions

- Stage 1 is independent and immediate; it protects the surface that exists
  today.
- Stage 2 before any bulk map-wiring push (don't hand-write 60 copies of the
  skeleton and then delete them).
- Stage 3's first scenario (`route3_sight`) can land any time — it tests
  what's already merged; do it early, it's the highest-value check in this
  plan.
- The map_sprites.asm sight-hook swap (bespoke `CheckTrainerSight` →
  `CheckFightingMapTrainers`, retiring `npc_beaten_flags`) is a **separate
  behavior-change task** deliberately outside this plan; Stage 3's scenarios
  are prerequisites for doing that swap safely.

## Completion

Archive to `docs/plans/map_script_fidelity.md` when: the lint rule is live and
clean tree-wide **(done)**; ≥3 standard maps run on the driver+tables with zero
per-map hand-written skeleton code **(1 of 3 — the driver and all 17 tables
exist; each further map is a `WIRED_MAPS` line plus a near-copy of
`route3_sight`)**; `route3_sight` is in the fidelity tiers **(done — `full`
tier, passing)**; and the standing scenario rule is written into the skill
**(done)**.
