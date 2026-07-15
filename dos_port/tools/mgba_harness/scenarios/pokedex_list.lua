---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- pokedex_list — golden for the port's DEBUG_G1 harness (fidelity plan Stage 3):
-- the pokédex CONTENTS list with the ▶ cursor on 001, SEEN 11 / OWN 4, the side
-- menu (DATA/CRY/AREA/PRNT/QUIT) drawn, and mon 004 as the unseen "----------"
-- row.
--
-- The port gate (RunPokedexTest, engine/menus/pokedex.asm) seeds the shared
-- identity spec ("RED"/id 0) plus its exact dex bits (seen $F7/$0F, owned $55 —
-- CHARMANDER deliberately unseen so the placeholder path renders), then draws
-- the list directly. This golden pokes the SAME bits (seed.pokedex_list) into a
-- real new game — plus EVENT_GOT_POKEDEX, pure navigation enablement (the START
-- menu hides POKéDEX without it; wEventFlags is not a compared region) — and
-- reaches the list through the real START → POKéDEX flow, so wPokedex pins the
-- bits and the rendered list pins the drawing.
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
	assert(y == 8 and x == 8, "pokedex_list: did not reach the (8,8) spawn tile")

	scenario.exec(function()
		seed.player(sym, text:encode(seed.PLAYER_NAME))
		seed.pokedex_list(sym)
		seed.set_event(sym, EVENT_GOT_POKEDEX)
	end)

	navigate.open_start_menu()
	navigate.choose(text:encode("POKéDEX"))
	navigate.wait_for_text(text:encode("CONTENTS"))
	scenario.wait(30) -- settle: list + side menu fully drawn, cursor on 001

	scenario.exec(function()
		dump.write("pokedex_list", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "pokédex CONTENTS list: SEEN 11 / OWN 4, cursor on 001, mon 004 unseen",
		})
	end)
end)
