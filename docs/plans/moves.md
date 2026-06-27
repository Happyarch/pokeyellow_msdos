# Current Plan: Move Data Layer

Make each move's **static data** queryable so battle/menu code can, for any move id,
get its name, type, power, accuracy, PP, physical-vs-special category, and field-move
status. Sequenced alongside the battle engine; most of the damage pipeline already
exists (see below), so this plan is narrow and targeted.

## What already exists (reuse, do NOT rebuild)
- `assets/moves.inc` + `tools/gen_moves.py` — 165 × 6-byte records (anim, effect,
  power, type, acc, PP), 1-based move-id order. `Moves` global; `MOVE_*` offsets in
  `include/gb_constants.inc`.
- `GetCurrentMove` (`src/engine/battle/get_current_move.asm`) — loads the 6-byte
  record into `wPlayerMove*`/`wEnemyMove*`, sets `wNameListIndex`.
- **Physical/Special split is already faithful**: `core_damage.asm`
  (`GetDamageVarsForPlayer/EnemyAttack`) does `cmp al, SPECIAL` / `jae` inline,
  selecting Attack/Defense vs Special — as pret `engine/battle/core.asm`.
  `SPECIAL equ 0x14` + type ids already present. Damage Stages 2–4
  (`CalculateDamage`, STAB, `AdjustDamageForMoveType`, `TypeEffects`) are landed.

## Architecture (faithfulness)
The original is data-driven with shared functions: one `CalculateDamage` for all
damaging moves; a single `MoveEffectPointerTable` (`jp hl`) keyed by the effect byte
(shared handlers); category = one `cp SPECIAL`; field-move detection = linear table
scan. We replicate that structure.

## Decisions locked
- **Move/item names: variable-length `@`-terminated**, faithful walk via a shared
  `GetName` + `NamePointers` dispatcher.
- **Monster names: KEEP fixed-width** — pret `GetMonName` is fixed-width by design
  (`AddNTimes`, `NAME_LENGTH-1`); the port already matches. No conversion.
- **Name-walk glitch preserved**: destination copy is bounded
  (`CopyData(NAME_BUFFER_LENGTH=20)` → 20-byte `wNameBuffer`) → no overflow/ACE.
  Out-of-range ids only walk the source → garbage names (`GLITCH`). Index-validation
  placeholder only under `BUG_FIX_LEVEL >= 2` (FIXALL). Tag the `names2.asm:22` `BUG`
  (`cp HM01` applies to all name types; range-guarded) faithfully.
- **Effect-category arrays + anim stub included** (data/stub only, no behavior).
- **Field moves: full faithful rewire** of `party_menu.asm`.

## Stages

- [x] **Stage 1 — Constants + WRAM aliases.** `gb_constants.inc`: `NUM_ATTACKS=165`,
  `MOVE_NAME_LENGTH=14`, `NAME_BUFFER_LENGTH=20`, name-list type ids (`MONSTER_NAME=1`…
  `TRAINER_NAME=7` from `constants/list_constants.asm`); lift field-move ids
  (`CUT/FLY/SURF/STRENGTH/FLASH/DIG/TELEPORT/SOFTBOILED`) out of `party_menu.asm`;
  drop the duplicate `MOVE_LENGTH`. `gb_memmap.inc`: confirm/add `wNameBuffer`,
  `wNameListType`, `wNameListIndex`, `wNamedObjectIndex`, `wPredefBank`.

- [x] **Stage 2 — Move-names asset.** `tools/gen_move_names.py` (mirror
  `gen_monster_names.py`: `load_charmap`/`encode`) reading `data/moves/names.asm` →
  `assets/move_names.inc` (`MoveNames`, variable-length `0x50`-terminated, 165). Expose
  `global MoveNames` + `%include` in `src/data/battle_data.asm`; wire Makefile assets +
  `.o` dep. Verify `nasm -f coff`.

