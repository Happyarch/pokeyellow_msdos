---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- battle_wrap — golden for the port's DEBUG_BATTLE_WRAP=1 gate (differ class
-- "datastruct": WRAM game data only). SNORLAX L80 uses WRAP on the
-- convergence-spec wild PIDGEY L13, and the scenario photographs the RELEASE:
-- the turn tail's CheckNumAttacksLeft clearing USING_TRAPPING_MOVE once the
-- trapping counter reaches 0.
--
-- WHY THIS SCENARIO EXISTS. CheckNumAttacksLeft has exactly two call sites
-- (pret core.asm:448/:476), BOTH in MainInBattleLoop's turn tail, and neither is
-- reachable from ExecutePlayerMove. Nothing in the registry had ever run it
-- against a SET bit, so battle plan 3a proved only that clearing an
-- already-clear bit changes nothing. This is the first harness on either side
-- that lets the real MainInBattleLoop run turns.
--
-- THREE THINGS ARE PINNED, AND EACH HAS A MEASURED REASON.
--   1. ENEMY HP 999. At the spec PIDGEY's 36 HP, WRAP from L80 SNORLAX KOs it
--      on turn 1 and MainInBattleLoop takes `jp z, HandleEnemyMonFainted` — the
--      turn tail, and therefore the routine under test, is NEVER REACHED. A KO
--      short-circuits exactly what this scenario is for.
--   2. ENEMY ASLEEP (counter 7). Its damage to SNORLAX would be a ROLL and
--      wBattleMon is compared, so the two sides would diverge on HP for reasons
--      unconnected to this box. Sleep removes the enemy turn deterministically
--      rather than masking anything.
--   3. THE TRAPPING COUNTER, forced to 1. TrappingEffect rolls it 2-5
--      (BattleRandom) and the two emulators do not share an RNG stream, so the
--      release has to be forced onto the same turn on both sides. Same class of
--      pin as battle_blackout's GUST pin. The port does this in AutoKeyDrive.
--
-- THE DUMP WINDOW IS NARROW, BY MEASUREMENT. Both sides keep pressing A to walk
-- text, and a released Wrap is immediately re-cast, so the released state
-- exists only for the frames between the turn tail and the next TrappingEffect.
-- Measured on the port: wPlayerNumAttacksLeft read 00 at frame 700 and 01 again
-- at 900 with the bit set throughout — release, then re-cast. Hence: ONE
-- read_range per poll covering both bytes (they are 9 apart), so a poll costs a
-- single frame and cannot step over the window.
--
-- Dump point: USING_TRAPPING_MOVE CLEAR and the counter 0, having previously
-- SEEN the bit set. That latch is what makes it a landmark — "bit clear and
-- counter 0" is also the initial state.

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

local WRAP = 0x23                  -- constants/move_constants.asm
local USING_TRAPPING_MOVE = 5      -- bit index, constants/battle_constants.asm
local TRAP_MASK = 1 << USING_TRAPPING_MOVE
local ENEMY_HP = { 0x03, 0xE7 }    -- 999, big-endian (Gen-1 byte order)
local SLEEP_TURNS = 7

