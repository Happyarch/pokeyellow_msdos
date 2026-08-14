---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- battle_pikachu_result — the RESULT/EXIT half of the per-battle-type box, for
-- BATTLE_TYPE_PIKACHU (the Prof. Oak tutorial). battle_pikachu (id 70) stops at
-- the rename inside the menu; this one follows the same battle to its end.
--
-- It is battle_oldman_result with one constant changed, and that is the point:
-- DisplayBattleMenu dispatches OLD_MAN and PIKACHU to the SAME
-- .doSimulatedMenuInput, and ItemUseBall routes BOTH to .oldManCaughtMon
-- (item_effects.asm:529-532), so the same landmark and the same pins apply.
--
-- WHAT MAKES IT A BRANCH WITNESS RATHER THAN AN END-OF-BATTLE WITNESS.
-- DisplayBattleMenu.doSimulatedMenuInput auto-selects ITEM (pret core.asm:2133,
-- `ld a,$2`), .simulatedInputBattle throws a POKE BALL, and ItemUseBall sends
-- BOTH tutorial types to .oldManCaughtMon (item_effects.asm:529-532) — the
-- branch that CATCHES the mon but does NOT give it to the player: no
-- IndexToPokedex, no party add. So at the landmark the party and the dex must be
-- UNCHANGED while the ball is consumed. A port that took the normal catch path
-- would hand the player a PIDGEY and fail on wPartyData AND wPokedex.
--
-- THE LANDMARK is wBattleResult == 2, the same one ball_catch polls.
-- pret's UseBagItem.returnAfterCapturingMon (core.asm:2393-2399) sets
-- wBattleResult=2 and `scf` together, and .displaySafariZoneBattleMenu is
-- `call DisplayBattleMenu / ret c` — so a capture exits the battle early and the
-- SAFARI tail after it is reached only when carry is CLEAR.
--
-- The pins are battle_oldman's, for its reasons: wBattleType re-asserted every
-- frame so the menu takes the simulated-input branch whichever frame it opens
-- on, and the enemy kept inert (65535 HP + sleep) because an enemy turn would
-- put a damage ROLL into compared WRAM and the two emulators do not share an RNG
-- stream.

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

local BATTLE_TYPE_PIKACHU = 4      -- constants/battle_constants.asm
local SLEEP_TURNS = 7

scenario.run(function()
	battle.enter_wild(sym, text)

	-- A dismisses "appeared!"; send-out runs unattended; the menu then parks.
	input.tap("A", 2, 8)

	local name = sym:addr("wPlayerName")
	local btype = sym:addr("wBattleType")

	-- THE POLL MUST DRIVE THE TEXT, and that is the difference from
	-- battle_oldman: that scenario dumps DURING the menu and never needs input,
	-- while the capture tail here runs only AFTER the "All right! / PIDGEY was
	-- caught!" message is dismissed. Measured: a poll with no taps sat on that
	-- message for 3600 frames and wBattleResult never left 0, even though the
	-- catch text was plainly on screen.
	local dumped = false
	for _ = 1, 400 do
		scenario.exec(function()
			if dumped then return end
			-- THE PINS STOP THE MOMENT THE BATTLE RESOLVES, and that is not
			-- tidiness -- it is required. Re-asserting them every frame past the
			-- teardown made the golden hold wBattleType $01 and wEnemyMonMaxHP
			-- $FFFF where the port (which pins once, at gate entry) correctly
			-- held $00 and the real $0024: EndOfBattle clears both, and a pin
			-- that outlives the battle re-creates state the flow just tore down.
			-- Measured as exactly those 2 unmasked fields before this guard.
			local result = emu:read8(sym:addr("wBattleResult"))
			if result == 0 then
			-- Pin 1, re-asserted: make the menu take the simulated-input branch
			-- whichever frame it opens on.
			emu:write8(btype, BATTLE_TYPE_PIKACHU)
			-- Pin 2: keep the enemy inert. SLEEP ONLY -- battle_oldman also pins
			-- HP/MaxHP to 65535 and that pin must NOT be carried here. The port
			-- gate pins those once at entry and the enemy LOAD overwrites them
			-- with the spec 36, so a per-frame pin on this side kept the golden
			-- at $FFFF where the port correctly held $0024 -- measured as exactly
			-- that one unmasked field. Sleep is what removes the enemy turn; the
			-- HP value was belt-and-braces.
			emu:write8(sym:addr("wEnemyMonStatus"), SLEEP_TURNS)
			end
			-- THE DUMP: the capture tail has run. wBattleResult ($CF0B) is NOT in
			-- the compared regions, so it is a landmark only -- the evidence is
			-- the party/dex/bag state it selects.
			-- NO wIsInBattle CLAUSE, deliberately. Measured: requiring
			-- wIsInBattle ~= 0 AND wBattleResult == 2 together never fired --
			-- the window between the capture tail and EndOfBattle zeroing
			-- wIsInBattle is a few frames wide and the A-taps step past it. Both
			-- sides therefore land AFTER the teardown (the port gate calls
			-- EndOfBattle before dumping), which removes the race.
			if result ~= 2 then return end
			dump.write("battle_pikachu_result", dump.standard_regions(sym), {
				frame = scenario.frame(),
				description = "the PIKACHU tutorial's capture tail: ItemUseBall took " ..
					".oldManCaughtMon, so the mon is caught but NOT given to the " ..
					"player -- party and dex unchanged, ball consumed, " ..
					"wBattleResult 2 and the battle exiting on pret's scf",
			})
			dumped = true
		end)
		if dumped then break end
		input.tap("A", 2, 2)
	end

	assert(dumped, "battle_pikachu_result: wBattleResult never reached 2 — the " ..
		"tutorial's scripted ball throw did not reach UseBagItem's capture tail")
end)
