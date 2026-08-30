# Viridian Mart Parcel Quest + RIVAL Defeat Speech + Y/X Audit + Interactable Coverage

> **Plan type:** active plan (`docs/current_plan_*.md` — indexed by `dos_port/tools/project_state --plans`).
> **Skills:** `project-conventions`, `build-and-debug`, `faithfulness-review` (always). `asm-translation` for literal `SaveTrainerName` only. `score-analysis` not needed.
> **Coordination:** `memory_search` before plan/edit, `claim_acquire` every file before editing. Pret tree at repo root is **read-only spec**; edits in `dos_port/` + `dos_port/tools/generators/`. Keep pret labels; generators are Tier-1 — fix generator and regenerate, never hand-edit output.
> **Double-check principle:** Every "claim" below was verified against the tree (files read). Where the task said "only" or gave a line number, the plan re-measures — see Verdicts.

## 0. Task framing

Fix the Viridian Mart parcel quest (stub dialog, off-by-one text IDs, dead table swap), wire faithful `RIVAL1/2/3` defeat-speech names via generated `TrainerNamePointers`, audit `sprite_collisions.asm` Y/X comments, and ensure interactable objects / event tiles (trash cans as probe) are actually generated. Tree already has collision-literal work landed (`af2fe82`, `f13c608`, `2b221e4`) — do not redo.

## 1. Ground truth — double-checked

### Fix 1 — `gen_npc_dialogs.py` mixed table

- **Claim:** `_parse_text_pointers` (`dos_port/tools/generators/gen_npc_dialogs.py:327-344`) only matches `dw_const` and `break`s → returns 0 rows for ViridianMart.
- **Evidence:** Code is `m = re.match(r'dw_const\s+(\w+)', s); if m: append else: break`. Pret `scripts/ViridianMart.asm:77-83` is `dw`×3, `const_def 4`, `dw_const`×2. Generated `dos_port/assets/npc_dialogs/viridian_mart_dialogs.inc:10-20` is 3× `db 0x00,0xE8,0xE8,0xE8,0x57,0x50` (`_SCRIPT_STUB` at `gen_npc_dialogs.py:57`) → clerk's `"..."`.
- **Verdict:** CONFIRMED.
- **"Only" claim:** `grep "TextPointers" scripts/` shows only ViridianMart has `ViridianMart_TextPointers` + `ViridianMart_TextPointers2`; `grep -R "^\s*dw\s+\w+Text" scripts/` should be re-run at execution to prove no other mixed table exists before choosing general vs local fix.

### Fix 2 — Off-by-one `equ`

- **Claim:** `dos_port/src/scripts/ViridianMart.asm:53-54` `equ 3/4` vs pret `4/5`.
- **Evidence:** Pret `const_def 4` then two `dw_const` ⇒ ids 4,5. `data/maps/objects/ViridianMart.asm:2-4` `object_const_def` + 3×`const_export` ⇒ ids 1-3 for `TEXT_VIRIDIANMART_CLERK/YOUNGSTER/COOLTRAINER_M`. Port indeed `equ 3`/`equ 4`. `wNumSprites==3` matches `src/home/text_script.asm:199-218` spriteHandling remap (`wMapSpriteData[(id-1)*2+1]`). Id 3 hits sprite path, 4/5 bypass it.
- **Verdict:** CONFIRMED. Stale `extern ViridianMartClerkText ; NOT YET DEFINED` is false — `dos_port/src/data/items/marts.asm:29` `global ViridianMartClerkText`.

### Fix 3 — Dead swap

