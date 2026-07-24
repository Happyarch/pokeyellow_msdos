---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- route6_sight — golden for the port's DEBUG_MAPSCRIPT_SIGHT_R6 gate (map-script
-- fidelity plan, Stage 3). Shared body in lib/sight.lua.
--
-- ROUTE6_YOUNGSTER1 stands at (x=0, y=15) facing RIGHT with view range 4
-- (Route6TrainerHeader2), and the player sits two tiles into that line at (Y=15, X=2).
--
-- WHY THIS TRAINER: it is header 2, and headers 0 and 1 (the two Cooltrainers at
-- (10,21) / (11,21)) have view range **0**. They are on screen from the sight tile, so
-- CheckForEngagingTrainers walks past both before reaching this one — which makes this
-- scenario the check that the header scan skips non-seeing trainers instead of
-- engaging the first one it finds.

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local gbtext = require("lib.gbtext")
local sight = require("lib.sight")

sight.run(symbols.load(), gbtext.load(), {
	name = "route6_sight",
	map = 0x11,            -- ROUTE_6
	width = 10,            -- blocks; constants/map_constants.asm
	y = 15,
	x = 2,
	cur_script = "wRoute6CurScript",
	description = "Route 6, player at (15,2) inside ROUTE6_YOUNGSTER1's view range 4; " ..
		"headers 0-1 have view 0 and must be skipped by the scan",
})
