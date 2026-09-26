# Current Plan: Linking the Map Scripts

Getting pret's 251 map scripts from "transpiled and assembling" to "linked into the
game". Seeded 2026-08-19 (commits `c3709ae13`, `b5b4efbae`).

## State

**225 of 225 linked** (measured 2026-08-26; was 224 on 2026-08-23, 221 on 2026-08-20, 220 on 2026-08-19, 207 at seeding, 352 + 1 before
that). All 225 translated script files are linked into `SCRIPT_SRCS` in `dos_port/Makefile`, with 0 check-only sources remaining. Count it, do not quote it:

```
python3 - <<'EOF'
import re, collections
from pathlib import Path
cur=None; c={}
for l in Path('dos_port/Makefile').read_text().splitlines():
    m=re.match(r'^([A-Za-z_][A-Za-z0-9_]*)\s*\+?:?=', l)
    if m: cur=m.group(1)
    # [A-Za-z0-9_]+, not [a-z0-9_]+ — the script files were renamed to pret's
    # exact PascalCase on 2026-08-20, and the old class silently matched nothing.
    for s in re.findall(r'src/scripts/([A-Za-z0-9_]+)\.asm', l): c[s]=cur
print(collections.Counter(c.values()))
EOF
```

### Groups A and B are CLOSED (vermilion_dock landed 2026-08-20)

The plan's A/B/C split held, but linking all the candidates at once and reading
the LINK ERRORS found four failure modes where it predicted two. The extra two are
worth knowing because they are cheap and invisible:

* **LABEL-DROP** (five instances: RocketHideoutB4F, MtMoonB2F, SilphCo11F,
  PokemonTower2F, PokemonTower7F DefaultScript/Script0). The body is already
  lowered CORRECTLY and sitting in the file with NO LABEL, because pret guards the
  routine's first lines with `IF DEF(_DEBUG)` and the tool consumed the label with
  the stripped block. No bail banner, no drop note — silently absent. One line each.
* **A MISSING FAR TEXT STREAM** (safari_zone_gate). Not a script defect at all:
  `gen_battle_text`'s `load_memmap()` read only `gb_memmap.inc`, so any stream
  whose `text_ram`/`text_bcd`/`text_decimal` named a symbol living in the generated
  `assets/pret_ram.inc` was SILENTLY SKIPPED WHOLE. Fixing it took the tree from
  1023 to 1032 generated labels.

Two bail messages also LIED by reading instructions in isolation, the same class
the `add-hl-r16` note in `script-fine-comb-fleet-queue` records:
`hl-half-register-access` on daycare's `ld d, h` / `ld e, l` (a register-PAIR copy,
`mov edx, esi`) and on VermilionDock_SyncScrollWithLY (a raster split-scroll whose
H/L use is incidental). **Read the pair, not the instruction.**

### All 225 scripts are linked

| script | status | notes |
|---|---|---|
| ~~`vermilion_dock`~~ | **DONE 2026-08-20.** | See `docs/plans/ss_anne_departure.md` |
| ~~`celadon_mansion_3f`~~ | **DONE 2026-08-23.** | `PrintDiploma` landed with Stage 2 of `plans/printer.md`. |
| ~~`pokemon_fan_club`~~ | **DONE 2026-08-23.** | `PrintFanClubPortrait` landed with Stage 2 of `plans/printer.md`. |
| ~~`summer_beach_house`~~ | **DONE 2026-08-23.** | `PrintSurfingMinigameHighScore` landed with Stage 2 of `plans/printer.md`. |
| ~~`hall_of_fame`~~ | **DONE 2026-08-26.** | `HallOfFamePC` and `SetSpriteFacingDirectionAndDelay` linked. |

