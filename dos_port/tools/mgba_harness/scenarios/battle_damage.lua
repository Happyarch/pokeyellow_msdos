---@diagnostic disable: undefined-global -- mGBA runtime globals (runner.c)
-- Semantic numerical oracle for the real Gen-1 damage pipeline. The mGBA ROM
-- and DOS port do not share an RNG stream, so the differ validates each staged
-- result against every legal random factor instead of comparing damage bytes.

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
local PIKACHU_SLOT = 3
local THUNDERSHOCK = 0x54
local SLASH = 0xA3
local TEST_HP = 1000

local function write_be(addr, value)
	emu:write8(addr, (value >> 8) & 0xff)
	emu:write8(addr + 1, value & 0xff)
end

local function snapshot()
	local out
	scenario.exec(function()
		local function r8(label, offset)
			return emu:read8(sym:addr(label) + (offset or 0))
		end
		local function r16(label, offset)
			return r8(label, offset) * 256 + r8(label, (offset or 0) + 1)
		end
		out = {
			player_hp = r16("wBattleMonHP"), enemy_hp = r16("wEnemyMonHP"),
			crit = r8("wCriticalHitOrOHKO"), damage_hi = r8("wDamage"),
			damage = r8("wDamage", 1),
			player_move = r8("wPlayerSelectedMove"),
			player_power = r8("wPlayerMovePower"),
			player_move_type = r8("wPlayerMoveType"),
			player_species = r8("wBattleMonSpecies"),
			player_level = r8("wBattleMonLevel"),
			player_special_hi = r8("wBattleMonSpecial"),
			player_special = r8("wBattleMonSpecial", 1),
			player_defense_hi = r8("wPartyMon1Defense",
				PIKACHU_SLOT * PARTYMON_STRUCT_LENGTH),
			player_defense = r8("wPartyMon1Defense",
				PIKACHU_SLOT * PARTYMON_STRUCT_LENGTH + 1),
			player_type1 = r8("wBattleMonType1"),
			player_type2 = r8("wBattleMonType2"),
			enemy_move = r8("wEnemySelectedMove"),
			enemy_power = r8("wEnemyMovePower"),
			enemy_move_type = r8("wEnemyMoveType"),
			enemy_species = r8("wEnemyMonSpecies"),
			enemy_level = r8("wEnemyMonLevel"),
			enemy_attack_hi = r8("wEnemyMonAttack"),
			enemy_attack = r8("wEnemyMonAttack", 1),
			enemy_special_hi = r8("wEnemyMonSpecial"),
			enemy_special = r8("wEnemyMonSpecial", 1),
			enemy_type1 = r8("wEnemyMonType1"),
			enemy_type2 = r8("wEnemyMonType2"),
		}
	end)
	return out
end

local function player_record(s, damage)
	return { s.crit, damage, s.player_move, s.player_power, s.player_move_type,
		s.player_species, s.player_level, s.player_special,
		s.player_type1, s.player_type2, s.enemy_species,
		s.player_special_hi | s.enemy_special_hi,
		s.enemy_special, s.enemy_type1, s.enemy_type2 }
end

local function enemy_record(s, damage)
	return { s.crit, damage, s.enemy_move, s.enemy_power, s.enemy_move_type,
		s.enemy_species, s.enemy_level, s.enemy_attack,
		s.enemy_type1, s.enemy_type2, s.player_species,
		s.enemy_attack_hi | s.player_defense_hi,
		s.player_defense, s.player_type1, s.player_type2 }
end

