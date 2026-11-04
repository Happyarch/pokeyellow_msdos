# Map seam analysis — editing map transitions without crossing maps

Status: active. Owner: map editor (`dos_port/tools/map_editor/`).
Related: `docs/current_plan_backlog.md`, robitnet memories
`map-editor-viewport-probe-geometry`, `map-editor-edits-are-staged-until-ctrl-s`.

## Why

Map authoring is edge work. A transition is two maps' edges agreeing, and the
editor used to make that the hardest thing to do:

- The connection strip drawn around a map is **the neighbour's data**, copied at
  runtime out of the neighbour's `.blk` into `wOverworldMap`
  (`LoadNorthSouth/EastWestConnectionsTileMap`). The editor locked those cells,
  so fixing a seam meant Tab-ing to the other map, finding the matching rows by
  eye, editing there, and coming back. **Fixed** in `8f61243a4` (stage 0).
- The port's viewport is **40x25 tiles (320x200)**; the GB's is **20x18
  (160x144)**. The port therefore puts on screen cells the original hardware
  never showed — so a seam that was harmless on the GB can be visible here.
  Those cells are the ones worth auditing.
- Block IDs legitimately differ between maps for the same graphic (the devs kept
  IDs fixed only for tiles that were visible across a seam). Any check that
  compares IDs rather than rendered pixels produces false positives.

## What the engine actually does (measured, not assumed)

These are the facts the flood must model. Each was read out of the port's own
translation, not inferred:

- **Positions are 16 px steps, never tiles.** `_AdvancePlayerSprite` does
  `wXCoord += wSpritePlayerStateData1XStepVector` with a step vector of +-1
  (`dos_port/src/engine/overworld/advance_player_sprite.asm:13-17`), and
  `GetTileSpriteStandsOn` converts a map-coord delta to tile rows by `*2`
  (`engine/overworld/movement.asm:204-205` "move tile pointer two rows down").
  So `wYCoord`/`wXCoord` are step units and **odd tile positions do not exist**.
