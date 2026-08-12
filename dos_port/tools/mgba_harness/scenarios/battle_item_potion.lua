---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- battle_item_potion — golden for the port's DEBUG_BATTLE_ITEM=1 gate (differ
-- class "datastruct": WRAM game data only). The convergence-spec wild PIDGEY
-- L13 battle (battle.enter_wild), then the player opens the BATTLE BAG and uses
-- a POTION on the active mon.
--
-- WHY THIS SCENARIO EXISTS. Battle plan 2c ported the real BagWasSelected /
-- DisplayBagMenu / UseBagItem on 2026-08-12 and nothing in the registry opened
-- the battle bag. `ball_catch` does NOT count: its gate presets wCurItem and
-- calls UseItem directly, bypassing the entire menu leg. This is the second of
-- the Stage 2 scenario box's five, after battle_switch.
--
-- IT PAID FOR ITSELF ON THE FIRST RUN. The port PAGE-FAULTED the moment an item
-- was chosen: GetItemName dropped pret's `.Finish: ld de, wNameBuffer`
-- (home/names.asm:47), so UseBagItem's `call GetItemName / call
-- CopyToStringBuffer` (core.asm:2348-2349) copied from whatever flat name-table
-- pointer GetName had left in EDX. The overworld bag never saw it because
-- DisplayListMenuID sets EDX itself.
--
-- MENU GEOMETRY, from pret core.asm:2150-2270 (same reading as battle_switch).
-- ITEM is the LEFT column's bottom item, so it is DOWN then A — no column
-- change. Its pre-swap id 1 becomes 2, which is the `cp $2` that falls into
-- BagWasSelected. Then POTION is the first bag entry (seed.DEBUG_ITEMS), so A
-- takes it, and a POTION is medicine: ItemUseMedicine opens the PARTY menu to
-- pick a target, which opens on slot 0 — the mon that is out and the one this
-- scenario heals — so that is another bare A.
--
-- THE DAMAGE SEED, and why it is a seed rather than a real hit. A POTION on a
-- full-HP mon takes ItemUseMedicine's no-effect branch, which is a DIFFERENT
-- scenario (the box's "failed item"). Taking real damage first would make the
-- healed total depend on a damage roll, and the two sides do NOT share an RNG
-- stream (lib/seed.lua). So the active mon is knocked to SEED_HP in both its
-- party slot and the loaded battle mon, exactly as the port gate does, and the
-- compared result is arithmetic: SEED_HP + 20, with no roll anywhere in the
-- flow.
--
-- RNG-INDEPENDENCE: nothing rolled before the dump. No move is used, no damage
-- is dealt, and the enemy's free turn happens after both sides have dumped.
--
-- Dump point: wBattleMonHP == SEED_HP + 20, the heal ItemUsePotion performs
-- (pret engine/items/item_effects.asm). The port gate dumps at the instruction
-- after DisplayBattleMenu returns, i.e. UseBagItem's own ret, a few beats later
-- — the window between them holds only the "recovered HP" message, the sprite
-- clear and the screen restore, none of which touch compared game data.

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

local SEED_HP = 100      -- must equal the port gate's POTION_SEED_HP
local POTION_HEAL = 20   -- pret item_effects.asm
local ITEM_MENU_ITEM = 1 -- wCurrentMenuItem for the left column's bottom entry
-- SNORLAX, party slot 0 = the active mon (lib/seed.lua DEBUG_PARTY[1]). Used as
-- the second half of the dump condition: wLoadedMon is a transient STAGING
-- buffer, and the party menu's own draw leaves the LAST party mon in it
-- (LAPRAS, slot 5). Waiting until DrawPlayerHUDAndHPBar has re-staged the
-- active mon aligns this side's last-writer with the port's, whose gate dumps
-- after the battle screen is restored. Without it the two sides disagree on
-- every wLoadedMon field for no reason but dump timing — measured, and the
-- alternative was masking the whole buffer.
local ACTIVE_SPECIES = 132

local function read8(label)
	return scenario.read_range(sym:addr(label), 1):byte(1)
end

local function read_be16(label)
	local raw = scenario.read_range(sym:addr(label), 2)
	return raw:byte(1) * 256 + raw:byte(2)
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

	-- A dismisses "appeared!"; the send-out of slot 0 runs unattended; the
	-- battle menu parks in its left-column input loop with the cursor on FIGHT.
	input.tap("A", 2, 8)
	navigate.dialog_until_text(text:encode("FIGHT"), 3600)
	scenario.wait(30) -- settle: menu parked in HandleMenuInput

	-- Knock the active mon down, in BOTH places (the party slot and the loaded
	-- battle mon), at the same point in the flow the port gate does. HP is a
	-- big-endian word — the Gen-1 byte order rule.
	scenario.exec(function()
		for _, label in ipairs({ "wPartyMon1HP", "wBattleMonHP" }) do
			local a = sym:addr(label)
			emu:write8(a, SEED_HP >> 8)
			emu:write8(a + 1, SEED_HP & 0xFF)
		end
	end)

	-- FIGHT -> ITEM (left column, bottom). Polled, not assumed.
	assert(tap_until_byte("DOWN", "wCurrentMenuItem", ITEM_MENU_ITEM, 30),
		"battle_item_potion: the battle-menu cursor never reached ITEM")

	-- A -> BagWasSelected -> the bag list, confirmed by its first entry.
	navigate.tap_until("A", text:encode("POTION"), 1800)
	scenario.wait(20) -- settle: list drawn, cursor placed

	-- A on POTION -> UseBagItem -> ItemUseMedicine -> the party menu, which
	-- opens on slot 0 (SNORLAX, the mon that is out and the heal target).
	navigate.tap_until("A", text:encode("SNORLAX"), 1800)
	scenario.wait(20)
	input.tap("A", 2, 10)

	-- Dump point (see the header). The taps walk the "recovered HP" message;
	-- the poll is what decides when to stop.
	local healed = false
	for _ = 1, 1800 do
		if read_be16("wBattleMonHP") == SEED_HP + POTION_HEAL
			and read8("wLoadedMon") == ACTIVE_SPECIES then
			healed = true
			break
		end
		input.tap("A", 2, 10)
	end
	assert(healed, ("battle_item_potion: the POTION never healed — wBattleMonHP " ..
		"did not reach %d"):format(SEED_HP + POTION_HEAL))

	scenario.exec(function()
		dump.write("battle_item_potion", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "a POTION used from the BATTLE BAG on the active mon " ..
				"(SNORLAX L80, seeded to " .. SEED_HP .. " HP) against the spec " ..
				"wild PIDGEY L13 — the first golden that opens the in-battle bag, " ..
				"so BagWasSelected / DisplayBagMenu / UseBagItem finally execute",
		})
	end)
end)
