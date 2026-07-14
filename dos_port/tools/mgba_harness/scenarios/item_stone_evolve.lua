---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- item_stone_evolve — golden for the port's DEBUG_ITEMSTONE gate (fidelity plan
-- Stage 1c, differ class "datastruct": WRAM game data only, no video compare).
--
-- Mirrors RunStoneTest's seeds exactly (src/debug/debug_dump.asm):
--   * PrepareNewGameDebug (= seed.debug_new_game)
--   * party slot 0's SPECIES BYTE (list + struct) becomes VULPIX ($52) — only that
--     byte; the rest of the struct stays the seeded SNORLAX's (level 80, its EXP,
--     its stats, its HM moves, its catch-rate byte $19). The nickname stays
--     "SNORLAX" too, which matches VULPIX's pre-evolution standard-name check
--     failing — but see below: evolution then renames to the NEW standard name
--     only if the nick equals the OLD species' standard name (it is "SNORLAX",
--     the old species is VULPIX, so both sides keep/rename identically by running
--     the same code from the same bytes).
--   * bag slot 0 becomes FIRE_STONE ($20), qty 1 — replacing the seeded POTION pair
-- then drives the REAL flow the gate's direct `call UseItem` short-circuits:
-- START → ITEM → FIRE STONE → USE → party mon 0 → evolution → dismissed.
--
-- Pins: wPartyData mon-0 species/types/stats as the real TryEvolvingMon leaves
-- them (NINETALES $53; catch-rate byte must SURVIVE as $19 — the Gen-2 held-item
-- slot); species list entry; wBagItems (stone consumed); wPokedex owned bit #38.

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

local FIRE_STONE, VULPIX = 0x20, 0x52 -- the gate's ITEMSTONE_ID / ITEMSTONE_SPECIES defaults

scenario.run(function()
	navigate.boot_to_main_menu()
	navigate.new_game_to_bedroom()

	scenario.exec(function()
		seed.debug_new_game(sym, text:encode(seed.PLAYER_NAME))
		-- party slot 0 becomes the mon under test — species byte only, exactly as
		-- RunStoneTest pokes it (list + struct)
		emu:write8(sym:addr("wPartySpecies"), VULPIX)
		emu:write8(sym:addr("wPartyMon1"), VULPIX)
		-- bag slot 0 = the stone, qty 1 (wNumBagItems stays 16)
		emu:write8(sym:addr("wBagItems"), FIRE_STONE)
		emu:write8(sym:addr("wBagItems") + 1, 1)
	end)

	navigate.open_start_menu()
	navigate.choose(text:encode("ITEM"))
	navigate.wait_for_text(text:encode("FIRE STONE"))
	scenario.wait(30) -- settle: a tap into a just-drawn list is swallowed (joypad flush)
	navigate.choose(text:encode("FIRE STONE"))
	navigate.ensure_text("A", text:encode("USE")) -- USE/TOSS submenu (re-tap if swallowed)
	scenario.wait(30)
	navigate.choose(text:encode("USE"))
	-- party menu (_PartyMenuItemUseText) → mon 0 (cursor starts there; it sits one
	-- row below the nickname)
	navigate.wait_for_text(text:encode("Use item on which"))
	scenario.wait(30)
	navigate.choose(text:encode("SNORLAX"), nil, 1)
	-- "What? SNORLAX is evolving!" runs the animation unattended (`done`, no ▼),
	-- then "SNORLAX evolved into NINETALES!" — advance to it, dismiss it (the
	-- dismiss retries: a tap mid-animation is swallowed), then the bag list
	-- redraws by itself (ANTIDOTE promoted to slot 0, the stone pair gone).
	navigate.dialog_until_text(text:encode("evolved"))
	navigate.dismiss_text(text:encode("evolved"))
	navigate.wait_for_text(text:encode("ANTIDOTE"))
	scenario.wait(60) -- settle over the reopened bag list

	scenario.exec(function()
		dump.write("item_stone_evolve", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "FIRE STONE used on party mon 0 (SNORLAX struct with the species " ..
				"byte poked to VULPIX, mirroring the gate) through the real bag flow; " ..
				"evolved to NINETALES, stone consumed, dex owned bit #38 set",
		})
	end)
end)
