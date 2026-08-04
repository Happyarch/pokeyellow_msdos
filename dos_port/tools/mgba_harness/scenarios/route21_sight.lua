---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- route21_sight — golden for the port's DEBUG_MAPSCRIPT_SIGHT_R21 gate
-- (overworld-events Stage 5a, batch 3). Shared body in lib/sight.lua.
--
-- ROUTE21_SWIMMER4 stands at (x=5, y=71) facing RIGHT with view range 4
-- (Route21TrainerHeader5, scripts/Route21.asm), and the player sits two tiles to its
-- RIGHT at (Y=71, X=7).
--
-- WHAT THIS ADDS, stated conservatively — this is the weakest gate of the batch and
-- it is better to say so than to dress it up. Two things, neither of them a new
-- branch:
--
--   1. BREADTH. Route 21 is one of the ten standard-shape maps the Stage 5a rollout
--      owes, and the project rule is "no scenario, no wire". The wire does not land
--      without a golden that actually runs this map's table.
--   2. MAGNITUDE. At y=71 on a 45-block-high map the view-pointer term
--      (width + 6) * (y >> 1) is 16 * 35 = 560 — second only to route17_sight's 960
--      in this batch, and above route10_sight's 432.
--
-- Headers 0 and 1 (ROUTE21_FISHER1/2) have view range 0 and are skipped before the
-- match, but route6_sight already covers that branch, so it is a repeat rather than
-- new coverage. Headers 2, 3 and 4 are ordinary lined-up rejections.
--
-- WHAT THIS GATE DOES *NOT* PROVE, since the map's shape invites the claim: Route 21
-- also has view-range-0 headers AFTER the match (7 and 8), which looks like a test
-- that the scan stops once someone engages. It is not one. Those headers have view
-- range 0, so a scan that wrongly ran past header 5 would still engage nobody and
-- overwrite nothing — the observable state is identical either way. Nothing in this
-- batch tests scan termination after a match.

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local gbtext = require("lib.gbtext")
local sight = require("lib.sight")

sight.run(symbols.load(), gbtext.load(), {
	name = "route21_sight",
	map = 0x20,            -- ROUTE_21
	width = 10,            -- blocks; constants/map_constants.asm
	y = 71,
	x = 7,
	cur_script = "wRoute21CurScript",
	description = "Route 21, player at (71,7) two tiles right of ROUTE21_SWIMMER4 " ..
		"(faces RIGHT, view 4) — view-range-0 headers both before and after the match",
})
