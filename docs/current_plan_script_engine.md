# Current Plan: Script Engine — Faithful Translation

> **SUPERSEDED (2026-07-12): absorbed into `docs/current_plan_overworld_events.md`**
> — its Stage 1 is this plan's Oak-intro milestone (ABI cheatsheet carried over);
> kept for the completed-stage record until that plan archives.

Active work item: faithfully translate gen-1's script system (per-map `_Script`
state machines + `_TextPointers` / `text_asm` text scripts, gated on the event-flag
system, dispatched by `DisplayTextID` / `RunMapScript`). Full plan:
`~/.claude/plans/hazy-hopping-puffin.md`.

**Milestone 1 — event-gated dialog foundation.** Actions needing systems not yet
ported (battling, items, party, menus, music) are stubbed and recorded; where an event
must persist past a stubbed set-piece, the stub force-sets the event flag.

## Tracking (the DB is the source of truth)

Use `dos_port/tools/work_queue` (over `translation.db`). The swarm `claim`/`place`
pipeline is for simple mass translation; the script engine is hand-translated by Claude
Code via targeted claims and the `wired`/`verified` transitions:

- `work_queue claim --name DisplayTextID --agent <id>` (or `--id N`) → translate →
  `place --output …` → `wire --id N` → `verify --id N`.
- Per-map scripts are the `script` category (`scripts/*.asm`, indexed by `build_index`).
- Stub deferrals: `work_queue stub add --id N --kind <battle|items|pokemon|party|menu|
  music|sfx|save|misc> --notes "…"`; sweep later with `stub list --kind X --unresolved`.
- `dos_port/tools/gen_progress_report` → `docs/translation_progress.md` (snapshot).
- Translation-log entries: `work_queue translation-log-entry --id N` → `docs/translation_log.md`.
  Header-level work (event macros) is logged in `translation_log.md` directly.

## Stages (see the full plan for detail)

- [x] **Pass 1 — tooling** (claim by id/name, `script` category + migration, `stubs`
      table + subcommands, `gen_progress_report`). Committed.
- [x] **Stage 1 — event-flag system**: `gen_event_constants.py` → `assets/event_constants.inc`;
      `include/events.inc` (`CheckEvent`/`SetEvent`/`ResetEvent`). Assembles.
- [x] **Stage 2+3 — text_asm dispatch** (collapsed): instead of `DisplayTextID` +
      `TX_START_ASM`-in-stream, a map TextTable slot can be a **SCRIPT entry**
      (`dd <routine>, 0xFFFFFFFF`). `CheckNPCInteraction` CALLs the flat `text_asm`
      routine; new shared `ShowTextStream` (copy flat→`NPC_DIALOG_BUF`, `PrintText`,
      wait) serves both scripts and plain text. `gen_npc_dialogs.py` gained a
      `SCRIPT_OVERRIDES` registry. Builds + links; **visual test pending Oak spawn**.
- [x] **Stage 4 — Pallet Town reference** (`src/scripts/pallet_town.asm`): `PalletTownOakText`
      gates on `EVENT_GOT_POKEBALLS_FROM_OAK` (`CheckEvent`) → two branches. Test with
      `DEBUG_OAK_EVENT=1` once Oak is spawn-gated into the map.
