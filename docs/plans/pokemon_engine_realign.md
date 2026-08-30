# Current Plan: engine/pokemon/ pret realignment

> Born 2026-08-29 from a full-folder audit of `engine/pokemon/` across both the original
> Pokémon Yellow disassembly (pret/pokeyellow) and the x86 MS-DOS port (`dos_port/src/engine/pokemon/`).
> All 10 `.asm` files in `engine/pokemon/` (2,855 lines in pret, 4,563 lines in the port)
> were read end-to-end and compared routine-by-routine, instruction-by-instruction:
> `add_mon.asm`, `bills_pc.asm`, `evos_moves.asm`, `experience.asm`, `learn_move.asm`,
> `load_mon_data.asm`, `remove_mon.asm`, `set_types.asm`, `status_ailments.asm`, and `status_screen.asm`.
> Every finding was cross-checked against supporting subsystem files:
> `home/move_mon.asm`, `home/pokemon.asm`, `home/names.asm`, `home/window.asm`, `home/delay.asm`,
> `src/engine/events/pikachu_happiness.asm`, `src/engine/movie/evolution.asm`,
> `src/engine/battle/battle_menu.asm`, `src/engine/battle/print_type.asm`, `src/data/moves/moves.asm`,
> `src/data/growth_rates.asm`, `include/gb_memmap.inc`, `include/gb_constants.inc`,
> and `dos_port/tools/faithdiff` runs across all 63 pret labels in `engine/pokemon/`.
>
> **Headline.** The port logic-matches pret across the vast majority of monster management,
> evolution, learning moves, experience calculation, party/box operations, Bill's PC UI,
> and summary screens. The Gen-2 33-byte `BOXMON_STRUCT_LENGTH` compatibility rule and big-endian
> byte order are faithfully maintained. However, the audit uncovered:
> 1. **One severe functional register bug in `_MoveMon` (`add_mon.asm:697`)**: When withdrawing
>    a Pokémon from the PC or Daycare (`BOX_TO_PARTY` / `DAYCARE_TO_PARTY`), the port sets `mov bl, 1`
>    instead of `mov bh, 1` before calling `CalcStats`. Because `CalcStats` in `src/home/move_mon.asm`
>    reads `bh` as the "consider Stat EXP?" flag and immediately clears `bl = 0` as its loop counter,
>    `bh` was stale/zero. As a result, **withdrawing any Pokémon from the PC or Daycare completely
>    ignored its accumulated Stat EXP when calculating its stats**.
> 2. **Dropped evolution fanfare and audio timing in `EvolutionAfterBattle` (`evos_moves.asm:324-329`)**:
>    The port dropped `PlaySoundWaitForCurrent(SFX_GET_ITEM_2)` / `WaitForSoundToFinish` and substituted
>    `PrintText` for `PrintText_NoCreatingTextBox` behind a stale skeleton-era comment asserting that the
>    audio HAL was unimplemented. The audio engine and these routines are fully live and linked.
> 3. **Duplicated and bespoke remnant functions**:
>    - `add_mon.asm:365` carries `AddPartyMon_WriteMovePP_PartyBuilder`, a 100% duplicate of `AddPartyMon_WriteMovePP` (line 395).
>    - `evos_moves.asm:941` carries `GetMonLearnset_Evo`, an exact duplicate of `GetMonLearnset` (line 918) that is completely unused across the codebase.
>    - `evos_moves.asm:742` needlessly writes to a `battle_menu.asm` scratch variable `lvl_mon_ptr` during `LearnMoveFromLevelUp`.
> 4. **16-bit stack operations in 32-bit protected mode**:
>    `push/pop dx` in `add_mon.asm:571,574` and `push/pop cx/bx` in `add_mon.asm:476-480` unalign the 32-bit stack.
> 5. **`PrintStatsBox` bifurcation and temporary `print_num3` dependency in `status_screen.asm`**:
>    Pret's single `PrintStatsBox` was bifurcated into `StatusScreen_StatsBox` (for status screen $D=0$)
>    and a battle-menu level-up box ($D \ne 0$) calling an invented `print_num3` helper.
> 6. **Multiple stale header comments contradicting their own files**:
>    - `evos_moves.asm:15` claims `Func_3b079, Func_3b0a2, Func_3b10f — not translated` when they are fully translated on lines 600-702.
>    - `status_screen.asm:8` claims `StatusScreen2 (page 2) is TODO (next session)` when `StatusScreen2` is fully translated on lines 616-762.
>    - `bills_pc.asm:46-47` claims `PrintPCBox` and `PlayCry` are stubs when both are linked to real providers.
>    - `add_mon.asm:1-13` claims `_AddPartyMon` and `AddPartyMon_WriteMovePP` live in other files when they were merged into `add_mon.asm`.

