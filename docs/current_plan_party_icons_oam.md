# Current Plan — Party Mon Icons: retire the BG-tile hack, port pret's OAM path

Status: **in progress.** Sequenced **before the items work** (user, 2026-07-12) so
items doesn't build more on the current shape.

- [x] Stage 0 — baselines + decide the sprite-gating contract
- [ ] Stage 1 — compositor: replace the `g_bg_whiteout` OBJ blanket-skip
- [ ] Stage 2 — port `engine/gfx/mon_icons.asm` under pret's names
- [ ] Stage 3 — party menu: icons via OAM, delete the BG-tile path
- [ ] Stage 4 — naming screen (the other live consumer)
- [ ] Stage 5 — regenerate icon assets without the baked mirror
- [ ] Stage 6 — delete the dead scaffolding + the collision assert

## Session notes (fill in as stages land)

**Stage 0 (done).** Baselines captured (9 pixelcheck frames + perf for
party_menu / ow_idle / battle). Baseline `party_menu` perf: WORK 7.392 ms/frame
(render_bg 2.079, render_sprites 0.176, present_windows 3.184).

*Contract decided — "whoever owns the canvas owns OAM", enforced at the
primitive, not per screen.* Audit result: **every** `g_bg_whiteout = 1` screen
(trainer_card, link_menu, main_menu, options, draw_badges, pokedex,
pokedex_entry, naming_screen; party_menu is the exception that will own OAM)
already calls **`ClearSprites` + sets `wUpdateSpritesEnabled = 0`** on entry. So
`PrepareOAMData` never re-runs behind them — the only thing left stale is the
port-side pair (`spr_oam_valid`, `$FE00`), which is what would ghost.

Rather than sprinkle `spr_oam_valid = 0` across 8 screens (and have the 9th new
screen forget it), **`ClearSprites` / `HideSprites` now publish `spr_oam_valid = 0`
themselves**. That is the GB semantics the port was missing: on hardware, clearing
shadow OAM + the unconditional VBlank DMA means *no sprites are drawn*; in the port
the DMA is gated on `wUpdateSpritesEnabled`, so the clear never reached the
compositor. Any screen that then wants its own OBJ republishes through
`PrepareOAMData` / `PrepareStaticOAM` / the mon-icon writers. `status_screen.asm`'s
explicit zeroing stays (it must happen *after* its whiteout delay frames).

## Why

The port draws party mon icons as **BG tiles parked in vTileset**; pret draws them
as **OAM sprites**. This is a documented DEVIATION (`src/engine/menus/party_menu.asm`
header; `start_sub_menus.asm .exitMenu`), and it is now a proven bug *class*, not a
style difference:

- **VRAM collisions.** At `PM_ICON_TILE_BASE $01` the six 4-tile slots spanned
  `$01–$18`, straddling the two tiles `UpdateMovingBgTiles` rewrites in place —
  `$03` (flower) and `$14` (water). The icons and the animator scribbled over each
  other: mon icons rippled like water/flowers, and mon pixels showed up as
  "phantom flowers". **Fixed 2026-07-12 (`be6500bc`) by re-basing to `$15` plus an
  assembly-time assert** — but that is a *guard rail around* the hack, not a fix
  for it. The icons still clobber real tileset tiles and still depend on
  `StartMenu_Pokemon .exitMenu` calling `LoadTilesetTilePatternData` to restore them.
- **Baked mirrored asset.** The BG layer has no per-tile X-flip, so
  `tools/gen_mon_icons_inc.py` bakes each icon's right column as a horizontal
  mirror of the left (`hflip_tile`), doubling the asset. pret gets this free:
  `WriteSymmetricMonPartySpriteOAM` sets `OAM_XFLIP` on the right column — and
  `render_sprites` **already implements X-flip**.