- **Claim:** `ViridianMartCheckParcelDeliveredScript` (`dos_port/src/scripts/ViridianMart.asm:80-92`) writes only `wCurMapTextPtr`; live lookup reads `w_map_text_table_ptr`.
- **Evidence:** `src/home/text_script.asm:153-168` ordinary path `mov esi,[w_map_text_table_ptr]` (`dos_port/src/engine/overworld/map_sprites.asm:104` BSS). Published at `src/home/overworld.asm:4494-4498` (`LoadMapData`), re-published at `2030-2034` (connection crossing) and `2309-2312` (`WarpFound2.done`) — lines drift ±4, shape holds. `"only ViridianMart does runtime _TextPointers swap"` sampled via `grep TextPointers2 scripts/` — only ViridianMart; re-grep at execution.
- **Verdict:** CONFIRMED.
- **Nuance found:** Port tables at `src/scripts/ViridianMart.asm:168-178` are `dd label` (4-byte stride) while flat path expects 8-byte `{dd stream, dd size}` (`text_script.asm:230` `lea edx,[eax*8-8]`). Publishing current table via `w_map_text_table_ptr` would mis-index — Fix 3 must convert both tables to 8-byte rows. Row 1 of `_TextPointers2` must be `ViridianMartClerkText` (`TX_SCRIPT_MART` 0xFE stream, `src/data/items/marts.asm`) so `text_script.asm:277` dispatches `DisplayPokemartDialogue`.

### Fix 4 — Rival names

- **Claim:** `GetTrainerName_` (`dos_port/src/engine/battle/get_trainer_name.asm:18-30`) faithful for `RIVAL1/2/3` via `wRivalName`; `SaveTrainerName` (`dos_port/src/engine/battle/save_trainer_name.asm:18-49`) forked to `GetName(TRAINER_NAME)` printing `RIVAL1` from `data/trainers/names.asm:27,44,45`.
- **Evidence:** Pret `engine/battle/save_trainer_name.asm:1-19` is `ld hl,TrainerNamePointers / dec a / add hl,bc*2 / ld a,[hli]... / .CopyCharacter` through `@` inclusive, linked against `data/trainers/name_pointers.asm:6-52` (47 rows, `assert_table_length NUM_TRAINERS`, 21 fixed strings + 26 `wTrainerName` rows; fixed strings byte-identical to class strings). Port `save_trainer_name.asm:46-48` `mov [wNameListIndex] / TRAINER_NAME / jmp GetName`.
- **Verdict:** CONFIRMED. Local `RIVAL1 equ 0x19 / RIVAL2 equ 0x2A` in `get_trainer_name.asm:14-15` minus `RIVAL3` relies on `gb_constants.inc` — harmless, note for `label_status`.

### Fix 5 — Y/X comments

- **Claim:** Y pair first into low bits, X block `rl c`/`shl` shifts Y up → `DH[3:2]=Y, DH[1:0]=X`; `thr_y>=thr_x` → `0x0C` else `0x03`. `Func_4d0a` identical. Previous `.use_ybits` → `.use_xbits` in `f13c608`.
- **Evidence:** `dos_port/src/engine/overworld/sprite_collisions.asm:233-242` (Y building `DH[1:0]=CF:!CF` with "X block shifts Y up to DH[3:2]"), `289-293` (X block shifts `dh` twice → `DH[1:0]=X, DH[3:2]=Y`), `330-339` (`cmp thr_y,thr_x / jc .use_xbits / 0x0C / 0x03`), `384-394` (`Func_4d0a`).
- **Verdict:** CONFIRMED as code description; audit `≈233-242,289-292,336-339,390-394` comments only.

### Fix 6 — Interactables / event tiles (trash cans)

