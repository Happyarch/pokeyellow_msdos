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

- [ ] **Stage 1 — Foundations (constants + WRAM aliases).** Add battle/move/type/
  move-effect constants to `gb_constants.inc`; add all battle WRAM aliases
  (player/enemy battle-mon struct fields, stat mods, move struct, wDamage,
  wCriticalHitOrOHKO, wMoveMissed, wTypeEffectiveness, battle-status bytes,
  wDamageMultipliers, etc.) to `gb_memmap.inc`, sym-pinned. Unblocks everything.

- [ ] **Stage 2 — Type-effectiveness data.** Generate `assets/type_matchups.inc`
  (`TypeEffects` table from `data/types/type_matchups.asm`) via a Python tool;
  expose in a data module. Pure data → generated, never hand-authored.

- [ ] **Stage 3 — Damage pipeline (core.asm subset).** `GetDamageVarsForPlayerAttack`,
  `GetDamageVarsForEnemyAttack`, `CriticalHitTest`, `CalculateDamage`,
  `AdjustDamageForMoveType` (STAB + type via `TypeEffects`), `RandomizeDamage`.
  Native-harness the formula against known matchups (e.g. L50 Tackle, crit, SE/NVE).

- [ ] **Stage 4 — Move hit test / accuracy.** `MoveHitTest`, accuracy/evasion stat
  stages, `AdjustDamageForMoveType` neutral/immune branches.

- [ ] **Stage 5 — Stat-stage modifiers.** `ApplyBadgeStatBoosts`, the stat up/down
  effect handlers (`StatModifierUpEffect`/`StatModifierDownEffect`) and the
  `GetStatMod` / unmodified-stat recompute helpers.

- [ ] **Stage 6 — Audit + wire existing drafts.** `move_effects/*` (13 files),
  `misc.asm`, `decrement_pp.asm`, `experience.asm`, `get_trainer_name.asm`.
  Audit each against pret; resolve externs; add to Makefile `BATTLE_SRCS`.

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
