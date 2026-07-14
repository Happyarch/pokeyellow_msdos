---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- sign_pallet — golden for the port's DEBUG_SIGNTEXT gate (fidelity plan Stage 1b):
-- the Pallet Town town sign, read from the tile beside it, with its last page printed
-- and the box waiting for A.
--
-- The sign is `bg_event 7, 9, TEXT_PALLETTOWN_SIGN` (data/maps/objects/PalletTown.asm),
-- i.e. the tile in front of the player must be (9,7). It is read from (Y=9, X=8) facing
-- LEFT — NOT from below: the tile under the sign is a flower ($03, absent from
-- Overworld_Coll), and the game will not let the player stand on it. The port's gate
-- seeds these same coords (SIGNTEXT_Y/X/DIR, engine/overworld/overworld.asm); its
-- earlier (10,7)-facing-UP default was a tile no player can reach, which only worked
-- because seeding coords bypasses collision.
--
-- _PalletTownSignText is THREE lines: "PALLET TOWN" / line "Shades of your" /
-- cont "journey await!". The `cont` is a page break: the first page shows lines 1-2
-- and waits, and the second page — the one the port dumps — shows lines 2-3. So the
-- golden must answer that prompt with a second A before it is in the port's state.
--
-- Player identity is seeded to the shared "RED" spec; no party is seeded, matching
-- the gate (DEBUG_SIGNTEXT boots the map, it does not run PrepareNewGameDebug).

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

local REDS_HOUSE_1F = 37 -- pret constants/map_constants.asm
local PALLET_TOWN = 0

local SIGN_Y, SIGN_X = 9, 8 -- the reading tile: one RIGHT of `bg_event 7, 9`

scenario.run(function()
	navigate.boot_to_main_menu()
	navigate.new_game_to_bedroom()

	-- bedroom (2F) → 1F → Pallet Town (route notes in start_menu.lua)
	navigate.walk("RIGHT", 1)
	navigate.walk("UP", 5)
	navigate.walk_until_map("RIGHT", REDS_HOUSE_1F)
	navigate.walk("DOWN", 6)
	navigate.walk("LEFT", 4)
	navigate.walk_until_map("DOWN", PALLET_TOWN)

	local y, x = navigate.coords()
	if x ~= SIGN_X then
		navigate.walk(x < SIGN_X and "RIGHT" or "LEFT", math.abs(SIGN_X - x))
	end
	y = navigate.coords()
	if y ~= SIGN_Y then
		navigate.walk(y < SIGN_Y and "DOWN" or "UP", math.abs(SIGN_Y - y))
	end
	input.tap("LEFT", 1, 12) -- 1-frame press: turn to face the sign, no step
	y, x = navigate.coords()
	scenario.log(("sign_pallet: standing at (%d,%d)"):format(y, x))
	assert(y == SIGN_Y and x == SIGN_X, "sign_pallet: did not reach the sign-reading tile")

	scenario.exec(function()
		seed.player(sym, text:encode(seed.PLAYER_NAME))
	end)

	-- Read it. dialog_until_text taps A only on the ▼ prompt, so this opens the box
	-- and answers the `cont` page break, landing on the port's page.
	--
	-- Do NOT wait for a ▼ afterwards: the stream ends in `done`, and the GB draws no
	-- arrow there. WaitForTextScrollButtonPress (home/joypad2.asm) only *blinks* an
	-- arrow the text engine already placed — its HandleDownArrowBlinkTiming off-branch
	-- returns immediately while hDownArrowBlinkCount1 is 0, which is exactly what the
	-- function seeds. So the box just sits there waiting for A, with no arrow. (Measured:
	-- 1800 frames, no ▼ anywhere in wTileMap.)
	local page2 = text:encode("journey await!")
	input.tap("A", 2, 8)
	navigate.dialog_until_text(page2)
	scenario.wait(30) -- settle: the box is now parked in WaitForTextScrollButtonPress
	assert(navigate.tilemap():find(page2, 1, true), "sign_pallet: sign text page 2 vanished")

	scenario.exec(function()
		dump.write("sign_pallet", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "Pallet Town sign read from (9,8) facing LEFT; page 2 of " ..
				"_PalletTownSignText printed, box waiting for A (no ▼ after `done`)",
		})
	end)
end)
