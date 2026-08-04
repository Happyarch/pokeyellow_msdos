---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- route14_sight — golden for the port's DEBUG_MAPSCRIPT_SIGHT_R14 gate
-- (overworld-events Stage 5a, batch 3). Shared body in lib/sight.lua.
--
-- ROUTE14_BIKER2 stands at (x=4, y=30) facing RIGHT with view range 4
-- (Route14TrainerHeader7, scripts/Route14.asm), and the player sits two tiles to its
-- RIGHT at (Y=30, X=6).
--
-- WHAT THIS ADDS: a RANGE rejection that is actually reached. In every other sight
-- golden — the seven older ones and the six alongside this one — every header the
-- scan evaluates before the match is thrown out by the LINED-UP test, on a
-- mismatched row or column. The distance comparison therefore only ever decides the
-- match itself, never a rejection, so a port that treated "lined up" as sufficient
-- and ignored range would still engage the right trainer everywhere.
--
-- Route 14 is the one tile in the batch where that is not true:
--
--   header 5  ROUTE14_COOLTRAINER_M6 (x=6, y=49) UP view 4 -> shares the player's
--             column EXACTLY and faces toward them. Lined up, in front, and
--             rejected on distance alone: 19 tiles against a view range of 4.
--   header 7  ROUTE14_BIKER2 (x=4, y=30) RIGHT view 4 -> the correct match, two
--             headers later.
--
-- So a missing or inverted range check does not merely fail to engage here — it
-- engages the WRONG trainer, two entries early, and the golden records that:
-- wEngagedTrainer would read OPP_BIRD_KEEPER roster 5 instead of OPP_BIKER
-- roster 15.
--
-- NOTE, because an earlier draft of this comment got it wrong: ROUTE14_BIKER3
-- (header 8, on the sight line but out of range) and ROUTE14_BIKER4 (header 9,
-- identical facing one tile off the line) are NOT tested here. The scan stops at
-- the first engaging header, so nothing past header 7 is ever evaluated. Only
-- headers 0..6 are real negatives at this tile.

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local gbtext = require("lib.gbtext")
local sight = require("lib.sight")

sight.run(symbols.load(), gbtext.load(), {
	name = "route14_sight",
	map = 0x19,            -- ROUTE_14
	width = 10,            -- blocks; constants/map_constants.asm
	y = 30,
	x = 6,
	cur_script = "wRoute14CurScript",
	description = "Route 14, player at (30,6) two tiles right of ROUTE14_BIKER2 " ..
		"(faces RIGHT, view 4) — three near-miss trainers must be rejected",
})