- [x] **Stage 3 — Shared `GetName` + `NamePointers` + wrappers (core).**
  Done + native-validated (POUND, STRUGGLE walk, fixed-width mon name, TM02 BUG
  path, FIXALL overflow guard). `src/home/names.asm` in BATTLE_SRCS tier.
  `src/home/names.asm` faithful to `home/names.asm` + `home/names2.asm`.
  `NamePointers` flat `dd` table — **mixed addressing**: Monster/Move/Unused/Item/
  Trainer names flat (`[esi]`); `wPartyMonOT`/`wEnemyMonOT` WRAM (`[ebp+esi]`).
  `GetName`: `MONSTER_NAME` → `GetMonName` (fixed-width); types 2–7 → walk `0x50`,
  bounded `CopyData(NAME_BUFFER_LENGTH)` → `wNameBuffer`. `GetMonName`/`GetMoveName`/
  `GetItemName`/`GetMachineName`. `BUG`/`GLITCH` tags + FIXALL guard. Resolves
  existing externs (`FormatMovesString`, `get_trainer_name`, `evos_moves`). Native
  ELF32 validate.

- [x] **Stage 4 — Category helper.** `src/engine/battle/move_category.asm`:
  `IsTypeSpecial` (AL=type) + `IsMoveSpecial` (AL=move id; reads MOVE_TYPE from
  flat `Moves`). Both return AL=1/CF=1 for special, AL=0/CF=0 physical. In
  BATTLE_SRCS; native-validated (POUND→physical, FIRE PUNCH→special).

- [x] **Stage 5 — Field-move data + predicate (full rewire).** `tools/gen_field_moves.py`
  → `assets/field_moves.inc` (`FieldMoveDisplayData` + `FieldMoveNames` from
  `data/moves/field_moves.asm` / `field_move_names.asm`, move ids resolved from
  `constants/move_constants.asm`). `IsFieldMove` (`src/engine/menus/field_moves.asm`,
  linear scan → CF + flat `FieldMoveNames` ptr) in GAME_SRCS (linked: party_menu calls
  it; battle_data is not yet linked). Rewired `party_menu.asm` off its inline `MV_*`
  table, baked `fm_str_*` strings, and `.field_move_name` cmp-chain → `IsFieldMove` +
  the shared tables. Build links (`SKIP_TITLE=1`); native ELF32 harness green
  (CUT/SOFTBOILED/FLASH → name, POUND → not-found, ANIM_B4 → empty unused slot); encoded
  name bytes byte-identical to the removed baked strings; `DEBUG_PARTYMENU` `FRAME.BIN`
  party-list render unchanged.
  **Deferred: `GetMonFieldMoves`** (the faithful `wFieldMoves[]`/`wNumFieldMoves` array
  fill). The port's party-menu pop-up builds entries directly via `IsFieldMove` and has
  no caller for the array form; it also needs the `wFieldMoves`/`wNumFieldMoves`/
  `wFieldMovesLeftmostXCoord`/`wLastFieldMoveID` WRAM aliases (a `NEXTU` union branch,
  addresses not yet sym-pinned). Add it (with those aliases) when the field-move *use*/
  effect system lands and actually needs the array.

- [x] **Stage 6 — Effect-category arrays (data only).** `tools/gen_effect_categories.py`
  → `assets/effect_categories.inc`: `ResidualEffects1/2`, `SpecialEffects`(+`Cont`
  fallthrough, single terminator), `AlwaysHappenSideEffects`, `SetDamageEffects` from
  `data/battle/*.asm`, `$FF`-terminated, effect ids resolved from
  `constants/move_effect_constants.asm`. Globals exposed via `battle_data.asm`
  (BATTLE_SRCS); Makefile rule + dep + `assets` target wired. No `MoveEffectPointerTable`
  (handler pointers would dangle). `nasm -f coff` clean; values match the pret comments.

