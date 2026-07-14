---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- battle_intro — golden for the port's DEBUG_BATTLE_GOLDEN=1 DEBUG_BATTLE_INTRO=1
-- gate (fidelity plan Stage 2): the wild battle intro screen — enemy front pic,
-- player back pic, "Wild PIDGEY appeared!" in the dialog box, party pokéball row —
-- with the enemy built by the REAL LoadEnemyMonData and its RNG-derived bytes
-- (DVs/stats/HP) overwritten to the convergence spec (seed.enemy).
--
-- Dump point: intro text fully revealed, box waiting for A. This precedes any
-- RNG consumption for battle outcomes (no turn has run).

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local gbtext = require("lib.gbtext")
local dump = require("lib.dump")
local scenario = require("lib.scenario")
local navigate = require("lib.navigate")
local battle = require("lib.battle")

local sym = symbols.load()
local text = gbtext.load()
navigate.init(sym, text)

scenario.run(function()
	battle.enter_wild(sym, text)

	assert(navigate.tilemap():find(text:encode("appeared"), 1, true),
		"battle_intro: intro text vanished before the dump")

	scenario.exec(function()
		dump.write("battle_intro", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "Wild PIDGEY L13 intro (forced Route 1 grass encounter); " ..
				"real LoadEnemyMonData + spec DV/stat overwrite; box waiting for A",
		})
	end)
end)
