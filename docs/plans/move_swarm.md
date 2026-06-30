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
- [x] **S2 — Queue.** Added `move` category to `build_index` + `work_queue` (schema/CHECK +
  per-label categoriser: all `move_effects/*.asm` labels + the 18 inline `effects.asm` bodies +
  StatModifierUp/DownEffect). Seeded the 16 drafts `translated` (audit-first, by source→dos_port
  output path), the 18 inline fresh bodies `needs_translation`. `build_index --rebuild` run:
  `list --category move` = 59 (41 translated + **18 claimable needs_translation = exactly the
  fresh bodies**). Swarm claims `--category move`.
- [x] **S3 — Scaffold (master's first integration task; Claude/Opus only).** Built green:
  - `IsInArray` is now the shared home global (`src/home/array.asm`); the local copies in
    trainer_ai/bills_pc were removed and both extern the global (trainer_ai now sets EDX=1).
  - Faithful **array-gated dispatch** (pret `core.asm:3294-3436`) translated into our
    `core.asm` `ExecutePlayerMove`/`ExecuteEnemyMove` — the 6 `IsInArray` checkpoints
    (ResidualEffects1 `jp` → SpecialEffectsCont `call` → SetDamageEffects skip-calc →
    ResidualEffects2 `jp` → AlwaysHappenSideEffects `call` → SpecialEffects catch-all
    `call nc`) replacing the simplified "JumpMoveEffect once after damage".
  - `JumpMoveEffect` is **LIVE** (effects.asm `MoveEffectPointerTable`; core_stubs.asm stub
    dropped). Wired live: StatModifierUp/DownEffect + PoisonEffect_; **every other entry →
    `UnportedMoveEffect`** no-op (the 14 drafts await audit/integration in S5).
  - Real shared helpers in `src/engine/battle/move_effect_helpers.asm`: `PrintText` (battle —
    the overworld `PrintText` was renamed `PrintText_Overworld`), `PrintStatText`,
    `ConditionalPrintButItFailed`/`PrintButItFailedText_`, `PrintDidntAffectText`,
    `PrintMayNotAttackText`, `EffectCallBattleCore`, `CheckTargetSubstitute` (faithful;
    replaced the battle_stubs no-op), `Bankswitch` (flat passthrough). `stat_mod_effects.asm`,
    `badge_boosts.asm`, `status_penalties.asm` now LINK (moved BATTLE_SRCS→FRONTEND_SRCS;
    the duplicate battle_exp_stubs badge/penalty stubs were deleted).
  - **Faithful-animation:** `UpdateCurMonHPBar` → DrawHUDsAndHPBars stand-in (gradual drain =
    incremental TODO); `PlayApplyingAttackAnimation` reused from animations.asm (software-PPU
    shake = incremental TODO); `HideSubstituteShowMonAnim`/`ReshowSubstituteAnim` linking
    no-ops (no Substitute yet). Audio/SFX + literal subanim are the allowlist stubs.
- [x] **S4 — Reference handler.** `PoisonEffect_` translated end-to-end as the gold standard
  (`src/engine/battle/move_effects/poison.asm`), wired into `MoveEffectPointerTable` ($02/$21/
  $42). Exercises the substitute/already-statused/type-immunity guards, the side-effect vs.
  main-effect accuracy split, the status-byte write, Toxic's BADLY_POISONED branch, faithful
  text, and a Gen-1 bug tag (1/256 miss via MoveHitTest). Build green; the enemy-move dispatch
  path verified in DOSBox-X (DEBUG_BATTLE_ENEMYHIT ran end-to-end, no hang/crash).
- [x] **S5 — Grind.** Workers drain `--category move`; auditors gate; master integrates +
  maintains the pointer table; docs agent logs + commits. **COMPLETE** (2026-06-30).
  - **ALL 34 non-NULL handlers are live in `MoveEffectPointerTable`** (build green:
    `make -C dos_port SKIP_TITLE=1 DEBUG_BATTLE_LIVE=1`), each logged in
    translation_log.md with a Divergences field. **59/59 move-queue tickets verified.**
  - **First-half integration (17 handlers):** PoisonEffect_ ($02/$21/$42, S4 ref),
    SplashEffect_ ($55), FlinchSideEffect_ ($1F/$25), ConfusionEffect_ ($31) +
    ConfusionSideEffect_ ($4C), SleepEffect_ ($01/$20), FreezeBurnParalyzeEffect_
    ($04/$05/$06/$22/$23/$24), ConversionEffect_ ($18), HazeEffect_ ($19),
    OneHitKOEffect_ ($26), MistEffect_ ($2E), FocusEnergyEffect_ ($2F), ParalyzeEffect_
    ($43), LeechSeedEffect_ ($54), ExplodeEffect_ ($07), BideEffect_ ($1A),
    TwoToFiveAttacksEffect_ ($1D/$1E/$2C/$4D), RageEffect_ ($51) — plus the shared
    StatModifierUp/DownEffect bodies, live since S3.
  - **Second-half integration (14 handlers, this session):** ChargeEffect_ ($27/$2B),
    MimicEffect_ ($52), SwitchAndTeleportEffect_ ($1C), DisableEffect_ ($56),
    TrappingEffect_ ($2A), HyperBeamEffect_ ($50), ThrashPetalDanceEffect_ ($1B),
    DrainHPEffect_ ($03/$08), ReflectLightScreenEffect_ ($40/$41), RecoilEffect_ ($30),
    PayDayEffect_ ($10), SubstituteEffect_ ($4F), HealEffect_ ($38), TransformEffect_
    ($39). Seven of these were re-translated after failed audits (drain_hp, heal,
    pay_day, reflect_light_screen, substitute, transform, recoil).
  - **The 7 NULL-in-pret entries correctly stay `UnportedMoveEffect`** (no body in
    pret; handled inline in core.asm's main flow): $09 MIRROR_MOVE, $11 SWIFT,
    $28 SUPER_FANG, $29 SPECIAL_DAMAGE, $2D JUMP_KICK, $4E (unused), $53 METRONOME.
  - **Shared support added during integration:** `move_effect_helpers.asm` gained
    `ClearHyperBeam` (global; Flinch/FBP/Trapping), `PrintDoesntAffectText`, and the
    `AnimationSubstitute` / `AnimationTransformMon` / `PlayBattleAnimation` no-op stubs;
    `gb_memmap.inc` gained `wPlayerConfusedCounter` / `wEnemyConfusedCounter`,
    `wUnknownSerialFlag_d499`, `wTotalPayDayMoney` / `wPayDayMoney`,
    `wTransformedEnemyMonOriginalDVs`; `gb_constants.inc` gained `XSTATITEM_ANIM`,
    `SHRINKING_SQUARE_ANIM`, `SLIDE_DOWN_ANIM`, `RAZOR_WIND` / `ROAR` / `SOLARBEAM` /
    `SKULL_BASH` / `SKY_ATTACK`. `tools/gen_battle_text.py` was fixed to emit
    `StartedSleepingEffect` (its label regex only matched `*Text` names); regen also
    restored a stale-missing `PickUpPayDayMoneyText`.
  - **Deferred / follow-up items (carried out of the swarm):**
    (a) The allowlist HW stubs are still no-ops — the literal subanimation engine,
    the audio HAL, the real Substitute pic-swap, and gradual HP-bar drain. This is
    faithful ANIMATION=OFF behavior; fill in later (PPU/audio passes).
    (b) **Makefile dependency gap:** the battle move-effect `.o` files don't list
    `assets/battle_text.inc` as a prerequisite, so regenerating `battle_text.inc`
    does NOT auto-rebuild them (the master `rm`'d stale `.o`s by hand this session).
    Worth adding that dependency to the Makefile.

## HANDOFF (resume here)
**ALL STAGES COMPLETE (S1–S5, 2026-06-30).** All 34 non-NULL move-effect handlers are
translated, audited FAITHFUL, and live in `MoveEffectPointerTable` (effects.asm); the 7
NULL-in-pret entries correctly stay `UnportedMoveEffect` (handled inline in core.asm). Build
green (`make -C dos_port SKIP_TITLE=1 DEBUG_BATTLE_LIVE=1`); 59/59 move-queue tickets verified.

**This plan is fully done and can be archived** per the CLAUDE.md convention —
`git mv docs/current_plan_move_swarm.md docs/plans/move_swarm.md` (recommendation only; NOT
performed by the docs agent).

Remaining follow-ups are NOT part of this plan (tracked above under S5 deferred items):
- The allowlist HW stubs (literal subanimation, audio HAL, real Substitute pic-swap, gradual
  HP-bar drain) are still faithful ANIMATION=OFF no-ops — to be filled in during the PPU/audio
  passes.
- Makefile dependency gap: battle move-effect `.o` files don't depend on `assets/battle_text.inc`,
  so regenerating it doesn't auto-rebuild them (worked around by hand-`rm`ing stale `.o`s this
  session) — worth adding the prerequisite.
