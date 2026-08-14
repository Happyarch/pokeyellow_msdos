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
- [x] **1g's original entry — DONE 2026-08-12, acceptance test MEASURED and
      DECOMPOSED.** The premise below is now FALSE and is kept as the record.

      **THE PREMISE IS STALE.** It said "The port has only `ChooseNextMon`" and
      "nothing reaches `SendOutMon` at battle start". Measured today with
      `label_status --callers SendOutMon`: the port has FOUR callers —
      `ChooseNextMon` (core.asm:4938), `SwitchPlayerMon` (core.asm:3379),
      `_InitBattleCommon` (init_battle.asm:446) and the harness's
      `RunBattleTest`. The battle-start site landed in `145754975` and carries a
      `DEVIATION{class=projection}` at the call explaining that
      `_InitBattleCommon` collapses pret's `InitWildBattle` + `_InitBattleCommon`
      + `StartBattle`, so it holds `StartBattle`'s `call SendOutMon` inline.

      **THE ACCEPTANCE TEST, per scenario, from the 65-scenario `fidelity-full`
      run (65 PASS / 0 FAIL) — this is the decomposition the box demanded, not a
      suite-passed claim.** Note first that `golden_diff` prints a `PALETTE:`
      line ONLY when there is at least one divergence (`if pal_all:`), so
      "no PALETTE line" means ZERO. That is unambiguous here because
      `cgb_palettes` is emitted unconditionally on both sides
      (debug_dump.asm:806's shared region table; every golden carries it).

      | scenario | was (2026-08-11) | now | verdict |
      |---|---|---|---|
      | `battle_intro` | 12, OBJ pal4-7 | **0** | RETIRED |
      | `battle_menu` | 12 | **0** | RETIRED |
      | `move_selection` | 12 | **0** | RETIRED |
      | `battle_damage` | 12, OBJ pal4-7 | **8** | NOT this family — see below |
      | `ball_catch` | 12 | **12** | a DIFFERENT family, already decomposed |

      **`battle_damage`'s residue is a HARNESS ROUTE ASYMMETRY, not a port
      defect, and it is structurally unfixable in that scenario.** The signature
      changed shape, which is what gave it away: the port no longer shows white,
      it shows the RIGHT colours with indices 1 and 3 EXCHANGED
      (`OBJ pal4 colour1: rom=(3,3,3) port=(31,31,0)` against
      `colour3: rom=(31,31,0) port=(3,3,3)`, and the same for pal5-7). `(3,3,3)`
      is the darkest shade, so the ROM is mapping index 1 to it — that is
      `$6C` (`%01101100`), `SetAnimationPalette`'s value — while the port maps
      index 3 to it, i.e. `$E4`, the identity the send-out left. So the port
      simply never runs `SetAnimationPalette` here, and the reason is by design:
      the `DEBUG_BATTLE_DAMAGE` gate calls the numerical spine directly
      (`GetCurrentMove` → `GetDamageVarsForPlayerAttack` → `CalculateDamage` →
      `AdjustDamageForMoveType` → `RandomizeDamage`) and contains NO animation,
      palette, `SendOutMon`, `MainInBattleLoop` or `ExecutePlayerMove` call at
      all — grep-verified — precisely "so text and animation waits cannot
      dominate a headless arithmetic check". The golden reaches the same numbers
      through REAL TURNS, which animate. Two different routes, so the palette is
      a side effect of the road not taken. **It must NOT be masked** (masking is
      how this class hid for a week) and it cannot be fixed without defeating
      the gate's purpose; it belongs to the palette plan as a known
      route-asymmetry, and the OBP1 family's real witnesses are the three
      scenarios above, which are at 0.

      `ball_catch`'s 12 are `BG pal0-3 / OBJ pal0-7 colour3: rom=(16,31,4)
      port=(31,31,31)` — every palette's colour 3, BG included. Not OBJ pal4-7,
      not this box; the mis-grouping was already corrected in-tree on 2026-08-11.

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
- [x] **1e. AI execution leaves — CLOSED 2026-08-14 (`04adbf0cb`).** Both clauses
      were implemented since 2026-08-11; the box stayed `[~]` SOLELY for want of a
      witness, and `battle_ai_switch` (id 83) is it — the first scenario ever to
      reach `SwitchEnemyMon`. PASS, WRAM OK (25 regions, 1 skipped), registry 81,
      `fidelity-full` 81/81 nonzero=0.
      * **IT FOUND A REAL PRODUCTION DEFECT ON ITS FIRST GREEN RUN**
        (`8e373b8b7`): `LoadEnemyMonData` had `inc esi` between
        `test al, 1 << TRANSFORMED` and its `jnz`, and `inc` writes ZF. ESI is a
        WRAM address and never zero, so the branch was ALWAYS taken and EVERY
        enemy mon took its DVs from `wTransformedEnemyMonOriginalDVs` — zero in
        an ordinary battle, making both the trainer-fixed and wild-random DV
        paths unreachable. Fixed with the flag-neutral `lea esi, [esi + 1]`.
        Invisible to every other scenario because they all seed enemy DVs
        directly on both sides; it surfaced here because the compared mon is the
        REPLACEMENT the game itself loads. 9 -> 2 divergences, the 7 being the
        DV word, its five derived stats and the roster copy.
      * **The design, and the three things that had to be right:** pin
        `wTrainerClass = COOLTRAINER_F` per frame (the ONLY RNG-free route —
        pret commented out that class's `ret nc`); SEED `wEnemyMonHP` ONCE into
        `maxHP/10 <= HP < maxHP/5` and never touch it again (a per-frame pin
        stalls the flow silently, measured twice); and fire the seed on a STATE
        both sides reach identically (`wBattleMonSpecies` non-zero) rather than
        a frame count, because the two emulators' input cadences advance the
        battle at different rates.
      * **The landmark needed the ROSTER HP**, and the golden caught it:
        `partyPos in 1..5` alone does not tell a SWITCH from a FAINT. On a
        switch `SwitchEnemyMon` writes the withdrawn mon's HP back non-zero.
      * One mask added and justified: `wPlayerMapPos +1..+2` is
        `wCurrentTileBlockMapViewPointer`, which `init_battle.asm:315-319` saves
        and zeroes for the battle renderer and `:512` restores — this is the
        first scenario to dump MID-battle while comparing that region.
      * *(original entry)* FIRST CLAUSE DONE 2026-08-11 (`b4cb88001`):
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
      is UNWITNESSED — the full tier passes byte-identical because no scenario
      makes the AI choose to switch. Same gap 3a/3b/3d had, and all three of
      those are now closed by scenarios, so this is the last of that family.

      **NOT STARTED 2026-08-12, and the reason is the GOLDEN side, not the
      gate.** `tools/mgba_harness/lib/battle.lua` exposes `enter_wild` and
      nothing else — there is no trainer-battle entry helper. The only existing
      trainer entry is `trainer_battle_route`'s hard-won overworld cadence
      (`A, DOWN x3, A`, state-gated D-pad, no B; two unguarded EnterMap seed
      hooks had to be fixed to get it green — `fefdf0ab`,
      `battle-stage1b-continuous-scenario`). So this scenario needs a
      trainer-entry harness written from scratch or lifted from that cadence,
      which is a whole iteration on its own rather than a variation on
      `battle_wrap`'s template. Deliberately not begun half-way.

      **THE ROUTE TO A WITNESS IS MEASURED AND IT IS DETERMINISTIC — the next
      iteration does not need to re-derive it.**
      * `SwitchEnemyMon` has exactly ONE port caller: `AISwitchIfEnoughMons`
        (`trainer_ai.asm:990`, `jnc`). Its condition is arithmetic, not a roll:
        count unfainted mons in `wEnemyMon1HP` over `wEnemyPartyCount` entries,
        and `cp 2 / jp nc, SwitchEnemyMon` — **two or more unfainted enemy mons
        and it switches.**
      * THREE AI classes reach it, and **`JugglerAI` reaches it
        UNCONDITIONALLY** (`trainer_ai.asm:607`, a bare `jmp`). The other two —
        Cooltrainer-F (`:647`) and `AgathaAI` (`:754`) — gate on
        `AICheckIfHPBelowFraction` first.

      **⚠ THE TWO BULLETS ABOVE ARE WRONG, AND THEY ARE WRONG IN BOTH
      DIRECTIONS — MEASURED 2026-08-14. Do not build on them.** The class that
      is RNG-free is the one this note dismissed, and the class it promoted as
      "unconditional" is the one carrying the roll.
      * **`JugglerAI` IS ROLL-GATED.** Port `trainer_ai.asm:604-607` reads
        `cmp al, PERCENT_25 / jnc .done / jmp AISwitchIfEnoughMons`, and pret
        is identical (`cp 25 percent + 1 / ret nc / jp AISwitchIfEnoughMons`).
        Line 607 IS a bare `jmp` — but only because the two lines above it did
        the branching. Reading the jump without its guard is how this note came
        to claim there is "NO roll anywhere on the decision".
      * **`TrainerAI` ITSELF ENDS IN `call Random / jp hl`** (pret
        `trainer_ai.asm:325-326`), which is where that `A` comes from. Every AI
        class is entered with a fresh random byte, so "no roll on the decision"
        could not have been true of any of them without checking the entry gate.
      * **`CooltrainerFAI` IS THE RNG-FREE ONE, by a documented Gen-1 bug.**
        pret writes `cp 25 percent + 1` with the following `ret nc`
        **commented out** ("The intended 25% chance to consider switching will
        not apply"), so the compare result is discarded and the class always
        proceeds. The port preserves this faithfully and annotates it —
        `BUG{class=data-model}` at `trainer_ai.asm:633`, `; jnc .done <-- 
        intentionally omitted`. Surveyed all 18 AI classes: it is the ONLY one
        whose entry is not `cp <threshold> / ret nc` (`GenericAI` just returns).
      * **So the deterministic route is COOLTRAINER_F, and its gate is PINNABLE
        STATE rather than a roll.** After the discarded compare it runs
        `ld a, 10 / AICheckIfHPBelowFraction / jp c, AIUseHyperPotion` and then
        `ld a, 5 / AICheckIfHPBelowFraction / ret nc / jp AISwitchIfEnoughMons`.
        `AICheckIfHPBelowFraction` divides `wEnemyMonMaxHP` by A and compares
        `wEnemyMonHP` against the quotient (port `:787-805`), so the switch
        needs enemy HP in the band **maxHP/10 <= HP < maxHP/5** — below 1/5 so
        the second check carries, but NOT below 1/10 or it reaches for a Hyper
        Potion instead. That is exactly the kind of pin `battle_low_hp` already
        does on the player side, and it costs no RNG alignment.
      * **ALL THREE OPEN QUESTIONS ARE NOW MEASURED — 2026-08-14. The design is
        BUILD-READY; the next iteration should not re-derive any of it.**
        1. **`wAICount` needs NO pin — it resolves itself.** `EnemySendOutFirstMon`
           sets `wAICount = $FF` (pret `core.asm:1346`, port
           `core.asm:5409`), and `$FF` is a SENTINEL, not a count: `TrainerAI`
           does `ld a,[wAICount] / and a / jr z,.done / inc hl / inc a /
           jr nz,.getpointer`, so `$FF+1 = 0` falls through to
           `dec hl / ld a,[hli] / ld [wAICount],a` — it loads the count from the
           CLASS TABLE. `data/trainers/ai_pointers.asm:38` is
           `dbw 1, CooltrainerFAI`, so pinning `wTrainerClass = COOLTRAINER_F`
           ($20) makes `wAICount` become 1 by itself. **Pin the class only.**
        2. **The trainer already has enough mons.** The sight trainer
           `trainer_battle_route` engages is Route 3's
           `object_event 10, 6, ... OPP_BUG_CATCHER, 4` (the scenario stands at
           `SIGHT_Y 6, SIGHT_X 12`, same row, trainer facing RIGHT). Bug Catcher
           party **4** is `db 10, CATERPIE, WEEDLE, CATERPIE, 0` —
           **three mons at L10**, comfortably over `AISwitchIfEnoughMons`'
           `cp 2`. Pinning `wTrainerClass` changes only the AI dispatch;
           `ReadTrainer` has already loaded the real roster.
        3. **`AIUseHyperPotion` is unreachable on this route, so its
           no-items behaviour is moot.** It sits behind
           `ld a, 10 / AICheckIfHPBelowFraction / jp c`, and the pin keeps HP at
           or above `maxHP/10`, so that branch is never taken.
      * **THE PIN, stated exactly.** `AICheckIfHPBelowFraction` divides
        `wEnemyMonMaxHP` by A and carries when `wEnemyMonHP` is BELOW the
        quotient, so the switch needs

              maxHP/10  <=  wEnemyMonHP  <  maxHP/5

        Both sides must COMPUTE it from the `wEnemyMonMaxHP` they read rather
        than hardcoding a number — the band is only a few HP wide at L10 — and
        both must assert the computed value satisfies both inequalities before
        proceeding, so a staging drift fails loudly instead of quietly missing
        the band in one direction.
      * **SHAPE: a variant of `trainer_battle_route` (51), not a new entry.**
        That scenario already walks a real new game to Route 3, takes the sight
        trainer through `StartTrainerBattle`, and fights the battle through the
        real `MainInBattleLoop` — which is where `TrainerAI` is called from
        (port `core.asm:450` and `:485`). The variant adds two per-frame pins
        during the battle and a different dump landmark.
      * **This also changes the harness bill, downward.** The box below says a
        witness needs a trainer-entry helper written from scratch because
        `battle.lua` exposes only `enter_wild`. But `wTrainerClass` is a pinnable
        byte like `wBattleType`, and `trainer_battle_init` / `trainer_battle_route`
        already reach a REAL trainer battle through the Route 3 sight script —
        so the roster comes from real trainer data and no enemy-party seeder is
        needed. **What still must be checked before building:** `TrainerAI`
        requires `wAICount != 0`, and that byte is loaded from the ORIGINAL
        class in `ReadTrainer`, so pinning `wTrainerClass` alone may leave it
        zero; pin both, on both sides. Also confirm the chosen Route 3 trainer
        has two or more unfainted mons, since `AISwitchIfEnoughMons` needs
        `cp 2 / jp nc`.
      * `TrainerAI`'s INVOCATION is not random-gated either (pret
        trainer_ai.asm:290-318): it needs `wIsInBattle == 2`, not a link battle,
        the enemy not locked (CHARGING_UP / THRASHING_ABOUT / STORING_ENERGY /
        USING_RAGE) and `wAICount != 0`, then dispatches on `wTrainerClass`.
      So: **trainer class JUGGLER + `wAICount != 0` + an enemy party with two
      unfainted mons ⇒ `SwitchEnemyMon` runs, with NO roll anywhere on the
      decision.** That is the same class of deterministic setup `battle_wrap` /
      `battle_bide` / `battle_thrash` use, so the gate can follow their shape
      (`jmp MainInBattleLoop`, pins in `AutoKeyDrive`, latch + dump).
      What still needs deciding when it is built: the compared landmark. The
      obvious one is `wEnemyMonPartyPos` changing together with the withdrawn
      mon's HP appearing in its roster slot — that pair is exactly what the
      2026-08-11 defect got wrong (it wrote the roster back and never sent the
      replacement out), so it is the pair that must be able to move.
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

- [x] **2a. Voluntary switch.** Rename the port-only `BattlePartyMenu` to its
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

      **DONE 2026-08-12, in two commits (72011a746 the callees, then the menu
      body).** `PartyMenuOrRockOrRun` is `24/24 calls (23 matched)` and
      `9/9 pret stores matched`.

      * The forked name is GONE, not renamed. `BattlePartyMenu` was a port-only
        ret-only helper standing in for a pret routine; renaming it would have
        parked a pret label in `battle_menu.asm` when the mirror rule puts the
        body in `core.asm`. `DisplayBattleMenu.partyMenuOrRun` now tail-jumps to
        `PartyMenuOrRockOrRun` exactly as pret's `jp` does, so the `dec a` run
        check sits at the routine's head where pret keeps it — the plan's
        "already inline in DisplayBattleMenu" note described the old split and
        no longer applies.
      * Two annotated deviations, both standing conventions: `class=projection`
        for the deselect wipe (`BCOORD(11, 11)`, and pret's own
        `6 * SCREEN_WIDTH + 9` carrying the port's 40-wide canvas), and
        `class=banking` for the two `StatusScreen` predefs being direct calls
        and pret's `Bankswitch` becoming the indirect `call esi` — which is the
        single unsuppressed ADDED call.
      * The 6 ADDED stores are an extraction asymmetry, not a divergence: pret
        writes the menu block through an `ld hl, wTopMenuItemY` + `ld [hli], a`
        walk that faithdiff cannot attribute to names, while the port writes
        `wTopMenuItemY/X`, `wCurrentMenuItem`, `wMaxMenuItem`,
        `wMenuWatchedKeys` and `wLastMenuItem` by name. Same class as
        `PlayerMon2Text`'s `hMultiplicand`.
      * `UseBagItem` is a declared `STUB{class=stub}` in `battle_stubs.asm`, so
        the safari `SAFARI_ROCK` arm keeps pret's shape while 2c owns the body.
        That arm is unreachable today for a second, independent reason: nothing
        enters a `BATTLE_TYPE_SAFARI` battle.
      * Supporting fix: `EnemySendOutFirstMon` had DROPPED both
        `wLastSwitchInEnemyMonHP` stores (pret core.asm:1398-1402). Restored —
        it is the baseline `PlayerMon2Text` subtracts from, so without it the
        switch-out line was chosen from whatever WRAM held. pret's second write
        site is inside `PrintSendOutMonMessage`, which is still a stub.

      **EVIDENCE CLASS — UPGRADED 2026-08-12 (`fb58e5ea6`).** It is no longer
      zero. The `DEBUG_BATTLE_SWITCH` viewer gate drives the production
      `DisplayBattleMenu` through PKMN → slot 1 → SWITCH, and the flow is proven
      to run, decomposed rather than asserted:

      * `wBattleMon` species `$90` / `wBattleMonNick` = PERSIAN — party slot 1 —
        where the scene had sent out slot 0 (`$84` / SNORLAX). So
        `PartyMenuOrRockOrRun` → `.switchMon` → `SwitchPlayerMon` →
        `LoadBattleMonFromParty` → `SendOutMon` all execute.
      * **The probe discriminates.** A control run pressing B instead of A at
        the SWITCH box leaves `wBattleMon` at `$84` / SNORLAX, so it would have
        reported the broken input.
      * `W_TILEMAP` at the dump holds the battle screen with PERSIAN L80 210/210
        in the HUD **and the dialog "SNORLAX good. / Come back"** — which is
        `PlayerMon2Text`'s outcome selector picking GoodText → ComeBackText.
        That is execution evidence for the 2a switch-out TEXT chain too, not
        just the switch.

      **RE-CLOSED 2026-08-12 after the visual half was fixed or filed.** Of the
      five defects the maintainer found by playing it: the battle screen not
      returning is FIXED (`55d9d45b8`), the stray switch-out message is FIXED
      (`65aa5a233`), the HP-bar colours and the invisible SWITCH/STATS/CANCEL
      box are FILED as backlog items 10b and 10c with `DEVIATION` markers at
      their call sites, and the player-palette report does not reproduce in any
      headless gate (`battle_intro` has ZERO palette divergences against the
      golden and renders Red correctly), so it needs a precise repro before it
      can be chased. The original reopening note follows.

      **WAS REOPENED (`[~]`, visual half only) — MAINTAINER-OBSERVED IN
      REAL GAMEPLAY.** The switch is structurally faithful (24/24) and the game
      state is correct, but the SCREEN is not. Playing
      `dos_port/run TRAINER_ROUTE_PILOT=1` and switching shows: HP bars red at
      full health, the SWITCH/STATS/CANCEL box not drawn at all (though it still
      responds to A), a corrupt party menu, the player sprite wearing the
      incoming mon's palette, and the battle screen never returning.

      **The lesson for this plan: `faithdiff` clean is not "works" for any
      screen the port draws differently from pret.** The party menu is one —
      pret's is a plain tilemap; the port's uses a window overlay, a
      `GB_TILEMAP1` mirror and OBJ icon tiles. 2a added the second-ever caller
      of it and reproduced only pret's calls.

      One symptom is root-caused and it is NOT a quick fix: the per-mon HP-bar
      colour is computed correctly and `RunPaletteCommand
      SET_PAL_PARTY_MENU_HP_BARS` IS issued, but `_RunPaletteCommand` drops that
      id (`ja .done`, "no port handler"). Writing the handler is necessary but
      insufficient — pret colours each row through a BLK packet that CGB really
      does consume (`SendSGBPackets` runs BOTH packets through
      `InitCGBPalettes`), while the port's palette HAL is per-TILE-ID
      (`tile_pal`) and all six bars share the same tile ids. The existing
      precedent for solving exactly this is `DuplicateEnemyHPBarTiles`, which
      already gives the battle's enemy gauge its own palette-able ids. Budget it
      as a HAL task. Full detail, plus the eliminations, in
      `regression-battle-party-menu-graphics-not-set-up`.

      It is still not a registered golden (no manifest entry, no mGBA side) —
      that remains the Stage 2 scenario box's job. And the gate immediately
      surfaced an open render-layer defect: see
      `regression-battle-switch-screen-stuck-on-party-menu`. WRAM and the
      tilemap are both correct; only the composited frame is wrong, so a
      datastruct-class golden would pass over it.
- [x] **2b. Forced switch.** Replace the automatic Yes and first-live-mon paths
      in `DoUseNextMonDialogue`/`ChooseNextMon` with the faithful Yes/No and party
      menus, including wild-run behavior and the no-cancel forced selection.

      **DONE 2026-08-12.** `DoUseNextMonDialogue` was `5 pret / 2 port` and is
      now **clean 5/5 calls, 1/1 stores**; `ChooseNextMon` was `13 / 3` and is
      now **13/13 (12 matched), 3/3 stores**, its one diff the annotated
      `FlagActionPredef` → `FlagAction` convention.

      * The wild "Use next Pokémon?" `TWO_OPTION_MENU` box is real, and NO now
        runs. Its position carries a `DEVIATION{class=projection}` for
        `BCOORD(13, 9)`.
      * The auto-select scan loop is gone. `ChooseNextMon` runs pret's
        `DisplayPartyMenu` in `BATTLE_PARTY_MENU` mode. **No-cancel is
        structural, not a flag:** pret loops back to `GoBackToPartyMenu` on
        both a cancelled menu (CF=1) and a fainted pick, so the only exit is a
        live mon. The picker it had been standing in for was linked all along —
        the deferral was the interactive UI, which 2a proved works.

      **A LATENT DIVERGENCE HAD TO BE FIXED FIRST, and it is the interesting
      part of this box.** pret's `TryRunningFromBattle` reads the player speed
      through `hl` and the enemy speed through `de`, both supplied by the
      caller — and its two callers pass DIFFERENT things:
      `BattleMenu_RunWasSelected` passes `wBattleMonSpeed`, while
      `DoUseNextMonDialogue`'s NO arm passes **`wPartyMon1Speed`**, because the
      battle mon has just fainted. The port had hardcoded `wBattleMonSpeed`,
      which is correct for the caller that existed and wrong for the one this
      box adds. The routine now honours the pointers (ESI/EDX) and both call
      sites set them; `label_status --callers` confirms there are exactly two
      and no third entry path. Had this not been caught, 2b would have shipped
      a run-odds bug that no scenario could see.

      Also added: `wPartyMon1Speed` (`wPartyMon1 + MON_SPD`), and a declared
      `STUB{class=stub}` for `LinkBattleExchangeData` so `ChooseNextMon` keeps
      pret's link branch. That branch is unreachable in this port for a
      structural reason, not a lucky one: there is no serial HAL, and nothing
      ever writes `LINK_STATE_BATTLING`.

      **EVIDENCE CLASS.** Both routines sit on the live faint path, but no
      scenario reaches them: `battle_faint` kills the ENEMY, and
      `battle_blackout` deliberately leaves exactly one mon alive so the
      black-out branch is taken instead — its header says so outright. So this
      box lands with **zero execution evidence**, same as 2a, and the Stage 2
      scenario box owns the debt for both.

      Left open deliberately: `TryRunningFromBattle` still drops
      `IsGhostBattle`, `LinkBattleExchangeData`, `LoadScreenTilesFromBuffer1`
      and `PrintText` (11 pret / 7 port). Those predate this box and belong to
      4c (ghost) and the run-message work, not here.
- [x] **2c. In-battle bag.** Rename the port-only `BattleItemMenu` to its pret
      counterpart `BagWasSelected` (pret engine/battle/core.asm:2270-2300,
      including the link-battle and safari-bait preamble), then implement it
      over the existing bag and
      `UseItem_` dispatcher. Preserve success/failure result codes, consumption,
      cancel behavior, and whether the enemy receives a turn. Do not fork item
      effects into battle code.

      **DEPENDENCY SURVEY, measured 2026-08-12 — this is mostly WIRING, not
      building.** 13 of 17 callees already exist; the whole backend is there.

      Present and `translated`: `DisplayListMenuID` (the bag list UI itself),
      `UseItem`, `UseItem_`, `GetItemName`, `CopyToStringBuffer`,
      `DrawHUDsAndHPBars`, `SaveScreenTilesToBuffer2`,
      `LoadScreenTilesFromBuffer1`, `LoadHudTilePatterns`, `ClearSprites`,
      `Delay3`, `GBPalNormal`, `ItemsCantBeUsedHereText`. Every WRAM symbol the
      flow needs is declared (`wListPointer`, `wPrintItemPrices`, `wListMenuID`,
      `wBagSavedMenuItem`, `wMenuWatchMovingOutOfBounds`, `wPseudoItemID`,
      `wCapturedMonSpecies`, `wNumBagItems`), as are `ITEMLISTMENU`,
      `BATTLE_TYPE_OLD_MAN` and `BATTLE_TYPE_PIKACHU`.

      **Missing — the whole new-code cost:**
      1. `BagWasSelected` (pret `core.asm:2292`), `DisplayPlayerBag` and
         `DisplayBagMenu` — three short routines, plus the link-battle and
         safari-bait preamble above them.
      2. `UseBagItem` — currently the `STUB{class=stub}` added by 2a so the
         safari arm could keep pret's shape. **2c retires it**; pret's body is
         at `core.asm:2344`.
      3. `SAFARI_BAIT` — one constant, `= BOULDERBADGE = $15`
         (`constants/item_constants.asm:32`), the same deliberate overload as
         `SAFARI_ROCK = CASCADEBADGE = $16` already added.
      4. `SimulatedInputBattleItemList` — a 4-byte data table.
      Plus: DELETE the port-only `BattleItemMenu`, exactly as 2a deleted
      `BattlePartyMenu` — do not rename it, since pret's body belongs in
      `core.asm` under the mirror rule.

      **⚠ 2c WALKS INTO THE SAME TRAP 2a DID — budget for it up front.** The
      bag/list menu is another screen-takeover: `list_draw_box_border`
      (`src/home/list_menu.asm`) calls `hide_window` and then `add_window`, and
      `town_map.asm:477` clears `g_bg_whiteout` with the comment "the bag menu
      may have set it". So the battle caller owes the SAME THREE port-only
      obligations on every exit that 2a had to learn the hard way:
      `g_window_count = 0`, `g_bg_whiteout = 0` (these two are a pair — clearing
      windows alone is inert), and re-assert `text_msgbox = msgbox_centered`.
      None of that is visible to `faithdiff`, which stayed at 24/24 across both
      of 2a's fixes because all three are port memory. Verify 2c with a rendered
      frame, not just the gates.

      **DONE 2026-08-12.** `BagWasSelected`, `DisplayPlayerBag`, `DisplayBagMenu`
      and `UseBagItem` are ported into the mirror; the port-only
      `BattleItemMenu` is DELETED and the `UseBagItem` stub 2a added is RETIRED.
      The tutorial presentation survives as the descriptively-named port-only
      `ShowSimulatedInputBagBox`, which claims no pret label.

      * `DisplayPlayerBag` clean; `DisplayBagMenu` 6/6 stores;
        `UseBagItem` 10/10 calls matched. The ADDED entries are the port-only
        `RestoreBattleScreenState` and the x86 lowering of pret's
        `ld hl`-indirect writes to `wPlayerBattleStatus1` /
        `wPlayerNumAttacksLeft`.
      * pret's fall-through is restored: the ITEM slot no longer `call`s a
        helper and re-dispatches on CF — the flow's own `ret` in `UseBagItem`
        IS `DisplayBattleMenu`'s return, as pret intends.
      * Item effects are NOT forked: this calls the same `UseItem` the overworld
        bag uses.

      **The warning above paid off twice.** First, `RestoreBattleScreenState`
      applies the three obligations on every exit. Second — and only a rendered
      frame showed it — the bag initially drew TWICE, once on the canvas and
      once through the list menu's own window descriptors, because the battle
      canvas is composited while the overworld's is not. Fixed by raising
      `g_bg_whiteout` for the duration of the list, which is what every other
      in-game list-menu owner does (`bills_pc.asm:308`). Verified by frame: one
      clean list, cursor on POTION, real bag contents.

      Two constraints found and recorded: `wListPointer` is a **16-bit GB
      address** in this port, so pret's flat `SimulatedInputBattleItemList`
      cannot be stored in it without staging a copy into GB memory — hence the
      `class=data-model` deviation and 4b owning the real list. And
      `SAFARI_BAIT` = `BOULDERBADGE` = `$15`, the same deliberate overload as
      `SAFARI_ROCK`.
- [x] Add separate must-hit scenarios for voluntary switch, forced switch, a
      successful medicine/battle-item use, a failed item, and ball capture entered
      through `BattleItemMenu`. The existing `party_menu`, `battle_menu`, and
      `ball_catch` scenarios do not prove these routes.

      **1 of 5 DONE 2026-08-12: `battle_switch` (scenario id 59) is in the
      registry and PASSES.** The voluntary switch is no longer unwitnessed. The
      registry is 57 scenarios, all 57 pass, and `WRAM: OK (13 regions, 0
      skipped)` for this one — the port's switch produces byte-identical game
      data to the real Game Boy.

      *What it drives, on both sides:* `RIGHT` then `A` into the real 2x2 battle
      menu (PKMN), `DOWN` then `A` in the real party menu (slot 1, PERSIAN L80),
      `A` on SWITCH. Neither side calls `SwitchPlayerMon`. `PartyMenuOrRockOrRun`,
      `SwitchPlayerMon`, `RetreatMon` and `AnimateRetreatingPlayerMon` execute
      here and nowhere else in the registry.

      *Dump point, and it is exact on both sides:* `wCurrentMenuItem == 2` while
      `wPlayerMonNumber == 1` — `SwitchPlayerMon`'s closing store (pret
      core.asm:2549-2551), which is reached only after `RetreatMon`, the 50-frame
      wait, `AnimateRetreatingPlayerMon`, `LoadBattleMonFromParty` and
      `SendOutMon` have all run. The port gate dumps at the instruction after
      `DisplayBattleMenu` returns, which is that same instant. The port gate also
      ASSERTS `wPlayerMonNumber == 1` and dumps `FRAME.BIN` with the `$EE` marker
      instead if the script mistimed, so a no-op switch cannot dump a passing
      state.

      **PROVEN TO BE A REAL WITNESS, not just a passing check.** Deleting the one
      `call LoadBattleMonFromParty` from `SwitchPlayerMon` and re-running it
      produced **26 unmasked divergences**, naming the failure exactly:
      `wBattleMon species: want $90 | got $84`, `wBattleMonNick: want 'PERSIAN' |
      got 'SNORLAX'`, and every stat/move/PP word with it. Restored and re-run:
      PASS. The golden is also deterministic — two consecutive generations are
      byte-identical (md5 `f96b93d9…`).

      *Two harness facts worth reusing.* The RIGHT press into the menu's right
      column is POLLED, not assumed: `wTopMenuItemX` is `$9` in the left
      HandleMenuInput loop and `$f` in the right one (pret core.asm:2157/2190),
      so a swallowed RIGHT is caught instead of turning the following `A` into
      FIGHT. And the port-only window-layer diagnosis rows this gate carried
      (`g_window_count` / `g_windows` / `io_lcdc`) moved behind a new
      `BATTLE_SWITCH_WINDOW_PROBE=1` knob — the differ joins regions by NAME and
      the golden side has no counterpart for port memory.

      **2 of 5 DONE 2026-08-12: `battle_item_potion` (scenario id 60) is in the
      registry and PASSES.** A POTION used from the BATTLE BAG on the active mon
      — the first scenario that opens the in-battle bag at all, so 2c's
      `BagWasSelected` / `DisplayBagMenu` / `UseBagItem` finally execute.
      `ball_catch` never counted: its gate presets `wCurItem` and calls `UseItem`
      directly, bypassing the whole menu leg.

      **IT FOUND A REAL DEFECT ON ITS FIRST RUN — a page fault.** `GetItemName`
      had dropped pret's `.Finish: ld de, wNameBuffer` (home/names.asm:47) and
      tail-jumped to `GetName` instead, so `UseBagItem`'s
      `call GetItemName / call CopyToStringBuffer` (core.asm:2348-2349) copied
      from whatever `GetName` had left in EDX — the FLAT name-table entry it
      copied from. `CopyToStringBuffer` reads its source as `[ebp + edx]`, so the
      port faulted the instant an item was chosen: `Page Fault cr2=00716616 at
      eip=39c5` with `edx=00166616`. Nothing had caught it because the overworld
      bag reaches the same printer through `DisplayListMenuID`, which sets EDX
      itself (list_menu.asm:423). Fixed by restoring pret's shape (call + the
      `.Finish` store); the dropped `wPredefBank` store went back at the same
      time, so faithdiff is now 2/2 calls and 3/3 stores.

      *Zero RNG by construction:* the active mon is SEEDED to 100 HP on both
      sides rather than damaged in a turn, so the compared result is arithmetic
      (100 + 20). *Dump points aligned rather than masked:* the golden waits for
      `wLoadedMon` to hold the active species again, because the party menu's own
      draw leaves the LAST party mon in that staging buffer and the port gate
      dumps after the battle screen is restored. The first attempt diverged on
      all 15 `wLoadedMon` fields for no reason but timing; aligning the landmark
      removed the need for a mask entirely. *Non-vacuity:* rebuilding with
      `POTION_SEED_HP=101` fails with 3 divergences (`wBattleMon`, `wLoadedMon`
      and `wPartyData mon 0` HP all `want 120 | got 121`), so the comparison
      really reads the heal. The golden is deterministic (md5 `2c746709…` twice).

      **3 of 5 DONE 2026-08-12: the ball capture now goes through the real bag.**
      No new scenario — `ball_catch`'s PORT side was the problem. Its golden has
      navigated the real battle bag since it was written
      (`ball_catch.lua:53-57`), while the gate preset `wCurItem` /
      `wWhichPokemon` / `wPseudoItemID` and called `UseItem` directly, so the two
      sides reached the same OUTCOME by different ROUTES and the port's menu leg
      was never executed by anything. The bypass is deleted: `AUTOKEY_ITEMBALL`
      now presses DOWN+A to ITEM and DOWN DOWN+A to MASTER BALL through the
      production `DisplayBattleMenu`, and the gate asserts `wBattleResult == 2`
      (only `.returnAfterCapturingMon` sets it) before dumping.

      **The committed golden was NOT regenerated — the port converged onto the
      existing one.** That is the strong form of the evidence: same golden bytes,
      real menu route. Non-vacuity: dropping a single DOWN from the press table
      makes the run produce no dump at all (goldencheck exits 2), so the exact
      sequence is load-bearing.

      *Press ORDER matters and is why this needed its own autokey script.* The
      catch flow ends at the live `AskName` prompt and B is what declines the
      nickname — but a B landing while the BAG LIST is still up cancels the list
      instead. `AUTOKEY_APRESS`'s `DEBUG_ITEMBALL` arm is B from frame 30, so it
      could not be reused; the new script does the navigation first and starts
      the B train only after the ball is thrown.

      **4 of 5 DONE 2026-08-12: `battle_choose_next_mon` (scenario id 61) is in
      the registry and PASSES — the FORCED SWITCH.** It is the third door out of
      `HandlePlayerMonFainted` and the only one nothing had ever opened:
      `battle_faint` kills the ENEMY, `battle_blackout` kills the player's LAST
      mon (`AnyPartyAlive` fails), and this one kills the player's mon with
      another alive, so `DoUseNextMonDialogue` and `ChooseNextMon` — both ported
      by 2b with zero execution evidence — finally run. `WRAM: OK (13 regions,
      0 skipped)`, no masks.

      **THE "PORT STALL" REPORTED YESTERDAY WAS MY HARNESS, AND THE PORT WAS
      RIGHT.** The first gate did `call HandlePlayerMonFainted` and asserted
      after the return. On the forced-switch path that routine ends in
      `jp MainInBattleLoop` (pret core.asm:1006, mirrored faithfully in the
      port) — it TAIL-JUMPS into the battle loop and never returns. So the dump
      was unreachable by construction, and the "loops back into a party menu"
      observation was `MainInBattleLoop` doing exactly its job. `battle_faint`
      and `battle_blackout` can use a return-based dump precisely because they
      take the two doors that DO return. The regression memory
      `regression-battle-choosenextmon-party-menu-never-returns` is closed with
      that finding.

      *The dump is state-gated on both sides:* `wPlayerMonNumber == 5` AND
      `wLoadedMon` species == LAPRAS AND `wLoadedMonAttack == wBattleMonAttack`.
      The third clause is not decoration — MEASURED: `ChooseNextMon`'s party
      menu draws all six mons through `LoadMonData` and the LAST one it stages
      is slot 5, the replacement itself, so species alone fires before
      `SendOutMon` and the two sides then disagree on exactly the four stat
      words in the ratio **9/8** (golden 68/64/50/73 vs port 76/72/56/82) —
      `LoadMonData` copies the party's TRUE stats, `DrawPlayerHUDAndHPBar`
      copies `wBattleMon`'s BADGE-BOOSTED ones (pret core.asm:1904, the
      divergence `battle_faint` documents and masks). Requiring the attack words
      to agree picks the boosted staging on both sides, so this scenario needs
      **no mask at all**.

      *Non-vacuity:* leaving party slot 4 alive in the port gate fails with
      `wPartyData mon 4 HP: want $0000 | got $0094`. *Determinism:* two
      consecutive golden generations are byte-identical (md5 `61c3c400…`).

      **5 of 5 DONE 2026-08-12: `battle_item_no_effect` (scenario id 62)
      closes this box.** A POTION used from the battle bag on a FULL-HP mon, so
      `ItemUseMedicine` reaches `.healingItemNoEffect` -> `ItemUseNoEffect` —
      the only scenario in the registry that takes an item's FAILURE path.
      `WRAM: OK (13 regions, 0 skipped)`, no masks.

      *It is the case that forced the state-gated dump,* and the earlier
      correction in this box is why it was built that way from the start: on
      failure `UseBagItem` is `jp z, BagWasSelected` when
      `wActionResultOrTookBattleTurn == 0` (pret core.asm:2360-2362), so every
      failed item loops back into the bag and `DisplayBattleMenu` never returns.
      Landmark: `wCurItem == POTION` AND `wUsedItemOnWhichPokemon == 1` AND
      `wActionResultOrTookBattleTurn == 0` — the last is the failure EDGE, since
      `UseItem_` sets it to 1 on entry. The target is slot 1 rather than slot 0
      because 0 is cleared WRAM and could not distinguish "failed" from "never
      ran".

      *No seeding at all and no RNG:* the party is already at full HP, so the
      failure is structural. What is compared is that NOTHING happened — the bag
      still holds 16 entries with POTION x1 (`RemoveUsedItem` is never reached)
      and every party HP is untouched. **A "nothing happened" comparison needs
      its non-vacuity proof more than any other**, so: perturbing one compared
      byte in the port gate (ANTIDOTE qty 3 -> 2) fails with
      `wBagItems slot 1 quantity: want $03 | got $02`. Determinism: two
      consecutive golden generations byte-identical (md5 `51bafd62…`).

      **THE BOX IS CLOSED. Registry is 60 scenarios and all 60 PASS.** What it
      bought, in order: `battle_switch` (59) executes `PartyMenuOrRockOrRun` /
      `SwitchPlayerMon` / `RetreatMon` / `AnimateRetreatingPlayerMon`;
      `battle_item_potion` (60) executes `BagWasSelected` / `DisplayBagMenu` /
      `UseBagItem` and found a page fault in `GetItemName`; `ball_catch` now
      reaches the capture through the real bag instead of a preset;
      `battle_choose_next_mon` (61) executes `DoUseNextMonDialogue` /
      `ChooseNextMon`; and this one executes `ItemUseNoEffect`. Stage 2 and the
      2a/2b/2c boxes now all have execution evidence, and the Stage 3 boxes that
      were blocked behind "scenario capability" are unblocked as a technique —
      each still needs its own scenario.

## Stage 3 — close backend and stub-era leaves

Re-derive each routine from pret at implementation time; do not carry the old
audit's finding status forward. Current generated/source evidence establishes the
provider shapes below, not their runtime behavior.

- [x] **3a. Multi-turn state.** `CheckNumAttacksLeft` TRANSLATED 2026-08-11,
      WITNESSED 2026-08-12 by `battle_wrap` (id 64); the
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

      **Unwitnessed.** No scenario uses a multi-turn move, so the suite proves
      only that clearing an already-clear bit changes nothing.

      **MEASURED 2026-08-12, AND IT CHANGES THE APPROACH: the `battle_pay_day`
      template does NOT extend to this box.** I recorded in
      `battle-stage3-blocked-on-mechanics-scenarios` that 3a could copy 3b's
      shape. That is wrong, and here is the measurement. `CheckNumAttacksLeft`
      has exactly two call sites, pret core.asm:448 and :476, mirrored at
      `src/engine/battle/core.asm:432` and `:458` — and BOTH are in
      `MainInBattleLoop`'s turn tail, after `HandlePoisonBurnLeechSeed` and
      `DrawHUDsAndHPBars`. It is NOT reachable from `ExecutePlayerMove`
      (`grep -c` over that routine's body: **0**). So the pay_day gate shape —
      preset the move, `call ExecutePlayerMove`, call the tail yourself — cannot
      reach it, and a gate that called `CheckNumAttacksLeft` directly after
      `ExecutePlayerMove` would be duplicating production's sequencing: instance
      4 of `bug-class-false-witness-scenario`, proving only that the routine
      runs when you run it.

      **WHAT A FAITHFUL WITNESS ACTUALLY NEEDS**, so the next pass budgets for it
      rather than discovering it mid-build:
      1. the REAL `MainInBattleLoop` completing a whole turn — it is already
         externed in `debug_dump.asm:151`, and `battle_choose_next_mon` ends up
         inside it, so this is a known-good direction, just a bigger harness than
         any gate built so far;
      2. TWO turns, because the release is what distinguishes the routine from a
         no-op: turn 1 sets `USING_TRAPPING_MOVE`, turn 2's tail decrements to 0
         and clears it;
      3. a PIN on the rolled attack count. Wrap and Bide both roll
         `wPlayerNumAttacksLeft` (2-5 / 2-3) and the two emulators do not share
         an RNG stream, so the count must be forced on both sides between the
         turns — the same class of pin `battle_blackout` uses for GUST. Compare
         the FLAG (`wPlayerBattleStatus1`'s `USING_TRAPPING_MOVE`) and the
         zeroed counter, not the rolled value;
      4. a scenario-local `gbregion`: `wPlayerBattleStatus1` (`$D061`) is in NO
         compared region today — `wBattleFlags` covers only
         `wIsInBattle..wBattleType` (`$D057-$D05A`). Precedents for a
         scenario-local row: `trainerResult`, `wBoxData`, `wMenuState`.

      **THE TWO RISKY UNKNOWNS ARE NOW MEASURED (2026-08-12), so the build is
      mechanical from here.**

      *(a) The battle menu is SKIPPED while trapped, so turn 2 needs no menu
      input.* `MainInBattleLoop` (pret core.asm:322-324) reads
      `wPlayerBattleStatus1`, masks
      `(1 << STORING_ENERGY) | (1 << USING_TRAPPING_MOVE)` and jumps straight to
      `.selectEnemyMove` when either is set — the player's move auto-repeats.
      So the autokey is: FIGHT + A once to pick the move, then a plain A train to
      walk text. That is much smaller than "drive two full menu turns", which is
      what this box previously implied.

      *(b) The counter the box is about is NOT the one at core.asm:3419.* That
      decrement belongs to `ATTACKING_MULTIPLE_TIMES` — multi-hit moves like
      Double Slap — and is a different mechanic. The trapping counter is
      decremented by the trapping effect in `engine/battle/effects.asm`, and
      separately at core.asm:2368 on the in-battle ITEM path. Do not witness the
      wrong one: a scenario built around a multi-hit move would exercise
      core.asm:3419 and never touch `CheckNumAttacksLeft` at all.

      **THE GATE IS BUILT (2026-08-12) AND IT DOES NOT TERMINATE YET.**
      `DEBUG_BATTLE_WRAP=1` is a VIEWER, deliberately NOT in the manifest.
      `run_headless.sh "DEBUG_BATTLE_WRAP=1"` produces no dump.

      What DOES work, measured from GBSTATE at frame 1500:
      * the real `MainInBattleLoop` runs turns from the gate — this is the first
        harness that drives it, and it is the direction this box needs;
      * WRAP is selected and the trapping state is live:
        `wPlayerBattleStatus1 = $20` (`USING_TRAPPING_MOVE`, bit 5) and
        `wPlayerNumAttacksLeft = 1`, i.e. the `AutoKeyDrive` PIN is holding;
      * the enemy seed landed and does its job: `wEnemyMon` reads HP 261 of max
        999 with status `$03` (the seeded sleep counting down from 7), so it
        survives WRAP and never acts. **That fixed the first failure** — at the
        spec PIDGEY's 36 HP, WRAP KO'd it on turn 1 and `MainInBattleLoop` took
        `jp z, HandleEnemyMonFainted`, skipping the turn tail entirely.

      **THE PORT SIDE NOW WORKS (2026-08-12).**
      `run_headless.sh "DEBUG_BATTLE_WRAP=1"` dumps, and the dump is the
      RELEASE: `wPlyStatus1 = $00` — `USING_TRAPPING_MOVE` CLEARED — with
      `wPlyAtksLeft = $00` and the enemy alive at 601 HP. **That is the first
      execution evidence in the project that `CheckNumAttacksLeft` clears a SET
      bit**, which is exactly what this box exists to prove; every prior run of
      that routine cleared an already-clear bit.

      *What the earlier failure actually was, since the box previously blamed
      the pin.* Both port routines are FAITHFUL — `CheckNumAttacksLeft` clears
      on 0, and `TrappingEffect` is guarded by `bit USING_TRAPPING_MOVE / ret nz`
      so it cannot re-roll mid-sequence. The per-turn decrement is
      `.multiturnMoveCheck` (pret core.asm:3726-3736, port
      `core.asm:1865-1874`), also faithful. The fault was the HARNESS: with
      `AUTOKEY_APRESS` mashing A, every release was immediately followed by a
      FRESH Wrap, so the sequence looked endless and the enemy died of chip
      damage. Measured signature of that cycle: `wPlyAtksLeft` read `00` at
      frame 700 and `01` again at 900 with `wPlyStatus1 = $20` throughout —
      release, then re-cast. The dump condition also carried an unverified
      `wPlayerUsedMove == WRAP` clause; the latch already makes the same claim,
      so it was dropped.

      **DONE 2026-08-12: `battle_wrap` is scenario id 64 and PASSES.**
      `WRAM: OK (13 regions, 2 skipped)`. Registry is 62, all 62 PASS.

      **The sabotage is the strongest this plan has produced.** Deleting the
      bit-clear from `CheckNumAttacksLeft` itself makes the run produce NO DUMP
      AT ALL — the landmark depends on the routine under test doing its job, so
      the scenario cannot pass without it. Determinism: two consecutive golden
      generations byte-identical (md5 `b181f3a8…`).

      **TWO SKIPS, both narrow and both justified in `golden_diff.py`.**
      `wEnemyMon`: its remaining HP is the accumulated damage of the trapping
      hits, i.e. a roll, and the emulators do not share an RNG stream; the mon is
      seeded to 999 only so it SURVIVES, so the value carries no information
      about this box. `wLoadedMon`: the HUD staging buffer — and **alignment was
      tried first and is recorded as not working here**, which is the honest
      part. At the release instant the golden holds the PLAYER mon (level `$50`)
      and the port holds the ENEMY (`$0D`); adding `wLoadedMonLevel == 80` to
      both dump conditions — the fix that worked for `battle_item_potion` and
      `battle_choose_next_mon` — makes the PORT never dump at all, because it
      never re-stages the player inside the released window before the next cast.

      **OPEN QUESTION, left visible rather than buried in the skip:** whether
      that staging difference is only frame granularity or a real ordering
      difference in when `DrawHUDsAndHPBars` stages each mon. It is not a hole in
      this scenario — what it pins is the scenario-local `wPlyStatus1` /
      `wPlyAtksLeft` pair, and the party and `wBattleMon` are compared UNMASKED —
      but it is the first thing to look at if a later scenario trips on the same
      buffer.

      Also still owed once it terminates: the golden, the manifest row, and the
      `wPlyStatus1`/`wPlyAtksLeft` scenario-local rows (already written into the
      gate) mirrored by name on the mGBA side.
- [x] **3a (original entry) — DONE 2026-08-12. All three thirds witnessed.**
      This box asked for "the complete Bide/Thrash/trapping counter,
      accumulation, release and cleanup flow"; the ticked 3a above covers only
      the trapping third, which is why this entry stayed live.

      * **Trapping — DONE** by `battle_wrap` (id 64, 782638274). See 3a above.
      * **Bide — DONE 2026-08-12** by `battle_bide` (id 67). `DEBUG_BATTLE_BIDE`
        has `battle_wrap`'s shape for the same structural reason: the store and
        release arms live in `ExecutePlayerMove` (`.bideCheck` /
        `.unleashEnergy`, port core.asm:1799-1843) and only mean anything across
        TWO turns, which only the real `MainInBattleLoop` drives. Nothing in the
        registry had ever set `STORING_ENERGY`, let alone released it.

        **FOUR PINS, and two of them are not obvious.** Enemy HP 999 (the
        release deals 200; the spec PIDGEY's 36 would be an overkill) and enemy
        asleep are `battle_wrap`'s. The other two are specific to Bide: the
        rolled counter is forced to 1, and **the accumulator is forced to 100
        with `wDamage` zeroed alongside it**. Bide accumulates the damage the
        USER TAKES, so with the enemy asleep the accumulated total is 0 and
        `.unleashEnergy` would take its `wMoveMissed = 1` arm — an unpinned run
        photographs the DEGENERATE release and proves nothing. `wDamage` is
        zeroed because `.bideCheck` ADDS it into the accumulator every storing
        turn, so without it the compared total depends on scratch residue.
        **Every mid-battle write is gated on `STORING_ENERGY` being SET**, on
        both sides: `.unleashEnergy` clears the bit before it writes `wDamage`,
        so that condition is what guarantees a pin can never land between the
        release computing its damage and `HandleIfPlayerMoveMissed` applying it.

        **`wEnemyMon` IS COMPARED here, unlike in `battle_wrap`.** A trapping
        move's chip damage is a roll; the Bide release is exactly twice the
        pinned accumulator and jumps straight to `HandleIfPlayerMoveMissed`,
        skipping the damage calculation and the accuracy test — so 999-200=799
        is arithmetic. It is the scenario's landmark, together with a latch
        proving `STORING_ENERGY` was seen set (bit-clear-and-accumulator-zero is
        also the pre-battle state).

        **EVIDENCE.** `goldencheck battle_bide` PASS, `WRAM: OK (16 regions, 0
        skipped)`, one pre-existing datastruct mask, NO scenario-specific skips
        — a cleaner comparison than `battle_wrap`, which has to skip
        `wLoadedMon` and `wEnemyMon`. Golden reproducible: two fresh generations
        and the committed file all sha1 `c1656988`. **SABOTAGE: deleting
        `.unleashEnergy`'s two accumulator-clearing stores fails with exactly
        `wPlyBideDmg +1: want $00 | got $64`** — the precise byte the cleanup
        writes, which is the "cleanup flow" clause of this box. `make fidelity`
        16 PASS; `lint_pret_labels` 0 both modes; `validate_scenarios` 65.
      * **Thrash / Petal Dance — DONE 2026-08-12** by `battle_thrash` (id 68).
        `.thrashingAboutCheck` (port core.asm:1845) had never executed;
        THRASHING_ABOUT had never been set by anything in the registry. Same
        `MainInBattleLoop` gate shape as the other two.

        **THE ENEMY-HP PIN DOES NOT COPY, AND THAT COST A RUN TO FIND.**
        `battle_wrap`'s 999 is sized for WRAP's power 15; THRASH is power 90, so
        two hits from L80 go straight through it, the enemy faints, and the
        thrash ends because the BATTLE ended rather than because the routine
        ran. **The failure is silent and reads exactly like a broken feature** —
        the probe showed THRASHING_ABOUT set and then cleared with CONFUSED
        never set, forever. Seeded to 65535 now. When copying a
        survive-the-sequence pin between scenarios, re-derive it from the MOVE'S
        POWER.

        **ALIGNMENT WORKED HERE, WHERE `battle_wrap` RECORDS THAT IT DOES NOT.**
        The first run's ONLY divergence was `wLoadedMon level: want $50 | got
        $0D` — the HUD staging buffer, golden holding the player mon and port
        the enemy, i.e. the two sides straddling the turn tail's
        `DrawHUDsAndHPBars`. That is `battle_wrap`'s exact symptom, and
        `battle_wrap` skips the whole region for it. Rather than copy the mask,
        both dump conditions got `wLoadedMonLevel == 80` — and it converged.
        **So `battle_wrap`'s "alignment does not work" note is scenario-specific,
        not a general truth: the difference is WINDOW WIDTH.** A released trap
        exists for a handful of frames before the next cast; CONFUSED persists
        for turns. `battle_thrash` therefore COMPARES `wLoadedMon`, and skips
        only two regions where `battle_wrap` skips three.

        **`wPlayerConfusedCounter` IS CARRIED BUT SKIPPED, deliberately.** It is
        a second `BattleRandom` roll (2-5 turns, pret core.asm:3716-3720), so
        the two emulators cannot be made to agree on it, and PINNING it would be
        a tautology — the harness writing a byte on both sides and then checking
        both read it back. Both sides happen to read `$05` today; that is a
        coincidence of two independent streams, not agreement, and the skip's
        why-string says so explicitly so nobody deletes it on the strength of a
        passing run. `wPlyMoveNum` is carried too and is likewise NOT
        discriminating — `GetCurrentMove` already wrote the selected move there
        (pret core.asm:1781) and the selected move IS THRASH, so it reads `$25`
        whether or not the block under test ran.

        **EVIDENCE.** `goldencheck battle_thrash` PASS, `WRAM: OK (15 regions, 2
        skipped)`. Golden reproducible: two fresh generations and the committed
        file all sha1 `c784b331`. **SABOTAGE (delete the `or … 1 << CONFUSED` at
        the thrash end): the run produces NO DUMP AT ALL** — the transition IS
        the dump condition, the same shape of proof `battle_wrap` gives.
        `make fidelity` 16 PASS; `lint_pret_labels` 0 both modes;
        `validate_scenarios` 66.

## Stage 4 — special battle types

> **MEASURED SCOPE, 2026-08-12** — recorded so the next iteration picks a box on
> evidence instead of on the prose below, which was written before any of it was
> measured. Commands are named so each line can be re-run rather than trusted.
>
> `dos_port/tools/label_status <Label>`:
> * **4c Ghost Marowak is REAL TRANSLATION WORK.** `MarowakAnim` and
>   `CopyMonPicFromBGToSpriteVRAM` are both `missing` (pret
>   `engine/battle/ghost_marowak_anim.asm`); `IsGhostBattle` is `translated`.
> * **4d Safari's text layer is missing.** `PrintSafariZoneBattleText` is
>   `missing` (pret `engine/battle/safari_zone.asm`, whose only other labels are
>   its two texts).
>
> `grep -c` of the battle-type constants, which measures BRANCH COVERAGE and
> nothing else — a present branch is not a working feature, and none of these
> is executed by any scenario:
> * **4b OLD MAN is largely branched-in already**: pret has **7**
>   `BATTLE_TYPE_OLD_MAN` sites (4 in `engine/items/item_effects.asm`, 3 in
>   `engine/battle/core.asm`); the port has **8**, in the same two files. The
>   extra one is EXPLAINED, not dangling, and the mapping was checked rather
>   than assumed: port `core.asm:592` is pret `core.asm:2113-2117`
>   (`ld hl, .oldManName / ld a,[wBattleType] / dec a / jr z, .useOldManName /
>   ld hl, .profOakName`). `BATTLE_TYPE_OLD_MAN` is 1, so pret's `dec a / jr z`
>   IS the equality test; the port spells it `cmp byte [wBattleType],
>   BATTLE_TYPE_OLD_MAN`, which the grep counts and pret's does not. So 4b is plausibly a WITNESS problem more than an
>   implementation one — start by trying to build its scenario, not by writing
>   code.
> * **4d Safari is roughly half-branched**: `Safari|SAFARI` appears **32** times
>   in pret `engine/battle/core.asm` and **13** in the port's. The BAIT/ROCK menu
>   wiring is there (port core.asm:568, :3199, :6377); the turn/flee mechanics
>   and the text layer are what is thin.
>
> Not measured this pass, and therefore NOT covered by the above: 4a's golden,
> and whether any of 4b's branches are CORRECT rather than merely present.
> (4a's happiness-init audit WAS since done — 2026-08-12, see the box; it found
> three missing calls and a scanner blind spot that had hidden all 15 of pret's
> call sites to `ModifyPikachuHappiness`.) 4a's
> THIRD sub-item — the Oak follow stall — was re-measured and is DEAD; see the
> box itself.


- [x] **4a. `BATTLE_TYPE_PIKACHU`.** Audit every pret branch and implement the
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
      - **(1) THE MUST-HIT PIKACHU GOLDEN IS DONE 2026-08-12** — `battle_pikachu`,
        id 70, registered and PASSING. It became cheap the moment the shared
        special-battle staging landed (`63a37b2e4`); before that it was blocked
        for the same reason 4b was.
        * It is the SAME `.doSimulatedMenuInput` as `battle_oldman` —
          `DisplayBattleMenu` dispatches `BATTLE_TYPE_OLD_MAN` and
          `BATTLE_TYPE_PIKACHU` to it identically (pret `core.asm:2094-2098`) —
          so what it adds is the OTHER name, and specifically the FRAGILE one.
          `str_profoak_name`'s 11-byte tail is pret **CODE** (`FA 2D`, the first
          two bytes of `ld a,[wBattleAndStartSavedMenuItem]`), not the
          data-adjacency the old-man tail is. The generator's warning that those
          bytes drift if upstream edits `handleBattleMenuInput` had **no
          enforcement** before this scenario; now a drift fails the suite.
        * The golden captured `8f 91 8e 85 e8 8e 80 8a 50 fa 2d` — live
          emulation reproducing even the code-byte tail.
        * **Non-vacuity:** reverting `str_profoak_name` to `0x50` padding fails
          it on exactly those bytes —
          `want 'PROF.OAK' | got 'PROF.OAK'`
          `(8f918e85e88e808a50 fa2d | 8f918e85e88e808a50 5050)`. Decoded
          strings identical, bytes different; generator restored byte-identical
          afterwards and the scenario re-run PASS.
        * `wLoadedMon` is skipped for the same measured reason as
          `battle_oldman` (faithdiff `LoadEnemyMonData` 8/8 stores matched; the
          only pret writer is in a normal-battle routine).
      - **(2) THE HAPPINESS-INIT AUDIT IS DONE (2026-08-12). It found three
        MISSING calls, and — more importantly — the reason no gate had ever
        reported them.**
        - pret reaches `ModifyPikachuHappiness` from **15** sites, and every one
          of them goes through `farcall_ModifyPikachuHappiness` /
          `callfar_ModifyPikachuHappiness` (`macros/farcall.asm:74,81`). Those
          macros carry the CALLEE IN THE MACRO NAME and take the reason code as
          their operand, so the pret-side scanners — which match
          `farcall <Label>` — saw the operand `PIKAHAPPY_GYMLEADER`, not the
          routine. **`ModifyPikachuHappiness` therefore read as having ZERO pret
          callers**, and faithdiff could not report a dropped call to it in
          either direction. The port's 9 real calls were being reported as
          spurious `+ ADDED` lines instead.
        - Fixed in BOTH scanners (they duplicate the regexes rather than sharing
          them, which is why fixing one did not fix the other):
          `update_label_db` and `faithdiff` now match
          `(farcall|callfar)_<Label> <arg>`. Non-vacuity, fully decomposed:
          pret edges **7406 → 7421, delta +15, zero dropped**, and all 15 are
          `-> ModifyPikachuHappiness` at the exact enumerated lines. Per-label:
          `RemoveFaintedPlayerMon` 9→10 pret calls, `InitBattleCommon` 8→9.
        - The three missing calls, now RESTORED:
          `InitBattleCommon` `PIKAHAPPY_GYMLEADER` (pret init_battle.asm:57,
          gated on `wLoneAttackNo` — the major-story-battle marker `ReadTrainer`
          also reads); and `RemoveFaintedPlayerMon`'s `PIKAHAPPY_FAINTED` /
          `PIKAHAPPY_CARELESSTRAINER` pair (pret core.asm:1067-1083, chosen by
          whether the enemy outlevelled the player by 30+). The latter also
          restored pret's `wWhichPokemon` store, which is not cosmetic — it
          selects the mon `IsThisPartyMonStarterPikachu` tests, so without it
          the happiness call would read whatever the last consumer left there.
          faithdiff's `- DROPPED [wWhichPokemon]` on `RemoveFaintedPlayerMon` is
          gone as a result.
        - **The port's own comment had documented this as a HAL deferral** —
          `RemoveFaintedPlayerMon`'s header listed `ModifyPikachuHappiness`
          alongside `PlayCry` under "Deferred (ANIMATION/audio/Yellow)". It is
          pure WRAM arithmetic with no HAL boundary in it. Same failure mode as
          the `item_effects.asm` comment that documented a wrong register as the
          port's convention (`8a7f920c9`): a comment asserting a defect is
          intentional, which no linter can see.
        - **NOT restored, and each is a different reason, not one excuse:**
          `TradeCenter_Trade` `PIKAHAPPY_TRADE` (cable_club.asm:801) — the link
          serial HAL is a Phase-4 boundary; and the two `poison.asm` sites
          (`ApplyOutOfBattlePoisonDamage` PIKAHAPPY_PSNFNT,
          `UpdatePikachuHappinessAndMood` PIKAHAPPY_WALKING) — measured
          2026-08-12, **`engine/events/poison.asm` is entirely unported**,
          neither label exists anywhere under `dos_port/src/`. That is a whole
          missing file, not a dropped call, and it owns the out-of-battle
          happiness drift (the 256-step walking bonus and the mood convergence).
          It belongs to an overworld-events plan, not to this one.
      - **(4) THE BRANCH ENUMERATION IS DONE 2026-08-13 — this is the "audit
        every pret branch" the box header asks for, done the same way 4b's
        was.** pret has **9** `BATTLE_TYPE_PIKACHU` sites outside the constant
        definition. **7 are present in the port and faithful in structure and
        ordering** (same value order OLD_MAN-then-PIKACHU, same branch targets):
        * `scripts/PalletTown.asm:143` -> `src/scripts/pallet_town.asm:208`
        * `core.asm:2097` `DisplayBattleMenu` `.doSimulatedMenuInput`
          -> port `core.asm:555`
        * `core.asm:2305` `BagWasSelected` `.simulatedInputBattle`
          -> port `core.asm:3230`
        * `core.asm:6390` `LoadPlayerBackPic` -> port `core.asm:6788`
        * `item_effects.asm:119` (skip the party/box-full check),
          `:160` (`.oldManBattle`), `:531` (`.oldManCaughtMon`)
          -> port `item_effects.asm:1749`, `:1785`, `:2101`
        **The 2 absent ones are pre-existing documented deviations, not new
        gaps**, and each is a different one:
        * `common_text.asm:12` — the asleep-Pikachu cry branch. Its whole
          containing routine `PrintBeginningBattleText` is `label_status
          missing`, which the `DEVIATION{class=temporary}` at
          `init_battle.asm` already records; it retires with 4c and the
          pokeballs debt. (`IsPlayerPikachuAsleepInParty` is a `stub` too.)
        * `core.asm:165` `StartBattle.checkAnyPartyAlive` — folded into the
          documented `StartBattle` collapse. **Stating precisely what that
          collapse costs, because it had never been written down:** pret makes
          TWO decisions there, and the port implements only one. Decision 2
          ("any nonzero `wBattleType` skips the player send-out") IS
          implemented, at `init_battle.asm:396`. Decision 1 ("`BATTLE_TYPE_RUN`
          and `BATTLE_TYPE_PIKACHU` skip the `AnyPartyAlive` ->
          `HandlePlayerBlackOut` check, everything else runs it") is NOT — the
          port has no battle-ENTRY blackout check at all, for any type.
          MEASURED: `label_status --callers AnyPartyAlive` gives the port 5
          callers, all fainting, post-battle or overworld paths; pret's
          `core.asm:167` entry call has no port counterpart. Practical impact
          is bounded rather than absent: the port DOES keep pret's overworld
          walking check (`OverworldLoopLessDelay`, pret
          `home/overworld.asm:289`), so an all-fainted player blacks out before
          reaching a battle. Recorded here rather than "fixed" speculatively —
          restoring it belongs with the `StartBattle` collapse, not with 4a.

      - **ITEM (3) IS DEAD AND HAS BEEN SINCE 2026-08-07 — do not treat it as a
        blocker.** It read: "DOWNSTREAM the post-battle `PLAYER_FOLLOWS_OAK`
        step STALLS … this is what still blocks the Oak intro from reaching the
        lab end-to-end." That was FIXED by `7deceb6f1` ("battle: AnyPartyAlive
        faithful 8-bit wrap — fixes Oak-intro empty-party blackout"), five days
        before this line was last re-read. The stigmergy memory
        `regression-oak-intro-follow-stall-after-battle` has said `FIXED` since
        the same day, and the repository corroborates it independently:
        `AnyPartyAlive` (port core.asm:6797-6818) now carries pret's 8-bit
        `dec cl` with NO zero-guard, and a comment naming this exact stall as
        what the guard used to cause. The v3 hypothesis quoted above — a
        battle-exit displacement to x=8 — was itself measured WRONG; the real
        cause was the empty intro party making `AnyPartyAlive` report
        all-fainted, blacking the player out to `SetupPlayerSprite`'s (8,8).
        **A stale blocker in a plan is worse than no note, because the next
        agent treats it as live work.** Re-measure before re-adding one.
- [x] **4b. `BATTLE_TYPE_OLD_MAN`.** Implement the tutorial identity/menu and
      scripted throw behavior behind a deterministic battle scenario. The
      Viridian script and story reachability belong to overworld-events Stage 5.
      - **BRANCH-CORRECTNESS AUDIT DONE 2026-08-12** — this answers the gate
        preamble's open question ("whether any of 4b's branches are CORRECT
        rather than merely present"). **All 7 pret `BATTLE_TYPE_OLD_MAN` sites
        are present in the port and 6 are faithful in structure and ordering**:
        `DisplayBattleMenu` (core.asm:2095), `BattleItemMenu` (:2303),
        `LoadPlayerBackPic` (:6387), and all four `item_effects.asm` sites
        (:117 party/box-full skip, :158 + :170 `.oldManBattle`, :529
        `.oldManCaughtMon`). The item sites carry their `GLITCH`/`BUG`
        annotations already. The port has an 8th site, which is the
        `.doSimulatedMenuInput` name compare split across two lines.
      - **ONE REAL DIVERGENCE FOUND, measured against the ROM, and it is DATA
        not code.** pret copies `NAME_LENGTH` = **11** bytes from
        `.oldManName` / `.profOakName`, which are only **8** and **9** bytes
        long, so hardware copies whatever follows them into `wPlayerName`.
        From `pokeyellow.gbc` at `0f:4fe7` (offset `0x3CFE7`):
          `.oldManName`  11 bytes = `8e 8b 83 7f 8c 80 8d 50` + **`8f 91 8e`**
            — the tail is "PRO", bleeding out of `.profOakName`.
          `.profOakName` 11 bytes = `8f 91 8e 85 e8 8e 80 8a 50` + **`fa 2d`**
            — the tail is the first two bytes of the FOLLOWING CODE
            (`ld a, [wBattleAndStartSavedMenuItem]` = `fa 2d cc`).
        `tools/generators/gen_runtime_strings.py` instead pads both to 11 with
        `0x50`, so the port writes `50 50 50` / `50 50` where hardware writes
        `8f 91 8e` / `fa 2d`.
      - **SCOPE OF THAT DIVERGENCE, deliberately not overstated.** It is
        display-invisible (the `0x50` terminator lands in the same position on
        both sides) and TRANSIENT (`ItemUseBall.oldManBattle` copies
        `wGrassRate` -> `wPlayerName`, restoring the real name). **It does NOT
        reach the Missingno encounter data** — an earlier reading of this that
        said it did was wrong: pret's `CopyData` copies `hl` -> `de`, so the
        glitch WRITE is the earlier `wPlayerName` -> `wLinkEnemyTrainerName`
        (== `wGrassRate`) in `.doSimulatedMenuInput`, carrying the player's REAL
        name, and `.oldManBattle` is the restore. What remains is a genuine
        compared-WRAM gap: `wPlayerName` is a standard golden region
        (`lib/dump.lua:92`, all `NAME_LENGTH` bytes), so any golden photographed
        between the rename and the ball throw would diverge on 3 bytes (old man)
        or 2 (Pikachu).
      - **WHY NOTHING CAUGHT IT (as of the finding):** no scenario exercised
        the simulated-menu path — 4a's Pikachu golden was unauthored and there
        was no old-man scenario at all. Precisely the class of defect the "add
        a must-hit scenario" rule exists for. *Both goldens now exist
        (`battle_oldman` id 69, `battle_pikachu` id 70) and both gate these
        bytes, so this paragraph is history, not a live gap.*
      - **FIX LANDED 2026-08-12 (`dbe6e797b`)**, generator-side per the Tier-1
        rule. `assets/battle_menu_runtime_strings.inc` now matches the ROM byte
        for byte.
      - **THE WITNESS IS BUILT BUT NOT YET REGISTERED — this is the one open
        piece of 4b, and it is a DUMP-POINT ALIGNMENT problem, not a defect.**
        Landed unregistered: the `DEBUG_BATTLE_OLDMAN` gate
        (`debug_dump.asm` + its Makefile flag block) and
        `tools/mgba_harness/scenarios/battle_oldman.lua` with a committed,
        twice-verified deterministic golden (`b1a53777…`).
        * **THE FIX IS CONFIRMED BY IT.** The golden captured
          `8e 8b 83 7f 8c 80 8d 50 8f 91 8e` — live emulation of the real game
          independently reproducing the static ROM read — and in the port-vs-
          golden diff **`wPlayerName` does NOT appear among the mismatches**. So
          the port and hardware agree on the bytes under test.
        * **WHY IT IS NOT IN THE SUITE:** the two sides photograph different
          phases. All 32 divergences are `wBattleMon` / `wLoadedMon` /
          `wBattleFlags` reading ZERO on the GOLDEN side (`want` is the golden,
          confirmed at `golden_diff.py:1919`) and populated on the port's — the
          golden dumps before the battle mon is loaded, the port after.
          Tightening the landmark to require `wIsInBattle != 0` AND the full
          11-byte name did NOT move the golden's dump frame (5718 both times),
          so the next step is to find what the golden is actually sitting in at
          that frame rather than to add clauses blind.
        * **DELIBERATELY NOT MASKED.** Masking 32 fields would turn a real
          alignment question into a green tick, which is precisely what the
          preamble forbids; and registering a knowingly-failing scenario would
          break `fidelity-full` for everyone. So the manifest and
          `golden_diff.SCENARIOS` are left untouched and the suite stays at 66
          consistent scenarios.
        * **RESOLVED 2026-08-12 — the scenario is REGISTERED and PASSES (id 69).**
          The diagnosis below is kept because it is a SHARED STAGE-4 BLOCKER, NOT A
          BUG IN THIS SCENARIO.** Adding `wBattleMonSpecies != 0` to the
          landmark made the golden generation FAIL, and the assert's tilemap
          dump is the evidence: it read "All right!" / "PIDGEY was ..." — the
          tutorial's CATCH text. **In the old-man battle the player's mon is
          never sent out**, so `wBattleMon` stays zero for the whole battle on
          hardware. pret is explicit (`core.asm:171-174`,
          `StartBattle.specialBattle`): `ld a,[wBattleType] / and a /
          jp z, .playerSendOutFirstMon` — only a NORMAL battle sends out.
          The golden is therefore CORRECT and the port's dump is the odd one.
        * **THE PORT'S GAME CODE IS FAITHFUL HERE — the harness is not.**
          `init_battle.asm:391` does `cmp wBattleType, 0 / jne
          .specialBattleIntro`, carrying a DEVIATION that records why
          `StartBattle` reads `missing` (it is collapsed into
          `_InitBattleCommon`). But the battle-GOLDEN harness prologue
          (`debug_dump.asm` ~:2171) stages a battle BY HAND —
          `InitBattleVariables` / `InitBattleCanvas` / HUDs — instead of going
          through `_InitBattleCommon`, so it loads `wBattleMon` before any gate
          body runs, whatever `wBattleType` says.
        * **CONSEQUENCE FOR THE WHOLE OF STAGE 4 — AND IT IS NOW BUILT.** Every
          `wBattleType != 0` scenario (**4a Pikachu, 4b old man, 4d Safari**)
          needs a harness entry that reaches the battle through the real
          special-battle path. That entry now exists, in the shared battle
          staging, and 4a/4d can use it directly:
          1. The send-out is guarded by `cmp wBattleType, 0 / jne
             .skipPlayerSendOut`, pret `StartBattle:171` exactly. Special types
             never send out, so `wBattleMon` stays zero on both sides.
          2. `wBattleType` is set in the STAGING, before that decision — a gate
             that sets it in its own body is already too late.
          3. A special battle **never enters `MainInBattleLoop`**: pret falls
             into `.displaySafariZoneBattleMenu` and loops on
             `DisplayBattleMenu` (`core.asm:176-181`). Jumping to
             `MainInBattleLoop` with no player mon simply hangs — that is how
             this was found, via a `run_headless` timeout.
        * **RESULT: 32 divergences → 1 → PASS.** The last one was
          `wLoadedMon level` ($0D vs $00), skipped with a written justification
          rather than a bare mask: `faithdiff LoadEnemyMonData` reports all 8
          pret stores matched (so the port drops nothing), and pret's only
          battle-path writer of `wLoadedMon` is `core.asm:1904` inside
          `DrawPlayerHUDAndHPBar` — a normal-battle routine a special battle
          never reaches. Same reason `battle_faint` skips that buffer.
        * **NON-VACUITY, decisive.** Reverting the generator to `0x50` padding
          makes the scenario FAIL on exactly the predicted bytes:
          `wPlayerName: want 'OLD MAN' | got 'OLD MAN'`
          `(8e8b837f8c808d50 8f918e | 8e8b837f8c808d50 505050)` — the decoded
          strings are IDENTICAL while the bytes differ, which is precisely why
          this defect stayed invisible.
        * Registering it is: re-add the manifest entry (id 69, tier `full`,
          class `datastruct`, gate `DEBUG_BATTLE_OLDMAN`) and the
          `golden_diff.SCENARIOS` row, then `make assets` (the
          `GBSTATE_SCENARIO equ 69` row is generated from the manifest).
- [~] **4c. Ghost Marowak — ANIMATION HALF DONE 2026-08-12. The rest of the box
      is untouched.** `MarowakAnim` and `CopyMonPicFromBGToSpriteVRAM` are
      translated into the mirror `dos_port/src/engine/battle/ghost_marowak_anim.asm`
      and linked; both were `missing`, and every other callee was already
      `translated`, so it needed no stubs.

      **CORRECTION — THE "BLOCKER" I RECORDED HERE ONE ITERATION EARLIER WAS
      WRONG, ON BOTH COUNTS.** It claimed `CopyMonPicFromBGToSpriteVRAM` could
      not be expressed with the port's `CopyVideoData` because the copy is
      "VRAM -> VRAM counted in BYTES" while the port wants a flat source and a
      tile count. Measured:
      * **`PIC_SIZE` is 49 TILES, not bytes** — `PIC_WIDTH * PIC_HEIGHT`,
        `constants/gfx_constants.asm` says `; tiles`. pret's own header for
        `CopyVideoData` reads "copy c 2bpp tiles from b:de to hl", so DE is the
        SOURCE, HL the DEST and C a TILE count — the same shape the port
        documents (ESI dest, EDX source, BH bank, BL tiles).
      * **The port dereferences EDX FLAT** (`mov esi, edx` then `rep movsb`), so
        an emulated-VRAM source is simply `lea edx, [ebp + vFrontPic]`. Its doc
        comment says ".data / ROM" because every earlier caller happened to copy
        from there; nothing in the routine requires it.
      So there was no design decision to make. I recorded a confident wrong
      claim that would have stopped the next agent — exactly the failure mode
      this plan's preamble warns about — and it is corrected here rather than
      quietly dropped.

      **THREE NON-OBVIOUS TRANSLATION POINTS, all carried into the source:**
      * *`jr nz` reads ZF ACROSS a call*, in both fade loops
        (`sla a / sla a / ldh [rOBP1], a / call UpdateCGBPal_OBP1 / jr nz`). Safe
        on both sides and load-bearing: pret's routine is `push af ... pop af /
        ret`, the port's is `mov byte [g_pal_dirty], 1 / ret`, and a mov
        immediate-to-memory sets no flags. **Adding any compare to that two-line
        routine would silently break both loops.**
      * *`rra` is `rcr al, 1`, not `shr`* — it pairs with `srl b` -> `shr bh, 1`
        to carry the ejected bit.
      * *The fade-in loop keeps two live values in BX* (mask in BH, DelayFrames
        count in BL). Safe because the port's `DelayFrames` touches BL only and
        its inner `DelayFrame` is `pushad`-wrapped.
      Plus the projection: pret's `hlcoord 12, 0` becomes
      `UI_ENEMY_PIC_ROW/_COL`, the expression `init_battle.asm:434` and
      `core.asm:5217` already use — raw coords for this exact 7x7 block are a
      shipped bug (`regression-battle-second-battle-hud-tile-band`).

      **TWO THINGS DELIBERATELY NOT DONE, both stated in the source:**
      * `hAutoBGTransferEnabled` writes are faithful but INERT (the port retired
        pret's VBlank auto-transfer), so the BG ghost->Marowak swap is not
        hidden the way the Game Boy hides it. That is a behavioural question for
        whoever first puts this on screen.
      * The 36 OAM records go to `wShadowOAM` exactly as pret writes them, and
        on this port that DRAWS NOTHING without a `PublishProjectedOAM` — whose
        projection OFFSET is a property of the screen that owns the canvas, and
        that screen (the ghost battle) does not exist yet. Inventing an offset
        would be a guess that stays invisible until someone finally sees the
        animation.

      **EVIDENCE.** Assembles standalone; build EXIT=0; `faithdiff MarowakAnim`
      8/8 calls, 3/3 pret stores matched with ONE `+ ADDED [IO_OBP1]`, which is
      faithdiff's documented hardware-register blind spot (its pret-side store
      regex matches only `w`/`h` names) — verified rather than assumed by
      counting both sides: pret writes `rOBP1` 3 times in this routine and the
      port writes `IO_OBP1` 3 times. `faithdiff CopyMonPicFromBGToSpriteVRAM`
      CLEAN. `lint_pret_labels` 0 in both modes; `make fidelity` 16 PASS / 0
      FAIL.

      **UNWITNESSED, and that is not glossed:** nothing calls `MarowakAnim` yet.
      **THE REST OF 4c, MEASURED 2026-08-12 — three of its four named items were
      ALREADY PRESENT, so the box overstated the work.** Checked one by one:
      * *Escape rules* — DONE (`af3910228`): `IsGhostBattle` is wired into
        `TryRunningFromBattle`, clearing the port's own `TODO(faithful)` and
        faithdiff's `- DROPPED IsGhostBattle`. It carries an UNDOCUMENTED Gen-1
        bug with it, annotated `BUG{class=data-model}` at the site and recorded
        in `gen1-quirk-silph-scope-run-odds-pointer-clobber`.
      * *Unidentified-ghost refusal* — the CATCH half is already wired:
        `ItemUseBall` (`item_effects.asm:1778`) does `call IsGhostBattle` and
        takes the can't-be-caught value on ZF. `PrintGhostText` is translated
        and faithdiff **CLEAN** (2/2 calls), and the `cp GHOST` type checks
        exist (`core.asm:7353`/`:7356`).
      * *The Poké Doll consumer* — already MATCHES pret: `ItemUsePokeDoll` is a
        plain wild-battle check, because the scripted-battle special case lives
        in the battle engine and not in the item. The port says so in place.

      **WHAT IS ACTUALLY LEFT IS TWO WIRE-UPS**, named with their pret line
      ranges so the next attempt does not re-survey:
      1. **Ghost IDENTITY at battle init — DONE 2026-08-14. Both halves landed
         together, as the entry below required.** What shipped:
         * **The asset**: `gen_mon_pics.py` now emits `FossilKabutopsPic`,
           `GhostPic` and `FossilAerodactylPic` under their pret
           `gfx/pics.asm` label names, plus a port-only `SpecialMonPics`
           `{ dd ptr, dd len }` table. VERIFIED BY DECOMPOSITION, not by "it
           linked": the three `pkmn.sym` addresses are 403 / 342 / 383 bytes
           apart — exactly the three source file sizes — the record block sits
           at the `SpecialMonPics` symbol address with those same three
           pointer/length pairs, and all three blobs are byte-identical to
           `gfx/battle/ghost.pic` / `fossilkabutops.pic` / `fossilaerodactyl.pic`
           inside `PKMN.EXE`.
         * **The data model**, which was the real blocker: `wMonHFrontSprite`
           now carries a small `SPECIAL_PIC_*` handle where pret carries the
           pic's GB ROM address, and `UncompressMonSprite` dereferences it
           through `SpecialMonPics`. That is **pret's own mechanism**, not a new
           one — pret's `UncompressMonSprite` reads the front-pic pointer out of
           the loaded mon header, which is the only reason a non-dex pic is
           addressable at all; the port simply could not follow it while the
           field held a meaningless ROM address. Handle 0 keeps the dex path
           unchanged, and it cannot collide: `gen_base_stats.py` zeroes the
           sprite-dim and both pic pointers in every `BaseStats` row.
           `GetMonHeader.specialID` writes the handle under a
           `DEVIATION{class=data-model}` that supersedes the 2026-07-13 TODO-HW
           (which was accurate when written and is now false).
         * **The ghost arm** of `InitWildBattle` is translated: `RESTLESS_SOUL`
           test, `IsGhostBattle` fallback, `wMonHSpriteDim = $66`, the "GHOST"
           nick (Tier-1, `ghost_nick` via `gen_runtime_strings.py`), the
           `wCurPartySpecies` save/substitute/restore, and `LoadMonFrontSprite`
           to `vFrontPic`. **This IMPROVED the faithdiff**: `IsGhostBattle` and
           `LoadMonFrontSprite` were both DROPPED before and now match (4 of 5
           pret calls, up from 2). The one remaining DROPPED call is pret's
           `predef CopyUncompressedPicToTilemap`, ADDED back as
           `CopyUncompressedPicToHL` — the same body one label later
           (`init_battle.asm:221` falls through to `:227`), which is exactly how
           pret's own `home/pokemon.asm:133` reaches it.
         * **ONE HAZARD THE CHANGE INTRODUCED AND CLOSED IN THE SAME COMMIT.**
           Making the port read the header re-imports pret's staleness contract
           ("assumes the corresponding mon header is already loaded",
           `home/pics.asm:UncompressMonSprite`) into a path that was previously
           immune to it — neither pret's nor the port's
           `LoadFrontSpriteByMonIndex` calls `GetMonHeader`, so a handle left in
           the header by a ghost battle the player RAN FROM would have hijacked
           the next pokédex / status / party pic. The dex entry now clears the
           handle before loading, which is sound by construction: it has just
           proved the species has a dex number, and $B6-$B8 cannot arrive there
           in either codebase because they take the Rhydon trap. Cost: one
           `+ ADDED [wMonHFrontSprite]` store on that label's faithdiff.
         * **UNWITNESSED, and that is not glossed.** No scenario enters a ghost
           battle, and none cheaply can: the mGBA side plays the real game with
           no synthetic staging (`lib/battle.lua` walks Pallet -> Route 1), so a
           witness needs a navigated route to Pokémon Tower 3F-6F without the
           Silph Scope. That is its own scenario box, listed below. What the
           suite DOES witness is the regression direction: every wild-battle
           scenario now executes the new `call IsGhostBattle`, so a wrong ZF
           would send them all down the ghost arm and break loudly.
         *(original diagnosis, kept because it is what the work was aimed at)*
         **BLOCKED 2026-08-12 on a MISSING ASSET, not on battle code.** pret `engine/battle/init_battle.asm`
         (~:76-90) hand-writes the mon header (`wMonHSpriteDim` = `$66`, front-pic
         pointer = `GhostPic`), sets `wEnemyMonNick` to "GHOST", substitutes
         `MON_GHOST` into `wCurPartySpecies`, calls `LoadMonFrontSprite`, then
         restores the species. Two things make that untranslatable as written:
         * **`GhostPic` DOES NOT EXIST IN THE PORT.** `GetMonHeader`'s `.ghost`
           path is already there and sets the dimensions correctly
           (`src/home/pokemon.asm:148-160`), but writes `wMonHFrontSprite = 0`
           under a `TODO-HW` verified 2026-07-13: *"none of the three exists in
           the port — no symbol in pkmn.sym, no data blob, no generator emits
           them — so there is nothing to point at."* The same gap covers
           `FossilKabutopsPic` and `FossilAerodactylPic`, so this is a shared
           asset-generation item, not a battle one.
           (Beware a grep for `GhostPic` reporting "present" — it matches that
           TODO comment. There is no data.)
         * **The port's front-pic loader is INDEX-driven, pret's ghost path is
           HEADER-driven.** `LoadMonFrontSprite`'s contract is `EAX = dex-1
           (0..150)` and its own header records that pret "reads the front-pic
           ROM pointer out of the loaded mon header" while the port does not;
           `LoadFrontSpriteByMonIndex` goes `wCurPartySpecies` ->
           `IndexToPokedex` -> `MonFrontPics[dex-1]`. `MON_GHOST` (`$B8`) has no
           dex number, so it would hit the Rhydon invalid-dex trap. Loading a
           non-dex pic needs a pointer-taking path that does not exist yet.
         So this item is owed an ASSET (a generator emitting the three special
         pics) plus a loader entry point that accepts an explicit pic pointer.
         Both are outside the battle plan's scope and neither should be
         improvised here.
         * **THE ASSET HALF IS MECHANICAL — MEASURED 2026-08-14, so the next
           attempt does not have to re-derive it.** All three `.pic` files are
           present in the checkout (`gfx/battle/ghost.pic` 342 B,
           `gfx/pokemon/front/fossilkabutops.pic` 403 B,
           `fossilaerodactyl.pic` 383 B), and they are the SAME compressed
           format `tools/generators/gen_mon_pics.py` already consumes — it emits
           `incbin` blobs plus `{ dd flat_ptr, dd blob_len }` records for all 151
           dex mons. Emitting three more is a generator change, not a design one.
         * **BUT EMITTING IT ALONE WOULD BE DEAD DATA, which is why this stays
           blocked rather than half-done.** `wMonHFrontSprite` is a 16-bit GB
           pointer field and these three pics have no dex number, so nothing can
           address them: `LoadFrontSpriteByMonIndex` goes
           `wCurPartySpecies -> IndexToPokedex -> MonFrontPics[dex-1]`, and
           `MON_GHOST` ($B8) has no dex entry. Generating the blobs would move
           the gap from "no data" to "data nothing can reach".
         * **SO THE REAL BLOCKER IS THE DATA MODEL, not the asset**: the port
           needs a pic path that takes an explicit flat pointer + length. One
           already exists in a different shape —
           `IntroDisplayPicCenteredOrUpperRight` takes exactly `ESI = flat
           pointer, ECX = length` — so the shape is proven, it simply is not
           reachable from the mon-header route. Do the two together or not at
           all.
         **The string half IS ready and is not the blocker:** "GHOST" belongs in
         `tools/generators/gen_runtime_strings.py` under
         `battle_intro_runtime_strings.inc` (which `init_battle.asm` already
         `%include`s and the Makefile already depends on), as
         `("ghost_nick", ["GHOST", [0x50]])` — the same shape as `intro_line1`.
         Hand-encoding charmap bytes in a `.asm` is this project's
         most-repeated violation, so it must go through the generator.
      2. **The unveil sequence — what makes `MarowakAnim` REACHABLE. TRACED
         2026-08-12 to a bigger, already-owned blocker.** The unveil arm is not
         a standalone call site: it lives inside pret's
         `PrintBeginningBattleText` (`engine/battle/common_text.asm`, the
         `.isMarowak` arm at ~:65-76 —  `EnemyAppearedText` ->
         `UnveiledGhostText` -> `LoadEnemyMonData` -> `callfar MarowakAnim` ->
         `WildMonAppearedText`). The dependency chain, measured:
         * ~~**`PrintBeginningBattleText` is `label_status` MISSING** — the port
           has no translation of it at all.~~ **STALE, corrected 2026-08-14.**
           It is `translated` (`src/engine/battle/common_text.asm`), faithdiff
           **11 pret / 11 port, 10 matched**, stores 3/3, with **0 port
           callers** — written but never wired. The blocker was never the
           translation; see the two measured findings in
           `battle-printbeginningbattletext-wiring-is-a-reconciliation`. What stands in its place is the
           ad-hoc intro in `init_battle.asm` (`DrawBattleIntroBox` /
           `DrawEmptyDialogBox`) under a `DEVIATION{class=temporary}`.
         * **That deviation's evidence clause was STALE and is corrected in the
           same change.** It read "…while common_text.asm TrainerWantsToFightText
           remains missing" — measured FALSE: the stream is generated Tier-1 at
           `assets/battle_text.inc:498-501`. So are the other five the routine
           needs (`WildMonAppearedText`, `EnemyAppearedText`,
           `GhostCantBeIDdText`, `UnveiledGhostText`, `HookedMonAttackedText`).
           Its `lifetime=` also named Stage 1d, which is TICKED — a retirement
           condition that has already passed without the routine landing.
         * ~~**The real blocker is `DrawAllPokeballs`**~~ — **RETIRED
           2026-08-14 (`337a2b0ab`).** `DrawAllPokeballs` is `translated`, with
           `SetupOwnPartyPokeballs` and `SetupEnemyPartyPokeballs` beside it,
           all three faithdiff 3/3 calls matched. The five-step fork retirement
           (`8a238be51`, `6ff7f160a`, `ae684a27e`, `72db8892b`, `337a2b0ab`)
           landed with ZERO golden movement throughout, which is what the
           separability argument predicted. **WHAT NOW BLOCKS THE WIRING IS
           DESIGN, NOT A MISSING ROUTINE** — two measured findings: `battle_intro`
           dumps INLINE and the faithful path parks at the text stream's prompt,
           so it times out and needs a FRAME-BASED dump (and therefore a
           regenerated golden); and `battle_safari` shows 132 blank tilemap
           cells because the new path changes what is on screen when
           `SaveBattleScreen` snapshots, which a special battle's menu then
           restores. Reconciling that ordering is design work.
           *(historical)* It was `missing`; the ROUTINE half of pret
           `engine/battle/draw_hud_pokeball_gfx.asm` (`DrawAllPokeballs`,
           `LoadPartyPokeballGfx`, `SetupPokeballs`, `PickPokeball`,
           `WritePokeballOAMData`, `PlaceHUDTiles`) lives in
           `src/engine/battle/pokeballs.asm` under PORT-ONLY NAMES with its own
           private copy of the tile blob. The mirror file says so itself:
           *"a faithful-in-spirit bespoke … that predates the mirror rule —
           pre-existing debt owned by the battle-completion plan, not grown
           here."*

         **SO THE NEXT ACTIONABLE BOX IS THE POKEBALLS FORKED-NAME DEBT**, not
         the unveil. Retiring it (restoring pret's names into the mirror) unlocks
         `PrintBeginningBattleText`, which in turn unlocks both this item and the
         faithful trainer intro. BLAST RADIUS, stated up front: replacing the
         ad-hoc intro changes what `battle_intro`, `battle_menu`,
         `move_selection` and `trainer_battle_route` photograph, so it will need
         golden regeneration and a `fidelity-full`, not just a core tier.

         **STARTED 2026-08-12 — STEP 1 OF N LANDED (`8a238be51`).**
         `LoadPartyPokeballGfx` is home in the mirror under its pret name, a
         literal translation tail-calling `CopyVideoData`; it also deleted
         `ball_gfx`, a SECOND `incbin` of `gfx/battle/balls.2bpp` that
         `pokeballs.asm` kept beside the mirror's own `PokeballTileGraphics`.
         Gates: faithdiff 0 lines, lint 0 both modes, static_gate PASS,
         `battle_intro` + `battle_menu` PASS. **Note the fork retirement is
         SEPARABLE from the intro replacement above** — this step moved a label
         with zero golden movement. Retire the fork first, then do the intro.

         *That label had to go first, and the reason generalises to any fork
         retirement:* its tile count is `(End - Start) / TILE_SIZE`, a DIVISION
         of a label difference, and non-linear assembly-time arithmetic on an
         external is impossible in NASM. A routine that computes its own blob's
         size can only live where the blob is defined — which is exactly why the
         forked copy had both a hardcoded count and a private copy of the blob.

         **TWO CORRECTIONS TO THE SCOPE AS PREVIOUSLY RECORDED, both measured:**
         1. *The fork is wider than this plan and its memory said.* It also
            spans `engine/battle/battle_hud.asm`: pret `PlaceHUDTiles`,
            `PlacePlayerHUDTiles` and `PlaceEnemyHUDTiles` are forked there as
            `place_hud_frame`, `DrawPlayerHUDFrame`, `DrawEnemyHUDFrame`. That
            half is also a DATA-MODEL divergence, not just a rename: pret copies
            a 3-byte table into `wHUDGraphicsTiles` and reads the corner and
            triangle tiles back out of WRAM, where the port passes them as
            immediates and never touches that WRAM.
            **DONE — STEP 2, 2026-08-12.** All three are in the mirror under
            pret's names, with `PlayerBattleHUDGraphicsTiles` /
            `EnemyBattleHUDGraphicsTiles` and the WRAM path restored; the five
            `wHUD*` equates ($CD3E-$CD42) are in `gb_memmap.inc` with addresses
            taken from `pokeyellow.sym`, not inferred. The five now-dead tile
            `%define`s were deleted rather than left as a second source of truth.
            *Tilemap output is unchanged by construction and that was CHECKED,
            not assumed:* the table bytes ($73/$77/$6F and $73/$74/$78) are
            byte-for-byte the immediates the forked version passed in BH/BL. The
            genuinely new observable is that `wHUDCornerTile`/`wHUDTriangleTile`
            now hold what hardware holds.
            *The `$CD3E` union overlap the earlier note flagged as owed is
            RESOLVED and is not a collision:* `pokeyellow.sym` lists both
            `wHUDPokeballGfxOffsetX` and
            `wBattleTransitionCircleScreenQuadrantX` at `00:cd3e`, so the real
            hardware aliases them too (pret wram.asm:815 and :863 are separate
            `NEXTU` lanes) — the transition finishes before the HUD draws. Note
            also `wNumFieldMoves` aliases `wHUDTriangleTile` at $CD41 and the
            party menu IS reachable mid-battle; that is safe because
            `PlacePlayerHUDTiles`/`PlaceEnemyHUDTiles` re-copy the table on
            every call, which is pret's own protection.
         2. *The remainder is NOT a mechanical rename.* pret's
            `WritePokeballOAMData` writes `wShadowOAM` ($C300); the port's
            `build_ball_row` writes `$FE00` directly and publishes through
            `PrepareStaticOAM`, which reads `$FE00`. This is deliberate —
            `src/home/vblank.asm:update_oam` records that
            `wUpdateSpritesEnabled == $FF` skips the shadow→`$FE00` DMA
            precisely because the ball row relies on not being re-copied over,
            since the normal path runs `PrepareOAMData` first and would rebuild
            shadow OAM from `wSpriteStateData`, destroying the entries. A
            faithful `wShadowOAM` translation is therefore possible but needs an
            explicit port-only publish (shadow → `$FE00`, the DMA the GB does,
            then `PrepareStaticOAM`). It would be strictly MORE faithful than
            today, and it CHANGES COMPARED WRAM — so that step needs golden runs,
            not just a static gate.

         Still forked after step 1: `DrawAllPokeballs`, `DrawEnemyPokeballs`,
         `SetupOwnPartyPokeballs`, `SetupEnemyPartyPokeballs`, `SetupPokeballs`,
         `PickPokeball`, `WritePokeballOAMData`,
         `SetupPlayerAndEnemyPokeballs`, plus the three `battle_hud.asm` labels.
         Five WRAM equates are owed first, addresses already resolved against
         `pokeyellow.sym`: `wHUDPokeballGfxOffsetX` $CD3E, `wHUDGraphicsTiles`
         $CD3F, `wHUDCornerTile` $CD40, `wHUDTriangleTile` $CD41,
         `wHUDGraphicsTilesEnd` $CD42 (that range is heavily unioned in the port
         and in pret — confirm no live battle overlap before adding).

- [x] **4c (original folding note) — SUPERSEDED 2026-08-12, not open work.**
      It asked for `MarowakAnim` + `CopyMonPicFromBGToSpriteVRAM` to be folded
      in from the archived animations plan. Both were translated into the mirror
      `dos_port/src/engine/battle/ghost_marowak_anim.asm` on 2026-08-12
      (`83d8cf1c1`), which is the "ANIMATION HALF DONE" half of the consolidated
      4c box above. Nothing here is outstanding; ticked so it stops reading as a
      third open 4c.
- [x] **4c (original entry) — SUPERSEDED 2026-08-12, not open work.** Its scope
      (ghost initialization/identity, unidentified-ghost move refusal, escape
      rules, the item-owned Poké Doll consumer, and the note that Pokémon
      Tower/Silph Scope reachability stays overworld-owned) is enumerated in
      full, with per-item measurement, inside the consolidated 4c box above —
      including the two findings that entry predates: the refusal's CATCH half
      is already wired, and `ItemUsePokeDoll` already MATCHES pret. **The
      remaining 4c work, and its recorded blocker chain, live in that box; track
      it there and nowhere else.** Ticked as a duplicate, NOT as completed work.
- [x] **4d. Safari.** Implement the BAIT/ROCK/ball/run menu and the Safari turn/flee
      divergence using the already-translated item-owned `ItemUseBait`,
      `ItemUseRock`, and `ItemUseBall` effects. Safari maps, steps, and story
      entry/exit remain overworld-owned.
      - **WITNESSED 2026-08-12 — `battle_safari` (id 71) is registered and
        PASSES.** The first scenario to RENDER the Safari menu, so everything
        4d landed is now compared against hardware: the full-width
        `SAFARI_BATTLE_MENU_TEMPLATE` box, the BALL/BAIT/THROW ROCK/RUN labels,
        both cursor columns and the ball counter. Tilemap, VRAM, OAM and WRAM
        all OK.
        * **It found a SECOND staging bug of the same family as the send-out
          one.** The golden staging hand-rolls a NORMAL battle intro
          (pokéballs, no HUD) because `DisplayBattleMenu` redraws the HUDs when
          `wBattleType == 0`. A special battle SKIPS `DrawHUDsAndHPBars`
          (pret `core.asm:2078-2082`), so the omission was invisible until a
          rendered special-battle scenario existed: 29 tilemap cells (the
          missing enemy HUD) and 6 OAM entries (pokéballs hardware does not
          show). The port's PRODUCTION path was right all along —
          `init_battle.asm:531` `.specialBattleIntro` draws the enemy HUD and
          no pokéballs — so the staging now mirrors production.
        * **Two ordering facts that cost a measurement each**, both now in the
          source: the battle type must be staged BEFORE the intro (setting it
          before the send-out left the intro on its normal path — 94
          divergences unchanged), and the enemy HUD must be drawn BEFORE
          `SaveBattleScreen`, because a special battle's menu opens with
          `LoadScreenTilesFromBuffer1` and restores away anything later
          (29 cells adrift until moved).
        * Progression, decomposed: 94 → 91 → 68 → PASS. The 68 masked hits are
          the SHARED rendered-battle mask sets `battle_menu` and
          `move_selection` already carry (the F-19 cloned enemy-gauge tiles and
          the battle sprite patterns) — not new masking.
      - **`PrintSafariZoneBattleText` TRANSLATED 2026-08-12.** The whole routine
        half of pret `engine/battle/safari_zone.asm`, in the mirror, faithdiff
        clean (3/3 calls, 2/2 stores). It carries the per-turn bait/angry
        message and the catch-rate refresh when the escape factor hits zero.
        * Its two text streams did not exist in the port at all until this
          change added `engine/battle/safari_zone.asm` to
          `gen_battle_text.py`'s `BATTLE_SRC` — the file had never been
          scanned, exactly as `trainer_ai.asm` had not been until 2026-08-11.
          Generated label count 150 → 152, both new labels Safari.
        * **UNWITNESSED**: nothing calls it yet. Its caller is the Safari turn
          flow, which is the rest of this box.
      - **THE TURN/FLEE LOOP IS DONE 2026-08-12.** pret `StartBattle:176-216`
        is translated into `.specialBattleLoop`, which retires the
        `DEVIATION{class=temporary}` that sat there naming this box as its
        lifetime. `PrintSafariZoneBattleText` finally has a caller (it had none
        since it was translated), so it is reachable rather than merely linked.
        The blocker below was resolved through `EXTRA_FAR`, as planned:
        `_OutOfSafariBallsText` added, battle_text.inc 153 → 154, delta +1, and
        losing pret's wrapper `text_end` is harmless because the far stream ends
        in `prompt` ($58), which terminates the engine — checked, not assumed.
      - **WHAT THIS TICK DOES AND DOES NOT CLAIM (2026-08-13).** The box asks
        for the menu and the turn/flee divergence to be IMPLEMENTED, and they
        are: 6/6 `DisplayBattleMenu` Safari branches, `PrintSafariZoneBattleText`
        (faithdiff clean), and `.specialBattleLoop` translating pret
        `StartBattle:176-216`. `battle_safari` (id 71) compares the rendered
        menu against hardware.
        * **The turn/flee loop itself is `reachable`, NOT `executed`** — those
          are different evidence per the verification-terms rule, and no
          scenario has yet driven a Safari TURN. `battle_safari` photographs
          the menu before any action, so `PrintSafariZoneBattleText`, the bait
          and escape-factor arithmetic and the flee roll are all unwitnessed.
        * **Why that witness is not trivial, so the next agent does not assume
          it is a small add:** the flee decision consumes `Random`, and the two
          emulators do not share an RNG stream (`mgba_harness/lib/seed.lua`),
          so the OUTCOME cannot be compared directly. A usable scenario has to
          dump on the deterministic part — the bait/angry text and
          `wSafariBaitFactor` / `wSafariEscapeFactor` after a BAIT — before the
          roll can end the battle.
        * Transferred to the "one must-hit scenario per battle type" box below,
          which already owns the RESULT/EXIT coverage gap. Tracked there, not
          here.
        * **SAFARI BAIT WITNESS PROBE, 2026-08-13 — not registered and fully
          reverted.** A temporary gate entered production `_InitBattleCommon`,
          pinned `wEnemyMonSpeed+1 = 0` so the post-BAIT flee threshold would be
          zero, scheduled DOWN then A, and waited to dump at
          `wSafariBaitFactor == 4` (the real loop's 5 -> 4 decrement before its
          text print). `run_headless` built successfully but produced no dump.
          This does **not** establish that the port loop is
          wrong: the uninstrumented run cannot distinguish failure to reach the
          special loop, a missed fixed-time menu input, or a failed BAIT action.
          The next attempt must add diagnostic state capture for those three
          phases before adding a scenario row or golden artifact.
      - *(historical, for the reasoning that got there)* **IT WAS BLOCKED ON ONE
        TEXT STREAM (measured 2026-08-12).** pret's loop is `StartBattle:176-216`
        (`.displaySafariZoneBattleMenu`): the action-taken re-loop, the
        out-of-balls arm, the `PrintSafariZoneBattleText` call — which would
        finally give that already-translated routine a caller — and the flee
        roll (`b = (enemy speed low byte) * 2`, `jp c, EnemyRan`; bait halves it
        twice; escape doubles it capped at $FF; `Random` vs `b`). The port's
        `.specialBattleLoop` (`init_battle.asm`) already carries a
        `DEVIATION{class=temporary}` whose `lifetime=` names THIS box, so
        landing it retires that annotation.
        * `EnemyRan` and `Random` are translated. The blocker is
          **`OutOfSafariBallsText`**, which does not exist in the port.
        * **DO NOT FIX IT BY WIDENING THE TEXT GENERATOR'S REGEX — measured and
          UNSAFE.** pret spells it `.outOfSafariBallsText`: a dot-local with a
          LOWERCASE initial. `gen_battle_text.py` learned dot-locals in
          `bb5c29b98` but requires an uppercase initial, so the tempting change
          is to allow `[a-z]`. Of the **11** lowercase dot-local `*Text` labels
          across `BATTLE_SRC`, **10 are CODE labels** — `.printText` is
          `call PrintText`, `.gotText` is `ret` — and only
          `.outOfSafariBallsText` is a real `text_far` wrapper. Widening the
          regex would hand ten code bodies to the text parser.
        * The safe mechanism is the generator's existing **`EXTRA_FAR`** list
          ("raw `_Xxx` far streams to emit even though no generatable wrapper
          references them"): add `_OutOfSafariBallsText`. Check first that what
          it emits TERMINATES — pret's wrapper is `text_far` + `text_end`, so
          the trailing `$50` matters.
      - **THE GAP IS DECOMPOSED PER ROUTINE (2026-08-12), and it is narrower
        than the totals suggest.** pret has 12 `BATTLE_TYPE_SAFARI` sites to the
        port's 9, but the shortfall is **entirely inside `DisplayBattleMenu`**:
          `TryRunningFromBattle`  pret 1 / port 1  ✔
          `UseBagItem`            pret 2 / port 2  ✔
          `PartyMenuOrRockOrRun`  pret 1 / port 1  ✔
          `DisplayBattleMenu`     pret 6 / port 1  ← the whole gap
          (+ 4 matched sites in `item_effects.asm`)
        (An earlier note said "13/32 branch coverage"; that figure could not be
        reconciled with any measurement reproducible here — re-measure rather
        than citing it.)
      - **TWO OF THE SIX RESTORED 2026-08-12**, both pure selection logic with
        no coordinate projection, so they were separable from the rest:
        * pret `:2224` — a Safari battle **skips the ITEM/PKMN id swap**, since
          its four items are already in menu order. The compare's ZF crosses two
          flag-neutral loads exactly as pret writes it; anything flag-writing
          between silently makes Safari take the swap.
        * pret `:2246` — the upper-left item is **SAFARI BALL, not FIGHT**
          (`jp UseBagItem`, not a call — `UseBagItem` owns the rest of the turn).
        `DisplayBattleMenu` code sites: 1 → 3 of pret's 6.
      - **THE REMAINING THREE ARE ENTANGLED WITH AN EXISTING DIVERGENCE**, which
        is why they were not done in the same pass:
        * `:2086` — **DONE 2026-08-12.** It was one job with a pre-existing
          faithdiff finding, as predicted: the port called a port-only
          `DrawBattleMenuBox` wrapper that hardcoded the battle template's
          geometry, so `DisplayTextBoxID` and `[wTextBoxID]` both read DROPPED
          and there was no way to ask for the Safari box at all. Replaced with
          pret's exact sequence (`wTextBoxID` = BATTLE_ or
          SAFARI_BATTLE_MENU_TEMPLATE, then `DisplayTextBoxID`).
          **Three findings closed, none added** — calls matched 11 → 12, stores
          5 → 6: DROPPED `DisplayTextBoxID`, ADDED `DrawBattleMenuBox` and
          DROPPED `[wTextBoxID]` are all gone.
          *Drawing is unchanged and that was DEMONSTRATED, not argued:* both
          templates resolve to the same generated layout records the wrapper
          used, and forcing the Safari box as a probe makes `battle_menu` fail
          with **32 tilemap cell mismatches** — so the scenario genuinely
          observes this box, and its PASS means the normal path is untouched.
          `DrawBattleMenuBox` is NOT dead: `DrawBattleMenu` still uses it for
          the non-interactive DEBUG dump harness.
        * `:2151` / `:2184` — **DONE 2026-08-12. `DisplayBattleMenu` is now 6 of
          pret's 6 Safari sites.** The Safari cursor columns, plus the ball
          counter both arms print (`PrintNumber` at pret `hlcoord 7,14`), which
          closed a FOURTH faithdiff finding (calls matched 12 → 13).
          Three layout records were added to the sidecar and regenerated rather
          than hand-written — `SAFARI_CUR_L` (gb 1 → col 11), `SAFARI_CUR_R`
          (gb 13 → col 23) and `SAFARI_BALLS` (gb 7 → col 17), all row 14 → 17.
          Verified additive: no existing record's offset changed.
          *Flag trap, same family as the others:* pret loads the blank tile into
          A **before** the branch (`cp BATTLE_TYPE_SAFARI / ld a, ' ' / jr z`),
          and `PrintNumber` clobbers BH/BL — which is why pret sets the top-item
          X **after** the call, not before. Both orders are preserved.
          *Non-vacuity:* pointing the left column at the Safari column makes
          `battle_menu` fail on exactly 2 tilemap cells (the cursor cells), so
          the scenario observes them and its PASS means the normal path is
          untouched.
- [x] Add one must-hit scenario per battle type, comparing the relevant menu,
      WRAM state, item/event result, and exit. Add live traversal only when its
      owning overworld story batch lands.
      - **CLOSED 2026-08-14. ALL FIVE TYPES NOW HAVE BOTH HALVES.**
        | type | menu | result/exit |
        |---|---|---|
        | NORMAL (0) | `battle_menu` + the battle tier | `ball_catch` (20), `battle_faint` (33) |
        | OLD_MAN (1) | `battle_oldman` (69) | `battle_oldman_result` (79) |
        | SAFARI (2) | `battle_safari` (71) | `battle_safari_result` (81) |
        | RUN (3) | `battle_run_type` (82) | `battle_run_type` (82) |
        | PIKACHU (4) | `battle_pikachu` (70) | `battle_pikachu_result` (80) |
      - **The `BATTLE_TYPE_RUN` blocker recorded below was a MISDIAGNOSIS, and
        naming it precisely is the finding.** It read "blocked on cross-emulator
        staging — a new mGBA entry method must set the type before StartBattle's
        special-battle decision". Measured: the earlier attempt pinned
        `wBattleAndStartSavedMenuItem`, but pret's `.handleUnusedBattle` reads
        **`wCurrentMenuItem`** (`core.asm:2257`). The pin could never select
        RUN, so the arm did exactly what pret does for every OTHER selection —
        print "Hurry, get away!" and redraw the menu forever. It presented as a
        staging failure and was a wrong-variable failure; ordinary key presses
        fix it and no menu pin is needed at all.
        * Two facts, read out of pret, made it buildable. **RUN reaches the SAME
          loop as SAFARI** (`.checkAnyPartyAlive` sends it to `.specialBattle`,
          which falls into `.displaySafariZoneBattleMenu` because `wBattleType`
          is non-zero), so the port gate enters through the trampoline
          `battle_safari_result` added — generalised to two consumers with a
          `%define` helper, since NASM `%ifdef` has no OR. And **it is RNG-free**:
          `TryRunningFromBattle` tests `cp BATTLE_TYPE_RUN / jp z, .canEscape`
          before the speed comparison and before `Random`.
        * Navigation from `core.asm:2215-2217`: `wCurrentMenuItem` is ROW plus 2
          in the RIGHT COLUMN, so RUN is item 3 — DOWN then RIGHT.
        * PASS: TILEMAP OK (360 cells), VRAM OK, OAM OK, WRAM OK (13 regions, 0
          skipped); 68 masked hits, all three PRE-EXISTING shared families.
          Measured on the port before any golden existed: tilemap row 17 reads
          `86 AE B3 7F A0 B6 A0 B8 7F B2 A0 A5 A4 AB B8 E7` = "Got away safely!".
        * **NON-VACUITY IS THE WEAKER NO-DUMP KIND, stated rather than dressed
          up as a divergence count.** Changing `.handleUnusedBattle`'s compare
          from 3 to 2 makes `goldencheck` fail with `no GBSTATE.BIN in image`.
          That is correct here — breaking the arm means the port cannot reach
          the landmark — and it is NOT the `goldencheck-timeout-looks-like-a-crash`
          ambiguity, because the unsabotaged build of the same image dumps at
          frame 5868 and the two builds differ by one immediate byte.
        * **LIMITATION, recorded rather than glossed:** the scenario proves the
          RUN arm is reached and escapes, but does NOT pin WHICH menu item
          triggered it — `wCurrentMenuItem` is not a dumped region, so a port
          that escaped on any item would also pass.
      - **FOUR OF FIVE TYPES NOW HAVE ONE (2026-08-12):** NORMAL (`battle_menu`
        and the rest of the battle tier), OLD_MAN (`battle_oldman`, id 69),
        SAFARI (`battle_safari`, id 71, RENDERED) and PIKACHU (`battle_pikachu`,
        id 70). All pass; registry 69.
      - **`BATTLE_TYPE_RUN` (3) has no scenario and is the honest remainder.**
        Its `.handleUnusedBattle` arm is now TRANSLATED (2026-08-12) — that was
        the DROPPED `BattleMenu_RunWasSelected` faithdiff reported on
        `DisplayBattleMenu`, and closing it took the routine to 14/17 matched
        calls. But the type is unused in the shipped game and nothing sets it,
        so the arm is faithful and unreachable, exactly like the Safari
        branches were before `battle_safari`.
        * **BLOCKED 2026-08-13 on cross-emulator staging, not implementation.**
          The port-only probe reaches its forced-escape checkpoint and writes
          both GBSTATE.BIN and DUMP.BIN. The matching mGBA attempt continuously
          wrote `wBattleType=3` and the saved RUN item after `enter_wild()`, but
          never observed `wEscapedFromBattle` in 3600 frames. Do not register a
          one-sided scenario: a new mGBA entry method must set the type before
          StartBattle's special-battle decision, rather than racing the menu.
      - Still owed even for the four covered types: the box asks for the
        item/event RESULT and EXIT as well as the menu, and none of the three
        new scenarios follows the battle to its end.
        * **CONFIRMED 2026-08-14, not assumed:** `battle_oldman`,
          `battle_pikachu` and `battle_safari` all carry
          `must_hit: [RunBattleTest, DisplayBattleMenu]`, and the first two are
          `datastruct`/`wram`-only. None goes past the menu. This half is
          **unstarted work, NOT blocked** — an earlier summary of this plan
          called all five open boxes "blocked", which was wrong.
      - **RESULT/EXIT WITNESS DESIGNED 2026-08-14 (specified, not yet built).**
        The tutorial types are the tractable target because their terminal state
        is *distinctive*, so the scenario proves a branch rather than just
        reaching an end:
        * **The path**, read out of pret: `DisplayBattleMenu.doSimulatedMenuInput`
          (`core.asm:2101`) draws the fake cursor moves and ends
          `ld a,$2 / jp .upperLeftMenuItemWasNotSelected` — it auto-selects
          ITEM. `:2303` then routes OLD_MAN/PIKACHU to `.simulatedInputBattle`,
          which points `wListPointer` at `SimulatedInputBattleItemList` and
          throws the ball.
        * **The distinctive terminal:** `ItemUseBall` at
          `item_effects.asm:529-532` sends BOTH tutorial types to
          `.oldManCaughtMon`, which prints the caught text and **skips giving
          the player the mon** — no `IndexToPokedex`, no party add.
        * **So the comparison is strong:** at `wBattleResult == 2` (the same
          landmark `ball_catch` already polls), compare `wPartyData` and
          `wPokedex` **UNCHANGED**, `wBagItems` with the ball consumed, and
          `wBattleResult`. A port that wrongly took the normal catch path would
          hand the player a WEEDLE and fail on party + dex.
      - **LANDED 2026-08-14 — `battle_oldman_result` (id 79), the first witness
        of a battle type's RESULT rather than its menu.** `goldencheck` PASS,
        WRAM clean (12 regions). Registry 77. Getting there took four measured
        corrections, and TWO OF THEM OVERTURNED CLAIMS MADE EARLIER THE SAME DAY
        in this very box:
        * **`wBattleResult` IS the landmark.** The "it is not" note below was
          wrong REASONING, not a wrong measurement: the compare sat on the
          fall-through side of `jc` and never executed. pret's
          `UseBagItem.returnAfterCapturingMon` (`core.asm:2393-2399`) sets
          `wBattleResult = 2` and `scf` together.
        * **The carry return is FAITHFUL — there was no divergence to settle.**
          pret's `.displaySafariZoneBattleMenu` is
          `call DisplayBattleMenu / ret c`, so a capture exits early on hardware
          too; the SAFARI tail is reached only when carry is CLEAR. The
          "unsettled fidelity question" recorded below dissolved on measurement.
        * **The reference must DRIVE THE TEXT.** With no A-taps it sat on
          "All right! / PIDGEY was caught!" for 3600 frames and `wBattleResult`
          never left 0 — `battle_oldman` never needed input because it dumps
          inside the menu.
        * **Both sides must land POST-TEARDOWN, and the pins must STOP at
          resolution.** Re-asserting `wBattleType` and enemy HP past
          `EndOfBattle` re-created state the flow had just torn down; it showed
          up as exactly those fields, in BOTH directions as the pin was moved
          from one side to the other. This scenario pins the enemy with SLEEP
          ONLY — `battle_oldman`'s 65535-HP pin outlives the battle here.
      - **SAFARI's RESULT/EXIT — THE BLOCKER IS CLEARED 2026-08-14
        (`42ee0a359`). What remains is ordinary scenario work, not a capability
        gap.** The blocker was measured with four in-WRAM markers in ONE build:
        production's `_InitBattleCommon.specialBattleLoop` — which holds the
        WHOLE Safari turn tail (out-of-balls exit,
        `PrintSafariZoneBattleText`, the flee roll) — was entered by no
        scenario, because `battle_safari`'s gate calls `DisplayBattleMenu`
        directly. A result gate written the way the tutorial gates are would
        have witnessed the gate's logic instead of the port's.
        * **The fix is a harness-only TRAMPOLINE**, `%ifdef`-gated on
          `DEBUG_BATTLE_SAFARI_RESULT`, exporting pret's own label name
          (`StartBattle_displaySafariZoneBattleMenu`) and jumping into the loop
          from outside the routine. `DEVIATION{class=temporary}`; its lifetime
          is `RunBattleTest` entering battles through `_InitBattleCommon`
          instead of replicating its intro, which stays the real fix.
        * **IT MUST BE A TRAMPOLINE, MEASURED NOT CHOSEN.** A `global` label
          written above `.specialBattleLoop` becomes the local-label PARENT for
          the rest of the routine; every following `.local` re-parents and NASM
          fails with 18 `changed during code generation` errors on labels as far
          away as `CopyUncompressedPicToHL`. Second instance of that NASM trap
          in this plan.
        * **The flee is made RNG-FREE rather than seeded.** The tail's first
          decision is `ld a,[wEnemyMonSpeed+1] / add a / jp c, EnemyRan`, so a
          speed LOW byte above 127 runs BEFORE `Random` is called. The gate pins
          `wEnemyMonSpeed+1 = $80` immediately before the call (staged earlier
          it is overwritten by the enemy load).
        * **MEASURED, decomposed:** the gate now dumps where it previously hung
          for the full 150 s with no dump at all. Tilemap row 17 reads
          `96 a8 ab a3 7f 8f 88 83 86 84 98` = "Wild PIDGEY", row 19 reads
          `b1 a0 ad e7` = "ran!" — `WildRanText`, printed by `EnemyRan`, which
          is reachable here only through the menu -> bait -> flee roll. Enemy
          speed reads `00 80`, so the pin took.
        * **The A pulses are load-bearing, not padding:** with only RIGHT+A the
          bait tail parks in `WaitForTextScrollButtonPress` and the run hangs.
          `AUTOKEY_SAFARI` carries eight.
        * **LANDED SAME DAY — `battle_safari_result` (id 81), `e96f765cd`.
          PASS on the first check**: TILEMAP OK (360 cells), VRAM OK (384
          slots), OAM OK (40 entries), WRAM OK (13 regions, 0 skipped). The 64
          masked hits are the three PRE-EXISTING shared battle families only —
          no new mask was added for it.
          * **LANDMARK: the enemy pic GONE *and* "ran!" on the tilemap.** Both
            halves are required: "ran!" alone fires during `PrintText`, BEFORE
            pret's `jpfar AnimationSlideEnemyMonOff` tail, at which instant the
            two sides disagree about the pic band by construction. Together they
            are true only after `EnemyRan` has run to its end — exactly where
            the port's gate returns.
          * **NON-VACUITY:** reverting only the `AnimationSlideEnemyMonOff` tail
            fails it with **exactly 49 unmasked tilemap divergences**, all in the
            7x7 block at GB(12,0) (`(0,12) want $7F got $00`, …). Reverted
            before the gates ran.
          * The gate-ordering rule bit as predicted and was handled: the entry
            carries THREE `build_flags` tokens against `battle_safari`'s two, so
            the registry chain puts `DEBUG_BATTLE_SAFARI_RESULT` at line 15 and
            `DEBUG_BATTLE_SAFARI` at line 31. The pre-registration dump reported
            `scenario_id 71`, which is that collision showing up early.
          * Trap banked, cost one golden generation: `navigate.tilemap()` reads
            through the coroutine and must NOT be called inside a
            `scenario.exec` thunk — "attempt to yield from outside a coroutine".
        * **AND IT PAID FOR ITSELF IMMEDIATELY — see `6070684b0`.** Executing
          the tail for the first time exposed four dropped pret behaviours in
          `EnemyRan`, all hidden behind a comment asserting the routine was a
          link-only safety path. That comment was measurably false; the SAFARI
          flee reaches `EnemyRan` in single player.
      - **NORMAL IS ALREADY COVERED — measured 2026-08-14, so DO NOT build a
        third scenario for it.** The box's result/exit ask is satisfied for
        BATTLE_TYPE_NORMAL by two existing scenarios, one per way a normal
        battle resolves: `ball_catch` (id 20) asserts `wBattleResult == 2` and
        runs the real `EndOfBattle` before dumping (the CAPTURE result, must_hit
        `UseBagItem`/`UseItem`), and `battle_faint` (id 33) covers the KO result
        (must_hit `HandleEnemyMonFainted`/`FaintEnemyPokemon`/`GainExperience`).
        The remaining result/exit work is SAFARI only, plus BATTLE_TYPE_RUN
        which has no scenario at all.
      - **SAFARI RESULT DESIGNED 2026-08-14, AND IT IS RNG-FREE — the recipe
        does NOT transfer, but a better landmark exists.** `battle_safari`
        (id 71) calls `DisplayBattleMenu` and then parks in a `DelayFrame` loop,
        so it never takes a turn; the flee roll has never been witnessed.
        * The tutorials' `wBattleResult == 2` landmark does not apply: a SAFARI
          capture goes through the party/box-full checks
          (`item_effects.asm:117-130`) that the tutorial types skip, so with the
          seeded 6-mon party the caught mon lands in the BOX.
        * **THE DETERMINISTIC EXIT IS THE LANDMARK.** pret's safari tail reads
          `ld a,[wEnemyMonSpeed + 1] / add a / jp c, EnemyRan` — "if
          (enemy speed % 256) > 127, the enemy runs" — **with no roll at all**;
          the RNG comparison is only reached when that carry is clear.
        * Measured: the spec PIDGEY's speed is **21**, so it does NOT take that
          path by default. Pinning `wEnemyMonSpeed + 1` to >= `$80` on BOTH
          sides forces it, which is the same "RNG-independence BY MATCHUP" move
          `battle_faint` and `battle_blackout` already use.
        * **THE BUILD SHAPE IS NOT THE TUTORIALS' — measured 2026-08-14, and
          this rules out the obvious approach.** The port's Safari turn/flee
          tail is ALREADY IMPLEMENTED IN PRODUCTION, faithfully, inside
          `_InitBattleCommon` (`init_battle.asm:566-602`): the out-of-balls
          text, `PrintSafariZoneBattleText`, the `add al,al / jc EnemyRan`
          deterministic exit, the bait `srl b` pair, the escape-factor `sla b`
          with its $FF cap, and the `Random`/`cp b` comparison — all present.
          * **So the gate must DRIVE production, not replicate it.** The
            tutorial RESULT gates work by re-running pret's menu loop inside the
            gate body (`.oldManMenuLoop`), which is fine there because the loop
            IS the battle. Doing that for SAFARI would put the GATE's copy of
            the flee tail under test instead of the port's — a false witness of
            exactly the kind this plan keeps catching.
          * **The right shape is the ANIMATION-scenario one:** put the
            checkpoint INSIDE the production routine — `EnemyRan` — under the
            new flag, and let `_InitBattleCommon`'s `.specialBattleLoop` drive.
            In such a build every `EnemyRan` entry is the Safari one, so the
            landmark needs no discriminator.
          * **THE PRESS GEOMETRY IS NOW MEASURED (2026-08-14), read off
            `battle_safari`'s golden tilemap rather than guessed:**
            ```
            row 14 |?>BALL???.....BAIT.?|   cursor $ED at col 1 on open
            row 16 |?.THROW.ROCK..RUN..?|
            ```
            So BALL is already selected and ONE `PAD_RIGHT` reaches BAIT.
            **BAIT, NOT BALL, is the correct selection:** a Safari ball attempts
            a CATCH, which is a roll, and a successful catch exits before the
            flee tail ever runs. Bait takes the turn with no catch attempt, so
            the speed-pinned `jc EnemyRan` is guaranteed to be the exit.
          * **BUT THE BUILD IS BLOCKED ON HARNESS SHAPE — probed and reverted
            2026-08-14, so this is measured, not predicted.** A full probe was
            written (staging speed pin, an `AUTOKEY_SAFARI` table doing
            RIGHT then A, and a checkpoint inside the production `EnemyRan`) and
            it **TIMED OUT at 150 s with no dump at all**.
            * **Cause: `DEBUG_BATTLE_SAFARI`'s gate body ends in a deliberate
              infinite hang** — `call DisplayBattleMenu` then
              `.goldensafarihang: call DelayFrame / jmp .goldensafarihang`. A
              RESULT variant that defines that flag inherits the hang, so the
              turn is never taken.
            * **And the port's Safari tail is NOT reachable from a gate:** it
              lives INSIDE `_InitBattleCommon` as the local
              `.specialBattleLoop` (`init_battle.asm:566-602`), so a gate body
              cannot call it. `RunBattleTest` does enter via `InitBattle`, but
              by the time the gate body runs, control has already returned.
            * **THREE FOLLOW-UP EXPERIMENTS, 2026-08-14 — two unknowns closed,
              one left. All reverted; the tree carries none of them.**
              1. **The presses reach the menu and the geometry is right.**
                 Giving the EXISTING safari gate the `PAD_RIGHT` table and
                 photographing frame 420 shows the cursor moved:
                 `|?.BALL???....>BAIT.?|`. So `PAD_RIGHT` does select BAIT on
                 the port, exactly as the golden's layout predicted.
              2. **The A press IS consumed and `DisplayBattleMenu` DOES
                 return.** A frozen menu at frame 900 was consistent with both
                 "A never consumed" and "A consumed, gate hung with the menu
                 still drawn", so a marker byte was written after the call:
                 `W_TILEMAP[0]` reads `$EE`, so the call returned. The earlier
                 timeout was therefore NOT a press failure.
              3. **RECONCILED — the gate body is DEAD CODE for this battle
                 type.** An entry marker written at the top of the
                 `DEBUG_BATTLE_SAFARI` gate body stays UNWRITTEN (`$7F`, not the
                 `$AA` it writes) under the stock config. So production's
                 `.specialBattleLoop` blocks in its own `DisplayBattleMenu` and
                 control never reaches the gate; `battle_safari` (71) works
                 purely because AutoKeyDrive's timer dump fires while production
                 is blocked. **A RESULT gate must therefore NOT add a menu loop
                 — production already drives it.**
              4. **AND THAT DIAGNOSED THE FIRST PROBE'S TIMEOUT: the speed pin
                 was in the wrong place.** Staged before `InitBattle`, the
                 enemy load overwrites it (the spec PIDGEY's speed is 21), so
                 the deterministic branch is never taken and the RNG comparison
                 runs instead. Moving the pin to `.specialBattleLoop`'s entry
                 puts it after the load and on every iteration.
              5. **STILL BLOCKED, and the pin was NOT the whole story.** With
                 the pin correctly placed, a second probe (press table +
                 `EnemyRan` checkpoint) **still timed out at 150 s with no
                 dump**. Since `PAD_RIGHT`/`PAD_A` are confirmed to reach and
                 return from `DisplayBattleMenu`, and the pin now survives the
                 load, the remaining failure is that **the BAIT selection is not
                 registering a taken turn** — production loops back to
                 `.specialBattleLoop` instead of falling through to the flee
                 tail. The next step is to instrument
                 `wActionResultOrTookBattleTurn` around the bait item-use path
                 rather than to keep adjusting presses.
              6. **RESOLVED 2026-08-14 BY A SINGLE-BUILD, FOUR-MARKER PROBE —
                 AND IT CORRECTS TWO EARLIER ENTRIES BELOW.** Both
                 `DisplayBattleMenu` call sites were marked in ONE build, with
                 the markers in `wPokedexOwned` scratch (a dumped region nothing
                 in this flow writes) rather than the tilemap:
                 | marker | value | meaning |
                 |---|---|---|
                 | production, before call | `$FF` untouched | **never reached** |
                 | production, returned | `$FF` | — |
                 | gate body, before call | `$33` | **reached** |
                 | gate body, returned | `$44` | **returned** |
                 * **THE GATE BODY IS LIVE, NOT DEAD CODE.** The earlier
                   "dead code" reading was an ARTEFACT of the marker location:
                   it was written into the tilemap margin, and
                   `LoadScreenTilesFromBuffer1` restores the WHOLE 40x25 canvas
                   from `screen_save`, wiping it. Probe markers must live in a
                   dumped WRAM region nothing in the flow writes — the tilemap
                   is not such a place, and neither is `wLoadedMon +33..43`,
                   which `DrawPlayerHUDAndHPBar` copies into.
                 * **PRODUCTION'S `.specialBattleLoop` IS NEVER REACHED under
                   the golden harness.** So the port's real Safari turn/flee
                   tail — the `jc EnemyRan` deterministic exit and everything
                   after it — is not executed by ANY scenario, and cannot be
                   while `RunBattleTest` drives the battle this way.
                 * **CONSEQUENCE FOR THE BOX:** a SAFARI result scenario built
                   on the gate body would witness the GATE's logic, not the
                   port's. The box is blocked on a HARNESS capability —
                   `RunBattleTest` needs a path that enters
                   `_InitBattleCommon`'s special-battle loop and lets it run —
                   not on scenario design, press geometry or the speed pin, all
                   of which are already correct and recorded above.
              7. **SUPERSEDED — the contradiction recorded here was the marker
                 artefact above, now explained:** Two experiments
                 disagree about whether the gate body runs:
                 * With **no presses** (stock `AUTOKEY_QUIET`), an entry marker
                   in the gate body stays UNWRITTEN -> production blocks in its
                   own `DisplayBattleMenu` and the gate body is dead code.
                 * With **presses** (`AUTOKEY_SAFARI`), a marker AFTER the gate
                   body's `DisplayBattleMenu` DOES fire -> the gate body ran,
                   so production's loop must have exited first.
                 Those reconcile IF the presses let production's loop finish and
                 return. **But the direct test of that refutes it:** a probe that
                 dumps UNCONDITIONALLY on both the carry and no-carry paths
                 immediately after production's `DisplayBattleMenu`, with the
                 same presses, **times out with no dump at all** — i.e.
                 production's `DisplayBattleMenu` appears never to return, which
                 the second experiment says it must.
                 * All three probes are reverted; the tree carries none of them.
                 * **The next person should start by re-establishing which
                   `DisplayBattleMenu` is which** — most cheaply by giving the
                   two call sites DISTINCT markers in a SINGLE build, rather
                   than comparing markers across builds with different flags, as
                   was done here. Comparing across configurations is very likely
                   what produced the contradiction.
              7. **SUPERSEDED — the earlier open question:**
                 `.specialBattleLoop` is PRODUCTION (`init_battle.asm:556`) and
                 calls `DisplayBattleMenu` itself, and the debug gate body calls
                 it AGAIN afterwards. With `AUTOKEY_QUIET` production's loop
                 would block there and the gate body would never run at all,
                 which suggests the gate body may be dead code for this type;
                 but the marker in experiment 2 fired, so the gate body's call
                 DID return. Those two facts are not yet reconciled, and the
                 reconciliation decides whether a RESULT gate should drive
                 production or replace it.
              * **Do not rebuild the probe until (3) is settled** — the press
                table and the speed pin are correct and lift straight back in,
                but a gate that races production for the same input is exactly
                how a scenario ends up witnessing the harness instead of the
                port.
      - **PIKACHU DONE TOO — `battle_pikachu_result` (id 80), 2026-08-14.** The
        recipe applied cheaply: the gate is the OLD_MAN pattern with the
        65535-HP pin `%ifndef`'d out, the rename dump compiled out, the same
        `wBattleResult == 2` / post-teardown landmark, and the reference is
        `battle_oldman_result` with ONE constant changed
        (`BATTLE_TYPE_PIKACHU = 4`). Both traps already recorded — the HP-pin
        guard and the 2-token `build_flags` ordering — carried over and cost no
        cycles. `goldencheck` PASS, WRAM clean (12 regions).
        * **ITS GOLDEN IS BYTE-IDENTICAL TO `battle_oldman_result`'s, AND THAT
          NEARLY MADE IT WORTHLESS — so it was tested, not argued.** Hardware
          reaches the same terminal state for both tutorial types once the name
          is restored, so a lazy read makes id 80 a duplicate occupying a suite
          slot. **Proved distinct by measurement:** sabotaging ONLY the PIKACHU
          arm of `ItemUseBall`'s tutorial check makes **id 80 FAIL while id 79
          still PASSES**. The goldens coincide; the PORT paths do not, and only
          80 discriminates. Recorded in the manifest so the identical goldens are
          never mistaken for redundancy.
        * **SENSITIVITY IS REAL BUT NOT WHAT WAS DESIGNED — measured.** Forcing
          the port to skip `.oldManCaughtMon` makes the scenario FAIL, on
          **`wEnemyMon party pos, want $00 got $0D`**. `wPartyData` MATCHED
          under that sabotage, so the sabotaged port did not actually gain a
          party mon: the discriminator is the enemy party-position field, not
          the party/dex pair the design predicted. The manifest records what
          fired, not what was expected.
        * **PROBED 2026-08-14, AND THE DESIGN ABOVE IS PARTLY WRONG — three
          measured corrections (SUPERSEDED by the four above; kept because two
          of them were themselves wrong and that is the lesson).** A `DEBUG_BATTLE_OLDMAN_RESULT` gate was built
          and run (`run_headless`), and it settles more than it opens:
          1. **`wBattleResult` is NOT this battle's landmark.** It lives at
             `$CF0B`, is in no compared region, and the first version polling
             `== 2` never fired while the screen plainly read "PIDGEY was /
             caught!". The tutorial never takes `ball_catch`'s
             `.returnAfterCapturingMon`.
          2. **THE PORT'S TUTORIAL IS CORRECT, and this is the first time that
             has been OBSERVED rather than assumed.** At the terminal instant:
             `wPartyData` count = **6** — the mon was caught and NOT given to
             the player, i.e. `ItemUseBall` really does take `.oldManCaughtMon`;
             and `wPlayerName` = `91 84 83 50…` = "RED" **restored**, so the
             Missingno-pair restore half ran and erased the rename.
          3. **AN UNSETTLED FIDELITY QUESTION BLOCKS REGISTRATION.** The port
             reaches that instant because `DisplayBattleMenu` returns **CARRY**
             (pret's "the player ran") after the scripted throw. pret instead
             routes EVERY non-zero `wBattleType` past the menu loop into the
             **SAFARI tail** (`core.asm:182+`: `wNumSafariBalls`,
             `PrintSafariZoneBattleText`, the enemy-run rolls). Whether the
             port's early carry return is faithful is unresolved, and **a golden
             built on an unfaithful exit would pin the divergence in place** —
             so the gate is kept as documented, UNREGISTERED groundwork and id
             79 stays reserved. Settle the carry question first.
        * **Build it as a NEW scenario (id 79 reserved), not by moving
          `battle_oldman`'s dump point** — the menu witness it provides today is
          what caught the `.oldManName` ROM-tail bytes, and scenario-local
          regions are cheap (see `golden-scenario-local-region-is-cheap-shared-is-not`).
      - **MEASURED 2026-08-13 — THE COVERAGE IS THINNER THAN "FOUR OF FIVE
        TYPES" SUGGESTS, AND THE BOX'S OWN WORDING IS WHERE IT SHOWS.** The box
        asks for a scenario "comparing the relevant MENU". Of the **22** battle
        scenarios in the registry, only **3 compare the tilemap at all** —
        `battle_intro`, `battle_menu` and `battle_safari`. Eighteen are
        `class: datastruct` (WRAM only) and one (`battle_damage`) is
        `class: semantic` (damage oracle only).
        * **So `battle_oldman` and `battle_pikachu` do NOT compare the menus
          they were built for.** They pin WRAM — which is how they caught the
          `.oldManName` / `.profOakName` ROM-tail bytes, a real result — but no
          scenario has ever compared a rendered OLD_MAN or PIKACHU screen.
        * This is the same shape as the three witness gaps found 2026-08-12/13
          (the SLP status rule, `CenterMonName`, the level swaps): the scenario
          reaches the code and compares a surface where the defect cannot show.
          Recorded as a fourth instance in `bug-class-false-witness-scenario`.
      - **PROMOTING `battle_oldman` TO A RENDERED COMPARISON IS BLOCKED, and it
        is blocked on 4c, not on effort.** Measured directly: class flipped to
        `default` with `window (10,3)` + `oam_window`, manifest regions widened
        to `tilemap,vram,oam,wram`, then `goldencheck`. Result **120 unmasked
        divergences**, fully decomposed:
        * **6 tilemap cells** — GB col 2, rows 4-9, `want $6B | got $C8`. The
          `DuplicateEnemyHPBarTiles` gauge clone, i.e. the F-19 mask set
          `battle_menu` / `battle_safari` already carry. Deliberate design.
        * **13 tilemap cells** — GB rows 14 and 16, cols 1-7: hardware has
          BLANKS, the port has `Wild PI…` / `appeare…`. This is the missing
          `PrintBeginningBattleText`. pret prints the tutorial/beginning stream
          there; the port's `.specialBattleIntro` substitutes
          `DrawBattleIntroBox`, the wild-style box, which is exactly what the
          `DEVIATION{class=temporary}` in `init_battle.asm` records and what 4c
          retires.
        * **101 VRAM tile slots**, all in `$8000` (vChars0) — golden zero, port
          populated, i.e. the port has battle pic/anim patterns loaded where
          hardware does not at this frame. Same family as `battle_safari`'s
          documented `$8000-$87FF` mask, but NOT verified to be the same set.
        * **Not masked, deliberately.** Masking 13 cells of a known-missing
          routine plus 101 unverified VRAM slots to get a green tick is what
          the preamble forbids. The experiment was reverted in full;
          `battle_oldman` is green again on its `datastruct` config and the
          registry is untouched at 69.
        * **The order this implies: land `PrintBeginningBattleText` (4c) FIRST,
          then promote both special-battle scenarios to rendered.** At that
          point the only expected residue is the shared F-19 gauge mask.
        * `battle_pikachu` was NOT measured. It shares
          `.specialBattleIntro`, so the same 13-cell text divergence is
          EXPECTED there — expected, not measured.
      - **THE THREE RENDERED SCENARIOS DO NOT WITNESS A MISSING HUD CLEAR
        EITHER (probed 2026-08-13).** Applying the break-it probe to this
        session's own `ClearScreenArea` restoration (`08558f48d`): both HUD
        clears deleted, rebuilt, then `battle_intro`, `battle_menu` and
        `battle_safari` re-run — **all three still PASS**. So nothing in the
        69-scenario suite can see that fix; it stands on the `run_headless` +
        golden-blob measurement recorded in its own commit, and the eight
        scenarios that commit lists are regression evidence only.
        * The first attempt at this probe silently did NOT apply (a literal
          matched 7 sites, not 2, and the guard assert caught it) — and the
          three passes it produced looked exactly like the real result. That is
          instance 2 of the false-witness class in miniature: **a probe that
          did not apply reads identically to a probe that found nothing.**
          Assert the edit landed before trusting the run.
      - **SIZING FOR THE NEXT STEP, so it is not restarted from scratch:
        translating `PrintBeginningBattleText` needs four things**, measured
        2026-08-13 — it is NOT a single-file translation.
        1. The mirror file `dos_port/src/engine/battle/common_text.asm`.
        2. ~~Five of its six text streams do not exist in the port.~~
           **THAT WAS WRONG — CORRECTED 2026-08-13, ALL SIX ALREADY EXIST.**
           `engine/battle/common_text.asm` has been in `gen_battle_text.py`'s
           `BATTLE_SRC` all along, and `assets/battle_text.inc` already defines
           `WildMonAppearedText`, `HookedMonAttackedText`, `EnemyAppearedText`,
           `TrainerWantsToFightText`, `UnveiledGhostText` and
           `GhostCantBeIDdText`. **Nothing is owed here.**
           * The wrong claim came from grepping the pret FAR-STREAM names
             (`_WildMonAppearedText`, leading underscore). The generator
             FLATTENS `text_far _X` into a stream emitted under the WRAPPER
             name `X`, so the underscore form never survives into the port and
             a grep for it finds nothing while the data is present. Grep the
             wrapper name, or `grep -c '^Label:' assets/battle_text.inc`.
           * Proven by trying it: adding `common_text.asm` to `BATTLE_SRC`
             produced a DUPLICATE entry and **0 new labels** — the generator
             still reported exactly 146, before and after. That null result is
             what exposed the error; it was then reverted.
        3. `DrawAllPokeballs` is `missing` and is the recorded pokeballs
           forked-name debt (blocked on the shadow-OAM publish design). It is
           reached only on the `wBattleType == 0` arm, so the SPECIAL-battle
           path this box needs does not touch it — but a faithful whole-routine
           translation does.
        4. `IsPlayerPikachuAsleepInParty` is a `stub`, on the
           `BATTLE_TYPE_PIKACHU` arm.
        Everything else it calls is translated (`IsItemInBag`, `PlayCry`,
        `PrintText`, `DelayFrames`, `LoadEnemyMonData`, `PlayPikachuSoundClip`,
        `PlaySound`, `WaitForSoundToFinish`, `MarowakAnim`), and every constant
        it needs resolves except `SILPH_SCOPE`, which is not yet in the port's
        includes.
      - **THE REAL COST IS THE WIRING, NOT THE TRANSLATION — measured
        2026-08-13, and it is why this was not started this iteration rather
        than half-done.** pret calls `PrintBeginningBattleText` once, as the
        tail of `SlidePlayerAndEnemySilhouettesOnScreen`, and it covers all
        three cases (wild / trainer / special). The port instead has THREE
        separate call sites in `_InitBattleCommon` — `DrawBattleIntroBox` on
        the wild and special arms and `DrawEmptyDialogBox` on the trainer arm.
        * `DrawBattleIntroBox` is not a thin wrapper: it HAND-DRAWS the bottom
          dialog box into `W_TILEMAP` at stride 40 (corners, walls, interior
          fill) and then prints. pret's path draws its box through `PrintText`
          and the msgbox projection. Substituting one for the other is a
          mechanism change on the battle intro, so it WILL move
          `battle_intro` / `battle_menu` / `battle_safari` — the only three
          scenarios that compare a tilemap.
        * **TRANSLATED 2026-08-13, DELIBERATELY NOT WIRED — and that reverses
          the recommendation this bullet used to carry.** The routine is in the
          mirror `dos_port/src/engine/battle/common_text.asm` (appended to the
          existing `RetreatMon` half of that file), `missing` -> `translated`,
          faithdiff **11 pret / 11 port, 10 matched**. The single ADDED/DROPPED
          pair is `DrawAllPokeballs` -> `DrawBattlePokeballs`, carrying its own
          `DEVIATION{class=stub}` — the pokeballs forked-name debt. Stores 3/3
          matched.
        * **`PrintBeginningBattleText` HAS 0 PORT CALLERS. That is the exact
          state that hid `SwapPlayerAndEnemyLevels`, and it is accepted here
          only because the wiring turned out to be a RECONCILIATION rather than
          a substitution** — which was not visible until pret's side was read
          line by line: pret reaches it from the
          `SlidePlayerAndEnemySilhouettesOnScreen` tail and then runs
          `PrintText(.emptyString)` + `SaveScreenTilesToBuffer1` + `ClearScreen`
          + a vBGMap0/vBGMap1 dance + `LoadScreenTilesFromBuffer1` + two
          `ClearScreenArea`s, while the port's `_InitBattleCommon` runs
          `DrawBattleIntroBox` -> `SaveBattleScreen` -> `DrawBattlePokeballs`
          -> `WaitForAPress`. pret draws the ball row INSIDE
          `PrintBeginningBattleText`; the port draws it after its screen
          snapshot. Those two orders cannot be swapped one call at a time.
        * **THE WIRING WAS ATTEMPTED 2026-08-13 AND DELIBERATELY REVERTED.
          The gate this bullet recommended does not work, and finding out why
          is the important result.** The change was made — `_InitBattleCommon`
          calling `PrintBeginningBattleText` in place of `DrawBattleIntroBox` /
          `DrawEmptyDialogBox` / `DrawBattlePokeballs` / `WaitForAPress`; it
          built, and `battle_intro`, `battle_menu` and `battle_safari` all
          PASSED with `battle_intro` reporting `TILEMAP: OK (360 cells)`.
          **That green is worthless, and here is the decomposition.**
        * **`battle_intro`'s harness NEVER ENTERS `_InitBattleCommon`.**
          `RunBattleTest` (`debug_dump.asm:2233-2236`) hand-rolls the intro:
          `LoadFrontSpriteByMonIndex` -> `LoadPlayerBackPic` ->
          `SlideBattlePicsIn` -> `DrawBattleIntroBox`. It calls
          `DrawBattleIntroBox` DIRECTLY, so it was still measuring the routine
          the change was replacing. Instance 3 of
          `bug-class-false-witness-scenario` — the harness duplicates
          production — and it applies to all three rendered scenarios.
        * **The scenarios that DO enter `_InitBattleCommon` cannot see a
          tilemap.** `trainer_battle_route`, `trainer_battle_init`,
          `trainer_battle_win`, `trainer_battle_loss` and `battle_blackout`
          all drive the live path and are all `class: datastruct`, WRAM only.
          All five pass, and none of them can observe an intro redraw.
        * **So NO scenario in the 69-scenario suite can witness a change to
          the battle intro.** Landing a rewrite of every battle entry in the
          game on that basis is exactly the failure this plan keeps
          documenting, so it was reverted rather than committed green. The
          translation stays (it is committed, faithdiff-clean and honestly
          labelled as having 0 callers).
        * **THE WITNESS NOW EXISTS — built 2026-08-13 in two steps, and step 2
          produced the real diagnosis.**
          * **Step 1 LANDED (`d6574e31c`).** The staging's
            `LoadPlayerBackPic` + `SlideBattlePicsIn` pair is exactly
            `SlidePlayerAndEnemySilhouettesOnScreen`, so it now calls that
            shared routine. Verified non-vacuous: callers 2 -> 3, with
            `RunBattleTest` joining the two `_InitBattleCommon` sites. A no-op
            today, and from now on the harness tracks the routine instead of
            re-deriving it.
          * **Step 2 was built, MEASURED, and reverted.** Giving the slide
            pret's `jmp PrintBeginningBattleText` tail and deleting both the
            harness's and production's `DrawBattleIntroBox` **made the three
            rendered scenarios FAIL — which is the proof the witness works**,
            since last iteration the identical change passed all three.
          * **FINDING 1 — the port's intro box is PROMPTLESS and pret's is
            not.** `battle_intro` did not fail on a comparison: it TIMED OUT
            with no dump at all. Its harness dumps INLINE, and the faithful
            path blocks on the text stream's own prompt, so the dump is never
            reached. `battle_menu` and `battle_safari`, which are frame-driven
            (`AUTOKEY_DUMP_FRAME=300`), got through and compared normally.
            The harness already documented the gap without naming it — it
            POKES a fake `▼` at GB (16,18) because "the port box prints
            instantly, promptless". So the wiring FIXES a real fidelity gap
            and `battle_intro` needs a frame-based dump before it can land.
            * **THAT PREREQUISITE IS NOW DONE (2026-08-13).** `battle_intro`'s
              dump is FRAME-DRIVEN: the harness parks in a `DelayFrame` loop
              and `AutoKeyDrive` photographs it at `AUTOKEY_DUMP_FRAME=300`,
              the same frame `battle_menu` and `battle_safari` use. Flags
              synced in the Makefile gate, `scenario_manifest.json` and
              `golden_diff.SCENARIOS` (`validate_scenarios` cross-checks the
              last two: 70 consistent).
            * **IT IS A MEASURED NO-OP on the compared surface**, which is the
              result that lets it land ahead of the wiring: `TILEMAP: OK (360
              cells)`, VRAM/OAM/WRAM OK, **59 masked divergences — identical to
              the pre-change baseline**, golden untouched. 300 frames of
              hanging changed nothing.
            * **NON-VACUITY, and it reproduces the wiring symptom in
              miniature:** replacing the loop's `call DelayFrame` with a bare
              spin makes the scenario TIME OUT with **no `GBSTATE.BIN` at
              all** — `AutoKeyDrive` runs from the `DelayFrame` pipeline
              (`src/home/vblank.asm:183`), not the joypad ISR. Probe reverted.
            * What this does NOT do is make the intro wiring landable on its
              own — FINDING 2 below (the `SaveBattleScreen` interaction) is
              untouched and is still the remaining design work.
          * **FINDING 2 — the screen-save interaction, not the text, is the
            hard part.** `battle_safari` came back with **133 unmasked
            divergences: 132 tilemap cells + 1 WRAM field**, VRAM and OAM both
            OK. The 132 are the port's canvas going BLANK (`got $7F`) where
            hardware has the enemy HUD — `PIDGEY`, `:L13`, the HP bar. So the
            new path changes what is on screen at `SaveBattleScreen` time, and
            a special battle's menu restores that snapshot via
            `LoadScreenTilesFromBuffer1`. Reconciling THAT is the remaining
            work, and it is design, not translation.
          * Step 2 reverted in full; `dos_port/src` is byte-identical to
            `d6574e31c` and `battle_intro` / `battle_safari` are green again.
        * Attempted and abandoned as impractical this iteration: bespoke
          runtime evidence. `run_headless` cannot stage the seed `.sav` those
          live scenarios need, and `goldencheck.sh` deletes its scratch dir on
          exit, so the port's own GBSTATE for a live battle is not reachable
          without harness work of its own.
        * Pre-existing annotation corrected in the same commit: the
          `DEVIATION{class=temporary}` at `init_battle.asm` had
          `evidence=PrintBeginningBattleText is label_status missing`, which is
          now false. Its evidence field records the reconciliation instead.

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
- [x] Add deterministic frame/state checkpoints for each selected transition and
      must-hit its selector plus animation body. Cover wild, trainer, dungeon,
      and scripted inputs; a final `FRAME.BIN` alone is regression evidence, not
      proof that the transition executed.
      - **THE STATIC HALF IS VERIFIED 2026-08-13 — the SELECTION is proven; the
        EXECUTION is not, and that is what still owes a scenario.** Five checks,
        each decomposed:
        1. **Bit positions identical.** `BIT_TRAINER_BATTLE_TRANSITION` 0,
           `BIT_STRONGER_` 1, `BIT_DUNGEON_` 2 — same as pret's `const_def`
           block (`engine/battle/battle_transitions.asm:67-71`). An off-by-one
           here would silently pick a different transition and NO faithdiff
           would see it, because the composition is arithmetic, not calls.
        2. **`BattleTransitions` table identical** — 8 entries, same routines,
           same order, including `Spiral` appearing at BOTH `%001` and `%011`.
        3. **`DungeonMaps1` / `DungeonMaps2` are BYTE-IDENTICAL TO THE ROM.**
           The port writes these as symbolic names resolved through the
           generated `assets/map_dims.inc`, so the source matching pret proves
           nothing — the RESOLVED bytes were compared against `pokeyellow.gbc`
           at `1c:4aa9` and `1c:4aae` (file offsets `0x070AA9` / `0x070AAE`).
           **12 of 12 constants plus both `$FF` terminators match**:
           VIRIDIAN_FOREST `33`, ROCK_TUNNEL_1F `52`, SEAFOAM_ISLANDS_1F `C0`,
           ROCK_TUNNEL_B1F `E8`; MT_MOON_1F `3B`, MT_MOON_B2F `3D`,
           SS_ANNE_1F `5F`, HALL_OF_FAME `76`, LAVENDER_POKECENTER `8D`,
           LAVENDER_CUBONE_HOUSE `97`, SILPH_CO_2F `CF`, CERULEAN_CAVE_1F `E4`.
           * NON-VACUITY: re-run with `SILPH_CO_2F` corrupted by one bit, the
             comparison reports exactly 1 mismatch (`port=0xCE rom=0xCF`). The
             zero is a real zero.
        4. **All three selectors faithdiff CLEAN** —
           `GetBattleTransitionID_WildOrTrainer`, `_CompareLevels`,
           `_IsDungeonMap`.
        5. **The dispatch composes faithfully.** `xor ebx, ebx` is pret's
           `ld bc, 0`; the three selectors set bits in BL (pret's `c`); the
           table index scales by 4 for the port's `dd` where pret double-adds
           for `dw`. `_CompareLevels` also preserves pret's unbounded
           all-fainted party scan, guarded at `BUG_FIX_LEVEL >= 2`.
      - **WHAT REMAINS IS EXACTLY WHAT THE BOX ASKS FOR AND IT IS NOT DONE:**
        a runtime checkpoint proving a given input actually EXECUTES the
        selected animation body. Static agreement on the selection tables and
        arithmetic is not that.
      - **THE FIRST RUNTIME CHECKPOINT LANDED 2026-08-13.**
        `wBattleTransitionSpiralDirection` (`$CD47`) is now a scenario-local
        dumped region on `trainer_battle_init` — the selector's OWN OUTPUT,
        written by `GetBattleTransitionID_CompareLevels` on every battle entry,
        so a live trainer entry pins it with no extra staging.
        * **Hardware says `01`** (inward spiral — the enemy is the stronger
          side at that entry) and the port agrees: `trainer_battle_init` PASSES
          with the row in place.
        * **NON-VACUITY, and it is exact:** inverting the selector's two writes
          makes the scenario FAIL with `wTransSpiral +0: want $01 | got $00` —
          **1 unmasked divergence and nothing else**. Probe reverted, green
          again.
        * Golden regenerated from the pinned ROM for this scenario only.
          DECOMPOSED against the committed one: regions **18 -> 19**, added
          exactly `['wTransSpiral']`, removed none, **no pre-existing region's
          bytes changed**, dump frame unchanged at 5804.
      - **CORRECTION — "a new dumped region changes the schema for all 69
        goldens" WAS WRONG, and it had been used to call three things blocked.**
        Only adding to the SHARED region set relayouts every golden. A
        SCENARIO-LOCAL row (port `gbregion` under that scenario's `%ifdef`, plus
        the matching `r[#r+1]` row in its `.lua`) regenerates ONE golden. The
        pattern was already established in-tree — `wBoxData`, `wBattleResult`
        and the sight rows all do exactly this, and `debug_dump.asm` says so in
        the `wBoxData` comment. Regeneration is fully local:
        `dos_port/tools/mgba_build/mgba-lua-runner` plus the pinned
        `../pokeyellow_msdos-pret-golden` worktree, both present.
      - **ANIMATION-BODY CHECKPOINT LANDED 2026-08-13.** The same real Route 3
        trainer entry now clears `$CD3D` before battle, then emits
        `wTransInSpiral = 1` only when the selected
        `BattleTransition_InwardSpiral` has made its body counter nonzero. This
        normalizes the intentional geometry result (pret's 20x18 body finishes
        at `$05`, the documented 40x25 projection at `$0D`) without comparing
        unlike implementations; a skipped body remains the cleared `$00`.
        `trainer_battle_init` now declares `BattleTransition`, both selector
        labels, `BattleTransition_Spiral`, and
        `BattleTransition_InwardSpiral` in its must-hit contract.
        * Both ROM and port dump `$01`; `make -C dos_port goldencheck
          SCENARIO=trainer_battle_init` passes with **10 compared WRAM regions,
          6 explicitly skipped**, and the existing reporting-only palette
          decomposition unchanged.
        * **NON-VACUITY:** a generated port GBSTATE with only this final byte
          corrupted to `$00` reports exactly `wTransInSpiral +0: want $01 | got
          $00` — **1 unmasked divergence**. The clean extracted GBSTATE passes.
        * Golden regenerated from the pinned ROM for this scenario only:
          regions **19 -> 20**, added exactly `['wTransInSpiral']`, removed
          none, dump frame unchanged at 5804. `run_headless DEBUG_TRAINER_INIT`
          also extracted both GBSTATE.BIN and DUMP.BIN, exercising the
          DEBUG-gated region table rather than relying on a plain build.

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
- [x] **6e. TRANSFERRED OUT 2026-08-14 (maintainer instruction) to the CGB
      colour plan, which owns its blocker. NOT done — re-homed.** It is now
      that plan's **Stage 5**, published at the same artifact URL recorded in
      stigmergy `cgb-colour-scoping-2026-08-08`. Everything below is kept
      verbatim as the record of what was measured here, and the Stage 5 text
      carries the mask inventory, the `DrawHPBar` / `DuplicateEnemyHPBarTiles`
      production sites, and the acceptance test (the eight battle scenarios
      must pass `fidelity-full` with the masks REMOVED). This was the
      maintainer's option 1 in the archival box below. **Do not re-open 6e
      here and do not retire an F-19 mask from this plan.**
      **RE-MEASURED 2026-08-14 AND THE BLOCKER HOLDS — not inherited, checked.**
      `src/engine/gfx/bg_map_attributes.asm` still resolves the attribute plane
      to a per-TILE-ID band at load time (`tile_pal[tile id] = attribute`) and
      the compositor still bakes palette into `tile_cache` per tile id; there is
      no per-cell attribute layer in `render_bg`. That file's own
      `DEVIATION{class=HAL}` names the same retirement condition — "retire when a
      per-cell attribute layer lands in the compositor". Checked
      `docs/current_plan_palette_fidelity.md` too: its 5 open boxes are OBJ
      pal4-7, live mon/HP-bar palettes, the blackout path, a re-measure and the
      `PALETTE_GATING` flip — none of them is the per-cell mechanism. So nothing
      has moved and F-19 cannot retire yet.
      **6e. Retire F-19 — BLOCKED 2026-08-12 on the CGB per-cell BG attribute
      plane, which is another plan's Stage 1 and lives OUTSIDE this repo.**
      Remove the enemy-gauge clone-id divergence, restore canonical gauge tile
      identities, and delete every F-19-owned tilemap/VRAM mask. Do not close
      the finding while its masks remain.

      **WHY IT IS BLOCKED, traced rather than assumed.** `golden_diff.py:216-221`
      states F-19's mechanism outright: the port *clones the nine enemy-gauge
      patterns into vFont ids `$C0-$C8` for per-tile palette binding*, and
      *"retiring F-19's mechanism (per-cell palettes) deletes this mask"*. The
      port's palette is today a pure function of TILE ID (`tile_pal`, 384 bytes,
      ORed into `tile_cache` at decode time, `ppu.asm:817-834`) and never of
      tilemap CELL — so the clone trick exists precisely because there is no
      per-cell plane. Building one is the CGB colour plan's Stage 1, and that
      plan is deliberately NOT in this repo (maintainer-confirmed; a markdown
      artifact — see stigmergy `cgb-colour-scoping-2026-08-08` for the URL).
      **Do not create `docs/current_plan_cgb_colour.md`.**

      Worse for 6e specifically: that plan's Stage 0 measured every
      statically-resolvable screen as collision-free, but records BATTLE as
      **unresolved** — its four slots are built at runtime from mon palettes —
      and names battle as one of only two real candidates for the per-cell
      compositor work. So F-19 sits on the *hardest* remaining case, not the
      easy one.

      **Nothing in this box should be attempted here.** Retiring the masks
      before the mechanism exists would be masking a divergence to get green,
      which this plan's preamble forbids. Re-check when the CGB plan's Stage 1
      lands; the report-in below is still accurate and unaffected.
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

      **THAT CARRY-FORWARD IS DISCHARGED — RE-MEASURED 2026-08-14, NOW THAT ALL
      FIVE STAGE-6 ANIMATION SCENARIOS EXIST (74-78). The trigger has not
      fired, and the note was imprecise about WHICH mask could fire it.**
      * **Mask family, measured from `golden_diff.py` rather than assumed:
        `_BATTLE_VRAM_MASKS` (the intro variant, slots `$00-$30`) is referenced
        by exactly ONE scenario — `battle_intro`.** Every animation scenario
        (`battle_anim_physical`, `_elemental`, `_ball`, `_blink`, `_optoff`)
        references `_BATTLE_VRAM_MASKS_MENU` instead, which masks `$00-$7F`
        under a *different* justification (post-send-out anim/pic bank). So an
        animation scenario cannot falsify the intro string by construction:
        it never consults it. `battle_intro`'s own dump point precedes any move
        selection, so the shake cannot run before it either.
      * **The underlying concern is nonetheless real, and the port side is
        measured, not inferred.** `AnimationShakeEnemyHUD`
        (`animations.asm:2445`) opens with `mov esi, GB_VCHARS0` /
        `mov ebx, PIC_SIZE` / `call CopyVideoData` — `PIC_SIZE` is 7x7 = 49, so
        it does write slots 0-48 = `$8000-$830F`, exactly as the note feared,
        and nothing restores those bytes afterwards (the tail restores the BG
        map and OAM, not vSprites).
      * **What actually gates it is the CALLER, and no current scenario is one.**
        `SE_SHAKE_ENEMY_HUD` (`$E4`) appears in exactly one subanimation,
        `EnemyHUDShakeAnim` (`data/moves/animations.asm:1177`), reached as
        animation id `ENEMY_HUD_SHAKE_ANIM` — and that id is played only from
        the stat-modifier effects (`engine/battle/effects.asm:141/257/264/272`;
        the port mirrors all four at `effects.asm:328/458/464/471`). It is NOT
        on `PlayApplyingAttackAnimation`'s path: that dispatches through
        `AnimationTypePointerTable`, whose six entries are the screen shakes and
        `BlinkEnemyMonSprite` — no HUD shake. And it cannot arrive as a plain
        move animation either, since `MoveAnimation` does `ld a,[wAnimationID] /
        and a / jr z,.animationFinished` (`animations.asm:425-427`), so
        `NO_MOVE` returns before dispatch.
      * The five animation scenarios use STRENGTH (physical, blink, optoff),
        THUNDERSHOCK (elemental) and MASTER BALL (ball). **None is a stat move,
        so none reaches the shake**, and the `$00-$30` justification string
        stands unchanged. Re-check when a stat-modifier scenario lands — that,
        not "any animation scenario", is the real trigger.
- [x] **DONE 2026-08-13 — all five landed and sabotage-proved: `battle_anim_physical`
      (74), `battle_anim_elemental` (75), `battle_anim_ball` (76),
      `battle_anim_blink` (77), `battle_anim_optoff` (78). Registry 76,
      `fidelity-full` green. The ball scenario caught a real production bug
      (`TX_LOW`, see below); the option-off scenario had its first landmark
      thrown out as blind before it was allowed to register.**
      Add must-hit animation scenarios for representative physical, elemental,
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
      - **FIRST CALIBRATION RESULT 2026-08-13 — `battle_faint` cannot be
        repurposed for the physical checkpoint.** It does enter the real menu
        turn (`FIGHT` -> `STRENGTH`) and therefore executes the production
        animation path, but its documented dump point is deliberately after
        enemy HP reaches zero, EXP is paid, and `DrawPlayerHUDAndHPBar` has
        restaged `wLoadedMon`. At that instant the OAM frame blocks required by
        the physical spec have already been cleaned up, so its green
        datastruct result proves the resolved turn only, not animation. A
        Stage-6 physical scenario needs an earlier state-gated landmark while
        the OAM block is live; do not relabel this post-flow scenario as one.
      - **PHYSICAL COMPLETE 2026-08-13 — `battle_anim_physical` (id 74).** The
        reference takes the real wild-battle `FIGHT` -> `STRENGTH` path and
        waits for OAM to CHANGE from the parked menu state; the port reuses the
        real `ExecutePlayerMove` spine and stops at `DrawFrameBlock` only when
        `wAnimationID == STRENGTH`, after publishing its first live frame.
        This condition matters: the first version stopped on the send-out
        `POOF_ANIM` and the tilemap/OAM disagreed, proving it was not the move
        landmark. The finished check has unmasked TILEMAP/VRAM/OAM/WRAM all
        matching; the one `wLoadedMon` level byte is an explicitly documented
        debug-staging mask. A deliberate one-bit corruption of canonical OAM
        failed exactly OAM entry 0 (`Y=48` -> `49`), so the witness is
        sensitive. `goldens-verify` regenerated all 72 artifacts with no
        drift. Elemental, ball, shake/blink and option-off remain open in this
        same box.
      - **~~ELEMENTAL PROBE BLOCKED 2026-08-13~~ — THAT BLOCKER DOES NOT
        REPRODUCE, AND THE PORT SIDE IS NOW BUILT AND MEASURED (2026-08-13,
        later session).** The recorded symptom was
        `debug_dump.asm:4297: label DumpGBState.ret changed during code
        generation`. A `DEBUG_BATTLE_ANIM_ELEMENTAL` gate of the *same shape as
        the physical one* was rebuilt from scratch and **assembles and links
        cleanly** (`make DEBUG_BATTLE_ANIM_ELEMENTAL=1`, exit 0 read from a
        status file). The failure was therefore specific to the reverted edit,
        not a property of `debug_dump.asm`'s conditional layout — most likely
        the same mid-file `extern`/`equ` ordering fault recorded in
        `battle-3b-pay-day-witnessed`; there are no `extern`s below line 2000 in
        that file today, so a new gate must keep them at the top. **Do not carry
        the "debug-gate layout" diagnosis forward.**
        * **THE CHECKPOINT WORKS AND WAS DECOMPOSED, not aggregated.**
          `tools/run_headless.sh "DEBUG_BATTLE_ANIM_ELEMENTAL=1"` produced a
          17-region GBSTATE. `wBattleMon` moves read `13 0F 39 54` =
          FLY/CUT/SURF/**THUNDERSHOCK**, so the gate's move pin took;
          `wEnemyMon` HP reads **36 (alive)**, so the dump is *before* damage
          application, i.e. it is the animation landmark and not the faint
          gate's post-KO dump; OAM holds 4 live entries (16 non-zero bytes), so
          a frame block is genuinely published.
      - **ELEMENTAL COMPLETE 2026-08-13 — `battle_anim_elemental` (id 75).**
        Registered, golden committed, `goldencheck` **PASS** with
        **TILEMAP / VRAM / OAM / WRAM all clean unmasked** (360 cells, 384 tile
        slots, 40 OAM entries, 13 WRAM regions / 0 skipped). The only wram mask
        is the same `wLoadedMon +33` level-staging asymmetry the physical twin
        already documents. `validate_scenarios`: 73 consistent.
        * **THE ONE REAL DIVERGENCE WAS FOUND AND FIXED, NOT MASKED.** The first
          run reported exactly one unmasked field —
          `wLoadedMon move 4: want $54 | got $46`. Cause, read out of pret
          rather than guessed: `DrawPlayerHUDAndHPBar` copies
          `wBattleMonSpecies..wBattleMonDVs` into `wLoadedMon`
          (`engine/battle/core.asm:1903`) and **that range spans the moves**, so
          a move pinned *after* the HUD draw is invisible to the staging buffer.
          The reference pins before its menu path draws the HUD; the port gate
          pinned after. Moving the port's pin ahead of `DrawHUDsAndHPBars`
          closed it. A mask here would have hidden a real ordering difference.
        * **THE WITNESS IS SENSITIVE, PROVED BY SABOTAGE.** A deliberate
          one-byte OAM corruption at the checkpoint (`inc [$FE00]`) made the
          scenario FAIL on exactly OAM entry 0 (`Y=40` -> `41`) and nothing
          else; the probe was then reverted. So the PASS above is a measurement,
          not an absence of comparison.
        * Ball, shake/blink and option-off remain open in this same box.
      - **OPTION-OFF COMPLETE 2026-08-13 — `battle_anim_optoff` (id 78), AFTER
        ITS FIRST LANDMARK WAS THROWN OUT AS BLIND.** Registered, golden
        committed, `goldencheck` **PASS** with TILEMAP/VRAM/OAM/WRAM all clean.
        **This closes Stage 6's animation-scenario box: 5 of 5.**
        * **THE LANDMARK IS INSIDE `MoveAnimation`'s `.animationsDisabled` ARM**
          (`animations.asm`), before its 30-frame delay. That placement is the
          whole design: **the port must TAKE the arm to dump at all**, so a port
          that ignored the option cannot reach the checkpoint.
        * **SENSITIVITY IS THEREFORE STRUCTURAL, AND IT WAS MEASURED.** Dropping
          the port's option pin — making it take the ANIMATED arm — turns the
          run into **89 unmasked divergences** (71 tilemap cells among them),
          because the port never reaches this checkpoint and falls through to
          the enclosing `DEBUG_BATTLE_FAINT` gate's own post-KO dump instead.
          Loud, and faster than a timeout. Probe reverted.
        * **A REAL ORDERING FACT CAME OUT OF THE FIRST FAILED RUN, and it was
          the reference that was wrong, not the port.** The first aligned
          attempt diverged on exactly `wBattleMon PP 4` and
          `wPartyData mon 0 PP 4` (`want $05 got $04`). pret's order is
          `DisplayUsedMoveText` -> `DecrementPP` -> ... -> `PlayMoveAnimation`
          (`core.asm:3289-3346`), so the port's spent PP inside `MoveAnimation`
          is FAITHFUL and the reference had stopped in the small window between
          the text and the decrement. Fixed by making the reference wait for the
          PP to actually drop (captured before the turn, compared after) rather
          than for the message alone.
        * **THE DISCARDED FIRST LANDMARK IS THE LESSON.** It reused
          `battle_anim_blink`'s shared hidden-pic instant and PASSED on the first
          run — while proving nothing, because the only surfaces separating the
          animated route from this one there are 79 VRAM tile slots (49..127)
          and the `wOptions` byte, and every one of those slots is inside
          `_BATTLE_VRAM_MASKS_MENU` (`$8000-$87FF`, slots `0x00-0x7F`). A port
          ignoring the option would still have passed. That mask range was
          established by reading the mask DEFINITION; an earlier note in this
          box had it wrong because it was derived from `goldencheck`'s printed
          HIT range instead. Recorded in
          `battle-stage6-optoff-landmark-is-blind`.
      - **BALL COMPLETE 2026-08-13 — `battle_anim_ball` (id 76), AND IT CAUGHT A
        REAL PRODUCTION BUG ON ITS FIRST RUN.** Registered, golden committed,
        `goldencheck` **PASS** with TILEMAP / VRAM / OAM / WRAM all clean
        unmasked and **no wram mask of its own at all**. Entered through the
        real battle ITEM menu (ITEM -> MASTER BALL) rather than FIGHT; the dump
        instant is distinguished from `ball_catch`'s by the party still being 5.
        * **THE BUG: `TX_LOW` printed the second dialogue line OUTSIDE the text
          box.** `dos_port/src/home/text.asm` `.cmd_low` hardcoded
          `W_TILEMAP + 16 * SCREEN_W_TILES + 1` — pret's GB offset
          (`hlcoord 1,16`) used as a **raw flat index into the port's 40-wide
          tilemap** — so the line landed at canvas (row 8, col 1), eleven rows
          above the box, while line 1 was placed correctly. Fix is one operand:
          `mov ebx, [text_line2]`. **The port already had the mechanism** —
          `text_line2` is exactly that coordinate and every other `(1,16)` site
          in the file (`handle_para`, both scroll anchors) already read it;
          `.cmd_low` was the one site that did not.
        * **Blast radius is wider than the ball.** `text_low` is a text-stream
          command, so every stream using it was affected —
          `ItemUseText00` (all four ball types plus every medicine/TM item use)
          and `GotOnBicycleText` are two confirmed users in pret. No existing
          scenario had ever compared a rendered `text_low` second line, which is
          why 73 green scenarios never saw it. Recorded as
          `regression-text-txlow-raw-gb-coord`.
        * **NOT FOUND BY LOOKING FOR IT** — the scenario's first run reported 14
          unmasked tilemap cells with `OAM/VRAM/WRAM all OK`, which is what said
          "same animation frame, different text placement". Rendering both
          tilemaps side by side located the string. The fix took the count 14 ->
          0, so the tilemap surface is demonstrably sensitive here.
        * **OAM sensitivity proved separately by sabotage:** a one-byte OAM
          corruption at the checkpoint failed on exactly entry 0 (`Y=88` ->
          `89`) and nothing else; probe reverted.
        * **SIBLING SWEEP (the raw-coord class says to do one): `TX_SCROLL` has
          the SAME defect and is NOT yet fixed.** `dos_port/src/home/text.asm`
          `.cmd_scroll` ($07) ends with the identical
          `mov ebx, W_TILEMAP + 16 * SCREEN_W_TILES + 1`, for the identical
          purpose — repositioning the cursor to the box's second line after
          scrolling. Decomposed rather than asserted: `PrintText`
          (`src/home/window.asm:143`) publishes the active projection record's
          `MB_LINE2` into `text_line2` on every call, and the DEFAULT overworld
          record's `MB_LINE2` (`text.asm:1480`) is literally that same constant.
          So the constant is correct in the overworld and WRONG in all five
          non-default projections that exist: battle (`core.asm:1341`,
          `BTXT_LINE2`), `bills_pc`, `players_pc`, `party_menu`, `oak_speech`.
          Fix is the same one operand. **FIXED separately from the ball commit,
          and it is UNWITNESSABLE — which is a measured property of the DATA,
          not a gap in the suite.** No text stream anywhere in pret emits
          `TX_SCROLL`: a repo-wide search for `text_scroll` outside `dos_port/`
          returns only the macro definition in `macros/scripts/text.asm`. So the
          handler is unreachable through game text and no scenario can ever
          compare it — do not open a "needs a witness" item for it. Corrected
          anyway so the two identical siblings do not disagree, with the
          reasoning recorded at the site. Gates: lint 0 both modes, core tier
          16/16.
        * Shake/blink and option-off remain open in this same box.
      - **SHAKE/BLINK COMPLETE 2026-08-13 — `battle_anim_blink` (id 77).**
        Registered, golden committed, `goldencheck` **PASS** with TILEMAP /
        VRAM / OAM / WRAM all clean unmasked. Its two `wLoadedMon` masks are
        both reported as HIT, so neither is vacuous. Sensitivity proved by
        sabotage: a one-byte corruption of a compared tilemap cell failed on
        exactly that cell (`(0,0) want $7F got $80`) and nothing else; probe
        reverted.
        * **THE BLOCKER FROM THE PREVIOUS PASS IS RESOLVED, AND THE PREVIOUS
          PASS'S "NOT UNDERSTOOD" WAS WRONG.** The `wLoadedMon` speed stat-EXP
          word is a PREVIOUSLY ADJUDICATED field: `battle_blackout` has masked
          `wLoadedMon +23..+24` since 2026-07-26, with the same two values
          (golden `$9876`, port `$0000`) and the same reasoning — neither dump-
          point routine writes it, because `DrawPlayerHUDAndHPBar` copies two
          disjoint runs (0-11 and 33-43) and leaves 12-32 as scratch. Checking
          `memory_search` before declaring a mystery would have found it.
        * **The measurement still refined the precedent's account, so it was
          worth taking:** at `battle_anim_physical`'s earlier instant BOTH sides
          read `$0000`, so the ROM writes that word somewhere between that
          instant and the blink rather than carrying it in from an earlier
          `LoadMonData`. It is a single 2-byte word — the rest of the 12-32
          window is zero on both sides — so it is scratch reuse, not a staging
          call the port omits: a `LoadMonData` would have populated OT id, EXP,
          the other four stat-EXP words and the DVs. `wBattleMon`, where those
          values actually live, is compared UNMASKED and matches.
        * **THE PATH.** After a move's own animation, `MoveAnimation` calls
          `PlayApplyingAttackAnimation`, which dispatches on `wAnimationType`
          (`engine/battle/animations.asm:506`). Type 4 — player used a damaging
          move without a side effect, which is what STRENGTH selects — is
          `BlinkEnemyMonSprite` -> `AnimationBlinkMon`, six iterations of
          {hide pic, 5 frames, show pic, 5 frames}. The landmark is the FIRST
          hide. `DebugDumpMemory` never returns, so "first" needs no counter.
        * **THE INSTANT IS PINNED BY TWO CONDITIONS, not one.** Measured on the
          port: the enemy's 7x7 pic block at GB (12,0) is blank AND
          `wEnemyMon` HP is still 36. Damage is applied only after
          `MoveAnimation` returns, so full HP is what separates a blink hide
          from any later hide. It sits strictly between `battle_anim_physical`
          (stops earlier, inside the move animation) and `battle_faint` (stops
          after the KO) — a gap nothing had covered.
        * **ONE DEFECT IN THE GATE FOUND AND FIXED:** omitting the
          `DrawEnemyHUDAndHPBar` call its siblings make left the enemy HUD
          showing the LEVEL where the reference shows `SLP`
          (`PrintStatusConditionNotFainted` takes the status branch and skips
          `PrintLevel`). goldencheck reported exactly those 4 tilemap cells;
          adding the call took TILEMAP to OK.
        * **THE TWO MASKS.** `wLoadedMon +23..+24` (the stat-EXP word above) and
          `wLoadedMon +33` (level: `DrawEnemyHUDAndHPBar` writes
          `wLoadedMonLevel` only on the no-status path, `core.asm:1966-1970`, so
          with the SLP pin the port's 13 is residue from the earlier
          `DrawHUDsAndHPBars` while the reference's menu path last staged the
          player L80 — the same asymmetry physical/elemental document). Both are
          reported HIT by `goldencheck`, so neither is dead weight.
          **A NOTE ON THE EARLIER DRAFT OF THIS BOX:** it claimed the port
          "zeroes it on the port side only". That was wrong — measured, the port
          reads `$0000` at BOTH instants and it is the ROM that writes the word.
          A wrong causal story in a plan is how the next agent hunts a
          non-existent port bug.
      - **BALL SUB-ITEM SCOPING (read-only measurement made before building it;
        both facts held).**
        Two facts that changed how it had to be built:
        * **`ball_catch` (id 20) CANNOT be promoted into this witness.** It is
          `scenario_class: datastruct` (`regions: ["wram"]`) and its gate dumps
          only after asserting `wBattleResult == 2`, i.e. after the capture has
          RESOLVED. Every toss frame block is long cleaned up by then. This is
          the same shape as the `battle_faint` finding above — reaches the code,
          compares a surface where the animation cannot show. A ball animation
          scenario needs its own earlier `DrawFrameBlock` landmark.
        * **THE SPEC'S `TOSS_ANIM` IS THE WRONG CONSTANT FOR THAT ROUTE.**
          `ball_catch` throws a MASTER BALL, and pret picks the toss animation
          by item (`engine/battle/animations.asm:2795`): `POKE_BALL` ->
          `TOSS_ANIM`, `GREAT_BALL` -> `GREATTOSS_ANIM`, everything else ->
          `ULTRATOSS_ANIM`. Values derived from `constants/move_constants.asm`
          and cross-checked against two knowns (`STRENGTH` $46, `THUNDERSHOCK`
          $54 both reproduce): `TOSS_ANIM` = **$C1**, `GREATTOSS_ANIM` = $C5,
          `ULTRATOSS_ANIM` = **$C6**. So a checkpoint reusing `ball_catch`'s
          MASTER BALL must key on `$C6`; keying on `TOSS_ANIM` would silently
          never fire. Either key on `$C6` or change the thrown ball — decide
          explicitly, do not inherit the spec's wording.
        * Note the entry point differs from the two landed scenarios: the toss
          runs through `PlayAnimation` (a 5-animation sequence: POOF, HIDEPIC,
          SHAKE, POOF, SHOWPIC), not `MoveAnimation`, so the `must_hit` list
          must be re-derived rather than copied from `battle_anim_physical`.

## Stage 7 — retirement and archival

- [x] **FINDING FROM THE STAGE-7 SWEEP (2026-08-12): `SwapPlayerAndEnemyLevels`
      is TRANSLATED BUT NEVER CALLED — pret calls it at 7 sites, the port at 0.**
      `label_status --callers` reports "port callers (0)"; faithdiff reports
      `DROPPED SwapPlayerAndEnemyLevels` on **4** of the 5 pret routines that use
      it: `EnemyCalcMoveDamage` (3 of the 7 sites), `HandleIfEnemyMoveMissed`,
      `EnemyCheckIfFlyOrChargeEffect`, `CheckEnemyStatusConditions`.
      * The routine exchanges `wBattleMonLevel` and `wEnemyMonLevel` so shared
        code that reads the PLAYER slot operates on the ENEMY's level during an
        enemy turn. pret swaps an ODD number of times before `CalculateDamage`.
      * **BEHAVIOURAL IMPACT STILL NOT ESTABLISHED, and the trace so far points
        AWAY from a damage bug** (measured 2026-08-12, partial):
        1. pret's `GetDamageVarsForEnemyAttack` loads the level with
           `ld a, [wEnemyMonLevel] / ld e, a` — **directly from the enemy slot**
           — and pret runs it in the UNSWAPPED window (swap off at :5716, swap
           back on at :5718). So the level handed to `CalculateDamage` in E is
           correct WITHOUT any swap.
        2. `CalculateDamage` (pret 4470-4638) contains **no** WRAM level read at
           all; it takes the level in E per its own header (`e: level`).
        3. Neither `CriticalHitTest` (4649-4718) nor `HandleCounterMove` reads a
           level byte.
        So none of the three routines that execute in the SWAPPED window
        consumes the swap. The consumer must be a CALLEE of one of them, or code
        after the enemy path that reads the levels while still exchanged — NOT
        yet identified.
      * **RESOLVED AS BENIGN 2026-08-12 — the consumer search is COMPLETE and
        found none.** Every reference to either level byte in `home/` +
        `engine/`, in ALL addressing forms, was enumerated:
        `wBattleMonLevel` — RemoveFaintedPlayerMon, LoadBattleMonFromParty (x3,
        copy bounds), DrawPlayerHUDAndHPBar, CheckForDisobedience,
        GetDamageVarsForPlayerAttack, ApplyAttackToEnemyPokemon, GainExperience,
        SwitchAndTeleportEffect (x2), PayDayEffect_;
        `wEnemyMonLevel` — GainExperience, PayDayEffect_, RemoveFaintedPlayerMon,
        LoadEnemyMonFromParty (x3), DrawEnemyHUDAndHPBar,
        GetDamageVarsForEnemyAttack, GetEnemyMonStat, ApplyAttackToPlayerPokemon,
        LoadEnemyMonData (x2), plus (outside the battle engine) only the dead
        debug menu and `item_effects` on player item use.
        **Not one sits inside a swapped window.** Each runs outside it, reads
        BOTH sides explicitly (`SwitchAndTeleportEffect`), or branches on
        `hWhoseTurn` itself (`PayDayEffect_`).
      * Two structural confirmations: pret turns the swap OFF around
        `GetDamageVarsForEnemyAttack` precisely so it reads the TRUE enemy level
        — which the port gets for free by never swapping; and
        `.moveDidNotMiss` restores BEFORE damage application, so
        `ApplyAttackToPlayerPokemon.specialDamage` (Seismic Toss / Night Shade,
        which read `wEnemyMonLevel` as the USER's level) runs UNSWAPPED, matching
        Gen-1 behaviour and what the port already does.
      * **Residual uncertainty, stated:** this traced static references BY
        SYMBOL NAME. A pointer access reaching the byte without naming it would
        not appear, so the claim is "no NAMED reader depends on the swap".
      * **A SEPARATE, REAL BUG WAS FOUND WHILE CHECKING THIS AND IS FIXED
        2026-08-12.** pret's `HandleExplosionMiss` opens `call Swap` + **`xor a`**
        and falls into `PlayEnemyMoveAnimation`, which does
        `push af … pop af / ld [wAnimationType], a` — so **A at entry BECOMES
        `wAnimationType`**. The port had no such label: the `EXPLODE_EFFECT`
        test jumped straight to `PlayEnemyMoveAnimation` still carrying
        `wEnemyMoveEffect` in AL, so a MISSED enemy Explosion/Selfdestruct set
        `wAnimationType = EXPLODE_EFFECT` instead of 0. The label is now
        restored with its `xor`, taking `HandleExplosionMiss` from `missing` to
        `translated`. This is independent of the swaps.
      * **A PRIOR AGENT ALREADY REASONED ABOUT THE SWAPS**, in a note at the
        enemy Bide site: pret's swap there "pairs with the un-swaps in
        HandleIfEnemyMoveMissed continuations, which the port stripped… A swap
        here would never be undone." That is ACCURATE — the port omits the swaps
        as a consistent whole — and it is why adding one in isolation is wrong.
      * **DONE 2026-08-13 — all 7 restored as a SET, and the analysis is now
        empirically confirmed.** Port callers 0 -> 7, at pret's exact sites.
        faithdiff on all five pret users is fully matched:
        `EnemyCalcMoveDamage` 11/11, `CheckEnemyStatusConditions` 10/10,
        `EnemyCheckIfFlyOrChargeEffect` 4/4, `HandleIfEnemyMoveMissed` 3/3,
        `HandleExplosionMiss` 1/1. Restoring them as a set is exactly what
        answers the prior agent's objection — the Bide swap is paired again by
        the un-swaps on `.moveDidNotMiss`, `HandleExplosionMiss` and
        `EnemyCheckIfFlyOrChargeEffect`. The `DEVIATION{class=projection}` on
        `HandleExplosionMiss` that recorded the omission is retired with it.
        * **THE GREEN IS NOT VACUOUS, AND PROVING THAT CHANGED THE ANSWER.**
          The recorded gate (`battle_damage`, `battle_faint`) passes — but a
          sensitivity probe removing ONE un-swap, so the count goes odd and the
          levels leak, **also passes both of them**. Those two scenarios cannot
          see this. Re-probed across the whole enemy-turn set, **exactly two
          scenarios catch it**: `battle_blackout` and `battle_choose_next_mon`,
          which fail with `wBattleMon level: want $05 | got $0D` and
          `wEnemyMon level: want $0D | got $05` — the pair literally exchanged.
          Probe reverted, both green again. **Use `battle_blackout` /
          `battle_choose_next_mon` as this finding's gate, NOT `battle_damage` /
          `battle_faint`.**
      * *(superseded action line)* restore the 7 calls for STRUCTURAL fidelity — it closes 4
        faithdiff findings and matches pret exactly — **not as a bug fix.** Gate
        with `battle_damage` and `battle_faint` (both drive enemy attacks): green
        is the empirical confirmation of the analysis; red means the consumer has
        been found, which is equally a result. Do not describe the current state
        as a damage defect.
      * **How it survived:** a translated-but-uncalled routine trips nothing —
        lint is clean, `label_status` says `translated`, and no scenario drives
        an enemy attack where a level difference would show. Only `faithdiff`
        per routine, or a CALLERS query, sees it.
      * **It was found by disbelieving a comment.** The harness-only
        `DoEnemyAttackDamage` (`battle_menu.asm`) carries a
        `DEVIATION{class=temporary}` asserting "the port already translates
        `EnemyCalcMoveDamage` faithfully". That claim is FALSE.
      * Memory: `regression-battle-swapplayerandenemylevels-never-called`.
- [x] **CORE.ASM MISSING-LABEL INVENTORY (measured 2026-08-12): 14 of 207
      labels, i.e. 93% translated.** Most are explained by deviations already
      documented — `StartBattle` (the collapse), `SimulatedInputBattleItemList`
      (`wListPointer` is a 16-bit GB address) and `BattleCore` (a section
      label), plus the nine labels this box called "the intro-slide family".
      * **THE "INTRO-SLIDE FAMILY" AUDIT IS DONE 2026-08-12, AND THE GROUPING
        WAS WRONG.** It is not one family of nine; it is three groups, and only
        one of them is open work. Measured against pret `engine/battle/core.asm`
        and every call site.
      * **(a) Genuine HAL boundary, correctly absent — 3 labels.**
        `SlidePlayerAndEnemySilhouettesOnScreen`, `SlidePlayerHeadLeft`,
        `SetScrollXForSlidingPlayerBodyLeft`. This is NOT a fork of convenience
        like `EnemyMoveHitTest`: `SetScrollXForSlidingPlayerBodyLeft` is a
        self-loop on `rLY` (`ldh a, [rLY] / cp l / jr nz` to its own label),
        and `rLY` is INERT in the port — a literal translation never
        terminates. `SlidePlayerHeadLeft` exists ONLY because that raster trick
        forces the player's head to be an OBJ while his body is BG; the port
        composites both pics into `W_TILEMAP` per frame, so there is no
        head/body split for it to drive. The port's `SlideBattlePicsIn`
        (`src/home/pics.asm`) is a different mechanism, not a renamed copy.
      * **(b) NOT THIS FAMILY AT ALL — 5 labels, and they are permanently out
        of scope.** `Func_3d4f5`, `Func_3d523`, `Func_3d529`, `asm_3d52d`,
        `Func_3d536` are pret's **_DEBUG test-battle move-selection harness**
        (they read/write `wTestBattlePlayerSelectedMove` and print it at
        `hlcoord 10,16`). Every call site is inside an `IF DEF(_DEBUG)` block —
        `MoveSelectionMenu`'s START/LEFT/RIGHT handlers (core.asm:2721-2728)
        and `SwapMovesInMenu` (:2929) — so they are unreachable in a retail
        build. They were only ever adjacent to the slide routines by ADDRESS.
        Strike them from the residue; they are not work.
      * **(c) The one real open item — `SlideTrainerPicOffScreen`.** It is a
        pure `wTileMap` column shift (`ld a,[hld] / ld [hli],a` per cell, no
        `rLY`, no hardware scroll), so unlike (a) it IS translatable, and both
        of its call sites are retail: `StartBattle`'s player send-out
        (core.asm:246, `hlcoord 1,5`, 9 columns) and `EnemySendOutFirstMon`
        (:1351, `hlcoord 18,0`, 8 columns — the direction switch is
        `hSlideAmount == 8`). The port drops both under the existing
        `; ANIMATION=OFF:` convention (`core.asm:5296`), which is the port's
        tracked animation-deferral class rather than an unannotated divergence,
        so nothing is owed here now — but this is the ONLY member of the
        original nine that a later stage should actually translate.
      * **TRANSLATED AND WIRED 2026-08-14 (maintainer directed). THE ANALYSIS
        BELOW WAS WRONG, AND THAT IS THE WHOLE STORY OF THIS ITEM.** pret's loop
        is a FIXED-WINDOW IN-PLACE SHIFT ANCHORED TO THE SCREEN EDGE, not a
        translation of the pic to a new position. Simulated cell-by-cell against
        the disassembly:
        * player pass (amount 9, from GB col 1): READS cols 1-9, WRITES cols 0-8
        * enemy pass (amount 8, from GB col 18): READS cols 18-11, WRITES 19-12
        Neither ever touches a cell outside the 20-wide GB screen. The pic is
        DESTROYED at the edge as blanks propagate in from the far side, and after
        `amount` steps the window is empty. The "slid LEFT 9 -> canvas col 2 /
        slid RIGHT 8 -> canvas col 36" reading below treated the slide as MOVING
        the pic that many columns; it does not move anywhere.
        * **CONSEQUENCE: no margin garbage is possible, and no residual-blanking
          DEVIATION is needed.** Because the window is anchored to the GB screen
          edge, every write stays inside the projected window (canvas cols
          10-29) once the caller passes a `BCOORD` origin. The whole
          "unwitnessable, lands where nothing can report it" premise — which
          deferred this item twice — was false.
        * **The row step needed no deviation either.** pret's
          `ld de, SCREEN_WIDTH / add hl, de` is literal, because the port's
          `SCREEN_WIDTH` IS 40 (`gb_memmap.inc:1689`) — same source expression,
          canvas constant.
        * **The only deviation is `hSlideAmount`**, realized as a file-local
          `.bss` byte under `DEVIATION{class=projection}`, following the
          established `oak_speech2.asm` precedent for pret's `hSlide*` HRAM.
        * **MEASURED:** `faithdiff SlideTrainerPicOffScreen` = 1/1 calls matched,
          one DROPPED store `[hSlideAmount]` (that documented substitution).
          Its caller decomposed before -> after: `EnemySendOutFirstMon`
          **23 pret / 10 port, 7 matched, `DROPPED SlideTrainerPicOffScreen`**
          -> **23 pret / 11 port, 8 matched, that DROPPED line gone**. One
          finding closed, none added. lint 0 in BOTH modes.
        * **SCOPE LIMIT, measured not assumed: only ONE of the two retail call
          sites could be wired.** `StartBattle` is `missing` in the port, so the
          player send-out site (pret `core.asm:246`) has no enclosing routine to
          wire it into. `EnemySendOutFirstMon` (pret `:1351`) is translated and
          live via `_InitBattleCommon`, and carries the real call now:
          `mov esi, BCOORD(18,0) / mov al, 8 / call SlideTrainerPicOffScreen`.
          **BOTH SITES ARE NOW WIRED (same day, second pass).** The "blocked on
          `StartBattle`" reading was itself too quick: `StartBattle` is `missing`
          only because **the port ABSORBED its body into `_InitBattleCommon`**
          (`init_battle.asm:355-357` says so: "pret splits this across
          InitBattle -> InitWildBattle -> _InitBattleCommon -> StartBattle …
          folded StartBattle … into the proven path"). So the player send-out
          site exists — inside the merged routine — and pret's own ordering
          located it exactly: `core.asm:243-247` puts the three calls between
          `wBattleMonSpecies2` and the `FlagAction` pair, and the port had that
          precise gap with all three missing. Now wired there:
          `LoadScreenTilesFromBuffer1` / `BCOORD(1,5)` + `al=9` +
          `SlideTrainerPicOffScreen` / `SaveScreenTilesToBuffer1`.
          * `SlideTrainerPicOffScreen` port callers **0 -> 2**, matching pret's
            two retail sites.
          * `_InitBattleCommon` faithdiff, before -> after: **4 -> 5 matched**,
            DROPPED lines **11 -> 10**, and none of the three added calls
            registers as ADDED.
          * For the record on why its counts look odd at all: that routine
            carries pret's `StartBattle` body, so it will always show ADDED
            calls relative to pret's own `_InitBattleCommon`. That is the
            pre-existing absorption fork, not this change.
      * **SUPERSEDED — the analysis that deferred it (kept because being wrong
        here is the lesson):**
      * **ANALYSED 2026-08-13, AND "needs PROJ coordinates" UNDERSTATES IT.**
        Projecting the two call sites is not enough, because pret's whole
        MECHANISM is "shift until the pic leaves the 20-wide screen", and the
        port's canvas is 40 wide with the GB window at +10. Computed:
        * player pic GB(1,5) = canvas col 11, slid LEFT 9 -> **canvas col 2**;
        * enemy pic GB(18,0) = canvas col 28, slid RIGHT 8 -> **canvas col 36**.
        Both land ON the canvas, in the margin, and **both are outside the
        compared window (cols 10-29)** — the same unguarded region where the
        stray `120/362` hid until 2026-08-13. A naive translation would park a
        trainer pic in the margin, visible on screen and reportable by no
        golden.
      * **THE DECISION IT NEEDS, so the next attempt starts from it:** keep
        pret's step count and timing (8/9 steps, `DelayFrames 2` each — that is
        the animation) and BLANK the residual cells at the end, as a
        `DEVIATION{class=projection}`. The alternative — sliding far enough to
        leave a 40-wide canvas — changes the animation's duration and is
        therefore less faithful, not more.
      * Also needed: `hSlideAmount` has no port memmap slot (`oak_speech2.asm`
        keeps its own file-local `.bss` copy for the same pret name), so the
        translation must either add the HRAM equate or follow that precedent.
      * **NOT LANDED BLIND, deliberately.** The harness's hand-rolled intro
        does not call it, so no scenario reaches it, and its end state lands in
        the unguarded margin. Landing an unwitnessed change whose only artifact
        appears where nothing can report it is the exact combination this plan
        has spent several iterations learning to refuse.
      * **RE-MEASURED 2026-08-14 — THE WITNESS HALF OF THAT REFUSAL IS NOW
        CLOSED, and the other premises still hold.**
        * `label_status --callers SlideTrainerPicOffScreen`: still `missing`,
          **0 port callers**. Unchanged.
        * **The "nothing can report it" half is no longer true.** This plan's
          own stride-leak sweep built a margin scan — dump the port's whole
          40x25 canvas, report every non-blank cell at canvas cols 0-9 or 30-39
          — and it is now PROVEN SENSITIVE AT EXACTLY THE TWO COLUMNS A SLID PIC
          WOULD LAND ON. In-vitro sabotage of a clean `battle_anim_blink`
          canvas: a glyph parked at canvas (row 8, **col 2**) — the player pic's
          computed landing column — is reported, and one at (row 3, **col 36**)
          — the enemy pic's — is reported too; clean scan is 0, sabotaged scan
          is 2 then 3. So a naive translation parking a pic in the margin WOULD
          be caught, by a check that needs no golden.
        * **The `hSlideAmount` question the box raises is already answered by an
          established precedent**, not an open decision:
          `src/engine/movie/oak_speech/oak_speech2.asm` uses file-local `.bss`
          (`slide_dir` / `slide_steps` / region) under a
          `DEVIATION{class=projection}` that names exactly that substitution for
          pret's `hSlideDirection`/`hSlideAmount`/`hSlidingRegionSize`.
        * **AND THE REGRESSION SURFACE WAS MEASURED 2026-08-14 — IT IS SMALLER
          THAN FEARED, BUT SO IS THE UPSIDE.** Two facts settle the risk in
          opposite directions, and both are measured:
          1. **Nothing compares the slide's result, so it cannot BREAK a
             scenario.** At `battle_intro`'s instant (class `default`, comparing
             tilemap/vram/oam/wram) the golden's player-pic band
             `GB(1,5)-(7,11)` holds **49 non-blank cells** — the BACK PIC,
             drawn after the send-out. The slide's blanked band is transient and
             immediately overwritten, so both sides already agree there.
          2. **Nothing compares the saved buffer either, and the reason is
             deeper than "no region for it" (sharpened 2026-08-14).** pret slides
             between `LoadScreenTilesFromBuffer1` and `SaveScreenTilesToBuffer1`,
             so the blanked band is what hardware SAVES while the port saves
             whatever it had — a possible latent stale-pic defect. The port's
             `SaveScreenTilesToBuffer1` copies into **`screen_save`, a flat
             host `.bss` buffer** (`mov edi, screen_save`), NOT into
             `[ebp + wTileMapBackup]`. That is a sanctioned
             `DEVIATION{class=data-model}` (`src/home/tilemap.asm:47`): pret
             unions `wTileMapBackup` with `wSurroundingTiles`, and the port keeps
             a persistent overworld map view that must survive in-overworld
             menus, so the union would corrupt it.
             * **So a witness is possible but costs real tooling**, and this is
               the specific bill: the port side needs a `gbregion_flat` dump of
               `screen_save` (1000 B, 40x25) against the golden's GB-region dump
               of `wTileMapBackup` (360 B, 20x18) — different bases AND different
               strides — and `check_addresses`' `projected` mechanism is
               currently hardcoded to `wTileMap` (it recomputes from each side's
               `wTileMap` base + stride + window, `golden_diff.py:1961-1973`).
               Extending `projected` to accept an arbitrary base-region pair is
               the enabling change. That is the same shape as the extension this
               plan already paid for once when `check_addresses` rejected the
               first HUD span, so it is a known, bounded path — not a wall.
          * **CONSEQUENCE: the translation is low-risk AND its positive effect
            is unwitnessable.** The margin scan guards exactly one failure mode
            (a pic parked at canvas col 2 / col 36); nothing can confirm the
            animation actually plays or that the saved buffer is now correct.
            That is the same combination this box already refused once, so it
            stays deferred DELIBERATELY rather than for lack of analysis — but
            it is now fully specified: decision made, precedent found, failure
            mode guarded, risk bounded. A future session can land it in one
            sitting.
      * **The original framing of what remains:** pret calls this between
          `LoadScreenTilesFromBuffer1` and `SaveScreenTilesToBuffer1` at BOTH
          sites (`core.asm:243-247` and `:1349-1353`), so the slide changes what
          gets SAVED into the screen buffer, not just what is momentarily drawn.
          That is a broad-surface change wanting `fidelity-full`, and it is the
          honest reason it is still not landed — not the witness gap.
      - **MARGIN SCAN EXTENDED 2026-08-14 to the four scenarios added this
        session** — `battle_anim_elemental`, `battle_anim_ball`,
        `battle_anim_blink`, `battle_anim_optoff`: **0 stray cells each** at
        canvas cols 0-9 / 30-39. The earlier sweep covered `battle_item_potion`,
        `battle_wrap`, `battle_menu`, `battle_safari` and `battle_faint`, so all
        nine battle scenarios that have been scanned are clean. Non-vacuity is
        the sabotage above, plus the original sweep's pre-fix potion run which
        reported exactly 7 cells (`F7 F8 F6 F3 F9 FC F8` = "120/362").
      * **THE PRET-NAMED ENTRY POINT LANDED 2026-08-12.**
        `SlidePlayerAndEnemySilhouettesOnScreen` now exists in the mirror file
        `dos_port/src/engine/battle/core.asm` as `call LoadPlayerBackPic /
        jmp SlideBattlePicsIn`, carrying a `DEVIATION{class=HAL}` that names
        every omitted pret internal. Both port call sites — `_InitBattleCommon`
        and `.specialBattleIntro` — call it instead of open-coding the pair, so
        pret's single `callfar` (`engine/battle/init_battle.asm:103`) has a
        counterpart by name. MEASURED: `_InitBattleCommon` faithdiff matched
        3 -> 4, port calls 24 -> 23, and both the `DROPPED
        SlidePlayerAndEnemySilhouettesOnScreen` and the `ADDED
        LoadPlayerBackPic` lines are gone. `SlideBattlePicsIn` keeps its
        port-only name deliberately: pret's slide is inline in
        `.slideSilhouettesLoop`, so there is no pret label for it to inherit.
        Execution order is unchanged, which was VERIFIED rather than assumed —
        core tier 16/16 plus `battle_intro`, `battle_pikachu`, `battle_oldman`
        and `battle_safari` individually, all PASS.
      * **`GetBattleHealthBarColor` TRANSLATED AND WIRED 2026-08-12** — the
        routine is `missing` -> `translated`, its own faithdiff is CLEAN (2/2
        calls), and both pret call sites now make the call:
        `ReplaceFaintedEnemyMon` matched 1 -> 2 calls (its DROPPED line is
        gone), and `DrawPlayerHUD` uses it in place of the bare
        `GetHealthBarColor`. The port's joint `SetPal_Battle` in
        `DrawBattleHUDs` is deliberately kept — it is the port's own two-slot
        publish, and republishing identical values is harmless.
        *`DrawPlayerHUDAndHPBar` still reports the DROPPED line*, and that is a
        pre-existing ALIAS artifact rather than a missing call: the port's
        `DrawPlayerHUDAndHPBar` is a bare `jmp DrawPlayerHUD`, so faithdiff sees
        9 pret calls against 1 port and attributes the real body elsewhere.
      * *(historical)* **It WAS DROPPED AT BOTH CALL SITES** —
        faithdiff confirms it on `ReplaceFaintedEnemyMon` (pret :904) and
        `DrawPlayerHUDAndHPBar` (:1927). pret republishes the battle palette
        **only when the HP-bar colour actually CHANGES**
        (`ld b,[hl] / call GetHealthBarColor / cp b / ret z / SET_PAL_BATTLE`);
        the port calls `SetPal_Battle` UNCONDITIONALLY from `DrawBattleHUDs`, so
        it does the palette work every draw where hardware does it on transition
        only. Behavioural impact NOT measured. Sits in the palette area.
      * **`CenterMonName` TRANSLATED AND WIRED 2026-08-12** — `missing` ->
        `translated`, own faithdiff CLEAN (0/0 calls, it makes none), and both
        pret call sites now make the call: `DrawPlayerHUD` (pret
        `DrawPlayerHUDAndHPBar`:1901) and `DrawEnemyHUD` (pret
        `DrawEnemyHUDAndHPBar`:1960). It shifts a nickname right by 2 columns
        at 1-2 characters, 1 column at 3-4, and not at all at 5+; the port
        placed every name flush-left. The column step needed no projection —
        `W_TILEMAP` is row-major, so pret's `inc hl`/`dec hl` are +/-1 byte on
        both sides. Counter kept 8-bit (`dec bh`) per the counter-width rule.
      * **NO EXISTING SCENARIO CAN WITNESS IT, and the core tier passing is
        therefore VACUOUS for this change.** Every battle scenario's mons are
        SNORLAX (7), PIDGEY (6) and ZUBAT (5) — all in the unshifted 5+ bucket,
        so the goldens are byte-identical by construction and 16/16 PASS proves
        only no regression. Non-vacuity was measured separately, with a
        temporary nickname poke and two headless `DEBUG_BATTLE_MENU` runs that
        differ ONLY in whether the two calls are present. Decomposed:
        - 3-char player nick, `wTileMap` row 21: without the call cols 0,1,2 =
          `80 84 96`; with it col 0 = `7F` and cols 1,2,3 = `80 84 96`.
          **Shift = exactly 1 column.**
        - 2-char enemy nick, row 6: without the call cols 11,12 = `80 81`; with
          it cols 13,14 = `80 81` (cols 11,12 keep PIDGEY's `8F 88`).
          **Shift = exactly 2 columns.**
        Both poke and disable were reverted before the gates ran; the committed
        tree contains neither. A permanent witness would need a new scenario
        with a <=4-character nickname — NOT added, and recorded here as the
        residue of this box.
      * **The two pret HUD entry points are an ALIAS FORK, still open.** Both
        `DrawPlayerHUDAndHPBar` and `DrawEnemyHUDAndHPBar` are bare `jmp`s to
        the port-only `DrawPlayerHUD` / `DrawEnemyHUD`, so faithdiff reports 9
        pret calls against 1 port on each and attributes the entire body
        elsewhere — the same fork shape as `EnemyMoveHitTest`, and the reason
        `CenterMonName` still reads DROPPED at both sites even though the call
        is now real. Pre-existing, not introduced by this box. Retiring it
        means moving the bodies under the pret names, which the port-only split
        (the intro draws the enemy HUD alone) has to survive.
      * Method: enumerate a REGION's labels and print only the `missing` ones.
        That found `EnemyMoveHitTest` and this in one pass, where targeted
        searching had found neither. Memory:
        `battle-core-missing-label-inventory`.
- [x] **RESIDUE OF THE CORE.ASM INVENTORY — CLOSED 2026-08-14.** All three
      items landed, and the two witness gaps this box opened along the way were
      closed by new scenarios rather than left as prose:
      * The HUD alias fork — retired `0698bb0eb`, and it exposed four real
        divergences (`ClearScreenArea`, `PrintStatusConditionNotFainted`,
        `PrintLevel`, `DrawHP`) plus the never-armed low-health alarm. All five
        fixed; the first four are gated by `battle_wrap`'s six projected HUD
        spans, the alarm by `battle_low_hp` (id 72).
      * `CenterMonName`'s missing witness — closed by `battle_short_nick`
        (id 73), non-vacuity proved by deleting the player-side call.
      * `SlideTrainerPicOffScreen` — **translated and BOTH retail call sites
        wired 2026-08-14** (`cd3257078`, `74707909c`). The header this box
        carried for two days ("blocked on a witness that can compare its
        projected final state") was FALSE and the body records exactly why:
        pret's loop is an edge-anchored fixed-window in-place shift, so no
        write ever leaves the projected window and no margin garbage — the
        entire premise of the deferral — is possible.
      **ONE RESIDUE MOVES OUT OF THIS BOX RATHER THAN STAYING OPEN IN IT: the
      `DrawHPBar` ENEMY half, and it is NOT a separate maintainer decision — it
      is 6e's blocker under another name.** The box recorded it as "maintainer
      input wanted: how does the enemy bar get its own palette slot without a
      second implementation". Traced 2026-08-14: calling pret's `DrawHPBar` on
      the enemy side means writing the shared `$63-$6b` ids, which IS retiring
      `DuplicateEnemyHPBarTiles` (`battle_hud.asm:184`), which IS retiring F-19
      — `golden_diff.py`'s F-19 comment says so outright ("retiring F-19's
      mechanism (per-cell palettes) deletes this mask"), and the clone trick
      exists only because the port's palette is a pure function of TILE ID
      (`tile_pal`) and never of tilemap cell. So the answer to "how" is the CGB
      per-cell BG attribute plane, which 6e is already blocked on and which
      lives in another plan outside this repo. Tracking it twice would invite
      two different answers; it is 6e's, and 6e already says do not attempt it
      here.
      * **The HUD alias fork — RETIRED 2026-08-13 (`0698bb0eb`).** The three
        bodies moved from the port-only `battle_hud.asm` into the mirror file
        under pret's names. faithdiff, before -> after:
        `DrawHUDsAndHPBars` 0 -> 2 matched, `DrawPlayerHUDAndHPBar` 0 -> 5
        (9 pret / 9 port), `DrawEnemyHUDAndHPBar` 0 -> 3. `battle_hud.asm`'s
        `print_num3` had to be exported as `hud_print_num3` — `battle_menu.asm`
        has its own file-local `print_num3`, and globalising the shadowed name
        is a link error.
        * **IT EXPOSED FOUR REAL DIVERGENCES NOTHING HAD EVER REPORTED**, and
          the alias-era comments justifying them are measurably false: every
          callee below is `translated` and linked, so "not available yet" is
          not the reason for any of them.
          1. `ClearScreenArea` dropped — FIXED 2026-08-13. Both halves now
             clear pret's rectangle first (`BCOORD(9,7)` 5x11 player,
             `BCOORD(0,0)` 4x12 enemy). The comment said `home/copy2.asm` was
             "not linked here"; it has 21 port callers. `BCOORD` is the same
             uniform (X+10, Y+3) projection the generated UI_* layout uses —
             verified by measurement, not assumed: every port HUD element
             (`UI_{ENEMY,PLAYER}_{NAME,LV,HPBAR,HPFRAC}`) carries pret's exact
             GB coordinate, so the rectangle is pret's rather than a new one.
             * DECOMPOSED against the `battle_wrap` hardware golden, port
               canvas vs golden GB coords, before -> after:
               player rect 5x11 = 55 cells, **0 -> 0** mismatches (this
               scenario never had a stale player cell); enemy rect 4x12 = 48
               cells, **7 -> 6**. So the clear fixed exactly ONE cell: the
               stale `:L` glyph at the enemy LV cell.
             * The 6 that remain are NOT this defect and are not a regression:
               all six are row GB y=2, x=4..9 — the enemy HP gauge — where the
               golden has `6B/69/63` and the port has `C8/C4/C0`. That is
               `DuplicateEnemyHPBarTiles` cloning `$63-$6b` into unused glyph
               slots so the enemy bar can own its own palette slot. Identical
               pixels, deliberately different tile IDs.
          2. `PrintStatusConditionNotFainted` dropped — FIXED 2026-08-13.
             **A PERMANENT WITNESS WAS ATTEMPTED 2026-08-13 AND IS BLOCKED ON
             ONE TOOLING GAP — measured, and the gap is small and named.**
             The right lever is NOT promoting `battle_wrap` to a full rendered
             comparison: its dump point is mid-message and the dialog area is
             timing-coupled between the emulators, which is exactly why it is
             `datastruct`. The enemy HUD is static once drawn, so two ROW SPANS
             are comparable while the screen as a whole is not. Both were
             confirmed byte-identical to hardware first:
             `eHudName` GB(1,0)..(10,0) = `8f 88 83 86 84 98 7f 7f 7f 7f`
             ("PIDGEY"), `eHudLv` GB(0,1)..(11,1) =
             `7f 7f 7f 7f 7f 92 8b 8f 7f 7f 7f 7f` (blank + "SLP").
             * Both sides were wired, and the golden regenerated SURGICALLY:
               regions 19 -> 21, added exactly `['eHudLv','eHudName']`, **no
               pre-existing region's bytes changed**, frame unchanged at 7039.
             * **`goldencheck` then rejected it, correctly**, with
               `REGION LAYOUT MISMATCH`: `check_addresses` cross-checks that
               both sides declare the SAME address, and a tilemap span cannot —
               the golden's `wTileMap` is 20 wide at `$C3A1`, the port's canvas
               is 40 wide with the (+10,+3) battle projection at `$C423`. The
               check exists to catch a label moving on one side only, so it is
               doing its job; it simply has no notion of a PROJECTED span.
             * **THE TOOLING GAP IS CLOSED AND THE WITNESS IS LIVE
               (2026-08-13).** `check_addresses` gained a third, DECLARED case:
               a scenario may list `"projected": {name: (col, row)}`, and both
               addresses are then RECOMPUTED from each side's own `wTileMap`
               base, that side's stride, and the scenario's `window` — and
               ASSERTED. It is deliberately NOT a skip: this is strictly
               STRONGER than the address equality it replaces for these
               regions, because it pins which CELL the span covers on both
               sides, so a wrong row, a wrong column or a wrong window all
               fail.
               * `battle_wrap` now carries `eHudName` GB(1,0) 10B and `eHudLv`
                 GB(0,1) 12B on both sides and PASSES.
               * **WITNESS NON-VACUITY:** removing the status-vs-level call
                 makes it FAIL with exactly
                 `eHudLv +4..+7: want $7F $92 $8B $8F | got $6E $F7 $F9 $7F` —
                 blank+"SLP" against ":L13", i.e. the precise defect.
               * **CHECK NON-VACUITY:** mis-declaring `eHudLv` as GB(0,2)
                 instead of (0,1) is rejected with
                 `projected at GB (0,2) => golden should be $C3C8, dump says
                 $C3B4` and the matching port line. The new case can fail.
               * Golden regenerated surgically: regions 19 -> 21, added exactly
                 `['eHudLv','eHudName']`, no pre-existing region's bytes
                 changed, frame unchanged at 7039.
               * **This is the first rendered-surface witness on a `datastruct`
                 scenario**, and the pattern generalises: a static sub-rectangle
                 can be pinned without promoting a whole timing-coupled screen.
               * **IT RETROACTIVELY WITNESSES `ClearScreenArea` TOO
                 (`08558f48d`), which was probed 2026-08-13 as witnessed by
                 NOTHING in the suite.** Re-running that probe — both HUD clears
                 deleted — now FAILS `battle_wrap` with
                 `eHudLv +4: want $7F | got $6E`: exactly the stale `:L` glyph
                 measured by hand when the fix landed. One span, two fixes
                 gated.
               * **THE PLAYER HUD IS COVERED TOO (2026-08-13).** Four more
                 projected spans on the same scenario — `pHudName` GB(10,7)x11,
                 `pHudLv` GB(14,8)x6, `pHudBar` GB(10,9)x9, `pHudFrac`
                 GB(11,10)x8 — all confirmed byte-identical to hardware before
                 being added. They gate the two HUD fixes that had NO witness:
                 `DrawHP` (`8b9e53060`, whose switch measured 0 changed cells,
                 so nothing could see it) and `PrintLevel` (`3beebbb9c`).
                 * NON-VACUITY: skipping the `DrawHP` call fails with **16
                   unmasked divergences**, all in `pHudBar` (9) and `pHudFrac`
                   (7 of 8 — one byte coincidentally matches).
                 * Golden regenerated surgically again: regions 21 -> 25, added
                   exactly the four `pHud*` names, no pre-existing region's
                   bytes changed, frame unchanged at 7039.
               * Net: `battle_wrap` went from pinning WRAM only to gating FOUR
                 previously unwitnessed fixes — the status rule, the HUD clear,
                 `DrawHP` and `PrintLevel` — without promoting its
                 timing-coupled screen.
               * **AND THE SPANS IMMEDIATELY FOUND A REGRESSION I HAD
                 INTRODUCED (2026-08-13).** Before adding the same spans to
                 `battle_item_potion` I checked them against its golden, as the
                 recipe requires. Five of six match — including `pHudBar`
                 `71 62 6b 6b 63 63 63 63 6d`, the PARTIAL-bar path that
                 `battle_wrap`'s full bar cannot exercise. But `pHudFrac` does
                 not: the port reads `7f 7f 7f 7f 7f 7f 7f 73` (blank) where
                 hardware reads `f7 f8 f6 f3 f9 fc f8 73` = "120/362".
                 * **Cause measured, not guessed:** deleting ONLY the
                   player-half `ClearScreenArea` makes the port draw
                   `f7 f6 f6 f3 f9 fc f8 73` instead of blanks. The clear I
                   restored in `08558f48d` wipes the fraction and the
                   `AnimateHPBar` sweep paths (potion / drain / heal, via
                   `UpdateCurMonHPBar`) never restore it.
                 * **The clear is FAITHFUL and must stay** — pret does it, and
                   deleting it reintroduces the stale-glyph defect that
                   `eHudLv` now catches. The defect is that the port's
                   port-only sweep lacks pret's per-step `DrawHP` redraw.
                   `BUG{class=projection}` filed at the clear site; memory
                   `regression-battle-hp-fraction-blanked-by-hud-clear`.
                 * **FIXED 2026-08-13, and the filed diagnosis was WRONG.**
                   The fraction was never "not restored": `DrawHP` DID redraw
                   it, with the correct value, at the WRONG PLACE. `DrawHP` is
                   stride-parameterised through `text_row_stride` so one
                   routine serves the 20-wide status/party screens and the
                   40-wide battle canvas, and it puts the fraction at
                   `bar + stride + 1`. The bag/item flow leaves the stride at
                   20, so the fraction landed at canvas **row 13, col 1** —
                   one 20-cell step below the bar instead of one 40-cell step.
                   That is OFF the GB-projected window (which starts at col
                   10), so the golden could never see it while it sat plainly
                   on the port's widescreen screen; the HUD's own cells were
                   left blank by the `ClearScreenArea`.
                 * Fix: republish the canvas stride at the `DrawHP` call site,
                   with a `DEVIATION{class=projection}`. MEASURED after:
                   the fraction reads `f7 f8 f6 f3 f9 fc f8 73` at
                   `bar+40+1` — byte-identical to hardware's "120/362" — and
                   `bar+20+1` is all `7f`, i.e. the stray text is gone.
                 * **The fix made the fraction DETERMINISTIC, which un-blocked
                   the span I had deferred.** All SIX spans now match on
                   `battle_item_potion` and are registered there. It is the
                   only witness for `draw_hp_bar`'s PARTIAL-segment path — its
                   bar is `71 62 6b 6b 63 63 63 63 6d` (120/362), where
                   `battle_wrap`'s is full and cannot exercise it.
                 * NON-VACUITY: removing the stride republish fails
                   `battle_item_potion` with **7 unmasked divergences**, all
                   `pHudFrac` (`want $F7 | got $7F`, …). Golden regenerated
                   surgically: regions 17 -> 23, exactly the six names, no
                   pre-existing region's bytes changed, frame unchanged at
                   6163.
      - **THE STRIDE LEAK WAS SWEPT AS A CLASS 2026-08-13, AND IT CAME UP
        CLEAN.** The fix above raised an obvious question the goldens cannot
        answer: **the compared window is GB cols 10-29, so ANYTHING the port
        draws outside it is invisible to every scenario by construction.** That
        is exactly where the stray `120/362` had been hiding.
        * **The check:** dump the port's whole 40x25 canvas and report every
          non-blank cell at canvas cols 0-9 or 30-39. Cheap, and it needs no
          golden at all — hardware has no opinion about those columns.
        * **Result: 0 stray cells across five battle scenarios** —
          `battle_item_potion` (post-fix), `battle_wrap`, `battle_menu`,
          `battle_safari`, `battle_faint`.
        * **NON-VACUITY, from the pre-fix dump:** the same scan on the
          PRE-fix potion run reports exactly 7 cells —
          `F7 F8 F6 F3 F9 FC F8` at row 13, cols 1-7 = "120/362". The zero is
          a real zero.
        * Every other `text_row_stride` consumer was classified while sweeping.
          Safe by caller: `print_type.asm`'s two reads are `PrintMonType` /
          `EraseType2Text`, whose only caller `StatusScreen` sets 40
          explicitly; `PrintMoveType` reaches `PlaceString` and never touches
          the stride. `home/pokemon.asm:539` places the 7x7 pic at the runtime
          stride, but it draws INSIDE the window so the goldens do gate it.
          Structurally identical to the bug, so it was chased to a conclusion:
          `UpdateHPBar_PrintHPNumber` (`hp_bar.asm:285`) uses the same
          `stride + 1` expression and is reached from `ItemUseMedicine` and
          `AIPrintItemUseAndUpdateHPBar`. **BOTH SITES ARE SAFE, for two
          DIFFERENT reasons, and settling it produced the invariant:**
          * `ItemUseMedicine` sets `BIT_PARTY_MENU_HP_BAR` before the call, and
            the routine then overwrites ECX with **9** — a pure horizontal
            offset — so the stride is NEVER READ on that path.
          * `AIPrintItemUseAndUpdateHPBar` begins with `AIPrintItemUse_`, which
            tail-jumps to `PrintBattleText` -> `PrintText`, and `PrintText`
            republishes the stride from `[text_msgbox]`. The battle record
            `msgbox_centered` (`core.asm:1335`) has `MB_STRIDE = FW` = 40, so
            the stride is freshly correct when read.
          * **THE INVARIANT:** a stride reader is safe iff EITHER it never
            reaches the stride branch, OR a battle `PrintText` immediately
            precedes it. Anything else must republish.
          * **And that is why `DrawHP` was the one that broke.**
            `DrawPlayerHUDAndHPBar` is reached from HUD-redraw paths with no
            battle `PrintText` immediately before — after the bag menu the last
            `PrintText` used a different msgbox record. It satisfied neither
            condition, so it had to republish. The fix now has a reason rather
            than being a patch. Memory:
            `golden-window-hides-the-canvas-margins`.
             Both halves now print the status condition one cell right of the
             level cell and print the level only when there is none, per pret
             :1913-1918 / :1963-1972. **HARDWARE TRUTH CAME OUT OF THE GOLDEN
             BLOBS**: `battle_wrap` and `battle_bide` seed `wEnemyMonStatus`
             05/06 and their golden `wTileMap[24:28]` is `7f 92 8b 8f` — blank
             then "SLP" — where the port was writing `:L13`. Seven battle
             scenarios seed enemy SLP, but ALL of them are `class: datastruct`
             and never compare the tilemap, which is why nothing ever failed.
             `PrintStatusConditionNotFainted` needed a `global` in
             `home/pokemon.asm`; it had never been exported.
             * Residual, and it is item 1 below, now with a number: the port's
               enemy LV cells read `6e 92 8b 8f` against hardware's
               `7f 92 8b 8f`. The "SLP" matches exactly; cell 174 keeps a stale
               `6e` (the `:L` glyph) from an earlier draw because the port skips
               pret's leading `ClearScreenArea`. Measured with `run_headless
               DEBUG_BATTLE_WRAP=1`.
             * `PrintLevel` itself stays dropped — the port keeps its own
               `print_level`. That is fork item 3, not this one.
          3. `PrintLevel` dropped — FIXED 2026-08-13 (`77e8fa968`). Both
             halves now call pret's `PrintLevel` (`home/pokemon.asm`, already
             hardware-gated by `status_p1` / `party_menu`) instead of the
             port-only duplicate `print_level`, now dead and unexported.
             * **The two changes had to land in this order.** pret's
               `PrintLevel` runs `PrintNumber` with `LEFT_ALIGN`, which for a
               leading zero writes NOTHING and does not advance the cursor —
               it relies on the `ClearScreenArea` restored in item 1 having
               blanked the cell. The port's `print_level` padded with a leading
               SPACE instead, which is what a printer without a clear has to
               do. Fixing the printer first would have left a stale glyph.
             * MEASURED, two-digit case (every level any scenario uses):
               **0 canvas cells changed** by the switch.
             * MEASURED, one-digit case, the only case that differs —
               `run_headless DEBUG_BATTLE_WRAP=1`, `wEnemyMonLevel` poked to 5
               and the SLP cleared, same build, old path vs new:
               old `6e 7f fb 7f` = `:L 5`; new `6e fb 7f 7f` = `:L5`. pret's
               is the left-aligned form. All pokes reverted before gating.
             * NOT claimed: no hardware golden contains a single-digit level,
               so that case is verified against pret's routine, not mGBA.
          4. `DrawHP` / `DrawHPBar` / `Multiply` / `Divide` dropped in favour
             of the port's `calc_hp_pixels` + `draw_hp_bar` — the last of the
             fork class and the biggest: the whole HP-bar pixel computation,
             not a printer. **ANALYSED 2026-08-13 and it is TWO items, one
             actionable and one blocked. Not attempted; this is the analysis,
             not a fix.**
             * **PLAYER HALF DONE 2026-08-13.** It now runs pret's
               `ld a,[wLoadedMonSpecies] / ld [wCurPartySpecies],a /
               hlcoord 10,9 / predef DrawHP`, replacing the port-only
               `calc_hp_pixels` + `draw_hp_bar` + `hud_print_num3` trio.
               **`DrawPlayerHUDAndHPBar` faithdiff is now 9 pret / 9 port with
               9 MATCHED — zero DROPPED, zero ADDED calls**, and the
               `[wCurPartySpecies]` store matches too. The three store lines
               left are the documented `hAutoBGTransferEnabled` deviation and
               two ADDEDs that are the faithdiff store-matching limitation
               (pret writes `wLowHealthAlarm` / `wChannelSoundIDs` through
               `hl`).
               * The offset question this box flagged RESOLVED by reading
                 `macros/ram.asm`: copy 1 moves battle_struct offsets 0..11 into
                 party_struct 0..11 (same fields, so `wLoadedMonHP` is right),
                 copy 2 moves battle_struct `Level..Special` into party_struct
                 `Level..Special` (so `wLoadedMonMaxHP` at party offset 34 is
                 right). The two structs genuinely differ in the middle, which
                 is why it needed checking.
               * `DrawHP` returns DL = bar pixels, which is exactly what
                 `GetBattleHealthBarColor` consumes next — that return is why
                 pret can order them this way, and the port now does.
               * MEASURED: `run_headless DEBUG_BATTLE_WRAP=1` before vs after,
                 **0 canvas cells changed**, and the player rectangle is 0/55
                 mismatches against the hardware golden. Because "0 changed"
                 is only worth as much as the check's sensitivity, a second
                 very different input was probed — HP poked to 7 of 362 — and
                 `DrawHP` produced `__7/362` with a 1-pixel gauge sliver, i.e.
                 the right cells and the right right-aligned formatting.
               * Dead after the switch and removed: `print_level`,
                 `print_num2`. NOT removed: `draw_hp_bar`, which is still live
                 — `AnimateHPBar` tail-jumps to it (`battle_hud.asm:375`).
                 Checking that before deleting is the whole reason it survived.
             * *(historical)* **Player half — plausibly actionable.** pret does
               `hlcoord 10,9 / predef DrawHP`, and `DrawHP` draws the bar AND
               the "cur/max" fraction. The port's coordinates already line up:
               `UI_PLAYER_HPBAR` is GB(10,9) and `UI_PLAYER_HPFRAC` is
               GB(11,10), which is where `DrawHP` puts the fraction. The player
               bar also already uses the standard `$62/$63/$6b/$6d` tiles that
               `DrawHPBar` hardcodes, so there is no tile conflict on this side.
               MUST BE CHECKED FIRST, and is the reason this was not attempted
               in the same iteration: `DrawHP` reads `wLoadedMonHP` /
               `wLoadedMonMaxHP`, and the port's player half stages `wLoadedMon`
               with `CopyData` over `wBattleMonSpecies .. wBattleMonDVs` — the
               MaxHP offset inside `wBattleMon` is NOT obviously the one
               `wLoadedMon` uses, and getting that wrong silently draws the
               wrong bar length rather than failing.
             * **Enemy half — BLOCKED on a deliberate port design, not on
               effort.** pret's `DrawHPBar` writes the literal tile IDs
               `$63-$6b`. The port's enemy bar deliberately uses CLONES of
               those patterns at `$C0+` (`DuplicateEnemyHPBarTiles`,
               `battle_hud.asm`) so the two HP bars can own distinct palette
               slots — that is exactly the 6-cell difference decomposed under
               item 1. Calling pret's `DrawHPBar` on the enemy side would write
               the shared IDs and destroy that mechanism. Retiring this fork
               needs a decision about how the enemy bar gets its own palette
               slot without a second implementation; it is not a translation
               task. ~~**Maintainer input wanted.**~~ **RESOLVED 2026-08-14 —
               there is no separate decision to make: retiring the clone
               mechanism IS retiring F-19, so this is 6e's blocker (the CGB
               per-cell BG attribute plane) reached from the other end. See
               this box's closing note.**
          5. The low-health alarm — FIXED, below.
      * **THE LOW-HEALTH ALARM NEVER ARMED — FIXED 2026-08-13.** pret's
        `DrawPlayerHUDAndHPBar.setLowHealthAlarm` tail is the game's ONLY
        setter of `BIT_LOW_HEALTH_ALARM` and had no port counterpart, so the
        red-HP beeping could not sound in any battle. All nine port writes to
        `wLowHealthAlarm` were enumerated: eight are clears or a save/restore,
        and the ninth (`low_health_alarm.asm:48`) re-ORs the bit INSIDE
        `Music_DoLowHealthAlarm`, which returns at :23 unless the bit is
        already set — so the alarm could perpetuate but never start. Tail now
        translated, with `wLowHealthAlarmDisabled` added to the memmap at
        `0xCCF6` taken from `pokeyellow.sym`, not inferred.
        * **No scenario can witness it** (none drives the player mon to red
          HP, and no dumped region covers `0xD082`), so it was measured
          directly: a temporary `wLowHealthAlarm` region row plus a 1-HP poke,
          two `run_headless` runs of `DEBUG_BATTLE_MENU` differing only in
          whether the tail runs. With the tail `wLowHealthAlarm = 0x83` (bit 7
          set, timer 3); without it `0x00`; `wBattleMonHP = 0001` in both. All
          three temporary edits reverted before the gates ran.
        * Still owed: a permanent witness — **and the reason recorded here was
          WRONG, corrected 2026-08-13.** It said adding a region "changes the
          GBSTATE schema for all 69 goldens". It does not: a SCENARIO-LOCAL row
          regenerates ONE golden, and that path is now proven end to end (see
          the Stage-5 `wTransSpiral` checkpoint, `1b915a3ed`).
        * **What is actually owed is STAGING, not a region — and 2026-08-13
          sharpened WHICH staging, by trying the best candidate and failing.**
          `battle_choose_next_mon` DOES seed a mon at red HP: slot 3,
          STARTER_PIKACHU L5 **at 1 HP**, and it is sent out, so the arming
          path genuinely runs mid-scenario. A `wLowHealthAlarm` region was
          added to both sides and the golden regenerated to check.
          **HARDWARE READS `00` AT THE DUMP** — by then the Pikachu has
          fainted and LAPRAS (139/139) is out, and the faint path clears the
          bit. The port agrees, so the scenario PASSES.
          * **But the row cannot DISCRIMINATE, which is what disqualifies it:**
            disabling the arming tail entirely **also passes**, because both
            states read `00` at a settled dump. Adding it would have been
            coverage that reads as clearance, so the whole probe — port row,
            Lua row and regenerated golden — was reverted.
          * **THE BLOCKER, STATED PRECISELY:** the alarm bit is TRANSIENT. It
            is set while a LIVE mon sits at red HP and cleared the moment that
            mon faints or is replaced. Every scenario's dump point is a settled
            post-faint state. A witness therefore needs a dump taken **WHILE a
            live mon is at red HP** — a dump-point constraint, not merely a
            "seed low HP" one. That is what no current scenario provides, and
            `battle_choose_next_mon` was the closest miss.
          * **CLOSED 2026-08-13 (`battle_low_hp`, scenario id 72).** A new
            scenario supplies exactly that dump point: `battle_menu`'s flow
            with party slot 0 seeded to **20/362 HP** (5.5%, inside
            `GetHealthBarColor`'s red band) and the mon still **ALIVE** when
            the dump is taken, so the arming window is caught open. The seed
            goes on the PARTY slot, not `wBattleMon`, so the real
            `LoadBattleMonFromParty` carries it across as it would in play;
            the Lua asserts `wBattleMonHP == 20` before dumping so a staging
            drift fails loudly instead of photographing a full-HP mon.
            * **CONFIRMED AGAINST HARDWARE — the first observation of the
              alarm ARMED on either side:** golden `wLowHealthAlarm = $91`,
              port `$83`, **both with bit 7 set**. `pHudBar`
              (`71 62 65 63 63 63 63 63 6d`) and `pHudFrac` (`" 20/362"`) are
              byte-identical, so the red-tier bar and its fraction render
              exactly right too.
            * **NON-VACUITY:** disabling the arming tail fails the scenario
              with `wLowHPAlarm +0: want $91 | got $00`, 1 unmasked
              divergence. This is the discrimination
              `battle_choose_next_mon` could not provide.
            * The low bits genuinely are not comparable — they are
              `LOW_HEALTH_TIMER_MASK`, the alarm's tone timer, ticked on each
              audio engine's own cadence (golden 17, port 3). A whole-byte
              `wram_mask` would have hidden bit 7 along with them, i.e. masked
              the thing under test, so `golden_diff` gained a narrow
              **`wram_bit_masks`** case that ignores named BITS of a byte and
              compares the rest. The probe above is its non-vacuity proof too,
              since bit 7 still reports through the mask.
      * **No permanent witness for `CenterMonName`.** Needs a scenario whose
        battle mon has a nickname of 4 characters or fewer; every current one
        is 5+ and therefore in the unshifted bucket. **Same correction as the
        alarm above: the blocker is STAGING, not the region schema.** The
        nickname is part of the compared `wBattleMonNick` region and the
        tilemap, so shortening it in an existing scenario changes what that
        scenario pins — hence a new scenario, not a row. Cheapest shape measured:
        the nickname is independent of species, so seeding
        `wPartyMonNicks` slot 0 on both sides (port debug gate + `seed.party`
        in `tools/mgba_harness/lib/seed.lua`) exercises the player HUD without
        touching species, stats or damage.
        * **SCENARIO LANDED AND ITS NON-VACUITY PROBE PASSED 2026-08-13 —
          `battle_short_nick` (id 73).** Deleting only the player-side
          `CenterMonName` call made `goldencheck` fail on exactly five
          `pHudName` bytes: `+0 want $7F got $80`, then the four ABRA glyphs
          shifted one cell left. Restoring the call returned the scenario to
          `WRAM: OK (14 regions, 0 skipped)`, so the scenario both reaches the
          call and distinguishes its one-column 3-4-character result.
          It is `battle_menu`'s flow with party slot 0 renamed to a FOUR-letter
          name. Four and not two on purpose: only the 3-4 bucket runs BOTH of
          `CenterMonName`'s pair iterations and its 8-bit `dec bh` counter.
        * The name is ABRA's, read from the ROM/`MonsterNames` table on BOTH
          sides (`GetMonName` on the port, an exported `seed.monster_name` on
          the golden) — so no charmap byte is hand-encoded and the two sides
          cannot drift on the encoding. Only the NICKNAME changes; species,
          stats and DVs stay exactly as `battle_menu` has them.
        * **THE GOLDEN SHOWS THE SHIFT DIRECTLY**, which is the measurement
          that matters: `pHudName` at GB (10,7) reads
          `7f 80 81 91 80 7f ...` — a BLANK at column 10, then "ABRA" at
          column 11. An unshifted draw would read `80 81 91 80 7f ...`.
          `wBattleMonNick` = `80 81 91 80 50` = `ABRA@`. The port matches:
          `goldencheck battle_short_nick` PASS, WRAM 14 regions 0 skipped.
        * Both sides assert the seed reached `wBattleMonNick` before dumping,
          so a staging drift fails loudly rather than photographing SNORLAX.
        * Trap banked on the way (cost one build): `extern` + `equ` added next
          to `extern GetMoveName` landed INSIDE that file's
          `%ifdef DEBUG_ANIM_SHOW` block, so both symbols were undefined in
          this build. NASM sized the forward references at 32 bits and then
          shrank, failing with 15 `label ... changed during code generation`
          errors pointing at unrelated routines 1800 lines away. The
          declare-before-use rule has a CONDITIONAL form: check which `%ifdef`
          you are inside, not just the line number.
      * **`SlideTrainerPicOffScreen`** — the one translatable member of the old
        intro-slide grouping. **LANDED 2026-08-14** (`cd3257078` translation,
        `74707909c` player-side call site); no longer dropped under
        `ANIMATION=OFF`, port callers 0 -> 2. Details in the closed inventory
        box above.

- [x] **DONE 2026-08-13/14.** 2 stubs retired (`IsPlayerPikachuAsleepInParty`,
      `FormatMovesString` — the latter needed a real port bug fixed first, see
      below), the other 7 measured as NOT stand-ins, 3 stale claims swept, and 2
      dead allowlist `suppress` rows retired with the maintainer's hash approval.
      `label_status --callers`, `update_label_db`, both lint modes and
      `fidelity_gate` all run. Detail below.
      Remove temporary guards and stand-ins whose real providers landed. Run
      `label_status --callers` for each retired stub, update the label DB, run
      default/strict label lint and `fidelity_gate`, and sweep related `STUB`,
      `TODO-HW`, extern-provider, allowlist, plan, skill, and stigmergy claims.
      - **INVENTORY 2026-08-13 — 9 battle-area stubs, 1 RETIRED, 8 classified.**
        * **RETIRED: `IsPlayerPikachuAsleepInParty`.** Every dependency was
          already present (`IsThisPartyMonStarterPikachu` and `AddNTimes` both
          `translated`; `STARTER_PIKACHU` and `SLP_MASK` both defined), so it
          was translated into a new mirror file
          `dos_port/src/engine/pikachu/pikachu_emotions.asm` — pret's path, not
          a neighbour. `stub` -> `translated`, faithdiff **CLEAN** (2/2 calls,
          1/1 stores).
        * The retirement SWEEP is the part the box is really about, and it had
          teeth: removing the stub made `lint_pret_labels` fail with **2
          `stale_extern` findings** — `core.asm` and `common_text.asm` both had
          extern comments still pointing at `pikachu_stubs.asm`. Both swept,
          along with two `(STUB, returns CF=0)` call-site comments and a
          `SendOutMon` header that still listed it as one of three ret-stubs.
          Lint back to 0 in both modes.
        * **REACHED BUT NOT WITNESSED — measured, and the distinction matters.**
          The debug party seeds `STARTER_PIKACHU` at slot 3 and
          `battle_choose_next_mon` sends it out, so `SendOutMon.starterPikachu`
          really does execute the routine. But inverting it to always report
          "asleep" **still PASSES** that scenario: the CF result only chooses
          between two Pikachu cry clips, which nothing compares. So the path is
          `executed`, the result is not `observed`.
        * **STILL STUBBED (7 after the FormatMovesString retirement below),
          with the reason each is not retirable now:**
          `TradeHidePokemon`, `TradeShakePokeball`, `TradeJumpPokeball`,
          `LinkBattleExchangeData` — link/serial, a Phase-4 HAL boundary;
          `StarterPikachuBattleEntranceAnimation` — an untranslated pret
          routine (`engine/battle/pikachu_entrance_anim.asm`); the old reason
          here said "animation, Stage 6", which is stale now that Stage 6's
          scenario box is closed — the deferral is that nothing has translated
          it, not that a stage owns it;
          `PrintSendOutMonMessage` — an untranslated pret routine, not a stub
          shadowing a landed provider;
          `RespawnOverworldPikachu` — explicitly deferred by box 3d.
      - **THE REMAINING 7 WERE RE-VERIFIED 2026-08-13, and none is a stand-in
        shadowing a landed provider** — which is the specific thing this box
        retires. Measured directly rather than re-read: each of
        `TradeHidePokemon`, `TradeShakePokeball`, `TradeJumpPokeball`,
        `LinkBattleExchangeData`, `StarterPikachuBattleEntranceAnimation`,
        `PrintSendOutMonMessage` and `RespawnOverworldPikachu` is defined in
        exactly ONE place — its own stub file — so the `FormatMovesString`
        pattern (a faithful body sitting unlinked elsewhere) does not repeat.
        Retiring any of them is new translation work, not a sweep.
      - **THE SWEEP FOUND THREE STALE CLAIMS ELSEWHERE, and two are NOT MINE TO
        FIX (2026-08-13).**
        * Swept: the `Makefile` `BATTLE_SRCS` comment still listed
          `misc/InitList` as a deferred closure and `FormatMovesString` as
          link-time-stubbed by `core_stubs.asm`; and
          `docs/bug_categorization.md` recorded a spot-check confirming
          `misc.asm` "is still check-only". Both corrected.
        * **MAINTAINER ACTION OWED — two `suppress` rows in
          `dos_port/tools/pret_label_allowlist.json`, both keyed
          `FormatMovesString`, are now stale debt:** the `dup_def` row ("known
          interim: core_stubs.asm body is linked; misc.asm's is check-only" —
          there is no dup any more) and the `non_ret_stub` row, whose own stated
          resolution was "should move to a non-stub file **or ride misc.asm's
          promotion**" — which is exactly what happened. **Agents may not edit
          that registry**, so they are reported here rather than removed.
      - **`FormatMovesString` WAS MISCLASSIFIED ABOVE, AND CHASING IT FOUND A
        REAL DEFECT (2026-08-13).** The line above used to group it with
        `PrintSendOutMonMessage` as "an untranslated pret routine". It is not:
        `label_status` reports it **`translated`**, with a faithful body in the
        mirror `src/engine/battle/misc.asm` AND a stand-in in `core_stubs.asm`
        — exactly the "stand-in shadowing a landed provider" shape this box
        exists to retire.
        * **The stand-in's stated reason is FALSE.** It reads "GetName/names.asm
          is not yet link-ready (TrainerNames is undefined)". `TrainerNames` is
          defined in `assets/trainer_names.inc`, `names2.o` links, and the
          symbol RESOLVES in `PKMN.EXE` at `0x00170475`.
        * **RETIRED 2026-08-13 — but only after fixing the REAL PORT BUG the
          first attempt exposed.** The port's `GetName`
          clobbers `EBX`/`EDX`/`ESI` where pret's preserves `BC`/`DE`/`HL`
          (`home/names2.asm`: `push af/hl/bc/de` … `pop de/pop bc/pop hl`).
          `FormatMovesString` keeps its move-slot counter in `BH` across
          `call GetName`, exactly as pret keeps it in `B`, so linking the
          faithful body destroys the loop bound and the writer runs away across
          WRAM. MEASURED: build and link CLEAN, faithdiff CLEAN on both
          `misc.asm` routines — and `goldencheck move_selection` then produces
          **no `GBSTATE.BIN` at all**. Same shape as the EXP ALL crash.
        * **THE FIX (2026-08-13), and it had to respect two tail-jumps.** The
          port's `GetName` leaves its own body twice — `jae GetMachineName` and
          `je GetMonName` — so a naive push/pop epilogue would be bypassed on
          both. pret's structure decides it: the `HM01` test happens BEFORE the
          pushes (so that tail-jump is faithful and stays), and MONSTER_NAME is
          a `call GetMonName` INSIDE them. The port now matches: `push esi/ebx/edx`
          after the HM01 branch, `.otherEntries` for the walk, and a single
          `.gotPtr` epilogue popping `edx/ebx/esi` that BOTH paths — including
          the `BUG_FIX_LEVEL >= 2` runaway guard — fall through to.
          * **faithdiff is UNCHANGED by the fix**, byte-for-byte against the
            baseline: 2/4 calls matched with `BankswitchCommon` (flat model) and
            `CopyData` (hand-rolled bounded copy) DROPPED, `[hSwapTemp]` DROPPED
            and `[wNameBuffer]` ADDED — all pre-existing and already sanctioned;
            lint 0 in both modes. The fix adds and drops nothing.
          * **NON-VACUITY, decomposed:** with `misc.asm` linked, reverting ONLY
            `names2.asm` reproduces the crash exactly — `goldencheck
            move_selection` again produces **no `GBSTATE.BIN` at all**. With the
            fix, `move_selection` and `status_p2` both PASS. So the register
            contract is the whole difference.
          * Recorded as `regression-getname-does-not-preserve-bc` (FIXED).
        * **AND THE STAND-IN IS GONE.** `misc.asm` is promoted to
          `FRONTEND_SRCS` and the `FormatMovesString` body in `core_stubs.asm`
          is deleted, so the live routine is now the faithful mirror. Battle
          stub inventory: **9 -> 7 retired-or-classified** (2 retired this
          stage: `IsPlayerPikachuAsleepInParty`, `FormatMovesString`).
        * **KEPT from the first attempt** (all safe, `make check` green): the
          `wInitListType`/`wItemPrices` WRAM equs and the five `INIT_*_LIST`
          selectors added to the includes; the seven bogus `extern`s deleted
          from `misc.asm` (they are equs/immediates, the case that file's own
          header note describes); and `misc.asm`'s `mov al, '-'` corrected to
          `0xE3` — NASM would assemble the literal to ASCII `0x2D`, while pret's
          charmap maps `-` to `$e3` (`constants/charmap.asm:163`). The file is
          now link-ready apart from the `GetName` bug.
        * **The witnesses are already in place for the eventual swap:**
          `FormatMovesString` has three callers — `MoveSelectionMenu`,
          `TryingToLearn`, `StatusScreen2` — and two are gated by tilemap-
          comparing scenarios, `move_selection` and `status_p2`, both PASSing.
- [x] Run targeted scenarios, the core tier, `fidelity-full`, and
      `goldens-verify` when scenario/golden artifacts changed. Close or transfer
      every battle-owned mask/finding with explicit evidence.
      - **ALL FOUR RAN GREEN ON THIS TREE, 2026-08-14, and each is decomposed
        rather than quoted as a total** — a bare "0 differences" is the aggregate
        this plan's preamble forbids:
        * **targeted:** `goldencheck battle_safari_result` and
          `goldencheck battle_run_type`, each PASS on its first check, each with
          a named non-vacuity probe (49 unmasked tilemap divergences; a no-dump
          failure).
        * **core tier:** `reported=16/16 nonzero=0`.
        * **`fidelity-full`:** `reported=80/80 nonzero=0`. Reported per
          `pgate`'s gap check, which is the part that matters — a scenario that
          never runs emits neither PASS nor FAIL, and this run's `reported`
          count equals the registry count.
        * **`goldens-verify`:** exit 0, **81 goldens regenerated and compared,
          81 dumps written, 0 `differs`**. The log carries 85 headers, and the
          4 without a dump are `battle_palette_trace`, `item_palette_trace`,
          `oak_palette_trace` and `title_trace` — `*_trace` recorders that have
          no committed golden and are skipped by design, NOT silent failures.
          Both goldens added this session are in the compared set
          (`battle_run_type` at log line 252, `battle_safari_result` at 274).
      - **The mask half of this box is "transfer", and the inventory below IS
        that transfer**: every battle-owned mask names the condition that
        retires it, and none is closable today. No mask was added this session —
        the two new scenarios reuse the three pre-existing shared families
        verbatim.
      - **MASK INVENTORY, MEASURED 2026-08-14 (enumerated from `golden_diff.py`,
        not recalled).** 76 scenario entries, 27 battle-ish. There are exactly
        THREE shared mask families plus SEVEN per-scenario masks, and **none is
        closable today** — each is either blocked on 6e or is a documented
        structural asymmetry. Each row names what retires it, which is the
        "transfer" this box asks for:
        | mask | what it covers | retired by |
        |---|---|---|
        | `_BATTLE_TILEMAP_MASKS_MENU` (8 users) | GB (2,4)-(2,9), the 6 enemy-gauge cells | **F-19** — now the CGB colour plan's Stage 5 (6e transferred out 2026-08-14); blocked on CGB per-cell BG attributes |
        | `_BATTLE_VRAM_MASKS_MENU` slots `$C0-$C9` (8 users) | the F-19 gauge CLONE slots | **F-19** — same, CGB plan Stage 5 |
        | `_BATTLE_VRAM_MASKS_MENU` slots `$00-$7F` (8 users) | the `$8000-$87FF` anim/pic bank post-send-out | the port draws from the COMPARED `$93xx` copies; retires only if the port stops mirroring pics into `$80xx` |
        | `_BATTLE_WRAM_MASKS` -> `wOptionsBlock +3` (27 users) | `wLetterPrintingDelayFlags` | sanctioned draw-layer divergence (`PlaceString` always delays); retires with a per-message text-delay gate |
        | `wLoadedMon` per-scenario (7: `battle_faint`, `battle_blackout`, `battle_exp_all`, and the four `battle_anim_*`) | staging-buffer residue at +23/+24 and +33 | route asymmetry between a synthetic gate and the menu path — retires if a gate ever reaches its landmark through the real menu |
        * **The `$00-$7F` VRAM mask is the one with teeth**, and that was
          measured this session: it is what made the first option-off landmark
          blind (see the box above). Any future battle scenario whose subject
          lives in `$8000-$87FF` cannot be witnessed by this family.
        * **`wLoadedMon +23..+24` is precedent-covered, not novel** —
          `battle_blackout` has masked it since 2026-07-26 with the same
          `$9876`/`$0000` values.
- [ ] Archive only when `project_state --plans` reports no open checklist items
      here and the default game can enter, play, and exit all in-scope battle
      types through their owning live routes.
      - **RESOLVED 2026-08-14 — the maintainer took option 1: 6e is TRANSFERRED
        to the CGB colour plan** (its Stage 5, same artifact URL). This plan no
        longer holds an item that waits on out-of-repo work, so the FIRST clause
        of this box is satisfiable from here. The second clause below is not,
        and is what still holds archival.
      - **THE PLAN'S TERMINAL STATE, as of 2026-08-14 — and it needs a
        maintainer decision, not more work here.** With box 2225 and the gates
        box closed, the ONLY thing standing between this plan and archival is
        **6e**, and 6e is blocked on the CGB per-cell BG attribute plane, which
        is another plan's Stage 1 and lives OUTSIDE this repo (maintainer-
        confirmed). 6e's own text already says "Nothing in this box should be
        attempted here."
      - So this condition, as written, can never be met from inside this plan:
        archival waits on zero open items, and one open item waits on work that
        is deliberately not in this repository. The two ways out are both the
        maintainer's call:
        1. **Transfer 6e** to the CGB colour plan that owns its blocker, leaving
           this plan archivable now; or
        2. **Keep 6e here** and accept that this plan stays open as the holder
           of the F-19 mask retirement until that plan's Stage 1 lands.
        Option 1 is the one consistent with how this plan has handled every
        other cross-plan tail (`battle_transitions`, `battle_animations` were
        both archived with their open tails transferred by name), but moving a
        box between plans is not a change an agent should make unilaterally.
        **The maintainer chose option 1 on 2026-08-14 and it is executed.**
      - The second clause — "the default game can enter, play, and exit all
        in-scope battle types through their owning live routes" — is **NOT
        satisfied by the scenario work and must not be read as satisfied by
        it.** Every battle type now has golden coverage, but four of the five
        are reached through `RunBattleTest`'s synthetic staging, not through a
        live overworld route. `trainer_battle_route` (51) is the only live-route
        battle in the suite. This clause is about playing the game, and it wants
        a human at the controls.

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
