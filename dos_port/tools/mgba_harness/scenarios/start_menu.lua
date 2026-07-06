---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- start_menu — golden for the port's DEBUG_STARTMENU harness: the START
-- menu over Pallet Town. The port harness opens the menu from its bare
-- SKIP_TITLE boot (no party, no pokédex event), so the menu is the minimal
-- ITEM / <player> / SAVE / OPTION / EXIT set; wPlayerName is seeded to the
-- shared "RED" spec (the port side must seed the same — plan, Session D).
--
-- The port boot spawns at Pallet Town (8,8) (overworld.asm:1174), so after
-- walking out of Red's house the player walks to (8,8) to match the
-- backdrop before opening the menu.

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

	-- bedroom (2F), spawn (3,6): the TV column blocks UP at x=3 and the
	-- console blocks x=6 on the spawn row — go RIGHT 1, UP the x=4 lane,
	-- then RIGHT into the (7,1) stairs warp (pret RedsHouse2F.asm). On 1F:
	-- DOWN the right wall, then LEFT onto the (3,7) door mat (warp tile).
	local y, x = navigate.coords()
	scenario.log(("start_menu: bedroom spawn (%d,%d)"):format(y, x))
	navigate.walk("RIGHT", 1)
	navigate.walk("UP", 5)
	navigate.walk_until_map("RIGHT", REDS_HOUSE_1F)
	y, x = navigate.coords()
	scenario.log(("start_menu: on 1F at (%d,%d)"):format(y, x))
	navigate.walk("DOWN", 6)
	navigate.walk("LEFT", 4) -- onto the (3,7) door mat…
	navigate.walk_until_map("DOWN", PALLET_TOWN) -- …which only warps on DOWN
	y, x = navigate.coords()
	scenario.log(("start_menu: in Pallet Town at (%d,%d)"):format(y, x))

	-- port boot spawn is (8,8); end facing DOWN like its default
	if x ~= 8 then
		navigate.walk(x < 8 and "RIGHT" or "LEFT", math.abs(8 - x))
	end
	y = navigate.coords()
	if y ~= 8 then
		navigate.walk(y < 8 and "DOWN" or "UP", math.abs(8 - y))
	end
	input.tap("DOWN", 1, 12) -- 1-frame press: turn in place, no step
	y, x = navigate.coords()
	scenario.log(("start_menu: standing at (%d,%d)"):format(y, x))
	assert(y == 8 and x == 8, "start_menu: did not reach the (8,8) spawn tile")

	scenario.exec(function()
		seed.player(sym, text:encode(seed.PLAYER_NAME))
	end)

	navigate.open_start_menu()

	scenario.exec(function()
		dump.write("start_menu", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "START menu over Pallet Town (8,8): no party/dex — ITEM/RED/SAVE/OPTION/EXIT",
		})
	end)
end)
