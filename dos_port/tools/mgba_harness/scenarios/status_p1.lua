---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- status_p1 — golden for the port's DEBUG_STATUS harness: status screen
-- page 1 of the debug party's slot-3 STARTER_PIKACHU (L5, SURF poked into
-- move slot 3), player RED / id 0.
--
-- Flow: new game (preset names) → bedroom → seed the spec party (lib/seed:
-- explicit DVs + pret formulas over ROM data) → START → POKéMON → PIKACHU →
-- STATS → dump page 1. The screen is a full redraw, so reaching it through
-- the real menus renders the same pixels the port's direct StatusScreen call
-- must produce.
--
-- Run via tools/mgba_harness/make_goldens.sh (env: PKMN_SYM, PKMN_CHARMAP,
-- GOLDEN_DIR).

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
	navigate.wait_for_text(text:encode("TYPE1/"))
	scenario.wait(30)

	scenario.exec(function()
		dump.write("status_p1", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "status screen page 1: slot-3 STARTER_PIKACHU L5 of the debug party (seed.lua spec)",
		})
	end)
end)
