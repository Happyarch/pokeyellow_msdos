---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- battle_thrash — golden for the port's DEBUG_BATTLE_THRASH=1 gate (differ class
-- "datastruct": WRAM game data only). SNORLAX L80 uses THRASH on the
-- convergence-spec wild PIDGEY L13, and the scenario photographs the END of the
-- thrash: ExecutePlayerMove's .thrashingAboutCheck clearing THRASHING_ABOUT and
-- setting CONFUSED once the counter runs out.
--
-- WHY THIS SCENARIO EXISTS. It is the last third of battle plan 3a's original
-- entry, which asked for "the complete Bide/Thrash/trapping counter,
-- accumulation, release and cleanup flow". battle_wrap witnessed the trapping
-- counter and battle_bide witnessed STORING_ENERGY; THRASHING_ABOUT had never
-- been set by anything in the registry. Like both of those, this needs the REAL
-- MainInBattleLoop: the block only means anything across two turns, and while
-- THRASHING_ABOUT is set MainInBattleLoop skips the menu entirely
-- (core.asm:322-324), so the move auto-repeats with no further input.
--
-- WHAT IS PINNED, AND WHAT DELIBERATELY IS NOT.
--   1. ENEMY HP 65535 + ASLEEP. THRASH is power 90 from L80; at the spec
--      PIDGEY's 36 HP the first hit is a KO, MainInBattleLoop takes
--      `jp z, HandleEnemyMonFainted`, and the second turn — the one that ends
--      the thrash — never happens. **battle_wrap's 999 IS NOT ENOUGH HERE, and
--      that was measured, not guessed:** WRAP is power 15 and THRASH is 90, so
--      two thrash hits from L80 blow straight through 999. The first attempt at
--      this scenario used 999 and the probe read `s1=00 atks=0 conf=0` forever
--      — the thrash had ended because the BATTLE had, not because
--      .thrashingAboutCheck ran. Sleep removes the enemy's turn so wBattleMon
--      stays roll-free.
--   2. THE THRASH COUNTER, forced to 1. ThrashPetalDanceEffect rolls it 2-3
--      (`BattleRandom / and $1 / inc a / inc a`, effects.asm:837-841) and the
--      two emulators do not share an RNG stream, so the end has to be forced
--      onto the same turn on both sides.
--   3. wPlayerConfusedCounter IS **NOT** PINNED, AND IS **NOT** COMPARED. It is
--      a second BattleRandom roll (`and 3 / inc a / inc a`, 2-5 turns), so the
--      two sides cannot agree on it. Pinning it would make the comparison a
--      TAUTOLOGY — the harness would write 3 on both sides and then check that
--      both read 3, which tests the harness rather than the port. It is carried
--      as a scenario-local row and SKIPPED in golden_diff with that reason
--      written out, so the gap is greppable instead of silent.
--
-- WHAT IS ACTUALLY WITNESSED, then: the state transition. THRASHING_ABOUT
-- CLEAR and CONFUSED SET in wPlayerBattleStatus1, with the counter down to 0.
-- The latch below is what makes that a landmark rather than an initial state —
-- "not thrashing and not confused" is exactly how the battle starts.
--
-- wPlyMoveNum IS CARRIED BUT IS **NOT** DISCRIMINATING, and saying so is the
-- point. .thrashingAboutCheck does write wPlayerMoveNum = THRASH on every
-- thrash turn (pret core.asm:3706) — but GetCurrentMove ALREADY wrote the
-- selected move there (pret core.asm:1781), and the selected move IS THRASH.
-- So the row reads $25 whether or not the block under test ran. It is kept
-- because it is cheap and it pins the port's move-number bookkeeping against
-- the ROM's, NOT because it is evidence that the thrash ended.
--
-- wEnemyMon IS SKIPPED, narrowly and for battle_wrap's exact reason: the
-- enemy's remaining HP is the accumulated damage of the thrash hits, which is a
-- roll. It is seeded high purely so it SURVIVES to the second turn.

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

local THRASH = 0x25                -- constants/move_constants.asm
local THRASHING_ABOUT = 1          -- bit index, constants/battle_constants.asm
local CONFUSED = 7
local THRASH_MASK = 1 << THRASHING_ABOUT
local CONFUSED_MASK = 1 << CONFUSED
local ENEMY_HP = { 0xFF, 0xFF }    -- 65535, big-endian (Gen-1 byte order)
local SLEEP_TURNS = 7
local PARTY_MON_LEVEL = 80      -- SNORLAX L80, lib/seed.lua DEBUG_PARTY[1]

-- wPlayerBattleStatus1 ($D061), wPlayerNumAttacksLeft ($D069) and
-- wPlayerConfusedCounter ($D06A) are within 10 bytes of each other, so ONE read
-- covers all three and a poll costs a single frame. battle_exp_all is the
-- cautionary tale: two reads in a poll are two frames, and a condition spanning
-- them can be "true" without ever having been true at one instant.
local STATUS_BLOCK = 0xD06A - 0xD061 + 1
local OFF_ATKS = 0xD069 - 0xD061 + 1      -- 1-based index into the block

