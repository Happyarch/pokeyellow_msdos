# Map-Script Fidelity — closing the `scripts/` gate gap

**Status: COMPLETE** (2026-07-24). All four completion criteria met: the
provenance lint is live and clean, three standard trainer maps run on the generic
driver with zero per-map skeleton code, three sight goldens are in the `full`
fidelity tier and pass, and the standing scenario rule is in the
`faithfulness-review` skill. The goldens earned their keep immediately — three
real defects fell out of them (see Stage 3).
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
- `[x]` **Three maps wired: ROUTE_3, ROUTE_6, ROUTE_11**, each with its own sight
  golden. The remaining 14 standard maps have their parameter blocks and
  `_ScriptPointers` tables emitted but stay dark under "no scenario, no wire";
  the generator prints them on every run so they cannot be silently forgotten.
  Wiring one is now a `WIRED_MAPS` line, a per-map Makefile gate, a ~15-line
  scenario file over `lib/sight.lua`, and a golden.
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
- `[x]` **Three golden scenarios**, sharing one body in
  `tools/mgba_harness/lib/sight.lua` and differing only in their numbers, all in
  the `full` tier as datastruct-class comparisons. The trainer each targets was
  picked for coverage, not convenience:
  | scenario | id | trainer | why this one |
  |---|---|---|---|
  | `route3_sight` | 30 | ROUTE3_YOUNGSTER1 (10,6) RIGHT, view 2 | horizontal sight, first header in the scan |
  | `route6_sight` | 31 | ROUTE6_YOUNGSTER1 (0,15) RIGHT, view 4 | it is header **2**; headers 0-1 have view range **0** and are on screen, so it only engages if the scan skips non-seeing trainers — the golden confirms it (`wSpriteIndex` = 3) |
  | `route11_sight` | 32 | ROUTE11_GAMBLER1 (10,14) DOWN, view 3 | the **vertical** branch: `TrainerEngage` splits on which axis lines up, and the two horizontal ones never take `.linedUpX`. The golden confirms it (`screenX` = `$40`, `screenY` = `$1C`) |
  One gate per map (`DEBUG_MAPSCRIPT_SIGHT_R3/_R6/_R11`) rather than one gate with
  overrides, because `golden_diff` validates the scenario id stamped in the dump
  and `gen_scenario_registry` derives that id from the `port_entry_gate` define —
  scenarios sharing a gate would stamp the same id and one would always fail.
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
- `[x]` **Three real defects caught by these goldens**, all fixed:
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

### Same-shape defects found while chasing those two

Both are the identical "unresolved constant / wrong array" pattern.

- `[x]` **`gen_map_headers.py`'s remaining 141 silent zeros — FIXED** (follow-up
  commit). Three more `object_event` slots were being resolved against empty
  tables, and the hole itself — `_resolve_const` warning and returning `0` — is
  now closed: an unknown constant is fatal.
  - **item ids** (58 distinct: `POTION`, `RARE_CANDY`, every `TM_*`, the key
    items) → `gen_items.load_item_ids`, which already owns the `add_tm`/`add_hm`
    forms.
  - **stationary wild Pokémon** (`VOLTORB`, `ELECTRODE`, `ARTICUNO`, `ZAPDOS`,
    `MOLTRES`, `MEWTWO`). These are *not* items: Gen 1 encodes them as the 8-arg
    TRAINER form with the species in the class slot and the level in the num slot
    (`object_event 9, 20, SPRITE_POKE_BALL, STAY, NONE, TEXT_…, VOLTORB, 40`),
    and the engine tells them apart by value (`< OPP_ID_OFFSET` = species). So the
    previous commit's `_OPP_CONSTS` fix was itself incomplete — that slot needs
    the union of both namespaces, and `_merge_disjoint` refuses if a name ever
    appears in both.
  - **`BOULDER_MOVEMENT_BYTE_2`** (21 objects across 8 maps). This one was not
    cosmetic: `TryPushingBoulder` gates on
    `cmp al, BOULDER_MOVEMENT_BYTE_2 / jne ResetBoulderPushFlags`, and with the
    byte generated as `0` that branch could never be taken — **no Strength
    boulder in Seafoam Islands, Victory Road or the Warden's house was
    pushable.** The generated bytes now carry it — `map_object_SEAFOAM_ISLANDS_B1F`
    reads `db 0x49, 0x0A, 0x15, 0xFF, 0x10, 0x01`, byte 2 = `$10`. Note this is
    the data half plus a static read of `TryPushingBoulder`'s compare; pushing a
    boulder has **not** been exercised at runtime, and there is no boulder
    scenario yet.
  - The hand-transcribed `_MOV_CONSTS` / `_DIR_CONSTS` dicts are retired too:
    both slots now read the same `DEF … EQU` block out of
    `constants/map_object_constants.asm`, so they cannot drift from pret.
- `[x]` **`src/engine/events/pick_up_item.asm` — FIXED** (same follow-up wave, at
  the maintainer's direction, documented rather than scenario-gated). It read
  `[ebp + wMapSpriteExtraData]` — the same never-written WRAM address
  `EngageMapTrainer` used — so `PickUpItem` handed `GiveItem` the item id `0` for
  every visible item ball. Same one-line fix: read the flat
  `map_sprite_extra_data` alias. Together with the item ids now being correct in
  the generated data, both halves of visible item-ball pickup are in place.
  **Not runtime-verified:** there is no item-ball pickup scenario, so this rests
  on `faithdiff PickUpItem` (clean), the fidelity tier (no regression) and the
  fact that it is the identical fix to the one `route3_sight` proved. An
  item-ball golden is the obvious next scenario.

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

## Completion — met, 2026-07-24

| criterion | state |
|---|---|
| lint rule live and clean tree-wide | **done** — `script_collision` / `script_misplaced`, 26 borrowed names, exit 0 |
| ≥3 standard maps on the driver+tables, zero per-map skeleton code | **done** — ROUTE_3, ROUTE_6, ROUTE_11; `src/scripts/route_3.asm` deleted outright |
| a must-hit sight scenario in the fidelity tiers | **done** — three of them, `full` tier, passing |
| standing scenario rule written into the skill | **done** — `faithfulness-review`, "Map scripts: no scenario, no wire" |

Carried forward (not blockers, recorded so they are not lost):

- The other **14** standard maps are table-only. Each is a `WIRED_MAPS` line, a
  Makefile gate, a ~15-line scenario over `lib/sight.lua`, and a golden.
- `route3_talk` — the `TalkToTrainer` / `SaveEndBattleTextPointers` path — is
  still unwritten. The mechanism is proven; it is ordinary work now.
- An **item-ball pickup golden**: `PickUpItem`'s fix (`5f01bba1`) is the only
  change in this workstream with no runtime evidence behind it.
- A **boulder** scenario: `BOULDER_MOVEMENT_BYTE_2` reaching the data is verified
  in the emitted bytes, but pushing a boulder has never been exercised.
- The truncated-tail retirement path (Stage 2's last bullet) is untouched — no
  affected map is wired yet, and the plan defers the decision to the first one
  that is.
- The map_sprites.asm sight-hook swap (bespoke `CheckTrainerSight` →
  `CheckFightingMapTrainers`, retiring `npc_beaten_flags`) remains the separate
  behavior-change task these scenarios were the prerequisite for. It is now
  unblocked.
