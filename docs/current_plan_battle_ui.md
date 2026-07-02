# Current Plan: Battle UI Layout Pipeline + Widescreen Redesign

Extend the subsystem-generic layout tool (`dos_port/tools/ui_layout/`, built in
menus Session 1) to the battle UI: factor a shared graphics core, migrate every
hardcoded battle coordinate into a `ui_layout_battle_sidecar.json` →
`gen_ui_layout.py battle` → `assets/ui_layout_battle.inc` pipeline (initially
reproducing the current layout byte-for-byte), then let the user redesign the
battle screen for the 40×25 widescreen canvas in the editor. Sibling plan:
`docs/current_plan_map_tool.md` (blocked on Session A2 here).

One session = one commit-sized chunk on branch `menus-port`. Every session
ends: `make -C dos_port` + `make -C dos_port check` green → verification pass
→ checkboxes updated → commit. Never end a session mid-refactor.

## Decisions (fixed, from the user 2026-07-02)

- Battle scope: **widescreen redesign** — pipeline migration is the enabler,
  the redesign itself is a human-in-the-loop editor session at the end.
- Tool shape: **shared core, separate tools** — new `dos_port/tools/gfx_core/`
  package (tile decode / palette / surface compose) used by ui_layout, the
  battle launcher, and the future map editor. Battle does NOT fork the editor;
  `ui_layout/editor.py` is already sidecar-generic.
- Battle first, maps after.
- BATTLE_MENU_TEMPLATE duplication resolves **battle-sidecar-owned** (B5):
  menus sidecar drops its element; `text_box.asm` imports the battle .inc
  equates-only. (Post-redesign divergence from pret's coord-table row then
  lives in the battle sidecar, the faithfulness-cleanest place.)

## Verified facts the sessions rely on

- Battle draws on the full 40×25 canvas (`InitBattle` zeroes view-ptr, sets
  `text_row_stride=40`; `EndBattleScreen` restores 20). `TextBoxBorder`/
  `PlaceString` honor the stride; the multi-line MSG_BOX/scroll helpers in
  `src/text/text.asm` are stride-20-locked, hence battle's hand-drawn dialog.
- ~47 `* FW +` geometry literal sites across `battle_hud.asm`, `core.asm`,
  `battle_menu.asm`, `init_battle.asm`, plus inline dialog-interior literals
  (battle_menu.asm ~335–343), `src/gfx/pics.asm` slide-in (22/3, 11/8),
  `pokeballs.asm` OAM bases ($60,$60)/($48,$20) with +80/+24 centering.
- Uniform battle transform = +10 col / +3 row (custom anchor, shift (10,3));
  full element inventory documented in `docs/ui_projection.md` PROJ table.
- `DEBUG_BATTLE=1` (`src/debug/debug_dump.asm:RunBattleTest`) already dumps a
  deterministic battle FRAME.BIN — the ready-made before/after identity gate.
- HP gauge = 9 consecutive tiles one row ($71,$62,6 segments $63+n/$6B,$6C);
  mon pics = 7×7 BG tile blocks (`PlacePicTilemap`); pokéballs = OAM sprites.

## Sessions

- [x] **Session A1 — extract `tools/gfx_core/`, menus regression-locked.**
  DONE 2026-07-02. Gates: menus .inc regen byte-identical (git diff clean);
  `--atlas` md5-identical before/after; assets_bridge shim import-verified;
  headless editor drag/clamp/save round-trip OK; `decode_2bpp` cross-checked
  against PNG slicing for all 32 font_extra tiles; `make` + `make check`.
  New package: `tiles.py` (PNG 1bpp/2bpp slicing from `assets_bridge.py`,
  `TILE=8`, `DMG_PAL`, raw `decode_2bpp()` for 16-byte GB tiles), `font.py`
  (`tile_for_code`, `encode_label`, `BOX_*`), `surface.py` (tile-grid → PIL
  compose + pygame zoom-blit helpers from `render.py`/`editor.py`).
  `ui_layout/assets_bridge.py` becomes a thin re-export shim. Projection math
  stays in `ui_layout/canvas.py` (generator keeps importing only
  canvas/schema — no new Makefile deps).
  Gates: `gen_ui_layout.py menus` regen → `git diff --exit-code` on the .inc;
  `--atlas` render byte-identical before/after (capture baseline to
  scratchpad first); headless editor load/drag/save smoke on a scratch copy.

