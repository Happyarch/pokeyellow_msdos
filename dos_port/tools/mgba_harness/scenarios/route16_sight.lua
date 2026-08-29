---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- route16_sight — golden for the port's DEBUG_MAPSCRIPT_SIGHT_R16 gate
-- (overworld-realign Stage J, near-miss set). Shared body in lib/sight.lua.
--
-- ROUTE16_BIKER1 stands at (x=17, y=12) facing LEFT with view range 3
-- (Route16TrainerHeader0, scripts/Route16.asm), and the player sits two tiles
-- to its left at (Y=12, X=15) — inside the range with a step right for TrainerWalkUpToPlayer.
--
-- WHY THIS MAP: Route16 is one of the four NEAR-MISS maps (skeleton body
-- but 4 script pointers vs standard 3). Its extra pointer is a second Snorlax
-- handler. The sight tile is chosen to cover the LEFT-facing branch on the
-- WIDEST map in the set (20 blocks, 40 tiles) — the horizontal opposite of
-- FightingDojo's 5-block width, exercising the (width+6)*(y>>1) term at a
-- different magnitude.

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local gbtext = require("lib.gbtext")
local sight = require("lib.sight")

sight.run(symbols.load(), gbtext.load(), {
	name = "route16_sight",
	map = 0x1B,            -- ROUTE_16
	width = 20,            -- blocks; assets/map_dims.inc
	y = 12,
	x = 15,
	cur_script = "wRoute16CurScript",
	description = "Route16, player at (12,15) two tiles left of ROUTE16_BIKER1 " ..
		"(faces LEFT, view 3) — near-miss 4-pointer map, widest width",
})
