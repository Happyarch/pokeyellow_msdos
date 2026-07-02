# Current Plan: Overworld Map Tool (viewer, border authoring, block painting)

A pygame map editor at `dos_port/tools/map_editor/` built on the shared
`tools/gfx_core/` package. **Blocked on `current_plan_battle_ui.md` Session A2**
(gfx_core map decode primitives). Primary goal: author real block content for
the out-of-map border regions so the two temporary clamps in
`src/engine/overworld/overworld.asm` (DrawTileBlock block-ID clamp,
LoadCurrentMapView address clamp — see CLAUDE.md) can be deleted. Secondary:
general block painting on real map areas via port-side overrides. pret sources
(`maps/*.blk`, `data/maps/*`) stay read-only; all edits live in committed
sidecar JSON merged at asset-generation time (two-tier rule).

One session = one commit on `menus-port` (or successor branch). Every session
ends: `make -C dos_port` + `make -C dos_port check` green → verification →
checkboxes updated → commit.

## Decisions (fixed, from the user 2026-07-02)

- Scope = border/edge extension tool PLUS some full map editing (view any map,
  paint blocks; warp/NPC editing deferred, inspect-only first).
- Separate tool (`tools/map_editor/`), shared rendering core (`gfx_core`).
- Sequenced after the battle-UI plan.

## Verified constraints

- **MAP_BORDER is already 6** (`gb_memmap.inc:943`, `gen_map_headers.py`
  BORDER=6). Worst-case maps ROUTE_17/ROUTE_23 (10×72 blocks) occupy
  (10+12)×(72+12) = 1848 of the 2048-byte `wOverworldMap`, and
  `W_TILEMAP_BACKUP2` sits immediately after at $F000 — **the buffer cannot
  grow in place**. Border-extension is therefore an *authoring* problem (fill
  the existing 6-block ring with designed blocks), NOT a border-growth
  problem. Border growth = contingency only (WRAM shuffle, own session).
- Map render pipeline: block ID → 4×4 tile IDs (`.bst`, 16 B/block) → 8×8
  2bpp tiles → 32×32 px/block. Runtime composes: border-block fill →
  connection strips (from `CONNECTIONS`/`get_connection()`) → real .blk rows.
- No Python 2bpp-tileset/blockset decoder existed before gfx_core A2.

## Sessions

- [ ] **Session C1 — read-only map viewer.**
  `map_editor/editor.py <MAP_CONST>` + `view.py`: render any map via
  `gfx_core.tilesets`/`pret_maps` — real .blk center, 6-block border ring
  filled with the border block, **connection strips rendered from neighbor
  maps' real .blk** (reuse `get_connection()` offsets so the tool shows
  exactly what the runtime composes). Pan/zoom (maps exceed one screen — do
  NOT reuse ui_layout's fixed 40×25 canvas model). Toggles: block grid, tile
  grid, warp markers (y,x,dest), sign markers, NPC positions. Viewport ghost:
  the 40×25 tile window / 12×9-block wSurroundingTiles reach around a chosen
  player position.
  Gates: side-by-side vs DOSBox FRAME.BIN for Pallet Town at spawn; all 25
  tilesets load; scripted sweep renders every map without exceptions.

- [ ] **Session C2 — border-region authoring (headline feature).**
  Data model: `dos_port/assets/map_borders/<MAP_CONST>.json` — sparse painted
  cells in padded-grid coords (col 0..w+11, row 0..h+11),
  `{"cells": [[row, col, block], ...]}`, editor-owned like the ui_layout
  sidecars. Cells inside the real map area or connection strips are rejected
  by editor AND generator validator (connections win; strips render
  locked/dimmed). Editor paint mode: block palette panel (from the map's
  blockset via gfx_core), eyedropper, paint, flood-fill, undo; save only via
  the editor.
  Gates: JSON round-trip stable order; validator rejects out-of-ring cells;
  painted preview matches `render_map` composition.

- [ ] **Session C3 — generator + runtime for border overrides.**
  Generator (extend `tools/gen_map_headers.py` or new `gen_map_borders.py`) →
  `assets/map_border_overrides.inc`: per-map RLE rows `db row, col, len` +
  block bytes, plus `MapBorderOverridePointers` table parallel to
  `MapHeaderPointers` (null pointer when no sidecar). Runtime:
  `ApplyMapBorderOverrides` pass in overworld.asm's map-load path — AFTER the
  border-block fill, BEFORE connection strip copies (ordering makes
  override/connection conflicts impossible). Makefile: .inc rule on
  `assets/map_borders/*.json` + generator; overworld.o dep.
  Gates: sentinel ring on Pallet Town visible in FRAME.BIN at map edge;
  unpainted maps byte-identical FRAME.BINs; regen idempotent; `make check`.

- [ ] **Session C4 — clamp retirement.**
  (a) Analytic bound: player at tilemap center, 12×9-block wSurroundingTiles —
  worst-case buffer excursion per direction vs `get_connection()` view_start
  formulas (west margin is exactly zero — check off-by-one). (b) Empirical:
  instrument both clamps with hit counters via the dosbox MCP (breakpoints /
  gb_read), run DEBUG_WALK edge-walks along all four edges of several maps +
  across every CONNECTIONS entry; record which clamp fires where. (c) Author
  border content for all reachable outdoor maps' exposed ring cells (human
  editor step — may spread over follow-ups; clamps stay until covered).
  (d) Delete both clamps once counters read zero across the suite.
  Gates: FRAME.BIN edge-walk suite green with clamps deleted; MCP watch shows
  no reads outside [$E800,$F000).

- [ ] **Session C5 — real-map block painting.**
  `dos_port/assets/map_overrides/<Pascal>.json` (sparse `[[y,x,block],...]`
  in map-block coords); `tools/gen_all_assets.py` merges overrides when
  emitting `assets/<map>_blk.inc` (pret .blk untouched; regen idempotent —
  override is an explicit committed file). Editor paint extends to the real
  map area, overridden cells badged. Makefile: `_blk.inc` targets gain
  `assets/map_overrides/*.json` dep.
  Gates: no-override regen byte-identical for all `_blk.inc`; sentinel edit
  visible in DOSBox; `make check`.

- [ ] **Session C6 (optional, ask user first) — warp & NPC editing.**
  Inspect-only ships in C1. Editing needs `data/maps/objects/*.asm` override
  sidecars merged by gen_map_headers.py — deferred until requested.

## Risks / notes

- Border-ring authoring volume is real design labor (C4c human step); C3 can
  ship with clamps intact as the safety net until coverage completes.
- If C4a shows border 6 geometrically insufficient anywhere, fallback is a
  WRAM shuffle (move/grow wOverworldMap) — separate risk-bearing session,
  not assumed by this plan.
