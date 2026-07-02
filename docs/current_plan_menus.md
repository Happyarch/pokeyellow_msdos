# Current Plan: engine/menus Port + UI Layout Tool

Port ALL of pret `engine/menus/` faithfully (realigning the live bespoke
start/bag/party menus onto the generic drivers) + a subsystem-generic pygame
layout tool. One session = one checkpointed chunk; a fresh session starts by
reading this file and verifying the previous checkpoint commit exists on
branch `menus-port`.

Every session ends: `make -C dos_port` + `make -C dos_port check` green →
verification pass done → checkboxes here updated → commit. Never end a
session mid-refactor.

## Decisions (fixed, from the user)

- Layout tool: pygame, `dos_port/tools/ui_layout/`; sidecar JSON
  (`assets/ui_layout_menus_sidecar.json`, edited ONLY via the editor) →
  `tools/gen_ui_layout.py` → `assets/ui_layout_menus.inc` (Tier 1, keyed by
  element ID). Battle later gets `ui_layout_battle_sidecar.json`, no code change.
- Full faithful realignment; `DisplayTextBoxID_` ported with coord tables fed
  by the generated include; link_menu serial → `; TODO-HW: network HAL` stubs
  returning pret's no-partner timeout path (never a bare `ret`); save = minimal
  real `.dsv` I/O (reuse `debug_dump.asm`'s DPMI INT 31h/0300h file-write).
- Out of scope (owned by `current_plan_pokemon_behavior.md`):
  StatusScreen/StatusScreen2, Bill's PC — stub the seams, never touch its
  files. Item USE dispatch is `current_plan_items.md` scope. Skip pret
  `unused_input.asm` (dead code).

## Worker rules (copy VERBATIM into every swarm brief)

1. Every routine keeps its pret name; `; pret ref: <file>:<label>` per logical
   block. Label parity is checked mechanically.
2. Deviations only behind exactly three tags: `; PROJ` (geometry — must cite a
   `UI_*` equate from `ui_layout_menus.inc`, never a bare literal),
   `; TODO-HW:`, `; DEVIATION: <one-line why>`. Untagged control-flow change
   = defect, package bounces.
3. Never reinvent something pret names — `extern` it or port it under its name.
4. Never touch git, `assets/*.inc`, the sidecar JSON, `gb_memmap.inc`, or the
   Makefile (report needed symbols/SRCS lines instead).
5. Run `make -C dos_port check` in the seeded worktree before reporting.
6. Completion report MUST end `FAITHFUL EXCEPT: <list|none>` + routine map +
   tag inventory + externs needed.

Root gates per package, in order: (1) branch-by-branch pret control-flow diff
(read-only verifier; count/polarity/fallthrough, flag-sense per
docs/register_map.md); (2) tag audit; (3) PROJ-geometry-cites-UI_* audit;
(4) `make check` + `make`; (5) TODO-HW return-contract audit; then Makefile
entry + commit (root only).

## Sessions

- [x] **Session 1 — Layout tool + pipeline.** `tools/ui_layout/` (schema/
  canvas/render/assets_bridge/seed_from_pret/editor) + `tools/gen_ui_layout.py`
  + Makefile `assets/ui_layout_menus.inc` rule. Seeded 19 elements from pret
  `data/text_boxes.asm` + live `; PROJ` tags; seeder asserts legacy geometry
  reproduced exactly (bag wx=199, START wx=247, dialog 87/152, …); nasm
  round-trip harness assembles every equate; editor smoke-tested headless
  (drag/snap/clamp/resize/save). JP_* templates omitted (DEVIATION: JP-only).
  **→ HUMAN STEP: run `python3 tools/ui_layout/editor.py
  assets/ui_layout_menus_sidecar.json` (from dos_port/), position/resize
  everything, confirm anchors (X/Y keys), Ctrl+S, then `make assets`.**
- [ ] **Session 2 — `DisplayTextBoxID_` + `DisplayTextIDInit`.** Rewrite
  `src/engine/menus/text_box.asm` (dispatcher + 3 tables from `UI_*` equates;
  DisplayMoneyBox, DoBuySellQuitMenu, DisplayTwoOptionMenu reconciled with
  yes_no.asm — ONE implementation; DisplayFieldMoveMonMenu/GetMonFieldMoves);
  port `display_text_id_init.asm` (audit overlap vs PrintText_Overworld
  first); resolve text_script.asm externs (lines 61/89); promote to
  LINK_SRCS; `DEBUG_TEXTBOXID=<id>` harness → FRAME.BIN per table entry.
  Requires: S1 layout frozen (frozen_at set in sidecar).
- [ ] **Session 3 — Wire dead drivers live.** Promote list_menu/yes_no/
  swap_items to LINK_SRCS; fill link-blockers (list_menu.asm header lines
  91-98: ClearScreenArea, LoadGBPal, IsKeyItem, PrintLevel, GetPartyMonName
  real impl, CopyToStringBuffer); add yes_no TRADE_CANCEL_MENU variant;
  `DEBUG_LISTMENU=<mode>` harness. No live-behavior change (baseline
  FRAME.BINs must match). Requires: S2.
- [ ] **Session 4 — Realign start_menu + bag_menu.** `_v2` files + DEBUG flag
  A/B swap; FRAME.BIN A/B diff for must-not-change behavior; SELECT-swap goes
  live via real swap_items.asm; bag USE stays tagged stub; single revertible
  swap commit, flag deleted same session. Requires: S3.
- [ ] **Session 5 — Realign party_menu.** Same `_v2` method for
  DrawPartyMenu_/RedrawPartyMenu_ + field-move pop-up rebased onto S2's
  DisplayFieldMoveMonMenu; HP/status/icon pixel-regression gate; STATS stays
  stub (pokemon_behavior seam — check that plan's status first). Requires: S4.
- [ ] **Session 6 — Swarm wave 1**: A (oaks_pc+league_pc), B (draw_badges +
  root writes gen_badge_tiles.py), D (options; rAUDTERM→TODO-HW),
  F (players_pc — flagship DisplayListMenuID second caller; PC boxes =
  in-memory Gen-1-shaped stand-in). Root seeds worktrees (assets+.2bpp),
  integrates, gates. Per-package `DEBUG_<PKG>=1` dumps: open/nav/terminal
  states. Requires: S5.
- [ ] **Session 7 — Swarm wave 2** + root-first `src/save/dsv_io.asm`
  (DOSV magic+version+checksum+32KB payload; DsvFileExists):
  E (main_menu; CheckForPlayerNameInSRAM→DsvFileExists; SpecialEnterMap wired
  by root), H (save.asm UI+structure; SaveGameData→real minimal .dsv write;
  ChangeBox faithful), C (naming_screen; rSTAT HBlank hack→DEVIATION plain
  copy; root writes gen_alphabets.py). Update saveconv.py stub header.
  Requires: S6.
- [ ] **Session 8 — Swarm wave 3**: G pokedex split G1 (2D scroller+side
  menu)/G2 (entry page; spike pics.asm front-pic reuse first) + root writes
  gen_dex_order.py/gen_dex_entries.py; I link_menu split I1 (menus/dispatch,
  serial stubs w/ pret timeout semantics)/I2 (cup validation, fully real).
  %include-based splits. Requires: S7.
- [ ] **Session 9 — Integration spine (root only).** Faithful pc.asm
  (ActivatePC/PCMainMenu; BillsPC seam stub) + start_sub_menus.asm
  (StartMenu_* wiring all packages, SwitchPartyMon, ErasePartyMenuCursors,
  Trainer Card + package B). All Makefile promotions serialized here.
  Requires: S6-S8 landed.
- [ ] **Session 10 — Final verification + closeout.** Interactive pass
  (every START entry; bag scroll/swap/toss/USE-fails-gracefully; party
  regression; trainer card; pokedex; players-PC; save→.dsv→CONTINUE appears;
  options persist; link cup validation + no-partner timeout; naming full
  grid). dosbox_mcp gb_read return-contract checks on 3+ screens. Update
  ui_projection.md index (cite UI_* equates), CLAUDE.md phase blurb,
  translation_log.md; `git mv docs/current_plan_menus.md docs/plans/menus.md`.

## Layout freeze

- frozen_at: **NOT YET FROZEN** — set the commit hash in the sidecar's
  `frozen_at` field (via editor save + manual regen) after the human
  positioning step; root-only edits after that, only between swarm waves.

## Package status ledger (fill during waves)

| Pkg | Screen | Status | FAITHFUL EXCEPT |
|-----|--------|--------|-----------------|
| A | oaks_pc + league_pc | queued | |
| B | draw_badges / trainer card gfx | queued | |
| C | naming_screen | queued | |
| D | options | queued | |
| E | main_menu | queued | |
| F | players_pc | queued | |
| G1/G2 | pokedex | queued | |
| H | save UI | queued | |
| I1/I2 | link_menu | queued | |

## Coordination

- `current_plan_pokemon_behavior.md` owns StatusScreen/BillsPC — re-check its
  status at S5 and S9 start.
- `current_plan_items.md` owns item USE dispatch (bag USE stays stubbed here).
- Worktree seeding: copy `dos_port/assets/*.inc` + `.2bpp/.pic/.1bpp` into
  every worker worktree; re-seed + re-`make check` if generators land mid-wave.
