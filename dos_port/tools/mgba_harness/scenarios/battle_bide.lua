---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- battle_bide — golden for the port's DEBUG_BATTLE_BIDE=1 gate (differ class
-- "datastruct": WRAM game data only). SNORLAX L80 uses BIDE on the
-- convergence-spec wild PIDGEY L13, and the scenario photographs the RELEASE:
-- ExecutePlayerMove's .unleashEnergy clearing STORING_ENERGY, zeroing the
-- accumulator and dealing twice what was stored.
--
-- WHY THIS SCENARIO EXISTS. battle_wrap witnessed the TRAPPING counter; nothing
-- has ever witnessed STORING_ENERGY. The Bide arms (port core.asm:1799-1843)
-- live in ExecutePlayerMove and only make sense across TWO turns, which only the
-- real MainInBattleLoop drives — so this gate has battle_wrap's shape, not
-- battle_faint's. It is the Bide half of battle plan 3a's original entry, which
-- asked for "the complete Bide/Thrash/trapping counter, accumulation, release
-- and cleanup flow".
--
-- FOUR THINGS ARE PINNED, EACH WITH A MEASURED REASON.
--   1. ENEMY HP 999. The release deals 200; the spec PIDGEY's 36 HP would be an
--      overkill and the state this scenario is about would be gone before it
--      could be photographed. Same pin, same reason, as battle_wrap's.
--   2. ENEMY ASLEEP (counter 7). Bide accumulates the damage the USER TAKES, so
--      an enemy turn would put a damage ROLL directly into the compared
--      accumulator — the one value this scenario exists to pin. Sleep removes
--      the enemy turn deterministically rather than masking anything.
--   3. THE ROLLED COUNTER, forced to 1. BideEffect rolls wPlayerNumAttacksLeft
--      and the two emulators do not share an RNG stream, so the release has to
--      land on the same turn on both sides. battle_wrap's pin exactly.
--   4. THE ACCUMULATOR, forced to 100 ($0064) — and wDamage to 0 alongside it.
--      With the enemy asleep the accumulated damage is 0, so an unpinned run
--      would take .unleashEnergy's `wMoveMissed = 1` arm and photograph the
--      DEGENERATE release. 100 doubles to the 200 the enemy's 999 HP absorbs.
--      wDamage is zeroed in the same breath because .bideCheck ADDS it into the
--      accumulator on every storing turn: without that, the total would depend
--      on whatever scratch value happened to be there rather than on the pin.
--
-- ALL FOUR OF 3 AND 4's WRITES ARE GATED ON STORING_ENERGY BEING SET, and that
-- condition is load-bearing rather than tidy: .unleashEnergy CLEARS the bit
-- before it writes wDamage, so gating on the bit guarantees these writes can
-- never land between the release computing its damage and
-- HandleIfPlayerMoveMissed applying it. The port gate's AutoKeyDrive block does
-- the identical thing under the identical condition.
--
-- Dump point: the enemy at 799 HP, having SEEN STORING_ENERGY set. The latch is
-- what makes it a landmark — "STORING_ENERGY clear and the accumulator 0" is
-- also the pre-battle state, and the HP value is the only quantity here that
-- cannot be an initial one.

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

local BIDE = 0x75                  -- constants/move_constants.asm
local STORING_ENERGY = 0           -- bit index, constants/battle_constants.asm
local STORE_MASK = 1 << STORING_ENERGY
local ENEMY_HP = { 0x03, 0xE7 }    -- 999, big-endian (Gen-1 byte order)
local SLEEP_TURNS = 7
local BIDE_STORED = { 0x00, 0x64 } -- 100, big-endian — doubles to 200
local ENEMY_HP_AFTER = 999 - 200   -- 799 = $031F

