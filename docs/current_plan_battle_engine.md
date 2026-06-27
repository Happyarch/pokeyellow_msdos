# Current Plan: Battle Engine Backend

The combat logic beneath the (deferred) battle UI: WRAM/constant foundations,
the type-effectiveness data, the damage-calculation pipeline, move hit/accuracy,
stat-stage modifiers, status conditions, turn ordering, the existing move-effect
drafts, trainer AI logic, and wild-encounter generation.

**Scope note (per user, 2026-06-26):** the *front end* (HUD rendering, battle
transitions, animations, move-select/party menus, text/animation timing) is
**deferred for manual verification** — it can't be validated headless. This plan
builds only the **backend** (pure logic + data), verified by NASM assembly and,
where the routine is pure computation, native ELF32 harnesses against canonical
Gen-1 values (the same method that validated the pokemon engine).

**Sequencing:** Pokémon (done) → items (done) → **battle** (here).

## Hard lessons inherited (apply to every routine)

From `current_plan_pokemon_engine.md`:
1. **Audit every draft against pret before wiring it; do not trust swarm code.**
   Common bugs: `ld a,[hli]` (read THEN increment) mistranslated as increment-
   then-read; flat data tables (program-image labels) wrongly read as `[ebp+esi]`
   (double-EBP → segfault) — flat tables are `[esi]`, EBP-relative GB memory is
   `[ebp+esi]`; dropped `edx` across `mul`/`div`; SM83 mnemonics (`sbc`, `hl`)
   left in place (never assembled).
2. **Validate natively, not just by building.** Running the EXE needs a DPMI host
   the sandbox lacks. Assemble `-f elf32`, link a tiny ELF harness (`ld -m
   elf_i386`) that sets `ebp` to a 64 KB buffer, call the routine, compare to
   canonical Gen-1 values.

Authoritative addresses: `git show origin/symbols:pokeyellow.sym` (bank:addr).

## Stages

- [x] **Stage 1 — Foundations (constants + WRAM aliases).** Add battle/move/type/
  move-effect constants to `gb_constants.inc`; add all battle WRAM aliases
  (player/enemy battle-mon struct fields, stat mods, move struct, wDamage,
  wCriticalHitOrOHKO, wMoveMissed, wTypeEffectiveness, battle-status bytes,
  wDamageMultipliers, etc.) to `gb_memmap.inc`, sym-pinned. Unblocks everything.

- [x] **Stage 2 — Type-effectiveness data.** `tools/gen_type_matchups.py` →
  `assets/type_matchups.inc` (`TypeEffects`, 82 matchups + $FF). Plus the two
  small fixed tables `HighCriticalMoves` / `StatModifierRatios` embedded in
  `src/data/battle_data.asm`. Wired into Makefile.

- [x] **Stage 3 — Damage pipeline (core.asm subset).** Done in
  `src/engine/battle/core_damage.asm`: `GetDamageVarsForPlayerAttack/EnemyAttack`,
  `GetEnemyMonStat`, `CalculateDamage`, `JumpToOHKOMoveEffect`, `CriticalHitTest`,
  `AdjustDamageForMoveType`, `RandomizeDamage`, `BattleRandom`.
  **Native-validated** (ELF32 harness): CalculateDamage L50/P40/A100/D100=19,
  L100/P80/A150/D120=86, L5/P40/A20/D20=5, L100/P250/A255/D10=999 (997-cap +
  24-bit multiply path) — all exact. AdjustDamageForMoveType: GRASS-STAB vs WATER
  =300 (multipliers $94), FIRE vs WATER=50, GROUND vs FLYING=0+miss, ELECTRIC-STAB
  vs WATER=300 — all exact. (BattleRandom link path is a Phase-4 TODO-HW stub.)

- [x] **Stage 4 — Move hit test / accuracy.** `MoveHitTest` + `CalcHitChance`
  done in core_damage.asm (mist/substitute/invulnerable/X-Accuracy/accuracy-roll;
  stat-stage accuracy/evasion ratios via `StatModifierRatios`). `CheckTargetSubstitute`
  is a deferred extern. Type immune→miss branch validated above. (Runtime accuracy
  roll depends on BattleRandom; logic verified by assembly + structural audit.)

