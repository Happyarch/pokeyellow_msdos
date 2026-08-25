---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- vending_machine — golden scenario for Vending Machine drinks menu:
-- VendingMachineMenu (engine/events/vending_machine.asm), HasEnoughMoney,
-- GiveItem, SubBCD, VendingPrices, and out-of-money rejection.
--
-- Interacts with Celadon Mart Roof vending machine with $610 money:
-- 1. Buys Fresh Water #1 ($200 -> $410 remaining).
-- 2. Buys Fresh Water #2 ($200 -> $210 remaining).
-- 3. Buys Fresh Water #3 ($200 -> $10 remaining).
-- 4. Attempts to buy Fresh Water #4 ($200 needed, $10 held) -> rejected with "Oops, not enough money!".
-- 5. Cancels / exits to overworld.

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

local CELADON_MART_ROOF = 0x7E -- constants/map_constants.asm: map_const 10, 4
local MAP_WIDTH_BLOCKS = 10
local BIT_WARP_FROM_CUR_SCRIPT = 3 -- constants/ram_constants.asm
local SPRITE_FACING_UP = 4         -- constants/sprite_data_constants.asm

local TALK_Y, TALK_X = 2, 10 -- one tile south of Vending Machine 1 (bg_event 10, 1)

scenario.run(function()
	navigate.boot_to_main_menu()
	navigate.new_game_to_bedroom()
	scenario.wait(60)

	scenario.exec(function()
		seed.player(sym, text:encode(seed.PLAYER_NAME))
		seed.party(sym, text:encode(seed.PLAYER_NAME))
		seed.items(sym, {}) -- empty bag
		seed.pokedex(sym)
		seed.badges(sym)
		-- Seed $610 (enough for 3 Fresh Waters at $200 each + $10 remainder)
		seed.money(sym, "\x00\x06\x10")

		-- Script warp straight into CELADON_MART_ROOF
		local view = sym:addr("wOverworldMap") + 7 + MAP_WIDTH_BLOCKS
			+ (MAP_WIDTH_BLOCKS + 6) * (TALK_Y >> 1) + (TALK_X >> 1)
		local ptr = sym:addr("wCurrentTileBlockMapViewPointer")
		emu:write8(ptr, view & 0xFF)
		emu:write8(ptr + 1, (view >> 8) & 0xFF)
		emu:write8(sym:addr("wYCoord"), TALK_Y)
		emu:write8(sym:addr("wXCoord"), TALK_X)
		emu:write8(sym:addr("wDestinationWarpID"), 0xFF)
		emu:write8(sym:addr("hWarpDestinationMap"), CELADON_MART_ROOF)
		local flags = sym:addr("wStatusFlags3")
		emu:write8(flags, emu:read8(flags) | (1 << BIT_WARP_FROM_CUR_SCRIPT))
	end)

	do
		local deadline = scenario.frame() + 900
		while navigate.read8("wCurMap") ~= CELADON_MART_ROOF do
			assert(scenario.frame() < deadline, "vending_machine: script warp to Celadon Mart Roof never fired")
			scenario.wait(2)
		end
	end
	do
		local sy, sx = navigate.coords()
		assert(sy == TALK_Y and sx == TALK_X,
			("vending_machine: warp moved player off (%d,%d) — at (%d,%d)"):format(TALK_Y, TALK_X, sy, sx))
	end
	scenario.wait(30)

	-- Turn UP toward Vending Machine
	local turn_deadline = scenario.frame() + 300
	while navigate.read8("wSpritePlayerStateData1FacingDirection") ~= SPRITE_FACING_UP do
		assert(scenario.frame() < turn_deadline, "vending_machine: player never turned UP")
		input.tap("UP", 2, 8)
	end
	scenario.wait(10)

	local fresh_water_text = text:encode("FRESH WATER")
	local pop_text = text:encode("popped out!")
	local out_money_text = text:encode("not enough")

	-- Purchase Drink 1 (FRESH WATER)
	navigate.tap_until("A", fresh_water_text, 1800)
	scenario.wait(20)
	input.tap("A", 2, 8) -- select FRESH WATER (item 0)
	navigate.wait_for_text(pop_text, 1800)
	scenario.wait(20)
	navigate.dismiss_text(pop_text, 600)
	scenario.wait(30)

	-- Purchase Drink 2 (FRESH WATER)
	navigate.tap_until("A", fresh_water_text, 1800)
	scenario.wait(20)
	input.tap("A", 2, 8) -- select FRESH WATER
	navigate.wait_for_text(pop_text, 1800)
	scenario.wait(20)
	navigate.dismiss_text(pop_text, 600)
	scenario.wait(30)

	-- Purchase Drink 3 (FRESH WATER)
	navigate.tap_until("A", fresh_water_text, 1800)
	scenario.wait(20)
	input.tap("A", 2, 8) -- select FRESH WATER
	navigate.wait_for_text(pop_text, 1800)
	scenario.wait(20)
	navigate.dismiss_text(pop_text, 600)
	scenario.wait(30)

	-- Attempt Purchase 4 (Out of money: needs $200, only $10 left)
	navigate.tap_until("A", fresh_water_text, 1800)
	scenario.wait(20)
	input.tap("A", 2, 8) -- select FRESH WATER
	navigate.wait_for_text(out_money_text, 1800)
	scenario.wait(20)
	navigate.dismiss_text(out_money_text, 600)
	scenario.wait(60)

	-- Assert final state
	scenario.exec(function()
		local money_b0 = emu:read8(sym:addr("wPlayerMoney"))
		local money_b1 = emu:read8(sym:addr("wPlayerMoney") + 1)
		local money_b2 = emu:read8(sym:addr("wPlayerMoney") + 2)
		-- 610 - 200 - 200 - 200 = 10 (BCD: \x00\x00\x10)
		assert(money_b0 == 0x00 and money_b1 == 0x00 and money_b2 == 0x10,
			("vending_machine: expected money $10, got %02X%02X%02X"):format(money_b0, money_b1, money_b2))

		local num_items = emu:read8(sym:addr("wNumBagItems"))
		assert(num_items == 1, ("vending_machine: expected 1 item type in bag, got %d"):format(num_items))
		local item_id = emu:read8(sym:addr("wBagItems"))
		local item_qty = emu:read8(sym:addr("wBagItems") + 1)
		assert(item_id == 60 and item_qty == 3,
			("vending_machine: expected Fresh Water (60) x3, got item %d x%d"):format(item_id, item_qty))

		dump.write("vending_machine", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "Celadon Mart Roof vending machine complete: purchased 3 Fresh Waters ($200 each), "
				.. "tested 4th purchase out-of-money rejection ($10 left), and returned cleanly to overworld",
		})
	end)
end)
