# current_plan_data_path_mirror — mirror pret `data/` paths, retire the `aux_misplaced` exception

**Owner:** one Opus agent, end to end, in `worktree-A`.
**Parallelism:** runs concurrently with `current_plan_script_transpiler`.
**Must NOT run concurrently with** `current_plan_memmap_pret_names` — that
workstream rewrites symbol references inside the very files this one splits, and
git sees a split as delete+add so those edits do not follow into the new files.

---

## Why

`dos_port/tools/lint_pret_labels:374-410` treats pret source dirs asymmetrically:

- `audio/` — the port mirrors pret's path **exactly** (measured 22/22 conformant)
- `data/` — only requires the label live *somewhere* under `dos_port/src/data/`,
  on the stated grounds that "the port groups by SUBSYSTEM … so a path mirror
  would be wrong"
- `gfx/`, `ram/` — exempt (generated assets / WRAM addresses owned by
  `gb_memmap.inc`)

That middle case is the exception to retire. Collapsing it gives the tree **one
placement rule**: a pret label lives at `dos_port/src/<pret path>`, or in a
generated `assets/*.inc`. `home/`+`engine/` (the `mirror` rule) and `audio/`
already work that way.

## Scope (measured 2026-08-16 from `translation.db`)

1,159 pret `data/` labels are defined in the port:

| where | count | action |
|---|---|---|
| generated `assets/*.inc` | 1,095 | exempt — do not move |
| hand-written `src/data/` | 64 | 20 already conformant, **44 must move** |
| elsewhere (violations) | 0 | — |

Representative moves:

```
src/data/card_key_data.asm   → src/data/events/card_key_coords.asm
src/data/battle_data.asm     → src/data/battle/special_effects.asm
src/data/tileset_data.asm    → src/data/tilesets/pair_collision_tile_ids.asm
src/data/audio_data.asm      → src/data/pokemon/cries.asm
```

## Stages

- [x] Enumerate all 44 moves from `translation.db` into a checked-in mapping list
      (source label → current file → mirrored destination) — see **Appendix A** below
- [x] Capture the `pkmn.sym` baseline: `make -C dos_port && cp dos_port/pkmn.sym /tmp/sym.A.before`
      (captured; a second `make` reproduced it byte-identically, so the baseline is
      deterministic and not a one-off)
- [x] `dos_port/tools/fidelity_gate --move-baseline <dir> <files...>` **before** any edit
      — 14 files, **44 pret labels** (0 modeled, 44 aux), **518 code lines**, at
      `c1ea70331`
- [x] Split the six generated `.inc` files that span more than one pret data file
      (see **Appendix B** — not anticipated by the original stage list)
- [x] Perform the splits, one destination group at a time
- [x] Makefile: replace each old path with the N new paths in its owning `_SRCS`
      variable, keeping them **adjacent and in order** (list order is link order)
- [x] Makefile: re-point every explicit per-object asset prerequisite naming an
      old `.o` (the hand-written lines in the `2903-3599` block)
- [x] Add `global`/`extern` for labels now crossing a file boundary — plus the 24
      `stale_provider` extern comments the split invalidated tree-wide
- [x] Delete orphaned `.o` files by hand (they drop out of `ALL_OBJS`, so
      `make clean` will not remove them)
- [x] `dos_port/tools/fidelity_gate --move-verify <dir> --to <each new file> --gates auto`
      — label set unchanged (44), 498 lines moved verbatim, residual +83 **all
      declarations**, decomposition == measurement. One unattributed row remains:
      `WildDataPointersEnd` (see Appendix C)
- [x] `diff /tmp/sym.A.before dos_port/pkmn.sym` — see Appendix C. 0 symbols added
      or removed, 0 kind flips, **0 `.text` symbols moved**; 3748 `.data`/`.bss`
      VMAs shifted by object-boundary padding
- [x] Manual contiguity review against pret's file boundaries (see Traps)
- [x] **Commit 1** — the moves alone (still passes the current weak rule)
- [x] Tighten `aux_misplaced` in `lint_pret_labels` to require exact path mirroring
      for `data/`, and delete the "a path mirror would be wrong" exemption comment
      — the `audio`/`data` branches collapse into one. Proven NON-VACUOUS: with
      `moves.asm` put back at a non-mirrored path (file **and** its `_SRCS` entry,
      which is what makes the scanner see it) the rule fires with exactly that
      finding; restored, it is 0 again
- [x] **Commit 2** — the rule change, plus the two SKILLs that stated the retired
      form of it (`faithfulness-review`, `project-conventions`)
- [x] `make -C dos_port static_gate` green at the `{}` baseline
- [x] Archive: `git mv docs/current_plan_data_path_mirror.md docs/plans/data_path_mirror.md`

