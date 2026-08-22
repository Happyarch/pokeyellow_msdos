---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- sign_pallet_house — the TEXT-ENGINE golden for the <PLAYER> name-substitution path.
--
-- WHY THIS EXISTS (docs/current_plan_text_engine_realign.md, Stage 4.2). The plan's
-- Stage 3 rewrites the label space of PlaceNextChar, and the question "what gates the
-- text engine?" was MEASURED rather than assumed. Counting control codes across all of
-- pret's text data:
--     line 3065 | cont 1791 | done 1699 | para 969 | prompt 672
--     <PLAYER> 152 | <RIVAL> 44 | <USER> 36 | <TARGET> 24 | <PKMN> 8 | <TRAINER> 1
--     <PC> <TM> <ROCKET> <……> <NULL> <PAGE> <DEXEND>  ALL ZERO
-- `line`/`cont`/`done` are already gated by sign_pallet (it dumps page 2, after a
-- `cont`), and `para` by route_15_binoculars. The gap was the print_name family:
-- oak_intro parks at _OakSpeechText1 page 1 and so never reaches _OakSpeechText3's
-- "<PLAYER>!", which is why 152 uses of the single most common substitution had no
-- golden at all.
--
-- _PalletTownPlayersHouseSignText is `text "<PLAYER>'s house " / done` — the smallest
-- real screen in the game that exercises PrintPlayerName -> PlaceCommandCharacter, and
-- it is a STATIC bg_event, so unlike the wandering GIRL/FISHER it is deterministic.
--
-- THE SIGN IS READ FROM BELOW, FACING UP. `bg_event 3, 5` is (x=3, y=5), on the front
-- wall of Red's house — the house occupies row 5, so the tile to its right (5,4) is
-- wall, not floor. The reading tile is the path tile beneath it, (y=6, x=3). This is
-- the opposite of sign_pallet, whose town sign stands in grass and CANNOT be read from
-- below (the tile under it is a flower, $03, absent from Overworld_Coll) and is read
-- from the side instead. Two signs, two different approaches — do not copy one to the
-- other.
--
-- Player identity is seeded to the shared "RED" spec BEFORE the sign is read: the whole
-- point is that the box renders the seeded name, so seeding after would prove nothing.

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

local SIGN_Y, SIGN_X = 6, 3 -- the reading tile: one BELOW `bg_event 3, 5`

scenario.run(function()
	navigate.boot_to_main_menu()
	navigate.new_game_to_bedroom()

	-- bedroom (2F) -> 1F -> Pallet Town (same route sign_pallet documents)
	navigate.walk("RIGHT", 1)
	navigate.walk("UP", 5)
	navigate.walk_until_map("RIGHT", REDS_HOUSE_1F)
	navigate.walk("DOWN", 6)
	navigate.walk("LEFT", 4)
	navigate.walk_until_map("DOWN", PALLET_TOWN)

	-- SETTLE BEFORE READING COORDS. walk_until_map returns as soon as wCurMap flips,
	-- which is BEFORE the destination coords are written: reading immediately gives
	-- Red's-house-1F coords (measured: (7,3), the interior tile) for a player who is
	-- really about to stand on the Pallet Town door warp at (5,5). Waiting first is
	-- the difference between a route that works and one that walks from a phantom
	-- position.
	scenario.wait(30)
	local y, x = navigate.coords()
	scenario.log(("sign_pallet_house: outside the house at (%d,%d)"):format(y, x))

	-- Step DOWN off the door warp before moving sideways: (5,5) IS the warp tile.
	if y < SIGN_Y then
		navigate.walk("DOWN", SIGN_Y - y)
	end
	y, x = navigate.coords()
	if x ~= SIGN_X then
		navigate.walk(x < SIGN_X and "RIGHT" or "LEFT", math.abs(SIGN_X - x))
	end
	y, x = navigate.coords()
	if y ~= SIGN_Y then
		navigate.walk(y < SIGN_Y and "DOWN" or "UP", math.abs(SIGN_Y - y))
	end

	y, x = navigate.coords()
	scenario.log(("sign_pallet_house: standing at (%d,%d)"):format(y, x))
	assert(y == SIGN_Y and x == SIGN_X,
		("sign_pallet_house: did not reach the reading tile (want %d,%d)"):format(SIGN_Y, SIGN_X))

	-- Seed identity BEFORE reading: the box must render the seeded name.
	scenario.exec(function()
		seed.player(sym, text:encode(seed.PLAYER_NAME))
	end)

	input.tap("UP", 1, 12) -- 1-frame press: turn to face the sign, no step
	y, x = navigate.coords()
	assert(y == SIGN_Y and x == SIGN_X, "sign_pallet_house: turning moved the player")

	-- Read it. The stream is one page ending in `done`, so there is no page break to
	-- answer and no arrow afterwards (same as sign_pallet's `done` tail).
	local want = text:encode(seed.PLAYER_NAME .. "'s house")
	input.tap("A", 2, 8)
	navigate.dialog_until_text(want)
	scenario.wait(30) -- settle: the box is parked in WaitForTextScrollButtonPress
	assert(navigate.tilemap():find(want, 1, true),
		"sign_pallet_house: substituted player name vanished from the box")

	scenario.exec(function()
		dump.write("sign_pallet_house", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "Pallet Town player's-house sign read from (6,3) facing UP; " ..
				"_PalletTownPlayersHouseSignText printed with <PLAYER> substituted " ..
				"(PrintPlayerName -> PlaceCommandCharacter), box waiting for A",
		})
	end)
end)
