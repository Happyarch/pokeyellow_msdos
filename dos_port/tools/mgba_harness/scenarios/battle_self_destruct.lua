---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- battle_self_destruct — golden for the port's DEBUG_BATTLE_SELFDESTRUCT=1 gate
-- (differ class "datastruct": WRAM game data only). SNORLAX L80 uses
-- SELFDESTRUCT on the convergence-spec wild PIDGEY L13, so BOTH mons reach 0 HP
-- in the same turn.
--
-- WHY THIS SCENARIO EXISTS. It is the MUTUAL FAINT that battle plan 3c owes.
-- FaintEnemyPokemon's `.sfxplayed` block (pret core.asm:805-815) has an arm that
-- only runs when the PLAYER's mon is also down: the wInHandlePlayerMonFainted
-- guard against calling RemoveFaintedPlayerMon twice, and the
-- RemoveFaintedPlayerMon call that writes the fainted mon's 0 HP back to its
-- party slot. battle_faint kills only the enemy and battle_blackout only the
-- player, so nothing had ever taken it.
--
-- REACHABILITY WAS CHECKED BEFORE BUILDING (the lesson 3a taught): FaintEnemyPokemon
-- is reached from HandleEnemyMonFainted, which the battle_faint gate template
-- already calls directly — so unlike CheckNumAttacksLeft this needs no
-- MainInBattleLoop harness.
--
-- DETERMINISTIC BY CONSTRUCTION, not by matchup luck. ExplodeEffect zeroes the
-- USER's HP unconditionally with no accuracy test (engine/battle/effects.asm),
-- so SNORLAX faints on every roll; and SELFDESTRUCT's power-130 hit from L80
-- overkills PIDGEY's 36 HP on every roll, so the enemy faints too. The damage
-- VALUE is never compared — both HP words end at 0 either way.
--
-- SNORLAX DOES NOT LEARN SELFDESTRUCT: lib/seed.lua pokes FLY/CUT/SURF/STRENGTH,
-- so both sides overwrite the LOADED battle mon's move slot 1. Slot 1 is where
-- the move cursor starts, so choosing it is a bare A.
--
-- Dump point: both HP words 0 AND party slot 0's HP 0 — that last clause is the
-- point of the scenario, because only RemoveFaintedPlayerMon writes it. Plus the
-- wLoadedMon staging alignment battle_faint documents (DrawPlayerHUDAndHPBar
-- stages the party mon after the EXP is paid, and the port gate dumps after
-- HandleEnemyMonFainted returns, so it has done that copy).

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

local SELFDESTRUCT = 0x78     -- constants/move_constants.asm

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

	-- A dismisses "appeared!"; send-out runs unattended; menu box parks.
	input.tap("A", 2, 8)
	navigate.dialog_until_text(text:encode("FIGHT"), 3600)
	scenario.wait(30) -- settle: menu parked in its input loop

	-- SELFDESTRUCT into the LOADED battle mon's move slot 1.
	scenario.exec(function()
		emu:write8(sym:addr("wBattleMonMoves"), SELFDESTRUCT)
	end)

	-- FIGHT -> the move list; slot 1 is where the cursor starts.
	navigate.choose(text:encode("FIGHT"))
	scenario.wait(30) -- settle: a tap into a just-drawn list is swallowed
	input.tap("A", 2, 10)

	-- Watch the STATE, not any one message: the beats race against the taps.
	-- Both mons must be down — that pair IS the mutual faint.
	local both_down = false
	for _ = 1, 3600 do
		if read_be("wEnemyMonHP", 2) == 0 and read_be("wBattleMonHP", 2) == 0 then
			both_down = true
			break
		end
		input.tap("A", 2, 10)
	end
	assert(both_down, "battle_self_destruct: the mons did not both reach 0 HP — " ..
		"SELFDESTRUCT did not execute, or the move slot poke did not take")
	scenario.log("self_destruct: both mons down")

	-- The scenario's actual subject: RemoveFaintedPlayerMon writing the fainted
	-- mon's 0 HP back into its PARTY slot, which only the `.sfxplayed`
	-- player-also-fainted arm does. Nothing else in this flow touches it.
	local written_back = false
	for _ = 1, 3600 do
		if read_be("wPartyMon1HP", 2) == 0 then
			written_back = true
			break
		end
		input.tap("A", 2, 10)
	end
	assert(written_back, "battle_self_destruct: party slot 0 HP never went 0 — " ..
		"FaintEnemyPokemon did not take its player-also-fainted arm")
	scenario.log("self_destruct: party slot 0 HP written back")

	-- battle_faint's wLoadedMon ALIGNMENT DOES NOT TRANSFER HERE, and this is
	-- recorded so it is not retried. battle_faint waits for
	-- DrawPlayerHUDAndHPBar to stage the party mon (wLoadedMonLevel == 80) as
	-- its dump instant. After a MUTUAL faint the GB does not do that: the
	-- player's mon is also down, so the flow continues into
	-- HandlePlayerMonFainted and the next-mon dialogue instead of redrawing the
	-- player's HUD. MEASURED: both earlier stages log fine and this poll then
	-- spins to the 36000-frame cap. The dump therefore lands on the write-back
	-- itself, which is what this scenario is about.

	scenario.exec(function()
		dump.write("battle_self_destruct", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "SNORLAX L80 used SELFDESTRUCT on the spec wild PIDGEY " ..
				"L13 and BOTH mons fainted in the same turn, so FaintEnemyPokemon " ..
				"took its player-also-fainted arm and RemoveFaintedPlayerMon wrote " ..
				"the 0 HP back to party slot 0 — the first golden with a mutual faint",
		})
	end)
end)
