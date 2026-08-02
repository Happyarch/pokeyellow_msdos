---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- item_pp_restore — golden for the port's DEBUG_ITEMPP gate (items plan Stage 11,
-- differ class "datastruct": WRAM game data only, no video compare).
--
-- Mirrors RunPPRestoreTest's seeds exactly (src/debug/debug_dump.asm):
--   * PrepareNewGameDebug (= seed.debug_new_game)
--   * bag slot 0 becomes ETHER ($50), qty 1 — replacing the seeded POTION pair
--   * party mon 0's move-slot-0 PP byte is drained to 1 (ITEMPP_DRAIN), PP-Up bits
--     deliberately clear so ETHER's +10 is unambiguous and the Max-Ether BUG{}
--     path stays out of this scenario
-- then drives the REAL flow the gate's direct `call UseItem` short-circuits:
-- START -> ITEM -> ETHER -> USE -> party mon 0 -> move slot 0 -> "PP was
-- restored." -> dismissed, bag list reopened with the ETHER consumed.
--
-- Pins: wPartyData mon-0 PP (slot 0 = 1 + 10 = 11, slots 1-3 untouched);
-- wBagItems (slot 0 consumed: ANTIDOTE promoted).
--
-- WHY THIS SCENARIO EXISTS: nothing else in the suite reaches ItemUsePPRestore.
-- `move_selection` drives the REGULAR battle move menu (wMoveMenuType = 0); the PP
-- items are the only caller of the type-2 relearn-shaped menu outside a battle, so
-- a green suite without this proves nothing about the handler.
--
-- Stays in the bedroom, as item_tm_teach does: the datastruct class compares no
-- tilemap/vram/oam, so walking to Pallet would only add NPC-wander nondeterminism.

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

local ETHER, QTY, DRAIN = 0x50, 1, 1 -- the gate's ITEMPP_ID / ITEMPP_DRAIN defaults

scenario.run(function()
	navigate.boot_to_main_menu()
	navigate.new_game_to_bedroom()

	scenario.exec(function()
		seed.debug_new_game(sym, text:encode(seed.PLAYER_NAME))
		-- bag slot 0 -> the PP item under test (the gate pokes the pair in place;
		-- wNumBagItems stays 16)
		emu:write8(sym:addr("wBagItems"), ETHER)
		emu:write8(sym:addr("wBagItems") + 1, QTY)
		-- drain mon 0's move-slot-0 PP, exactly as the gate does. Without this the
		-- move is already at full PP and .restorePP takes its "no effect" branch —
		-- a real branch, but not the one under test.
		emu:write8(sym:addr("wPartyMon1PP"), DRAIN)
	end)

	navigate.open_start_menu()
	navigate.choose(text:encode("ITEM"))
	navigate.wait_for_text(text:encode("ETHER")) -- bag list drawn, ETHER in slot 0
	scenario.wait(30) -- settle: a tap into a just-drawn list is swallowed (joypad flush)
	navigate.choose(text:encode("ETHER"))
	navigate.ensure_text("A", text:encode("USE")) -- USE/TOSS submenu (re-tap if swallowed)
	scenario.wait(30)
	navigate.choose(text:encode("USE"))
	-- party menu (_PartyMenuItemUseText) -> mon 0 (the cursor sits one row below
	-- the nickname, as in item_tm_teach / item_stone_evolve)
	navigate.wait_for_text(text:encode("Use item on which"))
	scenario.wait(30)
	navigate.choose(text:encode("SNORLAX"), nil, 1)
	-- "Restore PP of / which technique?" then the type-2 move menu. The menu opens
	-- on wPlayerMoveListIndex + 1, and ItemUsePPRestore zeroes that byte immediately
	-- before calling MoveSelectionMenu, so the cursor already sits on move slot 0
	-- (FLY, the drained one) — choose() confirms rather than moves.
	navigate.dialog_until_text(text:encode("which technique?"))
	scenario.wait(30)
	navigate.choose(text:encode("FLY"))
	-- "PP was restored." (prompt -> waits on A), then the bag list redraws by
	-- itself with ANTIDOTE promoted to slot 0 and the ETHER pair gone.
	navigate.wait_for_text(text:encode("PP was restored"))
	navigate.dismiss_text(text:encode("PP was restored"))
	navigate.wait_for_text(text:encode("ANTIDOTE"))
	scenario.wait(60) -- settle over the reopened bag list

	scenario.exec(function()
		dump.write("item_pp_restore", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "ETHER used on party mon 0's move slot 0 (PP pre-drained to 1) " ..
				"through the real bag flow; slot-0 PP restored to 11, ETHER consumed " ..
				"from bag slot 0",
		})
	end)
end)
