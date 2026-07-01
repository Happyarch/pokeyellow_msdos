# pret `home/` → DOS-port Divergence Audit + Rectification Swarm

## Context

The port keeps pret routine **names** but scatters them across `dos_port/src/**`
(there is no 1:1 `src/home/` mirror). Over many swarm sessions, coverage of the
~70 pret `home/*.asm` files has drifted: some routines are faithful, some are
partial, some are silently wrong, and whole clusters are missing — with no single
document tracking which is which. This plan (a) records a **file-by-file divergence
audit** of every pret `home/` routine against its port implementation, graded
`FAITHFUL / PARTIALLY FAITHFUL / PARTIALLY IMPLEMENTED / UNFAITHFUL / NOT
IMPLEMENTED`, and (b) specifies a **rectification swarm** with hand-written
per-member assignments to close the gaps, ordered by faithfulness severity.

The audit itself was run as a 21-agent **read-only** survey (one agent per pret
`home/` file or tight cluster; `overworld.asm` split in two). Findings below are
their consolidated, line-cited results.

### Resolved HOW decisions (hardware / phase-deferred divergences)
- **Audio** ($FF10–26): planned end-state = faithful call-structure + **silent
  no-op HAL stub**. *No-go to touch now* — deferred until other work lands. Only
  `PlaySound` currently exists (a `ret` stub); every other audio symbol is undefined.
- **Link / serial / printer** ($FF01/02): planned end-state = **faithful no-op HAL
  stub**. Deferred; no current caller, so nothing breaks today.
- **Save / SRAM**: **report only, untouched** until the game is stable.
- **Palette / color**: **structure faithful, color values deferred to Phase 5**
  (DMG-green placeholder stays). Grade palette *plumbing*, not color fidelity.
- **Fix scope**: **strictly home/-routines only.** A member fixes the pret
  home-equivalent routines in its lane; cross-subsystem glue to non-home callers is
  *logged as a follow-up*, not performed.
- **Swarm order**: **by faithfulness severity** — UNFAITHFUL / silent-wrong and
  build landmines first, then PARTIAL, then NOT IMPLEMENTED.

### Faithful-by-design adaptations (NOT counted as divergences)
Software PPU for $FF40–4B video + OAM DMA; keyboard ISR → joypad; PIT 60 Hz loop
for the frame heartbeat; flat EBP-relative memory for MBC banking (bankswitch =
no-op); shadow-OAM build + DMA-copy. These are graded faithful; the audit only
flags where the *effect* still diverges.

---

## PART A — Divergence Report

### A.0 Highest-severity findings (fix first)

