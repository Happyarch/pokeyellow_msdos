---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- battle_oldman — golden for the port's DEBUG_BATTLE_OLDMAN=1 gate (differ class
-- "datastruct": WRAM game data only). Witnesses
-- DisplayBattleMenu.doSimulatedMenuInput, the old-man / Prof. Oak tutorial menu,
-- which NO scenario in the registry has ever executed.
--
-- WHY THIS SCENARIO EXISTS. That coverage gap is not incidental — it is why the
-- tutorial-name bytes were wrong from the first day and were found by reading
-- pokeyellow.gbc rather than by the suite. pret copies NAME_LENGTH = 11 bytes
-- from `.oldManName`, an 8-byte literal, so hardware also copies the 3 bytes
-- that follow it ("PRO", the start of `.profOakName`). The port's generator
-- padded with 0x50 instead. Fixed in dbe6e797b; this scenario is the witness
-- that fix was owed (memory regression-battle-oldman-name-tail-bytes).
--
-- WHAT IS WITNESSED: wPlayerName, which the differ ALREADY compares in full as
-- a standard region. So this scenario adds NO scenario-local dump rows — the
-- thing under test is on the default contract. The expected 11 bytes are
--   8E 8B 83 7F 8C 80 8D 50 8F 91 8E   = "OLD MAN" @ + "PRO"
-- and a port that pads would differ in exactly the last three.
--
-- THERE IS NOTHING TO PRESS. .doSimulatedMenuInput is reached from wBattleType
-- alone; it then walks its own cursor with two DelayFrames(20) and takes the
-- ITEM branch. So this scenario drives no input into the menu, and there is no
-- roll anywhere in the path under test.
--
-- WHAT IS PINNED, AND WHY.
--   1. wBattleType = BATTLE_TYPE_OLD_MAN, written EVERY frame until the rename
--      is seen. Written once it would be a race: the exact frame on which
--      InitBattleVariables and the send-out finish differs between the two
--      emulators, and the value only matters at the instant DisplayBattleMenu
--      reads it. Re-asserting is idempotent and removes the timing question
--      entirely.
--   2. ENEMY HP 65535 + ASLEEP, the battle_thrash pin, for its reason: an enemy
--      turn puts a damage ROLL into wBattleMon, which IS compared, and the two
--      emulators do not share an RNG stream. Sleep removes the enemy's turn.
--
-- THE LANDMARK CANNOT BE AN INITIAL STATE, which is the rule battle_wrap and
-- battle_bide need latches to satisfy and this one gets for free:
-- wPlayerName[0] is 'R' ($91) of the seeded "RED" identity right up until the
-- rename lands, and $8E is 'O' — reachable here only by the .oldManName copy.
--
-- THE WINDOW CLOSES, so the poll is one frame wide. ItemUseBall.oldManBattle
-- copies wGrassRate BACK over wPlayerName (that is the restore half of the
-- Missingno. glitch pair, not the write half), which destroys the evidence. The
-- two DelayFrames(20) in the cursor walk are the margin.

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

local BATTLE_TYPE_OLD_MAN = 1      -- constants/battle_constants.asm
local OLDMAN_FIRST_BYTE = 0x8E     -- 'O' of "OLD MAN" (charmap)
local RED_FIRST_BYTE = 0x91        -- 'R' of the seeded "RED" identity
local ENEMY_HP = { 0xFF, 0xFF }    -- 65535, big-endian (Gen-1 byte order)
local SLEEP_TURNS = 7
-- The 11 bytes pret actually copies: "OLD MAN" + @ + the adjacent "PRO" of
-- .profOakName. Read from pokeyellow.gbc at 0f:4fe7 (file offset 0x3CFE7).
local EXPECT_NAME = { 0x8E, 0x8B, 0x83, 0x7F, 0x8C, 0x80, 0x8D,
                      0x50, 0x8F, 0x91, 0x8E }

