# Current Plan: The S.S. Anne Departure Cutscene

The last of groups A/B. `src/scripts/vermilion_dock.asm` is 1 of 5 scripts still
check-only; it cannot link because `VermilionDockSSAnneLeavesScript`
(pret `scripts/VermilionDock.asm:40-122`) is un-lowered.

Seeded 2026-08-19 from a read-only requirements sweep. Every number below is
measured; re-measure rather than quoting.

## The finding that changes the job

**My earlier framing was wrong.** I wrote that this needs
`ScheduleEastColumnRedraw` + `ScheduleColumnRedrawHelper` ported into
`src/home/overworld.asm` under the mirror rule, and that the machinery was
"already there". The second half is false in the way that matters:

> **A ported `ScheduleEastColumnRedraw` would have nothing to feed.**

- `RedrawRowOrColumn` (`dos_port/src/home/vcopy.asm:118-200`) writes into
  **`GB_TILEMAP0` ($9800)**.
- `render_bg`'s overworld path **never reads `GB_TILEMAP0` or
  `wMapViewVRAMPointer`** (verified: every `GB_TILEMAP0` reference in
  `src/ppu/ppu.asm` is in the WINDOW code or a comment). It decodes from
  `wSurroundingTiles` and computes scroll arithmetically from
  `wCurrentTileBlockMapViewPointer` / `wXCoord` / `wWalkCounter`
  (`ppu.asm:568-682`).
- Consistent with `gb_memmap.inc:1703`, which already flags
  `wMapViewVRAMPointer` as "dropped/unused after native renderer". The port sets
  it only to the constant `GB_TILEMAP0` and never slides it.

So the port has no VRAM torus for the pret scene to scroll. Porting the two
routines faithfully would produce dead code that assembles, links, passes every
gate, and does nothing — the exact false-witness shape this project keeps paying
for.

## The measured constraint that decides the approach

