---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- battle_short_nick — golden for the port's DEBUG_BATTLE_GOLDEN=1
-- DEBUG_BATTLE_SHORTNICK=1 gate: the same FIGHT/PKMN/ITEM/RUN screen as
-- battle_menu, with the player's mon renamed to a FOUR-letter name.
--
-- WHY IT EXISTS. CenterMonName (pret engine/battle/core.asm) shifts a battle
-- nickname right by 2 / 1 / 0 columns for a name of 1-2 / 3-4 / 5+ characters.
-- Every other scenario's battle mon is named 5 or more characters — the debug
-- party's SNORLAX is 7 — so all of them sit in the UNSHIFTED bucket, where the
-- routine's output is indistinguishable from not calling it at all. This is the
-- only scenario in which CenterMonName moves anything.
--
-- Four letters, not two, is deliberate: the routine counts in PAIRS with an
-- 8-bit `dec b` counter, and only the 3-4 bucket runs BOTH loop iterations. A
-- 1-2 letter name exits on the very first compare and never reaches the counter.
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
local seed = require("lib.seed")

local sym = symbols.load()
local text = gbtext.load()
navigate.init(sym, text)

-- ABRA, internal index $94 (pret constants/pokemon_constants.asm). The NAME is
-- never spelled here or on the port side: both read it out of the ROM's
-- MonsterNames table, so the two sides cannot drift on the encoding.
local SHORT_NICK_SPECIES = 0x94
local NAME_LENGTH = 11
local TERMINATOR = 0x50

local function regions()
	local r = dump.standard_regions(sym)
	-- The player HUD's nickname row. pret places it at hlcoord 10,7 and
	-- CenterMonName moves it one column right for this name, so an unshifted
	-- draw and a shifted one differ here and nowhere else.
	r[#r + 1] = { name = "pHudName", addr = sym:addr("wTileMap") + 7 * 20 + 10, size = 11 }
	return r
end

scenario.run(function()
	battle.enter_wild(sym, text)

	-- Rename PARTY SLOT 0 only — the species, stats and DVs stay exactly as
	-- battle_menu has them. The send-out below runs the real
	-- LoadBattleMonFromParty, which carries the nickname into wBattleMonNick
	-- just as it would in play; the port's gate does the same two steps.
	-- Read and write both inside scenario.exec: emu.memory.cart0 is only
	-- reachable from a callback context, so hoisting the ROM read out of here
	-- fails with "Function called from invalid context".
	local nick
	scenario.exec(function()
		nick = seed.monster_name(sym, SHORT_NICK_SPECIES) .. string.char(TERMINATOR)
		assert(#nick == NAME_LENGTH, "battle_short_nick: nickname field is not NAME_LENGTH")
		local base = sym:addr("wPartyMonNicks")
		for i = 1, #nick do
			emu:write8(base + i - 1, nick:byte(i))
		end
	end)

	-- Same navigation as battle_menu: A dismisses "appeared!", the send-out runs
	-- unattended, and the menu box ends the sequence.
	local fight = text:encode("FIGHT")
	input.tap("A", 2, 8)
	navigate.dialog_until_text(fight, 3600)
	scenario.wait(30) -- settle: menu parked in its input loop

	assert(navigate.tilemap():find(fight, 1, true), "battle_short_nick: menu vanished")

	scenario.exec(function()
		-- Prove the seed actually reached the battle mon before photographing it.
		-- Without this a staging drift would silently photograph SNORLAX and the
		-- scenario would pass while witnessing nothing — which is exactly the
		-- failure mode it was built to close.
		local nb = sym:addr("wBattleMonNick")
		local got = ""
		for i = 0, 3 do got = got .. string.char(emu:read8(nb + i)) end
		local want = nick:sub(1, 4)
		assert(got == want, ("battle_short_nick: wBattleMonNick starts %q, expected %q — " ..
			"the party rename did not reach the battle mon"):format(got, want))
		assert(emu:read8(nb + 4) == TERMINATOR,
			"battle_short_nick: nickname is not 4 characters — wrong CenterMonName bucket")

		dump.write("battle_short_nick", regions(), {
			frame = scenario.frame(),
			description = "Wild PIDGEY L13 battle (spec enemy); party slot 0 sent out " ..
				"under a FOUR-letter nickname, with the FIGHT/PKMN/ITEM/RUN menu open. " ..
				"The only scenario that leaves CenterMonName's unshifted bucket.",
		})
	end)
end)
