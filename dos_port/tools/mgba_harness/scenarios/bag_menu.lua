---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- bag_menu — golden for the port's DEBUG_BAGMENU harness: the ITEM list
-- (debug bag, seed.lua DEBUG_ITEMS = the port's DebugNewGameItemsList) as an
-- overlay over Pallet Town at the (8,8) spawn. Unlike the party menu this is
-- NOT a full-screen redraw — the overworld backdrop shows around the box, so
-- the walk out to (8,8) matters (same route as start_menu).

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
	input.tap("DOWN", 1, 12)
	y, x = navigate.coords()
	assert(y == 8 and x == 8, "bag_menu: did not reach the (8,8) spawn tile")

	scenario.exec(function()
		seed.player(sym, text:encode(seed.PLAYER_NAME))
		seed.items(sym)
	end)

	navigate.open_start_menu()
	navigate.choose(text:encode("ITEM"))
	navigate.wait_for_text(text:encode("POTION")) -- first bag entry drawn
	scenario.wait(30)

	scenario.exec(function()
		dump.write("bag_menu", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "ITEM bag list (DEBUG_ITEMS) over Pallet Town (8,8), cursor on POTION",
		})
	end)
end)
