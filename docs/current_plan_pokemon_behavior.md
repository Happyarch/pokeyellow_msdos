# Current Plan: engine/pokemon behavior/UI — faithful pret mirror

The behavior/UI layer above the (complete) Pokémon data/stats engine: evolution,
level-up move learning, the status/summary screen, and Bill's PC. Faithfully
translate the remaining `engine/pokemon/` routines from pret against the port's
existing text/menu/gfx/sound infra, fix two known defects, retire the obsolete
draft, and wire everything into the linked build + its battle/START-menu callers.

Sequenced **after** `current_plan_pokemon_engine.md` (data layer, done) and the
battle frontend (`current_plan_battle_pret_alignment.md`); it fixes bugs those
surfaced (garbage level-up stats, silently-dropped level-up moves).

## Session / resume guidance
- **BRANCH: this work lives on `menus-port`** (shared with a concurrent menus /
  `ui_layout` agent — see `docs/current_plan_menus.md`). This plan touches
  `src/engine/pokemon/*` + shared includes; the menus agent touches
  `dos_port/tools/ui_layout/` + `dos_port/Makefile`. Per CLAUDE.md "Commit Policy":
  commit only your own explicit paths (`git add <files>`, never `add -A`/`commit -a`),
  and leave the menus agent's uncommitted `ui_layout`/Makefile changes alone — ask
  the user before touching anything you didn't author this session.
- **Each stage is written to be picked up cold in a fresh session.** Read this file
  + `CLAUDE.md` first. Mark stages `[x]` here as they land; archive to
  `docs/plans/pokemon_behavior.md` when fully done.
- **Stages are NOT strictly sequential.** Stage 0 (cleanup) is a prereq for all.
  Stage 1 routines are independent and can each be done standalone. Stages 2/3/4 can
  overlap (different files) but share Stage-0 symbol promotions. Short independent
  bits (e.g. a single Stage-1 routine + the Stage-0 fix it needs) may be batched in
  one session. Stage 5 (integration) needs 2+3+4 landed; Stage 6 (PC UI) is separable
  and may become its own plan.
- **Audit every draft against pret before wiring** — prior drafts have been
  unreliable (see the pokemon_engine plan's lessons). Validate headlessly (ELF
  harness) + `ld -r` link closure before `make`.

## Scope decisions (confirmed with user 2026-07-01)
- **Battle/menu paths first; Bill's PC full UI is the final separable Stage 6.**
- **EvolveMon: functional-now** (data-correct evolve + pic swap + both cries +
  B-cancel), with a marked sub-stage **2b** for the full palette-flash morph.

## Reuse — already exists in the port (do NOT rebuild)
- Text/menu: `PrintText_Overworld`/`PrintText_NoBox` (`src/text/text.asm`), bare
  battle `PrintText` (`src/engine/battle/move_effect_helpers.asm`),
  `DisplayTextID`/`DisplayTextBoxID` (`src/home/text_script.asm`),
  `YesNoChoice`/`TwoOptionMenu` (`src/home/yes_no.asm`), `HandleMenuInput`
  (`src/home/window.asm`), `DisplayListMenuID` (`src/home/list_menu.asm`),
  `PlaceString`/`TextBoxBorder` (`src/text/text.asm`).
- Data/helpers: `FlagAction`/`FlagActionPredef` (`src/engine/flag_action.asm`),
  `AddNTimes`/`SkipFixedLengthTextEntries` (`src/home/array.asm`),
  `CopyData`/`CopyDataUntil` (`src/home/copy_data.asm`), `GetName`
  (`src/home/names.asm`), `LoadMonData_` (`load_mon_data.asm`), `CalcStats`
  (`src/home/move_mon.asm`), `CalcExperience`/`CalcLevelFromExperience`
  (`experience.asm`), `GetPredefRegisters` (`src/home/predef.asm`).
- Gfx/sound: pic loading incl. `LoadFlippedFrontSpriteByMonIndex` (`src/gfx/pics.asm`),
  `PlayCry`/pikachu clip helpers, party-menu HP-bar + status + animated-icon
  rendering (`src/engine/menus/party_menu.asm`).
