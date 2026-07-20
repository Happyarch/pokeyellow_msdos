---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- main_menu — menu-intro A3. The boot main menu with NO save file, reached by
-- real navigation: copyright -> Game Freak -> Yellow intro -> title -> START.
--
-- This scenario MIGRATES smoke_title's navigation rather than renaming its
-- artifact. smoke_title stops the moment "NEW GAME" appears, so what it always
-- actually evidenced was the main menu, not the title -- it predates the title
-- having a checkpoint of its own. The title now has one (title.lua), so the two
-- states are separated: `title` is the stable title composition, `main_menu` is
-- this. The navigation below is smoke_title's, unchanged, because changing it
-- would change what the golden means.
--
-- Navigation is state-aware, not blind: every intro stage consumes a START to
-- advance, but the main menu ALSO acts on START (it selects NEW GAME). So the
-- loop taps START only until the tilemap actually contains "NEW GAME", then
-- stops. Inputs stay a pure function of emulated state, so the run is
-- deterministic.
--
-- Run (from the repo root):
--   dos_port/tools/mgba_harness/make_goldens.sh main_menu

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
console:log(("main_menu: %d symbols from %s"):format(sym.count, sym.path))

local wTileMap = sym:addr("wTileMap")
local MENU_NEEDLE = text:encode("NEW GAME")

scenario.run(function()
	scenario.wait(180) -- copyright screen (not skippable)

	local on_menu = false
	for _ = 1, 40 do
		local tilemap = scenario.read_range(wTileMap, 20 * 18)
		if tilemap:find(MENU_NEEDLE, 1, true) then
			on_menu = true
			break
		end
		input.tap("START", 2, 28)
	end
	assert(on_menu, "main_menu: never saw NEW GAME on the tilemap — intro skip failed")

	scenario.wait(30) -- settle: menu is drawn, let any cursor blink state pass

	scenario.exec(function()
		dump.write("main_menu", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "boot main menu (NEW GAME/OPTION), no save file, "
				.. "reached by real navigation through the title",
		})
	end)
end)
