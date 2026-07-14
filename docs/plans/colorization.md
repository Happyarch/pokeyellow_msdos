# Current Plan — Asset Colorization Tool + Staged Runtime Palette Support

Status: **complete** — archived 2026-07-13.

- [x] Stage C0 — palette data pipeline (parsers, sidecar schema, CLI, generator, Makefile)
- [x] Stage C1 — automap generator (defaults for all 151 mons + battle)
- [x] Stage C2 — tool Mode 1: shade reassignment + preview (the 99% case)
- [x] Stage C3 — tool Mode 2: repaint PNG round-trip
- [x] Stage R1 — minimal runtime: battle shows automapped GBC colors *(after/with perf Stages 1–4)*
- [x] Stage R2 — repaint override consumption
- [x] Stage R3 — overworld / menus (later; rides the perf-rebased renderer)
- [x] Ride-along: preview/debug tooling (PAL.BIN + render_frame.py lockstep, with R1)

All paths relative to `dos_port/` unless rooted; pret sources at repo root are
read-only spec.

## Context

The port renders everything through one global 4-shade DMG-green ramp (`dmg_palette`,
`boot/video.asm`) — a debug placeholder. Phase 5 colorization was always planned
(`tools/colorize.py` is a print-and-exit stub; `RunPaletteCommand`/`UpdateCGBPal_*`/
`LoadSGB` are no-op stubs at every pret call site). This plan delivers a **colorization
tool** with two modes: (1) reassign an asset's original 4 shades (the 99% case),
(2) repaint pixels and add shades. Before manual work, it **automaps every
Pokémon to its authentic GBC colors** parsed from pret's hand-authored
`CGBBasePalettes` (40 palettes × 4 BGR555 colors), `MonsterPalettes` (152 species →
10 color families), and `PalPacket_*`/`BlkPacket_*` screen data.

**Settled with the user (2026-07-12):**
- End-to-end but staged: tool + generators first, then minimal runtime so colors show in DOS. First target: **mon pics + battle screen**; overworld/menus later.
- **Core mechanism: per-VRAM-tile-ID palette byte, baked into `tile_cache` at decode time.** Cycle cost first, bandwidth second, memory is plentiful.
- Repaint = **CGB-style multi-palette** (edited 2bpp tiles + per-tile palette grid, ~8–12 colors/asset; no 8bpp path), authored via **PNG round-trip** (export → paint in GIMP/Aseprite → import with validation).
- Runtime consumption is designed now but **lands after/coordinated with `docs/plans/compositor_perf.md` Stages 1–4** (same hot loops). Tool/generator stages can land anytime. **Unblocked 2026-07-12:** that plan is complete and archived — but read it before touching the hot loops, since `render_bg`/`render_window`/`render_sprites` now all composite from `tile_cache` and are dirty-skipped against id shadows.

## Core design

**Banded palette-indexed pixels, palette applied at cache-rebuild time — zero added frame-loop cycles:**
- `tile_cache` bytes become `(bg_slot << 2) | shade` (0–31). The only decode change is in `rebuild_tile_cache` (`src/ppu/ppu.asm:421-446`): OR in `tile_pal[tile_id] << 2` per pixel. `render_bg`'s hot row-copy loop is **byte-identical** — fully compatible with perf Stage 1b (dirty keys stay plain tile IDs; palette is a pure function of tile ID) and Stage 4a (optional variant: 8 pre-banded decode LUTs, 32 KB `.data`, keeps rebuild branch-free).
- Sprites: `render_sprites` already bands by palette (`4+color`/`8+color` off `OAM_PAL1`). Widen to `32 + (obj_slot << 2) + color` using `OAM_PAL1` + `OAM_HIGH_PALS` (already carried into shadow OAM by `PrepareOAMData`, currently dead) → 4 OBJ slots now, 8 possible with one more attr bit later. **NB (2026-07-12):** OBJ are no longer overworld-only — the party-menu / naming-screen mon icons are OBJ now (`engine/gfx/mon_icons.asm`, `docs/plans/party_icons_oam.md`), written with `OAM_XFLIP` and OBP attrs by pret's own writers, so those menus need OBJ palettes too, not just BG ones. They also composite *over* the window layer (`g_obj_over_window`), which `render_sprites`' banding must not assume away.
- **BG-priority fix rides along:** the sprite behind-BG test `cmp byte [ebp+ecx], 0` becomes `test byte [ebp+ecx], 3 / jnz` ("BG color 0 of any slot").
- Palette change = update table + `g_pal_dirty` (DAC) and/or `g_tilecache_dirty` (banding). Change-gated `commit_palette` grows 12 → 64 DAC entries.

