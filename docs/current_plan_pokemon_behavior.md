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
- **WORKTREE (start here): this work moved to its own git worktree + branch on
  2026-07-02 to avoid Makefile collisions with the concurrent menus agent.**
  - **Start Claude in:** `.claude/worktrees/pokemon-behavior/dos_port`
  - **Branch:** `pokemon-behavior` (based off `menus-port` HEAD `95643886`; Stage 1
    committed as `e3dc0b1c`). The menus / `ui_layout` agent stays on `menus-port`.
  - **Seeded artifacts:** the gitignored generated files (`dos_port/assets/*.inc`,
    `*.2bpp/.pic/.1bpp`) are copied in and already built, so `make` works
    immediately. If a `git checkout`/pull ever makes `make` try to *regenerate*
    assets (and fail on a Python module), `touch` the seeded artifacts so they're
    newer than the freshly-checked-out generator scripts.
  - It's a real worktree: shares `.git` + the stash stack with the main checkout —
    the CLAUDE.md multi-agent git cautions still apply.
  - **To land:** merge `pokemon-behavior` → `menus-port` (or wherever) when ready;
    separate branches let the Makefile merge section-by-section without clobbering
    the menus agent's edits.
- This plan touches `src/engine/pokemon/*` + shared includes; the menus agent
  touches `dos_port/tools/ui_layout/` + `dos_port/Makefile` (on its own branch).
  Per CLAUDE.md "Commit Policy": commit only your own explicit paths
  (`git add <files>`, never `add -A`/`commit -a`).
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

## Stage 2 — Evolution decision core: fix, wire, functional EvolveMon — [x] (LINKED)

<!-- ===================== STAGE 2 STATUS (updated 2026-07-02) =====================
NOW LINKED. evolution.asm + pikachu_status.asm are in POKEMON_SRCS; full `make`
and `make check` are green. Summary of the two work sessions:

SESSION B (unblock + link):
- Ported engine/pikachu/pikachu_status.asm faithfully to
  src/engine/pikachu/pikachu_status.asm (5 predicates: IsStarterPikachuAliveInOurParty,
  IsThisBoxMon/IsThisPartyMonStarterPikachu, UpdatePikachuMoodAfterBattle,
  CheckPikachuStatusCondition). It now `%include`s gb_memmap/gb_constants (was
  `extern` on WRAM/const symbols → non-assembling), loads pointer regs 32-bit
  (avoids stale-high-bit bugs the draft had), and uses `ld b`=BH for the JP-name
  counter. Fixed a SM83→x86 flag bug both name-compare loops had: `inc esi` after
  `cmp` clobbers ZF → replaced with `lea esi,[esi+1]`. Both routines validated
  headlessly (ELF harness, AddNTimes stubbed): IsThisPartyMon 4/4 cases,
  IsStarterPikachuAlive 3/3 (incl. fainted + wrong-OT).
- Resolved a duplicate-symbol collision: battle_menu.asm already ships the
  canonical, UI-complete LearnMoveFromLevelUp (learned-move box + PP + in-battle
  sync) that experience.asm calls. evolution.asm now `extern`s it (dropped its
  redundant copy + the global). Added pret's starter-Pikachu THUNDER/THUNDERBOLT
  wPikachuEmotionModifier/wPikachuMood bump to that canonical routine (it had
  omitted it) — this also gives pikachu_status a real linked caller.
- Added to includes: gb_constants STARTER_PIKACHU=84, NAME_LENGTH_JP=6; gb_memmap
  wPartyMon1HP=0xD16B, wPartyMon1OTID=0xD176, wPartyMon2=0xD196, wBoxMon1=0xDA95,
  wBoxMon2=0xDAB6 (all sym-verified vs origin/symbols).
- Makefile: moved evolution.asm + pikachu_status.asm into POKEMON_SRCS
  (POKEMON_CHECK_SRCS now just bills_pc.asm).
- Deferred still: [2b] evolution palette/pic morph + audio (Phase 3 HAL); an
  end-to-end EvolutionAfterBattle species/stats harness (fix proven by static trace).

SESSION A (code) — nasm clean, full `make` links, battle_text.inc regenerated:
- (1) STACK FIX in evolution.asm .doEvolution: added the [C] blob-cursor re-push
  BEFORE `call GetName` (port GetName clobbers ESI, unlike pret). Success-path tail
  `pop edx`([C] blob)/`pop esi`([G] party cursor) now matches pret 231-232. Verified
  by a full static push/pop trace (entry 5 pushes; [party]/[B]/[C]/[D]/[E]/[F] +
  inner eax/ebx pairs all balance; success AND cancel paths return to `.done`).
