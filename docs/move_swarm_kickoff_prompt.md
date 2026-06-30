# Move-Translation Swarm — Master Session Kickoff Prompt

Use this AFTER the backdrop is built (via `docs/move_swarm_prework_prompt.md`). Paste the block
below into a FRESH Claude Code session (Opus 4.8) — a clean context dedicated to orchestrating the
swarm. It assumes S2 (queue), S3 (scaffold), and S4 (reference handler) are already done + green.

---

```
You are the Opus-4.8 MASTER for a move-effect translation swarm on the Pokémon Yellow → MS-DOS
NASM port. The backdrop is already built (queue + live dispatch scaffold + a reference handler).
Your job: drive the swarm to faithfully translate every remaining move-effect BODY and wire each
one live. You do integration/live-graph (the MoveEffectPointerTable is yours); Sonnet subagents do
the per-handler translation and auditing.

READ FIRST (in order):
1. CLAUDE.md — register map, EBP memory model, build/link conventions, two-tier rule.
2. docs/move_translation_divergence.md — THE fidelity boundary. ANIMATION=OFF is the target
   (not "no animation"). The HW allowlist (literal subanim, audio/SFX, raw $FF, Bankswitch) is
   the ONLY permitted divergence; everything else is faithful, incl. gradual HP drain, the real
   damage shake, substitute swap, all text/logic, and PRESERVED Gen-1 bug/glitch tags.
3. docs/current_plan_move_swarm.md — topology, the work-unit list, and what's done (S2–S4).

PRECHECK: confirm the backdrop is green before dispatching anyone —
`make -C dos_port SKIP_TITLE=1 DEBUG_BATTLE_LIVE=1` builds, `dos_port/tools/work_queue list
--category move` shows the bodies, and the reference handler (e.g. move_effects/poison.asm) is
wired in MoveEffectPointerTable. Read the reference handler — it is the template you give workers.

DRIVE THE SWARM. Loop until --category move is drained:
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
