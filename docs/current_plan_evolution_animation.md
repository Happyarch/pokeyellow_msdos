# Current Plan: Evolution Animation & Sprite Morph System

Implementation plan to restore full graphical and animation fidelity to the evolution sequence (`EvolveMon`), porting the visual morph layer (`Evolution_BackAndForthAnim`), 7×7 dual-pic VRAM offset switching, silhouette whole-screen palette switching (`SetPal_PokemonWholeScreen`), and retiring `src/engine/movie/evolution_stubs.asm`.

## STATUS — MEASURED 2026-08-23: implementation COMPLETE, awaiting one look

Every implementation and gate box below is verified against generated state, not
read off the file: `Evolution_BackAndForthAnim`, `Evolution_LoadPic`,
`Evolution_ChangeMonPic`, `EvolutionSetWholeScreenPalette` and
`SetPal_PokemonWholeScreen` all report `translated` at their mirrored pret paths,
and `src/engine/movie/evolution_stubs.asm` no longer holds an
`Evolution_BackAndForthAnim` stub (its two remaining globals, `InternalClockTradeAnim`
and `HallOfFamePC`, belong to other plans). The plan had been sitting at 0/15 in
`project_state --plans` purely because nobody ticked the boxes.

The single remaining item is the maintainer's own eyes on the animation.

## Background & Context

The core gameplay logic of evolution (`EvolveMon`, `TryEvolvingMon`, `EvolutionAfterBattle`, B-button cancel loop, stat recomputation, move learning, and audio fanfare/cries) is fully functional in `src/engine/pokemon/evos_moves.asm` and `src/engine/movie/evolution.asm`.

However, the visual morphing sequence was previously bypassed:
- `Evolution_BackAndForthAnim` is a `ret`-stub in `dos_port/src/engine/movie/evolution_stubs.asm:18`.
- In `src/engine/movie/evolution.asm`, `EvolveMon` has placeholder comments skipping pic staging and palette toggles.
- `SetPal_PokemonWholeScreen` in `src/engine/gfx/palettes.asm` is a placeholder that jumps unconditionally to `SetPal_Screen`, ignoring the $c=1$ (`PAL_BLACK`) silhouette flag.

## Technical Architecture

### 1. Dual VRAM Pic Staging & VRAM Invalidation
- `vFrontPic` ($9000..$930F): 49 tiles ($00..$30).
- `vBackPic` ($9310..$961F): 49 tiles ($31..$61).
- `Evolution_LoadPic` decodes the **new species** front sprite to `vFrontPic` ($9000) and places tile IDs $00..$30 at `BCOORD(7, 2)` on the tilemap.
- `CopyVideoData` copies 49 tiles ($310 bytes) from `vFrontPic` to `vBackPic` ($9310), which arms `g_tilecache_dirty` in the port compositor.
- `Evolution_LoadPic` decodes the **old species** front sprite to `vFrontPic` ($9000) and places tile IDs $00..$30 at `BCOORD(7, 2)`.
- *Result*: `vFrontPic` holds Old Species (tiles $00..$30); `vBackPic` holds New Species (tiles $31..$61).

### 2. Silhouette Whole-Screen Palette Switching (`SetPal_PokemonWholeScreen`)
- `EvolutionSetWholeScreenPalette`: sets `bh = SET_PAL_POKEMON_WHOLE_SCREEN` and calls `RunPaletteCommand`.
- In `src/engine/gfx/palettes.asm:SetPal_PokemonWholeScreen`:
  - Calls `SetPal_Screen` to establish baseline slots, clear `g_bg_attr_table`, and zero `tile_pal`.
  - Tests `bl` (pret register `c`):
    - If `bl != 0`: sets `AL = PAL_BLACK`.
    - If `bl == 0`: reads `[ebp + wWholeScreenPaletteMonSpecies]` and calls `DeterminePaletteIDOutOfBattle`.
  - Directly publishes `AL` to `bg_slot_pal[0]` and `obj_slot_pal[0]`.
  - Sets `byte [g_pal_dirty], 1`.