-- The three SCENARIO-LOCAL rows, mirrored BY NAME from the %ifdef
-- DEBUG_BATTLE_BIDE gbregion rows in dos_port/src/debug/debug_dump.asm. None is
-- in any shared region — wBattleFlags covers only wIsInBattle..wBattleType.
-- Same precedent as battle_wrap's two rows.
local function regions(s)
	local r = dump.standard_regions(s)
	r[#r + 1] = { name = "wPlyStatus1",  addr = s:addr("wPlayerBattleStatus1"),  size = 1 }
	r[#r + 1] = { name = "wPlyAtksLeft", addr = s:addr("wPlayerNumAttacksLeft"), size = 1 }
	r[#r + 1] = { name = "wPlyBideDmg",  addr = s:addr("wPlayerBideAccumulatedDamage"), size = 2 }
	return r
end

scenario.run(function()
	battle.enter_wild(sym, text)

	-- A dismisses "appeared!"; send-out runs unattended; menu box parks.
	input.tap("A", 2, 8)
	navigate.dialog_until_text(text:encode("FIGHT"), 3600)
	scenario.wait(30) -- settle: menu parked in its input loop

	-- Pins 1 and 2, plus BIDE into the LOADED battle mon's move slot 1 (SNORLAX
	-- does not learn it; lib/seed.lua pokes FLY/CUT/SURF/STRENGTH).
	scenario.exec(function()
		local hp = sym:addr("wEnemyMonHP")
		local mx = sym:addr("wEnemyMonMaxHP")
		for i, b in ipairs(ENEMY_HP) do
			emu:write8(hp + i - 1, b)
			emu:write8(mx + i - 1, b)
		end
		emu:write8(sym:addr("wEnemyMonStatus"), SLEEP_TURNS)
		emu:write8(sym:addr("wBattleMonMoves"), BIDE)
	end)

	-- FIGHT -> the move list; BIDE is slot 1, where the cursor starts.
	navigate.choose(text:encode("FIGHT"))
	scenario.wait(30) -- settle: a tap into a just-drawn list is swallowed
	input.tap("A", 2, 10)

	-- Pins 3 and 4 live in this loop, and so does the dump. Everything happens
	-- inside ONE yielded thunk per frame: every scenario.* helper is a coroutine
	-- yield == one frame, so a read in one call and a write in the next are a
	-- frame apart, and the port's AutoKeyDrive does all of this within a single
	-- frame. (battle_exp_all learned this the expensive way: a two-read poll
	-- "succeeded" on a condition that was never true simultaneously.)
	local status1 = sym:addr("wPlayerBattleStatus1")
	local atks = sym:addr("wPlayerNumAttacksLeft")
	local bide = sym:addr("wPlayerBideAccumulatedDamage")
	local dmg = sym:addr("wDamage")
	local ehp = sym:addr("wEnemyMonHP")
	local seen_set = false
	local dumped = false
	for i = 1, 3600 do
		scenario.exec(function()
			if dumped then return end
			if (emu:read8(status1) & STORE_MASK) ~= 0 then
				seen_set = true
				if emu:read8(atks) > 1 then
					emu:write8(atks, 1)
				end
				for k, b in ipairs(BIDE_STORED) do
					emu:write8(bide + k - 1, b)
				end
				emu:write8(dmg, 0)
				emu:write8(dmg + 1, 0)
				return
			end
			if not seen_set then return end
			if emu:read8(ehp) * 256 + emu:read8(ehp + 1) ~= ENEMY_HP_AFTER then return end
			dump.write("battle_bide", regions(sym), {
				frame = scenario.frame(),
				description = "SNORLAX L80 used BIDE on the spec wild PIDGEY L13 " ..
					"(seeded to 999 HP and asleep so the two turns run without a KO " ..
					"or an enemy turn); the rolled counter was pinned to 1 and the " ..
					"accumulator to 100, and ExecutePlayerMove's .unleashEnergy " ..
					"released twice that into the enemy — the first golden in which " ..
					"STORING_ENERGY is ever set, let alone released",
			})
			dumped = true
		end)
		if dumped then break end
		-- Tap sparingly: the taps walk the move text, but the poll must stay one
		-- frame so the released window is not stepped over. battle_wrap's shape.
		if i % 4 == 0 then
			input.tap("A", 2, 6)
		end
	end
	assert(seen_set, "battle_bide: STORING_ENERGY was never set — BIDE did not " ..
		"execute, or the move slot poke did not take")
	assert(dumped, ("battle_bide: the enemy never reached %d HP — .unleashEnergy " ..
		"did not release the stored damage"):format(ENEMY_HP_AFTER))
end)