- **Trash can probe:** `data/events/hidden_events.asm:182-185` `SS_ANNE_KITCHEN` 2×`PrintTrashText` + 1×`HiddenItems`; `430-450` `VERMILION_GYM` 1×`PrintTrashText` + 15×`GymTrashScript` (args 0-14) mapping `wGymTrashCanIndex`. Generated `dos_port/assets/hidden_events.inc:660-698` has 1+15 entries for `VERMILION_GYM`; handlers `dos_port/src/engine/events/hidden_events/vermilion_gym_trash.asm` + `vermilion_gym_trash2.asm` are linked (`hidden_object_stubs.asm:31-32` RETIRED 2026-08-21). Dispatch is `CheckForHiddenEventOrBookshelfOrCardKeyDoor` (`src/home/hidden_events.asm:70-112`) → `CheckForHiddenEvent` (`src/engine/overworld/hidden_events.asm:72-130`) → `JumpToAddress`.
- **Gap found:** `dos_port/tools/generators/gen_all_assets.py:549-595` chains `gen_map_headers`, `gen_npc_dialogs`, `gen_toggleable_objects`, `gen_battle_text`… but **does not chain `gen_hidden_events`** (nor `gen_hidden_item_coords`/`gen_hidden_coin_coords`). So `python3 gen_all_assets.py` leaves `hidden_events.inc` stale — `make -C dos_port assets` may call it via separate Makefile targets, but the umbrella is incomplete. Must fix to prevent "regenerated assets but bug persists" (header that file cites at `gen_all_assets.py:550-555`).
- **`bg_event` signs** are separate: `gen_map_headers.py:584-648` `text_pointer_names()` + `parse_object_file()` signs → `map_headers.inc` `db y,x,text_id` (F-6 `times 0` stubs fixed). Trash cans are **hidden_events, not bg_events** — do not look in `map_headers.inc`.

## 2. Implementation order

### Phase A — Fix 1 + Fix 2 (one workstream; B depends on A)

1. **Claim** `dos_port/tools/generators/gen_npc_dialogs.py`.
2. Edit `_parse_text_pointers(path, map_pascal)`:
   - Accept `dw <label>` (`dw\s+(\w+)`) as positional row (occupies next index, defines no const).
   - Accept `dw_const <label>(?:,\s*\w+)?`.
   - Skip `const_def\s+\d+`, `def_text_pointers`, blank/`;` lines — do not break.
   - Break only on line matching `^\w+:\s*$` (next label) or EOF.
   - Add per-map assert: `raw = len(re.findall(r'^\s*dw(?:_const)?\s+\w+', text, re.M))` vs `len(result)` → `AssertionError` with map name.
3. Run `python3 dos_port/tools/generators/gen_npc_dialogs.py` (needs `pokeyellow.sym` — on clean checkout `make -C dos_port compare` first, per memory `ci-clean-tree-generator-order-traps`; dev tree with `dos_port/assets` present will not reproduce). Verify `viridian_mart_dialogs.inc` becomes 5 rows + sentinel, order `SayHiToOak, Youngster, CooltrainerM, YouCameFromPalletTown, ParcelQuest`; `npc_count_eff = max(3, max_sign_id, 5) = 5`. No other `*_dialogs.inc` row count changes (`git diff --stat`).
4. **Claim** `dos_port/src/scripts/ViridianMart.asm`.
5. Fix `TEXT_VIRIDIANMART_CLERK_YOU_CAME_FROM_PALLET_TOWN equ 3 → 4`, `TEXT_VIRIDIANMART_CLERK_PARCEL_QUEST equ 4 → 5`; fix `extern ViridianMartClerkText ; NOT YET DEFINED → ; TX_SCRIPT_MART stream, global in src/data/items/marts.asm`.

### Phase B — Fix 3 (depends on A)

6. Verify uniqueness: `rg "TextPointers2|wCurMapTextPtr" scripts/` — if only ViridianMart, local fix is correct (otherwise justify general).
7. **Claim** `dos_port/src/scripts/ViridianMart.asm` (+ optionally `dos_port/src/home/overworld.asm` / `dos_port/src/engine/overworld/map_sprites.asm` if plumbing needs — verify at `grep -n w_map_text_table_ptr` 2030/2309/4494).
8. Wire `ViridianMartCheckParcelDeliveredScript` to publish flat pointer every call (self-healing vs warp re-publishes):
   ```nasm
   extern w_map_text_table_ptr
   ; ...
   CheckEvent EVENT_OAK_GOT_PARCEL
   jnz .delivered
   mov esi, ViridianMart_TextPointers
   mov [w_map_text_table_ptr], esi
   jmp .done
   .delivered:
   mov esi, ViridianMart_TextPointers2
   mov [w_map_text_table_ptr], esi
   .done:
   mov eax, esi
   mov [ebp+wCurMapTextPtr], al
   mov [ebp+wCurMapTextPtr+1], ah
   ```
   Keep faithful `wCurMapTextPtr` writes (pattern `Set/RestoreMapTextPointer` in `src/home/predef_text.asm`).
