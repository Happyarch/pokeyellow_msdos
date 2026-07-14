---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- item_tm_teach — golden for the port's DEBUG_ITEMTM gate (fidelity plan Stage 1c,
-- differ class "datastruct": WRAM game data only, no video compare).
--
-- Mirrors RunTMHMTest's seeds exactly (src/debug/debug_dump.asm):
--   * PrepareNewGameDebug (= seed.debug_new_game)
--   * bag slot 0 becomes TM06 TOXIC ($CE), qty 1 — replacing the seeded POTION pair
--   * party mon 0 (SNORLAX) move slots 2-4 zeroed, PP left alone (the gate zeroes
--     only the move bytes; ItemUseTMHM writes the taught move's PP itself)
-- then drives the REAL flow the gate's direct `call UseItem` short-circuits:
-- START → ITEM → TM06 → USE → yes → party mon 0 → "learned" message → dismissed.
--
-- Pins: wPartyData mon-0 moves (TOXIC $5C into slot 2) + PP (slot-2 PP = TOXIC's
-- base 10, others untouched); wBagItems (slot 0 consumed: 15 items, ANTIDOTE first).
--
-- Stays in the bedroom: the datastruct class compares no tilemap/vram/oam, and the
-- walk to Pallet would only add NPC-wander nondeterminism for nothing.

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local gbtext = require("lib.gbtext")
local input = require("lib.input")
local dump = require("lib.dump")
local scenario = require("lib.scenario")
local seed = require("lib.seed")
local navigate = require("lib.navigate")

local sym = symbols.load()
local text = gbtext.load()
navigate.init(sym, text)

local TM06, QTY = 0xCE, 1 -- the gate's ITEMTM_ID default (TM_06 = TOXIC)

scenario.run(function()
	navigate.boot_to_main_menu()
	navigate.new_game_to_bedroom()

	scenario.exec(function()
		seed.debug_new_game(sym, text:encode(seed.PLAYER_NAME))
		-- bag slot 0 -> the machine under test (RunTMHMTest pokes the pair in place;
		-- wNumBagItems stays 16)
		emu:write8(sym:addr("wBagItems"), TM06)
		emu:write8(sym:addr("wBagItems") + 1, QTY)
		-- free mon 0's move slots 2-4 (the seeded SNORLAX knows four HMs, which
		-- LearnMove refuses to delete — the gate clears them so the teach lands in
		-- an empty slot; PP bytes deliberately untouched, mirroring the gate)
		local moves = sym:addr("wPartyMon1Moves")
		emu:write8(moves + 1, 0)
		emu:write8(moves + 2, 0)
		emu:write8(moves + 3, 0)
	end)

	navigate.open_start_menu()
	navigate.choose(text:encode("ITEM"))
	navigate.wait_for_text(text:encode("TM06")) -- bag list drawn, TM in slot 0
	scenario.wait(30) -- settle: a tap into a just-drawn list is swallowed (joypad flush)
	navigate.choose(text:encode("TM06"))
	navigate.ensure_text("A", text:encode("USE")) -- USE/TOSS submenu (re-tap if swallowed)
	scenario.wait(30)
	navigate.choose(text:encode("USE"))
	-- "Booted up a TM!" (▼) → "It contained TOXIC! / Teach TOXIC to a #MON?" +
	-- YES/NO box (TWO_OPTION_MENU, cursor on the YES default) → party menu
	-- (_PartyMenuUseTMText). Advance state-aware: answer whatever is actually on
	-- screen (A on a ▼, A on the visible YES/NO) and key on the party-menu
	-- prompt as the landing state — waiting to OBSERVE "YES" is racy: a ▼ tap's
	-- release can overlap the box opening and answer it in the same motion
	-- (measured: dialog_until_text("YES") sailed into the party menu).
	local teach = text:encode("Teach to which")
	local yes = text:encode("YES")
	local arrow = text:encode("▼")
	local limit = scenario.frame() + 7200
	while true do
		local tm = navigate.tilemap()
		if tm:find(teach, 1, true) then
			break
		elseif tm:find(yes, 1, true) or tm:find(arrow, 1, true) then
			input.tap("A", 2, 8)
		else
			scenario.wait(4)
		end
		assert(scenario.frame() < limit, "item_tm_teach: never reached the TM party menu")
	end
	-- mon 0 (the party cursor sits one row below the nickname)
	scenario.wait(30) -- settle the freshly drawn party menu
	navigate.choose(text:encode("SNORLAX"), nil, 1)
	-- "SNORLAX learned TOXIC!" parks over the party menu with a ▼ (measured —
	-- _LearnedMove1Text itself is text_end, but the print path waits on A here).
	-- Dismiss it; the flow then returns to the bag list by itself, with ANTIDOTE
	-- promoted to slot 0 and the TM06 pair gone — the stable post-flow state.
	navigate.wait_for_text(text:encode("learned"))
	navigate.dismiss_text(text:encode("learned"))
	navigate.wait_for_text(text:encode("ANTIDOTE"))
	scenario.wait(60) -- settle

	scenario.exec(function()
		dump.write("item_tm_teach", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "TM06 TOXIC taught to party mon 0 (SNORLAX, move slots 2-4 " ..
				"pre-cleared) through the real bag flow; TM consumed from bag slot 0",
		})
	end)
end)
