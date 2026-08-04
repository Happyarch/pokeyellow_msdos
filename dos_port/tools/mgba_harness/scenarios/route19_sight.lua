---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- route19_sight — golden for the port's DEBUG_MAPSCRIPT_SIGHT_R19 gate
-- (overworld-events Stage 5a, batch 3). Shared body in lib/sight.lua.
--
-- ROUTE19_SWIMMER1 stands at (x=13, y=25) facing LEFT with view range 3
-- (Route19TrainerHeader2, scripts/Route19.asm), and the player sits two tiles to its
-- LEFT at (Y=25, X=11).
--
-- WHAT THIS ADDS, stated honestly: less than the other six in this batch. Its
-- facing (LEFT), its header index (2) and its view range (3) are all covered
-- elsewhere. It is here primarily for BREADTH — Route 19 is one of the ten
-- standard-shape maps the rollout owes, and the project rule is "no scenario, no
-- wire", so the wire does not land without a golden that actually runs its table.
--
-- The one thing it does add is the RIGHT map edge: Route 19 is 10 blocks — 20 tiles
-- — wide, and the sight tile sits at x=11 with the trainer at x=13, near the far
-- edge of a narrow map. route6_sight covers the opposite case at x=2. Sprite screen
-- positions are what TrainerEngage compares, so a view pointer that is right in the
-- middle of a map and wrong near its edge is a real failure shape.

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local gbtext = require("lib.gbtext")
local sight = require("lib.sight")

sight.run(symbols.load(), gbtext.load(), {
	name = "route19_sight",
	map = 0x1E,            -- ROUTE_19
	width = 10,            -- blocks; constants/map_constants.asm
	y = 25,
	x = 11,
	cur_script = "wRoute19CurScript",
	description = "Route 19, player at (25,11) two tiles left of ROUTE19_SWIMMER1 " ..
		"(faces LEFT, view 3) — sight near the right edge of a narrow map",
})
