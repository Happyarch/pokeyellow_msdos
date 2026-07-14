---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- options_menu — golden for the port's DEBUG_OPTIONS harness (fidelity plan
-- Stage 3): the OPTION full-screen menu with the ▶ cursor parked on TEXT SPEED.
--
-- The port gate (RunOptionsTest, engine/menus/options.asm) opens the menu from
-- its bare SKIP_TITLE boot at the Pallet spawn: no party/bag/dex seed, identity
-- = the shared "RED"/id-0 spec, and wOptions/wPrinterSettings seeded to pret's
-- InitOptions defaults (TEXT_DELAY_MEDIUM / $40) — which are exactly what this
-- golden's real new-game boot leaves there, so wOptionsBlock is compared, not
-- seeded, on this side.
--
-- The walk to Pallet (8,8) matches the port's boot spawn so vChars2 holds the
-- same outdoor tileset under the full-screen takeover (same rationale as
-- start_menu; the options screen itself covers all 360 tilemap cells).
--
-- Port side: the OPTION screen draws W_TILEMAP as a GB-shaped STRIDE-20 scratch
-- (options.asm GBSCR_W) — the differ entry uses "stride": 20, window (0,0).

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
	assert(y == 8 and x == 8, "options_menu: did not reach the (8,8) spawn tile")

	scenario.exec(function()
		seed.player(sym, text:encode(seed.PLAYER_NAME))
	end)

	navigate.open_start_menu()
	navigate.choose(text:encode("OPTION"))
	navigate.wait_for_text(text:encode("TEXT SPEED"))
	scenario.wait(30) -- settle: screen fully drawn, cursor parked on TEXT SPEED

	scenario.exec(function()
		dump.write("options_menu", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "OPTION menu open, cursor on TEXT SPEED (InitOptions defaults)",
		})
	end)
end)
