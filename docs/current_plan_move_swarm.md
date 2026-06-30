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
- [ ] **S5 — Grind.** Workers drain `--category move`; auditors gate; master integrates +
  maintains the pointer table; docs agent logs + commits.

## HANDOFF (resume here)
DONE: S1 (divergence spec) + this plan + **S2 (queue) + S3 (scaffold) + S4 (reference handler
PoisonEffect_)** — build green, `JumpMoveEffect` live, the array-gated dispatch faithful, all
shared externs (§4) link. NEXT: **S5 — Grind** (run the swarm). Start a FRESH session with
`docs/move_swarm_kickoff_prompt.md`. Workers claim `--category move` (18 fresh bodies =
needs_translation) → `dos_port/scratch/`; auditors gate; the **master** integrates each faithful
body by repointing its `MoveEffectPointerTable` entry from `UnportedMoveEffect` to the handler
global (Tier-2, master-only), then building. The 14 audit-first drafts (status `translated`,
still routed to `UnportedMoveEffect`) need an audit pass + the same wiring before they go live.
The `MoveEffectPointerTable` is hand-authored Tier-2 owned by the master; only the master edits it.
Reuse already-live backend: GetCurrentMove, the damage pipeline, DecrementPP, BattleRandom,
StatModifier*Effect, IsInArray, the shared helpers (move_effect_helpers.asm), the generated
effect text (`battle_text.inc`) + effect-category arrays (`battle_data.asm`). `poison.asm` is the
copy-this template.
