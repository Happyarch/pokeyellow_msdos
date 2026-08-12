# Current Plan: Battle Engine Completion

> **Gate — the linter is MANDATORY. Rewritten 2026-08-02 against the tooling
> that actually exists; the version this replaces predated `static_gate` and
> told you "nothing runs it for you", which stopped being true on 2026-07-26.**
>
> **What runs automatically.** `dos_port/tools/static_gate` runs BOTH linter
> modes plus `test_label_db.py` and `validate_scenarios.py`, and it is invoked
> by `.githooks/pre-commit` (installed here: `core.hooksPath=.githooks`). It
> fires whenever anything under `dos_port/` is staged. It is a per-class
> RATCHET against a checked-in baseline: it fails a class that GREW.
>
> **What that does NOT mean.** A class sitting at baseline is not sanctioned —
> it is unfixed debt that merely has not gotten worse. `dos_port/tools/lint_pret_labels`
> **must exit 0**.
>
> **It DOES exit 0 today — that changed since this plan was written.** Measured
> 2026-08-11: both `lint_pret_labels --no-scan` and `--no-scan --strict-claims`
> report **0 violations**, and the `static_gate` baseline is empty (`{}`). The
> paragraph this replaces said the opposite ("it does not today", naming
> `aux_misplaced` / `hand_encoded_text` / `local_shadow` as outstanding); that
> was true on 2026-08-02 and is now stale. The debt was cleared by `a3804828`,
> `3fad3249` and the map-header relocation.
>
> The consequence for you is the important part: **any finding you see is
> YOURS**, not inherited. Do not treat a non-zero count as pre-existing.
> Still **run both modes yourself** rather than trusting any number written here
> — including this one. Do not cite "at baseline" as permission to leave a class
> non-zero, and do not rewrite the rule to match the breakage.
>
> **For every commit made under this plan:**
> 1. Record the per-class counts from BOTH `lint_pret_labels` and
>    `lint_pret_labels --strict-claims` **before** you start.
> 2. Run both again before committing and compare per class. A class that grew
>    is your regression to fix now, not the next agent's to discover. Moving a
>    routine between files silently invalidates `extern` provider comments
>    elsewhere in the tree — collateral visible **only** under `--strict-claims`.
> 3. A green static gate proves **no structural or bookkeeping drift and nothing
>    about behaviour.** If the change can move a pixel or a WRAM byte, run
>    `make -C dos_port fidelity` (core) or `fidelity-full`, and add a must-hit
>    scenario when no existing one can witness the change.
>
> **The allowlist is not yours to grow.** `dos_port/tools/pret_label_allowlist.json`
> is hash-locked legacy debt, not precedent. New relocations are FORBIDDEN. An
> agent may not add, expand or reinterpret it — including `structural_findings`
> and `suppress` — to make its own work pass. **Any ADDITION requires explicit
> maintainer sign-off and cannot be committed without it**; the pre-commit hook
> refuses added keys outright and names them. If the linter says `mirror`, move
> the complete routine to `dos_port/src/<pret path>` instead.
>
> Do not quote a finding count from this file, CLAUDE.md, AGENTS.md, a skill, or
> a stigmergy memory as evidence that a class is clean — every one of those has
> been wrong before. Re-measure it.

Status: **the wild-battle backend and the first battle fidelity surfaces are
live; trainer entry, the PKMN/ITEM subflows, special battle types, transitions,
and animations remain open.** Archive this file to
`docs/plans/battle_completion.md` only after Stage 7 closes.

This status was refreshed 2026-08-02 against pret, the default linked build,
`dos_port/tools/project_state --no-scan`, `label_status`, the fidelity manifest
(`dos_port/tools/scenario_manifest.json` — see it for the current scenario
count), and the operational evidence policy in `AGENTS.md`. The archived
`docs/archive/battle_audit_findings.md` predates that procedure and is historical
only: its claims are not current evidence. Superseded execution narratives and
resolved blockers remain in git history instead of being maintained here.

**2026-08-02 re-measurement coverage.** This pass re-measured this plan against
generated state per the maintainer directive — it is a currency refresh, not new
work. It reached 26 of the 32 open checklist items below; all 26 measured STILL
OPEN and none was found already done. Six items were **not reached** and must
not be read as covered by this refresh: Stage 1c's script-state half (the loss/
blackout/aborted-battle path through `wCurMapScript` and post-battle text
selection were not traced, only the beaten-flag write site), Stage 5's bullet 2
(the `docs/bugs_and_glitches.md` scripted-battle transition bug was not opened),
and all three Stage 7 bullets (the retirement sweep, the gated scenario/goldens
run, and the archival condition — none independently measured), plus the
shape-correctness of Stage 6's interpreter/dispatch decomposition (6c/6d were
measured for label/provider state only, not audited against pret's animation
source). Separately, five items were confirmed by a prior sampling pass rather
than re-derived this round: the five `battle_exp_stubs.asm` labels, `ReadTrainer`'s
caller count, and the shared `BattlePartyMenu`/`BattleItemMenu` `ret` body.

## Standing rules and ownership

- Preserve pret labels, big-endian GB data, register mapping, and exact ZF/CF
  contracts. Human-rendered text and static battle data are generated Tier-1
  assets; battle behavior, dispatchers, and HAL boundaries remain hand-written
  Tier-2 code.
- Before calling anything missing, stubbed, check-only, unreachable, or
  callerless, rerun `dos_port/tools/project_state` and use
  `label_status --callers/--callees`. Inspect Makefile linkage and `%ifdef`
  guards directly; a definition visible to static scanning may be absent from
  the default build.
- For changed pret code, run `dos_port/tools/fidelity_gate --base <base>`. A
  clean result means only "no detected structural divergence"; each behavior
  change also needs a deterministic scenario whose must-hit list proves the
  changed path executed.
- The completed items plan (`docs/plans/items.md`) delivered `UseItem_`,
  `ItemUsePtrTable`, every `ItemUse*` body, and item-subsystem helpers. This plan
  owns `BattleItemMenu`, battle-context routing, turn consumption, switches, and
  battle-loop consumers.
- `docs/current_plan_overworld_events.md` owns map/event data and dispatch,
  story scripts, battle-state seeding, and overworld result consumers. This plan
  owns trainer-battle activation/exit semantics and special battle-type behavior.
- Link battles remain Phase 4. Preserve pret's link branches and explicit
  structured stand-ins, but do not make link transport part of this plan.

## Proven baseline

- [x] The default build links the wild-entry, normal turn, damage/status/effect,
      faint/EXP, run, blackout, and overworld-return providers. The current
      scenario manifest does not execute an end-to-end battle win and return, so
      this is structural baseline rather than current runtime proof.
- [x] The battle fidelity expansion converged the wild intro, action menu, move
      selection, and ball-capture state against mGBA. It fixed the concrete
      F-17 through F-21 intro/HUD defects; the remaining F-19-owned clone masks
      are tracked separately in Stage 6e.
- [x] `UseItem_`, `ItemUsePtrTable`, medicine, balls, battle items, Poké Doll,
      and Safari BAIT/ROCK effects are translated. Their direct item scenarios do
      not make the live battle ITEM button functional.
- [x] Trainer party loading, trainer AI decision/scoring code, enemy send-out,
      prize-money arithmetic, victory, blackout, and the overworld trainer
      service spine have translated providers. Several are not on an executed
      default-build trainer route yet; linkage is not execution evidence.

## Measured accuracy survey — 2026-08-03

This survey is the sequencing gate requested before executing the plan. It uses
the label DB stamped at `93ef2363`, the 41-row scenario manifest, each stub's
port callers, and the actual `DEBUG_BATTLE_*` gates. Raw status, static
reachability, and archived audit prose are not execution evidence.

### Inventory decomposition

The modeled `engine/battle*` inventory is **384 translated / 283 missing / 13
stubs** (680 labels). The 283 missing labels decompose as follows; this is a
file inventory, not 283 independent missing features:

| pret file | missing | What the count mostly represents |
|---|---:|---|
| `animations.asm` | 135 | Stage 6 animation interpreter/data transforms |
| `battle_transitions.asm` | 37 | Stage 5 transitions |
| `core.asm` | 33 | menus, trainer presentation, link paths, wrappers and helpers |
| `common_text.asm` | 21 | presentation text |
| `effects.asm` | 17 | bank wrappers/text plus animation entry points |
| `draw_hud_pokeball_gfx.asm` | 14 | HUD graphics loader/presentation |
| `used_move_text.asm` | 6 | used-move text variants |
| `init_battle.asm` | 6 | pret wild/trainer orchestration labels collapsed by the port |
| `safari_zone.asm` | 3 | Safari presentation/flow |
| `ghost_marowak_anim.asm` | 2 | special-battle animation |
| `scroll_draw_trainer_pic.asm` | 2 | trainer presentation |
| `trainer_ai.asm` | 2 | AI item/withdraw text |
| `unused_stats_functions.asm` | 2 | selected-stat double/halve helpers |
| three one-label files | 3 | link versus text, Conversion bank wrapper, Pikachu entrance |

Raw `missing` overstates absent behavior where the port collapsed, inlined, or
split pret structure. Examples: the wild path lives in `_InitBattleCommon` while
`InitBattleCommon`/`InitWildBattle`/`StartBattle` remain missing, and several
`effects.asm` bank wrappers dispatch to translated `move_effects/*` bodies.
Every missing label still needs a label-by-label disposition when its stage is
taken; this table must not be used to waive one.

