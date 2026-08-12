---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- battle_pikachu — golden for the port's DEBUG_BATTLE_PIKACHU=1 gate (differ
-- class "datastruct": WRAM game data only). The must-hit Pikachu-battle
-- scenario battle plan 4a has wanted since 5a768070 landed the slice.
--
-- IT IS THE SAME CODE PATH AS battle_oldman, and that is deliberate.
-- DisplayBattleMenu dispatches BATTLE_TYPE_OLD_MAN and BATTLE_TYPE_PIKACHU to
-- the SAME .doSimulatedMenuInput (pret core.asm:2094-2098); the only difference
-- is which of the two names is copied over wPlayerName.
--
-- SO THIS WITNESSES THE HALF battle_oldman STRUCTURALLY CANNOT. The
-- tutorial-name fix (dbe6e797b) corrected TWO strings. battle_oldman covers
-- str_oldman_name, whose 11-byte tail is data-adjacency ("PRO", the start of
-- .profOakName). str_profoak_name is the FRAGILE one: its tail is pret CODE --
--   .profOakName + 11 = 8F 91 8E 85 E8 8E 80 8A 50 | FA 2D
-- where FA 2D is the first two bytes of the instruction that follows the
-- literal (ld a, [wBattleAndStartSavedMenuItem] = fa 2d cc). The generator
-- carries a warning that those two bytes will silently drift if upstream ever
-- edits DisplayBattleMenu.handleBattleMenuInput. Until this scenario existed
-- that warning had no enforcement; now a drift fails the suite.
--
-- WHAT IS WITNESSED: wPlayerName, which the differ ALREADY compares in full as
-- a standard region, so this scenario adds NO scenario-local dump rows.
--
-- THERE IS NOTHING TO PRESS. .doSimulatedMenuInput is reached from wBattleType
-- alone; it walks its own cursor with two DelayFrames(20) and takes the ITEM
-- branch. No input is driven into the menu and no roll exists in the path.
--
-- WHAT IS PINNED, AND WHY.
--   1. wBattleType = BATTLE_TYPE_PIKACHU, written EVERY frame until the rename
--      is seen. Written once it would be a race: the frame on which the menu
--      opens differs between the two emulators, and the value only matters at
--      the instant DisplayBattleMenu reads it.
--   2. ENEMY HP 65535 + ASLEEP, battle_thrash's pin for its reason: an enemy
--      turn puts a damage ROLL into wBattleMon, which is compared, and the two
--      emulators do not share an RNG stream.
--
-- THE PLAYER'S MON IS NEVER SENT OUT, and that is correct rather than a gap.
-- pret StartBattle (core.asm:171-174) sends out only when wBattleType == 0, so
-- wBattleMon stays ZERO for the whole battle on both sides. The port harness
-- reproduces that with a matching guard (debug_dump.asm .skipPlayerSendOut);
-- see memory battle-golden-harness-cannot-stage-special-battle-types.
--
-- THE LANDMARK CANNOT BE AN INITIAL STATE: wPlayerName[0] is 'R' ($91) of the
-- seeded "RED" identity until the rename lands, and $8F is 'P'.
--
-- THE WINDOW CLOSES. ItemUseBall.oldManBattle copies wGrassRate BACK over
-- wPlayerName (the RESTORE half of the Missingno. pair, not the write half),
-- which erases the evidence. The two DelayFrames(20) are the margin.

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
local PROFOAK_FIRST_BYTE = 0x8F    -- 'P' of "PROF.OAK" (charmap)
local RED_FIRST_BYTE = 0x91        -- 'R' of the seeded "RED" identity
local ENEMY_HP = { 0xFF, 0xFF }    -- 65535, big-endian (Gen-1 byte order)
local SLEEP_TURNS = 7
-- The 11 bytes pret actually copies, read from pokeyellow.gbc at 0f:4fef
-- (file offset 0x3CFEF): "PROF.OAK" + @ + the two CODE bytes that follow.
local EXPECT_NAME = { 0x8F, 0x91, 0x8E, 0x85, 0xE8, 0x8E, 0x80, 0x8A,
                      0x50, 0xFA, 0x2D }

scenario.run(function()
	battle.enter_wild(sym, text)

	-- A dismisses "appeared!"; the menu then parks.
	input.tap("A", 2, 8)

	local name = sym:addr("wPlayerName")
	local btype = sym:addr("wBattleType")

	-- Sanity BEFORE the pin: the identity really is the seeded "RED", so the
	-- landmark below is a transition rather than something already true.
	scenario.exec(function()
		assert(emu:read8(name) == RED_FIRST_BYTE,
			("battle_pikachu: expected the seeded RED identity before the rename, " ..
			 "got $%02X at wPlayerName[0] — the landmark would not be a landmark")
				:format(emu:read8(name)))
	end)

	local dumped = false
	for _ = 1, 3600 do
		scenario.exec(function()
			if dumped then return end
			emu:write8(btype, BATTLE_TYPE_PIKACHU)
			local hp = sym:addr("wEnemyMonHP")
			local mx = sym:addr("wEnemyMonMaxHP")
			for i, b in ipairs(ENEMY_HP) do
				emu:write8(hp + i - 1, b)
				emu:write8(mx + i - 1, b)
			end
			emu:write8(sym:addr("wEnemyMonStatus"), SLEEP_TURNS)
			-- THE DUMP: the rename is visible, and the battle is live.
			--
			-- DO NOT ADD `wBattleMonSpecies ~= 0` HERE. battle_oldman measured
			-- that: the assert fires with the tutorial's catch text on screen,
			-- because a special battle never sends the player's mon out at all.
			if emu:read8(sym:addr("wIsInBattle")) == 0 then return end
			if emu:read8(name) ~= PROFOAK_FIRST_BYTE then return end
			-- Require the WHOLE name: the tail IS the point of this scenario.
			local got = emu:readRange(name, #EXPECT_NAME)
			for i = 1, #EXPECT_NAME do
				if got:byte(i) ~= EXPECT_NAME[i] then return end
			end
			dump.write("battle_pikachu", dump.standard_regions(sym), {
				frame = scenario.frame(),
				description = "DisplayBattleMenu.doSimulatedMenuInput renamed the " ..
					"player to the Prof. Oak tutorial identity: wPlayerName holds " ..
					"the 11 bytes pret copies from the 9-byte .profOakName literal, " ..
					"so the tail is the two CODE bytes that follow it (FA 2D) rather " ..
					"than padding — the half battle_oldman cannot witness",
			})
			dumped = true
		end)
		if dumped then break end
	end
	assert(dumped, "battle_pikachu: wPlayerName was never renamed to PROF.OAK — " ..
		"DisplayBattleMenu did not take .doSimulatedMenuInput (wBattleType pin " ..
		"did not take, or the battle menu never opened)")
end)