- [x] **Stage 7 — `PlayMoveAnimation` decision-tree stub.** `src/engine/battle/animations.asm`:
  `bit BIT_BATTLE_ANIMATION(=7), [wOptions]` → set (animations OFF) → `DelayFrames(30)`;
  else `; TODO-HW:` real animation HAL (ShareMoveAnimations + PlayAnimation + screen
  shake), no-op. Added `BIT_BATTLE_ANIMATION`/`BIT_BATTLE_SHIFT` + `wOptions` alias to
  `gb_memmap.inc`. In BATTLE_SRCS; `nasm -f coff` clean; `make check` + full
  `SKIP_TITLE=1` link green.

## Verification
- `nasm -f coff` each new `.asm`/`.inc`.
- Native ELF32 harness (EXE needs a DPMI host the sandbox lacks): `GetMoveName`
  in-range (POUND=1, STRUGGLE=165), `GetMonName` fixed-width, out-of-range walk →
  bounded garbage (+ FIXALL guard → placeholder), `IsFieldMove`, category helper.
- djgpp partial link (`ld -r`) of the name/field/effect closure → zero unresolved
  externals; confirm `FormatMovesString`/`get_trainer_name`/`evos_moves` resolve.
- Full port build `SKIP_TITLE=1`; party-menu field-move render via `FRAME.BIN`.
- Build `.2bpp` at repo root before `make -C dos_port assets` (assets/ gitignored but
  force-tracked).

## Gen-2 forward-compat
All new tables are read-only static data; no party/box struct bytes touched.

## Handoff — resume at Stage 6 (2026-06-27)

**Stages 0–5 done + validated.** `make check` passes; native ELF32 harnesses green;
full `SKIP_TITLE=1` build links.

**Stage 5 files (committed to the working tree, not yet `git`-committed):**
- `dos_port/tools/gen_field_moves.py` → `dos_port/assets/field_moves.inc`
  (`FieldMoveDisplayData` 9×3-byte `$FF`-terminated + `FieldMoveNames` `@`-terminated).
- `dos_port/src/engine/menus/field_moves.asm` — data include + `IsFieldMove` (GAME_SRCS).
- `dos_port/src/engine/menus/party_menu.asm` — removed `MV_*` equ block, `fm_str_*`
  baked strings, and the `.field_move_name` cmp-chain; `.build_popup` now calls
  `IsFieldMove`. (STATS/SWITCH/CANCEL tail strings kept.)
- `dos_port/Makefile` — `field_moves.inc` rule + `field_moves.o` dep + `assets` target;
  `field_moves.asm` added to GAME_SRCS.

`GetMonFieldMoves` was intentionally deferred — see Stage 5 above for why.

---

(historical) **Stages 0–4 done + validated.** `make check` passes; native ELF32 harnesses green.

**Files created/changed so far (all committed to the working tree, not yet `git`-committed):**
- `dos_port/include/gb_constants.inc` — added `NUM_ATTACKS=165`, `MOVE_NAME_LENGTH=14`,
  `NAME_BUFFER_LENGTH=20`, `BANK_MoveNames=0`, name-type ids (`MONSTER_NAME`..`TRAINER_NAME`),
  field-move ids (`CUT/FLY/SURF/STRENGTH/DIG/TELEPORT/SOFTBOILED/FLASH`); removed the
  duplicate `MOVE_LENGTH`.
- `dos_port/include/gb_memmap.inc` — added `wNameListType/wPredefBank/wNamedObjectIndex/
  wNameBuffer/wUnusedNamePointer` (sym-pinned) and `wEnemyMonOT=0xD9AB`.
- `dos_port/tools/gen_move_names.py` → `dos_port/assets/move_names.inc` (`MoveNames`,
  165 variable-length `@`-terminated). Exposed in `dos_port/src/data/battle_data.asm`.