-- The three SCENARIO-LOCAL rows, mirrored BY NAME from the %ifdef
-- DEBUG_BATTLE_THRASH gbregion rows in dos_port/src/debug/debug_dump.asm.
-- wPlyConfused is carried but SKIPPED by the differ — see the header.
local function regions(s)
	local r = dump.standard_regions(s)
	r[#r + 1] = { name = "wPlyStatus1",  addr = s:addr("wPlayerBattleStatus1"),  size = 1 }
	r[#r + 1] = { name = "wPlyAtksLeft", addr = s:addr("wPlayerNumAttacksLeft"), size = 1 }
	r[#r + 1] = { name = "wPlyConfused", addr = s:addr("wPlayerConfusedCounter"), size = 1 }
	r[#r + 1] = { name = "wPlyMoveNum",  addr = s:addr("wPlayerMoveNum"),        size = 1 }
	return r
end

scenario.run(function()
	battle.enter_wild(sym, text)

	-- A dismisses "appeared!"; send-out runs unattended; menu box parks.
	input.tap("A", 2, 8)
	navigate.dialog_until_text(text:encode("FIGHT"), 3600)
	scenario.wait(30) -- settle: menu parked in its input loop

	-- Pin 1, plus THRASH into the LOADED battle mon's move slot 1 (SNORLAX does
	-- not learn it; lib/seed.lua pokes FLY/CUT/SURF/STRENGTH).
	scenario.exec(function()
		local hp = sym:addr("wEnemyMonHP")
		local mx = sym:addr("wEnemyMonMaxHP")
		for i, b in ipairs(ENEMY_HP) do
			emu:write8(hp + i - 1, b)
			emu:write8(mx + i - 1, b)
		end
		emu:write8(sym:addr("wEnemyMonStatus"), SLEEP_TURNS)
		emu:write8(sym:addr("wBattleMonMoves"), THRASH)
	end)

	-- FIGHT -> the move list; THRASH is slot 1, where the cursor starts.
	navigate.choose(text:encode("FIGHT"))
	scenario.wait(30) -- settle: a tap into a just-drawn list is swallowed
	input.tap("A", 2, 10)

	-- Pin 2 and the dump, both inside ONE yielded thunk per frame: every
	-- scenario.* helper is a coroutine yield == one frame, so testing in one
	-- call and dumping in the next photographs a frame later than the frame
	-- that satisfied the condition.
	local status1 = sym:addr("wPlayerBattleStatus1")
	local atks = sym:addr("wPlayerNumAttacksLeft")
	local seen_set = false
	local dumped = false
	for i = 1, 3600 do
		scenario.exec(function()
			if dumped then return end
			local blk = emu:readRange(status1, STATUS_BLOCK)
			local s1 = blk:byte(1)
			if (s1 & THRASH_MASK) ~= 0 then
				seen_set = true
				if blk:byte(OFF_ATKS) > 1 then
					emu:write8(atks, 1)
				end
				return
			end
			-- The END: the bit is clear, CONFUSED is set, and we watched the bit
			-- BE set. "Not thrashing and not confused" is the initial state, so
			-- the latch is what turns this into a landmark.
			if not seen_set then return end
			if (s1 & CONFUSED_MASK) == 0 then return end
			-- ALIGNMENT CLAUSE, tried BEFORE reaching for a mask. Without it the
			-- only divergence was `wLoadedMon level: want $50 | got $0D` — the
			-- HUD staging buffer, golden holding the PLAYER mon and port the
			-- ENEMY, the two sides straddling the turn tail's DrawHUDsAndHPBars.
			-- battle_wrap has the identical symptom and skips the whole region;
			-- here the window is wide enough to converge on, because CONFUSED
			-- stays set for turns rather than a handful of frames. The port gate
			-- makes the identical check.
			if emu:read8(sym:addr("wLoadedMonLevel")) ~= PARTY_MON_LEVEL then return end
			dump.write("battle_thrash", regions(sym), {
				frame = scenario.frame(),
				description = "SNORLAX L80 thrashed the spec wild PIDGEY L13 (seeded " ..
					"to 65535 HP and asleep so the sequence runs without a KO or an " ..
					"enemy turn) with the thrash counter pinned to 1, and " ..
					".thrashingAboutCheck ended it: THRASHING_ABOUT cleared and " ..
					"CONFUSED set — the first golden in which THRASHING_ABOUT is " ..
					"ever set, let alone cleared",
			})
			dumped = true
		end)
		if dumped then break end
		-- Tap sparingly: the taps walk the move text, but the poll must stay one
		-- frame. battle_wrap's shape.
		if i % 4 == 0 then
			input.tap("A", 2, 6)
		end
	end
	assert(seen_set, "battle_thrash: THRASHING_ABOUT was never set — THRASH did " ..
		"not execute, or the move slot poke did not take")
	assert(dumped, "battle_thrash: THRASHING_ABOUT was never cleared with CONFUSED " ..
		"set — .thrashingAboutCheck did not end the thrash")
end)
