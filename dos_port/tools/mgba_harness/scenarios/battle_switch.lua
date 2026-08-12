---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- battle_switch — golden for the port's DEBUG_BATTLE_SWITCH=1 gate (differ
-- class "datastruct": WRAM game data only). The convergence-spec wild PIDGEY
-- L13 battle (battle.enter_wild), then the player VOLUNTARILY SWITCHES from
-- party slot 0 (SNORLAX L80) to slot 1 (PERSIAN L80) through the real battle
-- menu.
--
-- WHY THIS SCENARIO EXISTS. Nothing in the registry had ever pressed PKMN, so
-- PartyMenuOrRockOrRun, SwitchPlayerMon, RetreatMon and
-- AnimateRetreatingPlayerMon were linked-but-unreached on the port side: battle
-- plan 2a and 2b both landed with ZERO execution evidence, and 3a/3b are in the
-- same state behind them. This is the scenario the Stage 2 box owes.
--
-- IT DRIVES THE REAL MENU, IT DOES NOT REIMPLEMENT IT. Every step below is a
-- key press through the production DisplayBattleMenu / party menu, on both
-- sides. A harness that instead called SwitchPlayerMon directly would inherit
-- production's bug and could not witness its own fix — that is exactly what
-- this file's DEBUG_BATTLE_GOLDEN twin did with SendOutMon and it blinded five
-- scenarios (bug-class-false-witness-scenario, instance 3).
--
-- MENU GEOMETRY, read out of pret core.asm:2150-2270 rather than guessed. The
-- battle menu is 2x2 and the columns are separate HandleMenuInput loops:
--   * the LEFT loop watches PAD_RIGHT|PAD_A and parks wTopMenuItemX = $9;
--   * PAD_RIGHT enters the RIGHT loop, which parks wTopMenuItemX = $f and, on
--     A, adds 2 to wCurrentMenuItem;
--   * ITEM/PKMN ids are then swapped, so the right column's top item (pre-swap
--     2) becomes 1 = PKMN.
-- So PKMN is exactly RIGHT then A, with no vertical movement — and
-- wTopMenuItemX is the landmark that says the RIGHT press landed, which is why
-- the column change is polled rather than assumed. A swallowed RIGHT followed
-- by a blind A would select FIGHT and open the move menu.
--
-- RNG-INDEPENDENCE (the two sides do NOT share an RNG stream — lib/seed.lua).
-- Nothing compared here depends on a roll: no move is used, no damage is dealt
-- and no accuracy is checked. The switch itself is deterministic, and the dump
-- lands before the enemy's free turn can do anything (see the dump point).
-- The one roll in the flow is the enemy's move SELECTION after the menu
-- returns, which happens after the dump and is not compared.
--
-- Dump point: wCurrentMenuItem == 2 while wPlayerMonNumber == 1. That pair is
-- SwitchPlayerMon's closing store (pret core.asm:2549-2551), reached only after
-- RetreatMon, the 50-frame wait, AnimateRetreatingPlayerMon,
-- LoadBattleMonFromParty and SendOutMon have all run — so the compared
-- wBattleMon is the NEW mon, fully sent out. The port gate dumps at the
-- instruction after DisplayBattleMenu returns, which is the same instant.
-- The guard on wPlayerMonNumber matters: wCurrentMenuItem is the party-menu
-- cursor moments earlier and passes through other values, and 2 alone would
-- also match a cursor parked on party slot 2.
--
-- Frame-granularity overshoot is bounded and harmless: the next thing the game
-- does is SelectEnemyMove and then print "PIDGEY used GUST!", and Gen-1 applies
-- damage only after that text and the move animation — tens of frames later.

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

local RIGHT_COLUMN_X = 0x0f -- wTopMenuItemX in DisplayBattleMenu's right loop
local TARGET_SLOT = 1       -- party slot 1 = PERSIAN L80 (lib/seed.lua DEBUG_PARTY[2])

-- Byte read via scenario.read_range: emu:* is reachable only from the main Lua
-- state (a bare emu:read8 here dies with "Function called from invalid
-- context"). read_range also advances one frame, so these are per-frame watches.
local function read8(label)
	return scenario.read_range(sym:addr(label), 1):byte(1)
end

-- Tap `keys` until `label` holds `want`, polling FIRST so an already-correct
-- state costs no press (an extra press into a menu selects something). Each
-- round polls 20 frames — a menu that is still drawing flushes the joypad, so a
-- single tap can be swallowed and the retry is what makes this reliable.
local function tap_until_byte(keys, label, want, rounds)
	for _ = 1, (rounds or 30) do
		for _ = 1, 20 do
			if read8(label) == want then
				return true
			end
		end
		input.tap(keys, 2, 8)
	end
	return false
end

scenario.run(function()
	battle.enter_wild(sym, text)

	-- A dismisses "appeared!"; the send-out of slot 0 runs unattended; the
	-- battle menu parks in its left-column input loop with the cursor on FIGHT.
	input.tap("A", 2, 8)
	navigate.dialog_until_text(text:encode("FIGHT"), 3600)
	scenario.wait(30) -- settle: menu parked in HandleMenuInput

	-- FIGHT -> the right column. Polled, not assumed: see the geometry note.
	assert(tap_until_byte("RIGHT", "wTopMenuItemX", RIGHT_COLUMN_X, 30),
		"battle_switch: the battle menu never entered its right column — " ..
		"the RIGHT press was swallowed, or the menu is not the 2x2 normal one")

	-- A on the right column's top item = PKMN -> PartyMenuOrRockOrRun. The
	-- party list is confirmed by the target mon's own name being on screen.
	navigate.tap_until("A", text:encode("PERSIAN"), 1800)
	scenario.wait(20) -- settle: list drawn, cursor placed

	-- The list opens on slot 0, which IS the mon that is already out; choosing
	-- it would print AlreadyOutText and bounce back to the list. Move to slot 1.
	assert(tap_until_byte("DOWN", "wCurrentMenuItem", TARGET_SLOT, 30),
		"battle_switch: the party cursor never reached slot 1")

	-- A on slot 1 opens the SWITCH / STATS / CANCEL box with the cursor on
	-- SWITCH (item 0), so the following A takes SWITCH.
	navigate.tap_until("A", text:encode("SWITCH"), 1800)
	scenario.wait(20)
	input.tap("A", 2, 10)

	-- Dump point (see the header). Poll the pair, not either half alone.
	-- The taps walk whatever the switch prints (the trainer's parting line,
	-- then "Go! PERSIAN!"); the poll is what decides when to stop, so an extra
	-- press cannot overshoot the dump. Same shape as battle_blackout's watch.
	local switched = false
	for _ = 1, 1800 do
		if read8("wPlayerMonNumber") == TARGET_SLOT and read8("wCurrentMenuItem") == 2 then
			switched = true
			break
		end
		input.tap("A", 2, 10)
	end
	assert(switched, "battle_switch: SwitchPlayerMon never completed — " ..
		"wPlayerMonNumber/wCurrentMenuItem did not reach 1/2")

	scenario.exec(function()
		dump.write("battle_switch", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "the player voluntarily switched from party slot 0 " ..
				"(SNORLAX L80) to slot 1 (PERSIAN L80) through the real battle " ..
				"menu against the spec wild PIDGEY L13 — the first golden that " ..
				"presses PKMN at all, so PartyMenuOrRockOrRun / SwitchPlayerMon / " ..
				"RetreatMon / AnimateRetreatingPlayerMon finally execute",
		})
	end)
end)