**Silent correctness bugs (UNFAITHFUL — wrong output, no crash):**
1. **`Random_` PRNG double-add** — `dos_port/src/engine/math/random.asm:33-37`
   does `add al,bl` then `adc al,bl`, adding DIV twice and clobbering the caller's
   incoming carry. Result is `hRandomAdd + 2*DIV + carry` vs pret's `+ DIV +
   carry_in`. The PRNG stream diverges from the GB reference on **every call**.
2. **`GetMachineName` doesn't restore `wNamedObjectIndex`** —
   `dos_port/src/home/names.asm:203-204` leaves `id + NUM_HMS` in
   `wNamedObjectIndex` after naming an HM (pret `push af`/`pop af`-restores).
   Silently corrupts the index for any caller that re-reads it.
3. **Text `TX_FAR` ($17) renders nothing** — `dos_port/src/text/text.asm:955`
   does `add esi,3 / jmp .next_cmd`, dropping the referenced far-text entirely.
   `text_far` is the dominant dialogue encoding; any un-fused stream shows a blank
   box. **Single largest faithfulness gap in the game.**
4. **`GBPalWhiteOut` only zeroes BGP** — `dos_port/src/movie/title.asm:446` leaves
   `OBP0/OBP1` untouched, so sprites stay visible through every white-out
   transition (pret zeroes all three).
5. **`ExtraWarpCheck` hardcoded** — `overworld.asm:507-511` collapses pret's
   per-map function-1 (`IsPlayerFacingEdgeOfMap`) vs function-2
   (`IsWarpTileInFrontOfPlayer`) dispatch to a single "facing DOWN on a warp" test;
   mis-warps on edge-warp maps.

**Build / link landmines (undefined or unlinked symbols):**
6. **`BankswitchCommon` undefined** — `dos_port/src/home/copy.asm:9,22,25` externs
   & calls it; **no definition exists** anywhere. Needs a trivial faithful no-op
   (`mov [ebp+hLoadedROMBank],al; ret`).
7. **`GetPredefPointer` → undefined `PredefPointers`** —
   `dos_port/src/engine/predefs.asm:27,42`; table include is commented out. Dead
   code with an unresolved reference.
8. **`count_set_bits.asm` not in the Makefile** — faithful `CountSetBits` exists but
   is never linked; unresolved the moment a real caller lands.
9. **`hFrameCounter` never decremented** — `H_FRAME_COUNTER` has no writer in the
   built tree; any ported caller that keeps pret's set-`hFrameCounter`-and-spin idiom
   (`print_text`, `text_script`, `joypad2`) would **deadlock**.
10. **`swap_items.asm` dead** (undefined `DisplayListMenuIDLoop`, absent from
    Makefile); **`src/engine/joypad.asm` dead** (faithful `_Joypad` copy, unlinked,
    jumps to undefined `Joypad`); **`src/engine/pokemon/add_mon.asm` unlinked**
    (`_MoveMon`/`_AddEnemyMonToPlayerParty` blocked by a duplicate
    `AddPartyMon_WriteMovePP` global).

### A.1 Per-file grade summary

Legend: F=Faithful, PF=Partially Faithful, PI=Partially Implemented, U=Unfaithful,
NI=Not Implemented, HAL=deferred HAL stub (by policy).

| pret home file | Status | Key notes |
|---|---|---|
| array/array2 | F + NI | `IsInArray`/`AddNTimes`/`SkipFixedLengthTextEntries` F; `IsInRestOfArray` NI; `IsInArray` uses flat `[esi]` (correct only for current callers) |
| compare | F | `StringCmp` F |
| copy | PF + NI | `CopyData` PF (count=0→0 vs pret 256); dead `copy.asm` twin; `CopyString` standalone NI |
| copy2 | NI | `FarCopyDataDouble`, `CopyVideoData(Double)`, `GetFarByte`, `ClearScreenArea`, `CopyScreenTileBufferToVRAM` all NI (blocks Town Map); `ClearScreen`/`CopyToStringBuffer` F |
| copy_string | NI | folded into `CopyToStringBuffer`; no standalone `CopyString` |
| count_set_bits | F-but-unbuilt | not in Makefile |
| math | F | `Multiply`/`Divide` F (+div-by-0 guard) |
| give | NI | `GiveItem`/`GivePokemon` absent (`AddItemToInventory` dep ready) |
| random | F + U | `Random` wrapper F; **`Random_` U (double-add bug)** |
| delay | PF | `DelayFrames` PF (c=0→0 vs 256); `DelayFrame` F |
| money | NI | `HasEnoughMoney`/`HasEnoughCoins` absent |
| text | PF + U | `TX_FAR` U (blank), `TX_DOTS`/`TX_PAUSE` U, `<_CONT>`/`<PAGE>` collapsed; most codes F |
| print_text | F | (adapted) |
| textbox | NI | general `DisplayTextBoxID` dispatcher absent (only battle-menu box) |
| tilemap | F + NI | save/load buffers F; `LoadScreenTilesFromBuffer2DisableBGTransfer` NI |
| text_script | NI | **`DisplayTextID` + entire dialogue-dispatch tree absent** (extern-only) |
| print_num/print_bcd | F | `PrintNumber`/`PrintBCDNumber` F; `FarPrintText` NI |
| names/names2 | F + U + NI | dispatch F; **`GetMachineName` U**; `IsItemHM`/`IsMoveHM`/`HMMoves` NI |
| load_font | PF | 1bpp→2bpp F; LCDC on/off VBlank-stream branch collapsed |
| overworld (1st half) | PF + NI | load/loop/warp skeleton PF; wild-encounter/step/sign/bike/blackout systems NI; **`ExtraWarpCheck` U** |
| overworld (2nd half) | PF + NI | collision/view/warp restructured & real; signs, ledges/tile-pairs, sim-input buffer, player-gfx variants, surf/strength NI; double `LoadScreenRelatedData` call to verify |
| overworld_text | NI | all sign/interaction text scripts absent |
| map_objects | NI | sprite-facing helpers, `CheckCoords`/`ArePlayerCoordsInArray`, sim-joypad start, PC text-scripts, `IsItemInBag`, `DisplayPokedex` absent |
| npc_movement | PI | `RunNPCMovementScript` door-half only; scripted-NPC dispatch deferred |
| pathfinding | NI | `MoveSprite`/`CalcDifference`/`DivideBytes` absent |
| hidden_events | NI | signs/bookshelf/card-key-door/Cinnabar-gate all absent |
| oam | NI | `WriteOAMBlock` absent (blocks Cut/emotion/trade animations) |
| clear_sprites | F | `ClearSprites`/`HideSprites` F |
| update_sprites | F/PF | `UpdateSprites` F; `_UpdateSprites` PF (no `SpawnPikachu` slot-$f0, no scripted-NPC dispatch) |
| reload_sprites | NI | `ReloadMapSpriteTilePatterns` absent (composable from ported parts) |
| reload_tiles | NI | `ReloadMapData`/`ReloadTilesetTilePatterns` wrappers absent (`LoadTilesetTilePatternData` exists) |
| reset_player_sprite | PF | value-set inlined; two-block `FillMemory` zero-clear absent |
| vblank/vcopy | PF + NI | **`hFrameCounter` dec NI (deadlock risk)**, `TrackPlayTime` NI, `wDisableVBlankWYUpdate` gate dropped, `UpdateMovingBgTiles`/`VBlankCopyBgMap` NI; auto-BG thirds collapsed |
| lcd/lcdc | PF + NI | `DisableLCD` PF (no scanline wait — OK for SW PPU); STAT/`wLYOverrides` NI |
| fade | NI | `GBFade*` family + `FadePal1..8` + `LoadGBPal` (Flash dimming) all absent — **implementable now, not blocked on color** |
| fade_audio | HAL | `FadeOutAudio` deferred (audio) |
| palettes | PF + NI | `GBPalNormal` PF; **`GBPalWhiteOut` U**; `GetHealthBarColor` NI (gameplay logic); `RunPaletteCommand`/`RunDefaultPaletteCommand` NI (SGB/Phase-5) |
| cgb_palettes | PF | `UpdateCGBPal_*` plumbing exists via per-frame `commit_palette`; CGB color-conversion deferred |
| pokemon/move_mon | F + PF + NI | struct offsets byte-identical incl. offset-7; `CalcStat(s)`/`LoadMonData`/`experience` F; **`_AddPartyMon` PF (no Dex flags, no wild-catch DV copy, OTID=0)**; `GetPartyMonName` NI-stub; `GetMonHeader` PF (fossil/ghost IDs unguarded) |
| pics/uncompress | F + NI | runtime decompressor + merge pipeline F (no offline-tool divergence); `UncompressMonSprite`+mon-pic pointer table NI; `LoadFrontSpriteByMonIndex` (Rhydon trap) NI |
| trainers/trainers2 | NI | **entire overworld trainer-engagement layer absent**; `GetTrainerName` F; bespoke `CheckTrainerSight`/`TrainerEncounterFlow` detect but never battle |
| inventory/item/item_price | F + PF + NI | add/remove/`GetMachinePrice` F; `TossItem_`/`IsKeyItem_` inlined bag-only (no `wIsKeyItem`); `GetItemPrice` PF (no MOVESLISTMENU); `UseItem_` NI (deferred); `AddAmountSoldToMoney` NI |
| list_menu/start_menu/yes_no/window | NI + PF | **YES/NO framework entirely NI**; generic `DisplayListMenuID` NI (item+party bespoke); start-menu dispatch stubs; `HandleMenuInput`/`PlaceMenuCursor` PF (no wrap/timeout/`wMenuCursorLocation`) |
| init/start/header/timer/play_time | F + PF + NI | `Init`/`ClearVram` F; header N/A; timer no-op F-by-design; `_Start` PF (no `hOnCGB`); **`SoftReset` NI**, **`TrackPlayTime` NI**, `CountDownIgnoreInputBitReset` PI (overworld-only) |
| predef/predef_text/bankswitch | NI + F | `Bankswitch` F-by-design; **`BankswitchCommon` NI (dangling extern)**; unified `Predef` NI (piecewise `*Predef` wrappers); `predef_text` unit fully NI |
| joypad/joypad2 | PF + NI | ISR read F-by-design; **`wJoyIgnore` mask NI, `hJoyReleased` NI, `BIT_DISABLE_JOYPAD` global discard PI**; `JoypadLowSensitivity` NI-stub; sim-joypad ad-hoc |
| audio/pikachu_cries | HAL | all deferred; only `PlaySound` stub exists |
| pikachu (follower) | NI | entire overworld follower FSM absent (slot 15 reserved only) |
| serial/printer | HAL | all deferred; no current callers |

---

## PART B — Rectification Swarm

Members are hand-written and ordered by faithfulness severity (Wave 0 = worst).
Each member is **strictly scoped to pret home/-routines** in its lane; non-home
glue is logged as a follow-up, not implemented. Each member must add/keep
`BUG`/`GLITCH`/`TODO-HW` tags and verify with `nasm -f coff -o /dev/null`.

### Orchestration model (write-collision avoidance)
The **root agent** orchestrates and is the *only* writer of shared/integration
files. Execution runs in **squads of 8 worker subagents**, and **per squad the root
spawns 2 documentation agents** (10 agents per squad). Division of labour:
- **All subagent writes go to the scratchpad, never the repo tree.** Workers and doc
  agents produce their output as files/patches under the session scratchpad
  (`.../scratchpad/<member-id>/`) — proposed `.asm` bodies, unified diffs, and a
  structured change summary. No subagent edits anything under `dos_port/` or `docs/`
  directly; the working tree is touched by the root alone.
- **Worker subagents (8/squad):** implement one member each, writing their proposed
  source (new/changed `.asm`) plus a summary (files targeted, new symbols, shared-file
  edits *needed* — Makefile/memmap/constants, follow-up glue) into their scratchpad dir.
- **Documentation agents (2/squad):** read the squad's scratchpad summaries and draft
  the `docs/translation_log.md` entries, plan-checkbox updates, and audit/swarm-doc
  patches — also written to the scratchpad, not the repo.
- **Root (sole integrator):** reviews each scratchpad, then applies everything into
  the real tree itself — source files, shared-*code* edits (Makefile source list,
  memmap/constants additions, dead-symbol removals), and the doc-agent patches —
  resolving any two members that need the same file. Runs the full `make -C dos_port`
  link, and only then releases the next squad. Serialising every repo write through
  the root means no two agents ever write the same file, and nothing lands unreviewed.

Squad batching follows the waves: Wave 0 (5 members) runs first as its own small
squad because it unblocks the link for everyone; subsequent waves are packed into
8-worker squads in severity order.

### WAVE 0 — Silent-wrong bugs & build landmines  ✅ DONE (2026-07-01; PKMN.EXE links, `make check` clean)

- [x] **M0.1 — `Random_` PRNG fix.** `engine/math/random.asm:33-37`: replace the stray
  `add al,bl` + `adc al,bl` with a single carry-preserving `adc al,bl` so the result
  is `hRandomAdd + DIV + carry_in` (pret `engine/math/random.asm:3-12`). Preserve the
  caller's incoming carry across entry. Keep the `+0x25 DIV` churn (faithful-by-design).
- [x] **M0.2 — Bankswitch symbols.** Add faithful no-op `BankswitchCommon`
  (`mov [ebp+hLoadedROMBank],al; ret`), plus no-op `BankswitchHome`/`BankswitchBack`
  so `FarCopyData` (`home/copy.asm`) links and future callers keep pret names.
- [x] **M0.3 — `GetMachineName` restore.** `home/names.asm`: save the original
  `wNamedObjectIndex` on entry and rewrite it before `ret` on the HM path (pret
  `home/names.asm:57,96-97`).
- [x] **M0.4 — `GBPalWhiteOut` sprites.** `movie/title.asm:446`: also zero `IO_OBP0` and
  `IO_OBP1` (pret `palettes.asm:34-43`).
- [x] **M0.5 — Build hygiene / dead code.** Add `count_set_bits.asm` to the Makefile;
  either assemble `PredefPointers` or remove the dead `GetPredefPointer`; delete or
  annotate the dead `src/home/copy.asm`, `src/engine/joypad.asm`, and `swap_items.asm`;
  resolve the duplicate `AddPartyMon_WriteMovePP` global so `add_mon.asm` can link.
  (Cross-file build changes — log any non-home glue as follow-up.)

### WAVE 1 — Text engine (highest player-visible impact)  ✅ DONE (2026-07-01; text.asm links, text_script/predef_text check-only)

- [x] **M1.1 — `TX_FAR` ($17) rendering.** `text/text.asm:955`: stage far-ROM text into
  EBP space and recursively invoke `TextCommandProcessor` on the resolved pointer
  (pret `home/text.asm:601`). Audit every `DEFERRED: text_far` marker as a fallback.
- [x] **M1.2 — Text control codes.** Implement `TX_DOTS` ($0C, animated `…`), `TX_PAUSE`
  ($0A, A/B-or-30-frame wait); split `<_CONT>` $4B (wait+scroll) from `<SCROLL>` $4C;
  implement `<PAGE>` $49 incl. `BIT_PAGE_CHAR_IS_NEXT`; differentiate
  `TX_PROMPT_BUTTON` vs `TX_WAIT_BUTTON` (arrow vs none) + `LINK_STATE_BATTLING` gate;
  fold in `hClearLetterPrintingDelayFlags`.
- [x] **M1.3 — `DisplayTextID` + dispatch tree.** Port `home/text_script.asm`
  (`DisplayTextID`, `CloseTextDisplay`, `HoldTextDisplayOpen`, mart/PC/PokéCenter/
  fainted/blacked-out/repel/Pikachu-emotion dialogue) and `home/predef_text.asm`
  (`PrintPredefTextID`, `Set`/`RestoreMapTextPointer`, `TextPredefs`). Add general
  `DisplayTextBoxID` dispatcher + `FarPrintText`.

### WAVE 2 — Frame/VBlank responsibilities  ✅ DONE (2026-07-01; links, render-integrity verified static+live)

- [x] **M2.1 — Timers.** Add `dec H_FRAME_COUNTER` (guarded) to `DelayFrame`; implement
  `TrackPlayTime` (frames→s→m→h + maxed, gated on `BIT_GAME_TIMER_COUNTING`) called
  per-frame; make `CountDownIgnoreInputBitReset` global with the `$ff` re-arm and
  `hJoyPressed` clear; restore the `wDisableVBlankWYUpdate` gate in `commit_shadow_regs`.
- [x] **M2.2 — BG animation/transfer.** Implement `UpdateMovingBgTiles` (water/flower,
  gated on `hTileAnimations`) and the queued `VBlankCopyBgMap` path
  (`hVBlankCopyBG*`). Auto-BG thirds-cycling stays collapsed (document).

### WAVE 3 — Input faithfulness  ✅ DONE (2026-07-01; links, make check clean)

- [x] **M3.1 — Joypad edge/mask.** In `joypad_update` (`src/input/joypad.asm`) add
  `wJoyIgnore` masking, `hJoyReleased`, and global `BIT_DISABLE_JOYPAD` discard
  (`DiscardButtonPresses`); implement `SoftReset` + the A+B+Start+Select combo (decide
  vs the current Esc-quit).
- [x] **M3.2 — `JoypadLowSensitivity`.** Real `hJoy5/6/7` behavior: newly-pressed, 30-frame
  initial delay + ~5-frame auto-repeat, A/B-held suppression (pret `joypad2.asm:16-53`);
  wire `title.asm:456` and `town_map.asm` sites.
- [x] **M3.3 — Simulated joypad.** Generalize the door-exit hack into
  `AreInputsSimulated`/`GetSimulatedInput`/`StartSimulatingJoypadStates` with the full
  buffer/index/`wOverrideSimulatedJoypadStatesMask`, plus `RunNPCMovementScript`'s
  scripted-dispatch half + `MoveSprite`/RLE decode (`pathfinding.asm`, `map_objects.asm`).

### WAVE 4 — Menus (missing frameworks)  ✅ DONE (2026-07-01; links, make check clean, UI-projected + deduped)

- [x] **M4.1 — YES/NO framework.** `YesNoChoice`, `TwoOptionMenu`, `DisplayYesNoChoice`,
  `WideYesNoChoice`, `YesNoChoicePokeCenter`, `InitYesNoTextBoxParameters` with the
  `wTwoOptionMenuID` variants + carry=YES contract (pret `home/yes_no.asm`).
- [x] **M4.2 — Generic list menu.** `DisplayListMenuID`/`DisplayListMenuIDLoop` keyed on
  `wListMenuID` (item/PC-box/moves/priced) + `DisplayChooseQuantityMenu` priced path;
  then wire `swap_items.asm` in or delete it.
- [x] **M4.3 — Menu input fidelity.** `HandleMenuInput` wrapping (`wMenuWrappingEnabled`),
  timeout (`wMenuJoypadPollCount`), `wMenuWatchMovingOutOfBounds`; `PlaceMenuCursor`
  writes `wMenuCursorLocation`; shared `EraseMenuCursor`/`PlaceUnfilledArrowMenuCursor`;
  two-phase `HandleDownArrowBlinkTiming`.

### WAVE 5 — Pokémon / item data correctness  ✅ DONE (2026-07-01; add_mon LINKS, make check clean)

- [x] **M5.1 — `_AddPartyMon` completeness.** Add `wPokedexOwned`/`Seen` `FlagAction`; the
  in-battle wild-catch path (copy enemy DVs/HP/status + enemy stats, not fresh
  `CalcStats`); trainer fixed IVs; real `wPlayerID`→OTID. Keep offset-7 catch-rate.
- [x] **M5.2 — Party/box movement.** Resolve M0.5's duplicate symbol, then link `_MoveMon`
  + `_AddEnemyMonToPlayerParty`; implement `GetPartyMonName`/`GetPartyMonName2`; guard
  `GetMonHeader` fossil/ghost IDs.
- [x] **M5.3 — give / money.** `GiveItem`, `GivePokemon`(+`_GivePokemon`), `HasEnoughMoney`,
  `HasEnoughCoins`, `AddAmountSoldToMoney`; restore `SubtractAmountPaidFromMoney_` money-box
  redraw + replace the magic `wTextBoxID`.
- [x] **M5.4 — HM/key-item predicates.** `IsItemHM`/`IsMoveHM`/`HMMoves`; `IsItemInBag`
  (over existing `GetQuantityOfItemInBag`); factor shared `IsKeyItem_` writing `wIsKeyItem`.

### WAVE 6 — Sprites & pics  ✅ DONE (2026-07-01; links, make check clean)

- [x] **M6.1 — OAM/sprite reloaders.** `WriteOAMBlock`; `ReloadMapSpriteTilePatterns`;
  full-clear `ResetPlayerSpriteData`(+`_ClearSpriteData`); `ReloadMapData`/
  `ReloadTilesetTilePatterns` wrappers.
- [x] **M6.2 — `_UpdateSprites` branches.** Add slot-$f0 `SpawnPikachu` dispatch and
  `DoScriptedNPCMovement` (pairs with M3.3).
- [x] **M6.3 — Mon front-pic dispatch.** `UncompressMonSprite` + a generated
  `MonFrontPicPointers` table; `LoadFrontSpriteByMonIndex` (Rhydon trap via existing
  `IndexToPokedex`) + `LoadFlippedFrontSpriteByMonIndex`; retire the debug `.pic` stubs.

### WAVE 7 — Overworld gameplay systems  ✅ DONE (2026-07-01; links, make check clean; recovered from a worker git-checkout that wiped overworld.asm)

- [x] **M7.1 — Wild encounters + steps.** `StepCountCheck`, `NewBattle`,
  `AllPokemonFainted`, and the `OverworldLoop` encounter trigger (`LoadWildData`
  already exists, uncalled).
- [x] **M7.2 — Signs + hidden events.** `SignLoop` + `CopySignData` (in `LoadMapHeader`);
  `CheckForHiddenEventOrBookshelfOrCardKeyDoor` + `CheckCoords`/`ArePlayerCoordsInArray`/
  `CheckBoulderCoords` + `UpdateCinnabarGymGateTileBlocks`; `overworld_text` sign texts.
- [x] **M7.3 — Ledges + tile-pairs.** `CheckForJumpingAndTilePairCollisions`,
  `CheckForTilePairCollisions{,2}`, `HandleMidJump`; complete `CollisionCheckOnLand`
  (ledge/sim-joypad/tile-pair hooks). Verify the double `LoadScreenRelatedData` call.
- [x] **M7.4 — Warp fidelity.** `ExtraWarpCheck` function-1/2 dispatch, tileset-based
  `CheckIfInOutsideMap`, held-direction gate, `WarpFound2` bookkeeping.
- [x] **M7.5 — Player-gfx variants + bike/surf.** `LoadWalkingPlayerSpriteGraphics` family
  + `LoadPlayerSpriteGraphicsCommon`; `IsBikeRidingAllowed`, `ForceBikeOrSurf`,
  `DoBikeSpeedup`, `StopBikeSurf`.

### WAVE 8 — Trainer overworld engagement

- [ ] **M8.1 — Sight→battle wiring.** `InitBattleEnemyParameters`: store trainer class/num
  in `InitMapSprites` (currently discarded), seed `wCurOpponent`/`wTrainerClass`/
  `wTrainerNo`, call `InitBattle`; `StartTrainerBattle`/`EndTrainerBattle`.
- [ ] **M8.2 — Trainer-header engine.** `StoreTrainerHeaderPointer`, `ReadTrainerHeaderInfo`,
  `ExecuteCurMapScriptInTable` (`wCurMapScript` + override), persistent `TrainerFlagAction`
  (replace the non-persistent `npc_beaten_flags`), `GetTrainerInformation`,
  `EngageMapTrainer`, end-battle-text pointers, real `TrainerWalkUpToPlayer` + `EmotionBubble`.

### WAVE 9 — Pikachu follower

- [ ] **M9.1 — Follower FSM.** State plumbing (`Func_1510`/`Func_151d`/Enable/Disable/Check),
  `SpawnPikachu`(+`_`), movement script (`GetPikachuMovementScriptByte`,
  `ApplyPikachuMovementData`(+`_`), `Pikachu_IsInArray`).

### WAVE 10 — VRAM/util plumbing & fades

- [ ] **M10.1 — VRAM transfer family.** `CopyVideoData`, `CopyVideoDataDouble`,
  `FarCopyDataDouble`, `ClearScreenArea`, `CopyScreenTileBufferToVRAM`, `GetFarByte`
  (unblocks Town Map's five TODO sites); `IsInRestOfArray`; standalone `CopyString`;
  reconcile `FillMemory`/`CopyData` count=0 semantics + fix the false header comment.
- [ ] **M10.2 — Fades + health-bar color.** `GBFade*` family + `FadePal1..8` +
  `GBFadeInc/DecCommon` (implementable now via `commit_palette` — not color-blocked);
  `LoadGBPal` (Flash dimming); `GBPalWhiteOutWithDelay3`;
  `RestoreScreenTilesAndReloadTilePatterns`; `GetHealthBarColor` (gameplay threshold).

### Deferred bucket (documented, NOT executed now)
- **Audio HAL** — no-op stubs for `PlayMusic`/`StopAllMusic`/`PlayDefaultMusic*`/
  `UpdateMusic*`/`Init{Music,SFX}Variables`/pikachu-cries. *Do not touch now.*
- **Serial / printer HAL** — no-op stubs; no callers yet.
- **Save / SRAM** — untouched until stable.
- **Phase-5 color** — `UpdateCGBPal_*` CGB conversion, `RunPaletteCommand`/SGB dispatch.

---

## Verification
- Per member: `nasm -f coff -o /dev/null <file>`; full `make -C dos_port` (and
  `SKIP_TITLE=1`) must link with no undefined symbols (Wave 0 unblocks this).
- Behavioral ground-truth via the memory/back-buffer dumps, not screenshots:
  `DEBUG_DUMP=1` → `DUMP.BIN`; `render_frame.py FRAME.BIN` for the PPU output; the
  `DEBUG_TRANSITION`/`DEBUG_WALK_NORTH` harnesses for overworld.
- Text waves: confirm a `text_far` dialogue renders non-blank; ellipsis/pause pacing.
- Data waves: dump a caught party mon; verify Dex flags set + struct offset-7 intact.