- **Four screens, one bespoke path.** pret's `mon_icons.asm` serves the party menu,
  the naming screen, trade, and (via `home/window.asm`) `AnimatePartyMon`. The port
  reimplements only the party menu's slice, so naming screen already leans on the
  hack (`naming_screen.asm:291` calls the port's `LoadMonPartySpriteGfx`), and
  trade/Bill's PC would each need their own.
- Icons render in the **BG palette** instead of pret's OBP palettes.

**What changed / why it's feasible now.** The BG-tile approach was a reasonable
workaround when written: `render_sprites` **blanket-skips all OBJ while
`g_bg_whiteout` is set**, and the party menu is a whiteout takeover — so sprites
could not appear on a menu screen at all. But the sprite layer is no longer
overworld-only. `render_sprites` is now a general 8×8 OBJ compositor that draws
whatever `spr_oam_valid` says is live, reading `spr_dos_sx`/`spr_dos_sy` in canvas
coordinates, honoring X/Y flip, both OBP palettes, transparency and BG priority.
A menu can own its OAM directly. Only the blanket-skip is in the way.

## Current state (read before touching anything)

| piece | where | note |
|---|---|---|
| BG-tile icons | `src/engine/menus/party_menu.asm` | `PM_ICON_TILE_BASE $15`, 6 slots × 4 tiles, `LoadPartyMonIconFrame`, `LoadMonPartySpriteGfx` (port's own, NOT pret's), `PartyMenuAnimCB` |
| the animation hook | `src/home/pokemon.asm:263` | `menu_redraw_cb = PartyMenuAnimCB`, standing in for pret's in-loop `AnimatePartyMon` |
| OBJ gate | `src/ppu/ppu.asm:render_sprites` | `cmp dword [g_bg_whiteout], 0 / jne .done` ← **the blocker** |
| OAM contract | `src/ppu/ppu.asm` (`spr_oam_valid`, `spr_dos_sx/sy`), `src/engine/gfx/sprite_oam.asm` (`PrepareOAMData` sets them) | `render_sprites` draws `spr_oam_valid` entries, positioned from `spr_dos_*` — **not** from the OAM Y byte |
| sprites disabled in-menu | `src/engine/menus/start_sub_menus.asm:158` | `wUpdateSpritesEnabled = 0` before `DisplayPartyMenu` ⇒ `frame.asm update_oam` skips `PrepareOAMData` entirely. pret does the same and writes shadow OAM directly — the port's menu path must too |
| icon asset | `tools/gen_mon_icons_inc.py` → `assets/mon_icons.inc` | bakes the mirrored right column; `MON_ICON_FRAME_BYTES 64` (4 tiles), `MON_ICON_BYTES 128` (2 frames) |
| the guard rail | `party_menu.asm` `%error` asserts vs `ANIM_FLOWER_TILE_ID`/`ANIM_WATER_TILE_ID` (`include/gb_memmap.inc`) | delete in Stage 6 once icons leave vTileset |

pret side to port (`engine/gfx/mon_icons.asm`): `AnimatePartyMon` /
`AnimatePartyMon_ForceSpeed1` / `GetAnimationSpeed` / `PartyMonSpeeds`,
`LoadMonPartySpriteGfx` / `LoadAnimSpriteGfx` / `LoadMonPartySpriteGfxWithLCDDisabled`,
`WriteMonPartySpriteOAMByPartyIndex` / `…BySpecies` / `WriteMonPartySpriteOAM`
(+ the symmetric/asymmetric writers — **ICON_HELIX is the asymmetric case**),
`GetPartyMonSpriteID` (`IndexToPokedex` → `MonPartyData` nybble → `ICON_*`).
Callers: `party_menu.asm` (×2), `naming_screen.asm` (×3), `trade.asm` (×2),
`home/window.asm` (`AnimatePartyMon`).

## Stages

### Stage 0 — baselines + the sprite-gating contract
- Capture `tools/pixelcheck.sh partymenu|startmenu|bagmenu|status|battle|pallet` and
  `tools/perf_capture.sh party_menu|ow_idle|battle` as the before-set.
- **Decide the contract that replaces the whiteout skip.** The blanket-skip exists
  for a real reason: per the note on `spr_oam_valid`, a flat-canvas screen that
  clears it would otherwise **ghost the overworld's sprites**. Proposed contract:
  *whoever owns the canvas owns OAM* — a flat-canvas/menu screen must set
  `spr_oam_valid` itself (0 to suppress, N to draw its own). Audit every
  `g_bg_whiteout` setter for compliance before removing the skip
  (`status_screen.asm:169` already zeroes `spr_oam_valid` — the precedent).

### Stage 1 — compositor: replace the blanket-skip
- Remove `render_sprites`' `g_bg_whiteout` early-out; rely on `spr_oam_valid`.
- Make every whiteout screen explicit per the Stage 0 contract. **Any screen missed
  here ghosts overworld sprites** — that is the main regression risk; pixelcheck all
  9 scenarios, which is exactly what they were built to catch.
- Also decide how a menu's OAM survives `wUpdateSpritesEnabled = 0` (see table):
  either the menu writes shadow OAM + sets `spr_dos_*`/`spr_oam_valid` directly
  (pret-shaped), or `update_oam` grows a menu-owned path. Prefer the former.

### Stage 2 — port `engine/gfx/mon_icons.asm`
- New `src/engine/gfx/mon_icons.asm`, **pret names verbatim** (hard rule), icon tile
  data loaded to **vSprites** (`GB_VCHARS0` OBJ area), not vTileset.
- `WriteMonPartySpriteOAM`: 4 OAM entries per mon; right column via `OAM_XFLIP`
  (symmetric) — keep the `ICON_HELIX` asymmetric branch.
- The port's `render_sprites` positions from `spr_dos_sx/sy`, so the writers must set
  those (canvas coords) alongside the OAM bytes — mirror how `PrepareOAMData` does it.
- Icons must arm **`g_tilecache_dirty`** on their VRAM writes (see
  [[compositor-perf-invariants]] / `docs/plans/compositor_perf.md`): BG, window **and**
  sprites all composite from `tile_cache` now.
- `GetPartyMonSpriteID` needs `MonPartyData` as generated data (Tier-1 rule —
  generator → `assets/*.inc`, never hand-encoded).

### Stage 3 — party menu on OAM
- `party_menu.asm`: icons drawn by `WriteMonPartySpriteOAMByPartyIndex`; the bob
  driven by pret's `AnimatePartyMon` (via `home/window.asm`'s call site) rather than
  `PartyMenuAnimCB` + `menu_redraw_cb`.
