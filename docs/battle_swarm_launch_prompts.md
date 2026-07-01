# Battle swarm — launch prompts (Masters A / B / C)

Copy-paste kickoff prompts for the three concurrent Opus master sessions, plus the one-time
worktree setup. Each master drives its own **Sonnet** worker/auditor/docs sub-swarm.
Tickets are the hand-authored `docs/battle_swarm_master_{A,B,C}.md` docs — the prompts just
point each session at its ticket and encode the guardrails.

---

## One-time setup: three concurrent worktrees from ONE clone

You do **not** need to reclone. `git worktree` gives each branch its own directory sharing this
clone's `.git`. Run from the primary clone (repo root):

```sh
PRIMARY="$PWD"
for M in A B C; do
  WT="../pkmn-swarm-$M"
  git worktree add "$WT" "battle-swarm-$M"
  # Seed gitignored build inputs (NOT in git): generated assets/*.inc + the graphics
  # binaries the build incbin's (.2bpp tiles, .pic compressed sprites, .1bpp).
  ( cd "$PRIMARY" && tar cf - dos_port/assets \
      $(find . \( -name '*.2bpp' -o -name '*.pic' -o -name '*.1bpp' \)) ) | ( cd "$WT" && tar xf - )
  # Keep the .inc newer than the .2bpp so `make` doesn't try to regenerate them.
  touch "$WT"/dos_port/assets/*.inc
done
git worktree list
```

Then open a **separate Claude Code (Opus) session in each** `../pkmn-swarm-A|B|C` directory and paste
that master's prompt below. They run fully in parallel; merge order at the end is A → B → C.

**Teardown when a branch is merged:** `git worktree remove ../pkmn-swarm-A` (from the primary clone).

**Note on assets:** masters edit `.asm` and rebuild the EXE (`make -C dos_port`), which only consumes
the `.inc`. Don't run `make assets` in a worktree (it needs rgbds + regenerates Tier-1 data); if a
generator genuinely must change, do it in the primary clone and re-seed.

---

## Shared guardrails (baked into every prompt)

- **Workers = Sonnet, logic-only.** Master (you) = Opus: you review, integrate, resolve `core.asm`
  overlap, and are the ONLY one who touches git.
- **Workers write ONLY to `dos_port/scratch/`**, extern the shared routines, and prove
  `nasm -f coff -o /dev/null <file>` passes. **They never edit existing files, and never run any git
  command** (checkout/stash/restore/reset/apply) — that clobbered a shared tree before.
- **Fidelity:** pret is the spec; diverge only at the `docs/plans/move_translation_divergence.md` §2
  allowlist. Preserve Gen-1 bugs/glitches with `; BUG(level):`+`%if BUG_FIX_LEVEL >= N` or `; GLITCH:`.
- **Build green after every integration:** `make -C dos_port SKIP_TITLE=1 DEBUG_BATTLE_LIVE=1` and
  `BUG_FIX_LEVEL=2`.
- **Commit only on the human's say-so**, with the `Co-Authored-By: Claude Opus 4.8` trailer.
- **Stay in your lane** (ownership is by routine, not file). Log every integrated unit in
  `docs/translation_log.md` with its Divergences field.
- The audit (`docs/battle_audit_findings.md`) is re-scoped and dated: items tagged **[RESOLVED]**
  (A-1, A-3) and **[LIKELY RESOLVED — verify @HEAD]** (A-2, A-7) are **already fixed on master — do
  not re-implement them.**

---

## Prompt — MASTER A (turn execution & special-move mechanics)

```
You are the Opus master for the battle-engine swarm, subsystem A (turn execution & special-move
mechanics), working in this git worktree on branch battle-swarm-A.

Read, in order: docs/battle_swarm_master_A.md (your ticket — work-unit table + isolation + drive
rules), docs/battle_swarm_README.md, docs/battle_audit_findings.md (your Tier-1 items A-1/A-2/A-3/A-7
are RESOLVED or LIKELY-RESOLVED on master — do NOT redo them; verify A-2/A-7 @HEAD then move on),
CLAUDE.md, and docs/plans/move_translation_divergence.md.

Your real remaining scope is the leaf stubs in core_stubs.asm and their re-entry hooks: Counter,
MirrorMove, Metronome, PrintCriticalOHKOText, DisplayEffectiveness, PrintMoveFailureText,
Ghost/IsGhostBattle, the charging-move full flow, and EXPLODE self-faint. Implement each as a NEW
file under src/engine/battle/ and repoint the extern in core_stubs.asm (minimize core.asm edits).

Drive a Sonnet sub-swarm: up to ~8 workers on the independent new-file leaves, plus Sonnet auditors
vs pret and Opus docs agents. Enforce the shared guardrails: workers are Sonnet, write only to
dos_port/scratch/, never edit existing files, never run git; you alone integrate and touch git.
Build green (levels 0 and 2) after each integration. Commit only when I say so. Stay in your lane —
do not touch ExecuteXxxMove flow bodies beyond the documented re-entry labels, MainInBattleLoop
pacing (B), or faint/lifecycle (C). Start by confirming the branch and a green baseline build, then
propose your worker fan-out before spawning.
```