The printer tier is fully ported (see `docs/plans/printer.md`, now archived).
`engine/printer/printer.asm` / `printer2.asm` / `serial.asm` carry the translated
engine, and `src/print/` carries the port-only DOS backend; the only labels left
out of the link set are the pret `PrinterDebug*` test body and the
`PrinterSerial_` byte-pump, both replaced by the in-memory
`PrintDev_ConsumePacket` seam and not part of the linked print flow.

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
`mt_moon_b_2f` (4), `bills_house` (1) — re-measured 2026-08-20, 5 banners in 2
files; `bike_shop`, `daycare` and `vermilion_dock` are consumed. Older text:
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

Nothing was wrong with the scripts. They needed:
- the **Game Boy Printer tier** (`PrintDiploma`, `PrintFanClubPortrait`,
  `PrintSurfingMinigameHighScore`,
  `Printer_PrepareSurfingMinigameHighScoreTileMap`) — now ported
  (`docs/plans/printer.md`, archived);
- `HallOfFamePC` (pret `engine/movie/credits.asm`) — now ported.

All five printer-script links above are DONE.

## Stages

- [x] Swap `%include` → `extern` for the two shared assets (108 files, 0 duplicates)
- [x] Link the 202 immediately-linkable scripts
- [x] Make the check-only tier the genuinely-blocked set, not a token file
- [x] Implement `DisplayPokedex`/`_DisplayPokedex`, the fossil trio, and
      `GameCornerDrawCoinBox` rather than stubbing them (+5 scripts linked)
- [x] Group B: re-emit the sibling-dropped labels (and the 5 LABEL-DROPS the plan
      did not know about, and the far-text-stream generator gap)
- [x] Group A: translate the bails — the 4 pikachu-table-index went by the ordinal
      table (42 entries, zero violations, so PikachuCryN is index N-1), daycare's
      5-bail chain and cerulean_trashed_house's predef/`and b` are done
- [x] Get maintainer rulings for the 2 `screen-coord-projection` sites — bike shop
      ruled AS THE POKÉ MART, S.S. Anne ruled FULL SPAN with a timing consequence
      (docs/ui_projection.md)
- [x] `vermilion_dock`: DONE 2026-08-20 — but NOT by porting `ScheduleEastColumnRedraw` +
      `ScheduleColumnRedrawHelper` into `src/home/overworld.asm`, then lower
      `VermilionDockSSAnneLeavesScript` and settle its scroll count visually
- [x] Group C: port the Printer tier and `HallOfFamePC`
      - **`HallOfFamePC` is DONE 2026-08-23** (4d3345837): the whole of
        `engine/movie/credits.asm` is ported (20/20) on the back of
        `engine/movie/hall_of_fame.asm` (17/17, 07828148b), so
        `HallOfFame_Script`'s predef call now runs the ceremony and the roll
        instead of a ret-stub. The stub is deleted from `evolution_stubs.asm`.
        See [[ending-chain-hof-and-credits-ported]].
      - The **Printer tier is DONE 2026-08-23** via `docs/plans/printer.md`
        (translated engine mirrors + `src/print/` backend); the plan is
        archived. The earlier "out of this tree's lane" note is superseded.
- [ ] Re-audit: with scripts linked, a dropped global is now a link error rather
      than silence. Re-run the sibling-drop audit across all 225, not just the
      blocked 18.

## Trainer-sight fidelity: remove the port-only fallback (added 2026-09-26)

### Why

The port carries a port-only trainer-sight fallback — `CheckTrainerSight` +
`TrainerEncounterFlow` (`src/engine/overworld/map_sprites.asm`), called from
`OverworldLoopLessDelay` (`src/home/overworld.asm`) — with no pret counterpart.
It is an M8.1-era stopgap: hardcoded 4-block range, a non-persistent `.bss`
beaten cache (`npc_beaten_flags`), no `EndTrainerBattle`, and no `text_asm` /
trainer-talk dispatch. `cc2a55227` fixed its player-coordinate read, so it began
firing on per-map trainer maps where the faithful path was already live. On
Pewter Gym it printed `PewterGymCooltrainerMText`'s machine code as text
(`.4o… error.`) and left the trainer unflagged, so the battle re-engaged forever.

### Measurement — the fallback serves no trainer map