- `dos_port/src/home/names.asm` — shared `GetName`/`NamePointers`/`GetMonName`/
  `GetMoveName`/`GetItemName`/`GetMachineName` (in BATTLE_SRCS). Has the `BUG`(cp HM01)
  + `GLITCH`(name-walk) tags and the `%if BUG_FIX_LEVEL>=2` FIXALL guard.
- `dos_port/src/engine/battle/move_category.asm` — `IsTypeSpecial`/`IsMoveSpecial` (BATTLE_SRCS).
- Caller cleanup (removed now-include-provided externs): `dos_port/src/engine/battle/misc.asm`,
  `dos_port/src/engine/battle/get_trainer_name.asm`.
- `dos_port/Makefile` — `move_names.inc` rule + `battle_data.o` dep + `assets` target;
  `names.asm` + `move_category.asm` added to `BATTLE_SRCS`.

**Native harness (recreate if needed):** scratch dir had `harness.asm`/`check.py`. Pattern:
`nasm -f elf32 -I include/ -I . [-D BUG_FIX_LEVEL=N]` the routine + `src/home/array.asm` +
a tiny harness that sets `ebp` to a 64 KB buffer, stubs the data labels, `%include`s the
real asset, calls the routine, and `sys_write`s the 20-byte `wNameBuffer`; decode with the
GB charmap host-side. (EXE can't run — no DPMI host in the sandbox.)

### Next: Stage 5 — field-move data + full party_menu rewire (START HERE)
Pret refs: `data/moves/field_moves.asm` (`FieldMoveDisplayData`: id, name-index, x-col;
9 entries incl. unused `ANIM_B4`), `data/moves/field_move_names.asm` (`FieldMoveNames`),
`engine/menus/text_box.asm:GetMonFieldMoves` (the linear scan).
- New `dos_port/tools/gen_field_moves.py` → `dos_port/assets/field_moves.inc`
  (`FieldMoveDisplayData` + `FieldMoveNames`; mirror `gen_move_names.py`'s charmap encode).
  Wire Makefile (rule + `assets` target + a `src/data/*.o` dep) and expose the globals
  (battle_data.asm or a new data asm).
- New `IsFieldMove` / `GetMonFieldMoves` (linear scan of `FieldMoveDisplayData`).
- **Rewire `dos_port/src/engine/menus/party_menu.asm`** — remove its inline `MV_*` equ
  block (~lines 96–103), the baked `fm_str_*` strings (~151–161), and the
  `.field_move_name` cmp-chain (~434–468); use the shared table/predicate + `GetMoveName`/
  `FieldMoveNames`. The field-move ids now live in `gb_constants.inc` (pret names, no `MV_`
  prefix). **Caution: party_menu is a working linked menu** — `make` (SKIP_TITLE=1) then a
  `FRAME.BIN` field-move render check (`tools/render_frame.py`).

### Then: Stage 6 (effect-category arrays) + Stage 7 (PlayMoveAnimation stub)
- Stage 6: `data/battle/{residual_effects_1,residual_effects_2,special_effects,
  always_happen_effects,set_damage_effects}.asm` → `dos_port/assets/effect_categories.inc`
  (`-1`-terminated `db` lists; tiny — generate or hand-translate). Expose globals; wire.
  **No `MoveEffectPointerTable`** (handler pointers would dangle).
- Stage 7: `PlayMoveAnimation` stub — `bit BIT_BATTLE_ANIMATION(=7), [wOptions]` (note:
  `W_OPTIONS=0xD354` already in gb_memmap; add a `wOptions` alias + `BIT_BATTLE_ANIMATION`)
  → set → `DelayFrames(30)`; else `; TODO-HW:` real anim (no-op). pret ref:
  `engine/battle/animations.asm:437`.

**Loose end:** add a `docs/translation_log.md` entry for `GetName`/`GetMoveName`/
`GetMonName`/`GetMachineName`/`IsMoveSpecial` (not yet written).
