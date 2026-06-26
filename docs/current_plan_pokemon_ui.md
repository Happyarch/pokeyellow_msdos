# Current Plan: Pokémon Engine ↔ UI Coupling

Couple the (built, harness-validated) data layers — `current_plan_pokemon_engine.md`
(party structs, base stats, `CalcStats`, `_AddPartyMon`, learnset/moves) and
`current_plan_items.md` (bag/PC `AddItemToInventory_`, `ItemNames`/`ItemPrices`) —
to the overworld UI now that the START menu exists (`src/engine/menus/start_menu.asm`).
Turn the menu's no-op POKéMON / ITEM stubs into real screens backed by live data.

## The gap

Everything in both data plans was validated **only via native ELF32 harnesses** —
none of it has ever executed inside the real DPMI/overworld binary, and the
overworld boots with an empty party + bag. So coupling has three layers:

1. **Runtime data** — get a real party + bag into WRAM during the actual boot.
   `src/engine/debug/debug_party.asm:PrepareNewGameDebug` already seeds party
   (`AddPartyMon`), bag (`AddItemToInventory`), Pokédex, money, badges, and sets
   `EVENT_GOT_POKEDEX`. It was never wired in and calls two pret wrappers
   (`AddPartyMon` / `AddItemToInventory`) the port lacked (engine exports the
   `_`-suffixed `_AddPartyMon` / `AddItemToInventory_`).
2. **List-menu UI** — a generic scrollable vertical list menu (pret
   `DisplayListMenuID` subset): the shared substrate for the bag and party screens.
3. **Wire the stubs** — START→ITEM (bag: name + qty) and START→POKéMON
   (party: nickname / level / HP).

## Conventions
- Same as the two parent plans: faithful pret translation, sym-pinned WRAM
  (`origin/symbols:pokeyellow.sym`), verify before assuming (the swarm drafts were
  broken where touched). Render-verify menus via `FRAME.BIN` dumps; verify data
  via `DUMP.BIN` windows — do not eyeball.
- Menu strings via the `unicode_converter` submodule (`gb_text.encode`) where the
  charset is single-char; pret-derived data keeps its greedy encoder.

## Stages

