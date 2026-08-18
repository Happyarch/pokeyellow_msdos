# UI Projection Registry

How GB UI coordinates map into this port's render surface. This is the durable
home for the per-subsystem conventions, the anchor rule, and the index of applied
`; PROJ` tags. Referenced from `CLAUDE.md`. Keep it current whenever a UI element
is placed or moved.

Why this exists: the original Game Boy screen is 20×18 tiles (160×144 px). Our
port renders the overworld at a native **40×25-tile / 320×200-px** viewport with
the player pinned at screen center, so GB UI coordinates do **not** map 1:1 — each
subsystem decides how it projects GB space into ours. Recording every non-identity
coordinate op keeps divergences from faithful GB coordinates auditable, the same
way `; BUG` / `; GLITCH` / `; TODO-HW` tags do.

---

## Per-subsystem conventions

Each subsystem declares its screen transform and any forced spacing overrides.
Add an entry here when a new subsystem is introduced.

### Overworld UI (start / bag / party menus) — TRANSFORM (confirmed)

Extended viewport (40×25) with **per-element anchoring** (anchor rule below).
Mostly pure projection, with occasional spacing overrides allowed. The START
menu (top-right) established this convention; the bag inherits it.

### Battle — GB-centered (RESOLVED)

The whole 160×144 GB battle screen is centered in the 40×25 canvas via a uniform
**+10 col / +3 row** tile offset (no per-element anchoring), with the bottom dialog
box hand-drawn at the same offset. The player HUD uses +3 (not +4) so its frame
"shelf" gets row 14. Per-element placements are in the table below + `; PROJ` tags
in `battle_hud.asm` / `init_battle.asm` / `pics.asm`. See `current_plan_battle_pret_alignment.md`
(battle-frontend draw layer; the old `current_plan_battle_frontend.md` is archived at `docs/plans/`).

### Battle animations — the same GB-centered projection, applied in code

In-battle move animations (`docs/plans/battle_animations.md`) use the
**identical +10 col / +3 row** offset as the battle screen above, via the
`BCOORD(x, y)` macro hoisted into `include/coords.inc`. Two things make this
subsystem different from the ones above, and both are load-bearing:

1. **Nothing here is a window.** These are tilemap writes into `W_TILEMAP` at a
   projected address, so the `wx`/`wy`/`clip`/`max_y` columns are `—` for every
   row — like the `overworld-field` row, not like the menu rows.
2. **`SCREEN_WIDTH` has TWO roles and only one of them projects.** As a row
   STRIDE (`ld bc, SCREEN_WIDTH`, `SCREEN_WIDTH - 8`, `-SCREEN_WIDTH`) the
   literal is correct verbatim on both sides — each means "my tilemap's stride",
   20 in pret and 40 here. As a COORDINATE it is not: pret writes the player-pic
   origin as `5 * SCREEN_WIDTH + 1`, which is the tile **(1,5)**, and the enemy
   origin as a bare `ld a, 12`, which is **(12,0)**. Re-derive those through
   `BCOORD`; never reuse the literal. Getting this backwards is the single
   easiest way to corrupt the battle frame.

The OAM half of the same subsystem does NOT project in the data: `wShadowOAM`
holds pret's exact GB bytes and the offset is applied at publication only, by
`PublishProjectedOAM(80, 24)` with `g_obj_clip = (80,24,240,168)` reproducing the
GB's off-screen hiding. See "OBJ viewport clipping — `g_obj_clip`" below.

Cross-check worth keeping: the animation origins `BCOORD(1,5)` / `BCOORD(12,0)`
are the same cells the `battle-ui (player back pic)` and `battle-ui (enemy front
pic)` rows already record, and a runtime dump confirmed it — a `TELEPORT`
animation changed exactly 49 `wTileMap` cells forming a 7×7 block at canvas
cols 11-17 / rows 8-14, i.e. GB (1,5)-(7,11).

### Cinematics — boot movie (splash, Yellow intro, title, Oak speech) — GB-centered

