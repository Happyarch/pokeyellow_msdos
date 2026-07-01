# Battle swarm — MASTER A: turn execution & special-move mechanics

You are an **Opus master** driving a Sonnet worker/auditor swarm. You own the
special-move mechanics that the faithful `ExecutePlayerMove`/`ExecuteEnemyMove` flow
currently calls as **stubs**, plus the move-failure/crit/effectiveness text. You turn those
stubs into faithful pret translations.

## Isolation (mandatory — prevents collisions with Masters B & C)

`core.asm` is shared. **Work on your own git branch/worktree** (`battle-swarm-A`). Edit ONLY
the routines listed under "Your work units". Do NOT touch `MainInBattleLoop` (Master B) or the
faint/switch/lifecycle handlers (Master C). Non-overlapping routines auto-merge; the human
merges the three branches. If a change would touch a B/C-owned routine, stop and flag it.

## Read first (in order)

1. `CLAUDE.md` — register map, EBP model, build/link conventions, two-tier rule.
2. `docs/plans/move_translation_divergence.md` — the fidelity boundary + §2 allowlist.
3. `docs/plans/move_swarm.md` — the proven master/worker/auditor topology (this is that, again).
4. pret `engine/battle/core.asm` — your spec. Every routine below cites its pret line.

## Fidelity (non-negotiable)

pret is the spec. Faithful = diverge only at the §2 allowlist (literal subanim → the
ANIMATION=OFF `PlayMoveAnimation` stub; audio; raw `$FF__`; bank/`callfar`/`jpfar`/`predef`
→ flat call). Every WRAM read/write, RNG draw, counter, status bit, branch, and text is
real. Preserve Gen-1 bugs/glitches with `; BUG(level):` + `%if BUG_FIX_LEVEL >= N` (or
`; GLITCH:`). Register map: A=AL, BC=BX, DE=EDX, HL=ESI, EBP=GB base, `[ebp+X]`; `percent` =
`* $FF / 100`. **Every divergence logged** in `docs/translation_log.md` with a one-line why.

## Precheck

`make -C dos_port SKIP_TITLE=1 DEBUG_BATTLE_LIVE=1` builds green (also `BUG_FIX_LEVEL=2`).
The seven leaf stubs live in `core_stubs.asm` (each carries a `TODO`/pret ref). `ExecuteXxxMove`
already exposes the re-entry labels these hook into.

> **Triage baseline (2026-07-01 — now on `master`, `c3325e1e`; branch off current `master`).** A
> single-agent triage pass fixed several `core.asm` regressions this master builds on; do **not**
> re-touch them:
> - `CheckForDisobedience` now honors its ZF=0 "obeys" contract (was a bare `ret` that silently
>   no-opped every non-charging player turn — that's why the live build now actually plays a turn).
> - The Bide-unleash blocks in `CheckPlayerStatusConditions`/`CheckEnemyStatusConditions` no longer
>   carry the unmatched `SwapPlayerAndEnemyLevels` call (was corrupting the level fields).
> - `ExecuteEnemyMove` now increments `wAILayer2Encouragement` (pret `:5656`).
> - **`ApplyAttackTo{Enemy,Player}Pokemon` + `AttackSubstitute` are now fully ported** (special/
>   fixed-damage dispatch, Substitute redirect). Removed from A's scope — do not re-implement.
>   Your remaining leaf stubs (Counter/Metronome/MirrorMove/PrintCriticalOHKO/DisplayEffectiveness/
>   PrintMoveFailure/Ghost/charging/EXPLODE) are unchanged. Note the Run-menu's Ghost short-circuit
>   now `TODO`s your `IsGhostBattle` — wiring it also lights up that path.

## Your work units (each → a worker ticket; new file where practical)

Implement as **new files** under `src/engine/battle/` and repoint the extern in
`core_stubs.asm` (drop the stub) — this minimizes `core.asm` edits and keeps merges clean.

| Unit | pret ref | Notes |
|---|---|---|
| **HandleCounterMove** | grep `engine/battle/core.asm:HandleCounterMove` | Counter reflects 2× last physical damage; returns ZF contract the port stub documents. Gen-1 Counter target/desync quirks — preserve. |
| **MirrorMoveCopyMove** | `engine/battle/` | copy target's last move; ZF=fail. |
| **MetronomePickMove** | `engine/battle/` | random move pick; must set up the picked move so the `CheckIfXxxNeedsToChargeUp` re-entry resolves (current stub only zeroes the effect to avoid a loop). |
| **PrintCriticalOHKOText** | `engine/battle/core.asm` | "Critical hit!" / "One-hit KO!" (reads `wCriticalHitOrOHKO`). |
| **DisplayEffectiveness** | pret `callfar DisplayEffectiveness` | "It's super effective!" / "not very effective!" / nothing (reads `wDamageMultipliers`). |
| **PrintMoveFailureText** | `engine/battle/core.asm:3897` | pick DoesntAffect vs miss text (port currently always prints `AttackMissedText`). |
| **PrintGhostText / IsGhostBattle** | `core.asm:3452 / 3480` | Pokémon Tower ghost path; needs `IsItemInBag(SILPH_SCOPE)` + map check. Stub returns "not ghost". |
| **Charging-move full flow** | `PlayerCanExecuteChargingMove:3282` + ChargeEffect | verify Fly/Dig/SolarBeam/Skull Bash/Razor Wind/Sky Attack: turn-1 charge (INVULNERABLE for Fly/Dig) → turn-2 execute. End-to-end. |
| **EXPLODE self-faint** | `core.asm` ExplodeEffect + the miss-path `.notDone` | confirm Explosion/Self-Destruct faints the user even on a miss, via the AlwaysHappenSideEffects path already wired. |

## Drive the swarm (loop until your category is drained)

- Spawn up to **8 Sonnet workers** (Agent, model: sonnet, fresh general-purpose, one unit
  each). Each gets: the pret label, the output path (new `src/engine/battle/<name>.asm`),
  the register map, and pointers to `docs/plans/move_translation_divergence.md` +
  `dos_port/src/engine/battle/move_effects/poison.asm` (the copy-this template) +
  `move_effect_helpers.asm` (the shared-extern interface). Worker writes ONLY to
  `dos_port/scratch/<id>__<label>.asm`, proves `nasm -f coff` passes, reports the allowlist
  divergences it took (each with a why) + any Gen-1 bug tag. **Never edits existing files.**
- Spawn **2 Sonnet auditors**: read-compare each scratch file vs pret; verdict
  FAITHFUL/DIVERGENT + specifics; no edits.
- **You integrate** faithful bodies only: place the file, repoint the extern in
  `core_stubs.asm` (delete the stub), build green (levels 0 and 2), quick second audit. Fix
  trivial misses yourself; re-queue real divergence to a fresh worker.
- Spawn **2 Opus docs agents**: keep `docs/translation_log.md` current (every integrated unit
  gets an entry whose "Divergences" field lists each allowlist divergence + a one-line why)
  and commit in batches (only on the human's say-so; `Co-Authored-By` trailer; never commit
  generated `assets/*.inc`).

## Hard rules

- Workers/auditors never edit existing files or the extern wiring (that's you).
- One worker per output file. Preserve Gen-1 bugs/glitches. `; TODO-HW:` at any `$FF__`.
- Keep the build green after every integration. Log every divergence.
- Stay in your lane: your branch, your routines. `MainInBattleLoop` = B; faint/lifecycle = C.