- [x] **Stage 0 — Runtime data (no-regrets foundation).** DONE. Added the flat-
  model wrappers `AddPartyMon` (→ `_AddPartyMon`, `src/home/move_mon.asm`) and
  `AddItemToInventory` (→ `AddItemToInventory_`, `inventory.asm`); wired
  `debug_party.asm` + `RunPartySeedTest` (`debug_dump.asm`) behind `DEBUG_PARTY=1`
  (entry.asm hook + Makefile). Seeds at boot and dumps party + bag to DUMP.BIN.
  **Verified inside the real binary** (not just the ELF harnesses): party count 4;
  species `84 90 64 54 FF`; Snorlax Normal/Normal, catch-rate 25, HM moves
  FLY/CUT/SURF/STRENGTH; Pikachu Electric, catch-rate 190, ThunderShock/Growl/Surf;
  nicknames SNORLAX/PERSIAN/JIGGLYPUFF/PIKACHU (internal→dex→name correct); bag = 14
  items matching the seed exactly. Fixed a debug-seed bug: `PERSIAN` was `113`
  (= KAKUNA's internal index) → `144` (per `data/pokemon/dex_order.asm`).
- [x] **Stage 1+2 — ITEM (bag) screen.** DONE. Built `src/engine/menus/bag_menu.asm`
  (`DisplayBagMenu`): a scrollable list of `wBagItems` showing item name
  (`ItemNames` walk) + "×NN" quantity, 4 visible entries, a CANCEL tail, ▼ "more
  below" indicator, cursor, up/down scroll (`.fix_scroll`), A no-op on items /
  CANCEL or B to exit. Rendered through the window layer like the START menu
  (render into the 20-wide wTileMap, copy box rect → GB_TILEMAP1, blit via
  `render_window` with `g_win_clip_w`/`g_win_max_y`). Wired START→ITEM
  (`start_menu.asm:.open_item`); refactored the START menu draw into a reusable
  `.draw_full` so the menu restores after the bag closes. Verified via DEBUG_BAGMENU
  (FRAME.BIN): MASTER BALL ×99 / TOWN MAP ×1 / BICYCLE ×1 / FULL RESTORE ×99 + ▼,
  over Pallet Town. (The generic Stage-1 list menu was implemented directly as the
  bag list; generalize it when the party screen needs the same substrate.)
  Found + fixed more hand-guessed Gen-1 constants in the debug seed: 7 item ids
  (TOWN_MAP/FULL_RESTORE/SECRET_KEY/CARD_KEY/S_S_TICKET/LIFT_KEY/PP_UP) per
  `constants/item_constants.asm`. Deferred: USE/TOSS sub-menu; key-item quantity
  suppression (`IsKeyItem`).
- [x] **Stage 3 — POKéMON (party) screen.** DONE. `src/engine/menus/party_menu.asm`
  (`DisplayPartyMenu`): lists the party (≤6, so no scroll) as "▶NICK :Lnn" then
  "HP cur/max", reading nickname (`wPartyMonNicks`, PlaceString), level
  (`MON_LEVEL`), and big-endian `MON_HP`/`MON_MAXHP` from the structs; a local
  `.print_num3` renders 0-999 with leading-space suppression. Wired START→POKéMON
  (`start_menu.asm:.open_party`, reusing `.draw_full` to restore on close).
  Verified via DEBUG_PARTYMENU: Snorlax L80 346/346, Persian L80 194/194,
  Jigglypuff L15 59/59, Pikachu L5 18/18 — HP matches hand-computed CalcStats
  exactly.
- [x] **Stage 3b — faithful party rows: HP-bar gauge + status.** DONE. Rebuilt the
  party screen to match the original game's per-mon layout (pret
  `RedrawPartyMenu_`): a borderless full-width panel with, per mon, a name row
  ("NICK  :Llvl  STATUS" using the real combined `:L` tile $6e) and an HP row (the
  6-segment / 48-pixel HP-bar gauge + "cur/ max"). The HP-bar/`:L` tiles ($62-$6e)
  live in the HpBarAndStatus set (`font_battle_extra`), absent in the overworld, so
  `party_menu.asm` loads it on entry (new `LoadHpBarAndStatusTilePatterns` in
  `src/gfx/load_font.asm`, embed `assets/font_battle_extra_2bpp.inc` via new
  `tools/gen_font_battle_extra_inc.py`) and restores the box-drawing tiles it
  clobbers (`LoadTextBoxTilePatterns`) on exit so the START border redraws. Bar
  fill is the faithful `GetHPBarLength`/`DrawHPBar` math (pixels = curHP·48/maxHP,
  ≥1 alive / 0 fainted; full/partial/empty segment tiles). Status text = FNT (HP 0)
  / PSN / BRN / FRZ / PAR / SLP / blank, by `MON_STATUS` bit priority. Verified via
  DEBUG_PARTYMENU (+ a temporary damaged-HP poke): Persian 97/194 → exact half bar,
  Jigglypuff 5/59 → sliver + PSN, Pikachu 0/18 → empty bar + FNT; full-HP mons full
  bars. NOTE: the generated `assets/font_battle_extra_2bpp.inc` is under a gitignored
  dir — `git add -f` it at commit time (same as the sibling `font_extra_2bpp.inc`).
  Still deferred: animated mon ICON sprites, full-screen white takeover, per-mon
  action sub-menu/summary.
