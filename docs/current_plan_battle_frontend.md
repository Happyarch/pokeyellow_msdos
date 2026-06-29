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

### ░░ HANDOFF — resume here (2026-06-29, Stage 2b player-attack damage live) ░░
**STATUS: the player's move now deals faithful Gen-1 damage, drains the enemy HP bar, and
faints the enemy.** Built + signed off incrementally. UNCOMMITTED: a large clean chunk
(Stage 1c + 2a + 2b-so-far). The user has NOT asked to commit — do not commit unprompted.

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
1. **HP-drain ANIMATION** (pret `UpdateHPBar`): tick the gauge down 1px at a time w/ a delay (and
   later a sound) instead of the instant redraw, so the drop reads clearly.
2. **Enemy turn**: `ExecuteEnemyMove` mirror (`GetDamageVarsForEnemyAttack` exists in core_damage)
   → drain the PLAYER bar → faint check on the player. Then turn ordering by speed.
3. **Battle end (2c)**: after `ShowEnemyFainted`, do victory (EXP via Wave-1 `GainExperience`) and
   exit the battle cleanly (currently it just loops back to the menu — the one known rough edge).
4. Deferred polish: real species→pic + `LoadBattleMonFromParty` (vs seeds); intro text uses the mon
   name; TYPE/PP `GetMaxPP` PP-Up scaling; move reorder (SELECT); accuracy/`MoveHitTest`+effects
   (replace the two stubs).

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

## Handoff — resume here (2026-06-28, Stage 1b done — HUDs on widescreen canvas)

**Stage 1b DONE (user signed off layout).** `src/engine/battle/battle_hud.asm`
(`DrawBattleHUDs`) draws both HUDs into the 40×25 canvas: enemy upper-left
(name(11,3)/`:L`lv(15,4)/HP bar(12,5)), player lower-right
(name(20,11)/lv(24,12)/HP bar(20,13)/frac(21,14)). Called from `InitBattle` after the
box; `InitBattle` now also calls `LoadHpBarAndStatusTilePatterns` (tiles $79-$7F are
byte-identical between the box & battle sets, so it does NOT clobber the dialog box —
verified; the load_font.asm warning is over-cautious). HP-bar/level/digit logic mirrors
the shipped party-menu renderer (linear within a row → stride-agnostic, drops onto the
canvas). Reads `wEnemyMon*`/`wBattleMon*`; the DEBUG_BATTLE harness seeds them
(PIDGEY L3 14/14, PIKACHU L6 11/22) — real path is `LoadBattleMonFromParty` (Stage 2/3).
FRAME.BIN histogram {0, 2, 3} (shade-2 from the bar tiles). Deferred to later passes:
HP-bar color by fraction (Phase 5 palette), status text (`.print_status` mirror; seeded
healthy so blank now), decorative HUD frame ($73/$76 underline) + pokeball indicators.

**NEXT — Stage 1c: mon sprites** (enemy front pic top-right, player back pic
bottom-left). Heaviest sub-step. **DECISION (user, 2026-06-28): FAITHFUL runtime
decompressor** — NOT a build-time PNG→2bpp shortcut. Reason: many Gen-1 sprite/ACE
glitches and glitch-Pokémon front sprites depend on the decompressor's real behavior
on malformed data; a build-time decode would silently kill them (fits the project's
GLITCH-preservation philosophy). Plan split: 1c-i decoder (native byte-exact),
1c-ii placement (FRAME.BIN). `HideSubstituteShowMonAnim`/`ReshowSubstituteAnim` +
`CheckTargetSubstitute` deferred.

### Stage 1c research — DONE this session (do not re-derive)
- **Source to port:** `home/uncompress.asm` (~600 lines, fully read) =
  `UncompressSpriteData`/`_UncompressSpriteData`/`UncompressSpriteDataLoop`,
  `MoveToNextBufferPosition`, `WriteSpriteBitsToBuffer`, `ReadNextInputBit/Byte`,
  `UnpackSprite`, `SpriteDifferentialDecode`, `DifferentialDecodeNybble`,
  `XorSpriteChunks`, `ReverseNybble`, `ResetSpriteBufferPointers`,
  `UnpackSpriteMode2`, `StoreSpriteOutputPointer`, + the 5 data tables.
  Then `home/pics.asm`: `UncompressMonSprite`/`LoadMonFrontSprite`/
  `LoadUncompressedSpriteData`/`AlignSpriteDataCentered`/`ZeroSpriteBuffer`/
  `InterlaceMergeSpriteBuffers` (1c-ii placement/merge), and `LoadMonBackPic`
  (engine/battle/init_battle.asm:160).
