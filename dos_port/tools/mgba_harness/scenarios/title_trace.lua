---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- title_trace — menu-intro A2.5. Record the title screen's per-frame register
-- sequence from the golden ROM, so the port's bounce and blink timing can be
-- compared record by record instead of by eye.
--
-- This is a TRACE scenario, not a golden-dump scenario: it writes a CSV of
-- (frame, hSCY, hWY, wTitleScreenScene) rather than a memory-region dump. The
-- title is continuously animated, so a single-frame memory golden cannot
-- express its motion — which is exactly the thing A2.5 has to verify.
--
-- No input is ever pressed. The title's own state machine drives everything,
-- so the trace is a pure function of emulated time and stays deterministic.
--
-- Run (from the repo root):
--   PKMN_SYM=../pokeyellow_msdos-pret-golden/pokeyellow.sym \
--   TITLE_TRACE_OUT=/tmp/title_trace.csv \
--   dos_port/tools/mgba_build/mgba-lua-runner -F 900 \
--       -s dos_port/tools/mgba_harness/scenarios/title_trace.lua \
--       ../pokeyellow_msdos-pret-golden/pokeyellow.gbc

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local scenario = require("lib.scenario")
local input = require("lib.input")

local sym = symbols.load()
console:log(("title_trace: %d symbols from %s"):format(sym.count, sym.path))

-- hSCY/hWY are HRAM ($FF00 page); wTitleScreenScene is WRAM. Resolve through
-- the symbol file so a pret relayout cannot silently retarget the trace.
local wTitleScreenScene = sym:addr("wTitleScreenScene")
local rSCY = 0xFF42
local rWY  = 0xFF4A

local OUT = os.getenv("TITLE_TRACE_OUT") or "/tmp/title_trace.csv"
local FRAMES = tonumber(os.getenv("TITLE_TRACE_FRAMES") or "700")

local rows = {}
local scy_now = -1

scenario.run(function()
	-- Phase 1 — skip the boot movie to reach the title.
	--
	-- The ROM plays the copyright screen, the Game Freak splash and the whole
	-- Yellow intro before DisplayTitleScreen runs; 700 uninterrupted frames do
	-- not get anywhere near it (measured: hSCY never leaves 0). START skips the
	-- intro, so tap until the title announces itself.
	--
	-- The detector is hSCY == 64: DisplayTitleScreen sets it at the top and it
	-- stays there until the bounce table starts walking it down. Tapping is safe
	-- right up to that point because the bounce does not read the joypad at all
	-- — .titleScreenLoop is ~68 frames later, long after the last tap.
	local armed = false
	for i = 1, 2000 do
		scenario.exec(function()
			scy_now = emu:read8(rSCY)
		end)
		if scy_now == 64 then
			armed = true
			break
		end
		if i % 20 == 0 then
			input.tap("START")
		end
	end
	assert(armed, "title_trace: never reached the title (hSCY never became 64)")

	-- Phase 2 — record with no input whatsoever, so the sequence is a pure
	-- function of the title's own state machine.
	for _ = 1, FRAMES do
		scenario.exec(function()
			-- wTitleScreenScene+4 is the .loop marker: pret's idle loop writes
			-- $0F there as its first act, so the transition pins idle-loop entry
			-- exactly. hSCY and hWY have both settled several routines earlier
			-- and cannot distinguish .loop from the PCM/music sequence before
			-- it — aligning the blink onset on hWY instead is off by that gap.
			rows[#rows + 1] = string.format("%d,%d,%d,%d,%d",
				scenario.frame(),
				emu:read8(rSCY),
				emu:read8(rWY),
				emu:read8(wTitleScreenScene),
				emu:read8(wTitleScreenScene + 4))
		end)
	end

	scenario.exec(function()
		local fh = assert(io.open(OUT, "w"))
		fh:write("frame,scy,wy,scene,marker\n")
		fh:write(table.concat(rows, "\n"))
		fh:write("\n")
		fh:close()
		console:log(("title_trace: wrote %d rows to %s"):format(#rows, OUT))
	end)
end)
