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
  single sub-step; may split into 1c-i (decoder, validated vs a known pic) and 1c-ii
  (place both pics on screen). `HideSubstituteShowMonAnim`/`ReshowSubstituteAnim` deferred.
- `CheckTargetSubstitute` (small) lands here.

### Stage 2 (≈glue 2b) — Main turn loop (silent: `PlayMoveAnimation` stays a stub)
- 2a: battle menu (FIGHT / PKMN / ITEM / RUN) + move-select submenu (player moves +
  PP) using existing menu primitives. **GATE:** menu navigates, move list correct.
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
