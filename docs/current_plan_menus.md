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
  **Human step DONE (2026-07-01): user reviewed the layout in the editor and
  kept the seeded defaults as-is.** Editor gained hide/solo visibility
  controls + foolproof save (plain S, refusal-not-crash) as follow-ups.
- [x] **Session 2 — `DisplayTextBoxID_` + `DisplayTextIDInit`.** DONE
  2026-07-02 (see translation_log.md "menus-port Session 2" for full detail).
  - `src/engine/menus/text_box.asm` full rewrite (canvas model: UI_*-projected
    tables, stride-40 dispatch with flags-safe restore, function stride 3→5 /
    text+coord 9→11, TWO_OPTION_MENU → yes_no.asm's ONE `DisplayTwoOptionMenu`,
    DisplayMoneyBox/DoBuySellQuitMenu/DisplayFieldMoveMonMenu/GetMonFieldMoves;
    JP_* omitted). NEW `src/home/textbox.asm` wrapper (canonical pret home);
    text_script.asm interim def removed (externs RESOLVED, stays check-only).
  - NEW `src/engine/menus/display_text_id_init.asm` — faithful
    DisplayTextIDInit; borders draw at pret GB coords into the stride-20
    scratch (dialog cell = MSG_BOX_ESI); `ldh [hWY],0` = TODO-HW with NO write
    (H_WY is the sync_dialog_window dialog-open gate; set_single_window owns
    it); sprite facing-save + stand-still loops faithful.
  - Includes: wTextBoxID ids in gb_constants.inc; field-move WRAM + wMiscFlags
    0xCD60 + pret sprite-struct aliases in gb_memmap.inc. **Fixed
    m8_2_pending_symbols.inc's wrong wMiscFlags 0xD72E (pokered wd72e).**
  - Makefile: text_box + display_text_id_init → GAME_SRCS; textbox + yes_no →
    HOME_SRCS (yes_no promoted from check-only, no collisions); dep lines for
    ui_layout_menus.inc / event_constants.inc; `DEBUG_TEXTBOXID=<id>` flag.
  - Verified: `RunTextBoxIDTest` FRAME.BIN gate ran ALL 14 non-interactive
    table ids green under a scripted border-corner pixel check (0x04's dynamic
    4-field-move box landed at (29,9)-(39,24), exactly pret's math +20/+7).
    0x14/0x15 are interactive; 0x15's template verified via 0x0E.
    `make` + `make check` green.
- [x] **Session 3 — Wire dead drivers live.** DONE 2026-07-02 (see
  translation_log.md "menus-port Session 3").
  - Link-blockers: all but PrintLevel already resolved to linked code
    (ClearScreenArea=copy2, LoadGBPal=fade, IsKeyItem=item_predicates,
    GetPartyMonName=home/pokemon [real], CopyToStringBuffer=battle core).
    NEW: PrintLevel/PrintLevelFull/PrintLevelCommon in src/home/pokemon.asm.
  - list_menu.asm faithful completions: party-vs-box nick-base select
    (pret "cp l" low-byte trick) in .pokemonList/.pokemonPCMenu; box-level
    copy (wLoadedMonBoxLevel→wLoadedMonLevel) + wNamedObjectIndex save/restore
    in the level path. FIXED: PlaceString called with pret's DE convention
    (port takes EAX=flat ptr) — names/CANCEL never rendered; priced path read
    entry id from PlaceString-clobbered EDX (now peeks saved ptr at [esp+4]).
  - Port-model wiring: list_mirror/qty_mirror (scratch→GB_TILEMAP0; the
    do_bg_transfer path targets GB_TILEMAP1 so windows never saw the box);
    menu_redraw_cb=list_mirror during HandleMenuInput (yes_no's mechanism);
    qty box moved to its own scratch+tilemap region (QTY_SROW=12, bag_menu's
    distinct-start-row scheme — was colliding with the list box at row 0).
  - yes_no: TRADE_CANCEL_MENU variant added — DisplayTwoOptionMenu branches to
    CableClub_TextBoxBorder (NEW src/engine/link/cable_club.asm, +DrawHorizontalLine;
    $76-$7D tile gfx load deferred to S8/I1 with its callers). FIXED latent EBX
    corruption (mov bh,[ebx+..] clobbered the descriptor ptr mid-read) — S2's
    gate never ran the interactive 0x14 path; live check lands with S4's bag
    realign. Added pret's pre-HandleMenuInput clears (wTwoOptionMenuID +
    BIT_NO_TEXT_DELAY).
  - Makefile: list_menu→HOME_SRCS, swap_items+cable_club→GAME_SRCS;
    `DEBUG_LISTMENU=<mode>` harness (debug_dump.asm RunListMenuTest: Old-Man
    auto-select drives the driver input-free; modes 0/2/3 verified via
    FRAME.BIN renders — party nicks+levels, price column, ×qty+IsKeyItem skip).
  - Gate: baseline FRAME.BINs (overworld/STARTMENU/BAGMENU) byte-identical
    before/after; `make` + `make check` green.
- [x] **Session 4 — Realign start_menu + bag_menu.** DONE 2026-07-02 (see
  translation_log.md "menus-port Session 4"). Direct overwrite instead of the
  `_v2` flag dance (user call: "correct or overwrite the unfaithful bespokes");
  still one revertible commit, gated by before/after FRAME.BIN diffs.
  - Bespoke `start_menu.asm`/`bag_menu.asm` DELETED, replaced by faithful
    `src/home/start_menu.asm` (DisplayStartMenu/RedisplayStartMenu/
    CloseStartMenu), `src/engine/menus/draw_start_menu.asm` (DrawStartMenu,
    canvas model + GB_TILEMAP1 window bridge at UI_START_MENU_*), and
    `src/engine/menus/start_sub_menus.asm` (ItemMenuLoop + StartMenu_Item live
    on DisplayListMenuID/DisplayTextBoxID/HandleMenuInput; Pokemon = party
    seam for S5; Pokedex/TrainerInfo/SaveReset/Option = tagged stubs for
    S6-S9). SELECT-swap live via swap_items.asm's HandleItemListSwapping (the
    driver's own SELECT path); bag USE stays a tagged stub (items plan).
  - TOSS chain faithful: IsKeyItem/IsItemHM → DisplayChooseQuantityMenu →
    NEW home/item.asm TossItem → NEW TossItem_ (item_effects.asm) with
    RemoveItemFromInventory wrapper + TWO_OPTION_MENU (0x14) via
    InitYesNoTextBoxParameters/DisplayTextBoxID — first live wiring of the
    interactive yes/no path. DEVIATION(text): the three toss dialogs are drawn
    whole (pret wording, ▼ + A/B prompt wait) instead of PrintText typewriter
    reveal — PrintText_Overworld collapses the window list (would hide the
    list); revisit when engine-text streams exist as GB-space assets.
  - Port-model guard: RedisplayStartMenu/CloseStartMenu call
    RefreshCollisionTileMap (pret screen-buffer-restore analog) so
    CheckSpriteAvailability's text-box tile check sees map+box only; the
    canvas box at UI_START_MENU cols 30-39 reproduces pret's
    NPC-hidden-under-menu behavior for free.
  - Gates: DEBUG_BAGMENU FRAME.BIN **byte-identical** to bespoke (hook moved
    into DisplayListMenuIDLoop; RunBagMenuTest drives StartMenu_Item);
    DEBUG_STARTMENU menu-box region (x≥240) **pixel-identical** (262 stray px
    outside = wandering-NPC first-tick init transient from the faithful
    UpdateSprites call, reachable only in the harness which opens the menu
    before OverworldLoop's first tick); overworld baseline byte-identical;
    DEBUG_LISTMENU=3 matches the bag render; `make` + `make check` green.
    DEBUG_BAGMENU_CONFIRM flag deleted with the bespoke. Interactive toss /
    yes-no / SELECT-swap hand-pass: `make DEBUG_BAGMENU_LIVE=1` + `dos_port/run`
    (formal interactive sweep stays S10). Requires: S3.
- [x] **Session 5 — Realign party_menu.** DONE 2026-07-02 (see
  translation_log.md "menus-port Session 5"). Direct overwrite (S4 method):
  bespoke party_menu.asm rewritten as the faithful pret split — home driver
  (home/pokemon.asm DisplayPartyMenu/GoBackToPartyMenu/PartyMenuInit/
  HandlePartyMenuInput on generic HandleMenuInput + PrintStatusCondition +
  DrawHPBar), engine renderer (DrawPartyMenu_/RedrawPartyMenu_/
  SetPartyMenuHPBarColor + DrawHP2 hosted pending pokemon_behavior's
  status_screen), StartMenu_Pokemon dispatcher + SwitchPartyMon family +
  ErasePartyMenuCursors (start_sub_menus.asm), NEW engine/gfx/hp_bar.asm +
  live status_ailments.asm. Field-move pop-up = S2's DisplayFieldMoveMonMenu
  via DisplayTextBoxID + fm_show_window dynamic right/bottom-anchored window
  at UI_FIELD_MOVE_MON_MENU. Icons stay BG-tile DEVIATION (PartyMenuAnimCB);
  messages drawn whole (S4 text DEVIATION). STATS + field effects + TMHM/
  EVO_STONE/item-use menus = tagged stubs (pokemon_behavior / items plans).
  Fixed latent port-wide PrintNumber little-endian read (pret is big-endian;
  exposed by the 2-byte HP fractions). Gate: FRAME.BIN HP/status/icon/name/
  message regions byte-identical to the bespoke baseline; only diffs = level
  LEFT_ALIGN + cursor-row fidelity fixes. `make`+`make check` green.
  Interactive pop-up/SWITCH pass deferred to the S10 sweep (no key injection).
  Requires: S4.
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

- frozen_at: **1252ef41** (seeded defaults kept verbatim; marker recorded in
  the sidecar's `frozen_at` field). Root-only edits from here, only between
  swarm waves. Session 2 is unblocked.

## Package status ledger (fill during waves)

| Pkg | Screen | Status | FAITHFUL EXCEPT |
|-----|--------|--------|-----------------|
| A | oaks_pc + league_pc | integrated (S6) | dialogs drawn-whole (text); buffer2 save→window-list; DisplayDexRating STUB(S8); HoF team loop STUB(S7) w/ 0-team guard + ret-stubs; palette TODO-HW |
| B | draw_badges / trainer card gfx | integrated (S6) | none |
| C | naming_screen | queued | |
| D | options | integrated (S6) | rAUDTERM + printer writes TODO-HW (wOptions/wPrinterSettings values still stored); window-mirror port plumbing |
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
