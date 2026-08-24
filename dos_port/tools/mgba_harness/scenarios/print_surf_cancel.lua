---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- print_surf_cancel — golden for the Game Boy Printer capture layer & error-cancel path
-- (docs/current_plan_printer.md Stage 3).
--
-- WHAT IT PROVES:
-- Interacting with the Summer Beach House printer (SUMMER_BEACH_HOUSE, bg_event 13, 1)
-- with surfing Pikachu unlocked and choosing to print the high score:
--   1. Executes SummerBeachHousePrinterText -> Func_f23d0 -> PrintSurfingMinigameHighScore.
--   2. PrintSurfingMinigameHighScore renders the high score tilemap to wTileMap,
--      sets up transmission (wcae2 = 0x13, wPrinterSettingsTempCopy), and copies
--      the 360-byte tilemap into wPrinterTileBuffer.
--   3. In mGBA with no printer on the serial bus, the transmission loop times out
--      into PRINTER_ERROR_2 ("CHECK THE CABLE / OR PRINTER MANUAL").
--   4. Pressing B cancels the error (Printer_StopIfPressB sets hCanceledPrinting = 1),
--      restores the screen buffer, and returns to Func_f23d0, which shows "Canceled printing.".
--   5. Dismissing the dialog returns cleanly to the overworld.
--
-- Compared surfaces:
--   - wPrinterTileBuffer (360 B): the captured 20x18 tile IDs of the high score page.
--   - wcae2 (1 B): the printer margin/sheet settings byte.
--   - wPrinterSettings (1 B): the temporary copy of printer settings.
--   - Standard video regions (wTileMap, vram_tiles, oam, cgb_palettes) and WRAM game data.

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

local REDS_HOUSE_1F = 37        -- pret constants/map_constants.asm
local PALLET_TOWN = 0
local SUMMER_BEACH_HOUSE = 0xF8 -- constants/map_constants.asm ($F8)
local BEACH_HOUSE_WIDTH = 7      -- blocks; constants/map_constants.asm
local BIT_WARP_FROM_CUR_SCRIPT = 3 -- constants/ram_constants.asm
local BIT_PIKACHU_SPAWN_SURFING = 6 -- constants/pikachu_emotion_constants.asm
local WD471_PIKACHU_SPAWN_STATE_FLAGS = 0xD471
local WD492_PIKACHU_MAP_SCRIPT_FLAGS = 0xD492

local TALK_Y, TALK_X = 2, 13     -- tile in front of bg_event 13, 1 (printer)
local D_UP = 0x01                -- D-pad UP direction bit

