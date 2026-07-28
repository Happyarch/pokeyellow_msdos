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

**Provenance and anonymization.** Downloaded from the internet, so the original
trainer name (a real person's) was replaced with `Player1` before the file was
committed; the original is not in git history. The rename covered every slot
holding it -- `sPlayerName`, all party/current-box/stored-box OT names, and the
six `wEnemyMonOT` entries, which are battle scratch that nonetheless lives inside
the `wMainData` block and so persists into the save (210 slots total) -- after
which the six affected checksums were recomputed. One unrelated stale OT
(`YOSHIRA`, in empty box 8) is left as-is.