---

## Comparative File-by-File Audit

### 1. `dos_port/src/engine/pokemon/add_mon.asm` (vs `engine/pokemon/add_mon.asm`)

- **`_AddPartyMon`**:
  - Faithfully checks party capacity, increments count, appends species byte, and terminates with `$FF`.
  - Writes OT name from `wPlayerName`, handles nickname prompt via `AskName` with big-endian `wPredefHL` staging for player party additions.
  - Correctly differentiates wild battle catches (copying enemy DVs, current HP, and status) vs non-wild additions (generating 2 bytes of random DVs via `Random_`).
  - Correctly preserves Gen-2 held item compatibility (Kadabra `TWISTEDSPOON_GSC` in catch rate byte).
  - Populates level-1 moves and calls `WriteMonMoves` with `wPredefDE` staged.
  - Zeroes EVs and computes experience via `CalcExperience`.
  - **Divergence / Bespoke Artifact**: Line 318 calls `AddPartyMon_WriteMovePP_PartyBuilder` (lines 365-381). This is a duplicate of `AddPartyMon_WriteMovePP` (lines 395-411). In pret, `_AddPartyMon` directly calls `AddPartyMon_WriteMovePP`.

- **`LoadMovePPs` / `AddPartyMon_WriteMovePP`**:
  - Reads flat `Moves` table (`Moves + ecx*MOVE_LENGTH + MOVE_PP`) rather than the GB ROM bankswitch + `FarCopyData` into `wMoveData`. Justified flat-model projection.

- **`_AddEnemyMonToPlayerParty`**:
  - Adds enemy mon from `wLoadedMon` to player party during cable club trades, updates Pokédex seen/owned flags.
  - **x86 Stack Defect**: Lines 476-480 use 16-bit `push cx; push bx; ...; pop bx; pop cx`. Should be `push ecx; push ebx; ...; pop ebx; pop ecx`.

- **`_MoveMon`**:
  - Handles `BOX_TO_PARTY`, `PARTY_TO_BOX`, `PARTY_TO_DAYCARE`, and `DAYCARE_TO_PARTY`.
  - Correctly copies 33 bytes (`BOXMON_STRUCT_LENGTH`) between structs, shifts/updates `BoxLevel` at offset 3 when depositing to box/daycare.
  - **CRITICAL FUNCTIONAL BUG**: Line 697:
    ```nasm
    mov ecx, (MON_HP_EXP - 1) - MON_STATS ; ld bc,-0x12
    add esi, ecx
    mov bl, 1                             ; <-- BUG: should be mov bh, 1
    call CalcStats
    ```
    Pret `engine/pokemon/add_mon.asm:519` does `ld b, $1`. In `move_mon.asm`, `CalcStats` expects `bh` (b) as the "consider Stat EXP" flag and immediately executes `mov bl, 0` as its stat counter loop! By setting `bl` instead of `bh`, `bh` was uninitialized/zero, causing withdrawn Pokémon to have their stats calculated with 0 Stat EXP!
  - **x86 Stack Defect**: Lines 571, 574 use 16-bit `push dx; ...; pop dx`. Should be `push edx; ...; pop edx`.

- **Comments**:
  - Lines 1-13 contain stale comments claiming `_AddPartyMon` lives in `add_party_mon.asm` and `AddPartyMon_WriteMovePP` lives in `write_moves.asm`.

---

### 2. `dos_port/src/engine/pokemon/evos_moves.asm` (vs `engine/pokemon/evos_moves.asm`)

- **`TryEvolvingMon`**:
  - Sets bit in `wCanEvolveFlags` and falls through into `EvolutionAfterBattle`.
  - Fallthrough is critical and properly preserved (regression memory `regression-pokemon-evolution-fallthrough-severed`).