### Runtime coverage lower bound

Only **4 of 41** scenarios are battle scenarios: `battle_intro`, `battle_menu`,
`battle_faint`, and `battle_blackout`. Their manifest `must_hit` lists contain
12 unique labels, of which `RunBattleTest` is port-only. Cross-checking the
remaining 11 against the compiled debug gates confirms direct calls or the
named faint chain:

`DisplayBattleMenu`, `ExecutePlayerMove`, `HandleEnemyMonFainted`,
`FaintEnemyPokemon`, `GainExperience`, `ExecuteEnemyMove`,
`HandlePlayerMonFainted`, `RemoveFaintedPlayerMon`,
`ReadPlayerMonCurHPAndStatus`, `AnyPartyAlive`, and `HandlePlayerBlackOut`.

Two stubs are additionally unavoidable before later observed landmarks:
`SlideDownFaintedMonPic` and `PrintEmptyString`. Thus **13 modeled pret battle
labels have direct or order-proven scenario execution evidence**. This is a
lower bound, not a claim that the other 667 labels do not execute: the manifest
does not instrument arbitrary callees, and static `not-proven-reached` cannot
prove a negative.

Both turn scenarios are synthetic entry gates. They preset the selected move
and call the execute/faint routines directly; neither drives `MainInBattleLoop`,
`SelectEnemyMove`, the in-battle ITEM/PKMN menus, trainer initialization, trainer
victory, or battle return. Most importantly, `battle_faint` deliberately uses a
guaranteed overkill and **does not compare the damage value** because the two
emulators have different RNG streams. It proves the turn/KO/EXP bookkeeping,
not numerical damage accuracy.

### The 13 stubs, settled against callers

| Group | Labels | Caller/coverage conclusion |
|---|---|---|
| animation (9) | four substitute/transform animations, four `Play*Animation*` dispatchers, `SlideDownFaintedMonPic` | `SlideDownFaintedMonPic` executes in both faint scenarios. The other eight have callers but no scenario proves their effect branches. Stage 6 owns them. |
| display state (1) | `PrintEmptyString` | Executes in `battle_faint` before the must-hit `GainExperience`; it is a live no-op stub, not dormant. |
| trainer presentation (1) | `SaveTrainerName` | Called only from trainer end-text flow; no trainer scenario proves it. Stage 1d owns it. |
| level-up mechanics (1) | `CalculateModifiedStats` | Indirectly called by `GainExperience` only when the active battler levels. `battle_faint` gains 102 EXP at level 80 and does not enter that branch. It is not on the ordinary damage path. |
| status-item mechanics (1) | `DoubleOrHalveSelectedStats` | Called after curing the active battler so selected Reflect/Light Screen stats can be restored. No in-battle ITEM route exists, so no scenario proves it. This is not the badge boost; the separately called `ApplyBadgeStatBoosts` is real and linked. |

The generated 13 also omit two convention debts: `CheckNumAttacksLeft` is a
bare `ret` inside `core.asm` but is classified `implementation`, and the
port-only `BattleItemMenu`/`BattlePartyMenu` names are adjacent ret-only helpers
rather than pret-labeled stubs. Stages 3a and 2a/2c already own those cases.

### Damage-path result and corrected over-claims

A recursive linked-call closure from `ExecutePlayerMove` reaches 62 translated
battle labels and three animation stubs; the enemy closure reaches 59 translated
labels and the same three animation stubs. Neither closure reaches
`CalculateModifiedStats` or `DoubleOrHalveSelectedStats`. This supports a
targeted completion strategy, not a battle-core rebuild, but it does **not**
validate arithmetic.

`faithdiff` is clean for `CriticalHitTest` and `HandleCounterMove`. The remaining
damage routines report conditional-jump lowering and explicit-store differences;
`EnemyCalcMoveDamage` also replaces pret's enemy-specific hit-test/level-swap
shape with shared `MoveHitTest` plus `GetDamageVarsForEnemyAttack`. Those are
review targets for a numerical oracle, not proof of a defect.

The explicit over-claim audit found and corrected current source comments that
still called `PrintGhostText`, `HandleCounterMove`, `MirrorMoveCopyMove`,
`MetronomePickMove`, `PrintCriticalOHKOText`, and `DisplayEffectiveness` stubs;
all six are linked implementations. The archived audit's trainer-AI and prize
money claims remain false: `SelectEnemyMove` calls
`AIEnemyTrainerChooseMoves`, and `AddBCD` has the payout callers. Neither has
trainer-scenario execution evidence.

### Sequencing decision produced by the survey

Do **not** rebuild battle core, and do not implement the two stat stubs merely to
make existing damage claims sound stronger: they are off the ordinary turn path.
First add a deterministic numerical damage oracle covering one non-KO player hit
and one non-KO enemy hit, including base formula, STAB/type, crit/no-crit and the
random factor without assuming shared RNG state. If that oracle passes, proceed
to Stage 1 trainer wiring and its win/loss/return scenarios. Stage 2c then makes
`DoubleOrHalveSelectedStats` observable; a deterministic active-battler level-up
scenario makes `CalculateModifiedStats` observable.

Survey-edit verification: `static_gate` passed all five checks and
`fidelity-full` passed 41/41 scenarios. `fidelity_gate` exited 1: its changed-file
selection expanded the comment-only edits in `core.asm` and `experience.asm` to
every pret label in those files, exposing their existing unsuppressed faithdiff
inventory. No instruction, label, call, or store changed in this survey commit;
the failed structural result remains recorded rather than reported as a pass.

### Numerical oracle result — 2026-08-03

`battle_damage` is now scenario 43 and the fifth battle scenario. Its mGBA side
drives real non-lethal turns until it observes a non-critical Pikachu
THUNDERSHOCK and a critical Pidgey SLASH. The port gate calls the corresponding
player/enemy numerical spines directly. Both stage the effective formula inputs;
`golden_diff.py` requires those inputs to match and validates each independently
against every legal Gen-1 random factor (217..255), so unrelated RNG streams are
not treated as equal-roll evidence.

Measured result: the player hit was mGBA 10 / DOS 12, both inside the legal
10..12 set; the enemy critical hit was mGBA 57 / DOS 60, both inside the legal
51..61 set. All inputs matched. `goldencheck SCENARIO=battle_damage` passed.
This clears the survey's sequencing gate: **Stage 1 trainer wiring is next**.

Verification: the four focused oracle tests pass, `static_gate` passes all five
checks with 42 scenarios consistent, and the 16-scenario core fidelity tier
passes. A second pristine-ROM generation reproduced both golden files byte for
byte. `fidelity_gate` reports no changed pret label definitions but exits 1 on
the then-standing `MapHeaderPointers` lint finding (cleared 2026-08-04,
719d997d — the tree now lints at zero). The broader `tools/tests` run is
not a clean project gate (31 passed / 14 existing failures: stale generator
paths, the same lint debt, and an older datastruct-description assertion).

## Stage 1 — make trainer battles live

Current evidence: `NewBattle` and guarded `StartTrainerBattle` both enter the
restored `InitBattle` dispatcher. `InitBattleCommon` calls the linked
`GetTrainerInformation`, `ReadTrainer`, and `_LoadTrainerPic` implementations,
then `_InitBattleCommon` selects the first enemy party mon. Scenario
`trainer_battle_init` proves that initialization state against a real Route 3
sight trainer. The paired `trainer_battle_win` / `trainer_battle_loss` scenarios
now prove terminal WRAM, event/script, prize/blackout, and return-state parity.
The production trainer handoff remains behind `TRAINER_BATTLE_LIVE` until the
continuous presentation/turn-loop/overworld choreography is exercised; the new
result gates deliberately stop after initialization and drive one terminal turn.