-- wPlayerBattleStatus1 ($D061) and wPlayerNumAttacksLeft ($D069) are 9 bytes
-- apart, so ONE read covers both and a poll costs one frame. Reading them
-- separately would cost two and could step over the release window.
-- The two SCENARIO-LOCAL rows, mirrored BY NAME from the %ifdef DEBUG_BATTLE_WRAP
-- gbregion rows in dos_port/src/debug/debug_dump.asm. Neither byte is in any
-- shared region: wBattleFlags covers only wIsInBattle..wBattleType
-- ($D057-$D05A). Same precedent as bills_pc_ops' wBoxData.
local function regions(s)
	local r = dump.standard_regions(s)
	r[#r + 1] = { name = "wPlyStatus1",  addr = s:addr("wPlayerBattleStatus1"),  size = 1 }
	r[#r + 1] = { name = "wPlyAtksLeft", addr = s:addr("wPlayerNumAttacksLeft"), size = 1 }
	-- Enemy-HUD checkpoint rows (witness for the status-vs-level rule). Same GB
	-- cells as the port's gbregion pair in src/debug/debug_dump.asm, expressed in
	-- this side's stride: wTileMap is 20 wide with no projection. golden_diff's
	-- "projected" declaration asserts both addresses against GB (col,row).
	r[#r + 1] = { name = "eHudName", addr = s:addr("wTileMap") + 0 * 20 + 1, size = 10 }
	r[#r + 1] = { name = "eHudLv",   addr = s:addr("wTileMap") + 1 * 20 + 0, size = 12 }
	-- Player-HUD spans: pBar + pFrac are DrawHP's whole output, pLv is PrintLevel.
	r[#r + 1] = { name = "pHudName", addr = s:addr("wTileMap") +  7 * 20 + 10, size = 11 }
	r[#r + 1] = { name = "pHudLv",   addr = s:addr("wTileMap") +  8 * 20 + 14, size = 6 }
	r[#r + 1] = { name = "pHudBar",  addr = s:addr("wTileMap") +  9 * 20 + 10, size = 9 }
	r[#r + 1] = { name = "pHudFrac", addr = s:addr("wTileMap") + 10 * 20 + 11, size = 8 }
	return r
end

local PARTY_MON_LEVEL = 80         -- SNORLAX L80, lib/seed.lua DEBUG_PARTY[1]

local function trap_state()
	local blk = scenario.read_range(sym:addr("wPlayerBattleStatus1"), 9)
	return blk:byte(1), blk:byte(9)   -- status1, attacks-left
end

-- ALIGNMENT WAS TRIED AND DOES NOT WORK HERE, recorded so it is not retried.
-- The turn tail runs DrawHUDsAndHPBars before CheckNumAttacksLeft, and that draw
-- stages a mon into wLoadedMon; at the release instant the golden holds the
-- PLAYER mon (L80) and the port holds the ENEMY (L13). Adding
-- `wLoadedMonLevel == 80` to BOTH dump conditions — the fix that worked for
-- battle_item_potion and battle_choose_next_mon — makes the PORT never dump at
-- all: it never re-stages the player inside the released window before the next
-- cast. So the buffer is skipped in golden_diff instead, with the ordering
-- question named there.

scenario.run(function()
	battle.enter_wild(sym, text)

	-- A dismisses "appeared!"; send-out runs unattended; menu box parks.
	input.tap("A", 2, 8)
	navigate.dialog_until_text(text:encode("FIGHT"), 3600)
	scenario.wait(30) -- settle: menu parked in its input loop

	-- Pins 1 and 2, plus WRAP into the LOADED battle mon's move slot 1 (SNORLAX
	-- does not learn it; lib/seed.lua pokes FLY/CUT/SURF/STRENGTH).
	scenario.exec(function()
		local hp = sym:addr("wEnemyMonHP")
		local mx = sym:addr("wEnemyMonMaxHP")
		for i, b in ipairs(ENEMY_HP) do
			emu:write8(hp + i - 1, b)
			emu:write8(mx + i - 1, b)
		end
		emu:write8(sym:addr("wEnemyMonStatus"), SLEEP_TURNS)
		emu:write8(sym:addr("wBattleMonMoves"), WRAP)
	end)

	-- FIGHT -> the move list; WRAP is slot 1, where the cursor starts.
	navigate.choose(text:encode("FIGHT"))
	scenario.wait(30) -- settle: a tap into a just-drawn list is swallowed
	input.tap("A", 2, 10)

	-- Watch the trapping state. Pin 3 lives in this loop: clamp the rolled
	-- counter to 1 the moment the bit is set, so the release lands on the next
	-- turn on both sides. Then dump the first poll that sees the RELEASE.
	local seen_set = false
	local released = false
	for i = 1, 3600 do
		local status1, atks = trap_state()
		if (status1 & TRAP_MASK) ~= 0 then
			seen_set = true
			if atks > 1 then
				scenario.exec(function()
					emu:write8(sym:addr("wPlayerNumAttacksLeft"), 1)
				end)
			end
		elseif seen_set and atks == 0 then
			released = true
			break
		end
		-- Tap sparingly: the taps walk the move text, but every poll must stay
		-- one frame so the narrow released window is not stepped over.
		if i % 4 == 0 then
			input.tap("A", 2, 6)
		end
	end
	assert(seen_set, "battle_wrap: USING_TRAPPING_MOVE was never set — WRAP did " ..
		"not execute, or the move slot poke did not take")
	assert(released, "battle_wrap: the trapping bit was never cleared — " ..
		"CheckNumAttacksLeft did not release the counter")

	scenario.exec(function()
		dump.write("battle_wrap", regions(sym), {
			frame = scenario.frame(),
			description = "SNORLAX L80 wrapped the spec wild PIDGEY L13 (seeded to " ..
				"999 HP and asleep so the sequence can run without a KO or an enemy " ..
				"turn), the trapping counter was pinned to 1, and the turn tail's " ..
				"CheckNumAttacksLeft cleared USING_TRAPPING_MOVE — the first golden " ..
				"in which that routine clears a SET bit",
		})
	end)
end)
