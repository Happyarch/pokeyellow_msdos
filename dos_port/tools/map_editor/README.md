# map_editor — overworld map + cutscene authoring

Port-side map authoring. Pret's `maps/*.blk`, `data/maps/objects/*` and
`data/maps/headers/*` are **read-only specification**: everything here writes
either a sidecar under `dos_port/assets/map_overrides/` or a port script under
`dos_port/src/scripts/`.

Two front ends over one core. `commands.py` is the only mutation surface; the
CLI and the pygame UI both call it and neither writes JSON or assembly itself.
The CLI writes immediately with `--write`; the GUI stages every write and commits
on Ctrl+S (`staging.py` is the path layer that makes that one rule true).

```sh
python3 dos_port/tools/map_editor/editor.py VERMILION_DOCK      # GUI
python3 dos_port/tools/map_editor/cli.py inspect VERMILION_DOCK # JSON, dry run
```

## Units — read this before adding a feature

Three coordinate systems are in play and confusing them silently misplaces
events:

| unit | size | where |
|---|---|---|
| editor tile | 8×8 px | `TileYX`, GUI cursor, `manual_delta_tile`, script `dbmapcoord` |
| game map square | 16×16 px | `object_event` / `warp_event` / `bg_event`, `MAPY`/`MAPX`, `wXCoord`/`wYCoord` |
| map block | 32×32 px | `.blk` bytes, extents, map dimensions |

So one block is **2 game map squares** or **4 editor tiles**. Convert only at
adapter boundaries (`objects.py`, `scripts.py`, `view.py`). `MAPY`/`MAPX` also
carry pret's `+4` bias; never change that, it is part of the binary format.

Game positions must land on even editor-tile coordinates, because a map square
cannot be addressed at 8 px resolution.

## Sidecars (`schema.py`)

`schema: 2`, one file per map at `assets/map_overrides/<Pascal>.json`:

```json
{"schema": 2, "map": "VermilionDock",
 "extent_blocks": {"north": 0, "west": 0, "south": 0, "east": 8},
 "base_blocks": [[1, 12, 13]],
 "added_blocks": [[1, 13, 13]],
 "recipes": [{"kind": "repeat_base_column", "edge": "east",
              "source_x": 12, "count": 8, "row_overrides": [[1, 13]]}],
 "objects": {"base:<hash>:0": {"manual_delta_tile": [0, 2], "sprite": "SPRITE_ROCKET"}},
 "new_objects": []}
```

- `base_blocks` are in **original pret block space**; `added_blocks` are in
  **final canvas block space**. Recipes run before `added_blocks`, so an explicit
  cell over a recipe cell overwrites it — `schema.recipe_cells()` exists to avoid
  exactly that.
- Warp overrides live under `"warps"` with the same stable-id scheme and carry
  `dest`, `warp_id` and `kind` (see "Warp events").
- Object overrides are keyed by a **source-derived stable id**
  (`objects.source_id`: map label + object source line + occurrence), never by
  array index, and store only the *manual* delta. Automatic extent translation is
  applied at lowering time, which is what keeps repeated expansion idempotent.
- Unknown top-level keys are preserved verbatim (`MapDiff.extra`), so hand-authored
  fields survive an editor save.

`compose_layout()` is the single implementation of base + diff → final blocks.
`gen_map_headers.py` and `gen_all_assets.py` both go through it; neither
re-implements extent arithmetic.

## CLI

Every command prints JSON and is a **dry run unless `--write`** is passed.

```sh
cli.py inspect MAP
cli.py blocks set MAP --y 3 --x 5 --block 0x2a [--write]
cli.py expand MAP --north-total 1 --west-total 0 --south-total 0 --east-total 8 [--write]
cli.py objects set MAP --object ID [--y T --x T] [--sprite S] [--movement M] [--facing R] [--write]
cli.py warps set MAP --warp ID [--y T --x T] [--dest MAP] [--target-warp N] [--kind K] [--write]
cli.py scripts scan MAP
cli.py scripts move MAP --index N --sha256 H --y T --x T [--write]
cli.py route scan MAP
cli.py route set MAP --label L --sha256 H --bytes-file route.json [--write]
cli.py render MAP --out map.png [--zoom N] [--palette dmg|port-cgb] [--last-map CONST]
```

Map names are matched fuzzily (exact, unique substring, then close spelling).
An ambiguous query is rejected with the candidate list rather than guessing —
that matters because these commands write.

## What expansion does

`expand --write` grows the canvas and:

