---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- trainer_card — golden for the port's DEBUG_TRAINERCARD harness (fidelity plan
-- Stage 3): the full TRAINER CARD (name / money / play time / badge grid),
-- parked in its WaitForTextScrollButtonPress.
--
-- The port gate (RunTrainerCardTest, engine/menus/trainer_card.asm) seeds the
-- shared identity spec ("RED"/id 0) plus money BCD 123456, play time 5:30 and
-- badges $A5, then draws the card directly. This golden pokes the SAME seeds
-- (seed.trainer_card) into a real new game and reaches the card through the
-- real START → <name row> flow, so wPlayerMoney pins the BCD bytes and the
-- rendered digits/badge grid pin the drawing.
--
-- The walk to Pallet (8,8) matches the port's boot spawn (vChars2 tileset —
-- see options_menu.lua). Port side draws W_TILEMAP as a GB-shaped STRIDE-20
-- scratch (trainer_card.asm TCSCR_W) — differ entry "stride": 20, window (0,0).

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

scenario.run(function()
	navigate.boot_to_main_menu()
	navigate.new_game_to_bedroom()

	-- bedroom (2F) → 1F → Pallet Town → the (8,8) port boot spawn
	-- (route notes in start_menu.lua)
	navigate.walk("RIGHT", 1)
	navigate.walk("UP", 5)
	navigate.walk_until_map("RIGHT", REDS_HOUSE_1F)
	navigate.walk("DOWN", 6)
	navigate.walk("LEFT", 4)
	navigate.walk_until_map("DOWN", PALLET_TOWN)
	local y, x = navigate.coords()
	if x ~= 8 then
		navigate.walk(x < 8 and "RIGHT" or "LEFT", math.abs(8 - x))
	end
	y = navigate.coords()
	if y ~= 8 then
		navigate.walk(y < 8 and "DOWN" or "UP", math.abs(8 - y))
	end
	input.tap("DOWN", 1, 12) -- 1-frame press: turn in place, no step
	y, x = navigate.coords()
	assert(y == 8 and x == 8, "trainer_card: did not reach the (8,8) spawn tile")

	scenario.exec(function()
		seed.player(sym, text:encode(seed.PLAYER_NAME))
		seed.trainer_card(sym)
	end)

	navigate.open_start_menu()
	-- the player-name row opens the trainer card (StartMenu_TrainerInfo)
	navigate.choose(text:encode(seed.PLAYER_NAME))
	navigate.wait_for_text(text:encode("BADGES"))
	scenario.wait(30) -- settle: card fully drawn, parked in the button wait

	scenario.exec(function()
		dump.write("trainer_card", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "TRAINER CARD: RED, $123456, 5:30, badges $A5",
		})
	end)
end)
