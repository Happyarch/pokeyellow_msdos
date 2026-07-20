---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- title — menu-intro A2.6. Golden for the title screen's STABLE CHECKPOINT.
--
-- The title is continuously animated, so "stable" here means stable
-- COMPOSITION, not a motionless machine. The checkpoint is the window after the
-- bounce has finished and before the first eye blink: hSCY is back to 0, the
-- logo-plus-Pikachu tilemap is installed at source row zero, the window layer is
-- parked off-screen again, the title palette is live, MUSIC_TITLE_SCREEN has
-- been dispatched, the eyes are open, and no input has been consumed. Every
-- frame in that window is pixel-identical, which is what makes it golden-able.
--
-- Motion fidelity is NOT this scenario's job and must not be inferred from it --
-- see title_trace.lua plus tools/check_title_timing.py, which compare the bounce
-- frame by frame. A single-frame golden structurally cannot express motion.
--
-- The checkpoint detector is wTitleScreenScene + 4 becoming $0F. pret's .loop
-- writes that byte (`ld a, $f / ld [wTitleScreenScene + 4], a`) as its very
-- first act, so the transition marks idle-loop entry exactly, whereas hSCY and
-- hWY have both already settled several routines earlier and cannot distinguish
-- .loop from the PCM/music sequence that precedes it.
--
-- Run (from the repo root):
--   dos_port/tools/mgba_harness/make_goldens.sh title

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local scenario = require("lib.scenario")
local input = require("lib.input")
local dump = require("lib.dump")

local sym = symbols.load()
console:log(("title: %d symbols from %s"):format(sym.count, sym.path))

local wTitleScreenScene = sym:addr("wTitleScreenScene")
local rSCY = 0xFF42

local scy_now, marker = -1, -1

scenario.run(function()
	-- Phase 1 — skip the boot movie. The ROM plays the copyright screen, the
	-- Game Freak splash and the whole Yellow intro before DisplayTitleScreen
	-- runs; measured, 700 uninterrupted frames do not get close. hSCY == 64 is
	-- the title announcing itself, and tapping is safe until then because the
	-- bounce never reads the joypad.
	local reached = false
	for i = 1, 2000 do
		scenario.exec(function() scy_now = emu:read8(rSCY) end)
		if scy_now == 64 then
			reached = true
			break
		end
		if i % 20 == 0 then
			input.tap("START")
		end
	end
	assert(reached, "title: never reached the title (hSCY never became 64)")

	-- Phase 2 — no further input, ever. Ride the bounce out and wait for .loop
	-- to stamp its marker. 400 frames is generous: the bounce is 32 frames, the
	-- reveal wait is 36, and the PCM beat is the only open-ended part.
	local settled = false
	for _ = 1, 400 do
		scenario.exec(function()
			marker = emu:read8(wTitleScreenScene + 4)
		end)
		if marker == 0x0F then
			settled = true
			break
		end
	end
	assert(settled, "title: .loop never stamped wTitleScreenScene+4 = $0F")

	-- Settle a few frames inside the stable window, matching the port's
	-- DEBUG_TITLE checkpoint (which dumps at .loop + 3 frames). Any frame here
	-- is identical until the first blink, ~54 frames away, so this is not a
	-- race -- but stay well clear of that edge.
	scenario.wait(3)

	scenario.exec(function()
		dump.write("title", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "title screen stable checkpoint: bounce complete, "
				.. "hSCY=0, eyes open, title music dispatched, no input consumed",
		})
	end)
end)