- fills genuinely new cells with the map's border block (never over a recipe);
- shifts authored cells and object overrides as a whole;
- rewrites **classified** script coordinates — `dbmapcoord`,
  `map_coord_movement`, and `db Y, X ; dbmapcoord X, Y` byte pairs — by the
  automatic delta, once;
- reports connection seams for manual review and never rewrites offsets;
- writes `coverage.script_coordinates_complete: false`, because arbitrary
  hand-written assembly that happens to load a coordinate is **not** parsed.

That last point is the honest limit: expansion is safe for the classified forms
and reports the rest. It is not a licence to assume every script coordinate moved.

## Warp events

Warps are drawn as a translucent **teal** onion skin with a centred **W** (teal
because it stays distinct from the cyan render-reach frame and the other markers
over both grass and water). Clicking one selects it and opens a properties panel
with the same layout as the NPC panel:

- **dest** — destination map constant;
- **target warp** — the 1-based warp id on that map, exactly as pret numbers it;
- **kind** — `door`, `hole`, `stairs`, `carpet`, `ledge`, `other`.

Warps can also be **dragged** on the map like NPCs; the landing tile snaps to the
16 px map square that contains the cursor, because that is the unit a warp byte
addresses.

Editing `dest` or `target warp` genuinely changes where the warp goes: the emitted
record is `db Y, X, target-1, dest_map_id`. Measured, Pallet Town warp 1:
`db 5, 5, 0, 0x25` → `db 5, 5, 2, 0x0C` for dest ROUTE_1 / target 3, and
`db 5, 5, 0, 0x25` → `db 11, 6, 0, 0x25` for a move to editor tile (Y 22, X 12).
Dragging likewise rewrites Y/X in the header.

`kind` is **editor metadata and is never emitted**. pret has no warp-type field:
what a warp does is decided by the tiles it stands on and the destination map's
scripts, not by the event record. Recording a kind is for authoring and review;
writing it into the map-header binary would be inventing data the engine does not
read. `commands.set_warp` returns that caveat in its `note` field, and
`test_objects.py` asserts the generator never touches `warp['kind']`.

Destinations, target ids and positions are real overrides and do reach the
generated header, through the same sidecar mechanism as NPCs.

## Script adapters (`scripts.py`, `routes.py`)


Only source forms that can be round-tripped are recognised:

- `dbmapcoord X, Y` / `map_coord_movement X, Y` (source order is `X, Y`);
- `db Y, X ; dbmapcoord X, Y` — the annotation must agree with the bytes or the
  scan fails;
- movement streams reached by `mov edi, Label` (and `mov edx, Label` for
  `MoveSprite2`) with no intervening label or `call`, consisting only of
  movement operands and terminated by `$FF`.

Operands may be numeric or the named constants (`NPC_MOVEMENT_*`, `STAY`). Writes
keep the author's style: `db NPC_MOVEMENT_UP` becomes `db NPC_MOVEMENT_LEFT`, not
`db 0x80`.

Every write is checked against a SHA-256 of the file taken at scan time, so a
concurrent edit fails that one write instead of being overwritten.

`MoveSprite2` pairs are reported together (`pair`/`channel`/`slot`), which is what
drives the GUI's `NPCMV1` / `NPCMV2` / `NPCMV12` onion skins. Route edits currently
keep the stream length, so comments and labels stay aligned.

## GUI controls

```
left click       place: paint a block, pick/drag an NPC, set the staging tile
middle drag      pan                     arrows  pan too
wheel            smooth zoom (continuous scale, not 1x/2x snapping)
Ctrl + wheel     zoom using the OTHER anchor mode while Ctrl is held
Ctrl + = / -     zoom in / out
G step grid (16px = 1 movement step)   B block grid (32px)   T tile grid (8px)
W warps + signs
N NPC markers    V/H/R port/GB/reach frames (click sets the staged player tile)
Y viewport probe click a step to box what the camera sees; drag to sweep a path
I inspector      C palette              O cycle route preview
X connections    assemble neighbouring maps at their real offsets; strip cells edit the owner
U walkable reach flood from the probe; shade what only the port can show
K look preview  render with the own look, then each neighbour's, then back
click W marker   select a warp; panel edits dest / target warp / kind
[ / ] route step 1-4 down/up/left/right (edits the port script)
Ctrl+Shift+arrow expand that edge by one block
Ctrl+S save       Ctrl+Z undo             F fill        right-click eyedropper
Ctrl-drag (hold) lock a paint stroke or probe sweep to one axis
P paint mode      Tab next map            Esc quit (without saving)
```

### Axis lock

