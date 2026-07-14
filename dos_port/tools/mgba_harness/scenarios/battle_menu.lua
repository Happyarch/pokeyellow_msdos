---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- battle_menu — golden for the port's DEBUG_BATTLE_GOLDEN=1 DEBUG_BATTLE_MENU=1
-- gate (fidelity plan Stage 2): the FIGHT/PKMN/ITEM/RUN battle menu after the
-- player's first mon (SNORLAX, party slot 0) is sent out. Gen 1 draws no
-- "What will X do?" text — the screen is both HUDs + an empty dialog box +
-- the menu box with the ▶ cursor on FIGHT.
--
-- Dump point: menu open, cursor parked. No turn has run (no outcome RNG).

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

scenario.run(function()
	battle.enter_wild(sym, text)

	-- A dismisses "appeared!"; the send-out ("Go! SNORLAX!" + ball animation)
	-- runs unattended; the menu box ends the sequence. dialog_until_text taps A
	-- only on a ▼ prompt, so it answers exactly the prompts the stream has.
	local fight = text:encode("FIGHT")
	input.tap("A", 2, 8)
	navigate.dialog_until_text(fight, 3600)
	scenario.wait(30) -- settle: menu parked in its input loop

	assert(navigate.tilemap():find(fight, 1, true), "battle_menu: menu vanished")

	scenario.exec(function()
		dump.write("battle_menu", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "Wild PIDGEY L13 battle (spec enemy); SNORLAX sent out; " ..
				"FIGHT/PKMN/ITEM/RUN menu open, cursor on FIGHT",
		})
	end)
end)
