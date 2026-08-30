# Current Plan: engine/battle/ Subsystem pret Realignment (excluding core.asm)

> Born 2026-08-29 from an exhaustive, full-file audit of the entire `engine/battle/` subsystem outside `core.asm`.
> Every `.asm` file in pret `engine/battle/` (and subdirectories like `move_effects/`) was read end-to-end
> and compared routine-by-routine, line-by-line against its port counterpart under `dos_port/src/engine/battle/`.
> This encompasses **40 `.asm` files** across the repository (14 `move_effects/` files, 21 standalone battle files,
> and 5 port-only battle helper/stub files).
>
> **Headline.** The battle subsystem outside `core.asm` is in a remarkably faithful state following multiple
> porting and swarm waves (Stage 1 through Stage 9, 2026-06 to 2026-08). The algorithmic core across move effects,
> EXP distribution, stat modifications, wild encounter triggers, and AI decision trees logic-matches pret with
> high precision, preserving Gen-1 quirks and bug behaviors under `%if BUG_FIX_LEVEL >= 2`.
> However, the audit identified:
> 1. **Instruction & Register Nuances**: `conversion.asm` performing 16-bit `bt ax` without masking AH, and `scale_sprites.asm` utilizing 16-bit arithmetic (`dec si`, `sub dx, 4`, `add si, bx`) in 32-bit protected mode.
> 2. **Local Constant Redundancy**: `get_trainer_name.asm` defining `RIVAL1` and `RIVAL2` locally rather than using `gb_constants.inc`.
> 3. **Extensive Comment Staleness & Contradictions**: Many files (`read_trainer_party.asm`, `safari_zone.asm`, `ghost_marowak_anim.asm`, `end_of_battle.asm`, `display_effectiveness.asm`) contain obsolete header warnings claiming routines or data are "uncalled", "unported", "missing", or "deferred", long after the respective providers and callers landed.
> 4. **Collapsed / Inline Routines**: `_InitBattleCommon` in `init_battle.asm` collapsing pret's `StartBattle` trampoline; `draw_hud_pokeball_gfx.asm` keeping `SetupPlayerAndEnemyPokeballs` stubbed in `battle_stubs.asm` pending widescreen OAM coordinate decisions for link versus mode.

---

## Files Audited (40 Total)

### 1. Move Effects (`engine/battle/move_effects/` vs `dos_port/src/engine/battle/move_effects/`)
1. `conversion.asm`
2. `drain_hp.asm`
3. `focus_energy.asm`
4. `haze.asm`
5. `heal.asm`
6. `leech_seed.asm`
7. `mist.asm`
8. `one_hit_ko.asm`
9. `paralyze.asm`
10. `pay_day.asm`
11. `recoil.asm`
12. `reflect_light_screen.asm`
13. `substitute.asm`
14. `transform.asm`

### 2. Battle Core Initialization & Trainers (`engine/battle/` vs `dos_port/src/engine/battle/`)
15. `init_battle.asm`
16. `init_battle_variables.asm`
17. `get_trainer_name.asm`
18. `save_trainer_name.asm`
19. `read_trainer_party.asm`
20. `trainer_ai.asm`

### 3. Mechanics, Stats, PP, Effectiveness, Experience & End of Battle
21. `wild_encounters.asm`
22. `safari_zone.asm`
23. `effects.asm`
24. `decrement_pp.asm`
25. `display_effectiveness.asm`
26. `used_move_text.asm`
27. `common_text.asm`
28. `print_type.asm`
29. `unused_stats_functions.asm`
30. `experience.asm`
31. `end_of_battle.asm`
32. `misc.asm`
33. `link_battle_versus_text.asm`

### 4. HUD, Animations, Graphics & Transitions
34. `draw_hud_pokeball_gfx.asm`
35. `ghost_marowak_anim.asm`
36. `pikachu_entrance_anim.asm`
37. `scale_sprites.asm`
38. `scroll_draw_trainer_pic.asm`
39. `battle_transitions.asm`
40. `animations.asm`

### 5. Port-Only Helpers & Stubs
- `dos_port/src/engine/battle/battle_menu.asm`
- `dos_port/src/engine/battle/pokeballs.asm`
- `dos_port/src/engine/battle/battle_stubs.asm`
- `dos_port/src/engine/battle/battle_exp_stubs.asm`
- `dos_port/src/engine/battle/core_stubs.asm`

