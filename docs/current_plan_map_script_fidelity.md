# Map-Script Fidelity — closing the `scripts/` gate gap

**Status: STAGE 1 DONE, STAGE 2 DONE, STAGE 3 BLOCKED** (2026-07-24 autonomous
implementation session; direction maintainer-approved in the M8.3 session).
Stage 3's blocker is measured and written up under that stage — it is a golden
*harness reachability* problem, not a fidelity finding.
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
- `[~]` **The other 16 standard maps are NOT wired**, deliberately. Their
  parameter blocks and `_ScriptPointers` tables are emitted (wiring one is a
  one-line `WIRED_MAPS` edit), but the standing rule this plan itself adds is
  "no scenario, no wire" — and Stage 3, which produces those scenarios, is
  blocked. Route 3 stays wired because it was already live before this plan
  (M8.3); nothing newly went live without evidence. The generator prints the 16
  on every run so they cannot be silently forgotten.
- `[ ]` **Truncated-tail retirement path** (untouched — no affected map is wired
  yet, and the plan defers the decision to the first one that is): extend the trainer-header
  generator with an optional per-header "post-end-battle event" field (data
  representation of the 3 behavioral `SetEvent` tails) consumed by the engine
  after `PrintEndBattleText`, OR schedule those 3 maps for bespoke hand-ports.
  Decide when the first affected map (Rocket Hideout / Lance) is wired.
  `PlayCry` tails ride on the existing text-stream sound-command model.

## Stage 3 — Behavioral goldens: one must-hit scenario per scripted map  `[~]`

Static checks can't see a wrong flag bit or swapped text pointer; the mGBA
differential harness can — and it's the only check that also validates the
*generated* header data.

**PORT HALF: DONE. GOLDEN HALF: BLOCKED on harness reachability.**

- `[x]` Port-side gate `DEBUG_MAPSCRIPT_SIGHT` (`RunMapScriptSightTest`,
  `src/debug/debug_dump.asm`; spawn seeding in `EnterMap`). Defaults to Route 3
  with the player at (Y=6, X=12) — two tiles inside `ROUTE3_YOUNGSTER1`'s
  view range 2 — and is parameterised (`MAPSCRIPT_MAP/Y/X`) so any wired map can
  reuse it. It drives `RunMapScript` + `UpdateSprites` per frame until the map's
  `_Script` engages, then dumps `GBSTATE.BIN` + `FRAME.BIN`.
  It deliberately does **not** enter `OverworldLoop`: the port still carries a
  bespoke `CheckTrainerSight`/`TrainerEncounterFlow` pair with no pret
  counterpart, and running both engages the trainer twice.
- `[x]` The trainer-flow WRAM rows (`%ifdef DEBUG_MAPSCRIPT_SIGHT` `gbregion`
  block). Scenario-local on purpose: putting them in the shared region set would
  change every committed golden's `.bin` layout and force a full `make goldens`.
- `[x]` **Measured port-side result** (`tools/run_headless.sh
  "DEBUG_MAPSCRIPT_SIGHT=1"`, GBSTATE flags `0x9E` = terminal + scenario 30):

  | field | value | meaning |
  |---|---|---|
  | `wSpriteIndex` / `wTrainerHeaderFlagBit` | `02` | ROUTE3_YOUNGSTER1 — object index 1, sprite slot 2 |
  | `wTrainerEngage` | `20 0C 3C 20` | view 2 (`<<4`), facing DOWN-code `$0C`, screenY `$3C`, screenX `$20` = exactly 2 tiles left of the player |
  | `wEmotionBubble` | `02 00` | sprite 2, EXCLAMATION |
  | `wStatusFlags7` | bit 3 | `BIT_TRAINER_BATTLE` |
  | `wStatusFlags5` | bit 0 | scripted NPC movement armed (walk-up running) |
  | `wCurMapScript` | `01` | advanced DEFAULT → START_BATTLE |
  | `wGameProgressFlags+8` (`$D5F7`) | `01` | **`wRoute3CurScript`** — the driver wrote back to the right per-map byte |

  This is real end-to-end execution of the generated trainer-header data through
  the Stage 2 driver. It is **not** a differential result: nothing here is
  compared against the real game.
- `[!]` **BLOCKED — the golden harness cannot put the player on Route 3.** All
  three mechanisms were tried and measured (details + the written scenario are in
  `dos_port/tools/mgba_harness/wip/route3_sight.lua`, kept out of `scenarios/`
  so `goldens-verify` does not demand a golden for it):
  1. **Walking.** Route 3 is six maps past the start, behind the Viridian parcel
     guard and the Viridian Forest maze; `navigate.walk` holds a direction, it
     cannot path-find.
  2. **Script warp** (`wStatusFlags3` `BIT_WARP_FROM_CUR_SCRIPT` → `WarpFound2`).
     Its destination byte `hWarpDestinationMap` is `$FF8B`, a **union** shared
     with `hDownArrowBlinkCount1`, `hSpriteInterlaceCounter` and ~12 others
     (`ram/hram.asm`). Probe: wrote `$0E`, the warp consumed `$0A` ~12 frames
     later. A scenario writes between frames; the clobber happens within one.
  3. **Fly warp** (`wStatusFlags6` `BIT_FLY_WARP` + `wDestinationMap`). Blocked
     twice over: `FlyWarpDataPtr`'s only non-town destinations are `ROUTE_4` and
     `ROUTE_10`, whose trainers sit ~50 tiles from the fly spot; and a probe
     setting `wDestinationMap = ROUTE_10` (`$15`) landed at `PALLET_TOWN` (5,6)
     while `wDestinationMap` still read `$15` afterwards — the warp did not use
     the value we wrote. Seeding a party first changed nothing.
  Next step is a 20-line probe: instrument `LoadSpecialWarpData`'s branch
  selection (log `wStatusFlags6` and `wLastBlackoutMap` at the moment
  `.otherDestination` is reached) to find out which branch actually ran. If the
  fly warp can be made to honour `wDestinationMap`, `route10_sight` on `ROUTE_10`
  becomes the cheapest first golden (it is a standard trainer map, its fly spot
  is (11,20), and `ROUTE10_COOLTRAINER_F1` at (7,25) facing LEFT view 3 sees
  (4..6, 25) — a ~10-tile walk).
- `[ ]` New scenario `route3_talk`: unstarted, same blocker.
- `[x]` **Standing rule** written into the `faithfulness-review` skill's
  subsystem guide: a newly wired map script lands with a must-hit scenario
  exercising at least its default script path. This is why Stage 2 wired no new
  maps.
- `[ ]` Known blocker to record in the scenario masks: the battle handoff is
  seeded-only (`TRAINER_BATTLE_LIVE` gate), so scenarios gate on the pre-battle
  WRAM state, not battle entry. (Not yet recorded — there is no scenario entry
  to record it in.)

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
exist; wiring is gated on Stage 3)**; a must-hit sight scenario is in the
fidelity tiers **(blocked)**; and the standing scenario rule is written into the
skill **(done)**.

The remaining work is one problem, not four: **give the mGBA harness a way to
place the player on an arbitrary map.** Everything else in this plan is finished
or is a one-line edit behind it.
