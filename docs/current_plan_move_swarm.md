# Plan: Move-Effect Translation Swarm

The faithful battle loop (`core.asm`) is live; `JumpMoveEffect` is stubbed. This plan
grinds every move-effect **body** to a faithful translation via a parallel agent swarm.
Fidelity boundary + worker/auditor rules: **`docs/move_translation_divergence.md`** (read it).

## Swarm topology (decided 2026-06-30)
- **5× Sonnet-5 workers** — one effect-handler body per ticket → `dos_port/scratch/`. Never
  edit existing files; never wire the dispatch table. Tag bugs/glitches per convention.
- **2 Sonnet auditors per 5 workers** — BEFORE integration, read-compare the scratch file
  vs the pret label: faithful = no divergence outside the allowlist + Gen-1 bug tags
  preserved. Verdict only, no edits.
- **Opus-4.8 master** — integrates a faithful body into `effects.asm`'s
  `MoveEffectPointerTable` (live-graph = master only), builds, runs a quick second audit,
  then hands to docs. Fixes trivial misses itself; re-queues real divergence as
  `needs_translation` to a fresh worker.
- **Opus-4.8 docs/commit agent** — translation_log + plan stages + commits.

Scale to 5 workers once the swarm proves healthy; may raise later.

## Work units (the effect **bodies**, `XxxEffect_` / inline `XxxEffect`)
pret `data/moves/effects_pointers.asm` → 34 effects; **7 are `NULL`** (no body, no ticket:
MIRROR_MOVE, SWIFT, SUPER_FANG, SPECIAL_DAMAGE, JUMP_KICK, METRONOME, + 1 unused — these are
handled inline in `core.asm`'s main flow, Claude/master territory).

- **Audit-first (drafts already exist, status `translated`)** — 14 in
  `dos_port/src/engine/battle/move_effects/`: conversion, drain_hp, focus_energy, haze,
  heal, leech_seed, mist, one_hit_ko, paralyze, pay_day, recoil, reflect_light_screen,
  substitute, transform; **+** `StatModifierUpEffect`/`DownEffect` in `stat_mod_effects.asm`.
- **Translate fresh (inline in pret `effects.asm`, status `needs_translation`)** — new files
  under `move_effects/`: SleepEffect, PoisonEffect, FreezeBurnParalyzeEffect, ExplodeEffect,
  FlinchSideEffect, ChargeEffect, BideEffect, RageEffect, ThrashPetalDanceEffect,
  TrappingEffect, ConfusionEffect, ConfusionSideEffect, DisableEffect, MimicEffect,
  SplashEffect, SwitchAndTeleportEffect, HyperBeamEffect, TwoToFiveAttacksEffect.
  (Output path: `dos_port/src/engine/battle/move_effects/<snake_name>.asm`, body label
  `XxxEffect_`.)

## Stages
- [ ] **S1 — Divergence spec.** DONE (`docs/move_translation_divergence.md`).
- [ ] **S2 — Queue.** Add `move` category to `build_index` (schema CHECK + a `move` scan of
  `move_effects/*.asm` + the hand-listed inline `effects.asm` body labels above); mark the 16
  drafts `translated` (audit-first), the rest `needs_translation`; `build_index --rebuild`.
  Swarm claims `--category move`.
- [ ] **S3 — Scaffold (master's first integration task; Claude/Opus only).** Build so handlers
  link + fire faithfully:
  - `IsInArray` as a shared home global (currently only local in trainer_ai/bills_pc).
  - Translate pret `core.asm:3294-3436` **array-gated dispatch** into our `core.asm`
    `ExecutePlayerMove`/`ExecuteEnemyMove` (replaces the simplified "JumpMoveEffect once after
    damage"): the 6 `IsInArray` checkpoints against ResidualEffects1 / SpecialEffectsCont /
    SetDamageEffects / ResidualEffects2 / AlwaysHappenSideEffects / SpecialEffects (arrays
    already generated + linked in `battle_data.asm`).
  - Wire `JumpMoveEffect` live via `effects.asm` `MoveEffectPointerTable` (drop the
    `core_stubs.asm` stub); unported entries → an `UnportedMoveEffect` no-op so it links.
  - Real shared helpers (text/logic): `PrintStatText`, `ConditionalPrintButItFailed` /
    `PrintButItFailedText_`, `EffectCallBattleCore`.
  - **Faithful-animation (ANIMATION=OFF; flagged follow-ups, can land incrementally):**
    gradual HP-bar drain (`UpdateCurMonHPBar`), the real software-PPU damage shake
    (`PlayApplyingAttackAnimation` — needs a renderer blit-offset/flash hook),
    substitute pic swap (`HideSubstituteShowMonAnim`/`ReshowSubstituteAnim`).
  - Audio/SFX + literal subanim stay as the allowlist stubs.
- [ ] **S4 — Reference handler.** Translate ONE body end-to-end as the gold-standard template
  (suggest `PoisonEffect` or `SleepEffect` — small, status-only, exercises text + WRAM +
  a Gen-1 bug tag), build green; link it from the worker ticket as the example.
- [ ] **S5 — Grind.** Workers drain `--category move`; auditors gate; master integrates +
  maintains the pointer table; docs agent logs + commits.

## HANDOFF (resume here)
DONE this session: the divergence spec (S1) + this plan. NEXT: S2 (queue) then S3 (scaffold)
— both are Claude/master work and must precede dispatching workers. The `MoveEffectPointerTable`
is hand-authored Tier-2 owned by the master; only the master edits it. Reuse already-live
backend: GetCurrentMove, the damage pipeline, DecrementPP, BattleRandom, StatModifier*Effect,
the generated effect text (`battle_text.inc`) + effect-category arrays (`battle_data.asm`).