---

## Scope & Acceptance Rules

1. **Faithful Logic Preservation**: Keep the functional SM83 logic intact, including Gen-1 quirks and bug guards (`%if BUG_FIX_LEVEL >= 2`).
2. **Flat Model Boundaries**: Bankswitching (`Bankswitch`), banked predefs (`predef`), and ROM far calls are translated directly into flat x86 calls with register arguments.
3. **Screen Projections**: Overworld and battle coordinate mappings (`BCOORD`, `PLAYER_STANDING_TILE`, `UI_*` equates) are retained as permanent projection deviations.
4. **Data vs Code (Two-tier rule)**: Text strings remain generated Tier-1 assets (`assets/battle_text.inc`, `assets/used_move_text.inc`). Human-authored code never hand-encodes charmap text.
5. **No Regressions**: All static gate checks, label linters, and golden scenarios must pass cleanly without introducing unsuppressed divergences.

---

## Gate & Verification Rules

For every commit executing this plan:
1. `nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 -o /dev/null <file>` per touched file.
2. `dos_port/tools/faithdiff <Label>` for each modified pret label.
3. `dos_port/tools/lint_pret_labels --no-scan` and `--no-scan --strict-claims`.
4. `make -C dos_port fidelity` for core regression verification.
5. Search stigmergy memories before editing (`memory_search battle`).

---

## Detailed Findings Ledger

### Stage A: Code Nuances & Minor Instruction Fixes

- [x] **A.1 (`conversion.asm`) Clean up bit-test on `INVULNERABLE`** — DONE 2026-08-30: `bt ax, INVULNERABLE / jc` → `test al, 1<<INVULNERABLE / jnz` (commit: conversion.asm:28).
  - *Location*: `dos_port/src/engine/battle/move_effects/conversion.asm:37`
  - *Issue*: `bt ax, INVULNERABLE` uses `ax` where `al` was loaded from `[ebp + wPlayerBattleStatus1]`. Although bit index 0 (`INVULNERABLE`) is safely within `al`, using 16-bit register `ax` when `ah` is uninitialized is sloppy.
  - *Fix*: Replace `bt ax, INVULNERABLE` with `test al, 1 << INVULNERABLE` or explicit 8-bit `bt eax, INVULNERABLE`.

- [x] **A.2 (`scale_sprites.asm`) Modernize 16-bit arithmetic to 32-bit registers** — DONE 2026-08-30: `dec dx→dec edx`, `sub dx,4→sub edx,4`, `dec si→dec esi`, `add si,bx→movsx ebx,bx + add esi,ebx` (scale_sprites.asm).
  - *Location*: `dos_port/src/engine/battle/scale_sprites.asm:65, 72, 75, 86, 92, 105, 107`
  - *Issue*: Routine uses `dec dx`, `sub dx, 4`, `add si, bx`, `dec si`, emitting 16-bit operand size override prefixes (0x66) in 32-bit protected mode.
  - *Fix*: Change pointer updates to 32-bit operations (`dec edx`, `sub edx, 4`, `dec esi`, `movsx ebx, bx` + `add esi, ebx`).

- [x] **A.3 (`get_trainer_name.asm`) Remove redundant local equates** — DONE 2026-08-30: added `RIVAL1 0x19`/`RIVAL2 0x2A` to `gb_constants.inc`, removed locals in `get_trainer_name.asm`.
  - *Location*: `dos_port/src/engine/battle/get_trainer_name.asm:24-25`
  - *Issue*: `RIVAL1 equ 0x19` and `RIVAL2 equ 0x2A` are defined locally, while `gb_constants.inc` already defines standard rival constants (`OPP_RIVAL1`, `RIVAL3`, etc.).
  - *Fix*: Clean up redundant local equates and ensure standard constants from `gb_constants.inc` are referenced.

---

### Stage B: Structural Realignment & Collapsed Functions