- [x] **1a. Trainer initialization.** Restore pret's wild/trainer split under
      `InitBattleCommon`/`InitWildBattle`/`_InitBattleCommon`; promote and call
      `GetTrainerInformation`, call `ReadTrainer`, load the trainer picture and
      first party mon, initialize trainer AI/battle state, and preserve the
      scripted-battle inputs. (Stale note removed 2026-08-07: the battle
      transition NOW EXISTS — Stage 5's first two boxes landed in 6a849f15.)

      Measured 2026-08-04: full-tier scenario 44 enters pret through Route 3's
      real `CheckFightingMapTrainers`/trainer-sight flow and enters the port
      through guarded `StartTrainerBattle`. Its 30-byte deterministic projection
      matches exactly: opponent/class/set, three-species roster and levels,
      active enemy selection, `$ff` AI reset, base/prize money, trainer battle
      kind, and trainer-name prefix. RNG-derived DVs/stats and presentation are
      explicitly outside this checkpoint. `label_status --callers` confirms the
      linked chain `StartTrainerBattle -> InitBattle -> InitBattleCommon ->
      {GetTrainerInformation, ReadTrainer, _LoadTrainerPic} ->
      _InitBattleCommon -> EnemySendOutFirstMon -> LoadEnemyMonFromParty`.
      The default build, `static_gate`, and all 43 `fidelity-full` scenarios
      pass; an independent mGBA rerun reproduced the 7,326-byte golden and its
      sidecar byte-for-byte at frame 5805. `fidelity_gate` exits 1 on the
      then-standing `MapHeaderPointers` lint finding (cleared 2026-08-04,
      719d997d) and the pre-existing
      unsuppressed inventories exposed by touching the large overworld/battle
      mirror files; that result is recorded, not reported as green.
- [x] **1b. Retire `TRAINER_BATTLE_LIVE`.** Exercise the trainer route under the
      guard, then remove the guard rather than leaving two build behaviors.
      Reconcile `StartTrainerBattle`/`EndTrainerBattle` and `wCurMapScript` with
      the overworld plan's script state machine. The earlier generator blocker
      was stale: `tools/generators/gen_trainer_headers.py` exists and emits the
      linked trainer-header tables. Re-measure the remaining
      `npc_beaten_flags`/`TrainerFlagAction` ownership before changing it.

      Measured 2026-08-04: the guarded result bridge now mirrors pret's outer
      `AllPokemonFainted` decision after `EndOfBattle`. A win runs
      `EndTrainerBattle`, sets Route 3 event bit 2, resets both script indices,
      awards `$000100`, and gives the active mon 112 EXP plus the exact five
      stat-EXP increments. A loss publishes `wIsInBattle=$ff`, runs
      `EndTrainerBattle` without setting the event, resets the scripts, then
      heals the party and halves `$999999` to `$499999`. What remains for 1b is
      the continuous guarded route through presentation and the turn loop,
      followed by removal of the compile-time guard. The default build,
      `static_gate`, all 45 `fidelity-full` scenarios, and `goldens-verify` pass.

      **Measured 2026-08-04 (second pass): 1b was never a guard deletion — it was
      a missing pret branch.** `grep wCurOpponent dos_port/src/home/overworld.asm`
      returned NOTHING: pret's battle-entry poll (`home/overworld.asm:65-67`,
      `ld a,[wCurOpponent] / and a / jp nz,.newBattle`, run immediately after
      `JoypadOverworld`'s `RunMapScript`) had never been ported. pret's
      `StartTrainerBattle` does **not** call `InitBattle` — it seeds
      `wCurOpponent` via `InitBattleEnemyParameters`, increments `wCurMapScript`
      and returns; the LOOP enters the battle. With no poll nothing could ever
      enter a trainer battle, so the port had made `StartTrainerBattle` call
      `InitBattle` + `FinalizeTrainerBattleOutcome` itself behind the guard —
      two calls pret does not make. Unguarding them would have cemented that
      divergence permanently instead of retiring it.

      Landed instead: the missing poll was ported into `OverworldLoop`
      (`src/home/overworld.asm`), both added calls were deleted from
      `StartTrainerBattle`, and the premature `call EndTrainerBattle` in
      `map_sprites.asm:TrainerEncounterFlow` was removed — post-battle cleanup
      now flows the pret way, through `wCurMapScript` → `RunMapScript` →
      `<Map>_ScriptPointers[2]` (`EndTrainerBattle` for every wired map;
      confirmed present for ROUTE_3 in the generated
      `assets/map_script_tables.inc`). `FinalizeTrainerBattleOutcome` survives
      only as the oracles' stand-in for the loop tail, since `OverworldLoop`'s
      own `.battleOccurred` (`AnyPartyAlive` → `AllPokemonFainted` →
      `HandleBlackOut`) was already a faithful port of the same pret logic.

      Evidence: `faithdiff StartTrainerBattle` reports
      `calls: 1 pret / 1 port (1 matched)` — previously 3 port calls with 2
      ADDED. Scenarios 44/45/46 (`trainer_battle_init` / `_win` / `_loss`) each
      still PASS against mGBA after the restructure, which is the load-bearing
      result rather than a regression tick: the roster species/levels and
      active-selection bytes they compare can only be populated by `InitBattle`
      → `ReadTrainer` → `EnemySendOutFirstMon`. `lint_pret_labels` and
      `--strict-claims` both stayed at 0 violations (the pre-work baseline was
      also 0/0, so any finding would have been this batch's).

      Annotation sweep in the same change: the `DEVIATION{class=temporary}`
      null-header skip inside `EndTrainerBattle` was **retired** — its premise
      ("TrainerEncounterFlow reaches EndTrainerBattle without calling
      `StoreTrainerHeaderPointer`") is false now that call is gone, and every
      remaining caller stores a non-null header first (map scripts via
      `ExecuteCurMapScriptInTable`, which also refuses to dispatch a map whose
      headers slot is 0; the `DEBUG_TRAINER_RESULT` oracle directly). pret's
      unconditional shape is restored. A NEW `DEVIATION{class=temporary}` at the
      `TrainerEncounterFlow` site records the converse residual: on an UNWIRED
      trainer map nothing now reaches `EndTrainerBattle`, leaving
      `BIT_PRINT_END_BATTLE_TEXT` and `wCurMapScript` set.

      **`TRAINER_BATTLE_LIVE` IS NOW FULLY GONE.** The three inert
      `-D TRAINER_BATTLE_LIVE` defines in `dos_port/Makefile`'s
      `DEBUG_TRAINER_{INIT,WIN,LOSS}` blocks were deleted once the
      overworld-events session released its claim on the Makefile. Nothing in
      `dos_port/{src,Makefile,tools}` references the macro except three
      past-tense comments describing its retirement. Re-verified after the
      deletion: default build 0, `trainer_battle_{init,win,loss}` all PASS
      again (their `NASMFLAGS` changed, so they were rebuilt and re-run), lint
      and `--strict-claims` both still 0.

      **TICKED 2026-08-05 (`fefdf0ab` + `ee5ba354`): the continuous scenario
      PASSES and is REGISTERED.**
      1. ~~No continuous overworld→battle→return scenario exists yet.~~
         `trainer_battle_route` (id 51) is green on master: the real
         `OverworldLoop` drives sight engagement → the `wCurOpponent` poll →
         live battle menus → `.battleOccurred` → `EnterMap` re-entry →
         `RunMapScript` idx 2 → `EndTrainerBattle` → persistent `$D7C2` bit 2
         SET, with the two zero-RNG reward bytes matching the golden. The
         blockers were HARNESS defects (two unguarded `EnterMap` seed hooks
         destroying the post-battle script state; a phase-lockable autokey
         cadence) plus the elided `EnemySendOutFirstMon` send-out tail — all
         fixed in `fefdf0ab`; full measurement trail in memory
         `regression-battle-trainer-post-battle-and-hud` (FIXED). 44/45/46
         remain synthetic oracle gates; id 51 is the live-path witness they
         structurally cannot be.
      2. `npc_beaten_flags` → `TrainerFlagAction` convergence is OWNED BY
         `docs/current_plan_overworld_events.md` (agreed by mail 2026-08-04, both
         roots) — not this plan's to close, and it is what retires the new
         `TrainerEncounterFlow` DEVIATION. That residual shrinks per wired map:
         on an unwired map `MapScriptPointers[wCurMap]` is the no-op
         `DefaultMapScript`, so the three-entry table is unreachable and
         post-battle cleanup cannot run. That residual shrinks with every map the
         overworld-events rollout wires, and with NO edit here — the gate's
         predicate is data-driven off the generated dispatch table.

         **Do not re-enumerate the wired set in this file.** The line that used to
         sit here ("WIRED_MAPS is ROUTE_3/6/11 plus ROUTE_4/8/9/10 … 7 of 17
         standard-shape maps, 10 still table-only") went false the moment the
         overworld-events batch `11126952` wired six more — which is precisely the
         hand-maintained-list failure mode that killed `TODO.md`. MEASURE it; the
         generated table is the authority:
             grep -c 'dd TrainerMapScript' dos_port/assets/map_scripts.inc
         Dated measurement, not a maintained list — at 2026-08-04 after
         `11126952`: 13 of 17 standard-shape maps wired. The bespoke hook is still
         ACTIVE on CERULEAN_CAVE_B1F, POWER_PLANT and VIRIDIAN_FOREST (the three
         interiors), on ROUTE_17 (wired then backed out, see
         `regression-overworld-forcebikedown-missing`), and on every non-standard
         map.
- [x] **1c. Victory-dependent trainer flags.** Move beaten/event writes to the
      verified post-victory result path. A loss, blackout, or aborted battle must
      leave the trainer armed; victory must advance the script, persist the flag,
      and expose the correct post-battle text. Depends on
      `docs/current_plan_overworld_events.md` populating `wToggleableObjectList`
      (`EndTrainerBattle`'s sprite-removal `DEVIATION{class=data-model}` cannot
      close until that builder exists).

      Proven by scenarios 45/46: the same generated Route 3 header is used on
      both sides; only the victory result sets its persistent bit. The loss path
      reaches the `$ff` early exit before `TrainerFlagAction`.
- [x] **1d. Trainer presentation and exit.** Generate class-specific end-battle
      streams (the `text_far`/`text_asm` continuation truncation is already
      retired — TX_ASM has real dispatch, TX_FAR its flat splice, and
      `_TrainerNameText` is generated Tier-1 in `assets/trainer_text.inc`; what
      remains is the per-header win/lose text data); restore
      trainer victory music, faint/send-out cries, waits, and screen restoration
      from pret. Resolve `PlayCry` by its real blocking contract rather than an
      audio-no-op assumption.

      **PARTIAL 2026-08-11 — three sub-items closed, and every one of them was
      blocked by a comment that measurement disproved.** Not ticked at that
      point: the per-header win/lose text data, the cries, and `PlayCry`'s
      blocking contract.

      **`PlayCry` AND THE CRIES CLOSED 2026-08-12.** `PlayCry` and `GetCryData`
      were both ret-only stubs in `home_stubs.asm`; their real bodies now live
      in the mirrored `src/home/pokemon.asm`. `faithdiff PlayCry` is
      `3/3 calls, 1/1 stores, clean`; `GetCryData` is `2/2 stores` with pret's
      `BankswitchHome`/`BankswitchBack` pair dropped under a
      `DEVIATION{class=banking}` (one flat address space, `CryData` is a linked
      program-image label). **The point was the blocking contract, and it is
      now real:** pret's `PlayCry` ends in `WaitForSoundToFinish`, so it blocks
      for the length of the cry, and a bare `ret` had been silently deleting
      that wait — the recorded live symptom (ledger M-32, observed 2026-07-13)
      was `UsedStrengthText` getting only `Delay3`'s three frames before the
      next message painted over it. Every faint and
      send-out cry site was already calling `PlayCry` faithfully, so those
      cries start sounding — and start waiting — with no further change.

      Retiring the stubs forced the convention sweep: 7 `stale_extern` comments
      still pointed at `home_stubs.asm` and 2 `STUB{}` annotations went
      malformed the moment the labels became `translated`
      (`pokedex.asm:390` for `GetCryData`, `evolution.asm:81` for `PlayCry` —
      the latter's own `lifetime` clause said "retire when `PlayCry` is
      translated"). All 9 fixed in the same change; both `lint_pret_labels`
      modes back to 0.

      **THE PER-HEADER WIN/LOSE TEXT DATA WAS ALREADY DONE — MEASURED
      2026-08-12, and 1d is ticked on that measurement.** This item survived on
      the plan because nobody had checked it. Two independent facts, not one
      aggregate:

      1. **Slot-for-slot agreement with pret, across every map.** pret's
         `trainer` macro (`macros/scripts/maps.asm:117`) emits
         `dw \3, \5, \4, \4` — before, after, end, end — so the win and lose
         pointers are deliberately THE SAME pointer, and the port's generated
         `assets/trainer_headers.inc` emits exactly that. Parsed both sides and
         compared view range plus all four pointers per header: **316 of 317
         pret headers present and 0 mismatched.**
      2. **Every one of those 1264 pointers resolves at link time**, which is a
         different claim from "the slots are right" — the build would fail on
         an undefined text label, and it does not.

      **The one exception is `ArticunoTrainerHeader`, and it is a generator
      CONTRACT gap, not a data error.** `gen_trainer_headers.py` anchors on a
      `<Map>TrainerHeaders:` label; `scripts/SeafoamIslandsB4F.asm` has none,
      because pret deliberately gives Articuno a bare `def_trainers 2` +
      `ArticunoTrainerHeader:` — its own comment explains why ("its sight range
      is 0, and trainer headers were not stored by
      `ExecuteCurMapScriptInTable`"). So the port emits no header for that map.
      **Latent, not live:** nothing in the port references
      `ArticunoTrainerHeader` today, and it only becomes a defect when Seafoam
      Islands B4F's script layer is ported. Recorded here rather than left to be
      rediscovered; the fix is to teach the generator the standalone
      `def_trainers`-anchored form (and collect that map's text streams with it).

      Related and now unblocked: the `.inc`'s own "TRUNCATED TAILS" inventory
      lists three wrappers whose `text_asm` tails are `call PlayCry / call
      WaitForSoundToFinish` (Mewtwo, Zapdos, Moltres). `PlayCry` became a real
      body on 2026-08-12, so those tails are implementable whenever their maps'
      script layers land.

      1. **`SaveTrainerName` stub RETIRED.** Its stated blocker — "needs the
         Tier-1 `TrainerNamePointers` name table, not yet generated" — was
         false: `assets/trainer_names.inc` already held all 47 names
         (`gen_trainer_names.py`) and `src/home/names2.asm` already bound that
         blob as name list 7 (`TRAINER_NAME`). Real body now in the mirrored
         `src/engine/battle/save_trainer_name.asm`; `faithdiff` 0 pret / 1 port
         (the `GetName` tail) under a `DEVIATION{class=data-model}` for the flat
         blob vs pret's pointer table.
      2. **`TrainerBattleVictory` RESTORED** — was `calls: 7 pret / 2 port`,
         now `7 / 7 (5 matched)`. Victory music (gym-leader / `RIVAL3` /
         `BIT_NO_MAP_MUSIC` branches), `TrainerDefeatedText`,
         `ScrollTrainerPicAfterBattle`, `DelayFrames 40` and
         `PrintEndBattleText` are all live. Its `TODO-HW` named three blockers
         and **two were false**: `PlayBattleVictoryMusic` is a translated
         routine in the same file, and `TrainerDefeatedText` IS generated
         (`assets/battle_text.inc:473`, which `core.asm` `%include`s). The two
         residual diffs are the port's standing conventions —
         `AddBCDPredef`→`AddBCD` (predef bank drop) and
         `PrintText`→`PrintBattleText` (battle-box projection).
         `PrintEndBattleText` had **zero port callers** before this; that is why
         retiring the `SaveTrainerName` stub alone changed no observable byte.
      3. **`HandlePlayerBlackOut` RESTORED** — was `calls: 6 pret / 1 port`
         (a three-line `ClearScreen`/`stc`/`ret` stand-in), now `6 / 6
         (5 matched)` with `stores: 1 / 1 matched`. The OPP_RIVAL1 screen wipe,
         pic scroll-in, `Rival1WinText`, the OAKS_LAB no-blackout early return,
         `SET_PAL_BATTLE_BLACK`, the link-vs-normal lose text and the
         `BIT_ALWAYS_ON_BIKE` clear are all live. Its `TODO-HW` claimed
         `SET_PAL_BATTLE_BLACK` and `PlayerBlackedOutText2` were unavailable;
         both existed (`engine/gfx/palettes.asm`, and battle_text.inc lines
         285/369/402).

      **New file:** `src/engine/battle/scroll_draw_trainer_pic.asm` —
      `_ScrollTrainerPicAfterBattle` + `DrawTrainerPicColumn`, the only pieces
      that were genuinely `missing`. Plus the `ScrollTrainerPicAfterBattle`
      `jpfar` thunk in `core.asm`. Both faithdiff clean.

      **Evidence class:** the two restored bodies' *presentation* calls sit
      inside the existing `%ifndef DEBUG_TRAINER_RESULT` guard (the state
      oracles have no input driver), so the trainer goldens are no-regression
      evidence, not execution evidence, for the text/scroll/wait steps. The
      control flow, the `wStatusFlags6` store and the palette command are
      ungated and DO run in `battle_blackout`. Witnessing the trainer
      presentation needs a scenario that samples the end-battle text moment —
      Stage 6's final box owns that.
- [x] **1f. Restore `SendOutMon`'s send-out sequence.** DONE 2026-08-11 (two
      commits: `AnimateSendingOutMon` ported, then the call graph restored).
      `faithdiff SendOutMon` is now `calls: 14 pret / 14 port (14 matched)`.
      Three callees land as annotated ret-stubs — `PrintSendOutMonMessage` and
      `StarterPikachuBattleEntranceAnimation` (`battle_stubs.asm`),
      `IsPlayerPikachuAsleepInParty` (new `src/engine/pikachu/pikachu_stubs.asm`)
      — so the SHAPE is pret's and the stubs are what remains to retire.

      **It did NOT close the palette family, and the reason is a separate
      defect — see 1g.** Measured: 11 battle-tier scenarios PASS, and their
      goldencheck output is BYTE-IDENTICAL to a stashed-baseline re-run
      (`battle_menu` / `battle_faint` / `trainer_battle_loss` diffed in full).
      Identical output means the restored code did not execute:
      `label_status --callers SendOutMon` reports ONE port caller,
      `ChooseNextMon`. So those 11 passes are no-regression evidence only.
- [x] **1g. Route the battle-entry send-out through `SendOutMon`.** DONE
      2026-08-11. **The truncation was in TWO places, and the second is why 1f
      looked like it did nothing.** Besides the production `_InitBattleCommon`,
      the `DEBUG_BATTLE_GOLDEN` gate in `src/debug/debug_dump.asm` does not call
      `_InitBattleCommon` at all — it hand-rebuilds the intro scene and ended its
      send-out at `LoadMonBackPic`, carrying its own copy of the same omission.
      So the scenario that was supposed to witness the fix contained the bug
      (`bug-class-false-witness-scenario`). Both sites now call `SendOutMon`.

      Measured result — the first execution evidence in this workstream:
      `battle_menu` and `move_selection` palette divergences **12 → 0**, and
      `battle_menu`'s `$80xx` VRAM mask hits **128 → 49**. TILEMAP, VRAM and WRAM
      stayed OK, so drawing both HUDs at send-out does not disturb the screen.

      It also exposed a real second defect, now fixed: `AnimationCleanOAM` left
      12 stale OAM entries (the POOF particles) in canonical `$FE00`. On the GB,
      `ClearSprites` zeroes `wShadowOAM` and the next VBlank DMA carries the
      zeros into `$FE00`; the port has no hardware DMA and `update_oam` skips the
      copy while `wUpdateSpritesEnabled` is `$FF`, as it is in battle. Rendering
      was unaffected (`spr_oam_valid` is zeroed), so only the compared bytes
      diverged. `AnimationCleanOAM` now republishes the cleared shadow, under a
      `DEVIATION{class=projection}` matching `DrawFrameBlock`'s.

      **One judgement call for maintainer review:** `trainer_battle_route` now
      needs a mask on the lead mon's PP. The send-out animation moves the port's
      RNG stream, so it took 4 turns where the golden took 3. This is the same
      class the scenario already declares (its `wLoadedMon` skip says the sides
      "fight the roster over a different number of RNG-dependent turns"), and the
      zero-RNG reward bytes still match, but it does retire the incidental
      move-selection witness the cadence used to give. Full reasoning is in the
      mask's own why-string.
- [~] **1g's original entry, kept as the record.** pret calls `SendOutMon` from THREE sites —
      `StartBattle` (core.asm:259, the initial send-out, immediately before
      `jr MainInBattleLoop`), `ChooseNextMon` (:1163) and `SwitchPlayerMon`
      (:2541). The port has only `ChooseNextMon`. `StartBattle` is `missing`:
      the port's `_InitBattleCommon` absorbed the wild/trainer orchestration and
      performs the initial send-out inline, so nothing reaches `SendOutMon` at
      battle start.

      That is what actually keeps `IO_OBP1` at 0 for the five battle
      checkpoints: hardware gets `$6C` from `SetAnimationPalette` via
      `StartBattle` → `SendOutMon` → `PlayMoveAnimation POOF_ANIM`. Closing this
      is what should retire the 12-divergence `OBJ pal4-7` signature in
      `battle_intro` / `battle_menu` / `move_selection` / `ball_catch` /
      `battle_damage`, and it is the acceptance test for this box — a passing
      suite alone is not, since the suite passed while the code was unreached.
      `SwitchPlayerMon` is Stage 2a's, not this box's.
      *What 1f looked like when it was opened, kept as the record of the defect
      and of one claim that turned out to be wrong.* It came from a measured
      palette-fidelity root cause, not from a survey. `faithdiff SendOutMon`
      reported `calls: 14 pret / 2 port (1 matched)`: 13 DROPPED
      (`PrintSendOutMonMessage`, `DrawEnemyHUDAndHPBar`, `DrawPlayerHUDAndHPBar`,
      `LoadMonBackPic`, `PlayMoveAnimation`, `AnimateSendingOutMon`,
      `IsThisPartyMonStarterPikachu`, `StarterPikachuBattleEntranceAnimation`,
      `IsPlayerPikachuAsleepInParty`, `PlayPikachuSoundClip`, `PlayCry`,
      `PrintEmptyString`, `SaveScreenTilesToBuffer1`), 1 ADDED (port-only
      `DrawHUDsAndHPBars`), plus dropped `[hStartTileID]` / `[hWhoseTurn]` /
      `[hAutoBGTransferEnabled]` stores and pret's enemy-HP-zero skip of the
      enemy HUD. `AnimateSendingOutMon` (pret `init_battle.asm:181`) and
      `StarterPikachuBattleEntranceAnimation` are both `missing`; everything
      else it needs is translated and linked.

      The in-source comment `; ANIMATION=OFF: PlayMoveAnimation(POOF_ANIM) /
      AnimateSendingOutMon / Pikachu.` is STALE — `PlayMoveAnimation` has been
      live since the battle-animations plan landed. Do not read it as a
      sanctioned deferral.

      Measured consequence: pret's `PlayMoveAnimation POOF_ANIM` reaches
      `SetAnimationPalette`, the ONLY writer of `rOBP1 = $6C`, so hardware holds
      `$6C` at the `battle_menu` / `battle_faint` / `battle_damage` /
      `move_selection` / `battle_blackout` checkpoints (each solves to that value
      UNIQUELY from its committed `cgb_palettes` golden) while the port holds 0.
      That is 12 palette divergences per scenario, all `OBJ pal4..7 colour1..3`.
      Decomposition and method: `docs/current_plan_palette_fidelity.md`.
      Restoring this should also RETIRE the battle goldens' 128-slot `$80xx`
      VRAM mask rather than needing a new one — check that when it lands.

      **CORRECTED 2026-08-11, same day, by the restoration itself.** The last two
      sentences above were wrong in their conclusion, though right about the
      mechanism: restoring `SendOutMon` changed NOTHING — `battle_menu` still
      reports the identical 12 divergences, the `$80xx` mask still hits 128
      times, and a stashed-baseline re-run diffed byte-identical. The missing
      link is 1g: the port's battle ENTRY never calls `SendOutMon`. Read the
      block above as the description of a real defect that was fixed, not as a
      prediction that came true.
- [~] **1e. AI execution leaves.** FIRST CLAUSE DONE 2026-08-11 (`b4cb88001`):
      `SwitchEnemyMon` restored through withdrawal and send-out — `faithdiff`
      4 pret / 4 port, 3 matched (was 1), stores 1/1 (was 0/1). It had been
      copying the withdrawn mon's HP back to the roster and then never sending
      the replacement out.

      **The blocker was a missing generated asset, not deferred UI work.**
      `AIBattleWithdrawText` did not exist in the port because
      `gen_battle_text.py`'s `BATTLE_SRC` never listed
      `engine/battle/trainer_ai.asm`. One line in the generator; it now emits the
      AI wrappers (133 -> 135 labels). **That also unblocks this box's SECOND
      clause** — `trainer_ai.asm:818`'s "Deferred UI: X used [wAIItem] on Z!
      (GetItemName + PrintText)" was waiting on the same asset.

      SECOND CLAUSE DONE 2026-08-11 too: `AIPrintItemUse_` (2/2, 1 matched —
      only the `PrintBattleText` wrapper) and `AIPrintItemUseAndUpdateHPBar`
      (3/3 matched, CLEAN) were both bare stubs under "Deferred UI ... Wave 2
      front-end". `GetItemName`, `UpdateHPBar2`, `PrintText` and
      `DecrementAICount` had all been linked for a long time; the only real
      blocker was the same missing generated asset (`AIBattleUseItemText`).
      `AIRecoverHP` already stages `wHPBarOldHP/NewHP/MaxHP`, matching pret, so
      only the coordinate and `wHPBarType` needed setting.

      WHAT THAT LEAVES: nothing in this box is unimplemented. It stays `[~]`
      SOLELY because none of it is witnessed — the restored switch
      is UNWITNESSED — 56/56 full tier passed byte-identical, because no scenario
      makes the AI choose to switch. Same gap as 3a/3b/3d
      (`battle-stage3-blocked-on-mechanics-scenarios`).
- [x] **1e (original entry).** Complete `SwitchEnemyMon` through withdrawal,
      `EnemySendOut`, and its return flags; complete AI item text/effect/HP-bar
      paths without duplicating item-owned player handlers.

      DONE 2026-08-12, structurally, with the evidence class stated below.
      * `SwitchEnemyMon` — `4/4 calls (3 matched), 1/1 stores`. Withdrawal via
        pret's own `CopyData` (a hand-rolled byte loop had been standing in),
        `AIBattleWithdrawText`, the `wFirstMonsNotOutYet` 1/0 abuse pret
        comments on, `EnemySendOut`, and the `LINK_STATE_BATTLING` CF=0 /
        CF=1 return contract. The one diff is the standing
        `PrintText`→`PrintBattleText` battle-box projection.
      * AI item paths — `AIPrintItemUseAndUpdateHPBar` 3/3 clean;
        `AIUseFullHeal` 3/3 clean; `AIUseSuperPotion` / `AIUsePotion` /
        `AIUseHyperPotion` / `AISwitchIfEnoughMons` clean; `AIPrintItemUse_`,
        `AIRecoverHP`, `AIUseFullRestore` and `AIIncreaseStat` match on calls
        with ADDED stores that are x86 lowering of pret's `ld hl`-indirect
        writes. No player item handler is duplicated: the AI path calls the
        shared `StatModifierUpEffect` and `UpdateHPBar2` rather than forking.
      * `AIPlayRestoringSFX` — was `ret` under "TODO-HW: audio HAL Phase 3.
        Stub no-op." **False blocker, and the fourth of its kind this week:**
        `PlaySoundWaitForCurrent` is a translated routine with ten other
        callers and `SFX_HEAL_AILMENT` is generated as `$8E`. Now
        `1/1 clean` — and, like `PlayCry`, the point is that
        `PlaySoundWaitForCurrent` BLOCKS, so the `ret` had been deleting a
        wait the item-use pacing depends on.
      * The file header's "per-trainer AI stubs — deferred UI paths" and
        "item/switch actions (UI stubbed)" claims are retired: measured, all
        eleven per-class bodies match pret's call graph exactly.

      **EVIDENCE CLASS: structural only.** No scenario in the 56-scenario
      registry fights a trainer that carries items (the only trainer scenarios
      are the Route 3 youngster), so the AI item and switch paths have zero
      execution evidence. That is a scenario debt, and Stage 2's scenario box
      is where it belongs.
- [x] Add deterministic trainer win and loss scenarios. Must-hit lists must name
      trainer initialization, party loading, battle entry, result handling, and
      the flag/script consumer. Compare party/enemy state, money, event/script
      state, and the rendered battle/exit surfaces; use a live sightline walk only
      for continuous choreography.

      Scenarios 45/46 use a live Route 3 sightline on pret and the guarded
      production initializer plus a deterministic final turn on the port. They
      compare WRAM state only; rendered battle/exit surfaces remain owned by 1d
      and the continuous 1b scenario rather than being claimed here.

## Stage 2 — complete the PKMN and ITEM battle subflows

Current evidence: `BattlePartyMenu` and `BattleItemMenu` are linked port-only
ret-only helpers, each called from `DisplayBattleMenu`. The items dispatcher and
effects they need are already translated. `DoUseNextMonDialogue` and
`ChooseNextMon` are linked partial implementations called from faint handling;
their current bodies auto-answer and auto-select.

- [ ] **2a. Voluntary switch.** Rename the port-only `BattlePartyMenu` to its
      pret counterpart — the TAIL of `PartyMenuOrRockOrRun` (pret
      engine/battle/core.asm:2409; the head, the dec-a run check, is already
      inline in `DisplayBattleMenu.partyMenuOrRun`) — then implement it with pret's
      `BATTLE_PARTY_MENU` mode, selection/cancel rules, withdrawal/send-out HUD
      work, party↔battle-mon synchronization, and the enemy's free turn.

      **DEPENDENCY SURVEY, measured 2026-08-12 — the box is NOT blocked, it is
      just large. 24 of its 28 callees already exist.** Do not re-derive this;
      re-measure it if it looks stale.

      Present and `translated`: `SaveScreenTilesToBuffer2`,
      `LoadScreenTilesFromBuffer1/2`, `DisplayPartyMenu`, `GoBackToPartyMenu`,
      `GBPalWhiteOut`, `GBPalNormal`, `LoadHudTilePatterns`,
      `RunDefaultPaletteCommand`, `DisplayTextBoxID`, `HandleMenuInput`,
      `PlaceUnfilledArrowMenuCursor`, `StatusScreen`, `StatusScreen2`,
      `AnimationSubstitute`, `AnimationMinimizeMon`, `GetMonHeader`,
      `LoadMonFrontSprite`, `HasMonFainted`, `AlreadyOutText`, `FlagAction`,
      `LoadBattleMonFromParty`, `SendOutMon`, `BattleMenu_RunWasSelected`,
      `FillMemory`, `ClearSprites`.

      **Missing, and this is the whole of the new-code cost:**
      1. `SwitchPlayerMon` (pret `core.asm:2521`, ~45 lines) — the fall-through
         target of `.switchMon`. Shared with 2b, so porting it serves both.
      2. `AnimateRetreatingPlayerMon` (pret `core.asm:1828`, ~30 lines) —
         starter-Pikachu branch, `ClearScreenArea`, `CopyDownscaledMonTiles`
         predef, `DelayFrames`.
      3. `RetreatMon` (pret `engine/battle/common_text.asm:183`) — two
         instructions, but its `PlayerMon2Text` carries a real `text_asm` tail
         that computes HP lost from `wLastSwitchInEnemyMonHP`. Tier-1 text +
         Tier-2 tail.
      4. `UseBagItem` — needed ONLY by the safari `SAFARI_ROCK` arm of
         `PartyMenuOrRockOrRun`. That arm belongs to **2c/4d**, not here; port
         the branch shape and let 2c supply the callee rather than inventing a
         stub for it.

      Naming: the port-only `BattlePartyMenu` in `battle_menu.asm` is a ret-only
      helper; it must be REPLACED by the pret label, not renamed in place, since
      the pret counterpart is the tail of `PartyMenuOrRockOrRun` in `core.asm`
      (the mirror rule puts the body in `src/engine/battle/core.asm`).

      Witness: nothing in the 56-scenario registry drives an in-battle party
      switch, so this box lands with zero execution evidence until the Stage 2
      scenario box below supplies one. Budget that scenario as part of 2a, not
      after it.
- [ ] **2b. Forced switch.** Replace the automatic Yes and first-live-mon paths
      in `DoUseNextMonDialogue`/`ChooseNextMon` with the faithful Yes/No and party
      menus, including wild-run behavior and the no-cancel forced selection.
- [ ] **2c. In-battle bag.** Rename the port-only `BattleItemMenu` to its pret
      counterpart `BagWasSelected` (pret engine/battle/core.asm:2270-2300,
      including the link-battle and safari-bait preamble), then implement it
      over the existing bag and
      `UseItem_` dispatcher. Preserve success/failure result codes, consumption,
      cancel behavior, and whether the enemy receives a turn. Do not fork item
      effects into battle code.
- [ ] Add separate must-hit scenarios for voluntary switch, forced switch, a
      successful medicine/battle-item use, a failed item, and ball capture entered
      through `BattleItemMenu`. The existing `party_menu`, `battle_menu`, and
      `ball_catch` scenarios do not prove these routes.

## Stage 3 — close backend and stub-era leaves

Re-derive each routine from pret at implementation time; do not carry the old
audit's finding status forward. Current generated/source evidence establishes the
provider shapes below, not their runtime behavior.

- [~] **3a. Multi-turn state.** `CheckNumAttacksLeft` TRANSLATED 2026-08-11; the
      rest of the box (verifying the full Bide/Thrash/trapping counter,
      accumulation, release and cleanup flow on both turns) is NOT done, so this
      stays `[~]`.

      The ret-only body carried the comment "No-op until the multi-turn move
      effects are wired." Measured: they ARE wired and linked — `TrappingEffect_`
      sets `USING_TRAPPING_MOVE` and seeds `wXxxNumAttacksLeft`
      (`effects.asm:1451-1480`), and the Bide, Thrash and multi-strike effects
      all write the same overloaded byte (`effects.asm:1000-1096`, `1238-1290`).
      So nothing on the ordinary turn path ever cleared the flag once set:
      Wrap/Bind/Fire Spin/Clamp would keep trapping past their 2-5 turns.

      Addresses checked against the checked-out ROM symbol file rather than the
      port header: `wPlayerNumAttacksLeft` `$D069`, `wEnemyNumAttacksLeft`
      `$D06E`, `wPlayerBattleStatus1` `$D061`, `wEnemyBattleStatus1` `$D066` —
      all four match `pokeyellow.sym`, and `USING_TRAPPING_MOVE` is bit 5 on
      both sides.

      `faithdiff CheckNumAttacksLeft`: 0 calls each side; the two ADDED stores
      are pret's `res USING_TRAPPING_MOVE, [hl]` writes through
      `ld hl, wXxxBattleStatus1`, which the faithfulness-review skill documents
      as surfacing this way (stores match by NAME, and pret's are
      pointer-indirect).

      **Unwitnessed, like 3b.** No scenario uses a multi-turn move, so the suite
      proves only that clearing an already-clear bit changes nothing. The
      remaining work — the counter/accumulation/release flow and its quirks —
      needs a deterministic Wrap or Bide scenario, and that is what would let
      this box be ticked.
- [ ] **3a (original entry).** Replace the linked ret-only
      `CheckNumAttacksLeft` body and verify the complete Bide/Thrash/trapping
      counter, accumulation, release, and cleanup flow on both turns. Preserve
      original-game quirks only when pret or the current bug reference supports
      them, with the required `BUG`/`GLITCH` tags.
- [~] **3b. Pay Day and end-of-battle money.** IMPLEMENTED 2026-08-11, NOT
      TICKED — the code is in, the acceptance evidence is not.

      The payout is now real in `EndOfBattle`: `AddBCD` (3-byte BCD, both
      pointers starting at their array's least-significant byte, exactly as
      pret's `HL`/`DE` do) into `wPlayerMoney`, then `PrintText
      PickUpPayDayMoneyText`. `faithdiff EndOfBattle` swaps `- DROPPED
      AddBCDPredef` for `+ ADDED AddBCD` under a `DEVIATION{class=HAL}` — the
      port's `AddBCDPredef` is `GetPredefRegisters` falling through to `AddBCD`,
      and there is no predef dispatcher staging the mailbox at this site, which
      is the convention `pay_day.asm` and `ReadTrainer` already follow.

      **All three of the old TODO-HW's deferral claims were false, each
      independently checkable in one command:** `AddBCDPredef` is `translated`
      (`src/engine/math/bcd.asm`), `PickUpPayDayMoneyText` IS generated
      (`assets/battle_text.inc:357`), and `PayDayEffect_` does accumulate into
      `wTotalPayDayMoney` (`move_effects/pay_day.asm:134`). The comment is
      deleted and replaced with the measurement.

      **WHAT IS OWED — a must-hit scenario.** No existing scenario can witness
      this: the branch is gated on `wTotalPayDayMoney != 0`, which is 0 in every
      scenario in the manifest, so the suite proves non-regression and nothing
      more. It needs a deterministic battle in which Pay Day is used and won,
      comparing `wPlayerMoney` (BCD) against the golden. Until that exists this
      box stays `[~]`. Do not read a green suite as evidence for it.

      One thing to check when that scenario is built: this branch now calls
      `PrintText` at battle exit. pret does the same, so it is faithful, but if
      the port's `PrintText` waits for a keypress there, an automated scenario
      reaching this path will stall — that is where to look first.
- [ ] **3b (original entry).** The move's accumulator is done and
      linked (`PayDayEffect_`, `move_effects/pay_day.asm`, `AddBCD` into
      `wTotalPayDayMoney`); complete the payout/text path in
      `end_of_battle.asm` (its `TODO-HW` still claims `AddBCDPredef` is unlinked
      and that the move cannot set `wTotalPayDayMoney` — both are now false; fix
      the comment in the same change) using big-endian/BCD conventions.
- [~] **3c. Battle draw and simultaneous-faint behavior.** RE-MEASURED
      2026-08-11, and the box's premise was mostly already satisfied.

      "Reconstruct the Self-Destruct/Explosion result and music selection from
      pret" — the reconstruction is ALREADY THERE and faithful. `FaintEnemyPokemon`
      carries pret's whole `.sfxplayed` block (`core.asm:808-815`): the
      player-HP test, the `wInHandlePlayerMonFainted` guard against calling
      `RemoveFaintedPlayerMon` twice, and the call itself. `RemoveFaintedPlayerMon`
      likewise has pret's early `ret` that suppresses the cry and the
      "<mon> fainted!" message when the enemy faint was detected first
      (`core.asm:1050-1052`). The wild victory jingle and `EndLowHealthAlarm` are
      wired. Do not re-derive these; read them.

      WHAT WAS ACTUALLY MISSING: pret documents a BUG at exactly this spot — the
      wild victory jingle starts BEFORE the player-HP check, so a simultaneous
      faint plays the win music for a battle the player did not win. It was
      untagged. Now `BUG{class=timing}` with a `BUG_FIX_LEVEL >= 2` correction
      that tests `wBattleMonHP` first (valid because
      `ReadPlayerMonCurHPAndStatus` runs at the top of `FaintEnemyPokemon`).

      Evidence the default path did not move: the default-build `PKMN.EXE` is
      BYTE-IDENTICAL with and without the change (sha256 `7559a45b…` both ways),
      while the `BUG_FIX_LEVEL=2` build differs (`f615ac29…`) — so the check is
      sensitive and the fix really is emitted at level 2. All three levels build.
      `faithdiff FaintEnemyPokemon` is unchanged by the edit.

      STILL OWED, which is why this is `[~]`: the must-hit scenario for the
      mutual-faint terminal state. Same bottleneck as 3a/3b — see stigmergy
      `battle-stage3-blocked-on-mechanics-scenarios`. The remaining trainer-faint
      SFX at `.sfxplayed` is a `TODO-HW` audio item (Phase 3), not this box.
- [ ] **3c (original entry).** Reconstruct the
      Self-Destruct/Explosion result and music selection from pret, then add a
      must-hit scenario for the mutual-faint terminal state.
- [~] **3d. Empty `battle_exp_stubs.asm`.** PARTIAL 2026-08-11: `PrintEmptyString`
      is RETIRED — real pret body (core.asm:6720) in the core.asm mirror, stub
      label removed, both extern comments repointed, `faithdiff` 1/1 with the
      documented `PrintText` -> `PrintBattleText` wrapper swap. 23/23 scenarios
      PASS, but that is NON-REGRESSION ONLY: the goldencheck output is
      byte-identical to the pre-change run. It IS executed (`battle_faint`
      must-hits `FaintEnemyPokemon`, whose call at core.asm:5924 is
      unconditional once `AnyPartyAlive` passes), but `battle_faint` is
      datastruct class so TILEMAP/VRAM/OAM are SKIPPED, and `battle_menu` dumps
      after `DisplayBattleMenu` has redrawn the box. Reachable is not witnessed.
      STILL OPEN: `CalculateModifiedStats`, `ModifyPikachuHappiness`, and
      `DoubleOrHalveSelectedStats` (blocked on 2c per this plan's ordering rule).
- [ ] **3d (original entry).** Implement and retire the battle-owned
      providers `PrintEmptyString`, `CalculateModifiedStats`, and
      `DoubleOrHalveSelectedStats`; implement `ModifyPikachuHappiness` at its
      pret-owned interface so the existing battle/item callers stop being inert.
      **Ordering constraint: `DoubleOrHalveSelectedStats` is blocked on item 2c** —
      it needs the in-battle ITEM menu (`BagWasSelected`/`BattleItemMenu`);
      until 2c lands, no item can be used mid-battle and this stays unreachable.
      `RespawnOverworldPikachu` stays in this item for now rather than
      transferring out; its in-tree TODO names the Yellow Pikachu-follow engine
      as its eventual home, and that transfer should happen after the 2a/2c
      pret-label rename lands, not before. Run `label_status --callers` and
      repair every stub-era extern/provider comment and assumption.
- [ ] **3e. EXP ALL.** Establish a deterministic whole-party EXP scenario before
      deciding whether any defect remains. Compare participants, EXP, levels,
      stats, moves, and `wIsInBattle`; do not preserve the old audit/repro claim
      without a current failing execution.

## Stage 4 — special battle types

- [ ] **4a. `BATTLE_TYPE_PIKACHU`.** Audit every pret branch and implement the
      starter-battle menu, ball refusal, initialization, loss/result, and
      happiness behavior. Overworld-events Stage 1 seeds `wCurOpponent`,
      `wBattleType`, and `wCurEnemyLevel`; its Oak milestone is incomplete until
      a must-hit battle scenario proves this handoff does not degrade to a plain
      wild battle.
      - PARTIAL (committed 5a768070, 2026-08-06): the special-battle slice is in
        and VERIFIED via headless GBSTATE probe — the Pallet intro Pikachu battle
        triggers, renders OAK's back pic vs Pikachu, captures on the scripted
        throw, and exits cleanly (`_InitBattleCommon` `.specialBattleIntro`/
        `.specialBattleLoop`, `LoadPlayerBackPic` wBattleType dispatch,
        `DisplayBattleMenu` `.doSimulatedMenuInput`, `BattleItemMenu` one-ball
        bag). Goldens battle_intro/battle_menu/overworld_pallet/sign_pallet PASS
        (wBattleType-gated, no normal-battle regression). Verify harness:
        `DEBUG_SEAM_KEEP_BATTLES=1 AUTOKEY_DUMP_ON_BATTLE=1` (gate dumps on
        `wCurOpponent`/`wBattleType`; boot-drift-robust).
      - STILL OPEN: (1) the must-hit Pikachu-battle golden scenario is not yet
        authored; (2) happiness init (`ModifyPikachuHappiness`) not audited;
        (3) DOWNSTREAM the post-battle `PLAYER_FOLLOWS_OAK` step STALLS — Oak's
        lead-to-lab movement never completes because the battle leaves the player
        at x=8 and `PalletMovementScript_OakMoveLeft` underflows
        `wXCoord - 10` to a 254-step walk. Root-caused in memory
        `regression-oak-intro-follow-stall-after-battle`. This is what still
        blocks the Oak intro from reaching the lab end-to-end.
- [ ] **4b. `BATTLE_TYPE_OLD_MAN`.** Implement the tutorial identity/menu and
      scripted throw behavior behind a deterministic battle scenario. The
      Viridian script and story reachability belong to overworld-events Stage 5.
- [ ] **4c. Ghost Marowak.** FOLDED IN 2026-08-11 from the archived animations
      plan (maintainer instruction), which had it as an optional tail explicitly
      deferred to this box: port `MarowakAnim` + `CopyMonPicFromBGToSpriteVRAM`
      (`engine/battle/ghost_marowak_anim.asm`). Measured today: `MarowakAnim` is
      `missing`, `IsGhostBattle` is `translated`. That plan declined to land it
      unilaterally because reachability is owned here, so it lands with 4c.
- [ ] **4c (original entry).** Starting from the linked `IsGhostBattle`, implement
      ghost initialization/identity, unidentified-ghost move refusal, escape
      rules, and the item-owned Poké Doll result consumer. Pokémon Tower/Silph
      Scope event reachability remains overworld-owned.
- [ ] **4d. Safari.** Implement the BAIT/ROCK/ball/run menu and the Safari turn/flee
      divergence using the already-translated item-owned `ItemUseBait`,
      `ItemUseRock`, and `ItemUseBall` effects. Safari maps, steps, and story
      entry/exit remain overworld-owned.
- [ ] Add one must-hit scenario per battle type, comparing the relevant menu,
      WRAM state, item/event result, and exit. Add live traversal only when its
      owning overworld story batch lands.

## Stage 5 — battle transitions

> Detail owner: `docs/plans/battle_transitions.md` (ARCHIVED 2026-08-07 — implemented and
> landed in 6a849f15; presolved 40×25 geometry, splice spec, and verification record). Only
> the third box below (per-transition state checkpoints) remains open, and it is owned HERE.

- [x] Port `GetBattleTransitionID_WildOrTrainer`,
      `GetBattleTransitionID_CompareLevels`, `_IsDungeonMap`, the
      `BattleTransitions` table, and all 8 animation bodies under their pret
      labels. DONE 2026-08-07 (6a849f15): `src/engine/battle/battle_transitions.asm`
      + `DoBattleTransitionAndInitBattleVariables` wrapper spliced at pret's two
      init_battle sites; maintainer visually approved all 8 via
      `DEBUG_TRANSITION_DEMO=1`; selection logic cross-checked vs reference
      video. Detail: the transitions plan + memory `battle-transitions-landed`.
- [x] Preserve and tag the documented scripted-battle transition bug from
      `docs/bugs_and_glitches.md` under the configured `BUG_FIX_LEVEL` policy.
      DONE 2026-08-07 (6a849f15): BUG{class=data-model} at
      `GetBattleTransitionID_CompareLevels` with a `BUG_FIX_LEVEL >= 2`
      wPartyCount bound.
- [ ] Add deterministic frame/state checkpoints for each selected transition and
      must-hit its selector plus animation body. Cover wild, trainer, dungeon,
      and scripted inputs; a final `FRAME.BIN` alone is regression evidence, not
      proof that the transition executed.

## Stage 6 — battle animations and battle-mask closure

> **SUPERSEDED 2026-08-11 — do not execute 6a-6d from here.** This stage was
> written before `docs/plans/battle_animations.md` existed; that plan took
> the work over and is 31 done / 2 open, with the MOVE animations
> maintainer-signed-off (stigmergy `battle-animations-plan-created`). Measured
> today, the routines 6c and 6d ask for are already `translated` and live:
> `PlayAnimation` (four callers, via `MoveAnimation` and `TossBallAnimation`),
> `MoveAnimation`, `AnimationShakeScreenVertically`. The boxes below are left
> unticked ONLY because they are not this plan's to tick — read them as pointers
> into the animations plan, and take the remaining work from there:
>
>   - 6a HAL design, 6b Tier-1 data, 6c interpreter, 6d shake/blink/flash —
>     delivered by `plans/battle_animations.md` Stages 1-5.
>   - 6e (retire the F-19 enemy-gauge masks) and the final animation-scenario box
>     are genuinely OPEN, and are the animations plan's Stage 6 / optional tail.
>
> **RECONCILED 2026-08-11.** `current_plan_battle_animations.md` is COMPLETE and
> ARCHIVED (maintainer instruction) at `docs/plans/battle_animations.md`, so the
> condition this banner waited on has happened. 6a-6d are ticked below against
> measured state, and the animations plan's two remaining opens were FOLDED IN
> here at the maintainer's direction: its optional Marowak tail into Stage 4c,
> and its animation-scenario spec into this stage's final box.


Current evidence: `PlayApplyingAttackAnimation` is linked, but the existing
ANIMATION=OFF path is the implemented behavior; `PredefShakeScreenHorizontally`
is a linked stub. The battle goldens intentionally mask animation/picture-bank
route differences. `golden_diff.py` also carries finding-owned F-19 masks for
enemy-gauge clone tile ids and VRAM slots.

- [x] **6a. HAL design.** Delivered by `docs/plans/battle_animations.md` (Stages 1-5). Document the battle-owned static OAM publication,
      scroll/shake, palette-flash, and VRAM-upload interfaces before translating
      the interpreter. Any move-animation tile upload must use `CopyVideoData` or
      arm `g_tilecache_dirty`.
- [x] **6b. Tier-1 animation data.** Delivered — `assets/battle_anim_data.inc` + `assets/battle_anim_constants.inc`, generated by `tools/generators/gen_battle_anim_data.py`. Generate subanimations, frame blocks,
      pointer/id tables, and move-animation graphics from pret. Keep interpreter
      and special-effect handlers hand-written Tier-2 code.
- [x] **6c. Interpreter.** Delivered and MEASURED 2026-08-11: `PlayAnimation` (`faithdiff` 7 pret / 7 port, 6 matched), `MoveAnimation` (7/7, ALL matched), `DrawFrameBlock`, `AnimationCleanOAM` and `PlayApplyingAttackAnimation` all `translated`. Port `PlayAnimation`, subanimation loading/transforms,
      frame-block drawing, OAM cleanup, and the battle-reachable special effects
      under their pret labels.
- [x] **6d. Shake, blink, flash, and options.** Delivered and MEASURED 2026-08-11: `AnimationShakeScreenVertically` translated, the shake stub RETIRED (`PredefShakeScreenHorizontally` is now `translated`, not `stub`), and the exact option gate is live at `src/engine/battle/animations.asm:570` (`test al, 1 << BIT_BATTLE_ANIMATION / jnz .animationsDisabled`) inside a `MoveAnimation` matching pret 7/7. Port the animation-type dispatch,
      shake/blink/palette commands, backend `wAnimationType` setup, and exact
      `BIT_BATTLE_ANIMATION` option gate; retire the shake stub. Preserve the
      current ANIMATION=OFF behavior as the option-off route, not as the engine.
- [ ] **6e. Retire F-19.** Remove the enemy-gauge clone-id divergence, restore
      canonical gauge tile identities, and delete every F-19-owned tilemap/VRAM
      mask. Do not close the finding while its masks remain.
      > **Report in from `plans/battle_animations.md` Stage 6 (2026-08-08),
      > as that plan's evaluate-and-report box requires — no mask was changed.**
      > The now-real Stage 4/5 animation route does **not** affect F-19. F-19
      > masks vFont `$C0-$C8` = `$8C00-$8C8F`; the animation route's complete VRAM
      > destination set is `$8310` (`LoadMoveAnimationTiles`), `$8000-$830F`
      > (`AnimationShakeEnemyHUD`), and `$9000` / `$9310` (the pic reloads).
      > No intersection, so retiring F-19 stays purely the per-cell-palette work
      > described above.
      > **One thing to carry into 6e's mask sweep, though:** the neighbouring
      > battle-intro mask over slots `$00-$30` is justified as "port `$80xx` is
      > undisplayed OBJ leftovers", and `AnimationShakeEnemyHUD` writes the back
      > pic into exactly slots 0-48. No scenario reaches the HUD shake today, so
      > the string is currently true — but it becomes false the moment a Stage 6
      > animation scenario exercises the shake. Re-measure it then rather than
      > carrying it forward.
- [ ] Add must-hit animation scenarios for representative physical, elemental,
      ball, shake/blink, and option-off paths. **SPEC FOLDED IN 2026-08-11 from
      the archived animations plan** (maintainer instruction), which tracked this
      same box: physical (Pound/Tackle), elemental flash (Thundershock), ball
      (TOSS_ANIM entered through the item path), shake/blink (`wAnimationType`),
      option-off (`BIT_BATTLE_ANIMATION` set). Ordered checkpoints — GBSTATE dumps
      at defined landmarks, not terminal-screen-only. Registration per the
      manifest / `validate_scenarios` chain, and each entry must state what path
      it actually ENTERS (false-witness rule).
      Its recorded reasoning for not starting stands: prerequisites are present
      (pinned golden worktree + built `mgba-lua-runner`), so it is a judgement
      call rather than a blocker — but these commit NEW GOLDEN ARTIFACTS, and a
      MID-ANIMATION landmark is strictly more timing-coupled than the post-flow
      WRAM instants `battle_faint` and `trainer_battle_route` already had to
      converge carefully. Compare ordered checkpoints rather
      than only the terminal screen; keep every remaining mask measured and
      justified.

## Stage 7 — retirement and archival

- [ ] Remove temporary guards and stand-ins whose real providers landed. Run
      `label_status --callers` for each retired stub, update the label DB, run
      default/strict label lint and `fidelity_gate`, and sweep related `STUB`,
      `TODO-HW`, extern-provider, allowlist, plan, skill, and stigmergy claims.
- [ ] Run targeted scenarios, the core tier, `fidelity-full`, and
      `goldens-verify` when scenario/golden artifacts changed. Close or transfer
      every battle-owned mask/finding with explicit evidence.
- [ ] Archive only when `project_state --plans` reports no open checklist items
      here and the default game can enter, play, and exit all in-scope battle
      types through their owning live routes.

## Fidelity and acceptance

The current manifest provides this battle-facing baseline:

| Scenario | Tier / class | Must-hit evidence | What it proves |
|---|---|---|---|
| `battle_intro` | full / default | `RunBattleTest` | deterministic synthetic wild intro/HUD state |
| `battle_menu` | core / default | `RunBattleTest`, `DisplayBattleMenu` | the normal action-menu surface, not PKMN/ITEM execution |
| `move_selection` | full / default | `RunBattleTest`, `MoveSelectionMenu` | the regular FIGHT move menu, not item type-2 or switching |
| `ball_catch` | full / datastruct | `RunBattleTest`, `UseItem` | capture WRAM outcome while bypassing `BattleItemMenu` |
| `battle_faint` | full / default | `RunBattleTest`, `ExecutePlayerMove`, `HandleEnemyMonFainted`, `FaintEnemyPokemon`, `GainExperience` | a resolved turn and an enemy KO with real EXP award; single-participant wild only |
| `battle_blackout` | full / default | `RunBattleTest`, `ExecuteEnemyMove`, `HandlePlayerMonFainted`, `RemoveFaintedPlayerMon`, `ReadPlayerMon` | the player-faint half through to black-out; deliberately avoids the party menu |

These scenarios do not prove trainer initialization, voluntary/forced switching,
the live in-battle bag, special battle types, transitions, animations, or normal
overworld result consumption.

For each remaining capability:

1. Establish current providers/callers with `project_state` and `label_status`,
   then inspect guards and indirect tables directly.
2. Run `fidelity_gate --base <base>` and review every ADDED/DROPPED call; record
   required justifications in the commit message.
3. Add or extend a deterministic scenario whose must-hit labels identify the
   changed dispatcher/state and downstream behavior. Compare WRAM and rendered
   surfaces according to what changed.
4. Run targeted `goldencheck`, the core tier, and `fidelity-full` for long-tail
   battle surfaces. Run `goldens-verify` whenever scenario or committed golden
   artifacts change.
5. Use live DOSBox-X only for continuous sightlines, choreography, and complete
   cross-system traversal that a deterministic dump cannot represent, and report
   that evidence as visually observed rather than golden-matched.
