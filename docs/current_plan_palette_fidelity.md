# Palette fidelity — closing the `cgb_palettes` backlog

The golden suite gained its first **colour** region on 2026-08-11:
`cgb_palettes`, 128 bytes of Game Boy palette RAM (8 BG + 8 OBJ palettes, four
BGR555 u16 each), compared against the port's composed equivalent. Design,
mechanisms and traps: stigmergy memory `golden-cgb-palettes-region`.

It is **reporting-only**: `golden_diff.py` prints divergences but does not fail
on them (`PALETTE_GATING = False`). This file is the work needed to flip that to
`True`.

## Why reporting-only rather than masked

The region found a real backlog on its first run. The alternative — masking the
survivors with "justified" entries to force the suite green — is precisely how
this class of defect hid for a week while `fidelity-full` reported 56/56. Four
palette defects shipped through that green suite in seven days (`912d43777`,
`2147f00fb`, `6d965c824`, `1b9c6d6ed`). A mask would have made the instrument
lie on the day it was built.

So the divergences are printed, counted, and listed here instead.

## Fixed alongside the region (2026-08-11)

- [x] **`PAL_DMG_GREEN` retired.** The pre-colour stopgap ramp was still the
  static initialiser for `bg_slot_pal` / `obj_slot_pal`. Since no screen command
  writes slots 4-7, it persisted there for the whole run. Replaced with
  `PAL_BOOT_WHITE`, the CGB power-on state (measured on hardware).
  Memory: `pal-dmg-green-stopgap-retired`.
- [x] **`SetPal_Overworld` and `SetPal_BattleBlack` wrote 8 slots, not 4.**
  pret hands a `PAL_SET` packet to `InitCGBPalettes`, which writes four; BG 4-7
  are never written by any packet. `SetPal_Overworld` additionally writes the
  map palette into **entry 0 only** (`PalPacket_Empty` is `PAL_SET 0,0,0,0`, so
  1-3 stay `PAL_ROUTE`). The port flooded all eight of both tables.
- [x] **`OverworldLoopLessDelay` dropped `LoadGBPal`.** pret calls it every
  overworld frame; it is the only thing that ever gives `rOBP1` a non-zero value
  on that path (`FadePal4 + 2` = `dc 3,2,0,0` = `$E0`). Without it `IO_OBP1`
  stayed at `Init`'s zero, so CGB OBJ palettes 4-7 — the four base palettes
  mapped through OBP1 — all collapsed to white. `faithdiff
  OverworldLoopLessDelay` had been reporting `- DROPPED LoadGBPal` the whole
  time; nothing forced anyone to look, because no gate could feel its absence.

  **It fixed far less than predicted — measured, not assumed.** The forecast was
  ~229 divergences; the actual delta was **16** (539 -> 523 divergences, 44 -> 42
  scenarios), and the `OBJ pal4-7 -> white` class only moved 268 -> 252. Reason:
  `LoadGBPal` is called from `OverworldLoopLessDelay`, so it runs on OVERWORLD
  screens only, and most failing scenarios park in a menu, an item flow or a
  battle and never reach that loop. The call was genuinely dropped and restoring
  it is correct on faithfulness grounds, but it is not the fix for this family.

## Open families

Counts from the 2026-08-11 run after the three fixes above: **523 divergences
across 42 scenarios**.

- [ ] **`OBJ pal4-7` collapse to white — 252 of 523, the largest family.**
  Signature: `OBJ pal4-7 colour2/3: rom=(real colour) port=(31,31,31)`. OBJ
  palettes 4-7 are the four base palettes mapped through `rOBP1`, so the port's
  `IO_OBP1` is 0 where hardware holds a non-zero value. `LoadGBPal` supplies
  `$E0` on the overworld and that path is now fixed, but every menu / item /
  battle checkpoint still shows it, so there is at least one more writer the port
  is missing. pret's `rOBP1` writers: `home/init.asm` (zero),
  `home/palettes.asm:GBPalWhiteOut` (zero), `home/fade.asm` x3 (`LoadGBPal`,
  `GBFadeIncCommon`, `GBFadeDecCommon`), plus battle/minigame sites. Start by
  finding which of those runs before each failing checkpoint on hardware.
- [ ] **Status / item screens.** `BG pal0 colour1: rom=(31,31,0)
  port=(16,31,4)` — the port has `PAL_ROUTE` where hardware has a mon-derived
  palette. `SetPal_StatusScreen` builds its packet live from `wCurPartySpecies`
  via `DeterminePaletteID` (pret `engine/gfx/palettes.asm`); check the port's
  equivalent actually runs and picks the same id. Scenarios: `status_p1`,
  `status_p2`, `item_potion_use`, `item_tm_teach`, `item_stone_evolve`.
- [ ] **Battle.** ~12 divergences per battle scenario, not yet characterised.
  Start with `SetPal_Battle`'s four live slots (player/enemy HP colour, player/
  enemy pic palette) and `battle_tile_pal`. Scenarios: `battle_intro`,
  `battle_menu`, `move_selection`, `ball_catch`, `battle_faint`.
- [ ] **Re-measure the remainder** after each family closes; the counts in this
  file are from the 2026-08-11 runs and will drift.
- [ ] **Flip `PALETTE_GATING = True`** in `tools/golden_diff.py` once the count
  reaches zero, and delete this file per the active-plan convention.

## Rules for this work

- **Do not mask a family to make the suite green.** If a divergence is a genuine
  permanent port deviation, it needs a mask *with* a written justification per
  the existing policy — but the default assumption is that the PORT is wrong.
  That assumption has been right every time so far: the first instinct on seeing
  BG 4-7 flagged was to mask it, and the correct answer was that a retired
  stopgap was still live.
- **`faithdiff` already knows.** `OverworldLoopLessDelay` lists 15 other dropped
  calls besides `LoadGBPal`. Read the faithdiff output for a routine before
  assuming its palette behaviour is faithful.
- **Validate with a headless scenario run, not a build.** `debug_dump.asm`'s
  region table is behind a DEBUG gate, so a plain `make` exercises none of it.
