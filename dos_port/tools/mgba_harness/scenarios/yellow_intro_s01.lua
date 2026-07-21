---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- yellow_intro_s01 — menu-intro B4. Golden for the Yellow intro's SCENE 1, the
-- first "wait last" hold (after scene 0 spawns the running-Pikachu object).
--
-- The intro plays uninterrupted from the boot (copyright -> Game Freak splash ->
-- PlayIntroScene); no input is pressed (START would skip to the title). Scene 0
-- sets up the object + timer and immediately advances, so wYellowIntroCurrentScene
-- becoming 1 is the first stable held scene. Its BG tilemap + VRAM are static
-- through the hold (only the animated OBJ moves), so they are the deterministic
-- per-scene golden content; the OBJ OAM is masked (its animation phase is verified
-- separately) — see golden_diff.SCENARIOS["yellow_intro_s01"].
--
-- Run (from repo root):
--   dos_port/tools/mgba_harness/make_goldens.sh yellow_intro_s01

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local scenario = require("lib.scenario")
local dump = require("lib.dump")

local sym = symbols.load()
console:log(("yellow_intro_s01: %d symbols from %s"):format(sym.count, sym.path))

local wYellowIntroCurrentScene = sym:addr("wYellowIntroCurrentScene")
local cur = -1

scenario.run(function()
	-- Play the whole boot to the Yellow intro; never press START (it skips).
	local reached = false
	for _ = 1, 3000 do
		scenario.exec(function() cur = emu:read8(wYellowIntroCurrentScene) end)
		if cur == 1 then reached = true break end
	end
	assert(reached, "yellow_intro_s01: never reached Yellow-intro scene 1")

	-- A few frames into the hold: tilemap/VRAM are static here, so the exact frame
	-- does not matter for the compared (OAM-masked) content.
	scenario.wait(3)

	scenario.exec(function()
		dump.write("yellow_intro_s01", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "Yellow intro scene 1 (first wait-hold): intro BG tilemap + "
				.. "graphics loaded, running-Pikachu object spawned; OBJ OAM masked",
		})
	end)
end)
