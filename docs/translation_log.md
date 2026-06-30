# Translation Log

Running notes on routines translated from SM83 to x86. One entry per routine.
Use this to document non-obvious decisions, flag edge cases found, and track
which H-flag situations were encountered.

Format:
```
## RoutineName
- Source: <file>:<label>
- Translated: <dos_port file>
- Date: YYYY-MM-DD
- H-flag: <involved / not involved / lazy>
- Bug tags: <none / BUG(critical) / BUG(cosmetic) / GLITCH>
- Divergences: <none (faithful) | each allowlist divergence + a one-line why,
  e.g. "PlayCurrentMoveAnimation → no-op: literal subanim deferred (ANIMATION=OFF, §2.1)">
- Notes: <decisions and edge cases>
```

For move-effect bodies, "Divergences" is mandatory and must list every allowed-divergence
(docs/move_translation_divergence.md §2) the body took, with a brief reason; "none (faithful)"
if it took none. This is the swarm's divergence audit trail.

---

## Move-effect swarm scaffold (S2–S4) + PoisonEffect_
- **Source:** pret `engine/battle/core.asm:3294-3436` (array-gated dispatch),
  `engine/battle/effects.asm` (PoisonEffect, PrintStatText, ConditionalPrintButItFailed,
  PrintButItFailedText_, PrintDidntAffectText, PrintMayNotAttackText, CheckTargetSubstitute),
  `home/array2.asm:IsInArray`, `data/battle/stat_mod_names.asm`.
- **Translated:** `src/home/array.asm` (IsInArray global); `src/engine/battle/core.asm`
  (ExecutePlayerMove/ExecuteEnemyMove faithful 6-checkpoint dispatch); `src/engine/battle/
  move_effect_helpers.asm` (shared helpers + faithful-anim hooks); `src/engine/battle/
  move_effects/poison.asm` (PoisonEffect_, the gold-standard reference handler); `effects.asm`
  (JumpMoveEffect live, table re-pointed); tooling: `tools/build_index` + `tools/work_queue`
  (`move` category).
- **Date:** 2026-06-30
- **H-flag:** Not involved (flags via instruction choice; IsInArray returns CF, the dispatch
  branches on it).
- **Bug tags:** PoisonEffect_ carries `BUG(cosmetic)` for the Gen-1 1/256 miss inherited via
  MoveHitTest (fix, if any, lives in MoveHitTest under BUG_FIX_LEVEL, not the handler).
- **Divergences (PoisonEffect_):** `PlayBattleAnimation2` / `PlayCurrentMoveAnimation2` → no-op
  stubs: literal move subanimation deferred (ANIMATION=OFF path, §2.1). Everything else faithful
  (status byte, Toxic branch, accuracy split, text via the real PrintText).