- [x] **Stage 5 — `RunMapScript` dispatch skeleton.** DONE. New
      `tools/gen_map_scripts.py` → `assets/map_scripts.inc`: `MapScriptPointers`
      (249 = NUM_MAPS flat `dd`, indexed by `wCurMap`, default `DefaultMapScript`,
      `SCRIPT_OVERRIDES` registry → `PALLET_TOWN`), exposed by `src/data/map_scripts.asm`.
      `RunMapScript` + `DefaultMapScript` + `CallFunctionInTable` (flat-`dd` jumptable
      dispatch) in `src/engine/overworld/run_map_script.asm`; **wired into `OverworldLoop`**
      (runs every frame, right after `RunNPCMovementScript`). Boulder push / dust /
      `SwitchToMapRomBank` are deferred no-ops (see header `; TODO` notes). A faithful
      `PalletTown_Script` skeleton (`src/scripts/pallet_town.asm`) does the
      `EVENT_GOT_POKEBALLS_FROM_OAK` → `EVENT_PALLET_AFTER_GETTING_POKEBALLS` event-gate,
      then `CallFunctionInTable` on `wPalletTownCurScript`. `EnableAutoTextBoxDrawing` /
      `DisableAutoTextBoxDrawing` are translated (`src/text/auto_textbox.asm`); the
      common-case map default (`DefaultMapScript`) and `PalletTown_Script` both use it
      faithfully (most pret `_Script`s that do nothing else are `jp EnableAutoTextBoxDrawing`).
      **Native-validated** (ELF32):
      CallFunctionInTable index dispatch (0/1/2), the Pallet event-gate (set/clear),
      all 10 Pallet states dispatch + return cleanly, and a default map → no-op. The
      script bundle partial-links (only `ShowTextStream` external); `overworld.asm`
      assembles with the new call.
- [~] **Stage 6 — stub conventions.** Pallet Town cutscene states recorded as stubs in
      `PalletTown_ScriptPointers`: `PalletTownDefaultScript` (the Oak-intro trigger,
      `; STUB(misc)`) and `PalletTown_CutsceneStub` (OAK_HEY_WAIT … DAISY,
      `; STUB(battle,misc)` — need scripted NPC movement + the Pikachu battle). These
      keep the dispatch total and faithful while the cutscene lands in a later milestone.
      Earlier: deferred Oak intro recorded as stubs on `PalletTownOakText` (battle, misc).

## Testing note

Oak does not spawn by default (no intro/spawn-gating yet), so the dialog can't be
reached until Oak is spawned into Pallet Town. To visually test: spawn Oak (debug
spawn flag), then talk to him — default build shows "Hey! Wait!", `DEBUG_OAK_EVENT=1`
(needs `make clean`) shows "That was close!". Plain Girl/Fisher dialog is the
regression check for the refactored `ShowTextStream` path.

## Next milestone — Oak intro cutscene (blockers cleared 2026-07-10; ready for a live-test session)

The Pallet Town Oak intro (`scripts/PalletTown.asm` — 10 `_Script` states +
`PalletTownOakText`) is the next milestone. Both former blockers are now cleared:
**scripted NPC movement is done** and the **battle engine runs a live overworld
encounter** (`_InitBattleCommon`, commit `a9352307`). Dependency audit (2026-07-10):
every predef/routine it needs is a **real ported body**, not a stub —
`EnableAutoTextBoxDrawing`, `DisplayTextID`, `StopAllMusic`/`PlayMusic`,
`ShowObject`/`HideObject`, `CalcPositionOfPlayerRelativeToNPC`, `FindPathToPlayer`,
`MoveSprite`/`MoveSprite_`, `EmotionBubble`; `CheckBothEventsSet`/`SetEventReuseHL`
macros exist; all constants/events are defined.