The whole 160×144 GB screen is centered as a **presentation matte vignette**:
canvas tile `(10,3)`, pixel `(80,24)`, ending exclusively at `(240,168)`. Same
uniform +10 col / +3 row offset as battle. Geometry comes from
`assets/ui_layout_intro_sidecar.json` → `assets/ui_layout_intro.inc`
(`UI_TITLE`, `UI_OAK_SPEECH`, `UI_SPLASH`, `UI_YELLOW_INTRO`), never literals.

**Why cinematics are NOT widescreen-expanded** (unlike the overworld): the
overworld expands because its camera observes a larger part of an existing
spatial map. Cinematics are *authored compositions* whose framing, entrances,
exits, slide distances, object masks and screen-edge timing depend on the
160×144 viewport. Expanding them would either expose artwork and sprite states
pret deliberately hides, or require inventing new staging. Both break fidelity.

The border is a matte: 80 px left/right, 24 px top, 32 px bottom (tile-aligned on
the 25-row canvas). It carries only the cinematic's colour-zero/whiteout field —
no duplicated artwork, no overworld residue, no OBJ.

Mechanics live in `src/engine/movie/movie_projection.asm` (`MovieBeginSurface` /
`MovieEndSurface` / `MovieMirrorSurface` / `MovieSyncScroll`), so no screen
hand-rolls them.

#### Fine source scrolling — `WIN_SRC_X` / `WIN_SRC_Y`, with GB wrap

Cinematic BG content scrolls (the title bounce walks `hSCY` a pixel at a time
including overshoot steps; Yellow-intro scenes scroll clouds/bars via `hSCX`).
The window descriptor carries two default-zero **source** offsets
(`gb_memmap.inc`). They move what the window *samples*, never the projected
destination rectangle — whole-tile remirroring would quantize the motion, and
moving the destination would expose content outside the surface.

Sampling reproduces the hardware exactly:

```text
src_y       = (WIN_SRC_Y + (screen_y - WIN_WY)) & 255
src_x       = (WIN_SRC_X + (screen_x - WIN_X0)) & 255
source tile = SRC_MAP[(src_y / 8) & 31][(src_x / 8) & 31]
```

The `& 31` is the whole point: the GB PPU wraps **within the single 32×32
tilemap**; it never walks past the map boundary into the adjacent one. A linear
read is not equivalent — past the boundary it picks up the next tilemap or
cleared VRAM, where hardware wraps back to *this* map's row/column 0.

**A register trace cannot verify this.** A trace logs the scroll value the game
*wrote*, which matches ground truth even when the renderer mis-samples it.
Wrapped and linear readings differ only in rendered pixels, and only on wrapped
frames. The evidence is `DEBUG_CINEMATIC_MARKERS` + `tools/check_projection.py`:
the harness fills the adjacent tilemap with a POISON tile, so a linear read
paints poison and fails. Verified across offsets 0..7 and 252..255 on both axes.

At `0/0` both offsets take `render_window`'s original unwrapped path, so every
descriptor predating the feature is pixel- and cost-identical.

#### OBJ viewport clipping — `g_obj_clip`

`g_obj_clip = (x0, y0, x1, y1)`, upper bounds **exclusive**, default
`(0,0,320,200)` — the full canvas, which is the semantic identity. Cinematics set
`(80,24,240,168)`.

Clipping is done in the **renderer**, not by culling in the publisher, so partial
edge clipping survives and canonical OAM stays byte-exact: a GB-hidden sprite
(`OAM_Y`=0, `OAM_Y`≥160, `OAM_X`=0, `OAM_X`≥168) lands outside the rectangle and
paints nothing, while a sprite straddling the edge shows exactly its on-screen
pixels.

Ownership follows the `g_obj_over_window` model: only code needing non-default
behavior sets, owns and restores it. `ClearSprites` deliberately does **not**
reset it (a cinematic clears sprites between frames while the rectangle must
persist). A leaked narrow rectangle is caught immediately — the next overworld
frame visibly clips its sprites and the overworld goldens fail.