- (2) EvolveMon FUNCTIONAL: pret movie/evolution.asm structure — 3-reg preserve,
  DelayFrames(80), `lb bc,1,16` 8-pass loop, LIVE Evolution_CheckForCancel
  (DelayFrame + JoypadLowSensitivity + [ebp+H_JOY5]&PAD_B, honoring wForceEvolution)
  and wEvoCancelled->CF. Audio = TODO-HW (Phase 3); palette flash + pic load +
  Evolution_BackAndForthAnim morph = [2b] deferred no-op stubs.
- (3) EVOLUTION TEXT: added "engine/pokemon/evos_moves.asm" to gen_battle_text.py
  BATTLE_SRC, regenerated battle_text.inc (IsEvolving/Evolved/Into/StoppedEvolving;
  120 labels). Wired PrintText into .doEvolution + CancelledEvolution.
  gb_memmap.inc: added wEvoMonTileOffset=0xCEEB, wEvoCancelled=0xCEEC.

- (4) WIRED into LINK_SRCS (done in Session B — see above; was blocked on
  pikachu_status.asm, now ported + linked).
The original investigation handoff (fully superseded) follows.
================================================================================ -->

<!-- ========================= STAGE 2 HANDOFF (2026-07-02) =========================
STATE: investigation complete; exactly ONE edit applied so far. All the design
decisions and concrete facts below are verified — the next session should be able
to finish mechanically without re-deriving anything. Work in the WORKTREE
(.claude/worktrees/pokemon-behavior/dos_port), branch `pokemon-behavior`.

WHAT'S DONE:
- `src/engine/pokemon/evolution.asm`: added an extern block right after
  `extern IsThisPartyMonStarterPikachu` (PrintText, GetPartyMonName,
  CopyToStringBuffer, ClearScreenArea, ClearSprites, ClearScreen, DelayFrames,
  DelayFrame, JoypadLowSensitivity, + the 4 text labels IsEvolvingText /
  EvolvedText / IntoText / StoppedEvolvingText). File still assembles clean
  (`nasm -f coff` exit 0 — unused externs are allowed), so this is a safe
  partial state. NOTHING ELSE has been changed (no .doEvolution rewrite, no
  EvolveMon rewrite, no CancelledEvolution text, no generator/Makefile/include
  edits). evolution.asm is STILL in POKEMON_CHECK_SRCS.

STILL TODO (4 sub-tasks; ordered by confidence):

(1) STACK-BUG FIX — highest confidence, ~1 line. ROOT CAUSE: the bug is a MISSING
    re-push of the blob cursor, NOT a bad pop. pret (evos_moves.asm) pushes the
    blob cursor at .doEvolution start [A] (line 115), pops it after EvolveMon [A']
    (line 140), reads the new species, then RE-PUSHES it [B] (line 150); the final
    `pop de`(=[B] blob) / `pop hl`(=[G] species-list cursor) at pret 231-232 then
    align. The dos_port already has the correct final sequence at evolution.asm
    ~395-401 (`pop edx`=blob, `pop esi`=species-list, write, push esi, `mov esi,edx`)
    — it was just never given the [B] push, so `pop edx` grabbed [G] and `pop esi`
    ate the routine-entry saved DE. FIX = add ONE `push esi` right after reading
    the new species (`pop esi`/read at ~257-261), while ESI still holds the blob
    cursor. CAUTION: the port's GetName CLOBBERS ESI (unlike pret's GetName which
    preserves HL), so the [B] push MUST go BEFORE the `call GetName`, not after it
    (functionally identical to pret). No other change to 395-401 is needed.

