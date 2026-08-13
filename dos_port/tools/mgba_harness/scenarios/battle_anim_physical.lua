---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- battle_anim_physical — Stage 6's physical-animation witness. It follows the
-- real wild-battle FIGHT -> STRENGTH menu path and dumps the first frame whose
-- hardware OAM differs from the parked battle-menu OAM. That is the first live
-- animation frame block, before the KO/faint path can clean it up.

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

local SLEEP_TURNS = 7 -- keep the enemy from introducing an RNG-dependent turn
local OAM_ADDR, OAM_SIZE = 0xFE00, 160

scenario.run(function()
	battle.enter_wild(sym, text)
	input.tap("A", 2, 8)
	navigate.dialog_until_text(text:encode("FIGHT"), 3600)
	scenario.wait(30)

	scenario.exec(function()
		emu:write8(sym:addr("wEnemyMonStatus"), SLEEP_TURNS)
	end)

	navigate.choose(text:encode("FIGHT"))
	navigate.ensure_text("A", text:encode("STRENGTH"), 3600)
	scenario.wait(30)

	-- This is the control state. Battle-menu OAM may be nonzero, so nonzero is
	-- not evidence of the frame block; the live frame must CHANGE it.
	local parked = scenario.read_range(OAM_ADDR, OAM_SIZE)
	navigate.choose(text:encode("STRENGTH"))

	local live
	for _ = 1, 3600 do
		local oam = scenario.read_range(OAM_ADDR, OAM_SIZE)
		if oam ~= parked then
			live = oam
			break
		end
	end
	assert(live, "battle_anim_physical: STRENGTH never produced a changed OAM frame")

	scenario.exec(function()
		dump.write("battle_anim_physical", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "first live OAM frame block from the real FIGHT -> " ..
				"STRENGTH turn, before animation cleanup or the faint path",
		})
	end)
end)