local function regions()
	local r = dump.standard_regions(sym)
	r[#r + 1] = { name = "wPrinterTileBuffer", addr = sym:addr("wPrinterTileBuffer"), size = 360 }
	r[#r + 1] = { name = "wcae2",             addr = sym:addr("wcae2"),             size = 1 }
	r[#r + 1] = { name = "wPrinterSettings",   addr = sym:addr("wPrinterSettingsTempCopy"), size = 1 }
	return r
end

scenario.run(function()
	navigate.boot_to_main_menu()
	navigate.new_game_to_bedroom()

	-- bedroom (2F) -> 1F -> Pallet Town
	navigate.walk("RIGHT", 1)
	navigate.walk("UP", 5)
	navigate.walk_until_map("RIGHT", REDS_HOUSE_1F)
	navigate.walk("DOWN", 6)
	navigate.walk("LEFT", 4)
	navigate.walk_until_map("DOWN", PALLET_TOWN)
	navigate.walk("DOWN", 1)
	scenario.wait(60)

	scenario.exec(function()
		seed.debug_new_game(sym, text:encode(seed.PLAYER_NAME))

		-- Script-warp directly in front of the printer at (13, 2)
		local view = sym:addr("wOverworldMap") + 7 + BEACH_HOUSE_WIDTH
			+ (BEACH_HOUSE_WIDTH + 6) * (TALK_Y >> 1) + (TALK_X >> 1)
		local ptr = sym:addr("wCurrentTileBlockMapViewPointer")
		emu:write8(ptr, view & 0xFF)
		emu:write8(ptr + 1, (view >> 8) & 0xFF)
		emu:write8(sym:addr("wYCoord"), TALK_Y)
		emu:write8(sym:addr("wXCoord"), TALK_X)
		emu:write8(sym:addr("wDestinationWarpID"), 0xFF)
		emu:write8(sym:addr("hWarpDestinationMap"), SUMMER_BEACH_HOUSE)
		local status3 = sym:addr("wStatusFlags3")
		emu:write8(status3, emu:read8(status3) | (1 << BIT_WARP_FROM_CUR_SCRIPT))
	end)

	do
		local deadline = scenario.frame() + 900
		while navigate.read8("wCurMap") ~= SUMMER_BEACH_HOUSE do
			assert(scenario.frame() < deadline,
				"print_surf_cancel: the script warp to SUMMER_BEACH_HOUSE never fired")
			scenario.wait(1)
		end
		local y, x = navigate.coords()
		scenario.log(("print_surf_cancel: on map %d at (%d,%d)"):format(SUMMER_BEACH_HOUSE, y, x))
		assert(y == TALK_Y and x == TALK_X,
			"print_surf_cancel: the warp moved the player off the seeded landing tile")
	end
	scenario.wait(60)

	-- Set surfing unlock flags (Pikachu in debug party slot 4 already has SURF)
	scenario.exec(function()
		local flags = WD471_PIKACHU_SPAWN_STATE_FLAGS
		emu:write8(flags, emu:read8(flags) | (1 << BIT_PIKACHU_SPAWN_SURFING))
		local script_flags = WD492_PIKACHU_MAP_SCRIPT_FLAGS
		emu:write8(script_flags, emu:read8(script_flags) | (1 << 1)) -- BIT_PIKACHU_MAP_SURF_SELECT
	end)

	local SPRITE_FACING_UP = 4
	-- Turn to face UP towards the printer
	do
		local deadline = scenario.frame() + 600
		while navigate.read8("wSpritePlayerStateData1FacingDirection") ~= SPRITE_FACING_UP do
			assert(scenario.frame() < deadline,
				"print_surf_cancel: the player never turned to face the printer (UP)")
			input.tap("UP", 2, 8)
		end
	end
	do
		local y, x = navigate.coords()
		assert(y == TALK_Y and x == TALK_X,
			("print_surf_cancel: facing tap moved the player to (%d,%d)"):format(y, x))
	end
	scenario.wait(30)

	-- Interact with printer: opens Text 2 ("SUMMER BEACH HOUSE PRINTER, it says.")
	local text2 = text:encode("SUMMER BEACH HOUSE")
	do
		local deadline = scenario.frame() + 600
		while not navigate.tilemap():find(text2, 1, true) do
			assert(scenario.frame() < deadline, "print_surf_cancel: text 2 never appeared")
			input.tap("A", 2, 20)
		end
	end
	scenario.wait(20)
	-- Text 2 ends in text_waitbutton; tap A until text 2 clears to advance to Text 3
	do
		local deadline = scenario.frame() + 600
		while navigate.tilemap():find(text2, 1, true) do
			assert(scenario.frame() < deadline, "print_surf_cancel: text 2 never cleared")
			input.tap("A", 2, 10)
			scenario.wait(10)
		end
	end

	-- Advance through Text 3 page 1 to "PRINT it out?"
	navigate.dialog_until_text(text:encode("PRINT it out"))
	scenario.wait(30)
	-- Default cursor is YES. Tap A to confirm YES.
	input.tap("A", 2, 20)

	-- Wait for the printer screen to encounter ERROR 2 ("Printer Error 2")
	do
		local error_text = text:encode("Printer Error")
		local deadline = scenario.frame() + 1200
		while not navigate.tilemap():find(error_text, 1, true) do
			assert(scenario.frame() < deadline,
				"print_surf_cancel: printer error 2 was not reached")
			scenario.wait(10)
		end
	end
	scenario.log(("print_surf_cancel: printer error 2 reached at frame %d"):format(scenario.frame()))
	scenario.wait(30)

	-- Press B to cancel printing
	input.tap("B", 2, 20)

	-- Wait for "PRINT error!" message in SummerBeachHouse
	local err_msg = text:encode("PRINT error")
	do
		local deadline = scenario.frame() + 600
		while not navigate.tilemap():find(err_msg, 1, true) do
			assert(scenario.frame() < deadline, "print_surf_cancel: PRINT error message never appeared")
			scenario.wait(10)
		end
	end
	scenario.wait(20)
	-- Dismiss message
	do
		local deadline = scenario.frame() + 600
		while navigate.tilemap():find(err_msg, 1, true) do
			assert(scenario.frame() < deadline, "print_surf_cancel: PRINT error message never cleared")
			input.tap("A", 2, 10)
			scenario.wait(10)
		end
	end

	-- Wait for overworld to settle
	scenario.wait(60)

	do
		local y, x = navigate.coords()
		assert(y == TALK_Y and x == TALK_X,
			("print_surf_cancel: player ended at (%d,%d), expected (%d,%d)"):format(y, x, TALK_Y, TALK_X))
	end

	scenario.exec(function()
		dump.write("print_surf_cancel", regions(), {
			frame = scenario.frame(),
			description = "Summer Beach House printer high-score print cancelled: " ..
				"wPrinterTileBuffer (360 B), wcae2, wPrinterSettingsTempCopy captured",
		})
	end)
end)