- [x] **B.1 (`init_battle.asm`) Evaluate `StartBattle` entry point** — DONE 2026-08-30: verified `StartBattle` already `translated` in `dos_port/src/engine/battle/core.asm` (label_status) and `_InitBattleCommon`/`InitBattleCommon` both `translated`; no alias needed — the plan's reported `missing` was stale (resolved 2026-08-29).
  - *Location*: `engine/battle/init_battle.asm:StartBattle` vs `dos_port/src/engine/battle/init_battle.asm:_InitBattleCommon`
  - *Issue*: In pret, `StartBattle` is a distinct label preceding `_InitBattleCommon` (`callfar PlayBattleMusic`, `callfar ClearVram`, `callfar InitBattleVariables`). In the port, `StartBattle` was merged into `_InitBattleCommon` and is reported as `missing` in `translation.db`.
  - *Fix*: Add `global StartBattle` alias pointing to the start of `_InitBattleCommon` to satisfy pret label tracking.

- [x] **B.2 (`draw_hud_pokeball_gfx.asm` & `battle_stubs.asm`) Link-battle pokeball versus row** — DONE 2026-08-30: confirmed `STUB{class=stub}` annotation in `battle_stubs.asm:59` already documents the widescreen coordinate deferral; no code change required, keep as structured STUB until Phase 4.
  - *Location*: `dos_port/src/engine/battle/battle_stubs.asm:39-63` (`SetupPlayerAndEnemyPokeballs`)
  - *Issue*: `SetupPlayerAndEnemyPokeballs` remains a `STUB` in `battle_stubs.asm` because GB-native coordinates ($50/$40 and $50/$68) have not been given an explicit widescreen canvas layout.
  - *Resolution*: Keep documented as a structured `STUB{class=stub}` until widescreen link cable presentation is authored in Phase 4.

---

### Stage C: Stale & Misleading Comment Remediation

- [x] **C.1 (`read_trainer_party.asm`) Obsolete ungenerated data / stub warnings** — DONE 2026-08-30: rewrote header to record that `TrainerDataPointers`/`SpecialTrainerMoves` are generated in `assets/trainer_parties.inc` via `src/data/trainer_data.asm` and `AddBCD` is a direct flat call.
  - *Location*: `dos_port/src/engine/battle/read_trainer_party.asm:11-25`
  - *Issue*: Header comment asserts that `TrainerDataPointers`, `SpecialTrainerMoves`, and `AddBCDPredef` are missing or stubbed no-ops. In reality, `TrainerDataPointers` and `SpecialTrainerMoves` are generated and linked in `assets/trainer_parties.inc`, and `AddBCD` is called directly at line 251.
  - *Fix*: Rewrite header comment to reflect the true linked state.

- [x] **C.2 (`safari_zone.asm`) Stale uncalled claim** — DONE 2026-08-30: header now cites `init_battle.asm` Safari loop as live caller of `PrintSafariZoneBattleText`.
  - *Location*: `dos_port/src/engine/battle/safari_zone.asm:19-22`
  - *Issue*: Header comment states "nothing calls this yet. Its caller is the Safari turn flow... UNWITNESSED by any scenario". In reality, `init_battle.asm:602` explicitly calls `PrintSafariZoneBattleText`.
  - *Fix*: Update header comment to cite `init_battle.asm` as a live caller.

- [x] **C.3 (`ghost_marowak_anim.asm`) Stale uncalled claim** — DONE 2026-08-30: header now cites `common_text.asm` as live caller of `MarowakAnim`.
  - *Location*: `dos_port/src/engine/battle/ghost_marowak_anim.asm:12-16`
  - *Issue*: Header comment claims "nothing calls MarowakAnim yet". In reality, `common_text.asm:376` calls `call MarowakAnim`.
  - *Fix*: Update header comment to acknowledge the caller in `common_text.asm`.

- [x] **C.4 (`end_of_battle.asm`) Stale deferred link-battle notes** — DONE 2026-08-30: header now notes link-battle presentation is IMPLEMENTED (DisplayLinkBattleVersusTextBox + palette + strings) with gating being two-instance runtime, not deferred code.
  - *Location*: `dos_port/src/engine/battle/end_of_battle.asm:15-16`
  - *Issue*: Header claims link-battle presentation is deferred, but lines 63-107 fully implement `DisplayLinkBattleVersusTextBox`, palette setting, result string placing, and delay.
  - *Fix*: Reconcile header comments with the implemented link-battle presentation.

- [x] **C.5 (`display_effectiveness.asm`) Contradictory Tier-2 text claim** — DONE 2026-08-30: clarified that strings are Tier-1 generated (`assets/effectiveness_runtime_strings.inc`).
  - *Location*: `dos_port/src/engine/battle/display_effectiveness.asm:21-24`
  - *Issue*: Header claims text strings are "hand-authored text streams (Tier-2 code; not in generated battle_text.inc)", which contradicts the project two-tier rule. In reality, it includes `assets/effectiveness_runtime_strings.inc`.
  - *Fix*: Clarify that the text definitions are generated asset includes.

