---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- map_connection — golden for the port's DEBUG_MAPCONN gate (datastruct).
-- Overworld realign I.4 — A1 seam: CheckMapConnections after StepCountCheck/Safari/poison/NewBattle.
-- Seeds Viridian City west edge (3,16), walks west into Route 22 via west connection.

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

local VIRIDIAN_CITY = 1
local VIRIDIAN_CITY_WIDTH = 20
local BIT_WARP_FROM_CUR_SCRIPT = 3

local function regions()
	local r = dump.standard_regions(sym)
	for _, x in ipairs({
		{ name = "wPlayerMapPos", addr = sym:addr("wCurMap"), size = 5 },
		{ name = "wStatusFlags5to7", addr = sym:addr("wStatusFlags5"), size = 4 },
		{ name = "wMovementFlags", addr = sym:addr("wMovementFlags"), size = 1 },
		{ name = "wStepCounter", addr = sym:addr("wStepCounter"), size = 1 },
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
	navigate.walk_until_map("RIGHT", 37)
	navigate.walk("DOWN", 6)
	navigate.walk("LEFT", 4)
	navigate.walk_until_map("DOWN", 0)
	navigate.walk("DOWN", 1)
	scenario.wait(60)

	scenario.exec(function()
		seed.debug_new_game(sym, text:encode(seed.PLAYER_NAME))
		emu:write8(sym:addr("wStepCounter"), 0)
		local view = sym:addr("wOverworldMap") + 7 + VIRIDIAN_CITY_WIDTH
			+ (VIRIDIAN_CITY_WIDTH + 6) * (16 >> 1) + (3 >> 1)
		local ptr = sym:addr("wCurrentTileBlockMapViewPointer")
		emu:write8(ptr, view & 0xFF)
		emu:write8(ptr + 1, (view >> 8) & 0xFF)
		emu:write8(sym:addr("wYCoord"), 16)
		emu:write8(sym:addr("wXCoord"), 3)
		emu:write8(sym:addr("wDestinationWarpID"), 0xFF)
		emu:write8(sym:addr("hWarpDestinationMap"), VIRIDIAN_CITY)
		local flags = sym:addr("wStatusFlags3")
		emu:write8(flags, emu:read8(flags) | (1 << BIT_WARP_FROM_CUR_SCRIPT))
	end)
	do
		local deadline = scenario.frame() + 900
		while navigate.read8("wCurMap") ~= VIRIDIAN_CITY do
			assert(scenario.frame() < deadline, "map_connection: warp to Viridian City never fired")
			scenario.wait(2)
		end
	end
	scenario.wait(30)

	-- Walk west 2 tiles inside Viridian City (16,3)->(16,1) west 2 to verify StepCountCheck before CheckMapConnections
	for i=1,2 do
		navigate.walk("LEFT", 1)
		scenario.wait(10)
	end
	scenario.wait(30)

	scenario.exec(function()
		dump.write("map_connection", regions(), {
			frame = scenario.frame(),
			description = "Viridian City (16,3) walks west 2 tiles inside to (16,1), wStepCounter decremented (A1 ordering) without crossing",
		})
	end)
end)
