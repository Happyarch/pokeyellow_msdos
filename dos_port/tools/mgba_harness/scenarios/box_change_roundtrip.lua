---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- box_change_roundtrip — golden for the port's DEBUG_BILLSPC_CHANGEBOX gate
-- (sram plan stage 6, differ class "datastruct"): the ONLY runtime path into
-- SRAM banks 2/3.
--
--   deposit PERSIAN → CHANGE BOX → YES (the first change runs
--   EmptyAllSRAMBoxes: banks 2+3 init) → BOX12 (bank-3 traffic both ways +
--   a real SaveGameData) → CHANGE BOX back to BOX 1 → B out → dump.
--
-- PERSIAN surviving in the final wBoxData proves the bank-2 store AND load;
-- wCurrentBoxNum must read $80 = box 0 | BIT_HAS_CHANGED_BOXES.
--
-- mGBA-side real saves are safe here: runner.c never autoloads a battery and
-- no fixture is attached, so ChangeBox's SRAM/SaveGameData writes touch only
-- this run's anonymous battery.
--
-- Entry is the same genuine PC main-menu handoff as bills_pc_ops (lib/pc.lua:
-- walk to the Viridian Center PC, "SOMEONE's PC"); the port side is
-- RunBillsPCTest + the AUTOKEY_BILLSPC_CHANGE script (debug_dump.asm).
--
-- Run (from the repo root):
--   dos_port/tools/mgba_harness/make_goldens.sh box_change_roundtrip

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local gbtext = require("lib.gbtext")
local dump = require("lib.dump")
local scenario = require("lib.scenario")
local navigate = require("lib.navigate")
local input = require("lib.input")
local pc = require("lib.pc")

local sym = symbols.load()
local text = gbtext.load()
navigate.init(sym, text)

local PERSIAN = 144 -- internal species id (seed.DEBUG_PARTY slot 1)
local BIT_HAS_CHANGED_BOXES = 0x80

local function regions(s)
	local r = dump.standard_regions(s)
	-- MIRRORS the %ifdef DEBUG_BILLSPC_CHANGEBOX gbregion rows in debug_dump.asm.
	r[#r + 1] = {
		name = "wBoxData",
		addr = s:addr("wBoxDataStart"),
		size = s:addr("wBoxDataEnd") - s:addr("wBoxDataStart"),
	}
	r[#r + 1] = {
		name = "wCurrentBoxNum",
		addr = s:addr("wCurrentBoxNum"),
		size = 1,
	}
	return r
end

-- CHANGE BOX from the Bill's PC menu: dialog (cont+para) → YES → pick
-- `box_needle` in the box list → save → back at the Bill's PC menu.
local function change_box_to(box_needle)
	navigate.choose(text:encode("CHANGE BOX"))
	-- "When you change a / #MON BOX, data" (cont) "will be saved." (para)
	navigate.dialog_until_text(text:encode("Is that okay"))
	scenario.wait(30) -- YES/NO box drawn, YES on top
	navigate.tap_until("A", text:encode("Choose a")) -- YES → the box menu
	scenario.wait(30)
	navigate.choose(box_needle)
	-- SFX_SAVE + box copies + SaveGameData, then the Bill's PC menu redraws
	navigate.wait_for_text(text:encode("WITHDRAW"))
	scenario.wait(30)
end

scenario.run(function()
	navigate.boot_to_main_menu()
	navigate.new_game_to_bedroom()

	pc.to_viridian_center_pc(sym, text)
	pc.open_someones_pc(text)

	assert(navigate.read8("wBoxCount") == 0,
		"box_change_roundtrip: the current box is not empty at the start")

	-- deposit PERSIAN into BOX 1
	navigate.choose(text:encode("DEPOSIT"))
	navigate.wait_for_text(text:encode("PERSIAN"))
	scenario.wait(30)
	navigate.choose(text:encode("PERSIAN"))
	navigate.wait_for_text(text:encode("STATS"))
	scenario.wait(30)
	input.tap("A", 2, 8) -- DEPOSIT (submenu cursor opens on it)
	navigate.wait_for_text(text:encode("stored in Box"), 1800)
	navigate.dismiss_text(text:encode("stored in Box"))
	navigate.wait_for_text(text:encode("WITHDRAW"))
	scenario.wait(30)

	-- BOX 1 → BOX12 (first change: EmptyAllSRAMBoxes + banks 2/3 init),
	-- then back to BOX 1. "BOX 1" (with the space) cannot match BOX10-12.
	change_box_to(text:encode("BOX12"))
	change_box_to(text:encode("BOX 1"))

	-- B out of Bill's PC (ExitBillsPC) → back to the PC main menu
	navigate.tap_until("B", text:encode("SOMEONE"))
	scenario.wait(60) -- settle

	-- End-state guard: the same bytes the port harness verified via GBSTATE.
	assert(navigate.read8("wBoxCount") == 1,
		"box_change_roundtrip: the box did not come back with exactly PERSIAN")
	assert(navigate.read8("wBoxSpecies") == PERSIAN,
		"box_change_roundtrip: box slot 0 is not PERSIAN after the round trip")
	assert(navigate.read8("wCurrentBoxNum") == BIT_HAS_CHANGED_BOXES,
		"box_change_roundtrip: wCurrentBoxNum is not box 0 | BIT_HAS_CHANGED_BOXES")
	assert(navigate.read8("wPartyCount") == 5,
		"box_change_roundtrip: party count is not 5 after the deposit")

	scenario.exec(function()
		dump.write("box_change_roundtrip", regions(sym), {
			frame = scenario.frame(),
			description = "Bill's PC change-box round trip via the Viridian Center "
				.. "PC: deposit PERSIAN, change to BOX12 (EmptyAllSRAMBoxes + "
				.. "bank-3 traffic + SaveGameData), change back to BOX 1, B out; "
				.. "PERSIAN back in wBoxData proves the bank-2 store and load, "
				.. "wCurrentBoxNum = $80",
		})
	end)
end)
