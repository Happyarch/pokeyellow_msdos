---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- battle_faint — golden for the port's DEBUG_BATTLE_FAINT=1 gate (differ class
-- "datastruct": WRAM game data only). The convergence-spec wild PIDGEY L13
-- battle (battle.enter_wild), then the REAL battle menu -> FIGHT -> STRENGTH,
-- resolving a full turn that knocks the enemy out and pays EXP.
--
-- This is the first golden in the suite in which a turn resolves and a mon
-- faints. Session 8's coverage analysis measured that the four existing battle
-- scenarios stop at the menu, the move list or a Master Ball capture, so 49 of
-- the 62 pret core.asm labels it relocated were never executed by a green
-- suite: the whole damage pipeline and every faint/send-out/EXP path.
--
-- WHY THIS MATCHUP, and why it is not luck. The port and this harness do NOT
-- share an RNG stream (see lib/seed.lua: the debug seed's DVs "cannot be
-- reproduced by construction"), so nothing compared may depend on a roll:
--   * SNORLAX L80 (debug party slot 0) vs PIDGEY L13, 36 HP. STRENGTH's
--     MINIMUM damage roll still overkills 36 by a wide margin, so the KO takes
--     exactly one turn for every roll and every crit outcome.
--   * The enemy never gets a turn -- BUT NOT BECAUSE OF SPEED, which is what
--     this comment used to claim. A YELLOW L13 PIDGEY knows QUICK ATTACK, and
--     +1 priority beats any speed; whether the AI picks it is a roll the two
--     emulators do not share. MEASURED in battle_exp_all (same matchup): with
--     no pin the golden's SNORLAX finished on 359 HP one generation and 360 the
--     next, against the port's full 362. The enemy is pinned ASLEEP on both
--     sides instead, so the party mon's HP, status and PP really are untouched
--     by any roll. battle_wrap / battle_bide / battle_thrash / battle_exp_all
--     carry the same pin.
--   * So EXP gained, stat EXP gained, party HP, wBattleResult and the zeroed
--     enemy HP are functions of species and level only. The damage VALUE does
--     differ between the two sides and is deliberately NOT compared: it
--     survives only in transient battle scratch, and the enemy ends at 0 HP
--     either way.
-- The one roll that could still diverge is the Gen-1 1/256 accuracy miss. Both
-- emulators are deterministic, so that is a fixed outcome per side rather than
-- a flake; the enemy-HP assert below turns it into a loud failure instead of a
-- confusing WRAM diff.
--
-- STRENGTH is move slot 4 of SNORLAX (lib/seed.lua DEBUG_PARTY[1].pokes[4]).
--
-- Dump point: the frame wBattleResult reads 0 (win) AND the enemy is at 0 HP.
-- FaintEnemyPokemon sets wBattleResult before paying EXP, so the EXP messages
-- are walked through first and the dump is taken once the party EXP has
-- actually landed -- polling wBattleResult alone would photograph the state a
-- few frames too early, before GainExperience wrote anything.
--
-- Pins: wPartyData (SNORLAX's EXP + stat EXP raised, HP untouched, PP of slot 4
-- decremented by 1); wEnemyMon (HP 0); wBattleFlags (wBattleResult 0).

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

-- SNORLAX's level in the debug party (lib/seed.lua DEBUG_PARTY[1].level). Used
-- as the marker that the post-faint HUD redraw has staged it into wLoadedMon.
local SLEEP_TURNS = 7           -- enemy SLP counter; outlasts this one turn
local PARTY_MON_LEVEL = 80

-- Big-endian multi-byte reads (Gen-1 data layout). These go through
-- scenario.read_range, NOT emu:* directly: emu is only reachable from the main
-- Lua state, so a bare emu:read8 in the scenario body dies with "Function
-- called from invalid context". read_range also advances one frame per call,
-- which is what makes the loops below per-frame watches.
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

	-- THE ENEMY MUST NOT ACT. See the header: speed does not remove its turn,
	-- QUICK ATTACK's +1 priority beats any speed. Sleep does, deterministically.
	-- The port gate makes the identical write.
	scenario.exec(function()
		emu:write8(sym:addr("wEnemyMonStatus"), SLEEP_TURNS)
	end)

	-- FIGHT -> the move list, then STRENGTH (SNORLAX's slot 4).
	navigate.choose(text:encode("FIGHT"))
	navigate.ensure_text("A", text:encode("STRENGTH"), 3600)
	scenario.wait(30) -- settle: a tap into a just-drawn list is swallowed
	navigate.choose(text:encode("STRENGTH"))

	-- The turn: "SNORLAX used STRENGTH!" -> damage/animation -> "Wild PIDGEY
	-- fainted!" -> the EXP messages. Walk the whole message chain with A until
	-- the enemy is actually down; the individual beats race against the taps
	-- (measured in ball_catch: a mid-flow checkpoint was already gone by its
	-- wait), so watch the STATE rather than any one string.
	local down = false
	for _ = 1, 3600 do
		if read_be("wEnemyMonHP", 2) == 0 then
			down = true
			break
		end
		input.tap("A", 2, 10)
	end
	assert(down, "battle_faint: enemy never reached 0 HP — a 1/256 accuracy " ..
		"miss, or the turn did not resolve")

	-- EXP is paid AFTER wBattleResult is set, so keep answering messages until
	-- the party mon's EXP actually moves. Snapshot first, then wait for change.
	local exp_before = read_be("wPartyMon1Exp", 3)
	local paid = false
	for _ = 1, 3600 do
		if read_be("wPartyMon1Exp", 3) ~= exp_before then
			paid = true
			break
		end
		input.tap("A", 2, 10)
	end
	assert(paid, "battle_faint: GainExperience never credited the party mon")

	-- Converge on the PORT'S dump instant, which is one step later than "EXP
	-- landed". HandleEnemyMonFainted pays the EXP inside FaintEnemyPokemon and
	-- only THEN calls DrawPlayerHUDAndHPBar (core.asm:719), which copies
	-- wBattleMon* into the wLoadedMon staging buffer (core.asm:1904). The port
	-- gate dumps after HandleEnemyMonFainted RETURNS, so it has done that copy;
	-- dumping here the moment EXP moved would photograph the frame before it and
	-- diverge on all 12 wLoadedMon fields (measured: golden held the L13 enemy,
	-- port held SNORLAX L80). Watch for the copy itself rather than guessing a
	-- frame count: wLoadedMonLevel reads the party mon's level once it lands.
	--
	-- THE LEVEL ALONE IS NOT ENOUGH, and adding the enemy-asleep pin is what
	-- exposed that. DrawPlayerHUDAndHPBar copies only two DISJOINT runs into
	-- wLoadedMon -- species..moves and level..stats -- so bytes 12-32 keep
	-- whatever the last LoadMonData left. There is a staging where the level
	-- already reads 80 while those bytes are still ZERO, and the pin shifted the
	-- frame counts just enough to land on it: the golden came out with
	-- `wLoadedMon EXP: want $000000 | got $09C466` and the same for all four
	-- stat-EXP words. So the poll also requires the staged buffer to CARRY the
	-- EXP, which only LoadMonData writes. One read covers level (offset $21) and
	-- EXP (offsets $0E-$10) -- two reads would be two frames.
	local LOADED_SPAN = 0x22
	local staged = false
	for _ = 1, 3600 do
		local blk = scenario.read_range(sym:addr("wLoadedMon"), LOADED_SPAN)
		local exp = blk:byte(0x0F) * 65536 + blk:byte(0x10) * 256 + blk:byte(0x11)
		if blk:byte(0x22) == PARTY_MON_LEVEL and exp ~= 0 then
			staged = true
			break
		end
		input.tap("A", 2, 10)
	end
	assert(staged, "battle_faint: DrawPlayerHUDAndHPBar never staged the party " ..
		"mon into wLoadedMon (the port gate's dump instant)")

	assert(navigate.read8("wBattleResult") == 0,
		"battle_faint: wBattleResult is not 0 (win) after the KO")

	scenario.exec(function()
		dump.write("battle_faint", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "SNORLAX L80 knocked out the spec wild PIDGEY L13 with " ..
				"STRENGTH from the real battle FIGHT menu; dumped once " ..
				"GainExperience had credited the party — the first golden in " ..
				"which a turn resolves and a mon faints",
		})
	end)
end)