- **Notes:** `JumpMoveEffect` is now LIVE (effects.asm MoveEffectPointerTable); the core_stubs
  stub was dropped. Only StatModifierUp/DownEffect + PoisonEffect_ are wired; every other entry
  → `UnportedMoveEffect` no-op (battle can't crash on an unported move) until the swarm (S5)
  audits + the master wires each. Link-cascade resolutions: the overworld `PrintText` (text.asm)
  was renamed `PrintText_Overworld` so the bare `PrintText` is the battle printer the swarm
  bodies extern (only linked overworld caller, map_sprites.asm, was updated); `CheckTargetSub-
  stitute` is now the faithful helper (battle_stubs no-op removed → MoveHitTest's substitute
  check is real); `stat_mod_effects`/`badge_boosts`/`status_penalties` moved BATTLE_SRCS→
  FRONTEND_SRCS, and the duplicate battle_exp_stubs badge/penalty stubs were deleted.
  `DelayFrames`/`PlayApplyingAttackAnimation` reuse the live frame.asm/animations.asm globals.
  Verified: build green (`SKIP_TITLE=1 DEBUG_BATTLE_LIVE=1`, `make check`), and the enemy-move
  dispatch path ran end-to-end in DOSBox-X (DEBUG_BATTLE_ENEMYHIT) without hang/crash.

## InitBattle (Wave 2 Stage 1a — battle frame + intro text)
- **Source:** front-end scaffold (no single pret label); mirrors the battle screen
  build order in `engine/battle/init_battle.asm` / `core.asm`.
- **Translated:** `dos_port/src/engine/battle/init_battle.asm`
- **Date:** 2026-06-28
- **H-flag:** Not involved.
- **Bug tags:** none.
- **Notes:** Stage 1a renders the battle screen on the **full 320×200 (40×25)
  widescreen canvas** (user direction 2026-06-28: use the wide screen, center the
  default GB UI now, extend elements outward later). Layout: blank the whole 40×25
  `W_TILEMAP` → hand-draw the bottom dialog box at canvas (10,15) → fixed intro text
  "Wild POKéMON / appeared!". The GB 20×18 default layout is centered via col-offset
  10 = (40−20)/2 and row-offset 3 ≈ (25−18)/2.
  **Render path (key, reusable):** the battle screen is the BG plane. `render_bg`'s
  non-overworld branch already decodes the whole 40×25 `W_TILEMAP` straight to the
  back buffer (the title/menu path); it only renders the overworld when
  `wCurrentTileBlockMapViewPointer` is nonzero. So `InitBattle` zeroes that pointer
  + `IO_SCX`/`IO_SCY` and `hide_window`s, and `frame.asm` just calls `render_bg`
  (the Stage-0.5 `clear_backbuffer_battle` + centered-window descriptor are gone).
  No new full-screen renderer was needed.
  **Text-helper constraint:** `TextBoxBorder`/`PlaceString` hardcode a 20-wide
  stride (`text.asm: SCREEN_W_TILES equ 20`), so they cannot lay out into the
  40-wide canvas. The dialog box is hand-drawn with the box-border charmap tiles
  ($79–$7E) at stride 40; single-line text (no `<NEXT>`/`<LINE>`) is
  stride-agnostic, so `PlaceString` still works for HUD names later. The fixed
  intro is raw glyph tile-bytes (renderable glyphs $60+ map 1:1 to tile IDs).
  Also clears `wUpdateSpritesEnabled` so the per-frame `update_oam`/`PrepareOAMData`
  rebuild stops re-showing the overworld player sprite after `ClearSprites`.
  (Superseded the first Stage-0.5/1a centered 20×18 window approach, which hit two
  now-moot gotchas — the stride-20 build and the `wx=87` GB `WX−7` centering.)

## DrawBattleHUDs (Wave 2 Stage 1b — battle HUD boxes + HP bars)
- **Source:** `engine/battle/core.asm` (`DrawEnemyHUDAndHPBar`/`DrawPlayerHUDAndHPBar`)
  + `home/pokemon.asm:DrawHPBar`/`PrintLevel`; logic mirrored from the shipped port
  renderer `src/engine/menus/party_menu.asm`.
- **Translated:** `dos_port/src/engine/battle/battle_hud.asm`
- **Date:** 2026-06-28
- **H-flag:** Not involved.
- **Bug tags:** none.
- **Notes:** Draws enemy HUD (upper-left) + player HUD (lower-right) into the 40×25
  widescreen W_TILEMAP canvas: name (`PlaceString` from `wEnemyMonNick`/`wBattleMonNick`),
  ":L"+level (`print_num2`), 6-segment HP bar (`draw_hp_bar`, fill =
  `calc_hp_pixels` = curHP*48/maxHP, ≥1 sliver if alive), and the player's cur/max HP
  fraction (`print_num3`). Centered = GB coords + (10col, 3row). All writes are linear
  within a row → stride-agnostic, so they work on the 40-wide canvas (vs the
  stride-20-locked TextBoxBorder/multi-line PlaceString). HP-bar gauge tiles ($62-$71,
  ":L"=$6e) loaded by `LoadHpBarAndStatusTilePatterns` (added to `InitBattle`); tiles
  $79-$7F are byte-identical between the box and battle tile sets, so that load does NOT
  clobber the dialog box (load_font.asm's "OVERWRITES $79-$7E" comment is over-cautious —
  verified by comparing the .2bpp bytes). Reads the battle-mon structs; the DEBUG_BATTLE
  harness seeds them until `LoadBattleMonFromParty` lands (Stage 2/3). Deferred: HP-bar
  color (Phase 5 palette), status text, decorative HUD frame/pokeballs.

## FillMemory

- **Source:** `home/copy2.asm:137–155`
- **Translated:** `dos_port/src/util/fill_memory.asm`
- **pret cross-ref:** `FillMemory` (home/copy2.asm)
- **H-flag:** Not involved — pure store loop, no arithmetic.
- **Bug tags:** None. FillMemory is clean.

### Summary

Fills `BC` bytes at `HL` with byte `A`.

### SM83 Analysis

The original uses a double-loop to handle the full 16-bit count in two nested
8-bit decrements. This exists because on the SM83, 16-bit register
decrements (`dec bc`) do not set the Zero flag, so you can't branch on them.
The workaround:

1. If `B == 0`: use C as an 8-bit count directly (less than 256 bytes).
2. If `B != 0 && C == 0`: it's an exact multiple of 256; loop B times without
   incrementing B.
3. If `B != 0 && C != 0`: increment B first, then loop `B+1` times (each inner
   loop does 256 bytes, but the last iteration runs only C bytes before C wraps).

### x86 Translation Decision

`movzx ecx, bx` zero-extends the full 16-bit count into ECX, and `rep stosb`
handles any value 0–65535 correctly. The double-loop trick is not needed.

Edge cases verified:
| BX | SM83 path | x86 ECX | Correct? |
|----|-----------|---------|----------|
| 0x0000 | B=0, C=0, copies 256 bytes (!!) | 0 — no-op | x86 is correct; SM83 has a subtle bug here: if B=0 AND C=0, it enters `.eightbitcopyamount`, increments B to 1, then loops 256 times with dec C starting at 0, which wraps to 255 and counts 256 bytes. **This is a latent SM83 bug.** The game presumably never calls FillMemory with BC=0, but it's worth noting. |
| 0x00FF | B=0, C=255, 8-bit path | 255 — correct | ✓ |
| 0x0100 | B=1, C=0, exact 256 path | 256 — correct | ✓ |
| 0x0101 | B=1, C=1, B incremented to 2 | 257 — correct | ✓ |
| 0xFFFF | B=255, C=255, large count | 65535 — correct | ✓ |

**Edge case: BX=0x0000** — the SM83 FillMemory actually copies 256 bytes when
called with BC=0 (it falls through to the 8-bit path, increments B from 0 to 1,
then loops with C starting at 0 which wraps to 255 after first dec). This is
arguably a SM83 bug. The x86 translation (rep stosb with ECX=0) does nothing
instead. Since the game never calls FillMemory with BC=0 in practice
(confirmed by pret source review), this difference is acceptable. Tagged as:

```nasm
; BUG(cosmetic): BC=0 edge case — SM83 writes 256 bytes; x86 writes 0.
; pret ref: home/copy2.asm:FillMemory
; Game never passes BC=0 in practice. Fixed by /FIXALL for purity.
; %if BUG_FIX_LEVEL >= 2 ... handle BC=0 as no-op ... %endif
; (Currently: x86 behavior is the "fixed" behavior; the SM83 behavior is the bug.)
```

### Register Use

- `EDI`: scratch destination pointer (per register map convention for secondary pointer)
- `ECX`: loop counter — clobbered (callee must not rely on it)
- `ESI`: **preserved** — contains the GB address (HL) unchanged after return
- `EBX`: **preserved** — contains BC (count) unchanged after return
- `EAX`: **preserved** — AL = fill byte, unchanged after return

---

---

## LoadTextBoxTilePatterns

- **Source:** `home/load_font.asm:LoadTextBoxTilePatterns`
- **Translated:** `dos_port/src/gfx/load_font.asm`
- **Date:** 2026-06-13
- **H-flag:** Not involved.
- **Bug tags:** None.

### Summary

Copies the 2bpp box-drawing + extra-character tile data (`gfx/font/font_extra.png`,
32 tiles, chars $60–$7F) to vChars2+$60 at EBP offset $9600.

### Translation Notes

The GB original loads from ROM via FarCopyData/CopyVideoData into VRAM. In the
DOS port, the tile data is embedded as a committed NASM data file
(`assets/font_extra_2bpp.inc`, generated by `tools/gen_font_extra_inc.py`) and
copied directly to the emulated VRAM region with `rep movsd`. No bank-switching
needed. Destination = `GB_VCHARS2 + 0x60 * TILE_SIZE = $9600`.

---

## TextCommandProcessor / PrintText / PlaceString (extended)

- **Source:** `home/text.asm`, `home/window.asm:PrintText`
- **Translated:** `dos_port/src/text/text.asm`
- **Date:** 2026-06-13
- **H-flag:** Not involved.
- **Bug tags:** None.

### Summary

Full two-level text engine:

**Level 1 — TextCommandProcessor**: reads TX_* command bytes (TX_START, TX_BOX,
TX_MOVE, TX_LOW, TX_FAR, TX_END, plus stubs for TX_SCROLL/TX_PROMPT/TX_PAUSE/
sound/dots). TX_FAR skips 3 bytes (no ROM bank switching in flat model). Register
mapping: ESI = command stream (HL), EBX = tile cursor (BC).

**Level 2 — PlaceString extension**: all 20 dictionary control codes added
($00–$5F):

| Code | Name | Implementation |
|------|------|----------------|
| $00 | `<NULL>` | Silent terminator |
| $49 | `<PAGE>` | Skip (stub) |
| $4A | `<PKMN>` | Print "PK MN" ($E1,$E2) |
| $4B | `<_CONT>` | Scroll stub |
| $4C | `<SCROLL>` | Scroll stub |
| $51 | `<PARA>` | Paragraph stub |
| $52 | `<PLAYER>` | Loop-copy wPlayerName ($D158, TODO: verify) |
| $53 | `<RIVAL>` | Loop-copy wRivalName ($D34A, TODO: verify) |
| $54 | `#` | Print "POKé" |
| $55 | `<CONT>` | Scroll stub |
| $56 | `<……>` | Print "……" |
| $57 | `<DONE>` | Terminate via DONE_SENTINEL_WRAM |
| $58 | `<PROMPT>` | Stub |
| $59 | `<TARGET>` | Skip |
| $5A | `<USER>` | Skip |
| $5B | `<PC>` | Print "PC" |
| $5C | `<TM>` | Print "TM" |
| $5D | `<TRAINER>` | Print "TRAINER" |
| $5E | `<ROCKET>` | Print "ROCKET" |
| $5F | `<DEXEND>` | Print ".", terminate |

**PrintText**: draws MESSAGE_BOX border (interior 18×4 at tile coord (0,12)),
sets cursor to (1,14), tail-calls TextCommandProcessor.

### Key Phase 2 Stubs

- `manual_text_scroll`: returns immediately (no button wait). Full
  implementation needs joypad polling integrated into text flow.
- `scroll_text_up`: no-op. Full implementation needs tile-buffer row copy.
- TX_FAR: skips 3 bytes. Full implementation needs ROM data staged in EBP
  space so inline far-text can be read.
- `<PLAYER>`/`<RIVAL>` addresses (W_PLAYER_NAME=$D158, W_RIVAL_NAME=$D34A)
  must be verified against pokeyellow.sym when ROM build is available.

### CHAR_DONE ($57) Mechanism

`<DONE>` needs to terminate TextCommandProcessor from inside PlaceString.
The SM83 does this via a `ld de, .stop-1; ret` pattern that unwinds the call
chain. In x86, PlaceString returns to TextCommandProcessor's `.cmd_start`
handler with EDX pointing at a sentinel. A two-byte TX_END sequence at
`DONE_SENTINEL_WRAM` (= $C0F0) lets TextCommandProcessor exit cleanly:
- PlaceString sets EDX = DONE_SENTINEL_WRAM, returns
- `.cmd_start` does `mov esi, edx; inc esi` → ESI = $C0F1
- `.next_cmd` reads `[ebp + $C0F1]` = TX_END → done

`text_engine_init` writes the two TX_END bytes at startup.

### Inline Substitution Strings

Static strings (POKé, TM, PC, TRAINER, ROCKET, ……, PK/MN, ".") live in DS and
are written by `place_flat_str`, which reads via `[EAX]` (flat) rather than
`[EBP + EDX]` (GB-relative). Player/rival names use a dedicated EBP-relative
loop since they live in WRAM.

*Add new entries below as routines are translated.*

---

## PrepareTitleScreen / DisplayTitleScreen

- **Source:** `engine/movie/title.asm:PrepareTitleScreen`, `engine/movie/title_yellow.asm`
- **Translated:** `dos_port/src/movie/title.asm`
- **Date:** 2026-06-13
- **H-flag:** Not involved.
- **Bug tags:** None in the translated code; original glitches (Pikachu eye blink timer 0/$80/$90) preserved faithfully.

### Summary

Full title screen: graphics load, bounce animation, blink state machine, input idle loop.

### Key decisions

**Two-tilemap bounce trick:** Physical tilemap 0 ($9800) is used in two configurations,
selected by `hAutoBGTransferDest` hi byte ($98 = row 0, $9B = row 24). `do_bg_transfer`
in `frame.asm` copies the 20-wide `wTileMap` shadow into the 32-wide physical tilemap
with stride handling and 1 KB wrap. The bounce animation starts with `hSCY=64` (showing
row 8 of the physical tilemap downward), bouncing to `hSCY=0` to reveal the full logo.

**Pikachu appearance:** After the bounce settles, `LoadScreenTilesFromBuffer1` restores
the logo+pikachu map and `DelayFrames(36)` commits it via auto-BG transfer.

**Asset loading:** All title graphics come from `.inc` files generated by
`tools/gen_title_gfx_inc.py` (PNG→2bpp). `FarCopyData` is not used for program-image
sources; direct `rep movsb` is used instead (CopyData/FarCopyData add EBP which would
corrupt flat pointers).

**VRAM layout (signed tile mode, LCDC_DEFAULT=$E3, bit4=0, base $9000):**

| Address   | Content                        | Tile indices used    |
|-----------|--------------------------------|----------------------|
| $8800     | Pikachu BG tiles (64 tiles)    | $80–$BF (signed −)   |
| $8E00     | Nintendo copyright (5 tiles)   | $E0–$E4 (signed −)   |
| $8E50     | GameFreak inc. logo (9 tiles)  | $E5–$ED (signed −)   |
| $8EE0     | Nine tile (1 tile)             | $EE (signed −)       |
| $8F00     | Pikachu OBJ sprites (12 tiles) | $F0–$FB (signed −)   |
| $8FD0     | Logo corner tiles (3 tiles)    | $FD–$FF (signed −)   |
| $9000     | Pokemon logo (128 tiles)       | $00–$7F (signed +)   |

**Phase stubs:** Audio (PlaySound, StopAllMusic, PCM), CGB palette (RunPaletteCommand,
UpdateCGBPal_OBP0), SRAM (FillSpriteBuffer0WithAA), OAM renderer (sprite eye blink
writes are correct but invisible until Phase 1 OAM pass), MainMenu (→ EnterMap Phase 2).

---

## Overworld Engine (Phase 2)

- **Sources:** `home/overworld.asm` — ResetMapVariables, CopyMapViewToVRAM, DrawTileBlock,
  LoadCurrentMapView, LoadTilesetTilePatternData, LoadTileBlockMap, LoadScreenRelatedData,
  LoadMapData; Phase 2 scaffold: EnterMap/SetupPalletTown/OverworldLoop
- **Translated:** `dos_port/src/engine/overworld/overworld.asm`
- **Date:** 2026-06-13
- **H-flag:** Not involved — all pure data movement.
- **Bug tags:** None.

### Key decisions

**Asset layout in ROM window ($4000–$4EFF):** The original reads tileset GFX,
blockset, and map data from ROM banks via FarCopyData. In the flat model, Phase 2
embeds these as NASM `.rodata` and copies them to `[EBP + $4000]` at map load.
`wTilesetGfxPtr = $4000`, `wTilesetBlocksPtr = $4600`, `wCurMapDataPtr = $4E00`.
Faithful routines index off these 16-bit pointers unchanged.

**Tileset addressing:** `vTileset = $9000` (sym-confirmed). LCDC bit 4 = 0
(signed mode). Tile IDs 0–93 map to $9000 + id×16. Font at $8800 coexists
(IDs $80–$FF, negative signed). `LoadTilesetTilePatternData` copies $600 bytes;
the trimmed .2bpp (1504 B) uses the remaining 32 bytes as DPMI-zeroed blanks.

**DrawTileBlock:** SM83 `swap a` / mask to compute `blockID × 16` replaced with
`shl eax, 4` — semantically identical, cleaner.

**Connection strips:** Phase 2 sets all connected maps to $FF; strip-load code
is translated but skipped. TODOs in place for player movement phase.

**WRAM address corrections (2026-06-13):** gb_memmap.inc updated with all
sym-verified addresses. Key corrections: `wPlayerName` ($D158→$D157),
`wRivalName` ($D34A→$D349), `wTileMapBackup2` ($D300→$CD81),
`wTitleScreenScene` ($D200→$CD3D), and ~8 audio/status variables relocated
from placeholder $D20x range to their true WRAM0 addresses. Title screen
unaffected (zeroed wrong WRAM before; correct zeroing now, same visual result).

---

## Player movement — `src/engine/overworld/overworld.asm` (2026-06-14)

Translated the movement-relevant subset of `home/overworld.asm:OverworldLoop` /
`OverworldLoopLessDelay` plus the helpers from
`engine/overworld/advance_player_sprite.asm`, `home/vcopy.asm:RedrawRowOrColumn`,
and the collision path (`CollisionCheckOnLand` → `_GetTileAndCoordsInFrontOfPlayer`
→ `_IsTilePassable`).

### Routines

- **OverworldLoop / OverworldLoopLessDelay** — joypad state machine. Two
  `DelayFrame`s per iteration (matches the original ~16-frame/step cadence). Idle:
  sample `hJoyHeld`, set the X/Y step vector + facing + `wPlayerDirection`,
  collision-check, and arm `wWalkCounter = 8`. Mid-step: `AdvancePlayerSprite`.
- **AdvancePlayerSprite** (`_AdvancePlayerSprite`) — on the first step frame
  (counter == 7) slides `wMapViewVRAMPointer` by 2 tiles, crosses a block via
  `MoveTileBlockMapPointer{East,West,South,North}`, rebuilds the view with
  `LoadCurrentMapView`, and schedules the exposed edge. Every frame scrolls
  `hSCX`/`hSCY` by ±2 px.
- **RedrawRowOrColumn** + **Schedule{North,South}RowRedraw** /
  **Schedule{East,West}ColumnRedraw** + helpers — the sliding-window VRAM update.
  `RedrawRowOrColumn` is exported and called from `frame.asm:DelayFrame` (the GB
  VBlank-order slot), so only the 2 freshly exposed rows/cols are rewritten per
  step while `hSCX`/`hSCY` grow unbounded (renderer wraps the 32×32 VRAM at 256 px).
- **CollisionCheckOnLand / GetTileInFrontOfPlayer / IsTilePassable** — land
  passability only. `GetTileInFrontOfPlayer` reads `wTileMap` at the fixed
  per-facing screen coords; `IsTilePassable` scans the `$FF`-terminated list at
  `wTilesetCollisionPtr`.

### Key decisions

- **Auto-BG transfer off in the overworld:** `H_AUTO_BG_TRANSFER_EN = 0` in
  `SetupPalletTown`. Otherwise `do_bg_transfer` re-blits `wTileMap` to `$9800`
  every frame and fights `RedrawRowOrColumn` (matches the original, which disables
  auto-transfer while walking).
- **Collision data embedded:** `gen_overworld_assets.py` now parses
  `data/tilesets/collision_tile_ids.asm` for `Overworld_Coll` →
  `assets/overworld_coll.inc`, copied to ROM window `OW_COLL_GBADDR` ($4F00);
  `wTilesetCollisionPtr` points there.
- **Player marker placeholder:** `draw_player_marker` (ppu.asm) paints a 16×16
  two-tone box at the fixed player screen center, gated by `g_player_marker_on`
  (set in the overworld, off on the title). Stands in until the OAM sprite
  renderer (Phase 1 open item) lands.
- **32-bit gotcha:** `dil`/`sil` byte registers do not exist outside long mode;
  low-byte-of-EDI arithmetic uses `mov eax, edi` / `and eax, 0xFF` instead.

### Phase 2 omissions vs. pret

OAM sprite-shift loop, `IsSpinning`, ledges, tile-pair collisions, sprite
collisions, warps, `CheckMapConnections`, NPCs, battles, and scripted movement.

### Verification

Built `SKIP_TITLE=1`; verified in DOSBox-X and user-confirmed: walking in all
four directions scrolls Pallet Town smoothly with correct tiles at the newly
exposed edges, trees/buildings block movement, and the placeholder marker tracks
the screen center.

---

## OAM sprite renderer + player sprite — `src/ppu/ppu.asm`, `src/engine/overworld/overworld.asm` (2026-06-14)

HAL renderer (not a pret translation) plus an overworld scaffold to drive it.

### Routines

- **render_sprites** (ppu.asm) — DMG OBJ emulation in 8×8 mode. Reads the 40 OAM
  entries at `$FE00` (Y, X, tile, attr), blits each 8×8 tile from the OBJ tile
  area (`$8000`, unsigned), honoring X/Y flip, OBP0/OBP1 (color 0 = transparent),
  and the BG-priority bit (attr bit 7 → draw only over back-buffer shade 0, which
  equals BG color 0 under the standard `BGP=$E4`). Called from
  `frame.asm:DelayFrame` right after `render_bg`.
- **LoadPlayerSpriteGraphics** (overworld.asm, scaffold) — copies the 24-tile Red
  sprite (`gfx/sprites/red.2bpp`, embedded via `gen_overworld_assets.py` →
  `assets/player_sprite.inc`) to `$8000` and zeroes OAM. Called from `LoadMapData`
  where pret calls the real `LoadPlayerSpriteGraphics`.
- **UpdatePlayerOAM** (overworld.asm, scaffold) — writes the player's four OAM
  entries each frame for the current facing, composing the 16×16 standing pose
  from tiles 0–11 via `player_oam_table` (derived from `data/sprites/facings.asm`).
  Player is camera-locked at screen pixel (64,64); the BG scrolls under it.

### Key decisions / gotchas

- **OAM byte order** is Y, X, tile, attr (verified against `PrepareOAMData`'s read
  sequence — the "attributes, tile index" comment in `facings.asm` is mislabeled).
- DMG sprite priority is simplified to **reverse-OAM-order draw** (lower index on
  top) — honors the index tiebreak but not the smaller-X-wins rule; no
  10-per-scanline limit; 8×16 OBJ size unhandled (overworld/menus use 8×8).
- The earlier `draw_player_marker` placeholder is now disabled
  (`g_player_marker_on = 0`) but kept as a gated fallback.

### Verification

`SKIP_TITLE=1`: the Red player sprite renders camera-locked at screen center over
Pallet Town and faces the direction of movement.

---

## Sprite engine — `src/gfx/sprite_oam.asm`, `src/engine/overworld/movement.asm` (2026-06-15)

Replaced the `UpdatePlayerOAM` / `player_oam_table` scaffold with a faithful
translation of the Yellow sprite engine, so the player renders through the real
shadow-OAM pipeline driven by `wSpriteStateData1/2` (slots 0–15). NPC slots are
inert (picture ID 0) but the loop, priority, and tile logic are the real engine,
so NPCs render the moment a map fills their slots.

### Routines

- **PrepareOAMData** (sprite_oam.asm) — faithful translation of
  `engine/gfx/sprite_oam.asm:PrepareOAMData` (Yellow). Iterates the 16 sprite
  slots; for each visible sprite (picture ID ≠ 0, image index ≠ `$ff`) it indexes
  `SpriteFacingAndAnimationTable` by `imageIndex & $f`, reads `Y/X` from the slot,
  and writes the pose's OAM entries into `wShadowOAM` (`$C300`). Handles the
  under-grass BG-priority bit, OBP0/OBP1 → CGB high-palette mapping, the `$80+`
  tile → Pikachu-VRAM-offset path, the OAM-overflow guard, and clearing unused
  entries to `Y=$a0`. Plus `GetSpriteScreenXY` and `Func_4a7b` (VRAM base tile).
  The full `SpriteFacingAndAnimationTable` + facing data is embedded (a `dd` table
  of absolute label addresses, indexed `*4`, vs pret's `dw` of GB addresses).
- **UpdateSprites / _UpdateSprites / UpdatePlayerSprite** (movement.asm) — faithful
  translation of the player path of `home/update_sprites.asm` +
  `engine/overworld/sprite_collisions.asm:_UpdateSprites` +
  `engine/overworld/movement.asm:UpdatePlayerSprite` (with `Func_4e32`,
  `Func_5274`). Sets the player's facing from `wPlayerMovingDirection`, advances
  the walk-animation counters (intra-anim → anim-frame every 4 ticks), recomputes
  the image index (`facing + animFrame`), and sets grass priority. Called once per
  `OverworldLoop` iteration.
- **frame.asm:update_oam** — runs `PrepareOAMData` then DMA-copies `wShadowOAM` →
  OAM (`$FE00`) each `DelayFrame`, gated on `wUpdateSpritesEnabled` (mirrors the GB
  VBlank `PrepareOAMData` + `hDMARoutine`; gating keeps the title screen's own
  shadow-OAM writes from being force-copied).
- **LoadPlayerSpriteGraphics** (overworld.asm) — now loads Red's standing tiles
  (0–11) to `$8000` (OBJ `$00–$0B`) and walking tiles (12–23) to `$8800`
  (OBJ `$80–$8B`), the layout the engine indexes; walking tiles time-share vChars1
  with the text font exactly as on the GB.

### Key decisions / gotchas

- **Stub boundaries:** `DetectCollisionBetweenSprites` (no NPCs to collide) and
  `UpdateNonPlayerSprite` (NPC engine) are no-ops; the spinning-tile path is inert
  (`wMovementFlags` stays 0). All marked `; TODO`.
- **32-bit register trap:** `sil`/`dil` are not byte-addressable without REX, so
  slot-offset byte stores go through `al` (mov eax, esi / mov [..], al).
- **Player screen position** is the original's fixed `YPixels=$3c`, `XPixels=$40`
  (slightly above geometric center), per `home/reset_player_sprite.asm`.

### Verification

`SKIP_TITLE=1 DEBUG_DUMP=1` with a one-shot `UpdateSprites`+`PrepareOAMData` before
the dump: `wSpritePlayerStateData1` = pictureID 1 / imageIndex 0 / Y `$3c` / X
`$40` / facing 0; `wSpriteStateData2` imageBaseOffset 1; shadow OAM slot 0 holds
the four StandingDown entries `($4c,$48,$00) ($4c,$50,$01) ($54,$48,$02)
($54,$50,$03)` (attrs masked to 0, not in grass) and entry 4 = `$a0` (hidden);
standing tiles present at `$8000`, distinct walking tiles at `$8800`. Default and
`SKIP_TITLE=1` builds link clean.

---

## BG scanline rewrite + DrawTileBlock clamp — `src/ppu/ppu.asm`, `src/engine/overworld/overworld.asm` (2026-06-15)

- **Sources:** HAL renderer (`render_bg`, not a pret translation); `DrawTileBlock`
  (`home/overworld.asm`).
- **H-flag:** Not involved.
- **Bug tags:** None (fixes to our own port code, not pret bugs).

### render_bg — pixel-smooth scrolling

Replaced the tile-blitter (each tile written to a fixed `tile_col*8` / `tile_row*8`
slot) with a **scanline renderer**. Per output scanline: compute
`world_y = (y + SCY) & 0xFF`, derive the tilemap row + `(world_y & 7)*2` source-row
offset, decode 41 tiles (40 visible + 1 for the sub-tile shift) into a virtual line
buffer (`bg_scanline_buf`), then `rep movsb` 320 px starting at `bg_fine_x = SCX & 7`
into the back buffer.

- **Why:** the blitter applied neither `SCX & 7` (horizontal scroll only moved on
  8-px boundaries) nor a per-scanline tilemap-row fetch (its single-tile 8-row
  decode overflowed into the next *VRAM* tile, not the next *tilemap* row). Both
  axes are now pixel-smooth.
- **Cost:** ~200×41 tile-row decodes/frame vs. the blitter's 1000 tile decodes —
  more work, traded for correctness. (Note: this runs counter to the perf goal of
  the open "VGA-native renderer" refactor in TODO.md Phase 2; revisit there.)
- `stosb`/`rep movsb` to/from the flat `.bss` line buffer mirror `decode_win_row` /
  `render_window` (ES base == DS base after `setup_flat_access`).

### DrawTileBlock — out-of-range block clamp (TEMPORARY)

Added a clamp: if `wTilesetBlocksPtr + blockID*16` lands past the embedded blockset
(`OW_BLOCKS_GBADDR + OVERWORLD_BLOCKS_SIZE`), substitute block 0.

- **Why:** the extended 40×25-tile viewport draws a larger area than the original
  20×18, so the camera can reach into uninitialized `wOverworldMap` padding and
  hand `DrawTileBlock` a block ID past the 128-block embedded blockset; the read
  then walks off the blockset and paints garbage. No GB equivalent (there the
  blockset fills a bank and map data is bounded by the loader).
- **Temporary:** this is a stopgap. The plan is to **extend the map data** so those
  regions hold real blocks (no blank area from the extended draw), after which the
  clamp is dead code and should be deleted. Tracked in TODO.md (Phase 2) and noted
  in CLAUDE.md + a code comment at the clamp site.

### render_window — bottom-of-screen garbage fix (2026-06-15)

Symptom: red/green vertical lines at the bottom-right of the overworld (pixel
values >3, indexing the leftover `test_palette` ramps). Two compounding causes:

- `LCDC_DEFAULT_VAL = 0xE3` enables the window (bit 5) — the real Pokémon value.
  The game parks it at `WY=144` to hide it on the 144-px GB screen, but our
  viewport is 200 px, so rows 144–199 rendered the parked (uninitialized) window.
  **Fix:** bound the window scanline loop at `SCREEN_H` (144), not `RENDER_H`
  (200), preserving the GB park semantics. (A textbox for the full 200-px viewport
  is future window-layer work.)
- The `wx_adj ≥ 0` copy path lacked a length clamp (the left-clip path has one) and
  copied up to `RENDER_W` (320) bytes from the 256-byte `row_buf`, spilling into
  adjacent BSS. **Fix:** clamp the copy to 256.

Verified 2026-06-15 in DOSBox-X: initial render clean; single-step scroll in all
four directions clean. See docs/session_handoff.md for the remaining open items
(render speed, map connections, facing-down collision ±1-vs-±2).

### render_bg — decoded-tile cache optimization (2026-06-15)

`render_bg` previously bit-decoded 41 tiles × 200 scanlines (2bpp→8bpp via a
`shl`/`rcl` loop) **every frame** — ~65k px/frame of per-pixel decode, the
overworld's hot path. Replaced with a **pre-decoded tile cache**:

- `tile_cache` (BSS, 384 tiles × 64 B = 24 KB) holds the whole BG/window
  tile-data region ($8000-$97FF) decoded to 8bpp, BGP shade baked in.
- `rebuild_tile_cache` decodes all 384 tiles in one linear pass and records the
  BGP used. `render_bg` calls it only when `g_tilecache_dirty` is set **or**
  `IO_BGP` changed since the last build — so a static, scrolling map reuses the
  cache and does ~zero decode work. The per-tile inner loop is now two 4-byte
  `mov`-pair copies (`tile_cache → bg_scanline_buf`); the `SCX & 7` scanline
  buffer + 320 px copy for smooth horizontal scroll is unchanged.
- `g_tilecache_dirty` lives in `.data` initialized to 1 (first frame builds the
  cache) and is set by every VRAM tile-data writer: `LoadFontTilePatterns`,
  `LoadTextBoxTilePatterns`, `LoadYellowTitleScreenGFX`,
  `LoadTilesetTilePatternData`, `LoadPlayerSpriteGraphics`,
  `SetupPalletTownNPCs`, `ClearVram`. BGP/palette changes are auto-detected.

Faithful to behavior (cache is a pure decode of the same VRAM + BGP the
per-pixel path read). Follows docs/386_optimization_strategy.md (cache decode
out of the hot loop, 32-bit moves, scaled-index addressing). Verified
pixel-identical to the pre-optimization Pallet Town render (SKIP_TITLE
screenshot, 2026-06-15). **Invariant for future work:** any new routine that
writes VRAM tile data must set `g_tilecache_dirty`.

### Renderer — raw color indices + DAC palette (Tier 2 step 1, 2026-06-15)

The PPU renderer no longer bakes BGP/OBP shades into framebuffer pixels. It writes
**raw GB color indices** and the VGA DAC maps them: BG/window color 0-3 → DAC 0-3,
sprite OBP0 → 4+color (DAC 4-7), OBP1 → 8+color (DAC 8-11). New `commit_palette`
(boot/video.asm) programs DAC 0-11 from BGP/OBP0/OBP1 (consecutive regs
$FF47-49) using `dmg_palette`, skipping when unchanged; called per frame in
`DelayFrame` after `commit_shadow_regs`. Dropped `bgp_tab`/`obp_tab`/
`g_tilecache_bgp` and the BGP-driven tile-cache rebuild — `tile_cache` now holds
raw color and depends only on `g_tilecache_dirty`. A palette fade/flash is now a
DAC reprogram, not a tile re-decode (cheaper + more faithful). Byte-identical
output at the normal BGP/OBP (identity) mapping; verified via `./test_render.sh`
(BG + player/NPC sprites correct). **Invariant:** code that writes the back buffer
directly must use the raw-index convention, not shade values. Part of the Tier 2
plan (docs/render_tier2_plan.md); progress tracked in docs/render_opt_handoff.md.

### render_bg — direct-to-backbuffer assembly (Tier 2 step 2, 2026-06-15)

Removed the redundant per-scanline copy. `render_bg` previously decoded 41 tiles
into `bg_scanline_buf` then `rep movsb`-copied 320 px into the back buffer at the
`SCX&7` offset; now it assembles each scanline **directly into the back buffer**
in one pass (~192 KB → ~128 KB frame traffic). The fine offset is handled by
writing each tile at `dest_pos = tile_col*8 - fine_x` with per-tile left/right
clipping (`bg_row_ptr` = row start): tile 0 left-clips `fine_x` px, the last tile
right-clips to remaining room; `fine_x=0` → 40 full tiles, `fine_x>0` → tiles 0
and 40 partial = exactly 320 px. Kept the back buffer + `present` (window/sprite
compositing stays in fast RAM; avoids slow VGA reads for sprite BG-priority).
Removed BSS `bg_scanline_buf` and dead `bg_fine_y2`; added `bg_row_ptr`. Verified
pixel-correct (sub-tile fine offset intact) via `./test_render.sh`.

### render_bg — offscreen surface mirror + viewport blit (Tier 2 step 3, 2026-06-15)

`render_bg` no longer resolves tiles per scanline. A `bg_surface` (256×256 chunky
raw-color, BSS) mirrors the *decoded* BG tilemap torus; each frame the renderer
(1) diffs the live VRAM tilemap against `bg_tilemap_shadow` and re-decodes only
changed tiles into the surface (`sync_surface_diff` → `surf_decode_tile`), with a
full `rebuild_surface_full` on `g_tilecache_dirty` or a tilemap-base switch, then
(2) blits a 320×200 window at `(SCX,SCY)` with 256-px torus wrap (1–2 `rep movsb`
per row). Eliminates the per-frame per-tile addressing and the 40-into-32 fold;
sampling matches the old renderer (BG pixel (x,y) = surface ((SCX+x)&255,
(SCY+y)&255)). **Decoupled** — we mirror by VRAM tilemap *address*, so the
faithful sliding-window scroll + `RedrawRowOrColumn` edge redraw need no changes
(their tilemap writes show up in the diff). `tile_cache` kept as the decoded
tile-data source the surface copies from. New BSS: `bg_surface` (64 KB),
`bg_tilemap_shadow` (1 KB), `surf_last_base`; removed the per-scanline scratch.
Verified: clean-boot render matches known-good Pallet Town; user-driven scrolling
renders clean aligned tiles with no stale strips/seams (only the pre-existing
missing-connector junk remains). Completes the Tier 2 render-opt quest
(docs/render_opt_handoff.md).

### LoadTileBlockMap connection strips + Load{NS,EW}ConnectionsTileMap (2026-06-15)

Un-stubbed the map-connection logic in `LoadTileBlockMap` and translated
`LoadNorthSouthConnectionsTileMap` / `LoadEastWestConnectionsTileMap` (pret:
home/overworld.asm). For each connected direction (≠ $FF) the strip header
(src/dest/length/connected-map-width) is loaded and the connected map's edge is
copied into the wOverworldMap border: N/S copies MAP_BORDER rows × strip-width,
E/W copies strip-length rows × MAP_BORDER cols; src advances by the connected map
width, dest by the wOverworldMap stride (wCurMapWidth + 2·MAP_BORDER).
`SwitchToMapRomBank` is a no-op (flat model); 16-bit pointer math becomes plain
32-bit `add` on the GB-offset registers. The hNorthSouthConnectionStripWidth /
connected-map-width HRAM reuse H_MAP_STRIDE/H_MAP_WIDTH (faithful unions).

Scaffold wiring (SetupPalletTown, NOT a faithful LoadMapHeader): Pallet Town
connects north→Route1, south→Route21. Route1.blk (10×18) / Route21.blk (10×45)
are embedded (tools/gen_overworld_assets.py → assets/route1_blk.inc,
route21_blk.inc) and copied to OW_ROUTE1_BLK_GBADDR ($5000) /
OW_ROUTE21_BLK_GBADDR ($5200). The connection-struct field values (strip
src/dest, length, width, Y/X-align, view-ptr) were precomputed from the pret
`connection` macro (macros/scripts/maps.asm) for offset-0 connections and set as
constants. Connection-struct field offsets added to gb_memmap.inc (CONN_*).

Dump-verified (2026-06-15): wOverworldMap north border rows 0-2 cols 3-12 ==
Route 1 rows 15-17; south border rows 12-14 cols 3-12 == Route 21 rows 0-2;
connection structs at $D370/$D37B match the computed bytes. Boot render
unchanged (strips are off-screen until you walk to the edge). **Scope:** this is
strip *loading* only — the map-*transition* trigger (crossing into the connected
map) is a separate follow-on; the DrawTileBlock clamp stays (E/W + past-map-end).

## Native-width BG renderer (Stage A)

- **Sources:** `dos_port/src/ppu/ppu.asm`, `dos_port/src/engine/overworld/overworld.asm`
- **Date:** 2026-06-16
- **H-flag:** Not involved.
- **Bug tags:** None.

### Summary

Rewrote `render_bg` to naturally decode `wSurroundingTiles` (44x32) into a native 352x256 surface, eliminating the 256px GB VRAM torus wrap and duplicated columns.
Smooth fine-scroll is now applied natively via offset to the viewport blit using `+ signed(H_SCX/H_SCY)`.
Removed dead VRAM-ring scroll routines (`CopyMapViewToVRAM`, `FillExtraVRAMRows`, `RedrawRowOrColumn`) and simplified `AdvancePlayerSprite`.

*Add new entries below as routines are translated.*

---

## Movement delay + door-exit logic fixes — `src/engine/overworld/overworld.asm` (2026-06-20)

- **Sources:** `home/overworld.asm` (OverworldLoop / WarpFound2.done),
  `engine/overworld/movement.asm` (UpdatePlayerSprite/.handleDirectionButtonPress),
  `engine/overworld/auto_movement.asm` (PlayerStepOutFromDoor)
- **Date:** 2026-06-20
- **H-flag:** Not involved.
- **Bug tags:** None (port correctness fixes, not pret bugs).

### Bug 1 — Movement delay (`.startWalk` → `jmp OverworldLoop`)

**Symptom:** holding any direction felt "discrete" — each step had a visible pause
before the first pixel moved, making smooth scrolling feel sluggish.

**Root cause:** after setting `wWalkCounter = 8`, the port jumped back to
`OverworldLoop`, passing through another `UpdateSprites` + 2×`DelayFrame` (2 extra
frames) before reaching the first `AdvancePlayerSprite`. In the original, `.noCollision`
falls straight to `.moveAhead2` (AdvancePlayerSprite) in the same iteration:
`ld a, 8 / ld [wWalkCounter], a / callfar Func_fcc08 / jr .moveAhead2`.

**Fix:** `.startWalk` now jumps to `.moveAhead` (the port's equivalent of `.moveAhead2`)
instead of `OverworldLoop`. First pixel movement happens in the same loop iteration as
the step is armed, matching the original's 16-frame/step cadence exactly. This also
fixes the door-exit step delay (same code path).

### Bug 2 — Door-exit iteration skipped (`jmp OverworldLoop.lessDelay`)

**Symptom:** after a warp arrival the player stood still for an extra loop iteration
(2 frames) before the auto-walk fired.

**Root cause:** `.warpTransition` jumped to `OverworldLoop.lessDelay`, skipping
`RunNPCMovementScript` on the first post-warp iteration. In the original,
`WarpFound2.done` calls `jp EnterMap` which falls into `OverworldLoop` (top), so
`RunNPCMovementScript` → `PlayerStepOutFromDoor` fires on the very first frame.

**Fix:** `.warpTransition` now jumps to `OverworldLoop` (top). Map state is fully
loaded by `LoadWarpDestination` before the jump, so this is safe.

### Bug 3 — Scripted movement didn't bypass 180° turn-delay

**Root cause:** the port's `.handleDirection` applied the turn-delay check even during
scripted movement (door auto-walk). The original has an explicit guard:
`bit BIT_SCRIPTED_MOVEMENT_STATE / jr nz, .noDirectionChange`. The previous port
worked around this by priming `wPlayerLastStopDirection = PLAYER_DIR_DOWN` in
`PlayerStepOutFromDoor` — fragile and wrong.

**Fix:** added `test BIT_SCRIPTED_MOVEMENT_STATE / jnz .walkStart` at the top of
`.handleDirection`, before the turn-delay check. Removed the `wPlayerLastStopDirection`
prime from `PlayerStepOutFromDoor`.

### `LoadCurrentMapView` in `CollisionCheckOnLand` — why it's required

`LoadCurrentMapView` rebuilds `wSurroundingTiles` from the block map AND copies a
sub-block-offset viewport into `wTileMap` based on `W_Y_BLOCK_COORD`/`W_X_BLOCK_COORD`.
`AdvancePlayerSprite` only calls it on block-boundary crossings. Between crossings
YBC/XBC can advance 0→1 without triggering a rebuild, leaving `wTileMap` at the
previous sub-block viewport offset. `GetTileInFrontOfPlayer` then reads the wrong tile.

Symptom: walking toward a 2×2 cluster of impassable tiles (route 1 bushes, building
outer walls, ledges) sporadically passes through — at the half-block sub-step the
tile read lands on the adjacent passable tile instead of the correct one. The call is
retained in `CollisionCheckOnLand`. A future optimisation could split out just the
viewport-copy step (lines 1114–1135) since `wSurroundingTiles` is already current.

### Also in this commit

- **`gb_memmap.inc`:** added `BIT_STANDING_ON_DOOR`, `BIT_EXITING_DOOR`,
  `BIT_STANDING_ON_WARP`, `BIT_DISABLE_JOYPAD`, `BIT_SCRIPTED_MOVEMENT_STATE`
  constants; `W_JOY_IGNORE`, `W_SIMULATED_JOYPAD_STATES_END`,
  `W_SIMULATED_JOYPAD_STATES_INDEX`, `W_IGNORE_INPUT_COUNTER` addresses.
- **`assets/map_headers.inc`:** removed `IF DEF(_DEBUG)` debug warps from
  `REDS_HOUSE_2F` (those 4 extra warp entries only exist in a debug build of the
  original; the port is not a debug build).

---

## Math (Multiply / Divide)

- **Source:** `home/math.asm`
- **Translated:** `dos_port/home/math.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

Implemented as wrapper skeletons (`Multiply`, `Divide`) that call external implementations (`_Multiply`, `_Divide`). Preserves SM83 caller state around the external calls via stack pushes.

---

## CountSetBits

- **Source:** `home/count_set_bits.asm`
- **Translated:** `dos_port/home/count_set_bits.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

Loop structure preserved, counts bits in a string of bytes. Shift-and-carry approach retained using `shr` and `adc`.

---

## StringCmp

- **Source:** `home/compare.asm`
- **Translated:** `dos_port/home/compare.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

Uses standard `cmp` loop comparing bytes at ESI and EDX (representing HL and DE).

---

## Random

- **Source:** `home/random.asm`
- **Translated:** `dos_port/home/random.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

Wrapper skeleton. Calls `Random_` and then fetches `hRandomAdd` to return random value in AL. Preserves caller state.

---

## Copy Routines (FarCopyData / CopyData)

- **Source:** `home/copy.asm`
- **Translated:** `dos_port/home/copy.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

- **CopyData** implements a 32-bit block move optimization. Instead of an 8-bit copy loop, it processes the copy in 4-byte (`DWORD`) chunks where possible via a `cmp ecx, 4` sub-loop, dropping to 1-byte copies for the remainder. This significantly reduces memory bus utilization per the 386 optimization strategy.
- Video copy routines (`CopyVideoDataAlternate`, `CopyVideoDataDoubleAlternate`) check LCDC bit 7 to selectively branch to `CopyVideoData` or `CopyVideoDataDouble` with register preservation and bit manipulation intact.
- Far routines (`FarCopyData`) wrap bankswitching with pushes.

---

## Array Operations (SkipFixedLengthTextEntries / AddNTimes)

- **Source:** `home/array.asm`
- **Translated:** `dos_port/home/array.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

**Excellent strength reduction.** The original SM83 looped AL times doing `add HL, BC`. The x86 translation replaces the iterative loops with a single `imul ecx, eax` followed by `add esi, ecx`, converting an O(N) loop into an O(1) mathematical operation. This perfectly aligns with the performance goals of the 386 port strategy.

---

## Multiply / Divide Logic (_Multiply / _Divide)

- **Source:** `main.asm` (math routines)
- **Translated:** `dos_port/src/util/multiply_divide.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

- `_Multiply` discards the original 8-bit iterative addition loop and leverages the native 386 hardware `mul` instruction. It reconstructs the 24-bit multiplicand into a 32-bit register (`EAX`), multiplies by the 8-bit multiplier (`ECX`), and cleanly writes the 32-bit product back to `H_PRODUCT` in big-endian format. Perfect O(1) cycle implementation.
- `_Divide` maintains faithful step-by-step subtraction logic to accurately preserve Game Boy memory side-effects and byte alignments for `hDividend` and `hDivideBuffer`, but caches the operations in 32-bit registers (`EAX`, `EDI`, `EDX`) to avoid heavy memory access penalties.

---

## BCD Math (AddBCD / SubBCD / DivideBCD)

- **Source:** `main.asm` (BCD routines)
- **Translated:** `dos_port/src/util/bcd.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

**Brilliant hardware optimization:** The translated `AddBCD` and `SubBCD` completely replace the Game Boy's manual Binary-Coded Decimal correction logic by utilizing the native x86 `DAA` (Decimal Adjust AL after Addition) and `DAS` (Decimal Adjust AL after Subtraction) instructions. This pairs natively with `adc` and `sbc` for massive cycle savings while remaining 100% behaviorally accurate. `DivideBCD` also uses an optimized shift-and-subtract approach.

---

## Random Number Generator (Random_)

- **Source:** `main.asm` (random logic)
- **Translated:** `dos_port/src/util/random.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

Accurately preserves the SM83 carry flag chain. The Game Boy original uses `adc b` and later `sbc b` without clearing flags, meaning it relies on the residual carry from the caller and previous instructions. The x86 translation perfectly mirrors this by keeping the exact sequence using `adc al, bl` and `sbb al, bl`.

---

*Add new entries below as routines are translated.*

## Text Box Coordinates (GetAddressOfScreenCoords)

- **Source:** `engine/menus/text_box.asm`
- **Translated:** `dos_port/engine/menus/text_box.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

**Brilliant hardware optimization:** The Game Boy's `GetAddressOfScreenCoords` typically requires iterative looping to calculate the tilemap offset (`row * 20 + col`). In the x86 translation, this loop has been entirely replaced by an O(1) calculation using the 32-bit hardware `imul eax, 20` instruction. This dramatically reduces cycles by converting an O(N) iterative addition loop into a single optimized instruction perfectly aligned with the 386 optimization strategy.

---

## PC / Item Swap Menus (RemoveItemByID / HandleItemListSwapping)

- **Source:** `engine/menus/pc.asm`, `engine/menus/swap_items.asm`
- **Translated:** `dos_port/engine/menus/pc.asm`, `dos_port/engine/menus/swap_items.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

Provides fully unwired skeletons for inventory management, abstracting iterative array scanning and item recombination. `HandleItemListSwapping` makes heavy use of 32-bit offset additions (e.g. `movzx ecx, al; add esi, ecx`) to calculate base pointers for the list cursor offset rather than the native 8-bit pointer advancement strategies, drastically reducing pressure on pointer manipulation loops.

---

## Save System (SaveMainData / CalcCheckSum)

- **Source:** `engine/menus/save.asm`
- **Translated:** `dos_port/engine/menus/save.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

Maintains faithful SRAM boundaries and checksum calculation. `CalcCheckSum` leverages a fast 32-bit `movzx ecx, cx` loop register countdown to rapidly sum the SRAM state. 

---

## Text Engine Base (text.asm)

- **Source:** `text.asm`
- **Translated:** `dos_port/text.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

Ported as a section-based include skeleton for later text data insertion.

---

*Add new entries below as routines are translated.*

## Item Inventory (AddItemToInventory_ / RemoveItemFromInventory_)

- **Source:** `engine/items/inventory.asm`
- **Translated:** `dos_port/src/items/inventory.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

Replaces the Game Boy's iterative 8-bit pointer advancement for item slot offsets with native 32-bit math. In `AddItemToInventory_`, the target memory address for the new item slot is computed instantly via `lea edx, [esi + 1 + ecx]`, completely eliminating loop-based pointer math perfectly aligned with the 386 strategy.

---

## Get Bag Item Quantity

- **Source:** `engine/items/get_bag_item_quantity.asm`
- **Translated:** `dos_port/src/items/get_bag_item_quantity.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

A clean, unwired translation of `GetQuantityOfItemInBag`. Standard array scanning returning item quantity.

---

## Pokemon Experience / Level Up 

- **Source:** `engine/pokemon/experience.asm`, `engine/battle/experience.asm`
- **Translated:** `dos_port/engine/pokemon/experience.asm`, `dos_port/engine/battle/experience.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

Heavily utilizes native 32-bit registers to streamline operations. The original 24-bit experience comparisons and arithmetic that required complex byte-by-byte manual cascades are instead highly optimized using the native capabilities of x86 32-bit registers to execute wide comparisons directly.

---

## Remove Pokemon

- **Source:** `engine/pokemon/remove_mon.asm`
- **Translated:** `dos_port/src/pokemon/remove_mon.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

A faithful array-shift implementation for PC and Party deletions. It capitalizes on the previously documented `imul` optimized `AddNTimes` routine to rapidly calculate struct boundaries (`PARTYMON_STRUCT_LENGTH` / `BOXMON_STRUCT_LENGTH`) and employs `CopyDataUntil` with seamless 32-bit addressing.

---

## Decrement PP

- **Source:** `engine/battle/decrement_pp.asm`
- **Translated:** `dos_port/engine/battle/decrement_pp.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

Optimizes battle status bit-checking. The original Game Boy logic required checking individual bits sequentially. The x86 translation compresses this into a single 32-bit mask test (`test al, (1 << STORING_ENERGY) | (1 << THRASHING_ABOUT) | (1 << ATTACKING_MULTIPLE_TIMES)`), saving multiple cycles.

---

## Pikachu Status Verification

- **Source:** `engine/pikachu/pikachu_status.asm`
- **Translated:** `dos_port/engine/pikachu/pikachu_status.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

Highly optimized struct verification for `IsThisPartyMonStarterPikachu` and `IsThisBoxMonStarterPikachu`. Heavy use of the O(1) `imul`-powered `AddNTimes` to immediately jump into `wBoxMon` or `wPartyMon` sub-arrays, instantly bridging OT Names, OT IDs, and Species fields without manual array traversal.

---

*Add new entries below as routines are translated.*

## Flag Action (FlagActionPredef / FlagAction)

- **Source:** `engine/flag_action.asm`
- **Translated:** `dos_port/engine/flag_action.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

**Native Bitwise Optimization:** `FlagAction` eliminates the Game Boy's bit-shifting loop required to generate a bitmask. By loading the bit index into `cl` and using the native x86 `shl dl, cl` instruction, the bitmask is generated in a single cycle. Additionally, the byte offset within the flag array is computed instantly via `shr al, 3` and directly added to the 32-bit base pointer (`add esi, eax`), fully optimizing array access.

---

## Joypad Input Handling (_Joypad / ReadJoypad_)

- **Source:** `engine/joypad.asm`
- **Translated:** `dos_port/engine/joypad.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

Accurately simulates the Game Boy hardware `IO_JOYP` polling logic. The state-transition calculations (deriving newly pressed and released keys from the previous state) heavily leverage hardware register cascades (e.g., `xor`, `and`, `not`) to compute `hJoyPressed` and `hJoyReleased` natively without unnecessary memory swapping. Applies the `wJoyIgnore` mask via an efficient inverted bitwise `and`.

---

## Predef Pointers (GetPredefPointer)

- **Source:** `engine/predefs.asm`
- **Translated:** `dos_port/engine/predefs.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

**`LEA` Multiplier Optimization:** The `PredefPointers` table relies on a 3-byte struct (1 byte for Bank, 2 bytes for Address). To access the nth element, the original Game Boy loops or does complex additions to multiply the index by 3. The x86 translation resolves this natively using the 32-bit `lea` (Load Effective Address) instruction: `lea ecx, [ecx + ecx*2]`. This instantly multiplies the index by 3 and elegantly offsets into the table in O(1) time.

---

*Add new entries below as routines are translated.*

---

## Debug State / Party (PrepareNewGameDebug / SetDebugNewGameParty)

- **Source:** `engine/debug/debug_party.asm`
- **Translated:** `dos_port/src/debug/debug_party.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

A pure data-setup unwired skeleton. Rapidly bypasses legacy loops and directly injects optimal state flags, utilizing optimized division-by-8 loop generation to cleanly populate Pokedex bit fields natively (`NUM_POKEMON / 8` and `(1 << (NUM_POKEMON % 8)) - 1`).

---

## Surfing Pikachu Minigame Math (SurfingMinigame_AddPointsToTotal / SurfingMinigame_Deduct1HP)

- **Source:** `engine/minigame/surfing_pikachu.asm`
- **Translated:** `dos_port/src/minigame/surfing_pikachu.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

**Native BCD Minigame Logic:** Completely detaches the minigame score calculations from graphical state logic. BCD addition and subtraction points scoring are perfectly optimized utilizing the native 386 hardware `DAA` (addition) and `DAS` (subtraction) instructions, natively maintaining a constant cap limitation (`0x9999`) without manual software correction arrays.

---

## Slot Machine Arrays & RNG (SlotMachine_FindWheel1Wheel2Matches / SlotMachine_CheckForMatch)

- **Source:** `engine/slots/slot_machine.asm`
- **Translated:** `dos_port/src/slots/slot_machine.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

Isolates the 3x3 slot machine reel array mapping and random number generation from graphical rendering routines. The logic relies on clean 32-bit `ESI`/`EDI` pointer offset indexing to verify slot layout rows directly, elegantly replacing convoluted 8-bit mapping pointers.

---

*Add new entries below as routines are translated.*

## Itemfinder / Hidden Items (HiddenItemNear)

- **Source:** `engine/items/itemfinder.asm`
- **Translated:** `dos_port/src/items/itemfinder.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

Coordinate delta logic optimally resolved utilizing simple `add` and native carry boundary logic (`jc` / `jnc`) avoiding multi-step conditional branching.

---

## BCD Transaction Subtraction (SubtractAmountPaidFromMoney_)

- **Source:** `engine/items/subtract_paid_money.asm`
- **Translated:** `dos_port/src/items/subtract_paid_money.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

Expertly handles 3-byte BCD array math using native 32-bit registers, deferring pointer iteration to the ultra-fast `StringCmp` and hardware-accelerated `SubBCDPredef` (which relies on native `DAS`). This guarantees instant, safe monetary transactions exactly adhering to GB constraints.

---

## Super Rod Encounters & PRNG (GenerateRandomFishingEncounter)

- **Source:** `engine/items/super_rod.asm`
- **Translated:** `dos_port/src/items/super_rod.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

Effectively maintains the glitch-accurate pseudo-random (PRNG) boundary constraints (`0x66`, `0xB2`, `0xE5`) corresponding to specific Pokemon encounters. Slot array iteration skips iterative counts by advancing pointers directly in `add esi, 8` intervals.

---

## TM Pricing Arrays (GetMachinePrice)

- **Source:** `engine/items/tm_prices.asm`
- **Translated:** `dos_port/src/items/tm_prices.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

BCD packed array access elegantly transformed. The Game Boy's `swap a` macro is replaced by efficient 32-bit native register manipulation (`shl cl, 4; shr al, 4; or al, cl`). The array indexing utilizes `movzx ecx, al; add esi, ecx` natively detaching the pointer array math from 8-bit registers.

---

*Add new entries below as routines are translated.*

## Town Map Data Extraction (LoadTownMapEntry / TownMapCoordsToOAMCoords)

- **Source:** `engine/items/town_map.asm`
- **Translated:** `dos_port/engine/items/town_map.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

**Graphical Independence:** Completely extracts the map array lookups, duplicate-filtering, and OAM conversion logic out from the visual map drawing routines. Uses clean 32-bit `lea` instructions (`lea esi, [esi + ecx*2]`) for pointer resolution, avoiding scaling loops entirely.

---

## TM/HM Base Engine (CheckIfMoveIsKnown / CanLearnTM)

- **Source:** `engine/items/tmhm.asm`, `engine/items/tms.asm`
- **Translated:** `dos_port/engine/items/tmhm.asm`, `dos_port/engine/items/tms.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

Unwired array scanners for validating if a Pokemon possesses the capacity to learn a move or if the move is currently active in the party move structures.

---

## Item Effects Engine (ApplyHealingItem / RestorePPAmount / Func_d85d)

- **Source:** `engine/items/item_effects.asm`
- **Translated:** `dos_port/engine/items/item_effects.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** GLITCH (Preserved original `MAX_ETHER` PP mask bypass).

### Notes

**UI Abstraction & Native Math:**
- `Func_d85d` completely abstracts evolution stone logic away from UI loops.
- `ApplyHealingItem` optimally handles 16-bit Big-Endian potion and revive logic. It seamlessly utilizes the native x86 `sub` and `sbc` chain to verify maximum bounds boundaries and natively divides by 2 (`shr al, 1; rcr al, 1`) for Half-HP Revival logic.
- `RestorePPAmount` accurately ports the legacy Max Ether glitch where upper bits (PP Up increments) bypass masking.

---

*Add new entries below as routines are translated.*

## Bill's PC Headless Logic (BillsPCDepositLogic / BillsPCWithdrawLogic / BillsPCReleaseLogic / KnowsHMMove)

- **Source:** `engine/pokemon/bills_pc.asm`
- **Translated:** `dos_port/src/pokemon/bills_pc.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** GLITCH (Preserved original unreachable logic in `KnowsHMMove`).

### Notes

**Headless PC Abstraction:**
Worker expertly separated the core box transaction operations (Depositing, Withdrawing, and Releasing) entirely from their UI and graphics wrappers. The translated functions operate as headless bounds-checking APIs returning strict carry-flag conditions (`CF=1` for box full/party empty errors) before safely triggering underlying `MoveMon` / `RemovePokemon` algorithms.

**HM Move Parsing:**
`KnowsHMMove` converts multi-cycle structure traversal natively using the O(1) `imul` arithmetic to instantly seek to the Pokemon's move array. It resolves HM applicability using the 32-bit bounded `IsInArray` function passing a data-driven `HMMoveArray`, cleanly optimizing move verification. Note that the original Game Boy codebase contained an unreachable path attempting to parse Box Mon structs; this has been preserved for bug-compatibility.

---

*Add new entries below as routines are translated.*

## Pokemon Array Router (_MoveMon / _AddEnemyMonToPlayerParty / AddPartyMon_WriteMovePP)

- **Source:** `engine/pokemon/add_mon.asm`
- **Translated:** `dos_port/engine/pokemon/add_mon.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

**Massive Structural Abstraction:** Worker successfully routed the enormous `_MoveMon` Pokemon structural data transfer logic. It seamlessly handles moving complex `BOXMON` and `PARTYMON` structs between the Box, Party, and Daycare boundaries headless of any UI interaction. The implementation optimally extracts structural constraints utilizing 32-bit offset arithmetic and `AddNTimes` to instantly resolve pointer targets without legacy iterative pointer increments. 
`AddPartyMon_WriteMovePP` and `_AddEnemyMonToPlayerParty` perfectly optimize array routing while handling Pokédex flag writes natively.

---

## Mon Data Structural Loaders (LoadMonData_ / GetMonSpecies)

- **Source:** `engine/pokemon/load_mon_data.asm`
- **Translated:** `dos_port/engine/pokemon/load_mon_data.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

**Headless Pointers:** Cleanly isolates Pokemon data pointer parsing (`LoadMonData_`) and indexing (`GetMonSpecies`) away from the UI-dependent `learn_move.asm` graphics logic. The data fetching seamlessly relies on ultra-fast native 32-bit structural jumping (`add esi, edx`) resolving list index queries instantly.

---

*Add new entries below as routines are translated.*

---

## Evolutions & Learnsets Engine (EvolutionAfterBattle / LearnMoveFromLevelUp / WriteMonMoves)

- **Source:** `engine/pokemon/evos_moves.asm`
- **Translated:** `dos_port/engine/pokemon/evos_moves.asm`
- **Date:** 2026-06-18
- **H-flag:** Not involved.
- **Bug tags:** None.

### Notes

**Headless Iteration:** The `EvosMovesPointerTable` structural parsers were perfectly mapped out, extracting the pure logical sequences out of `EvolutionAfterBattle` and `LearnMoveFromLevelUp`. Legacy text-box UI routines, extensive string prints, and pure graphical evolution routines were strictly carved out, leaving behind an optimized 32-bit array traversal engine using fast pointers (`add esi, ecx`) and `AddNTimes` for base stat recalculations and pointer data routing (`WriteMonMoves_ShiftMoveData`).

---

## GetTrainerName_

- **Source:** `engine/battle/get_trainer_name.asm:GetTrainerName_`
- **Translated:** `dos_port/src/engine/battle/get_trainer_name/GetTrainerName_.asm`
- **Date:** 2026-06-20
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** HL→ESI, DE→EDX, BC→BX, A→AL
- **Notes:** W_RIVAL_NAME equ 0xD349 used; defined dummy constants for RIVAL1, etc.

---

## FormatMovesString

- **Source:** `engine/battle/misc.asm:FormatMovesString`
- **Translated:** `dos_port/src/engine/battle/misc/FormatMovesString.asm`
- **Date:** 2026-06-20
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** HL->ESI for move array and name buf, DE->EDX for out string, B->BH
- **Notes:** used EDX for DE ptr; mapped '@' to 0x50, '<NEXT>' to 0x4E based on text.asm

---

## InitList

- **Source:** `engine/battle/misc.asm:InitList`
- **Translated:** `dos_port/src/engine/battle/misc/InitList.asm`
- **Date:** 2026-06-20
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** A->AL, BC->BX, DE->DX, HL->ESI
- **Notes:** Used EAX to extract L and H from ESI. Used 32-bit relocations for externs to satisfy COFF.

---

## ConversionEffect_

- **Source:** `engine/battle/move_effects/conversion.asm:ConversionEffect_`
- **Translated:** `dos_port/src/engine/battle/move_effects/conversion/ConversionEffect_.asm`
- **Date:** 2026-06-20
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** HL→ESI, DE→EDX, A→AL
- **Notes:** removed Bankswitch logic, evaluated INVULNERABLE to 6

---

## CallBankF

- **Source:** `engine/battle/move_effects/conversion.asm:CallBankF`
- **Translated:** `dos_port/src/engine/battle/move_effects/conversion/CallBankF.asm`
- **Date:** 2026-06-20
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** B→BH
- **Notes:** loaded BANK_PrintButItFailedText_ via EAX to avoid 8-bit relocation error

---

*Add new entries below as routines are translated.*

## ConvertedTypeText

- **Source:** `engine/battle/move_effects/conversion.asm:ConvertedTypeText`
- **Translated:** `dos_port/src/engine/battle/move_effects/conversion.asm`
- **Date:** 2026-06-20
- **H-flag:** (not recorded)
- **Bug tags:** none
- **Registers:** (not recorded)
- **Notes:** Emitted as raw byte stream (0x17, dummy addr/bank, 0x50). COFF rejects 16-bit relocations, so dw 0 is used for the far pointer; TextCommandProcessor skips 3 bytes anyway.

---

## PrintButItFailedText

- **Source:** `engine/battle/move_effects/conversion.asm:PrintButItFailedText`
- **Translated:** `dos_port/src/engine/battle/move_effects/conversion.asm`
- **Date:** 2026-06-20
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** HL→ESI
- **Notes:** Flat memory model simplifies CallBankF to a simple jmp esi.

---

## DrainHPEffect_

- **Source:** `engine/battle/move_effects/drain_hp.asm:DrainHPEffect_`
- **Translated:** `dos_port/src/engine/battle/move_effects/drain_hp.asm`
- **Date:** 2026-06-20
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** HL→ESI, BC→EBX, DE→EDX, A→AL
- **Notes:** hlcoord converted to W_TILEMAP offsets.

---

## SuckedHealthText

- **Source:** `engine/battle/move_effects/drain_hp.asm:SuckedHealthText`
- **Translated:** `dos_port/src/engine/battle/move_effects/drain_hp.asm`
- **Date:** 2026-06-20
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** none
- **Notes:** Translated as text data block (TX_FAR skipped, TX_END).

---

## DreamWasEatenText

- **Source:** `engine/battle/move_effects/drain_hp.asm:DreamWasEatenText`
- **Translated:** `dos_port/src/engine/battle/move_effects/drain_hp.asm`
- **Date:** 2026-06-20
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** none
- **Notes:** Translated as text data block (TX_FAR skipped, TX_END).

---

## FocusEnergyEffect_

- **Source:** `engine/battle/move_effects/focus_energy.asm:FocusEnergyEffect_`
- **Translated:** `dos_port/src/engine/battle/move_effects/focus_energy.asm`
- **Date:** 2026-06-20
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** HL→ESI for status ptr, A→AL, C→CL
- **Notes:** used bt/bts for GETTING_PUMPED, text macros commented out

---

## GettingPumpedText

- **Source:** `engine/battle/move_effects/focus_energy.asm:GettingPumpedText`
- **Translated:** `dos_port/src/engine/battle/move_effects/focus_energy.asm`
- **Date:** 2026-06-20
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** none
- **Notes:** Translated text macros to data bytes, used dd for 32-bit far pointer

---

## HazeEffect_

- **Source:** `engine/battle/move_effects/haze.asm:HazeEffect_`
- **Translated:** `dos_port/src/engine/battle/move_effects/haze.asm`
- **Date:** 2026-06-20
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** A->AL, BC->BX, DE->EDX, HL->ESI
- **Notes:** Translated all Haze functions. defined local constants. commented out text_far.

---

## CureVolatileStatuses

- **Source:** `engine/battle/move_effects/haze.asm:CureVolatileStatuses`
- **Translated:** `dos_port/src/engine/battle/move_effects/haze.asm`
- **Date:** 2026-06-20
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** HL→ESI, A→AL
- **Notes:** Used AND with bitmasks for RES bit manipulation

---

## ResetStatMods

- **Source:** `engine/battle/move_effects/haze.asm:ResetStatMods`
- **Translated:** `dos_port/src/engine/battle/move_effects/haze.asm`
- **Date:** 2026-06-20
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** A→AL, B→BH, HL→ESI
- **Notes:** Straightforward translation

---

## ResetStats

- **Source:** `engine/battle/move_effects/haze.asm:ResetStats`
- **Translated:** `dos_port/src/engine/battle/move_effects/haze.asm`
- **Date:** 2026-06-20
- **H-flag:** (not recorded)
- **Bug tags:** none
- **Registers:** (not recorded)
- **Notes:** (none)

---


## StatusChangesEliminatedText

- **Source:** `engine/battle/move_effects/haze.asm:StatusChangesEliminatedText`
- **Translated:** `dos_port/src/engine/battle/move_effects/haze.asm`
- **Date:** 2026-06-20
- **H-flag:** (not recorded)
- **Bug tags:** none
- **Registers:** (not recorded)
- **Notes:** (none)

---


## HealEffect_

- **Source:** `engine/battle/move_effects/heal.asm:HealEffect_`
- **Translated:** `dos_port/src/engine/battle/move_effects/heal.asm`
- **Date:** 2026-06-20
- **H-flag:** (not recorded)
- **Bug tags:** none
- **Registers:** (not recorded)
- **Notes:** (none)

---


## StartedSleepingEffect

- **Source:** `engine/battle/move_effects/heal.asm:StartedSleepingEffect`
- **Translated:** `dos_port/src/engine/battle/move_effects/heal.asm`
- **Date:** 2026-06-20
- **H-flag:** (not recorded)
- **Bug tags:** none
- **Registers:** (not recorded)
- **Notes:** (none)

---


## FellAsleepBecameHealthyText

- **Source:** `engine/battle/move_effects/heal.asm:FellAsleepBecameHealthyText`
- **Translated:** `dos_port/src/engine/battle/move_effects/heal.asm`
- **Date:** 2026-06-20
- **H-flag:** (not recorded)
- **Bug tags:** none
- **Registers:** (not recorded)
- **Notes:** (none)

---


## RegainedHealthText

- **Source:** `engine/battle/move_effects/heal.asm:RegainedHealthText`
- **Translated:** `dos_port/src/engine/battle/move_effects/heal.asm`
- **Date:** 2026-06-20
- **H-flag:** (not recorded)
- **Bug tags:** none
- **Registers:** (not recorded)
- **Notes:** (none)

---


## LeechSeedEffect_

- **Source:** `engine/battle/move_effects/leech_seed.asm:LeechSeedEffect_`
- **Translated:** `dos_port/src/engine/battle/move_effects/leech_seed.asm`
- **Date:** 2026-06-20
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** HL→ESI, DE→EDI, A→AL, C→CL
- **Notes:** used 1<<7 for SEEDED, 22 for GRASS type

---

## WasSeededText

- **Source:** `engine/battle/move_effects/leech_seed.asm:WasSeededText`
- **Translated:** `dos_port/src/engine/battle/move_effects/leech_seed.asm`
- **Date:** 2026-06-20
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** none (text data)
- **Notes:** expanded text_far macro explicitly as requested

---

## EvadedAttackText

- **Source:** `engine/battle/move_effects/leech_seed.asm:EvadedAttackText`
- **Translated:** `dos_port/src/engine/battle/move_effects/leech_seed.asm`
- **Date:** 2026-06-20
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** none
- **Notes:** expanded text_far and text_end macros

---

## MistEffect_

- **Source:** `engine/battle/move_effects/mist.asm:MistEffect_`
- **Translated:** `dos_port/src/engine/battle/move_effects/mist.asm`
- **Date:** 2026-06-20
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** HL→ESI for status pointer, A→AL for turn
- **Notes:** translated text_far and text_end to db 0x17, dd pointer, db 0x50

---

## ShroudedInMistText

- **Source:** `engine/battle/move_effects/mist.asm:ShroudedInMistText`
- **Translated:** `dos_port/src/engine/battle/move_effects/mist.asm`
- **Date:** 2026-06-20
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** none (data only)
- **Notes:** expanded text_far and text_end macros to manual db/dd

---


## OneHitKOEffect_

- **Source:** `engine/battle/move_effects/one_hit_ko.asm:OneHitKOEffect_`
- **Translated:** `dos_port/src/engine/battle/move_effects/one_hit_ko.asm`
- **Date:** 2026-06-20
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** A->AL, HL->ESI, DE->EDI, B->BL
- **Notes:** straight translation, basic branching and 16-bit cmp via 8-bit sub/sbb

---

## ParalyzeEffect_

- **Source:** `engine/battle/move_effects/paralyze.asm:ParalyzeEffect_`
- **Translated:** `dos_port/src/engine/battle/move_effects/paralyze.asm`
- **Date:** 2026-06-20
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** HL→ESI, DE→EDI, A→AL, BC→EBX
- **Notes:** callfar -> call, jpfar -> jmp, ld c -> mov bl for DelayFrames

---

## PayDayEffect_

- **Source:** `engine/battle/move_effects/pay_day.asm:PayDayEffect_`
- **Translated:** `dos_port/src/engine/battle/move_effects/pay_day.asm`
- **Date:** 2026-06-20
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** A->AL, HL->ESI, DE->EDI, BC->EBX
- **Notes:** used ebx/bl for B and C counts; rol al, 4 for swap a

---

## CoinsScatteredText

- **Source:** `engine/battle/move_effects/pay_day.asm:CoinsScatteredText`
- **Translated:** `dos_port/src/engine/battle/move_effects/pay_day.asm`
- **Date:** 2026-06-20
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** not involved
- **Notes:** macro expansion of text_far _CoinsScatteredText

---

## OverworldLoop warp bug fixes

- **Source:** `home/overworld.asm` (warp resolution logic)
- **Translated:** `dos_port/src/engine/overworld/overworld.asm`
- **Date:** 2026-06-20
- **H-flag:** not involved
- **Bug tags:** none (regression fixes, not known original bugs)

### Four bugs fixed in this session

**Bug 1 — W_LAST_MAP unconditional update (multi-floor warp corruption)**

`.warpTransition` always wrote `W_CUR_MAP → W_LAST_MAP` before switching to the
destination map. Going 1F → 2F → 1F would set `W_LAST_MAP = Red's House 2F`; the
next 0xFF warp resolution would then land the player in 2F instead of Pallet Town.
Fix: only update `W_LAST_MAP` when the source map is outdoor (`W_CUR_MAP < FIRST_INDOOR_MAP_ID = 0x25`).
This mirrors pret's `CheckIfInOutsideMap` guard in `WarpFound2`.

**Bug 2 — BIT_STANDING_ON_WARP never set at spawn**

`LoadWarpDestination` placed the player at spawn coords but never checked whether
those coords match a warp entry in the destination map's `W_WARP_ENTRIES`. As a
result, `BIT_STANDING_ON_WARP` was always 0 after a warp transition, making the
collision-exit guard (`test BIT_STANDING_ON_WARP; jz OverworldLoop`) permanently
skip door exits. Fix: after `LoadCurrentMapView`, call `CheckWarpTile` and set
`BIT_STANDING_ON_WARP` if CF=1. Mirrors pret's `IsPlayerStandingOnWarp` called
from `EnterMap`.

**Bug 3 — BIT_EXITING_DOOR suppressed collision-exit (regression from 445c6a3a)**

Commit 445c6a3a added `test BIT_EXITING_DOOR; jnz OverworldLoop` to the
collision-exit path. Pret does NOT have this guard: `BIT_EXITING_DOOR` marks the
auto-walk state, it does not suppress subsequent exit attempts. Combined with Bug 2
(BIT_STANDING_ON_WARP=0 at spawn), all door exits via the collision path were
completely broken — the player could not exit any building by pressing DOWN at the
door. Fix: remove the `test BIT_EXITING_DOOR` guard entirely. The `BIT_STANDING_ON_WARP`
guard is sufficient (it's only set when the player is actually on a warp tile).

**Bug 4 — BIT_SCRIPTED_MOVEMENT_STATE bypass was dead code**

`PlayerStepOutFromDoor` sets `BIT_SCRIPTED_MOVEMENT_STATE` to inject a scripted
PAD_DOWN that should bypass the 180°-turn-delay and immediately fire the
collision-exit. However, the flag was being CLEARED at the simulated-input dispatch
point (before reaching `.handleDirection`) — so `.handleDirection`'s bypass check
always saw 0. Fix: remove the early clear; instead, `.handleDirection` now clears
the flag (after testing it), making the bypass live. Scripted movement now bypasses
`W_CHECK_FOR_TURN` and goes straight to `.walkStart`, which hits the blocked wall
and fires the collision-exit via the now-fixed path.

### Combined effect

After all four fixes: entering a building correctly sets `W_LAST_MAP` only if
coming from outdoors; spawning at the door tile sets `BIT_STANDING_ON_WARP`;
`PlayerStepOutFromDoor` injects a scripted south-step that fires `.walkStart →
CollisionCheckOnLand → collision-exit → warp out` in one frame (bypassing
both the turn-delay and the ignore-input window, which only blocks manual input).
Stair transitions are unaffected: `IsPlayerStandingOnDoorTile` returns CF=0 for
stair tiles, so `PlayerStepOutFromDoor` takes `.notStandingOnDoor`, clears
`BIT_STANDING_ON_DOOR`, and no scripted step is injected.

---

## gen_map_headers.py — IF DEF(_DEBUG) pointer desync bug (2026-06-22)

**Not a translation bug — a tooling bug in the asset generator.**

### What broke

All indoor map warps to maps with ID > `0x26` (BLUES_HOUSE and beyond) were
broken: entering those buildings loaded garbage header data (wrong tileset, wrong
dimensions, wrong warp table). Outdoor→outdoor map transitions were fine.

### Root cause

In commit `445c6a3a`, the `REDS_HOUSE_2F` section of `dos_port/assets/map_headers.inc`
was **hand-edited** to remove 4 `IF DEF(_DEBUG)` warp entries from the object
data. However, the `MapHeaderPointers` table (hardcoded absolute addresses
computed at generation time) was NOT updated. It was still generated assuming 5
warps for REDS_HOUSE_2F (5 × 4 = 20 bytes of warp data). With only 1 warp in the
blob (4 bytes), every pointer for maps after 0x26 pointed 16 bytes too far into
the data blob.

This was invisible locally because `make` sees the committed `.inc` as up to date
and skips regeneration. A fresh clone + regenerate on another machine produced a
consistent (5-warp) file and worked correctly — the discrepancy is what exposed it.

### Fix

`tools/gen_map_headers.py` now calls `strip_debug_blocks()` before parsing each
object file. This strips `IF DEF(_DEBUG) ... ENDC` blocks (with nesting depth
tracking) so the generator produces the same 1-warp layout as the hand-edit —
but also recomputes all the `MapHeaderPointers` correctly. Regenerating the file
closes the 16-byte gap.

### Rule going forward

**Never hand-edit generated files.** If content in `map_headers.inc` or any
other `assets/*.inc` file needs to change, fix the **generator** and regenerate.
The pointer tables are computed at generation time and cannot be partially updated.
If you need to exclude RGBASM-conditional content, add a filter to the generator.

---

## CureVolatileStatuses

- **Source:** `engine/battle/move_effects/haze.asm:CureVolatileStatuses`
- **Translated:** `dos_port/src/engine/battle/move_effects/haze.asm`
- **Date:** 2026-06-23
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** HL->ESI for battle status ptr, A->AL
- **Notes:** none

---

## ResetStatMods

- **Source:** `engine/battle/move_effects/haze.asm:ResetStatMods`
- **Translated:** `dos_port/src/engine/battle/move_effects/haze.asm`
- **Date:** 2026-06-23
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** HL→ESI, B→BH, A→AL
- **Notes:** straight translation; gb memory access via ebp+esi

---

## FocusEnergyEffect_

- **Source:** `engine/battle/move_effects/focus_energy.asm:FocusEnergyEffect_`
- **Translated:** `dos_port/src/engine/battle/move_effects/focus_energy.asm`
- **Date:** 2026-06-23
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** HL->ESI for status ptr, A->AL for turn
- **Notes:** used OR/TEST for GETTING_PUMPED, DelayFrames count in cl

---

## HazeEffect_

- **Source:** `engine/battle/move_effects/haze.asm:HazeEffect_`
- **Translated:** `dos_port/src/engine/battle/move_effects/haze.asm`
- **Date:** 2026-06-23
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** HL->ESI, DE->EDX, A->AL, B->BH
- **Notes:** used EDX for DE to support 32-bit flat EBP addressing

---

## ResetStats

- **Source:** `engine/battle/move_effects/haze.asm:ResetStats`
- **Translated:** `dos_port/src/engine/battle/move_effects/haze.asm`
- **Date:** 2026-06-23
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** HL->ESI for source stat ptr, DE->EDI for dest stat ptr, B->BH for loop counter, A->AL
- **Notes:** added NUM_STATS equ 7 to allow assembly; used EBP memory model

---

## StatusChangesEliminatedText

- **Source:** `engine/battle/move_effects/haze.asm:StatusChangesEliminatedText`
- **Translated:** `dos_port/src/engine/battle/move_effects/haze.asm`
- **Date:** 2026-06-23
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** none
- **Notes:** text macro translation

---

## HealEffect_

- **Source:** `engine/battle/move_effects/heal.asm:HealEffect_`
- **Translated:** `dos_port/src/engine/battle/move_effects/heal.asm`
- **Date:** 2026-06-23
- **H-flag:** not involved
- **Bug tags:** BUG(cosmetic): most significant bytes comparison is ignored
- **Registers:** HL→ESI, DE→EDI, A→AL, B→BH, C→BL
- **Notes:** expanded hlcoord macro manually; translated predef UpdateHPBar2 as call UpdateHPBar2

---

## FellAsleepBecameHealthyText

- **Source:** `engine/battle/move_effects/heal.asm:FellAsleepBecameHealthyText`
- **Translated:** `dos_port/src/engine/battle/move_effects/heal.asm`
- **Date:** 2026-06-23
- **H-flag:** (not recorded)
- **Bug tags:** none
- **Registers:** (not recorded)
- **Notes:** (none)

---

## RegainedHealthText

- **Source:** `engine/battle/move_effects/heal.asm:RegainedHealthText`
- **Translated:** `dos_port/src/engine/battle/move_effects/heal.asm`
- **Date:** 2026-06-23
- **H-flag:** (not recorded)
- **Bug tags:** none
- **Registers:** (not recorded)
- **Notes:** Translated text macro using db byte constants (TX_FAR, TX_END) and dd for flat far pointer.

---

## StartedSleepingEffect

- **Source:** `engine/battle/move_effects/heal.asm:StartedSleepingEffect`
- **Translated:** `dos_port/src/engine/battle/move_effects/heal.asm`
- **Date:** 2026-06-23
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** none
- **Notes:** Text macro converted to db 0x17, dd pointer, db 0x50

---

## LeechSeedEffect_

- **Source:** `engine/battle/move_effects/leech_seed.asm:LeechSeedEffect_`
- **Translated:** `dos_port/src/engine/battle/move_effects/leech_seed.asm`
- **Date:** 2026-06-23
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** HL->ESI, DE->EDI, A->AL, C->CL
- **Notes:** Translated purely; EDI used for DE, CL for C.

---

## WasSeededText

- **Source:** `engine/battle/move_effects/leech_seed.asm:WasSeededText`
- **Translated:** `dos_port/src/engine/battle/move_effects/leech_seed.asm`
- **Date:** 2026-06-23
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** none
- **Notes:** explicit byte directives for text_far and text_end

---

## EvadedAttackText

- **Source:** `engine/battle/move_effects/leech_seed.asm:EvadedAttackText`
- **Translated:** `dos_port/src/engine/battle/move_effects/leech_seed.asm`
- **Date:** 2026-06-23
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** none
- **Notes:** Translated text_far and text_end macros into byte directives.

---

## ShroudedInMistText

- **Source:** `engine/battle/move_effects/mist.asm:ShroudedInMistText`
- **Translated:** `dos_port/src/engine/battle/move_effects/mist.asm`
- **Date:** 2026-06-23
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** none
- **Notes:** explicit byte directives for text_far and text_end

---

## OneHitKOEffect_

- **Source:** `engine/battle/move_effects/one_hit_ko.asm:OneHitKOEffect_`
- **Translated:** `dos_port/src/engine/battle/move_effects/one_hit_ko.asm`
- **Date:** 2026-06-23
- **H-flag:** computed
- **Bug tags:** none
- **Registers:** HL->ESI, DE->EDI, A->AL, B->BH
- **Notes:** Translated exactly matching 8-bit operations.

---

## GettingPumpedText

- **Source:** `engine/battle/move_effects/focus_energy.asm:GettingPumpedText`
- **Translated:** `dos_port/src/engine/battle/move_effects/focus_energy.asm`
- **Date:** 2026-06-23
- **H-flag:** (not recorded)
- **Bug tags:** none
- **Registers:** (not recorded)
- **Notes:** Translated text macro

---

## MistEffect_

- **Source:** `engine/battle/move_effects/mist.asm:MistEffect_`
- **Translated:** `dos_port/src/engine/battle/move_effects/mist.asm`
- **Date:** 2026-06-23
- **H-flag:** not involved
- **Bug tags:** none
- **Registers:** HL->ESI, A->AL
- **Notes:** used test/or with 1<<PROTECTED_BY_MIST for bit/set since it's a bit index

---

## PrepareOAMData — extended viewport + walk-offset NPC tracking

- **Source:** `engine/overworld/movement.asm:PrepareOAMData`
- **Translated:** `dos_port/src/gfx/sprite_oam.asm:PrepareOAMData`
- **Date:** 2026-06-23
- **H-flag:** not involved
- **Bug tags:** none

### Summary

Extended `PrepareOAMData` and `render_sprites` to handle the DOS 320×200 viewport
(44×32 visible blocks), replacing 8-bit OAM coordinate arithmetic that overflowed for
NPCs beyond ~8 blocks from the player.

### Changes

**Problem:** The original `render_sprites` derived the screen position of each sprite
by sign-extending the 8-bit OAM Y/X bytes (`movsx eax, byte [ebp + esi]`), then adding
a fixed letterbox offset. For NPCs whose `(MAPY - wYCoord) * 16 - 4` overflows 8 bits
(≥ 8 blocks from the camera), the OAM byte wraps (e.g., MAPY=18, wYCoord=8 → 0xAC),
producing a wildly wrong screen Y in `render_sprites`. Simultaneously, culling used
`cmp al, 0xA0; jae .nextSprite` (GB convention for inactive entries), which falsely
culled any NPC whose OAM Y byte was ≥ 0xA0 even when the computed DOS position was on-screen.

**Fix — 32-bit position tables:**
- Added BSS globals in `ppu.asm`: `spr_dos_sy[40]`, `spr_dos_sx[40]` (one dword per OAM
  entry), and `spr_oam_valid` (count of entries PrepareOAMData wrote this frame).
- `PrepareOAMData` computes a 32-bit `dos_base_y/x` using a hybrid formula:
  - Slot 0 (player): `movsx(H_SPRITE_SCREEN_Y) + 36` / `movsx(H_SPRITE_SCREEN_X) + 96`
    (safe; YPIXELS ≤ 127 for the player).
  - NPC slots 1–15: `(MAPY - wYCoord) * 16 + 32` and `(MAPX - wXCoord) * 16 + 96`
    (full 32-bit; no overflow regardless of map size).
- In `tileLoop`, `edx = (edi - W_SHADOW_OAM) >> 2` (OAM entry index 0–39). Each tile's
  dos_base + tableY/X offset is written to `spr_dos_sy[edx*4]` and `spr_dos_sx[edx*4]`.
- At `.ret`, `spr_oam_valid = H_OAM_BUFFER_OFFSET / 4`.
- `render_sprites` now reads from the tables instead of recomputing from 8-bit OAM bytes.
  The `cmp al, 0xA0` cull is replaced by `cmp ecx, [spr_oam_valid]; jae .nextSprite`.

**Fix — walk-offset NPC smoothing:**
The 32-bit MAPY-based dos_base is block-aligned (constant across a walk step). The BG
scrolls 2 px/frame via `bg_scy`/`bg_scx`. Without compensation, NPCs drift 2 px/frame
against BG tiles and then snap 16 px at the block boundary. Fix: after `.dos_base_done`,
for NPC slots only, subtract `YSTEP_VECTOR * (8 - walk_counter) * 2` (and same for X)
from `dos_base_y/x_tmp`. This is an exact reverse of the BG scroll already applied, so
NPCs track BG tiles smoothly throughout all 8 walk frames.

### Key constants

- `W_SPRITE_PLAYER_Y_STEP_VECTOR = 0xC103` — signed byte; +1 south, -1 north
- `W_SPRITE_PLAYER_X_STEP_VECTOR = 0xC105` — signed byte; +1 east, -1 west
- `W_WALK_COUNTER = 0xCFC4` — 8-frame countdown during a walk step (0 = standing)
- `spr_dos_sy / spr_dos_sx` — BSS arrays declared in `ppu.asm`, externs in `sprite_oam.asm`

---

## render_sprites — extended viewport culling

- **Source:** (DOS-only; no GB equivalent — PPU software renderer)
- **Translated:** `dos_port/src/ppu/ppu.asm:render_sprites`
- **Date:** 2026-06-23
- **H-flag:** not involved
- **Bug tags:** none

### Summary

`render_sprites` was rewritten to use the `spr_dos_sy/sx` position tables filled by
`PrepareOAMData` (see entry above) instead of recomputing positions from 8-bit OAM
bytes. Entry validity is now checked via `spr_oam_valid` count rather than the GB-style
`cmp al, 0xA0` OAM-Y sentinel, which falsely culled on-screen NPCs whose 8-bit OAM Y
had wrapped past 0xA0 due to the extended viewport distance.

The symptom that surfaced the bug: walking RIGHT kept NPCs visible (only X changed;
Y-byte stable). Walking UP/DOWN/LEFT triggered premature NPC disappearance because
those directions changed the Y-byte across the 0xA0 threshold.

---

## InitMapSprites / LoadNPCSpriteTiles

- **Source:** `engine/overworld/map_sprites.asm:InitMapSprites` + `LoadMapSpriteTilePatterns`
- **Translated:** `dos_port/src/engine/overworld/map_sprites.asm`
- **Date:** 2026-06-23
- **H-flag:** not involved
- **Bug tags:** none

### Summary

Implements the data pipeline from map object binary → NPC sprite slots → VRAM:

1. Clears NPC slots 1–15 in `wSpriteStateData1/2`.
2. Reads `sprite_count` + per-NPC 6-byte records from the GB address pointed to
   by `W_OBJECT_DATA_PTR_TEMP` (set by `LoadMapHeader`).
3. Populates `PICTUREID`, `MAPY/MAPX`, `MOVEMENTBYTE1/2`, `MOVEMENTDELAY`,
   `IMAGEBASEOFFSET`, and `ISTRAINER` for each slot.
4. Trainer NPCs: reads extra 2 bytes (trainer_class, trainer_num) and sets ISTRAINER=1.
5. `FindOrAssignVramSlot`: deduplicates sprite types; each unique type gets a
   `imageBaseOffset` (3, 4, 5, …); slots 1=player, 2=Pikachu are reserved.
6. `LoadNPCSpriteTiles`: copies 192 bytes (12 still tiles) per unique sprite type to
   `[EBP + GB_VCHARS0 + (imageBaseOffset-1)*192]`; sets `g_tilecache_dirty=1`.

NPC assets (`npc_oak_still.inc`, `npc_girl_still.inc`, `npc_fisher_still.inc`) are
embedded in `.data` section of `map_sprites.asm` via `NpcSpriteAssets` lookup table.

---

## CheckSpriteAvailability — DOS viewport culling fix

- **Source:** `engine/overworld/movement.asm:CheckSpriteAvailability`
- **Translated:** `dos_port/src/engine/overworld/movement.asm:CheckSpriteAvailability`
- **Date:** 2026-06-23
- **H-flag:** not involved
- **Bug tags:** none (DOS-port adaptation, not a GB bug)

### Summary

The original pret visibility range test used 8-bit unsigned byte arithmetic:
`cmp wYCoord, MAPY; jae .invisible` (lower bound) + `add wYCoord, SCREEN_HEIGHT/2-1; jb .invisible` (upper). With `SCREEN_HEIGHT=25` (DOS) this gave `MAPY ∈ [wYCoord, wYCoord+11]`. Due to the `origin+4` offset stored in `MAPY/MAPX`, the actual-tile-delta visible range was `[-4, +7]` Y and `[-4, +15]` X — badly asymmetric with the DOS 320×200 viewport needing `[-6, +6]` Y and `[-10, +9]` X.

**Symptom:** NPCs disappeared 5–7 metatile columns too early to the west (X) and ~2 rows too early to the north (Y). One-sided culling was the fingerprint that isolated this to `CheckSpriteAvailability` rather than the symmetric `render_sprites` or `dos_base` formulas.

**Fix:** Two-sided 32-bit signed range comparisons replacing the old `jae`/`jb` pair:
- Y: `MAPY ∈ [wYCoord−3, wYCoord+11]` → actual delta `[−7, +7]` (1-tile buffer)
- X: `MAPX ∈ [wXCoord−7, wXCoord+14]` → actual delta `[−11, +10]` (1-tile buffer)

**Critical:** Lower-bound subtraction must use 32-bit signed registers — `sub al, 3` wraps to `0xFC` when `wYCoord=0`, culling every NPC. Fix: `movzx eax; lea ecx,[eax-N]; cmp ecx,edx; jg .invisible`.

---

## UpdateNonPlayerSprite / NPC walk state machine

- **Source:** `engine/overworld/movement.asm:UpdateNPCSprite` and helpers (pret lines 99–370, 556–666, 990–1016)
- **Translated:** `dos_port/src/engine/overworld/movement.asm`
- **Date:** 2026-06-23
- **H-flag:** not involved
- **Bug tags:** BUG(cosmetic) Yellow south-displacement fix applied (see below)

### Summary

Full NPC random-walk state machine: status dispatch, delay countdown, direction selection with UP_DOWN/LEFT_RIGHT/forced-dir constraints, tile passability + collision + displacement bounds check, walk-pixel interpolation, and animation counter.

### Functions translated

| Pret label | DOS label | Notes |
|---|---|---|
| `UpdateNPCSprite` | `UpdateNonPlayerSprite` | Status 0→init, 1→ready, 2→delay, 3→walk; BIT_FACE_PLAYER stub |
| `Func_5337` | `Func_5337` | Write FACINGDIRECTION/YSTEPVECTOR/XSTEPVECTOR to sprite slot |
| `Func_5349` | `Func_5349` | Advance MAPY/MAPX to destination at walk START (not end) |
| `TryWalking` | `TryWalking` | Call Func_5337 → CanWalkOntoTile → Func_5349 → STATUS=3 |
| `CanWalkOntoTile` | `CanWalkOntoTile` | IsTilePassable + STAY check + displacement bounds + DetectCollision |
| `UpdateSpriteMovementDelay` | `UpdateSpriteMovementDelay` | Decrement MOVEMENTDELAY; 0 → STATUS=1, fall into NotYetMoving |
| `NotYetMoving` | `NotYetMoving` | Reset ANIMFRAMECOUNTER, UpdateSpriteImage |
| `UpdateSpriteInWalkingAnimation` | `UpdateSpriteInWalkingAnimation` | pixel-interpolation (YPIXELS/XPIXELS += YSTEP/XSTEP), WALKANIMCOUNTER |
| `Random` | `Random` | Thin wrapper: saves/restores EBX, calls `Random_`, returns H_RANDOM_ADD in AL |

### SPRITESTATEDATA2 constants bug fixed

`gb_memmap.inc` had MOVEMENTDELAY at offset 0x1 (unused slot) and MOVEMENTBYTE2 at 0x8 (the real MOVEMENTDELAY slot). This caused map_sprites.asm to write direction constraints to slot 0x8 and delays to slot 0x1. Fix: swap them to match pret (MOVEMENTBYTE2=0x1, MOVEMENTDELAY=0x8). Because map_sprites.asm uses symbolic constants, the write offsets corrected automatically.

### Func_5349 timing — teleport-prevention

Pret advances MAPY/MAPX to the **destination** at walk **start** (inside `TryWalking`, before the first pixel step). PrepareOAMData's `dos_base_npc` formula therefore subtracts `YSTEP × WALKANIMCOUNTER` and `XSTEP × WALKANIMCOUNTER` to interpolate back to the source position, counting down to 0 at walk end. Without this, NPCs would appear to teleport one metatile and slide back.

### wMapSpriteData indirection eliminated

Pret's `UpdateNPCSprite` reads the direction constraint (`wCurSpriteMovement2`) via a separate `wMapSpriteData` pointer array. The DOS port stores the constraint directly in `SPRITESTATEDATA2[MOVEMENTBYTE2]` (offset 0x1), set by `InitMapSprites`. No separate array needed.

### Yellow south-displacement fix

Red/Blue had a bug: the south-displacement upper bound used `cmp a, 5; jnc .blocked` — the same condition as the north lower bound — which meant NPCs could only move 4 tiles south of their starting position. Yellow fixed this by removing the south upper bound check. The DOS port follows Yellow behavior (no south or east upper bound).

### Random_ / IO_DIV

`random.asm`'s LCG reads `IO_DIV` (at `[EBP + 0xFF04]`). Previously always 0 (emulated but not driven). Fixed by incrementing `IO_DIV` once per frame inside `commit_shadow_regs` (`frame.asm`) so the LCG has changing input. Verified live: NPCs walk with varied directions and delays.

---

## Script engine — event-flag system (Stage 1)

- **Source:** `macros/scripts/events.asm` (CheckEvent/SetEvent/ResetEvent), `constants/event_constants.asm`
- **Translated:** `dos_port/include/events.inc` + `dos_port/assets/event_constants.inc` (generated by `tools/gen_event_constants.py`)
- **Date:** 2026-06-25
- **H-flag:** Not involved.
- **Bug tags:** None.

`gen_event_constants.py` parses the rgbds `const_def`/`const`/`const_skip`/`const_next`
enumeration into `EVENT_* equ <bit index>` (522 events, `NUM_EVENTS=2560` = 320 bytes).
`events.inc` converts an index into `(byte offset, bit mask)` at assembly time
(`EVENT_BYTE`/`EVENT_MASK`; modulo written as `i-(i/8)*8` to avoid NASM's `%`
preprocessor character) and provides `CheckEvent`/`SetEvent`/`ResetEvent` over
`W_EVENT_FLAGS` (0xD746), which `InitMapSprites` already zeroes. All three clobber AL;
`CheckEvent` sets ZF with pret's polarity (ZF=1 ⇒ flag clear, matching `bit n,[hl]` →
`jr z`). Header-level NASM macros, so not a `translation.db` queue row. Verified:
Pallet Town event values spot-checked against the source; a harness exercising all
three macros assembles clean (`nasm -f coff`).

---

## Script engine — text_asm dispatch + Pallet Town reference (Stages 2–4)

- **Source:** `home/text_script.asm:DisplayTextID` (dispatch concept), `scripts/PalletTown.asm:PalletTownOakText`
- **Translated:** `dos_port/src/scripts/pallet_town.asm`, `dos_port/src/engine/overworld/map_sprites.asm` (`ShowTextStream` + dispatch), `dos_port/tools/gen_npc_dialogs.py` (`SCRIPT_OVERRIDES`)
- **Date:** 2026-06-25
- **H-flag:** Not involved.
- **Bug tags:** None.

**Design (divergence from pret, documented):** gen-1 marks a `text_asm` entry with a
`TX_START_ASM` (0x08) byte at the head of the text stream and `jp hl` past it. The DOS
port's map TextTable already stores `(flat ptr, size)` per slot and copies streams into
`NPC_DIALOG_BUF` (WRAM) because `PrintText` wants EBP-relative pointers. So instead of an
in-stream marker, a **SCRIPT entry** is `dd <routine>, 0xFFFFFFFF` — the sentinel size
tells `CheckNPCInteraction` to CALL the flat `text_asm` routine. A new shared
`ShowTextStream` (ESI=flat stream, ECX=count → copy to `NPC_DIALOG_BUF`, `PrintText`,
`npc_dialog_wait_impl`) serves both the plain path and scripts. The font load was moved
ahead of the dispatch (both paths need it); `LoadFontTilePatterns` preserves EDI and
leaves EBX untouched, so the flat ptr/size survive it.

`gen_npc_dialogs.py:SCRIPT_OVERRIDES` maps a pret text-pointer label → a hand-written
NASM script label; matching slots emit the SCRIPT entry + `extern`.
`PalletTownOakText` (reference) gates on `EVENT_GOT_POKEBALLS_FROM_OAK` via the Stage 1
`CheckEvent` macro and shows one of two branches. The full intro (wOakWalkedToPlayer
variants, Oak walk-up cutscene, Pikachu battle) is deferred — recorded as `stubs` on
queue row 4398 (kinds: battle, misc).

**Status:** builds + links (default and `DEBUG_OAK_EVENT=1`). **Not yet visually
verified** — Oak does not spawn into Pallet Town until the intro/spawn-gating exists, so
the dialog is unreachable in-game for now. Verify once Oak is spawned.

---

## Pokémon engine — Stage 5 tail (load/set-types/remove) + sym-pinned addresses

- **Source:** `engine/pokemon/load_mon_data.asm` (LoadMonData_/GetMonSpecies),
  `engine/pokemon/set_types.asm` (SetPartyMonTypes), `home/move_mon.asm`
  (RemovePokemon→_RemovePokemon, CopyDataUntil), `home/predef.asm` (GetPredefRegisters)
- **Translated:** `dos_port/src/engine/pokemon/{load_mon_data,set_types,remove_mon}.asm`,
  `dos_port/src/home/{predef.asm,copy_data.asm (+CopyDataUntil)}`,
  `dos_port/include/gb_memmap.inc` (address fixes + aliases),
  `dos_port/tools/gen_growth_rates.py` (new generator)
- **Date:** 2026-06-25
- **H-flag:** Not involved.
- **Bug tags:** None new; fixed a latent address bug (below).

**Address correction (sym-pinned).** `origin/symbols:pokeyellow.sym` revealed the
lowercase `wMonHeader` block in `gb_memmap.inc` was off by one (too high):
`wMonHeader` was $D0B8, sym says $D0B7; the whole block shifted down one byte to
match (`wMonHBaseHP` $D0B8, `wMonHType1` $D0BD, … `wMonHLearnset` $D0CB). A prior
pass had also "corrected" `W_MON_H_GROWTH_RATE`/`wMonHGrowthRate` $D0CA→$D0CB on
the false premise wMonHeader was $D0B8 — reverted to the sym's $D0CA. The error
was invisible to the existing native harnesses because each is self-contained
(the writer and reader share the same constant); the new `load_mon_data` test
reads real Bulbasaur base stats back through `GetMonHeader` at the corrected
addresses, so writer/reader now agree on absolute placement too. Added the
previously-deferred cross-section aliases (`wLoadedMon`, `wPokedexNum`, enemy/box/
daycare, `wPredefHL/DE/BC`, `wPartyMonNicksEnd`, `wRemoveMonFromBox`) from the sym.

**Draft bugs fixed.** (1) Wrong include paths (`dos_port/include/...` → `-I`
relative). (2) Register contract: `AddNTimes`/`CopyDataUntil` read **BX** (the
bc pair), but `remove_mon` passed strides and CopyDataUntil end-pointers in
`ECX`, which those helpers ignore — every party/box shift was driven by garbage.
Rewrote `remove_mon` faithfully using BX. `load_mon_data`'s data-location
dispatch relies on `mov` not touching EFLAGS between `cmp` and `jz/jc` (faithful
to SM83 `ld hl,…` between `cp` and `jr`) — kept and commented.

**New support routines.** `CopyDataUntil` (copies `[HL,BC)`→`DE`, 16-bit end
compare via `cmp si,bx`). `GetPredefRegisters` (restores HL/DE/BC from the
big-endian `wPredef*` slots); only this predef leaf is ported — `SetPartyMonTypes`
is its sole caller and harnesses populate `wPredefHL` directly (full predef
dispatch deferred).

**Reproducibility fix.** `assets/growth_rates.inc` was hand-authored, but
`dos_port/assets/` is gitignored, so a fresh clone couldn't assemble
`pokemon_data.asm`. Now generated by `tools/gen_growth_rates.py` from
`data/growth_rates.asm` (dn/sign-magnitude macro logic) and wired into the
Makefile `assets` target alongside `gen_base_stats.py`.

**Status / validation.** All POKEMON_SRCS assemble (`-f coff`). A djgpp partial
link (`ld -r`) of the full pokemon closure succeeds with **zero unresolved
externals**. Native ELF harness (nasm `-f elf32` + `gcc -m32`, EBP→64KB buffer)
PASSES all three: `_RemovePokemon` (party-of-3, remove idx 1 → count 2, species
`[10,30,FF]`, structs/OT/nicks shifted, untouched mon intact), `LoadMonData_`
(party mon 0 Bulbasaur $99 → struct copied to wLoadedMon, base stats HP $2D /
Grass $16 / Poison $03), `SetPartyMonTypes` (writes Grass/Poison to MON_TYPE).
The full `make` link is blocked only by the unrelated rgbds map-asset bootstrap
(`*_blk.inc` ← `.2bpp`), which affects `overworld.o`, not pokemon code.

---

## Pokémon engine — Stage 6 learnset/moves core (data + WriteMonMoves + integration)

- **Source:** `engine/pokemon/evos_moves.asm` (GetMonLearnset, WriteMonMoves,
  WriteMonMoves_ShiftMoveData), `engine/pokemon/add_mon.asm`
  (AddPartyMon_WriteMovePP + the _AddPartyMon move/PP path), `data/moves/moves.asm`,
  `data/pokemon/evos_moves.asm`
- **Translated:** `dos_port/src/engine/pokemon/write_moves.asm`,
  `dos_port/src/engine/pokemon/add_party_mon.asm` (integration + WriteMovePP),
  `dos_port/tools/gen_moves.py`, `dos_port/tools/gen_evos_moves.py`,
  `dos_port/src/data/pokemon_data.asm` (+globals), `gb_constants.inc` (MOVE_*),
  `gb_memmap.inc` (wLearningMovesFromDayCare/wDayCareStartLevel)
- **Date:** 2026-06-25
- **H-flag:** Not involved.
- **Bug tags:** None.

**Data (generated, never hand-authored).** `gen_moves.py` emits `Moves`
(165 × MOVE_LENGTH=6: anim,effect,power,type,acc,pp; the rgbds `percent` macro is
`* $ff / 100`). `gen_evos_moves.py` emits `EvosMovesPointerTable` + per-mon blobs
(evolution entries, db 0, level/move learnset pairs, db 0), resolving every db
operand against a merged EVOLVE_*/species/item/move constant table. **DOS
divergence:** the pointer table is flat 32-bit `dd` (program-image labels), not
pret's 16-bit `dw` bank pointers — so `GetMonLearnset` indexes it ×4 and reads a
32-bit pointer. Both wired into `pokemon_data.asm` and the Makefile `assets` target.

**Routines.** `GetMonLearnset` rewritten for the flat table (the draft read a
16-bit pointer and used it as a flat address — unusable). `WriteMonMoves` +
`WriteMonMoves_ShiftMoveData`: the learnset cursor (hl→ESI) is a FLAT program
pointer read with `[esi]`, while the mon's move slots (de→EDX) are GB WRAM read
`[ebp+edx]`; inside the shift branch ESI is reloaded from EDX and is a WRAM
offset. The day-care branch (`wLearningMovesFromDayCare != 0`) is translated but
unreachable today (no day-care system); its PP write reads the flat `Moves`
table directly (like GetMonHeader) rather than via EBP-relative FarCopyData —
TODO-DAYCARE. `AddPartyMon_WriteMovePP` likewise reads base PP straight from the
flat `Moves` table.

**Integration.** `_AddPartyMon`'s move/PP stubs are replaced: after writing the
level-1 base moves it sets `wPredefDE` = MON_MOVES base (the predef contract
`WriteMonMoves` restores via GetPredefRegisters) and calls `WriteMonMoves`, then
`AddPartyMon_WriteMovePP` for real PP.

**Validation (native ELF32 + gcc -m32 harness).** L15 Bulbasaur →
Tackle/Growl/Leech Seed/Vine Whip, PP 35/40/10/10 (base + L7/L13 learnset). L48
Bulbasaur exercises the slot-shift: base moves pushed out, final slots
Razor Leaf/Growth/Sleep Powder/SolarBeam, PP 25/…/10 — exact vs Gen-1. A djgpp
partial link (`ld -r`) of the full pokemon closure resolves with zero unresolved
externals. (Full `make` link still gated only by the unrelated rgbds map-asset
bootstrap.) DEFERRED: evolution flow, MonsterNames, bills_pc, TM/HM learnset bits.

---

## Pokémon engine — Stage 6 data: TM/HM bitfield + MonsterNames + default nickname

- **Source:** base_stats `tmhm` macro (macros/data.asm) + constants/item_constants.asm
  (TMNUM order); data/pokemon/names.asm + constants/charmap.asm; engine/pokemon/
  add_mon.asm (the AskName default-name behaviour)
- **Translated/generated:** `tools/gen_base_stats.py` (TM/HM bitfield now filled),
  `tools/gen_monster_names.py` (new), `src/data/pokemon_data.asm` (+MonsterNames),
  `src/engine/pokemon/add_party_mon.asm` (default nickname)
- **Date:** 2026-06-25
- **H-flag / Bug tags:** none.

**TM/HM bitfield.** `gen_base_stats.py` no longer zeroes the 7-byte field at +20:
it parses each species' `tmhm` move list (joining `\`-continued lines) and sets
bit (TMNUM-1) per move, where TMNUM is built from `item_constants.asm`'s `add_tm`
order (1..50) + `add_hm` order (51..55). Verified against the hand-computed
Bulbasaur field `A4 03 38 C0 03 08 06`. Consumers (TM-item usage) remain deferred.

**MonsterNames.** `gen_monster_names.py` encodes data/pokemon/names.asm with the
GB charmap (reusing the gen_npc_dialogs loader pattern) into 190 × 10-byte
'@'-padded records, internal-index order. Verified RHYDON / NIDORAN♂ (♂=0xEF).

**Default nickname (UI stub).** `_AddPartyMon` writes the species name from
MonsterNames into the new mon's nick slot — the non-UI outcome of pret's
`predef AskName`. STUB documented at `add_party_mon.asm:.nickCopy`: the
interactive naming screen is deferred; when built it should branch on
wMonDataLocation==0 and fall back to this default. MonsterNames is a flat table,
so it's read directly (not via EBP-relative CopyData). Native harness: gift
Bulbasaur nickname encodes to "BULBASAUR" (81 94 8B 81 80 92 80 94 91 50 50).

---

## Items engine — Stage 1: bag/PC inventory bookkeeping (no UI)

- **Source:** engine/items/inventory.asm (AddItemToInventory_, RemoveItemFromInventory_)
- **Translated:** dos_port/src/engine/items/inventory.asm (replaces the swarm draft),
  + WRAM aliases / BAG_ITEM_CAPACITY/PC_ITEM_CAPACITY in gb_memmap.inc/gb_constants.inc
- **Date:** 2026-06-25
- **H-flag / Bug tags:** none.

Pure data manipulation of a bag/PC inventory (count, then (id,qty) pairs, then
$FF). No UI. `RemoveItemFromInventory_` resets a few menu-state bytes (scroll/
cursor) — plain WRAM writes; the rendering that consumes them is UI elsewhere.

**Draft bug fixed:** the swarm draft advanced hl before the empty-inventory
zero-count test (pret's `ld a,[hli]` reads the count THEN increments), so a fresh
`00 FF` bag tested the wrong byte and misbehaved. The SM83 `push af`/`pop bc`
trick that stashes wItemQuantity is replaced by an explicit save/restore.

**Native validation (ELF32 + gcc -m32):** add-new, stack-existing, ≥100 overflow
(99 in slot + leftover in a new slot), bag-full rejection (CF clear), remove-
partial, and remove-to-zero (slot dropped, following slots shifted up) — all exact.

---

## Items engine — Stage 2 (partial): item names + prices data

- **Source:** data/items/names.asm (ItemNames), data/items/prices.asm (ItemPrices)
- **Generated:** dos_port/tools/gen_items.py -> assets/items.inc;
  src/data/item_data.asm (globals ItemNames/ItemPrices)
- **Date:** 2026-06-25 — pure data, no UI.

ItemNames: 97 names, GB-charmap encoded and '@'-terminated ($50), variable length
(as pret's `li` macro). ItemPrices: 97 x 3-byte BCD (pret's bcd3: nibble-packed
6-digit). Verified POKé BALL encoding (8F 8E 8A BA 7F 81 80 8B 8B 50) and prices
(MASTER_BALL 0, ULTRA_BALL 1200 -> 00 12 00, POKE_BALL 200 -> 00 02 00). No
consumer yet (mart/bag UI deferred); foundational data for those.

---

## Pokémon engine — Gen-2 forward-compat: held item in the catch-rate byte

- **Source:** engine/pokemon/add_mon.asm (the KADABRA / TWISTEDSPOON_GSC case)
- **Translated:** dos_port/src/engine/pokemon/add_party_mon.asm; constants +
  forward-compat notes in gb_constants.inc; CLAUDE.md "Gen 2 Forward-Compatibility".
- **Date:** 2026-06-25.

Restored the pret behaviour my _AddPartyMon rewrite had dropped: the
MON_CATCH_RATE byte (struct offset 7) is Gen 2's held-item slot across the Time
Capsule, so Kadabra (internal idx $26) is written holding TWISTEDSPOON_GSC ($60)
there. Documented that the party (44) / box (33) struct layout must stay
byte-identical to Gen 1 for the planned Gen 2 port — no shrinking/repurposing,
and party↔box/trade/save paths must carry offset 7 verbatim. Native harness:
Bulbasaur keeps catch rate 0x2D in +7; Kadabra shows 0x60.

---

## Overworld START menu — DisplayStartMenu

- **Source:** home/start_menu.asm (DisplayStartMenu), engine/menus/draw_start_menu.asm
- **Translated:** dos_port/src/engine/menus/start_menu.asm; trigger in
  src/engine/overworld/overworld.asm (OverworldLoop START-press); window
  generalization in src/ppu/ppu.asm; place_flat_str export in src/text/text.asm;
  LoadNPCSpriteTiles export in src/engine/overworld/map_sprites.asm.
- **Date:** 2026-06-25.

The corner menu box renders through the **GB window layer** (same path as the NPC
dialog box), not the BG: the box + item labels are drawn into wTileMap (the text
engine's 20-wide scratch grid, unused for BG in the overworld) with TextBoxBorder /
place_flat_str, then the 10×{14,16} box rect is copied into GB_TILEMAP1 and shown
by render_window. render_window gained two box-bound globals — **g_win_clip_w**
(blit width) and **g_win_max_y** (bottom row) — defaulting to SCREEN_W / RENDER_H
so the existing full-width bottom dialog box is byte-for-byte unchanged; the menu
narrows them to an 80px × {112,128}px corner box at WX=167 (the centered GB col 10).

**Font-swap gotcha (the whole reason text first rendered as garbage):** vFont
($8800) is time-shared with the player's/NPCs' walk tiles in the overworld, so the
glyphs are not resident until loaded. DisplayStartMenu mirrors the dialog path —
force the player to a standing pose, set BIT_FONT_LOADED (freezes NPC movement),
call LoadFontTilePatterns before drawing, and on close restore the walk tiles
(LoadNPCSpriteTiles + LoadPlayerSpriteGraphics). Input uses H_JOY_PRESSED (reliable
here: this loop calls DelayFrame exactly once per iteration, unlike OverworldLoop's
double-delay idle path). Pokédex slot is event-gated (EVENT_GOT_POKEDEX → 7 vs 6
items). All sub-menus are no-op stubs returning to the menu — **SAVE is an
intentional dead-end** (no save system) and the rest are hooks for the item / party
/ options UIs; EXIT / B / START close. Verified via the DEBUG_STARTMENU harness
(FRAME.BIN dump): box, border, cursor, and "POKéMON / ITEM / NINTEN / SAVE / OPTION
/ EXIT" all render correctly over Pallet Town; dialog box + baseline overworld
unaffected.

---

## Item effects (heal / cure / PP / wake / vitamin / rare candy) + mart data

- **Source:** `engine/items/item_effects.asm` (the `.addHealAmount` / `.cureStatusAilment`
  / `.restorePP` / `.useVitamin` / `.useRareCandy` cores), `data/items/marts.asm`
- **Translated:** `dos_port/src/engine/items/item_effects.asm`,
  `dos_port/tools/gen_items.py` → `assets/items.inc`
- **Date:** 2026-06-26
- **H-flag:** Not involved (8/16-bit add/sub with CF carried into `sbb`/`rcr`; no DAA/CPL).
- **Bug tags:** GLITCH(faithful) — Max-Ether/Max-Elixer PP-Up bug reproduced (full
  PP-restore path doesn't mask the upper two PP-Up bits, so a maxed move with PP Ups
  isn't detected as "no effect").

### Summary

Items-plan Stage 3 (non-UI effect math) + Stage 2 finish (mart inventories).

**Effects.** Lifted the pure WRAM-mutation cores out of the `ItemUse*` handlers,
dropping the surrounding text/menu/animation/in-battle-stat-copy (UI boundary).
Caller passes the target pointer (ESI) + amount (BL); CF returns had-effect.
Replaces the swarm draft, which (a) declared every constant `extern` instead of
`%include`-ing the const headers, and (b) had a 16-bit `mov dx,/mov bx,` width bug
in the evo-stone path. `ApplyHealingItem` keeps the big-endian HP layout and the
exact branch order (REVIVE → half-max; current≥max → clamp; FULL_RESTORE/MAX_POTION
/MAX_REVIVE → force max). x86 note: `dec`/`inc` preserve CF, so the borrow from the
`sub`/`sbb` HP compare and the `shr`→`rcr` half-max rotate survive the pointer
arithmetic between them.

`ApplyVitamin` adds 2560 stat exp (256*10) to the chosen stat's big-endian
stat-exp word MSB, capped when the MSB already reaches 100 (25600); the dead +255
clamp from pret is kept faithfully. `RareCandyLevelUp` is the data core of
`.useRareCandy`: +1 level (no-op at MAX_LEVEL), `CalcExperience` → set experience
to the new level's minimum, `CalcStats` recalc, then add (new max HP − old max HP)
to current HP. Ordering note: the experience write must precede CalcStats because
`H_EXPERIENCE` aliases `H_MULTIPLICAND` (CalcStats scratch). Both reuse the existing
pokemon-engine `CalcStats`/`CalcExperience`; the move-learn / evolution / stats-box
/ party-menu redraw tail is deferred (engine + UI).

**Deferred:** `Func_d85d` (evo-stone applicability) reads `EvosMovesPointerTable`,
which the DOS port stores with its own flat addressing (`evos_moves.asm`); the pret
`add hl,bc` ×2 / copy-2-bytes-as-a-pointer logic isn't a verbatim carry-over, so it
belongs with the evolution path. The X-stat / X-Accuracy / Guard Spec / Dire Hit
items are battle-engine integration (set a `wPlayerBattleStatus2` bit / call
`StatModifierUpEffect`), deferred to the battle work.

**Marts.** `gen_items.py` parses `script_mart ITEM, …` lines (resolving constant
names → ids from the `; $XX` comments in `item_constants.asm`, incl. `add_tm`/`add_hm`
→ `TM_`/`HM_`) and emits `MartInventories` (16 marts, each `db count, ids, $FF` —
the `script_mart` body minus the TX_SCRIPT_MART dispatch byte) + a flat `MartPointers`
dd-table + `NUM_MARTS`.

### Validation

Native ELF32 + `gcc -m32`, 38 checks all pass: potion partial/overheal-clamp,
revive half-max, antidote hit/miss + full-heal-any, ether +10/cap/already-full +
max-ether PP-Up bug, party sleep-clear + wake-flag set/clear, vitamin
add/cap/other-stat-untouched/last-stat (Calcium), and rare-candy
level+exp+new-maxHP+HP-delta + max-level no-op. The rare-candy test stubs
`CalcExperience`/`CalcStats` to inject known values (the real ones need the full
growth-rate / base-stat subsystems), so it validates this routine's pointer
arithmetic and HP-delta math; the production build links the real engine routines.
Mart bytes spot-checked vs pret (Viridian, Celadon-2F TM clerk). Full
`make SKIP_TITLE=1` links with `item_effects.asm` wired into `ITEMS_SRCS`.

---

## Mart money math + GetItemPrice (SubtractAmountPaidFromMoney_ / AddAmountSoldToMoney_ / GetItemPrice)

- **Source:** `engine/items/subtract_paid_money.asm`, `home/inventory.asm`
  (AddAmountSoldToMoney), `home/item_price.asm`, `data/items/tm_prices.asm`
- **Translated:** `dos_port/src/engine/items/subtract_paid_money.asm`,
  `dos_port/src/engine/items/item_price.asm`, `dos_port/tools/gen_items.py`
  (TechnicalMachinePrices)
- **Date:** 2026-06-26
- **H-flag:** Not involved (BCD via x86 `daa`/`das`; H is consumed inside the BCD
  helpers, not by these callers).
- **Bug tags:** None new. Reproduces the GB BCD overflow saturation (fill 0x99).

### Summary

Items-plan Stage 4: the non-UI buy/sell money math + item price lookup.

**Money.** `SubtractAmountPaidFromMoney_` BCD-compares wPlayerMoney vs hMoney
(MSB→LSB, `StringCmp`) and, if affordable, subtracts (`SubBCD`), returning CF=0
success / CF=1 can't-afford. `AddAmountSoldToMoney_` BCD-adds the sale total
(`AddBCD`). The MONEY text-box redraw + SFX_PURCHASE are UI, dropped. The prior
swarm draft fed `StringCmp` the operands in EDI/CL, but the port's StringCmp reads
EDX (de) and BL (c) — so the compare ran on stale registers; fixed, and the
`*Predef` wrappers (which reload args from predef regs) swapped for direct
`AddBCD`/`SubBCD` since we set the registers ourselves. Linking these also pulled
in `engine/math/bcd.asm` for the first time, surfacing a latent `sbc`→`sbb`
NASM-syntax error in SubBCD (fixed).

**Price.** `GetItemPrice` indexes the flat `ItemPrices` table for regular items
(`ItemPrices + 3*(id-1)`, big-endian BCD → hItemPrice) and tail-calls
`GetMachinePrice` for TMs/HMs (id ≥ HM01; HMs are priceless and leave hItemPrice
untouched). pret's ROM-bank juggling and the `wListMenuID == MOVESLISTMENU`
price-by-move special case are bank/UI concerns and dropped. `gen_items.py` now
emits `TechnicalMachinePrices` (50 TM prices in thousands, nybble-packed two-per-
byte high-first, matching rgbds `nybble_array`); `HM01`/`TM01` added to
gb_constants.inc.

### Validation

Native ELF32 + `gcc -m32`, 14 checks all pass: GetItemPrice for Poké Ball (200),
Ultra Ball (1200), Master Ball (0), TM01 (3000), TM02 (2000), priceless HM01
(hItemPrice untouched); subtract afford/can't-afford/exact (CF + money); add
normal + 999999 overflow saturation. Full `make SKIP_TITLE=1` links with the three
item files + shared compare.asm/bcd.asm wired into `ITEMS_SRCS`.

---

## Bag TOSS confirmation: in-window YES/NO menu (bag_menu.asm)

- **Source:** engine/items/item_effects.asm (TossItem_ confirm flow), home/item.asm
- **Translated:** `dos_port/src/engine/menus/bag_menu.asm`
- **Date:** 2026-06-26
- **H-flag:** Not involved.
- **Bug tags:** None.

### Summary

The bag's TOSS already had a quantity chooser + key-item guard + a direct
`RemoveItemFromInventory_` call ("logic complete"). This adds the missing
confirmation UI: a reusable in-window **YES/NO two-option menu** (`.yes_no_menu` /
`.draw_yes_no`) — a small bordered box drawn into the bag's window (wTileMap →
GB_TILEMAP1), UP/DOWN to move the ▶ cursor, A confirms, B = NO, default YES (top).
The `.render` copy loop was factored into a reusable `.copy_window` the menu shares.

Toss flow now: choose quantity → "THROW AWAY?" prompt + YES/NO → YES removes the
items, NO/B returns to the list. Selecting a key item or HM (which can't be tossed)
now shows a "TOO IMPORTANT!" notice (`.key_item_notice`) instead of the previous
silent no-op. Strings are inline charmap glyphs (letters $80+(c-'A'), '?'=$E6,
'!'=$E7), matching the existing `bm_str_cancel` pattern.

The USE branch remains deferred (most item effects are battle/UI coupled).

### Validation

Visual via the deterministic FRAME.BIN harness: `DEBUG_BAGMENU` confirms the list
still renders after the `.copy_window` refactor (no regression), and the new
`DEBUG_BAGMENU_CONFIRM` flag overlays the prompt + YES/NO box — verified the box,
border, "YES"/"NO" labels, cursor, and "THROW AWAY?" prompt render correctly over
the bag list. Production `make SKIP_TITLE=1` builds clean.

---

## 2026-06-26 — Battle Stage 9: wild-encounter generation (`LoadWildData`, `TryDoWildEncounter`)

Battle engine plan, Stage 9. New generator `tools/gen_wild_encounters.py` parses
`data/wild/` (the `WildDataPointers` order, the per-map `def_grass_wildmons` /
`def_water_wildmons` blobs, and `probabilities.asm`) and emits
`assets/wild_data.inc`: a flat `dd` `WildDataPointers` table (249 = NUM_MAPS,
mirroring the port's EvosMovesPointerTable pointer model), 60 unique map blobs
(`[grass_rate (+20 mon bytes iff !=0)][water_rate (+20 iff !=0)]`, species names
resolved to internal indices via `pokemon_constants.asm`), and the 10-entry
`WildMonEncounterSlotChances` cumulative table. Exposed by `src/data/wild_data.asm`.

`LoadWildData` (`src/engine/overworld/wild_mons.asm`) — faithful port of
`engine/overworld/wild_mons.asm`. Indexes `WildDataPointers[wCurMap]` (flat ×4),
reads the grass rate, copies 20 grass-mon bytes to `wGrassMons` (flat→WRAM inline
loop, since CopyData biases the source by EBP and the table is flat), then the
water rate + 20 water bytes. Preserves the faithful no-clear behaviour: a rate-0
section leaves the prior map's mon buffer untouched.

`TryDoWildEncounter` (`src/engine/battle/wild_encounters.asm`) — faithful port of
`engine/battle/wild_encounters.asm`. Gate bytes → standing-tile grass/water rate
select → `hRandomAdd` rate compare → `WildMonEncounterSlotChances` slot walk with
`hRandomSub` → species/level pick → repel check. Returns Z = encounter. The
overworld helpers (door/warp, just-outside-map, repel text) are deferred externs
(the overworld step *trigger* is the consumer), and the player-standing-tile read
is a `; TODO-OVERWORLD` placeholder (the port's 40-wide viewport differs from the
GB's 20-wide centred screen).

### Validation

Freestanding ELF32 harnesses (link the real `wild_data.o`; stub the overworld
externs). `LoadWildData`: PALLET all-zero, ROUTE_1 rate 25 / mons [3,36(PIDGEY),
4,36], ROUTE_19 water rate 5 / mons [5,24(TENTACOOL),…], plus the stale-retention
case. `TryDoWildEncounter`: rate-fail no-encounter; grass slot 0/1 → PIDGEY L3/L4;
water slot 0 → TENTACOOL L5; repel blocks (wild<lead) with step 3→2; indoor rate-0
no-encounter. All exact. Added `gcc-multilib` + `nasm` to the fresh container.

---

## 2026-06-26 — Battle Stage 5: stat-stage modifier effects (`StatModifierUpEffect` / `StatModifierDownEffect`)

Battle engine plan, Stage 5. Faithful translation of `engine/battle/effects.asm`'s
two stat-stage move-effect handlers into `src/engine/battle/stat_mod_effects.asm`,
with all their flow-control helpers (UpdateStat/UpdateStatDone, RestoreOriginal-
StatModifier, PrintNothingHappenedText, UpdateLoweredStat/Done, CantLowerAnymore
[_Pop], MoveMissed). Wired into BATTLE_SRCS.

The handlers bump the relevant stat-mod by ±1/±2 (clamped to the 1..13 stage
range — can't pass +6 or −6) and recompute the affected battle stat from the
unmodified stat via `StatModifierRatios` (the HRAM Multiply/Divide contract,
capping at 999 / flooring at 1, and reverting the mod bump when the stat is
already 999). Care points carried over faithfully: the `hProduct+2 == hMultiplicand+1`
overlap the GB relies on for the 999-cap write; the big-endian stat-pointer
arithmetic; the `StatModifierRatios` entry index = mod−1; the down-effect's
enemy-turn 25%/side-effect 33% rolls (`× $ff / 100` ⇒ 64 / 85).

The presentation tail — PrintStatText, PlayCurrentMoveAnimation(2), the
substitute/minimize Bankswitch dance, and the rose/fell/nothing-happened text —
is the deferred battle front end (declared `extern`, like the move_effects/*
files), so the file assembles (and all BATTLE_SRCS assemble) but does not yet link
into the EXE. `ApplyBadgeStatBoosts` (the third routine the Stage-5 plan line
names) was already done + validated earlier. There is no `GetStatMod` in pret; the
"unmodified-stat recompute helpers" the plan referenced are this inline recalc.

### Validation

Freestanding ELF32 harness linking the **real** Multiply/Divide + StatModifierRatios
(battle_data.o), stubbing the UI externs. Six cases, all exact: Up Atk +1 → mod 8 /
stat 150 (100×1.5); Up Atk +2 → mod 9 / 200; Up at mod 13 → no-op, stat untouched;
Up with stat already 999 → mod bump reverted; Down Atk −1 → mod 6 / 66 (100×0.66);
Down to mod 1 with unmod 1 (0.25×→0) → floored to 1.

---

## 2026-06-26 — Battle Stage 7: HandleBuildingRage

Battle engine plan, Stage 7 (one of the named remaining items). Faithful translation
of `engine/battle/core.asm:HandleBuildingRage` into `src/engine/battle/building_rage.asm`.
When the mon being attacked is under Rage, it flips hWhoseTurn, temporarily rewrites
the target's move to a null move with ATTACK_UP1_EFFECT, calls `StatModifierUpEffect`
(the new Stage-5 routine) to raise its Attack one stage, then restores the Rage move
number and the turn flag. PrintText/BuildingRageText are the deferred front end (extern).

Validated natively end to end (links the real StatModifierUpEffect + Multiply/Divide
+ StatModifierRatios): raging enemy-turn case → player Attack mod 7→8, stat 100→150,
wPlayerMoveNum restored to RAGE (63) / effect cleared / hWhoseTurn restored; no-op when
the target isn't raging or its Attack mod is already +6 (13). Wired into BATTLE_SRCS.

---

## 2026-06-26 — Battle: GetCurrentMove (move-record load backend)

Battle engine plan (a listed deferred backend item). Faithful translation of
`engine/battle/core.asm:GetCurrentMove` into `src/engine/battle/get_current_move.asm`.
Loads the selected move's 6-byte record (anim, effect, power, type, accuracy, pp)
from the flat `Moves` table into wPlayerMove*/wEnemyMove*, picked by hWhoseTurn,
including the debug TestBattle forced-move override. Like LoadWildData, it indexes
the flat table (esi = Moves + (id-1)*MOVE_LENGTH) and copies flat→WRAM inline,
since the port's FarCopyData/CopyData bias the source by EBP (for GB WRAM) whereas
Moves is a flat program-image table. wNameListIndex is set (the non-UI half); the
GetMoveName name fetch is the deferred UI tail.

This is the move-record load `MoveHitTest`, `CalculateDamage`, and the trainer-AI
move-scoring (`ReadMove`) all consume — so it unblocks the AI layer. Wired into
BATTLE_SRCS. Native-validated (links the generated Moves table): player move 1 →
[01,00,28,00,FF,23] + wNameListIndex 1; enemy move 2 → [02,00,32,00,FF,19];
TestBattle-forced move 3 → [03,1D,0F,00,D8,0A]. All exact.

---

## 2026-06-26 — Script engine Stage 5: RunMapScript dispatch skeleton

Script engine plan, Stage 5 (+ Stage 6 stub conventions). New
`tools/gen_map_scripts.py` → `assets/map_scripts.inc`: `MapScriptPointers`, a
flat `dd` table (249 = NUM_MAPS) indexed by `wCurMap`, each entry a map's `_Script`
(default `DefaultMapScript`, a no-op), with a `SCRIPT_OVERRIDES` registry naming the
ported maps (currently `PALLET_TOWN → PalletTown_Script`) — the same flat-pointer +
registry pattern as WildDataPointers and gen_npc_dialogs' SCRIPT_OVERRIDES. Exposed
by `src/data/map_scripts.asm`.

`RunMapScript` (`src/engine/overworld/run_map_script.asm`) — faithful translation of
home/overworld.asm:RunMapScript: runs the current map's `_Script` each overworld
frame via `MapScriptPointers[wCurMap]`. Boulder push / dust animation,
`RunNPCMovementScript` (already called at the top of OverworldLoop), and
`SwitchToMapRomBank` are deferred (no-op, see header). `CallFunctionInTable` is the
flat-`dd` port of home/scripting.asm:CallFunctionInTable (16-bit table → flat dd,
index ×4) that every map `_Script` uses to dispatch on its current-script index.
Wired into `OverworldLoop` (one `call RunMapScript` after `RunNPCMovementScript`).

`PalletTown_Script` (`src/scripts/pallet_town.asm`) — faithful skeleton of
scripts/PalletTown.asm:PalletTown_Script: the `EVENT_GOT_POKEBALLS_FROM_OAK` →
`EVENT_PALLET_AFTER_GETTING_POKEBALLS` event-gate, then `CallFunctionInTable` on
`wPalletTownCurScript` over `PalletTown_ScriptPointers` (flat dd, 10 states). The
cutscene states (Oak walk-up, Pikachu battle, Daisy) are recorded stubs
(`; STUB(battle,misc)`) deferred to the movement + battle milestone; state 0's Oak-
intro trigger is a `; STUB(misc)` no-op so the player moves freely.

### Validation

Freestanding ELF32 harness (links the real RunMapScript + CallFunctionInTable +
MapScriptPointers + PalletTown_Script; stubs ShowTextStream): CallFunctionInTable
dispatches index 0/1/2 to the matching routine; the Pallet event-gate sets
EVENT_PALLET_AFTER only when GOT_POKEBALLS is set; RunMapScript dispatches through
all 10 Pallet states and returns cleanly; a default map (ROUTE_1) → DefaultMapScript
no-op leaves scratch untouched. Script bundle partial-links (only ShowTextStream
external); overworld.asm assembles with the new call.

---

## 2026-06-26 — Script engine: EnableAutoTextBoxDrawing + faithful DefaultMapScript

Faithful translation of home/text.asm:EnableAutoTextBoxDrawing /
DisableAutoTextBoxDrawing (src/text/auto_textbox.asm): set wAutoTextBoxDrawingControl
(bit BIT_NO_AUTO_TEXT_BOX) and clear wDoNotWaitForButtonPressAfterDisplayingText.
Used by map _Scripts (and the wild-encounter repel message). Made the script
dispatch faithful: DefaultMapScript is now `jmp EnableAutoTextBoxDrawing` (most pret
map scripts that do nothing else are exactly that), and PalletTown_Script calls it
before CallFunctionInTable, matching pret. Added the two WRAM aliases +
BIT_NO_AUTO_TEXT_BOX; wired into GAME_SRCS. Native-validated: RunMapScript on a
default map sets wAutoTextBoxDrawingControl to 0 (auto-draw on).

---

## 2026-06-27 — Move data layer: names dispatcher, category helper, field moves

Covers move-data-plan Stages 3–5 (`docs/current_plan_moves.md`).

### Names (Stage 3) — `src/home/names.asm`
Faithful merge of `home/names.asm` + `home/names2.asm`. `GetName` dispatches on
`wNameListType` through a flat `NamePointers` `dd` table (**mixed addressing**:
Monster/Move/Unused/Item/Trainer names are flat data pointers walked via `[esi]`;
`wPartyMonOT`/`wEnemyMonOT` are WRAM, walked via `[ebp+esi]`). `MONSTER_NAME` →
`GetMonName` (fixed-width `AddNTimes`, faithful to pret — mon names stay fixed-width
by design); name types 2–7 walk `$50`-terminated source strings and `CopyData` a
**bounded** `NAME_BUFFER_LENGTH` (20) into `wNameBuffer`. Wrappers `GetMoveName`/
`GetItemName`/`GetMachineName`. `BUG` tag on the `cp HM01` machine-name branch (pret
`names2.asm:22`, range-guarded) and a `GLITCH` tag on the bounded name-walk
(out-of-range ids walk garbage source but the 20-byte destination copy can't
overflow → no ACE); `%if BUG_FIX_LEVEL >= 2` adds an index-validation placeholder.

### Category helper (Stage 4) — `src/engine/battle/move_category.asm`
`IsTypeSpecial` (AL = type id) and `IsMoveSpecial` (AL = move id; reads `MOVE_TYPE`
from the flat `Moves` table). Both return AL=1/CF=1 for special, AL=0/CF=0 for
physical — the `cp SPECIAL` / `jae` split pret uses inline in `core.asm`. Native-
validated (POUND → physical, FIRE PUNCH → special).

### Field moves (Stage 5) — `tools/gen_field_moves.py`, `src/engine/menus/field_moves.asm`
`gen_field_moves.py` emits `assets/field_moves.inc`: `FieldMoveDisplayData` (3-byte
records: move id, `FieldMoveNames` index, leftmost tile col; `$FF`-terminated) and
`FieldMoveNames` (`@`-terminated, 1-based index order) from
`data/moves/field_moves.asm` + `field_move_names.asm`, resolving move ids from
`constants/move_constants.asm`. `IsFieldMove` (AL = move id) is the linear scan from
pret `engine/menus/text_box.asm:GetMonFieldMoves` `.fieldMoveLoop`: walk the
`$FF`-terminated table, on a match take the 1-based name index and skip that many
`@`-terminated strings → CF=1 + flat `FieldMoveNames` pointer (CF=0/EAX=0 otherwise);
preserves EBX/ECX/EDX/ESI so party_menu's slot loop keeps its live registers.
`party_menu.asm` was rewired off its inline `MV_*` equ block, baked `fm_str_*`
strings, and `.field_move_name` cmp-chain to call `IsFieldMove` + the shared tables.
Lives in GAME_SRCS (linked) because party_menu calls it and `battle_data.asm`
(BATTLE_SRCS) is not yet linked. Native ELF32 harness: CUT/SOFTBOILED/FLASH → name,
POUND → not-found, ANIM_B4 → empty (unused slot); encoded name bytes byte-identical
to the removed baked strings; `DEBUG_PARTYMENU` `FRAME.BIN` party list unchanged.
`GetMonFieldMoves` (the `wFieldMoves[]` array fill) deferred — no caller yet and it
needs the not-yet-pinned `wFieldMoves` union WRAM aliases (see the plan).

### Effect-category arrays (Stage 6) — `tools/gen_effect_categories.py`
`gen_effect_categories.py` emits `assets/effect_categories.inc` from `data/battle/`:
`ResidualEffects1`, `ResidualEffects2`, `SpecialEffects` + `SpecialEffectsCont`
(the original's fallthrough with a single `$FF` terminator), `AlwaysHappenSideEffects`,
`SetDamageEffects` — each a `$FF`-terminated byte list of move-effect ids, resolved
from `constants/move_effect_constants.asm` (handles `const_def`/`const`/`const_skip`).
Exposed as globals via `battle_data.asm` (BATTLE_SRCS, not yet linked). DATA ONLY —
no `MoveEffectPointerTable`, whose handler pointers would dangle until the effect
handlers are ported. The battle engine scans these linearly to classify a move's
effect (residual / special / always-happens-on-faint / sets-damage).

### PlayMoveAnimation stub (Stage 7) — `src/engine/battle/animations.asm`
Faithful skeleton of pret `engine/battle/animations.asm:MoveAnimation`'s
`.moveAnimation` decision. Only the strictly-needed branch is implemented: when
battle animations are OFF in the options (`bit BIT_BATTLE_ANIMATION, [wOptions]`
set), substitute a flat 30-frame `DelayFrames` so message pacing matches the
original. With animations ON the real playback (ShareMoveAnimations + PlayAnimation
+ PlayApplyingAttackAnimation screen shake) is a `; TODO-HW:` no-op deferred to the
battle-animation HAL. Added `BIT_BATTLE_ANIMATION`(=7)/`BIT_BATTLE_SHIFT`(=6) and a
`wOptions` pret-name alias (= `W_OPTIONS` = `$D354`) to `gb_memmap.inc`. In
BATTLE_SRCS; `make check` + full `SKIP_TITLE=1` link clean.

**Move data layer plan (`docs/current_plan_moves.md`) complete** — archived to
`docs/plans/moves.md`.

---

## Wave 1 — Unblocked Backend (headless, native-ELF32-validated)

Branch `wave1-battle-backend`. Parallel sonnet subagents authored each dedicated
.asm + native harness; orchestrator (opus) audited + integrated serially.

### Bill's PC box logic — `src/engine/pokemon/bills_pc.asm` (task 1)
Faithful port of pret `engine/pokemon/bills_pc.asm`: `KnowsHMMove`,
`BillsPCDepositLogic` (fail if party≤1 / box full → `_MoveMon` PARTY_TO_BOX +
`_RemovePokemon` from party), `BillsPCWithdrawLogic` (fail if box empty / party
full → `_MoveMon` BOX_TO_PARTY [CalcStats recompute] + `_RemovePokemon` from box),
`BillsPCReleaseLogic`. Audit vs draft: externs corrected `MoveMon`/`RemovePokemon`
→ `_MoveMon`/`_RemovePokemon`; `push/pop bx`→`ebx`; redundant local %defines
dropped for the gb_constants includes; a local `IsInArray` added (array.asm lacks
it). Gen-2 forward-compat: MON_CATCH_RATE (offset 7) preserved by deposit (copies
33B verbatim) and withdraw (CalcStats starts at MON_STATS=$22) — verified in
harness. Native ELF32: 24/24 assertions (HM detection, deposit/withdraw/release
success+fail paths, counts, species list, offset-7 retention). **Check-only**
(POKEMON_CHECK_SRCS): not linked — needs a link-ready `_MoveMon` (the `add_mon.asm`
draft has a duplicate `AddPartyMon_WriteMovePP` + extern-constant errors). PC menu
UI deferred.

### JumpMoveEffect dispatch seam — `src/engine/battle/effects.asm` (task 6)
Faithful port of pret `engine/battle/effects.asm` (`JumpMoveEffect`/`_JumpMoveEffect`)
+ `data/moves/effects_pointers.asm` (`MoveEffectPointerTable`). Reads `hWhoseTurn`
→ selects `wPlayerMoveEffect`/`wEnemyMoveEffect`, `dec`→×4 index into an 86-entry
flat `dd` table, `jmp dword [esi]` tail-call (handler `ret` → `mov bh,1; ret`).
pret `dw` (16-bit bank-relative) → `dd` (32-bit flat); index ×2 → ×4. A NASM `%if`
arity guard `%fatal`s on table drift from 86 entries. 14 handlers wired
(StatModifierUp/Down, PayDay_, Conversion_, Haze_, OneHitKO_, Mist_, FocusEnergy_,
Recoil_, Heal_, Paralyze_, LeechSeed_, + DrainHP_ at $03/$08 after promoting
`DrainHPEffect_` to `global` in drain_hp.asm); the remaining ~72 effects route to a
shared `UnportedMoveEffect` no-op (header lists each + its pret handler for Wave 2).
Native ELF32: 17/17 dispatch tests (index math, player/enemy path, first/last
boundary, BH=1 postcondition, Unported no-clobber). BATTLE_SRCS (check-only, not
linked until the Wave-2 loop calls it).

### Residual damage — `src/engine/battle/residual_damage.asm` (task 2)
Faithful port of pret `engine/battle/core.asm` `HandlePoisonBurnLeechSeed`
(+`_DecreaseOwnHP`/`_IncreaseEnemyHP`). End-of-turn Poison/Burn = 1/16 maxHP
(min 1); Toxic multiplies by an escalating counter; Leech Seed drains the seeded
mon and heals the opposing mon (overheal clamped to maxHP). Two pret glitches
carried (no BUG_FIX_LEVEL guard, neither independently fixable): the Leech-Seed +
Toxic counter interaction (counter bumped per DecreaseOwnHP call, incl. the Leech
path) and the overkill heal (BX uncapped when HP < drain). Deferred UI externs
(stubbed in the harness): PrintText, PlayMoveAnimation, DrawHUDsAndHPBars,
DelayFrames, UpdateCurMonHPBar (must preserve BX), HurtBy{Poison,Burn,LeechSeed}Text.
Aliases added in PREP: wAnimationType/wPlayerToxicCounter/wEnemyToxicCounter,
ABSORB/BURN_PSN_ANIM. Native ELF32: 10/10 (poison/burn 1/16+min-1, toxic
escalation, overkill, leech drain+heal, overheal clamp, faint/alive flags, 16-bit
maxHP, enemy-turn heal). BATTLE_SRCS check-only.

### GainExperience — `src/engine/battle/experience.asm` (task 4)
Audited + fixed the battle-side EXP draft (NOT the pokemon-side CalcExperience,
which was already done). 10 fixes vs the swarm draft: hExperience→H_EXPERIENCE;
wPlayerID/wCalculateWhoseStats added to includes; PIKAHAPPY_LEVELUP/
LEVEL_UP_STATS_BOX defined; FlagActionPredef→FlagAction at all 4 sites (the predef
variant clobbers ESI via GetPredefRegisters); `dec esi`→`sub esi,2` in the max-EXP
overwrite path (reach the high byte at MON_EXP, not the middle); CopyData dest is
EDX not EDI; CallBattleCore `call BattleCore`→`call esi; ret` (flat function-pointer
dispatch); full extern decls. Headless math (stat-exp gain w/ 0xFFFF cap, exp award
×baseExp×level/7, BoostExp ×1.5, DivideExpDataByNumMonsGainingExp) native-validated
6/6. Deferred Wave-2 externs: PrintText, GetPartyMonName, LoadMonData,
ModifyPikachuHappiness, PrintStatsBox, WaitForTextScrollButtonPress,
Save/LoadScreenTilesFromBuffer1, PrintEmptyString, LearnMoveFromLevelUp, and the
CallBattleCore targets (CalculateModifiedStats, ApplyBurnAndParalysisPenalties-
ToPlayer, ApplyBadgeStatBoosts, DrawPlayerHUDAndHPBar). BATTLE_SRCS check-only.

### Trainer AI + read_trainer_party — `src/engine/battle/{trainer_ai,read_trainer_party}.asm` (task 3)
trainer_ai.asm: AIEnemyTrainerChooseMoves, AIMoveChoiceModification1/2/3/4 +
AIMoveChoiceModificationFunctionPointers (flat dd), TrainerClassMoveChoiceModifications,
StatusAilmentMoveEffects, ReadMove, TrainerAI/TrainerAIPointers (dd 5B/entry vs pret
dbw), AICheckIfHPBelowFraction/AICureStatus/DecrementAICount; AIUseX*/AIRecoverHP/
switch actions with UI parts stubbed as local no-ops. SM83 `ret z/nz`→`jnz/jz+ret`;
`~(1<<BADLY_POISONED)` byte mask. **AUDIT (orchestrator): the draft's item-id equs
were WRONG** (SUPER_POTION/FULL_RESTORE/GUARD_SPEC/DIRE_HIT/X_* off); replaced with
correct constants/item_constants.asm values in gb_constants.inc (X_ACCURACY_ITEM→
X_ACCURACY). read_trainer_party.asm: ReadTrainer — link-battle skip, flat/special
level blob parse, SpecialTrainerMoves override loop, prize-money via AddBCDPredef
(stubbed). Both native-validated (7/7 + 3/3; item-use branches not exercised — hence
the audit). BATTLE_SRCS check-only. DEFERRED (reported): `TrainerDataPointers` +
`SpecialTrainerMoves` need a `tools/gen_trainer_parties.py` generator + a
battle_data global; `AddBCDPredef` needs the predef BCD adder. Aliases added:
12 WRAM (wAICount/wAIItem/wBuffer/wEnemyMon1*/wTrainer*/…) + EFFECT_01/
XSTATITEM_DUPLICATE_ANIM/NUM_TRAINERS + 10 item ids.

### Evolution + level-up move learning — `src/engine/pokemon/evolution.asm` (task 5)
Authored by the (killed) sonnet subagent; completed + audited + validated by the
orchestrator. Routines: TryEvolvingMon, EvolutionAfterBattle, EvolveMon (UI stub),
RenameEvolvedMon, CancelledEvolution, LearnMoveFromLevelUp, GetMonLearnset_Evo[_BlobStart].
**Orchestrator fixes:**
1. Include paths `dos_port/include/...` → `gb_memmap.inc`/`gb_constants.inc` (the
   documented swarm bug; only "assembled" before because it was tested from repo root).
2. **Real flag bug in LearnMoveFromLevelUp**: `cmp al,bh` (level match) was followed
   by `mov al,[esi]` + `inc esi` before `jne` — x86 `inc` clobbers ZF (SM83 `inc hl`
   does not), so the level compare was destroyed and NO move was ever learned. Fixed
   `inc esi`→`lea esi,[esi+1]` (flags-preserving). This was the killed agent's
   unresolved "Test 5" failure (its own harness also linked a STUB EvosMovesPointerTable,
   masking the data path).
3. Exported GetMonLearnset_Evo_BlobStart (global) for reuse/validation.
**Native ELF32 (real pokemon_data.o table, 3/3):** GetMonLearnset_Evo_BlobStart(Bulbasaur
=0x99) → evo entry [EVOLVE_LEVEL,16,IVYSAUR=0x09] (i.e. Bulbasaur L16→Ivysaur);
GetMonLearnset_Evo → learnset start [7,LEECH_SEED]; LearnMoveFromLevelUp@L13 → Vine Whip
written to the empty slot.
**KNOWN BUG deferred to Wave 2 (documented in-file):** EvolutionAfterBattle's
evolution-success path has a stack imbalance (double-pop consumes the function-saved
DE; species write uses a wrong pointer). It only triggers on an actual evolution,
which needs the deferred deps (FlagActionPredef/LoadMonData_/CalcStats) — so it's
unvalidated and must be fixed+validated end-to-end in Wave 2.
POKEMON_CHECK_SRCS (check-only): evolution depends on GetName (check-only names.asm),
FlagActionPredef, and pikachu, so it isn't linked into the EXE yet.

### Sprite decompressor — `src/gfx/uncompress.asm` (Wave 2, Stage 1c-i, 2026-06-29)
Faithful 1:1 port of `home/uncompress.asm` (the runtime SM83 sprite decompressor):
UncompressSpriteData/`_UncompressSpriteData`/UncompressSpriteDataLoop,
MoveToNextBufferPosition, WriteSpriteBitsToBuffer, ReadNextInputBit/Byte, UnpackSprite,
SpriteDifferentialDecode, DifferentialDecodeNybble, XorSpriteChunks, ReverseNybble,
ResetSpriteBufferPointers, UnpackSpriteMode2, StoreSpriteOutputPointer + the 5 const
tables. Decodes the RLE + length-encoded bit stream into two column-major 1bpp planes
(sSpriteBuffer1/2), then differential-decodes / XOR-merges per the stream's unpack mode.
Ported faithfully (not a build-time PNG→2bpp shortcut) so Gen-1 sprite/ACE glitches that
depend on the decoder's behavior on malformed data survive (user directive 2026-06-28).
**Control-flow fidelity:** the GB ends its "endless" decode loop by popping the loop's
return address off the stack (`MoveToNextBufferPosition .allColumnsDone: pop hl`); the
port keeps this verbatim as `pop esi`, so the coupled cluster (`_UncompressSpriteData`,
the Loop, MoveToNext, UnpackSprite, SpriteDifferentialDecode, XorSpriteChunks,
UnpackSpriteMode2) carries **no register-saving prologue** — durable state lives in the
WRAM vars, registers are transient (GB model). Leaf helpers are balanced.
**Addressing:** GB state ($D0A0+ scratch), the input stream, and the 3 sprite buffers
($A188/$A310) are EBP-relative; the const decode/reverse/offset tables are flat `.data`;
the per-call differential table is held in flat 32-bit `.bss` selectors `sp_dtbl0/1`
(the 16-bit `wSpriteDecodeTable*Ptr` GB vars can't hold a flat address — left unused).
**Native byte-exact validation (`gcc -m32` harness):** an asm shim sets EBP=GB base and
calls UncompressSpriteData; the harness reassembles buffer1(even)/buffer2(odd) +
`transpose_tiles` exactly as `tools/pkmncompress.c` does, then compares to the canonical
`.2bpp`. **353/353 committed pics byte-exact** — front 153, back 151, trainers 46,
battle 3 — covering all unpack modes (0/1/2) and both plane orders. The flipped path
(back pics) runs deterministically; its byte-exact check belongs to Stage 1c-ii, where
`InterlaceMergeSpriteBuffers`'s nybble-swap completes the horizontal flip. Linked via
FRONTEND_SRCS (only extern = FillMemory). Note: `pkmncompress -u <pic>` == the committed
`.2bpp` (verified), so it is the canonical decode oracle. Harness is ephemeral (scratchpad).

### Mon-pic merge/scale + placement — `src/gfx/pics.asm` (Wave 2, Stage 1c-ii, 2026-06-29)
Ports home/pics.asm (LoadUncompressedSpriteData, AlignSpriteDataCentered, ZeroSpriteBuffer,
InterlaceMergeSpriteBuffers) + engine/battle/scale_sprites.asm (ScaleSpriteByTwo and helpers
ScaleFirstThreeSpriteColumnsByTwo / ScaleLastSpriteColumnByTwo / ScalePixelsByTwo +
DuplicateBitsTable). Pairs with the validated decoder (uncompress.asm): front pics are
centered in a 7x7 buffer (AlignSpriteDataCentered), back pics are 2x-scaled from 4x4→7x7
(ScaleSpriteByTwo); both then InterlaceMergeSpriteBuffers interleaves the two 1bpp planes
(buffer0=MSB, buffer1=LSB) into the 2bpp sprite, nybble-swaps if wSpriteFlipped, and the
port copies the 49 tiles (784 B) from sSpriteBuffer1 to VRAM + sets g_tilecache_dirty.
**Placement:** the battle BG uses SIGNED tile addressing (LCDC bit4=0), so tile IDs $00-$7F
map to VRAM $9000-$97F0; PlacePicTilemap fills a 7x7 W_TILEMAP block column-major (ID =
base + col*7 + row), matching the merged buffer's tile order (faithful to
CopyUncompressedPicToTilemap). Enemy front pic → VRAM $9000 (tile $00), canvas (22,3);
player back pic → VRAM $9310 (tile $31), canvas (11,8). The back pic's tile range $31-$61
(VRAM $9310-$961F) abuts the HP-bar tiles at $9620; the 2-tile overlap at IDs $60/$61 hits
only the box set's unused font_extra glyphs, so it is cosmetically safe. **Verified:**
FRAME.BIN renders a full faithful battle screen (Pidgey front + Pikachu back) — user
signed off both sprites. Test stubs (DrawEnemyFrontPic_Stub/DrawPlayerBackPic_Stub) embed
pidgey/pikachub .pic via incbin and are driven from the DEBUG_BATTLE harness; the real
species→pic-pointer path is a Stage 2/3 data-layer task. Wired into FRONTEND_SRCS.

### Enemy turn + wild AI + wild moveset generation (Wave 2, Stage 2b, 2026-06-29)
Three linked pieces extending the player-attack path into a full battle round.

**Enemy turn** (`src/engine/battle/battle_menu.asm`): `ExecutePlayerTurn` is now a full-round
handler — choose the enemy move (`SelectEnemyMove`), order the two battlers by speed
(player first if wBattleMonSpeed >= wEnemyMonSpeed; Quick Attack/Counter priority + random
tie-break deferred), run the faster one's attack, and if its target faints the round ends
(no retaliation). New `DoEnemyAttackDamage` (mirror of `DoPlayerAttackDamage`: hWhoseTurn=1,
GetCurrentMove → GetDamageVarsForEnemyAttack → CalculateDamage → AdjustDamageForMoveType →
RandomizeDamage, drains wBattleMonHP), `RenderEnemyTurn` ("Enemy <nick> / used <move>!", the
faithful `<USER>`="Enemy "+nick on the enemy's turn per home/text.asm:PlaceMoveUsersName),
`ShowPlayerFainted`. Step helpers `PlayerAttackStep`/`EnemyAttackStep` return CF=1 on a
battle-ending faint. Accuracy/MoveHitTest still deferred (always hits); crit forced off.

**Wild AI** — `src/engine/battle/select_enemy_move.asm`: faithful port of
engine/battle/core.asm:SelectEnemyMove. The WILD random-move path (25% per slot, re-roll on
disabled/empty) is the whole enemy move choice AND the default stub for every opponent
(trainer-AI scoring `AIEnemyTrainerChooseMoves` deferred — both wild + trainer fall into
.chooseRandomMove). Forced-move early-outs (recharge/charge/thrash/freeze/sleep/trap/bide)
ret without choosing. Link path = TODO-HW (Phase 4). `percent` macro = n*$ff/100.

**Wild moveset generation** — `src/engine/battle/load_enemy_moves.asm` (`LoadWildMonMoves`):
faithful port of LoadEnemyMonData's `.copyStandardMoves`+`.loadMovePPs` — copy the 4 base
moves from the mon header (wMonHMoves), WriteMonMoves fills the level-up learnset
(assets/evos_moves.inc, already generated) up to the level, LoadMovePPs writes base PP.
Also ported `LoadMovePPs`/`AddPartyMon_WriteMovePP` into `src/engine/pokemon/write_moves.asm`
(flat-`Moves` PP read, like its daycare branch). Sets wCurPartySpecies (GetMonLearnset key)
+ wCurEnemyLevel + wPredefDE/HL for the two predef calls. NOTE (Gen 1): enemy PP is loaded
for parity but never decremented; TM/HM moves are not part of wild generation (player-only
learnset category). All three wired into FRONTEND_SRCS.

**Validation (headless DUMP.BIN via DEBUG_BATTLE_ENEMYHIT, a new scripted one-shot gate):**
PIDGEY ($24) L3 → wEnemyMonMoves=[GUST $10,0,0,0], wEnemyMonPP[0]=35 (GUST base PP);
SelectEnemyMove picks GUST; wEnemyMove*=[$10,$00,$28(40),$FF(100%)]; GUST deals 5 (STAB,
neutral) → player HP 11→6. Level-up fill proven at L13 → [GUST,SAND_ATTACK $1c,QUICK_ATTACK
$62,0], matching PidgeyEvosMoves. Live FRAME.BIN sign-off pending (enemy turn already
visually confirmed by the user).

### HP-drain animation — `src/engine/battle/battle_hud.asm` (Wave 2, Stage 2b, 2026-06-29)
The port's stride-agnostic stand-in for pret UpdateHPBar (engine/gfx/hp_bar.asm). The battle
HUD already replaces pret's tile-based DrawHPBar with draw_hp_bar/calc_hp_pixels (the 40-wide
canvas needs stride-agnostic drawing), so the animation replicates the BEHAVIOR rather than
porting DrawHPBar: `AnimateEnemyHPBar`/`AnimatePlayerHPBar` tick the displayed HP from a passed
old value (ECX) toward the final value in WRAM one unit at a time, redrawing the gauge on each
PIXEL change with a 2-frame DelayFrame wait (pret's cadence); the player HUD's "cur" digits tick
alongside via print_num3. Factored `hp_to_pixels` (HP value in EAX) out of calc_hp_pixels so the
loop can price an arbitrary ticking HP. Loop state kept in BSS so draw_hp_bar/print_num3/DelayFrame
clobbering can't corrupt it; the entries take registers. RenderPlayerTurn/RenderEnemyTurn reordered:
DrawBattleHUDs at PRE-attack HP → print "<mon> used <move>!" → DoXAttackDamage → animate the
defender's bar (so the gauge starts full and drains). A 0-difference (status move / miss) animates
nothing. User signed off the live drain.

### Battle terminal states (Stage 2c) — `src/engine/battle/battle_menu.asm` (Wave 2, 2026-06-29)
Clean win/lose termination so the battle loop ends instead of re-looping the menu forever. New
`wBattleOver` flag (0 ongoing / 1 win / 2 lose): ExecutePlayerTurn sets it from which side fainted
(PlayerAttackStep CF=1 → enemy fainted → win; EnemyAttackStep CF=1 → active mon fainted → lose),
DisplayBattleMenu's FIGHT path breaks its `jmp DisplayBattleMenu` loop when it is nonzero, and the
DEBUG_BATTLE_LIVE harness resets it at battle start, polls it after each menu turn, and on end calls
new `EndBattleScreen` (blank the canvas + present) as a clean terminal. DEFERRED: multi-mon
switch-in (any active-mon faint currently ends the battle as a loss — pret would prompt to send out
another party mon) and the real exit path — Stage 3 returns to the overworld and runs the victory
EXP screen (Wave-1 GainExperience). EndBattleScreen's blank canvas is the placeholder for that.
Live sign-off pending.

### Turn-order quirks (Quick Attack priority + speed-tie) — battle_menu.asm (Wave 2, Stage 2b, 2026-06-29)
Replaced ExecutePlayerTurn's speed-only ordering with the faithful pret order (engine/battle/
core.asm:.noLinkBattle): Quick Attack ($62) takes priority; Counter ($44) always moves last;
otherwise compare wBattleMonSpeed vs wEnemyMonSpeed (big-endian), with a 50/50 BattleRandom break
on a tie (`50 percent + 1` = 128). pret's internal-clock tie invert is link-battle only → TODO-HW
(Phase 4). Added QUICK_ATTACK to gb_constants.inc (COUNTER was already there). Observable in the
DEBUG_BATTLE_LIVE demo: when the random wild AI rolls QUICK ATTACK and the player picks a non-QA
move, "Enemy PIDGEY used QUICK ATTACK!" resolves before the player's move despite Pikachu being
faster. Live sign-off pending.

### FIGHT-menu cursor persistence — battle_menu.asm + init_battle.asm (Wave 2, Stage 2a polish, 2026-06-29)
Fidelity fix (user observation, confirmed vs pret): the FIGHT move-list cursor must remember the
last-highlighted move across move uses AND menu exits for the whole battle, cleared only at battle
start. pret keeps it in wPlayerMoveListIndex: MoveSelectionMenu (.menuset, core.asm:2645) inits the
cursor from it, and core.asm:2745 writes it on BOTH select (A) and back (B) — which is why backing
out preserves it too. The port previously hardcoded wCurrentMenuItem=0 in DrawMoveList every open
(always snapped to the first move). Now: DrawMoveList restores wCurrentMenuItem from
wPlayerMoveListIndex (clamped to the real move count); MoveSelectionMenu writes wPlayerMoveListIndex
= wCurrentMenuItem after WideHandleMenuInput (covers A and B); InitBattle clears wPlayerMoveListIndex
at battle start (it sits outside InitBattleVariables' clear block — a deliberate port-side clear).
wPlayerMoveListIndex was already aliased ($CC2E). Live sign-off pending.

### Battle intro: real mon name + blinking ▼ — init_battle.asm + battle_menu.asm (Wave 2, intro polish, 2026-06-29)
Intro polish (user, software-native battle-entry pass, order text→balls→slide). (1) intro text now
pulls the real mon name: "Wild <wEnemyMonNick>" / "appeared!" (faithful _WildMonAppearedText) instead
of the fixed "Wild POKéMON". (2) The intro is now actually SHOWN: it was drawn by InitBattle then
instantly covered by the menu; the live flow waits for A/B on it first (faithful PrintBeginningBattleText
pausing before the menu). (3) WaitForAPress now BLINKS the ▼ text-advance arrow (tile $EE) at the dialog
box's bottom-right interior (canvas 28,19), toggling vs space every ~20 frames — the port's take on
WaitForTextScrollButtonPress/HandleDownArrowBlinkTiming; applies to every battle text wait (intro/attack/
faint). New DEBUG_BATTLE_INTRO FRAME hook dumps the intro screen (verified: "Wild PIDGEY appeared!" + ▼).
Next: party-status pokéballs (DrawAllPokeballs) + a placeholder Bug Catcher trainer to test the enemy ball row.

### Battle-intro party pokéballs (OAM) — pokeballs.asm + sprite_oam.asm + battle_hud.asm (Wave 2, 2026-06-29)
Step 2 of the battle-entry polish (user: OAM sprites like pret, intro-only). New pokeballs.asm =
faithful DrawAllPokeballs/SetupPokeballs/PickPokeball/WritePokeballOAMData: balls.2bpp (ok/status/
fainted/empty) loads into the free OBJ tile area ($8000 tiles $00-$03), the party-status row is written
as OAM entries (PickPokeball: HP==0→fainted, status!=0→status, else ok; past count→empty), and a new
ppu helper PrepareStaticOAM fills render_sprites' DOS position tables straight from $FE00 (DOS=OAM-16/-8)
so the balls composite without the wSpriteStateData/PrepareOAMData path (update_oam is gated off in
battle). DrawBattlePokeballs sets IO_OBP0=$E4 + LCDCF_OBJ_ON; HideBattlePokeballs (HideSprites + clear
OBJ) hands off to the HP-bar HUD. Faithful sequencing: DrawBattleHUDs split into DrawEnemyHUD/DrawPlayerHUD;
InitBattle now draws only the enemy HUD (intro shows player balls, not the player HP bar), and the live
intro does DrawBattlePokeballs → WaitForAPress → HideBattlePokeballs before the menu draws the player HP bar.
Positions = pret OAM coords + the battle centering (+80,+24). Wild = player row only; trainer (wIsInBattle==2)
adds the enemy row at OAM entries 6-11. VERIFIED (DEBUG_BATTLE_INTRO FRAME histogram + PNG): 6 balls at the
player position, no player HP bar. Remaining: Bug Catcher test trainer (enemy ball row) + status-variety seed.

### Battle HUD frame tiles + persistent shelf — LoadHudTilePatterns + gen_battle_hud_inc.py (Wave 2, 2026-06-29)
Root-caused the "missing divider" the user flagged: pret's LoadHudAndHpBarAndStatusTilePatterns is TWO
loads — LoadHpBarAndStatusTilePatterns (font_battle_extra → $62, ported) AND LoadHudTilePatterns
(BattleHudTiles1 → vChars2 $6d, BattleHudTiles2+3 → $73), which OVERWRITE the font_extra "ID No."
placeholders at $73/$74 with the real HUD frame pieces ($73 vertical, $74/$77 corners, $76 line,
$78/$6f triangles). The port only ported the first load, so $73/$74 kept "ID No." (confirmed: generated
.inc == source .2bpp, so no generator/load bug — the tiles simply were never loaded). FIX (generator,
per project rule — never hand-edit tiles): new tools/gen_battle_hud_inc.py emits assets/battle_hud_2bpp.inc
from gfx/battle/battle_hud_{1,2,3}.png (1bpp expanded 1bpp→2bpp doubled, = FarCopyDataDouble); new
LoadHudTilePatterns (src/gfx/load_font.asm) loads tiles1 @ $6d and tiles23 @ $73; InitBattle calls it
after LoadHpBarAndStatusTilePatterns. Re-applied the faithful PlaceHUDTiles port (DrawEnemyHUDFrame/
DrawPlayerHUDFrame/place_hud_frame in battle_hud.asm). PERSISTENCE FIX (user): pret draws the player
shelf in BOTH the pokéball intro (SetupOwnPartyPokeballs) AND the HP-bar HUD (DrawPlayerHUDAndHPBar), so
it survives the send-out; the port now calls DrawPlayerHUDFrame from DrawPlayerHUD too. To give the shelf
its own row, the player HUD shifted up one row (name/lv/bar/frac canvas rows 10-13, +3 centering like the
enemy; shelf row 14) — the port previously used +4, colliding the frac with pret's shelf row. Also this
thread: intro text pulls the real mon name + blinking ▼ arrow (WaitForAPress); party pokéballs as OAM
sprites (pokeballs.asm + PrepareStaticOAM). User-signed-off live. Remaining: Bug Catcher enemy ball row +
fainted/status ball variety; darkened silhouette slide-in.

### Trainer sprite data generator — gen_trainer_pics.py + trainer_pics.asm (Wave 2, 2026-06-29)
Generated all trainer battle graphics up front (user, saves time before trainer battles).
New tools/gen_trainer_pics.py → assets/trainer_pics.inc: parses gfx/pics.asm (pic label → .pic
file, incl. bare-alias labels like ChiefPic reusing ScientistPic) + data/trainers/pic_pointers_money.asm
(class-ordered pic_money) → emits 45 unique `incbin "../gfx/trainers/*.pic"` blobs, TrainerPicPointers
(flat dd, 47 classes, index = trainer class - 1, mirroring pret TrainerPicAndMoneyPointers), and
TrainerBaseMoney (bcd3 prize money). The .pic blobs are the same compressed format uncompress.asm
already validated byte-exact on all trainers, so a class's sprite loads like a wild mon's front pic.
Tier-2 wrapper src/data/trainer_pics.asm (section .data + globals) wired into FRONTEND_SRCS; Makefile
assets rule + `make assets` dep added. Links clean (18 KB data). Consumer (trainer _LoadTrainerPic
path) is Stage 4 / the Bug Catcher test. assets/*.inc is gitignored→force-track on commit (git add -f).

### Battle-entry silhouette slide-in — SlideBattlePicsIn (pics.asm) + faithful init flow (Wave 2, 2026-06-29)
Software-native port of pret SlidePlayerAndEnemySilhouettesOnScreen (its per-scanline SCX raster
trick can't be expressed in the tile renderer; user OK'd a software-native slide). Restructured the
battle-entry flow to match pret _InitBattleCommon order: InitBattle split into setup/clear vs new
DrawBattleIntroBox (box + "Wild <nick> appeared!" + enemy HUD); pic stubs made decode-only (VRAM only).
SlideBattlePicsIn clears the canvas + redraws both decoded pic blocks (PlacePicSlide, clipped to the
40-wide canvas, column-major tile IDs) at shifted columns each frame — enemy front slides in from the
right (col 22+step), player back from the left (col 11-step), step 18→0, 2 frames each — under a
silhouette BGP ($FC: color 0→light, 1-3→dark), then restores normal BGP at the final position. Harness
flow now: InitBattle → decode pics → SlideBattlePicsIn → DrawBattleIntroBox → pokeballs → menu.
Silhouette color: TODO(palette) — faithful = CGB SET_PAL_BATTLE_BLACK (Phase 5); stopgap (user-OK'd)
forces dmg_palette shade 3 → RGB black during the slide (saved/restored), so non-transparent pixels go
true black. dmg_palette made global. User signed off the slide ("looks decent enough"); black-tweak live.

### Player battle sprites (slide-in trainer + send-out) — gen_trainer_pics.py + pics.asm (Wave 2, 2026-06-29)
Fix (user): the wild slide-in showed Pikachu on the player side, but faithfully the PLAYER TRAINER back
sprite slides in (pret LoadPlayerBackPic → RedPicBack); the mon's back pic only appears after send-out.
Added PlayerPicFront (gfx/player/red.pic) + PlayerPicBack (gfx/player/redb.pic) to gen_trainer_pics.py
(generated data, globals in trainer_pics.asm). For the test harness, DrawPlayerRedBackPic_Stub decodes the
Red back (redb.pic, embedded; 4x4 like a mon back → LoadMonBackPicToVRAM) to VRAM $31 for the slide;
DrawPlayerBackPic_Stub (Pikachu) now runs at the intro→battle transition as the send-out (straight VRAM
swap over the same $31-$61 tilemap block, no grow animation yet — simplified AnimateSendingOutMon).
Verified (FRAME): intro shows the Red/Yellow trainer back + wild PIDGEY (user signed off). Also added a
TODO(glitch) to uncompress.asm: real mons stay in their dims box, but the GB decoder can write past it for
glitch sprites (MissingNo) — not separately exercised (the port decoded all real pics byte-exact).

### Bug Catcher trainer test + player party-status balls — debug_dump.asm + pics.asm (Wave 2, 2026-06-29)
Test harness for the enemy pokéball row + ball-status variety (user). New DEBUG_BATTLE_TRAINER seed
(combine with DEBUG_BATTLE_INTRO/LIVE): wIsInBattle=2, wEnemyPartyCount=3 with status variety (mon0 ok,
mon1 fainted HP=0, mon2 statused) + player party variety (mon1 fainted, mon2 statused), and loads the Bug
Catcher trainer sprite (DrawBugCatcherPic_Stub — 7x7 front-style via LoadMonPicToVRAM; embedded for the
test, real path = generated TrainerPicPointers). DrawBattleIntroBox now draws the enemy HUD only for wild
(wIsInBattle==1); a trainer shows the enemy ball row instead. VERIFIED (FRAME): Bug Catcher + player-trainer
back + BOTH ball rows (enemy top Y41-47, player bottom Y105-111) with ok/fainted/status/empty tiles.
Known rough edges (noted): trainer intro text still "Wild <nick> appeared!" (should be "<class> wants to
fight!"); a live trainer battle needs the enemy send-out + AI (Stage 4). Send-out (user note): faithfully
the trainer slides OUT then the mon comes in — starter PIKACHU just slides (no ball/grow, Yellow special),
others get ball-throw+grow; port does a straight VRAM swap for now (TODO(send-out) in code).

### RUN flow — TryRunningFromBattle (Wave 2, Stage 3, 2026-06-29)
Wired the battle menu's RUN option (was a no-op stub that re-opened the menu). Faithful port of pret's
`TryRunningFromBattle` + `BattleMenu_RunWasSelected` (engine/battle/core.asm) into `battle_menu.asm`
(`RunWasSelected`/`TryRunningFromBattle`/`PrintRunLine`). Wild-mon escape odds:
`(playerSpeed*32) / ((enemySpeed/4) % 256)`, +30 per prior run attempt, vs a `BattleRandom` roll;
playerSpeed ≥ enemySpeed → guaranteed escape; (enemySpeed/4)%256==0 or quotient>255 → escape. Uses the
real `Multiply`/`Divide` HRAM pipeline (hMultiplicand/hProduct/hDividend/hDivisor/hQuotient) byte-for-byte.
Outcomes: escape → "Got away safely!" + `wBattleOver=3` (new "ran" terminal, ends the harness `.live`
loop via the same path as win/lose); wild fail → `wActionResultOrTookBattleTurn=1`, "Can't escape!", then
the enemy gets its free attack (may KO → loss); trainer (`wIsInBattle==2`) → "No! There's no / running from
a / trainer battle!" (3-line, single-spaced), no turn consumed → re-menu. New aliases pinned from
origin/symbols: `wNumRunAttempts`=$D11F, `hEnemySpeed`=$FF8D (2B). Ghost/safari/run/link "always-escape"
special cases omitted (unreachable in the wild/trainer harness — TODO if those battle types are added).
Assembles + links clean into PKMN.EXE (FRONTEND_SRCS). Harness seeds PIKACHU spd 40 ≥ PIDGEY spd 21 → RUN
reliably escapes; the can't-escape branch needs a faster enemy to exercise. GATE: awaiting live user sign-off.

### Victory EXP screen — wire GainExperience live (Wave 2, Stage 3, 2026-06-29)
On enemy faint (`ExecutePlayerTurn.enemyFainted`) the front end now runs the Wave-1 `GainExperience`
(validated EXP/stat-exp/level math) and shows "<nick> gained / N EXP. Points!" via wide_text
(`battle_menu.asm:BattleWonGiveExp` + `print_dec`; N = `wExpAmountGained`). To LINK the previously
check-only `experience.asm` into PKMN.EXE: moved it from BATTLE_SRCS → FRONTEND_SRCS, added
`flag_action.asm` (fixed its include path: `dos_port/include/...`→`gb_memmap.inc`, added gb_constants
for FLAG_TEST + GetPredefRegisters extern), and added `battle_exp_stubs.asm` — link-only `ret` stubs
for GainExperience's deferred UI/display externs (GetPartyMonName, PrintStatsBox, Save/LoadScreenTiles
ToBuffer1, PrintEmptyString, WaitForTextScrollButtonPress, ModifyPikachuHappiness, CalculateModified
Stats, DrawPlayerHUDAndHPBar, ApplyBadgeStatBoosts, ApplyBurnAndParalysisPenaltiesToPlayer,
LearnMoveFromLevelUp, LoadMonData, + GainExpPrintStub). `experience.asm`'s two deferred `call PrintText`
display sites now call `GainExpPrintStub` (no-op) — the port's PrintText is the stride-20 OVERWORLD
renderer and would corrupt the 40-wide battle canvas; the display is done by the front end instead.
LEVEL-UP DATA is still updated by the real CalcStats inside GainExperience; only the level-up DISPLAY
(stats box / "grew to level N" / move learn) is deferred (stubs). LATENT COLLISION documented: when the
level-up-display step wires the real ApplyBadgeStatBoosts/ApplyBurnAndParalysis/LearnMoveFromLevelUp
(check-only backend) in, the matching stubs here must be deleted. Harness seeds PIDGEY base stats + base
exp 55 + party-slot-0 gain flag; expected "PIKACHU gained 102 EXP. Points!" (55*13/7, wild=no boost).
Links clean (FRONTEND_SRCS). GATE: awaiting live user sign-off. NOTE: harness battle-mon (PIKACHU,
seeded directly) ≠ party slot 0 (SNORLAX L80, from DEBUG_PARTY) — the LoadBattleMonFromParty-deferred
gap; the displayed name is wBattleMonNick (PIKACHU) and the EXP number is enemy-derived, so both read
correct on screen even though slot 0 receives the points.

### Level-up display — grew-text + level-up stats box (Wave 2, Stage 3, 2026-06-29)
The deferred half of the victory flow. GainExperience's per-mon display tail now calls real front-end
routines instead of stubs (battle_menu.asm): ShowGainedExpText ("<nick> gained / N EXP. Points!", waits),
ShowGrewLevelText ("<nick> grew / to level N!", no wait — pret GrewLevelText), PrintStatsBox (the level-up
stats box: ATTACK/DEFENSE/SPEED/SPECIAL with right-aligned values, pret PrintStatsBox.LevelUpStatsBox),
and WaitForTextScrollButtonPress (= WaitForAPress). This matches pret's per-mon order (gained → grew + box
→ one A-press), so the gained-EXP text moved from BattleWonGiveExp INTO GainExperience's loop (BattleWonGiveExp
is now just `call GainExperience`). The display reads the leveled PARTY mon directly (wPartyMon1 +
wWhichPokemon*PARTYMON_STRUCT_LENGTH stats / wPartyMonNicks nick / wCurEnemyLevel), so LoadMonData/
GetPartyMonName stay stubbed (no wLoadedMon dependency). New helpers print_num3 (3-digit right-aligned,
space-padded) + get_party_nick. Removed PrintStatsBox/WaitForTextScrollButtonPress/GainExpPrintStub from
battle_exp_stubs.asm (now real). Coords use pret CONTENT (the 4 stat labels + values) but wide-canvas
PLACEMENT (level-up box at canvas (26,2), 12x4) is a first pass to ITERATE with the user per the battle-UI
placement convention. Harness: gain flag moved slot 0 → slot 3 (PIKACHU L5 + 102 EXP → L6) so the leveling
mon matches the on-screen PIKACHU and exercises the level-up path. Builds + links clean (FRONTEND_SRCS).
The level-up stats box is the BATTLE one (distinct from the party-menu status screen — user note). GATE:
awaiting live user sign-off (+ placement iteration). Deferred still: move learning (LearnMoveFromLevelUp
stub), the in-battle modified-stat recompute stubs (irrelevant post-victory), faint-sprite clear (the enemy
pic lingers under the box). LATENT COLLISION reminder stands in battle_exp_stubs.asm for the remaining stubs.

### Battle text char-by-char reveal + centered level-up box (Wave 2, Stage 3, 2026-06-29)
Two user-flagged fixes to the level-up display:
1. PLACEMENT (user: battle UI is drawn to the centered GB viewport, not the widescreen margins). The
   level-up stats box now uses pret PrintStatsBox.LevelUpStatsBox's exact GB coords mapped by the
   battle-UI (+10,+3) projection offset: box GB(9,2)→canvas(19,5) 9x8; labels GB(11,3/5/7/9), values
   GB(15,4/6/8/10) — label-row then value-row, as the GB renders it. (Was a wrong (26,2) margin guess.)
2. TIMING (user: battle text was instant — an oversight; the overworld already reveals char-by-char,
   and pret uses the SAME function for both). wide_text now SHARES the overworld's PrintLetterDelay:
   added a `wide_reveal` flag; when set, WidePlaceString (and battle_menu print_dec) call PrintLetterDelay
   per glyph (per-letter frame delay from wOptions speed, A/B-held skips) — faithful to pret (PlaceString
   = instant menus/HUD/stats-box; the PrintText char loop = delayed dialog). InitBattle enables the delay
   flags (W_LETTER_PRINTING_DELAY |= BIT_TEXT_DELAY|BIT_FAST_TEXT_DELAY; wOptions speed = MEDIUM/3). The
   dialog routines set wide_reveal=1 (attack text, faint, gained-EXP, grew-level, run/no-run); the instant
   routines clear it (DrawBattleMenu, PrintStatsBox); HUD names use the stride-agnostic PlaceString (no
   WidePlaceString) so they're unaffected. DEFERRED: the battle INTRO ("Wild <nick> appeared!",
   DrawBattleIntroBox) still hand-draws via rep movsb (a separate path) → still instant; convert to reveal
   later for full consistency. Builds + links clean. GATE: awaiting live sign-off (incl. reveal speed feel).

### CORRECTION — battle text reveal gated by BIT_TEXT_DELAY, not a separate flag (2026-06-29)
The earlier `wide_reveal` flag was wrong: it only gated wide_text's WidePlaceString, but the battle HUD
draws mon names with text.asm's PlaceString — and the port's PlaceNextChar calls PrintLetterDelay just like
pret. Enabling BIT_TEXT_DELAY globally in InitBattle therefore made the HUD names type out too. Faithful
fix (matches pret exactly): BIT_TEXT_DELAY (wLetterPrintingDelayFlags) is THE single gate, shared by
PlaceString and WidePlaceString (both call PrintLetterDelay unconditionally, like PlaceNextChar). It is OFF
by default (InitBattle only sets BIT_FAST_TEXT_DELAY + wOptions speed) and turned ON only while a dialog
MESSAGE prints (faithful to TextCommandProcessor): the message routines `or` it on; the instant text
routines (DrawBattleHUDs, DrawBattleMenu, DrawMoveList, PrintMoveInfoBox, PrintStatsBox) `and` it off.
Dropped the `wide_reveal` global entirely. Result: only dialog messages (attack/faint/gained/grew/run) type
out; menu, move names, TYPE/PP, level-up stats box, and the HUD mon names + HP are instant — as in Gen 1.

### Level-up move learning — LearnMoveFromLevelUp (Wave 2, Stage 3, 2026-06-29)
Faithful port of pret evos_moves.asm:LearnMoveFromLevelUp into battle_menu.asm (replaces the
battle_exp_stubs no-op; GainExperience's level-up tail now calls the real one). Sets wCurPartySpecies =
wPokedexNum (internal index — EvosMovesPointerTable is internal-index-ordered, same as the working
WriteMonMoves path), GetMonLearnset → flat [level,moveID] pairs, finds a move taught at wCurEnemyLevel
(the new level); if not already known and a free (id 0) move slot exists, writes the move + its base PP
(Moves table) and shows "<nick> learned / <move>!" (dialog message → char-by-char). Full-moveset
"forget a move?" menu is DEFERRED (move not learned when all 4 slots full) — TODO. Reads/writes the PARTY
mon (wPartyMon1 + wWhichPokemon*PARTYMON_STRUCT_LENGTH), pret-faithful. Harness demo: PIKACHU slot 3 L5→L6
learns TAIL WHIP (Yellow Pikachu learnset L6) into its free slot (base Thundershock/Growl + debug SURF).
Builds + links clean. GATE: awaiting live sign-off.

### PP system (player-only) — decrement / 0-PP block / Struggle (Wave 2, Stage 3, 2026-06-29)
Faithful to pret (user: PP applies to the PLAYER only — Gen 1 never decrements the enemy AI's PP).
Three parts in battle_menu.asm:
1. DecrementPlayerPP (pret DecrementPP) — `DoPlayerAttackDamage` decrements the used move's PP in
   wBattleMonPP[wPlayerMoveListIndex] (skips Struggle). Party-struct PP sync deferred with
   LoadBattleMonFromParty (harness battle mon is seeded directly; wBattleMonPP backs the menu/TYPE-PP box).
   Multi-turn-status skips (Rage/Thrash/etc) not modelled (those moves aren't wired).
2. 0-PP move block (pret SelectMenuItem) — A on a move whose PP&PP_MASK==0 → ShowNoPP ("No PP left for /
   this move!") → RestoreBattleScreen → re-show the move menu (cursor preserved), can't be chosen.
3. Forced Struggle (pret AnyMoveToSelect) — before the move menu, CheckAllMovesNoPP; if every move's
   PP==0, set wPlayerSelectedMove=STRUGGLE (0xA5), ShowNoMovesLeft ("<nick> has no / moves left!"), and
   run the turn with Struggle (skips the menu). Struggle's recoil effect is deferred (move-effects).
PP text strings added (pret _MoveNoPPText / _NoMovesLeftText). TEMP PP-test harness seed (REVERT noted):
PIKACHU move PP = 2/1/1/1 and enemy HP bumped 35→200 so all 4 moves can be depleted to reach Struggle.
Builds + links clean. GATE: awaiting live sign-off.

---

## 2026-06-30 — Text engine completed game-wide (pret-aligned dynamic commands)

Plan: docs/current_plan_battle_pret_alignment.md Stage 0. The port's
TextCommandProcessor/PlaceString (src/text/text.asm, used by overworld NPC dialog)
already had the layout commands + `<PLAYER>`/`<RIVAL>` name tokens, but the
operand-bearing dynamic commands were skip-stubs. Implemented faithfully:

- **TX_RAM ($01)** — was `.cmd_skip2`. Now reads the 2-byte WRAM pointer and
  PlaceString's it at the cursor (pret home/text.asm:TextCommand_RAM). Enables
  nicknames / arbitrary RAM strings in any text stream.
- **TX_NUM ($09 / text_decimal)** — was `.cmd_skip3`. Reads addr + format byte
  (`(bytes<<4)|digits`), forces LEFT_ALIGN, calls PrintNumber (pret
  TextCommand_NUM).
- **TX_BCD ($02 / text_bcd)** — was `.cmd_skip3`. Reads addr + flags|length,
  calls PrintBCDNumber (pret TextCommand_BCD). For money.
- **`<TARGET>`/`<USER>` ($59/$5A)** — added to PlaceNextChar dispatch. Per
  hWhoseTurn (TARGET = ^1): player side → wBattleMonNick; enemy side → "Enemy " +
  wEnemyMonNick (pret PlaceMoveTargetsName / PlaceMoveUsersName). Manual glyph
  copy matching the existing `<PLAYER>`/`<RIVAL>` handlers.

New files mirroring pret's tree (file-for-file):
- **src/home/print_num.asm** — `PrintNumber` (mirrors home/print_num.asm). Pret's
  3-byte power-of-ten subtraction is computed with native 32-bit DIV (value ≤ 24
  bits); observable behaviour identical — same digits + leading-zero /
  LEFT_ALIGN / space-pad + pointer-advance rules (.PrintLeadingZero / .NextDigit).
- **src/home/print_bcd.asm** — `PrintBCDNumber` + `PrintBCDDigit` (faithful
  transliteration; calls PrintLetterDelay; note bit 7 = *suppress* leading zeroes,
  inverted vs PrintNumber, per pret).

Text flag bits (BIT_MONEY_SIGN/LEFT_ALIGN/LEADING_ZEROES) added to
gb_constants.inc (BIT_LEFT_ALIGN also defined locally in text.asm, which doesn't
include gb_constants). Both new files added to the Makefile GAME_SRCS beside
text.asm (always linked). Assembles + links clean.

Not yet exercised live: nothing emits TX_RAM/TX_NUM yet (overworld dialog uses
line/para/done only) — proof comes when the Stage-2 battle-text generator routes a
message (nick + EXP number) through it. The ad-hoc print_dec/print_num3 copies in
battle_menu/battle_hud/party_menu remain; retire them onto PrintNumber alongside
Stage 2.

---

## 2026-06-30 — Text engine UNIFIED (deleted the stride-40 wide_text.asm fork)

Plan: docs/current_plan_battle_pret_alignment.md Stage 0.5 (user-approved). The
port had forked pret's single stride-20 text engine into a parallel stride-40
clone (src/text/wide_text.asm: WidePlaceString/WideTextBoxBorder/
WideHandleMenuInput/WidePlaceMenuCursor) so battle could draw into the 40-wide
full-screen W_TILEMAP. pret has no such split (hardware is 20-wide everywhere) —
it was pure divergence (double maintenance, and would have forced cloning the
whole TextCommandProcessor too). Unified onto the ONE engine:

- text.asm parameterized on a runtime `text_row_stride` (.data, default 20).
  TextBoxBorder's row-advance and PlaceNextChar's `<NEXT>` now read it instead of
  the SCREEN_W_TILES literal. Overworld unchanged (stays 20).
- PlaceString now takes its source pointer in EAX (port calling convention; logic
  byte-identical to pret, which uses DE). Updated every caller: TextCommandProcessor
  (.cmd_start/.cmd_ram), battle_hud (2), party_menu, start_menu.
- Menu input relocated to new pret-mirrored src/home/window.asm as HandleMenuInput
  / PlaceMenuCursor (+ menu_item_step / menu_redraw_cb), stride-aware via
  text_row_stride. (These are home/window.asm routines in pret.)
- battle_menu.asm migrated off Wide*: WidePlaceString→PlaceString + `mov esi,ebx`
  (PlaceString returns the end cursor in EBX = pret's BC; identical position to
  Wide's returned ESI, so chaining is preserved), WideTextBoxBorder→TextBoxBorder,
  WideHandleMenuInput→HandleMenuInput, wide_line_step→menu_item_step,
  wide_menu_redraw_cb→menu_redraw_cb.
- InitBattle sets text_row_stride=40; EndBattleScreen resets it to 20 (so a future
  overworld return can't inherit the battle stride; full clean exit is Stage 3).
- src/text/wide_text.asm DELETED; removed from Makefile; src/home/window.asm added.
  type_names.asm (data table WideTypeNames) and init_battle.asm had no Wide *calls*
  (only a data label / comment) — left as-is.

Builds + links clean (DEBUG_BATTLE_LIVE). This is a behavior-preserving refactor;
needs a live regression check that the battle UI (HUD names, FIGHT/PKMN/ITEM/RUN
menu + cursor, move list + TYPE/PP box, attack/EXP/level messages) renders
exactly as before. The Stage-0 dynamic commands (TX_RAM/TX_NUM/<USER>) now reach
battle text via this one engine, but aren't *emitted* yet — that's Stage 2.

## 2026-06-30 (fix) — unification regression: PlaceString source addressing

After unifying the text engine, battles page-faulted and the FIGHT/PKMN/ITEM/RUN
labels were blank (overworld was fine). Root cause: the deleted WidePlaceString
read its source string FLAT (`[eax]`), while the unified PlaceString read it
EBP-relative (`[ebp+edx]`). battle_menu passes FLAT-LINEAR source pointers
(`mov eax, str_x` for .data labels, `lea eax,[ebp+nick]` for GB strings), so
PlaceString did `[ebp + flat_ptr]` → garbage; with no `$50` in the garbage,
PlaceNextChar walked off the mapped pages → page fault. (HUD names worked because
battle_hud passed a GB *offset*.)

Fix: PlaceString now reads its source FLAT-LINEAR (`[edx]`, no EBP) — matching
place_flat_str and the DJGPP flat model — so battle_menu's 49 sites need no change.
Updated the callers that passed GB offsets to pass flat-linear instead:
TextCommandProcessor .cmd_start (`lea eax,[ebp+esi]` in; `sub esi,ebp` after to get
the GB offset back for TCP) and .cmd_ram (`lea eax,[ebp+edx]`); the `<DONE>` handler
returns `lea edx,[ebp+DONE_SENTINEL_WRAM]` (flat) so the sentinel round-trips;
battle_hud (2), party_menu, start_menu now `lea eax,[ebp+...]`. The internal
`<PLAYER>`/`<RIVAL>`/`<USER>` handlers still read GB WRAM via `[ebp+edx]` (unchanged).
Static FRAME.BIN confirms FIGHT/PKMN/ITEM/RUN render. Re-touches the overworld
TCP/`<DONE>` path → needs an overworld NPC-dialog re-check.

## 2026-06-30 — Faithful battle core.asm orchestration written (Stage 3, assembles)

dos_port/src/engine/battle/core.asm — a structure-for-structure translation of pret
engine/battle/core.asm replacing the bespoke battle_menu.asm orchestration. Assembles
clean (standalone; not yet linked). Routines: MainInBattleLoop, DisplayBattleMenu (two-
column input + FIGHT/PKMN/ITEM/RUN dispatch), MoveSelectionMenu + AnyMoveToSelect
(faithful FormatMovesString → '-' empty slots, 0-PP/disabled/Struggle), ExecutePlayer/
EnemyMove (faithful core damage path), DisplayUsedMoveText (<USER> used <MOVE>!),
ApplyAttackTo{Enemy,Player}Pokemon, PrintBattleText + RunBattleTextStream, HandleEnemy/
PlayerMonFainted (+ GainExperience), BattleMenu_RunWasSelected, ReadPlayerMonCurHPAndStatus,
CheckNumAttacksLeft, BattlePromptWait. %includes the generated battle_text.inc.

Text engine parameterized (text.asm) for the battle box: text_line2 (<LINE> target),
text_arrow_pos + text_prompt_hook (battle ▼ in W_TILEMAP), and <PROMPT> now faithfully
draws ▼ → waits → TERMINATES (pret PromptText→DoneText) — data-driven ▼ (prompt=arrow,
done/text_end=none), fixing the earlier "▼ on every battle message" issue.

New gb_memmap symbols: wMenuItemToSwap CC35, wBattleAndStartSavedMenuItem CC2D,
wAnimationID D07B, wMonIsDisobedient CCED.

TODO(faithful) deepening, clearly marked in-source (translate next; not silent
divergences): CheckPlayer/EnemyStatusConditions (sleep/freeze/para/confusion/flinch/
Bide/Thrash/Rage), CheckForDisobedience, the IsInArray effect-array gating (currently
JumpMoveEffect runs once after damage), HandleCounterMove, multi-hit, Mirror/Metronome,
PrintCriticalOHKOText/DisplayEffectiveness, SlideDownFaintedMonPic + faint SFX, trainer
multi-mon/prize/blackout, GetCurrentMove move-name-buffer tail. Move animation = HP-bar
placeholder; audio = no-op (agreed).

NEXT (Stage 5 integration): alias battle_menu draw helpers to pret names (DrawHUDsAndHPBars
/Save+LoadScreenTilesToBuffer1/DrawBattleMenuBox/DrawEmptyDialogBox), add BattleItemMenu/
BattlePartyMenu deferred stubs, GUT battle_menu.asm's bespoke orchestration (keep only
draw helpers), wire JumpMoveEffect→effects.asm (remove battle_stubs stub, link the backend
live), point the DEBUG_BATTLE harness at MainInBattleLoop, add core.asm to the Makefile,
build + FRAME/live verify.

---

## 2026-06-30 — Stage 5 integration: faithful core.asm battle loop goes LIVE

The faithful `engine/battle/core.asm` translation is now LINKED and drives the battle
(replacing the bespoke battle_menu.asm orchestration). `make SKIP_TITLE=1
DEBUG_BATTLE_LIVE=1` builds; the static `DEBUG_BATTLE=1` FRAME dump confirms the HUD
(PIDGEY :L13 — E_LV fix), both sprites, the FIGHT/PKMN/ITEM/RUN menu and ▼ render.

Changes:
- **battle_menu.asm rewritten** to DRAW HELPERS + EXP/level-up display + run-odds only.
  Bespoke orchestration removed (DisplayBattleMenu, MoveSelectionMenu, ExecutePlayerTurn,
  Render*/Do*AttackDamage, the fainted/no-PP/run message draws). Kept: Save/LoadScreen-
  TilesToBuffer1 (+ SaveBattleScreen/RestoreBattleScreen aliases), DrawHUDsAndHPBars
  (→DrawBattleHUDs), DrawEmptyDialogBox/DrawBattleMenuBox/DrawBattleMenu, WaitForAPress,
  TryRunningFromBattle, ShowGainedExp/GrewLevel/Learned text, PrintStatsBox,
  LearnMoveFromLevelUp, FindMoveName, PrintMoveInfoBox. Added BattleItemMenu/
  BattlePartyMenu deferred stubs. DoEnemyAttackDamage kept as DEBUG_BATTLE_ENEMYHIT
  scaffold only.
- **animations.asm**: PlayMoveAnimation now ALWAYS takes pret's ANIMATION=OFF path
  (DelayFrames(30) + PlayApplyingAttackAnimation), per the user directive — the prior
  version gated on the wOptions bit, whose default (animations ON) skipped the delay
  entirely. PlayApplyingAttackAnimation is faithfully gated on wAnimationType; the visible
  shake/blink (rWX/OBJ-palette) is a marked TODO-HW. HP-bar drop is the separate
  DrawHUDsAndHPBars step, not the animation.
- **core.asm**: CriticalHit → CriticalHitTest (real core_damage.asm global).
- **core_stubs.asm (new, LINKED)**: faithful FormatMovesString (copy of misc.asm output —
  names via the flat FindMoveName walk since GetName/names.asm is not link-ready;
  TrainerNames undefined — and the '-' empty-slot tile is correctly 0xE3, vs misc.asm's
  latent ASCII-0x2D bug), plus no-op/faithful stubs for JumpMoveEffect,
  HandlePoisonBurnLeechSeed (ZF=0), TrainerAI (CF=0) — the deep effect/residual/AI
  closures aren't link-ready.
- **battle_stubs.asm**: JumpMoveEffect stub removed (now in core_stubs); CheckTarget-
  Substitute stub kept.
- **battle_exp_stubs.asm**: Save/LoadScreenTilesToBuffer1 stubs removed (battle_menu now
  provides the real ones — the EXP display gets real screen save/restore).
- **debug_dump.asm**: the DEBUG_BATTLE_LIVE `.live` loop now calls MainInBattleLoop
  (returns on win/lose/ran), replacing the bespoke DisplayBattleMenu/wBattleOver loop.
- **Makefile**: core.asm + core_stubs.asm + decrement_pp.asm + animations.asm linked
  (FRONTEND_SRCS); BATTLE_SRCS stays check-only.

Deferred (clearly marked TODO(faithful) in core.asm / core_stubs.asm): move effects
(JumpMoveEffect), residual poison/burn/leech, trainer AI + multi-mon/prize, status
conditions (sleep/freeze/para/confusion), CheckForDisobedience, multi-hit/charging/Counter,
the visible screen-shake. These are later waves — the loop STRUCTURE is faithful and live.

### 2026-06-30 — follow-up fixes (live-test bugs)
- **Blank FIGHT move names**: core_stubs.asm FormatMovesString kept the wMovesString write
  cursor in EDX across `call FindMoveName`, which clobbers DL → cursor corrupted, names
  written off-target. Fixed: push/pop EDX around the call.
- **"X used MOVE!" overflowed the box**: DisplayUsedMoveText composed the message on ONE
  line; pret's _ActorNameText + _UsedMove1Text put the actor name on line 1 and `line
  "used "` (a break) before the move name. Fixed: str_used_grammar now leads with <LINE>
  ($4F).
- **Level-up showed "grew to level 1"** (pre-existing engine bug, never live-tested — NOT a
  harness artifact): GainExperience adds EXP to the party struct, then (faithfully) calls
  LoadMonData so CalcLevelFromExperience can read the loaded-mon scratch
  (W_LOADED_MON_SPECIES/EXP). But LoadMonData was a no-op stub (battle_exp_stubs.asm), so
  wLoadedMon stayed stale → level computed off garbage (≈1). This would break a real battle
  too. FAITHFUL FIX: wired the home wrapper `LoadMonData` (new, load_mon_data.asm) →
  `LoadMonData_` (already linked; copies the full party mon into wLoadedMon + sets wMonHeader),
  and removed the stub — exactly pret's flow (load mon, then calc level). An earlier targeted
  hand-copy of just species+exp into wLoadedMon was reverted in favour of this. (The stat
  recompute reads the party struct directly, so it was unaffected.) Separately, the harness
  seeds the on-screen battle mon (L18) independently of the gaining party slot 3 (PIKACHU L5),
  so the display reads the L5→L6 party mon, not the L18 on-screen mon — a HARNESS seam (real
  battles LoadBattleMonFromParty), distinct from the engine bug above.

### 2026-06-30 — battle data generators (4) + move-effect text de-duplication
Added 4 Tier-1 generators (one per Sonnet subagent, reviewed against pret):
- gen_battle_text.py EXTENDED: now scans engine/battle/move_effects/*.asm for effect text
  wrappers and emits `global <Label>` per stream (103→123 labels). Taught it `text_pause`
  ($0A) so GettingPumpedText generates. (building_rage/residual_damage paths are port-only
  splits with no pret root file — harmless no-ops; that text lives in core.asm.)
- gen_trainer_parties.py NEW → TrainerDataPointers (47 dd, class-1 indexed) + rosters (both
  fixed-level and $FF per-mon formats) + SpecialTrainerMoves (358 B, $FF-term). Species =
  internal index (matches gen_wild_encounters/add_party_mon).
- gen_trainer_names.py NEW → TrainerNames (47, '@'-terminated, GetName-walked).
- gen_move_grammar.py NEW → MoveGrammar (4 groups, db -1/db 0 pret-literal; vestigial in
  English but carried for faithfulness).
Wired: gen_all_assets.py chains all 4; Makefile asset rules; new linked data objects
src/data/trainer_data.asm (+trainer_parties/_names.inc) and src/data/move_grammar.asm.
Build green (DEBUG_BATTLE_LIVE) + make check clean.

De-duplicated move-effect text (per the "text data is generated" rule): 10 move_effects/*.asm
hand-authored their text streams in code (e.g. focus_energy `GettingPumpedText`), colliding
with the now-generated battle_text labels and carrying dangling `extern _XxxText`. Stripped
the inline definitions + `global` + dangling externs; each now `extern`s the generated label.
KNOWN GAP: heal.asm's `StartedSleepingEffect` is a text wrapper that doesn't end in "Text",
so gen_battle_text's `*Text:` regex doesn't capture it — it's now an undefined extern (fine
check-only; needs the regex widened to `*Effect` text wrappers, or stays hand-authored, when
move_effects get linked for JumpMoveEffect).

Type-id handling verified correct end-to-end (Gen-1 gap): gb_constants NORMAL=0..GHOST=0x08,
gap 0x09-0x13, SPECIAL=FIRE=0x14..DRAGON=0x1A; WideTypeNames is a 27-entry raw-id-indexed
table (gap→tn_normal); damage split is `cmp al, SPECIAL(0x14)/jae .special`. (WideTypeNames
is still hand-authored — candidate for a future gen_type_names.)
