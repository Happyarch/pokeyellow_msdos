---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- battle_exp_all — golden for the port's DEBUG_BATTLE_EXPALL=1 gate (differ
-- class "datastruct": WRAM game data only). battle_faint's matchup — SNORLAX
-- L80 KOs the convergence-spec wild PIDGEY L13 with STRENGTH — with EXP_ALL in
-- the bag, so FaintEnemyPokemon takes its whole-party branch and every mon in
-- the party is credited instead of only the one that fought.
--
-- WHY THIS SCENARIO EXISTS. The seeded bag has no EXP_ALL, so
-- FaintEnemyPokemon's `ld b, EXP_ALL / call IsItemInBag` had never once come
-- back true in this project. That branch is not a small variation on
-- battle_faint: it halves wEnemyMonBaseStats and calls GainExperience a SECOND
-- time over the whole party, which is a different program.
--
-- WHAT IT CAUGHT ON ITS FIRST EXECUTION (fixed in 17d670c2f, before this
-- scenario could be registered): DivideExpDataByNumMonsGainingExp — reachable
-- ONLY from here, because a single mon gaining EXP returns at its `cp 2` —
-- kept its byte counter in CL, which `Divide` destroys (_Divide loads the
-- divisor into ECX and `div ecx` leaves it there). The loop never terminated,
-- ESI walked out of the 7-byte base-stat block writing quotient bytes across
-- WRAM (wIsInBattle first, so the wild battle then took the TRAINER branch),
-- and the run page-faulted. So this scenario's job is not decoration: the
-- branch it reaches was broken the entire time it was unreachable.
--
-- THE BAG PIN, and it is the one thing to get right. wNumBagItems is the COUNT
-- and wBagItems is the LIST, so item i's id is at wBagItems + i*2 — NO +1. The
-- port gate makes the identical write to the identical slot (the last seeded
-- one, index 15, PP_UP), so wBagItems compares clean and no count/terminator
-- juggling is needed. An earlier port-side version of this pin added the +1,
-- landed on item 15's QUANTITY, and the branch was simply never entered while
-- everything still looked healthy — always read back the byte a pin changes.
--
-- DETERMINISTIC, BUT IT NEEDS ONE MORE PIN THAN battle_faint. The two sides do
-- not share an RNG stream (lib/seed.lua), so nothing compared may move with a
-- roll: STRENGTH's minimum roll from L80 overkills PIDGEY's 36 HP, and each
-- mon's EXP is a function of the enemy's base EXP, its level and the number of
-- mons gaining EXP. What battle_faint's argument gets WRONG — measured here —
-- is "SNORLAX outspeeds it so the enemy never acts": a YELLOW L13 PIDGEY knows
-- QUICK ATTACK, and +1 priority beats speed. So the enemy is pinned ASLEEP on
-- both sides. The damage VALUE differs between the sides and is not compared.
--
-- Dump point: the settled post-battle state (wIsInBattle back to 0), reached
-- only AFTER the LAST party slot has been credited — that landmark is what says
-- the whole-party pass finished rather than the fought-mon pass. battle_faint's
-- in-battle instant is NOT available here; see the comment at the dump loop.

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local gbtext = require("lib.gbtext")
local input = require("lib.input")
local dump = require("lib.dump")
local scenario = require("lib.scenario")
local navigate = require("lib.navigate")
local battle = require("lib.battle")

local sym = symbols.load()
local text = gbtext.load()
navigate.init(sym, text)

local EXP_ALL = 0x4B            -- constants/item_constants.asm
local BAG_SLOT = 15             -- the last seeded slot (PP_UP), overwritten
local PARTYMON_STRUCT_LENGTH = 44
local LAST_SLOT = 5             -- the seeded party is six mons
local SLEEP_TURNS = 7           -- enemy SLP counter; outlasts this one turn

local function read_be(label, size)
	local raw = scenario.read_range(sym:addr(label), size)
	local v = 0
	for i = 1, size do
		v = v * 256 + raw:byte(i)
	end
	return v
end

-- Slot N's 3-byte EXP, read through scenario.read_range for the same reason
-- battle_faint documents: emu:* is unreachable from the scenario coroutine, and
-- one read_range == one frame, which is what makes these loops per-frame.
local function slot_exp(slot)
	local addr = sym:addr("wPartyMon1Exp") + slot * PARTYMON_STRUCT_LENGTH
	local raw = scenario.read_range(addr, 3)
	return raw:byte(1) * 65536 + raw:byte(2) * 256 + raw:byte(3)
end

