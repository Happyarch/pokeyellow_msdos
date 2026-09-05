# Current Plan: pret upstream merge (2026-09-02 commits)

## Execution record (2026-09-04, root r-e4c1a68d89f9)

Executed end-to-end. Merge `7100b398b`, `make compare` green (hashes unchanged).
Slices 2-6 landed via 5 parallel peers (disjoint scopes, no clobbering — verified
via `git status` + per-file diff review). Gates: `make assets` 0,
`update_label_db` 0, `lint` 0/0 both modes, `static_gate` 8/8 PASS, `faithdiff`
exit-profile byte-identical to pre-change baseline on all 8 touched labels,
core fidelity 16/16 PASS. Slices proven byte-neutral at object level: 672 `.o`
compared timestamp-masked, all code sections identical (only 2 symtab label
deletions + 1 `T_SPACE` equ).
`fidelity-full`: 85/105, 20 hangs (timeout, no GBSTATE) proven PRE-EXISTING —
fail identically at pre-session baseline `1e0b15fac` in a clean worktree; filed
as `regression-fidelity-20-scenarios-hang-pre-existing` (suspect post-08-22
input/autokey path). Companion: `assets/battle_menu_runtime_strings.inc` is a
stale orphan with no make rule yet `%include`d by `debug_dump.asm:9337` — fresh
trees cannot build. Slice 4/6 committed no tracked files (generated-only /
byte-identical regen). Orphan `cerulean_trade_house_blk.inc` removed post-regen.

## Objective

Integrate the two pending upstream pret/pokeyellow commits on **both** branches
(`master` 2f25a18de→e89ead15, `symbols` 02fc33021→573535d7) and propagate every
label/constant/generator consequence port-side. Merges are conflict-free by
construction (measured 2026-09-04: our side touched **zero** pret paths since
2f25a18de); the work is all port-side follow-through.

## Background evidence (measured 2026-09-04, three explore slices)

- **Pending commits, master** (`ahead_by 2, behind_by 0` — fetch is FF):
  - `e9feb04` #165 "Add FightDebugMenu labels and battle class constants" (11 files,
    +1635/-1587): splits `engine/debug/debug_menu.asm` (keeps 71-line dispatcher,
    `jp z, FightDebugMenu`) into new `engine/debug/fight_debug_menu.asm` (+892)
    and `engine/debug/set_box_debug_menu.asm` (+726, verbatim + 2 BUG comments);
    renames 70 labels `TestBattle`/`Func_fe*`/`Text_fe*`/`Data_fe*` →
    `FightDebugMenu.*` (full 70-row table held by the investigation; same addresses,
    byte-identical); `ram/wram.asm` +`wPlayerBattleStatusEnd` ($D064) /
    +`wEnemyBattleStatusEnd` ($D069) zero-size aliases; uses (not adds)
    `WILD_BATTLE`/`TRAINER_BATTLE`/`LOST_BATTLE` in `init_battle.asm` + 4 scripts.
  - `e89ead1` #166 "Add some constants, minor cleanup" (20 files, +24/-27):
    +`TRADE_DATA_SIZE` (`constants/script_constants.asm`, = 14) used in
    `data/events/trades.asm` + `engine/events/in_game_trades.asm`; removes 3 dead
    local labels; `wTitleMonSpecies`→`wUnusedTitleMonSpecies`; ~15 symbolic-literal
    swaps (`$7f`→`' '`, `$8`→`PLAYER_DIR_UP`, `$e`→stride, …) all assembling
    identically; deletes unused intro moves; renames `CeruleanTradeHouse.blk`→
    `CeruleanMelaniesHouse.blk` (0/0).
- **Sole behavior change in range: `data/text/text_8.asm`.**
  `text "sed because of"` → `db "osed because of"` (byte `$00`→`'o'`), `_YELLOW_VC`
  build only. Everything else is rename/comment/symbolic.
- **`symbols` branch is a 6-file artifact branch** (`pokeyellow{,_debug,_vc}.{map,sym}`
  only — verified via `git ls-tree`). Its 2 commits touch generated files only.
  **NEVER merge it into `master`** (would delete the tree). Fetch-FF the pointer
  and use it as (a) rename-table reference, (b) committed-`.sym` input for
  `gen_pret_ram.py`.
