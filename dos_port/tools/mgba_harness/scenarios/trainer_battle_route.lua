---@diagnostic disable: undefined-global -- mGBA Lua runtime globals
-- trainer_battle_route -- the CONTINUOUS overworld -> battle -> return scenario
-- (battle plan Stage 1b).
--
-- On the golden side this is a straightforward real playthrough: warp to Route 3
-- standing in ROUTE3_YOUNGSTER1's line of sight, let the map script engage on its
-- own, answer the menus, and wait for the return to the overworld with the
-- trainer flagged beaten and the map script reset.
--
-- The point of the scenario is what it proves about the PORT: that its real
-- OverworldLoop drives the whole chain (RunMapScript -> TrainerMapScript ->
-- CheckFightingMapTrainers -> StartTrainerBattle seeds wCurOpponent -> the loop's
-- own battle-entry poll -> InitBattle -> ... -> .battleOccurred -> the next
-- RunMapScript dispatches EndTrainerBattle). Scenarios 44/45/46 call
-- StartTrainerBattle and InitBattle from a harness and never run the loop, so
-- none of them can prove any of that.
--
-- COMPARED SURFACE: choreography + the two zero-RNG reward bytes. Damage and HP
-- are deliberately absent -- pinning them would need RNG lockstep between the two
-- emulators through live menu timing, and per-turn damage math is already covered
-- by battle_faint and 45/46. See the matching gbregion list in the port's
-- src/debug/debug_dump.asm (DEBUG_TRAINER_ROUTE block); the differ joins by NAME,
-- so the two lists must stay in step.

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local gbtext = require("lib.gbtext")
local input = require("lib.input")
local dump = require("lib.dump")
local scenario = require("lib.scenario")
local navigate = require("lib.navigate")
local seed = require("lib.seed")

local sym = symbols.load()
local text = gbtext.load()
navigate.init(sym, text)

local REDS_HOUSE_1F, PALLET_TOWN, ROUTE_3 = 37, 0, 0x0E
local ROUTE_3_WIDTH, SIGHT_Y, SIGHT_X = 35, 6, 12
local BIT_WARP_FROM_CUR_SCRIPT = 3
local ROUTE3_EVENT_BYTE = 0xD7C2
local ROUTE3_EVENT_MASK = 1 << 2

