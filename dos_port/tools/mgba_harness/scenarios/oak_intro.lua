---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- oak_intro — menu-intro A4 checkpoint golden: Prof. Oak's opening speech, parked at
-- the page-1 <PARA> wait. Reached through the REAL boot->title->menu->NEW GAME route:
-- StartNewGame clears BIT_DEBUG_MODE and calls OakSpeech, which shows Prof. Oak's pic,
-- fades it in, and types _OakSpeechText1 page 1 ("Hello there! / Welcome to the / world
-- of POKeMON!") to its first `para`, where IntroTextWait parks on the ▼ key-wait.
--
-- This proves OakSpeech / PrepareOakSpeech / FadeInIntroPic / DisplayPicCenteredOrUpperRight
-- run for real and land the exact page-1 cinematic state. The port reaches the same state
-- via its DEBUG_OAKINTRO shim (RunOakSpeechCheckpoint: clear BIT_DEBUG_MODE -> real
-- OakSpeech -> park), which SKIP_TITLEs the route it does not need for a STATE golden.
--
-- The name is not chosen yet at this checkpoint (naming happens after page 1), so
-- wPlayerName/wRivalName hold PrepareOakSpeech's placeholder defaults on both sides;
-- pre-game WRAM that differs by construction is skipped/masked in golden_diff.py, measured
-- from the first diff. Cinematic surface: GB 20x18 centred on the canvas at tile (10,3),
-- same projection as gamefreak_intro / yellow_intro_s01.
--
-- Run: dos_port/tools/mgba_harness/make_goldens.sh oak_intro

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local gbtext = require("lib.gbtext")
local dump = require("lib.dump")
local scenario = require("lib.scenario")
local navigate = require("lib.navigate")

local sym = symbols.load()
local text = gbtext.load()
navigate.init(sym, text)

scenario.run(function()
	navigate.boot_to_main_menu()
	navigate.choose(text:encode("NEW GAME"))
	-- OakSpeech runs automatically and types the first two lines ("Hello there!" /
	-- "Welcome to the") into the box, then parks on the ▼ key-wait BEFORE the `cont`
	-- scroll that would bring in line 3 ("world of POKeMON!"). We tap nothing, so it
	-- holds there — the same state the port's AUTOKEY_QUIET checkpoint parks at (it
	-- also never presses a key). Wait for the visible second line, then settle.
	navigate.wait_for_text(text:encode("Welcome to the"))
	scenario.wait(45) -- settle: both lines typed, parked at the ▼ key-wait

	scenario.exec(function()
		dump.write("oak_intro", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "Prof. Oak opening speech, page 1 parked at the <PARA> wait: "
				.. "Oak pic + box + 'Hello there! Welcome to the world of POKeMON!'",
		})
	end)
end)
