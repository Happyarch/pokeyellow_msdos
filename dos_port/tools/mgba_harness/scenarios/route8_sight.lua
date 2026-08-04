---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- route8_sight — golden for the port's DEBUG_MAPSCRIPT_SIGHT_R8 gate
-- (overworld-events Stage 5, batch 2). Shared body in lib/sight.lua.
--
-- ROUTE8_GAMBLER1 stands at (x=13, y=9) facing UP with view range 4
-- (Route8TrainerHeader1, scripts/Route8.asm), and the player sits two tiles ABOVE it
-- at (Y=7, X=13).
--
-- WHY THIS TRAINER: it is the UPWARD vertical sight case. TrainerEngage branches on
-- which axis lines up, and CheckSpriteCanSeePlayer then tests the trainer's FACING
-- against the sign of the offset — so an UP-facing trainer and a DOWN-facing one take
-- different arms of the same branch. route11_sight covers DOWN; nothing covered UP.
--
-- Header 1 is also deliberate: Route 8 has nine trainer headers, so this proves the
-- scan advances by the 12-byte header stride correctly rather than only ever reading
-- header 0 (route3/route4) or header 2 (route6).

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local gbtext = require("lib.gbtext")
local sight = require("lib.sight")

sight.run(symbols.load(), gbtext.load(), {
	name = "route8_sight",
	map = 0x13,            -- ROUTE_8
	width = 30,            -- blocks; constants/map_constants.asm
	y = 7,
	x = 13,
	cur_script = "wRoute8CurScript",
	description = "Route 8, player at (7,13) two tiles above ROUTE8_GAMBLER1 " ..
		"(faces UP, view 4, header 1) — the upward vertical sight branch",
})
