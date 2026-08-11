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
- [ ] **Live mon / HP-bar palettes — status and item screens.** Measured:
  `status_p1` is exactly 6 divergences, `BG pal0/1` and `OBJ pal0/1`, e.g.
  `BG pal0 colour1: rom=(31,31,0) port=(16,31,4)` and `colour2: rom=(0,31,0)
  port=(11,23,31)`. The rom values are HP-bar / mon palettes (green, yellow,
  brown); the port has `PAL_ROUTE` throughout, i.e. it never installs the live
  per-species and per-HP-colour slots. `SetPal_StatusScreen` builds its packet live from `wCurPartySpecies`
  via `DeterminePaletteID` (pret `engine/gfx/palettes.asm`); check the port's
  equivalent actually runs and picks the same id. Scenarios: `status_p1`,
  `status_p2`, `item_potion_use`, `item_tm_teach`, `item_stone_evolve`.
- [ ] **Blackout / loss path — whole palettes white where hardware is
  `PAL_BLACK`.** Characterised 2026-08-11: `trainer_battle_loss` is 40
  divergences, and **32 of them are all four colours of BG 0-3 and OBJ 0-3**,
  `rom=(3,3,3)` against `port=(31,31,31)`. Hardware is blacked out at that
  checkpoint and the port is not, i.e. `SetPal_BattleBlack`'s effect is absent or
  overwritten. (The port reads white because the slots still hold
  `PAL_BOOT_WHITE`; before that stopgap retirement the same divergence showed as
  green, so this is pre-existing, not caused by it.) `trainer_battle_init` (36)
  and `trainer_battle_win` (28) share the shape.

**"Battle" is NOT a family of its own.** Measured: `battle_intro`,
`battle_menu`, `move_selection`, `ball_catch` and `battle_damage` are 12
divergences each and **every one is the `OBJ pal4-7 -> white` family above** —
colours 1-3 of the four OBP1-derived palettes, with colour 0 matching because it
is white on both sides. Do not open a separate battle investigation for those
five; they close when `IO_OBP1` closes. Only the blackout/loss shape is
battle-specific.
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
