---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- battle_item_no_effect — golden for the port's DEBUG_BATTLE_ITEM_FAIL=1 gate
-- (differ class "datastruct": WRAM game data only). The convergence-spec wild
-- PIDGEY L13 battle (battle.enter_wild), then a POTION used from the BATTLE BAG
-- on a FULL-HP mon, which FAILS.
--
-- WHY THIS SCENARIO EXISTS. It is the last of the Stage 2 scenario box's five
-- and the only one that exercises an item's FAILURE path: ItemUseMedicine ->
-- .healingItemNoEffect -> ItemUseNoEffect, which prints "It won't have any
-- effect." and zeroes wActionResultOrTookBattleTurn (UseItem_ had set it to 1
-- on entry, engine/items/item_effects.asm). battle_item_potion covers the
-- success path; nothing covered this one.
--
-- IT NEEDS A STATE-GATED DUMP, and that is the structural fact worth carrying:
-- on failure UseBagItem is `jp z, BagWasSelected` when
-- wActionResultOrTookBattleTurn == 0 (pret engine/battle/core.asm:2360-2362),
-- so EVERY failed item — no-effect medicine, a can't-use-here item, a declined
-- ball — loops back into the bag menu and DisplayBattleMenu NEVER RETURNS.
-- battle_item_potion, battle_switch and ball_catch all hang their dump on that
-- return and none of them could be copied here.
--
-- TARGET IS PARTY SLOT 1 (PERSIAN L80), NOT SLOT 0. wUsedItemOnWhichPokemon is
-- 0 in cleared WRAM, so a slot-0 target would give a landmark that cannot be
-- told apart from "the flow never ran".
--
-- NO SEEDING AT ALL, and no RNG: the party is at the seed's full HP already, so
-- the failure is structural rather than arranged. No move is used, no damage is
-- dealt, no accuracy is checked, and both sides dump before the enemy can act.
--
-- Dump point: wCurItem == POTION AND wUsedItemOnWhichPokemon == 1 AND
-- wActionResultOrTookBattleTurn == 0. Each clause earns its place — the item
-- that was chosen, the party choice having been made, and then the failure
-- edge. What is compared is that NOTHING happened: the bag still holds 16
-- entries with POTION x1, and every party HP is untouched.

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

local ITEM_MENU_ITEM = 1 -- wCurrentMenuItem for the battle menu's left/bottom entry
local TARGET_SLOT = 1    -- PERSIAN L80 (lib/seed.lua DEBUG_PARTY[2]), full HP
local POTION = 0x14      -- constants/item_constants.asm

local function read8(label)
	return scenario.read_range(sym:addr(label), 1):byte(1)
end

-- Tap `keys` until `label` holds `want`, polling FIRST so an already-correct
-- state costs no press (an extra press into a menu selects something).
local function tap_until_byte(keys, label, want, rounds)
	for _ = 1, (rounds or 30) do
		for _ = 1, 20 do
			if read8(label) == want then
				return true
			end
		end
		input.tap(keys, 2, 8)
	end
	return false
end

scenario.run(function()
	battle.enter_wild(sym, text)

	-- A dismisses "appeared!"; the send-out runs unattended; the battle menu
	-- parks in its left-column input loop with the cursor on FIGHT.
	input.tap("A", 2, 8)
	navigate.dialog_until_text(text:encode("FIGHT"), 3600)
	scenario.wait(30)

	-- FIGHT -> ITEM (left column, bottom). Polled, not assumed.
	assert(tap_until_byte("DOWN", "wCurrentMenuItem", ITEM_MENU_ITEM, 30),
		"battle_item_no_effect: the battle-menu cursor never reached ITEM")

	-- A -> BagWasSelected -> the bag list, confirmed by its first entry.
	navigate.tap_until("A", text:encode("POTION"), 1800)
	scenario.wait(20)

	-- A on POTION -> UseBagItem -> ItemUseMedicine -> the party menu. SNORLAX
	-- appears only in the party list, never in the bag, so it discriminates.
	navigate.tap_until("A", text:encode("SNORLAX"), 1800)
	scenario.wait(20)

	-- Move to slot 1 (PERSIAN, full HP) and use the POTION on it.
	assert(tap_until_byte("DOWN", "wCurrentMenuItem", TARGET_SLOT, 30),
		"battle_item_no_effect: the party cursor never reached slot 1")
	input.tap("A", 2, 10)

	-- Dump point (see the header). The taps walk "It won't have any effect.";
	-- the poll decides when to stop, so an extra press cannot overshoot it.
	local failed = false
	for _ = 1, 1800 do
		if read8("wCurItem") == POTION
			and read8("wUsedItemOnWhichPokemon") == TARGET_SLOT
			and read8("wActionResultOrTookBattleTurn") == 0 then
			failed = true
			break
		end
		input.tap("A", 2, 10)
	end
	assert(failed, "battle_item_no_effect: the POTION never reported failure — " ..
		"wCurItem/wUsedItemOnWhichPokemon/wActionResultOrTookBattleTurn did not " ..
		"reach POTION/1/0")

	scenario.exec(function()
		dump.write("battle_item_no_effect", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "a POTION used from the BATTLE BAG on a FULL-HP mon " ..
				"(PERSIAN L80, party slot 1) against the spec wild PIDGEY L13 — " ..
				"ItemUseMedicine's no-effect branch, so nothing is consumed and " ..
				"nothing is healed: the first golden that takes an item's FAILURE path",
		})
	end)
end)
