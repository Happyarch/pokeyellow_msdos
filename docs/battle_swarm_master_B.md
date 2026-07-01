# Battle swarm — MASTER B: battle text & HUD pacing

You are an **Opus master** driving a small Sonnet swarm. You own **battle message flow and
HP-bar pacing** — the fix for the "messages run over each other / menu returns before a
message is up" bug. This subsystem is **serial-integration-heavy**: expect ~2–3 effective
workers, not 8. Width doesn't help here; correctness of the interleaving does.

## The bug you're fixing (root cause)

Battle messages cascade with no pause because the natural inter-message delays were stubbed:
1. **`UpdateCurMonHPBar` redraws instantly** (`move_effect_helpers.asm` → `jmp
   DrawHUDsAndHPBars`). pret drains the HP bar one pixel at a time with a per-tick delay — the
   *biggest* pause holding a result message up. Implement the gradual drain.
2. **Messages don't wait for the player.** They auto-advance on `PlayMoveAnimation`'s flat
   30-frame delay only; result/status/"attack continues!" lines have no `<PROMPT>`/▼ wait.
3. **The menu redraws with no post-round acknowledgment.** `MainInBattleLoop` →
   `DisplayBattleMenu` fires at the top of the loop and can paint over the last message.

> **Triage baseline (2026-07-01 — now on `master`, `c3325e1e`; branch off current `master`).**
> - `battle_hud.asm` numeric bugs are fixed: level ≥100 now uses a 3-digit path, and the Gen-1
>   maxHP≥256 lossy HP-bar quirk is restored (exact division gated behind `BUG_FIX_LEVEL >= 2`).
>   You still own the **gradual HP-drain pacing** (unchanged).
> - `ApplyAttackTo{Enemy,Player}Pokemon` now faithfully populate `wHPBarOldHP/NewHP/MaxHP`, so your
>   gradual-drain loop has correct inputs (the instant subtract is still the placeholder to replace).
> - **Stat-change messages** (`MonsStatsRose`/`MonsStatsFell`, `core.asm`) are now composed in code
>   with the verb + `<PROMPT>` wait — the generator no longer silently truncates them
>   (`gen_battle_text.py` skips `text_far`+`text_asm` labels). **Verify** the "greatly" line's
>   `<SCROLL>` pacing live and fold it into your PROMPT/wait discipline — don't re-implement the text.

## Isolation (mandatory)

`core.asm` is shared. **Work on branch/worktree `battle-swarm-B`.** You own: `battle_hud.asm`,
the battle text helpers in `move_effect_helpers.asm` (`UpdateCurMonHPBar`) and the text engine
it calls (`text.asm` / `PrintBattleText` / `RunBattleTextStream` / `BattlePromptWait` in
`core.asm`), and **`MainInBattleLoop` in `core.asm`** (the menu-redraw gating only). Do NOT
touch `ExecutePlayerMove`/`ExecuteEnemyMove`/`CheckXxxStatusConditions` (Master A's flow) or the
faint/switch handlers (Master C). If pacing needs a change inside those, flag it for that master.

## Read first

1. `CLAUDE.md` (register map, EBP model, PPU/text conventions, timing/DelayFrames).
2. `docs/plans/move_translation_divergence.md` — the ANIMATION=OFF target is faithful: HP
   bars **drain tick-by-tick**, the screen shakes, the mon flashes; only the literal
   subanimation is skipped. So the gradual drain is *required* faithful behavior, not an anim.
3. pret `engine/battle/core.asm` — `UpdateHPBar` / `UpdateCurMonHPBar` (the drain loop),
   `MainInBattleLoop:289`, `PrintText` / `PromptText` (the `<PROMPT>`/▼ wait), and how the
   text box is drawn/cleared between messages. `home/vblank.asm`/`home/delay.asm` for `DelayFrames`.

## Your work units

| Unit | pret ref | Notes |
|---|---|---|
| **Gradual HP-bar drain** | pret `UpdateHPBar` / `UpdateCurMonHPBar` | replace the instant `jmp DrawHUDsAndHPBars` with the tick-by-tick pixel drain + per-tick `DelayFrames`, reading `wHPBar{Old,New,Max}HP`. This is the keystone pause. Both sides. |
| **Message PROMPT / wait discipline** | pret `PrintText` vs `PrintText_NoButton`, `PromptText` | audit which battle messages pret shows with a `<PROMPT>`/button-wait vs auto-advance, and make `PrintBattleText`/the text streams reproduce it. The result/status/faint lines that pret waits on must wait. |
| **Menu-redraw gating** | pret `MainInBattleLoop:289` | ensure `DisplayBattleMenu` does not paint until the round's final message has been acknowledged/cleared (pret's flow clears the box first). Only the menu-timing hunk of `MainInBattleLoop`. |
| **DrawEnemyHUDAndHPBar** | pret | port it (enemy anim redraws currently borrow the both-bars `DrawHUDsAndHPBars` stand-in). |
| **Text-box clear/scroll between messages** | pret text engine | confirm consecutive messages clear/scroll faithfully rather than overprint. |

## Verification is essential here

This is UX-timing work — build-green is necessary but not sufficient. Use the DOSBox-X MCP
(`dbg_command`, `gb_read`, `dump_frame`) and/or `dos_port/run SKIP_TITLE=1 DEBUG_BATTLE_LIVE=1`
to actually watch a two-sided round and confirm each message is readable before the next and
the menu no longer races the last line. Capture a before/after.

## Drive the swarm

- Spawn **2–3 Sonnet workers** on the genuinely-separable units (e.g. one on the HP-drain loop,
  one on the PROMPT/wait audit+wiring, one on `DrawEnemyHUDAndHPBar`). The menu-gating +
  text-box-clear are tightly coupled — do those yourself or with one worker, serially.
- Workers write ONLY to `dos_port/scratch/`; they extern the shared helpers; they prove
  `nasm -f coff` passes. **Never edit existing files.**
- **2 Sonnet auditors** verify each against pret's HP-drain loop / PromptText semantics.
- **You integrate**, build green (levels 0/2), and **live-verify the pacing** before moving on.
- **2 Opus docs agents**: `translation_log.md` entries (Divergences field) + batched commits
  (human's say-so only).

## Hard rules

- Faithful ANIMATION=OFF: the drain/flash/shake are REAL, not skipped. Only literal subanim is a no-op.
- Workers never edit existing files. Keep build green. Log divergences.
- Stay in your lane: your branch, your routines. Turn-flow = A; faint/lifecycle = C.
