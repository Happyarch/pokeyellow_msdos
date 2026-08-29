---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- poison_tick — golden for the port's DEBUG_POISON gate (differ class "datastruct":
-- WRAM game data only, no video compare).
--
-- Overworld realign I.3 — A2 seam: ApplyOutOfBattlePoisonDamage every 4th step.
-- Seeds a poisoned party mon (HP=10, PSN status), walks 4-step square loop on Pallet
-- Town open area (5,5)->(5,6)->(6,6)->(6,5)->(5,5) to trigger tick (HP 10->9).

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

local PALLET_TOWN = 0
local PALLET_TOWN_WIDTH = 10
local BIT_WARP_FROM_CUR_SCRIPT = 3

local function regions()
	local r = dump.standard_regions(sym)
	for _, x in ipairs({
		{ name = "wPlayerMapPos", addr = sym:addr("wCurMap"), size = 5 },
		{ name = "wStatusFlags5to7", addr = sym:addr("wStatusFlags5"), size = 4 },
		{ name = "wMovementFlags", addr = sym:addr("wMovementFlags"), size = 1 },
		{ name = "wStepCounter", addr = sym:addr("wStepCounter"), size = 1 },
		{ name = "wPlayerDir", addr = sym:addr("wPlayerDirection"), size = 1 },
		{ name = "wWalkCounter", addr = sym:addr("wWalkCounter"), size = 1 },
	}) do
		r[#r + 1] = x
	end
	return r
end

scenario.run(function()
	navigate.boot_to_main_menu()
	navigate.new_game_to_bedroom()
	navigate.walk("RIGHT", 1)
	navigate.walk("UP", 5)
	navigate.walk_until_map("RIGHT", 37) -- REDS_HOUSE_1F
	navigate.walk("DOWN", 6)
	navigate.walk("LEFT", 4)
	navigate.walk_until_map("DOWN", 0) -- PALLET_TOWN
	navigate.walk("DOWN", 1)
	scenario.wait(60)

	scenario.exec(function()
		seed.debug_new_game(sym, text:encode(seed.PLAYER_NAME))
		-- poison first mon: HP=10, status PSN (0x08), wStepCounter 0->252 after 4 steps triggers
		emu:write8(sym:addr("wPartyMon1HP"), 0)
		emu:write8(sym:addr("wPartyMon1HP")+1, 10)
		emu:write8(sym:addr("wPartyMon1Status"), 0x08)
		emu:write8(sym:addr("wStepCounter"), 0)
		-- warp to Pallet Town (8,8)
		local view = sym:addr("wOverworldMap") + 7 + PALLET_TOWN_WIDTH
			+ (PALLET_TOWN_WIDTH + 6) * (8 >> 1) + (8 >> 1)
		local ptr = sym:addr("wCurrentTileBlockMapViewPointer")
		emu:write8(ptr, view & 0xFF)
		emu:write8(ptr + 1, (view >> 8) & 0xFF)
		emu:write8(sym:addr("wYCoord"), 8)
		emu:write8(sym:addr("wXCoord"), 8)
		emu:write8(sym:addr("wDestinationWarpID"), 0xFF)
		emu:write8(sym:addr("hWarpDestinationMap"), PALLET_TOWN)
		local flags = sym:addr("wStatusFlags3")
		emu:write8(flags, emu:read8(flags) | (1 << BIT_WARP_FROM_CUR_SCRIPT))
	end)
	do
		local deadline = scenario.frame() + 900
		while navigate.read8("wCurMap") ~= PALLET_TOWN do
			assert(scenario.frame() < deadline, "poison_tick: warp to Pallet Town never fired")
			scenario.wait(2)
		end
	end
	do
		local y, x = navigate.coords()
		assert(y == 8 and x == 8, ("poison_tick: warp off (8,8) at (%d,%d)"):format(y,x))
	end
	scenario.wait(30)

	-- Walk 4 steps: up 2, down 2 on Pallet (8,8)->(6,8)->(8,8), 4th step triggers poison
	navigate.walk("UP", 2)
	scenario.wait(20)
	navigate.walk("DOWN", 2)
	scenario.wait(30)

	scenario.exec(function()
		dump.write("poison_tick", regions(), {
			frame = scenario.frame(),
			description = "Pallet Town poison tick: PSN mon HP=10 at (8,8) walks 4 steps up 2 + down 2 to (8,8), wStepCounter 0->252 triggers ApplyOutOfBattlePoisonDamage HP 10->9",
		})
	end)
end)