- **Aliases/constants ADDED + committed-ready (this session):**
  `gb_memmap.inc`: `wSpriteCurPosX..wSpriteDecodeTable1Ptr` at **$D0A0–$D0B3**
  (derived: pret puts the 20-byte block (10 db + 5 dw) right before `wCurSpecies`
  $D0B4 → $D0B4-0x14=$D0A0; lands exactly at wCurSpecies, verifying the count;
  $D0A0-$D0B3 is otherwise unused). `GB_SRAM=$A000`, `sSpriteBuffer0/1/2 =
  $A000/$A188/$A310` (SRAM free in port; buffer1/2 must stay contiguous — the
  decompressor clears 2*SPRITEBUFFERSIZE from buffer1). `gb_constants.inc`:
  `TILE_1BPP_SIZE=8`, `PIC_WIDTH/HEIGHT=7`, `SPRITEBUFFERSIZE=0x188` (392).
- **Addressing decision for the port:** the const tables (Decode*/NybbleReverse/
  LengthEncodingOffsetList) are ROM in pret, accessed via `[hl]`. In the port they
  must be FLAT `.data` (NOT `[ebp+...]`), while buffers/input/WRAM vars stay
  `[ebp+addr]`. So keep tables flat and select the differential-decode table via
  port-local 32-bit ptrs (e.g. `decode_tbl0/1` in .bss) instead of storing flat
  addresses in the 16-bit `wSpriteDecodeTable*Ptr` GB vars. Store pic pointers as
  16-bit LE words (`mov word [ebp+var]`); 16-bit pointer math stays in-buffer (no
  wrap), so 32-bit `add` is fine. `dn x,y` macro = `db (x<<4)|y` (tables already
  hand-expanded in notes below).
- **VALIDATION REFERENCE FOUND (native, byte-exact):** `tools/pkmncompress -u
  <in.pic> <out>` DEcompresses → confirmed byte-identical to `gfx/pokemon/front/
  pikachu.2bpp` (400B, native 5×5; .pic first byte 0x55 = 5×5 tiles). NOTE the
  formats: my GB decompressor emits COLUMN-MAJOR 1bpp chunks; `pkmncompress -u`
  finishes with `transpose_tiles` (back to row-major) + interleave
  (`out[i*2]=plane0, out[i*2+1]=plane1`). So to byte-compare in the harness, either
  (a) compare my two chunks against `pkmncompress -u` output AFTER de-interleaving +
  transposing it to column-major, or (b) port the full merge (1c-ii) and compare the
  reassembled native 2bpp. `transpose_tiles(data,width)`: tile i → j =
  `(i*width + i/width) % (width*width)` (see tools/pkmncompress.c:46). pkmncompress
  also picks mode/order (read from the stream by the decoder — handled automatically).
- **Decode-table bytes (pre-expanded `dn`):**
  `DecodeNybble0Table:        01 32 76 45 FE CD 89 BA`
  `DecodeNybble1Table:        FE CD 89 BA 01 32 76 45`
  `DecodeNybble0TableFlipped: 08 C4 E6 2A F7 3B 19 D5`
  `DecodeNybble1TableFlipped: F7 3B 19 D5 08 C4 E6 2A`
  `NybbleReverseTable:        0 8 4 C 2 A 6 E 1 9 5 D 3 B 7 F`
  `LengthEncodingOffsetList:  dw 1,3,7,15,...,65535 (2^(n+1)-1, 16 entries)`
- **NOT YET WRITTEN:** `src/gfx/uncompress.asm` (no code yet — only includes were
  edited). Next session: write it, add a source list + native harness, byte-validate,
  then do 1c-ii (merge + place enemy front top-right / player back bottom-left).
  `LoadMonBackPic` sets `wSpriteFlipped`; front pics are not flipped.