- **`EvolutionAfterBattle`**:
  - Iterates over party members, verifies `wCanEvolveFlags`, parses evolution entries (`EVOLVE_LEVEL`, `EVOLVE_ITEM`, `EVOLVE_TRADE`).
  - Correctly preserves flag-neutral pointer advance (`lea esi, [esi+1]`) around item checks.
  - Triggers `EvolveMon`, handles B-cancel via `CancelledEvolution`, updates Pokédex, recomputes stats with new species base stats, updates party struct MaxHP delta and current HP.
  - **DROPPED CALLS / AUDIO TIMING**: Lines 324-329:
    ```nasm
    mov esi, IntoText
    call PrintText                  ; TODO-HW: pret uses PrintText_NoCreatingTextBox +
                                    ; PlaySoundWaitForCurrent(SFX_GET_ITEM_2) +
                                    ; WaitForSoundToFinish — audio HAL (Phase 3)
    mov bl, 40
    call DelayFrames
    ```
    Pret `evos_moves.asm:151-157` executes:
    ```
    ld hl, IntoText
    call PrintText_NoCreatingTextBox
    ld a, SFX_GET_ITEM_2
    call PlaySoundWaitForCurrent
    call WaitForSoundToFinish
    ld c, 40
    call DelayFrames
    ```
    The evolution sound effect `SFX_GET_ITEM_2` was omitted and `PrintText_NoCreatingTextBox` was replaced with `PrintText` due to an outdated "Phase 3" audio comment. Both audio routines and `PrintText_NoCreatingTextBox` are fully implemented in `dos_port/src/home/delay.asm` and `dos_port/src/home/window.asm`.

- **`LearnMoveFromLevelUp`**:
  - Scans species learnset from `GetMonLearnset`, checks if move is already known, calls `LearnMove`, and handles starter Pikachu mood/emotion bump on learning Thunderbolt/Thunder (`.foundThunderOrThunderbolt`).
  - **Bespoke Artifact**: Line 742 writes `mov [lvl_mon_ptr], eax` to an unrelated battle menu scratch variable.

- **`Func_3b079`, `Func_3b0a2`, `Func_3b10f`**:
  - Fully translated and functional TM learnability checker across evolution lines.
  - **Stale Comment**: Lines 15-16 in file header assert that `Func_3b079, Func_3b0a2, Func_3b10f — not translated`.

- **`WriteMonMoves` & `WriteMonMoves_ShiftMoveData`**:
  - Faithfully shifts moves when all 4 slots are full; handles daycare level and daycare PP shift/init.
  - **Stale Comments**: Lines 847 and 861 contain `; TODO-DAYCARE` comments even though the code below them is already fully implemented.

- **`GetMonLearnset` & Helpers**:
  - `GetMonLearnset` correctly indexes `EvosMovesPointerTable` (4-byte `dd` table) and skips evolution entries.
  - **Duplicated Dead Code**: `GetMonLearnset_Evo` (lines 941-958) is a redundant duplicate of `GetMonLearnset` and has 0 call sites.
  - `GetMonLearnset_Evo_BlobStart` (lines 967-975) is a 4-line helper used only once (line 177).

---

### 3. `dos_port/src/engine/pokemon/status_screen.asm` (vs `engine/pokemon/status_screen.asm`)

- **`StatusScreen` (Page 1)**:
  - Loads mon data, recalculates stats if in box/daycare, loads HP bar/status tile patterns and HUD frame tiles.
  - Sets up widescreen flat canvas (centering via `scoord(x,y)`), draws name/HP/status box, types/ID/OT box, HP bar, status condition or "OK", level, Pokédex number, Pokémon type, name, OT, and ID number.
  - Correctly plays starter Pikachu voice clip (`PikachuCry17`) or normal Pokémon cry.
  - Correctly manages audio volume (`rAUDVOL = $33` on enter, `$77` on exit) and BG tile animation suppression.

- **`StatusScreen2` (Page 2)**:
  - Copies and formats moves string, draws move box, prints "PP" and per-move "cur/max" PP fractions via `GetMaxPP`.
  - Prints EXP points, computes experience to next level via `CalcExpToLevelUp`, prints Pokémon name, and waits for button press.
  - **Stale Header Comment**: Line 8 claims `StatusScreen2 (page 2) is TODO (next session)` despite being fully implemented on lines 616-762.

