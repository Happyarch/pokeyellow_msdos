# Fidelity-harness expansion — WRAM datastructs, streamed text, battle, more menus

> **STATUS — OPEN.** Planned 2026-07-13 in the `worktree-fidelity-expansion` worktree;
> **folded back into master 2026-07-14** and rectified against it in the same pass.
> Stages 0, 1a, 1b, 1c and **2** are DONE (see the ledger); **3/4 remain — see the
> SESSION HANDOFF section immediately below.** Work stage-by-stage, update the Coverage
> table, append findings, commit per stage.
>
> **Filed as `docs/current_plan_fidelity_expansion.md`** — the active-plan path. The
> fold-back (`9dc7fed2`) wrote it into `docs/plans/` instead, the *completed*-plan directory,
> where an open plan is invisible to the start-of-session `docs/current_plan_*.md` scan.
> Restored 2026-07-14. Archive it (`git mv` into `docs/plans/`) only when Stage 4 closes.
>
> **To be clear about what the fold-back got right:** it hand-copied a *rectified* plan instead
> of running `git merge`, **deliberately and correctly**. A merge would have restored this
> branch's pre-audit text over master's corrections — undoing what the menu-fidelity audit had
> just landed, which is exactly the hazard the "Read this first" section below is about. The
> rectify-don't-merge call was right. Only the destination directory was wrong.
>
> Skills to load before starting: `build-and-debug` + `faithfulness-review` (always),
> `asm-translation` (before touching `debug_dump.asm`), `project-conventions`.

## 🤝 SESSION HANDOFF (written 2026-07-14, end of the Stage-2 session)

The session that executed Stages 1c and 2 ended here **by design** (context hygiene — the
user asked for a fresh session for the rest). If you are that fresh session: this section is
your starting state. Everything below it is still binding; read "⚠ Read this first" next,
then the Stage 3/4 specs.

**Where master stands after the Stage-2 commit:**
- `make -C dos_port fidelity` is **14/14** green: status_p1/p2, start_menu, overworld_pallet,
  party_menu, bag_menu, sign_pallet, item_tm_teach, item_stone_evolve, item_potion_use,
  battle_intro, battle_menu, move_selection, ball_catch.
- All goldens are committed and regenerate byte-identically (verified ×2 this session for the
  four battle goldens; the Route 1 encounter lands at frame 5259 every run).
- `tools/lint_pret_labels` exits 0. `tools/update_label_db` was run after the commit.

**What remains: Stage 3 (menu scenarios ×5 + stride-20 differ support), then Stage 4
(tiers, `goldens-verify`, mask policy, skill updates, archive this plan).** Their specs below
are already rectified — but re-measure anyway; the standing rule (master is truth, comments
are not) applies to this file too.

**Machinery Stage 2 left you (reuse, don't rebuild):**
- Golden side: `lib/battle.lua` (`enter_wild` = the whole boot→Route-1→forced-encounter→spec
  enemy flow), `seed.enemy` / `seed.force_encounter` / `seed.set_event` in `lib/seed.lua`.
- Port side: the `DEBUG_BATTLE_GOLDEN` branch of `RunBattleTest` (`debug_dump.asm`) with
  subflag chain `_INTRO` / `_MENU` / `DEBUG_MOVEMENU` / `DEBUG_ITEMBALL`; scenario ids 14/15/16/20.
- Differ: battle window is a uniform (10,3) with `oam_window: True`; `_BATTLE_VRAM_MASKS`
  (intro) vs `_BATTLE_VRAM_MASKS_MENU` (post-send-out) — every mask string explains its
  measurement; F-19's masks carry the finding id (Stage 4's mask policy is already followed
  there).
- Stage 3 needs the `"stride": 20` differ key (NOT yet implemented) — see its spec.

**Session mechanics for the fresh session:**
- **Stigmergy**: register (`context_open` + `root_register` with your host session id), then
  re-acquire claims for what you touch (`golden_diff.py`, `mgba_harness/**`, `Makefile`,
  `debug_dump.asm`, this file). The Stage-2 session released its claims (96–99, 107) at
  handoff.
- **Codex agent `r-1a5ca7a94daa`** (mailbox thread 13, session since ended): its
  scenario-manifest consolidation (`scenario_manifest.json` + `validate_scenarios.py`,
  currently describing only the 10 Stage-1c scenarios — it will report drift for the battle
  scenarios; that is expected and theirs to update) is **sequenced after Stage 4's archive**.
  When you archive this plan, send a mail to that root (or whoever holds the manifest files
  then) saying the claims are released and the scenario set is final.
- `.codex/config.toml` shows modified in the tree — **not ours; do not commit it.**
- Standing user directives that governed this plan's sessions: *"Don't stop until the plan is
  done"*; per-stage task lists that start high-level and expand to subtasks on entering the
  stage; *"Reason then do — doing without reason breaks things"*; measure divergences from
  first diffs, never lift expected values; one commit per stage with the ledger + findings
  updated in that same commit; revert-proof each new capability (paste the RED output in the
  stage notes, then revert).

## ⚠ Read this first — why this document was rewritten

This plan was written and executed on a branch that forked from master at `e7dc3f6b`,
and then sat while master absorbed ~50 commits of the **menu-fidelity audit**. That audit's
closing finding was:

> **the recurring defect was not bad assembly, it was a confident comment.**

This document was itself an instance of that defect. It shipped a section titled *"Verified
architecture facts (**trust these**; re-verify only if a diff disagrees)"* — a standing
instruction to trust, in a codebase whose dominant failure mode is trusted assertions. When
it was folded back, its claims were re-checked against master and several were false. The
"trust these" framing is gone. What remains below survives on evidence, and **carries the
evidence with it**.

Two sections were deleted outright rather than ported:

