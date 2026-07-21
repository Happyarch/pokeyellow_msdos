---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- gamefreak_intro — menu-intro B4. Golden for the Game Freak splash's STABLE
-- checkpoint: the boot copyright screen.
--
-- PlayShootingStar draws the "(c)1995-1999 Nintendo / Creatures inc. / GAME FREAK
-- inc." copyright screen (LoadCopyrightAndTextBoxTiles), then holds it motionless
-- for DelayFrames 180 before the bars/logo/shooting-star animation begins. That
-- 180-frame still is the golden-able composition: three text lines on wTileMap
-- rows 7 / 9 / 11 (double-spaced <NEXT>, since BIT_SINGLE_SPACED_LINES is clear at
-- boot), the copyright-logo + font glyph tiles in vChars2, no OAM.
--
-- Motion (the shooting star, the logo flash) is NOT this scenario's job — that is
-- a separate splash trace. A single-frame golden structurally cannot express it.
--
-- Checkpoint detector: wTileMap row 7 col 2 (pret hlcoord 2,7 = the first
-- copyright glyph) becoming a copyright-logo/font tile ($60-$7b). Measured to
-- occur at frame ~79; the copyright then sits for 180 frames, so dumping a fixed
-- offset later lands well inside the still window and is fully deterministic.
--
-- Run (from the repo root):
--   dos_port/tools/mgba_harness/make_goldens.sh gamefreak_intro

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local scenario = require("lib.scenario")
local dump = require("lib.dump")

local sym = symbols.load()
console:log(("gamefreak_intro: %d symbols from %s"):format(sym.count, sym.path))

local wTileMap = sym:addr("wTileMap")   -- GB tilemap, 20 tiles wide
local COPYRIGHT_CELL = wTileMap + 7 * 20 + 2  -- hlcoord 2, 7

local function is_copyright_tile(t) return t >= 0x60 and t <= 0x7b end

local tile = -1

scenario.run(function()
	-- Phase 1 — reach the copyright screen. No input: the boot plays it
	-- unconditionally and the copyright/splash never samples the joypad here.
	local reached = false
	for _ = 1, 400 do
		scenario.exec(function() tile = emu:read8(COPYRIGHT_CELL) end)
		if is_copyright_tile(tile) then
			reached = true
			break
		end
	end
	assert(reached, "gamefreak_intro: copyright screen never appeared (row7 col2 never a $60-$7b tile)")

	-- Phase 2 — land mid-still. The copyright holds for 180 frames; 40 is deep
	-- inside that window with ~140 frames of margin before the bars/logo redraw.
	scenario.wait(40)

	scenario.exec(function()
		dump.write("gamefreak_intro", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "Game Freak splash copyright screen: 3 lines on wTileMap "
				.. "rows 7/9/11, copyright-logo + font glyphs in vChars2, no OAM",
		})
	end)
end)
