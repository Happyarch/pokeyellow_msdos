---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- safari_game_over — golden for Safari Zone game over sequence:
-- exercises SafariZoneCheckSteps -> SafariZoneGameOver -> PrintSafariGameOverText.
--
-- Seeding: player in Safari Zone (SAFARI_ZONE_CENTER), EVENT_IN_SAFARI_ZONE set,
-- wSafariSteps = 1, wNumSafariBalls = 30.
-- Walking 1 step decrements wSafariSteps to 0, which triggers SafariZoneCheckSteps
-- to branch to SafariZoneGameOver, playing SFX_SAFARI_ZONE_PA and displaying
-- TimesUpText ("PA: Ding-dong!\nTime's up!") and GameOverText ("PA: Your SAFARI\nGAME is over!").
-- The dump captures the game-over dialog on screen and the updated game state
-- (EVENT_SAFARI_GAME_OVER set, wSafariZoneGameOver = 1, warp to SAFARI_ZONE_GATE armed).

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local gbtext = require("lib.gbtext")
local input = require("lib.input")
local dump = require("lib.dump")
local scenario = require("lib.scenario")
local seed = require("lib.seed")
local navigate = require("lib.navigate")

local sym = symbols.load()
local text = gbtext.load()
navigate.init(sym, text)

local SAFARI_ZONE_CENTER = 0xDC -- constants/map_constants.asm: map_const SAFARI_ZONE_CENTER ... ; $DC
-- WAS 157 (= $9D = FUCHSIA_GYM) until 2026-08-21. Never run, so never observed.

scenario.run(function()
	navigate.boot_to_main_menu()
	navigate.new_game_to_bedroom()

	scenario.exec(function()
		seed.player(sym, text:encode(seed.PLAYER_NAME))
		-- Seed Safari Zone state
		emu:write8(sym.wCurMap, SAFARI_ZONE_CENTER)
		emu:write8(sym.wNumSafariBalls, 30)
		emu:write16LE(sym.wSafariSteps, 0x0001) -- big-endian on GB: hi=0, lo=1 (1 step left)
	end)

	-- Step to decrement steps to 0 and trigger SafariZoneGameOver
	input.tap("DOWN", 1, 16)

	-- Advance through the PA announcement text
	local pa_text = text:encode("Time's up!")
	navigate.dialog_until_text(pa_text)
	scenario.wait(30)

	scenario.exec(function()
		dump.write("safari_game_over", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "Safari Zone step countdown reached 0; TimesUpText displayed and game over armed",
		})
	end)
end)