### 3. $\pm\$31$ Tilemap Offset Flipping (`Evolution_ChangeMonPic`)
- `Evolution_ChangeMonPic` adds `[wEvoMonTileOffset]` to every tile ID in the 7×7 tilemap block at `BCOORD(7, 2)`.
- Adding `+$31` (+49) switches tile IDs from $00..$30 to $31..$61 $\rightarrow$ reveals the **new species**.
- Adding `-$31` (-49) switches tile IDs from $31..$61 back to $00..$30 $\rightarrow$ reveals the **old species**.
- Calls `Delay3` (3 frames) with `hAutoBGTransferEnabled = 1`.
- Row stride on the 40×25 canvas: `SCREEN_WIDTH - 7 = 33`.

### 4. Accelerating Morph Animation Loop (`Evolution_BackAndForthAnim`)
- Outer loop starts with $b=1, c=16$.
- Each pass: `Evolution_CheckForCancel` delays $c$ frames while monitoring `PAD_B`.
- `Evolution_BackAndForthAnim` executes $b$ cycles of (New Pic $\rightarrow$ Delay3 $\rightarrow$ Old Pic $\rightarrow$ Delay3).
- Increment $b$ (`inc bh`) and decrement $c$ by 2 (`dec bl; dec bl`).
- Runs 8 passes ($c = 16, 14, 12, 10, 8, 6, 4, 2$).
- If completed: final `Evolution_ChangeMonPic` locks pic to new species ($31..$61), plays new cry, and restores color.
- If cancelled: retains old species pic ($00..$30), plays old cry, and restores color.

---

## Action Items & Tasks

### Stage 1: Palette HAL Implementation (`src/engine/gfx/palettes.asm`)
- [x] Implement faithful `SetPal_PokemonWholeScreen` in `src/engine/gfx/palettes.asm` supporting `PAL_BLACK` silhouette when `bl != 0`.
- [x] Add structured `DEVIATION` annotation documenting the direct slot-publish HAL boundary matching `SetPal_StatusScreen`.

### Stage 2: Translate Evolution Animation Routines (`src/engine/movie/evolution.asm`)
- [x] Port `EvolutionSetWholeScreenPalette`.
- [x] Port `Evolution_LoadPic` using `BCOORD(7, 2)` for widescreen 40×25 canvas projection.
- [x] Port `Evolution_ChangeMonPic` with 8-bit row/column loop counters and `SCREEN_WIDTH - 7 = 33` row advance.
- [x] Port `Evolution_BackAndForthAnim` with 8-bit cycle decrement (`dec bh`).
- [x] Restore complete `EvolveMon` visual pipeline (new pic load $\to$ VRAM copy $\to$ old pic load $\to$ silhouette palette $\to$ accelerando loop $\to$ cry/color resolution).

### Stage 3: Stub Retirement & Link Integration
- [x] Delete `Evolution_BackAndForthAnim` stub and `STUB{...}` annotation from `src/engine/movie/evolution_stubs.asm`.
- [x] Remove `extern Evolution_BackAndForthAnim` from `src/engine/movie/evolution.asm` and update extern declarations.

### Stage 4: Verification & Validation
- [x] Run `dos_port/tools/faithdiff` across all modified labels (`EvolveMon`, `Evolution_BackAndForthAnim`, `Evolution_LoadPic`, `Evolution_ChangeMonPic`, `EvolutionSetWholeScreenPalette`, `SetPal_PokemonWholeScreen`).
- [x] Run `dos_port/tools/lint_pret_labels --no-scan --strict-claims` (must report 0 violations).
- [x] Run `make -C dos_port static_gate`.
- [x] Run `make -C dos_port goldencheck SCENARIO=item_stone_evolve`.
- [x] Run `make -C dos_port fidelity` core test suite.
- [ ] **MAINTAINER SIGN-OFF, the only thing left here.** Visually verify in DOSBox-X (Rare Candy / Evolution Stone evolution and B-button cancel).