**DAC layout (64 of 256):**

| DAC | Owner | Notes |
|---|---|---|
| 0–31 | BG slots 0–7 × 4 colors | pixel value == cache byte |
| 32–63 | OBJ slots 0–7 × 4 colors | color 0 never written (transparent) |

`commit_palette` reproduces pret's CGB semantic: `DAC[slot*4+c] = pal_rgb_table[slot_pal_id].color[(BGP_or_OBP >> 2c) & 3]` — the DMG-register remap means **`FadePal` fades/whiteouts keep working** as pure register pokes → one gated DAC reprogram, no re-decode (this is exactly pret's `DMGPalToCGBPal`).

**Visual-parity defaults:** at boot, `tile_pal[]` = all slot 0, slot 0 / OBJ slots 0–1 = a `PAL_DMG_GREEN` entry appended to the RGB table → every non-colorized screen renders pixel-identical colors to today (backbuffer *values* shift for sprites, 4–11 → 33–43; see FRAME.BIN note in Verification).

**HP-bar simultaneity (player green vs enemy red, same tile IDs):** duplicate the ~7 HP-bar fill tiles into a second VRAM tile-ID band at battle HUD load (112 B VRAM); player bar tiles → BG slot 0, enemy's duplicates → slot 1, each slot's `PAL_*` set from `GetHealthBarColor`. Chosen over DAC content-swaps because per-tile-ID palettes cannot disambiguate a shared tile ID at two positions; duplication keeps the mechanism uniform.

**Automap data flow:** pret sources → parsers (`gfx_core`) → **defaults**, ⊕ **sidecar deltas** (committed JSON, editor-owned) → `gen_palettes.py` → gitignored `assets/colors/palettes.inc` (`.data` section — link.ld orphan rule). Two-tier rule: generated tables are Tier 1; dispatch/handlers are Tier-2 hand-written asm under pret labels.

## Sidecar schema — `assets/colors/palettes.json` (deltas only; VGA 6-bit RGB 0–63)

```jsonc
{ "version": 1,
  "pal_overrides":    { "PAL_REDMON": [[63,20,16],[52,12,8],[30,4,4],[6,6,6]] },
  "species_overrides":{ "CHARIZARD": {"pal": "PAL_YELLOWMON"},
                        "MEW":       {"colors": [[..],[..],[..],[..]]} },
  "screen_overrides": { "SET_PAL_BATTLE": {"slot2": "PAL_MEWMON"} },
  "repaint": { "CHARIZARD_front": {
      "png": "colors/repaint/charizard_front.png",
      "tile_pal": [/* 49 slot ids, 7×7 pic grid */],
      "extra_palettes": [[[..]]],            // ≤4 per asset
      "override_2bpp": "colors/repaint/charizard_front.2bpp" } } }
```
Validation in both editor and generator (`ui_layout/schema.py` pattern): colors length-4, names resolve against pret enums, repaint ≤4 colors per 8×8 tile / ≤4 palettes per asset, slot ids 0–7.