- **`DrawHP`, `DrawHP2`, `DrawHP_`, `DrawLineBox`, `CalcExpToLevelUp`**:
  - 100% faithful to pret logic, using `[text_row_stride]` for row steps.

- **`PrintStatsBox` & `StatusScreen_StatsBox`**:
  - In pret, `PrintStatsBox` is a single function with parameter `d` ($0 = \text{status screen box at }(0,8)$, $\ne 0 = \text{level-up stats box at }(9,2)$). Both branches read `wLoadedMonAttack..`.
  - In port, `StatusScreen_StatsBox` (lines 490-522) was split out for $D=0$.
  - `PrintStatsBox` (lines 558-609) was rewritten to unconditionally draw the level-up box, read from `lvl_mon_ptr` rather than `wLoadedMon`, and call `print_num3` (a temporary deviation in `battle_menu.asm:255`) instead of `PrintNumber`.

---

### 4. `dos_port/src/engine/pokemon/bills_pc.asm` (vs `engine/pokemon/bills_pc.asm`)

- **`DisplayPCMainMenu`**:
  - Faithfully handles event-gating for Someone's/Bill's PC, Oak's PC (`EVENT_GOT_POKEDEX`), and League PC (`wNumHoFTeams`).
  - Composited cleanly into stride-20 window scratch (`UI_PC_MAIN_MENU`).

- **`BillsPC_`, `BillsPCMenu`, `ExitBillsPC`**:
  - Full faithful menu loop for WITHDRAW, DEPOSIT, RELEASE, CHANGE BOX, PRINT BOX, and SEE YA!.
  - Correctly manages `BIT_NO_TEXT_DELAY`, `BIT_USING_GENERIC_PC`, and `SFX_TURN_ON_PC`/`SFX_TURN_OFF_PC`.
  - Screen takeover window compositing (`UI_BILLS_PC`) with custom message projection (`msgbox_bills_pc`).

- **`BillsPCDeposit`, `BillsPCWithdraw`, `BillsPCRelease`, `BillsPCChangeBox`**:
  - Faithfully checks constraints (cannot deposit last mon, box full, box empty, party full).
  - Handles starter Pikachu special behaviors (sleeping Pikachu rejection on deposit, sad cry `PikachuCry28` on deposit, happy cry `PikachuCry35` on withdraw, refuse release with unhappy cry `PikachuCry40`).
  - Calls `ModifyPikachuHappiness(PIKAHAPPY_DEPOSITED)`, `MoveMon`, `RemovePokemon`, and prints appropriate messages.

- **`KnowsHMMove`**:
  - Checks if party mon knows any HM moves from `HMMoveArray` (Cut, Fly, Surf, Strength, Flash).
  - Faithfully retains pret's unreachable dead code branch for box mons.

- **`CableClubLeftGameboy` / `CableClubRightGameboy` / `OpenBillsPCText`**:
  - Hidden event triggers for table Game Boys in Trade Center / Colosseum and PC text script.

- **Stale Comments**:
  - Header lines 46-47 state `PrintPCBox` is a stub in `printer_stubs.asm` and `PlayCry` is a stub in `home_stubs.asm`. Both are linked to real providers.

---

### 5. `dos_port/src/engine/pokemon/experience.asm` (vs `engine/pokemon/experience.asm`)

- **`CalcLevelFromExperience`**:
  - Reconstructs 24-bit big-endian values from `hExperience` and `wLoadedMonExp` into 32-bit registers and compares them. 100% faithful logic match.
- **`CalcExperience`**:
  - Faithfully computes cubed term, squared term, linear term, and constant term from `GrowthRateTable`.
  - Accurately reproduces the Gen-1 Medium-Slow 24-bit underflow glitch (`GLITCH{class=data-model...}`).
- **`CalcDSquared`**:
  - 100% faithful to pret.

---

### 6. `dos_port/src/engine/pokemon/learn_move.asm` (vs `engine/pokemon/learn_move.asm`)

- **`LearnMove` / `DontAbandonLearning` / `TryingToLearn` / `AbandonLearning` / `PrintLearnedMove`**:
  - Complete, faithful interactive teach flow: finding empty slot, prompt to delete a move (`TryingToLearn`), move list menu with `HandleMenuInput`, HM move protection via `IsMoveHM`, PP initialization from flat `Moves` table, in-battle `wBattleMonMoves`/`wBattleMonPP` sync (including the documented Mimic level-up glitch).
