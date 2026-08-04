---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- route13_sight — golden for the port's DEBUG_MAPSCRIPT_SIGHT_R13 gate
-- (overworld-events Stage 5a, batch 3). Shared body in lib/sight.lua.
--
-- ROUTE13_COOLTRAINER_M3 stands at (x=7, y=13) facing UP with view range 4
-- (Route13TrainerHeader9, scripts/Route13.asm), and the player sits two tiles ABOVE
-- it at (Y=11, X=7).
--
-- WHAT THIS ADDS: the TABLE WALK, not a facing. Route 13 has ten trainer headers,
-- and the one that engages is HEADER 9 — the last entry before the `db -1`
-- terminator. Every earlier sight golden engages a header at index 0..4, so the
-- scan has never had to read past offset 4 * TH_SIZE; here it must reach
-- 9 * 22 = 198 and still stop cleanly at the terminator. A stride error, a
-- short-count, or an off-by-one terminator test would leave the earlier seven
-- goldens green and fail only this one.
--
-- The other nine headers are genuine negatives at this tile, not padding —
-- header 8 (ROUTE13_BIKER, x=10, y=7, UP, view 2) is the near miss: it faces the
-- same direction, but its x is 10 against the player's 7, so the lined-up test
-- must reject it three entries before the real match.

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local gbtext = require("lib.gbtext")
local sight = require("lib.sight")

sight.run(symbols.load(), gbtext.load(), {
	name = "route13_sight",
	map = 0x18,            -- ROUTE_13
	width = 30,            -- blocks; constants/map_constants.asm
	y = 11,
	x = 7,
	cur_script = "wRoute13CurScript",
	description = "Route 13, player at (11,7) two tiles above ROUTE13_COOLTRAINER_M3 " ..
		"(faces UP, view 4) — header 9, the last entry of a ten-header table",
})
