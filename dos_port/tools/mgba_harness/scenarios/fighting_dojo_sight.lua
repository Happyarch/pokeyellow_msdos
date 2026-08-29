---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- fighting_dojo_sight — golden for the port's DEBUG_MAPSCRIPT_SIGHT_FIGHTING_DOJO gate
-- (overworld-realign Stage J, near-miss set). Shared body in lib/sight.lua.
--
-- FIGHTINGDOJO_BLACKBELT1 stands at (x=3, y=4) facing RIGHT with view range 4
-- (FightingDojoTrainerHeader0, scripts/FightingDojo.asm), and the player sits two
-- tiles to its right at (Y=4, X=5) — inside the range with a step left for TrainerWalkUpToPlayer.
--
-- WHY THIS MAP: FightingDojo is one of the four NEAR-MISS maps (skeleton body
-- but 4 script pointers vs standard 3). It is the only near-miss whose extra
-- pointer is KarateMasterPostBattleScript, a post-battle handler that reuses the
-- same header set. The sight tile is chosen to cover the RIGHT-facing branch at
-- the smallest map width (5 blocks) — the opposite extreme of Route4's wide
-- horizontal case (45 blocks).

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local gbtext = require("lib.gbtext")
local sight = require("lib.sight")

sight.run(symbols.load(), gbtext.load(), {
	name = "fighting_dojo_sight",
	map = 0xB1,            -- FIGHTING_DOJO
	width = 5,             -- blocks; assets/map_dims.inc
	y = 4,
	x = 5,
	cur_script = "wFightingDojoCurScript",
	description = "FightingDojo, player at (4,5) two tiles right of FIGHTINGDOJO_BLACKBELT1 " ..
		"(faces RIGHT, view 4) — near-miss 4-pointer map, smallest width",
})
