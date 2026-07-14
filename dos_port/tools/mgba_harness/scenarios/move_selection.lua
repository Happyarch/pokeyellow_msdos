---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- move_selection — golden for the port's DEBUG_BATTLE_GOLDEN=1 DEBUG_MOVEMENU=1
-- gate (fidelity plan Stage 2): the FIGHT sub-menu (move list + ▶ cursor) for
-- SNORLAX's seeded HM moveset (FLY/CUT/SURF/STRENGTH — PrepareNewGameDebug's
-- move pokes, mirrored by seed.DEBUG_PARTY).
--
-- Dump point: move list open, cursor on slot 1. No turn has run.

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

	-- intro → battle menu (as battle_menu.lua)
	local fight = text:encode("FIGHT")
	input.tap("A", 2, 8)
	navigate.dialog_until_text(fight, 3600)
	scenario.wait(30)

	-- FIGHT (cursor already on it) → move list. ensure_text polls first, so a
	-- swallowed tap on the just-drawn menu is retried instead of double-fired.
	local strength = text:encode("STRENGTH")
	navigate.ensure_text("A", strength, 1800)
	scenario.wait(30) -- settle: move menu parked in its input loop

	assert(navigate.tilemap():find(strength, 1, true), "move_selection: move list vanished")

	scenario.exec(function()
		dump.write("move_selection", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "Wild PIDGEY L13 battle (spec enemy); FIGHT sub-menu open " ..
				"showing FLY/CUT/SURF/STRENGTH, cursor on slot 1",
		})
	end)
end)
