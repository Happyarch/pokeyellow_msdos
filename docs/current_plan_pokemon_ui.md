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
- [ ] **Stage 1 — Generic list menu.** Translate the `DisplayListMenuID` subset
  needed for a scrollable vertical list (cursor, up/down with scroll, A select /
  B cancel) rendered via the window layer, reusing the start-menu's font-swap +
  `g_win_clip_w`/`g_win_max_y` box-bounding.
- [ ] **Stage 2 — ITEM (bag) screen.** Wire START→ITEM to a bag list: item name
  (`ItemNames`) + quantity from `wBagItems`. Read-only first (no toss/use). The
  simpler of the two list types — no stats.
- [ ] **Stage 3 — POKéMON (party) screen.** Wire START→POKéMON to a party list:
  nickname (`wPartyMonNicks`) + level + HP from the party structs.
- [ ] **Later (deferred):** item use/toss dispatch, party→summary/switch, the
  real new-game/Oak-gift data path replacing the DEBUG_PARTY seed.

## Notes
- The DEBUG_PARTY seed is scaffolding for *testing* the UI against live data; the
  real data path is the new-game init + Oak starter gift (the latter is the
  deferred item in `current_plan_script_engine.md` that needs `AddPartyMon`).
