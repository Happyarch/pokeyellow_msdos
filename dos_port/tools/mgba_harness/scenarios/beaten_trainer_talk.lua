---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- beaten_trainer_talk — golden for the port's DEBUG_BEATEN_TALK gate (datastruct).
-- Overworld realign I.6 — A7: beaten trainer prints after-battle text, no battle.

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

local ROUTE_3 = 0x0E
local ROUTE_3_WIDTH = 35
local BIT_WARP_FROM_CUR_SCRIPT = 3

local function regions()
	local r = dump.standard_regions(sym)
	for _, x in ipairs({
		{ name = "wPlayerMapPos", addr = sym:addr("wCurMap"), size = 5 },
		{ name = "wStatusFlags5to7", addr = sym:addr("wStatusFlags5"), size = 4 },
		{ name = "wMovementFlags", addr = sym:addr("wMovementFlags"), size = 1 },
		{ name = "wBattleFlags", addr = sym:addr("wIsInBattle"), size = 4 },
		{ name = "wCurOpponent", addr = sym:addr("wCurOpponent"), size = 1 },
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
		-- warp to Route 3 (12,8) in front of Youngster
		local view = sym:addr("wOverworldMap") + 7 + ROUTE_3_WIDTH
			+ (ROUTE_3_WIDTH + 6) * (8 >> 1) + (12 >> 1)
		local ptr = sym:addr("wCurrentTileBlockMapViewPointer")
		emu:write8(ptr, view & 0xFF)
		emu:write8(ptr + 1, (view >> 8) & 0xFF)
		emu:write8(sym:addr("wYCoord"), 8)
		emu:write8(sym:addr("wXCoord"), 12)
		emu:write8(sym:addr("wDestinationWarpID"), 0xFF)
		emu:write8(sym:addr("hWarpDestinationMap"), ROUTE_3)
		local flags = sym:addr("wStatusFlags3")
		emu:write8(flags, emu:read8(flags) | (1 << BIT_WARP_FROM_CUR_SCRIPT))
		-- set EVENT_BEAT_ROUTE_3_TRAINER_0 ($3E2 -> byte 0x7C, bit 2)
		emu:write8(sym:addr("wEventFlags") + 0x7C, 0xFF)
	end)
	do
		local deadline = scenario.frame() + 900
		while navigate.read8("wCurMap") ~= ROUTE_3 do
			assert(scenario.frame() < deadline, "beaten_trainer_talk: warp to Route 3 never fired")
			scenario.wait(2)
		end
	end
	scenario.wait(30)

	-- Press A in front of trainer (facing west? Actually trainer at (13,8) east of player)
	-- Player at (12,8) facing east, trainer at (13,8). Press A.
	input.tap("A", 8, 30)
	scenario.wait(60)
	-- Advance one text page if needed
	input.tap("A", 8, 30)
	scenario.wait(60)

	scenario.exec(function()
		dump.write("beaten_trainer_talk", regions(), {
			frame = scenario.frame(),
			description = "Route 3 (12,8) re-talks beaten Youngster, after-battle text prints, no battle (A7)",
		})
	end)
end)
