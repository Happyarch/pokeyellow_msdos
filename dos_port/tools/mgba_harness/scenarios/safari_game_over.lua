---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- safari_game_over — golden for the Safari Zone step countdown running out:
-- SafariZoneCheckSteps -> SafariZoneGameOver -> PrintSafariGameOverText.
--
-- *** GROUND TRUTH ONLY — THIS SCENARIO IS NOT REGISTERED, AND CANNOT BE YET. ***
-- The port never runs the check. pret's home/overworld.asm has, right after
-- StepCountCheck:
--     CheckEvent EVENT_IN_SAFARI_ZONE
--     jr z, .notSafariZone
--     farcall SafariZoneCheckSteps
--     ld a, [wSafariZoneGameOver] / and a / jp nz, WarpFound2
-- and dos_port/src/home/overworld.asm goes straight from StepCountCheck to
-- NewBattle. SafariZoneCheckSteps and SafariZoneGameOver are both TRANSLATED but
-- have no caller, and the branch's target WarpFound2 is `missing` from the port
-- entirely — so wiring it is engine work on the live warp path, not a scenario fix.
-- The golden is generated and committed so the ground truth exists and
-- `make goldens` succeeds; register it once the port has the branch.
-- See regression memory: the safari step countdown is unreachable in the port.
--
-- REWRITTEN 2026-08-21. The committed draft could never have run:
--   * it used map id 157 (= $9D FUCHSIA_GYM), not $DC SAFARI_ZONE_CENTER;
--   * it wrote `sym.wCurMap` — FIELD access on the symbol table, which is nil, so
--     emu:write8(nil, ...) raised "Error calling function (invoking failed)";
--   * it set wCurMap directly with no warp, so the player was never actually on
--     the map and no map data was loaded;
--   * it called emu:write16LE for a value pret stores BIG-endian (`dw` read as
--     hi,lo by SafariZoneCheckSteps).

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

-- constants/map_constants.asm: map_const SAFARI_ZONE_CENTER, 15, 13 ; $DC
local SAFARI_ZONE_CENTER = 0xDC
local SAFARI_ZONE_CENTER_WIDTH = 15
local REDS_HOUSE_1F = 37
local PALLET_TOWN = 0
local BIT_WARP_FROM_CUR_SCRIPT = 3
local EVENT_IN_SAFARI_ZONE = 591 -- assets/event_constants.inc

-- A walkable tile on SAFARI_ZONE_CENTER with room to step south. DERIVED, not
-- guessed: decoding safari_zone_center_blk through forest_blocks and forest_coll,
-- (y=1, x=4) and the three tiles below it are all passable. An earlier revision
-- used (10,10), which is blocked — the warp landed correctly on map $DC but the
-- player never moved, so the step counter never decremented and no game over fired.
local START_Y, START_X = 1, 4

scenario.run(function()
	navigate.boot_to_main_menu()
	navigate.new_game_to_bedroom()

	-- bedroom -> 1F -> Pallet Town, then settle before arming the script warp
	-- (see lib/sight.lua's header for why the settle is load-bearing).
	navigate.walk("RIGHT", 1)
	navigate.walk("UP", 5)
	navigate.walk_until_map("RIGHT", REDS_HOUSE_1F)
	navigate.walk("DOWN", 6)
	navigate.walk("LEFT", 4)
	navigate.walk_until_map("DOWN", PALLET_TOWN)
	navigate.walk("DOWN", 1)
	scenario.wait(60)

	scenario.exec(function()
		seed.player(sym, text:encode(seed.PLAYER_NAME))
		local view = sym:addr("wOverworldMap") + 7 + SAFARI_ZONE_CENTER_WIDTH
			+ (SAFARI_ZONE_CENTER_WIDTH + 6) * (START_Y >> 1) + (START_X >> 1)
		local ptr = sym:addr("wCurrentTileBlockMapViewPointer")
		emu:write8(ptr, view & 0xFF)
		emu:write8(ptr + 1, (view >> 8) & 0xFF)
		emu:write8(sym:addr("wYCoord"), START_Y)
		emu:write8(sym:addr("wXCoord"), START_X)
		emu:write8(sym:addr("wDestinationWarpID"), 0xFF)
		emu:write8(sym:addr("hWarpDestinationMap"), SAFARI_ZONE_CENTER)
		local flags = sym:addr("wStatusFlags3")
		emu:write8(flags, emu:read8(flags) | (1 << BIT_WARP_FROM_CUR_SCRIPT))
	end)

	local deadline = scenario.frame() + 900
	while navigate.read8("wCurMap") ~= SAFARI_ZONE_CENTER do
		assert(scenario.frame() < deadline, "safari_game_over: script warp never fired")
		scenario.wait(1)
	end

	scenario.exec(function()
		-- The countdown only runs while EVENT_IN_SAFARI_ZONE is set.
		seed.set_event(sym, EVENT_IN_SAFARI_ZONE)
		emu:write8(sym:addr("wNumSafariBalls"), 30)
		-- wSafariSteps is a `dw` that SafariZoneCheckSteps reads BIG-endian
		-- (hi = [wSafariSteps], lo = [wSafariSteps+1]). One step remaining.
		emu:write8(sym:addr("wSafariSteps"), 0x00)
		emu:write8(sym:addr("wSafariSteps") + 1, 0x01)
		emu:write8(sym:addr("wSafariZoneGameOver"), 0)
	end)
	scenario.wait(10)

	-- One completed step decrements the counter to 0; the NEXT step check sees
	-- zero and falls into SafariZoneGameOver. navigate.walk, not input.tap: a
	-- 2-frame tap is far shorter than a step animation, so it never completes a
	-- move — measured, the player stayed on the seeded tile and the counter never
	-- decremented. walk polls until the coordinate actually changes.
	navigate.walk("DOWN", 1)
	navigate.walk("DOWN", 1)

	-- The literal on-screen line. gbtext's encoder is GREEDY as of 2026-08-21, so
	-- "'s" encodes as the single ligature tile $BD exactly as the ROM stores it —
	-- an apostrophe needle used to be unwritable and this scenario originally asked
	-- for one, then timed out for 1800 frames against a needle it could not build.
	-- dialog_until_text, NOT wait_for_text: pret writes this as
	--     text "PA: Ding-dong!" / para "Time's up!"
	-- and `para` starts a NEW PARAGRAPH behind a ▼ prompt, so the second line only
	-- exists after an A press. wait_for_text never presses, so it waited 1800 frames
	-- for a line the game had not drawn yet.
	navigate.dialog_until_text(text:encode("Time's up!"))
	scenario.wait(60)

	scenario.exec(function()
		dump.write("safari_game_over", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "Safari Zone step countdown reached 0: TimesUpText on screen, game over armed",
		})
	end)
end)