**Why it was NOT ported blind this session (needs live DOSBox-X verification):** the
cutscene is an atomic 10-state chain — half-porting soft-locks the town's north exit
(`PalletTownDefaultScript` freezes the player + `wJoyIgnore` on reaching `wYCoord==0`
with `EVENT_FOLLOWED_OAK_INTO_LAB` clear, then hands to the next state). Several
integration points are ABI-sensitive and unverifiable without running it:
- **`MoveSprite` sprite selector:** the port's `GetSpriteMovementByte1Pointer` reads
  `H_CURRENT_SPRITE_OFFSET` (0xFFDA) as a **pre-multiplied byte offset** (slot×$10),
  NOT pret's raw `hSpriteIndex` slot. pret `ldh [hSpriteIndex], PALLETTOWN_OAK / call
  MoveSprite` must become `mov [H_CURRENT_SPRITE_OFFSET], slot*$10` (confirm whether the
  port's `MoveSprite` does its own swap first — cross-check `trainer_engine.asm:505-511`
  which uses `MoveSprite_`). Pathfinding uses `H_NPC_SPRITE_OFFSET` (0xFF95, a union w/
  `hNPCPlayerYDistance`) — pret `hNPCSpriteOffset`.
- **`DisplayTextID` dispatch:** the port routes NPC dialog through SCRIPT entries /
  `ShowTextStream`, not pret's `hTextID`→map-`TextPointers`. Verify `call DisplayTextID`
  with `hTextID = TEXT_PALLETTOWN_OAK` actually reaches `PalletTownOakText`.
- **`BATTLE_TYPE_PIKACHU` special flow:** `PalletTownPikachuBattleScript` sets
  `wCurOpponent=STARTER_PIKACHU`, `wBattleType=BATTLE_TYPE_PIKACHU`, `wCurEnemyLevel=5`,
  then the overworld forced-opponent path fires. `_InitBattleCommon` runs the WILD flow;
  the Pikachu starter battle (no ball/no-catch/scripted) is a battle-engine special case
  still to handle.
- **ABI cheatsheet (verified):** `PlayMusic` = AL music id, BL audio bank (`ld c,BANK /
  ld a,MUSIC` → `mov bl,BANK / mov al,MUSIC`); `SetEventReuseHL`≡`SetEvent`;
  `H_JOY_HELD`=0xFFB4, `W_JOY_IGNORE`=0xCD6B, `W_PLAYER_MOVING_DIRECTION`=0xD527,
  `W_Y_COORD`=0xD360/`W_X_COORD`=0xD361, `PLAYER_DIR_UP`=8, `SPRITE_FACING_UP`=$04/
  `LEFT`=$08/`RIGHT`=$0C, `TOGGLE_PALLET_TOWN_OAK`=0, `wNPCMovementDirections2`=0xCC97,
  `W_NPC_MOVEMENT_SCRIPT_FUNCTION_NUM`=0xCF10/`_BANK`=0xCC58, `wStatusFlags5` bit
  `BIT_SCRIPTED_NPC_MOVEMENT`=0.

**Recommended execution:** port all 10 states faithfully in one pass, gate
`PalletTownDefaultScript`'s trigger body behind `%ifdef DEBUG_OAK_INTRO` (default =
today's free-roam, zero regression), then live-test the whole chain via the flag +
Oak spawn; drop the gate once verified. Handle `BATTLE_TYPE_PIKACHU` as a battle-engine
sub-task (may reuse the wild flow initially with a `; TODO(special)` for no-catch/loss).

## Also deferred

Per-map `_Script` state machines beyond the no-op skeleton; the `DisplayTextID` special
dict cases (start menu, mart, pokecenter, PC) — all stubbed and recorded.

**INBOUND HANDOFF (2026-07-10, from the overworld-port plan): scripted NPC movement
is DONE and this plan now owns OW-2.5.** The overworld plan's Stage 2 landed the
complete scripted-movement engine (DoScriptedNPCMovement/InitScriptedNPCMovement,
the MoveSprite scripted chain incl. Func_5288, pathfinding, auto_movement's
`PalletMovementScript_*` Oak walk-to-lab state machine + RLELists, ungated
`RunNPCMovementScript` dispatch) — all linked, faithful, and inert until a script
fires the trigger. The blocker for the Oak cutscene is now purely on THIS plan's
side: replace the `PalletTownDefaultScript`/`PalletTown_CutsceneStub` ret-stubs
with the real trigger + cutscene states 1–8. When that lands, run **OW-2.5's
runtime verification** (spec in `current_plan_overworld_port.md` Stage 2):
DOSBox-X MCP breakpoint `DoScriptedNPCMovement`, `gb_read wNPCMovementDirections2`,
`dump_frame` per step; final FRAME.BIN shows Oak + player walked to the Lab.
Report the result back to the overworld plan's Stage 8 runtime-regression item.
