---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- save_real_load — CONTINUE from a REAL cartridge save.
--
-- continue_seed proves the port round-trips ITS OWN bytes: it seeds, saves,
-- clobbers and reloads. That is a closed loop, and a closed loop cannot see an
-- error it makes symmetrically -- a field written at the wrong offset is read
-- back from the same wrong offset and matches itself. This scenario closes that
-- gap by starting from data the port never authored: a genuine Game Boy battery
-- save (tests/fixtures/yellow_100.sav -- 6-mon party, 151/151 Pokedex, a
-- populated current box, all 15 GB checksums valid).
--
-- Both sides start from the SAME 32 KiB image. mGBA attaches it as the
-- cartridge battery here; the port gets it as POKEMON.DSV, converted per run by
-- goldencheck.sh (saveconv.py --to-dos) and staged into the disk image, from
-- which boot's SramLoadImage scatters it into the resident SRAM banks.
--
-- Alignment note: this side reaches the load through the REAL main menu
-- (CONTINUE), while the port gate calls TryLoadSaveFile directly after
-- clobbering the save WRAM. Those differ in surrounding state (map, menu
-- residue), but NOT in anything compared: every non-battle region in the
-- golden's WRAM set -- wPlayerName, wPartyData, wPokedex, wBagItems,
-- wPlayerMoney, wOptionsBlock, wPlayerID -- lives inside a saved block, so
-- after the load both sides hold save-derived values and the surrounding
-- difference is invisible to the diff. This is a datastruct scenario: WRAM only.
--
-- NOT box coverage: the fixture's stored boxes are near-empty (box 10 holds one
-- mon, the rest none) and the dump carries no wBoxData region anyway. The
-- stage-6 deposit/withdraw scenario is still required.
--
-- Run (from the repo root):
--   dos_port/tools/mgba_harness/make_goldens.sh save_real_load

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
console:log(("save_real_load: %d symbols from %s"):format(sym.count, sym.path))

local SAVE_FIXTURE = root .. "/../../tests/fixtures/yellow_100.sav"

-- Pinned by the fixture; the post-load signal and a check that we loaded the
-- file we meant to rather than an empty cartridge.
local EXPECTED_PARTY_COUNT = 6

scenario.run(function()
	-- Attach the battery save BEFORE the ROM can read SRAM, then reset so the
	-- cartridge comes up with it in place. runner.c never calls
	-- mCoreAutoloadSave (it has no save directory), so without this the GB boots
	-- with uninitialised SRAM and the menu would offer NEW GAME only.
	--
	-- *** temporary = TRUE is load-bearing, not a default. *** With false, mGBA
	-- adopts the file as the live battery and writes SRAM back to it on exit —
	-- it silently rewrote this committed fixture the first time (the ROM stages
	-- decompressed pics in sSpriteBuffer0, so bank 0 came back changed). A
	-- golden run must never mutate its own input. true keeps the mapping
	-- read-only.
	scenario.exec(function()
		assert(emu:loadSaveFile(SAVE_FIXTURE, true),
			"save_real_load: could not attach " .. SAVE_FIXTURE)
		emu:reset()
	end)

	-- With a save present the menu is CONTINUE / NEW GAME / OPTION; the helper
	-- waits on "NEW GAME", which is on screen either way.
	navigate.boot_to_main_menu()
	navigate.choose(text:encode("CONTINUE"))

	-- CONTINUE runs the save-screen panel, then the load. Poll for the loaded
	-- party rather than waiting a fixed number of frames: the party count is
	-- zero until LoadSAVCheckSum copies sPartyData into WRAM, so this fires on
	-- the load itself and cannot pass on a menu that never advanced.
	local loaded = false
	for _ = 1, 900 do
		if navigate.read8("wPartyCount") == EXPECTED_PARTY_COUNT then
			loaded = true
			break
		end
		scenario.wait(4)
	end
	assert(loaded, ("save_real_load: wPartyCount never reached %d — the CONTINUE "
		.. "load did not happen (menu stuck, or the save did not attach)")
		:format(EXPECTED_PARTY_COUNT))

	scenario.wait(60) -- let the load finish every block, not just the party

	scenario.exec(function()
		dump.write("save_real_load", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "WRAM after CONTINUE loads a real cartridge save "
				.. "(6-mon party, 151/151 Pokedex); externally-authored data, so "
				.. "offsets a self-round-trip would hide diverge here",
		})
	end)
end)