## Handoff (2026-06-28, Stage 1a built — WIDESCREEN canvas)

**ARCHITECTURE PIVOT (user direction 2026-06-28):** "we should be using the wider
screen and just centering everything. I want to extend it later." → the battle
screen is now the **full 320×200 (40×25-tile) widescreen canvas**, with the default
GB UI built CENTERED in it (col +10, row +3). The Stage-0.5 centered 20×18 window
descriptor is GONE. This reverses the Stage-0.5 "defer render_screen_tilemap"
decision — but no new renderer was needed (see below).

**Stage 1a DONE (user signed off the text box display; pivot re-verified clean).**
`src/engine/battle/init_battle.asm`: blank the whole 40×25 `W_TILEMAP` → hand-draw
the dialog box at canvas (10,15) → fixed intro "Wild POKéMON / appeared!". FRAME.BIN
clean (shade 0 + shade 3 only, 1404 box px, 0 sprite px, h-center 159 ≈ 160).

**KEY REUSABLE FACTS (also in translation_log + memory):**
1. **Battle screen = the BG plane via `render_bg`'s non-overworld path.** `render_bg`
   decodes the full 40×25 `W_TILEMAP` to the back buffer whenever
   `wCurrentTileBlockMapViewPointer == 0` (the title/menu path). `InitBattle` zeroes
   that pointer + `IO_SCX`/`IO_SCY` and `hide_window`s; `frame.asm` just calls
   `render_bg` (no more `clear_backbuffer_battle`, no window descriptor). To place a
   battle element anywhere on the wide screen, write tiles into `W_TILEMAP` at 40×25
   coords — no clip, no 20-tile cap.
2. **`TextBoxBorder`/`PlaceString` are stride-20-locked** (`text.asm:
   SCREEN_W_TILES equ 20`) and CANNOT build into the 40-wide canvas. Boxes are
   hand-drawn with box-border charmap tiles ($79–$7E) at stride 40. **Single-line**
   `PlaceString` (no `<NEXT>`/`<LINE>`) is stride-agnostic → still usable for HUD
   names. Multi-line battle text (Stage 2 turn loop) needs a stride-40-aware text
   placement (build a small helper, or a 20-wide scratch + center-copy).
3. `InitBattle` clears `wUpdateSpritesEnabled` so `update_oam` stops re-showing the
   overworld player sprite after `ClearSprites`.

**NEXT — Stage 1b (HUD boxes + HP bars), now on the wide canvas.** Port the helpers
pret's `DrawEnemyHUDAndHPBar`/`DrawPlayerHUDAndHPBar` need (none ported): `PrintLevel`,
`DrawHPBar` (+`DrawHP`), `CenterMonName`, `PrintStatusConditionNotFainted`,
`ClearScreenArea`, HUD-tile placers (`PlaceEnemyHUDTiles`/`PlacePlayerHUDTiles`).
Build at the GB coords + the (10,3) centering offset (enemy HUD GB(0,0)→canvas(10,3);
player HUD GB(9,7)→canvas(19,10)). Each placement = FRAME.BIN → user gate → `; PROJ`
+ ui_projection row. Names need `wEnemyMonNick`/`wBattleMonNick` in GB memory (seed /
`GetMonName`) for `PlaceString` (EBP-relative source). Per the user, build centered
first, then iterate elements outward into the margins case-by-case.

---

## Prior handoff (2026-06-27)

**Branches/commits.** Wave 1 backend is MERGED to `master` (`750d4b57`). Wave 2 is on
**`wave2-battle-frontend`** (off master), pushed. Key commits:
- `793c5db3` plan + sign-offs · `cee290d3`/`86ff4c69` layout decision (widescreen →
  refined to centered-baseline-then-iterate)
- `065872de` Stage 0: battle WRAM aliases + `InitBattleVariables`
- `d5077677` Stage 0.5: centered battle render mode + `DEBUG_BATTLE` harness
- `899c7e93` `DEBUG_BATTLE_LIVE` (hold screen for inspection)