scenario.run(function()
	battle.enter_wild(sym, text)

	-- Make slot 3 the first living mon, and give the eventual battle mon enough
	-- HP that every sampled hit is non-lethal.
	scenario.exec(function()
		local hp = sym:addr("wPartyMon1HP")
		local maxhp = sym:addr("wPartyMon1MaxHP")
		for slot = 0, PIKACHU_SLOT - 1 do
			write_be(hp + slot * PARTYMON_STRUCT_LENGTH, 0)
		end
		write_be(hp + PIKACHU_SLOT * PARTYMON_STRUCT_LENGTH, TEST_HP)
		write_be(maxhp + PIKACHU_SLOT * PARTYMON_STRUCT_LENGTH, TEST_HP)
	end)

	input.tap("A", 2, 8)
	navigate.dialog_until_text(text:encode("FIGHT"), 3600)
	scenario.wait(30)

	local wanted_player, wanted_enemy
	for _ = 1, 64 do
		-- Reset every state field that the preceding attempt can mutate, then
		-- pin both move lists. The normal battle loop still chooses and executes
		-- the attacks; all four enemy slots are SLASH so AI selection is immaterial.
		scenario.exec(function()
			write_be(sym:addr("wBattleMonHP"), TEST_HP)
			write_be(sym:addr("wBattleMonMaxHP"), TEST_HP)
			write_be(sym:addr("wEnemyMonHP"), TEST_HP)
			write_be(sym:addr("wEnemyMonMaxHP"), TEST_HP)
			emu:write8(sym:addr("wBattleMonStatus"), 0)
			emu:write8(sym:addr("wEnemyMonStatus"), 0)
			for _, label in ipairs({"wPlayerBattleStatus1", "wPlayerBattleStatus2",
				"wPlayerBattleStatus3", "wEnemyBattleStatus1", "wEnemyBattleStatus2",
				"wEnemyBattleStatus3"}) do
				emu:write8(sym:addr(label), 0)
			end
			emu:write8(sym:addr("wBattleMonMoves"), THUNDERSHOCK)
			emu:write8(sym:addr("wBattleMonPP"), 30)
			local enemy_moves = sym:addr("wEnemyMonMoves")
			local enemy_pp = sym:addr("wEnemyMonPP")
			for i = 0, 3 do
				emu:write8(enemy_moves + i, SLASH)
				emu:write8(enemy_pp + i, 30)
			end
		end)

		navigate.choose(text:encode("FIGHT"))
		navigate.ensure_text("A", text:encode("THUNDERSHOCK"), 3600)
		navigate.choose(text:encode("THUNDERSHOCK"))

		local player_hit, enemy_hit
		for _ = 1, 3600 do
			local s = snapshot()
			if not enemy_hit and s.player_hp < TEST_HP then
				local damage = TEST_HP - s.player_hp
				assert(s.damage_hi == 0 and s.damage == damage,
					"battle_damage: enemy hit and wDamage disagree")
				enemy_hit = enemy_record(s, damage)
			end
			if not player_hit and s.enemy_hp < TEST_HP then
				local damage = TEST_HP - s.enemy_hp
				assert(s.damage_hi == 0 and s.damage == damage,
					"battle_damage: player hit and wDamage disagree")
				player_hit = player_record(s, damage)
			end
			if player_hit and enemy_hit then
				break
			end
			input.tap("A", 1, 2)
		end
		assert(player_hit and enemy_hit, "battle_damage: both attacks did not land")

		if player_hit[1] == 0 and enemy_hit[1] == 1 then
			wanted_player, wanted_enemy = player_hit, enemy_hit
			break
		end
		navigate.dialog_until_text(text:encode("FIGHT"), 3600)
	end
	assert(wanted_player and wanted_enemy,
		"battle_damage: no non-critical player / critical enemy pair in 64 turns")

	scenario.exec(function()
		local addr = sym:addr("wBuffer")
		local records = {wanted_player, wanted_enemy}
		local n = 0
		for _, record in ipairs(records) do
			for _, value in ipairs(record) do
				emu:write8(addr + n, value)
				n = n + 1
			end
		end
		local regions = dump.standard_regions(sym)
		regions[#regions + 1] = {name = "damageOracle", addr = addr, size = 30}
		dump.write("battle_damage", regions, {
			frame = scenario.frame(),
			description = "independent real-turn damage records: non-critical " ..
				"PIKACHU THUNDERSHOCK and critical PIDGEY SLASH",
		})
	end)
end)