- [~] **TOSS — logic complete (manual test pending).** A on a tossable bag item →
  quantity chooser (up/down 1..qty, wrap) → `RemoveItemFromInventory_`; A on a key
  item is a no-op. Key-item guard `bag_menu.asm:.is_key_item` uses the generated
  `KeyItemFlags` bit array (gen_items.py, byte0 `0xF0` verified) + the HM range
  ($C4-$C8 key, $C9+ TM tossable). The bag refreshes (entry count + scroll clamp)
  after a toss. `RemoveItemFromInventory_` was audited (faithful to pret) and is
  native-validated. NOT yet frame-verified interactively (needs an input sequence
  the headless harness can't drive) — **manual test before relying on it**:
  build normally, START→ITEM, A on e.g. FULL RESTORE (tossable) vs TOWN MAP (key).
  Deferred polish: "TOSS how many?" / "TOO IMPORTANT!" text; the USE/TOSS sub-menu
  (A currently jumps straight to toss since USE isn't implemented).

## Handoff — resume here

Two threads remain before this is "real" (both deferred deliberately):

1. **Party screen polish** (`party_menu.asm`): HP **bar**, **status**, the
   **whiteout + centered** layout, and the **animated mon icons** are all DONE
   (Stages 3b–3d). Remaining: the per-mon **action sub-menu** (STATS / SWITCH /
   CANCEL → summary screen, party reorder), and a possible **runtime X-flip** for
   any asymmetric icon (see Stage 3d note — currently the right half is a baked
   mirror, valid for all symmetric party icons).

- [x] **Stage 3c — whiteout + centered menu.** DONE. Added a `g_bg_whiteout` flag
  (`ppu.asm`): when set, `render_bg` fills the whole 320×200 back buffer with BG
  color 0 and `render_sprites` is skipped, so the party menu sits on a clean white
  field instead of over Pallet Town. `party_menu.asm` sets it on entry / clears on
  exit, and centers the 160px window both horizontally (WX) and vertically
  (WY = (RENDER_H − rows·8)/2). The flag is 0 everywhere else, so the overworld
  path is unchanged (two extra `cmp/je`). Verified via DEBUG_PARTYMENU FRAME.BIN.
- [x] **Stage 3d — animated mon icons.** DONE. Faithful 2×2 party-sprite icons left
  of each name (cols 1-2), with the original layout shift (cursor/icon/name/level/
  status; HP gauge at col 4). New `tools/gen_mon_icons_inc.py` bakes
  `assets/mon_icons.inc`: 11 ICON_* types × 2 frames × 4 tiles (right half = baked
  horizontal mirror since the window/BG layer has no per-tile X-flip — revisit if
  an asymmetric/helix icon is ever needed), plus an internal-index→ICON map
  (PokedexOrder ∘ MonPartyData). Icons load into the vTileset region ($9000+, tiles
  $01-$18, restored on exit via `LoadTilesetTilePatternData`) and render as window
  tiles (the decoder reads VRAM directly). Animation matches pret AnimatePartyMon:
  ONLY the cursor-selected mon bobs, at a period from its HP-bar color
  (green ≥27px → 6, yellow ≥10px → 17, red/fainted <10px → 33 vblanks/frame); other
  slots stay on frame A. NOTE: status does NOT affect speed in pret (only HP
  fraction does); fainting maps to red via 0 HP. Verified via DEBUG_PARTYMENU:
  correct icons (Snorlax/Persian MON, Jigglypuff FAIRY, Pikachu PIKACHU), frame-A vs
  frame-B differ, and a diff confirmed only the selected icon animates.
2. **Real data path** — replace the `DEBUG_PARTY` debug seed (`debug_party.asm` +
   `PrepareNewGameDebug`) with the actual new-game init + Oak starter-gift flow
   (the deferred item in `current_plan_script_engine.md` that needs `AddPartyMon`),
   so the party/bag are populated by gameplay, not a `make DEBUG_*` flag. Until
   then, the menus only show data under `DEBUG_PARTY`/`DEBUG_BAGMENU`/`DEBUG_PARTYMENU`.

Also pending: **item USE** dispatch (the large per-item effect engine — separate
from TOSS), and generalizing the bag/party list rendering into one shared list-menu
substrate if a third list type appears.

## Notes
- The DEBUG_PARTY seed is scaffolding for *testing* the UI against live data; the
  real data path is the new-game init + Oak starter gift (the latter is the
  deferred item in `current_plan_script_engine.md` that needs `AddPartyMon`).
