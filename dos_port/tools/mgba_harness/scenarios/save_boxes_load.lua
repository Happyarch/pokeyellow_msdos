---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- save_boxes_load — CONTINUE from a real save whose PC boxes are FULL.
--
-- save_real_load proved the port reads an externally-authored save, but the
-- suite has never compared a single byte of BOX data: dump.wram_regions has no
-- wBoxData row, so the whole box_struct layout -- the 33-byte stride, the
-- species list and its $FF sentinel, the 20 OT names and the 20 nicknames --
-- has had ZERO coverage. This scenario adds it.
--
-- The fixture (tests/fixtures/yellow_boxes_full.sav) is the same real save with
-- all 12 boxes filled to 20 mons, built by dos_port/tools/savegen using
-- PKHeX.Core so the EXP curves, level-up movesets and species mapping are the
-- real ones rather than something hand-rolled. Both sides start from that same
-- 32 KiB image: mGBA attaches it as the cartridge battery, the port gets it as
-- POKEMON.DSV via goldencheck.sh.
--
-- *** SCOPE, precisely: this does NOT exercise SRAM banks 2 and 3. *** A
-- CONTINUE load copies sCurBoxData -- which lives in bank 1 -- into WRAM, and
-- never reads sBoxN. Reaching the stored boxes needs ChangeBox, which needs the
-- PC UI; that remains stage 6's job. What this pins is the current-box block.
--
-- wBoxData is a SCENARIO-LOCAL region, mirrored by the %ifdef DEBUG_BOX_SAVE
-- gbregion row in dos_port/src/debug/debug_dump.asm. The differ joins by NAME
-- and cross-checks the address, so the two lists must agree. Deliberately not
-- added to dump.wram_regions: that would relayout every committed golden.
--
-- Run (from the repo root):
--   dos_port/tools/mgba_harness/make_goldens.sh save_boxes_load

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local gbtext = require("lib.gbtext")
local navigate = require("lib.navigate")
local dump = require("lib.dump")
local scenario = require("lib.scenario")

local sym = symbols.load()
local text = gbtext.load()
navigate.init(sym, text)
console:log(("save_boxes_load: %d symbols from %s"):format(sym.count, sym.path))

local SAVE_FIXTURE = root .. "/../../tests/fixtures/yellow_boxes_full.sav"

-- Pinned by the fixture. wBoxCount is the post-load signal AND the assertion
-- that the box actually arrived full -- 20 is what makes this scenario mean
-- something, so it is checked rather than assumed.
local EXPECTED_PARTY_COUNT = 6
local EXPECTED_BOX_COUNT = 20

local function regions(s)
	local r = dump.standard_regions(s)
	-- MIRRORS the %ifdef DEBUG_BOX_SAVE row in debug_dump.asm.
	r[#r + 1] = {
		name = "wBoxData",
		addr = s:addr("wBoxDataStart"),
		size = s:addr("wBoxDataEnd") - s:addr("wBoxDataStart"),
	}
	return r
end

scenario.run(function()
	-- temporary = TRUE: with false mGBA adopts the file as the live battery and
	-- writes SRAM back on exit, which would mutate this committed fixture.
	scenario.exec(function()
		assert(emu:loadSaveFile(SAVE_FIXTURE, true),
			"save_boxes_load: could not attach " .. SAVE_FIXTURE)
		emu:reset()
	end)

	navigate.boot_to_main_menu()
	navigate.choose(text:encode("CONTINUE"))

	local loaded = false
	for _ = 1, 900 do
		if navigate.read8("wPartyCount") == EXPECTED_PARTY_COUNT then
			loaded = true
			break
		end
		scenario.wait(4)
	end
	assert(loaded, "save_boxes_load: the CONTINUE load never happened")

	scenario.wait(60) -- let every block finish loading, not just the party

	local boxCount = navigate.read8("wBoxCount")
	assert(boxCount == EXPECTED_BOX_COUNT,
		("save_boxes_load: wBoxCount is %d, expected %d — the fixture's current "
		.. "box is not full, so this scenario would prove nothing")
		:format(boxCount, EXPECTED_BOX_COUNT))

	scenario.exec(function()
		dump.write("save_boxes_load", regions(sym), {
			frame = scenario.frame(),
			description = "WRAM after CONTINUE loads a real save with all 12 PC "
				.. "boxes full; adds the wBoxData region (20-mon current box, "
				.. "OT names and nicknames) that no other scenario compares",
		})
	end)
end)
