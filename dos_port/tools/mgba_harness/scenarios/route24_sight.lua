---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- route24_sight — golden for the port's DEBUG_MAPSCRIPT_SIGHT_R24 gate
-- (overworld-realign Stage J, near-miss set). Shared body in lib/sight.lua.
--
-- ROUTE24_COOLTRAINER_M2 stands at (x=5, y=20) facing UP with view range 4
-- (Route24TrainerHeader0, scripts/Route24.asm), and the player sits two tiles
-- above it at (Y=18, X=5) — inside the range with a step down for TrainerWalkUpToPlayer.
--
-- WHY THIS MAP: Route24 is the only NEAR-MISS map with 5 script pointers
-- (vs 4 for the other three), and its extra pointers are the Nugget Bridge
-- handlers. The sight tile is chosen to cover the UP-facing branch, the only
-- vertical UP case among the four near-miss goldens (FightingDojo RIGHT,
-- Route12 LEFT, Route16 LEFT) — completing the facing coverage for the set.

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local gbtext = require("lib.gbtext")
local sight = require("lib.sight")

sight.run(symbols.load(), gbtext.load(), {
	name = "route24_sight",
	map = 0x23,            -- ROUTE_24
	width = 10,            -- blocks; assets/map_dims.inc
	y = 18,
	x = 5,
	cur_script = "wRoute24CurScript",
	description = "Route24, player at (18,5) two tiles above ROUTE24_COOLTRAINER_M2 " ..
		"(faces UP, view 4) — near-miss 5-pointer map, UP-facing case",
})
