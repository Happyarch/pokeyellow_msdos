---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- route12_sight — golden for the port's DEBUG_MAPSCRIPT_SIGHT_R12 gate
-- (overworld-realign Stage J, near-miss set). Shared body in lib/sight.lua.
--
-- ROUTE12_FISHER1 stands at (x=14, y=31) facing LEFT with view range 4
-- (Route12TrainerHeader0, scripts/Route12.asm), and the player sits two tiles
-- to its left at (Y=31, X=12) — inside the range with a step right for TrainerWalkUpToPlayer.
--
-- WHY THIS MAP: Route12 is one of the four NEAR-MISS maps (skeleton body
-- but 4 script pointers vs standard 3). Its extra pointer is SnorlaxPostBattleScript,
-- a Snorlax handler that shares the same header table. The sight tile is chosen
-- to cover the LEFT-facing branch on a medium-width map (10 blocks) at a mid
-- vertical position (y=31), distinct from FightingDojo's small-width RIGHT case
-- and Route16's large-width LEFT case.

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local gbtext = require("lib.gbtext")
local sight = require("lib.sight")

sight.run(symbols.load(), gbtext.load(), {
	name = "route12_sight",
	map = 0x17,            -- ROUTE_12
	width = 10,            -- blocks; assets/map_dims.inc
	y = 31,
	x = 12,
	cur_script = "wRoute12CurScript",
	description = "Route12, player at (31,12) two tiles left of ROUTE12_FISHER1 " ..
		"(faces LEFT, view 4) — near-miss 4-pointer map, mid-width LEFT case",
})