All 67 pret maps that define `<Map>TrainerHeaders` already run
`CheckFightingMapTrainers`:

| route to `CheckFightingMapTrainers` | count |
|---|---|
| generic `TrainerMapScript` | 17 |
| per-map `_Script`, pointer table generated in `assets/map_script_tables.inc` | 23 |
| per-map `_Script`, inline call | 27 |
| **total** | **67** |

Zero trainer maps dispatch only `DefaultMapScript`. `trainer_map_script.asm`
stays: it is the intentional dedup of pret's copied `_Script` boilerplate (46
maps) and trainer-talk hooks (265), with the per-map operands in generated data.

### Work

- **Audit** the faithful routines: `src/engine/overworld/trainer_sight.asm`
  (`TrainerEngage`, `ReadTrainerScreenPosition`, `TrainerWalkUpToPlayer`,
  `_Get/_SetSpritePosition1/2`, `CheckSpriteCanSeePlayer`,
  `CheckPlayerIsInFrontOfSprite`) and the home labels
  (`CheckForEngagingTrainers`, `CheckFightingMapTrainers`, `TalkToTrainer`,
  `DisplayEnemyTrainerTextAndStartBattle`, `StartTrainerBattle`,
  `EndTrainerBattle`) with `faithdiff` + source compare. Run the `*_sight`
  goldens and `trainer_battle_route`.
- **Delete** the fallback:
  - `src/home/overworld.asm`: the gate + its `DEVIATION` and the two `extern`s;
    the `ISTRAINER` store + DEVIATION in `InitSprites`.
  - `src/engine/overworld/map_sprites.asm`: `CheckTrainerSight` and
    `TrainerEncounterFlow`; `.bss` `npc_beaten_flags`, `w_trainer_enc_slot`,
    `w_player_frozen`, `w_check_npc_slot_tmp`; simplify `CheckNPCInteraction`'s
    `.run_trainer_talk` to call `TrainerTalkHook` unconditionally (pret's shape —
    `TalkToTrainer` already does the persistent flag test).
  - `include/gb_memmap.inc`: remove `SPRITESTATEDATA2_ISTRAINER` (port-only; set
    only in `InitSprites`, read only by the fallback).
  - `src/debug/debug_dump.asm`: migrate `DEBUG_BEATEN_TALK`'s
    `RunBeatenTalkTestSeed` off `npc_beaten_flags` to the real
    `EVENT_BEAT_ROUTE_3_TRAINER_0` flag.
  - `Makefile`: update the sight-gate comment (its "would engage twice" rationale
    is gone).
- **No new golden** (maintainer ruling 2026-09-26). Coverage is the existing
  `*_sight` set, `trainer_battle_route`, `beaten_trainer_talk`, plus
  `fidelity` / `fidelity-full`.
- **Deferred, measurement-only.** pret gates engagement on the trainer being on
  the GB screen (`IMAGEINDEX != 0xff`, computed by `CheckSpriteAvailability` over
  160×144). The port's `CheckSpriteAvailability` uses the wider 320×200 zone
  (`MAPY ∈ [wYCoord-2,+9]`, `MAPX ∈ [wXCoord-6,+13]`, a permanent projection
  deviation), so a trainer the GB would hide can be eligible. First compare
  engage decisions port-vs-golden-ROM across the trainer placements; add a
  `DEVIATION{class=projection}` guard in `TrainerEngage` only if a divergence
  actually manifests.

### Sweep

Delete memory `regression-overworld-checktrainersight-player-coord`; update
`regression-battle-second-trainer-wont-engage`; fix the stale
`docs/current_plan_overworld_realign.md` references (archived to
`docs/plans/overworld_realign.md`); `episode_record` the removal.

## Verification for any change here

`make assets` → `make -j8` → `make static_gate` (must print **8** static checks) →
`make fidelity-full`. A linked script that assembles is not evidence it behaves;
`faithdiff` has no model for `scripts/` labels by design, so `lint_pret_labels`
(`script_labels` / `script_collision` / `script_misplaced`) is the structural check
that applies there.