-- Mirrors the port's DEBUG_TRAINER_ROUTE gbregion list, joined by NAME.
local function regions()
	local out = dump.standard_regions(sym)
	local function one(name, label, size)
		out[#out + 1] = { name = name, addr = sym:addr(label), size = size }
	end
	local function raw(name, addr, size)
		out[#out + 1] = { name = name, addr = addr, size = size }
	end
	one("wBattleOutcome", "wBattleResult", 1)
	one("wIsInBattle", "wIsInBattle", 1)
	one("wCurOpponent", "wCurOpponent", 1)
	one("wCurMapScript", "wCurMapScript", 1)
	one("wRoute3Script", "wRoute3CurScript", 1)
	raw("wRoute3Event", ROUTE3_EVENT_BYTE, 1)
	one("wStatusFlags3", "wStatusFlags3", 1)
	one("wStatusFlags4", "wStatusFlags4", 1)
	one("wStatusFlags7", "wStatusFlags7", 1)
	one("wPlayerMapPos", "wCurMap", 5)
	one("wPlayerMoney", "wPlayerMoney", 3)
	one("wPartyMon1Exp", "wPartyMon1Exp", 3)
	return out
end

-- Same entry as trainer_battle_win: a real new game walked out of Red's house,
-- then a scripted warp onto Route 3 standing in the youngster's sight line. The
-- warp is how both sides reach an identical starting state without depending on
-- a long cross-map walk staying deterministic.
local function enter_route3()
	navigate.boot_to_main_menu()
	navigate.new_game_to_bedroom()
	navigate.walk("RIGHT", 1)
	navigate.walk("UP", 5)
	navigate.walk_until_map("RIGHT", REDS_HOUSE_1F)
	navigate.walk("DOWN", 6)
	navigate.walk("LEFT", 4)
	navigate.walk_until_map("DOWN", PALLET_TOWN)
	navigate.walk("DOWN", 1)
	scenario.wait(60)

	scenario.exec(function()
		seed.debug_new_game(sym, text:encode(seed.PLAYER_NAME))
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
		-- Arm the trainer exactly as the port's RunTrainerRouteTestSeed does:
		-- beaten bit clear, map script at its DEFAULT handler.
		emu:write8(ROUTE3_EVENT_BYTE, emu:read8(ROUTE3_EVENT_BYTE) & ~ROUTE3_EVENT_MASK)
		emu:write8(sym:addr("wRoute3CurScript"), 0)
		emu:write8(sym:addr("wCurMapScript"), 0)
	end)

	local deadline = scenario.frame() + 900
	while navigate.read8("wCurMap") ~= ROUTE_3 do
		assert(scenario.frame() < deadline, "trainer_battle_route: Route 3 warp never fired")
		scenario.wait(1)
	end
end

scenario.run(function()
	enter_route3()

	-- The map script engages on its own from here; we only ANSWER. Tapping A
	-- drives the pre-battle text, the battle menu (FIGHT is the default cursor
	-- position), the move menu, and every message in between. Nothing here
	-- selects a target or forces a move -- the same division of labour as the
	-- port's AUTOKEY_TRAINER_ROUTE script.
	local function trace(tag)
		scenario.log(string.format(
			"trainer_battle_route[%s] f=%d map=%d inBattle=%d opp=%d enemySpc=%d "
			.. "curScript=%d r3Script=%d event=%02x",
			tag, scenario.frame(), navigate.read8("wCurMap"),
			navigate.read8("wIsInBattle"), navigate.read8("wCurOpponent"),
			navigate.read8("wEnemyMonSpecies"), navigate.read8("wCurMapScript"),
			navigate.read8("wRoute3CurScript"),
			scenario.read_range(ROUTE3_EVENT_BYTE, 1):byte(1)))
	end
	trace("on-route3")

	local deadline = scenario.frame() + 7200
	while navigate.read8("wIsInBattle") ~= 2 or navigate.read8("wEnemyMonSpecies") == 0 do
		if scenario.frame() % 600 < 12 then trace("await-battle") end
		assert(scenario.frame() < deadline, "trainer_battle_route: trainer battle never started")
		input.tap("A", 2, 8)
	end
	trace("battle-started")

	-- Fight it out, ONE TURN AT A TIME, with state-aware navigation rather than
	-- blind A-mashing.
	--
	-- Measured 2026-08-04, and the reason this loop is shaped the way it is: an
	-- earlier version just tapped A until the battle ended. It killed the first
	-- roster mon and then stalled on the second for 29000 frames until the runner's
	-- frame cap. Tapping A takes the battle menu's default (FIGHT) and then move
	-- slot 0, and slot 0 is not reliably lethal here — so the battle ran forever
	-- without either side fainting. Choosing the move BY NAME is what makes the
	-- run terminate, and it is the same mechanism trainer_battle_win uses.
	--
	-- STRENGTH is the lead's decisive move (the contract 45/46 already rely on:
	-- its minimum roll overkills this trainer's mons). Selecting it explicitly
	-- costs nothing in fidelity — the compared surface contains no damage byte —
	-- and buys a bounded, repeatable run.
	local FIGHT, STRENGTH = text:encode("FIGHT"), text:encode("STRENGTH")
	local done = false
	for turn = 1, 12 do
		local event = scenario.read_range(ROUTE3_EVENT_BYTE, 1):byte(1)
		if (event & ROUTE3_EVENT_MASK) ~= 0
			and navigate.read8("wRoute3CurScript") == 0
			and navigate.read8("wCurMapScript") == 0
			and navigate.read8("wIsInBattle") == 0
			and navigate.read8("wCurOpponent") == 0 then
			done = true
			break
		end
		trace("turn" .. turn)
		-- Reach the battle menu, answering whatever text stands between us and it
		-- (send-out, faint, EXP, level-up). dialog_until_text ADVANCES dialog and
		-- returns nothing; it ASSERTS on timeout. pcall is therefore load-bearing
		-- rather than defensive: on the last turn the battle ends while we are
		-- waiting, FIGHT never reappears, and the timeout assert would abort the
		-- whole scenario instead of letting the completion check below see a
		-- perfectly good finished battle.
		local ok = pcall(function()
			-- Get to the battle menu with B, not A.
			--
			-- MEASURED 2026-08-04, two failed runs: when a trainer sends out its
			-- next mon, Gen 1 asks "will <PLAYER> change POKéMON?" YES/NO. That
			-- box contains no FIGHT, so dialog_until_text just waits on it; and
			-- an A press answers YES and parks in the party menu, which is where
			-- the blind-A version sat for 29000 frames until the frame cap. B
			-- both advances ordinary text and answers NO, so it is the safe key
			-- for "get me back to the battle menu from wherever I am".
			local guard = scenario.frame() + 3600
			while not navigate.tilemap():find(FIGHT, 1, true) do
				assert(scenario.frame() < guard, "no battle menu")
				input.tap("B", 2, 8)
			end
			scenario.wait(30)
			navigate.choose(FIGHT)
			navigate.ensure_text("A", STRENGTH, 3600)
			scenario.wait(30)
			navigate.choose(STRENGTH)
		end)
		if not ok then
			trace("turn" .. turn .. "-nofight")
			break
		end
	end

	-- The battle can close on the turn after the last faint, so give the return
	-- choreography (EndOfBattle, the map re-entry, the RunMapScript that dispatches
	-- EndTrainerBattle) room to finish before declaring failure.
	if not done then
		for _ = 1, 3600 do
			local event = scenario.read_range(ROUTE3_EVENT_BYTE, 1):byte(1)
			if (event & ROUTE3_EVENT_MASK) ~= 0
				and navigate.read8("wRoute3CurScript") == 0
				and navigate.read8("wCurMapScript") == 0
				and navigate.read8("wIsInBattle") == 0
				and navigate.read8("wCurOpponent") == 0 then
				done = true
				break
			end
			input.tap("A", 2, 8)
		end
	end
	trace("post-loop")
	assert(done, "trainer_battle_route: battle never completed and returned to the overworld")

	-- Let the overworld settle before the dump so both sides compare a resting
	-- state rather than one mid-reload.
	scenario.wait(60)

	scenario.exec(function()
		assert(emu:read8(sym:addr("wBattleResult")) == 0,
			"trainer_battle_route: terminal result is not victory")
		dump.write("trainer_battle_route", regions(), {
			frame = scenario.frame(),
			description = "continuous Route 3 trainer battle: map-script sight engagement, " ..
				"battle entry through the overworld loop, live menus, and the " ..
				"EndTrainerBattle return with the beaten flag persisted",
		})
	end)
end)
