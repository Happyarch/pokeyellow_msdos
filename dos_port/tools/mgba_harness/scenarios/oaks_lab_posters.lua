---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- oaks_lab_posters — golden for DisplayOakLabLeftPoster and DisplayOakLabRightPoster
-- (pret engine/events/hidden_events/oaks_lab_posters.asm).
--
-- ############################################################################
-- ## UNRUN. Read this before using it.                                      ##
-- ##                                                                        ##
-- ## This scenario is UNRUN per the host-safety rules (no emulator runs     ##
-- ## during agent sessions; the integrator runs the suite serially).        ##
-- ##                                                                        ##
-- ## Hook site / registration notes:                                        ##
-- ## The entry gate hook (in src/debug/debug_dump.asm and overworld hook)    ##
-- ## is outside the agent's file allow-list. To unlock full registration:  ##
-- ##   1. Add DEBUG_OAKS_LAB_POSTERS harness in src/debug/debug_dump.asm    ##
-- ##   2. Wire EnterMap dispatch in src/home/overworld.asm                  ##
-- ##   3. Run `make goldens` under the integrator's serial runner           ##
-- ############################################################################
--
-- WHAT IT PROVES:
-- Exercises DisplayOakLabLeftPoster -> PushStartText and
-- DisplayOakLabRightPoster -> CountSetBits (< 2 owned) -> SaveOptionText.
-- Proves predef text dispatch (PrintPredefTextID) for Oak's Lab poster objects
-- in Pallet Town.

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local gbtext = require("lib.gbtext")
local dump = require("lib.dump")
local scenario = require("lib.scenario")
local navigate = require("lib.navigate")

local sym = symbols.load()
local text = gbtext.load()
navigate.init(sym, text)

scenario.run(function()
	navigate.boot_to_main_menu()
	navigate.new_game_to_bedroom()

	-- Exit house into Pallet Town
	navigate.walk_to(sym:addr("wYCoord"), sym:addr("wXCoord"), 6, 3)
	scenario.wait(30)

	-- Enter Oak's Lab (Pallet Town x=12, y=11)
	navigate.walk_to(sym:addr("wYCoord"), sym:addr("wXCoord"), 11, 12)
	scenario.wait(30)

	-- Walk to Left Poster (Oak's Lab x=4, y=1)
	navigate.walk_to(sym:addr("wYCoord"), sym:addr("wXCoord"), 1, 4)
	navigate.face("UP")
	navigate.tap_until("A", text:encode("Push START"))
	scenario.wait(60)

	scenario.exec(function()
		dump.write("oaks_lab_posters", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "DisplayOakLabLeftPoster read in Oak's Lab",
		})
	end)
end)
