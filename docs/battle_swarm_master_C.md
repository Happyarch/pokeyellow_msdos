# Battle swarm — MASTER C: lifecycle, multi-mon & in-battle sub-UIs

You are an **Opus master** driving a Sonnet swarm. You own **what happens when a mon faints,
multi-mon (trainer) battles, and the in-battle bag/party sub-menus** — plus trainer AI and
Yellow obedience. This subsystem **couples to the items and party layers**, so several units
are integration-heavy (~3–4 effective workers).

## Isolation (mandatory)

`core.asm` is shared. **Work on branch/worktree `battle-swarm-C`.** You own: the faint/switch
handlers in `core.asm` (`HandlePlayerMonFainted` / `HandleEnemyMonFainted` and the switch-in
flow), `battle_menu.asm` (the sub-UI hooks), `trainer_ai.asm`, `read_trainer_party.asm`, and
`CheckForDisobedience` (currently a `core_stubs.asm`/`core.asm` stub). Do NOT touch
`ExecutePlayerMove`/`ExecuteEnemyMove`/`CheckXxxStatusConditions` (A) or `MainInBattleLoop`
message/menu pacing (B). Non-overlapping routines auto-merge; the human merges the branches.

## Read first

1. `CLAUDE.md` — register map, EBP model, the Gen-2 forward-compat struct rules (party/box
   byte layout is load-bearing — do NOT realign when doing party↔battle-mon sync).
2. `docs/plans/move_translation_divergence.md` — fidelity boundary + allowlist.
3. `docs/current_plan_pokemon_ui.md` + `docs/current_plan_items.md` — the party/bag layers you
   couple to (ITEM/POKéMON menus, item USE dispatch state).
4. pret `engine/battle/core.asm` — `HandlePlayerMonFainted` (`:708`ish), `HandleEnemyMonFainted`,
   `AnyPartyAlive`, the switch-in / `EnemySendOut` / trainer multi-mon flow, `MainInBattleLoop`'s
   `.checkAnyPartyAlive`, and `engine/battle/trainer_ai.asm`.

## Fidelity

pret is the spec. Faithful = §2 allowlist only. Preserve Gen-1 bugs/glitches with
`; BUG(level):` + `%if BUG_FIX_LEVEL >= N` (or `; GLITCH:`). Register map A=AL/BC=BX/DE=EDX/
HL=ESI/EBP base. Every divergence logged in `translation_log.md`.

## Your work units

| Unit | pret ref | Notes |
|---|---|---|
| **Faint → switch-in (player)** | `HandlePlayerMonFainted`, `AnyPartyAlive` | today: player faint just sets `wBattleResult=1` (loss). Port the real flow: remove fainted mon, `AnyPartyAlive` → blackout/whiteout vs forced party-switch to a live mon. |
| **Faint → next mon (enemy/trainer)** | `HandleEnemyMonFainted` + `EnemySendOut` | wild = battle ends (already works); trainer = send out the next party mon (pic swap, HUD, "Trainer sent out X!"). |
| **battle-mon ↔ party-mon sync** | pret load/store around switch | on switch/faint, load the incoming mon from `wPartyMon[wPlayerMonNumber]` into the battle-mon struct and write HP back on switch-out. **Carry byte offset 7 (catch-rate/held-item) verbatim** (Gen-2 forward-compat). |
| **Multi-mon trainer battles** | pret trainer battle loop | the enemy party iterates; verify `read_trainer_party.asm` feeds the send-out; prize money on victory. |
| **`BattleItemMenu`** | pret `MainInBattleLoop` ITEM branch | wire the in-battle bag → item USE dispatch (couples to `items/item_effects.asm`; today it's a re-show-the-menu stub). |
| **`BattlePartyMenu`** | pret PKMN branch | in-battle party → switch a mon (couples to `menus/party_menu.asm`; today a re-show stub). |
| **`TrainerAI` deepening** | `engine/battle/trainer_ai.asm` | item use / switch logic / multi-mon; today stubbed "no AI action" (correct only for wild). Its closure (AIGetTypeEffectiveness + stat-mod handlers) — check what's link-ready. |
| **`CheckForDisobedience`** | pret Yellow obedience | traded-mon obedience by badge/level; today stubbed "obeys". |
| **`MoveSelectionMenu` `wMoveMenuType=1`** | pret | the Mimic runtime gap — the human-player "pick a foe move to copy" path currently lists the player's own moves. |

## Drive the swarm

- Spawn up to **~4 Sonnet workers** on separable units (faint/switch, trainer send-out,
  disobedience, one sub-UI). The two sub-UIs and party-sync are integration-heavy — expect to
  do the wiring yourself.
- Workers write ONLY to `dos_port/scratch/`; extern the shared routines; prove `nasm -f coff`.
  **Never edit existing files.** For anything that must call a deferred items/party routine,
  the worker flags it; you decide link-now vs stub.
- **2 Sonnet auditors** verify vs pret (esp. the party-struct byte layout + the obedience math).
- **You integrate**, build green (levels 0/2), quick second audit.
- **2 Opus docs agents**: `translation_log.md` (Divergences field) + batched commits (human's
  say-so only). Update `docs/current_plan_pokemon_ui.md` when the ITEM/PKMN battle hooks land.

## Hard rules

- Party/box struct stays byte-identical to Gen 1 (offset 7 load-bearing). Never realign.
- Workers never edit existing files. Preserve Gen-1 bugs/glitches. Keep build green. Log divergences.
- Stay in your lane: your branch, your routines. Turn-flow = A; message/menu pacing = B.