- [x] **Stage 5 — Stat-stage modifiers.** DONE. `ApplyBadgeStatBoosts` was already
  done + validated (Stage-1/badge_boosts.asm; see the log row). The stat up/down
  effect handlers `StatModifierUpEffect` / `StatModifierDownEffect` are now
  translated faithfully in `src/engine/battle/stat_mod_effects.asm` (incl. all
  flow helpers: UpdateStat(Done), RestoreOriginalStatModifier, UpdateLoweredStat-
  (Done), CantLowerAnymore(_Pop), MoveMissed, PrintNothingHappenedText) and wired
  into BATTLE_SRCS. The stat-stage **arithmetic** — mod ±1/±2 clamp to the 1..13
  range, recompute the affected stat via `StatModifierRatios` (Multiply/Divide,
  cap 999 / floor 1, already-999 revert) — is **native-validated** (ELF32, real
  Multiply/Divide + StatModifierRatios; UI stubbed). The presentation tail
  (PrintStatText, move animation, substitute/minimize, rose/fell/nothing text) is
  the deferred battle front end (extern, like the move_effects), so the file
  assembles but doesn't link yet. NOTE: there is **no `GetStatMod`** routine in
  pret — the "unmodified-stat recompute" the plan referenced is this inline
  ratio-recalc path (now done); the `unused_stats_functions.asm` Double/Halve
  helpers are dead glitch code and intentionally not ported.

- [x] **Stage 6 — Audit + wire existing swarm drafts.** Audited every draft
  against pret. All redundant externs (WRAM symbols now defined by Stage 1) were
  dropped, includes normalized, and redundant local `equ`s (shadowing the
  includes, all same-value) removed. Wired the assembling files into BATTLE_SRCS.
  **Audit results:**
  - **Correct as translated** (only the extern/include cleanup needed): the 13
    `move_effects/*` (spot-audited focus_energy, mist, conversion, haze, paralyze,
    one_hit_ko, recoil line-by-line — all faithful, incl. the OHKO speed-compare
    borrow and the recoil negative-offset HP pointer math), `misc.asm`,
    `get_trainer_name.asm`.
  - **`decrement_pp.asm` — rewrote, 2 bugs fixed**: missing gb_constants include;
    AddNTimes stride in CX instead of BX (helper reads BX).
  - **`experience.asm` — 6 mechanical bugs fixed (sbc→sbb ×3, cx→bx ×3) but
    NOT wired/validated**: deeply coupled to the deferred level-up/EXP subsystem
    + battle UI (CalcExperience, CalcLevelFromExperience, LearnMoveFromLevelUp,
    PrintStatsBox, FlagActionPredef, …) and lacks extern decls. Left out of
    BATTLE_SRCS; revisit when that subsystem exists.
  NOTE: BATTLE_SRCS assembles (`make check`) but does not yet *link* into the EXE
  — the move-effects call deferred UI/animation/text routines. That's expected;
  the front end is deferred per the user.

- [~] **Stage 7 — Status + turn helpers.** `ApplyBurnAndParalysisPenalties(ToPlayer/
  ToEnemy)`, `QuarterSpeedDueToParalysis`, `HalveAttackDueToBurn` done in
  `src/engine/battle/status_penalties.asm` and **native-validated** (Spd 200→50,
  2→1 min-clamp, Atk 100→50, unstatused 300→unchanged). These resolve the
  `QuarterSpeedDueToParalysis` extern the move-effects reference. `HandleBuildingRage`
  is now also done (`src/engine/battle/building_rage.asm`): when the attacked mon
  is under Rage it flips hWhoseTurn, injects a null move + ATTACK_UP1_EFFECT, runs
  `StatModifierUpEffect` (Stage 5), then restores the Rage move — **native-validated**
  end to end (raging → Atk mod 7→8 / stat 100→150 / move restored to RAGE; no-op when
  not raging or already at +6). REMAINING: residual poison/burn/leech-seed damage
  (`HandlePoisonBurnLeechSeed`, HUD-coupled) and the inline turn-order speed compare
  (in the deferred main battle loop).

