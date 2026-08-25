---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- prize_corner — golden scenario for Celadon Game Corner Prize Menu:
-- CeladonPrizeMenu (engine/events/prize_menu.asm), HasEnoughCoins, GivePokemon,
-- SubBCD, PrizeDifferentMenuPtrs, PrizeMonLevelDictionary, and insufficient-coins rejection.
--
-- Interacts with Celadon Prize Room Vendor 1 (Pokemon vendor: Abra 230 coins, Vulpix 1000 coins, Wigglytuff 2680 coins) with 250 coins:
-- 1. Attempts to purchase Vulpix (1000 coins) -> confirms YES -> rejected with "You need more coins!".
-- 2. Purchases Abra (230 coins) -> confirms YES -> receives Abra, declines nickname, 20 coins remaining.
-- 3. Returns cleanly to overworld.

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

local GAME_CORNER_PRIZE_ROOM = 0x89 -- constants/map_constants.asm: map_const 5, 4
local MAP_WIDTH_BLOCKS = 5
local BIT_WARP_FROM_CUR_SCRIPT = 3  -- constants/ram_constants.asm
local SPRITE_FACING_UP = 4          -- constants/sprite_data_constants.asm

local TALK_Y, TALK_X = 3, 2 -- one tile south of Prize Vendor 1 (bg_event 2, 2)
local COIN_CASE = 69        -- constants/item_constants.asm: $45 = 69

scenario.run(function()
	navigate.boot_to_main_menu()
	navigate.new_game_to_bedroom()
	scenario.wait(60)

	scenario.exec(function()
		seed.player(sym, text:encode(seed.PLAYER_NAME))
		-- Seed a 1-mon party so slot 2 is open for Abra
		local party = {
			{ species = 84, level = 15, pokes = { [3] = 57 } }, -- STARTER_PIKACHU
		}
		seed.party(sym, text:encode(seed.PLAYER_NAME), party)
		-- Seed bag with COIN_CASE ($45 = 69)
		seed.items(sym, {
			{ COIN_CASE, 1 },
		})
		seed.pokedex(sym)
		seed.badges(sym)
		seed.money(sym)

		-- Seed 250 coins (BCD: \x02\x50)
		local coins_addr = sym:addr("wPlayerCoins")
		emu:write8(coins_addr, 0x02)
		emu:write8(coins_addr + 1, 0x50)

		-- Script warp straight into GAME_CORNER_PRIZE_ROOM
		local view = sym:addr("wOverworldMap") + 7 + MAP_WIDTH_BLOCKS
			+ (MAP_WIDTH_BLOCKS + 6) * (TALK_Y >> 1) + (TALK_X >> 1)
		local ptr = sym:addr("wCurrentTileBlockMapViewPointer")
		emu:write8(ptr, view & 0xFF)
		emu:write8(ptr + 1, (view >> 8) & 0xFF)
		emu:write8(sym:addr("wYCoord"), TALK_Y)
		emu:write8(sym:addr("wXCoord"), TALK_X)
		emu:write8(sym:addr("wDestinationWarpID"), 0xFF)
		emu:write8(sym:addr("hWarpDestinationMap"), GAME_CORNER_PRIZE_ROOM)
		local flags = sym:addr("wStatusFlags3")
		emu:write8(flags, emu:read8(flags) | (1 << BIT_WARP_FROM_CUR_SCRIPT))
	end)

	do
		local deadline = scenario.frame() + 900
		while navigate.read8("wCurMap") ~= GAME_CORNER_PRIZE_ROOM do
			assert(scenario.frame() < deadline, "prize_corner: script warp to Prize Room never fired")
			scenario.wait(2)
		end
	end
	do
		local sy, sx = navigate.coords()
		assert(sy == TALK_Y and sx == TALK_X,
			("prize_corner: warp moved player off (%d,%d) — at (%d,%d)"):format(TALK_Y, TALK_X, sy, sx))
	end
	scenario.wait(30)

	-- Turn UP toward Prize Vendor 1
	local turn_deadline = scenario.frame() + 300
	while navigate.read8("wSpritePlayerStateData1FacingDirection") ~= SPRITE_FACING_UP do
		assert(scenario.frame() < turn_deadline, "prize_corner: player never turned UP")
		input.tap("UP", 2, 8)
	end
	scenario.wait(10)

	local prizes_text = text:encode("prizes")
	local abra_text = text:encode("ABRA")
	local more_coins_text = text:encode("more coins")
	local yes_text = text:encode("YES")
	local nickname_text = text:encode("give a nickname")

	-- === 1. Attempt purchase with insufficient coins (VULPIX 1000 coins) ===
	navigate.tap_until("A", prizes_text, 1800)
	scenario.wait(40)
	-- Advance "We exchange your coins for prizes." into prize menu
	navigate.ensure_text("A", abra_text, 1800)
	scenario.wait(40)
	-- Move cursor DOWN to VULPIX (item 1)
	input.tap("DOWN", 2, 8)
	scenario.wait(30)
	-- Select VULPIX -> opens YES/NO menu
	navigate.ensure_text("A", yes_text, 1800)
	scenario.wait(40)
	-- Confirm YES with A -> "You need more coins!"
	navigate.ensure_text("A", more_coins_text, 1800)
	scenario.wait(40)
	-- Dismiss text back to overworld
	navigate.dismiss_text(more_coins_text, 600)
	scenario.wait(60)

	-- === 2. Successful purchase of ABRA (230 coins) ===
	navigate.tap_until("A", prizes_text, 1800)
	scenario.wait(40)
	-- Advance into prize menu
	navigate.ensure_text("A", abra_text, 1800)
	scenario.wait(40)
	-- Select ABRA (item 0) -> opens YES/NO menu
	navigate.ensure_text("A", yes_text, 1800)
	scenario.wait(40)
	-- Confirm YES with A -> GivePokemon receives Abra and asks "Do you want to give a nickname to ABRA?"
	input.tap("A", 2, 8)
	navigate.wait_for_text(nickname_text, 1800)
	scenario.wait(60)
	-- Decline nickname by tapping B until the prompt/box clears
	while navigate.tilemap():find(nickname_text, 1, true) do
		input.tap("B", 2, 10)
		scenario.wait(10)
	end
	scenario.wait(60)

	-- Assert final state
	scenario.exec(function()
		local coins_b0 = emu:read8(sym:addr("wPlayerCoins"))
		local coins_b1 = emu:read8(sym:addr("wPlayerCoins") + 1)
		local party_count = emu:read8(sym:addr("wPartyCount"))
		-- 250 - 230 = 20 (BCD: \x00\x20)
		assert(coins_b0 == 0x00 and coins_b1 == 0x20,
			("prize_corner: expected 20 coins, got %02X%02X"):format(coins_b0, coins_b1))

		assert(party_count == 2, ("prize_corner: expected 2 party mons, got %d"):format(party_count))

		dump.write("prize_corner", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "Celadon Prize Room complete: tested insufficient-coins rejection on Vulpix (1000 coins), "
				.. "successfully purchased Abra for 230 coins (20 coins left in Coin Case), and received Abra in party",
		})
	end)
end)
