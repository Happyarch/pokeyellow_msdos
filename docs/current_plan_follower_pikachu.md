# Current Plan: Overworld Follower Pikachu Subsystem

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
- [ ] Port spawn calculation routines: `CalculatePikachuPlacementCoords`, `CalculatePikachuSpawnCoordsAndFacing`, `CalculatePikachuFacingDirection`, `ComputePikachuFacingDirection`, `SchedulePikachuSpawnForAfterText`, `ClearPikachuSpriteStateData`.
- [ ] Port outdoor, warp pad, and connected map transition spawn hooks: `SetPikachuSpawnOutside`, `SetPikachuSpawnWarpPad`, `SetPikachuSpawnBackOutside`, `Pointer_fc64b`, `Pointer_fc653`, `Pointer_fc68e`.
- [ ] Port `_SpawnPikachu` (canonical `SpawnPikachu_`): `WillPikachuSpawnOnTheScreen`, `Func_fc745`, `Func_fc76a`.
- [ ] Port `PointerTable_fc710` 11-state machine handlers:
  - `Func_fc793` (State 0: init & screen coords)
  - `Func_fc7aa`, `Pointer_fc7e3` (State 1: pop step & branch)
  - `Func_fc803`, `PointerTable_fc85a` (State 2: idle fidgets/hops/spins)
  - `NormalPikachuFollow`, `asm_fc9c3` (State 3: 8-frame normal step)
  - `Func_fca0a`, `asm_fca1c` (State 4: double-step catchup)
  - `FastPikachuFollow`, `asm_fc9ee` (State 5: 4-frame fast step)
  - States 6–9: `asm_fc87f`, `asm_fc904`, `asm_fc937`, `asm_fc969` (fidget animations)
- [ ] Port step interpolation and pixel math: `AddPikachuStepVector`, `TryDoubleAddPikachuStepVectorToScreenPixelCoords`, `DoubleAddPikachuStepVectorToScreenPixelCoords`, `AddPikachuStepVectorToScreenPixelCoords`, `ResetPikachuStepVector`, `GetPikachuWalkingAnimationSpeed`, `UpdatePikachuWalkingSprite`.
- [ ] Port follow command buffer FIFO: `Func_fcc08`, `Func_fcc23`, `Func_fcc42`, `Func_fcc64`, `Func_fcc92`, `GetPikachuFollowCommand`, `GetPikachuFollowCommandIfBufferSizeNonzero`, `AreThereAtLeastTwoStepsInPikachuFollowCommandBuffer`, `ComparePikachuHappinessTo80`.
- [ ] Wire hooks in `dos_port/src/home/overworld.asm`:
  - Call `Func_fcc08` in `OverworldLoop.startWalk` / `.noCollision`.
  - Wire `CheckWarpsCollision` / `indoorMaps` / `goBackOutside` spawn setters.
  - Wire `LoadMapHeader` spawn scheduling (`SchedulePikachuSpawnForAfterText`).

### Phase 2: Scripted Movement Interpreter & Asset Loading (`src/engine/pikachu/pikachu_movement.asm`)
- [ ] Port `ApplyPikachuMovementData_`, `LoadPikachuMovementCommandData`, `ExecutePikachuMovementCommand` (swapping player and Pikachu state data structures during script execution).
- [ ] Port `PikachuMovementDatabase` (63 entries), `PikaMovementFunc1Jumptable` (24 handlers), `PikaMovementFunc2Jumptable` (11 handlers).
- [ ] Port hopping shadow helpers: `GetCoordsForPikachuShadow`, `AnimatePikachuShadow`, `LoadPikachuShadowOAMData`.
- [ ] Port VRAM graphics loaders: `LoadPikachuBallIconIntoVRAM`, `OverworldPikachuBallGFX`, `LoadPikachuSpriteIntoVRAM`.
- [ ] Port context checks and math: `PikachuPewterPokecenterCheck`, `PikachuFanClubCheck`, `PikachuBillsHouseCheck`, `Cosine_e`, `Sine_e`, `GetSine`, `SineWave_3f`.
- [ ] Retire `ApplyPikachuMovementData_` stub and `STUB{...}` annotation in `src/engine/overworld/overworld_stubs.asm`.

### Phase 3: Overworld Interaction, Emotion Dispatch & Status Scans (`src/engine/pikachu/pikachu_emotions.asm`)
- [ ] Restore `IsPlayerTalkingToPikachu` hook on overworld A-press after `IsSpriteOrSignInFrontOfPlayer` in `src/home/overworld.asm`.
- [ ] Port `TalkToPikachu` and `DoStarterPikachuEmotions` bytecode interpreter (handling text, pcm, emote bubbles, movement, pikapic, subcmd, delay).
- [ ] Port context-sensitive emotion selector `MapSpecificPikachuExpression` (Fan Club, Pewter Center, Bill's House, Pokémon Tower, status conditions).
- [ ] Port `PikachuWalksToNurseJoy` counter hop animation.
- [ ] Port `RespawnOverworldPikachu` (`src/engine/pikachu/respawn_overworld_pikachu.asm`) and `IsSurfingPikachuInParty` (`src/home/map_objects.asm`).
- [ ] Retire `TalkToPikachu`, `IsSurfingPikachuInParty` stubs in `overworld_stubs.asm` and `RespawnOverworldPikachu` stub in `battle_exp_stubs.asm`.

### Phase 4: Front-Pic Facial Animation Engine (`src/engine/pikachu/pikachu_pic_animation.asm`)
- [ ] Port `GetPikaPicAnimationScriptIndex` and mood/happiness matrix lookup tables (`PikachuMoodLookupTable`, `PikaPicAnimationScriptPointerLookupTable`).
- [ ] Port `ExecutePikaPicAnimScript`, object buffer animator, and bytecode interpreter (`PikaPicAnimCommand_*`).
- [ ] Port `LoadOverworldPikachuFrontpicPalettes` palette publisher.
- [ ] Generate Tier-1 pikapic data tables in `src/data/pikachu/` and link `gfx/pikachu/` 2bpp graphics.
- [ ] Add `pikachu_pic_animation.o` to Makefile `LINK_SRCS`.

### Phase 5: Verification & Golden Scenarios
- [ ] Run `dos_port/tools/lint_pret_labels --no-scan --strict-claims`.
- [ ] Run `dos_port/tools/faithdiff` across all newly ported Pikachu routines.
- [ ] Run `make -C dos_port static_gate`.
- [ ] Run core fidelity suite (`make -C dos_port fidelity`).
- [ ] Author and run golden scenarios verifying follower movement, ledge jumping, talking to Pikachu, and Pokémon Center healing.
