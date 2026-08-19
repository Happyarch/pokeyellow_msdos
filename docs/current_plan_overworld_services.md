# Current Plan: De-Stubbing Overworld Service Wrappers

Implementation plan to de-stub overworld service dialog wrappers in `dos_port/src/engine/menus/main_menu_stubs.asm` (`DisplayPokemonCenterDialogue_`, `DisplayPokemartDialogue_`, `VendingMachineMenu`, `CeladonPrizeMenu`), connecting them to their completed backend data engines.

## Background & Scope

Five overworld service wrappers exist in `dos_port/src/engine/menus/main_menu_stubs.asm`. While `CableClubNPC` remains stubbed for Phase 4 (Serial Link), the other four service wrappers are ready to be fully de-stubbed and backed by faithful pret implementations:
1. `DisplayPokemonCenterDialogue_` (line 39) $\to$ `src/engine/events/pokecenter.asm`
2. `DisplayPokemartDialogue_` (line 32) $\to$ `src/engine/events/pokemart.asm`
3. `VendingMachineMenu` (line 44) $\to$ `src/engine/events/vending_machine.asm`
4. `CeladonPrizeMenu` (line 49) $\to$ `src/engine/events/prize_menu.asm`

Their underlying functional engines (`HealParty`, `AnimateHealingMachine`, `DoBuySellQuitMenu`, `DisplayListMenuID`, `DisplayChooseQuantityMenu`, `AddItemToInventory_`, `SubtractAmountPaidFromMoney_`, `GiveItem`, `HasEnoughMoney`, `HasEnoughCoins`, `PrintBCDNumber`) are already 100% complete in the port.

---

## Technical Architecture

### 1. Pokémon Center Healing Flow (`pokecenter.asm`)
- **Pret Source:** `engine/events/pokecenter.asm`, `engine/events/set_blackout_map.asm`, `data/maps/rest_house_maps.asm`.
- **Routines:**
  - `DisplayPokemonCenterDialogue_`: Pewter sleeping check, welcome message, YES/NO prompt, blackout map setter, Pikachu walk-to-nurse coordination (`PikachuWalksToNurseJoy`), Nurse Joy bowing (`Func_6ebb`), machine lights (`AnimateHealingMachine`), party heal (`HealParty`), audio restart, sprite restoration, and farewell text.
  - `SpriteFunc_34a1` (`src/home/map_objects.asm`): Decodes sprite image index using `ImageBaseOffset` nibble swap and `hSpriteImageIndex`.
  - `SetLastBlackoutMap` (`src/engine/events/set_blackout_map.asm`): Updates `wLastBlackoutMap` unless inside a Safari Zone Rest House.

### 2. Poké Mart Transaction Loop (`pokemart.asm`)
- **Pret Source:** `engine/events/pokemart.asm`.
- **Routines:**
  - `DisplayPokemartDialogue_`: Main loop driving `BUY_SELL_QUIT_MENU` and `MONEY_BOX`.
  - Buying flow: `INIT_OTHER_ITEM_LIST`, priced item list display, quantity selection (`DisplayChooseQuantityMenu`), BCD money check (`StringCmp`), bag capacity check (`AddItemToInventory`), deduction (`SubtractAmountPaidFromMoney`), and `SFX_PURCHASE` sound playback.
  - Selling flow: `INIT_BAG_ITEM_LIST`, key item / HM rejection, 50% price halving (`hHalveItemPrices = 2`), confirmation prompt, money addition (`AddAmountSoldToMoney`), and item removal (`RemoveItemFromInventory`).

### 3. Vending Machines (`vending_machine.asm`)
- **Pret Source:** `engine/events/vending_machine.asm`, `data/items/vending_prices.asm`.
- **Routines:**
  - `VendingMachineMenu`: Drinks menu (Fresh Water, Soda Pop, Lemonade, Cancel), BCD money check, bag capacity check, dispense sound loop (`SFX_PUSH_BOULDER`), money deduction, and drink item delivery (`GiveItem`).

### 4. Celadon Prize Corner (`prize_menu.asm`)
- **Pret Source:** `engine/events/prize_menu.asm`, `data/events/prizes.asm`, `data/events/prize_mon_levels.asm`.
- **Routines:**
  - `CeladonPrizeMenu`: Coin Case verification, coin balance display header, TM and Pokémon prize menu population, BCD coin verification (`HasEnoughCoins`), coin deduction, and TM (`GiveItem`) or Pokémon (`GivePokemon`) delivery.

