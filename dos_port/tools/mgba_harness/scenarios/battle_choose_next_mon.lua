---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- battle_choose_next_mon — golden for the port's DEBUG_BATTLE_NEXTMON=1 gate
-- (differ class "datastruct": WRAM game data only). The convergence-spec wild
-- PIDGEY L13 battle (battle.enter_wild), with the party reshaped so the
-- PLAYER's mon faints while ANOTHER mon is still alive — the FORCED SWITCH.
--
-- WHY THIS SCENARIO EXISTS. It is the third door out of HandlePlayerMonFainted
-- and the only one nothing had ever opened:
--   battle_faint      kills the ENEMY;
--   battle_blackout   kills the player's LAST mon (AnyPartyAlive fails);
--   this one          kills the player's mon with another alive, so
--                     AnyPartyAlive succeeds and DoUseNextMonDialogue +
--                     ChooseNextMon run.
-- Battle plan 2b ported both of those (68210555a) with zero execution evidence.
-- battle_blackout's header explains why it leaves exactly one mon alive: the
-- party menu was believed "untimeable against a golden". battle_switch
-- disproved that, so this is now buildable.
--
-- PARTY SHAPE. Two mons alive:
--   slot 3 STARTER_PIKACHU L5 at 1 HP — the FIRST alive slot, so the send-out
--          scan picks it on both sides without either naming it, and any damage
--          roll faints it (Gen-1 minimum damage is 1);
--   slot 5 LAPRAS L34, left at the seed's full HP — the replacement.
-- Slots 0/1/2/4 are zeroed. The gap between 3 and 5 is deliberate: a wrong
-- cursor lands on a FAINTED mon ("no will to fight" and a re-ask) rather than
-- silently selecting the right one, so a mistimed script fails loudly.
--
-- RNG-INDEPENDENCE (the two sides do NOT share an RNG stream — lib/seed.lua):
-- identical to battle_blackout. PIKACHU L5's speed ~14 loses to the spec PIDGEY
-- L13's 21, so the ENEMY ALWAYS MOVES FIRST and the 1-HP mon faints before it
-- ever acts — its PP and the party's PP are untouched by any roll. The enemy's
-- moves are pinned to GUST so move SELECTION cannot diverge either.
-- Residual roll: GUST's 1/256 Gen-1 accuracy miss, made loud by the assert.
--
-- DUMP POINT: wPlayerMonNumber == 5 AND wLoadedMon's species == LAPRAS.
-- ChooseNextMon sets wPlayerMonNumber before LoadBattleMonFromParty, and
-- SendOutMon's DrawPlayerHUDAndHPBar is what stages the mon into wLoadedMon —
-- DrawEnemyHUDAndHPBar stages the ENEMY first, so species alone would fire one
-- routine too early. And species is not enough on its own — MEASURED: the
-- party menu draws all six mons through LoadMonData and the LAST one it stages
-- is slot 5, the replacement itself, so wLoadedMon already says LAPRAS before
-- SendOutMon runs. The two sides then disagree on exactly the four stat words
-- in the ratio 9/8, because LoadMonData copies the party's TRUE stats while
-- DrawPlayerHUDAndHPBar copies wBattleMon's BADGE-BOOSTED ones (pret
-- core.asm:1904 — the divergence battle_faint documents and masks). So the
-- landmark also requires wLoadedMonAttack == wBattleMonAttack, which picks the
-- boosted staging on both sides and lets wLoadedMon be compared UNMASKED (the
-- same alignment battle_item_potion needed).
--
-- The port gate CANNOT use a return-based dump here and neither should any
-- successor: on the forced-switch path HandlePlayerMonFainted ends in
-- `jp MainInBattleLoop` (pret core.asm:1006) — it tail-jumps into the battle
-- loop and never returns. That is exactly why battle_faint and battle_blackout
-- could dump after their call and this one is state-gated on both sides.

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

local PARTYMON_STRUCT_LENGTH = 44
local ACTIVE_SLOT = 3      -- STARTER_PIKACHU L5, seeded to 1 HP
local TARGET_SLOT = 5      -- LAPRAS L34, the replacement
local TARGET_SPECIES = 19  -- LAPRAS, internal species id
local GUST = 0x10          -- constants/move_constants.asm

local function read8(label)
	return scenario.read_range(sym:addr(label), 1):byte(1)
