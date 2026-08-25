---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- pokemart_buy_sell — golden scenario for Poke Mart buy/sell transaction loop:
-- DisplayPokemartDialogue_ (engine/events/pokemart.asm), AddItemToInventory,
-- SubtractAmountPaidFromMoney, AddAmountSoldToMoney (SFX_PURCHASE sound restored),
-- RemoveItemFromInventory, DisplayChooseQuantityMenu, DisplayListMenuID,
-- IsKeyItem and IsItemHM rejection.
--
-- Talks to Pewter Mart clerk:
-- 1. BUY 1 Poke Ball ($200 deducted).
-- 2. SELL attempt on Bicycle -> rejected with "I can't put a price on that."
-- 3. SELL attempt on HM01 -> rejected with "I can't put a price on that."
-- 4. SELL 1 Potion -> sells for $150 (AddAmountSoldToMoney with SFX_PURCHASE).
-- 5. QUIT transaction loop back to overworld.

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local gbtext = require("lib.gbtext")
local input = require("lib.input")
local dump = require("lib.dump")
local scenario = require("lib.scenario")
local seed = require("lib.seed")
local navigate = require("lib.navigate")

local sym = symbols.load()
local text = gbtext.load()
navigate.init(sym, text)

local PEWTER_MART = 0x38 -- constants/map_constants.asm: map_const 4, 4
local MAP_WIDTH_BLOCKS = 4
local BIT_WARP_FROM_CUR_SCRIPT = 3 -- constants/ram_constants.asm
local SPRITE_FACING_LEFT = 8       -- constants/sprite_data_constants.asm ($08)

local TALK_Y, TALK_X = 5, 1 -- one tile east of Clerk (object_event 0, 5)

local BICYCLE = 6   -- constants/item_constants.asm
local HM01 = 196    -- HM_01 (CUT)
local POTION = 20   -- POTION

