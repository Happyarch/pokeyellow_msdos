---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- route18_sight — golden for the port's DEBUG_MAPSCRIPT_SIGHT_R18 gate
-- (overworld-events Stage 5a, batch 3). Shared body in lib/sight.lua.
--
-- ROUTE18_COOLTRAINER_M3 stands at (x=42, y=13) facing LEFT with view range 4
-- (Route18TrainerHeader2, scripts/Route18.asm), and the player sits two tiles to its
-- LEFT at (Y=13, X=40).
--
-- WHAT THIS ADDS: the SHORT end of the table walk. Route 18 has only THREE trainer
-- headers — the smallest table among the seventeen standard-shape maps — and the
-- engaging one is the last of them. Paired with route13_sight (header 9 of 10) this
-- brackets CheckFightingMapTrainers' scan at both extremes: the shortest table and
-- the longest, each terminating on its final entry. A terminator test that happened
-- to work at one length and not the other cannot survive both.
--
-- header 1 (ROUTE18_COOLTRAINER_M2, x=40, y=15, LEFT, view 3) is the near miss: it
-- stands on the player's x exactly, faces the same way, and is two tiles off on y.

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local gbtext = require("lib.gbtext")
local sight = require("lib.sight")

sight.run(symbols.load(), gbtext.load(), {
	name = "route18_sight",
	map = 0x1D,            -- ROUTE_18
	width = 25,            -- blocks; constants/map_constants.asm
	y = 13,
	x = 40,
	cur_script = "wRoute18CurScript",
	description = "Route 18, player at (13,40) two tiles left of ROUTE18_COOLTRAINER_M3 " ..
		"(faces LEFT, view 4) — header 2, the last of a three-header table",
})