- Battle: `GainExperience` (`src/engine/battle/experience.asm`, linked) already runs
  the in-battle level-up path and *calls* `LearnMoveFromLevelUp` + `PrintStatsBox`
  as deferred stubs — the hook points already exist.

---

## Stage 0 — Cleanup & symbol alignment (prereq for all) — [x]
<!-- Done 2026-07-01: evos_moves.asm git rm'd (no external caller of its unique
     Evolution_FlagAction/Func_3b079/3b0a2/3b10f; GetMonLearnset/WriteMonMoves/
     _ShiftMoveData already provided by the wired write_moves.asm). evolution.asm's
     %ifndef self-aliases deleted; promoted (sym-verified vs origin/symbols) into
     gb_memmap.inc (wLoadedMonHP/HPExp/MaxHP/Stats, wEvolutionOccurred, wPikachuMood,
     wPikachuEmotionModifier — the rest already existed) and gb_constants.inc
     (LINK_STATE_TRADING, THUNDER_STONE, THUNDERBOLT, THUNDER; MAX_LEVEL already at 100).
     status_screen.asm: added `bits 32`, include gb_constants.inc (MAX_LEVEL now a
     constant, not extern → fixes the imm8 COFF reloc), dropped extern wLoadedMonLevel
     (from gb_memmap.inc). Verified: `make check` (all sources) + clean `make` link. -->

- **Retire `evos_moves.asm`.** Duplicates `write_moves.asm`'s
  `GetMonLearnset`/`WriteMonMoves`/`WriteMonMoves_ShiftMoveData` (with the
  ×2/16-bit-pointer bug the wired copy already fixed), plus `sbc al,bh` (invalid x86 →
  `sbb`), wrong repo-root `%include`, missing `bits 32`, undefined `LearnMove`.
  `evolution.asm` + `write_moves.asm` supersede it. `git rm` it (in no Makefile var);
  move unique bits (`Evolution_FlagAction`; debug `Func_3b0a2/3b10f/3b079`) into
  `evolution.asm` only if a caller needs them.
- **Promote `evolution.asm`'s `%ifndef` self-aliases** (~lines 55–146:
  `wEvolutionOccurred`, `wMoveNum`, `wPikachuMood`, `wPikachuEmotionModifier`,
  `wLoadedMon{HP,HPExp,Level,MaxHP,Stats}`, `LINK_STATE_TRADING`, `THUNDER_STONE`,
  `THUNDERBOLT`, `THUNDER`) into `include/gb_memmap.inc`/`gb_constants.inc`,
  sym-verified vs `origin/symbols:pokeyellow.sym` + `constants/`; delete the in-file
  blocks.
- **Fix `status_screen.asm` COFF failure:** `MAX_LEVEL` is `extern` used as
  `cmp al, MAX_LEVEL` (imm8) → NASM COFF can't emit an 8-bit reloc. Add
  `MAX_LEVEL equ 100` to `gb_constants.inc`, drop the `extern`, add `bits 32`.

## Stage 1 — Pure-logic (A) routines: port + wire — [x]
<!-- Done 2026-07-01. All three routines linked into PKMN.EXE (added to POKEMON_SRCS)
     and validated headlessly (ELF trampoline harness, 15/15 pass: all 5 statuses +
     healthy + PSN>SLP priority; FNT-on-faint / ailment-when-alive / blank-when-healthy;
     KnowsHMMove found-first / not-found / found-last). Full `make` link closure holds.
     - PrintStatusAilment: filled the empty src/engine/pokemon/status_ailments.asm
       (was a skip-stub) with the faithful bit-test version (put_str3 mirrors pret's
       ld_hli_a_string: ESI += 2, AL = last tile; ZF set iff no status). The shared
       PrintStatusCondition / PrintStatusConditionNotFainted wrapper went into
       src/home/pokemon.asm (pret home-bank placement; tail-jmp to PrintStatusAilment).
       party_menu.asm's inline .print_status was LEFT ALONE (working screen; a concurrent
       menus agent owns that file) — the shared routine is for the Stage 4 StatusScreen.
       Added wLoadedMonStatus ($CF9B, sym-verified) to gb_memmap.inc as its natural input.
     - CalcExpToLevelUp: Stage 0 already fixed the COFF/bits issue; now wired into the
       link (status_screen.asm → POKEMON_SRCS). Its live caller is Stage 4 StatusScreen.
     - KnowsHMMove: split out (+ HMMoveArray) into new src/engine/pokemon/knows_hm_move.asm
       so it LINKS independently of bills_pc.asm's still-blocked _MoveMon closure (bills_pc
       stays check-only). Daycare-script caller not wired: no port daycare script exists yet
       (script engine WIP) — the global is ready for it. -->
