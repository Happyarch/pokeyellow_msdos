# Current Plan: Battle Front-End (Wave 2)

The keystone milestone: the on-screen battle loop that ties the Wave-1 backend
(damage pipeline, type/category/effect data, `JumpMoveEffect` dispatch, trainer AI,
status residual, EXP/level-up) into a playable wild + trainer battle.

**Scope note (user directive, 2026-06-26):** the front end can't be validated
headless. Validation here is **FRAME.BIN** (`tools/render_frame.py`) + interactive
**DOSBox-X** `DEBUG_BATTLE_*` builds, NOT native ELF32 harnesses. **Every stage is
gated on a manual visual check by the user before moving on.** This plan is
intentionally staged into small, individually-verifiable steps.

**Viewport / placement (user, 2026-06-27):** the port viewport (320×200, 40×25
tiles) differs substantially from the GB (160×144, 20×18), so pret battle-screen
coordinates do NOT map 1:1. **Every on-screen placement (HUD boxes, HP bars, mon
sprites, text box, menus) is a sign-off point:** propose coords → render FRAME.BIN →
iterate with the user. Record the agreed coords as `; PROJ` tags + entries in
`docs/ui_projection.md` (the GB→port UI coordinate registry) so they're reusable and
documented. Expect frequent placement check-ins throughout Stage 1.

**Sequencing:** Wave 1 backend (done) → here → Wave 3 (battle-gated features).

## Wave-1 handoff (foundation in place)
Backend landed + native-validated on `wave1-battle-backend`: `CalculateDamage`/
`AdjustDamageForMoveType`/`MoveHitTest`/`CriticalHitTest`, type/category/effect data,
`JumpMoveEffect` dispatch (`effects.asm`, 14 handlers wired + `UnportedMoveEffect`
stub for the rest), `trainer_ai.asm`/`read_trainer_party.asm`, `residual_damage.asm`,
`GainExperience` math, stat-mod effects, badge boosts, status penalties, building
rage, wild-encounter gen. **All are BATTLE_SRCS check-only** (assemble + validated,
not yet linked) — Wave 2 supplies the UI/text/HUD externs they call and pulls the
whole closure into LINK_SRCS.

## Substrate already available (reuse, don't rebuild)
Text/box: `PrintText`, `PrintText_NoBox`, `PlaceString`, `TextBoxBorder`,
`EnableAutoTextBoxDrawing`, `LoadFontTilePatterns`, `LoadTextBoxTilePatterns`,
**`LoadHpBarAndStatusTilePatterns`**. Sprites: `PrepareOAMData`, `ClearSprites`,
`HideSprites`. Menus: `DisplayPartyMenu`, `DisplayBagMenu` (for PKMN/ITEM in battle).
PPU: software BG + OAM renderer, window layer. Math/data: the full Wave-1 backend.

## Known cross-cutting prerequisites (resolve as encountered, not up front)
- **Bank-switch shims** (`Bankswitch`, `CallBankF`, `BANK_*`, `predef *`): pret
  far-calls. Port convention (CLAUDE.md RST/bank section) = direct `call`. Provide a
  thin shim/`%define` so the many `BANK_x`/`CallBankF` refs resolve to direct calls.
- **`CheckTargetSubstitute`, `CalculateModifiedStats`** — small battle-core helpers
  pulled in by the loop; build alongside Stage 2.
- The `_MoveMon` extraction (bills_pc) and trainer-party data generator
  (`gen_trainer_parties.py` + `AddBCDPredef`) are Wave-1 deferrals; trainer data +
  AddBCDPredef are needed in **Stage 4** (trainer battles), built there.

---

## Stages (each ends at a manual FRAME.BIN / DOSBox-X gate)

### Stage 0 — Battle harness + entry scaffold (infra; no gameplay yet)
- `DEBUG_BATTLE` build hook mirroring `DEBUG_PARTY`/`DEBUG_BAGMENU_LIVE`: seed the
  player party (existing `DEBUG_PARTY` seed) + a fixed wild enemy mon, then jump
  straight into battle init and dump FRAME.BIN. Add to `boot/entry.asm` + Makefile.
- `init_battle_variables.asm` (clear/seed battle WRAM) + a minimal `InitBattle` that
  populates the enemy battle-mon struct from the seeded species/level.