- [x] **Session A2 — map decode primitives in gfx_core.** DONE 2026-07-02.
  `gfx_core/tilesets.py` (2bpp/blockset load, expand_block mirrors
  DrawTileBlock's clamp, render_map with border-ring pad) +
  `gfx_core/pret_maps.py` (MapInfo layer reusing gen_map_headers's parsers/
  tables verbatim; CONNECTIONS/get_connection re-exported). Gates: PALLET_TOWN
  (10x9, overworld, 94 tiles) and OAKS_LAB (5x6, DOJO) render pixel-faithful
  PNGs incl. border ring; build untouched (pure tooling, `make` green from A1).
  `gfx_core/tilesets.py`: `load_tileset_2bpp(stem)` (gfx/tilesets/*.2bpp,
  16 B/tile), `load_blockset(stem)` (gfx/blocksets/*.bst, 16 B = 4×4 tile
  IDs), `expand_block()`, `render_map(blk, w, h, blockset, tileset,
  border_block, pad)` → PIL. `gfx_core/pret_maps.py`: read-only map metadata
  by importing `tools/gen_map_headers.py` as a module (import-safe, `main()`
  guarded) — reuse `parse_map_constants`/`parse_all_headers`/
  `parse_object_file`/`CONNECTIONS`/`get_connection`. Zero duplication.
  Gates: check script renders PALLET_TOWN + OaksLab PNGs to scratchpad;
  eyeball vs FRAME.BIN render. Pure tooling, `make` untouched.
  **Unblocks current_plan_map_tool.md.**

- [x] **Session B1 — battle element kinds + editor rendering.** DONE
  2026-07-02. schema kinds hp_gauge(9x1)/mon_pic(7x7)/oam_row(6x1) via
  FIXED_SIZES + hud_frame (w=10, h=2 enemy / 3 player, variant in notes;
  sprite_popup kept separate — it's a bordered box, not an OAM group). NEW
  `gfx_core/battle_tiles.py`: battle-VRAM charset (font_battle_extra 30
  tiles at $62 + battle_hud_1/2/3 overlays at $6d/$73 + balls.png), so
  battle previews use the exact in-battle glyphs incl. the battle box tiles.
  render.py kind dispatch + `tile_fn` charset threading in gfx_core.surface;
  `ui_layout/battle.py` launcher. Gates: synthetic battle sidecar renders
  headless (visually verified); constraint rejection works; menus sidecar
  validates; menus .inc + atlas byte-identical.
  `schema.py`: add kinds `hp_gauge` (fixed 9×1), `mon_pic` (fixed 7×7),
  `hud_frame`, `oam_row` (6×1, tile-aligned) with per-kind `validate()`
  constraints. First check whether existing `sprite_popup` semantics already
  cover `oam_row` — reuse if so. Reuse `textbox` for dialog/move/menu boxes,
  `text` for single-row strings, `cursor` for cursor cells.
  `render.py`/`editor.py`: kind renderers — hp_gauge draws real HPB tiles,
  mon_pic a labeled 7×7 placeholder, hud_frame the shelf/corner tiles
  ($73/$76/$77/$6F/$74/$78, variant `enemy`/`player` via `notes`), oam_row
  ball placeholders. `ui_layout/battle.py` = thin launcher (battle sidecar +
  `--bg` battle FRAME.BIN).
  Gates: synthetic battle sidecar renders headless; menus sidecar still
  validates; menus `--check` byte-identical.

- [x] **Session B2 — seed_from_battle + generator battle branch + Makefile.**
  DONE 2026-07-02. 28 elements seeded, ALL 29 legacy-geometry assertions
  pass (byte offsets, pic cols/rows, SLIDE_STEPS=18, pokéball OAM bases —
  NB: verified OAM = screen+(8,16) via PrepareStaticOAM, so PLAYER_BALLS =
  GB(11,10), ENEMY_BALLS = GB(3,2) marching left, engine base = right end).
  Generator now emits UI_*_OFS (row*cols+col) for ALL subsystems (menus .inc
  regen'd, additive), oam_row _PX_X/_PX_Y/_OAM_X/_OAM_Y, and derived
  UI_BATTLE_SLIDE_STEPS. Makefile rule + assets target entry. Gates: regen
  idempotent (cmp), nasm round-trip assembles all 373 equates, battle atlas
  renders, `make` + `make check` green. (.inc files are gitignored generated
  assets — only the sidecar JSON is committed, as with menus.)
  `ui_layout/seed_from_battle.py`: build `assets/ui_layout_battle_sidecar.json`,
  all elements `anchor=custom shift=(10,3)`, ~24 elements from the current
  %defines / ui_projection.md PROJ table: ENEMY_NAME GB(1,0), ENEMY_LV
  GB(4,1), ENEMY_HPBAR GB(2,2) 9×1, ENEMY_HUD_FRAME, PLAYER_NAME GB(10,7),
  PLAYER_LV GB(14,8), PLAYER_HPBAR GB(10,9), PLAYER_HPFRAC GB(11,10),
  PLAYER_HUD_FRAME, DIALOG_BOX GB(0,12) 20×6, DIALOG_LINE1 GB(1,14),
  DIALOG_LINE2 GB(1,16), DIALOG_ARROW GB(18,16), ACTION_MENU_BOX GB(8,12)
  10×4, ACTION_TEXT GB(10,14), ACTION_CUR_L GB(9,14), ACTION_CUR_R GB(15,14),
  MOVE_BOX GB(4,12) 14×4, MOVE_TEXT GB(6,13), MOVE_CURSOR GB(5,13), INFO_BOX
  GB(0,8), LVLUP_BOX GB(9,2) + LBL/VAL, ENEMY_PIC mon_pic GB(12,0),
  PLAYER_PIC GB(1,5), PLAYER_BALLS oam_row GB(12,12)→px($60,$60), ENEMY_BALLS
  GB(9,4)→px($48,$20). Interior dialog rows derive from DIALOG_LINE1 (+n) —
  note in sidecar, don't multiply elements. Seeder ASSERTS every legacy byte
  offset (E_NAME==3*40+11==131, MOVEBOX_OFF==15*40+14, OUTER_OFF==15*40+10,
  enemy pic 22/3, SLIDE_STEPS==18, …) and aborts on mismatch, like the menus
  seeder.
  `gen_ui_layout.py`: emit `UI_<ID>_OFS equ ROW*canvas_cols+COL` for every
  element (all subsystems — regen menus .inc once, additive, `make` green);
  battle-derived equates `UI_BATTLE_SLIDE_STEPS` (=max(cols−ENEMY_PIC_COL,
  PLAYER_PIC_COL+7)) and `UI_*_PX_X/PX_Y` for oam_row.
  Makefile: `assets/ui_layout_battle.inc` rule (same shape as the menus rule).
  Gates: `--check` idempotent; nasm round-trip harness assembles every equate;
  all seeder asserts pass; menus regen reviewed; `make check`.

- [ ] **Session B3 — .asm migration half 1 (no visual change).**
  `battle_hud.asm` (names/levels/bars/fracs + HUD frame literals),
  `init_battle.asm` (DrawBattleIntroBox, COL_OFF/ROW_OFF geometry uses),
  `src/gfx/pics.asm` (slide-in cols/rows + SLIDE_STEPS → UI_ equates),
  `pokeballs.asm` (OAM bases → UI_*_PX_*, fold the +80/+24 into the equate).
  All replacements cite `UI_*` with `; PROJ battle:` tags per CLAUDE.md.
  Gates: capture DEBUG_BATTLE FRAME.BIN baseline BEFORE; after = byte
  identical (`cmp`); `grep -n '\* FW +'` over migrated files → zero geometry
  hits (tile-code defines stay); `make` + `make check`.

- [ ] **Session B4 — .asm migration half 2.**
  `core.asm`: BTXT_LINE1/LINE2/ARROW, MENU_ROW/CUR_COL_L/CUR_COL_R (incl.
  wTopMenuItemX/Y stores), MOVEBOX_OFF/MOVES_TEXT/MOVES_CUR_COL/MOVES_ROW0.
  `battle_menu.asm`: BOX_OFF/TEXT_OFF/OUTER_OFF/INFOBOX_OFF/LVLBOX_OFF/
  LVL_LBL_OFF/LVL_VAL_OFF/ARROW_OFF + inline interior-row literals (~335–545).
  Gates: FRAME.BIN identity; interactive DOSBox-X pass of battle menu + move
  menu + one attack turn (or a scripted-input RunBattleTest extension if
  cheap); repo-wide `grep '\* FW +'` over battle sources → zero geometry hits.

- [ ] **Session B5 — consolidate BATTLE_MENU_TEMPLATE.**
  Battle sidecar owns the action-menu box; menus sidecar drops
  BATTLE_MENU_TEMPLATE + SAFARI variant; `src/engine/menus/text_box.asm`
  composes those dispatch rows from `UI_ACTION_MENU_BOX_*` via
  `%define UI_LAYOUT_EQUATES_ONLY` + `%include ui_layout_battle.inc`.
  Gates: FRAME.BIN identical for both consumers (DEBUG_BATTLE scene +
  DEBUG_TEXTBOXID battle-menu id); menus .inc regen reviewed.

- [ ] **Session B6 — the widescreen redesign (human-in-the-loop).**
  Editor hardening: live constraint enforcement (hp_gauge/mon_pic
  non-resizable; text single-row; dialog interior never below 18×4 — pret
  `<LINE>` wrapping is content, not geometry; LVLUP label/value move as a
  group); battle-preview composite over the DEBUG_BATTLE FRAME.BIN underlay.
  **Human step: user redesigns in `tools/ui_layout/battle.py`, saves.**
  Regen → `make` → DOSBox-X visual pass: slide-in (derived SLIDE_STEPS),
  HUDs, HP animation, action menu, move menu, dialog scroll/arrow, level-up
  box, pokéballs, EndBattleScreen restore. Set `frozen_at`; update
  `docs/ui_projection.md` battle rows from `canvas.proj_tag`.
  Gates: `make check`; archive before/after FRAME.BIN renders (intentional
  visual change — no identity gate).

## Risks / notes

- Text wrapping is baked into pret strings (18-char `<LINE>` breaks); the
  redesign can move/grow the dialog box but not re-wrap text. A wider-text
  redesign would need a text-pipeline change — out of scope, flag to user.
- RunBattleTest covers the static scene; move-menu/level-up identity in B4
  may need one scripted-input extension (reuse the RunListMenuTest
  auto-drive trick) — keep it small or fall back to interactive verification.
