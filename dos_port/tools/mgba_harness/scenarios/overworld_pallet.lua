---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- overworld_pallet — golden for the port's DEBUG_TRANSITION+DEBUG_BASELINE
-- harness: pristine Pallet Town with the player standing at the (8,8) boot
-- spawn, facing DOWN, no menu open. Player identity seeded to the shared
-- "RED" spec. The walk out of Red's house is the same route start_menu uses.

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

local REDS_HOUSE_1F = 37 -- pret constants/map_constants.asm
local PALLET_TOWN = 0

scenario.run(function()
	navigate.boot_to_main_menu()
	navigate.new_game_to_bedroom()

	-- bedroom (2F) → 1F → Pallet Town (route notes in start_menu.lua)
	navigate.walk("RIGHT", 1)
	navigate.walk("UP", 5)
	navigate.walk_until_map("RIGHT", REDS_HOUSE_1F)
	navigate.walk("DOWN", 6)
	navigate.walk("LEFT", 4)
	navigate.walk_until_map("DOWN", PALLET_TOWN)

	local y, x = navigate.coords()
	if x ~= 8 then
		navigate.walk(x < 8 and "RIGHT" or "LEFT", math.abs(8 - x))
	end
	y = navigate.coords()
	if y ~= 8 then
		navigate.walk(y < 8 and "DOWN" or "UP", math.abs(8 - y))
	end
	input.tap("DOWN", 1, 12) -- 1-frame press: turn in place, no step
	y, x = navigate.coords()
	scenario.log(("overworld_pallet: standing at (%d,%d)"):format(y, x))
	assert(y == 8 and x == 8, "overworld_pallet: did not reach the (8,8) spawn tile")

	scenario.exec(function()
		seed.player(sym, text:encode(seed.PLAYER_NAME))
	end)
	scenario.wait(30) -- settle: walk animation over, idle frame

	scenario.exec(function()
		dump.write("overworld_pallet", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "pristine Pallet Town, player at the (8,8) boot spawn facing DOWN, no menu",
		})
	end)
end)