- **GATE:** boots into "battle mode" without crashing; FRAME.BIN renders *something*
  deterministic (even if just a cleared screen + text box).

### Stage 0.5 — Battle render mode (centered-baseline approach)
**Layout decision (user, 2026-06-27, refined): build the FAITHFUL GB battle UI
(pret's 20×18 coords) CENTERED in the 320×200 viewport first, then ITERATE elements
outward into the widescreen margins.** Iterating from a working baseline is faster
than designing 40×25 coords cold. Consequence: the centered GB content (≤20 tiles
wide) FITS the existing window-overlay path (`render_window`, ≤32-wide GB tilemap) —
so **`render_screen_tilemap` is NOT needed yet** (defer until iteration pushes
content past 32 tiles wide). The one frame-pipeline change: while `wIsInBattle`,
clear the backbuffer to the battle background (black/blank) instead of rendering the
overworld, so the pillarbox/letterbox margins aren't Pallet Town. Battle content is
built in `W_TILEMAP`/`GB_TILEMAP1` and placed via a centered window descriptor
(wx≈80, wy≈28, like the menu placement convention). **GATE:** `DEBUG_BATTLE` shows a
deterministic centered battle field (cleared margins) in FRAME.BIN.

### Stage 1 (≈glue 2a) — Static battle screen + HUD
**Start from pret's faithful GB coords (centered); record placements as `; PROJ` /
`docs/ui_projection.md` entries. Widescreen spacing is an ITERATION pass after the
centered baseline renders (move HUD/sprites outward with the user via FRAME.BIN).**
- [x] 1a: battle screen frame — full blank → bottom `TextBoxBorder` dialog box →
  intro text ("Wild POKéMON / appeared!"), centered baseline. **GATE:** awaiting
  user sign-off (FRAME.BIN render shown 2026-06-28). Done: `init_battle.asm`
  rewritten from the Stage-0.5 full-frame placeholder; stride/centering/sprite
  fixes (see translation_log + handoff below).
- [x] 1b: `DrawBattleHUDs` (new `battle_hud.asm`) — enemy HUD upper-left + player HUD
  lower-right: name, `:L`level, 6-seg HP bar (via `LoadHpBarAndStatusTilePatterns`),
  player HP fraction. **GATE: user signed off layout 2026-06-28** (enemy PIDGEY L3
  14/14 full bar; player PIKACHU L6 11/22 half bar + "11/ 22"). Mirrors party_menu's
  stride-agnostic HP-bar/digit logic; reads `wEnemyMon*`/`wBattleMon*` (harness-seeded
  until `LoadBattleMonFromParty`). Deferred: HP-bar color (Phase 5 palette), status
  text (seeded healthy), decorative HUD frame/pokeballs.
- 1c: mon sprites — enemy front pic (top-right) + player back pic (bottom-left).
  **DECIDED (user, 2026-06-27): real pic decompression now** — port `pkmncompress`
  decode + pic loading in this stage (not a placeholder). This is the heaviest
  single sub-step; split into 1c-i (decoder, validated vs a known pic) and 1c-ii
  (place both pics on screen). `HideSubstituteShowMonAnim`/`ReshowSubstituteAnim` deferred.
  - [x] **1c-i: runtime decompressor DONE + native byte-exact validated (2026-06-29).**
    `src/gfx/uncompress.asm` — faithful 1:1 port of `home/uncompress.asm` (all of
    UncompressSpriteData/`_`/Loop, MoveToNextBufferPosition, Write/ReadNextInput*,
    UnpackSprite, SpriteDifferentialDecode, DifferentialDecodeNybble, XorSpriteChunks,
    ReverseNybble, ResetSpriteBufferPointers, UnpackSpriteMode2, StoreSpriteOutputPointer
    + the 5 tables). The GB "endless loop terminated by popping the return off the
    stack" is preserved verbatim (`MoveToNextBufferPosition .allColumnsDone: pop esi`),
    so the control-flow cluster is intentionally **naked** (no register-saving
    prologues — see the file header). Addressing: GB state/buffers/input EBP-relative;
    const tables flat `.data`; chosen differential table held in flat `.bss` selectors
    `sp_dtbl0/1` (the 16-bit `wSpriteDecodeTable*Ptr` GB vars can't hold a flat addr,
    so they go unused). **Validation: a native `gcc -m32` harness** (shim sets EBP →
    `run_decode` → reassemble buffer1(even)/buffer2(odd) + `transpose_tiles` exactly
    like `pkmncompress.c`) decoded **all 353 committed pics byte-exact** vs their
    `.2bpp`: front 153/153, back 151/151, trainers 46/46, battle 3/3 — exercising every
    unpack mode (0/1/2) and both plane orders. Flipped path (back pics) runs
    deterministically; its byte-exact gate belongs to **1c-ii** (the horizontal flip is
    completed by the merge step's `InterlaceMergeSpriteBuffers` nybble-swap, plus the
    on-screen FRAME.BIN gate). Harness is ephemeral (scratchpad, not committed), matching
    the project's native-harness convention. Wired into `FRONTEND_SRCS` (links clean into
    PKMN.EXE; only `FillMemory` extern). NOTE: clean stale `DEBUG_BATTLE` `overworld.o`
    before a non-debug link (RunBattleTest undefined-ref = the known stale-object trap).
  - [x] **1c-ii: merge + placement DONE + user-signed-off (2026-06-29).** `src/gfx/pics.asm`:
    ported `LoadUncompressedSpriteData`/`AlignSpriteDataCentered`/`ZeroSpriteBuffer`/
    `InterlaceMergeSpriteBuffers` (front) + `ScaleSpriteByTwo` (+`ScaleFirstThree`/`ScaleLast`/
    `ScalePixelsByTwo`/`DuplicateBitsTable`, the 4x4→7x7 2x scale) for the back pic. The
    merge ends with a 49-tile (784-byte) copy from sSpriteBuffer1 to VRAM + sets
    `g_tilecache_dirty`; `PlacePicTilemap` writes the 7x7 tile-ID block into W_TILEMAP
    column-major (faithful to `CopyUncompressedPicToTilemap`). Battle BG uses SIGNED tile
    addressing, so tile ID $00-$7F → VRAM $9000-$97F0. **Enemy front** (PIDGEY 5x5, exercises
    centering) at VRAM $9000 / tile $00, canvas (22,3). **Player back** (PIKACHU 4x4→scaled,
    flipped=0) at VRAM $9310 / tile $31, canvas (11,8); its 49 tiles ($31-$61, VRAM
    $9310-$961F) clear the HP-bar tiles at $9620 — the 2-tile overlap at IDs $60/$61 is the
    box set's unused font_extra glyphs (not shown in battle), so cosmetically safe. Stubs
    (`DrawEnemyFrontPic_Stub`/`DrawPlayerBackPic_Stub`, embedded pidgey/pikachub .pic via
    incbin) called from the DEBUG_BATTLE harness — the real path (species→pic-pointer table)
    is a Stage 2/3 data-layer task. **GATE: user confirmed both sprites render correctly**
    (Pidgey front + Pikachu back, full faithful battle screen — FRAME.BIN render shown).
    Polish deferred (user): intro text should pull the actual mon name vs the fixed string.
