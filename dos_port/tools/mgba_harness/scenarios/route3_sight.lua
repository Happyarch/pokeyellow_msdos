---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- route3_sight — golden for the port's DEBUG_MAPSCRIPT_SIGHT_R3 gate (map-script
-- fidelity plan, Stage 3). The shared body — script warp, view-pointer computation,
-- the settle requirement, the compared regions — lives in lib/sight.lua.
--
-- ROUTE3_YOUNGSTER1 stands at (x=10, y=6) facing RIGHT with view range 2
-- (data/maps/objects/Route3.asm + Route3TrainerHeader0 in scripts/Route3.asm), so the
-- player sits at (Y=6, X=12): the second tile in its line of sight, far enough that
-- TrainerWalkUpToPlayer still has a step to take. This is the HORIZONTAL sight case
-- and the FIRST header in the map's scan.

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local gbtext = require("lib.gbtext")
local sight = require("lib.sight")

sight.run(symbols.load(), gbtext.load(), {
	name = "route3_sight",
	map = 0x0E,            -- ROUTE_3
	width = 35,            -- blocks; constants/map_constants.asm
	y = 6,
	x = 12,
	cur_script = "wRoute3CurScript",
	description = "Route 3, player at (6,12) inside ROUTE3_YOUNGSTER1's view range 2; " ..
		"dumped on the frame Route3_Script engaged the trainer",
})
