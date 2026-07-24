---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- route11_sight — golden for the port's DEBUG_MAPSCRIPT_SIGHT_R11 gate (map-script
-- fidelity plan, Stage 3). Shared body in lib/sight.lua.
--
-- ROUTE11_GAMBLER1 stands at (x=10, y=14) facing DOWN with view range 3
-- (Route11TrainerHeader0), and the player sits two tiles below it at (Y=16, X=10).
--
-- WHY THIS TRAINER: it is the VERTICAL sight case. TrainerEngage branches on which
-- axis lines up — screenY == $3C takes .linedUpY, screenX == $40 takes .linedUpX — and
-- the Route 3 / Route 6 scenarios only ever exercise the first. This one is the only
-- coverage of the second, and of a DOWN-facing trainer's CheckSpriteCanSeePlayer.

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local gbtext = require("lib.gbtext")
local sight = require("lib.sight")

sight.run(symbols.load(), gbtext.load(), {
	name = "route11_sight",
	map = 0x16,            -- ROUTE_11
	width = 30,            -- blocks; constants/map_constants.asm
	y = 16,
	x = 10,
	cur_script = "wRoute11CurScript",
	description = "Route 11, player at (16,10) two tiles below ROUTE11_GAMBLER1 " ..
		"(faces DOWN, view 3) — the vertical sight branch",
})
