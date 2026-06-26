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

- [ ] **Stage 5 — Stat-stage modifiers.** `ApplyBadgeStatBoosts`, the stat up/down
  effect handlers (`StatModifierUpEffect`/`StatModifierDownEffect`) and the
  `GetStatMod` / unmodified-stat recompute helpers.

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
  `QuarterSpeedDueToParalysis` extern the move-effects reference. REMAINING:
  residual poison/burn/leech-seed damage (`HandlePoisonBurnLeechSeed`, HUD-coupled),
  `HandleBuildingRage`, and the inline turn-order speed compare (in the deferred
  main battle loop).

- [~] **Stage 8 — Trainer AI backend.** `AIGetTypeEffectiveness` done in
  core_damage.asm (single-type effectiveness vs the player mon → wTypeEffectiveness;
  preserves the faithful `$10`-init bug and the Lorelei/Dewgong 40%-ignore case).
  Native-validated (WATER→FIRE=20, NORMAL→GRASS=16 [the bug], GROUND→FLYING=0,
  GRASS→WATER=20). REMAINING: the AI move-scoring layer (`AIMoveChoiceModification*`,
  trainer-class AI pointers) and `read_trainer_party.asm`.

- [ ] **Stage 9 — Wild-encounter generation.** `wild_encounters.asm`
  (`TryDoWildEncounter` data/RNG path; the overworld trigger is the consumer).

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

All battle files assemble under the Makefile flags (`make check`). Include
additions introduce no symbol collisions in existing pokemon/items/menu/home files.

## What remains (all UI- or subsystem-coupled — deferred per the user)

- The main battle loop / turn flow (`MainInBattle`, `ExecutePlayerMove`/
  `ExecuteEnemyMove`, move-effect dispatch `JumpMoveEffect`) — interleaved with
  text/animation; this is the front end's backbone.
- `CheckTargetSubstitute`, HP-bar update, HUD draw (UI).
- `GetCurrentMove` move-record load (backend core + name/UI tail; needs flat-source copy).
- Status residual damage (`HandlePoisonBurnLeechSeed`), `HandleBuildingRage`.
- `experience.asm` (mechanical bugs fixed; needs the level-up/EXP subsystem to link).
- AI move-scoring (`AIMoveChoiceModification*`), `read_trainer_party.asm`.
- Wild-encounter generation (`TryDoWildEncounter`) — needs per-map encounter data tables.
</content>
</invoke>
