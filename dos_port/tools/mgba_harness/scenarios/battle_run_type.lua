---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- battle_run_type — the LAST battle type in the per-battle-type box.
-- BATTLE_TYPE_RUN (3) is unused in the shipped game, so its arms are faithful
-- but were reachable by nothing; this scenario reaches them on both sides.
--
-- THE PLAN RECORDED THIS AS BLOCKED ON CROSS-EMULATOR STAGING. That diagnosis
-- was wrong in a specific, cheap way: the earlier attempt pinned
-- wBattleAndStartSavedMenuItem, but pret's .handleUnusedBattle reads
-- wCurrentMenuItem (core.asm:2257), so the pin never selected RUN and the arm
-- did exactly what pret says it does for every OTHER selection — print
-- "Hurry, get away!" and redraw the menu. It looked like a staging failure and
-- was a wrong-variable failure. Real key presses fix it; no pin is needed.
--
-- NAVIGATION, read out of pret rather than guessed. The battle menu builds
-- wCurrentMenuItem as ROW plus 2 IF IN THE RIGHT COLUMN (core.asm:2215-2217):
--     FIGHT  PKMN       item 0   item 2
--     ITEM   RUN        item 1   item 3
-- so RUN is row 1 + column 2 = item 3, and DOWN then RIGHT is the whole
-- navigation. Item 3 is the ONLY value .handleUnusedBattle acts on.
--
-- IT IS RNG-FREE, which is what makes it comparable across two emulators that
-- share no RNG stream. TryRunningFromBattle tests
--     cp BATTLE_TYPE_RUN
--     jp z, .canEscape
-- BEFORE the speed comparison and before Random is ever called, so the run
-- always succeeds. Nothing here is a roll.
--
-- LANDMARK: "Got away safely!" on the tilemap AND wIsInBattle back to 0. The
-- text alone would catch the message mid-battle, before the teardown; the port
-- gate's call returns only after .battleFinished has run EndOfBattle, so both
-- sides must land POST-TEARDOWN. That is battle_oldman_result's rule, applied
-- deliberately rather than rediscovered.

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

local BATTLE_TYPE_RUN = 3      -- constants/battle_constants.asm

scenario.run(function()
	battle.enter_wild(sym, text)

	local btype = sym:addr("wBattleType")
	local inBattle = sym:addr("wIsInBattle")
	local fight = text:encode("FIGHT")
	local gotAway = text:encode("Got away safely!")

	-- A dismisses "appeared!"; the battle menu then draws itself.
	input.tap("A", 2, 8)

	-- Phase 1 — hold the type until the menu is up. Re-asserted every frame for
	-- battle_safari's reason: the frame on which the ROM reads wBattleType
	-- differs between the emulators, and it must be set BEFORE StartBattle's
	-- send-out decision or the player's mon goes out and the two sides
	-- photograph different phases.
	local menuUp = false
	for i = 1, 3600 do
		scenario.exec(function()
			emu:write8(btype, BATTLE_TYPE_RUN)
		end)
		if navigate.tilemap():find(fight, 1, true) then
			menuUp = true
			break
		end
		if i % 4 == 0 then
			input.tap("A", 2, 6)
		end
	end
	assert(menuUp, "battle_run_type: the battle menu never drew")

	scenario.wait(30) -- settle: menu parked in HandleMenuInput

	-- Phase 2 — the navigation. No pin substitutes for it; see the header.
	input.tap("DOWN", 2, 10)    -- FIGHT -> ITEM (row 1)
	input.tap("RIGHT", 2, 10)   -- left column -> right column (+2) = RUN, item 3
	input.tap("A", 2, 10)       -- take it

	-- Phase 3 — walk the escape text and stop once the battle has torn down.
	-- The wBattleType pin STOPS here: the last read of it is TryRunningFromBattle's
	-- `cp BATTLE_TYPE_RUN`, which has already happened, and battle_oldman_result
	-- measured that re-asserting past resolution pins the golden into state the
	-- flow has just cleared.
	local dumped = false
	for _ = 1, 600 do
		local tilemap = navigate.tilemap()
		local stillInBattle = scenario.read_range(inBattle, 1):byte(1)
		if tilemap:find(gotAway, 1, true) and stillInBattle == 0 then
			scenario.exec(function()
				dump.write("battle_run_type", dump.standard_regions(sym), {
					frame = scenario.frame(),
					description = "BATTLE_TYPE_RUN taken to its end: the battle " ..
						"menu's RUN item (wCurrentMenuItem 3) routed through " ..
						".handleUnusedBattle to BattleMenu_RunWasSelected, and " ..
						"TryRunningFromBattle's BATTLE_TYPE_RUN arm escaping " ..
						"without a speed check or a Random call",
				})
			end)
			dumped = true
			break
		end
		input.tap("A", 2, 4)
	end

	assert(dumped, "battle_run_type: never reached the post-teardown escape state " ..
		"(\"Got away safely!\" with wIsInBattle back to 0) — RUN was not selected " ..
		"(.handleUnusedBattle acts on wCurrentMenuItem == 3 only), or the escape " ..
		"did not run")
end)