| quantity | value | source |
|---|---|---|
| ship size / position on the map | 4x2 blocks = **16x8 tiles**, block cols 5-8 | `maps/VermilionDock.blk`, corroborated by `VermilionDock_EraseSSAnne`'s `hlowcoord 5, 2` |
| GB scroll the scene performs | `e=8` outer x 16 px = **128 px = 16 tile columns** | `scripts/VermilionDock.asm:74-105` |
| GB gap, ship left edge to screen left edge | **0 columns** (player enters at warp 1, x=14 → screen left edge sits exactly on the ship's left edge) | `data/maps/objects/VermilionDock.asm:6` + the standard camera anchor |
| **port** ship position | screen cols **16..31** (player pinned at col 24, ship left edge 8 tiles west) | `PLAYER_STANDING_COL = 24`, 40-col viewport |
| **port** scroll needed to clear the left edge | **32 columns = 256 px** | arithmetic from the two rows above |
| **port renderer's horizontal slack** | **64 px = 8 tile columns** (surface 384 px, window 320 px; `bg_scx` clamped 0..64) | `ppu.asm:590-682`, `gb_memmap.inc:1776-1777` |

**256 px needed against 64 px available.** That gap, not the missing routines, is
the actual problem. It also means the maintainer's ruling — "it has to reach the
screen's edge, which will factually take longer now" — is right and is a *bigger*
scale-up than the geometry alone suggests: 16 → 32 columns, double the scroll, on
a surface that can only express a quarter of it.

## Two defects already in the tree (mine, from `15790f746`)

`VermilionDock_SyncScrollWithLY` is translated and assembles, but is wrong in two
ways. Both are latent — the file is check-only, so nothing runs — and both must be
fixed before it links:

1. **It arms `g_row_xoff_on` and never clears it**
   (`src/scripts/vermilion_dock.asm:303`; no clearing write exists in the file).
   The wavy-screen precedent it copied is battle-scoped and cleared by
   `ClearSprites`; this is not. Leaving it armed leaks a per-row displacement into
   every screen drawn afterwards.
2. **It writes offsets up to 127 into a channel with 64 px of headroom.** The
   clamp at `ppu.asm:715-731` catches only NEGATIVE offsets (`jns` → `xor ecx,ecx`);
   a positive `bg_scx + row_xoff` past 64 samples beyond the 384-px surface row and
   tears. pret's `d` reaches 128 by design, so this is not an edge case.

## Approach — three candidates, one recommendation

**(A) Draw the scene on the WINDOW layer, as the surfing minigame does.**
This is the option the evidence favours. The surf minigame runs
`RedrawRowOrColumn` for real — a genuine 2-tile column scroll around the 32-wide
GB torus (`surfing_pikachu.asm:2440-2492`) — and it works *because* the surf
screen is a window descriptor with `WIN_TILEMAP = GB_TILEMAP0` and
`WIN_SRC_X = hSCX` (`:423-436`). The window path walks a GB tilemap row directly,
so pret's torus semantics survive intact. The dock departure is the same shape: a
full-screen cutscene takeover, not the interactive overworld. Taking this route,
`ScheduleEastColumnRedraw` / `ScheduleColumnRedrawHelper` become worth porting
*faithfully* into `src/home/overworld.asm`, because they would then feed a
consumer that exists.

**(B) Extend the BG surface / scroll range.** Widen `wSurroundingTiles` or add a
scene-scoped BG scroll that re-decodes as it advances. Touches the compositor hot
loop that `docs/plans/compositor_perf.md` fences, costs WRAM in a layout that just
finished a delicate expansion, and buys one cutscene.

**(C) Reproduce the visual without pret's mechanism** — e.g. scroll by moving
`wCurrentTileBlockMapViewPointer` with `MoveTileBlockMapPointerEast` +
`LoadCurrentMapView` (`advance_player_sprite.asm:182-190`, `overworld.asm:2841+`),
block-granular, with the fine motion faked. Cheapest, least faithful, and the
label chain would no longer correspond to pret's.

## Stages

- [ ] **S1 — Maintainer decision: A, B or C.** Nothing else should start first;
      each implies different work and A/C imply different files.
- [ ] **S2 — Fix the two `SyncScrollWithLY` defects** (clear `g_row_xoff_on` on
      scene exit; bound the offsets to the channel's real range, or drop the HAL
      entirely if S1 picks (A), where `hSCX`/`WIN_SRC_X` carries the scroll and the
      row split is expressed on the window instead).
- [ ] **S3 — Implement the chosen mechanism.** Under (A): a window descriptor for
      the dock scene, then port `ScheduleEastColumnRedraw` +
      `ScheduleColumnRedrawHelper` into `src/home/overworld.asm` (mirror rule —
      they are `home/overworld.asm` routines and must not live in a script file).
- [ ] **S4 — Lower `VermilionDockSSAnneLeavesScript`** and scale the outer count
      from 8 to whatever clears the port's left edge (arithmetic says 16, i.e.
      double, but this is the number to CHECK against a frame rather than trust).
- [ ] **S5 — Restore-on-exit audit.** pret saves and restores
      `wMapViewVRAMPointer` around the loop precisely because the loop destroys it
      (`VermilionDock.asm:68-70`, `:113-116`); the port's equivalent state must get
      the same treatment. Also `rWY`/`hWY`, `wUpdateSpritesEnabled`,
      `hAutoBGTransferEnabled`, `rOBP1`, and whatever (A)/(B)/(C) introduces.
- [ ] **S6 — Link it** (`vermilion_dock` → `GAME_SRCS`), `make static_gate` (8
      checks), `make fidelity-full`.
- [ ] **S7 — A golden scenario.** There is none for this map, so every stage above
      is gate-verified and not runtime-verified. A cutscene with a scroll count
      tuned by eye and no witness will silently rot.

## Traps recorded from the sweep

- **`wMapViewVRAMPointer` must be restored.** pret's push/pop around the loop
  exists because the loop adds 2 per iteration (+16 total) and the pointer is the
  overworld camera's VRAM origin; leaving it east desyncs every later walk redraw.
- The scene leaves `rSCX` at 0 (the final `SyncScrollWithLY` pass sets `h=0`) and
  never touches `hSCX`, so the GB self-heals on the next VBlank shadow commit. Any
  port mechanism needs an equivalent self-heal or an explicit reset.
- `wNumberOfWarps` is decremented deliberately (`:117-118`) to delete the S.S. Anne
  warp — that is real state change, not cleanup, and must survive.
- pret's own comment says the `wOverworldMap` water overwrite (`:200-206`) is
  unnecessary. Keep it anyway; faithfulness first.