Hold **Ctrl** during a paint or probe drag and the stroke is constrained to one
axis. It is a HOLD, not a toggle: the modifier is read on every motion, so
pressing it mid-stroke starts constraining and releasing it returns to freehand.
The dominant direction from the anchor picks the axis and re-evaluates as you
move, so a stroke can turn from a row into a column without releasing. The status
bar shows `LOCK H` / `LOCK V` while it is active.

| key | default | meaning |
|---|---|---|
| `axis_lock` | `"ctrl"` | modifier held during a drag: `ctrl`, `shift`, `alt` or `none` |

Ctrl is the default because **shift already clears the probe** in probe mode; one
modifier doing two jobs is how a mis-click clears an overlay you were still
using. `shift` is available if you prefer the GIMP binding, at the cost of that
overlap.

A locked paint stroke paints the straight line from the anchor and fills the
cells between motion samples, so a fast drag is solid rather than the handful of
cells the mouse happened to sample. A locked probe sweep is recomputed from the
anchor each motion, so pulling back toward the start shortens the path instead of
growing a branch.

### Saving: edits are staged, Ctrl+S commits

Nothing is written as you edit. A paint stroke, an NPC drag, a warp move, a route
byte and an expansion all land in a scratch copy of the three trees the editor
owns (`assets/map_overrides/`, `assets/map_borders/`, `src/scripts/`), and reach
the repository only when you press **Ctrl+S**. Quitting discards them.

That is what makes an accidental drag harmless and what keeps a 30-second
exploratory click from leaving a sidecar in the tree. A plain `S` does nothing:
the save gesture is unambiguous, and it works from any mode rather than only
paint mode. The status bar reads `*UNSAVED* Ctrl+S` while anything is pending —
in-memory paint, staged sidecars, or staged script rewrites.

Switching maps (Tab) keeps staged edits — they live in the session — and flushes
the in-memory paint first, so a stroke is never lost by navigating. Saving writes
every staged file for every map touched in the session, not just the current one.
`staging.py` is the whole mechanism; the commands keep their `write=True`
contract and the CLI, which never opens a session, still writes directly.

### Zoom anchoring

`zoom_anchor` picks what stays still when the scale changes: `cursor` (default)
keeps the map point under the mouse fixed, `center` keeps the viewport centre
fixed. **Ctrl is a shift key, not a toggle** — while it is held the *other* mode
is in force, and releasing it returns to the configured default. So the setting
is never mutated by a stray Ctrl+scroll; it is a momentary override.

### Settings (`config.json`)

Optional file next to this module; missing means defaults. Unknown keys are an
error, so a typo fails loudly instead of silently doing nothing.

| key | default | meaning |
|---|---|---|
| `zoom_anchor` | `"cursor"` | `cursor` or `center` |
| `zoom_min` / `zoom_max` | `0.25` / `6.0` | scale bounds |
| `zoom_step` | `1.1` | wheel multiplier per notch |
| `zoom_key_step` | `1.25` | Ctrl+= / Ctrl+- multiplier |
| `pan_button` | `2` | mouse button that pans (1 left, 2 middle, 3 right) |
| `ui_scale` | `"auto"` | `"auto"` (derive from the window) or a number to pin it |
| `ui_scale_min` / `ui_scale_max` | `0.75` / `2.5` | bounds applied to either form |
| `ui_reference` | `[1024, 700]` | the window size `"auto"` is measured against |
| `palette_cell` | `32` | base px per paint-palette cell (32 = one block at 1:1, 16 = one step); the UI scale multiplies it |
| `palette_cols` | `"auto"` | tiles per row, or `"auto"` = as many rows as the window is tall |

`ui_scale` drives the HUD font, the properties panels and the bottom bar, so the
chrome stays readable when the window is resized. `"auto"` uses
`min(width/ref_w, height/ref_h)` — the SMALLER axis ratio, so a short window
shrinks the chrome rather than letting it overflow the bottom bar. The scale is
recomputed whenever the window size changes; pinning it with a number overrides
the formula but still respects the bounds.

### Viewport probe (`Y`)

Answers "what is on screen if the player stands here?" without booting the port.
Tap `Y` to enter probe mode, then:

| gesture | effect |
|---|---|
| click a step | anchor the camera box on that **16 px step** |
| drag | sweep a path; the box follows and the outline becomes the **union** |
| shift + click | clear the probe |
| `V` / `H` | show the DOS box (red) / the GB box (blue) — either, both or neither |

The anchor is always a legal player position: a step is 2x2 tiles, so the click
snaps to even tile coordinates and the box is positioned from there, not from
the raw cursor pixel. Leaving probe mode keeps the overlay — it is an annotation
you keep while painting or editing, not a transient cursor. It is also drawn in
connections mode, since the coordinates are the same padded grid.

