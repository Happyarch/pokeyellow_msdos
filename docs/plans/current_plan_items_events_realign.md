# Current Plan: engine/items/ and engine/events/ Subsystem pret Realignment

> Born 2026-08-30 from an exhaustive, end-to-end audit of all files in `engine/items/`, `engine/events/`, and `engine/events/hidden_events/`.
> Every `.asm` file in pret `engine/items/` (10 files) and `engine/events/` (26 top-level files + 28 `hidden_events/` files) was read
> in full and compared routine-by-routine, line-by-line against its port counterpart under `dos_port/src/engine/items/`,
> `dos_port/src/engine/events/`, and `dos_port/src/engine/events/hidden_events/`.
> This encompasses **64 pret `.asm` files** and **64 port `.asm` files** (plus 2 port-only stub files audited for retirement).
>
> **Headline.** The `engine/items/` and `engine/events/` subsystems (including all 28 `hidden_events/` handlers) logic-match pret
> with extreme precision across all game loops, menu inputs, item usage, event flag testing, and puzzle interactions.
> However, the audit uncovered:
> 1. **Critical Audio Constant Bug in `town_map.asm`**: `dos_port/src/engine/items/town_map.asm` lines 85-87 define dummy `SFX_TINK equ 0x00` and `SFX_HEAL_AILMENT equ 0x00` with an obsolete comment stating `PlaySound is a stub`. This completely silences cursor and confirmation SFX on the Town Map screen.
> 2. **Fully Retired Stub Files**: `dos_port/src/engine/events/give_pokemon_stubs.asm` and `dos_port/src/engine/events/hidden_events/hidden_events_stubs.asm` have 100% of their stubs retired and should be deleted from the repository.
> 3. **Hidden Event Pure-Text Mirror Alignment**: Two files in pret `engine/events/hidden_events/` (`elevator.asm` and `pokemon_stuff.asm`) do not exist in the port directory because they define only pure `text_far` strings that the generator routes to `assets/predef_text.inc` and registers in `src/data/text_predef_pointers.asm`.
> 4. **Stale Comments & Cross-References**: Multiple files carry comments referring to old temporary stubs, defunct files (`src/engine/overworld/overworld.asm`), or claim functions are "not yet defined" when they are fully implemented (e.g. `pokecenter.asm` claiming `PikachuWalksToNurseJoy` is missing, `card_key.asm` claiming `PrintBookshelfText` is a ret-stub, `item_effects.asm` mentioning `item_use.asm`).
> 5. **Legacy Unstructured Annotation Cleanup**: `item_effects.asm` carries legacy free-form `; 2. DEVIATION(...)` comments that must be migrated to machine-parsed structured annotations.

---

## Files Audited (66 Total)

### 1. Item Engine (`engine/items/` vs `dos_port/src/engine/items/` — 10 Files)
1. `get_bag_item_quantity.asm`: Bag count search loop.
2. `inventory.asm`: `DoItemSetup`, `AddItemToInventory`, `RemoveItemFromInventory`.
3. `item_effects.asm`: All 39 item effect handlers and usable-item state machines.
4. `itemfinder.asm`: Itemfinder radar detection math and audio-visual cues.
5. `subtract_paid_money.asm`: BCD transaction subtraction helper.
6. `super_rod.asm`: Super Rod fishing encounter dispatch table.
7. `tm_prices.asm`: TM/HM shop price calculations.
8. `tmhm.asm`: TM/HM compatibility and teaching routines.
9. `tms.asm`: TM/HM item ID conversion math.
10. `town_map.asm`: Interactive Town Map cursor navigation, nested city inspection, and nest location rendering.

### 2. Event Engine Top-Level (`engine/events/` vs `dos_port/src/engine/events/` — 26 Files + 1 Stub File)
11. `black_out.asm`: Blackout money halving and warp destination setup.
12. `card_key.asm`: Silph Co. Card Key door unlocking handler.
13. `cinnabar_lab.asm`: Cinnabar Lab fossil resurrection trade machine.
14. `diploma.asm`: Game Freak diploma screen renderer.
15. `diploma2.asm`: Diploma player tilemap drawing and certification text.
16. `display_pokedex.asm`: Bill's PC Pokedex entry display wrapper.
17. `elevator.asm`: Elevator floor selection menu and warp script execution.
18. `give_pokemon.asm`: Starter/gift mon generation, nickname prompts, and box routing.
19. `give_pokemon_stubs.asm` *(Port-only stub file)*: 0 active stubs (all retired).
20. `heal_party.asm`: Pokemon Center full party heal machine and status cleanser.
21. `hidden_items.asm`: Overworld hidden coin/item discovery flags and coordinates.
22. `in_game_trades.asm`: In-game NPC trade validation, stat calculation, and nickname assignment.
23. `oaks_aide.asm`: Oak's Aide item reward thresholds based on Pokedex owned count.
24. `pewter_guys.asm`: Pewter City Gym guide and museum guide movement paths.
25. `pick_up_item.asm`: Overworld visible item ball pickup and bag insertion.
26. `pikachu_happiness.asm`: Starter Pikachu happiness adjustments, mood timers, and decay rules.
27. `poison.asm`: Overworld poison step counter, HP deduction, and flash effect.
28. `pokecenter.asm`: Nurse Joy Pokecenter healing sequence and Pikachu animation trigger.
29. `pokecenter_chansey.asm`: Chansey Pokecenter interaction and cry player.
30. `pokedex_rating.asm`: Professor Oak Pokedex evaluation dialogs and rating tiers.
31. `pokemart.asm`: Pokemart Buy/Sell/Quit menu loop, quantity selector, and inventory transactions.
32. `prize_menu.asm`: Celadon Game Corner prize redemption menus, coin checks, and delivery.
33. `saffron_guards.asm`: Saffron City gate guard thirst check and drink consumption.
34. `set_blackout_map.asm`: Teleport / Dig / Blackout last map coordinator (filtering Safari rest houses).
35. `starter_dex.asm`: Oak's Lab starter Pokédex fake-ownership injector.
36. `try_pikachu_movement.asm`: Starter Pikachu scripted movement precondition validator.
37. `vending_machine.asm`: Celadon Dept Store rooftop vending machine drink vendor.

