---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- route9_sight — golden for the port's DEBUG_MAPSCRIPT_SIGHT_R9 gate
-- (overworld-events Stage 5, batch 2). Shared body in lib/sight.lua.
--
-- ROUTE9_COOLTRAINER_F1 stands at (x=13, y=10) facing LEFT with view range 3
-- (Route9TrainerHeader0, scripts/Route9.asm), and the player sits two tiles to its
-- LEFT at (Y=10, X=11).
--
-- WHY THIS TRAINER: it is the LEFT-facing horizontal case. route3_sight and
-- route6_sight are both RIGHT-facing, so CheckSpriteCanSeePlayer's negative-offset
-- arm on the X axis had no coverage at all — the same asymmetry route8_sight closes
-- on the Y axis. A sign error there passes both existing horizontal goldens.

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local gbtext = require("lib.gbtext")
local sight = require("lib.sight")

sight.run(symbols.load(), gbtext.load(), {
	name = "route9_sight",
	map = 0x14,            -- ROUTE_9
	width = 30,            -- blocks; constants/map_constants.asm
	y = 10,
	x = 11,
	cur_script = "wRoute9CurScript",
	description = "Route 9, player at (10,11) two tiles left of ROUTE9_COOLTRAINER_F1 " ..
		"(faces LEFT, view 3) — the leftward horizontal sight branch",
})
