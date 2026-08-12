---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- battle_pay_day — golden for the port's DEBUG_BATTLE_PAYDAY=1 gate (differ
-- class "datastruct": WRAM game data only). SNORLAX L80 uses PAY_DAY on the
-- convergence-spec wild PIDGEY L13; the KO ends the battle and EndOfBattle pays
-- the accumulated wTotalPayDayMoney into wPlayerMoney with AddBCD.
--
-- WHY THIS SCENARIO EXISTS. EndOfBattle's payout branch is gated on
-- wTotalPayDayMoney != 0, which is 0 in every other scenario in the registry,
-- so nothing has ever entered it. Battle plan 3b has stood
-- IMPLEMENTED-BUT-NOT-TICKED for want of exactly this.
--
-- THE WALLET IS SEEDED LOW, AND THAT IS NOT COSMETIC. MEASURED: the debug seed
-- leaves wPlayerMoney at the BCD maximum 999999, so AddBCD saturates and the
-- payout leaves the compared bytes completely unchanged — the scenario would
-- PASS while proving nothing at all. Both sides therefore set 001000 first, and
-- the expected end state is 001160.
--
-- ZERO RNG IN THE COMPARED VALUE. The payout is level * 2 in BCD
-- (PayDayEffect_), so it depends on nothing but SNORLAX's level: 80 * 2 = 160.
-- The damage roll and any critical hit change only WHETHER the KO happens, and
-- PAY_DAY at power 40 from L80 overkills PIDGEY's 36 HP on every roll — the
-- same argument battle_faint makes for STRENGTH.
--
-- SNORLAX DOES NOT LEARN PAY_DAY. lib/seed.lua pokes FLY/CUT/SURF/STRENGTH into
-- its four slots, so both sides overwrite the LOADED battle mon's move 1
-- (wBattleMonMoves) after the send-out. Slot 1 is where the move menu's cursor
-- starts, so choosing it is a bare A rather than a name search.
--
-- Dump point: wPlayerMoney == 001160. That is a positive, non-initial value —
-- it cannot be confused with the seeded balance or with cleared WRAM.

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

local PAY_DAY = 0x06        -- constants/move_constants.asm
local MONEY_SEED = { 0x00, 0x10, 0x00 }  -- 001000 BCD
local MONEY_AFTER = 0x001160             -- 001000 + 80 * 2

local function read_be(label, size)
	local raw = scenario.read_range(sym:addr(label), size)
	local v = 0
	for i = 1, size do
		v = v * 256 + raw:byte(i)
	end
	return v
end

scenario.run(function()
	battle.enter_wild(sym, text)

	-- A dismisses "appeared!"; send-out runs unattended; menu box parks.
	input.tap("A", 2, 8)
	navigate.dialog_until_text(text:encode("FIGHT"), 3600)
	scenario.wait(30) -- settle: menu parked in its input loop

	-- Seed the wallet low (see the header) and give the LOADED battle mon
	-- PAY_DAY in slot 1, matching the port gate exactly.
	scenario.exec(function()
		local money = sym:addr("wPlayerMoney")
		for i, b in ipairs(MONEY_SEED) do
			emu:write8(money + i - 1, b)
		end
		emu:write8(sym:addr("wBattleMonMoves"), PAY_DAY)
	end)

	-- FIGHT -> the move list; PAY_DAY is slot 1, where the cursor starts.
	navigate.choose(text:encode("FIGHT"))
	scenario.wait(30) -- settle: a tap into a just-drawn list is swallowed
	input.tap("A", 2, 10)

	-- Walk the turn to the KO. Watch the STATE, not any one message: the beats
	-- race against the taps.
	local down = false
	for _ = 1, 3600 do
		if read_be("wEnemyMonHP", 2) == 0 then
			down = true
			break
		end
		input.tap("A", 2, 10)
	end
	assert(down, "battle_pay_day: enemy never reached 0 HP — a 1/256 accuracy " ..
		"miss, or the turn did not resolve")

	-- NO wTotalPayDayMoney ASSERT HERE, deliberately. It looks like the obvious
	-- mid-flow check and it is wrong: EndOfBattle ZEROES wTotalPayDayMoney after
	-- paying, and the KO poll above only exits at a frame boundary, which can
	-- already be past that. Measured — the first version of this scenario failed
	-- on exactly that and briefly looked like a port divergence. The payout
	-- itself is the test.

	-- Dump point: EndOfBattle has paid out AND finished. The wIsInBattle clause
	-- is not decoration — MEASURED: polling on the money alone lands DURING
	-- EndOfBattle, before its .resetVariables, and the port gate (which calls
	-- EndOfBattle and dumps after it returns) then diverges on exactly that one
	-- byte: `wBattleFlags wIsInBattle: want $01 | got $00`. Same alignment note
	-- ball_catch carries, in the opposite direction.
	local paid = false
	for _ = 1, 3600 do
		if read_be("wPlayerMoney", 3) == MONEY_AFTER
			and read_be("wIsInBattle", 1) == 0 then
			paid = true
			break
		end
		input.tap("A", 2, 10)
	end
	assert(paid, ("battle_pay_day: wPlayerMoney never reached %06x — the " ..
		"EndOfBattle payout branch did not run"):format(MONEY_AFTER))

	scenario.exec(function()
		dump.write("battle_pay_day", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "SNORLAX L80 knocked out the spec wild PIDGEY L13 with " ..
				"PAY_DAY from the real battle FIGHT menu, and EndOfBattle paid the " ..
				"accumulated 160 into a wallet seeded at 001000 — the first golden " ..
				"that enters the Pay Day payout branch at all",
		})
	end)
end)