- Delete `LoadPartyMonIconFrame`, `PM_ICON_TILE_BASE`/`PM_ICON_TILE_COUNT`, the port's
  own `LoadMonPartySpriteGfx`, and the vTileset restore that `.exitMenu` did *for the
  icons* (the HP-bar/box-tile restore stays).
- Coordinates: icons sit at the panel's 2×2 slot (cols 1–2) — project through the
  existing UI layout (`docs/ui_projection.md`), don't hardcode.

### Stage 4 — naming screen
- Repoint `naming_screen.asm:291` at the real `LoadMonPartySpriteGfx` +
  `WriteMonPartySpriteOAMBySpecies` + `AnimatePartyMon_ForceSpeed1` (pret's calls).
- Trade / Bill's PC aren't ported yet — they inherit the correct path for free.

### Stage 5 — icon assets without the mirror
- `tools/gen_mon_icons_inc.py`: drop `hflip_tile` / the baked right column; emit the
  2-tile column pret ships (`MON_ICON_FRAME_BYTES` 64 → 32, `MON_ICON_BYTES` 128 → 64).
- Re-run `make assets`; **never hand-edit `assets/mon_icons.inc`**.

### Stage 6 — delete the scaffolding
- Remove the `%error` asserts and `PM_ICON_TILE_*` from `party_menu.asm`.
- Keep `ANIM_FLOWER_TILE_ID` / `ANIM_WATER_TILE_ID` in `gb_memmap.inc` — the reserved
  vTileset IDs still bind **any other** screen that parks graphics there. Note that in
  their comment.
- Update the DEVIATION notes in `party_menu.asm` / `start_sub_menus.asm .exitMenu` —
  they will be describing code that no longer exists.

## Verification (every stage)

1. `tools/pixelcheck.sh` — all 9 scenarios. Icons are 8×8 OBJ now, so the party-menu
   frame **may legitimately shift by a pixel or in palette** (BG → OBP): if it differs,
   diff the PNG (`tools/render_frame.py`) and justify the delta rather than assuming
   breakage. Every *other* scenario must stay byte-identical — a diff there means a
   ghosted sprite from Stage 1.
2. `make fidelity` / `goldencheck SCENARIO=party_menu` — this is the scenario that
   diffs **OAM entries** against the mGBA golden, so it is the real oracle for this
   plan: pret's icons *are* OAM, so a faithful port should converge toward the golden.
   Existing party_menu masks may need revisiting (masks need written justifications —
   skill `faithfulness-review`).
3. `tools/perf_capture.sh party_menu` — `render_sprites` grows (24 more OBJ), the BG
   tile-cache rebuild per bob frame goes away. Net should be a win; confirm it is.
4. `tools/faithdiff <Label>` for each ported routine + `tools/lint_pret_labels` → 0.

## Risks

- **Ghosted overworld sprites** on any whiteout screen missed in Stage 1. Highest-
  probability regression; pixelcheck catches it.
- **The 10-sprites-per-scanline limit is not emulated** (`render_sprites` header). Six
  mons × 4 tiles = 24 OBJ, but they're on different scanlines — pret runs on real
  hardware, so it fits by construction. Not expected to bite; note it if it does.
- `wUpdateSpritesEnabled = 0` during the menu (see table) — get this wrong and the
  icons simply never appear.