- **"Worktree build setup"** — obsolete; this work lives in master now.
- **"Coordination with the menu-fidelity /loop"** — that loop is **closed**. All 24 rows
  landed and it was archived (`61b8548e`). Its rules ("never edit `src/home/*`", "don't fix
  M-3 ourselves", "rebase between waves") no longer bind anything, and following them today
  would prevent correct work.

**Standing rule for anyone executing this plan:** master is the source of truth. Verify a
claim against the code (`nm`, the Makefile's source lists, `git log -p`) — never against a
comment, including the comments in this file. Update this file **in the same commit** as the
work it describes, so it never drifts back into being a confident lie.

## Why this exists

`make fidelity` covered 6 scenarios when this plan opened (status_p1/p2, start_menu,
overworld_pallet, party_menu, bag_menu), and compared only tilemap cells, VRAM tile slots, and
OAM. (It is 7 now — Stage 1b added `sign_pallet` — and it compares WRAM.) Proven blind spots:

- **No WRAM datastruct comparison** — party structs, `wLoadedMon`, bag, player data were
  never diffed vs mGBA (the never-done Session-F item of `docs/plans/fidelity_harness.md`).
  User: *"We can compare against GB RAM values for most of these things except the overworld
  really."* → **closed by Stage 1a.**
- **No rendered-text check for streamed dialog** — a `PrintText` refactor passed all 6
  goldens yet regressed live text to "REDRED".
- **Menus with DEBUG gates but no golden**: options, trainer card, naming, pokédex G1/G2,
  list-menu modes, textbox ids, learn-move, all item-use flows.
- **Battle goldens deferred** pending a convergence spec — the port's `DEBUG_BATTLE` seeds
  `REVERT`-tagged synthetic enemy values no real encounter reproduces.
- The bag_menu golden **masked** a real bug (missing ▼ blink) instead of failing it. **Both
  halves are now resolved** — verify before re-filing this: the bug was fixed by menu-audit row
  24 (`9bea1c15`, which gave the blink a cell a box actually owns), and the mask at
  `golden_diff.py` cell (11,18) was **re-measured, not left lying**: its why-string now records a
  genuine *blink-phase* difference (the golden caught blink-off; the port's harness dumps the
  list before `HandleMenuInput` arms the blink, so its arrow is still on). What remains for
  Stage 4 is narrower and real: that mask is **timing-coupled**, and the honest fix is to pin
  the dump frame on both sides so the phase is deterministic — not to keep a live cell masked.

Scope decisions (user, 2026-07-13): wave 1 = streamed text + WRAM datastructs; battle via a
**synthetic-enemy seed spec** (wave 2); remaining menus wave 3; port-side scripted-input
replay **out of scope** (entry states only). Overworld *map/view* RAM is exempt from
comparison; pure game-data regions are compared in every scenario.

## Architecture facts (re-verified against master 2026-07-14)

Each is stated with where it was checked. Re-check before relying on one; line numbers rot.

- **Goldens are region-table-driven.** `tools/mgba_harness/lib/dump.lua` — `dump.write(name,
  regions, extra)` takes arbitrary `{name, addr, size}` regions and writes the JSON sidecar
  (region name = the join key; the differ never assumes offsets). `make_goldens.sh` **globs**
  `scenarios/*.lua`, so a new scenario needs no registration on the mGBA side. ✅ holds.
- **`lib/seed.lua`** hand-builds the 44-byte pret party structs from ROM data + pret formulas
  (CalcStat, exp polynomials), DV spec bytes `$98 $76`, all multi-byte fields big-endian.
  `seed.*` must run inside `scenario.exec`. Since Stage 1a it also implements
  `mon_learnset` + `write_mon_moves` (see F-3) and the composite `seed.debug_new_game`.
- **`lib/navigate.lua`**: state-aware nav (`wait_for_text`, `dialog_until_text`, `choose`,
  `walk`, `open_start_menu`, `new_game_to_bedroom`, `boot_to_main_menu`). `lib/gbtext.lua`
  encodes via the pret charmap (**never hand-encode bytes**). `lib/symbols.lua` resolves pret
  `.sym` labels and errors on unknown. ✅ all present.
- **`tools/golden_diff.py`** `SCENARIOS` dict is the single source of truth per scenario:
  `flags`, `window` (col,row of the 20×18 GB screen in the 40×25 canvas), `projections`,
  `offcanvas`, `masks`, and — since Stage 1a — `wram_skip` / `wram_masks`. Exit 1 on unmasked
  divergence. `--flags` feeds `goldencheck.sh`. ✅ holds.
- **`make goldens` / `goldencheck SCENARIO=` / `fidelity`** live in the Makefile with
  `FIDELITY_SCENARIOS := status_p1 status_p2 start_menu overworld_pallet party_menu bag_menu
  sign_pallet` (Stage 1b appended the last one). ✅ holds (the old line citations were stale
  and are dropped).
- **WRAM addresses** (`include/gb_memmap.inc`, re-verified): `wPlayerName` $D157 (11);
  `wPartyCount` $D162 → `wPartyMonNicksEnd` $D2F6, one contiguous 0x194 block;
  `wPokedexOwned` $D2F6 (owned 19 + seen 19); `wNumBagItems` $D31C (1+20×2+1 = 42);
  `wLoadedMon` $CF97 (44); `wEnemyMonNick` $CFD9 / `wEnemyMon` $CFE4 / `wBattleMonNick` $D008
  / `wBattleMon` $D013; `wIsInBattle` $D056; `wPlayerMoney` $D346 (3, BCD); `wOptions` $D354;
  `wPlayerID` $D358 (2). Also `wNumSigns` $D4AF, `wSignCoords` $D4B0, `wSignTextIDs` $D4D0.
- **`DEBUG_DIALOG`** (overworld.asm) is a **synthetic window-position test** (checkerboard),
  NOT a real-text gate. The real-text gate is `DEBUG_SIGNTEXT` (Stage 1b).

### ✱ CORRECTED — the overworld dialog scratch is stride-20, and that is CORRECT

The original plan asserted:

> *"Port dialog text lands in W_TILEMAP rows 12-17 at pret coordinates … only the ▼ advance
> arrow lives solely in GB_TILEMAP1."*

and Stage 1b then filed **F-9** claiming the port's box was at the wrong row with the wrong
line spacing. **Both were wrong, and the second was a measurement error.** The overworld
dialog is drawn into a **GB-shaped scratch with a stride of 20, not the canvas's 40**
(`src/home/text.asm:1380-1386`):

```asm
msgbox_dialog:
    dd 20                       ; MB_STRIDE       — GB-shaped scratch
    dd MSG_BOX_ESI              ; MB_BOX_OFS      — (0,12)
    dd MSG_TEXT_EBX             ; MB_LINE1        — (1,14)
    dd W_TILEMAP + 16 * SCREEN_W_TILES + 1  ; MB_LINE2 — <LINE> at (1,16)
```

`MB_LINE1` and `MB_LINE2` are **40 bytes apart = two rows of a 20-wide grid** — exactly the
GB's 14/16 spacing, with a blank row between the text lines. Read as a 40-wide canvas they
*look* like adjacent rows 7 and 8, which is precisely the table F-9 reported. **The dump was
read at the wrong stride.** Confirmed independently from rendered pixels (see F-9 below).

Consequence for anyone writing a dialog-bearing golden: the projection is a **stride change,
not a row remap**:

    golden wTileMap (row r, col c), r in 12..17, c in 0..19
      →  port flat offset  W_TILEMAP + r*20 + c        (stride 20, NOT 40)

Laid over the 40-wide canvas that flat offset lands, for `k = r - 12`, at canvas
row `6 + k//2`, col `c + 20*(k%2)` — 6 rows × 1 panel re-flowed into 3 rows × 2 panels, the
same shape `party_menu`/`bag_menu`'s message box takes, so `golden_diff.py` already had the
mechanism. `sign_pallet` uses exactly that, and matches 360/360 cells. (It also means the
dialog scratch **shares bytes with the map mirror** — F-13.)

## Coverage (execution ledger — update per stage)

| # | stage | status | commit | notes |
|---|---|---|---|---|
| 0 | Groundwork: box-level reconcile, DebugDumpMemory→GBSTATE hook, scenario ids | DONE | `a74c44c9` | box-level was a non-issue (F-1); hook verified on DEBUG_ITEMTM; +`tools/run_headless.sh` |
| 1a | GBSTATE v2 + WRAM regions end-to-end (existing 6 scenarios) | DONE | `a74c44c9`, `8b018e84` | v2 is SELF-DESCRIBING (design change, below); found 3 real harness bugs (F-3/F-4/F-5); fidelity 6/6 green |
| 1b | `sign_pallet` streamed-text scenario | **DONE** | `60990fd5`, `b99c0199`, `1c346cbb`, `189fbb59` | the port could not read a sign AT ALL (F-6 data, F-7 code) — both fixed. Plus **F-10** (text-id-0 collision) and **F-12** (the gate stood on an unreachable tile), both found during the fold-back. Golden passes 360/360 tilemap cells incl. the whole dialog box; `make fidelity` 7/7. **Never was blocked**: F-9 was a misdiagnosis, F-8 does not reproduce. New OPEN findings it surfaced: **F-13** (scratch/mirror overlap), **F-14** (▼ after `done`). |
| 1c | Item datastruct scenarios ×3 | **DONE** | (this commit) | Differ class `datastruct` + `item_tm_teach` / `item_stone_evolve` / `item_potion_use`; `make fidelity` 10/10. First-ever observation of these gates (F-15) immediately caught a REAL port bug: **F-16** — the post-evolution stat recalc read the NEXT species' base stats (NINETALES got JIGGLYPUFF's). Fixed; golden-verified. M-8 did **not** surface (no priced list in these flows — see the stage notes). |
| 2 | Battle convergence spec + battle_intro/battle_menu/move_selection + ball_catch | **DONE** | (this commit) | The spec battle (real loaders both sides, DVs $98 $76 overwritten, loader-derived parts asserted) converges end-to-end: `make fidelity` **14/14**. First diffs caught **four real port fidelity bugs** — **F-17** (enemy HUD drawn during the wild intro), **F-18** (dead $73 drawn over the HP-bar cap), **F-19** (enemy-gauge palette clones parked on LIVE glyphs incl. the battle ▼), **F-20** (player HP-bar cap $6C where battle uses $6D) — plus **F-21** (wLoadedMon staging + player-first HUD order omitted). Ball tiles moved to pret's OBJ ids $31–$34; ball OAM rows now zero all of $FE00 (GB DMA parity). `ball_catch` passes with **zero WRAM masks**. |
| 3 | Menu scenarios ×5 + stride support | TODO | | |
| 4 | Cross-cut: tiers, goldens-verify, mask policy, skill updates | TODO | | |

---

### Stage 0 — Groundwork (S) — **DONE**

1. Box-level byte (party struct offset 3) reconcile → non-issue, F-1.
2. `call DumpGBState` at the top of `DebugDumpMemory`, so DUMP.BIN-style gates
   (`DEBUG_ITEM*`, `DEBUG_CALCSTATS`…) also emit GBSTATE.BIN — symmetric with
   `DumpBackbuffer`'s existing call. → F-2.
3. Scenario ids 8–20 (`%elifdef` chain in `debug_dump.asm`): 8 OPTIONS, 9 TRAINERCARD,
   10 G1, 11 G2, 12 NAMINGSCREEN, 13 SIGNTEXT, 14 BATTLE_MENU, 15 BATTLE_INTRO,
   16 MOVEMENU, 17 ITEMTM, 18 ITEMSTONE, 19 ITEMUSE, 20 ITEMBALL. Sanity tag only — the
   differ selects the golden by name.
   **ORDER IS LOAD-BEARING**: a gate that *implies* another must be tested first (the
   Makefile makes `DEBUG_ITEMBALL` imply `DEBUG_BATTLE`, so ITEMBALL precedes BATTLE or it
   tags itself 7).
   ✱ **CORRECTED in the fold-back**: the branch named id 16 `DEBUG_BATTLE_MOVESEL`, a gate
   that does not exist. Master's real gate is **`DEBUG_MOVEMENU`** (row 22 of the menu audit
   rewrote the FIGHT sub-menu). As written, a `DEBUG_MOVEMENU=1` build fell through to
   `%elifdef DEBUG_BATTLE` and mis-tagged itself scenario 7.