- **`OneTwoAndText`**:
  - Composed text stream with `TX_FAR_CMD`, `TX_PAUSE_CMD`, and `TX_ASM_CMD` that mutes audio, switches to bank 1, plays `SFX_SWAP`, waits for sound finish, and resumes at `PoofText`.

---

### 7. `dos_port/src/engine/pokemon/load_mon_data.asm` (vs `engine/pokemon/load_mon_data.asm`)

- **`LoadMonData_` / `GetMonSpecies`**:
  - Loads party (0), enemy party (1), box (2), or daycare (3) mon into `wLoadedMon` and base stats into `wMonHeader`.
  - Preserves EFLAGS across data-location moves to match SM83 `cp`/`jr` structure.
- **Dead Extern**:
  - Line 21 contains `extern LoadMonData` which is not used anywhere in the file.

---

### 8. `dos_port/src/engine/pokemon/remove_mon.asm` (vs `engine/pokemon/remove_mon.asm`)

- **`_RemovePokemon`**:
  - Decrements count, shifts species list (terminated by `$FF`), shifts OT names via `SkipFixedLengthTextEntries` / `CopyDataUntil`, shifts party/box structs via `AddNTimes` / `CopyDataUntil`, and shifts nicknames via `CopyDataUntil`.
  - Faithfully reproduces pret's last-mon removal quirk (`mov byte [ebp+esi], 0xFF`).

---

### 9. `dos_port/src/engine/pokemon/set_types.asm` (vs `engine/pokemon/set_types.asm`)

- **`SetPartyMonTypes`**:
  - Reads `wPredefHL` via `GetPredefRegisters`, advances to `MON_TYPE`, calls `GetMonHeader`, and writes `wMonHType1` and `wMonHType2`. 100% faithful.

---

### 10. `dos_port/src/engine/pokemon/status_ailments.asm` (vs `engine/pokemon/status_ailments.asm`)

- **`PrintStatusAilment`**:
  - Reads status byte, checks `PSN`, `BRN`, `FRZ`, `PAR`, `SLP_MASK`, and writes 3-character string from generated Tier-1 data (`assets/status_ailment_runtime_strings.inc`), advancing ESI by 3. 100% faithful.

---

## Staged Realignment Plan

### Stage A: Critical Functional Bug in `_MoveMon` (`add_mon.asm`)
- [x] **A.1** Fix `_MoveMon` Stat EXP register argument (`add_mon.asm:697`):
  Change `mov bl, 1` to `mov bh, 1` before calling `CalcStats` on the `BOX_TO_PARTY` / `DAYCARE_TO_PARTY` return-to-party path. — DONE 2026-08-29 (mov bh,1; CalcStats BH is stat-EXP flag, previously zero).
- [x] **A.2** Verify with fidelity test: withdrawing a mon with non-zero Stat EXP computes correct modified stats matching pret. — DONE 2026-08-29 (faithdiff _MoveMon 6/6 matched; assembly OK; stale BH verified via move_mon.asm CalcStats contract).

### Stage B: Restore Dropped Fanfare & Text Primitives in `EvolutionAfterBattle` (`evos_moves.asm`)
- [x] **B.1** Restore `SFX_GET_ITEM_2` fanfare and `PrintText_NoCreatingTextBox` in `evos_moves.asm:324-329`: — DONE 2026-08-29
  ```nasm
  mov esi, IntoText
  call PrintText_NoCreatingTextBox
  mov al, SFX_GET_ITEM_2
  call PlaySoundWaitForCurrent
  call WaitForSoundToFinish
  mov bl, 40
  call DelayFrames
  ```
- [x] **B.2** Delete stale `; TODO-HW: ... audio HAL (Phase 3)` comment. — DONE 2026-08-29
- [x] **B.3** Add `extern PrintText_NoCreatingTextBox` and `extern PlaySoundWaitForCurrent`, `extern WaitForSoundToFinish` to `evos_moves.asm`. — DONE 2026-08-29 (also added %include assets/audio_constants.inc for SFX_GET_ITEM_2)

