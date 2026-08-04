---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- route10_sight — golden for the port's DEBUG_MAPSCRIPT_SIGHT_R10 gate
-- (overworld-events Stage 5, batch 2). Shared body in lib/sight.lua.
--
-- ROUTE10_HIKER1 stands at (x=3, y=57) facing UP with view range 3
-- (Route10TrainerHeader1, scripts/Route10.asm), and the player sits two tiles ABOVE
-- it at (Y=55, X=3).
--
-- WHY THIS MAP, stated honestly: the FACING adds nothing route8_sight does not
-- already cover (both are UP). What it adds is GEOMETRY. Route 10 is 10 blocks wide
-- by 36 high — the first TALL map in the sight set, where every other wired map is
-- short and wide — and the sight tile is at y=55, where lib/sight.lua's view-pointer
-- term
--
--     (width + 6) * (y >> 1)
--
-- evaluates to 16 * 27 = 432, against 3..48 on every existing gate (their y is
-- 3..16). That term is the one piece of hand-re-derived pret arithmetic in the
-- harness (macros/coords.asm event_displacement), and it is exactly the kind of
-- formula that is right for small operands and wrong for large ones. The check is
-- self-enforcing: a wrong view pointer puts the map's sprites somewhere else,
-- TrainerEngage reads their screen positions, nobody engages, and lib/sight.lua's
-- assert fires instead of a quietly wrong golden being written.

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local gbtext = require("lib.gbtext")
local sight = require("lib.sight")

sight.run(symbols.load(), gbtext.load(), {
	name = "route10_sight",
	map = 0x15,            -- ROUTE_10
	width = 10,            -- blocks; constants/map_constants.asm
	y = 55,
	x = 3,
	cur_script = "wRoute10CurScript",
	description = "Route 10, player at (55,3) two tiles above ROUTE10_HIKER1 " ..
		"(faces UP, view 3) — sight on a tall map at large y",
})
