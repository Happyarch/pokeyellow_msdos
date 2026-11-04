# map_editor — overworld map + cutscene authoring

Port-side map authoring. Pret's `maps/*.blk`, `data/maps/objects/*` and
`data/maps/headers/*` are **read-only specification**: everything here writes
either a sidecar under `dos_port/assets/map_overrides/` or a port script under
`dos_port/src/scripts/`.

Two front ends over one core. `commands.py` is the only mutation surface; the
CLI and the pygame UI both call it and neither writes JSON or assembly itself.

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
I inspector      C palette              O cycle route preview
X connections    assemble neighbouring maps at their real offsets (read-only)
click W marker   select a warp; panel edits dest / target warp / kind
[ / ] route step 1-4 down/up/left/right (edits the port script)
Ctrl+Shift+arrow expand that edge by one block
P paint mode     S save     Ctrl+Z undo     F fill     right-click eyedropper
Tab next map     Esc quit
```

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

`ui_scale` drives the HUD font, the properties panels and the bottom bar, so the
chrome stays readable when the window is resized. `"auto"` uses
`min(width/ref_w, height/ref_h)` — the SMALLER axis ratio, so a short window
shrinks the chrome rather than letting it overflow the bottom bar. The scale is
recomputed whenever the window size changes; pinning it with a number overrides
the formula but still respects the bounds.

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