- **Port impact summary:** debug-menu port mirror is a deliberate `ret` stub
  (`dos_port/src/engine/debug/debug_menu.asm:1-49`) — **no port symbol renames**,
  only stub-header prose + 99 `missing` DB rows flipping names on rescan.
  Everything else lands as: constant swaps at ~10 literal sites, 2 local-label
  deletions in `src/home/overworld.asm`, 4 generator reruns (one needs a code
  touch: `gen_trades.py` hardcodes the stride), `pret_ram.inc` regen via fresh
  `.sym`, comment-only syncs.
- **Tooling verdicts (measured, durable):** NASM port → `label_status
  --callers/--callees` primary + `dos_port/tools/asm_lsp_mcp/server.py --refs/--def`
  secondary; **rgbds-lsp has NO find-references capability** (only def/symbols/hover
  via `tools/rgbds_lsp_mcp/server.py`) — do not prescribe it for callers; Python
  tools → `rg` + read-only sqlite on `translation.db` (no LSP exists). Use
  hound `smart_fetch` (not webfetch) for any further GitHub reads.
- **Regressions queried:** `memory_search regression pret/faithfulness` done
  pre-plan; each slice re-queries `memory_search regression <area>` before editing
  per AGENTS.md checklist.

## Slice 0 — Fetch + pre-merge verification (ROOT, serial, prerequisite)

- [x] `git fetch upstream` (writes only remote-tracking refs; safe any time)
- [x] Re-verify: `git merge-base --is-ancestor e89ead15` post-fetch topology,
      `git diff 2f25a18de..HEAD -- engine home constants data ram maps scripts includes.asm`
      still empty (no port-side pret edits since base — was empty 2026-09-04)
- [x] Re-verify live tips equal the investigated SHAs (`e89ead15`, `573535d7`);
      if upstream moved again, re-run the enumerator slice before proceeding
- [x] Confirm `symbols` tip tree is still 6 files (`git ls-tree --name-only upstream/symbols`)

## Slice 1 — Integrate pret tree + byte-identity gate (ROOT or worker A, after Slice 0)

- [x] Merge `upstream/master` into `master` (expect: touches pret paths only, zero
      conflicts; abort on ANY conflict and report — it contradicts the measured premise)
- [x] `make compare` at root (sha1 gate over `pokeyellow.gbc`/`_debug.gbc`/`.patch`;
      #165/#166 are byte-identical except the one VC text byte, so ROM hashes change
      only if RGBDS rebuilds deterministically pick it up — record old vs new hashes
      in the merge commit message either way)
- [x] FF-update local `symbols` pointer (`git fetch` already did; do NOT merge it anywhere)
- Claim: none (root owns the merge) + notify holders of nearby files if touched

## Slice 2 — Debug-menu stub sync (worker B, parallel after Slice 1)

Scope: `dos_port/src/engine/debug/debug_menu.asm`, `translation.db` (rescan — serialized, see Slice 7).
- [x] Update stub header prose (`:6-23` "98 of those 99" counts, `:41` label list):
      `TestBattle`→`FightDebugMenu`, `Func/Text/Data_fe*`→`FightDebugMenu.*`
- [x] Decide `DEBUG_TESTBATTLE` flag fate: port-only gate (`core.asm:125,1305`,
      `Makefile:5265`); upstream rename did not touch the bit (`BIT_TEST_BATTLE`
      unchanged). Default: KEEP as-is, note in commit message. Escalate only if the
      merged pret `core.asm` hunks show otherwise (read them first).