- **Stage 1 COMPLETE** (1a frame, 1b HUDs, 1c sprites — all user-signed-off).
- `CheckTargetSubstitute` (small) lands here.

### Stage 2 (≈glue 2b) — Main turn loop (silent: `PlayMoveAnimation` stays a stub)
- 2a: battle menu (FIGHT / PKMN / ITEM / RUN) + move-select submenu (player moves +
  PP) using existing menu primitives. **GATE:** menu navigates, move list correct.
  - [x] **FIGHT/PKMN/ITEM/RUN menu DONE + user-signed-off (2026-06-29).** Built the
    **faithful** way (user directive: "match the original's routine within our
    structure", not a hand-drawn bodge). NEW reusable module `src/text/wide_text.asm`
    = stride-40 (W_TILEMAP) ports of the GB routines the wide battle canvas needs but
    the stride-20-locked `text.asm` can't provide: `WideTextBoxBorder` (TextBoxBorder),
    `WidePlaceString` (PlaceString/PlaceNextChar incl. `<NEXT>` $4E), `WideHandleMenuInput`
    + `WidePlaceMenuCursor` (HandleMenuInput/PlaceMenuCursor, double-spaced, faithful
    `wTileBehindCursor` erase). `battle_menu.asm` is now a faithful `DisplayBattleMenu`
    port: clear announcement text (PrintEmptyString) → draw the smaller menu sub-box via
    `WideTextBoxBorder` at the real `BATTLE_MENU_TEMPLATE` (8,12-19,17) coords → place
    `BattleMenuText` via `WidePlaceString` → two-column input (per-column HandleMenuInput
    watching RIGHT|A / LEFT|A; right-column A adds 2; gen-1 ITEM/PKMN id swap). Added the
    menu WRAM vars to gb_memmap (`wTopMenuItemY/X` $CC24/25, `wTileBehindCursor` $CC27,
    `wMenuWatchedKeys` $CC29, `wLastMenuItem` $CC2A). Dropped GB peripherals (down-arrow
    blink, party-mon shake, AB sound, low-sensitivity auto-repeat — uses per-frame edge
    `H_JOY_PRESSED` like the START menu). **GATE: user signed off** (cursor navigates
    2x2 cleanly, no ghost cursor, faithful sub-box). FIGHT/PKMN/ITEM/RUN A-dispatch is
    next. Wired into FRONTEND_SRCS; harness calls `DisplayBattleMenu` (live) / `DrawBattleMenu`
    (dump). The `wide_text` module backs all future battle text/menus.
  - [x] **FIGHT move list + TYPE/PP box + teardown DONE + signed off (2026-06-29).** A→FIGHT lists
    the 4 moves (`MoveSelectionMenu`, self-contained `FindMoveName` over the linked `MoveNames`);
    `PrintMoveInfoBox` (faithful `PrintMenuItem`) shows TYPE/`<type>`/`cur/max` PP, refreshed per
    cursor move via a new `wide_menu_redraw_cb` hook (= pret SelectMenuItem calling PrintMenuItem).
    Type names = generated `type_names.asm` (`WideTypeNames`). Box nudged 1 col left of GB-center so
    it clears the player HUD. `SaveBattleScreen`/`RestoreBattleScreen` (= `SaveScreenTilesToBuffer1`/
    `LoadScreenTilesFromBuffer1`) wipe the move box + TYPE/PP box on back-out (B) / move-use (A).
    Bug fixes: watch only A|B in the move list (UP/DOWN handled internally); full-outer-box redraw.
    Deferred: max-PP PP-Up scaling (`GetMaxPP`); move reorder (SELECT swap).
  - [x] **Stage-2b START: attack text (2026-06-29).** A on a move → `ExecutePlayerTurn`: faithful
    `DisplayUsedMoveText` — "`<MON>` / used `<MOVE>`!" in the dialog box, wait for A.
- **Stage 2a COMPLETE** (menu + move list + TYPE/PP box + teardown, all user-signed-off).

### ░░ HANDOFF — resume here (2026-06-29, COMMITTED @ c73b9a9b — turn loop + battle-entry done) ░░
**STATUS: a wild battle plays a full round AND has the faithful battle-entry sequence.** All of
Stage 2 (turn loop) + the battle-entry polish are done and **committed** (branch
`wave2-battle-frontend`, commit `c73b9a9b`); all user-signed-off live. The next session picks up at
**Stage 3 (wild end-to-end: victory EXP, RUN)** and **Stage 4 (trainer battle: enemy send-out + AI)**.

**WHAT WORKS NOW (this session, all committed):**
- **Full round**: player attack + enemy retaliation, speed-ordered (Quick Attack priority, Counter
  last, 50/50 tie), faint ends the round. Wild random-move AI (`SelectEnemyMove`, also default for
  trainers). Faithful wild moveset gen (`LoadWildMonMoves`: base moves + level-up learnset + PP).
  HP-drain animation. Win/lose termination (`wBattleOver`/`EndBattleScreen`). FIGHT-cursor persistence.
- **Battle entry** (faithful pret `_InitBattleCommon` order): silhouette **slide-in**
  (`SlideBattlePicsIn`, software-native, true-black stopgap) → intro text (real mon name) + blinking
  ▼ + party **pokéballs** (OAM, `pokeballs.asm`/`PrepareStaticOAM`) → press A → send-out → HP-bar HUD.
  **HUD frame tiles** now load (`LoadHudTilePatterns` + `gen_battle_hud_inc.py`) — the missing piece
  that left "ID No." garbage at $73/$74. Player **trainer (Red) back** slides in; Pikachu at send-out.
- **Trainer data**: `gen_trainer_pics.py` → all 46 trainer pics + `TrainerPicPointers` (class→pic) +
  `TrainerBaseMoney` + player front/back. **Bug Catcher test** (`DEBUG_BATTLE_TRAINER`): both ball
  rows + ok/fainted/status/empty variety + trainer sprite — verified, signed off.

**DEBUG FLAGS (debug_dump.asm `RunBattleTest`):** `DEBUG_BATTLE_LIVE` (interactive wild),
`+ DEBUG_BATTLE_TRAINER` (Bug Catcher), `DEBUG_BATTLE_INTRO` (FRAME dump of the intro),
`DEBUG_BATTLE_ENEMYHIT` (headless one-enemy-hit DUMP.BIN). Harness PIDGEY is now **L13** (GUST/
SAND-ATTACK/QUICK-ATTACK so the random AI varies), PIKACHU L18/45HP. Stats/moves HARNESS-SEEDED.

**DEFERRED / TODO (tagged in code + translation_log):**
- **Stage 3** — wild victory EXP (Wave-1 `GainExperience` + PrintStatsBox), RUN flow, clean overworld
  exit (`EndBattleScreen` is the blank placeholder). Catch flow may defer to Wave 3.
- **Stage 4** — trainer battle: enemy send-out (enemy mon appears + HP bar), trainer AI turns,
  multi-mon, `end_of_battle` prize money (`TrainerBaseMoney` is ready), defeat text. Also: real
  `_LoadTrainerPic` via `TrainerPicPointers` (replace `DrawBugCatcherPic_Stub`); trainer intro text
  ("`<class>` wants to fight!", currently still "Wild <nick> appeared!").
- **Send-out animation** `TODO(send-out)` (pics.asm/debug_dump.asm): trainer slides OUT then the mon
  comes in — starter PIKACHU just slides (no ball/grow, Yellow special), others get ball-throw+grow.
- **Black silhouette interior** `TODO(palette)`: BGP only blackens non-color-0 pixels; full CGB black
  = Phase-5 palette. **Decompressor over-box** `TODO(glitch)`: MissingNo case (real mons unaffected).
- Real `LoadBattleMonFromParty` (vs harness seeds); `GetMaxPP` PP-Up; move reorder (SELECT);
  accuracy/`MoveHitTest`+effects (replace battle_stubs); audio HAL (battles silent).

**READ THESE FILES FIRST (exact):**
1. `dos_port/src/engine/battle/battle_menu.asm` — the battle front-end heart. Now holds:
   `DisplayBattleMenu` (faithful Load→DrawHUDs→Save→menu), `DrawBattleMenu`, `MoveSelectionMenu`
   + `DrawMoveList` + `FindMoveName`, `PrintMoveInfoBox` (TYPE/PP), `Save/RestoreBattleScreen`,
   `ExecutePlayerTurn`→`RenderPlayerTurn` (RestoreScreen→`DoPlayerAttackDamage`→`DrawBattleHUDs`
   →attack text→WaitForA→faint check→`ShowEnemyFainted`), `DoPlayerAttackDamage` (the real
   pipeline), `WaitForAPress`, `print_2d`.
2. `dos_port/src/text/wide_text.asm` — the stride-40 text/box/menu layer (`WideTextBoxBorder`,
   `WidePlaceString` (returns end ESI; `wide_line_step` controls `<NEXT>`+cursor spacing),
   `WideHandleMenuInput`+`WidePlaceMenuCursor`, `wide_menu_redraw_cb`). Backs ALL battle UI.
3. `dos_port/src/engine/battle/battle_hud.asm` — `DrawBattleHUDs` + `draw_hp_bar`/`calc_hp_pixels`
   (the 6-seg gauge; empty seg = tile `$63`, nearly invisible — relevant to "bar disappeared").
4. `dos_port/src/engine/battle/init_battle.asm` — `InitBattle` (widescreen canvas; the dialog box
   geometry `OUTER_OFF`/etc. that battle_menu mirrors).
5. `dos_port/src/debug/debug_dump.asm` — the `RunBattleTest` harness (seeds PIDGEY enemy + PIKACHU
   player **stats/types/moves/PP**; `%ifdef DEBUG_BATTLE_LIVE` runs `DisplayBattleMenu` loop, else
   dumps FRAME.BIN). It also has a `%elifdef DEBUG_BATTLE` memory-dump `windows:` table aimed at
   battle WRAM — handy for ground-truthing (see "how I debugged" below). Leftover unused
   `extern`s (RenderPlayerTurn/GetCurrentMove/…) are harmless.
6. `dos_port/src/engine/battle/core_damage.asm` (READ-ONLY ref) — the Wave-1 damage backend now
   LINKED: `GetCurrentMove`(in get_current_move.asm)/`GetDamageVarsForPlayerAttack`/`CalculateDamage`/
   `AdjustDamageForMoveType`/`RandomizeDamage`. `engine/battle/core.asm` (pret) lines ~2076 (Display-
   BattleMenu), ~2567 (MoveSelectionMenu/SelectMenuItem), ~3010 (PrintMenuItem), ~3314 (player
   attack order), ~741 (FaintEnemyPokemon).

**WHAT'S WIRED + LINKED (Makefile `FRONTEND_SRCS`):** wide_text, battle_data, type_names,
home/random, core_damage, get_current_move, battle_stubs, uncompress, pics, init_battle*,
battle_hud, battle_menu. `battle_stubs.asm` = link-only `JumpMoveEffect`/`CheckTargetSubstitute`
`ret` stubs (only reached by OHKO / MoveHitTest paths we don't call yet).

**KEY FACTS / GOTCHAS (don't relearn the hard way):**
- **Battle canvas = 40×25 W_TILEMAP via render_bg's non-overworld path** (view-ptr=0). Box/HP-bar
  tiles use SIGNED tiledata: tile id $00-$7F → VRAM $9000-$97F0. Enemy front pic at tiles $00-$30,
  player back at $31-$61, HP-bar tiles $62-$71 (no overlap). See memory `battle-widescreen-canvas`.
- **`text.asm` PlaceString/TextBoxBorder are stride-20-locked** → cannot lay out the 40-wide canvas;
  that's WHY `wide_text.asm` exists. Single-line PlaceString IS stride-agnostic (battle_hud uses it
  for names).
- **The damage IS faithful** (proven by memory dump): THUNDERSHOCK 21 dmg = 2× super-effective
  (electric vs PIDGEY flying) → OHKO; QUICK ATTACK 4 dmg; GROWL/TAIL WHIP 0. Don't "fix" the calc.
- **RNG fix (latent bug I fixed):** `engine/math/random.asm` `Random_` now does `add byte [ebp+IO_DIV],0x25`
  each call — the port never advanced IO_DIV, so the PRNG never churned and `RandomizeDamage`'s
  217..255 rejection loop hung forever. Also `home/random.asm` now `%include`s gb_memmap (was
  wrongly `extern hRandomAdd`).
- **Stale-snapshot rule:** `RestoreBattleScreen` replays the saved screen; `DisplayBattleMenu` MUST
  re-`DrawBattleHUDs`+`SaveBattleScreen` (current HP) or a drained bar "refills". (Just fixed.)
- **Stale debug objects:** `make clean` leaves `src/{debug,engine/debug}/*.o` + `overworld.o`
  referencing RunBattleTest — `rm -f src/debug/debug_dump.o src/engine/debug/debug_party.o
  src/engine/overworld/overworld.o` before switching DEBUG flags or get undefined-ref at link.
- **Build/run:** `make -C dos_port SKIP_TITLE=1 DEBUG_BATTLE_LIVE=1 && dos_port/run` (live, Esc
  quits). `DEBUG_BATTLE=1` → FRAME.BIN dump; render `python3 tools/render_frame.py FRAME.BIN out.png`.
  Stats/moves are HARNESS-SEEDED (no `LoadBattleMonFromParty` yet).

**NEXT (Stage 2b/2c, in order of value):**
1. [x] **Enemy turn** (DONE 2026-06-29): `DoEnemyAttackDamage`/`RenderEnemyTurn` mirror, speed-
   ordered round, faint ends round. Wild random-move AI (`SelectEnemyMove`) + faithful wild
   moveset generation (`LoadWildMonMoves`). Headless-validated; live sign-off pending.
2. [x] **HP-drain ANIMATION** (DONE 2026-06-29): `AnimateEnemyHPBar`/`AnimatePlayerHPBar` tick the
   gauge down per-pixel with a 2-frame wait (pret UpdateHPBar cadence); player digits tick too.
   User signed off. Still no sound (audio HAL is the Stage-2 tail).
3. [x] **Battle TERMINATION (2c)** (DONE + user-signed-off 2026-06-29): `wBattleOver` win/lose
   flag breaks the menu loop; `EndBattleScreen` clears to a clean terminal. DEFERRED to Stage 3:
   victory EXP (Wave-1 `GainExperience`), real overworld exit, multi-mon switch-in on faint.
4. **Victory EXP screen** (Stage 3): wire Wave-1 `GainExperience` (+ PrintStatsBox / level-up / move
   learn) on the win path; replace `EndBattleScreen`'s blank placeholder with the real exit.
5. Speed-tie random break + Quick Attack/Counter priority (turn-order quirks deferred above).
5. Deferred polish: real species→pic + `LoadBattleMonFromParty` (vs seeds); intro text uses the mon
   name; TYPE/PP `GetMaxPP` PP-Up scaling; move reorder (SELECT); accuracy/`MoveHitTest`+effects
   (replace the two stubs); trainer-AI scoring (`AIEnemyTrainerChooseMoves`, wire into SelectEnemyMove).

**HOW I GROUND-TRUTH BATTLE STATE** (since the PPU collapses many bugs to "blank"): point the
`%elifdef DEBUG_BATTLE` `windows:` table in debug_dump.asm at the WRAM of interest (wEnemyMonHP
$CFE5, wDamage $D0D6, wPlayerMove* $CFD1, W_TILEMAP rows = $C3A0+row*40), call the routine under
test then `jmp DebugDumpMemory`, build `DEBUG_BATTLE=1`, run headless, hexdump DUMP.BIN. This is
how I proved the damage was faithful and the "bar disappeared" was just HP=0.
- 2b: one full turn — `MainInBattle` core: read selection, turn ordering (speed
  compare), `ExecutePlayerMove`/`ExecuteEnemyMove` → `GetDamageVars`+`CalculateDamage`
  (Wave 1) → apply HP → `UpdateHPBar` → `JumpMoveEffect` (Wave 1) → faint check →
  `HandlePoisonBurnLeechSeed` (Wave 1). Text: "X used MOVE!", effectiveness, faint.
  **GATE:** a scripted `DEBUG_BATTLE` turn drops HP + prints text in FRAME.BIN.
- 2c: win/lose terminal states (enemy faints → victory; player party faints → lose).
  **GATE:** battle ends cleanly to the overworld/black.

### Stage 3 (≈glue 2c) — Wild battle end-to-end
- Wild `InitBattle` entry (intro text, simple/stubbed transition), RUN flow, victory
  → `GainExperience` (Wave 1) wired with its text/`PrintStatsBox`. Catch flow may
  defer to Wave 3 (item USE) — note as stub.
- **GATE:** a wild battle is playable start→finish in DOSBox-X.

### Stage 4 (≈glue 2c) — Trainer battle end-to-end
- Trainer `InitBattle` (Wave-1 `read_trainer_party` — needs the
  `gen_trainer_parties.py` data tables + `AddBCDPredef`, built here), trainer intro,
  AI turns (Wave-1 `trainer_ai`), multi-mon `EnemySendOut`, `end_of_battle` (prize
  money), defeat text.
- **GATE:** a trainer battle is playable start→finish in DOSBox-X.

### Cross-cut — Audio HAL (glue Wave-2 tail / Phase 3)
`dos_port/include/audio_hal.inc` + a first driver (Tandy/SB16 = 1:1 APU synthesis;
MT-32/GM = build-time pre-rendered MIDI). Disjoint files (`src/audio/*`) → could run
as a **separate agent alongside** Stage 2+, BUT it needs *hardware* verification
(not headless/logic-only), so it does not fit the "sonnet parallel = logic-only"
rule — treat as a serial/owner-verified track. Battles stay **silent** until then.

## Archived handoffs

The Stage 1a/1b and 2026-06-27 "resume here" handoffs that used to live here are
**superseded** — their content is captured in the completed `[x]` stage entries above
and in git history (branch `wave2-battle-frontend`). The single current resume point
is the **`░░ HANDOFF — resume here ░░`** block in the Stage 2 section above. Do not
resume from anything else.