9. Convert both tables to 8-byte flat rows `{dd stream, dd size}` at `ViridianMart.asm:168-178`:
   - `ViridianMart_TextPointers`: 5× `dd <label>, <label>_end-<label>` (text_far streams via `assets/map_text/ViridianMart.inc`).
   - `ViridianMart_TextPointers2`: row1 `dd ViridianMartClerkText, 0` (TX_SCRIPT_MART — size ignored, or real size), rows2-3 reuse `ViridianMartYoungsterText`/`CooltrainerMText`. Ensure `section .data` (orphan-section trap — `link.ld`).
10. Alternative accepted: extend `gen_npc_dialogs.py` to synthesize `_TextPointers2` — document Tier-1 vs Tier-2 choice per `project-conventions`. Hand-authored rows are Tier-2.

### Phase C — Fix 4 (parallel, different files)

11. **Claim** `dos_port/tools/generators/gen_trainer_names.py` (or new `gen_trainer_name_pointers.py` + `dos_port/Makefile` rule — prefer extending existing to minimize `Makefile` churn).
12. Parse `data/trainers/name_pointers.asm`: 47 rows, `table_width 2`, `dw .XName` vs `dw wTrainerName`; collect fixed strings `db "YOUNGSTER@"`… with `0x50` terminator verbatim (do not re-encode).
13. Emit `dos_port/assets/trainer_name_pointers.inc`:
    - `global TrainerNamePointers`
    - 47× `dd` flat pointer (fixed rows: `dd .YoungsterName` where label `db "YOUNGSTER",0x50`; `wTrainerName` rows: `dd 0xFFFFFFFF` marker — reusing `npc_dialogs` `0xFFFFFFFF/0xFFFFFFFE` precedent) — document marker.
    - `assert 47` / `assert_table_length`.
    - Wire: `%include "assets/trainer_name_pointers.inc"` in `section .data` carrier (e.g. `src/data/pokemon/names.asm` or dedicated `src/data/trainers/name_pointers.asm`), add to `POKEMON_SRCS` if new object.
14. Add `DEVIATION{class=data-model; pret=data/trainers/name_pointers.asm:TrainerNamePointers; behavior=flat dd rows with marker for wTrainerName (WRAM/ROM split); evidence=GB single address space vs port flat model; lifetime=permanent}`.
15. **Claim** `dos_port/src/engine/battle/save_trainer_name.asm` — replace `GetName` tail with literal translation of `engine/battle/save_trainer_name.asm:2-19`:
    - `ESI=TrainerNamePointers; ECX=[ebp+wTrainerClass]-1` zero-extended; `mov esi,[esi+ecx*4]` (stride 4 vs pret dw×2 — note widening); `cmp esi,0xFFFFFFFF / je .runtime`; `.runtime: lea esi,[ebp+wTrainerName]`; `EDI=ebp+wNameBuffer`; `.CopyCharacter: mov al,[esi] / mov [edi],al / inc esi / inc edi / cmp al,0x50 / jne`.
    - Remove `extern GetName`, `wNameList*` writes, `wPredefBank`; add `extern TrainerNamePointers`. Keep `.CopyCharacter` label; add stride-widening note. Sole caller `PrintEndBattleText` (`src/home/trainers.asm:672`) — verify no side-effect dependency before removing `GetName` path (`label_status --callers SaveTrainerName`).
16. **Claim** `dos_port/src/home/trainers.asm:676-683` — rewrite anticipating comment to state table now exists; delete `DEVIATION` in `save_trainer_name.asm:18` premised on "no table".

### Phase D — Fix 5 (parallel, comments only)

17. **Claim** `dos_port/src/engine/overworld/sprite_collisions.asm` (comments only).
18. Audit comments at `≈233-242, 289-292, 336-339, 390-394` against layout `DH[3:2]=Y, DH[1:0]=X, Y>=X→0x0C else 0x03`. Fix comments to match; if a mask (`0x0C`/`0x03`) or label (`.use_xbits`) contradicts code, **STOP and report** per task.

