# Golden test fixtures

## `yellow_100.sav`

A real Pokemon Yellow battery save (raw 32768-byte `.sav`, MBC5 bank order), used
as golden seed data for the save/load path. It is the same byte layout as the
`.dsv` v2 payload, so `tools/saveconv.py --to-dos` converts it to a
`POKEMON.DSV` the port loads at boot.

**Measured contents** (not estimated -- re-measure rather than quoting this if it
matters):

| | |
|---|---|
| Pokedex | 151 owned, 151 seen |
| Party | 6 mons |
| Current box (`sCurBoxData`, bank 1) | 19 mons |
| Stored boxes (banks 2-3) | **box 10 holds 1 mon; the other 11 are empty** |
| Checksums | all 15 valid (main data, both all-box, all 12 per-box) |

*** The stored boxes are essentially empty. *** This fixture is strong coverage
for the main-data / party / Pokedex / current-box tier and it exercises the
bank-2/3 **checksum** paths, but it does **not** populate the box banks. Do not
cite it as box-tier coverage, and do not let it retire the synthetic
deposit/withdraw/change-box scenario that
`docs/current_plan_sram_pc_storage.md` stage 6 still requires.

Used by the `save_real_load` golden scenario.

## `yellow_boxes_full.sav`

`yellow_100.sav` with **all 12 PC boxes filled to 20 mons** (240 total), built by
`dos_port/tools/savegen` (PKHeX.Core). Party, Pokedex, name and TID are carried
through unchanged; only the boxes differ. Deterministic — re-running the
generator reproduces it byte for byte.

Used by the `save_boxes_load` golden scenario, which is the first thing in the
suite to compare any box bytes at all (the scenario-local `wBoxData` region).

*** It still does not exercise SRAM banks 2 and 3. *** A CONTINUE load copies
`sCurBoxData`, which lives in bank 1, into WRAM and never reads `sBoxN`.
Reaching the stored boxes needs `ChangeBox`, which needs the PC UI — so the
stored-box half of `docs/current_plan_sram_pc_storage.md` stage 6 is still open.
What this fixture closes is the box **data layout**: the 33-byte `box_struct`
stride, the species list and its `$FF` sentinel, and the 20 OT names and 20
nicknames.

Verified accepted by the real ROM (mGBA, CONTINUE): `wBoxCount` = 20, party 6.

## Provenance and anonymization

Applies to both files, since the second is derived from the first. Downloaded from the internet, so the original
trainer name (a real person's) was replaced with `Player1` before the file was
committed; the original is not in git history. The rename covered every slot
holding it -- `sPlayerName`, all party/current-box/stored-box OT names, and the
six `wEnemyMonOT` entries, which are battle scratch that nonetheless lives inside
the `wMainData` block and so persists into the save (210 slots total) -- after
which the six affected checksums were recomputed. One unrelated stale OT
(`YOSHIRA`) survives in `yellow_100.sav`'s empty box 8; it is gone from
`yellow_boxes_full.sav`, whose boxes are all overwritten.
