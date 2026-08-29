---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- warp_door — golden for the port's DEBUG_WARP_DOOR gate (datastruct).
-- Overworld realign I.5 — PlayMapChangeSound projection: door tile at (PLAYER_STANDING_ROW-1,COL) vs land.

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local gbtext = require("lib.gbtext")
local dump = require("lib.dump")
local scenario = require("lib.scenario")
local seed = require("lib.seed")
local navigate = require("lib.navigate")

local sym = symbols.load()
local text = gbtext.load()
navigate.init(sym, text)

local PALLET_TOWN = 0
local REDS_HOUSE_1F = 37
local BIT_WARP_FROM_CUR_SCRIPT = 3

local function regions()
	local r = dump.standard_regions(sym)
	for _, x in ipairs({
		{ name = "wPlayerMapPos", addr = sym:addr("wCurMap"), size = 5 },
		{ name = "wStatusFlags5to7", addr = sym:addr("wStatusFlags5"), size = 4 },
		{ name = "wMovementFlags", addr = sym:addr("wMovementFlags"), size = 1 },
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
	navigate.walk_until_map("RIGHT", REDS_HOUSE_1F)
	navigate.walk("DOWN", 6)
	navigate.walk("LEFT", 4)
	navigate.walk_until_map("DOWN", PALLET_TOWN)
	navigate.walk("DOWN", 1)
	scenario.wait(60)

	scenario.exec(function()
		seed.debug_new_game(sym, text:encode(seed.PLAYER_NAME))
		local view = sym:addr("wOverworldMap") + 7 + 10 -- PALLET_TOWN width 10 blocks
			+ (10 + 6) * (8 >> 1) + (6 >> 1)
		local ptr = sym:addr("wCurrentTileBlockMapViewPointer")
		emu:write8(ptr, view & 0xFF)
		emu:write8(ptr + 1, (view >> 8) & 0xFF)
		emu:write8(sym:addr("wYCoord"), 8)
		emu:write8(sym:addr("wXCoord"), 6)
		emu:write8(sym:addr("wDestinationWarpID"), 0xFF)
		emu:write8(sym:addr("hWarpDestinationMap"), PALLET_TOWN)
		local flags = sym:addr("wStatusFlags3")
		emu:write8(flags, emu:read8(flags) | (1 << BIT_WARP_FROM_CUR_SCRIPT))
	end)
	do
		local deadline = scenario.frame() + 900
		while navigate.read8("wCurMap") ~= PALLET_TOWN do
			assert(scenario.frame() < deadline, "warp_door: warp to Pallet Town never fired")
			scenario.wait(2)
		end
	end
	scenario.wait(30)

	-- Walk north into door warp at (7,6) from one south at (8,6)
	navigate.walk("UP", 1)
	scenario.wait(60)

	scenario.exec(function()
		dump.write("warp_door", regions(), {
			frame = scenario.frame(),
			description = "Pallet Town (8,6) walks north into door warp at (7,6), PlayMapChangeSound samples door tile at ROW-1 correctly (GO_INSIDE)",
		})
	end)
end)
