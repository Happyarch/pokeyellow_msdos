---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- route15_sight — golden for the port's DEBUG_MAPSCRIPT_SIGHT_R15 gate
-- (overworld-events Stage 5a, batch 3). Shared body in lib/sight.lua.
--
-- ROUTE15_COOLTRAINER_F2 stands at (x=53, y=10) facing LEFT with view range 3
-- (Route15TrainerHeader1, scripts/Route15.asm), and the player sits THREE tiles to
-- its LEFT at (Y=10, X=50).
--
-- WHAT THIS ADDS: the RANGE BOUNDARY. Every other sight golden parks the player two
-- tiles from the trainer regardless of that trainer's view range, so the distance
-- comparison has only ever been exercised comfortably inside the range — a port that
-- computed the boundary wrongly would pass all seven older gates. Here the player is
-- at EXACTLY the view range.
--
-- pret's CheckSpriteCanSeePlayer (engine/overworld/trainer_sight.asm) is:
--
--     ld a, [wTrainerEngageDistance]   ; range, in PIXELS (view range << 4)
--     cp b                             ; b = distance to player, also pixels
--     jr nc, .checkIfLinedUp           ; range >= distance -> still visible
--
-- so the comparison is INCLUSIVE and distance == range must engage. 3 tiles is
-- 0x30 pixels against a stored range of 0x30. A port that emitted a strict
-- "greater than" here — the natural x86 slip, ja for jae — fails this gate and only
-- this gate. The golden stamps wTrainerEngageDistance, so the recorded value is
-- checked against 3 << 4 rather than merely "somebody engaged".
--
-- Only header 0 (ROUTE15_COOLTRAINER_F1, x=41, y=11, DOWN, view 2) is evaluated
-- before the match, and it is rejected on its column. Everything else on this map,
-- including the same-row ROUTE15_BEAUTY2, sits past header 1 and is never reached —
-- the scan stops at the first engaging header. This gate is the boundary test and
-- nothing more; route14_sight is the one that exercises a range REJECTION.

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local gbtext = require("lib.gbtext")
local sight = require("lib.sight")

sight.run(symbols.load(), gbtext.load(), {
	name = "route15_sight",
	map = 0x1A,            -- ROUTE_15
	width = 30,            -- blocks; constants/map_constants.asm
	y = 10,
	x = 50,
	cur_script = "wRoute15CurScript",
	description = "Route 15, player at (10,50) exactly three tiles left of " ..
		"ROUTE15_COOLTRAINER_F2 (faces LEFT, view 3) — engagement at the range boundary",
})
