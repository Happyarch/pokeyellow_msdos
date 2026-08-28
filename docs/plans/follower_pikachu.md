# Current Plan: Overworld Follower Pikachu Subsystem

> **ARCHIVED 2026-08-21.** Every implementation and verification box is `[x]`.
> The one remaining line is a `[~]` MAINTAINER DECISION of 2026-08-18 not to
> author golden scenarios for a follower that is self-demonstrating — a
> resolution, not outstanding work, so `project_state --plans` counting it as
> open is a parser artifact rather than a reason to keep the plan active.
> Moved here from `docs/current_plan_follower_pikachu.md`.

Implementation plan to bring the overworld companion Pikachu subsystem to full completion, implementing follower placement, stepping state machines, movement command FIFO buffers, scripted movement interpreters, dialogue emotion reactions, and front-pic portrait animations.

## Background & Architecture

In Pokémon Yellow, Red's starter Pikachu follows behind him in the overworld as a persistent companion occupying **Sprite Slot 15** (`$F0` in `wSpriteStateData1` / `wSpriteStateData2`).

The subsystem consists of four primary components:
1. **Follower Placement & Coordinate Tracking (`pikachu_follow.asm`):** Coordinates follower positioning, spawn calculations across map transitions/doors/warp pads, and the 16-byte follow command FIFO (`wPikachuFollowCommandBuffer`).
2. **Follower Stepping FSM (`pikachu_follow.asm` & `pikachu_movement.asm`):** Drives the 11-state follow state machine (`PointerTable_fc710`: normal 8-frame steps, fast catch-up 4-frame steps, hops, spins, fidgets) and scripted movement interpreter (`ApplyPikachuMovementData_`).
3. **Overworld Interaction & Emotion Dispatch (`pikachu_emotions.asm`):** Handles A-press interaction (`IsPlayerTalkingToPikachu`), context-specific reactions (Fan Club, Pewter Center, Bill's House, Pokémon Tower, status conditions), emote bubble displays, PCM speech playback (`PlayPikachuSoundClip`), and Nurse Joy healing coordination.
4. **Front-Pic Facial Reaction Engine (`pikachu_pic_animation.asm`):** Mood & happiness matrix driving 5×5 animated facial reaction portraits.

---

## Action Items & Tasks

### Phase 1: Follower State, Coordinates & Overworld Stepping FSM (`src/engine/pikachu/pikachu_follow.asm`)
- [x] Port spawn calculation routines: `CalculatePikachuPlacementCoords`, `CalculatePikachuSpawnCoordsAndFacing`, `CalculatePikachuFacingDirection`, `ComputePikachuFacingDirection`, `SchedulePikachuSpawnForAfterText`, `ClearPikachuSpriteStateData`.
- [x] Port outdoor, warp pad, and connected map transition spawn hooks: `SetPikachuSpawnOutside`, `SetPikachuSpawnWarpPad`, `SetPikachuSpawnBackOutside`, `Pointer_fc64b`, `Pointer_fc653`, `Pointer_fc68e`.
- [x] Port `_SpawnPikachu` (canonical `SpawnPikachu_`): `WillPikachuSpawnOnTheScreen`, `Func_fc745`, `Func_fc76a`.
- [x] Port `PointerTable_fc710` 11-state machine handlers:
  - `Func_fc793` (State 0: init & screen coords)
  - `Func_fc7aa`, `Pointer_fc7e3` (State 1: pop step & branch)
  - `Func_fc803`, `PointerTable_fc85a` (State 2: idle fidgets/hops/spins)
  - `NormalPikachuFollow`, `asm_fc9c3` (State 3: 8-frame normal step)
  - `Func_fca0a`, `asm_fca1c` (State 4: double-step catchup)
  - `FastPikachuFollow`, `asm_fc9ee` (State 5: 4-frame fast step)
  - States 6–9: `asm_fc87f`, `asm_fc904`, `asm_fc937`, `asm_fc969` (fidget animations)
- [x] Port step interpolation and pixel math: `AddPikachuStepVector`, `TryDoubleAddPikachuStepVectorToScreenPixelCoords`, `DoubleAddPikachuStepVectorToScreenPixelCoords`, `AddPikachuStepVectorToScreenPixelCoords`, `ResetPikachuStepVector`, `GetPikachuWalkingAnimationSpeed`, `UpdatePikachuWalkingSprite`.
- [x] Port follow command buffer FIFO: `Func_fcc08`, `Func_fcc23`, `Func_fcc42`, `Func_fcc64`, `Func_fcc92`, `GetPikachuFollowCommand`, `GetPikachuFollowCommandIfBufferSizeNonzero`, `AreThereAtLeastTwoStepsInPikachuFollowCommandBuffer`, `ComparePikachuHappinessTo80`.
- [x] Wire hooks in `dos_port/src/home/overworld.asm`:
  - Call `Func_fcc08` in `OverworldLoop.startWalk` / `.noCollision`.
  - Wire `CheckWarpsCollision` / `indoorMaps` / `goBackOutside` spawn setters.
  - Wire `LoadMapHeader` spawn scheduling (`SchedulePikachuSpawnForAfterText`).

### Phase 2: Scripted Movement Interpreter & Asset Loading (`src/engine/pikachu/pikachu_movement.asm`)
- [x] Port `ApplyPikachuMovementData_`, `LoadPikachuMovementCommandData`, `ExecutePikachuMovementCommand` (swapping player and Pikachu state data structures during script execution).
- [x] Port `PikachuMovementDatabase` (63 entries), `PikaMovementFunc1Jumptable` (24 handlers), `PikaMovementFunc2Jumptable` (11 handlers).
- [x] Port hopping shadow helpers: `GetCoordsForPikachuShadow`, `AnimatePikachuShadow`, `LoadPikachuShadowOAMData`.
- [x] Port VRAM graphics loaders: `LoadPikachuBallIconIntoVRAM`, `OverworldPikachuBallGFX`, `LoadPikachuSpriteIntoVRAM`.
- [x] Port context checks and math: `PikachuPewterPokecenterCheck`, `PikachuFanClubCheck`, `PikachuBillsHouseCheck`, `Cosine_e`, `Sine_e`, `GetSine`, `SineWave_3f`.
- [x] Retire `ApplyPikachuMovementData_` stub and `STUB{...}` annotation in `src/engine/overworld/overworld_stubs.asm`.

### Phase 3: Overworld Interaction, Emotion Dispatch & Status Scans (`src/engine/pikachu/pikachu_emotions.asm`)
- [x] Restore `IsPlayerTalkingToPikachu` hook on overworld A-press after `IsSpriteOrSignInFrontOfPlayer` in `src/home/overworld.asm`.
- [x] Port `TalkToPikachu` and `DoStarterPikachuEmotions` bytecode interpreter (handling text, pcm, emote bubbles, movement, pikapic, subcmd, delay).
- [x] Port context-sensitive emotion selector `MapSpecificPikachuExpression` (Fan Club, Pewter Center, Bill's House, Pokémon Tower, status conditions).
- [x] Port `PikachuWalksToNurseJoy` counter hop animation.
- [x] Port `RespawnOverworldPikachu` (`src/engine/pikachu/respawn_overworld_pikachu.asm`) and `IsSurfingPikachuInParty` (`src/home/map_objects.asm`).
- [x] Retire `TalkToPikachu`, `IsSurfingPikachuInParty` stubs in `overworld_stubs.asm` and `RespawnOverworldPikachu` stub in `battle_exp_stubs.asm`.

### Phase 4: Front-Pic Facial Animation Engine (`src/engine/pikachu/pikachu_pic_animation.asm`)
- [x] Port `GetPikaPicAnimationScriptIndex` and mood/happiness matrix lookup tables (`PikachuMoodLookupTable`, `PikaPicAnimationScriptPointerLookupTable`).
- [x] Port `ExecutePikaPicAnimScript`, object buffer animator, and bytecode interpreter (`PikaPicAnimCommand_*`).
- [x] Port `LoadOverworldPikachuFrontpicPalettes` palette publisher.
- [x] Generate Tier-1 pikapic data tables in `src/data/pikachu/` and link `gfx/pikachu/` 2bpp graphics.
- [x] Add `pikachu_pic_animation.o` to Makefile `LINK_SRCS`.

### Phase 5: Verification & Golden Scenarios
- [x] Run `dos_port/tools/lint_pret_labels --no-scan --strict-claims`. (0 findings, via `static_gate` checks 2+3)
- [x] Run `dos_port/tools/faithdiff` across all newly ported Pikachu routines.
- [x] Run `make -C dos_port static_gate`. (PASS — static gate green)
- [x] Run core fidelity suite (`make -C dos_port fidelity`). (16/16 PASS; `fidelity-full` 85 also run for the warp-path change)
- [~] Golden scenarios: NOT AUTHORED, by maintainer decision (2026-08-18). A follower that
  walks behind the player is self-demonstrating — running the game exercises it — and a
  golden for it would be about as useful as a golden for the act of walking. The subsystem
  is covered by the static tier plus the existing golden suite (89 scenarios at
  2026-08-21 — re-measure, it drifts upward) (which prove it regresses
  nothing); visual confirmation is by playing.


---

## Wiring closeout (2026-08-18)

Phases 1-4 ported the routines; a separate pass was needed because several were
**defined but never called**. Method: enumerate every Pikachu routine pret calls from
outside `engine/pikachu/` + `home/pikachu.asm`, then check each for a call site in the
port. Six gaps found and closed:

| routine | pret call site | port fix |
|---|---|---|
| `Func_fcc08` | `home/overworld.asm:231` (`.noCollision`) | called from `.startWalk` — pushes each step into the follow FIFO |
| `SetPikachuSpawnOutside` | `home/overworld.asm:476` | outdoor-source warp branch, after `wCurMap` = destination |
| `SetPikachuSpawnWarpPad` | `home/overworld.asm:503` | indoor source, non-`LAST_MAP` destination |
| `SetPikachuSpawnBackOutside` | `home/overworld.asm:507` | indoor source, `LAST_MAP` destination — called BEFORE `wCurMap` is reassigned |
| `IsPikachuRightNextToPlayer` | `engine/items/item_effects.asm:1887` | Poke Flute PEWTER_POKECENTER branch |
| `PlaySpecificPikachuEmotion` | `engine/items/item_effects.asm:1893` | same branch, emotion index 26 |

Two supporting changes were required:

* **`hWarpDestinationMap` did not exist in the port.** pret's `WarpFound1` records the
  RAW destination byte before resolving `LAST_MAP`, and `WarpFound2` branches on it to
  pick the spawn setter. The port resolved `$FF` inside `CheckWarpTile` and discarded the
  raw value, which made `.goBackOutside` indistinguishable from a warp naming `wLastMap`
  outright. Added `hWarpDestinationMap equ 0xFF8B` (pret's union byte) and recorded it at
  the resolution site.
* **The `wPikachuSpawnState = 2` / flags bit 4 set at `.loadNewMap`** was explicitly
  deferred in a comment; now live, placed BEFORE `LoadMapHeader` as pret does.

### Known remaining gap (NOT follower work) — RESOLVED 2026-08-28 Stage A2

`UpdatePikachuHappinessAndMood` was ported but unwired; its only pret call site is
`engine/events/poison.asm:16`. Stage A2 (`fa5bae9b2`) ported `engine/events/poison.asm`
(`src/engine/events/poison.asm`) and wired the overworld poison-step tick at
`src/home/overworld.asm:.notSafariZone` (`wIsInBattle` guard → `ApplyOutOfBattlePoisonDamage`
→ `wOutOfBattleBlackout` → `HandleBlackOut`). That call chain invokes
`UpdatePikachuHappinessAndMood` every poison tick, so the gap is closed.