## Traps

**This is file-SPLITTING, not renaming.** `src/data/battle_anims.asm` alone
scatters to five destinations (`moves/animations.asm`,
`battle_anims/base_coords.asm`, `battle_anims/frame_blocks.asm`, `moves/sfx.asm`,
`battle_anims/subanimations.asm`). ~15 files become ~30. `_SRCS` list order **is**
link order (`LINK_OBJS` feeds `ld` in order, `dos_port/Makefile:3699`), so keep new
entries adjacent and ordered or the layout shifts.

**Every destination needs its own `--to`.** `fidelity_gate:322-336`
(`rename_targets`) only auto-discovers git's single best rename match; one file
becoming several yields at most one `R` status. Omitting a destination fails
loudly — the 2026-07-28 "0 moved, 69 dropped" mode — which is the desired
behaviour, not a problem.

**`move-verify`'s blind spot needs human cover.** The move classification is
LINE-level, not block-level (`fidelity_gate:77-81`): it cannot prove the moved
lines are contiguous, in the same order, or in the file you intended. Check
`[4/5]` prints a port_file change *dim, not red*, so a routine landing in the
**wrong new file still PASSES**. The `pkmn.sym` VMA check above is the mechanical
half of the cover; read the splits against pret's own file boundaries for the rest.

**Rule-change ordering is load-bearing.** `static_gate`'s baseline is `{}` — every
class at zero — and the ratchet is **bidirectional**, so an unexplained *shrink*
also fails. Move first (findings stay 0 under the weak rule), then tighten
(findings stay 0 under the strict rule). Tightening first creates 44 findings and
fails the pre-commit hook.

**Symbol-table bloat is expected and harmless.** Each `.o` re-embeds the full
`equ` set (a 3 KB source yields a ~53 KB object with ~1500 absolute symbols), so
~15 files becoming ~30 grows `PKMN.EXE`'s symbol table. `gen_symfile.py` already
filters absolutes out of `pkmn.sym`, so the VMA check is unaffected.

## Evidence

- Rule and its exemption comment: `dos_port/tools/lint_pret_labels:374-410`
- Move battery: `dos_port/tools/fidelity_gate:426` (`move_baseline`), `:524`
  (`move_verify`), blind spot documented at `:77-81`, `--to` rationale at `:822-826`
- Makefile pattern rule `:3790-3791`, `_SRCS` block `:455-2607`, link order `:3699`
- Counts from `dos_port/tools/translation.db` (`aux_labels` ⋈ `port_defs`), 2026-08-16

---

## Appendix A — the 44 moves (measured from `translation.db`, 2026-08-16)

14 source files → 40 destination files. `[gen]` marks a label whose bytes come from
a generated `assets/*.inc` (the carrier `.asm` holds its `global` and `%include`);
`[hand]` marks rows written literally in the `.asm`, which move verbatim.

