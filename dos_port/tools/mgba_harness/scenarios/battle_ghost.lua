---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- battle_ghost — golden for the port's DEBUG_BATTLE_GHOST gate (battle plan 4c).
--
-- THE ONE WITNESS 4c OWED. The ghost arm of InitWildBattle — GhostPic, the
-- "GHOST" nick, the MON_GHOST species substitution — had no scenario, so the
-- whole ghost identity path shipped unwitnessed.
--
-- IT NEEDS NO POKéMON TOWER, and that is what makes it cheap. Measured on both
-- sides (pret engine/battle/init_battle.asm:64-67, port init_battle.asm:263-268):
-- InitWildBattle tests `wCurOpponent == RESTLESS_SOUL` FIRST and takes .isGhost
-- on that ALONE. The tower map range and the absent Silph Scope gate only
-- IsGhostBattle (the RANDOM tower encounters) and PrintBeginningBattleText's
-- .isMarowak UNVEIL arm. RESTLESS_SOUL is MAROWAK ($91).
--
-- ENTRY PATH, all of it the game's own and RNG-FREE: seed wCurOpponent, take one
-- step. NewBattle (home/overworld.asm:324) tail-jumps to InitBattle past its
-- three flag guards; InitBattle sees wCurOpponent != 0 and takes InitOpponent;
-- InitBattleCommon's `sub OPP_ID_OFFSET` puts MAROWAK below the threshold, so it
-- falls into InitWildBattle -> .isGhost.
--
-- Route 1 column 7 is the ledge scenario's proven lane: clear of both Route 1
-- NPCs (YOUNGSTER1 wanders UP_DOWN in column 5, YOUNGSTER2 LEFT_RIGHT on row 13)
-- and clear of grass, so no wild-encounter roll can fire before the forced
-- opponent does.
--
-- Dump point: the intro parked at its own prompt, "Wild GHOST appeared!" on
-- screen — the same instant battle_intro photographs, and reached the same way
-- now that PrintBeginningBattleText is wired.

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local gbtext = require("lib.gbtext")
local input = require("lib.input")
local dump = require("lib.dump")
local scenario = require("lib.scenario")
local seed = require("lib.seed")
local navigate = require("lib.navigate")

local sym = symbols.load()
local text = gbtext.load()
navigate.init(sym, text)

local RESTLESS_SOUL = 0x91 -- MAROWAK, pret constants/pokemon_constants.asm:154
local REDS_HOUSE_1F = 37   -- pret constants/map_constants.asm
local PALLET_TOWN = 0
local ROUTE_1 = 12
local ROUTE_1_WIDTH = 10   -- blocks; constants/map_constants.asm
local BIT_WARP_FROM_CUR_SCRIPT = 3 -- constants/ram_constants.asm

scenario.run(function()
	navigate.boot_to_main_menu()
	navigate.new_game_to_bedroom()

	-- bedroom (2F) -> 1F -> Pallet Town, then a script warp onto Route 1. Both
	-- legs are ledge_hop's, verbatim and for its reasons: walk_to_route1 leaves
	-- the player at Route 1 (35,10), 25 rows south of the gate's spawn with a
	-- blocked lane between (measured — walking LEFT from there times out), so a
	-- warp is the only way onto column 7.
	navigate.walk("RIGHT", 1)
	navigate.walk("UP", 5)
	navigate.walk_until_map("RIGHT", REDS_HOUSE_1F)
	navigate.walk("DOWN", 6)
	navigate.walk("LEFT", 4)
	navigate.walk_until_map("DOWN", PALLET_TOWN)
	navigate.walk("DOWN", 1)
	scenario.wait(60) -- let the arrival's EnterMap finish before seeding coords

	scenario.exec(function()
		seed.debug_new_game(sym, text:encode(seed.PLAYER_NAME))
		-- Script warp onto Route 1 at (10,7) — the gate's spawn tile, one row
		-- BELOW the ledge at (9,7) so a DOWN step is an ordinary walk and not a
		-- ledge hop. The hand-computed view pointer is pret's
		-- macros/coords.asm event_displacement (see ledge_hop's header): it is
		-- self-checking, because a wrong value puts the wrong tile under the
		-- player and the step fails rather than producing a quietly wrong golden.
		local view = sym:addr("wOverworldMap") + 7 + ROUTE_1_WIDTH
			+ (ROUTE_1_WIDTH + 6) * (10 >> 1) + (7 >> 1)
		local ptr = sym:addr("wCurrentTileBlockMapViewPointer")
		emu:write8(ptr, view & 0xFF)
		emu:write8(ptr + 1, (view >> 8) & 0xFF)
		emu:write8(sym:addr("wYCoord"), 10)
		emu:write8(sym:addr("wXCoord"), 7)
		emu:write8(sym:addr("wDestinationWarpID"), 0xFF)
		emu:write8(sym:addr("hWarpDestinationMap"), ROUTE_1)
		local flags = sym:addr("wStatusFlags3")
		emu:write8(flags, emu:read8(flags) | (1 << BIT_WARP_FROM_CUR_SCRIPT))
	end)
	do
		local deadline = scenario.frame() + 900
		while navigate.read8("wCurMap") ~= ROUTE_1 do
			assert(scenario.frame() < deadline,
				"battle_ghost: the script warp to Route 1 never fired")
			scenario.wait(2)
		end
	end
	do
		local sy, sx = navigate.coords()
		assert(sy == 10 and sx == 7,
			("battle_ghost: the warp moved the player off (10,7) — at (%d,%d)"):format(sy, sx))
	end
	scenario.wait(30)

	-- THE forced opponent. Set after the warp so the arrival's EnterMap cannot
	-- clear it; this one byte is what makes the next step a ghost battle.
	scenario.exec(function()
		emu:write8(sym:addr("wCurOpponent"), RESTLESS_SOUL)
	end)

	-- One step is the whole trigger.
	input.tap("DOWN", 2, 8)

	local start = scenario.frame()
	while navigate.read8("wIsInBattle") == 0 do
		assert(scenario.frame() - start < 3600,
			"battle_ghost: the forced battle never started")
		scenario.wait(2)
	end
	scenario.log(("battle_ghost: wIsInBattle set at frame %d"):format(scenario.frame()))

	navigate.wait_for_text(text:encode("appeared"), 3600)
	scenario.wait(30) -- settle: intro text fully revealed, parked at the prompt

	-- The subject of the scenario, asserted before the photograph so a silent
	-- non-ghost battle cannot pass as one.
	local nick = scenario.read_range(sym:addr("wEnemyMonNick"), 5)
	assert(nick == text:encode("GHOST"),
		"battle_ghost: enemy nick is not GHOST — the ghost arm did not run")

	scenario.exec(function()
		dump.write("battle_ghost", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "forced RESTLESS_SOUL battle on Route 1 (10,7): the " ..
				"ghost identity — GhostPic, the GHOST nick — parked at the " ..
				"intro prompt",
		})
	end)
end)