Independent, low-risk, each standalone-linkable + ELF-testable.
- **`PrintStatusAilment`** (pret `home/pokemon.asm`) — 3-letter status abbrev via bit
  tests, no external calls. Port faithfully; extract a shared `PrintStatusCondition`
  wrapper matching pret rather than duplicating `party_menu.asm`'s inline status text.
- **`CalcExpToLevelUp`** — already in `status_screen.asm`; fix (Stage 0) + wire.
- **`KnowsHMMove`** (in `bills_pc.asm`) — pure `IsInArray` over `HMMoveArray`, deps
  exist. Split out so it links independently of the (blocked) PC UI; wire its
  daycare-script caller.

## Stage 2 — Evolution decision core: fix, wire, functional EvolveMon — [ ]
- **Fix `EvolutionAfterBattle` stack bug** (`evolution.asm:473–491`): success path
  does `pop edx` (cursor, ok) then `pop esi` which wrongly eats the routine-level
  saved DE. Rewrite pret-faithfully — pop the one per-iteration species cursor,
  `[hl]=wLoadedMonSpecies`, push it back. Re-validate the party loop headlessly.
- **Wire `evolution.asm` into `LINK_SRCS`** (from `POKEMON_CHECK_SRCS`). Externs
  resolve (`GetName`, `FlagActionPredef`, `LoadMonData_`, `CalcStats`,
  `SetPartyMonTypes`, `IsThisPartyMonStarterPikachu`); promote any check-only dep
  (e.g. `names.asm`) into the link as needed.
- **`EvolveMon` functional:** replace the always-succeed stub with data-correct evolve
  + `PlayCry` (old/new) + evolve text (`PrintText`) + `JoypadLowSensitivity` B-cancel,
  via `pics.asm`/`PlayCry`. **[2b]** later: full palette-flash back-and-forth morph
  (faithful `engine/movie/evolution.asm` against the software PPU/palette).
- Fill the small deferred text/tileset stubs in `EvolutionAfterBattle`/
  `CancelledEvolution` against the real helpers.

## Stage 3 — `learn_move.asm`: interactive teach flow (new port) — [ ]
Faithfully translate pret `engine/pokemon/learn_move.asm` → new
`src/engine/pokemon/learn_move.asm`:
- `LearnMove`, `DontAbandonLearning`, `AbandonLearning`, `TryingToLearn`
  ("1, 2 and… which move to forget?"), `PrintLearnedMove`, `OneTwoAndText`.
- Reuse `PrintText`, `DisplayTextBoxID` (yes/no), `HandleMenuInput`,
  `TextBoxBorder`/`PlaceString`, `FormatMovesString`, `IsMoveHM`, screen
  save/restore buffers.
- Keep the **battle hook**: learning mid-battle copies new move/PP into
  `wBattleMonMoves`/`wBattleMonPP` (pret `learn_move.asm:56–74`).
- Replace `evolution.asm`'s `LearnMove_Deferred` no-op with `extern LearnMove`.
- **Wire `LearnMoveFromLevelUp`** into `GainExperience` (`experience.asm:497` stub →
  real call) and the Rare Candy item path.

## Stage 4 — `status_screen.asm`: the summary screen — [ ]
Translate the drawing routines (currently absent — the file holds only
`CalcExpToLevelUp`):
- `StatusScreen` (pg1: name/level/HP/status/types/ID/OT/pic/cry), `StatusScreen2`
  (pg2: moves/PP/EXP/exp-to-next), `DrawHP`/`DrawHP2`/`DrawHP_`, `PrintStatsBox`,
  `DrawLineBox`, `StatusScreen_ClearName`/`_PrintPP`.