**Generated tables** (via `gen_all_assets.py:write_inc()`): `pal_rgb_table` (40×4×3 B + port-only entries like PAL_DMG_GREEN), `mon_pal_table` (152 B, Pokédex order), `battle_slot_pal` (default PAL per slot for SET_PAL_BATTLE), `battle_tile_pal` (384 B tile-ID→slot, from `BlkPacket_Battle` regions + the port's fixed battle VRAM layout + HP-bar duplicate band), repaint blobs (R2).

## Stage C0 — Palette data pipeline (tool-side; can land now)

- [x] `tools/gfx_core/palettes.py`: `parse_cgb_base_palettes()` (`data/sgb/sgb_palettes.asm`, RGB 5-bit → VGA 6-bit `round(v*63/31)`), `parse_monster_palettes()`, `parse_pal_packets()`/`parse_blk_packets()`, PAL_*/SET_PAL_* enums from `constants/palette_constants.asm`. (4th `gfx_core` consumer; parser-as-module per `pret_maps.py` precedent.)
- [x] `tools/colors/schema.py` — sidecar dataclass + `validate()`.
- [x] `tools/colorize.py` — replace stub body with real CLI (`--gen`, `--edit`, `--export-png`, `--import-png`, `--verify`); keep filename (ROADMAP references it).
- [x] `tools/gen_palettes.py` → `assets/colors/palettes.inc`; Makefile rule (deps: sidecar + generator + gfx_core + pret sources), add to `assets` target, consuming `.o` prerequisites.

## Stage C1 — Automap generator (defaults for all 151 mons + battle)

- [x] Emit all four tables above from pret data (BlkPacket_Battle: msg box→slot2, enemy HP→1, player HP→0, player mon→2, enemy mon→3).
- [x] Idempotence check: two runs, byte-identical output.

## Stage C2 — Tool Mode 1: shade reassignment + preview (the 99% case)

- [x] `tools/colors/editor.py` (pygame, house style): pick species/`PAL_*`/screen slot → edit 4 RGB with live preview; mon pic decoded via `gfx_core` (`UncompressSpriteData` equivalent not needed — decode the `.pic` in Python or reuse pret's PNG sources) rendered under candidate palette.
- [x] **Battle-scene mock view** (mon + HP bars + message box composited with slot colors) so simultaneity reads correctly; tile-ID→slot authoring overlay writes `screen_overrides`.
- [x] Editor writes sidecar deltas only; `--verify` round-trips sidecar→inc→parse. Extract shared palette-aware blit into `gfx_core/surface.py` (battle_ui extraction precedent).

## Stage C3 — Tool Mode 2: repaint PNG round-trip

- [x] `--export-png`: asset at current palettes → indexed PNG.
- [x] `--import-png`: validate ≤4 colors/tile + ≤4 palettes/asset, auto-derive per-tile palette grid, emit override 2bpp + grid + extra palettes into sidecar.
- [x] Round-trip idempotence test (export→import→export byte-stable).

## Stage R1 — Minimal runtime: battle shows automapped GBC colors *(after/with perf Stages 1–4)*

- [x] `boot/video.asm commit_palette`: 64 entries, per-slot PAL deref + DMG-register remap, gate on BGP/OBP change OR `g_pal_dirty`; boot defaults = visual parity (above).
- [x] `src/ppu/ppu.asm`: `rebuild_tile_cache` OR-in `tile_pal[id]<<2` (or pre-banded LUT variant if perf 4a landed); `render_sprites` obj-slot widening + the `test …,3` BG-priority fix; `render_bg` untouched.
- [x] New `src/home/palettes.asm` + `src/engine/gfx/palettes.asm` (pret-label mirrors): `RunPaletteCommand`/`_RunPaletteCommand` + `SetPalFunctions` jump table, `DeterminePaletteID` (species→`IndexToPokedex`→`mon_pal_table`), `SetPal_Battle`/`SetPal_BattleBlack` (load `battle_slot_pal`, patch mon slots via `DeterminePaletteID`, HP slots via `GetHealthBarColor`, copy `battle_tile_pal`→live `tile_pal`, arm both dirty flags). **Adapt, don't duplicate:** `GetHealthBarColor` already lives at `src/home/fade.asm:202`; the no-op `RunPaletteCommand` at `src/engine/battle/faint_switch.asm:59` is retired (`label_status --callers`, repoint externs, `update_label_db`, `lint_pret_labels`).
- [x] HP-bar tile duplication at battle HUD load (`src/engine/battle/battle_hud.asm`).
- [x] `SlideBattlePicsIn` (`src/home/pics.asm`): replace the `dmg_palette` shade-3 poke with faithful SET_PAL_BATTLE_BLACK slot swap.
- [x] Real `UpdateCGBPal_BGP/OBP0/OBP1` bodies (= arm `g_pal_dirty`; fades already flow through commit's remap) — fills the four `TODO-HW` sites in `src/home/fade.asm`, retires the `UpdateCGBPal_OBP1` ret-stub in `overworld_stubs.asm`.
- [x] faithdiff justification: SGB packet bit-banging realized as data + HAL dispatch (not ported verbatim).

## Stage R2 — Repaint override consumption

- [x] At pic-load (`src/home/pics.asm`, post-interlace): if species has a repaint record, blit override 2bpp over the VRAM pic tiles, write its per-pic-tile grid into `tile_pal[picbase..]`, load extra palettes into free BG slots, arm both dirty flags. Default `UncompressSpriteData` path untouched (glitch fidelity).

## Stage R3 — Overworld / menus (later; rides the perf-rebased renderer)

- [x] `SetPal_Overworld` (map-id+1 → PAL_ROUTE.., cave/tower special cases), remaining `SetPal_*` screens, per-tileset tile-ID tables, NPC OBJ palettes.

## Preview/debug tooling (rides R1)

- [x] Debug dump also writes `PAL.BIN` (live 64-entry DAC + `tile_pal` + slot tables).
- [x] `tools/render_frame.py` + `gfx_core/tiles.py`/`surface.py`: consume `PAL.BIN` when present for banded values 0–63; fallback debug palette updated for the new sprite band (4–11 → 32–63). Keep the two in lockstep (documented invariant).

## Verification

- **C stages:** generator idempotence; sidecar validate; PNG round-trip stability; `make assets` clean. Note: `.inc` content changes need `touch`/`make clean` of consumers (NASMFLAGS stamp only tracks `-D` flags).
- **R1:** build `make SKIP_TITLE=1 DEBUG_SEED_PARTY=1` (run_with_mcp.sh does not build); wild battle in DOSBox-X; `FRAME.BIN`+`PAL.BIN` via `render_frame.py` — correct mon colors, green-vs-red HP bars simultaneously, message-box tint. Non-battle screens pixel-identical colors (parity defaults).
- **Fidelity:** `make fidelity`/`goldencheck` unaffected (goldens compare tilemap/VRAM/OAM GB-space bytes, not backbuffer); `faithdiff` + `lint_pret_labels` exit 0 for every touched pret-labeled routine.
- **Perf-plan coordination:** banding changes backbuffer *values* — perf FRAME.BIN pixel-identity baselines must be captured on the same side of R1 landing; palette-change → `g_tilecache_dirty` is compatible with Stage 1b dirty keys.

## Risks / open questions

- Other same-tile-two-palettes cases beyond HP bars → audit battle VRAM during R1; apply the duplication trick if found.
- `battle_tile_pal` assumes stable battle VRAM tile bases across wild/trainer/link — verify; fallback is building `tile_pal` from the live tilemap at `SetPal_Battle` time.
- OBJ slots limited to 4 until a 3rd OAM attr bit is added (battle likely needs ≤4).
- R1 sequencing: prefer landing after perf Stages 1–4; if co-developed, adopt the pre-banded-LUT variant with Stage 4a.

## Key files

New: `tools/gfx_core/palettes.py`, `tools/colors/{schema,editor,render}.py`, `tools/gen_palettes.py`, `assets/colors/palettes.json`, `src/home/palettes.asm`, `src/engine/gfx/palettes.asm`.
Modified: `tools/colorize.py`, `Makefile`, `boot/video.asm`, `src/ppu/ppu.asm`, `src/home/{pics,fade}.asm`, `src/engine/battle/{battle_hud,faint_switch}.asm`, `src/engine/overworld/overworld_stubs.asm`, `tools/render_frame.py`, `tools/gfx_core/{tiles,surface}.py`.
