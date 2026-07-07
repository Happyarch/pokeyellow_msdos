---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- party_menu — golden for the port's DEBUG_PARTYMENU harness: the POKéMON
-- party list of the 6-mon debug party (seed.lua spec). The screen is a full
-- redraw (ClearScreen + list), so the bedroom backdrop is irrelevant — same
-- shortcut status_p1 uses.

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
		seed.player(sym, text:encode(seed.PLAYER_NAME))
		seed.party(sym, text:encode(seed.PLAYER_NAME))
	end)

	navigate.open_start_menu()
	navigate.choose(text:encode("POKéMON"))
	navigate.wait_for_text(text:encode("PIKACHU")) -- list drawn (slot-3 nick)
	scenario.wait(30) -- settle on a stable frame

	scenario.exec(function()
		dump.write("party_menu", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "party menu: the 6-mon debug party (seed.lua spec), cursor on slot 0",
		})
	end)
end)
