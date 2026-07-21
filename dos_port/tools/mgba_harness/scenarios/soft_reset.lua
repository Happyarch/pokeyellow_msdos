---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- soft_reset — menu-intro B4. Prove the title-screen soft-reset combo replays the
-- boot movie. pret's DisplayTitleScreen idle loop treats UP+SELECT+B as the secret
-- reset-save combo: it takes .go_to_main_menu -> .doClearSaveDialogue -> jmp Init.
-- With the faithful-default flip, Init calls PlayIntro, so the movie REPLAYS. This
-- golden captures the replayed copyright screen (== gamefreak_intro composition, but
-- reached via the reset-combo route), proving the route end-to-end.
--
-- Navigation: tap START until the title (hSCY==64) to skip the initial intro, stop,
-- ride the bounce into the idle loop, then HOLD UP+SELECT+B so the idle read takes
-- the reset path. With the flip the movie replays; wait for the copyright, then dump.
--
-- Run: dos_port/tools/mgba_harness/make_goldens.sh soft_reset

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local scenario = require("lib.scenario")
local input = require("lib.input")
local dump = require("lib.dump")

local sym = symbols.load()
console:log(("soft_reset: %d symbols from %s"):format(sym.count, sym.path))

local wTileMap = sym:addr("wTileMap")
local COPYRIGHT_CELL = wTileMap + 7 * 20 + 2
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
	assert(reached, "soft_reset: never reached the title (hSCY never became 64)")

	-- Phase 2 — ride the bounce into the idle loop, then HOLD the reset combo. It must
	-- stay held not just for the idle read but through .go_to_main_menu's exit sequence,
	-- which RE-checks the combo (hJoyHeld) before branching to DoClearSaveDialogue — a
	-- brief hold that's released before then falls through to MainMenu instead. Hold it
	-- generously across the bounce-to-idle transition and the exit sequence.
	scenario.wait(80)
	input.press_for({ "UP", "SELECT", "B" }, 60)

	-- Phase 3 — the ROM's combo opens the "Clear all saved data? NO/YES" dialogue
	-- (DoClearSaveDialogue). EITHER choice jumps to Init, so tap A (default cursor =
	-- NO) to confirm; then the movie replays. (The PORT stubs this dialogue and jumps
	-- straight to Init — a documented Phase-5 divergence the copyright-state golden
	-- cannot capture; this scenario proves the reset REPLAY, not the dialogue.) Tap A
	-- periodically until the copyright reappears, then stop before the replay reads input.
	local replayed = false
	for i = 1, 600 do
		scenario.exec(function() tile = emu:read8(COPYRIGHT_CELL) end)
		if is_copyright_tile(tile) then replayed = true break end
		if i % 20 == 0 then input.tap("A") end   -- confirm the clear-save NO/YES box
	end
	assert(replayed, "soft_reset: the movie never replayed after the reset combo")

	scenario.wait(3)
	scenario.exec(function()
		dump.write("soft_reset", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "UP+SELECT+B -> Init -> PlayIntro replay: the copyright screen "
				.. "reappears, proving the soft-reset combo replays the boot movie",
		})
	end)
end)