| # | label(s) | current file | mirrored destination (`dos_port/src/…`) |
|---|---|---|---|
| 1 | CryData `[gen]` | `data/audio_data.asm` | `data/pokemon/cries.asm` |
| 2 | SpecialEffectPointers `[hand]` | `data/battle_anim_dispatch.asm` | `data/battle_anims/special_effect_pointers.asm` |
| 3 | AnimationIdSpecialEffects `[hand]` | `data/battle_anim_dispatch.asm` | `data/battle_anims/special_effects.asm` |
| 4 | AttackAnimationPointers `[gen]` | `data/battle_anims.asm` | `data/moves/animations.asm` |
| 5 | SubanimationPointers `[gen]` | `data/battle_anims.asm` | `data/battle_anims/subanimations.asm` |
| 6 | FrameBlockPointers `[gen]` | `data/battle_anims.asm` | `data/battle_anims/frame_blocks.asm` |
| 7 | FrameBlockBaseCoords `[gen]` | `data/battle_anims.asm` | `data/battle_anims/base_coords.asm` |
| 8 | MoveSoundTable `[gen]` | `data/battle_anims.asm` | `data/moves/sfx.asm` |
| 9 | TypeEffects `[gen]` | `data/battle_data.asm` | `data/types/type_matchups.asm` |
| 10 | MoveNames `[gen]` | `data/battle_data.asm` | `data/moves/names.asm` |
| 11 | ResidualEffects1 `[gen]` | `data/battle_data.asm` | `data/battle/residual_effects_1.asm` |
| 12 | ResidualEffects2 `[gen]` | `data/battle_data.asm` | `data/battle/residual_effects_2.asm` |
| 13 | SpecialEffects, SpecialEffectsCont `[gen]` | `data/battle_data.asm` | `data/battle/special_effects.asm` |
| 14 | AlwaysHappenSideEffects `[gen]` | `data/battle_data.asm` | `data/battle/always_happen_effects.asm` |
| 15 | SetDamageEffects `[gen]` | `data/battle_data.asm` | `data/battle/set_damage_effects.asm` |
| 16 | HighCriticalMoves `[hand]` | `data/battle_data.asm` | `data/battle/critical_hit_moves.asm` |
| 17 | StatModifierRatios `[hand]` | `data/battle_data.asm` | `data/battle/stat_modifiers.asm` |
| 18 | StatModTextStrings `[gen]` | `data/battle_data.asm` | `data/battle/stat_mod_names.asm` |
| 19 | CardKeyTable1/2/3 `[gen]` | `data/card_key_data.asm` | `data/events/card_key_coords.asm` |
| 20 | FieldMoveDisplayData `[gen]` | `data/field_moves.asm` | `data/moves/field_moves.asm` |
| 21 | FieldMoveNames `[gen]` | `data/field_moves.asm` | `data/moves/field_move_names.asm` |
| 22 | ItemNames `[gen]` | `data/item_data.asm` | `data/items/names.asm` |
| 23 | ItemPrices `[gen]` | `data/item_data.asm` | `data/items/prices.asm` |
| 24 | KeyItemFlags `[gen]` | `data/item_data.asm` | `data/items/key_items.asm` |
| 25 | TechnicalMachinePrices `[gen]` | `data/item_data.asm` | `data/items/tm_prices.asm` |
| 26 | TechnicalMachines `[gen]` | `data/item_data.asm` | `data/moves/tmhm_moves.asm` |
| 27 | MapSongBanks `[gen]` | `data/maps/map_songs.asm` | `data/maps/songs.asm` |
| 28 | MoveEffectPointerTable `[hand]` | `data/move_effect_pointers.asm` | `data/moves/effects_pointers.asm` |
| 29 | BaseStats `[gen]` | `data/pokemon_data.asm` | `data/pokemon/base_stats.asm` |
| 30 | GrowthRateTable `[gen]` | `data/pokemon_data.asm` | `data/growth_rates.asm` |
| 31 | Moves `[gen]` | `data/pokemon_data.asm` | `data/moves/moves.asm` |
| 32 | EvosMovesPointerTable `[gen]` | `data/pokemon_data.asm` | `data/pokemon/evos_moves.asm` |
| 33 | MonsterNames `[gen]` | `data/pokemon_data.asm` | `data/pokemon/names.asm` |
| 34 | TextPredefs `[hand]` | `data/predef_text_data.asm` | `data/text_predef_pointers.asm` |
| 35 | TilePairCollisionsLand/Water `[gen]` | `data/tileset_data.asm` | `data/tilesets/pair_collision_tile_ids.asm` |
| 36 | LedgeTiles `[gen]` | `data/tileset_data.asm` | `data/tilesets/ledge_tiles.asm` |
| 37 | BikeRidingTilesets `[gen]` | `data/tileset_data.asm` | `data/tilesets/bike_riding_tilesets.asm` |
| 38 | TrainerClassMoveChoiceModifications `[hand]` | `data/trainer_data.asm` | `data/trainers/move_choices.asm` |
| 39 | WildDataPointers `[gen]` | `data/wild_data.asm` | `data/wild/grass_water.asm` |
| 40 | WildMonEncounterSlotChances `[gen]` | `data/wild_data.asm` | `data/wild/probabilities.asm` |

Four source files SURVIVE the split, holding content with no pret `data/` label of
its own: `audio_data.asm` (AudioRom), `item_data.asm` (marts, VitaminStats,
UsableItems_*), `trainer_data.asm` (trainer parties + names) and
`predef_text_data.asm`'s generated streams. The other ten are deleted.

## Appendix B — the generated-`.inc` split this required

**The original stage list assumed each old `.o` maps to one new `.o`. Six generated
`.inc` files span MORE THAN ONE pret data file**, and a destination `.asm` must
physically contain its labels (NASM rejects `global` on a symbol the translation
unit does not define), so the generators had to emit one `.inc` per pret data file:

