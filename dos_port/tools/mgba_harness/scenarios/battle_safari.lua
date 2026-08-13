---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- battle_safari — golden for the port's DEBUG_BATTLE_SAFARI=1 gate. The first
-- scenario to RENDER the Safari battle menu, and the witness for everything
-- battle plan 4d has landed:
--   * the SAFARI_BATTLE_MENU_TEMPLATE box (full-width, not the action box);
--   * the BALL / BAIT / THROW ROCK / RUN labels;
--   * the two Safari cursor columns (pret ld b,$1 and ld b,$d);
--   * the remaining-ball counter (pret hlcoord 7,14 + PrintNumber).
--
-- IT IS A RENDERED SCENARIO, unlike battle_oldman / battle_pikachu, because what
-- the Safari branches produce IS the screen. The compared tilemap is the point;
-- the differ's GB-window projection (col 10, row 3) lines the two sides up.
--
-- WHAT IS PINNED, AND WHY.
--   1. wBattleType = BATTLE_TYPE_SAFARI, written EVERY frame until the menu is
--      up. Written once it would be a race: the frame on which DisplayBattleMenu
--      reads it differs between the emulators. Re-asserting is idempotent.
--      It must also be set EARLY -- before StartBattle's send-out check -- or
--      the ROM sends the player's mon out and the two sides photograph
--      different phases (that is exactly what cost battle_oldman a full
--      iteration; see battle-golden-harness-cannot-stage-special-battle-types).
--   2. wNumSafariBalls = 30, pret's count at zone entry. The menu PRINTS this
--      number, so an unpinned value would put whatever the debug new-game left
--      into a compared tilemap.
--
-- THE PLAYER'S MON IS NEVER SENT OUT and that is correct: pret StartBattle
-- (core.asm:171-174) sends out only when wBattleType == 0. Red's back pic is
-- still on screen because LoadPlayerBackPic runs in the battle INTRO, before
-- that decision -- it is the sent-out mon's pic that never replaces it.
--
-- LANDMARK: the word "BAIT" on the tilemap. It cannot be an initial state --
-- no other battle screen contains it -- and unlike a WRAM byte it proves the
-- Safari menu actually DREW rather than merely being selected.

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local gbtext = require("lib.gbtext")
local input = require("lib.input")
local dump = require("lib.dump")
local scenario = require("lib.scenario")
local navigate = require("lib.navigate")
local battle = require("lib.battle")

local sym = symbols.load()
local text = gbtext.load()
navigate.init(sym, text)

local BATTLE_TYPE_SAFARI = 2   -- constants/battle_constants.asm
local SAFARI_BALLS = 30        -- pret's count on Safari Zone entry

scenario.run(function()
	battle.enter_wild(sym, text)

	local btype = sym:addr("wBattleType")
	local balls = sym:addr("wNumSafariBalls")
	local bait = text:encode("BAIT")

	-- A dismisses "appeared!"; the menu then draws itself.
	input.tap("A", 2, 8)

	local dumped = false
	for i = 1, 3600 do
		scenario.exec(function()
			if dumped then return end
			-- Pins 1 and 2, re-asserted every frame (see the header).
			emu:write8(btype, BATTLE_TYPE_SAFARI)
			emu:write8(balls, SAFARI_BALLS)
		end)
		if navigate.tilemap():find(bait, 1, true) then
			scenario.wait(30) -- settle: menu parked in its input loop
			scenario.exec(function()
				emu:write8(btype, BATTLE_TYPE_SAFARI)
				emu:write8(balls, SAFARI_BALLS)
				dump.write("battle_safari", dump.standard_regions(sym), {
					frame = scenario.frame(),
					description = "Wild PIDGEY L13 encounter forced to " ..
						"BATTLE_TYPE_SAFARI: the Safari battle menu is drawn — " ..
						"full-width box, BALL/BAIT/THROW ROCK/RUN labels, the " ..
						"remaining-ball counter, and the cursor in the Safari " ..
						"left column. No player mon is sent out, as pret " ..
						"StartBattle:171 skips the send-out for any non-zero " ..
						"wBattleType",
				})
			end)
			dumped = true
			break
		end
		-- Tap sparingly to walk the intro text without swallowing the menu.
		if i % 4 == 0 then
			input.tap("A", 2, 6)
		end
	end
	assert(dumped, "battle_safari: the Safari menu never drew — the wBattleType " ..
		"pin did not take before DisplayBattleMenu read it, or the battle never " ..
		"reached its menu")
end)