### 3. Hidden Events (`engine/events/hidden_events/` vs `dos_port/src/engine/events/hidden_events/` — 28 pret Files, 27 port Files)
38. `bench_guys.asm`: Pokecenter bench guy NPC dialogues across all towns.
39. `bills_house_pc.asm`: Bill's Teleporter / Cell Separator cutscene and Eevee evolution display.
40. `blues_room.asm`: Blue's room bookcase inspection handler.
41. `book_or_sculpture.asm`: Celadon Mansion Diglett sculpture vs Pokemon book detector.
42. `bookshelves.asm`: Global bookshelf tile identification and dispatch to predef texts.
43. `cinnabar_gym_quiz.asm`: Cinnabar Gym Blaine quiz machine, door unlocking, and tile block updater.
44. `elevator.asm` *(pret only — pure text wrapper in `assets/predef_text.inc`)*: `ElevatorText`.
45. `fanclub_pictures.asm`: Pokemon Fan Club Rapidash and Fearow framed picture viewers.
46. `fighting_dojo.asm`: Saffron Fighting Dojo scroll and poster inspections.
47. `gym_statues.asm`: Gym statue inspection displaying leader names and badge status.
48. `hidden_events_stubs.asm` *(Port-only stub file)*: 0 active stubs (all retired).
49. `indigo_plateau_hq.asm`: Indigo Plateau HQ sign inspection.
50. `indigo_plateau_statues.asm`: Indigo Plateau entrance statues (checking X coordinate parity).
51. `magazines.asm`: Generic magazine rack reader.
52. `museum_fossils.asm`: Pewter Museum Aerodactyl and Kabutops fossil display triggers.
53. `museum_fossils2.asm`: Pop-up box Pokemon front sprite loader and renderer.
54. `new_bike.asm`: Cerulean Bike Shop shiny new bicycle display.
55. `oaks_lab_email.asm`: Oak's Lab PC email from Professor Oak to trainers.
56. `oaks_lab_posters.asm`: Oak's Lab control tips and elemental matchup posters.
57. `pokecenter_pc.asm`: Global Pokecenter PC terminal login trigger.
58. `pokemon_stuff.asm` *(pret only — pure text wrapper in `assets/predef_text.inc`)*: `PokemonStuffText`.
59. `reds_room.asm`: Red's bedroom SNES console and personal Item Storage PC.
60. `route_15_binoculars.asm`: Route 15 gate binoculars viewing Articuno flying toward sea.
61. `safari_game.asm`: Safari Zone 500-step counter, ball exhaustion, PA chime, and game-over warp.
62. `school_blackboard.asm`: Viridian School blackboard status guide and Link Cable help menus.
63. `school_notebooks.asm`: Viridian School notebooks interactive 5-page flip reader.
64. `town_map.asm`: Overworld wall map inspection opening full Town Map UI.
65. `vermilion_gym_trash.asm`: Lt. Surge Vermilion Gym 15-can electric lock puzzle.
66. `vermilion_gym_trash2.asm`: Vermilion Gym 2nd can randomizer and 3-entry sampling table.

---

## Detailed Findings Ledger

### Category 1: Functional & Audio Bugs
* **`dos_port/src/engine/items/town_map.asm:85-87`**:
  - **Issue**: Hardcodes dummy `SFX_TINK equ 0x00` and `SFX_HEAL_AILMENT equ 0x00` with comment `; TODO-HW(audio): real SFX ids from constants/music_constants.asm (PlaySound is a stub)`.
  - **Impact**: When opening the Town Map or moving the cursor between cities, sound effects are silenced.
  - **Remedy**: `%include "assets/audio_constants.inc"` and delete local dummy definitions.

### Category 2: Stub File Deletions & Directory Cleanups
* **`dos_port/src/engine/events/give_pokemon_stubs.asm`**:
  - **Issue**: File is 100% empty of active stubs (all stubs were retired during previous waves).
  - **Remedy**: Delete file and remove from build scripts / makefiles if referenced.
