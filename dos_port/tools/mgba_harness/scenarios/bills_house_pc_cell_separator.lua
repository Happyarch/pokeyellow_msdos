---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- bills_house_pc_cell_separator — golden DRAFT for a (not-yet-wired)
-- DEBUG_BILLSHOUSEPC gate: the Bill's House PC prop's "cell separator" branch
-- (engine/events/hidden_events/bills_house_pc.asm:BillsHousePC ->
-- .doCellSeparator), the richest of the routine's three branches and the one
-- that exercises the predef_code trampoline BillsHouseInitiatedText.
--
-- *** THIS SCENARIO IS AUTHORED AND UNRUN, AND NOT YET REGISTERED IN
-- tools/scenario_manifest.json. *** No emulator was run to produce or verify
-- it (hard rule: no emulator, ever). It is intentionally left OUT of the
-- manifest: tools/validate_scenarios.py (run by static_gate) requires every
-- manifest entry to have a matching tools/golden_diff.py SCENARIOS row, a real
-- DEBUG_<gate> id already assembled into assets/scenario_registry.inc, and
-- committed tests/goldens/<name>.{bin,json} — none of which can exist without
-- (a) a boot dispatch in dos_port/src/home/overworld.asm (same shape as
-- DEBUG_BILLSPC's RunBillsPCTest) and a dump block in
-- dos_port/src/debug/debug_dump.asm (both OUTSIDE this task's file allow-list:
-- only dos_port/src/engine/events/hidden_events/bills_house_pc.asm and its own
-- generator/Makefile lines were in scope) and (b) running `make goldens`
-- against the golden ROM, which is the forbidden emulator step. Registering
-- the manifest entry now would fail static_gate for reasons that have nothing
-- to do with this file's own correctness. The integrator (or a follow-up task
-- with debug_dump.asm/overworld.asm in scope) should add those two hooks,
-- register this scenario in the manifest + golden_diff.py, then run and
-- verify it.
--
-- NOTE ON REACHABILITY: an earlier batch in this same subsystem (PC-access
-- cluster, docs/translation_log.md) declined to author a golden at all for
-- its interior-map predef-text handlers, citing docs/current_plan_backlog.md
-- #31 ("interiors are not resident"). That premise is STALE — stigmergy
-- memory `interior-maps-blocked-by-tileset-residency-not-blk` (RESOLVED
-- 2026-08-16, 566c3027c) measured interiors rendering correctly and states
-- backlog #31's cause is superseded ("predef text's must-hit scenario should
-- now be buildable; nobody has tried yet"). This scenario is the first
-- attempt; it does not skip itself on that (disproven) basis. Its actual, live
-- blocker is narrower: the missing DEBUG_ entry gate and the missing golden
-- artifacts described above, not tileset residency.
--
-- WHAT IT DOES (once wired): new game -> Pallet Town -> the game's own script
-- warp (wDestinationWarpID=$FF / hWarpDestinationMap / BIT_WARP_FROM_CUR_SCRIPT,
-- see lib/sight.lua's header for why this is the safe way onto an arbitrary
-- map) onto BILLS_HOUSE at the tile below the hidden-event PC, facing UP ->
-- seed the "Bill has told the player to use the Cell Separator, but it has not
-- been used yet" event-flag state -> press A -> wait for BillsHousePC's
-- .doCellSeparator sequence (BillsHouseInitiatedText's trampoline print +
-- StopAllMusic/SFX_SWITCH tail, then 4x DelayFrames+PlaySound+
-- WaitForSoundToFinish, then PlayDefaultMusic) to finish and set
-- EVENT_USED_CELL_SEPARATOR_ON_BILL -> dump.
--
-- COORDINATES. data/events/hidden_events.asm: `hidden_event 1, 4, BillsHousePC,
-- SPRITE_FACING_UP` — the `hidden_event` macro (data/events/hidden_events.asm:94)
-- emits (y=\2, x=\1, argument=\4, function=\3), so the tile IN FRONT OF THE
-- PLAYER the hidden-event scan matches is (Y=4, X=1) — same "tile in front,
-- not tile stood on" convention as sign_pallet.lua's town sign. Facing UP means
-- that tile is one row NORTH of the player, so the player must stand at
-- (Y=5, X=1). BILLS_HOUSE is a 4x4-block map (constants/map_constants.asm:
-- BILLS_HOUSE_WIDTH=4), map id $58 (constants/map_constants.asm).
--
-- EVENT FLAGS (assets/event_constants.inc): EVENT_USED_CELL_SEPARATOR_ON_BILL
-- =1372, EVENT_BILL_SAID_USE_CELL_SEPARATOR=1375 (both byte 171 of
-- wEventFlags: 1372/8=171, 1375/8=171), EVENT_LEFT_BILLS_HOUSE_AFTER_HELPING
-- =1376 (byte 172, bit 0). For the .doCellSeparator branch: byte 171 must have
-- bit 7 (1375%8) SET and bit 4 (1372%8) CLEAR; byte 172 bit 0 CLEAR. A fresh
-- save already has every event flag clear, so this scenario only needs to SET
-- bit 7 of byte 171 before pressing A.

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local gbtext = require("lib.gbtext")
local scenario = require("lib.scenario")
local navigate = require("lib.navigate")
local dump = require("lib.dump")
local seed = require("lib.seed")
local input = require("lib.input")

