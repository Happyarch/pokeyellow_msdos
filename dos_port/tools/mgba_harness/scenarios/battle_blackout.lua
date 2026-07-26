---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- battle_blackout — golden for the port's DEBUG_BATTLE_BLACKOUT=1 gate (differ
-- class "datastruct": WRAM game data only). The convergence-spec wild PIDGEY
-- L13 battle (battle.enter_wild), with the party reshaped so the PLAYER's mon
-- faints and the party blacks out.
--
-- This is the other half of the coverage battle_faint opened. battle_faint
-- kills the ENEMY; nothing in the suite had ever killed the PLAYER, so
-- RemoveFaintedPlayerMon and HandlePlayerBlackOut were still moved-blind code.
--
-- WHY THE PARTY IS RESHAPED. The black-out branch is reached only when
-- AnyPartyAlive fails (pret core.asm:985-988); any surviving mon instead routes
-- to DoUseNextMonDialogue + ChooseNextMon, an INTERACTIVE party menu that is
-- both a port stub and untimeable against a golden. So exactly one mon is left
-- alive. It is party slot 3, STARTER_PIKACHU L5 (lib/seed.lua DEBUG_PARTY[4]),
-- and neither side names it: the send-out scan takes the first ALIVE mon, so
-- zeroing slots 0-2 selects slot 3 on both sides by itself.
--
-- RNG-INDEPENDENCE (the two sides do NOT share an RNG stream — see lib/seed.lua):
--   * PIKACHU L5 speed ~14 vs the spec PIDGEY L13's measured 21, so the ENEMY
--     ALWAYS MOVES FIRST. The player mon faints before it ever acts, so its PP
--     and the party's PP are untouched — that is what makes the compared party
--     data roll-invariant.
--   * The player mon sits at 1 HP, so ANY damage roll and any crit faints it
--     (Gen-1 minimum damage is 1).
--   * The enemy's 4 moves are PINNED to GUST so move SELECTION cannot matter.
--     Without it the AI could pick SAND-ATTACK, deal no damage and hand the
--     turn to the player, who would then act and decrement PP a different
--     number of times on each side. Same class of pin as seed.enemy's DV pin;
--     the port gate applies the identical one.
-- Residual roll: GUST's 1/256 Gen-1 accuracy miss. Deterministic per side, so
-- the assert below makes it loud rather than a confusing WRAM diff.
--
-- Dump point: once wBattleMonHP has reached 0 AND the blacked-out text has been
-- walked through, matching the port gate, which dumps after
-- HandlePlayerMonFainted returns.
--
-- Pins: wPartyData (all six mons at 0 HP), wBattleMon (0 HP), wEnemyMon (moves
-- pinned to GUST, still loaded).

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
local ALIVE_SLOT = 3 -- STARTER_PIKACHU L5
local GUST = 0x10    -- constants/move_constants.asm

-- Big-endian read via scenario.read_range: emu:* is reachable only from the
-- main Lua state (a bare emu:read8 here dies with "Function called from invalid
-- context"). read_range also advances one frame, making these per-frame watches.
local function read_be(label, size)
	local raw = scenario.read_range(sym:addr(label), size)
	local v = 0
	for i = 1, size do
		v = v * 256 + raw:byte(i)
	end
	return v
end

scenario.run(function()
	battle.enter_wild(sym, text)

	-- Reshape the party BEFORE the send-out: slot 3 at 1 HP, everything else
	-- at 0, so the send-out scan picks slot 3 and its faint empties the party.
	scenario.exec(function()
		local hp = sym:addr("wPartyMon1HP")
		for slot = 0, 5 do
			local a = hp + slot * PARTYMON_STRUCT_LENGTH
			emu:write8(a, 0)
			emu:write8(a + 1, slot == ALIVE_SLOT and 1 or 0)
		end
		-- Pin the enemy's moves so its turn always damages (see header).
		local mv = sym:addr("wEnemyMonMoves")
		for i = 0, 3 do
			emu:write8(mv + i, GUST)
		end
	end)

	-- A dismisses "appeared!"; send-out runs unattended; menu box parks.
	input.tap("A", 2, 8)
	navigate.dialog_until_text(text:encode("FIGHT"), 3600)
	scenario.wait(30) -- settle: menu parked in its input loop

	-- Re-pin the enemy moves: LoadBattleMonFromParty / the send-out path runs
	-- between the seed above and here, and the wild-mon move load can rewrite
	-- wEnemyMonMoves. Cheap, and makes the pin independent of that ordering.
	scenario.exec(function()
		local mv = sym:addr("wEnemyMonMoves")
		for i = 0, 3 do
			emu:write8(mv + i, GUST)
		end
	end)

	-- Take the turn. The player mon is slower, so whatever the player picks the
	-- ENEMY resolves first and the 1-HP mon faints before acting. FIGHT + the
	-- first move is the least-surprising choice and is never actually executed.
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
	assert(down, "battle_blackout: the player mon never reached 0 HP — a 1/256 " ..
		"accuracy miss, or the enemy turn did not resolve")

	-- Walk the faint + blacked-out messages through to where the port gate
	-- dumps (after HandlePlayerMonFainted returns).
	navigate.tap_until("A", text:encode("blacked out"), 3600)
	scenario.wait(60)

	scenario.exec(function()
		dump.write("battle_blackout", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "the spec wild PIDGEY L13 knocked out the player's last " ..
				"mon (PIKACHU L5, party slot 3, seeded to 1 HP) and the party " ..
				"blacked out — the first golden in which the PLAYER's mon faints",
		})
	end)
end)