---

## Action Items & Tasks

### Phase 1: Generator Updates & Text Asset Generation
- [ ] Add Poké Center far text (`_PokemonCenterWelcomeText`, `_ShallWeHealYourPokemonText`, `_NeedYourPokemonText`, `_PokemonFightingFitText`, `_PokemonCenterFarewellText`, `_LooksContentText`) to `dos_port/tools/generators/gen_overworld_strings.py`.
- [ ] Add Poké Mart far text (`_PokemartBuyingGreetingText`, `_PokemartTellBuyPriceText`, `_PokemartBoughtItemText`, `_PokemartNotEnoughMoneyText`, `_PokemartItemBagFullText`, `_PokemonSellingGreetingText`, `_PokemartTellSellPriceText`, `_PokemartItemBagEmptyText`, `_PokemartUnsellableItemText`, `_PokemartThankYouText`, `_PokemartAnythingElseText`) to `gen_overworld_strings.py`.
- [ ] Add Vending Machine far text (`_VendingMachineText1`, `_VendingMachineText4`, `_VendingMachineText5`, `_VendingMachineText6`, `_VendingMachineText7`) to `gen_overworld_strings.py`.
- [ ] Add Prize Corner far text (`_RequireCoinCaseText`, `_ExchangeCoinsForPrizesText`, `_WhichPrizeText`, `_HereYouGoText`, `_SoYouWantPrizeText`, `_SorryNeedMoreCoinsText`, `_OopsYouDontHaveEnoughRoomText`, `_OhFineThenText`) to `gen_overworld_strings.py`.
- [ ] Run `gen_overworld_strings.py` to generate `assets/pokecenter_text.inc`, `assets/pokemart_text.inc`, `assets/vending_machine_text.inc`, `assets/prize_menu_text.inc`.
- [ ] Create Tier-1 data carrier files:
  - `src/data/maps/rest_house_maps.asm` (`SafariZoneRestHouses`)
  - `src/data/items/vending_prices.asm` (`VendingPrices`)
  - `src/data/events/prizes.asm` (`PrizeDifferentMenuPtrs`, `PrizeMenu*Entries/Cost`)
  - `src/data/events/prize_mon_levels.asm` (`PrizeMonLevelDictionary`)

### Phase 2: Home & Prerequisite Helpers
- [ ] Implement `SpriteFunc_34a1` in `dos_port/src/home/map_objects.asm`.
- [ ] Implement `PikachuWalksToNurseJoy` in `dos_port/src/engine/pikachu/pikachu_emotions.asm`.
- [ ] Implement `SetLastBlackoutMap` in `dos_port/src/engine/events/set_blackout_map.asm`.
- [ ] Export `SubtractAmountPaidFromMoney` in `dos_port/src/home/inventory.asm` and restore `PlaySoundWaitForCurrent` / `WaitForSoundToFinish` in `AddAmountSoldToMoney`.

### Phase 3: Service Body Translations
- [ ] Port `dos_port/src/engine/events/pokecenter.asm` (`DisplayPokemonCenterDialogue_`).
- [ ] Port `dos_port/src/engine/events/pokemart.asm` (`DisplayPokemartDialogue_`).
- [ ] Port `dos_port/src/engine/events/vending_machine.asm` (`VendingMachineMenu`).
- [ ] Port `dos_port/src/engine/events/prize_menu.asm` (`CeladonPrizeMenu`).

### Phase 4: Stub Retirement & Build System Integration
- [ ] Delete `DisplayPokemartDialogue_`, `DisplayPokemonCenterDialogue_`, `VendingMachineMenu`, and `CeladonPrizeMenu` stubs and annotations from `dos_port/src/engine/menus/main_menu_stubs.asm`.
- [ ] Add new `.asm` files to `ENGINE_SRCS` and `DATA_SRCS` in `dos_port/Makefile`.
- [ ] Add asset include prerequisites in `dos_port/Makefile`.
- [ ] Verify clean build via `make -C dos_port`.

### Phase 5: Verification & Gating
- [ ] Run `dos_port/tools/faithdiff` on all newly ported service routines.
- [ ] Run `dos_port/tools/lint_pret_labels --no-scan --strict-claims`.
- [ ] Run `make -C dos_port static_gate`.
- [ ] Run `make -C dos_port fidelity`.
- [ ] Author and run golden test scenarios for Pokémon Center healing, Poké Mart purchasing/selling, Vending machines, and Prize Corner.