local sym = symbols.load()
local text = gbtext.load()
navigate.init(sym, text)

local REDS_HOUSE_1F = 37   -- pret constants/map_constants.asm
local PALLET_TOWN = 0
local BILLS_HOUSE = 0x58   -- pret constants/map_constants.asm
local BILLS_HOUSE_WIDTH = 4 -- blocks; constants/map_constants.asm BILLS_HOUSE_WIDTH
local BIT_WARP_FROM_CUR_SCRIPT = 3 -- constants/ram_constants.asm

local PLAYER_Y, PLAYER_X = 5, 1 -- one tile south of the hidden_event's (Y=4,X=1)

-- wEventFlags byte 171: bit 7 = EVENT_BILL_SAID_USE_CELL_SEPARATOR (set before
-- pressing A), bit 4 = EVENT_USED_CELL_SEPARATOR_ON_BILL (must come back SET
-- after the sequence runs). Mirror this region by name in the (not-yet-added)
-- DEBUG_BILLSHOUSEPC block of src/debug/debug_dump.asm.
local EVENT_BYTE_OFFSET = 171
local BIT_BILL_SAID_USE_CELL_SEPARATOR = 7
local BIT_USED_CELL_SEPARATOR_ON_BILL = 4

-- Extra WRAM this scenario compares on top of dump.standard_regions: the byte
-- the whole flow reads and mutates. Scenario-local (same rationale as
-- lib/sight.lua's regions()) so it does not change any other golden's layout.
local function regions(s)
	local regs = dump.standard_regions(s)
	regs[#regs + 1] = {
		name = "wBillsHouseEvents",
		addr = s:addr("wEventFlags") + EVENT_BYTE_OFFSET,
		size = 1,
	}
	return regs
end

scenario.run(function()
	navigate.boot_to_main_menu()
	navigate.new_game_to_bedroom()

	-- bedroom (2F) -> 1F -> Pallet Town (route notes in start_menu.lua)
	navigate.walk("RIGHT", 1)
	navigate.walk("UP", 5)
	navigate.walk_until_map("RIGHT", REDS_HOUSE_1F)
	navigate.walk("DOWN", 6)
	navigate.walk("LEFT", 4)
	navigate.walk_until_map("DOWN", PALLET_TOWN)
	-- Settle before arming the script warp — see lib/sight.lua's header note:
	-- arming while an EnterMap from the door is still in flight loses the write.
	navigate.walk("DOWN", 1)
	scenario.wait(60)

	scenario.exec(function()
		seed.player(sym, text:encode(seed.PLAYER_NAME))
		local view = sym:addr("wOverworldMap") + 7 + BILLS_HOUSE_WIDTH
			+ (BILLS_HOUSE_WIDTH + 6) * (PLAYER_Y >> 1) + (PLAYER_X >> 1)
		local ptr = sym:addr("wCurrentTileBlockMapViewPointer")
		emu:write8(ptr, view & 0xFF)
		emu:write8(ptr + 1, (view >> 8) & 0xFF)
		emu:write8(sym:addr("wYCoord"), PLAYER_Y)
		emu:write8(sym:addr("wXCoord"), PLAYER_X)
		emu:write8(sym:addr("wSpritePlayerStateData1FacingDirection"), 0x04) -- SPRITE_FACING_UP
		emu:write8(sym:addr("wDestinationWarpID"), 0xFF)
		emu:write8(sym:addr("hWarpDestinationMap"), BILLS_HOUSE)
		local flags = sym:addr("wStatusFlags3")
		emu:write8(flags, emu:read8(flags) | (1 << BIT_WARP_FROM_CUR_SCRIPT))
	end)

	local deadline = scenario.frame() + 900
	while navigate.read8("wCurMap") ~= BILLS_HOUSE do
		assert(scenario.frame() < deadline,
			"bills_house_pc_cell_separator: script warp to BILLS_HOUSE never fired")
		scenario.wait(1)
	end
	local y, x = navigate.coords()
	scenario.log(("bills_house_pc_cell_separator: on BILLS_HOUSE at (%d,%d)"):format(y, x))
	assert(y == PLAYER_Y and x == PLAYER_X,
		"bills_house_pc_cell_separator: the warp moved the player off the seeded tile")

	-- Arm EVENT_BILL_SAID_USE_CELL_SEPARATOR so BillsHousePC takes the
	-- .doCellSeparator branch (EVENT_LEFT_BILLS_HOUSE_AFTER_HELPING and
	-- EVENT_USED_CELL_SEPARATOR_ON_BILL are already clear on a fresh save).
	scenario.exec(function()
		local addr = sym:addr("wEventFlags") + EVENT_BYTE_OFFSET
		emu:write8(addr, emu:read8(addr) | (1 << BIT_BILL_SAID_USE_CELL_SEPARATOR))
	end)

	-- Face UP at the PC (already facing UP from the warp seed) and press A.
	-- BillsHousePC -> .doCellSeparator: prints BillsHouseInitiatedText (predef_code
	-- trampoline: text_far preamble + text_promptbutton, then the text_asm tail —
	-- StopAllMusic, 4x SFX+DelayFrames, PlayDefaultMusic), then
	-- SetEvent EVENT_USED_CELL_SEPARATOR_ON_BILL. The prompt button needs an A to
	-- clear, and the tail runs unattended after that.
	input.tap("A", 2, 30) -- open the prompt and let the text settle
	input.tap("A", 2, 30) -- clear the text_promptbutton wait

	-- Total tail delay is 32+80+48+32 = 192 frames of DelayFrames alone, plus
	-- WaitForSoundToFinish stalls and PlayDefaultMusic; budget generously.
	local ev_addr = sym:addr("wEventFlags") + EVENT_BYTE_OFFSET
	deadline = scenario.frame() + 1200
	while (scenario.read_range(ev_addr, 1):byte(1) & (1 << BIT_USED_CELL_SEPARATOR_ON_BILL)) == 0 do
		assert(scenario.frame() < deadline,
			"bills_house_pc_cell_separator: EVENT_USED_CELL_SEPARATOR_ON_BILL never set — "
			.. "check the prompt-button press landed and the text_asm tail ran")
		scenario.wait(1)
	end
	scenario.log(("bills_house_pc_cell_separator: cell separator used at frame %d")
		:format(scenario.frame()))
	scenario.wait(30) -- settle after PlayDefaultMusic before the dump

	scenario.exec(function()
		dump.write("bills_house_pc_cell_separator", regions(sym), {
			frame = scenario.frame(),
			description = "BillsHousePC .doCellSeparator branch run to completion: "
				.. "BillsHouseInitiatedText's predef_code trampoline printed its text "
				.. "and ran the StopAllMusic/4xSFX/PlayDefaultMusic tail, then "
				.. "EVENT_USED_CELL_SEPARATOR_ON_BILL was set",
		})
	end)
end)
