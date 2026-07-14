---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- battle.lua — shared entry flow for the Stage 2 battle golden scenarios
-- (battle_intro / battle_menu / move_selection): boot → seeded new game →
-- bedroom → Pallet Town → Route 1 → forced grass encounter → wild PIDGEY L13
-- intro on screen → seed.enemy() applied (spec DVs + recomputed stats).
--
-- All three scenarios call battle.enter_wild() and then diverge only in how
-- far they advance (intro / battle menu / move list) before dumping.

local input = require("lib.input")
local scenario = require("lib.scenario")
local seed = require("lib.seed")
local navigate = require("lib.navigate")

local battle = {}

local REDS_HOUSE_1F = 37 -- pret constants/map_constants.asm
local PALLET_TOWN = 0
local ROUTE_1 = 12
local EVENT_FOLLOWED_OAK_INTO_LAB = 0 -- constants/event_constants.asm

-- Walk from the bedroom (where new_game_to_bedroom leaves us) out of the house
-- and up to the Route 1 boundary. Route notes: bedroom → 1F → Pallet Town is
-- sign_pallet's proven route; Pallet's north opening to Route 1 is the x=10
-- column (the gap in the tree border above the map's central path).
local function walk_to_route1(sym)
	navigate.walk("RIGHT", 1)
	navigate.walk("UP", 5)
	navigate.walk_until_map("RIGHT", REDS_HOUSE_1F)
	navigate.walk("DOWN", 6)
	navigate.walk("LEFT", 4)
	navigate.walk_until_map("DOWN", PALLET_TOWN)

	-- Yellow's PalletTownDefaultScript fires the scripted Oak catch-up (wild
	-- Pikachu cutscene) the moment wYCoord hits 0 — unless
	-- EVENT_FOLLOWED_OAK_INTO_LAB is set. Set it before approaching the exit.
	scenario.exec(function()
		seed.set_event(sym, EVENT_FOLLOWED_OAK_INTO_LAB)
	end)

	local _, x = navigate.coords()
	if x ~= 10 then
		navigate.walk(x < 10 and "RIGHT" or "LEFT", math.abs(10 - x))
	end
	navigate.walk_until_map("UP", ROUTE_1)
	local y2, x2 = navigate.coords()
	scenario.log(("battle: on Route 1 at (%d,%d)"):format(y2, x2))
end

-- Hold UP through the Route 1 grass until a battle triggers, sidestepping when
-- blocked (ledges/trees stall the walk: coords stop changing while UP is held).
-- wIsInBattle is set by InitBattleVariables during the battle transition, well
-- before the intro text — release input the moment it goes nonzero.
local function step_until_battle(max_frames)
	local start = scenario.frame()
	local sidesteps = { "LEFT", "RIGHT", "LEFT", "RIGHT" }
	local next_side = 1
	local ly, lx = navigate.coords()
	local still = 0
	input.hold("UP")
	while navigate.read8("wIsInBattle") == 0 do
		assert(scenario.frame() - start < max_frames,
			"battle: no encounter triggered walking Route 1 grass")
		scenario.wait(2)
		local y, x = navigate.coords()
		if y == ly and x == lx then
			still = still + 2
			if still > 90 then -- blocked: sidestep one tile and resume UP
				input.release()
				local dir = sidesteps[next_side]
				next_side = next_side % #sidesteps + 1
				scenario.log(("battle: blocked at (%d,%d), sidestepping %s"):format(y, x, dir))
				input.press_for(dir, 20)
				scenario.wait(20)
				still = 0
				input.hold("UP")
			end
		else
			ly, lx, still = y, x, 0
		end
	end
	input.release()
	scenario.log(("battle: encounter triggered at frame %d, coords (%d,%d)"):format(
		scenario.frame(), ly, lx))
end

-- Full shared flow. Leaves the game showing "Wild PIDGEY appeared!" with the
-- enemy's RNG-derived bytes overwritten to the convergence spec. `sym`/`text`
-- must already be loaded and navigate.init'd by the caller.
function battle.enter_wild(sym, text)
	navigate.boot_to_main_menu()
	navigate.new_game_to_bedroom()

	walk_to_route1(sym)

	-- Seed AFTER the walk: the full debug_new_game seed in the bedroom broke
	-- the very first walk step (hypothesis under test) — and nothing before the
	-- battle reads the party/bag anyway (send-out happens post-encounter).
	scenario.exec(function()
		seed.debug_new_game(sym, text:encode(seed.PLAYER_NAME))
		seed.force_encounter(sym)
	end)

	step_until_battle(7200)

	navigate.wait_for_text(text:encode("appeared"), 3600)
	scenario.wait(30) -- settle: intro text fully revealed, box parked

	scenario.exec(function()
		seed.enemy(sym)
	end)
end

return battle