- [x] **C.6 (`battle_exp_stubs.asm`) Obsolete stub inventory** — DONE 2026-08-30: retired per-stub comments, replaced with empty placeholder note; file retained as linked placeholder per Makefile LINK_SRCS.
  - *Location*: `dos_port/src/engine/battle/battle_exp_stubs.asm:1-41`
  - *Issue*: The entire file contains only comments noting that all stubs have been retired into real files.
  - *Fix*: Retain or cleanly deprecate the file in accordance with Makefile build lists.

---

## Verified Faithful Ledger (Subsystem Audit)

The following routines and implementations across all 40 audited files were verified against pret instruction-by-instruction and proven logic-identical:

1. **Move Effects**:
   - `DrainHPEffect_`: Big-endian HP damage division, `DREAM_EATER_EFFECT` vs `DRAIN_HP_EFFECT` checks, and `UpdateCurMonHPBar` projections.
   - `FocusEnergyEffect_`: `DelayFrames` (BL=50) for failure delay; faithfully sets status2 bit.
   - `HazeEffect_`: `CureVolatileStatuses`, `ResetStatMods` (preserves AL=7), `ResetStats`.
   - `HealEffect_`: `REST` vs `Recover/Softboiled` latching mechanism (`isRestStash` in BSS). Gen-1 modulo 255 HP deficit bug under `BUG_FIX_LEVEL < 2`.
   - `LeechSeedEffect_`: `MoveHitTest`, `GRASS` typing checks, `SEEDED` status bit.
   - `MistEffect_`: `PROTECTED_BY_MIST` bit test/set and `PrintButItFailedText_`.
   - `OneHitKOEffect_`: 16-bit speed compare and carry preservation across `sub` / `sbb`.
   - `ParalyzeEffect_`: `ELECTRIC` vs `GROUND` immunity via pointer math, `MoveHitTest`, `QuarterSpeedDueToParalysis`.
   - `PayDayEffect_`: `Divide` input convention (BH=4) and `AddBCD` convention (ESI=src, EDX=dst, CL=count).
   - `RecoilEffect_`: 25% vs 50% (`STRUGGLE`) recoil damage math and negative HP clamp to 0.
   - `ReflectLightScreenEffect_`: `HAS_LIGHT_SCREEN_UP` and `HAS_REFLECT_UP` setting and `EffectCallBattleCore` (`jmp esi`).
   - `SubstituteEffect_`: `maxHP/4` subtraction, Gen-1 self-KO bug at exact HP = maxHP/4 under `BUG_FIX_LEVEL < 2`, `AnimationSubstitute` dispatch.
   - `TransformEffect_`: Gen-1 `INVULNERABLE` bugs #1 & #2 under `BUG_FIX_LEVEL < 2`, species/type/catch-rate/moves/DVs/stats copying and 5 PP setting.

2. **Battle Initialization & Trainers**:
   - `InitBattle`: Full canvas setup (`InitBattleCanvas`), stores overworld view pointer and letter delay in memory (`saved_ow_view_ptr`, `saved_letter_printing_delay`) instead of stack push/pop across battle, and keeps `DrawBattleIntroBox` (a port helper).
   - `InitBattleVariables`: `wMiscBattleData` block wipe, `wTestBattlePlayerSelectedMove = POUND`, `wCurMap` Safari Zone range check, and `PlayBattleMusic` tail jump.
   - `SaveTrainerName`: `TrainerNamePointers` stride-4 indexing and `wNameBuffer` copy until `@` (0x50).
   - `ReadTrainerParty`: Flat-level vs special-level parsing, `AddPartyMon`, `SpecialTrainerMoves` overrides, and prize money calculation via `AddBCD`.
   - `TrainerAI`: Move choice scoring, `AIMoveChoiceModification1..4`, `TrainerAI`, `TrainerAIPointers`, per-trainer AI routines, `DecrementAICount`, `AICheckIfHPBelowFraction`, `AICureStatus`, `AIPlayRestoringSFX`, `AIPrintItemUse_`, `AIPrintItemUseAndUpdateHPBar`, `AIUsePotion..`, `AISwitchIfEnoughMons` (using `dec cl` for 8-bit counter bounds), `SwitchEnemyMon`, `AIIncreaseStat`, and `AIUseGuardSpec`.