With a swept path the outline is the union of the window along it: everything
that is on screen at *some* point while walking that route. The union is
computed on the 8 px tile grid and only the boundary is drawn, so a long sweep
costs one outline rather than N overlapping rectangles.

Sizes are the real ones: **DOS** 40x25 tiles (320x200), **GB** 20x18 (160x144).
The GB box is a size reference, not an emulation of the original camera's edge
scroll rules, and neither box is clamped at the map edge — a box hanging off the
map is telling you exactly how much of the view is out of bounds.

### Walkable reach + the attention band (`U`)

Answers "what can the port ever put on screen, and what did the GB never show?"
Place the probe on a walkable step and press `U`:

- the map is flooded 4-connected from that step over every position the player
  can stand on;
- the camera window is unioned over all of them, once for DOS (320x200) and once
  for GB (160x144);
- **DOS minus GB** is shaded amber: cells the port reveals and the original
  hardware never displayed. That is the seam-audit band.

`U` again clears it. The HUD reports
`Reach N steps · DOS X · GB Y · DOS-only Z (+B border) 4px cells` — the unit is
**4 px cells**, not tiles, because the DOS window is 12.5 tiles tall. `+B border`
is the DOS-only area outside the map and its connection strips: the port paints
its border clamp block there, which is a rendering decision rather than a seam,
so it is excluded from the band and reported instead of being dropped silently.

Walkability is the engine's own rule, not an approximation of it: the player
stands on the **lower-left** tile of its 2x2 sprite (`lda_coord 8, 9`; and
`GetTileSpriteStandsOn` says so outright), and collision tests exactly that one
tile two tiles ahead (`_GetTileAndCoordsInFrontOfPlayer` → `CheckTilePassable` →
`IsTilePassable`). So a step is walkable when its lower-left tile is in the
tileset's passable list — the sprite may overlap a wall, and a step wedged into a
corner still counts. Requiring all four tiles would under-approximate the walkable
area and hide seams.

Ledges are **traversable one way**, and the hop is **two steps** long: the first
step puts the player's sprite ON the ledge tile, the second clears it. So a ledge
is in play when the tile *behind* it is passable and reachable — above a downward
ledge, to the right of a leftward one, to the left of a rightward one — and the
tile in front is the ledge tile `data/tilesets/ledge_tiles.asm` lists for that
facing. Ignoring them would put a wall where the game jumps and hide everything
below it. `HandleLedges` returns early for every non-OVERWORLD tileset, so only
overworld maps get them.

The flood runs in two phases so the common case stays cheap: plain 4-connectivity
first (no ledge logic at all), then the ledges of the steps it reached, resolved
from a queue. A hop that lands somewhere new opens a region, so its landing goes
back through phase 1. Each reached step has its ledge checked exactly once.

That two-step hop matters for the union: the camera is centred on the ledge step
mid-hop, so `Reach` separates positions the player can **stand** on from
positions the camera merely **passes over**. The union is taken over both, since
"can the player see from here" is a camera question. (Measured across every
overworld map, the mid-hop positions change the union by 0 cells today — a 320 px
window is 20 steps wide and a hop is 2, so the midpoint window is already covered
by the two end windows — but the model records them rather than relying on that.)