(2) EvolveMon FUNCTIONAL (2a) — replace the always-CF-clear stub. IMPORTANT: audio
    does NOT exist in the port — `PlayCry`/SFX/music are Phase-3 TODO-HW boundaries
    (see faint_switch.asm), so 2a is: port pret movie/evolution.asm EvolveMon
    STRUCTURE with (a) reg preservation as pret, (b) audio calls as `; TODO-HW:
    audio HAL (Phase 3)`, (c) palette + pic-load + back-and-forth morph as marked
    `[2b]` deferred stubs, (d) a LIVE cancel loop. Port `Evolution_CheckForCancel`
    faithfully (pret 138-156): `call DelayFrame` / `call JoypadLowSensitivity` /
    read `[ebp+H_JOY5]` / `and al,PAD_B` / on B: honor `wForceEvolution` (can't
    cancel when set) → set CF; else loop `dec c`. Keep the outer loop shell
    (`lb bc,1,16`; 8 iters; inc b, dec c twice) calling Evolution_CheckForCancel;
    make `Evolution_BackAndForthAnim` a `[2b]` no-op `ret` stub. Return CF from
    `wEvoCancelled`. Externs needed (all resolvable): JoypadLowSensitivity (linked),
    DelayFrame/DelayFrames (frame.asm, linked). Consts: PAD_B (=2, exists). WRAM:
    H_JOY5 (0xFFB5, exists as H_JOY5 — JoypadLowSensitivity writes it),
    wForceEvolution (0xCCD4, exists), wEvoCancelled (0xCEEC — MUST ADD, see #4).

(3) TEXT STUBS — text data is GENERATED into assets/battle_text.inc by
    tools/gen_battle_text.py (Tier-1 rule: don't hand-edit the .inc). The 4
    evolution wrappers live in pret engine/pokemon/evos_moves.asm:303-317
    (text_far → _EvolvedText/_IntoText/_StoppedEvolvingText in data/text/text_4.asm,
    _IsEvolvingText in text_5.asm). TO ADD: append "engine/pokemon/evos_moves.asm"
    to the generator's BATTLE_SRC list, run `make -C dos_port assets`, confirm the
    4 `global`+label pairs land in battle_text.inc. THEN wire PrintText into
    .doEvolution faithfully (pret 118-159): GetPartyMonName(AL=[wWhichPokemon],
    ESI=wPartyMonNicks→EDX=wNameBuffer) + CopyToStringBuffer(EDX→wStringBuffer) +
    `mov esi,IsEvolvingText`/`call PrintText` + `mov bl,50`/DelayFrames +
    ClearScreenArea(ESI=W_TILEMAP, BH=12, BL=20) + ClearSprites → EvolveMon →
    PrintText(EvolvedText) → [A'] pop/read species → GetName → [B] push (see #1) →
    PrintText(IntoText) [`; TODO-HW: pret uses PrintText_NoCreatingTextBox +
    PlaySoundWaitForCurrent(SFX_GET_ITEM_2)+WaitForSoundToFinish — not ported`] +
    `mov bl,40`/DelayFrames + ClearScreen + RenameEvolvedMon → fall into the
    existing (untouched) IndexToPokedex/data block at ~267. CancelledEvolution:
    add `mov esi,StoppedEvolvingText`/`call PrintText` + `call ClearScreen` before
    its `pop esi`/jmp. Signatures verified: DelayFrames takes BL (not CX);
    ClearScreenArea ESI/BH/BL; ClearScreen/ClearSprites no args; W_TILEMAP=0xC3A0.
    GetName's MONSTER_NAME path ignores wPredefBank (pret: "bank not used for
    monster names") → skip setting it. LEAVE DEFERRED (not linked / nonexistent):
    Evolution_ReloadTilesetTilePatterns (reload_tiles.asm is HOME_CHECK-only),
    PrintText_NoCreatingTextBox, PlaySound*/PlayDefaultMusic. All other helpers
    used are already in LINK_SRCS (GetPartyMonName=home/pokemon; CopyToStringBuffer=
    battle/core; ClearScreenArea=home/copy2; ClearSprites=gfx/sprites;
    ClearScreen=movie/title; DelayFrames=video/frame; PrintText=move_effect_helpers).

(4) WIRE into LINK_SRCS — move evolution.asm from POKEMON_CHECK_SRCS to POKEMON_SRCS
    AND add pikachu_status.asm to POKEMON_SRCS (it's currently in NO Makefile var;
    it's the only unresolved extern for evolution: IsThisPartyMonStarterPikachu).
    pikachu_status closure is tiny: only `call AddNTimes` (linked) + WRAM + 3
    consts; VERIFIED none of its 5 globals collide with any linked file. Its
    IsStarterPikachuAliveInOurParty has a latent negative-word-offset quirk
    (wPartyMon1HP-wPartyMon1OTID = -11) but evolution only calls
    IsThisPartyMonStarterPikachu (positive offsets, fine) — DON'T touch
    pikachu_status logic; another session owns that file.
    ADD to include/gb_memmap.inc (sym-verified vs origin/symbols:pokeyellow.sym):
      wPartyMon1HP=0xD16B, wPartyMon1OTID=0xD176, wPartyMon2=0xD196,
      wBoxMon1=0xDA95, wBoxMon2=0xDAB6, wEvoCancelled=0xCEEC.
    ADD to include/gb_constants.inc: STARTER_PIKACHU equ 84 ($54 = PIKACHU internal
      index, matches debug_party.asm's %define), NAME_LENGTH_JP equ 6.
      (NAME_LENGTH=11, MONSTER_NAME=1, PAD_B already exist.)
    VERIFY: `nasm -f coff` each changed file; `ld -r` closure = zero unresolved;
    then full `make -C dos_port` (and `make -C dos_port SKIP_TITLE=1`). Commit only
    your own paths (evolution.asm, pikachu_status wiring in Makefile, includes,
    generator, regenerated battle_text.inc) — never `git add -A`.

HEADLESS VALIDATION: the ELF trampoline harness (see Stage 1 notes / verification
section) can drive the stack-fixed EvolutionAfterBattle party loop with PrintText/
GetPartyMonName/etc. STUBBED, seeding a mon 1 level below its evo and asserting the
party struct's species/stats update. This is the ground-truth test for the fix.
================================================================================ -->

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

## Stage 3 — `learn_move.asm`: interactive teach flow (new port) — [x] (fully linked, including the interactive forget-list flow)
<!-- Done 2026-07-02. Landed in the pokemon-behavior worktree, branch pokemon-behavior.

SCOPE CORRECTION vs. the original bullets below (found during investigation, not
assumed): `LearnMoveFromLevelUp` was already a REAL, LINKED routine in
battle_menu.asm (experience.asm:497's "DEFERRED stub" comment was stale) — the
actual gap was that its inline free-slot scan `jmp .restore`d silently, with NO
message, whenever all 4 move slots were full. That's the "silently-dropped
level-up moves" bug this stage fixes. `evolution.asm`'s `LearnMove_Deferred` was
only a header comment, no symbol — nothing to replace there. `RareCandyLevelUp`
(item_effects.asm) has no caller at all yet (UseItem_ dispatch is deferred per
current_plan_items.md) — nothing to wire on that path today.

**Revision (same session)**: the first pass hand-rolled a collapsed stand-in for
`TryingToLearn`/`AbandonLearning` (always silently "gave up") to avoid depending
on the separate menus-port branch's `engine/menus` work. User feedback: don't
avoid the dependency by hand-rolling around it — call the real pret functions
under their real names (`DisplayTextBoxID`, `HandleMenuInput`, `IsMoveHM`,
`TextBoxBorder`, `PlaceString`, `FormatMovesString`, `GetMoveName`) and let
integration provide the missing one for real later. Investigation found that,
in *this* worktree, every one of those is already real and linked (`HandleMenuInput`
in `window.asm`, `IsMoveHM` in `item_predicates.asm`, `TextBoxBorder`/`PlaceString`
in `text.asm`, `FormatMovesString` in `core_stubs.asm`, `GetMoveName` in
`names.asm`) — `DisplayTextBoxID` (pret home/textbox.asm) is the sole exception,
still check-only in `text_script.asm` (the actual menus-port territory).

DONE:
- `src/engine/pokemon/learn_move.asm` (linked, POKEMON_SRCS) is now a full,
  structure-for-structure translation of pret's file: `LearnMove` →
  `DontAbandonLearning` (find-empty-slot / write-move / write-PP-from-the-flat-
  `Moves`-table / in-battle `wBattleMonMoves`/`wBattleMonPP` sync) → `TryingToLearn`
  (real "delete a move?" YES/NO, then the real move-to-forget list: `HandleMenuInput`-
  driven cursor, `IsMoveHM` rejection + retry loop, B-to-cancel) → `AbandonLearning`
  (real "give up?" YES/NO; NO loops back to `DontAbandonLearning` to pick again) →
  `PrintLearnedMove`. `hlcoord`/`lb bc` translate to this port's established
  `W_TILEMAP + Y*SCREEN_WIDTH + X` / `BH,BL` idiom (matches bag_menu.asm/
  party_menu.asm). The double-spaced-menu toggle uses this port's own
  `menu_item_step` convention (window.asm), not a `hUILayoutFlags` bit — pret has
  no such variable, but the port's `HandleMenuInput` already establishes this as
  the real mechanism.
- `src/engine/pokemon/learn_move_stubs.asm` (new, linked): a *minimal* link-time
  stub for `DisplayTextBoxID` only — mirrors the existing
  `src/engine/battle/core_stubs.asm` precedent for the same "faithful caller,
  deferred backend" situation. Alternates NO/YES-give-up across calls (a fixed
  constant would loop forever, since both prompts share the same box params and
  only a real player normally breaks that loop). Header documents exactly when to
  delete it: once a real, linked `DisplayTextBoxID` lands.
- One real gap remains, and is *not* silently worked around: `OneTwoAndText` (the
  "X forgot Y and..." message printed when a move is actually deleted) cannot be
  generated at all — its pret source chains `text_far` → `text_pause` → `text_asm`,
  and the `text_asm` block is literal GB machine code spliced into the text stream
  (bank-switch, play SFX_SWAP, then continue printing at a different label). This
  is the *same*, already-acknowledged `TX_START_ASM` limit `src/text/text.asm`'s
  `TextCommandProcessor` documents for several other battle labels (`GainedText`,
  `MonsStatsRoseText`, ...). `DontAbandonLearning` still does the real `GetMoveName`
  call so `wNameBuffer` holds the right name, but the `PrintText` step is skipped
  with a `TODO-HW`-style marker instead of calling a symbol that cannot exist.
- `tools/gen_battle_text.py` fix (real bug, not scoped to this stage but found and
  fixed because Stage 3 now actually executes the affected labels):
  `collect_wrappers` stopped scanning a wrapper's body immediately after a
  `text_far` line, silently dropping any trailing directives (`text_promptbutton`,
  `sound_get_item_1`, the wrapper's own `text_end`). Verified against
  `src/text/text.asm`'s own `TX_FAR` handler (`.cmd_far`/`.done`) that this is a
  real, reachable recursive call-and-return, not dead code — so those trailing
  bytes are genuinely part of the stream. Fixed: continue scanning past `text_far`
  (still stopping for the pre-existing `text_far`+`text_asm` grammar-branch case);
  added `sound_get_item_1`/`sound_level_up` (`$0B`) to the tolerated-directive map.
  Regenerated `assets/battle_text.inc`: 128 of 129 previous labels gained a
  strictly-additive trailing-byte fix (verified byte-for-byte prefix-preserving
  across all of them — no existing content changed); `OneTwoAndText` now correctly
  fails to generate (previously it silently emitted wrong/truncated bytes with no
  warning) and is grouped with the other already-known `TX_START_ASM` skips.
- `battle_menu.asm`'s `LearnMoveFromLevelUp`: replaced the inline free-slot-scan/
  write/PP/sync/`ShowLearnedMoveText` block with `GetMoveName`+`CopyToStringBuffer`
  (name → wStringBuffer, matching the port's established idiom) + `call LearnMove`,
  keeping the learnset-scan/already-known-check and the starter-Pikachu
  THUNDER/THUNDERBOLT mood bump. Deleted the now-dead `ShowLearnedMoveText`/
  `learned_move_id`/`str_learned`.

VERIFIED:
- Two headless ELF i386 harnesses, 28/28 checks total, direct-memory assertions
  (stubbing `DisplayTextBoxID`/`HandleMenuInput`/`IsMoveHM` with scripted,
  call-order-exact response queues + call counters — real `CopyData`/`AddNTimes`
  linked in, not stubbed):
  - Harness 1 (13 checks): common empty-slot write, slot/PP correctness,
    non-target slots untouched, in-battle `wBattleMonMoves`/`wBattleMonPP` sync,
    full-slots-declined-then-given-up leaves the move array byte-for-byte
    unchanged + returns "not learned".
  - Harness 2 (15 checks, new — covers the paths only reachable once
    `TryingToLearn`/`AbandonLearning` became real): accept + pick a non-HM slot
    (correct write/PP, other slots untouched); accept + HM-move-picked → retry →
    cancel → `AbandonLearning` give-up (`HandleMenuInput` called exactly twice,
    `IsMoveHM` exactly once, no corruption); decline the first prompt outright
    (list never shown, `HandleMenuInput` never called); decline → "don't give up"
    at `AbandonLearning`'s own prompt → loops back to `DontAbandonLearning` →
    retries → accepts → succeeds (proves the retry-loop control flow, not just
    the terminal outcomes).
  - **Bug found by harness 2, fixed**: `TryingToLearn`'s forget-list loop clobbered
    `EAX` (`HandleMenuInput`'s returned key mask, needed for the `PAD_B`-cancel
    test) with the `menu_item_step` single-spaced-restore load *before* testing
    it — pret's equivalent (`res BIT_DOUBLE_SPACED_MENU, [hl]`) is a memory-only
    op that never touches `A`; the x86 translation needs a different scratch
    register (`ECX`). Symptom before the fix: an unbounded retry loop (confirmed
    via `gdb` — `HandleMenuInput` call count climbed past its scripted queue
    length instead of stopping at the scripted cancel, eventually reading
    off the end of the test's response arrays and segfaulting). Fixed by
    reordering: `push eax` (save the real key mask) *before* the `ECX`-based
    `menu_item_step` restore, matching pret's non-clobbering register choice.
- `nasm -f coff` both changed/new files; full `make` (clean) links; `make check`
  still green (untouched `engine/menus` check-only files unaffected).
- **Live, DOSBox-X, real render** (advisor-flagged gap, closed earlier this
  session): the no-input debug gate `DEBUG_LEARNMOVE=1` (`src/debug/debug_dump.asm:
  RunLearnMoveTest`, wired via `overworld.asm`/Makefile exactly like the existing
  `DEBUG_BATTLE`/`DEBUG_PARTY` gates) seeds `PrepareNewGameDebug`'s real
  STARTER_PIKACHU (party slot 3, level 5, real `WriteMonMoves`-generated moveset —
  not hand-picked), levels it 5→6 (pret `PikachuEvosMoves` learns TAIL_WHIP there),
  calls `LearnMoveFromLevelUp` directly in a battle-mode canvas, and dumps
  `FRAME.BIN`. A capture taken before the generator fix below confirmed a
  correctly bordered box reading "PIKACHU learned / TAIL WHIP!" — `PrintText
  (LearnedMove1Text)` renders correctly in the live battle canvas with correct
  nick (`wLearnMoveMonName`) and move-name (`wNamedObjectIndex`→`GetMoveName`)
  substitution; that box-drawing path is unchanged by everything since, so the
  capture still stands as evidence of the render.
- **Regression found + fixed, then superseded by a more faithful fix (same
  session)**: first found the deleted `ShowLearnedMoveText` ended in
  `call WaitForAPress`, but its replacement `PrintLearnedMove` initially didn't —
  `LearnedMove1Text`'s generated stream ended in plain TX_END (`0x50`) instead of
  carrying pret's own trailing `text_promptbutton` ($06). Bolted on an explicit
  `call WaitForAPress` to fix the immediate regression (message would otherwise
  flash and vanish). Later in the same session, once `gen_battle_text.py`'s
  `collect_wrappers` bug was fixed at the root (see DONE above — trailing
  directives after `text_far` are real, reachable bytes, not dead code),
  `LearnedMove1Text` regenerated with its own correct `TX_SOUND_GET_ITEM_1`/
  `TX_PROMPT_BUTTON`/`TX_END` tail — so `PrintText`'s own `TextCommandProcessor`
  now holds the box exactly as pret does. The bolted-on `WaitForAPress` was
  removed as redundant/less-faithful once the real mechanism was restored.
  **Final verification**: rebuilt both `DEBUG_LEARNMOVE=1` (common path) and
  `DEBUG_LEARNMOVE=1 DEBUG_LEARNMOVE_FULL=1` (full-slots path) and ran each
  headless under `timeout -s KILL 12` — both now correctly **hang** (killed by
  the timeout, no `FRAME.BIN` produced), proving both terminal prints
  (`LearnedMove1Text` and `DidNotLearnText`) block on a real button-wait via the
  same in-stream mechanism, not a bolt-on.

Remaining (folded into a future Stage 5/menus-port integration, not a new stage):
promote `learn_move_stubs.asm`'s `DisplayTextBoxID` stand-in to the real
`DisplayTextBoxID` once menus-port lands (delete the stub file, drop it from the
Makefile); generate `OneTwoAndText` once the text engine gains `TX_START_ASM`
support (or hand-translate its SFX+continuation as code — same boundary as the
other already-skipped `text_asm` battle labels) and wire its `PrintText` call
into `DontAbandonLearning`'s marked TODO spot; wire
`RareCandyLevelUp` → `LearnMoveFromLevelUp`-equivalent once `UseItem_` dispatch
exists (current_plan_items.md). -->

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
