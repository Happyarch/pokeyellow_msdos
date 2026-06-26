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

- [ ] **Stage 7 — Status + turn helpers.** Status-condition application/checks,
  speed compare / turn order, `HandleBuildingRage`, `ApplyBurnAndParalysisPenalties`.

- [ ] **Stage 8 — Trainer AI backend.** `trainer_ai.asm` move-scoring logic
  (no UI). `read_trainer_party.asm`.

- [ ] **Stage 9 — Wild-encounter generation.** `wild_encounters.asm`
  (`TryDoWildEncounter` data/RNG path; the overworld trigger is the consumer).

## Verification log
(fill as stages complete)
</content>
</invoke>
