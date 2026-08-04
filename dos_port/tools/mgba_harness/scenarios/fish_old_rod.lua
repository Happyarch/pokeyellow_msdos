---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- fish_old_rod — golden for the port's DEBUG_FISH gate (differ class "datastruct":
-- WRAM game data only, no video compare).
--
-- Covers the fishing-rod item family's two DETERMINISTIC branches through the
-- real bag UI on the Pallet Town shore (same measured tile map as
-- surf_round_trip: spawn (14,5) = $33 land facing the water tile (15,5) = $14):
--   1. FishingInit FAILURE — using the rod with a non-water wTileInFrontOfPlayer
--      takes `jp c, ItemUseNotTime` ("OAK: <PLAYER>! This isn't the time...").
--      Deterministic because the byte is SEEDED to 0 first (see below).
--   2. OLD ROD bite — ItemUseOldRod has NO RNG: always bite, MAGIKARP level 5.
--      Covers FishingInit success, RodResponse's encounter write
--      (wRodResponse=1, wCurEnemyLevel=5, wCurOpponent=MAGIKARP, wMoveMissed=1),
--      and FishingAnim's bite path (rod gfx via LoadAnimSpriteGfx, sprite
--      shake, the real EmotionBubble "!", ItsABiteText).
-- The RNG-gated branches — Good Rod's 50/50 + mon pick, Super Rod's 50/50 —
-- CANNOT be golden-compared: both sides run free-running GB RNG
-- (hRandomAdd/hRandomSub tick per frame, and the two sides' frame counts
-- differ), so their outcome is not cross-side deterministic. They share this
-- scenario's whole skeleton (FishingInit / RodResponse / FishingAnim); only
-- the species/bite pick differs.
--
-- THE STALE-BYTE CONTRACT (same one surf_round_trip pins): FishingInit →
-- IsNextTileShoreOrWater reads wTileInFrontOfPlayer STALE — nothing recomputes
-- it. The golden side arrives with water already in it (the walk south wrote
-- it), the port gate boots with 0 — so before the FAIL use, both sides SEED it
-- to 0 (the port's boot state). The bump before the second use then populates
-- it with the water tile through the real collision check on both sides.
--
-- WHERE IT STOPS: dumped with the bag still open, right after the bite text is
-- dismissed. wCurOpponent is armed, so closing the menus would START the wild
-- battle — battle flow is owned by the battle scenarios, and stopping here
-- keeps the compared bytes to exactly what the rod flow wrote.

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
local OLD_ROD = 0x4C     -- constants/item_constants.asm
local PALLET_WIDTH = 10  -- blocks; constants/map_constants.asm

-- Mirrors the %ifdef DEBUG_FISH gbregion rows in dos_port/src/debug/debug_dump.asm.
-- The differ joins by NAME and cross-checks each address, so the two lists must
-- agree. Scenario-local on purpose (see surf_round_trip.lua).
local function regions()
	local r = dump.standard_regions(sym)
	for _, x in ipairs({
		{ name = "wPlayerMapPos", addr = sym:addr("wCurMap"), size = 5 },
		{ name = "wRodResponse", addr = sym:addr("wRodResponse"), size = 1 },
		{ name = "wCurOpponent", addr = sym:addr("wCurOpponent"), size = 1 },
		{ name = "wCurEnemyLevel", addr = sym:addr("wCurEnemyLevel"), size = 1 },
		{ name = "wMoveMissed", addr = sym:addr("wMoveMissed"), size = 1 },
		{ name = "wWalkBikeSurf", addr = sym:addr("wWalkBikeSurfState"), size = 1 },
		{ name = "wWalkBikeSurfCopy", addr = sym:addr("wWalkBikeSurfStateCopy"), size = 1 },
		{ name = "wTileInFront", addr = sym:addr("wTileInFrontOfPlayer"), size = 1 },
		{ name = "wMovementFlags", addr = sym:addr("wMovementFlags"), size = 1 },
		{ name = "wStatusFlags5to7", addr = sym:addr("wStatusFlags5"), size = 4 },
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
		emu:write8(sym:addr("wBagItems"), OLD_ROD)
		emu:write8(sym:addr("wBagItems") + 1, 1)
		-- Script warp onto the shore tile — the sight.lua mechanism; see
		-- surf_round_trip.lua for why a plain coordinate poke does not work and
		-- for the self-checking view-pointer formula.
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
				"fish_old_rod: the script warp never landed the player on (14,5)")
			scenario.wait(2)
		end
	end
	scenario.wait(30)

	-- ===== Use 1: FishingInit FAILURE (facing the hedge, not the water) =====
	-- Turn UP: the tile above the spawn strip is Pallet's south hedge
	-- ($23/$39 — impassable AND non-water), so the tap is turn-only (or a
	-- blocked bump — either way the player stays put) and pret's START-press
	-- GetTileAndCoordsInFrontOfPlayer refresh then writes a NON-water tile.
	-- (A first cut seeded wTileInFrontOfPlayer = 0 while still facing DOWN —
	-- and the START refresh promptly overwrote it with the water tile, turning
	-- the "failure" use into a bite. The facing is the only thing the refresh
	-- respects.) The port side needs no refresh at all: its byte still holds
	-- boot-0, also non-water — outcomes match, exact bytes are compared only at
	-- the dump, where both sides hold the post-bump water tile.
	-- Retried, not tapped once: wJoyIgnore is $FF for a long tail after the
	-- warp's EnterMap and a single tap is swallowed (the same measurement
	-- surf_round_trip's bump made — a one-shot UP here left the player facing
	-- DOWN and the "failure" use bit).
	do
		local deadline = scenario.frame() + 900
		while navigate.read8("wSpritePlayerStateData1FacingDirection") ~= 0x04 do
			assert(scenario.frame() < deadline,
				"fish_old_rod: the UP tap never turned the player")
			-- 2-frame taps: a longer hold outlives the turn-delay and WALKS
			-- ((13,5) is passable — measured, a 6-frame hold moved the player)
			input.tap("UP", 2, 30)
		end
		local y, x = navigate.coords()
		assert(y == 14 and x == 5,
			("fish_old_rod: the UP turn moved the player to (%d,%d)"):format(y, x))
	end
	navigate.open_start_menu()
	navigate.choose(text:encode("ITEM"))
	navigate.wait_for_text(text:encode("OLD ROD"))
	scenario.wait(30)
	navigate.choose(text:encode("OLD ROD"))
	navigate.ensure_text("A", text:encode("USE"))
	scenario.wait(30)
	navigate.choose(text:encode("USE"))
	navigate.dialog_until_text(text:encode("time to use that"))
	navigate.dismiss_text(text:encode("time to use that"))
	assert(navigate.read8("wRodResponse") ~= 1,
		"fish_old_rod: the failure use must not have produced a bite")
	-- back in the bag; close it and the START menu
	input.tap("B", 10, 50)
	input.tap("B", 10, 50)
	scenario.wait(30)

	-- ===== Turn back DOWN, then bump into the water =====
	-- The first (turn-only) DOWN and the bump share one retry loop: taps keep
	-- coming until the collision check has actually run against the water tile.
	do
		local deadline = scenario.frame() + 900
		while navigate.read8("wTileInFrontOfPlayer") ~= 0x14 do
			assert(scenario.frame() < deadline,
				("fish_old_rod: the bump never left water in front of the player " ..
				 "(tile $%02X)"):format(navigate.read8("wTileInFrontOfPlayer")))
			input.tap("DOWN", 10, 30)
		end
		local y, x = navigate.coords()
		assert(y == 14 and x == 5,
			("fish_old_rod: the bump MOVED the player to (%d,%d)"):format(y, x))
	end
	scenario.wait(30)

	-- ===== Use 2: OLD ROD bite (deterministic — no RNG in ItemUseOldRod) =====
	navigate.open_start_menu()
	navigate.choose(text:encode("ITEM")) -- cursor remembered on ITEM
	navigate.wait_for_text(text:encode("OLD ROD"))
	scenario.wait(30)
	navigate.choose(text:encode("OLD ROD"))
	navigate.ensure_text("A", text:encode("USE"))
	scenario.wait(30)
	navigate.choose(text:encode("USE"))
	-- FishingInit prints "RED used OLD ROD!" (no prompt), delays 80 frames; the
	-- rod handler + FishingAnim then run (10f + rod gfx + 100f wait + shake +
	-- the real "!" EmotionBubble) before ItsABiteText prompts.
	navigate.dialog_until_text(text:encode("a bite!"))
	navigate.dismiss_text(text:encode("a bite!"))
	-- back in the bag. STOP HERE — wCurOpponent is armed; closing the menus
	-- would start the wild MAGIKARP battle (owned by the battle scenarios).
	do
		local deadline = scenario.frame() + 600
		while navigate.read8("wRodResponse") ~= 1 do
			assert(scenario.frame() < deadline,
				"fish_old_rod: wRodResponse never reached 1 (bite)")
			scenario.wait(2)
		end
	end
	scenario.wait(60) -- settle, bag still open

	scenario.exec(function()
		dump.write("fish_old_rod", regions(), {
			frame = scenario.frame(),
			description = "OLD ROD on the Pallet shore: one FishingInit failure " ..
				"(seeded non-water front tile -> ItemUseNotTime), then the " ..
				"deterministic bite (wRodResponse=1, MAGIKARP lv5 armed in " ..
				"wCurOpponent/wCurEnemyLevel); dumped with the bag still open",
		})
	end)
end)