- **Collision is ONE tile: the destination step's bottom-right tile.** The
  player's feet are the bottom-right of its 2x2 sprite (`lda_coord 8, 9`), and
  `_GetTileAndCoordsInFrontOfPlayer` reads exactly one tile two tiles ahead in
  the travel direction (`src/engine/overworld/player_state.asm:505-533`), which
  `CheckTilePassable` feeds to `IsTilePassable`
  (`src/home/overworld.asm:3700`). A step is therefore walkable when its
  **bottom-right tile** is in the tileset's passable list — *not* when all four
  of its tiles are. Measured on PALLET_TOWN: 214 steps pass the feet rule, 202
  pass an all-four rule, and the 12-step difference is real geometry (e.g. step
  (14,7) has feet tile `$54`, passable, while its top row is water `$14` — the
  player standing at the water's edge with the sprite overlapping the water).
- **Ledges are traversable, one way, and they are TWO steps long.**
  `HandleLedges` (`engine/overworld/ledges.asm`) matches (facing, standing tile,
  tile in front) against `data/tilesets/ledge_tiles.asm`, then sets
  `wSimulatedJoypadStatesIndex = 2` with two identical pad presses — two steps —
  and sets `BIT_LEDGE_OR_FISHING`, which makes `CollisionCheckOnLand` return
  "passable" for the whole hop. It is OVERWORLD-only. A flood that ignores
  ledges sees a wall where the game jumps over it and **misses everything below
  it** — the unsafe direction.
- **A ledge is in play when the tile BEHIND it is passable and reachable** —
  above a downward ledge, to the right of a leftward one, to the left of a
  rightward one. Reachability is exactly what the flood has already established,
  so the rule is checked only from steps the player can stand on. pret's table
  additionally pins the approach tile to `$2C`/`$39`; measured across all 34
  OVERWORLD maps that pins the same **756** transitions as "approach tile is
  passable" (0 disagreements), so the two rules agree today. The table is what
  `HandleLedges` actually matches, so it is the one implemented: paint a ledge
  whose approach tile is not one of those two and the hop genuinely will not
  happen in-game, which the editor should tell you.
- **The mid-hop position is a camera position, not a standing position.** The
  first of the two simulated steps puts the player's sprite ON the ledge tile, so
  the camera is centred there and its window is real — but the player cannot stop
  or turn, so the flood must never expand from it. `view.Reach` therefore
  separates `standing` from `traversed`.
- **Tile-pair collisions are barriers on CAVERN/FOREST only**
  (`data/tilesets/pair_collision_tile_ids.asm`). Not modelled in v1; ignoring
  them lets the flood cross an elevation edge the game forbids, which
  over-marks. That is the safe direction and is documented, not hidden.
- **Warps and doors are ordinary passable tiles** (e.g. Overworld `$1B`/`$58` are
  in both `warp_tile_ids.asm` and `Overworld_Coll`), so a flood that treats them
  as standing positions is faithful. Warps create no intra-map adjacency.
- **Sprites are ignored.** NPCs move, so "can the player ever stand here" must
  not depend on where an NPC happens to be.

## Stages

- [x] **0. Write-through connector editing.** A strip cell knows its owner
  (`ComposedMap.strip_owner`: padded idx -> (neighbour CONST, final y, x)); a
  paint writes to the owner's sidecar via `commands.set_block`, the strips
  re-copy immediately, undo writes back to the owner, flood fill stops at an
  ownership boundary. Shipped `8f61243a4`.
- [ ] **1. Walkable reach + viewable union** (corrected by the spec review).
  - `view._collision_lists` must accumulate **stacked labels**: pret writes
    `RedsHouse1_Coll::` immediately above `RedsHouse2_Coll::` and a single
    `coll_tiles` line, and the first parser assigned the list only to the last
    label — measured: `RedsHouse1`, `Mart`, `Dojo`, `ForestGate`, `Museum` all
    parsed as **empty**, so `reds_house` (4 maps, incl. the player's own house)
    reported zero walkable steps. Assign each `coll_tiles` set to every pending
    label.
  - `view.feet_tile` / `step_walkable`: the bottom-right tile rule above.
  - `view.reachable_steps`: two phases per round, in the order that keeps the
    common case cheap. **(1)** plain 4-connectivity from every step reached so
    far — no ledge logic in the inner loop, and it answers most of the map;
    **(2)** then resolve the ledges of those steps from a queue. A hop that lands
    somewhere new opens a region, so its landing goes back through phase 1.
    Every reached step has its ledge checked exactly once, so the cost is
    proportional to what the flood covers rather than to the whole map (Route 1:
    2 ms for 369 standing + 42 mid-hop steps). Returns `Reach(standing,
    traversed)`.
  - `view.viewport_cells`: union of the camera window over a step set, as
    absolute 4 px cells (already written; the grids align because every origin
    is a multiple of 4).
  - `view.cell_meaningful` / `view.viewable`: the DOS-only band **masked to real
    map data** (the map's own blocks plus connection strips). Outside that the
    port paints its border clamp block, which is a rendering decision, not a
    seam; without the mask every edge-adjacent reach drowns the band in border
    noise. Report the excluded border count rather than dropping it silently.
- [ ] **2. Probe integration.** `U` in probe mode computes the reach from the
  probe anchor (the last `probe_steps()` entry, which falls back to the player's
  own step), draws the DOS-only band as an **amber** translucent fill, outlines
  the DOS union (red) and GB union (blue), and reports
  `reach N steps · DOS X · GB Y · DOS-only Z (+B border)`. `U` again clears it.
  Invalidate on every `cm.grid` mutation (paint, undo, fill, expand, load, map
  switch) — the skeleton currently never invalidates and never draws, which
  would ship an overlay that lies after the first edit.
- [ ] **3. Cross-map seam check.** Started, and the mechanism turned out to be
  narrower than the plan assumed. `LoadTilesetHeader` rebuilds the tileset per
  map (`LoadMapHeader` calls it every load), so while standing on A, A's tileset
  expands every block on screen **including the strip copied from B** — and
  `SetPal_Overworld` picks the palette per map (town = `map id + 1`, all routes =
  `PAL_ROUTE`, interiors = `wLastMap`). The block on screen at a shared cell is
  the neighbour's own byte in both cases, so **a world cell can only change
  appearance across a seam if the tileset or the palette differs.**
  `K` now previews the map through each connected neighbour's tileset + palette
  and reports `Swap at X: N of M band cells change (shape S, colour C)`, where
  `shape` compares the two tilesets under one palette and `colour` the two
  palettes under one tileset. Measured on Route 1: shape **0**, colour **2668**
  for both neighbours (shared `OVERWORLD`, different town palettes). The genuine
  shape change needs a cross-tileset pair — `ROUTE_22` vs `ROUTE_23` — which the
  port does not connect, so **no live seam can change graphics today**.
  Still open: the `ConnectionView`-assembly comparison, which would also cover
  the pairs the port renders as border-vs-edge, and palette context for interiors
  (already warned, not guessed).
- [ ] **4. Docs + tests.** README section, tests for the flood/union/difference,
  and an explicit note that the flood is undirected ("can the player ever stand
  here", not "can they get here from the entrance"), that tile-pair collisions
  are unmodelled (over-marks), and that water/surfing is out of scope in v1.

## Findings outside the editor (for the maintainer, not fixed here)

- **The ROUTE_22 <-> ROUTE_23 seam does not exist in the port.**
  `gen_map_headers.py:468` deliberately omits `ROUTE_22`'s NORTH connection
  ("NORTH Route23 omitted (PLATEAU tileset)"), and `ROUTE_23` and
  `INDIGO_PLATEAU` are declared with **no connections at all** (`:473-474`).
  Verified in the generated `dos_port/assets/map_headers.inc`:
  `map_header_ROUTE_22` has connections bitmask `0x01` (EAST only),
  `map_header_ROUTE_23` and `map_header_INDIGO_PLATEAU` have `0x00`. Pret
  declares both links and calls them "unnecessary"
  (`data/maps/headers/Route22.asm:2`, `Route23.asm:3`). Consequence in the port:
  the badge-check road and the league approach are not walkable from Route 22 —
  the player is blocked one step earlier than on the GB. This is a fidelity
  question of its own (a cross-tileset strip cannot be drawn with the current
  map's tileset), so it is recorded here rather than silently patched by the
  editor work.
- The earlier draft of this plan claimed that pair was "the one cross-tileset
  connection the checker would exercise". It is not a connection in this port at
  all, so the seam check has **no cross-tileset pair to compare today**.

## Decisions

- The flood is seeded by the probe anchor and run with `U`, so a plain click
  still means "one step". A click that both placed a step and flooded would make
  the point probe impossible.
- Walkability comes from pret's `data/tilesets/collision_tile_ids.asm`, the same
  list the port links as `<tileset>_Coll`.
- The attention band is `dos_cells - gb_cells` on absolute 4 px cells, then
  masked to real map data. Both windows are player-centred and DOS strictly
  contains GB, so per-position difference is the frame and union-difference is
  "ever on DOS, never on GB".
- The union is over every position the CAMERA occupies (`Reach.steps()` =
  standing + mid-hop), because "can the player see from here" is a camera
  question, not a standing question. Measured across all 34 OVERWORLD maps,
  adding the mid-hop positions changes the union by **0 cells** — a 320x200
  window is 20 steps wide and a hop is 2, so the midpoint window is already
  covered by the two end windows. They are modelled anyway: the camera really is
  there, and a future narrower window would make the omission a real under-mark.
- The GB box is a **size reference**, not an emulation of the GB camera's
  edge-scroll rules (`README.md`). Near map edges the real GB camera slides while
  the reference stays centred, so the band over-marks there. Over-marking is the
  safe direction; the alternative risks missing seams.
- Nothing here writes to pret. Edits remain port-side sidecars, staged until
  Ctrl+S.

## Open questions

- Should the band also mark cells visible from **both** maps (the shared-view
  set) as a second class? They are the seam check's input, so showing them would
  explain why a flag exists. Cheap once `ConnectionView` overlap is computed.
- Water/surfing: a land-only flood is the v1 scope. Water-heavy routes have the
  largest DOS-only bands, so a surf-inclusive mode is a plausible follow-up
  (`data/tilesets/water_tilesets.asm`).
- Should the ROUTE_22/23 isolation become its own work item (port fidelity), or
  is the omission accepted until the PLATEAU strip problem is solved?
