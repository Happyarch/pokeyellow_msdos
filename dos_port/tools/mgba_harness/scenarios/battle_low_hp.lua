---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- battle_low_hp — golden for the port's DEBUG_BATTLE_GOLDEN=1 DEBUG_BATTLE_LOWHP=1
-- gate: the same FIGHT/PKMN/ITEM/RUN screen as battle_menu, but with the
-- player's mon seeded to RED HP and still ALIVE.
--
-- WHY IT EXISTS. The low-health alarm (wLowHealthAlarm bit 7) is armed by
-- DrawPlayerHUDAndHPBar's tail only while a LIVE mon sits at red HP, and cleared
-- the instant that mon faints. Every other scenario's dump point is a settled,
-- post-faint state, so none of them can observe the bit set — battle_choose_next_mon
-- even seeds a 1 HP mon but photographs it after the faint (measured: hardware
-- reads 00 there). This is the only scenario that catches the alarm armed.
--
-- Dump point: menu open, cursor parked on FIGHT. No turn has run, so no outcome
-- RNG is involved — identical determinism to battle_menu.

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

-- 20 of SNORLAX's 362 HP = 5.5%, comfortably inside GetHealthBarColor's red
-- band (<= 1/5) and far from fainting. Seeded BIG-ENDIAN, as all GB mon HP is.
local LOW_HP = 20

local function regions()
	local r = dump.standard_regions(sym)
	-- The alarm byte itself — the thing this scenario exists to pin.
	r[#r + 1] = { name = "wLowHPAlarm", addr = sym:addr("wLowHealthAlarm"), size = 1 }
	-- The red HP bar and its fraction: a different draw from every other
	-- scenario's (full, or partial-but-yellow). Projected spans — same GB cells
	-- as the port's gbregion rows, in this side's stride.
	r[#r + 1] = { name = "pHudBar",  addr = sym:addr("wTileMap") +  9 * 20 + 10, size = 9 }
	r[#r + 1] = { name = "pHudFrac", addr = sym:addr("wTileMap") + 10 * 20 + 11, size = 8 }
	return r
end

scenario.run(function()
	battle.enter_wild(sym, text)

	-- Seed the PARTY slot, not wBattleMon: the send-out below runs the real
	-- LoadBattleMonFromParty, which carries the value across exactly as it would
	-- in play. The port's gate seeds the same two bytes at the same point.
	scenario.exec(function()
		local hp = sym:addr("wPartyMon1HP")
		emu:write8(hp, LOW_HP >> 8)         -- big-endian: high byte first
		emu:write8(hp + 1, LOW_HP & 0xFF)
	end)

	-- Same navigation as battle_menu: A dismisses "appeared!", the send-out runs
	-- unattended, and the menu box ends the sequence.
	local fight = text:encode("FIGHT")
	input.tap("A", 2, 8)
	navigate.dialog_until_text(fight, 3600)
	scenario.wait(30) -- settle: menu parked in its input loop

	assert(navigate.tilemap():find(fight, 1, true), "battle_low_hp: menu vanished")

	scenario.exec(function()
		local cur = emu:read8(sym:addr("wBattleMonHP")) * 256
			+ emu:read8(sym:addr("wBattleMonHP") + 1)
		assert(cur == LOW_HP, ("battle_low_hp: wBattleMonHP is %d, expected %d — " ..
			"the party seed did not reach the battle mon"):format(cur, LOW_HP))
		dump.write("battle_low_hp", regions(), {
			frame = scenario.frame(),
			description = "Wild PIDGEY L13 battle (spec enemy); SNORLAX sent out at " ..
				LOW_HP .. "/362 HP — RED bar, still alive — with the FIGHT/PKMN/ITEM/RUN " ..
				"menu open. The only scenario that catches wLowHealthAlarm ARMED.",
		})
	end)
end)
