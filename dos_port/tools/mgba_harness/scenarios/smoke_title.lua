---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- smoke_title — Session B smoke scenario: boot the golden ROM, skip the
-- copyright/GameFreak/Pikachu intro, land on the main menu (NEW GAME /
-- OPTION), dump tilemap + VRAM + OAM.
--
-- Navigation is state-aware, not blind: every intro stage consumes a START
-- to advance, but the main menu ALSO acts on START (it selects NEW GAME —
-- learned the hard way: a fixed 20-tap mash overshot into Oak's speech). So
-- the loop taps START only until the tilemap actually contains "NEW GAME",
-- then stops. Inputs are still a pure function of emulated state, so the run
-- is deterministic.
--
-- Run (from the repo root):
--   GOLDEN_DIR=dos_port/tests/goldens \
--   PKMN_SYM=../pokeyellow_msdos-pret-golden/pokeyellow.sym \
--   dos_port/tools/mgba_build/mgba-lua-runner \
--       -s dos_port/tools/mgba_harness/scenarios/smoke_title.lua \
--       ../pokeyellow_msdos-pret-golden/pokeyellow.gbc

-- Scenario scripts self-locate: mGBA names the chunk "@<path as invoked>" and
-- roots `require` at scenarios/, so hop one level up to reach lib/.
local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local gbtext = require("lib.gbtext")
local input = require("lib.input")
local dump = require("lib.dump")
local scenario = require("lib.scenario")

local sym = symbols.load()
local text = gbtext.load()
console:log(("smoke_title: %d symbols from %s"):format(sym.count, sym.path))

local wTileMap = sym:addr("wTileMap")
local MENU_NEEDLE = text:encode("NEW GAME")

scenario.run(function()
	scenario.wait(180) -- copyright screen (not skippable)

	-- Tap START through GF logo → Pikachu intro → title, stopping the moment
	-- the main menu's text is on screen (START at the menu would select).
	local on_menu = false
	for _ = 1, 40 do
		local tilemap = scenario.read_range(wTileMap, 20 * 18)
		if tilemap:find(MENU_NEEDLE, 1, true) then
			on_menu = true
			break
		end
		input.tap("START", 2, 28)
	end
	assert(on_menu, "smoke_title: never saw NEW GAME on the tilemap — intro skip failed")

	scenario.wait(30) -- settle: menu is drawn, let any cursor blink state pass

	-- emu-touching work must run on the main Lua state (scenario.lua rule)
	scenario.exec(function()
		dump.write("smoke_title", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "main menu (NEW GAME/OPTION) after intro skip, no save file",
		})
	end)
end)
