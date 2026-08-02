---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- surf_round_trip — golden for the port's DEBUG_SURF gate (items plan Stage 11,
-- differ class "datastruct": WRAM game data only, no video compare).
--
-- Covers ItemUseSurfboard in BOTH directions through the real overworld loop, with
-- live collision on both sides. Nothing else in the suite reaches it, and it is also
-- the suite's first coverage of CollisionCheckOnWater and the surf state machine.
--
-- THE TILE MAP, measured off pret data (maps/PalletTown.blk + gfx/blocksets/
-- overworld.bst, OVERWORLD tileset) rather than eyeballed:
--   (14,5) = $33  land, in Overworld_Coll   <- spawn, facing the water
--   (15,5) = $14  water                     <- mount target
--   (15,4) = $32  SHORE, in ShoreTiles      <- surf onto it, still surfing
--   (15,3) = $2C  land, in Overworld_Coll   <- what makes the dismount legal
--
-- The shore tile is the whole trick. CollisionCheckOnWater auto-dismounts the moment
-- the player moves toward passable LAND, so the only way to be surfing while adjacent
-- to land is to stand on a shore tile — IsNextTileShoreOrWater keeps the surf state on
-- the way in. And ItemUseSurfboard reads wTileInFrontOfPlayer STALE (it never
-- recomputes it), so after the step onto (15,4) that byte still holds the shore tile
-- $32, which IsTilePassable rejects. The A press before the second bag visit runs the
-- interaction check, refreshing it to (15,3) = $2C. Without that press the dismount
-- takes the "no place to get off" branch instead.
--
-- WHERE IT STOPS, and why that is deliberate: the dump happens with the bag STILL
-- OPEN, right after the dismounting USE (which prints nothing). It arms a simulated
-- LEFT step and
-- sets wJoyIgnore = $FF; the port has no JoypadOverworld yet, so nothing clears that
-- byte, and with the menus closed the port does NOT consume the step — measured stuck
-- at (15,4) with wSimulatedJoypadStatesIndex = 1 at frames 1180 / 1440 / 1800. What
-- the real game does after the menus close was NOT measured, so this scenario does not
-- assert it either way; the simulated-input consumer is overworld-events' to own.
-- Stopping with the bag open keeps the compared bytes to exactly what
-- ItemUseSurfboard wrote (both sides have the step armed and unconsumed here).
-- The MOUNT's simulated step IS consumed on both sides, and IS compared.

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
local SURFBOARD = 0x07   -- the gate's SURF_ITEM_ID default; its NAME is "?????"
local PALLET_WIDTH = 10  -- blocks; constants/map_constants.asm