4. `tools/run_headless.sh` — `goldencheck.sh`'s scenario-free twin (build → headless
   DOSBox-X on a scratch PKMN.IMG copy → extract GBSTATE/DUMP/FRAME). Needed to probe a new
   gate before a golden exists.

### Stage 1a — GBSTATE v2 + WRAM compare (L) — **DONE**

> **DESIGN CHANGE (user guidance): "wram is a moving target… ideally I would source symbols
> instead of hard memory addresses."** The plan had the region list hand-mirrored in *three*
> places (dumper, dump.lua, differ), any of which could silently drift. Instead **GBSTATE v2
> is self-describing**: the dump carries a region directory (name, GB address, size, file
> offset) after its header, so the differ *reads* the layout rather than restating it — two
> tables, not three. Both are symbol-sourced (port: `gb_memmap.inc` equates and symbol
> *differences* like `wPartyMonNicksEnd - wPartyCount`; golden: `sym:addr()` on pret's
> `.sym`), and the differ **cross-checks every shared region's address/size across the two
> sides** (`check_addresses`), so a memmap drift is a loud failure instead of a silent
> wrong-bytes comparison. All 16 regions agree.
>
> Symbol-derived sizes also corrected the plan: `wEnemyMon` is **29 B** (`battle_struct`,
> pret `macros/ram.asm:39`), not 36 — 36 was the *gap* to the next label, which sweeps in
> `wEnemyMonBaseStats`/`wEnemyMonActualCatchRate`.

**Format: self-describing v2.** Header `"GBST"`, u8 version=2, u8 scenario id, u16 region
count, u32 dir size, u32 total; then the region directory; then payloads. Every scenario dumps
the same regions — per-scenario *policy* lives in the differ, no `%ifdef` layout forks in the
dumper.

Regions: `wTileMap` (the port's full 40×25 canvas — the golden's is the GB's 20×18; same
name, different size, **by design**, the differ extracts the subwindow), `vram_tiles`, `oam`,
plus `wPlayerName`, `wPartyData`, `wPokedex`, `wBagItems`, `wPlayerMoney`, `wOptionsBlock`,
`wPlayerID`, `wLoadedMon`, `wBattleFlags`, `wEnemyMonNick`, `wEnemyMon`, `wBattleMonNick`,
`wBattleMon`.

Excluded deliberately: `NPC_DIALOG_BUF` (port-bespoke WRAM), the rival-name span
$D349-$D353 (nondeterministic), the `wStringBuffer` union (volatile, multi-use).

Reporting is **field-aware**: a bad byte prints as `wPartyData mon 3 DVs` or `wBagItems slot 2
quantity`, never a hex offset — the kind of report that gets fixed instead of masked. Names
and species are charmap-decoded; multi-byte big-endian fields collapse to one line.

#### Exit-gate evidence

- `make fidelity` **PASS on every scenario** (6/6 at Stage 1a; **7/7** once Stage 1b added
  `sign_pallet`), each reporting `WRAM: OK (8 regions, 5 skipped)` (the 5 skips =
  `_NONBATTLE_WRAM_SKIP`, retired by the Stage 2 battle scenarios).
- `make goldens` twice → **byte-identical sha1s**.
- `tools/lint_pret_labels` exits 0.
- **Revert-proof** — corrupting one DV byte and one seeded bag quantity in `debug_party.asm`:

```
WRAM: 27 mismatched fields:
  wBagItems slot 1 quantity: want $03 | got $07
  wLoadedMon DVs: want $9876 (39030) | got $A376 (41846)
  wPartyData mon 0 HP: want $016A (362) | got $0163 (355)
  wPartyData mon 0 DVs: want $9876 (39030) | got $A376 (41846)
  wPartyData mon 0 max HP: want $016A (362) | got $0163 (355)
  ...
```

  Both capabilities land: the differ names the exact **field**, and the DV corruption is
  caught cascading into every stat recomputed from it. Both reverted.

### Stage 1b — `sign_pallet` streamed-text scenario (M)

**The plan assumed the port could read a sign. It could not** — that is what this stage
actually found. Three independent defects, all dead-code silent: **F-6** (every sign was a
data stub), **F-7** (the caller was never ported), **F-10** (the text-id 0 collision). Plus a
harness trap, **F-8**.

**DONE (port side):**

- `tools/gen_map_headers.py` — emits real `bg_event` records (Y, X, text_id) instead of
  `times n*3 db 0` stubs; `text_pointer_names()` resolves the id **by name** against the map's
  `<Map>_TextPointers` `dw_const` list.
- `tools/gen_npc_dialogs.py` — the per-map text table runs through the highest sign id, and is
  emitted even for maps with **no NPCs** (load-bearing — see F-10).
- `src/engine/overworld/overworld.asm` — `IsSpriteOrSignInFrontOfPlayer` (pret name, SIGN
  branch; allowlisted relocation) + port-only glue `DoSignInteraction`, wired into
  `OverworldLoop`'s A-press dispatch **before** the sprite branch (pret's order).
- **F-10 fix**: text ids are pret's **1-based** ids again; all three consumers subtract 1 at
  the lookup, as pret's `DisplayTextID` does.
- `DEBUG_SIGNTEXT` gate (scenario id 13) — spawns **beside** the Pallet Town sign facing it
  (`SIGNTEXT_MAP/Y/X/DIR`; the tile below the sign is unstandable — F-12), runs the real
  A-press dispatch, dumps FRAME.BIN + GBSTATE.BIN once the text is printed and the box is
  waiting. Needs `AUTOKEY_APRESS` (F-8).

**DONE (golden side):**

- `tools/mgba_harness/scenarios/sign_pallet.lua` — seeds the player only (matching the gate),
  walks to (9,8), faces LEFT, A, answers the `<cont>` with a second A, settles, dumps
  standard+wram. Byte-identical across two runs.
