---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- naming_screen — golden for the port's DEBUG_NAMINGSCREEN harness (fidelity
-- plan Stage 3): the PLAYER naming screen ("YOUR NAME?" + the uppercase letter
-- grid + underscores + "lower case" footer), cursor parked on 'A'.
--
-- The port gate (RunNamingScreenTest, engine/menus/naming_screen.asm) seeds
-- NAME_PLAYER_SCREEN and draws the grid via the real PrintNamingText /
-- PrintAlphabet / PrintNicknameAndUnderscores, mirroring DisplayNamingScreen's
-- own init (incl. its ClearScreen and tile loaders). This golden reaches the
-- same screen through the real flow: NEW GAME → Oak speech → the preset-name
-- list → NEW NAME. The name is not chosen yet at the dump, so wPlayerName /
-- wPlayerID are poked to the shared spec right before dumping — the port gate
-- seeds the same bytes (SeedDeterministicPlayerIdentity).
--
-- No walk to Pallet here: the real naming screen exists only inside the intro,
-- before the overworld. Undisplayed VRAM leftovers therefore differ by
-- construction (golden: Oak-speech remnants; port: the boot overworld tileset)
-- — masked per slot in golden_diff.py, measured from the first diff.
--
-- Port side draws W_TILEMAP as a GB-shaped STRIDE-20 scratch (naming_screen.asm
-- GBSCR_W) — differ entry "stride": 20, window (0,0).

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local gbtext = require("lib.gbtext")
local dump = require("lib.dump")
local scenario = require("lib.scenario")
local seed = require("lib.seed")
local navigate = require("lib.navigate")

local sym = symbols.load()
local text = gbtext.load()
navigate.init(sym, text)

scenario.run(function()
	navigate.boot_to_main_menu()
	navigate.choose(text:encode("NEW GAME"))
	navigate.dialog_until_text(text:encode("NEW NAME")) -- player preset list
	navigate.choose(text:encode("NEW NAME"))
	navigate.wait_for_text(text:encode("YOUR NAME?"))
	scenario.wait(30) -- settle: grid drawn, cursor parked on 'A'

	scenario.exec(function()
		seed.player(sym, text:encode(seed.PLAYER_NAME))
		dump.write("naming_screen", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "PLAYER naming screen: YOUR NAME?, uppercase grid, cursor on A",
		})
	end)
end)