- [~] **Stage 8 — Trainer AI backend.** `AIGetTypeEffectiveness` done in
  core_damage.asm (single-type effectiveness vs the player mon → wTypeEffectiveness;
  preserves the faithful `$10`-init bug and the Lorelei/Dewgong 40%-ignore case).
  Native-validated (WATER→FIRE=20, NORMAL→GRASS=16 [the bug], GROUND→FLYING=0,
  GRASS→WATER=20). REMAINING: the AI move-scoring layer (`AIMoveChoiceModification*`,
  trainer-class AI pointers) and `read_trainer_party.asm`.

- [x] **Stage 9 — Wild-encounter generation.** DONE. New generator
  `tools/gen_wild_encounters.py` → `assets/wild_data.inc`: `WildDataPointers`
  (249 = NUM_MAPS flat `dd` pointers, like EvosMovesPointerTable), the 60 unique
  per-map blobs (`[grass_rate (+20 mon bytes)][water_rate (+20)]`, species resolved
  to internal indices), and `WildMonEncounterSlotChances` (10 cumulative slots).
  Exposed via `src/data/wild_data.asm`; wired into the Makefile (`assets` target +
  `BATTLE_SRCS`). `LoadWildData` (`src/engine/overworld/wild_mons.asm`, flat→WRAM
  copy of the map's blob into wGrassRate/wGrassMons/wWaterRate/wWaterMons) and
  `TryDoWildEncounter` (`src/engine/battle/wild_encounters.asm`, the rate-compare +
  slot-roll + species/level pick + repel logic) both translated faithfully and
  **native-validated** (ELF32 harnesses; tables verified vs ROM). The overworld
  externs (door/warp/outside-map checks, repel text) are deferred — the overworld
  step **trigger** is the consumer — and the player-standing-tile read is a
  documented `; TODO-OVERWORLD` placeholder (the 40-wide port viewport differs from
  the GB's 20-wide centred screen). All three files assemble; they don't link into
  the EXE yet (overworld trigger + standing-tile offset deferred to the consumer).

## Verification log

Toolchain installed in the web container: NASM 2.16.01 (`apt`). No DPMI host /
no `-m32` libc, so pure-computation routines are validated with freestanding
NASM ELF32 harnesses (`nasm -f elf32` + `ld -m elf_i386`, syscalls), exactly the
method the pokemon-engine plan used.

| Routine | Inputs → output | Result |
|---|---|---|
| CalculateDamage | L50 P40 A100 D100 | 19 ✓ |
| CalculateDamage | L100 P80 A150 D120 | 86 ✓ |
| CalculateDamage | L5 P40 A20 D20 | 5 ✓ |
| CalculateDamage | L100 P250 A255 D10 (997-cap + 24-bit mul path) | 999 ✓ |
| AdjustDamageForMoveType | GRASS-STAB vs WATER, dmg 100 | 300, mult $94 ✓ |
| AdjustDamageForMoveType | FIRE vs WATER | 50 ✓ |
| AdjustDamageForMoveType | GROUND vs FLYING (immune) | 0 + wMoveMissed ✓ |
| ApplyBadgeStatBoosts | Atk100/Def900/Spd8/Spc255, all badges | 112/999(cap)/9/286 ✓ |
| QuarterSpeedDueToParalysis | Spd 200 / Spd 2 | 50 / 1(min) ✓ |
| HalveAttackDueToBurn | Atk 100 | 50 ✓ |
| (penalty, unstatused) | Spd 300 | 300 (unchanged) ✓ |
| AIGetTypeEffectiveness | WATER→FIRE / NORMAL→GRASS / GROUND→FLYING / GRASS→WATER | 20 / 16(faithful bug) / 0 / 20 ✓ |
| LoadWildData | PALLET / ROUTE_1 / ROUTE_19 | all-0 / rate25 mons[3,36,4,36] / water rate5 mons[5,24,…] ✓ |
| LoadWildData (stale-retention) | ROUTE_19 after ROUTE_1 (grass rate 0) | wGrassMons keeps ROUTE_1 data (faithful) ✓ |
| TryDoWildEncounter | grass, rand≥rate | no encounter (Z clear) ✓ |
| TryDoWildEncounter | grass, slot 0 / slot 1 (hRandomSub 0 / 51) | PIDGEY L3 / PIDGEY L4 ✓ |
| TryDoWildEncounter | water, slot 0 | TENTACOOL L5 ✓ |
| TryDoWildEncounter | repel, wild<lead | blocked (Z clear) + steps 3→2 ✓ |
| TryDoWildEncounter | indoor, grass rate 0 | no encounter ✓ |
| StatModifierUpEffect | Atk +1 / +2 (unmod 100) | mod 8 stat 150 / mod 9 stat 200 ✓ |
| StatModifierUpEffect | +1 at mod 13 (cap) | nothing happens, stat untouched ✓ |
| StatModifierUpEffect | +1 with stat already 999 | mod bump reverted, stat 999 ✓ |
| StatModifierDownEffect | Atk −1 (unmod 100) | mod 6 stat 66 ✓ |
| StatModifierDownEffect | −1 to mod 1, unmod 1 (0.25×→0) | mod 1 stat floored to 1 ✓ |
| HandleBuildingRage | raging / not raging / maxed | Atk 7→8 stat 150, move→RAGE / no-op / no-op ✓ |
| GetCurrentMove | player move 1 / enemy move 2 / TestBattle move 3 | records [01,00,28,00,FF,23] / [02…] / [03…] exact ✓ |

Toolchain note (this fresh container): also installed `gcc-multilib` (the `-m32`
libc the earlier session lacked), so harnesses can use either freestanding ELF32
or `gcc -m32`. The wild-encounter harnesses are freestanding ELF32 (link the real
`wild_data.o` for the live tables, stub the overworld externs).

All battle files assemble under the Makefile flags. (`make check` over the *whole*
tree currently stops earlier at a pre-existing, unrelated `init.asm:110`
`g_window_count` error — present at HEAD, not introduced here.) Include additions
introduce no symbol collisions in existing pokemon/items/menu/home/battle files.

## What remains (all UI- or subsystem-coupled — deferred per the user)

- The main battle loop / turn flow (`MainInBattle`, `ExecutePlayerMove`/
  `ExecuteEnemyMove`) — interleaved with text/animation; this is the front end's
  backbone.
- ~~move-effect dispatch `JumpMoveEffect`~~ — **DONE** (Wave 1, `src/engine/battle/
  effects.asm`): 86-entry `dd` `MoveEffectPointerTable`, 14 handlers wired, the rest
  → `UnportedMoveEffect` stub (header lists each + pret handler). Native-validated
  (17/17 dispatch). Check-only until the Wave-2 loop calls it.
- `CheckTargetSubstitute`, HP-bar update, HUD draw (UI).
- ~~`GetCurrentMove` move-record load~~ — **DONE** (backend core,
  `src/engine/battle/get_current_move.asm`): flat `Moves`-table → wPlayerMove* /
  wEnemyMove* copy, picked by hWhoseTurn, incl. the TestBattle override; native-
  validated (player/enemy/test paths exact). Only the `GetMoveName` name tail
  (wNameListIndex → UI) remains deferred. Unblocks the AI move-scoring (`ReadMove`).
- Status residual damage (`HandlePoisonBurnLeechSeed`). (`HandleBuildingRage` is now done.)
- `experience.asm` (mechanical bugs fixed; needs the level-up/EXP subsystem to link).
- AI move-scoring (`AIMoveChoiceModification*`), `read_trainer_party.asm`.
- ~~Wild-encounter generation (`TryDoWildEncounter`)~~ — **DONE** (Stage 9): generator
  + `LoadWildData`/`TryDoWildEncounter` native-validated; only the overworld step
  trigger (the consumer) remains deferred.
</content>
</invoke>
