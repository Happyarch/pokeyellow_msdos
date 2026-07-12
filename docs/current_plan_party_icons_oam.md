# Current Plan — Party Mon Icons: retire the BG-tile hack, port pret's OAM path

Status: **in progress.** Sequenced **before the items work** (user, 2026-07-12) so
items doesn't build more on the current shape.

- [x] Stage 0 — baselines + decide the sprite-gating contract
- [x] Stage 1 — compositor: replace the `g_bg_whiteout` OBJ blanket-skip (`58d5a94a`)
- [x] Stage 2 — port `engine/gfx/mon_icons.asm` under pret's names
- [x] Stage 3 — party menu: icons via OAM, delete the BG-tile path
- [x] Stage 4 — naming screen (the other live consumer)
- [x] Stage 5 — regenerate icon assets without the baked mirror
- [x] Stage 6 — delete the dead scaffolding + the collision assert

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

**Stage 1 (done, `58d5a94a`).** pixelcheck 9/9: 8 byte-identical; **`battle`
differs by 438 px and it is a FIX** — the before-frame drew three ghost pokéballs
over the FIGHT/ITEM/RUN menu (`HideBattlePokeballs` cleared shadow OAM, but the
stale `$FE00` entries stayed *published*, and battle is not a whiteout screen so
the old skip never covered it). `make fidelity` 6/6 PASS. Note the `party_menu`
golden already carries 4 masks that describe the BG-icon deviation
(tilemap 0,1..11,2 / vChars0 slots 0-127 / OAM entries 0-23) — **Stage 3 should
retire those masks**, they are exactly what this plan fixes.

**Stages 2 + 3 (done, one commit — they are inseparable: the port's own
`LoadMonPartySpriteGfx` in party_menu.asm had to go before pret's real one could
link).** `src/engine/gfx/mon_icons.asm` holds every pret label plus the two OAM
writers pret keeps in `engine/items/town_map.asm` (the port's `town_map.asm` is a
DANGLING/unlinked file, so they live with their only caller — registered in
`tools/pret_label_allowlist.json`). Stage 5's generator rewrite rode along (raw pret
blobs + `MonPartyData`), and most of Stage 6 too (the `PM_ICON_TILE_*` equates,
the `%error` asserts and `PartyMenuAnimCB` are gone).

Three things the plan did not anticipate, all load-bearing:

1. **OBJ-vs-window z-order.** The icons were written, published and *painted over*:
   the port composites `present_windows` **after** `render_sprites` (a documented
   deviation — its only window is normally the bottom dialog box, which must occlude
   NPCs the widescreen camera exposes under it). The party panel IS a window, so its
   icons need the hardware order. New opt-in flag **`g_obj_over_window`** (ppu.asm,
   default 0 = today's order): `ShowPartyMenuWindows` raises it, `.exitMenu` clears it
   beside `g_bg_whiteout`. Every other scenario stays byte-identical because the flag
   is off for them.
2. **`update_oam` gates the DMA too**, so the menu publishes its own OAM:
   `CommitMonPartySpriteOAM` (shadow OAM → `$FE00`, fills `spr_dos_sx/sy` through the
   panel-anchor projection set by `SetMonPartySpriteOrigin`, sets `spr_oam_valid`).
   It is called from `WriteMonPartySpriteOAM`'s tail and from `GetAnimationSpeed`
   right before its `jp DelayFrame` — i.e. exactly where the GB's VBlank DMA runs.
3. **`RestoreScreenTilesAndReloadTilePatterns` had to stop stubbing
   `ReloadMapSpriteTilePatterns`** (`home/fade.asm`) — the icons live in vSprites now,
   which is precisely the map-sprite tile area that call exists to restore.

Verification: pixelcheck 9/9 (8 byte-identical, only `party_menu` differs — icons are
OBJ now); `make fidelity` 6/6 PASS with the **party_menu tilemap + all-40-OAM +
whole-vChars0 icon masks retired** — OAM now diffs entry-for-entry against the mGBA
golden and matches, as does every vChars0 slot the icon loader writes. The one
surviving vChars0 mask (`ICON_GAP_SLOTS`, 48 slots) is the set the loader *never*
writes (unused ICON ids `$0B-$0D`, and each 2-pattern icon's +1/+3 gap — the
symmetric writer only ever displays base and base+2); the golden holds zeros there,
the port holds leftover overworld map-sprite tiles, and no OAM entry references them.
faithdiff: the new divergences are `CommitMonPartySpriteOAM` (the DMA analog),
`AddNTimes`/`FarCopyData`/`IndexToPokedex`-predef dropping out to flat pointer math
and the port's flat `IndexToPokedex` table, and `LoadMonPartySpriteGfxWithLCDDisabled`
calling the shared `LoadAnimSpriteGfx` instead of re-inlining pret's copy of the loop.
`lint_pret_labels` 0.

Perf (`party_menu`): WORK **8.419 ms** vs the 7.392 ms baseline (51.5% of the 16.348 ms
budget) — `render_sprites` 0.176 → 1.202 ms for the 24 new OBJ. The plan predicted a
net *win* from losing the per-bob `tile_cache` rebuild; that rebuild doesn't show in
this harness (it dumps one static frame and never bobs), so the measured delta is the
sprite cost alone. Comfortably inside budget; flagged, not chased.

**Stages 4 + 5 + 6 (done).** Naming screen: it already called `LoadMonPartySpriteGfx`
(which now resolves to the real one), and its three remaining DEVIATION(icons) sites are
now pret's code — `wMonPartySpriteSpecies` + `WriteMonPartySpriteOAMBySpecies` for the
named mon's icon, `AnimatePartyMon_ForceSpeed1` in `.inputLoop` (it ends in DelayFrame,
so it IS that loop's frame pacing — the port's own `DelayFrame` there is gone), and both
`wAnimCounter` resets. It sets its own OAM origin (`UI_NAMING_SCREEN_WX - 7`, `_WY`).

`g_obj_over_window` is now **cleared by `ClearSprites`/`HideSprites`** as well, next to
`spr_oam_valid` — the same "enforce it at the primitive" move as Stage 0's contract: the
z-order override dies with the OAM that needed it, so no exit path can strand the
overworld with OBJ over its dialog box. The explicit clear in `.exitMenu` stays.

Stage 5 landed with Stage 2 (generator emits pret's raw blobs + `MonPartyData`; the
`.inc` is now rule-driven from `make assets` — it never was). Stage 6: `PM_ICON_TILE_*`,
the two `%error` asserts and `PartyMenuAnimCB` are gone; `ANIM_FLOWER_TILE_ID` /
`ANIM_WATER_TILE_ID` stay in `gb_memmap.inc` (no live claimant now, but they still bind
any other screen that parks graphics in vTileset — noted in their comment); the
DEVIATION(icons) notes in `party_menu.asm` / `start_sub_menus.asm .exitMenu` /
`naming_screen.asm` now describe the real path.

Verification after Stage 4: pixelcheck 9/9 unchanged from the Stage-3 baseline,
`make fidelity` 6/6 PASS, `lint_pret_labels` 0. faithdiff `DisplayNamingScreen`: the only
new ADDED call is the port's `SetMonPartySpriteOrigin`; everything else is pre-existing
(window-model mirror/show, the HUD-tiles tail jump).

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