- Reuse `LoadMonData`, `CalcStats`, `PlaceString`/`TextBoxBorder`, `PrintNumber`,
  `LoadFlippedFrontSpriteByMonIndex`, `PlayCry`, HP-bar-length + status helpers
  shared with `party_menu.asm`.
- Register `StatusScreen`/`StatusScreen2`/`DrawHP*`/`PrintStatsBox` predef targets.
  **Wire two callers:** START-menu party **STATS** (`start_sub_menus`) and the
  **battle level-up** `PrintStatsBox` callfar (`experience.asm`) — the latter fixes
  the garbage-stats display flagged in `current_plan_battle_pret_alignment.md`.

## Stage 5 — Post-battle & integration verification — [ ]
- Wire `EvolutionAfterBattle` as the `end_of_battle` predef (`wForceEvolution`
  post-battle), per pret `engine/battle/end_of_battle.asm`.
- End-to-end: win → EXP → level-up learns a move (S3) → post-battle evolution (S2) →
  status screen reflects new species/moves/stats (S4).

## Stage 6 — Bill's PC full UI (separable; may become its own plan) — [ ]
- Extract a **link-ready `_MoveMon`** from `add_mon.asm` (resolve the duplicate
  `AddPartyMon_WriteMovePP` symbol + extern-constant errors) so `bills_pc.asm` +
  `_MoveMon`/`_RemovePokemon` link.
- Port the PC menu path faithfully: `DisplayPCMainMenu`, `BillsPC_`, `BillsPCMenu`,
  `BillsPCDeposit`/`Withdraw`/`Release`, `BillsPCChangeBox` (needs `ChangeBox` from
  `engine/menus/save.asm`), `DisplayMonListMenu`, `DisplayDepositWithdrawMenu` (its
  STATS branch reuses Stage 4's `StatusScreen`).
- Wire overworld PC callers (`pc.asm`, map-object interaction).

---

## Critical files
- Retire: `dos_port/src/engine/pokemon/evos_moves.asm`
- Fix + wire: `dos_port/src/engine/pokemon/evolution.asm`, `status_screen.asm`,
  `bills_pc.asm`
- New: `dos_port/src/engine/pokemon/learn_move.asm`; `PrintStatusAilment` (new
  `status_ailments.asm` or fold into `src/home/pokemon.asm` per pret's home-bank
  placement)
- Shared decls: `dos_port/include/gb_memmap.inc`, `include/gb_constants.inc`
- Build/wiring: `dos_port/Makefile` (`LINK_SRCS`/`POKEMON_CHECK_SRCS`), predef table,
  `src/engine/battle/experience.asm`, `src/engine/battle/end_of_battle.*`,
  `src/engine/menus/start_sub_menus.asm`

## Conventions (per CLAUDE.md)
- Keep pret labels; add lowercase aliases to the `.inc` rather than renaming. `;
  TODO-HW:` at any `$FF__` I/O boundary; `; BUG(level):`/`; GLITCH:` where pret has
  known bugs. Flat program-image tables read `[label]`/`[esi]`; EBP-relative GB
  memory `[ebp+addr]`. Data vs. code two-tier rule: generators only touch
  `assets/*.inc`, never `.asm`.

## Verification
- **Per routine (headless):** `nasm -f coff` each file; for logic routines the ELF
  harness (`ld -m elf_i386`, `ebp`→64 KB buffer, compare to canonical Gen-1 values) —
  covers post-stack-fix `EvolutionAfterBattle`, `LearnMoveFromLevelUp`,
  `PrintStatusAilment`, `KnowsHMMove`.
- **Link closure:** `ld -r` partial link → zero unresolved externals after each
  wiring step; then full `make -C dos_port`.
- **Live (DOSBox-X, only supported target):**
  - Status screen: START → POKéMON → STATS; `FRAME.BIN` → `tools/render_frame.py`,
    verify name/level/HP-bar/types/moves/PP/EXP.
  - Level-up learn + stats box: drive a battle to a level-up (battle-alignment
    harness); confirm real "learned MOVE!" + correct stats.
  - Post-battle evolution: seed a party mon one level below evolution, win, confirm
    species/name/types/moves update (`DUMP.BIN` of party struct).
- Prefer `DUMP.BIN`/`FRAME.BIN` over screenshots for ground truth (CLAUDE.md).