**What's built & WORKING (ground-truth verified):**
- `src/engine/battle/init_battle_variables.asm` — faithful `InitBattleVariables`
  (WRAM clears; audio call left as `; TODO-HW`). Linked via `FRONTEND_SRCS`.
- `src/engine/battle/init_battle.asm` — **minimal placeholder** `InitBattle`:
  `InitBattleVariables` → `wIsInBattle=1` → `ClearSprites` → builds a full-frame
  `TextBoxBorder` in `W_TILEMAP` (20×18) → copies 20×18 to `GB_TILEMAP1` (32-stride)
  → `set_single_window` centered (wx=80, wy=28, clip=160, max_y=172).
- `src/video/frame.asm` — DelayFrame now: while `wIsInBattle`, calls
  `clear_backbuffer_battle` (fills `GB_BACKBUF` with shade 0) **instead of**
  `render_bg`, so the overworld isn't behind the battle. Overworld path unchanged
  (verified byte-identical Pallet Town via `DEBUG_BASELINE`).
- `DEBUG_BATTLE` (dump 1 frame + exit) / `DEBUG_BATTLE_LIVE` (loop, Esc quits) in
  `debug_dump.asm:RunBattleTest`, hooked in `overworld.asm` EnterMap, Makefile flags.

**CURRENT VISUAL STATE (what the user saw, and why):** only the centered ~160×144
region shows content (a placeholder box, shades 1/2 borders); everything else is
blank shade-0. This is the intended Stage-0.5 PLACEHOLDER, not a real battle — there
is no HUD/sprites/text yet. `DEBUG_BATTLE` (non-live) also *exits to DOS* after one
frame by design (looked like a crash). Use `DEBUG_BATTLE_LIVE` to inspect.

**Verified non-issues (don't re-investigate):**
- Assets are NOT stale: a forced `make -B assets` changed only 2 header-comment
  lines/file; data identical; overworld render byte-for-byte unchanged. Reverted.
- The host image viewer serves STALE cached PNGs — it caused multiple phantom
  "overworld still showing" diagnoses. **Verify FRAME.BIN via byte/pixel histograms,
  not the rendered image** (see memory `frame-bin-image-viewer-unreliable`). The user
  does the real visual gate on their own display.

**USER NOTE to apply in Stage 1 (2026-06-27):** "Before the battle screen is drawn,
pret blanks the ENTIRE screen." pret's battle init does a full screen/VRAM clear +
loads battle tile patterns before drawing. Our per-frame `clear_backbuffer_battle`
approximates the blank, but Stage 1 should mirror pret's init order: clear the whole
`W_TILEMAP` (40×25, not just the 20×18 region) + load HP-bar/battle tiles, THEN draw
the HUD. Consider clearing `W_TILEMAP` fully in `InitBattle` so stale tiles never
linger, and confirm the blank covers the full widescreen, not only the centered box.

**NEXT — Stage 1 (real HUD), still per the centered-baseline-then-iterate decision:**
1. In `InitBattle`, replace the placeholder full-frame box with the real battle
   layout: full-screen blank first (per the user note), then enemy HUD (top-left:
   name/`:L`level/HP bar/status) + player HUD (bottom-right: + HP number) using
   `LoadHpBarAndStatusTilePatterns` and pret's `DrawEnemyHUDAndHPBar` /
   `DrawPlayerHUDAndHPBar` as references — built at GB coords, centered.
2. Each placement = propose coords → `DEBUG_BATTLE` FRAME.BIN → user sign-off →
   record as `; PROJ` tag + `docs/ui_projection.md` entry. Then iterate elements
   outward into the widescreen margins with the user.
3. Then mon pics (Stage 1c): port `pkmncompress` decode + pic load (user chose real
   pics, not placeholders).

**Build/run:**
```
make -C dos_port DEBUG_BATTLE_LIVE=1 && dos_port/run     # inspect live (Esc quits)
make -C dos_port DEBUG_BATTLE=1                          # dump FRAME.BIN + exit
python3 dos_port/tools/render_frame.py dos_port/FRAME.BIN out.png
# clean-build trap: `make clean` leaves src/{debug,engine/debug}/*.o — rm before switching DEBUG_* flags
```