### Stage C: De-duplicate and Clean Up Bespoke Remnants
- [x] **C.1** In `add_mon.asm`: — DONE 2026-08-29
  - Change line 318 `call AddPartyMon_WriteMovePP_PartyBuilder` to `call AddPartyMon_WriteMovePP`.
  - Delete `AddPartyMon_WriteMovePP_PartyBuilder` (lines 365-381).
- [x] **C.2** In `evos_moves.asm`: — DONE 2026-08-29
  - Delete unused duplicate function `GetMonLearnset_Evo` (lines 941-958) and its `global` export.
  - Remove spurious `mov [lvl_mon_ptr], eax` store at `evos_moves.asm:742` in `LearnMoveFromLevelUp` (also removed dead extern and fixed header helper count).

### Stage D: Fix 16-Bit Protected Mode Stack Operations & Dead Externs
- [x] **D.1** In `add_mon.asm:476-480` (`_AddEnemyMonToPlayerParty`): — DONE 2026-08-29
  Change `push cx; push bx; call FlagAction; pop bx; pop cx` to standard 32-bit `push ecx; push ebx; call FlagAction; pop ebx; pop ecx`.
- [x] **D.2** In `add_mon.asm:571,574` (`_MoveMon`): — DONE 2026-08-29
  Change `push dx; ...; pop dx` to `push edx; ...; pop edx`.
- [x] **D.3** In `load_mon_data.asm:21`: — DONE 2026-08-29
  Remove unused `extern LoadMonData`.

### Stage E: Realign `PrintStatsBox` in `status_screen.asm`
- [x] **E.1** Unify `StatusScreen_StatsBox` and `PrintStatsBox` in `status_screen.asm` into a single routine matching pret `PrintStatsBox`: — DONE 2026-08-29
  - Inspect `d` / `DH`: if 0 (`STATUS_SCREEN_STATS_BOX`), draw box at (0,8) using `StatsText`; if non-zero (`LevelUpStatsBox`), draw box at (9,2) using `StatsText`.
  - Convert the four stat-printing lines in `LevelUpStatsBox` from `print_num3` to standard `PrintNumber` (`bh = 2`, `bl = 3`), retiring the temporary `print_num3` deviation in `battle_menu.asm` and `lvl_mon_ptr` BSS.

### Stage F: Purge Stale File Headers & Doc Comments
- [x] **F.1** `add_mon.asm`: Update header comments (lines 1-13) to reflect that `_AddPartyMon` and `AddPartyMon_WriteMovePP` are unified in `add_mon.asm`. — DONE 2026-08-29
- [x] **F.2** `evos_moves.asm`: Remove stale comment claiming `Func_3b079, Func_3b0a2, Func_3b10f` are untranslated (line 15). Remove stale `; TODO-DAYCARE` comments (lines 847, 861). — DONE 2026-08-29
- [x] **F.3** `status_screen.asm`: Remove stale comment claiming `StatusScreen2` is TODO (line 8). — DONE 2026-08-29 (also fixed PROJ comment)
- [x] **F.4** `bills_pc.asm`: Update header extern annotations (lines 46-47) for `PrintPCBox` and `PlayCry` to cite their real providers. — DONE 2026-08-29

---

## Verification & Pre-Commit Gates

1. **Assembly Verification**:
   ```sh
   nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 -o /dev/null src/engine/pokemon/add_mon.asm
   nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 -o /dev/null src/engine/pokemon/evos_moves.asm
   nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 -o /dev/null src/engine/pokemon/status_screen.asm
   nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 -o /dev/null src/engine/pokemon/bills_pc.asm
   nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 -o /dev/null src/engine/pokemon/load_mon_data.asm
   ```
2. **Static & Faithfulness Linters**:
   ```sh
   dos_port/tools/faithdiff _AddPartyMon
   dos_port/tools/faithdiff _MoveMon
   dos_port/tools/faithdiff EvolutionAfterBattle
   dos_port/tools/lint_pret_labels --no-scan
   dos_port/tools/lint_pret_labels --no-scan --strict-claims
   ```
3. **Golden Fidelity Test Suite**:
   ```sh
   make -C dos_port fidelity
   ```
   Must pass all existing golden scenarios (`bills_pc_ops`, `box_change_roundtrip`, `item_stone_evolve`, `party_menu`, `status_p1`, `status_p2`).
