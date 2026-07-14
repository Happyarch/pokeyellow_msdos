---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- status_p2 — golden for the port's DEBUG_STATUS_PAGE2 harness: status
-- screen page 2 (EXP, moves/PP — including the SURF-with-PP-0 pre-poke
-- quirk) of the debug party's slot-3 STARTER_PIKACHU. Same flow as
-- status_p1 plus one A press.

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

scenario.run(function()
	navigate.boot_to_main_menu()
	navigate.new_game_to_bedroom()

	scenario.exec(function()
		-- The port gate calls PrepareNewGameDebug, which seeds party + bag + dex +
		-- badges + money; the WRAM regions are compared in every scenario, so the
		-- golden must seed all of it, not just this screen's data.
		seed.debug_new_game(sym, text:encode(seed.PLAYER_NAME))
	end)

	navigate.open_start_menu()
	navigate.choose(text:encode("POKéMON"))
	navigate.wait_for_text(text:encode("PIKACHU"))
	navigate.choose(text:encode("PIKACHU"), nil, 1) -- party cursor sits on the HP-bar row
	navigate.choose(text:encode("STATS"))
	navigate.wait_for_text(text:encode("TYPE1/")) -- page 1 up first
	navigate.tap_until("A", text:encode("EXP POINTS"))
	scenario.wait(30)

	scenario.exec(function()
		dump.write("status_p2", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "status screen page 2: slot-3 STARTER_PIKACHU L5 of the debug party (seed.lua spec)",
		})
	end)
end)