Deliberate approximations, all in the *safe* direction (they over-mark, never
under-mark): the flood is undirected ("can the player ever stand here", not "can
they get here from the entrance"), sprites are ignored because they move, warps
are ordinary passable tiles, tile-pair collisions (`CAVERN`/`FOREST` elevation
edges) are unmodelled, and water/surfing is out of scope. The GB box is a size
reference rather than the real edge-clamped camera, so near a map edge the band
over-marks too.

The reach is derived from the live grid, so any edit (paint, fill, undo,
expansion, map switch) drops it — a stale overlay would claim the port shows
cells it no longer does.

### Tileset + palette preview (`K`)

Answers "does anything change at this seam?" — the swap, before crossing.

**How the game loads it.** `LoadTilesetHeader` (`engine/overworld/tilesets.asm`)
copies the tileset's graphics, blockset and collision list into fixed slots and
arms `g_tilecache_dirty` so the decoded-tile cache rebuilds; `LoadMapHeader`
calls it on **every map load**. So yes: the tileset is rebuilt per map, and while
you stand on map A, **A's tileset expands every block on screen — including the
strip copied out of B's `.blk`**. The palette is per map too
(`SetPal_Overworld`): cemetery → `PAL_GRAYMON`, cavern → `PAL_CAVE`, a town gets
`map id + 1`, every route shares `PAL_ROUTE`, and interiors inherit `wLastMap`.

The consequence is worth stating plainly, because it narrows the search:

> A world cell can only look different when you cross if the two maps differ in
> **tileset** or **palette**. Same tileset + same palette ⇒ provably identical,
> because the block on screen is the neighbour's own byte in both cases.

`K` cycles the look: own → each *distinct* connected neighbour → own. The canvas
re-renders the same block ids through that tileset and palette, so the amber band
is shown exactly as the neighbour would show it. The HUD says
`View as VIRIDIAN_CITY (OVERWORLD · PAL_VIRIDIAN)`, and that it is a preview —
edits still belong to the map you have open.

With the reach showing, `K` also measures it:

```
Swap at VIRIDIAN_CITY: 2668 of 2668 band cells change (shape 0, colour 2668)
```

- **shape** — the two tilesets under the *same* palette: a different tileset turns
  these block ids into different graphics. This is the tree→grass case.
- **colour** — the two palettes under the same tileset: the per-map palette
  recolours them. A route↔city seam is colour-only.

Measured on Route 1: both neighbours are `OVERWORLD`, so shape is **0** and every
band cell changes colour only (Viridian and Pallet each have their own palette).
The genuine shape change needs a cross-tileset pair — `ROUTE_22` (OVERWORLD) vs
`ROUTE_23` (PLATEAU) — which the port does not connect, so no live seam can
change graphics today.

### Paint palette sizing

The swatches are one map block each, drawn at **1:1 pixels** by default (32 px at
1×) and multiplied by the UI scale, so the tiles are actually readable — a step-
sized 16 px cell was too small to tell blocks apart.

`palette_cols` defaults to `"auto"`, which fits as many ROWS as the window is
tall and derives the columns from that. That is the trade the palette needs: a
bigger cell does not make a wider strip that eats the map, it makes a LONGER
column with fewer tiles per row. Set a number to pin the columns instead.

| window | cell | cols x rows | strip |
|---|---|---|---|
| 1024x700 | 32 | 7 x 19 | 236 x 620 |
| 1600x1000 | 46 | 7 x 19 | 334 x 886 |
| 2560x1440 | 66 | 7 x 19 | 474 x 1266 |

The blocks are rendered at their true 32 px and then resized to the cell, so a
32 px cell is exact 1:1 and larger cells are nearest-neighbour scaled (sharp,
not blurred). `palette_click` hit-tests the drawn cell, so clicking picks the
block under the cursor at every scale.

### Connections view (`X`)

Draws every connected map assembled at the offset `get_connection` implies, under
the current map, with this map outlined. In this mode the current map is drawn
**without** its border ring, because the ring is exactly what the neighbours are
there to fill — otherwise the padded raster would paint border blocks over the
seam you are trying to inspect. Neighbours with a different tileset are reported
in the status area instead of drawn, since their block IDs are not comparable.

The geometry is not guessed: `view.neighbour_origin` derives each origin from the
same indices the generator emits, and `test_connections.py` checks the assembled
neighbours cell-for-cell against the strips `compose_padded` already reproduces
from the runtime.

A **strip cell is the neighbour's data**, not this map's: the runtime copies
MAP_BORDER rows or columns of the connected map's `.blk` into `wOverworldMap`, so
editing one here writes to the map that owns it (`commands.set_block(owner, ...)`)
and both sides of the seam update at once. Undo writes back to the owner too, the
paint overlay tints each neighbour's cells separately, and the HUD names the owner
under the cursor (`B(Y:0,X:0)=$52 ← PALLET_TOWN(Y:0,X:0)`). A fill stops at an
ownership boundary, so a flood fill can never start editing another map.

`C` switches between the port's real overworld palette and the DMG ramp. The
overworld palette is BG slot 0 only; interiors depend on `wLastMap`, which is
runtime state the editor cannot infer, so it says so in the HUD instead of
guessing. Sprite thumbnails assume the identity `OBP` register.

## Tests

```sh
python3 -m unittest discover -s dos_port/tools/map_editor -p 'test_*.py'
```

Focused, and the only meaningful gate for this tool — the port's static and
fidelity gates do not exercise it. After changing a generator, confirm the
checked-in maps still regenerate identically (`make -C dos_port assets`, then
compare `map_headers.inc` / `map_dims.inc` / `vermilion_dock_blk.inc`).

## Known data limits

Two pret maps cannot be opened as standalone grids, and the editor reports that
rather than crashing:

- `UNDERGROUND_PATH_ROUTE_7_COPY` is a COPY map with no `.blk` of its own;
- `UNDERGROUND_PATH_NORTH_SOUTH` declares 4×24 while pret's own source notes the
  file is 4×23.
