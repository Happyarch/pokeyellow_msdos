---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- ⚠ WORK IN PROGRESS — NOT a registered scenario, and deliberately NOT under
-- scenarios/ (goldens-verify globs that directory and demands a committed golden
-- for every file in it).
--
-- BLOCKER, measured 2026-07-24: the golden harness has no way to put the player on
-- Route 3.
--   * Walking is out: Route 3 is six maps past the start, behind the Viridian
--     parcel guard and the Viridian Forest maze, and navigate.walk cannot path-find.
--   * WarpFound2 (wStatusFlags3 BIT_WARP_FROM_CUR_SCRIPT) is out: its destination
--     byte hWarpDestinationMap is $FF8B, a UNION shared with hDownArrowBlinkCount1,
--     hSpriteInterlaceCounter and ~12 others (ram/hram.asm). A probe wrote $0E and
--     the warp consumed $0A ~12 frames later — the byte is clobbered before the
--     check reads it, and a scenario cannot write mid-frame.
--   * The fly warp (wStatusFlags6 BIT_FLY_WARP + wDestinationMap) is out twice
--     over: FlyWarpDataPtr's only non-town destinations are ROUTE_4 and ROUTE_10,
--     whose trainers sit ~50 tiles from the fly spot; and a probe setting
--     wDestinationMap = ROUTE_10 ($15) landed at PALLET_TOWN (5,6) with
--     wDestinationMap still reading $15 afterwards — i.e. the value the warp used
--     was not the one we wrote. Seeding a party first did not change it.
--
-- Everything below the blocker is written and believed correct — the frame loop,
-- the region list (mirrored by the %ifdef DEBUG_MAPSCRIPT_SIGHT gbregion rows in
-- src/debug/debug_dump.asm) and the dump call. What it needs is a working way onto
-- the map. Most promising next step: find (or add to the harness) a legal in-game
-- mechanism that sets wCurMap from WRAM only, or measure why the fly warp ignored
-- wDestinationMap — that one is a 20-line probe away from an answer.
-- route3_sight — golden for the port's DEBUG_MAPSCRIPT_SIGHT gate (map-script
-- fidelity plan, Stage 3): a Route 3 trainer seeing the player, dumped on the frame
-- the map's _Script engages.
--
-- ROUTE3_YOUNGSTER1 stands at (x=10, y=6) facing RIGHT with view range 2
-- (data/maps/objects/Route3.asm + Route3TrainerHeader0 in scripts/Route3.asm), so the
-- player is placed at (Y=6, X=12) — the second tile in its line of sight, far enough
-- that TrainerWalkUpToPlayer still has a step to take.
--
-- WHY A SCRIPT-WARP AND NOT A WALK: Route 3 is six maps and a Viridian Forest maze
-- past the starting point, gated on events (Oak's parcel, the Route 2 guard) — a
-- navigable route exists but no reliable one. Instead this uses the game's OWN warp
-- mechanism, the one a map script uses:
--
--   wDestinationWarpID = $FF   "not a warp arrival" — engine/overworld/tilesets.asm's
--                              LoadTilesetHeader tail skips LoadDestinationWarpPosition
--                              on that value, so the hand-set coords survive the load
--   hWarpDestinationMap = ROUTE_3
--   wStatusFlags3 BIT_WARP_FROM_CUR_SCRIPT  -> OverworldLoopLessDelay jumps to
--                              WarpFound2, which (outside map) copies
--                              hWarpDestinationMap into wCurMap and falls into EnterMap
--
-- Fly warp is not usable here: FlyWarpDataPtr only covers fly-able towns.
--
-- The one thing LoadDestinationWarpPosition would normally do for us is set
-- wCurrentTileBlockMapViewPointer alongside the coords, and nothing in the load path
-- derives it (that is exactly why the port has SeamReseatView). So this computes it
-- with pret's own formula — macros/coords.asm, event_displacement:
--
--   wOverworldMap + 7 + width + (width + 6) * (y >> 1) + (x >> 1)
--
-- and the computation is self-checking: a wrong view pointer places the map's sprites
-- somewhere else, TrainerEngage reads their screen positions, and no trainer engages —
-- which trips the assert below instead of producing a quietly wrong golden.
--
-- Player identity is seeded to the shared "RED" spec; no party is seeded, matching the
-- gate (DEBUG_MAPSCRIPT_SIGHT boots the map, it does not run PrepareNewGameDebug).

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local gbtext = require("lib.gbtext")
local dump = require("lib.dump")
local scenario = require("lib.scenario")
local seed = require("lib.seed")
local navigate = require("lib.navigate")

local sym = symbols.load()
local text = gbtext.load()
navigate.init(sym, text)

local REDS_HOUSE_1F = 37 -- pret constants/map_constants.asm
local PALLET_TOWN = 0
local ROUTE_3 = 0x0E
local ROUTE_3_WIDTH = 35 -- blocks; constants/map_constants.asm map_const ROUTE_3, 35, 9

local SIGHT_Y, SIGHT_X = 6, 12
local BIT_WARP_FROM_CUR_SCRIPT = 3 -- constants/ram_constants.asm

-- The extra WRAM this scenario compares on top of dump.standard_regions: the state
-- the sight flow mutates. MIRRORED BY the %ifdef DEBUG_MAPSCRIPT_SIGHT gbregion rows
-- in dos_port/src/debug/debug_dump.asm — the differ joins by NAME and cross-checks
-- each address, so the two lists must agree. Deliberately scenario-local: adding them
-- to dump.wram_regions would change every committed golden's .bin layout.
local function sight_regions()
	local cur_scripts = sym:addr("wGameProgressFlags")
	return {
		{ name = "wTrainerFlagBit", addr = sym:addr("wTrainerHeaderFlagBit"), size = 1 },
		{ name = "wEngagedTrainer", addr = sym:addr("wEngagedTrainerClass"), size = 2 },
		-- distance, facing, screenY, screenX
		{ name = "wTrainerEngage", addr = sym:addr("wTrainerEngageDistance"), size = 4 },
		{ name = "wEmotionBubble", addr = sym:addr("wEmotionBubbleSpriteIndex"), size = 2 },
		{ name = "wJoyIgnore", addr = sym:addr("wJoyIgnore"), size = 1 },
		{ name = "wSpriteIndex", addr = sym:addr("wSpriteIndex"), size = 1 },
		-- wCurMap .. wXCoord
		{ name = "wPlayerMapPos", addr = sym:addr("wCurMap"), size = 5 },
		{ name = "wStatusFlags5to7", addr = sym:addr("wStatusFlags5"), size = 4 },
		{ name = "wCurMapScript", addr = sym:addr("wCurMapScript"), size = 1 },
		-- the persistent per-map script bytes, incl. wRoute3CurScript
		{ name = "wGameProgressFlags", addr = cur_scripts, size = 0x30 },
	}
end

local function all_regions()
	local regions = dump.standard_regions(sym)
	for _, r in ipairs(sight_regions()) do
		regions[#regions + 1] = r
	end
	return regions
end

scenario.run(function()
	navigate.boot_to_main_menu()
	navigate.new_game_to_bedroom()

	-- bedroom (2F) → 1F → Pallet Town (route notes in start_menu.lua)
	navigate.walk("RIGHT", 1)
	navigate.walk("UP", 5)
	navigate.walk_until_map("RIGHT", REDS_HOUSE_1F)
	navigate.walk("DOWN", 6)
	navigate.walk("LEFT", 4)
	navigate.walk_until_map("DOWN", PALLET_TOWN)

	-- Arm the script warp to Route 3 with the destination position pre-set.
	scenario.exec(function()
		seed.player(sym, text:encode(seed.PLAYER_NAME))
		local view = sym:addr("wOverworldMap") + 7 + ROUTE_3_WIDTH
			+ (ROUTE_3_WIDTH + 6) * (SIGHT_Y >> 1) + (SIGHT_X >> 1)
		local ptr = sym:addr("wCurrentTileBlockMapViewPointer")
		emu:write8(ptr, view & 0xFF)
		emu:write8(ptr + 1, (view >> 8) & 0xFF)
		emu:write8(sym:addr("wYCoord"), SIGHT_Y)
		emu:write8(sym:addr("wXCoord"), SIGHT_X)
		emu:write8(sym:addr("wDestinationWarpID"), 0xFF)
		emu:write8(sym:addr("hWarpDestinationMap"), ROUTE_3)
		local flags = sym:addr("wStatusFlags3")
		emu:write8(flags, emu:read8(flags) | (1 << BIT_WARP_FROM_CUR_SCRIPT))
	end)

	-- The warp is taken on the next idle overworld iteration; EnterMap then reloads
	-- the map, sprites and all.
	local deadline = scenario.frame() + 900
	while navigate.read8("wCurMap") ~= ROUTE_3 do
		assert(scenario.frame() < deadline, "route3_sight: script warp to Route 3 never fired")
		scenario.wait(1)
	end
	local y, x = navigate.coords()
	scenario.log(("route3_sight: on Route 3 at (%d,%d)"):format(y, x))
	assert(y == SIGHT_Y and x == SIGHT_X,
		"route3_sight: the warp moved the player off the seeded sight tile")

	-- Route3_Script runs every overworld frame; wRoute3CurScript leaves 0 only when
	-- CheckFightingMapTrainers has engaged someone.
	local cur_script = sym:addr("wRoute3CurScript")
	deadline = scenario.frame() + 600
	while scenario.read_range(cur_script, 1):byte(1) == 0 do
		assert(scenario.frame() < deadline,
			"route3_sight: no trainer engaged — check the sight tile and the view pointer")
		scenario.wait(1)
	end
	scenario.log(("route3_sight: engaged at frame %d"):format(scenario.frame()))

	scenario.exec(function()
		dump.write("route3_sight", all_regions(), {
			frame = scenario.frame(),
			description = "Route 3, player at (6,12) inside ROUTE3_YOUNGSTER1's view " ..
				"range 2; dumped on the frame Route3_Script engaged the trainer",
		})
	end)
end)
