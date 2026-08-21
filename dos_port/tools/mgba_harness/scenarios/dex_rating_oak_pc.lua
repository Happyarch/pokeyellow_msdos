---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- dex_rating_oak_pc — golden for DisplayDexRating (pret engine/events/
-- pokedex_rating.asm), differ class "datastruct".
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
-- ##   * dos_port/src/debug/debug_dump.asm  — a RunDexRatingTest harness    ##
-- ##     (seed the two dex bitsets to an exact count, pick the event        ##
-- ##     branch, `call DisplayDexRating`, `call DebugDumpMemory`)           ##
-- ##   * dos_port/src/home/overworld.asm    — the `%ifdef DEBUG_DEXRATING   ##
-- ##     call RunDexRatingTest` dispatch in EnterMap                        ##
-- ##   * dos_port/Makefile                  — the DEBUG_DEXRATING gate      ##
-- ##     (NEED_DEBUG_DUMP, DEBUG_SEED_PARTY, SKIP_TITLE, DEBUG_AUTOKEY,     ##
-- ##      AUTOKEY_APRESS, AUTOKEY_DUMP_FRAME=999999)                        ##
-- ##   * the manifest + golden_diff stanzas, then `make goldens`            ##
-- ############################################################################
--
-- WHAT IT WOULD PROVE. DisplayDexRating picks its rating band by walking
-- DexRatingsTable and taking the first entry whose threshold EXCEEDS the owned
-- count (pret: `ld a,[hli] / ld b,a / ldh a,[hDexRatingNumMonsOwned] / cp b /
-- jr c`). An off-by-one in that walk — or in the port's entry stride, which is
-- 5 bytes where the GB's is 3 because the pointer widened from `dw` to `dd` —
-- prints the WRONG rating. No static check in this tree can see that: faithdiff
-- compares calls and named stores, and the band choice is neither. Seeding an
-- exact owned count that sits just inside one band's window is the only way to
-- pin which band the walk lands on.
--
-- SEEDS (must be mirrored byte-for-byte by the port-side harness):
--   owned = 55 species, seen = 70 species, both set LSB-first from the base of
--   their bitset. 55 lands in band DexRatingText_Own50To59 (thresholds 50 and
--   60), which is also the LONGEST band stream at 76 bytes — the bound case for
--   the hall-of-fame copy loop. 70 is kept different from 55 so
--   DexCompletionText's two text_decimal fields cannot be confused.
--   EVENT_HALL_OF_FAME_DEX_RATING is left CLEAR (a fresh game), which selects
--   the first-viewing branch: DexCompletionText + the band text through the
--   ordinary text engine, then WaitForTextScrollButtonPress.
--
-- MASK THE OTHER BRANCH, NOT THIS ONE. If a second scenario is ever added with
-- the event SET, its golden MUST mask wDexRatingText: the GB copies the 4-byte
-- TX_FAR command into it, the port copies the whole flattened stream (see the
-- DEVIATION on .copyRatingTextLoop in src/engine/events/pokedex_rating.asm).
-- The two count bytes wDexRatingNumMonsSeen/wDexRatingNumMonsOwned match
-- exactly on both branches and are the real pins.
--
-- ROUTE: bedroom → Viridian Pokémon Center PC (the same walk bills_pc_ops
-- uses) → PC main menu → "PROF.OAK's PC" → "Rate my #DEX?" YES. OaksPC is the
-- third PC menu row and only appears once EVENT_GOT_POKEDEX is set
-- (DisplayPCMainMenu, engine/pokemon/bills_pc.asm), so this seeds it.
--
-- Run (from the repo root):
--   dos_port/tools/mgba_harness/make_goldens.sh dex_rating_oak_pc

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local gbtext = require("lib.gbtext")
local dump = require("lib.dump")
local scenario = require("lib.scenario")
local seed = require("lib.seed")
local navigate = require("lib.navigate")
local pc = require("lib.pc")

local sym = symbols.load()
local text = gbtext.load()
navigate.init(sym, text)

local OWNED, SEEN = 55, 70
local EVENT_GOT_POKEDEX = 37            -- assets/event_constants.inc (pret constants/event_constants.asm)

-- Set exactly `count` bits from the base of a bitset, LSB-first inside each
-- byte — the order pret's SetOwnedMon/SetSeenMon use, so CountSetBits returns
-- exactly `count` and the port-side harness can reproduce the pattern byte for
-- byte. The whole owned+seen block is zeroed first: seed.debug_new_game leaves
-- its own "all seen, scattered owned" pattern behind, and a stray bit anywhere
-- in the range moves the band.
local function seed_dex_counts(owned_count, seen_count)
	local owned = sym:addr("wPokedexOwned")
	local seen = sym:addr("wPokedexSeen")
	for a = owned, sym:addr("wPokedexSeenEnd") - 1 do
		emu:write8(a, 0)
	end
	local function set_bits(base, count)
		local full, tail = count // 8, count % 8
		for i = 0, full - 1 do
			emu:write8(base + i, 0xFF)
		end
		if tail > 0 then
			emu:write8(base + full, (1 << tail) - 1)
		end
	end
	set_bits(owned, owned_count)
	set_bits(seen, seen_count)
	console:log(("seed: dex counts owned=%d seen=%d"):format(owned_count, seen_count))
end

scenario.run(function()
	navigate.boot_to_main_menu()
	navigate.new_game_to_bedroom()

	-- Walks to the Center PC and seeds a debug new game on arrival.
	pc.to_viridian_center_pc(sym, text)

	-- AFTER pc.to_viridian_center_pc's own seeding, which writes the dex.
	scenario.exec(function()
		seed_dex_counts(OWNED, SEEN)
		seed.set_event(sym, EVENT_GOT_POKEDEX) -- makes the OaksPC row appear
	end)

	-- A on the PC → "<PLAYER> turned on / the PC." → PC main menu.
	navigate.tap_until("A", text:encode("turned on"))
	-- "PROF.OAK", not "PROF.OAK's PC": the 's is a single charmap ligature tile
	-- that gbtext's one-glyph encoder cannot produce (the pc.lib "SOMEONE"
	-- lesson). "PROF.OAK" is unique on this menu.
	navigate.dialog_until_text(text:encode("PROF.OAK"))
	scenario.wait(30) -- settle: a tap into a just-drawn menu is swallowed
	navigate.choose(text:encode("PROF.OAK"))

	-- OpenOaksPC: "Accessed OAK's PC." → "Rate my #DEX?" → YES/NO. The cursor
	-- opens on YES (wCurrentMenuItem = 0), which is the branch that reaches
	-- DisplayDexRating at all.
	navigate.dialog_until_text(text:encode("YES"))
	scenario.wait(30)
	navigate.choose(text:encode("YES"))

	-- DisplayDexRating: DexCompletionText ("#DEX comp-/letion is:" → the two
	-- decimals → "PROF.OAK's/Rating:") then the band text. THE NEXT LINE IS THE
	-- ASSERTION: only DexRatingText_Own50To59 contains this phrase, so reaching
	-- it proves the threshold walk landed on the band 55 owned belongs to.
	navigate.dialog_until_text(text:encode("least 50 species"))
	scenario.wait(60) -- let the page finish revealing before the dump

	scenario.exec(function()
		dump.write("dex_rating_oak_pc", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "DisplayDexRating via Oak's PC with 55 owned / 70 seen; " ..
				"band DexRatingText_Own50To59 selected and printed, " ..
				"hDexRatingNumMonsSeen=70 hDexRatingNumMonsOwned=55",
		})
	end)
end)
