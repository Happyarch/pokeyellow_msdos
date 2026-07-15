---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- pokedex_entry — golden for the port's DEBUG_G2 harness (fidelity plan Stage 3):
-- RHYDON's pokédex DATA page (border, front pic, name/№/species, HT/WT), dumped
-- BEFORE the flavor text starts printing — the port gate dumps right after
-- DrawDexEntryOnScreen (its flavor's <PAGE> break blocks a headless run), and on
-- the golden the same state is the frames between "WT 265.0lb" appearing and the
-- first flavor letter (pret prints HT/WT after the blocking PlayCry, then starts
-- the flavor with per-letter delay — wait_for_text("265") + an immediate dump
-- lands inside that window).
--
-- The port gate (RunPokedexEntryTest, engine/menus/pokedex.asm) seeds the shared
-- identity spec plus RHYDON (dex 112) seen+owned, then calls
-- ShowPokedexDataInternal directly. This golden pokes the SAME bits
-- (seed.pokedex_entry) plus EVENT_GOT_POKEDEX (navigation enablement only) and
-- reaches the page through the real flow: START → POKéDEX → scroll the 112-row
-- list (hJoy7 key-repeat, RHYDON is the last row so holding DOWN cannot
-- overshoot) → A → side menu DATA → the entry page.
--
-- The walk to Pallet (8,8) matches the port's boot spawn (vChars2 tileset —
-- see options_menu.lua). Port side draws W_TILEMAP as a GB-shaped STRIDE-20
-- scratch (pokedex.asm GBSCR_W) — differ entry "stride": 20, window (0,0).

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
local EVENT_GOT_POKEDEX = 37 -- pret constants/event_constants.asm

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
	assert(y == 8 and x == 8, "pokedex_entry: did not reach the (8,8) spawn tile")

	scenario.exec(function()
		seed.player(sym, text:encode(seed.PLAYER_NAME))
		seed.pokedex_entry(sym)
		seed.set_event(sym, EVENT_GOT_POKEDEX)
	end)

	navigate.open_start_menu()
	navigate.choose(text:encode("POKéDEX"))
	navigate.wait_for_text(text:encode("CONTENTS"))
	scenario.wait(30) -- settle: list drawn, cursor on 001 (an unseen "-" row)

	-- scroll to the last row (112 RHYDON — the only seen mon): hold DOWN and let
	-- the dex list's hJoy7 key-repeat do the walking; the list stops at its last
	-- row, so this cannot overshoot.
	input.hold("DOWN")
	navigate.wait_for_text(text:encode("RHYDON"), 6000)
	input.release()
	scenario.wait(30) -- settle: repeat drained, cursor parked on RHYDON

	navigate.choose(text:encode("RHYDON"))
	-- side menu (DATA/CRY/AREA/QUIT) is drawn even before it activates and its
	-- cursor starts ON "DATA", so a plain choose("DATA") could mis-scroll the
	-- list if the A above was swallowed. ensure_text polls first and only
	-- re-taps A when the page has not appeared — converging from either state.
	navigate.ensure_text("A", text:encode("HT"))
	-- HT/WT print only after the blocking cry; the flavor's first letter is
	-- several frames behind them (letter delay) — dump inside that window.
	navigate.wait_for_text(text:encode("265"))

	scenario.exec(function()
		dump.write("pokedex_entry", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "pokédex DATA page: RHYDON №112, HT 6'03\" WT 265.0lb, pre-flavor",
		})
	end)
end)