- `golden_diff.py` `SCENARIOS["sign_pallet"]` — window **(16, 8)** (measured; the odd Y puts
  the block-aligned mirror two rows above `overworld_pallet`'s), plus the **stride-20 dialog
  reflow** as a projection: golden rows 12–17 → canvas rows 6–8 × 2 panels, i.e. exactly the
  shape `party_menu`/`bag_menu`'s message box already takes. **360/360 tilemap cells agree**,
  including every cell of the dialog box; VRAM/OAM/WRAM clean. `make fidelity` is 7/7.
- The **F-8 hook re-test**: the hang does not reproduce. The dump now sits **inside**
  `npc_dialog_wait_impl`, after the box is staged — so the golden covers the printed dialog,
  which is what "sign reading is live" should prove. (Full account under F-8.)

**Still open, and still worth doing** (it is the only check that regression-tests the *data*):

- Add `wNumSigns` ($D4AF, 1), `wSignCoords` ($D4B0, 32) and `wSignTextIDs` ($D4D0, 16) as
  golden regions. mGBA reports Pallet's real values (4 signs, ids 4–7); the pre-fix port
  emitted all zeros. One region byte-exactly regression-tests the sign feature *and* its
  numbering. **Until it lands, no golden captures any text-id state**, so a green
  `make fidelity` is not evidence for F-10 either way — F-10's fix was proven instead by a
  game-wide static cross-check against pret (940/943 `object_event`s, 203/203 `bg_event`s)
  and by Route 5's sign, dead before the fix, rendering after it.

### Stage 1c — Item datastruct scenarios (M) — **DONE**

New differ scenario **class `datastruct`**: compares only WRAM regions; tilemap/vram/oam
skipped with a class-level why ("the dump point is a post-flow WRAM gate; transient message
frames are timing-coupled — rendered-text fidelity is owned by the menu/dialog scenarios").
Port gates exist and emit GBSTATE via Stage 0.

**DONE (this commit).** `golden_diff.py` grew the `class` key (`"datastruct"` skips the
three video comparators, loudly, through the masked-divergence channel — never silently);
three scenarios landed (`scenarios/item_*.lua` + `SCENARIOS` entries + `FIDELITY_SCENARIOS`).
Execution notes, all measured:

- **The goldens run in the bedroom** (no walk to Pallet): the class compares no video, and
  the walk would only add NPC-wander surface. The gates' map position is irrelevant to every
  compared region.
- **The two direct-call gates converge with the real UI flow.** RunTMHMTest/RunStoneTest
  bypass the bag UI (`wCurItem`/`wWhichPokemon` preset, `call UseItem`); the goldens drive
  START→ITEM→…→USE. All compared WRAM — including `wLoadedMon`, which lands on the last
  party-menu-loaded mon (mon 5) on both sides — agrees byte-for-byte.
- **`item_potion_use` mirrors the WHOLE AUTOKEY_ITEMUSE script** (POTION heal + ANTIDOTE
  refusal), not just the plan table's potion leg: the refusal's second party-menu pass is
  what the transient regions last saw. Port flags pin `AUTOKEY_DUMP_FRAME=700` (script done,
  bag list reopened, WRAM settled).
- **Navigation lessons that will bite Stage 2/3 too**: (1) a tap into a just-drawn list
  menu is swallowed (joypad flush) — settle 30 frames after the menu appears, and verify
  each submenu transition with the new poll-first `navigate.ensure_text` (re-tap only if
  the state never appeared; a blind re-tap would double-select); (2) the TM flow's YES/NO
  can be consumed in the same motion as the preceding ▼ tap — key on the *landing* state
  (the party-menu prompt), not on observing "YES"; (3) "SNORLAX learned TOXIC!" parks with
  a ▼ even though `_LearnedMove1Text` is `text_end` (the print path waits); the heal
  message (`done`) waits with NO ▼ — `navigate.dismiss_text` retries A against observed
  state for both shapes.
- **M-8 did not surface**: these flows open no priced quantity box (it needs a mart /
  `PRICEDITEMLISTMENU`, whose only setter still dead-ends in a ret-stub). Still open,
  still unmasked, still expected to bite whoever goldens the mart.

**Revert-proof (both directions).** Synthetic: corrupting RunTMHMTest's seeded TM quantity
(1→7) went RED naming the exact fields, then was reverted:

```
WRAM: 25 mismatched fields:
  wBagItems wNumBagItems: want $0F | got $10
  wBagItems slot 0 item id: want $0B | got $CE
  wBagItems slot 0 quantity: want $03 | got $06
  ...
FAIL item_tm_teach: 25 unmasked divergences
```

And a live one nobody staged — the class's first run against master caught **F-16**:

```
WRAM: 12 mismatched fields:
  wPartyData mon 0 HP: want $00DE (222) | got $0122 (290)
  wPartyData mon 0 attack: want $008D (141) | got $005B (91)
  wPartyData mon 0 defense: want $0089 (137) | got $0031 (49)
  ...
FAIL item_stone_evolve: 12 unmasked divergences
```

| scenario | port flags | mGBA nav | pins |
|---|---|---|---|
| item_tm_teach | DEBUG_ITEMTM=1 | mirror the gate's seeds exactly (TM06 in bag slot 0 qty 1; mon-0 move slots 2-4 zeroed); START→ITEM→TM06→USE→mon 0→A through; dump after the "learned" text clears | wPartyData mon-0 moves/PP; wBagItems slot consumed |
| item_stone_evolve | DEBUG_ITEMSTONE=1 | mirror seeds (VULPIX + FIRE_STONE); use; A through the evolution | species/stats recalc; bag; wPokedex owned bit (NINETALES) |
| item_potion_use | DEBUG_ITEMUSE=1 | seed mon-0 HP=1; use POTION on mon 0; dismiss; close menu; dump | HP delta; POTION gone |

All three flows are RNG-free by construction. (`ball_catch` rides Stage 2 — it needs the enemy
spec.)

⚠ **Rectified**: the menu audit left **M-8 OPEN** — the priced quantity box is drawn wider
than its window exposes. It is in this stage's blast radius. Expect it to surface; **fail on
it, do not mask it.**

### Stage 2 — Battle convergence spec + scenarios (L)

- **`seed.enemy` spec**: wild **PIDGEY ($24 internal), level 13, DV bytes $98 $76**, stats via
  pret CalcStat (stat-exp 0), HP=MaxHP, status 0. Both sides run the **real loaders**, then
  overwrite only the RNG-derived parts (DVs→spec; stats recomputed; HP=MaxHP) and **assert**
  the loader-derived parts (species/types/catch rate/moves/PP from the real learnset) instead
  of writing them — so a loader regression still fails the diff.
- **`seed.force_encounter`**: `wGrassRate=$FF` + all 10 `wGrassMons` slots = (level 13, PIDGEY)
  → the encounter and slot rolls become outcome-independent of RNG.
- **mGBA scenarios**: Pallet → Route 1 grass; force_encounter; step until `wIsInBattle==1`;
  `wait_for_text("appeared")`; `scenario.exec(seed.enemy)`; then `battle_intro` (dump),
  `battle_menu` (A → FIGHT box visible → dump), `move_selection` (A on FIGHT → move list →
  dump). All dump points precede RNG consumption for battle outcomes.
- **Port**: `DEBUG_BATTLE_GOLDEN` (+ `_INTRO`/`_MENU` subflags, and `DEBUG_MOVEMENU` for the
  move list): PrepareNewGameDebug → seed enemy species/level → real InitBattle/LoadEnemyMonData
  → spec-DV overwrite + stat recompute + HP=MaxHP → real intro → dump. Keep the interactive
  `DEBUG_BATTLE`/`_LIVE` harness, but **de-REVERT its temp HP/PP values** to the spec numbers
  so live play matches.
- **Differ**: window **(10,3)**, no per-element projections (battle = uniform +10col/+3row —
  `docs/ui_projection.md`, "Battle — GB-centered"); battle WRAM regions leave
  `_NONBATTLE_WRAM_SKIP`; measure masks (pic VRAM areas, intro ▼).
- Then **`ball_catch`** (DEBUG_ITEMBALL=1, the deterministic MASTER_BALL path) as a
  `datastruct` scenario.

⚠ **Rectified**: the branch's note "if `MoveSelectionMenu` is mid-rework (menu-audit row 22),
gate `_MOVESEL` behind that row" is **stale — row 22 has landed.** The FIGHT sub-menu was a
bespoke loop in which three of pret's four labels did not exist; it now has pret's structure
and its load-bearing **1-based cursor**. The gate is `DEBUG_MOVEMENU`.

#### Stage 2 — DONE. How it actually converged (execution notes)

**Golden side.** `lib/battle.lua:enter_wild` is the shared flow: boot → seeded new game →
bedroom → walk to Route 1 (`EVENT_FOLLOWED_OAK_INTO_LAB` seeded first, or Yellow's Oak
catch-up cutscene fires at Pallet's `wYCoord==0`) → **seed at Route 1, not in the bedroom**
(seeding before the walk broke the very first step) → forced grass encounter (deterministic:
**frame 5259 every run**) → `wait_for_text("appeared")` → `seed.enemy` (asserts the
loader-derived parts, overwrites DVs → $98 $76, recomputes stats, HP=MaxHP). `battle_menu` /
`move_selection` continue with A → menu; `ball_catch` continues menu → ITEM → MASTER BALL →
catch flow (the "caught!" message holds a `<cont>` scroll-wait — the ▼-answering
`dialog_until_text` drives it), declines the nickname prompt with a retried **B** (the port's
AddPartyMon keeps the species-name default — its documented AskName stub), then **polls
`wBattleResult == 2` per frame** (UseBagItem's post-capture tail) and dumps that frame.

**Port side.** `RunBattleTest`'s `DEBUG_BATTLE_GOLDEN` branch (debug_dump.asm): the REAL
`InitBattle` → `LoadEnemyMonData`, then the spec-DV overwrite + `CalcStats` recompute (same
registers as the loader's own call), then the real intro (front pic, slide-in, intro box,
pokéballs — **no HUDs**: the GB first draws them at the battle menu). Subflags: `_INTRO`
dumps at the parked "appeared!" (▼ poked at GB (16,18)); `_MENU`/`DEBUG_MOVEMENU` run the
send-out (real `LoadBattleMonFromParty`) then the real `DisplayBattleMenu` /
`MoveSelectionMenu` and photograph at `AUTOKEY_DUMP_FRAME=300`; `DEBUG_ITEMBALL` presets
`wCurItem`/`wWhichPokemon` (the in-battle ITEM menu is still a stub), calls the real
`UseItem`, mirrors UseBagItem's post-capture tail, runs the real **`EndOfBattle`** (measured:
the golden's dump frame already has `.resetVariables` done — `wIsInBattle==0` was the
one-field first diff), and dumps. Combined flags compose in the Makefile:
`DEBUG_BATTLE_GOLDEN=1 DEBUG_ITEMBALL=1`.

**Masks (all measured, none lifted from expectations):** intro masks VRAM slots $00–$30
(golden's $8000-copy of the front pic; the port draws from the compared $9310 copy) +
$C0–$C8 (F-19 clone slots); menu/movesel mask the whole $8000 bank post-send-out (back pic +
POOF/slide anim streamed through it; measured golden slot 0x131 == port 0x131) + the F-19
slots + 6 tilemap cells (2,4)-(2,9) (gauge clone ids). One WRAM byte masked:
`wLetterPrintingDelayFlags` (sanctioned draw-layer divergence). `ball_catch` (datastruct)
passes with **zero WRAM masks**.

**RED proofs (the differ catches regressions through the masks):**
- battle_menu, organic (F-20): `TILEMAP: 1 mismatched cells (of 360) … ( 9,18) want $6D got
  $6C … FAIL battle_menu: 1 unmasked divergences` — a single-cell real bug surfaced with all
  masks live.
- ball_catch, organic (EndOfBattle timing): `WRAM: 1 mismatched fields: wBattleFlags
  wIsInBattle: want $00 | got $01 … FAIL ball_catch` — a single WRAM field through the
  datastruct class skips.
- battle_intro, synthetic: corrupting the ▼ poke ($EE→$00) → `FAIL battle_intro: 1 unmasked
  divergences`; reverted.

**Determinism:** all four goldens regenerated a second time → byte-identical
(`cmp` on .bin: battle_intro, battle_menu, move_selection, ball_catch).

### Stage 3 — Menu scenarios (L)

Differ support first: per-scenario key `"stride": 20` — the trainer card and pokédex draw
`W_TILEMAP` as a **stride-20 scratch** behind a full-screen window; port cell =
`row*stride + col`, window (0,0). Default stays 40. (The overworld dialog box needs the same
support — see the stride-20 correction above. One mechanism serves both.)

| scenario | port flags | mGBA nav | notes |
|---|---|---|---|
| options_menu | DEBUG_OPTIONS=1 | START→OPTION→wait "TEXT SPEED" | confirm the port's seeded defaults == the golden's InitOptions defaults; `wOptionsBlock` compared |
| trainer_card | DEBUG_TRAINERCARD=1 | new `seed.trainer_card(sym)` poking the gate's exact seeds (money BCD 123456, playtime 5:30, badges $A5, name RED) → START→name row→wait "BADGES" | stride 20; `wPlayerMoney` pins the BCD |
| pokedex_list | DEBUG_G1=1 | new `seed.pokedex(sym)` replicating the port's dex-bit pattern → START→POKéDEX→"CONTENTS" | stride 20; `wPokedex` pins the bits |
| pokedex_entry | DEBUG_G2=1 | from the list, choose the same mon the port gate draws → wait "HT"/"WT" | pic-area mask à la `_STATUS_MASKS` |
| naming_screen | DEBUG_NAMINGSCREEN=1 | new game → NEW NAME → grid visible → dump | match the gate's mode/page |

⚠ **Rectified — this stage's premises were the most damaged.** The original text told the
executor to *expect* divergences and mask them, citing the menu-fidelity plan as authority
for a list of "KNOWN" gaps. **Those gaps have since been FIXED** — rows 15–24 landed the
naming screen's prompt, the palette-register unification (M-62), the blinking ▼ (row 24), the
dex pages, and the PC screens. Carrying the old expectations forward would **mask corrected
behavior into the goldens as expected**, cementing the very bugs the audit removed.
**Measure every divergence from a first diff against master. Assume nothing is "known".**

**Deferred explicitly** (document, don't silently skip): main_menu (OakSpeech stub), save_menu,
link menus (TODO-HW serial), Hall of Fame (save-gated), standalone list_menu modes (dishonest
without a mart), all interactive sweep states (no input replay — out of scope per user).
**No longer deferred**: the PC screens — the audit's row 17 ported the PC spine
(players/oaks/league). But note **M-82 is OPEN**: `ActivatePC` is unreachable from the game,
so a PC golden needs its DEBUG gate, not an in-game route.

### Stage 4 — Cross-cut (S-M)

- **Makefile**: `FIDELITY_SCENARIOS_CORE` (the 6 + options_menu + trainer_card) /
  `FIDELITY_SCENARIOS_FULL`; `fidelity` runs core, `fidelity-full` runs all; new
  `goldens-verify` target (regen into a temp dir, diff vs committed = drift check).
- **Mask policy**: a mask owned by an open finding carries the finding id in its why-string;
  retiring a finding requires deleting its masks (grep-able).
- ~~**M-69 hardening (do this early — it invalidates every other verification).**~~ **DONE in
  the fold-back** (`8b018e84`): both runners now `mdel` the stale dumps
  (`goldencheck.sh:31`, `run_headless.sh:38`). See F-11.
- **Skill updates**: `faithfulness-review` step 3 — replace the hardcoded screen list with a
  subsystem→required-scenarios table (party/bag/dex/add_mon/item_effects → **datastruct
  scenarios even if the change renders nothing**; text printers / NPC dialog → sign_pallet).
  `build-and-debug` — GBSTATE v2 layout, the datastruct class, tiers.
- No new linker sections expected; if one appears, `link.ld` first (hard rule).

## Verification (every stage ends green)

1. `make -C dos_port fidelity` passes; `make goldens` ×2 byte-identical.
2. Revert-proofs per new capability — paste the red output into the stage notes, then revert.
3. `tools/lint_pret_labels` exit 0; `tools/faithdiff <Label>` for any pret-labeled routine
   touched.
4. One commit per stage, scoped; commit messages justify any faithdiff divergence.
5. **Delete `FRAME.BIN` from the image before every headless run** (F-11) — otherwise a run
   that crashes before dumping reads as a pass.

## Findings

Format: `### F-N. summary [OPEN | FIXED | SANCTIONED]`

### F-1. The "box-level residue" reconcile item was a non-issue [SANCTIONED]

Predicted that pret's `_AddPartyMon` might write **level** at party-struct offset 3 where
`seed.lua` writes 0. It does not: pret writes `xor a` → **0** on *both* struct paths
(`add_mon.asm:139`, `:158`), and the port mirrors it (`add_party_mon.asm:209,231`). The
`ld [de], a ; de = BoxLevel` at `add_mon.asm:433` that seeded the worry is in **`_MoveMon`**
(party→box), where storing the level is correct. All three sides already agreed.

### F-2. `DebugDumpMemory` now emits GBSTATE.BIN [FIXED — Stage 0]

`DumpGBState` was only reachable from `DumpBackbuffer` (the FRAME.BIN gates), so the
DUMP.BIN-only gates (`DEBUG_ITEM*`, `DEBUG_CALCSTATS`…) — precisely the datastruct flows Stage
1c wants — emitted no GB state. Hooked `call DumpGBState` at the top of `DebugDumpMemory`.

### F-3. `seed.lua` never ran `WriteMonMoves` — the golden party was one the game cannot produce [FIXED — Stage 1a]

The first WRAM diff failed on `wPartyData mon N moves/PP` for 4 of the 6 debug-party mons.
**The golden was the wrong side.** pret's `_AddPartyMon` copies the species' four *base-stats*
moves and then calls `predef WriteMonMoves` (`add_mon.asm:199`), which folds in the level-up
learnset; PP is written *after* that, from the **final** moves. `seed.lua` took only
`bs:byte(16,19)` and computed PP from those — so its level-80 PERSIAN knew
SCRATCH/GROWL/BITE/SCREECH instead of the real SCREECH/PAY_DAY/FURY_SWIPES/SLASH. The port was
right all along.

Fixed by implementing `mon_learnset()` and `write_mon_moves()` in Lua. **This is exactly the
blind spot the plan exists to close: the goldens passed 6/6 for months because party WRAM was
never compared.**

### F-4. Golden scenarios seeded less than their port gate does [FIXED — Stage 1a]

Every port gate that reaches a real screen calls `PrepareNewGameDebug` (party + bag + dex +
badges + money + identity), but each golden scenario seeded only what its own screen displayed.
Harmless while only the screen was compared; with WRAM compared it surfaced as ~40 divergences.
Added `seed.pokedex` / `seed.money` / `seed.badges` and the composite `seed.debug_new_game`.

### F-5. The `DEBUG_TRANSITION` gate's `wPlayerID` was an RNG roll [FIXED — Stage 1a]

`overworld_pallet`'s gate never seeded the player identity, so it compared the build-define
`PLAYER_NAME` against the golden's "RED" — and `wPlayerID` was whatever `InitPlayerData` rolled
from the RNG, i.e. **not reproducible between runs of the port itself**. Added
`SeedDeterministicPlayerIdentity` (guarded by `%ifdef DEBUG_TRANSITION`; it does **not** leak
into the normal boot path).

### F-6. Every sign in the game was a stub — `gen_map_headers.py` emitted zeros [FIXED — Stage 1b]

The generator wrote the map header's sign block as `times sign_count * 3 db 0`. The **count**
was right, so `wNumSigns` was right and `CopySignData` copied the right number of bytes — but
every sign's record was (Y=0, X=0, id=0). `SignLoop` compares the player's front-tile coords
against those, so **no sign in the game could ever match.**

Fixed: parse each `bg_event X, Y, TEXT_ID` and emit `db Y, X, id`, resolving the id **by name**
against the map's `<Map>_TextPointers` list — bg_events do follow the object_events in that
list, but nothing guarantees it, and a positional guess would silently mis-address a sign to
another sign's text.

**Why the harness caught it and nothing else did:** signs render nothing and crash nothing.
Walk up to one, press A, and the game just... does not respond. No visual artifact for a
screenshot, no fault for a debugger.

### F-7. `IsSpriteOrSignInFrontOfPlayer` was never ported — `SignLoop`/`DisplaySignText` were unreachable [FIXED — Stage 1b]

`SignLoop` (`src/home/hidden_events.asm`) and `DisplaySignText` (`src/home/overworld_text.asm`)
were both fully translated, both correct, and both **dead**: the pret routine that calls them
had no port counterpart, and `OverworldLoop`'s A-press path went straight to
`CheckNPCInteraction`. `hidden_events.asm` even carried an "INTEGRATION (future wire — this
routine has no live caller yet)" note. Nobody had wired it.

Ported (sign branch) beside its only caller. pret's routine does three things; the port
realizes them as two pret-named halves — this one (signs) and `CheckNPCInteraction` (the sprite
scan, which both detects *and* displays). pret's counter-tile range extension is the third and
stays unported (it needs mart/pokécenter counter tilesets).

### F-8. `<cont>` is a *waiting* text command — a headless text gate hangs on it [FIXED — Stage 1b]

The Pallet Town sign's stream is `PALLET TOWN <line> Shades of your <cont> journey await!`.
`<cont>` ($55) scrolls **and blocks on A/B**. A headless DOSBox-X run has no keyboard, so
`DEBUG_SIGNTEXT` parked there forever and `run_headless.sh` reported "crashed before the dump"
(killed by the timeout, not faulted).

Fixed as `DEBUG_ITEMTM` / `DEBUG_ITEMBALL` already handle their message waits: `DEBUG_SIGNTEXT`
implies `DEBUG_AUTOKEY -D AUTOKEY_APRESS` (+ `AUTOKEY_DUMP_FRAME ?= 999999`, so AutoKeyDrive's
own dump never pre-empts the gate's).

**Generalize before writing any future text scenario:** any golden whose dump point is past a
`<cont>` / `<para>` / `<prompt>` needs AUTOKEY on the port side and a matching button press on
the mGBA side, or it will hang rather than fail.

**Sub-item: "the sign path HANGS in `npc_dialog_wait_impl`" — REFUTED (`b99c0199`).** The
source note claimed it, and put the dump hook *before* the wait to dodge it. Re-tested on
master: **it does not hang.** `AUTOKEY_APRESS` *pulses* A (5 frames on, 15 off), so the wait's
release-check clears; master's own `DEBUG_TEXT=9` gate already drove `ShowTextStream` →
`npc_dialog_wait_impl` to completion. The hook now sits **inside** the wait, after the box is
staged, so the golden covers the printed dialog.

⚠ **The re-test itself nearly produced a third false comment, and the trap is worth naming.**
The first re-run produced no dump — "F-8 CONFIRMED", obviously. It was not. A `git stash` cycle
had left `assets/*.inc` **newer** than the `.py` generators that produce them, and `make assets`
is mtime-gated: it regenerated nothing, so the build mixed master's 0-based `npc_dialogs` with
the new 1-based `map_headers` and died before dumping. What exposed it was a **control run of
the known-good hook position, which also failed** — proving the variable under test was not the
variable that had changed. *Always run the control.* (Stale generated assets are a standing
hazard for every claim in this plan: after any stash/rebase, run the generators directly rather
than trusting `make assets`.)

### F-9. ~~The port's overworld dialog box has the wrong geometry AND line spacing~~ [WITHDRAWN — MISDIAGNOSIS]

**This finding was wrong, and it wrongly blocked Stage 1b for a full session.** It claimed the
port's dialog box sat at canvas row 6 instead of 12, with its two text lines *adjacent* (rows
7/8) where the GB leaves a blank row between them (14/16) — and concluded that
`src/home/text.asm`'s line advance was off by a factor of two, so *"every multi-line dialog in
the game"* would diverge.

**None of that is true. The dump was read at the wrong stride.** The overworld dialog scratch
is deliberately **GB-shaped, stride 20** (`msgbox_dialog` → `dd 20 ; MB_STRIDE`), so
`MB_LINE1` (flat 281) and `MB_LINE2` (flat 321) are **40 bytes = two rows of a 20-wide grid**
apart — the GB's exact 14/16 spacing. Read as a 40-wide canvas they *look* adjacent. Likewise
"box at row 6": flat 240 is row 12 of a stride-20 scratch, row 6 of a stride-40 one.

Confirmed independently from **rendered pixels** (FRAME.BIN, `DEBUG_LEARNMOVE`, counting ink per
8-px band): the box occupies pixel-rows 15–20, with `top border | blank | text | blank | text |
bottom border` — a blank row *between* the text lines, as the GB does.

Nothing in `text.asm` needed to change. `sign_pallet` was writable the whole time.

**The lesson is the one this project keeps re-learning**: the finding *felt* rigorous — it had a
table, two measured coordinates, and a mechanism. It was a confident claim built on an unchecked
assumption about a stride. **Measure the rendered output, not the buffer, when the buffer's
shape is itself in question.**

### F-10. Port text id 0 meant both "the first text pointer" and "no text" — 7 signs were silently swallowed [FIXED — fold-back]

Found while folding this branch into master, and **not caught by any golden**.

pret's text ids are **1-based**: `def_text_pointers` is `const_def 1`
(`macros/scripts/maps.asm:238`), and `DisplayTextID` subtracts one **at the lookup**
(`home/text_script.asm`):

```
.skipSpriteHandling
	dec a          ; ids are 1-based; pret subtracts 1 HERE
	ld e, a
	add hl, de
	add hl, de     ; hl = TextPointers + 2*(id-1)
```

The port folded that `dec a` into the **generator** (`port_id = pret_id - 1`) instead of the
lookup — while `DisplaySignText` still used pret's 1-based `test eax,eax / jz .done` sentinel.
So **id 0 meant both "the map's first text pointer" and "no text"**, and 7 signs resolved to
index 0 and were silently swallowed: the font loads, the box never draws, the A-press is
consumed. (`CeladonMansion2F`, `CeladonMansionRoof`, `CeladonMartElevator`,
`RocketHideoutElevator`, `Route5`, `Route7`, `SilphCoElevator`.) Pallet's sign is not among
them, which is exactly why Stage 1b's gate passed and the bug stayed invisible.

**It was two bugs on the same 7 maps.** Those maps are precisely the maps with **zero
object_events** — a sign only reaches index 0 if no NPC precedes it — and `gen_npc_dialogs`
bailed out (`npc_count == 0` → no table emitted at all), so `DisplaySignText` died at the
*null-table* check before ever reaching the index. **The `-1` alone fixes nothing on them.**

Fixed by restoring pret's numbering: the generators emit pret's 1-based id verbatim, and **all
three** consumers absorb the `-1` at the lookup (`lea edx, [eax*8 - 8]` — same single
instruction), mirroring pret's `dec a`:

- `CheckNPCInteraction` (`map_sprites.asm`)
- `TrainerEncounterFlow` (`map_sprites.asm`) — **the easy one to miss**; skip it and every
  trainer's pre-battle line shifts by one
- `DisplaySignText` (`home/overworld_text.asm`)

…plus the `gen_npc_dialogs` guard that emits a table for sign-only maps. **All of it lands in
one commit — there is no safe intermediate state** (a `-1` in only some consumers makes slot-0
NPCs compute `[table - 8]` and read a bogus stream pointer).

Verified game-wide before touching code: all **943** `object_event`s and all **203** `bg_event`s
satisfy `pret_const == index + 1`, no exceptions; max id is 25, under `LoadSprite`'s `and $3f`
ceiling of 63. pret ORs the TRAINER/ITEM flags onto the *1-based* id too
(`macros/scripts/maps.asm:16`), so this makes the port's map-object bytes **byte-identical to
the ROM** rather than breaking the mask.

**Adjacent, pre-existing, NOT fixed here:** `ViridianMart`'s script table opens with three bare
`dw` rows before its `const_def 4`, and both generators' `dw_const`-only parsers stop at the
first one — so its three NPCs emit stub text. A generator assert now *surfaces* it rather than
letting it stay silent.

### F-11. A build can ship a stale `FRAME.BIN`, so a run that crashes before dumping reads as a PASS [FIXED — fold-back, `8b018e84`]

(= **M-69** in the menu-fidelity ledger; hit independently by both sessions.)

`PKMN.IMG` carries a `FRAME.BIN` baked in from a previous build. A headless run that crashes
*before* dumping leaves that old frame in the image; `mcopy` pulls it out, and the capture looks
like a clean success — **a silently passing test of nothing.** It bit the text-engine session (a
crashing case returned a plausible-looking overworld frame).

Mitigation — delete it from the image copy before every run, so a found frame is definitionally
fresh:

    mdel -i "$SCRATCH/pkmn.img@@1048576" ::FRAME.BIN 2>/dev/null || true

Belongs in `goldencheck.sh` **and** `run_headless.sh`. **This is a tooling hazard for every
verification in this plan** — until it lands, no "the harness dumped and it looked right" claim
is trustworthy.

Landed in both runners, and widened while landing: the runner deletes `GBSTATE.BIN` and
`DUMP.BIN` too, not just `FRAME.BIN`. All three are stale-able, and `goldencheck` diffs
`GBSTATE.BIN` — the one file whose staleness would produce a *confident wrong verdict* rather
than a missing artifact.

### F-12. A gate that seeds coords bypasses collision — so the port read the sign from a tile no player can stand on [FIXED — Stage 1b]

`DEBUG_SIGNTEXT` originally seeded `(Y=10, X=7)` facing UP: the tile directly *below* the Pallet
sign (`bg_event 7, 9`). It printed the sign text perfectly. It is also **a tile the game will not
let you occupy** — the step below the sign is a flower (tile `$03`, absent from `Overworld_Coll`,
`data/tilesets/collision_tile_ids.asm`), so it is solid.

Nothing in the port objected, because `EnterMap` writes `wYCoord`/`wXCoord` directly and the sign
check only looks at the tile *in front of* the player. The golden is what objected: mGBA has to
**walk** there, and the walk blocked. The reachable reading tile is **(Y=9, X=8) facing LEFT**.

The lesson generalizes past this gate: **a debug gate that hand-seeds player state can park the
game in a state the game cannot reach**, and everything downstream will look fine. Its golden is
the only thing that will ever notice — which is an argument for goldening the gates, not for
trusting them. The gate now takes `SIGNTEXT_DIR` alongside `SIGNTEXT_MAP/Y/X`, and defaults to
the reachable tile; `scenarios/sign_pallet.lua` walks to the same one.

### F-13. The stride-20 dialog scratch overlaps the block-aligned map mirror in `wTileMap` [OPEN — invisible today, load-bearing if anything reads the mirror back]

(M-29 family: "the party panel and the dialog share a staging buffer".)

The overworld dialog is drawn into a **GB-shaped stride-20 scratch** at `W_TILEMAP + 12*20`
(`msgbox_dialog`, `src/home/text.asm`) and *displayed* from `GB_TILEMAP1` via
`sync_dialog_window`. But `W_TILEMAP` is also the port's **40-wide block-aligned map mirror**.
Flat bytes 240..359 — the six stride-20 dialog rows — are canvas rows 6..8 of that mirror. The
two structures occupy the same bytes.

It is invisible on screen: `render_bg` draws from the tile surface, not from the mirror, and the
dialog is composited from `GB_TILEMAP1`. `sign_pallet` sees it exactly once, as golden row 0
landing on canvas row 8 (masked, with this justification). But anything that **reads the mirror
back while a dialog is open** — `SaveScreenTilesToBuffer`, a screen-restore path — reads dialog
bytes where it expects map. Fix belongs with the mirror/staging cleanup, not here.

### F-14. The port shows a ▼ where the GB shows none: `done`-terminated text has no arrow [OPEN]

`npc_dialog_wait_impl` (`src/engine/overworld/map_sprites.asm`) unconditionally places
`CHAR_DOWN_ARROW` into `GB_TILEMAP1` before waiting for A. The GB does not.

pret draws the ▼ from the **text commands** — `cont`/`prompt` (the page breaks) — and
`WaitForTextScrollButtonPress` (`home/joypad2.asm`) only *blinks* an arrow that is already there:
its `HandleDownArrowBlinkTiming` off-branch (`home/window.asm:246`) returns immediately while
`hDownArrowBlinkCount1` is 0, which is exactly what the function seeds. So a stream ending in
`done` — `_PalletTownSignText` is one — parks in a box with **no arrow at all**, just waiting for
A. Measured: 1800 frames on the golden, no ▼ anywhere in `wTileMap`.

`sign_pallet` cannot catch this: the port's arrow goes to `GB_TILEMAP1`, which is not a compared
region (the port's own `wTileMap` correctly has none — that is why the scenario passes 360/360).
The fix is to make the arrow a property of the *text command*, as in pret, rather than of the
wait. Do it with the `cont`/`prompt` work, and add `GB_TILEMAP1` to the compared regions so the
golden can see the window layer at all.

### F-15. All three item gates were dumping NOTHING — the `=160` hardcode exited the program before the capture ran [FIXED — Stage 1c groundwork]

M-120 said the hardcoded `-D AUTOKEY_DUMP_FRAME=160` made the gates' dump frame
*non-overridable*. That undersold it. **The frame it was pinned to was also wrong, and the gates
were not capturing at all.**

`AutoKeyDrive`'s own `FRAME.BIN` dump **exits the program**. `DEBUG_ITEMTM` / `DEBUG_ITEMSTONE` /
`DEBUG_ITEMBALL` are `DUMP.BIN` gates (`NEED_DEBUG_DUMP := 1`) whose capture runs long — past the
message waits, past the evolution, past the throw. Pinned at 160, AutoKeyDrive fired **first**,
wrote a `FRAME.BIN` and quit, and `DebugDumpMemory` never ran. Measured, `run_headless.sh` (which
deletes stale dumps first, so a produced file is definitionally fresh):

| gate | `AUTOKEY_DUMP_FRAME=160` (the old effective default) | `=999999` |
|---|---|---|
| `DEBUG_ITEMBALL` | `FRAME.BIN`, `GBSTATE.BIN` — **no `DUMP.BIN`** | `DUMP.BIN` (576 B) ✅ |
| `DEBUG_ITEMTM` | `FRAME.BIN`, `GBSTATE.BIN` — **no `DUMP.BIN`** | `DUMP.BIN` (576 B) ✅ |
| `DEBUG_ITEMSTONE` | `FRAME.BIN`, `GBSTATE.BIN` — **no `DUMP.BIN`** | `DUMP.BIN` (576 B) ✅ |

`DEBUG_ITEMBALL`'s comment said this all along — *"AutoKeyDrive's own FRAME.BIN dump exits the
program … so push it out of the way here"* — directly above a line that did the opposite. The
comment was right and the code was wrong, which is the **inverse** of this project's usual defect
and worth noticing: the lesson is not "distrust comments", it is **measure**. Default is now
999999 on all three.

**Consequence for Stage 1c, and it is a good one:** its three scenarios are not being added to a
working harness — they are the first thing that will ever have *observed* these gates. Any
"expected" value taken from a pre-fix `DUMP.BIN` is worthless, because there were none.

### F-16. Post-evolution stat recalc read the NEXT species' base stats — NINETALES got JIGGLYPUFF's [FIXED — Stage 1c]

Found by `item_stone_evolve`'s **first run**, minutes after the class could see WRAM. The
port's `TryEvolvingMon` (`src/engine/pokemon/evolution.asm`) resolved the evolved species'
dex number as `IndexToPokedex[species-1]` and then ran `inc al` under the comment
*"0-based → 1-based dex num"*. **The table already stores pret's 1-based dex number** —
the generator says so (`gen_base_stats.py`), and every other consumer decrements after the
lookup (`GetMonHeader`, the dex-flag site 100 lines below, `home/pics.asm`). So the
`wMonHeader` copy indexed one full record past: a FIRE_STONE VULPIX→NINETALES evolution
recalculated stats from **JIGGLYPUFF** (dex 39) base stats — measured 290/91/49/48/54 at
L80 where the golden (real game) says 222/141/137/176/174. Types/species/catch-rate were
right (different code paths); only the stat recalc was poisoned, so nothing on screen
looked wrong enough to notice.

Fixed by deleting the `inc al`. Golden-verified: `item_stone_evolve` PASSes, WRAM clean.

Two morals, both this project's recurring ones: **the comment was confident and wrong**
(the correct basing was documented in three other places), and **no screen render could
have caught it** — the stats are only ever *displayed* after other code recomputes or
copies them; only a WRAM datastruct diff against ground truth sees the poisoned bytes the
moment they are written.

### F-17. The port drew the enemy HUD during the wild-battle intro — the GB draws NO HUDs there [FIXED — Stage 2]

`DrawBattleIntroBox` (`src/engine/battle/init_battle.asm`) called `DrawEnemyHUD` as part of
the intro. pret's intro is `PrintBeginningBattleText` — cry + `DrawAllPokeballs` +
"Wild X appeared!" — and **both HUDs are first drawn by `DisplayBattleMenu` →
`DrawHUDsAndHPBars`** (core.asm:1886). The golden's intro rows 0–3 are blank; the port's
held a full enemy name/level/HP bar. Fixed by deleting the call (the battle_intro golden is
the regression guard).

### F-18. The player HUD's $73 connector was drawn AFTER the HP bar — pret draws it before, and the bar cap overwrites it [FIXED — Stage 2]

pret `DrawPlayerHUDAndHPBar` places the (18,9) `$73` right after `PlacePlayerHUDTiles`, then
`predef DrawHP` **overwrites it with the bar's right cap $6D** — the second `$73` is dead
the moment the bar draws. The port drew frame + connector last, leaving `$73` where the
golden shows `$6D`. Fixed: frame first, bar last, like pret (`battle_hud.asm:DrawPlayerHUD`).

### F-19. The enemy-gauge palette clones were parked on LIVE glyphs — including the battle ▼ [FIXED — Stage 2]

The colorization work clones the nine gauge patterns ($63–$6B) into vFont slots so the enemy
bar can bind its own palette. The slots picked ($EC/$EE/$EF/$F0/$F1/$F4) were **live charmap
glyphs** — $EE is the ▼ prompt itself, so every battle dialog's arrow rendered as a gauge
segment. Moved to **$C0–$C8**: the charmap maps NOTHING in $C0–$DF, so no text can reference
them (`battle_hud.asm:enemy_hp_tile_ids` + `gen_palettes.py`, kept in sync by comment).
Masks carrying the F-19 id: the $C0–$C8 vram mask (all battle scenarios) and the
(2,4)-(2,9) tilemap mask (menu/movesel). Retiring the per-cell-palette mechanism deletes
this finding's masks.

### F-20. The player HP bar's right cap was $6C (Pokémon-menu variant) — battle always uses $6D [FIXED — Stage 2]

pret `DrawHPBar` picks the cap from `[wHPBarType]`: the player battle bar is **always type 1**
(`DrawHP`, core.asm:5015, core.asm:687) → cap `$6D`; the enemy bar **always type 0**
(core.asm:2034/4897/686) → `$6C`. The port's shared `HPB_END equ 0x6C` was the menu/enemy
value for both. The port's helper split (player/enemy) maps 1:1 onto pret's type split, so
the cap is now per-helper (`HPB_END_PLAYER $6D` / `HPB_END_ENEMY $6C`). Found as the last
single cell of the battle_menu first diff — `( 9,18) want $6D got $6C`.

### F-21. The HUDs never staged wLoadedMon, and drew enemy-first [FIXED — Stage 2]

pret's `DrawPlayerHUDAndHPBar` copies the battle mon into `wLoadedMon` (species..DVs, then
level..PP — core.asm:1903-1910) and `DrawEnemyHUDAndHPBar` then overwrites `wLoadedMonLevel`
with the **enemy's** level (core.asm:1969-1970); `DrawHUDsAndHPBars` draws **player first**
(core.asm:1886), so the surviving level byte is the enemy's. The port staged nothing and drew
enemy-first. Invisible on screen; the battle_menu golden's `wLoadedMon` region caught all 14
bytes. Both the staging and the order are now pret's (`battle_hud.asm`), with the
order-is-load-bearing note at the call site.

## Imported open findings from the menu-fidelity audit

That audit closed with ~20 `M-` findings filed OPEN against files outside the rows that found
them. The ones that touch this plan:

- ~~**M-69**~~ — stale `FRAME.BIN` → a failed dump reads as a pass. Adopted as **F-11** and
  **FIXED** (`8b018e84`); both runners delete the stale dumps. The menu ledger still tags it
  `[OPEN — tooling]` — it is not. Do not re-file it.
- **M-8** — the priced quantity box is drawn wider than its window exposes. Stage 1c's blast
  radius. Note it is **unreachable today** (the only `PRICEDITEMLISTMENU` setter dead-ends in a
  ret-stub), so it may not surface until the Pokémart lands; **fail on it, don't mask it.**
- **M-29** — the party panel and the dialog box share a staging buffer and collide. Any
  scenario that shows both. (Row 11 closed it *for the party screen* via the `msgbox_party`
  projection; the shared-buffer root cause is what remains — and it is the same root cause as
  **F-13**.)
- **M-59** — the text encoder has no longest-match pass, so apostrophe ligatures encode wrong.
  Row 15 **worked around** the one live instance with a raw `APOS_S = 0xBD` byte; **the encoder
  gap itself is open**, so any *new* generated string containing `'s`/`'d`/`'l`/`'t`/`'v`/`'r`/
  `'m` is silently mis-encoded — including one written for a golden's expected text.
- **M-32** — `PlayCry`'s ret-stub hides a real blocking contract (pret's `PlayCry` ends in
  `WaitForSoundToFinish`). Relevant to battle-intro timing (Stage 2). Per the menu ledger this
  is **two direct translations, not an audio project** — everything it needs is already linked.
- **M-82** — `ActivatePC` is unreachable from the game (guarded out behind a stale
  `%ifdef M72_OVERWORLD_TEXTSCRIPTS`); a PC golden needs its DEBUG gate, not an in-game route.
- **M-113** — `ClearScreenArea` is **not stride-aware**: hardwired to `SCREEN_WIDTH` (40) while
  `TextBoxBorder`/`PlaceString`/the cursor all honour `text_row_stride`. **Stage 3's blast
  radius** — it is exactly the stride-20 screens (trainer card, pokédex) that cannot call it.
- **M-120** — `AUTOKEY_DUMP_FRAME` was a hardcoded `=160` that a passed value only *enabled*,
  never overrode. Row 24 fixed its own gate and flagged the rest. **Verified against master
  2026-07-14 — the hardcode is still live in all three of Stage 1c's gates, plus Stage 2's
  `ball_catch`:**

  | Makefile line | gate | effect |
  |---|---|---|
  | 573 | `DEBUG_ITEMBALL` | `AUTOKEY_DUMP_FRAME ?= 999999` … then `-D AUTOKEY_DUMP_FRAME=160` |
  | 599 | `DEBUG_ITEMSTONE` | same |
  | 616 | `DEBUG_ITEMTM` | same |

  The `?=` was **dead** — the literal `160` on the next line won, so `make DEBUG_ITEMTM=1
  AUTOKEY_DUMP_FRAME=400` silently still dumped at frame 160. **FIXED (this commit)** — all three
  now read `?= 999999` + `-D AUTOKEY_DUMP_FRAME=$(AUTOKEY_DUMP_FRAME)`, as `DEBUG_ITEMUSE`
  already did. See **F-15**: the default had to change too, and the reason is worse than M-120.
  (Still carrying the old hardcode, outside this plan's scope: `DEBUG_TEXT` 697,
  `DEBUG_LISTMENU_QTY` 719, `DEBUG_CHANGEBOX` 835.)
