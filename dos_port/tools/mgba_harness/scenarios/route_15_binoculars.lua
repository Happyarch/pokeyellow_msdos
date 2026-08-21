---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- route_15_binoculars — golden for Route15GateLeftBinoculars (pret engine/events/hidden_events/route_15_binoculars.asm)
--
-- ############################################################################
-- ## UNRUN AND NOT YET REGISTERED. Read this before using it.               ##
-- ##                                                                        ##
-- ## This file is the mGBA (ground-truth) half only. The scenario is NOT in ##
-- ## tools/scenario_manifest.json and NOT in golden_diff.py's SCENARIOS,    ##
-- ## because registering it without a committed tests/goldens/*.bin+.json   ##
-- ## makes tools/validate_scenarios.py — step 5 of static_gate — fail, and  ##
-- ## producing those artifacts needs `make goldens`, i.e. an emulator run,  ##
-- ## which the author of this file was forbidden to perform.                ##
-- ##                                                                        ##
-- ## STILL MISSING, and all of it is OUTSIDE the authoring agent's          ##
-- ## file allow-list, so it was deliberately not written:                   ##
-- ##   * dos_port/src/debug/debug_dump.asm  — a RunRoute15BinocularsTest    ##
-- ##     harness (warp to ROUTE_15_GATE_2F, face up at (1,2), call          ##
-- ##     Route15GateLeftBinoculars, call DebugDumpMemory)                   ##
-- ##   * dos_port/src/home/overworld.asm    — the %ifdef DEBUG_BINOCULARS   ##
-- ##     call RunRoute15BinocularsTest dispatch in EnterMap                 ##
-- ##   * dos_port/Makefile                  — the DEBUG_BINOCULARS gate     ##
-- ##   * the manifest + golden_diff stanzas, then `make goldens`            ##
-- ############################################################################
--
-- WHAT IT WOULD PROVE:
-- Route15GateLeftBinoculars checks player facing UP, triggers auto text box,
-- displays Route15UpstairsBinocularsText ($0A predef text), loads ARTICUNO species,
-- plays Articuno cry, calls DisplayMonFrontSpriteInBox (pop-up window with front pic),
-- and clears hAutoBGTransferEnabled.
-- Running this scenario would verify that interacting with the left binoculars in
-- Route 15 Gate 2F facing UP triggers the predef text stream and Articuno front box.

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local gbtext = require("lib.gbtext")
local dump = require("lib.dump")
local scenario = require("lib.scenario")
local seed = require("lib.seed")
local navigate = require("lib.navigate")

local sym = symbols.load()
local text = gbtext.load()
navigate.init(sym, text)

local ROUTE_15_GATE_2F = 197 -- assets/map_dims.inc / constants/map_constants.asm

scenario.run(function()
	navigate.boot_to_main_menu()
	navigate.new_game_to_bedroom()

	-- Warp to Route 15 Gate 2F in front of the left binoculars (x=1, y=2), facing UP (direction 4)
	scenario.exec(function()
		seed.warp(sym, ROUTE_15_GATE_2F, 1, 2)
		emu:write8(sym:addr("wSpritePlayerStateData1FacingDirection"), 4) -- SPRITE_FACING_UP
	end)

	scenario.wait(10)

	-- Press A to interact with the binoculars
	navigate.press("A")

	-- Wait for "Looked into" predef text to start displaying
	navigate.dialog_until_text(text:encode("Looked into"))
	scenario.wait(60)

	scenario.exec(function()
		dump.write("route_15_binoculars", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "Route15GateLeftBinoculars: interacted with left binoculars facing UP on Route 15 Gate 2F",
		})
	end)
end)
