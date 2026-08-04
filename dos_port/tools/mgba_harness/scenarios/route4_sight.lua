---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- route4_sight — golden for the port's DEBUG_MAPSCRIPT_SIGHT_R4 gate
-- (overworld-events Stage 5, batch 2). Shared body in lib/sight.lua.
--
-- ROUTE4_COOLTRAINER_F2 stands at (x=63, y=3) facing RIGHT with view range 3
-- (Route4TrainerHeader0, scripts/Route4.asm), and the player sits two tiles to its
-- right at (Y=3, X=65) — inside the range with a step left for TrainerWalkUpToPlayer.
--
-- WHY THIS MAP: Route 4 is the WIDEST in the sight set — 45 blocks, 90 tiles — and
-- the sight tile is at x=65. Every other gate sits at x=2..13, so this is the only
-- coverage of lib/sight.lua's view-pointer (x >> 1) term and of TrainerEngage's
-- screen-X projection at a large horizontal offset. It is the horizontal twin of
-- route10_sight's large-y case.
--
-- Route 4 also has exactly ONE trainer header, so nothing else on the map can mask a
-- failure by engaging in its place.
--
-- WHAT IS *NOT* THE REASON, because the first draft of this comment got it wrong:
-- Route 4 declares `def_trainers 2`, so its header0 pairs with OBJECT 2 rather than
-- object 1 (the header's first byte is that start bit, and home/trainers.asm
-- CheckForEngagingTrainers stores it straight into wSpriteIndex; EngageMapTrainer
-- then indexes wMapSpriteExtraData by `wSpriteIndex - 1`). That pairing is real and
-- load-bearing — but it is NOT unique to this map: scripts/Route3.asm declares
-- `def_trainers 2` as well, so route3_sight has covered it since Stage 3. Both
-- goldens stamp wTrainerFlagBit = 2, which is how the over-claim was caught.

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local gbtext = require("lib.gbtext")
local sight = require("lib.sight")

sight.run(symbols.load(), gbtext.load(), {
	name = "route4_sight",
	map = 0x0F,            -- ROUTE_4
	width = 45,            -- blocks; constants/map_constants.asm
	y = 3,
	x = 65,
	cur_script = "wRoute4CurScript",
	description = "Route 4, player at (3,65) two tiles right of ROUTE4_COOLTRAINER_F2 " ..
		"(faces RIGHT, view 3) — the def_trainers-start-bit-2 header/object pairing",
})
