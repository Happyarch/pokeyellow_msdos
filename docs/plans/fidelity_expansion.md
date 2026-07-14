# Fidelity-harness expansion — WRAM datastructs, streamed text, battle, more menus

> **STATUS — OPEN.** Planned 2026-07-13 in the `worktree-fidelity-expansion` worktree;
> **folded back into master 2026-07-14** and rectified against it in the same pass.
> Stages 0 and 1a are DONE; 1b is partly done (see the ledger). Work stage-by-stage,
> update the Coverage table, append findings, commit per stage.
>
> Skills to load before starting: `build-and-debug` + `faithfulness-review` (always),
> `asm-translation` (before touching `debug_dump.asm`), `project-conventions`.

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

`make fidelity` covers 6 scenarios (status_p1/p2, start_menu, overworld_pallet, party_menu,
bag_menu). Before this plan it compared only tilemap cells, VRAM tile slots, and OAM.
Proven blind spots:

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
- The bag_menu golden **masked** a real bug (missing ▼ blink) instead of failing it.

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
  `FIDELITY_SCENARIOS := status_p1 status_p2 start_menu overworld_pallet party_menu bag_menu`.
  ✅ holds (the old line citations were stale and are dropped).
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
| 0 | Groundwork: box-level reconcile, DebugDumpMemory→GBSTATE hook, scenario ids | DONE | | box-level was a non-issue (F-1); hook verified on DEBUG_ITEMTM; +`tools/run_headless.sh` |
| 1a | GBSTATE v2 + WRAM regions end-to-end (existing 6 scenarios) | DONE | | v2 is SELF-DESCRIBING (design change, below); found 3 real harness bugs (F-3/F-4/F-5); fidelity 6/6 green |
| 1b | `sign_pallet` streamed-text scenario | **DONE** | | the port could not read a sign AT ALL (F-6 data, F-7 code) — both fixed. Plus **F-10** (text-id-0 collision) and **F-12** (the gate stood on an unreachable tile), both found during the fold-back. Golden passes 360/360 tilemap cells incl. the whole dialog box; `make fidelity` 7/7. **Never was blocked**: F-9 was a misdiagnosis, F-8 does not reproduce. New OPEN findings it surfaced: **F-13** (scratch/mirror overlap), **F-14** (▼ after `done`). |
| 1c | Item datastruct scenarios ×3 | TODO | | |
| 2 | Battle convergence spec + battle_intro/battle_menu/move_selection + ball_catch | TODO | | |
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

- `make fidelity` **6/6 PASS**, each reporting `WRAM: OK (8 regions, 5 skipped)` (the 5 skips
  = `_NONBATTLE_WRAM_SKIP`, retired by the Stage 2 battle scenarios).
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

### Stage 1c — Item datastruct scenarios (M)

New differ scenario **class `datastruct`**: compares only WRAM regions; tilemap/vram/oam
skipped with a class-level why ("the dump point is a post-flow WRAM gate; transient message
frames are timing-coupled — rendered-text fidelity is owned by the menu/dialog scenarios").
Port gates exist and emit GBSTATE via Stage 0.

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
- **M-69 hardening (do this early — it invalidates every other verification).** See F-11.
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

## Imported open findings from the menu-fidelity audit

That audit closed with ~20 `M-` findings filed OPEN against files outside the rows that found
them. The ones that touch this plan:

- **M-69** — stale `FRAME.BIN` → a failed dump reads as a pass. Adopted above as **F-11**.
- **M-8** — the priced quantity box is drawn wider than its window exposes. Stage 1c's blast
  radius.
- **M-29** — the party panel and the dialog box share a staging buffer and collide. Any
  scenario that shows both.
- **M-59** — the text encoder has no longest-match pass, so apostrophe ligatures encode wrong.
  Affects any golden whose expected text contains one.
- **M-32** — `PlayCry`'s ret-stub hides a real blocking contract. Relevant to battle-intro
  timing (Stage 2).
- **M-82** — `ActivatePC` is unreachable from the game; a PC golden needs its DEBUG gate.
