# Map-Script Fidelity — closing the `scripts/` gate gap

**Status: PLANNED** (maintainer-approved direction, 2026-07-24 M8.3 session).
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

## Stage 1 — Provenance lint for `scripts/` labels  `[ ]`

The cheapest check that catches the worst failure (name collision / wrong
provider), without dragging thousands of script labels into the DB's
missing/translated counts.

- `[ ]` Teach `tools/lint_pret_labels` (or `update_label_db`, whichever owns
  the scan) a **names-only side table** of pret `scripts/*.asm` global labels
  (plus their owning map file). No status bookkeeping, no headline-count
  impact.
- `[ ]` New lint rule: any port-defined global whose name appears in that side
  table must be defined in `src/scripts/<snake_case map>.asm` (the
  `pallet_town.asm` / `route_3.asm` naming), exactly once. Violations:
  `script_collision` (name used by a non-scripts port file) and
  `script_misplaced` (wrong scripts file).
- `[ ]` Run tree-wide; fix or annotate anything it flags on the existing two
  script files (expected: clean).
- `[ ]` Update the `faithfulness-review` skill + `route_3.asm`/
  `pallet_town.asm` headers to name the new rule (they currently say "the
  mirror linter never fires on these").

Non-goal: faithdiff for script labels. Per-map pret scripts are macro-heavy
(`dw_const`, `def_script_pointers`, `CheckEvent`…), so the call-graph model
would need per-map suppressions everywhere — poor return while Stage 2 shrinks
the surface anyway. Revisit only if hand-written script code grows despite
Stage 2 (measure: count of hand-written lines under `src/scripts/`).

## Stage 2 — Data-driven drivers for the formulaic script shapes  `[ ]`

Replace the copy-paste majority of a map's script layer with one generic
driver + generated Tier-1 tables. Hand-written per-map `.asm` remains only for
genuinely bespoke logic (Oak walk-up, Route 22 rival, the truncated tails).

- `[ ]` **`TrainerMapScript` driver** (port-only routine; lives with the script
  engine, gets normal gate coverage): parameterized by
  `(flat header table, flat script-pointer table, per-map CurScript GB addr)`,
  it performs the universal skeleton — `EnableAutoTextBoxDrawing`,
  `ExecuteCurMapScriptInTable(ESI=headers, EDI=table, AL=[CurScript])`, store
  AL back. Exactly what `Route3_Script` hand-writes today.
- `[ ]` **`gen_map_script_tables.py`** → `assets/map_script_tables.inc`: for
  every "standard trainer map" (a `_Script` that is *only* the skeleton, and a
  `_ScriptPointers` table that is *only*
  `CheckFightingMapTrainers / DisplayEnemyTrainerTextAndStartBattle /
  EndTrainerBattle`), emit the per-map parameter block + script-pointer table,
  keeping pret label names on the tables. Emit the per-map `w<Map>CurScript`
  addresses from the golden `pokeyellow.sym` (single source; retires the
  hand-pulled `wRoute3CurScript equ`). Maps that don't match the standard
  shape are listed in the generator output as hand-port debt (no silent caps).
- `[ ]` **Generic `TrainerTalkHook`**: one routine + a generated
  (map, text-id) → header-ptr table replaces the N per-map
  `ld hl, HeaderN / call TalkToTrainer / jp TextScriptEnd` hooks. Needs a
  small extension to the `gen_npc_dialogs` SCRIPT_OVERRIDES mechanism (a
  parameterized-hook entry form) — design against `CheckNPCInteraction`'s
  `call edi` dispatch.
- `[ ]` Convert Route 3 to the driver (deleting most of `route_3.asm`) and
  wire the next 2–3 pure-trainer maps (candidates: Route 4, Route 6, Route 24
  — pick from the generator's standard-shape list) as table entries only.
- `[ ]` **Truncated-tail retirement path**: extend the trainer-header
  generator with an optional per-header "post-end-battle event" field (data
  representation of the 3 behavioral `SetEvent` tails) consumed by the engine
  after `PrintEndBattleText`, OR schedule those 3 maps for bespoke hand-ports.
  Decide when the first affected map (Rocket Hideout / Lance) is wired.
  `PlayCry` tails ride on the existing text-stream sound-command model.

## Stage 3 — Behavioral goldens: one must-hit scenario per scripted map  `[ ]`

Static checks can't see a wrong flag bit or swapped text pointer; the mGBA
differential harness can — and it's the only check that also validates the
*generated* header data.

- `[ ]` New golden scenario `route3_sight`: spawn on Route 3 inside a
  trainer's view range (`DEBUG_START_MAP=0x0E` + coords), let the sight flow
  fire, dump at a deterministic gate; compare vs mGBA ground truth the WRAM
  the flow mutates (`wSpriteIndex`, `wTrainerHeaderFlagBit`, `wCurMapScript`
  progression, `wEngagedTrainerClass/Set`, `wJoyIgnore`) + emotion-bubble
  OAM/VRAM. This retroactively end-to-end-verifies M8.2 + M8.3.
- `[ ]` New scenario `route3_talk` (after the talk hooks or generic hook are
  live on a reachable interaction): TalkToTrainer path incl.
  `SaveEndBattleTextPointers` WRAM effects.
- `[ ]` **Standing rule** (add to the `faithfulness-review` skill's subsystem
  guide): a newly wired map script lands with a must-hit scenario exercising
  at least its default script path. No scenario, no wire.
- `[ ]` Known blocker to record in the scenario masks: the battle handoff is
  seeded-only (`TRAINER_BATTLE_LIVE` gate), so scenarios gate on the pre-battle
  WRAM state, not battle entry.

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
clean tree-wide; ≥3 standard maps run on the driver+tables with zero per-map
hand-written skeleton code; `route3_sight` (minimum) is in the fidelity tiers;
and the standing scenario rule is written into the skill.