### Phase E — Fix 6: Interactable / event-tile generation (trash cans)

19. **Claim** `dos_port/tools/generators/gen_all_assets.py`, `dos_port/Makefile` (and generated `dos_port/assets/hidden_events.inc` if chaining changes).
20. Wire umbrella: add `import gen_hidden_events, gen_hidden_item_coords, gen_hidden_coin_coords` to `gen_all_assets.py:549-595` chain after `gen_toggleable_objects`:
    ```python
    print("chaining gen_hidden_events ..."); gen_hidden_events.main()
    ```
    Ensure `Makefile: assets:` target lists `assets/hidden_events.inc` (and `hidden_item_coords.inc` etc.) as prerequisites so `make -C dos_port assets` is not stale either. This mirrors `gen_npc_dialogs` chaining rationale (single run regenerates consistently).
21. Add static cross-check (new `dos_port/tools/check_hidden_events.py` or extend `lint_pret_labels` / `static_gate`):
    - Parse `data/events/hidden_events.asm` and `assets/hidden_events.inc`, assert `len(pret)==len(generated)` and every handler in generated is `global` in `dos_port/src/engine/events/hidden_events/` or `hidden_object_stubs.asm`.
    - Fail build if a `hidden_event` landed without regeneration (same class as `map_headers` sign-count check).
22. Regenerate: `make -C dos_port compare` (if clean) then `make -C dos_port assets` (or `python3 gen_hidden_events.py` directly); `git diff --stat` should show only `viridian_mart_dialogs.inc` 5-row change + new `trainer_name_pointers.inc` + `hidden_events.inc` if previously stale.

## 3. Verification & acceptance

- **Build & lint:** `make -C dos_port -j8`, `dos_port/tools/lint_pret_labels --strict-claims` → 0, `dos_port/tools/static_gate` → at baseline, `dos_port/tools/faithdiff ViridianMartCheckParcelDeliveredScript / SaveTrainerName / TrainerNamePointers` with justifications for unsuppressed adds/drops.
- **Fidelity:** `make -C dos_port fidelity` (core 16 scenarios ≈30s via `pgate.sh`) and `fidelity-full` (66 scenarios ≈378s) if label set changed; `pgate.sh` exits non-zero on gaps — do not count PASS only. Do not edit sources while suite runs (pgate rsyncs base copy at staging).
- **Goldens — new:**
  1. **Parcel cutscene E2E:** seed `wCurMap=VIRIDIAN_MART`, `EVENT_OAK_GOT_PARCEL=0`, drive `hTextID=4` script, assert `"Hey! You came from PALLET TOWN?"`, auto-step `PAD_LEFT/UP`, `TEXT 5` gives `OAKS_PARCEL` + `EVENT_GOT_OAKS_PARCEL`, `wViridianMartCurScript==2`, no re-trigger on re-entry.
  2. **Mart after parcel:** `EVENT_OAK_GOT_PARCEL=1`, `hTextID=1` → `TX_SCRIPT_MART` inventory `POKE_BALL,POTION,ANTIDOTE,PARLYZ_HEAL,BURN_HEAL`, purchasable, survives map re-entry (exercises every-frame republish vs `overworld.asm:2030`/`2309`).
  3. **Rival name:** `wRivalName="BLUE"`, `wTrainerClass=RIVAL1/2/3` → `SaveTrainerName` → `wNameBuffer="BLUE@"` / `TrainerEndBattleText` prefix `BLUE:`; regular trainer e.g. `YOUNGSTER` unchanged (regression).
  4. **Trash-can dispatch (Fix 6):** `rg "HiddenEventsFor_VERMILION_GYM" assets/hidden_events.inc -A 17` shows 1×`PrintTrashText`+15×`GymTrashScript`; `nm PKMN.EXE | grep GymTrashScript` resolves. Headless: `DEBUG_HIDDENOBJ` harness at `VERMILION_GYM (1,7)` (`overworld.asm:506-529` pattern) with `AUTOKEY_APRESS=1` → `hDidntFindAnyHiddenEvent==0` and `VermilionGymTrashSuccessText*` far stream (`data/text/text_2.asm:759-789`) or at least `hItemAlreadyFound==0` non-fallthrough (stub-safe `hidden_object_stubs.asm:10-14`).
