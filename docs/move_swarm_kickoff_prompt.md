# Move-Translation Swarm — Master Session Kickoff Prompt

Paste the block below into a fresh Claude Code session (Opus 4.8) to bootstrap the
move-effect translation swarm. It assumes the repo is checked out and CLAUDE.md is read at
session start.

---

```
You are the Opus-4.8 MASTER for a move-effect translation swarm on the Pokémon Yellow → MS-DOS
NASM port. Your job: orchestrate the faithful translation of every Gen-1 move-effect BODY into
the battle engine, then wire them live. You do the architecture/integration/live-graph work;
Sonnet subagents do the bulk per-handler translation and auditing.

READ FIRST (in order):
1. CLAUDE.md — register map, EBP memory model, build/link conventions, two-tier rule.
2. docs/move_translation_divergence.md — THE fidelity boundary. ANIMATION=OFF is the target
   (not "no animation"). The HW allowlist (literal subanim, audio/SFX, raw $FF, Bankswitch) is
   the ONLY permitted divergence; everything else is faithful, incl. gradual HP drain, the real
   damage shake, substitute swap, all text/logic, and PRESERVED Gen-1 bug/glitch tags.
3. docs/current_plan_move_swarm.md — topology, the exact work-unit list, and the S2–S5 recipe.

EXECUTE IN ORDER (S2–S4 are yours; do NOT dispatch workers until S3 links green):

S2 — QUEUE. Add a `move` category to dos_port/tools/build_index (schema CHECK +(category) and
a per-label categoriser): tag the move_effects/*.asm bodies + the hand-listed inline effect
labels (in pret engine/battle/effects.asm — see the plan's work-unit list) as `move`. Seed the
16 existing drafts as status `translated` (audit-first: the 14 move_effects/ files +
StatModifierUp/DownEffect), the 18 inline ones as `needs_translation`. Run
`dos_port/tools/build_index --rebuild`. Verify with `dos_port/tools/work_queue list --category move`.

S3 — SCAFFOLD (live-graph; you only). Build so handlers link + fire faithfully:
  - `IsInArray` as a shared home global (it's currently only local in trainer_ai/bills_pc).
  - Translate pret core.asm:3294-3436 — the array-gated effect dispatch — into our
    src/engine/battle/core.asm ExecutePlayerMove/ExecuteEnemyMove, replacing the simplified
    "JumpMoveEffect once after damage". The 6 IsInArray checkpoints test ResidualEffects1 /
    SpecialEffectsCont / SetDamageEffects / ResidualEffects2 / AlwaysHappenSideEffects /
    SpecialEffects (all already generated + linked in src/data/battle_data.asm).
  - Wire JumpMoveEffect live via effects.asm MoveEffectPointerTable (drop the core_stubs.asm
    JumpMoveEffect stub); unported entries route to an UnportedMoveEffect no-op so it links.
  - Real shared text/logic helpers: PrintStatText, ConditionalPrintButItFailed /
    PrintButItFailedText_, EffectCallBattleCore.
  - Faithful-animation (ANIMATION=OFF; can land incrementally as you integrate handlers that
    need them): gradual HP-bar drain (UpdateCurMonHPBar), the real software-PPU damage shake
    (PlayApplyingAttackAnimation — add a renderer blit-offset/flash hook), substitute pic swap
    (HideSubstituteShowMonAnim / ReshowSubstituteAnim). Audio + literal subanim stay allowlist stubs.
  - Build green: make -C dos_port SKIP_TITLE=1 DEBUG_BATTLE_LIVE=1.

S4 — REFERENCE HANDLER. Translate ONE body end-to-end yourself as the gold standard (suggest
PoisonEffect or SleepEffect: small, status-only, exercises text + WRAM + a Gen-1 bug tag).
Build green. This is the template you cite in worker tickets.

S5 — GRIND (the swarm). Loop until --category move is drained:
  - Spawn up to 5 Sonnet-5 workers (Agent tool, model: sonnet, fresh general-purpose). Each gets
    ONE effect body (a `needs_translation` ticket): the pret label + output path
    dos_port/src/engine/battle/move_effects/<snake>.asm, the register-map rows, and a pointer to
    docs/move_translation_divergence.md + the reference handler. Worker writes ONLY to
    dos_port/scratch/<id>__<label>.asm, calls the shared externs, translates the rest, tags bugs,
    proves `nasm -f coff` passes, reports back. Never edits existing files; never touches the table.
  - Spawn 2 Sonnet-5 auditors per 5 workers: each reads a scratch file vs the pret label and
    returns FAITHFUL/DIVERGENT + specifics (no edits). Faithful = no divergence outside the
    allowlist + Gen-1 bug tags preserved. The 16 audit-first drafts go straight to auditors.
  - YOU integrate only faithful bodies: place into src/, add the MoveEffectPointerTable entry
    (you own that table), build green, do a quick second audit. Fix trivial misses yourself;
    re-queue real divergence as needs_translation to a fresh worker. Update the work_queue
    (translated → wired). Never mark translated outside the tool.
  - Spawn an Opus-4.8 docs/commit agent to keep docs/translation_log.md + the plan stages current
    and commit in batches (commit only on the user's say-so; branch off master if needed;
    Co-Authored-By trailer; never commit generated assets/*.inc).

HARD RULES: workers/auditors never edit existing files or the dispatch table (live-graph = you).
One worker per output file. Preserve Gen-1 bugs (BUG(level): + BUG_FIX_LEVEL blocks) and glitches
(GLITCH:). Emit ; TODO-HW: at any $FF__ boundary. Keep the build green after every integration.
```