scenario.run(function()
	battle.enter_wild(sym, text)

	-- A dismisses "appeared!"; send-out runs unattended; menu box parks.
	input.tap("A", 2, 8)
	navigate.dialog_until_text(text:encode("FIGHT"), 3600)
	scenario.wait(30) -- settle: menu parked in its input loop

	-- THE PIN: give the player EXP_ALL by overwriting the last seeded bag
	-- slot's id, exactly as the port gate does.
	scenario.exec(function()
		emu:write8(sym:addr("wBagItems") + BAG_SLOT * 2, EXP_ALL)
		-- AND THE ENEMY MUST NOT ACT. battle_faint gets away with no pin here by
		-- arguing that SNORLAX outspeeds the L13 PIDGEY — true, and not enough:
		-- in YELLOW a L13 PIDGEY knows QUICK ATTACK, whose +1 priority beats any
		-- speed, and whether the AI picks it is a roll the two emulators do not
		-- share. MEASURED while building this scenario, before the pin: the
		-- golden's SNORLAX finished on 359 HP in one run and 360 in the next
		-- while the port (whose gate calls ExecutePlayerMove and gives the enemy
		-- no turn) held a full 362, so wBattleMon/wLoadedMon/wPartyData HP all
		-- diverged and could never converge. A seeded sleep counter removes the
		-- enemy's turn deterministically; the port gate makes the identical
		-- write. Same pin, same reasoning as battle_wrap's.
		emu:write8(sym:addr("wEnemyMonStatus"), SLEEP_TURNS)
	end)
	assert(scenario.read_range(sym:addr("wBagItems") + BAG_SLOT * 2, 1):byte(1) == EXP_ALL,
		"battle_exp_all: the bag pin did not take — item " .. BAG_SLOT ..
		" is not EXP_ALL, so FaintEnemyPokemon will not take the whole-party " ..
		"branch and this scenario would pass while testing nothing")

	-- FIGHT -> the move list, then STRENGTH (SNORLAX's slot 4).
	navigate.choose(text:encode("FIGHT"))
	navigate.ensure_text("A", text:encode("STRENGTH"), 3600)
	scenario.wait(30) -- settle: a tap into a just-drawn list is swallowed
	navigate.choose(text:encode("STRENGTH"))

	-- Walk the turn to the KO. Watch the STATE, not any one message: the beats
	-- race against the taps (measured in ball_catch).
	local down = false
	for _ = 1, 3600 do
		if read_be("wEnemyMonHP", 2) == 0 then
			down = true
			break
		end
		input.tap("A", 2, 10)
	end
	assert(down, "battle_exp_all: enemy never reached 0 HP — a 1/256 accuracy " ..
		"miss, or the turn did not resolve")

	-- THE LANDMARK THAT SEPARATES THIS SCENARIO FROM battle_faint: the LAST
	-- party slot gaining EXP. Slot 0 is credited by the fought-mon pass, which
	-- happens with or without EXP_ALL; slot 5 is credited only by the
	-- whole-party pass, and it is credited last, so its EXP moving means the
	-- second GainExperience has walked the entire party.
	assert(navigate.read8("wBattleResult") == 0,
		"battle_exp_all: wBattleResult is not 0 (win) after the KO")

	local last_before = slot_exp(LAST_SLOT)
	local whole_party_paid = false
	for _ = 1, 3600 do
		if slot_exp(LAST_SLOT) ~= last_before then
			whole_party_paid = true
			break
		end
		input.tap("A", 2, 10)
	end
	assert(whole_party_paid, "battle_exp_all: party slot " .. LAST_SLOT ..
		" never gained EXP — FaintEnemyPokemon did not take the EXP_ALL " ..
		"whole-party branch")
	scenario.log("exp_all: the whole-party pass reached the last slot")

	-- THE DUMP INSTANT IS THE SETTLED POST-BATTLE STATE, and that choice was
	-- forced by measurement rather than preferred. The obvious instant —
	-- battle_faint's, i.e. wLoadedMonLevel == 80 with wIsInBattle still 1 right
	-- after HandleEnemyMonFainted — DOES NOT EXIST ON THE ROM once the
	-- whole-party pass has run: DrawPlayerHUDAndHPBar's staging and the battle
	-- teardown fall inside one frame, so a loop polling for both bytes in a
	-- SINGLE read_range never fired and hit its 3600-frame cap. (An earlier
	-- version appeared to work only because it read the two bytes in two
	-- read_range calls, i.e. on two different frames — the condition was never
	-- true simultaneously, and the golden came out with wIsInBattle $00 while
	-- the assert claimed $01. Two reads in a poll are two frames; that is a
	-- trap, not a detail.) So the port gate carries on into EndOfBattle, exactly
	-- as DEBUG_BATTLE_PAYDAY does, and this side waits for the same settled
	-- state: wIsInBattle back to 0.
	--
	-- The test and the dump share ONE yielded thunk. Every scenario.* helper is
	-- a coroutine yield == one frame, so "poll, break, then scenario.exec(dump)"
	-- photographs the state at least one frame later than the frame that
	-- satisfied the condition — invisible in a wide window, fatal in a narrow
	-- one, and this window was narrow twice over.
	local dumped = false
	for i = 1, 3600 do
		scenario.exec(function()
			if dumped then return end
			if emu:read8(sym:addr("wIsInBattle")) ~= 0 then return end
			dump.write("battle_exp_all", dump.standard_regions(sym), {
				frame = scenario.frame(),
				description = "SNORLAX L80 knocked out the spec wild PIDGEY L13 with " ..
					"STRENGTH while holding EXP_ALL, so FaintEnemyPokemon halved the " ..
					"enemy's base stats and ran GainExperience a second time over the " ..
					"whole party — the first golden that enters the Exp. All branch, " ..
					"and the branch whose DivideExpDataByNumMonsGainingExp page-faulted " ..
					"the port until 17d670c2f",
			})
			dumped = true
		end)
		if dumped then break end
		if i % 4 == 0 then
			input.tap("A", 2, 6)
		end
	end
	assert(dumped, "battle_exp_all: the battle never ended (wIsInBattle stayed " ..
		"non-zero) after the whole-party EXP pass — EndOfBattle did not run")
end)