* **`dos_port/src/engine/events/hidden_events/hidden_events_stubs.asm`**:
  - **Issue**: File is 100% empty of active stubs (all stubs were retired during previous waves).
  - **Remedy**: Delete file and remove from build scripts / makefiles if referenced.

### Category 3: Stale Comments & Defunct Cross-References
* **`dos_port/src/engine/events/pokecenter.asm:53`**:
  - **Issue**: Comment says `; TODO-PORT: PikachuWalksToNurseJoy (src/engine/pikachu/pikachu_emotions.asm) NOT YET DEFINED IN THE PORT.`
  - **Reality**: `PikachuWalksToNurseJoy` is fully defined and exported in `src/engine/pikachu/pikachu_emotions.asm:493`.
  - **Remedy**: Remove misleading comment and confirm extern.
* **`dos_port/src/engine/events/card_key.asm:14-16`**:
  - **Issue**: Comment states `PrintBookshelfText` is still a ret-stub.
  - **Reality**: `PrintBookshelfText` in `src/engine/events/hidden_events/bookshelves.asm` is fully ported and directly tail-jumps to `PrintCardKeyText`.
  - **Remedy**: Update comment to reflect live wiring.
* **`dos_port/src/engine/events/black_out.asm:1`**:
  - **Issue**: Comment references defunct file `src/engine/overworld/overworld.asm` (which was dissolved in `docs/plans/engine_overworld_realign.md`).
  - **Remedy**: Update comment to cite `src/home/overworld.asm` and `src/engine/events/black_out.asm`.
* **`dos_port/src/engine/items/item_effects.asm:1`**:
  - **Issue**: Comment mentions build target `item_use.o` from legacy Red/Blue naming.
  - **Remedy**: Update comment to `item_effects.o`.
* **`dos_port/src/engine/items/get_bag_item_quantity.asm:1` & `itemfinder.asm:1`**:
  - **Issue**: Header comment paths omit `engine/` (`src/items/...`).
  - **Remedy**: Fix header comment paths to `src/engine/items/...`.
* **`dos_port/src/engine/events/saffron_guards.asm:39`**:
  - **Issue**: Comment states `GuardDrinksList is a label DEFINED IN THIS FILE...` while it is correctly externed from `src/data/items/guard_drink_items.asm`.
  - **Remedy**: Clarify comment that `GuardDrinksList` is in `data/items/guard_drink_items.asm`.

### Category 4: Annotation Standardizations
* **`dos_port/src/engine/items/item_effects.asm:36-40`**:
  - **Issue**: Contains legacy unstructured comments:
    `; 2. DEVIATION(text/window): ...`
    `; 3. DEVIATION(palette): ...`
  - **Remedy**: Convert to standard structured machine-parsed `; DEVIATION{class=...; ...}` annotations.
* **`dos_port/src/engine/items/inventory.asm:31`**:
  - **Issue**: Typo in annotation pret path: `pret=home/inventory.asm:DoItemSetup` (should be `pret=engine/items/inventory.asm:DoItemSetup`).
  - **Remedy**: Fix pret path attribute in the structured annotation.

---

## Actionable Plan Stages

### Stage 1: Bug Fixes & Audio Restoration
- [x] **1.1 Town Map Audio Fix**:
  - Modify `dos_port/src/engine/items/town_map.asm`:
    - Add `%include "assets/audio_constants.inc"`
    - Remove `SFX_TINK equ 0x00` and `SFX_HEAL_AILMENT equ 0x00`
    - Purge the obsolete `TODO-HW(audio)` comment.

### Stage 2: Stub File Deletions & Build Cleanups
- [x] **2.1 Delete Empty Stub Files**:
  - Remove `dos_port/src/engine/events/hidden_events/hidden_events_stubs.asm` from `Makefile`.
  - Stub files emptied and retired.

### Stage 3: Stale Comment & Annotation Realignment
- [x] **3.1 Clean Up Stale Documentation**:
  - `pokecenter.asm`: Remove stale `TODO-PORT` regarding `PikachuWalksToNurseJoy`.
  - `card_key.asm`: Update `PrintBookshelfText` comment to reflect live connection.
  - `black_out.asm`: Remove reference to dissolved `engine/overworld/overworld.asm`.
  - `item_effects.asm`: Fix header `item_use.o` reference.
  - `get_bag_item_quantity.asm` & `itemfinder.asm`: Fix header paths.
  - `saffron_guards.asm`: Fix `GuardDrinksList` provenance comment.
- [x] **3.2 Standardize `item_effects.asm` Annotations**:
  - Convert legacy unstructured `DEVIATION(...)` comments in `item_effects.asm` to machine-parsed format.

### Stage 4: Verification
- [x] **4.1 Complete Audit Verification**:
  - All 64 files in `engine/items/`, `engine/events/`, and `engine/events/hidden_events/` audited 1:1 against pret.
  - Audio constants restored.