- **No other map's `*_dialogs.inc` row count changes** — enforced by generator assert + `git diff --stat`.
- **Interactable audit record:** episode or memory noting `hidden_events.inc` handler count vs pret, umbrella wiring, and audit result for `sprite_collisions.asm` (all-correct counts as result).

Retired `DEVIATION`/comments deleted/rewritten; new `DEVIATION` only for marker-encoding (`data-model`) and ViridianMart flat publish if needed (document choice Tier-1 vs Tier-2).

## 4. Deliverables & claims

`dos_port/tools/generators/gen_npc_dialogs.py`, `dos_port/tools/generators/gen_trainer_names.py` (or new generator + `dos_port/Makefile` rule), `dos_port/tools/generators/gen_all_assets.py` + `dos_port/tools/generators/gen_hidden_events.py` wiring, `dos_port/src/scripts/ViridianMart.asm`, `dos_port/src/engine/battle/save_trainer_name.asm`, `dos_port/src/home/trainers.asm` (comment), `dos_port/src/data/items/marts.asm` (if comment), `dos_port/src/engine/overworld/sprite_collisions.asm` (comments only), plus `dos_port/assets/trainer_name_pointers.inc` and regenerated `viridian_mart_dialogs.inc` / `hidden_events.inc`, plus `tools/mgba_harness/scenarios/*.lua` and `tests/goldens`.

**Claim each before editing** per AGENTS.md. Edits to a claimed path are blocked outright (Codex halted after the fact).

## 5. Risks & traps

- On `git clean -Xdf dos_port/assets`, regenerate via `make -C dos_port compare && make -C dos_port assets` (memory `ci-clean-tree-generator-order-traps`).
- Any new `section .data` must be in `link.ld` (orphan-section trap — `.rodata` all-white bug).
- Do not hand-edit generator output — fix generator and regenerate (Tier-1 rule, `project-conventions`). Text strings are Tier-1 data via `gb_text.encode` → `assets/*.inc`.
- The "only ViridianMart" claim must be measured (`rg`), not quoted — plan correctness depends on it.
- The 8-byte row mismatch in Fix 3 is the most likely place task prose understates work — verify `MapTextTablePointers` dispatch before wiring.
- New `hidden_events.inc` handler `extern` list is load-bearing (`gen_hidden_events.py:194-198` — forward refs destabilize offsets) — never hand-edit.
- Fidelity gates are parallel (`pgate.sh`); do not use `fidelity-serial` unless maintainer asks. Never `make fidelity | tail -40` (masks exit code).

## 6. Open question (answer before execution)

Trash cans are `hidden_event` objects, not `bg_event` tiles. Should the audit cover only `hidden_event` interactables, or also `bg_event` signs (poster/blackboard/bookshelf) and `warp_event` tiles (same `gen_map_headers.py` blob)? Cheapest is all three — they share dispatch (`CheckForHiddenEventOrBookshelfOrCardKeyDoor` → hidden_events then `PrintBookshelfText`), but if you only want trash cans, sign/warp parts can be audit-only (no code).

Also: trash-can puzzle-success golden (requires deterministic RNG seeding `hGymTrashCanRandNumMask`, `wSecondLockTrashCanIndex` at `ram/hram.asm:329` / `ram/wram.asm:2399`) vs dispatch-exists golden (pressing the can consumes `hItemAlreadyFound` and does not fall through to NPC talk) — state which is in scope.

---
*Teams: viridian_mart_dialogs.inc 3→5 rows, RIVAL name via TrainerNamePointers, Y/X comment layout, hidden_events umbrella — double-checked 2026-08-27.*
