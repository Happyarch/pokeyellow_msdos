---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- viridian_forest_sight — golden for the port's DEBUG_MAPSCRIPT_SIGHT_VF gate.
-- The shared body — script warp, view-pointer computation, the settle requirement,
-- the compared regions — lives in lib/sight.lua.
--
-- THE FIRST NON-ROUTE MAP ON THIS GATE, and the reason it exists: VIRIDIAN_FOREST
-- was "table-only" — its MapScriptParams row and TrainerHeaders were generated, but
-- MapScriptPointers still dispatched DefaultMapScript, so CheckFightingMapTrainers
-- (script state 0) never ran. Its five trainers could be TALKED to, printing their
-- battle text, and then never fought, with no "!" ever appearing. Found by a
-- maintainer hand-testing battles, 2026-08-15.
--
-- gen_map_script_tables.py excluded the three interiors "because they share the
-- single indoor .blk slot". That reason did not hold for this map and was tested
-- rather than trusted: wired, built and run headless, the port reaches
-- wCurMapScript=1 with wEngagedTrainer=$CA/set 1. This golden is what makes that
-- a fidelity claim instead of an observation.
--
-- ViridianForestTrainerHeader0 is YOUNGSTER2 at (x=30, y=33) facing LEFT with view
-- range 4 (scripts/ViridianForest.asm), so the player sits at (Y=33, X=28) — the
-- second tile in its line of sight, far enough that TrainerWalkUpToPlayer still has
-- a step to take. Same rule as route3_sight, mirrored: this is the LEFT-facing
-- horizontal case on a TALL indoor map (17 blocks wide, 24 high).

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local gbtext = require("lib.gbtext")
local sight = require("lib.sight")

sight.run(symbols.load(), gbtext.load(), {
	name = "viridian_forest_sight",
	map = 0x33,            -- VIRIDIAN_FOREST
	width = 17,            -- blocks; constants/map_constants.asm:89
	y = 33,
	x = 28,
	cur_script = "wViridianForestCurScript",
	description = "Viridian Forest, player at (33,28) inside ViridianForestTrainerHeader0's " ..
		"view range 4; dumped on the frame ViridianForest_Script engaged the trainer",
})
