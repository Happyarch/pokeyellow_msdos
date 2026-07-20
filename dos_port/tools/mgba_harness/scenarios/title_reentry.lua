---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- title_reentry — menu-intro A3. The title's stable checkpoint reached AFTER a
-- round trip through the main menu: title -> START -> MainMenu -> B -> title.
--
-- The port proves the no-leak property at the pixel level (the reentry FRAME.BIN
-- is byte-identical to the title FRAME.BIN). This scenario is the GBSTATE-level
-- counterpart, and it drives the round trip with REAL input on the golden ROM so
-- the golden itself exercises the B-cancel path -- not a copy of title.bin
-- asserted to be equal, but the ROM actually returning to the title.
--
-- Detectors, all pure functions of emulated state:
--   "NEW GAME" tiles           the main menu is drawn.
--   wTitleScreenScene+4 == $0F the idle loop (.loop) has been entered.
--
-- Run (from the repo root):
--   dos_port/tools/mgba_harness/make_goldens.sh title_reentry

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
console:log(("title_reentry: %d symbols from %s"):format(sym.count, sym.path))

local wTileMap = sym:addr("wTileMap")
local wTitleScreenScene = sym:addr("wTitleScreenScene")
local MENU_NEEDLE = text:encode("NEW GAME")

local function on_menu()
	return scenario.read_range(wTileMap, 20 * 18):find(MENU_NEEDLE, 1, true) ~= nil
end

local function at_idle()
	local v
	scenario.exec(function() v = emu:read8(wTitleScreenScene + 4) end)
	return v == 0x0F
end

scenario.run(function()
	-- Reach the main menu (visit 1): tap START through the intro and the title
	-- bounce until "NEW GAME" is on screen. State-aware, so deterministic.
	local reached = false
	scenario.wait(180) -- copyright screen (not skippable)
	for _ = 1, 80 do
		if on_menu() then reached = true break end
		input.tap("START", 2, 28)
	end
	assert(reached, "title_reentry: never reached the main menu")

	-- B-cancel back to the title.
	input.tap("B", 2, 10)

	-- Wait for the menu to tear down and the title's idle loop to re-arm. The
	-- $0F marker is stamped by .loop AFTER the second bounce completes, so this
	-- lands on the same stable composition the `title` golden captures.
	local back = false
	for _ = 1, 400 do
		if not on_menu() and at_idle() then back = true break end
		scenario.wait(1)
	end
	assert(back, "title_reentry: never returned to the title idle loop")

	scenario.wait(20) -- settle into the open-eye window (same as title.lua)

	scenario.exec(function()
		dump.write("title_reentry", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "title stable checkpoint after title -> menu -> B -> title; "
				.. "no leaked compositor state",
		})
	end)
end)