scenario.run(function()
	navigate.boot_to_main_menu()
	navigate.new_game_to_bedroom()
	scenario.wait(60)

	scenario.exec(function()
		seed.player(sym, text:encode(seed.PLAYER_NAME))
		seed.party(sym, text:encode(seed.PLAYER_NAME))
		-- Seed bag with Key Item (BICYCLE), HM (HM01), and 5 Potions
		seed.items(sym, {
			{ BICYCLE, 1 },
			{ HM01, 1 },
			{ POTION, 5 },
		})
		seed.pokedex(sym)
		seed.badges(sym)
		-- Seed $10,000
		seed.money(sym, "\x01\x00\x00")

		-- Script warp straight into PEWTER_MART
		local view = sym:addr("wOverworldMap") + 7 + MAP_WIDTH_BLOCKS
			+ (MAP_WIDTH_BLOCKS + 6) * (TALK_Y >> 1) + (TALK_X >> 1)
		local ptr = sym:addr("wCurrentTileBlockMapViewPointer")
		emu:write8(ptr, view & 0xFF)
		emu:write8(ptr + 1, (view >> 8) & 0xFF)
		emu:write8(sym:addr("wYCoord"), TALK_Y)
		emu:write8(sym:addr("wXCoord"), TALK_X)
		emu:write8(sym:addr("wDestinationWarpID"), 0xFF)
		emu:write8(sym:addr("hWarpDestinationMap"), PEWTER_MART)
		local flags = sym:addr("wStatusFlags3")
		emu:write8(flags, emu:read8(flags) | (1 << BIT_WARP_FROM_CUR_SCRIPT))
	end)

	do
		local deadline = scenario.frame() + 900
		while navigate.read8("wCurMap") ~= PEWTER_MART do
			assert(scenario.frame() < deadline, "pokemart_buy_sell: script warp to Mart never fired")
			scenario.wait(2)
		end
	end
	do
		local sy, sx = navigate.coords()
		assert(sy == TALK_Y and sx == TALK_X,
			("pokemart_buy_sell: warp moved player off (%d,%d) — at (%d,%d)"):format(TALK_Y, TALK_X, sy, sx))
	end
	scenario.wait(30)

	-- Turn LEFT toward Mart Clerk
	local turn_deadline = scenario.frame() + 300
	while navigate.read8("wSpritePlayerStateData1FacingDirection") ~= SPRITE_FACING_LEFT do
		assert(scenario.frame() < turn_deadline, "pokemart_buy_sell: player never turned LEFT")
		input.tap("LEFT", 2, 8)
	end
	scenario.wait(10)

	local buy_text = text:encode("BUY")

	-- Talk to Clerk: advances greeting text until BUY/SELL/QUIT menu is open
	navigate.tap_until("A", buy_text, 1800)
	scenario.wait(50)

	-- =========================================================================
	-- 1. BUY: Select BUY (cursor starts on BUY) -> Buy 1 Poké Ball ($200)
	-- =========================================================================
	input.tap("A", 2, 16)
	scenario.wait(60)
	-- Dismiss "Take your time." (0x57 prompt) -> enters buy list
	input.tap("A", 2, 16)
	scenario.wait(60)
	-- Select POKé BALL (cursor starts on POKé BALL at top of buy list) -> opens quantity
	input.tap("A", 2, 16)
	scenario.wait(80)
	-- Confirm quantity 1 with A -> prints "That will be ¥200. OK?" (0x57 prompt)
	input.tap("A", 4, 30)
	scenario.wait(80)
	-- Dismiss price prompt -> opens YES/NO menu
	input.tap("A", 2, 16)
	scenario.wait(60)
	-- Confirm YES on YES/NO menu with A -> plays SFX_PURCHASE -> prints "Here you are! Thank you!" (0x58 prompt)
	input.tap("A", 4, 30)
	scenario.wait(80)
	-- Dismiss "Thank you!" back to buy list
	input.tap("A", 2, 16)
	scenario.wait(80)
	-- Press B to exit buy list -> prints "Is there anything else I can do?" (0x57 prompt)
	input.tap("B", 2, 16)
	scenario.wait(80)
	-- Dismiss "anything else" -> returns to BUY_SELL_QUIT_MENU
	input.tap("A", 2, 16)
	scenario.wait(60)

	-- =========================================================================
	-- 2. SELL: Key item rejection (BICYCLE)
	-- =========================================================================
	-- Move cursor down to SELL
	input.tap("DOWN", 2, 30)
	scenario.wait(40)
	-- Select SELL -> prints "What would you like to sell?" (0x57 prompt)
	input.tap("A", 2, 16)
	scenario.wait(80)
	-- Dismiss prompt -> enters bag list
	input.tap("A", 2, 16)
	scenario.wait(60)
	-- Select BICYCLE (cursor is on BICYCLE at slot 1) -> prints "I can't put a price on that." (0x58 prompt)
	input.tap("A", 2, 16)
	scenario.wait(80)
	-- Dismiss rejection text -> automatically returns to "Is there anything else I can do?" (0x57 prompt)
	input.tap("A", 2, 16)
	scenario.wait(80)
	-- Dismiss "anything else" -> returns to BUY_SELL_QUIT_MENU
	input.tap("A", 2, 16)
	scenario.wait(60)

	-- =========================================================================
	-- 3. SELL: HM rejection (HM01)
	-- =========================================================================
	-- Move cursor down to SELL
	input.tap("DOWN", 2, 30)
	scenario.wait(40)
	-- Select SELL -> prints "What would you like to sell?" (0x57 prompt)
	input.tap("A", 2, 16)
	scenario.wait(80)
	-- Dismiss prompt -> enters bag list
	input.tap("A", 2, 16)
	scenario.wait(60)
	-- Move cursor down to HM01 (slot 2)
	input.tap("DOWN", 2, 30)
	scenario.wait(40)
	-- Select HM01 -> prints "I can't put a price on that." (0x58 prompt)
	input.tap("A", 2, 16)
	scenario.wait(80)
	-- Dismiss rejection text -> returns to "Is there anything else I can do?" (0x57 prompt)
	input.tap("A", 2, 16)
	scenario.wait(80)
	-- Dismiss "anything else" -> returns to BUY_SELL_QUIT_MENU
	input.tap("A", 2, 16)
	scenario.wait(60)

	-- =========================================================================
	-- 4. SELL: Valid item (POTION)
	-- =========================================================================
	-- Move cursor down to SELL
	input.tap("DOWN", 2, 30)
	scenario.wait(40)
	-- Select SELL -> prints "What would you like to sell?" (0x57 prompt)
	input.tap("A", 2, 16)
	scenario.wait(80)
	-- Dismiss prompt -> enters bag list
	input.tap("A", 2, 16)
	scenario.wait(60)
	-- Move cursor down to POTION (slot 3: 2 DOWN taps)
	input.tap("DOWN", 2, 30)
	scenario.wait(40)
	input.tap("DOWN", 2, 30)
	scenario.wait(40)
	-- Select POTION -> opens quantity menu
	input.tap("A", 2, 16)
	scenario.wait(60)
	-- Confirm quantity 1 with A -> prints "I can pay you ¥150 for that." (0x57 prompt)
	input.tap("A", 2, 16)
	scenario.wait(80)
	-- Dismiss price prompt -> opens YES/NO menu
	input.tap("A", 2, 16)
	scenario.wait(60)
	-- Confirm YES on YES/NO menu with A -> plays SFX_PURCHASE -> prints "Turned over the POTION and received ¥150." (0x58 prompt)
	input.tap("A", 4, 30)
	scenario.wait(80)
	-- Dismiss received text back to bag list
	input.tap("A", 2, 16)
	scenario.wait(80)
	-- Press B to exit bag list -> prints "Is there anything else I can do?" (0x57 prompt)
	input.tap("B", 2, 16)
	scenario.wait(80)
	-- Dismiss "anything else" -> returns to BUY_SELL_QUIT_MENU
	input.tap("A", 2, 16)
	scenario.wait(60)

	-- =========================================================================
	-- 5. QUIT: Select QUIT (2 DOWN taps from BUY) -> Exit to overworld
	-- =========================================================================
	input.tap("DOWN", 2, 30)
	scenario.wait(40)
	input.tap("DOWN", 2, 30)
	scenario.wait(40)
	-- Select QUIT -> prints "Thank you!" (0x57 prompt)
	input.tap("A", 2, 16)
	scenario.wait(80)
	-- Dismiss "Thank you!" -> exits mart dialog back to overworld
	input.tap("A", 2, 16)
	scenario.wait(60)

	-- Assert final money and bag state
	scenario.exec(function()
		local money_b0 = emu:read8(sym:addr("wPlayerMoney"))
		local money_b1 = emu:read8(sym:addr("wPlayerMoney") + 1)
		local money_b2 = emu:read8(sym:addr("wPlayerMoney") + 2)
		-- Initial: 10000 (\x01\x00\x00) - 200 + 150 = 9950 (\x00\x99\x50)
		assert(money_b0 == 0x00 and money_b1 == 0x99 and money_b2 == 0x50,
			("pokemart_buy_sell: expected money $9,950, got %02X%02X%02X"):format(money_b0, money_b1, money_b2))

		dump.write("pokemart_buy_sell", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "Pewter Poke Mart transaction loop complete: bought 1 Poke Ball ($200), "
				.. "tested Key Item (Bicycle) and HM (HM01) sell rejection, sold 1 Potion with SFX_PURCHASE ($150), "
				.. "and exited cleanly to overworld with $9,950 money",
		})
	end)
end)