scenario.run(function()
	battle.enter_wild(sym, text)

	-- A dismisses "appeared!"; send-out runs unattended; the menu then parks.
	input.tap("A", 2, 8)

	local name = sym:addr("wPlayerName")
	local btype = sym:addr("wBattleType")

	-- Sanity, BEFORE the pin: the identity really is the seeded "RED", so the
	-- landmark below is a transition and not something that was already true.
	scenario.exec(function()
		assert(emu:read8(name) == RED_FIRST_BYTE,
			("battle_oldman: expected the seeded RED identity before the rename, " ..
			 "got $%02X at wPlayerName[0] — the landmark would not be a landmark")
				:format(emu:read8(name)))
	end)

	local dumped = false
	for _ = 1, 3600 do
		scenario.exec(function()
			if dumped then return end
			-- Pin 1, re-asserted (see the header): make the menu take the
			-- simulated-input branch whichever frame it opens on.
			emu:write8(btype, BATTLE_TYPE_OLD_MAN)
			-- Pin 2: keep the enemy inert for as long as the battle runs.
			local hp = sym:addr("wEnemyMonHP")
			local mx = sym:addr("wEnemyMonMaxHP")
			for i, b in ipairs(ENEMY_HP) do
				emu:write8(hp + i - 1, b)
				emu:write8(mx + i - 1, b)
			end
			emu:write8(sym:addr("wEnemyMonStatus"), SLEEP_TURNS)
			-- THE DUMP: the rename is visible. One frame wide on purpose — the
			-- ball throw restores the real name and erases it.
			--
			-- BOTH CLAUSES ARE LOAD-BEARING, and the second was added after the
			-- first attempt aligned wrong. wPlayerName[0] == $8E ALONE fired
			-- while wIsInBattle was still 0, so the golden photographed a
			-- pre-battle frame and diverged from the port on 32 fields — every
			-- one of them wBattleMon/wLoadedMon zero on the golden side, i.e. a
			-- DUMP-POINT misalignment rather than a defect. Requiring the battle
			-- to be live makes the landmark mean what the header claims it does.
			if emu:read8(sym:addr("wIsInBattle")) == 0 then return end
			-- DO NOT ADD `wBattleMonSpecies ~= 0` HERE. It was tried, and it
			-- MEASURED THE REAL ANSWER by failing: the assert fired with the
			-- screen showing "All right!" / "PIDGEY was ..." — the tutorial's
			-- CATCH text. In the old-man battle the player's mon is NEVER SENT
			-- OUT (the old man throws the ball immediately), so wBattleMon stays
			-- zero for the whole battle on hardware. The golden is CORRECT to
			-- have it zero; anything that waits for it waits forever.
			if emu:read8(name) ~= OLDMAN_FIRST_BYTE then return end
			-- And require the WHOLE name, not just its first byte: the tail is
			-- the entire point of this scenario, so a partial match is not a
			-- landmark worth dumping on.
			local got = emu:readRange(name, #EXPECT_NAME)
			for i = 1, #EXPECT_NAME do
				if got:byte(i) ~= EXPECT_NAME[i] then return end
			end
			dump.write("battle_oldman", dump.standard_regions(sym), {
				frame = scenario.frame(),
				description = "DisplayBattleMenu.doSimulatedMenuInput renamed the " ..
					"player to the old-man tutorial identity: wPlayerName holds the " ..
					"11 bytes pret copies from the 8-byte .oldManName literal, so " ..
					"the tail is the adjacent \"PRO\" of .profOakName rather than " ..
					"padding — the first scenario ever to execute this path",
			})
			dumped = true
		end)
		if dumped then break end
	end
	assert(dumped, "battle_oldman: wPlayerName was never renamed — " ..
		"DisplayBattleMenu did not take .doSimulatedMenuInput (wBattleType pin " ..
		"did not take, or the battle menu never opened)")
end)
