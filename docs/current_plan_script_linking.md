# Current Plan: Linking the Map Scripts

Getting pret's 251 map scripts from "transpiled and assembling" to "linked into the
game". Seeded 2026-08-19 (commits `c3709ae13`, `b5b4efbae`).

## State

**207 of 225 linked.** `build: 559 linked + 18 check-only sources` (was 352 + 1).
The check-only tier IS the 18 that cannot link yet — they assemble-validate so a
change that breaks them is still caught, and each graduates as its blocker lands.

## What actually blocked this (worth knowing before touching it again)

Not the undefined symbols everyone assumed. It was **1342 duplicate global
definitions**: `assets/trainer_headers.inc` (1302 symbols, 67 scripts) and
`assets/map_script_tables.inc` (41 scripts) were `%include`d, and both *define*
their symbols — so linking a second script duplicated every one. The single
carriers are `src/data/trainer_headers.asm` and `src/data/map_script_tables.asm`.
Scripts now `extern` only what they reference (608 externs replacing 108 includes).

**If you add a script that needs trainer text or a script-pointer table, `extern`
it. Do not `%include` the asset.**

## The 18 still blocked, by fix shape

Measured 2026-08-19. Three distinct kinds of work — do not treat them as one queue.

### A. 7 files with a real transpiler BAIL — needs translation
`bike_shop` (4), `daycare` (5), `mt_moon_b_2f` (4), `vermilion_dock` (2),
`cerulean_trashed_house` (1), `oaks_lab` (1), `seafoam_islands_b_4f` (1).

19 banners / 8 files tree-wide. By class: 7 `target-region-bailed` (cascade — they
resolve when their root does), 4 `pikachu-table-index`, 2 `screen-coord-projection`,
2 `hl-half-register-access`, 1 each `predef-leaves-parent-bank-in-a`,
`local-label-scope-collision`, `event-macro-reuse-a-hint`,
`owned-by-gen_map_script_tables`.

- **The 4 `pikachu-table-index` bails are no longer a refusal.** `ldpikacry` /
  `ldpikaemotion` need `(X_id - Table) / N` across object files, which NASM cannot
  do. But `PikachuEmotionTable` is strictly ordinal (34 entries, verified), so the
  index is a literal. Solved this way for `PlaySpecificPikachuEmotion` in
  `c3709ae13`; the same move should retire all four.
- **The 2 `screen-coord-projection` bails need maintainer projection rulings**, like
  the mart. Everything else in this class so far has derived from an existing ruling.

### B. 5 files with a SIBLING-DROP — cheaper, different fix
`pokemon_tower_5f` (5), `rocket_hideout_b_4f` (3), `mt_moon_b_2f` (2),
`pokemon_tower_6f` (2), `silph_co_11f` (2).

The transpiler's "owned-by-generated-assets" collapse drops a whole pret *region*
when it contains an owned label, taking non-owned siblings with it. Fix: re-emit
**only** the non-owned labels from that region; never the owned one (it would
collide with `assets/trainer_headers.inc`). Full diagnosis and worked examples:
memory `script-fine-comb-fleet-queue`.

This was predicted by that memory — *"a dropped GLOBAL becomes `extern X ; NOT YET
DEFINED IN THE PORT`, invisible only because src/scripts/ is NOT LINKED; audit when
the scripts get linked"*. Confirmed: 4 of 6 sampled undefined symbols trace to it.

### C. 7 files blocked purely by unported ENGINE routines
`celadon_mansion_3f`, `hall_of_fame`, `pokemon_fan_club`, `pokemon_tower_2f`,
`pokemon_tower_7f`, `safari_zone_gate`, `summer_beach_house`.

Nothing wrong with the scripts. They need:
- the **Game Boy Printer tier** (`PrintDiploma`, `PrintFanClubPortrait`,
  `PrintSurfingMinigameHighScore`,
  `Printer_PrepareSurfingMinigameHighScoreTileMap`) — a real subsystem, not a
  routine;
- `HallOfFamePC` (pret `engine/movie/credits.asm`).

## Stages

- [x] Swap `%include` → `extern` for the two shared assets (108 files, 0 duplicates)
- [x] Link the 202 immediately-linkable scripts
- [x] Make the check-only tier the genuinely-blocked set, not a token file
- [x] Implement `DisplayPokedex`/`_DisplayPokedex`, the fossil trio, and
      `GameCornerDrawCoinBox` rather than stubbing them (+5 scripts linked)
- [ ] Group B: re-emit the sibling-dropped labels in the 5 files
- [ ] Group A: translate the 19 bails — start with the 4 pikachu-table-index, which
      have a proven technique
- [ ] Get maintainer rulings for the 2 `screen-coord-projection` sites
- [ ] Group C: port the Printer tier and `HallOfFamePC`
- [ ] Re-audit: with scripts linked, a dropped global is now a link error rather
      than silence. Re-run the sibling-drop audit across all 225, not just the
      blocked 18.

## Verification for any change here

`make assets` → `make -j8` → `make static_gate` (must print **6** static checks) →
`make fidelity-full`. A linked script that assembles is not evidence it behaves;
`faithdiff` has no model for `scripts/` labels by design, so `lint_pret_labels`
(`script_labels` / `script_collision` / `script_misplaced`) is the structural check
that applies there.
