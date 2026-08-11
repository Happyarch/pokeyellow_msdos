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

  **ROOT-CAUSED for the five battle scenarios — 2026-08-11, measured, not
  inferred.** The missing writer is `SetAnimationPalette`
  (pret `engine/battle/animations.asm:565`, `ld a, $6c / ldh [rOBP1], a`), and
  the port's body of it is already faithful. What is missing is the CALL CHAIN:
  pret's `SendOutMon` (`engine/battle/core.asm:1803`) does
  `ld a, POOF_ANIM / call PlayMoveAnimation` → `MoveAnimation` →
  `SetAnimationPalette`, and the port's `SendOutMon` ends at
  `RunPaletteCommand` with the comment
  `; ANIMATION=OFF: PlayMoveAnimation(POOF_ANIM) / AnimateSendingOutMon / Pikachu.`
  `PlayMoveAnimation` has been translated and live since the battle-animations
  plan landed, so that comment is stale — this is a genuine dropped call, not a
  deferral.

  How it was measured, with the decomposition (aggregates alone would not have
  settled it):
  * Solved each committed golden's `cgb_palettes` region for the DMG register
    that maps OBJ base palettes 0-3 onto slots 4-7 (`_UpdateCGBPal_OBP` with
    `CONVERT_OBP1`). `battle_menu`, `battle_faint`, `battle_damage`,
    `move_selection` and `battle_blackout` all solve to a UNIQUE `rOBP1 = $6C`;
    `battle_intro` solves to `$E4` (its checkpoint precedes the send-out);
    overworld/menu goldens solve to `$E0`, i.e. `LoadGBPal`, as this file
    already recorded.
  * `$6C` appears exactly twice in all of pret `home/` + `engine/`, both inside
    `SetAnimationPalette` (its SGB and non-SGB arms).
  * `goldencheck SCENARIO=battle_menu` (PASS, reporting-only) prints 12
    divergences and they are exactly `OBJ pal4..7 colour1..3`, port
    `(31,31,31)` throughout — the signature of `IO_OBP1 == 0` composed against
    a base palette whose colour 0 is white. `OBJ pal0-3` do NOT diverge, which
    proves `obj_slot_pal[0..3]` is already correct and isolates the fault to
    the register.

  **CORRECTION, same day: restoring `SendOutMon` was NOT the fix.** It landed
  (`faithdiff SendOutMon` 14/14 matched) and moved nothing: `battle_menu` reports
  the same 12 divergences, and a stashed-baseline re-run of `battle_menu` /
  `battle_faint` / `trainer_battle_loss` diffed BYTE-IDENTICAL. Measured cause —
  `label_status --callers SendOutMon` gives ONE port caller, `ChooseNextMon`,
  where pret has three: `StartBattle` (core.asm:259, the initial send-out),
  `ChooseNextMon` (:1163) and `SwitchPlayerMon` (:2541). `StartBattle` is
  `missing`; the port's `_InitBattleCommon` does the battle-entry send-out
  inline. **So the open work is routing battle entry through `SendOutMon`** —
  `docs/current_plan_battle_completion.md` item 1g. Everything below about the
  mechanism stands; only the "which routine to fix" conclusion was wrong.

  **Also corrected:** the blackout/loss bullet below records `trainer_battle_loss`
  as 40 divergences. Measured 2026-08-11 it is **48**, on BOTH sides of the
  `SendOutMon` change — and 48 is exactly the number of non-white entries in its
  committed golden (48 of 64), i.e. the port's palette RAM is entirely white at
  that checkpoint. The 40 was stale before this work started.

  **What restoring `SendOutMon` involved, for the record.**
  `faithdiff SendOutMon` reports `calls: 14 pret / 2 port (1 matched)` — 13
  DROPPED (`PrintSendOutMonMessage`, `DrawEnemyHUDAndHPBar`,
  `DrawPlayerHUDAndHPBar`, `LoadMonBackPic`, `PlayMoveAnimation`,
  `AnimateSendingOutMon`, `IsThisPartyMonStarterPikachu`,
  `StarterPikachuBattleEntranceAnimation`, `IsPlayerPikachuAsleepInParty`,
  `PlayPikachuSoundClip`, `PlayCry`, `PrintEmptyString`,
  `SaveScreenTilesToBuffer1`) and 1 ADDED (the port-only `DrawHUDsAndHPBars`),
  plus dropped `[hStartTileID]` / `[hWhoseTurn]` / `[hAutoBGTransferEnabled]`
  stores. `AnimateSendingOutMon` and `StarterPikachuBattleEntranceAnimation`
  are both `missing` per `label_status`. So this belongs in
  `docs/current_plan_battle_completion.md` as send-out restoration work, not
  in a one-line palette patch — and it should RETIRE, not grow, the battle
  goldens' 128-slot `$80xx` VRAM mask, whose justification string ("the port
  draws from the matching $93xx copies and its $80xx is undisplayed after the
  intro") is a consequence of exactly this dropped chain.

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