- [x] Sync `core.asm` TestBattle-stepper comments (`:981-1351,3826`) against merged
      pret `engine/battle/core.asm` hunks — comment-only expected; the stepper block
      itself is port `_DEBUG` scope, out of rename blast radius (verify, don't assume)
- [x] `label_status --callers FightDebugMenu` → expect `missing`, 0 port callers;
      `label_status --callers TestBattle` → expect gone from DB after rescan
- [x] Gate: `lint_pret_labels` + `--strict-claims` exit 0; `faithdiff` N/A (stub, no body)
- For分配: NASM queries via `label_status`; `--refs` via `asm_lsp_mcp/server.py` if needed

## Slice 3 — Battle constants into code (worker C, parallel after Slice 1)

Scope: `dos_port/src/engine/battle/init_battle.asm`, `draw_hud_pokeball_gfx.asm`,
`effects.asm`, `experience.asm`, `core.asm` (literal sites), `dos_port/src/scripts/`
(MtMoonB2F, PokemonTower7F, RocketHideoutB4F, SilphCo11F mirrors),
`dos_port/include/gb_constants.inc` (verify-only), `tools/generators/gen_trades.py`
(code touch), `assets/script_constants.inc` + `assets/trades.inc` (regen).
- [x] `init_battle.asm:206` `2`→`TRAINER_BATTLE`, `:226` `1`→`WILD_BATTLE`,
      `:448` `cmp …,2`→`TRAINER_BATTLE` (constants PRESENT but UNUSED at
      `gb_constants.inc:480-482` — wire them, don't redefine)
- [x] Audit + convert every other `$1/$2`-of-`wIsInBattle` literal site
      (`draw_hud_pokeball_gfx.asm:342`, `effects.asm:1192-1237`,
      `experience.asm:254-256`, `core.asm` sites) — `label_status --callers` each
      touched label first (asm-lsp `--refs` secondary); `faithdiff <Label>` per
      touched routine, justify added/dropped calls in commit message
- [x] 4 script mirrors: `cp $ff`→`LOST_BATTLE` where pret did (read merged pret
      scripts first; scripts are Tier-2 tool-seeded, hand-editable)
- [x] `TRADE_DATA_SIZE`: confirm `gen_script_constants.py` picks it up automatically
      (generic DEF parser) → regen `assets/script_constants.inc`; **code-touch**
      `gen_trades.py` (`:69` hardcoded `NAME_LENGTH=11`, `:145` stride comment) to
      honor the DEF instead of the literal; `in_game_trades.asm:114` `mov bx,0xe`→
      `TRADE_DATA_SIZE`; `data/events/trades.asm:6-9` carrier comment sync
- [x] Gate: `faithdiff` on all touched routines; `lint_pret_labels` 0; battle tier goldens

## Slice 4 — WRAM renames + `.sym`-driven regen (worker D, parallel after Slice 1)

Scope: `dos_port/assets/pret_ram.inc` (generated), `gb_memmap.inc` (verify-only),
`dos_port/src/engine/movie/title_rb.asm` (mirror check), battle-init FillMemory lengths.
- [x] Find the `pret_ram.inc` regen target (UNVERIFIED: no Makefile rule found in
      survey — `rg pret_ram.inc dos_port/Makefile`). Rebuild pret (`make` at root)
      → fresh `pokeyellow.sym`, or source it from the FF'd `symbols` branch, then
      run `gen_pret_ram.py` and confirm `wUnusedTitleMonSpecies` / `wPlayerBattleStatusEnd` /
      `wEnemyBattleStatusEnd` appear
- [x] Confirm the three labels surface in `aux_labels` (ram dir) after `update_label_db`
- [x] Port `title_rb` mirror: pret `[wTitleScreenScene]`→`[wUnusedTitleMonSpecies]`
      (same $CD3D union) — mirror the rename at the port use site
- [x] Check port battle-init FillMemory lengths: adopt the symbolic
      `wPlayerBattleStatusEnd`/`wEnemyBattleStatusEnd` forms where the port spells
      those spans literally (values identical — `make compare`-style reasoning does
      not apply port-side; gate is `faithdiff` + battle goldens)
- [x] Gate: `lint_pret_labels` 0, `static_gate` PASS

## Slice 5 — Deletions + literal/comment syncs (worker E, parallel after Slice 1)

Scope: `dos_port/src/home/overworld.asm`, `pikachu_entrance_anim.asm`, ~12 comment/literal sites,
port map-blob assets + `map_editor` (for the `.blk` rename).
- [x] Delete `ContinueCheckWarpsNoCollisionLoop` (`overworld.asm:2373` + `global :2293` +
      mention `:2259`); delete `.checkIfVermilionDockTileset` (`:4318-4320`);
      `DisplayTwoOptionMenu.pressedAButton` already absent — verify still absent, no action
- [x] `pikachu_entrance_anim.asm:93` `mov al,0x7F`→`T_SPACE` idiom (precedent:
      `print_type.asm:46`, `core.asm:659,690`); header `:19` `$7F (blank)` comment sync
- [x] Per-site literal→symbolic swaps (each: read merged pret hunk, mirror port-side,
      `faithdiff` the routine): `main_menu` `$8`→`PLAYER_DIR_UP`;
      `text_box`/`unused_input`/`window` `$28/40`→`SCREEN_WIDTH` idioms;
      `printer` `wOverworldMap+650`→`wHandshakeFrameDelay`;
      `VermilionDock` `$ff`→`PAD_BUTTONS|PAD_CTRL_PAD`;
      `home/overworld` 2-line change; comment-only: `oak_speech`, `oak_speech2`,
      `intro`, `title_rb`, `OaksLab`, `emotion_bubbles` (blank line — skip if N/A port-side)
- [x] `intro.asm` unused-move deletion: confirm the port has no counterpart
      (`MOVE_NIDORINO_RIGHT`/`GENGAR_*`); if absent, record as no-op with evidence
- [x] `.blk` rename: check port embedded map blobs + `tools/map_editor/` for
      `CeruleanTradeHouse` references; rename/alias as the port's asset flow requires
      (0-byte pret change — port-side is asset bookkeeping only)
- [x] `includes.asm` reorder: N/A port-side (no such file) — record with evidence
- [x] Gate: `lint_pret_labels` 0 both modes; goldens for touched areas (walk/surf/menu)

## Slice 6 — VC text fix regen (worker F, parallel after Slice 1)

Scope: `assets/link_npc_text.inc` (generated), carrier `src/engine/link/cable_club_npc.asm` (verify-only).
- [x] Re-run `gen_menu_strings.py` (rule `Makefile:4182-4192`); confirm the one-word
      delta lands in `_CableClubNPCLinkClosedBecauseOfInactivityText` bytes
- [x] Verify `strip_vc` (`gen_battle_text.py:247-270`) still yields "closed because of"
      on the non-VC branch (the fix is VC-branch-only; non-VC bytes must be unchanged)
- [x] No golden covers cable-club VC text — propose acceptance WITHOUT new scenario
      (VC-only display byte, regen-diff is the evidence); maintainer call if disputed
- [x] Tier-1 rule reminder: no hand-edit to `.inc` — generator only

## Slice 7 — Gates + commit sequence (ROOT, serial, after Slices 2-6)

Serialization: `update_label_db`/`lint` (default rescan) rewrite tracked
`translation.db` — single-writer; no builds/rescans while another agent builds.
`make fidelity*` holds a spirit write-lock — no source edits during the run
(pgate rsyncs up front, but wait for staging anyway); never poll with
`pgrep -f "make fidelity"` (matches itself); read the status file.
- [x] Order: `make -C dos_port assets` (Slices 3,4,6 outputs) → `update_label_db`
      (deliberate tracked-DB commit) → `lint_pret_labels` + `--strict-claims` (exit 0)
      → `static_gate` PASS → `faithdiff` per touched pret label (commit message
      justifies every unsuppressed added/dropped call)
- [ ] `make -C dos_port fidelity` (core ≈30s) then `fidelity-full` (≈6min parallel
      via pgate; NEVER the `-serial` tiers without explicit maintainer order)
- [ ] Commit sequence: (1) pret merge commit (Slice 1, with old/new `make compare`
      hashes); (2) port-slice commits per slice; (3) `translation.db` rescan commit.
      In-scope only per Commit Policy; the `symbols` pointer update rides with (1)
- [ ] Close-out sweep (per AGENTS.md capability rule): `rg TODO-HW|STUB` + extern
      allowlist + plan/skill text + regression memories touching renamed labels;
      update or delete stale ones in the same workstream
- [ ] `episode_record` the merge session, grounding any new durable memories

## Open questions for maintainer

1. `DEBUG_TESTBATTLE` flag: keep port-only name (default, Slice 2) or align toward
   `FightDebugMenu` naming? No behavior impact either way.
2. VC text fix without golden: accept regen-diff as evidence (Slice 6 default)?
3. `pret_ram.inc` regen make target was not found by survey — if Slice 4 finds no
   rule, add one or document the manual invocation?

## Subagent dispatch map

| Slice | Workers | Claims (narrowest) | Parallel with |
|---|---|---|---|
| 0, 1, 7 | ROOT (serial) | — (merge + gates) | — |
| 2 | 1 peer | `dos_port/src/engine/debug/` | 3, 4, 5, 6 |
| 3 | 1 peer | `dos_port/src/engine/battle/init_battle.asm`, `dos_port/src/scripts/`, `dos_port/tools/generators/gen_trades.py` | 2, 4, 5, 6 |
| 4 | 1 peer | `dos_port/assets/pret_ram.inc`, `dos_port/src/engine/movie/title_rb.asm` | 2, 3, 5, 6 |
| 5 | 1 peer | `dos_port/src/home/overworld.asm`, `dos_port/src/engine/battle/pikachu_entrance_anim.asm` | 2, 3, 4, 6 |
| 6 | 1 peer | `dos_port/tools/generators/gen_menu_strings.py` (+ regen'd `assets/link_npc_text.inc`) | 2, 3, 4, 5 |

Peers report to ROOT; ROOT writes memories/episodes. Peers are read-slice owners
except Slice owners performing their edits; `translation.db` rescan stays ROOT-only in Slice 7.
