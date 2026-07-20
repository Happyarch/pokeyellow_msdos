---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- continue_seed — menu-intro A3. The reference "loaded state" a CONTINUE must
-- reproduce: the deterministic debug save (seed.lua == the port's
-- PrepareNewGameDebug + RED/id 0 identity).
--
-- This is a datastruct scenario: it seeds the save WRAM and dumps it. The GOLDEN
-- is the invariant the port's continue-load must preserve. The port gate
-- (DEBUG_CONTINUE_SEED) seeds the same data, writes POKEMON.DSV, ZEROES the live
-- save WRAM, and loads it back with TryLoadSaveFile -- so the port's dump comes
-- entirely from the load, and a match proves the CONTINUE load preserved every
-- saved region.
--
-- wOptions is set to TEXT_DELAY_MEDIUM to match: the port's SKIP_TITLE boot runs
-- InitOptions before it seeds and saves, so the value that round-trips through
-- the save is MEDIUM. On a real continue both sides reach InitOptions the same
-- way (main menu), so this reflects the real invariant, it does not paper over a
-- divergence.
--
-- Run (from the repo root):
--   dos_port/tools/mgba_harness/make_goldens.sh continue_seed

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local gbtext = require("lib.gbtext")
local seed = require("lib.seed")
local dump = require("lib.dump")
local scenario = require("lib.scenario")

local sym = symbols.load()
local text = gbtext.load()
console:log(("continue_seed: %d symbols from %s"):format(sym.count, sym.path))

-- InitOptions writes both of these before the save on both sides (the port's
-- SKIP_TITLE boot; a real continue's main menu). Both are in wMainData, so both
-- round-trip through the save -- set both, or the port's faithfully-restored
-- $01 flag reads as a divergence.
local TEXT_DELAY_MEDIUM = 0x03
local FAST_TEXT_DELAY = 0x01                 -- 1 << BIT_FAST_TEXT_DELAY
local wOptions = sym:addr("wOptions")
local wLetterPrintingDelayFlags = sym:addr("wLetterPrintingDelayFlags")

scenario.run(function()
	scenario.wait(60) -- let the ROM settle past its power-on clears

	scenario.exec(function()
		seed.debug_new_game(sym, text:encode(seed.PLAYER_NAME))
		emu:write8(wOptions, TEXT_DELAY_MEDIUM)
		emu:write8(wLetterPrintingDelayFlags, FAST_TEXT_DELAY)
	end)

	scenario.exec(function()
		dump.write("continue_seed", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "deterministic debug save state -- the invariant a CONTINUE "
				.. "load must reproduce (seed.lua == PrepareNewGameDebug + RED/id 0)",
		})
	end)
end)
