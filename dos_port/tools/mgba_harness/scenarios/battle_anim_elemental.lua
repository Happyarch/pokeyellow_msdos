---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- battle_anim_elemental — Stage 6's elemental-animation witness, the twin of
-- battle_anim_physical. Same real wild-battle FIGHT -> move menu path, same
-- "dump the first frame whose hardware OAM differs from the parked battle-menu
-- OAM" landmark, but the selected move is ELEMENTAL so the checkpoint lands on
-- the subanimation/flash path rather than the physical frame blocks.
--
-- THE MOVE PIN. The shared debug party's SNORLAX carries only the four HMs, so
-- there is no elemental move to select. Rather than change a party that every
-- other golden already compares, both sides overwrite move slot 4 of the LOADED
-- battle mon with THUNDERSHOCK and leave its PP alone -- see the matching write
-- in dos_port/src/debug/debug_dump.asm under DEBUG_BATTLE_ANIM_ELEMENTAL. The
-- write happens BEFORE the FIGHT menu opens here (the menu is drawn from
-- wBattleMonMoves, so slot 4 must already read THUNDERSHOCK to be selectable);
-- the port pokes it just before its direct ExecutePlayerMove call. Both sides
-- reach the dump with identical wBattleMon bytes.

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
local THUNDERSHOCK = 0x54 -- constants/move_constants.asm
local MOVE_SLOT = 3 -- 0-based; the same slot the debug party's STRENGTH occupies
local OAM_ADDR, OAM_SIZE = 0xFE00, 160

scenario.run(function()
	battle.enter_wild(sym, text)
	input.tap("A", 2, 8)
	navigate.dialog_until_text(text:encode("FIGHT"), 3600)
	scenario.wait(30)

	scenario.exec(function()
		emu:write8(sym:addr("wEnemyMonStatus"), SLEEP_TURNS)
		emu:write8(sym:addr("wBattleMonMoves") + MOVE_SLOT, THUNDERSHOCK)
	end)

	navigate.choose(text:encode("FIGHT"))
	navigate.ensure_text("A", text:encode("THUNDERSHOCK"), 3600)
	scenario.wait(30)

	-- This is the control state. Battle-menu OAM may be nonzero, so nonzero is
	-- not evidence of the frame block; the live frame must CHANGE it.
	local parked = scenario.read_range(OAM_ADDR, OAM_SIZE)
	navigate.choose(text:encode("THUNDERSHOCK"))

	local live
	for _ = 1, 3600 do
		local oam = scenario.read_range(OAM_ADDR, OAM_SIZE)
		if oam ~= parked then
			live = oam
			break
		end
	end
	assert(live, "battle_anim_elemental: THUNDERSHOCK never produced a changed OAM frame")

	scenario.exec(function()
		dump.write("battle_anim_elemental", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "first live OAM frame block from the real FIGHT -> " ..
				"THUNDERSHOCK turn, before animation cleanup or the faint path",
		})
	end)
end)
