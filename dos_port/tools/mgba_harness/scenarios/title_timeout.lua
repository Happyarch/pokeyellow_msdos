---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- title_timeout — menu-intro B4. Prove the title-screen TIMEOUT replays the boot
-- movie. pret's DisplayTitleScreen idle loop counts up (IncrementResetCounter) and,
-- after ~$0C00 frames with no input, resets to Init. With the faithful-default flip,
-- Init calls PlayIntro, so the movie REPLAYS. This golden captures the replayed
-- copyright screen (identical composition to gamefreak_intro, but reached via the
-- timeout route), proving the route end-to-end.
--
-- Navigation: tap START until the title announces itself (hSCY==64) to skip the
-- initial intro (the bounce never reads the joypad, so tapping is safe there), then
-- STOP — pressing A/START at the idle title would open the menu instead of timing out.
-- With no further input the idle loop times out and the movie replays; wait for the
-- copyright to reappear, then dump. (The port side shortens the timeout under
-- DEBUG_TITLE_TIMEOUT so its headless run is short; the state reached is the same.)
--
-- Run: dos_port/tools/mgba_harness/make_goldens.sh title_timeout

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local scenario = require("lib.scenario")
local input = require("lib.input")
local dump = require("lib.dump")

local sym = symbols.load()
console:log(("title_timeout: %d symbols from %s"):format(sym.count, sym.path))

local wTileMap = sym:addr("wTileMap")
local COPYRIGHT_CELL = wTileMap + 7 * 20 + 2          -- hlcoord 2,7 (first © glyph)
local rSCY = 0xFF42
local function is_copyright_tile(t) return t >= 0x60 and t <= 0x7b end

local scy, tile = -1, -1

scenario.run(function()
	-- Phase 1 — tap START to skip the initial intro and reach the title.
	local reached = false
	for i = 1, 2000 do
		scenario.exec(function() scy = emu:read8(rSCY) end)
		if scy == 64 then reached = true break end
		if i % 20 == 0 then input.tap("START") end
	end
	assert(reached, "title_timeout: never reached the title (hSCY never became 64)")

	-- Phase 2 — no more input. The idle loop times out (~$0C00 frames) and the movie
	-- replays; wait for the copyright to reappear.
	local replayed = false
	for _ = 1, 4000 do
		scenario.exec(function() tile = emu:read8(COPYRIGHT_CELL) end)
		if is_copyright_tile(tile) then replayed = true break end
	end
	assert(replayed, "title_timeout: the movie never replayed after the timeout")

	scenario.wait(3)   -- into the copyright still (static)
	scenario.exec(function()
		dump.write("title_timeout", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "title timeout -> Init -> PlayIntro replay: the copyright screen "
				.. "reappears (rows 7/9/11), proving the reset route replays the boot movie",
		})
	end)
end)
