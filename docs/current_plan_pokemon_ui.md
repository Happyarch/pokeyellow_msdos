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
  exactly. Deferred polish: HP bar, status, the per-mon action sub-menu/summary,
  level/HP right-alignment.
- [ ] **TOSS (easy, after Stage 3).** Per user: TOSS is low-effort — a
  "how many?" quantity prompt + `IsKeyItem` guard, then `RemoveItemFromInventory_`
  (already built). Good first interactive action on the bag list. (Item **USE** is
  much larger — the per-item effect dispatch — so it stays deferred.)
- [ ] **Later (deferred):** item USE dispatch, party→summary/switch, the real
  new-game/Oak-gift data path replacing the DEBUG_PARTY seed.

## Notes
- The DEBUG_PARTY seed is scaffolding for *testing* the UI against live data; the
  real data path is the new-game init + Oak starter gift (the latter is the
  deferred item in `current_plan_script_engine.md` that needs `AddPartyMon`).