3. **Mechanics, Stats, PP, Effectiveness, Experience & End of Battle**:
   - `TryDoWildEncounter`: Uses projected `PLAYER_STANDING_TILE` (`wTileMap + 17*40 + 24`), correctly checks map indoor status and Repel logic.
   - `PrintSafariZoneBattleText`: Backward pointer walk `dec esi` to `wSafariEscapeFactor`, zero-crossing detection, species header catch rate restore.
   - `JumpMoveEffect` / `_JumpMoveEffect`: Dispatch table `MoveEffectPointerTable` (dd pointers) and handlers in `effects.asm`.
   - `DecrementPP`: Multi-turn move exemption list, `STRUGGLE` check, transformed party mon bypass, `AddNTimes` stride in BX.
   - `DisplayEffectiveness`: Multiplier masking (`and al, 0x7F`) and `EFFECTIVE` compare.
   - `DisplayUsedMoveText`: Text command processor (`TX_FAR` + `TX_START_ASM`), `GetMoveGrammar` table scan.
   - `RetreatMon` / `PlayerMon2Text` / `PrintSendOutMonMessage`: Big-endian HP difference percentage calculation and message selector chains in `common_text.asm`.
   - `PrintBeginningBattleText`: Pokémon Tower / Silph Scope checks, Pikachu cry sound clip selection, battle pokeball display, trainer SFX playback.
   - `PrintMonType` / `PrintMoveType` / `EraseType2Text`: Flat 32-bit `WideTypeNames`, direct calling convention without predef table.
   - `DoubleSelectedStats` / `HalveSelectedStats`: Big-endian low/high byte carry propagation in `unused_stats_functions.asm`.
   - `GainExperience`: Stat EXP accumulation (0xFFFF cap), boosted EXP (trade/trainer), 3-byte add, level-up stats recalculation, `CallBattleCore` via `call esi`.
   - `EndOfBattle`: Pay Day money award via `AddBCD`, post-battle evolution trigger, battle WRAM block reset, font-loaded bit clearing.
   - `FormatMovesString` / `InitList`: Accurate move name copying, dash filling with `0xE3`, 16-bit pointer storage in WRAM.
   - `DisplayLinkBattleVersusTextBox`: `BCOORD` projection, text border drawing, bold "VS" tile placing.

4. **HUD, Animations, Graphics & Transitions**:
   - `draw_hud_pokeball_gfx.asm`: Projected coordinates (`UI_PLAYER_BALLS_OAM_X/Y`, `UI_ENEMY_BALLS_OAM_X/Y`), HUD shelf underline generation.
   - `ghost_marowak_anim.asm`: OBP1 palette shifting, sprite VRAM copy, flashing sprite animation, Marowak fade-in.
   - `pikachu_entrance_anim.asm`: Column sliding with `BCOORD(0, 5)` projection and 7x7 back pic tile index arithmetic.
   - `scroll_draw_trainer_pic.asm`: Trainer pic column sliding with `BCOORD(19, 0)` projection.
   - `battle_transitions.asm`: Full 40x25 widescreen transition engine (DoubleCircle, Spiral, Circle, HorizontalStripes, Shrink, VerticalStripes, Split).
   - `animations.asm`: Complete move animation interpreter (~3344 lines) with command streams, subanimations, frame blocks, and sound triggers.
   - `battle_menu.asm`: Draw-layer helpers (`DrawBattleMenuBox`, `DrawEmptyDialogBox`, `ShowSimulatedInputBagBox`, `EndBattleScreen`).
   - `pokeballs.asm`: Port-only OAM HAL (`DrawBattlePokeballs`, `HideBattlePokeballs`).

---

## Plan Status Summary

- **Total Routines Audited**: 120+ top-level routines across 40 `.asm` files.
- **Critical Logic Mismatches**: 0 (all core algorithms verified faithful).
- **Code Fixes Needed**: 3 minor instruction/equate cleanups (Stage A).
- **Comment Fixes Needed**: 6 documentation/provenance updates (Stage C).
- **Stubs Remaining**: 1 (`SetupPlayerAndEnemyPokeballs`, documented and justified in `battle_stubs.asm`).
