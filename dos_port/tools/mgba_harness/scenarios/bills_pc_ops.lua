---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- bills_pc_ops — golden for the port's DEBUG_BILLSPC gate (sram plan stage 6,
-- differ class "datastruct"): the Bill's PC box flows through the REAL UI.
--
--   deposit PERSIAN → deposit JIGGLYPUFF → withdraw PERSIAN (the 44B→33B→44B
--   party→box→party round trip + stat recompute — the star coverage) →
--   release JIGGLYPUFF (YES) → B out of Bill's PC → settle → dump.
--
-- Both sides run the same GB code path: this side walks to the Viridian
-- Pokémon Center PC and enters via "SOMEONE's PC" (the PC main-menu handoff
-- that sets BIT_USING_GENERIC_PC + BIT_NO_MENU_BUTTON_SOUND); the port's
-- RunBillsPCTest opens BillsPC_ directly with the same two bits set and
-- drives the identical flow via AUTOKEY_BILLSPC (debug_dump.asm).
--
-- Never touches Pikachu: only PERSIAN and JIGGLYPUFF are selected, so no
-- starter-Pikachu branch (SleepingPikachu / PikachuUnhappy / PikachuCry)
-- fires on either side.
--
-- wBoxData is a SCENARIO-LOCAL region, mirrored by the %ifdef DEBUG_BILLSPC
-- gbregion row in dos_port/src/debug/debug_dump.asm (the DEBUG_BOX_SAVE
-- precedent). The box starts empty (asserted, not seeded) and ends empty —
-- what the region pins is the deterministic residue the deposit/withdraw/
-- release shifts leave behind, plus the count/sentinel bookkeeping.
--
-- Run (from the repo root):
--   dos_port/tools/mgba_harness/make_goldens.sh bills_pc_ops

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

-- Seeded party order (seed.DEBUG_PARTY): 0 SNORLAX, 1 PERSIAN, 2 JIGGLYPUFF,
-- 3 STARTER_PIKACHU, 4 CHARIZARD, 5 LAPRAS. End state: PERSIAN withdrawn last
-- so it re-enters the party at the tail.
local END_SPECIES = { 132, 84, 180, 19, 144 } -- SNORLAX PIKACHU CHARIZARD LAPRAS PERSIAN

local function regions(s)
	local r = dump.standard_regions(s)
	-- MIRRORS the %ifdef DEBUG_BILLSPC row in debug_dump.asm.
	r[#r + 1] = {
		name = "wBoxData",
		addr = s:addr("wBoxDataStart"),
		size = s:addr("wBoxDataEnd") - s:addr("wBoxDataStart"),
	}
	return r
end

-- The DEPOSIT/WITHDRAW // STATS/CANCEL submenu: its cursor opens on the
-- confirm row (wCurrentMenuItem = 0), so one A confirms. Positional on
-- purpose — the mon list underneath may keep its own arrow glyph, which
-- would confuse navigate.choose's cursor scan.
local function confirm_submenu(outcome_needle)
	navigate.wait_for_text(text:encode("STATS"))
	scenario.wait(30) -- settle: a tap into a just-drawn menu is swallowed
	input.tap("A", 2, 8)
	navigate.wait_for_text(outcome_needle, 1800)
end

scenario.run(function()
	navigate.boot_to_main_menu()
	navigate.new_game_to_bedroom()

	pc.to_viridian_center_pc(sym, text)
	pc.open_someones_pc(text)

	-- The box must start empty: this scenario's baseline is a fresh game,
	-- and an unexpectedly non-empty box would silently change every shift
	-- residue the golden pins.
	assert(navigate.read8("wBoxCount") == 0,
		"bills_pc_ops: the current box is not empty at the start")

	-- deposit PERSIAN
	navigate.choose(text:encode("DEPOSIT"))
	navigate.wait_for_text(text:encode("PERSIAN"))
	scenario.wait(30)
	navigate.choose(text:encode("PERSIAN"))
	confirm_submenu(text:encode("stored in Box"))
	navigate.dismiss_text(text:encode("stored in Box"))

	-- deposit JIGGLYPUFF
	navigate.wait_for_text(text:encode("DEPOSIT"))
	scenario.wait(30)
	navigate.choose(text:encode("DEPOSIT"))
	navigate.wait_for_text(text:encode("JIGGLYPUFF"))
	scenario.wait(30)
	navigate.choose(text:encode("JIGGLYPUFF"))
	confirm_submenu(text:encode("stored in Box"))
	navigate.dismiss_text(text:encode("stored in Box"))

	-- withdraw PERSIAN (box list: PERSIAN 0, JIGGLYPUFF 1; cursor opens at 0)
	navigate.wait_for_text(text:encode("WITHDRAW"))
	scenario.wait(30)
	navigate.choose(text:encode("WITHDRAW"))
	navigate.wait_for_text(text:encode("PERSIAN"))
	scenario.wait(30)
	navigate.choose(text:encode("PERSIAN"))
	confirm_submenu(text:encode("taken out"))
	navigate.dismiss_text(text:encode("taken out"))

	-- release JIGGLYPUFF (no submenu: straight to the OnceReleased YES/NO)
	navigate.wait_for_text(text:encode("RELEASE"))
	scenario.wait(30)
	navigate.choose(text:encode("RELEASE"))
	navigate.wait_for_text(text:encode("JIGGLYPUFF"))
	scenario.wait(30)
	navigate.choose(text:encode("JIGGLYPUFF"))
	-- "Once released, / JIGGLYPUFF is" (cont ▼) → "gone forever. OK?" + YES/NO
	navigate.dialog_until_text(text:encode("gone forever"))
	scenario.wait(30) -- YES/NO box drawn, YES on top
	input.tap("A", 2, 8)
	navigate.wait_for_text(text:encode("released outside"), 1800)
	navigate.dismiss_text(text:encode("released outside"))

	-- B out of Bill's PC (ExitBillsPC) → back to the PC main menu
	navigate.wait_for_text(text:encode("WITHDRAW"))
	scenario.wait(30)
	navigate.tap_until("B", text:encode("SOMEONE"))
	scenario.wait(60) -- settle

	-- End-state guard: party 5 (PERSIAN re-appended), box empty — the same
	-- bytes the port harness verified via GBSTATE after C3.
	assert(navigate.read8("wPartyCount") == #END_SPECIES,
		"bills_pc_ops: party count is not 5 after the flows")
	for i, species in ipairs(END_SPECIES) do
		local got = scenario.read_range(sym:addr("wPartySpecies") + i - 1, 1):byte(1)
		assert(got == species,
			("bills_pc_ops: party slot %d species %d, expected %d"):format(i - 1, got, species))
	end
	assert(navigate.read8("wBoxCount") == 0,
		"bills_pc_ops: the box is not empty after withdraw+release")

	scenario.exec(function()
		dump.write("bills_pc_ops", regions(sym), {
			frame = scenario.frame(),
			description = "Bill's PC via the Viridian Center PC (SOMEONE's PC): "
				.. "deposit PERSIAN, deposit JIGGLYPUFF, withdraw PERSIAN, release "
				.. "JIGGLYPUFF, B out; party 5 with PERSIAN re-appended, box empty; "
				.. "adds the scenario-local wBoxData region (shift residue)",
		})
	end)
end)