Cost note: the default configuration deliberately stays on the ORIGINAL code
path in both `render_window` and `render_sprites` rather than routing everything
through a new general test. At DOSBox's 23880 cycles/ms, ~2 extra cycles/pixel
over ~2560 sprite pixels is ~0.2 ms against a 0.548 ms `render_sprites` budget.
So OBJ vertical clipping is per-ROW and horizontal uses a separate
`SPR_COL_CLIP` unrolled variant reached only when the rectangle is non-default.

#### Two traps, both found the hard way

- **BG tile addressing follows `rLCDC` bit 4.** Tiles loaded at `$8000` need the
  bit SET; with it clear (the overworld's setting) ids resolve through signed
  `$9000` addressing and the BG decodes as garbage while OBJ — always unsigned
  `$8000` — look fine.
- **`W_UPDATE_SPRITES_ENABLED = 0` erases cinematic OAM.** 0 means "hide once,
  then park at `$FF`", so `PrepareOAMData` runs `HideSprites` and republishes
  `spr_oam_valid = 0` on the next `DelayFrame`. The parking value is **`$FF`**;
  `MovieBeginSurface` sets it and restores 1 on exit.

### Surfing Pikachu minigame — GB-centered, but it owns its own presentation

`engine/minigame/surfing_pikachu.asm` uses the same centred 160×144 surface as the
cinematics — window at `wx = 80 + 7`, `wy = 24`, clip 160, max_y 168, sourcing
`GB_TILEMAP0`, with the OBJ clip rectangle at (80, 24)–(240, 168). What it does
*not* do is go through `MovieBeginSurface`: it hand-rolls the equivalent in
`SurfingMinigame_SetupPresentation` / `_TeardownPresentation` / a per-frame
`g_surface_redraw_cb` hook, because it also needs a second window descriptor for
the status bar (sourcing `GB_TILEMAP1` at `wy = 24 + $7E`) and the per-scanline
`wLYOverrides` wave channel. Treat it as a third projected-surface owner
alongside the cinematics and battle, not as a `movie_projection.asm` client.

Three consequences, each of which was a live bug on 2026-08-18
(`7445a3fa8`, memory `regression-surfing-pikachu-no-sprites`):

1. **The file re-defines `hlcoord` / `decoord` to `BCOORD` (+10 columns,
   +3 rows).** Every cell this screen authors already sits at the projected canvas
   origin, so anything that reads the canvas back must source `BCOORD(0, 0)` —
   **not** `wTileMap`. Sourcing `wTileMap` puts the whole screen 10 columns right
   and clips half of it off the window.
2. **A screen that stages through `wTileMap` must mirror it itself.** The port
   retired pret's `hAutoBGTransferEnabled` VBlank transfer (`src/home/vblank.asm`),
   so the faithful `ldh [hAutoBGTransferEnabled], a` writes move nothing. The
   minigame's *gameplay* is unaffected because `SurfingMinigame_GenerateBGMap`
   writes `vBGMap0` directly via `hlbgcoord` — only the intro, which stages into
   `wTileMap`, needed an explicit one-shot mirror. Mirroring per frame instead
   would overwrite the generated BG map.
3. **`g_obj_over_window` must be re-armed, not just armed.** Here the window *is*
   the whole screen, so the port's default window-last order hides every OBJ
   completely rather than merely reordering it — and `ClearSprites` / `HideSprites`
   zero the flag by design. Arming it once in setup is not enough if any faithful
   path clears sprites afterwards (this one does, at `LoadGFXAndLayout`).

### Poké Mart — the one screen that anchors to BOTH edges, plus one raw origin

Ruling by the maintainer, 2026-08-18, per the per-element process rule in
"Anchor rule (TRANSFORM subsystems, per axis, by developer intent)" below.

The mart is the first screen whose GB layout hugs **both** edges at once
(`data/text_boxes.asm`): `BUY_SELL_QUIT_MENU_TEMPLATE` is (0,0)-(10,6), flush
LEFT at column 0, and `MONEY_BOX_TEMPLATE` is (11,0)-(19,2), flush RIGHT with
column 19 the last GB column. A center `X+10` projection would detach both from
the edges they were designed against and float them into the middle of the
canvas, so each keeps its own edge instead:

- **BUY/SELL/QUIT — `X+0`.** The mirror image of the START menu's rule. GB col 0
  maps to canvas col 0, same box size, no scaling. This is the FIRST top-left
  anchored element in the registry; everything else in overworld-ui is top-right.
- **MONEY — `X+20`.** Inherits the existing overworld-ui convention unchanged.

The result spreads the mart UI across the widescreen canvas rather than
stretching or centering it, because the GB screen's two edges land on the port's
two edges.

**The priced item list is a deliberate one-off with RAW coordinates, not an
anchor rule.** On hardware it is drawn at `hlcoord 4, 2` with `lb de, 9, 14`
(`home/list_menu.asm:34`) — a 16x11 box over GB cols 4-19, rows 2-12 — which
partially covers the MONEY box's bottom border AND paints over BUY/SELL/QUIT.
That overlap is a 20x18 SCREEN-SIZE CONSTRAINT, not a design intent, and at 40x25
there is room to stop borrowing those cells. The port therefore places it at a
raw canvas origin of **(11, 7)**: its top-left corner just touches the
bottom-right corner of BUY/SELL/QUIT, so the list unfolds down-and-right from the
menu that opened it and overlaps NOTHING (menu cols 0-10 rows 0-6; money cols
31-39 rows 0-2; list cols 11-26 rows 7-17).

Recorded as raw coordinates ON PURPOSE. It is genuinely a one-off: the registry's
vocabulary is per-axis translation, and "offset from another element's box" is a
relative-anchor concept no other screen needs. Inventing one for a single screen
would add a mechanism with exactly one user.

**Consequence for the code, and it is not just a table edit:** the generic
`list_menu.asm` row `(4,2) 16x11` is shared by the bag, the PC and the elevator,
all of which stay `X+20`. `DisplayListMenuID` therefore CANNOT apply one
projection for every caller — the mart must set its own origin. A mart
implementation that simply inherits the generic list anchor is wrong, and will
look wrong in exactly the way this section exists to prevent.

### Vending machine and Celadon prize menu — the mart rule, and nothing bespoke

Decided 2026-08-18 under maintainer delegation ("whatever you do for the inferred
projections is fine, I may overrule it later at my discretion"), following the
Poké Mart ruling above. Geometry measured from pret, not inferred from the
screenshots: TextBoxBorder's `lb bc, h, w` draws a (w+2) x (h+2) box, verified
against the registry's own list-menu row (hlcoord 4,2 + lb de, 9,14 -> 16x11).

  vending drink box  engine/events/vending_machine.asm:20  hlcoord 0,3 + lb bc, 8,12
                     -> 14x10, GB cols 0-13,  rows 3-12   FLUSH LEFT
  prize main box     engine/events/prize_menu.asm:25       hlcoord 0,2 + lb bc, 8,16
                     -> 18x10, GB cols 0-17,  rows 2-11   FLUSH LEFT
  prize coin box     engine/events/prize_menu.asm:145      hlcoord 11,0 + lb bc, 1,7
                     -> 9x3,   GB cols 11-19, rows 0-2    FLUSH RIGHT (col 19 is last)

The prize screen is STRUCTURALLY THE SAME SHAPE AS THE MART: a left-flush main box
with a right-flush money/coin box in the top corner. Its coin box is even the same
9x3 at GB (11,0) as MONEY_BOX_TEMPLATE. So it takes the same ruling — each box
keeps the edge it was designed against, X+0 for the left one and X+20 for the right
one — and the widescreen canvas spreads them apart exactly as it does on the mart.

*** AND NEITHER SCREEN NEEDS A BESPOKE ORIGIN. *** Unlike the mart's priced item
list, the prize main box and its coin box DO NOT OVERLAP on hardware — they occupy
disjoint rows (2-11 vs 0-2) — so there is no 20x18 crowding artefact to undo, and
plain per-axis edge anchoring is enough. The vending machine is a single box with
no companion at all. That is the evidence that the mart's RAW (11,7) origin really
is a one-off rather than the first of a pattern: it exists solely because pret's
list menu had to paint over two other boxes for want of screen space, and no other
service screen has that problem.

Y is untranslated (Y+0) on all three, as everywhere else in overworld-ui: these are
vertical positions within an 18-row layout that the 25-row canvas does not compress,
and the rows are load-bearing (the prize box sits below its coin box by design).

### Pikachu front-pic animation (pikapic) — CENTERED, and the cel draw start must follow

Decided 2026-08-18 under the same maintainer delegation as the vending/prize rows.

`PlacePikapicTextBoxBorder` (engine/pikachu/pikachu_pic_animation.asm:139) is
`hlcoord 6, 5` + `lb bc, 5, 5` -> a 7x7 box at GB cols 6-12, rows 5-11. Unlike
every other screen ruled today it is NOT flush against either edge: it sits
essentially centred on the 20-wide screen (box centre col 9, screen centre 9.5).
So it takes the CENTER rule the dialog and party-menu rows already use — X+10,
Y+0 -> canvas cols 16-22, rows 5-11 — not an edge anchor. Projecting a centred
element to an edge would be as wrong as centring an edge-anchored one.

*** THE FRAME IS NOT THE ONLY THING THAT MOVES. *** The animation's cels are not
placed by an hlcoord literal; `ExecutePikaPicAnimScript`'s object drawer computes
its destination as `wTileMap + wPikaPicPikaDrawStartY * SCREEN_WIDTH +
wPikaPicPikaDrawStartX` (pikachu_pic_animation.asm:464, `hlcoord 0, 0` +
`ld bc, SCREEN_WIDTH` + `AddNTimes`), plus the per-object X/Y offsets. Two
consequences for the port:
  - SCREEN_WIDTH there is a STRIDE (40 on the canvas), not a coordinate. It is
    already correct if left as SCREEN_WIDTH; do NOT substitute pret's 20.
  - The DRAW START values must carry the same +10/+0 projection as the frame, or
    the cels will render at the GB origin while their frame sits 10 columns right.
    The frame and the cels must be projected together or not at all.

An open question deliberately left to the implementer to ANSWER WITH EVIDENCE
rather than guess: pikapic plays during overworld emotion playback, so the
overworld view pointer is live and this is NOT the flat-canvas path evolution
uses. Whether it therefore needs canvas ownership (the evo_canvas_enter/_exit
pattern), a window, or simply writes into the overworld's own staging is a
measurement, not a preference. pret zeroes hAutoBGTransferEnabled around the box
placement and re-enables it after, which is inert in the port — so whatever
commits those cells, it is not that.

### Future subsystems

Add an entry here when introduced, stating the transform and whether it uses
per-element anchoring or one uniform transform.

---

## Anchor rule (TRANSFORM subsystems, per axis, by developer intent)

The GB screen (20×18 tiles) sits inside our viewport (40×25), leaving **20 tiles
of horizontal slack and 7 tiles of vertical slack**. Project each element per axis
by the developer-intended anchor:

```
our_col = gb_col + H_SHIFT     H_SHIFT = 0 (left) | 10 (center) | 20 (right)
our_row = gb_row + V_SHIFT     V_SHIFT = 0 (top)  | ~3-4 (center) | 7 (bottom)

wx     = our_col_left * 8 + 7          ; render_window left edge is WX-7
wy     = our_row_top  * 8
clip_w = width  * 8
max_y  = (our_row_top + height) * 8    ; first screen row the box stops drawing at
```

Examples: a **top-left** element translates neither axis (0,0); a **top-right**
element translates X only (+20, flush-right) and keeps Y (the top edge is shared).
The START menu is top-right, so `our_col = gb_col + 20` reproduces its known-good
`IO_WX = 247` (Python-verified). Equivalently `screen_x = 160 + 8*gb_col`,
`screen_y = 8*gb_row`.

**Process rule (per UI element):** infer the anchor per axis from pret intent,
state the inference, and confirm with the developer whether **X, Y, both, or
neither** is translated before placing it. Record the chosen anchor next to each
element (in code via a `; PROJ` tag, and in the index below).

---

## `; PROJ` tag format (inline, at each placement site)

Greppable, self-documenting. Place one at every non-identity GB→port coordinate op
(translation, scale, or override):

```
; PROJ <subsystem>: GB(<col,row>) <WxH> --(<op>)--> wx=.. wy=.. clip=.. [max_y=..]
```

Examples:

```
; PROJ overworld-ui: GB(4,2) 16x11 --(anchor=top-right, X+20, Y+0)--> wx=199 wy=16 clip=128 max_y=104
; PROJ battle: GB(0,0) 20x18 --(Y-scale 144->200)--> ...
; PROJ overworld-ui: GB(15,9) 5x3 --(spacing override)--> ...
```

The index below can be regenerated by grepping the tree for `PROJ`:

```sh
grep -rn '; PROJ' dos_port/src
```

---

## Index of applied `; PROJ` tags

(Regenerate with the grep above. One row per placement site.)

| Subsystem      | GB (col,row) | W×H   | op                          | wx  | wy | clip | max_y | site |
|----------------|:------------:|:-----:|-----------------------------|:---:|:--:|:----:|:-----:|------|
| overworld-ui (bag list)     | (4, 2)  | 16×11 | anchor=top-right, X+20, Y+0 | 199 | 16 | 128 | 104 | bag_menu.asm (LIST_*) |
| overworld-ui (bag USE/TOSS) | (13, 10)| 7×5   | anchor=top-right, X+20, Y+0 | 271 | 80 | 56  | 120 | bag_menu.asm (USETOSS_*) |
| overworld-ui (bag YES/NO)   | (14, 7) | 6×5   | anchor=top-right, X+20, Y+0 | 279 | 56 | 48  | 96  | bag_menu.asm (YESNO_*) |
| overworld-ui (bag quantity) | (15, 9) | 5×3   | anchor=top-right, X+20, Y+0 | 287 | 72 | 40  | 96  | bag_menu.asm (QTY_*) |
| overworld-ui (dialog)       | (0, 17) | 20×6  | center, X+10, Y+0           | 87  | 152| 160 | 200 | text.asm (PrintText) |
| overworld-ui (START menu)   | (0, 0)  | 10×N  | anchor=top-right, X+20, Y+0 | 247 | 0  | 80  | rows*8 | start_menu.asm (.draw_full) |
| overworld-ui (party)        | (0, ~3) | 20×N  | center, X+10                | 87  | .. | 160 | ..  | party_menu.asm |
| overworld-ui (home YES/NO)  | (14, 7) | 6×5   | anchor=top-right, X+20, Y+0 | 279 | 56 | 48  | 96  | yes_no.asm (YesNoChoice, mode 0; = bag YES/NO) |
| overworld-ui (WIDE YES/NO)  | (12, 7) | 8×5   | anchor=top-right, X+20, Y+0 | 263 | 56 | 64  | 96  | yes_no.asm (WideYesNoChoice) |
| overworld-ui (HEAL/CANCEL)  | (11, 6) | 9×6   | anchor=top-right, X+20, Y+0 | 255 | 48 | 72  | 96  | yes_no.asm (YesNoChoicePokeCenter) |
| overworld-ui (list menu)    | (4, 2)  | 16×11 | anchor=top-right, X+20, Y+0 | 199 | 16 | 128 | 104 | list_menu.asm (generic; reuses bag LIST_* anchor) |
| overworld-ui (list quantity)| (15, 9) | 5×3   | anchor=top-right, X+20, Y+0 | 287 | 72 | 40  | 96  | list_menu.asm (DisplayChooseQuantityMenu) |
| overworld-ui (mart BUY/SELL/QUIT) | (0, 0) | 11×7 | anchor=top-LEFT, X+0, Y+0 | 7 | 0 | 88 | 56 | pokemart.asm (BUY_SELL_QUIT_MENU_TEMPLATE, data/text_boxes.asm) |
| overworld-ui (mart MONEY)         | (11, 0)| 9×3  | anchor=top-right, X+20, Y+0 | 255 | 0 | 72 | 24 | pokemart.asm (MONEY_BOX_TEMPLATE, data/text_boxes.asm) |
| overworld-ui (mart priced list)   | (4, 2) | 16×11| RAW origin (11, 7) — one-off, see the Poké Mart section above | 95 | 56 | 128 | 144 | pokemart.asm (PRICEDITEMLISTMENU; overrides the generic list_menu.asm anchor) |
| overworld-ui (vending drinks)     | (0, 3) | 14×10| anchor=top-LEFT, X+0, Y+0 | 7 | 24 | 112 | 104 | vending_machine.asm:20 (hlcoord 0,3 + lb bc,8,12) |
| overworld-ui (prize menu)         | (0, 2) | 18×10| anchor=top-LEFT, X+0, Y+0 | 7 | 16 | 144 | 96 | prize_menu.asm:25 (hlcoord 0,2 + lb bc,8,16) |
| overworld-ui (prize coin box)     | (11, 0)| 9×3  | anchor=top-right, X+20, Y+0 | 255 | 0 | 72 | 24 | prize_menu.asm:145 PrintPrizePrice (hlcoord 11,0 + lb bc,1,7) |
| overworld-ui (pikapic frame)      | (6, 5) | 7×7  | center, X+10, Y+0 | 135 | 40 | 56 | 96 | pikachu_pic_animation.asm:139 PlacePikapicTextBoxBorder (hlcoord 6,5 + lb bc,5,5) |
| overworld-field (tile reads) | (8, 9) player feet | 1×1 | +16col, +8row → W_TILEMAP (PLAYER_STANDING_COL=24, PLAYER_STANDING_ROW=17); facing-relative reads ±2 tiles (one block), two-steps ±4 | — | — | — | — | overworld.asm (GetTileInFrontOfPlayer), player_state.asm (_GetTileAndCoordsInFrontOfPlayer / GetTileTwoStepsInFrontOfPlayer), player_animations.asm (IsPlayerStandingOnWarpPadOrHole), wild_encounters.asm (PLAYER_STANDING_TILE, fixed OW-A.6) — NEVER copy pret stride-20 lda_coord literals |
| battle-ui (YES/NO box)      | (cc,rr) | W×H   | battle center, X+10, Y+3    | —   | —  | —   | —   | yes_no.asm (mode 1) — UNVERIFIED, no caller wired |
| battle-ui (whole screen)    | (0, 0)  | 20×18 | center in 40×25 BG, +10col/+3row | — | — | — | — | init_battle.asm (full widescreen canvas via render_bg) |
| battle-ui (msg box)         | (0, 12) | 20×6  | → canvas (10,15), +10col/+3row   | — | — | — | — | init_battle.asm (hand-drawn box, stride 40) |
| battle-ui (enemy HUD)       | (1,0)/(4,1)/(2,2) | — | +10col/+3row → name(11,3) lv(15,4) hpbar(12,5); frame shelf row 6 | — | — | — | — | battle_hud.asm (DrawEnemyHUD/DrawEnemyHUDFrame) |
| battle-ui (player HUD)      | (10,7)/.. | —   | +10col/+3row (shifted up 1 row) → name(20,10) lv(24,11) hpbar(20,12) frac(21,13); frame shelf row 14 | — | — | — | — | battle_hud.asm (DrawPlayerHUD/DrawPlayerHUDFrame) |
| battle-ui (enemy front pic) | (12,0)  | 7×7   | +10col/+3row → canvas (22,3), VRAM tile $00 | — | — | — | — | pics.asm (PlacePicTilemap / slide) |
| battle-ui (player back pic) | (1,5)   | 7×7   | +10col/+3row → canvas (11,8), VRAM tile $31 | — | — | — | — | pics.asm (player Red back → mon back at send-out) |
| battle-ui (pokéballs)       | OAM     | 6×1   | player base OAM ($60,$60)+center; enemy ($48,$20)+center (trainer) | — | — | — | — | pokeballs.asm (OAM via PrepareStaticOAM) |
| battle-ui (slide-in)        | —       | —     | pics slide from edges: enemy col 22+step (right), player col 11-step (left), step 18→0 | — | — | — | — | pics.asm (SlideBattlePicsIn, darkened) |
| battle-anim (mon-pic origin)| (1,5) player / (12,0) enemy | 7×7 | BCOORD +10col/+3row → canvas (11,8) / (22,3). pret writes these as `5 * SCREEN_WIDTH + 1` and a bare `ld a, 12` — COORDINATES, not strides | — | — | — | — | animations.asm (AnimationHideMonPic, GetMonSpriteTileMapPointerFromRowCount, ChangeMonPic) |
| battle-anim (move/reset pos)| (2,5) player / (11,0) enemy | 7×7 | BCOORD; the shifted "stepped forward" pic position | — | — | — | — | animations.asm (AnimationMoveMonHorizontally, AnimationResetMonPosition) |
| battle-anim (shake b&forth) | (0,5)+(2,5) / (11,0)+(13,0) | 7×9 clear | BCOORD; drawn at hl then de, erased by ONE 7×9 clear anchored at hl (9 wide because de = hl+2) | — | — | — | — | animations.asm (AnimationShakeBackAndForth) |
| battle-anim (squish)        | (5,5)+(3,5) / (16,0)+(14,0) | 7×7 | BCOORD; row-shift pair walked by AnimCopyRowLeft/Right | — | — | — | — | animations.asm (AnimationSquishMonPic) |
| battle-anim (slide up)      | (1,6)→(1,5) / (12,1)→(12,0); bottom row (1,11) / (12,6) | 7×7 | BCOORD; src/dst pair, stride SCREEN_WIDTH×2 verbatim | — | — | — | — | animations.asm (AnimationSlideMonUp, _AnimationSlideMonUp) |
| battle-anim (slide off)     | (0,5) player / (12,0) enemy | 7×8 | BCOORD; row advance `SCREEN_WIDTH - 8` is a STRIDE (32 here, 12 in pret) | — | — | — | — | animations.asm (_AnimationSlideMonOff) |
| battle-anim (fainted slide) | (1,10)→(1,11) player / (12,5)→(12,6) enemy | 7×7 | BCOORD; walks UPWARD (`-SCREEN_WIDTH`), no push/pop swap — unlike _AnimationSlideMonUp | — | — | — | — | core.asm (SlideDownFaintedMonPic call sites) |
| battle-anim (Marowak dodge) | (17,0) | 7×7 | BCOORD; pret's adjacent `ld de, 20` is a row STRIDE and carries the port's 40 | — | — | — | — | animations.asm (DoBallTossSpecialEffects) |
| battle-anim (enemy HUD shake)| rows 0-6 | 20×7 | canvas pixel rows 24..79 (GB tile rows 0-6 at +3), displaced by the per-row HAL `g_row_xoff` instead of pret's window+rSCX trick | — | — | — | — | animations.asm (ShakeEnemyHUD_SetHUDRows) |
| battle-anim (showcase label)| (1,14) | 12×1 | BCOORD; DEBUG_ANIM_SHOW only — move name printed in the battle frame | — | — | — | — | debug_dump.asm (DEBUG_ANIM_SHOW) |

---

## Window descriptor model (how a projected box reaches the screen)

UI boxes are drawn through the **unified window descriptor list** (see
`docs/current_plan_window_compositor.md`). A screen fully (re)defines the ordered
`g_windows[]` list whenever its window state changes; `render_window` draws each
descriptor in order (painter's order resolves overlap). The projected `wx / wy /
clip_w / max_y` from the anchor rule above are exactly the descriptor fields a
placement site fills (via `set_single_window` for the common single-box case, or
by appending descriptors for multi-box screens like the bag).
