# Current Plan: The S.S. Anne Departure Cutscene

The last of groups A/B. `src/scripts/VermilionDock.asm` is 1 of 5 scripts still
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
   (`src/scripts/VermilionDock.asm:303`; no clearing write exists in the file).
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

## How the approach was decided (three routes, two ruled out)

Recorded because each rejection is a measured fact about the compositor that the
next scene will want.

**The window layer cannot carry a full-width scrolling scene.** `win_rowbuf8` is
256 bytes per row and `render_window` masks the fine source with `and eax, 255`,
so a window row IS a 256-px torus. A 320-px `clip_w` has nothing to read past
256. Feeding 40 columns from the 32-column `GB_TILEMAP0` (the
`MovieMirrorSurface` trick) repeats 8 columns, and during this scene the repeat
region can hold ship.

**The cinematic surface would have been mechanically ideal and is still wrong
here.** `MovieBeginSurface` / `SurfingMinigame_SetupPresentation` present an
exact 160x144 GB surface centred in a matte; under it the ship travels pret's
128 px, `ScheduleEastColumnRedraw` feeds a real consumer, and every scale-up
below evaporates. It is rejected because it letterboxes a mid-gameplay cutscene,
against the maintainer's ruling that the scene reaches the screen edge.

**So the scene stays on the port's own BG path**, and the scroll is split the way
pret already splits it: coarse (the view walk) plus fine (rSCX). See S3/S4.

## Stages — COMPLETE 2026-08-20

- [x] **S1 — Approach.** (A) in spirit, realised on the port's own BG path: the
      window route was ruled out (`render_window`'s row buffer is 256 bytes and
      the fine source is masked `& 255`, so a 320 px window row cannot exist),
      and the cinematic-surface route was ruled out as a mid-gameplay letterbox.
- [x] **S2 — Both `SyncScrollWithLY` defects retired**, by removing the cause
      rather than patching it. `g_row_xoff_on` now has an owner
      (`VermilionDock_BeginDeparture` / `EndDeparture`), and the channel carries
      0..31 px instead of 127. The right-edge clamp added to `ppu.asm`
      (`438fea426`) stands on its own for the two battle callers.
- [x] **S3 — The scroll mechanism.** Coarse: `VermilionDock_RedecodeBand`
      re-fills the band's rows of `wSurroundingTiles` from `wOverworldMap` at an
      advancing block offset. Fine: 0..31 px through `g_row_xoff`. Same
      decomposition pret uses (pointer walk + rSCX), realised where the port's
      map view actually lives.
- [x] **S4 — `VermilionDockSSAnneLeavesScript` lowered.** Outer count is
      `DOCK_WALK_BLOCKS * 2` (16) rather than pret's 8: same 16 px per pass, so
      the ship keeps pret's speed and the scene runs twice as long rather than
      twice as fast. `call ScheduleEastColumnRedraw` is dropped — it feeds
      `GB_TILEMAP0`, which the overworld path never reads.
- [x] **S5 — Restore-on-exit.** `wMapViewVRAMPointer` save/walk/restore carried
      verbatim (bookkeeping on the port, but pret's state); `rWY`/`hWY`,
      `wUpdateSpritesEnabled`, `hAutoBGTransferEnabled`, `rOBP1` all follow pret;
      the per-row HAL is disarmed by `EndDeparture`.
- [x] **S6 — Linked.** `vermilion_dock.asm` moved from `ITEMS_CHECK_SRCS` to
      `SCRIPT_SRCS`; 220 -> 221 of 225 scripts linked.
- [x] **S7 — Map data.** `tools/generators/map_expansion.py` widens
      VERMILION_DOCK 14 -> 22 block columns at generation time so the eastward
      walk samples real cells instead of `wMapBackgroundTile` ($0F, the border
      block — not sea). pret's `maps/*.blk` and `constants/map_constants.asm`
      are never written, so the ROM the golden harness runs is still the game.
- [x] **No golden scenario** — maintainer decision 2026-08-20: not practicable
      for this scene. Recorded here so the absence reads as a decision rather
      than an oversight. The consequence is explicit: everything below is
      gate-verified and ASSEMBLY/LINK-verified, and **none of it has executed**.

## What is verified, and what is not

| claim | evidence |
|---|---|
| assembles, links | `make` exit 0 with `vermilion_dock.asm` in `SCRIPT_SRCS` |
| no annotation drift | `lint_pret_labels` and `--strict-claims` both 0 violations |
| no structural drift | `static_gate` 8 checks |
| the other ~250 maps are unaffected by the widening | `fidelity-full` 86/86, 0 nonzero |
| the departure scene renders correctly | **NOT VERIFIED — no scenario, nothing has run it** |

The band's position is the number most likely to be wrong. It is derived
(`PLAYER_STANDING_ROW * 8`, six rows) rather than transplanted from pret's
literal scanlines 80/128, because those are anchored to the GB camera whose
vertical origin is not the port's — an earlier version of this file copied them
across under a comment asserting the numbers coincided, and they do not. The
derivation is sound but unwitnessed.

`faithdiff` does not cover any of this: `update_label_db` models pret `home/` and
`engine/` only, so `scripts/` labels are absent from the labels table and every
one of them answers "not a pret label". That gap is now its own workstream.

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
