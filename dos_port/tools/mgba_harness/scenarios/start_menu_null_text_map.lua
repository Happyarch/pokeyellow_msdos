---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- start_menu_null_text_map — golden for the port's DEBUG_STARTMENU_NULLMAP gate:
-- the START menu opened through the REAL overworld joypad path on REDS_HOUSE_2F
-- (map 0x26), whose generated MapTextTablePointers entry is NULL.
--
-- WHY THIS SCENARIO EXISTS (cf5ec020d). DisplayTextID carried a port-only
-- null-text-table bail BEFORE the `hTextID == 0 -> DisplayStartMenu` dispatch.
-- For the 34 maps with no NPC dialogs that pointer is 0, so on those maps
-- (REDS_HOUSE_2F is the first map of a new game) pressing START fell through to
-- "after displaying text" and the menu never opened. The existing start_menu
-- golden cannot witness this: it calls DisplayStartMenu directly on non-null
-- Pallet Town, so it passes with the bug present.
--
-- Here the real ROM walks a new game to the bedroom (where the text table IS
-- null), turns to face DOWN, presses START, and dumps once the menu is up. The
-- port side boots straight onto the same map (DEBUG_SPAWN) and injects one
-- START into the live loop (AUTOKEY_STARTMENU_NULLMAP); AutoKeyDrive photographs
-- at AUTOKEY_DUMP_FRAME. With the bug reintroduced the port draws no menu, so
-- the compared START-menu box diverges (or no dump is produced at all).

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

local REDS_HOUSE_2F = 38 -- pret constants/map_constants.asm
local SPRITE_FACING_DOWN = 0

scenario.run(function()
	navigate.boot_to_main_menu()
	navigate.new_game_to_bedroom()

	-- The new game drops RED in the bedroom. Assert it: the port gate seeds the
	-- same (X=3, Y=6) spawn via DEBUG_SPAWN, and a mismatch would silently compare
	-- two different screens.
	local y, x = navigate.coords()
	assert(navigate.read8("wCurMap") == REDS_HOUSE_2F,
		"start_menu_null_text_map: intro ended off REDS_HOUSE_2F")
	assert(y == 6 and x == 3,
		("start_menu_null_text_map: bedroom spawn (%d,%d), expected (6,3)"):format(y, x))
	scenario.log(("start_menu_null_text_map: in bedroom at (%d,%d)"):format(y, x))

	-- Align facing DOWN (SPRITE_FACING_DOWN = 0), the port gate's seeded facing.
	-- A short tap turns in place without completing a step; assert the position
	-- did not move while turning.
	local ty, tx = navigate.coords()
	local turn_deadline = scenario.frame() + 300
	while navigate.read8("wSpritePlayerStateData1FacingDirection") ~= SPRITE_FACING_DOWN do
		assert(scenario.frame() < turn_deadline,
			"start_menu_null_text_map: player never turned to face DOWN")
		input.tap("DOWN", 2, 8)
	end
	local ny, nx = navigate.coords()
	assert(ny == ty and nx == tx,
		("start_menu_null_text_map: turning moved the player (%d,%d) -> (%d,%d)")
			:format(ty, tx, ny, nx))

	-- Seed the shared identity ("RED" / id 0) the port's SeedDeterministicPlayerIdentity
	-- writes, so the menu's name row and wPlayerName agree.
	scenario.exec(function()
		seed.player(sym, text:encode(seed.PLAYER_NAME))
	end)

	-- The real START press. open_start_menu retries the tap and waits for EXIT
	-- (unique to the START menu) to appear, then lets the box settle.
	navigate.open_start_menu()

	scenario.exec(function()
		dump.write("start_menu_null_text_map", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "START menu opened through the real overworld joypad path on "
				.. "REDS_HOUSE_2F (0x26), whose NPC text table is null; no party/dex",
		})
	end)
end)
