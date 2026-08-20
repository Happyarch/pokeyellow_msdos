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
   clamp at `ppu.asm:715-731` caught only NEGATIVE offsets (`jns` → `xor ecx,ecx`);
   a positive `bg_scx + row_xoff` past 64 samples beyond the 384-px surface row and
   tears. pret's `d` reaches 128 by design, so this is not an edge case.

   **The RENDERER half of (2) is fixed** (`.row_xoff_hi`, `ppu.asm`): the channel
   now clamps at `SURF_W - RENDER_W` as well, so no caller can walk the source
   pointer into the next surface row. The default `g_row_xoff_on == 0` fast path
   is untouched — the added compare sits after the `jns`, on the armed path only.
   That makes the channel safe; it does NOT make the dock scene correct, because
   a clamped 127 is still not a 127-px scroll. The scene-side half stays open and
   its shape depends on S1.

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

## S1 RESOLVED 2026-08-20: (A), and what (A) turned out to mean

Maintainer chose (A) — "if it is the most faithful". Reading the window
compositor at implementation depth split (A) into three, and only one of them
satisfies both halves of what has been asked for.

**A1 — the cinematic surface, `MovieBeginSurface` (`engine/movie/movie_projection.asm`).**
This is the mechanically ideal (A): the screen becomes one window descriptor
sourcing `GB_TILEMAP0`, `MovieMirrorSurface` repacks the stride-40 canvas into
the stride-32 GB map every frame, and `hSCX` transfers to `WIN_SRC_X`. pret's
`ScheduleEastColumnRedraw` / `RedrawRowOrColumn` would drive a real consumer and
the ship would travel exactly pret's 128 px. **It is rejected on the maintainer's
own ruling**: that model deliberately keeps the GB's 160x144 framing centred in a
matte (`movie_projection.asm:9-17`), so the dock scene would letterbox mid-
gameplay — the opposite of "it has to reach the screen's edge".

**A2 — a full-canvas (320 px) window.** Not viable, and the limit is structural,
not a tuning knob: `win_rowbuf8` is **256 bytes per row** and `render_window`
masks the fine source with `and eax, 255` (`ppu.asm`), so a window row is a
256-px torus. A 320-px `clip_w` cannot be fed. Making it possible IS approach
(B) — renderer surgery — wearing (A)'s name.

**A3 — CHOSEN. Keep the overworld BG path; split pret's scroll the way pret
already splits it.** pret advances two quantities in lockstep: a COARSE one
(`wMapViewVRAMPointer += 2` per outer pass, with `ScheduleEastColumnRedraw`
feeding a fresh east column so the torus never re-shows stale content) and a FINE
one (`rSCX = d`, 0..15 within each pass). The port realises the coarse half by
shifting the affected rows of `wSurroundingTiles` west two tiles and filling the
new east columns with water, and the fine half through the existing per-row HAL —
which now only ever needs **0..15 px**, comfortably inside the 64 px the channel
has and inside the clamp added above. The 256-px problem dissolves: it was only
ever a problem for a mechanism that had to express the whole scroll as a view
offset.

Consequence for the pret labels, stated plainly rather than discovered later:
`ScheduleEastColumnRedraw` / `ScheduleColumnRedrawHelper` are **not** ported.
They write `wScreenEdgeTiles` for `RedrawRowOrColumn`, which writes `GB_TILEMAP0`,
which the overworld path does not read — porting them would be the dead-code
false witness this plan opened by rejecting. The port keeps their *decomposition*
and records the substitution as a `DEVIATION{class=projection}`.

## Stages

- [x] **S1 — Maintainer decision: A, B or C.** (A), realised as A3 above.
- [ ] **S2 — Fix the two `SyncScrollWithLY` defects** (clear `g_row_xoff_on` on
      scene exit; bound the offsets to the channel's real range, or drop the HAL
      entirely if S1 picks (A), where `hSCX`/`WIN_SRC_X` carries the scroll and the
      row split is expressed on the window instead).
- [ ] **S3 — Implement A3.** A scene-scoped coarse shift of the water band in
      `wSurroundingTiles` (west 2 tiles per outer pass, east columns refilled with
      water tile $14), plus the fine 0..15 px through `g_row_xoff`. No window
      descriptor, no compositor change, and NOT a port of
      `ScheduleEastColumnRedraw` — see the S1 note for why porting it would be
      dead code.
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