-- Mirrors the %ifdef DEBUG_SURF gbregion rows in dos_port/src/debug/debug_dump.asm.
-- The differ joins by NAME and cross-checks each address, so the two lists must
-- agree. Scenario-local on purpose: adding them to dump.wram_regions would change
-- every committed golden's .bin layout.
local function regions()
	local r = dump.standard_regions(sym)
	for _, x in ipairs({
		{ name = "wPlayerMapPos", addr = sym:addr("wCurMap"), size = 5 },
		{ name = "wWalkBikeSurf", addr = sym:addr("wWalkBikeSurfState"), size = 1 },
		{ name = "wWalkBikeSurfCopy", addr = sym:addr("wWalkBikeSurfStateCopy"), size = 1 },
		{ name = "wStatusFlags5to7", addr = sym:addr("wStatusFlags5"), size = 4 },
		{ name = "wTileInFront", addr = sym:addr("wTileInFrontOfPlayer"), size = 1 },
		{ name = "wPlayerDir", addr = sym:addr("wPlayerDirection"), size = 1 },
		{ name = "wSimJoypad", addr = sym:addr("wSimulatedJoypadStatesIndex"), size = 2 },
		{ name = "wSimJoypadEnd", addr = sym:addr("wSimulatedJoypadStatesEnd"), size = 1 },
		{ name = "wJoyIgnore", addr = sym:addr("wJoyIgnore"), size = 1 },
		{ name = "wPikachuSurf", addr = sym:addr("wPikachuOverworldStateFlags"), size = 2 },
	}) do
		r[#r + 1] = x
	end
	return r
end

scenario.run(function()
	navigate.boot_to_main_menu()
	navigate.new_game_to_bedroom()

	-- bedroom (2F) -> 1F -> Pallet Town (route notes in start_menu.lua / sight.lua)
	navigate.walk("RIGHT", 1)
	navigate.walk("UP", 5)
	navigate.walk_until_map("RIGHT", REDS_HOUSE_1F)
	navigate.walk("DOWN", 6)
	navigate.walk("LEFT", 4)
	navigate.walk_until_map("DOWN", PALLET_TOWN)
	navigate.walk("DOWN", 1)
	scenario.wait(60) -- let the arrival's EnterMap finish before seeding coords

	scenario.exec(function()
		seed.debug_new_game(sym, text:encode(seed.PLAYER_NAME))
		emu:write8(sym:addr("wBagItems"), SURFBOARD)
		emu:write8(sym:addr("wBagItems") + 1, 1)
		-- Move to the shore tile with the game's own SCRIPT WARP — the mechanism
		-- lib/sight.lua uses — re-entering PALLET_TOWN rather than teleporting inside
		-- it. A same-map coordinate poke was tried first and does NOT work: nothing
		-- redraws wSurroundingTiles/wTileMap for hand-set coords, so
		-- GetTileAndCoordsInFrontOfPlayer kept reading the OLD view and the bump below
		-- reported a flower tile instead of water. Re-entering the map runs the real
		-- load path over the seeded coords.
		--   wDestinationWarpID = $FF   "not a warp arrival", so LoadTilesetHeader's
		--                              tail skips LoadDestinationWarpPosition and the
		--                              hand-set coords survive the load
		--   wStatusFlags3 BIT_WARP_FROM_CUR_SCRIPT -> OverworldLoopLessDelay -> WarpFound2
		-- The view pointer is still computed by hand (pret's macros/coords.asm
		-- event_displacement formula) because the load path does not derive it, and it
		-- is self-checking: a wrong value puts the wrong tile in front of the player
		-- and trips the assert below instead of producing a quietly wrong golden.
		local view = sym:addr("wOverworldMap") + 7 + PALLET_WIDTH
			+ (PALLET_WIDTH + 6) * (14 >> 1) + (5 >> 1)
		local ptr = sym:addr("wCurrentTileBlockMapViewPointer")
		emu:write8(ptr, view & 0xFF)
		emu:write8(ptr + 1, (view >> 8) & 0xFF)
		emu:write8(sym:addr("wYCoord"), 14)
		emu:write8(sym:addr("wXCoord"), 5)
		emu:write8(sym:addr("wDestinationWarpID"), 0xFF)
		emu:write8(sym:addr("hWarpDestinationMap"), PALLET_TOWN)
		local flags = sym:addr("wStatusFlags3")
		emu:write8(flags, emu:read8(flags) | (1 << 3)) -- BIT_WARP_FROM_CUR_SCRIPT
	end)
	do
		local deadline = scenario.frame() + 900
		while true do
			local y, x = navigate.coords()
			if y == 14 and x == 5 then break end
			assert(scenario.frame() < deadline,
				"surf_round_trip: the script warp never landed the player on (14,5)")
			scenario.wait(2)
		end
	end
	scenario.wait(30)

	-- Bump south into the water. Blocked, but the collision check populates
	-- wTileInFrontOfPlayer, which is what ItemUseSurfboard reads.
	-- Retried, not tapped once: wJoyIgnore is $FF for the whole of EnterMap and is
	-- cleared only on its last line, so a single tap after the warp is swallowed
	-- (measured — the first cut asserted here with a flower tile in front).
	do
		local deadline = scenario.frame() + 900
		while navigate.read8("wTileInFrontOfPlayer") ~= 0x14 do
			assert(scenario.frame() < deadline,
				("surf_round_trip: the bump never left water in front of the player " ..
				 "(tile $%02X, coords %d,%d)"):format(
					navigate.read8("wTileInFrontOfPlayer"), navigate.coords()))
			input.tap("DOWN", 10, 30)
		end
		local y, x = navigate.coords()
		assert(y == 14 and x == 5,
			("surf_round_trip: the bump MOVED the player to (%d,%d) — (15,5) should be " ..
			 "impassable water on land"):format(y, x))
	end
	scenario.wait(30)

	-- START -> ITEM -> SURFBOARD -> USE = MOUNT
	navigate.open_start_menu()
	navigate.choose(text:encode("ITEM"))
	navigate.wait_for_text(text:encode("?????")) -- SURFBOARD's name really is "?????"
	scenario.wait(30)
	navigate.choose(text:encode("?????"))
	navigate.ensure_text("A", text:encode("USE"))
	scenario.wait(30)
	navigate.choose(text:encode("USE"))
	navigate.dialog_until_text(text:encode("got on"))   -- "<PLAYER> got on / ?????!"
	navigate.dismiss_text(text:encode("got on"))
	-- Close the bag and the START menu so the overworld loop runs and consumes the
	-- simulated DOWN step .makePlayerMoveForward armed.
	input.tap("B", 10, 50)
	input.tap("B", 10, 50)
	local deadline = scenario.frame() + 900
	while true do
		local y, x = navigate.coords()
		if y == 15 and x == 5 and navigate.read8("wWalkBikeSurfState") == 2 then break end
		assert(scenario.frame() < deadline,
			"surf_round_trip: the mount's simulated step never put the player on the water")
		scenario.wait(2)
	end
	scenario.log("surf_round_trip: mounted, on the water at (15,5)")

	-- ONE surf step LEFT onto the shore tile; the surf state must survive it.
	-- Deliberately NOT navigate.walk("LEFT", 1): walk() holds the key until the
	-- coordinate changes, and the coordinate changes at the START of a step, so it
	-- latches a second one — measured, it overshot to (15,3), which is plain land and
	-- auto-dismounted the player. A fixed short press is one step (the port gate uses
	-- the same 12-frame hold).
	input.press_for("LEFT", 12)
	scenario.wait(60)
	do
		local y, x = navigate.coords()
		assert(y == 15 and x == 4, "surf_round_trip: the surf step did not land on (15,4)")
		assert(navigate.read8("wWalkBikeSurfState") == 2,
			"surf_round_trip: moving onto the shore tile dismounted the player")
	end

	-- Refresh wTileInFrontOfPlayer to the land tile (15,3) — see the header.
	input.tap("A", 10, 40)
	scenario.wait(30)
	assert(navigate.read8("wTileInFrontOfPlayer") == 0x2C,
		"surf_round_trip: the A press did not refresh the tile in front to (15,3)")

	-- START -> ITEM -> SURFBOARD -> USE = DISMOUNT. No DOWNs: the START menu reopens
	-- on the remembered ITEM cursor.
	navigate.open_start_menu()
	navigate.choose(text:encode("ITEM"))
	navigate.wait_for_text(text:encode("?????"))
	scenario.wait(30)
	navigate.choose(text:encode("?????"))
	navigate.ensure_text("A", text:encode("USE"))
	scenario.wait(30)
	navigate.choose(text:encode("USE"))
	-- NO MESSAGE HERE. ItemUseSurfboard's .stopSurfing prints nothing — it writes the
	-- state, arms the forward step and tail-jumps to LoadWalkingPlayerSpriteGraphics.
	-- (The only dismount text, SurfingNoPlaceToGetOffText, is the FAILURE branch.)
	-- So wait on the state byte, not on a dialog.
	do
		local deadline = scenario.frame() + 900
		while navigate.read8("wWalkBikeSurfState") ~= 0 do
			assert(scenario.frame() < deadline,
				"surf_round_trip: the second USE did not dismount — is wTileInFrontOfPlayer " ..
				"still the shore tile? (that takes the no-place-to-get-off branch)")
			scenario.wait(2)
		end
	end
	scenario.wait(60) -- settle, bag still open (see the header)

	scenario.exec(function()
		dump.write("surf_round_trip", regions(), {
			frame = scenario.frame(),
			description = "SURFBOARD mount at Pallet (14,5) -> simulated step onto the " ..
				"water (15,5) -> one surf step onto the shore tile (15,4) -> SURFBOARD " ..
				"dismount; dumped with the bag still open, before the dismount's " ..
				"simulated step is consumed",
		})
	end)
end)
