---@diagnostic disable: undefined-global -- mGBA Lua runtime globals
-- battle_ai_switch — battle plan 1e's witness: the trainer AI CHOOSING TO SWITCH.
--
-- SwitchEnemyMon has exactly one caller, AISwitchIfEnoughMons, and until
-- 2026-08-14 NOTHING in the suite reached it — the full tier passed
-- byte-identical because no scenario ever made the AI switch. That is why 1e sat
-- implemented-but-unwitnessed: the 2026-08-11 defect (the routine copied the
-- withdrawn mon's HP back to the roster and never sent the replacement out) could
-- not have been caught by any gate then in existence.
--
-- ENTRY is trainer_battle_route's, verbatim in shape: a real new game walked out
-- of Red's house, then a scripted warp onto Route 3 standing in
-- ROUTE3_YOUNGSTER1's line of sight, so the map script engages on its own. That
-- trainer is OPP_BUG_CATCHER party 4 = CATERPIE / WEEDLE / CATERPIE at L10 —
-- three mons, comfortably over AISwitchIfEnoughMons' `cp 2`.
--
-- TWO STAGING WRITES, and the asymmetry between them is the whole lesson.
--
--   1. wTrainerClass = COOLTRAINER_F, written EVERY frame. Cheap and safe:
--      nothing in the engine animates toward this byte. It is needed because
--      COOLTRAINER_F is the ONLY RNG-free route to AISwitchIfEnoughMons — pret
--      writes `cp 25 percent + 1` with the following `ret nc` COMMENTED OUT
--      ("The intended 25% chance to consider switching will not apply"), so that
--      class alone ignores the random byte TrainerAI's `call Random / jp hl`
--      hands it. Every other class opens `cp <threshold> / ret nc`, and the two
--      emulators share no RNG stream. wAICount needs no write at all:
--      EnemySendOutFirstMon leaves the $FF sentinel and TrainerAI reloads the
--      count from the class table.
--
--   2. wEnemyMonHP SEEDED ONCE, then never touched again. CooltrainerFAI wants
--      maxHP/10 <= HP < maxHP/5 — below 1/5 so its second AICheckIfHPBelowFraction
--      carries, but NOT below 1/10 or it reaches for a Hyper Potion instead. The
--      value is COMPUTED from the maxHP actually read, never hardcoded.
--
-- *** DO NOT MAKE (2) A PER-FRAME PIN. *** Measured twice on the port side, and
-- it fails SILENTLY — the battle simply never gets anywhere. Rewriting HP every
-- frame means anything animating toward a target HP cannot converge: from the
-- first in-battle frame it stalls the INTRO and MainInBattleLoop is never
-- entered at all; delayed until mid-battle it stalls the TURN LOOP instead, and
-- every AI call has already happened before the write engages. maxHP is left
-- REAL for the same reason — there is nothing to survive.
--
-- WHY ONE SEED IS ENOUGH: the debug party's lead is SNORLAX L80 whose move slot 0
-- is FLY, a TWO-TURN move. Tapping A takes the battle menu's default (FIGHT) and
-- then slot 0, so turn 1 is the charge, the enemy takes no damage, and the AI is
-- consulted with the seeded HP still inside the band. This scenario therefore
-- must NOT select STRENGTH by name the way trainer_battle_route does — that move
-- one-shots the roster and the AI is never asked.
--
-- LANDMARK: a COMPLETED switch — wEnemyMonPartyPos in 1..5 with a replacement
-- actually loaded (wEnemyMonSpecies non-zero). $FF is rejected: it is battle
-- INITIALIZATION, measured, not a switch. Both halves of the compared pair must
-- move — the party position AND the withdrawn mon's HP landing in the roster —
-- because a landmark checking only the roster write would have passed against
-- the original defect.

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
local COOLTRAINER_F = 0x20      -- constants/trainer_constants.asm
local PARTY_LENGTH = 6

-- Mirrors the port's DEBUG_BATTLE_AISWITCH gbregion list, joined by NAME. The
-- enemy ROSTER is the addition no standard region covers, and it carries the
-- half of the landmark that the 2026-08-11 defect got right, so it must be
-- compared alongside the half it got wrong.
local function regions()
	local out = dump.standard_regions(sym)
	local function one(name, label, size)
		out[#out + 1] = { name = name, addr = sym:addr(label), size = size }
	end
	local function raw(name, addr, size)
		out[#out + 1] = { name = name, addr = addr, size = size }
	end
	-- The port gate DEFINES DEBUG_TRAINER_ROUTE to reuse its entry, so it also
	-- emits that gate's whole gbregion list. The differ joins by NAME and fails
	-- loudly on a region present on only one side, so this list must mirror it.
	one("wBattleOutcome", "wBattleResult", 1)
	one("wIsInBattle", "wIsInBattle", 1)
	one("wCurOpponent", "wCurOpponent", 1)
	one("wCurMapScript", "wCurMapScript", 1)
	raw("wRoute3Script", 0xD5F7, 1)
	raw("wRoute3Event", ROUTE3_EVENT_BYTE, 1)
	one("wStatusFlags3", "wStatusFlags3", 1)
	one("wStatusFlags4", "wStatusFlags4", 1)
	one("wStatusFlags7", "wStatusFlags7", 1)
	one("wPlayerMapPos", "wCurMap", 5)
	one("wPlayerMoney", "wPlayerMoney", 3)
	one("wPartyMon1Exp", "wPartyMon1Exp", 3)
	-- The enemy ROSTER, which no standard region covers, and which carries the
	-- half of the landmark the 2026-08-11 defect got right.
	one("eRosterCount", "wEnemyPartyCount", 1)
	one("eRoster1HP", "wEnemyMon1HP", 2)
	return out
end

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
		emu:write8(ROUTE3_EVENT_BYTE, emu:read8(ROUTE3_EVENT_BYTE) & ~ROUTE3_EVENT_MASK)
		emu:write8(sym:addr("wRoute3CurScript"), 0)
		emu:write8(sym:addr("wCurMapScript"), 0)
	end)

	local deadline = scenario.frame() + 900
	while navigate.read8("wCurMap") ~= ROUTE_3 do
		assert(scenario.frame() < deadline, "battle_ai_switch: Route 3 warp never fired")
		scenario.wait(1)
	end
end

scenario.run(function()
	enter_route3()

	-- Let the map script engage on its own; only ANSWER the pre-battle text.
	local deadline = scenario.frame() + 7200
	while navigate.read8("wIsInBattle") ~= 2 or navigate.read8("wEnemyMonSpecies") == 0 do
		assert(scenario.frame() < deadline, "battle_ai_switch: trainer battle never started")
		input.tap("A", 2, 8)
	end
	scenario.log(string.format("battle_ai_switch: battle started f=%d", scenario.frame()))

	local cls = sym:addr("wTrainerClass")
	local hp = sym:addr("wEnemyMonHP")
	local maxhp = sym:addr("wEnemyMonMaxHP")
	local battleFrames, seeded, dumped = 0, false, false

	-- READS GO OUTSIDE scenario.exec, WRITES INSIDE. navigate.read8 and
	-- scenario.read_range go through the coroutine, so calling either from
	-- inside an exec thunk fails with "attempt to yield from outside a
	-- coroutine". This cost one golden generation here and one on
	-- battle_safari_result before it; the split is not stylistic.
	for _ = 1, 3000 do
		local inBattle = navigate.read8("wIsInBattle")
		if inBattle == 2 then
			battleFrames = battleFrames + 1
			scenario.exec(function()
				emu:write8(cls, COOLTRAINER_F)         -- staging write 1, per frame
			end)

			-- SEED ON A STATE BOTH SIDES REACH IDENTICALLY, NOT ON A FRAME COUNT.
			-- Measured: a frame delay does NOT align the emulators — this
			-- script's A-tap cadence advances the battle faster than the port's
			-- AUTOKEY_TRAINER_ROUTE, so at 300 in-battle frames the port still
			-- had its first roster mon out while hardware had already fainted it
			-- and sent the second, and the two sides seeded different mons.
			-- wBattleMonSpecies becoming non-zero is the player send-out
			-- completing: after all enemy loading, before the first turn, on both.
			if not seeded
				and navigate.read8("wEnemyMonSpecies") ~= 0
				and navigate.read8("wBattleMonSpecies") ~= 0 then
				local mb = scenario.read_range(maxhp, 2)
				local m = mb:byte(1) * 256 + mb:byte(2)     -- big-endian
				if m >= 5 then
					local want = (m // 5) - 1   -- largest HP strictly below maxHP/5
					assert(want >= m // 10,
						("battle_ai_switch: seed %d is below maxHP/10 (%d) — it would "
							.. "take AIUseHyperPotion instead of the switch"):format(want, m // 10))
					assert(want < m // 5,
						("battle_ai_switch: seed %d is not below maxHP/5 (%d)"):format(want, m // 5))
					scenario.exec(function()
						emu:write8(hp, (want >> 8) & 0xFF)  -- staging write 2, ONCE
						emu:write8(hp + 1, want & 0xFF)
					end)
					seeded = true
					scenario.log(string.format(
						"battle_ai_switch: seeded enemy HP %d of maxHP %d (band %d..%d) f=%d",
						want, m, m // 10, (m // 5) - 1, scenario.frame()))
				end
			end

			-- THE ROSTER HP IS WHAT SEPARATES A SWITCH FROM A FAINT, and leaving
			-- it out is how the first version of this scenario photographed the
			-- wrong event. On a FAINT the next mon also comes out with
			-- wEnemyMonPartyPos non-zero and the roster slot reading 0000; on a
			-- SWITCH the withdrawn mon's HP is written back NON-ZERO. Measured:
			-- the first golden caught WEEDLE at partyPos 1 with eRoster1HP 0000
			-- -- the faint path -- while the port had genuinely switched.
			local pos = navigate.read8("wEnemyMonPartyPos")
			local roster = scenario.read_range(sym:addr("wEnemyMon1HP"), 2)
			local rosterHP = roster:byte(1) * 256 + roster:byte(2)
			if seeded and pos ~= 0 and pos < PARTY_LENGTH
				and rosterHP ~= 0
				and navigate.read8("wEnemyMonSpecies") ~= 0 then
				scenario.exec(function()
					dump.write("battle_ai_switch", regions(), {
						frame = scenario.frame(),
						description = "the trainer AI chose to SWITCH: CooltrainerFAI saw "
							.. "the active mon inside its HP band and took "
							.. "AISwitchIfEnoughMons -> SwitchEnemyMon, withdrawing mon 0 "
							.. "and sending out the replacement. The withdrawn mon's HP is "
							.. "in the enemy roster and wEnemyMonPartyPos names the new "
							.. "slot -- the pair the 2026-08-11 defect could not produce",
					})
				end)
				dumped = true
				break
			end
		end
		input.tap("A", 2, 4)
	end

	assert(seeded, "battle_ai_switch: never seeded the enemy HP — the battle did not "
		.. "stay in wIsInBattle == 2 long enough to pass SEED_DELAY")
	assert(dumped, "battle_ai_switch: the AI never switched — wEnemyMonPartyPos stayed "
		.. "0 with the seeded HP inside CooltrainerFAI's band. Check that "
		.. "wTrainerClass held COOLTRAINER_F and that move slot 0 is still FLY "
		.. "(a lethal slot-0 move ends the turn before the AI is consulted)")
end)
