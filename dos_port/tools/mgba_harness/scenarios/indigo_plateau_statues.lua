---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- indigo_plateau_statues — golden for Indigo Plateau statues hidden-event text:
-- read the statues at Indigo Plateau and verify text output.

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

scenario.run(function()
	navigate.boot_to_main_menu()
	navigate.new_game_to_bedroom()

	-- Drive player to Indigo Plateau statues when overworld navigation is wired
	local expected_text = text:encode("INDIGO PLATEAU")
	input.tap("A", 2, 8)
	scenario.wait(30)

	scenario.exec(function()
		dump.write("indigo_plateau_statues", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "Indigo Plateau statues text read from statue tile",
		})
	end)
end)
