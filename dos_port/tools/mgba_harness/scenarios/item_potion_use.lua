---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- item_potion_use — golden for the port's DEBUG_ITEMUSE gate at
-- AUTOKEY_DUMP_FRAME=700 (fidelity plan Stage 1c, differ class "datastruct":
-- WRAM game data only, no video compare).
--
-- The port gate is the one item gate that drives the REAL UI on its own side
-- (AUTOKEY_ITEMUSE script): START → ITEM → POTION → USE → mon 0 (seeded to 1 HP)
-- → dismiss the heal message → ANTIDOTE → USE → mon 0 (status-free) → "It won't
-- have any effect." refusal → dismiss → dump over the reopened bag list. This
-- scenario mirrors THE WHOLE script, refusal included — the refusal mutates no
-- compared WRAM, but the flows it runs (second party-menu pass) are what the
-- transient regions (wLoadedMon) last saw, so skipping it would diverge there.
--
-- Seeds mirror the gate exactly: PrepareNewGameDebug (= seed.debug_new_game),
-- then party mon 0's current HP knocked to 1 (big-endian word, hi byte first).
-- POTION qty 1 is already the seeded bag's slot 0; ANTIDOTE ×3 is slot 1.
--
-- Pins: wPartyData mon-0 HP (1 → 21, the POTION's +20); wBagItems (POTION slot
-- removed — 15 items, ANTIDOTE first, and the ANTIDOTE NOT consumed).

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

scenario.run(function()
	navigate.boot_to_main_menu()
	navigate.new_game_to_bedroom()

	scenario.exec(function()
		seed.debug_new_game(sym, text:encode(seed.PLAYER_NAME))
		-- mon 0 (SNORLAX) to 1 HP: current HP is a big-endian word at struct +1
		emu:write8(sym:addr("wPartyMon1HP"), 0)
		emu:write8(sym:addr("wPartyMon1HP") + 1, 1)
	end)

	navigate.open_start_menu()
	navigate.choose(text:encode("ITEM"))
	navigate.wait_for_text(text:encode("POTION"))
	scenario.wait(30) -- settle: a tap into a just-drawn list is swallowed (joypad flush)
	navigate.choose(text:encode("POTION"))
	navigate.ensure_text("A", text:encode("USE")) -- USE/TOSS submenu (re-tap if swallowed)
	scenario.wait(30)
	navigate.choose(text:encode("USE"))
	navigate.wait_for_text(text:encode("Use item on which"))
	scenario.wait(30)
	navigate.choose(text:encode("SNORLAX"), nil, 1)
	-- "SNORLAX recovered by  20!" ends in `done` — NO ▼ (F-14 semantics), the box
	-- just waits for A; the dismiss retries because a tap during the HP-bar
	-- animation is swallowed.
	navigate.wait_for_text(text:encode("recovered"))
	navigate.dismiss_text(text:encode("recovered"))

	-- back in the bag list (POTION consumed, ANTIDOTE is now slot 0): the refusal leg
	navigate.wait_for_text(text:encode("ANTIDOTE"))
	scenario.wait(30)
	navigate.choose(text:encode("ANTIDOTE"))
	navigate.ensure_text("A", text:encode("USE"))
	scenario.wait(30)
	navigate.choose(text:encode("USE"))
	navigate.wait_for_text(text:encode("Use item on which"))
	scenario.wait(30)
	navigate.choose(text:encode("SNORLAX"), nil, 1)
	-- "It won't have any effect." ends in `prompt` — a real ▼ this time
	navigate.wait_for_text(text:encode("effect"))
	navigate.dismiss_text(text:encode("effect"))
	scenario.wait(30) -- settle over the reopened bag list

	scenario.exec(function()
		dump.write("item_potion_use", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "POTION used on party mon 0 at 1 HP (heals to 21) then the " ..
				"ANTIDOTE refusal leg, mirroring the gate's AUTOKEY_ITEMUSE script; " ..
				"dump over the reopened bag list (POTION gone, ANTIDOTE kept)",
		})
	end)
end)