## Prompt — MASTER B (battle text & HUD pacing)

```
You are the Opus master for the battle-engine swarm, subsystem B (battle message flow & HP-bar
pacing — the "messages run over each other / menu races the last line" fix), working in this git
worktree on branch battle-swarm-B.

Read, in order: docs/battle_swarm_master_B.md (your ticket), docs/battle_swarm_README.md,
docs/battle_audit_findings.md, CLAUDE.md, and docs/plans/move_translation_divergence.md (ANIMATION=OFF
is faithful: HP bars DRAIN tick-by-tick, screen shakes, mon flashes — the gradual drain is REQUIRED,
not an animation to skip).

Your keystone unit is the gradual HP-bar drain (replace UpdateCurMonHPBar's instant
jmp DrawHUDsAndHPBars with pret's tick-by-tick pixel drain + per-tick DelayFrames, reading
wHPBar{Old,New,Max}HP — inputs are already populated). Then: the PROMPT/button-wait discipline so
result/status/faint lines wait like pret, MainInBattleLoop menu-redraw gating (menu must not paint
over the last message), DrawEnemyHUDAndHPBar, and faithful text-box clear/scroll between messages.
This is serial-integration-heavy: ~2-3 Sonnet workers max (HP-drain loop / PROMPT audit+wiring /
DrawEnemyHUDAndHPBar); do the menu-gating + text-box-clear yourself.

Enforce the shared guardrails (Sonnet workers, scratch-only, never edit existing files, never run
git; you alone integrate/commit; green at levels 0/2; commit on my say-so; stay in lane — do not
touch turn-flow (A) or faint/lifecycle (C)). This is UX-timing work: build-green is necessary but
NOT sufficient — live-verify each change with dos_port/run SKIP_TITLE=1 DEBUG_BATTLE_LIVE=1 or the
DOSBox-X MCP, watching a two-sided round, and capture a before/after. Start by confirming the branch
and a green baseline, then propose your fan-out before spawning.
```

## Prompt — MASTER C (lifecycle, multi-mon & in-battle sub-UIs)

```
You are the Opus master for the battle-engine swarm, subsystem C (faint/switch lifecycle, multi-mon
trainer battles, in-battle bag/party sub-menus, trainer AI, Yellow obedience), working in this git
worktree on branch battle-swarm-C.

Read, in order: docs/battle_swarm_master_C.md (your ticket — work-unit table + isolation), 
docs/battle_swarm_README.md, docs/battle_audit_findings.md, CLAUDE.md (Gen-2 forward-compat: the
party/box struct is byte-identical to Gen 1, offset 7 = catch-rate/held-item is load-bearing — NEVER
realign when doing party<->battle-mon sync), docs/plans/move_translation_divergence.md, and the
party/bag layers you couple to (docs/current_plan_pokemon_ui.md, docs/current_plan_items.md).

Your units: faint -> switch-in (player: remove fainted mon, AnyPartyAlive -> blackout vs forced
switch), faint -> next mon (enemy/trainer send-out), battle-mon<->party-mon sync (carry offset 7
verbatim), multi-mon trainer battles + prize money, BattleItemMenu/BattlePartyMenu sub-UIs (couple to
items/party), TrainerAI deepening, real CheckForDisobedience math (its ZF contract is already fixed —
add behavior, don't re-fix the stub), MoveSelectionMenu wMoveMenuType=1 (Mimic), HandleEnemyMonFainted
EXP-ALL dispatch (preserve the Gen-1 half-zeroed wPlayerBideAccumulatedDamage bug), SelectEnemyMove ->
AI move-select wiring, and linking trainer_ai/wild_encounters/read_trainer_party into the live EXE.

Drive up to ~4 Sonnet workers on the separable units (faint/switch, send-out, disobedience, one
sub-UI); the sub-UIs + party-sync are integration-heavy — expect to wire those yourself. Enforce the
shared guardrails (Sonnet workers, scratch-only, never edit existing files, never run git; you alone
integrate/commit; green at levels 0/2; commit on my say-so; stay in lane — do not touch turn-flow (A)
or message/menu pacing (B)). Auditors must double-check the party-struct byte layout and the obedience
math vs pret. Start by confirming the branch and a green baseline, then propose your fan-out before
spawning.
```
