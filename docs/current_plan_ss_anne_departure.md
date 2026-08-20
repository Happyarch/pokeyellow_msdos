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

## S1 RESOLVED 2026-08-20: (A), as the surf-minigame convention

Maintainer: "(A) would make the most sense if it is the most faithful" — then,
on being shown the sub-variants: "I don't care about the how. I just want it to
be faithful without rewriting everything. The convention used for the surfing
minigame and such is probably okay."

That ruling **supersedes the earlier "it has to reach the screen's edge"**, and it
is the ruling that makes this tractable, so it is worth being explicit about why.
The surf minigame (`SurfingMinigame_SetupPresentation`) is the same 160x144
centred projection the boot cinematics use: `g_bg_whiteout` matte, window
descriptors at wx 87 / wy 24 / clip_w 160 / max_y 168 sourcing `GB_TILEMAP0`,
`hSCX` -> `WIN_SRC_X`, OBJ clip (80,24,240,168), `g_surface_redraw_cb` armed.
Under that convention the dock scene's screen edge IS the GB screen edge, so
**the ship travels pret's exact 128 px** and every scale-up in the sections above
evaporates.

Three problems this dissolves outright, all of which the earlier sections
document as blocking:

1. **The 256-px scroll.** Gone. 128 px, exactly pret's, because the surface is
   160 px wide.
2. **The band-position defect.** The `80`/`128` scanline split becomes correct
   again: on a GB-sized surface those are surface-local rows, projected once by
   the descriptor's `wy`. The camera-anchor mismatch that made them wrong only
   existed while the scene lived on the port's own widescreen camera.
3. **The dead-code objection that opened this plan.** `ScheduleEastColumnRedraw`
   / `ScheduleColumnRedrawHelper` now feed a REAL consumer: they fill
   `wRedrawRowOrColumnSrcTiles` / `hRedrawRowOrColumnDest` /
   `hRedrawRowOrColumnMode`, `RedrawRowOrColumn` writes `GB_TILEMAP0`, and the
   window samples it. The surf minigame already drives that exact interface
   (`SurfingMinigame_GenerateBGMap`), which is the proof it works.

**A3 (coarse shift of `wSurroundingTiles` + fine per-row HAL) is DROPPED.** It was
the best available answer to "span the full canvas without touching the
compositor"; once the scene is GB-framed it is a bespoke mechanism solving a
problem that no longer exists. The per-row HAL is not used by this scene at all —
`VermilionDock_SyncScrollWithLY`'s raster split is expressed as **three window
descriptors** over one tilemap instead (`MAX_WINDOWS` is 6, surf already uses 2):

| rows | descriptor | `WIN_SRC_X` |
|---|---|---|
| above the split | wy 24, max_y 104, start_row 0 | 0 |
| the water band | wy 104, max_y 152, start_row 10 | `d` |
| below the split | wy 152, max_y 168, start_row 16 | 0 |

The right-edge clamp committed in `438fea426` stays — it is a real asymmetry in
the HAL and the two battle callers keep it — but it is no longer on this scene's
path.

## Stages

- [x] **S1 — Maintainer decision.** (A), via the surf/cinematic surface convention.
- [ ] **S2 — Rework `VermilionDock_SyncScrollWithLY`** to publish `WIN_SRC_X` on
      the band descriptor rather than writing `g_row_xoff`. This retires BOTH
      recorded defects (the never-cleared `g_row_xoff_on` and the out-of-range
      offsets) by removing the HAL from this scene, rather than by patching them.
      Its `DEVIATION{}` needs rewriting to match: the split is realised as
      descriptors, not as a per-row displacement table.
- [ ] **S3 — Presentation entry/exit** modelled on
      `SurfingMinigame_{Setup,Teardown}Presentation`: matte, descriptors, OBJ
      clip, `g_obj_over_window`, `g_surface_redraw_cb` to mirror the canvas into
      `GB_TILEMAP0`. Port-only glue, descriptive names, one `class=projection`
      annotation.
- [ ] **S4 — Port `ScheduleEastColumnRedraw` + `ScheduleColumnRedrawHelper`**
      faithfully into `src/home/overworld.asm` (mirror rule), and lower
      `VermilionDockSSAnneLeavesScript` with pret's counts UNCHANGED (`e=8`,
      `b=$10`, `c=8`) — under this convention they are correct as written.
- [ ] **S5 — Restore-on-exit audit.** `wMapViewVRAMPointer` (pret pushes/pops it
      around the loop for a reason), `rWY`/`hWY`, `wUpdateSpritesEnabled`,
      `hAutoBGTransferEnabled`, `rOBP1`, plus the presentation teardown.
- [ ] **S6 — Link it** (`vermilion_dock` -> `GAME_SRCS`), `make static_gate`,
      `make fidelity-full`.
- [ ] **S7 — A golden scenario.** Still required, but no longer a PREREQUISITE:
      with the scene GB-framed, mGBA and the port are composing the same 160x144
      picture, so the scenario is a comparison rather than the only way to
      discover where the band sits.

### The one place the port must do MORE than pret

pret's `VermilionDock_EraseSSAnne` replaces only the ship's LOWER block row
(`hlowcoord 5, 2`, four blocks) and its own comment calls even that unnecessary,
because the ship is south of the player and never redrawn before the map exits.
The port regenerates the view from `wOverworldMap` every frame, so whatever is
left in those blocks comes BACK. Whether the upper row also needs clearing is a
question for the frame, not for arithmetic — check it at S7 and annotate if the
port has to clear more.

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