| generator | was | now emits |
|---|---|---|
| `gen_battle_anim_data.py` | `battle_anim_data.inc` | `moves_animations.inc`, `subanimations.inc`, `frame_blocks.inc`, `base_coords.inc`, `move_sfx.inc` |
| `gen_effect_categories.py` | `effect_categories.inc` | `residual_effects_1.inc`, `residual_effects_2.inc`, `special_effects.inc`, `always_happen_effects.inc`, `set_damage_effects.inc` |
| `gen_items.py` | `items.inc` | + `item_names.inc`, `item_prices.inc`, `key_item_flags.inc`, `tm_prices.inc`, `tmhm_moves.inc` (`items.inc` keeps marts / VitaminStats / UsableItems_*) |
| `gen_static_tables.py` | `tileset_tables.inc` | `pair_collision_tile_ids.inc`, `ledge_tiles.inc`, `bike_riding_tilesets.inc` |
| `gen_field_moves.py` | `field_moves.inc` | `field_moves.inc` + `field_move_names.inc` |
| `gen_wild_encounters.py` | `wild_data.inc` | `wild_grass_water.inc`, `wild_probabilities.inc` |

Consequence for the `pkmn.sym` check: a blob that used to be one object's
contribution to `.data` is now several, and each object's section carries its own
alignment, so **some VMA movement from new object-boundary padding is expected**
where the plan predicted zero. The check is still run and every moved VMA must be
accounted for by padding at a new object boundary — nothing may change ORDER, and
no symbol may appear or disappear.

## Appendix C — what the verification actually measured

**`pkmn.sym`, before vs after.** 14,154 symbols on both sides: **0 added, 0
removed, 0 kind changes**. No `t`→`T` flip appeared because every moved label was
already `global` in its old carrier — the plan's expectation of some was wrong in
the safe direction. **No `.text` symbol moved at all**, so code layout is
byte-identical; 3,748 `.data`/`.bss` symbols shifted. Decomposition:

- `.bss` moved uniformly by **+512** (all 234 of them, one delta) — `.bss` follows
  `.data`, which grew by exactly that much in alignment padding at the ~25 new
  object boundaries.
- Address-ordered symbol sequence differs in **16 hunks, all accounted for**:
  six are `*_end` markers (`BaseStats_end`, `Moves_end`, `ItemNames_end`,
  `ItemPrices_end`, `MoveNames_end`, `TrainerNames_end`) that used to share an
  address with the next table's start label and now sort differently once padding
  separates them — their position relative to their own table is unchanged; one is
  `WildMonEncounterSlotChances` and one is the `TechnicalMachinePrices` /
  `TechnicalMachines` / `VitaminStats` group, both deliberate re-orderings of
  label-addressed tables (below).

**Generated `.inc` content, before vs after the generator split.** Every data line
is preserved: for all six split files the code-line **multiset is identical**, and
four of six are identical as an ordered **sequence** too. The two that reorder are
`items.inc` (the mart/VitaminStats/UsableItems remainder now precedes the TM
tables) and `wild_data.inc` (`WildMonEncounterSlotChances` now follows the per-map
blobs instead of preceding them). Per-label body comparison shows **zero**
differing table bodies; the only two flagged blocks differ by the position of a
`global VitaminStats` declaration line, not by data. Both re-ordered tables are
reached only by label, and neither is read past its own terminator.

**The one move-verify row that does not attribute.** `WildDataPointersEnd` reports
`port_only -> port_only [UNEXPLAINED — not in this unit]`. It is a **port-only**
end marker with no pret counterpart, so it is not in the unit's pret-label set,
but it is defined in the same generated `.inc` as `WildDataPointers` and moved with
it (`assets/wild_data.inc` → `assets/wild_grass_water.inc`). The tool cannot
attribute a port-only label; this is that limitation, not a stray edit.

---

## Outcome (2026-08-16)

COMPLETE, in two commits on `data-path-mirror`:

- `7e4e5db5e` — the 44 moves, 14 source files to 40 destinations.
- `b681541a1` — the `aux_misplaced` tightening + the two SKILLs that stated the
  retired rule.

Gates: `lint_pret_labels` and `--strict-claims` 0 each; `static_gate` PASS at the
`{}` baseline (hook-run on both commits); `make -C dos_port` EXIT=0;
`make fidelity-full` **reported=85/85, nonzero=0**, all 85 scenarios exited 0 in
348 s.

Two things the plan got wrong, both recorded above rather than quietly fixed:

1. **"~15 files become ~30" understated the generated half.** Six generated
   `.inc` files each spanned more than one pret data file, so the generators had
   to be split too (Appendix B). The plan's stage list had no box for it.
2. **"Expect ZERO VMA changes" was not achievable and did not need to be.** No
   `t`→`T` flip appeared either, because every moved label was already `global`.
   What the check actually proves is stronger and is in Appendix C: 0 symbols
   added or removed, 0 kind changes, **0 `.text` symbols moved**, and every one of
   the 16 address-order hunks accounted for.

Note for whoever maintains `CLAUDE.md`: its "core 16 scenarios / full 66
scenarios 378 s" figures are stale — the registry is **85** and the full tier ran
in **348 s** here. Not changed by this workstream; `CLAUDE.md` is out of its scope.