end

local function read_be(label, size)
	local raw = scenario.read_range(sym:addr(label), size)
	local v = 0
	for i = 1, size do
		v = v * 256 + raw:byte(i)
	end
	return v
end

local function pin_enemy_moves()
	scenario.exec(function()
		local mv = sym:addr("wEnemyMonMoves")
		for i = 0, 3 do
			emu:write8(mv + i, GUST)
		end
	end)
end

scenario.run(function()
	battle.enter_wild(sym, text)

	-- Reshape the party BEFORE the send-out: slot 3 at 1 HP, slot 5 left alone,
	-- everything else at 0. The send-out scan then picks slot 3 by itself.
	scenario.exec(function()
		local hp = sym:addr("wPartyMon1HP")
		for slot = 0, 5 do
			if slot ~= TARGET_SLOT then
				local a = hp + slot * PARTYMON_STRUCT_LENGTH
				emu:write8(a, 0)
				emu:write8(a + 1, slot == ACTIVE_SLOT and 1 or 0)
			end
		end
	end)
	pin_enemy_moves()

	-- A dismisses "appeared!"; send-out runs unattended; menu box parks.
	input.tap("A", 2, 8)
	navigate.dialog_until_text(text:encode("FIGHT"), 3600)
	scenario.wait(30) -- settle: menu parked in its input loop

	-- Re-pin: LoadBattleMonFromParty / the send-out path runs between the seed
	-- above and here, and the wild-mon move load can rewrite wEnemyMonMoves.
	pin_enemy_moves()

	-- Take the turn. The player mon is slower, so whatever it picks the ENEMY
	-- resolves first and the 1-HP mon faints before acting.
	navigate.choose(text:encode("FIGHT"))
	scenario.wait(30)
	input.tap("A", 2, 10) -- select the first move

	-- Watch the state, not any one message: the beats race against the taps.
	local down = false
	for _ = 1, 3600 do
		if read_be("wBattleMonHP", 2) == 0 then
			down = true
			break
		end
		input.tap("A", 2, 10)
	end
	assert(down, "battle_choose_next_mon: the player mon never reached 0 HP — a " ..
		"1/256 accuracy miss, or the enemy turn did not resolve")

	-- Walk the faint beats to DoUseNextMonDialogue's box. "POKéMON?" breaks
	-- across the line, so match the first word only.
	navigate.tap_until("A", text:encode("Use next"), 3600)
	scenario.wait(30) -- let the YES/NO box draw fully
	input.tap("A", 2, 10) -- YES is item 0 and where the cursor starts

	-- ChooseNextMon's party menu. Walk the cursor to the replacement; polling
	-- wCurrentMenuItem means a swallowed press retries instead of desyncing.
	navigate.wait_for_text(text:encode("Bring out"), 1800)
	scenario.wait(20)
	local at_target = false
	for _ = 1, 40 do
		for _ = 1, 20 do
			if read8("wCurrentMenuItem") == TARGET_SLOT then
				at_target = true
				break
			end
		end
		if at_target then break end
		input.tap("DOWN", 2, 8)
	end
	assert(at_target, "battle_choose_next_mon: the party cursor never reached slot 5")
	input.tap("A", 2, 10)

	-- Dump point (see the header): the replacement is out AND its HUD has been
	-- drawn, so wLoadedMon holds it rather than the enemy.
	local sent = false
	for _ = 1, 1800 do
		if read8("wPlayerMonNumber") == TARGET_SLOT
			and read8("wLoadedMon") == TARGET_SPECIES
			and read_be("wLoadedMonAttack", 2) == read_be("wBattleMonAttack", 2) then
			sent = true
			break
		end
		input.tap("A", 2, 10)
	end
	assert(sent, "battle_choose_next_mon: the replacement never came out — " ..
		"wPlayerMonNumber/wLoadedMon did not reach 5/LAPRAS")

	scenario.exec(function()
		dump.write("battle_choose_next_mon", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "the spec wild PIDGEY L13 knocked out the player's " ..
				"PIKACHU L5 (party slot 3, seeded to 1 HP) with another mon still " ..
				"alive, and the player sent out LAPRAS L34 (slot 5) through the real " ..
				"ChooseNextMon party menu — the first golden that takes the " ..
				"forced-switch door out of HandlePlayerMonFainted",
		})
	end)
end)
