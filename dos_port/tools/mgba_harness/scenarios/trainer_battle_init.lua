---@diagnostic disable: undefined-global -- emu/C/callbacks/console are mGBA runtime globals
-- trainer_battle_init -- Route 3's first sight trainer through the real map
-- script, stopped once InitBattleCommon has loaded the roster and selected its
-- first active mon. The compact trainerInit region excludes RNG-derived DVs and
-- stats; it pins the deterministic trainer identity, roster, prize metadata,
-- AI reset, battle kind and name prefix against the port's DEBUG_TRAINER_INIT gate.

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local gbtext = require("lib.gbtext")
local input = require("lib.input")
local dump = require("lib.dump")
local scenario = require("lib.scenario")
local navigate = require("lib.navigate")
local seed = require("lib.seed")

local sym = symbols.load()
local text = gbtext.load()
navigate.init(sym, text)

local REDS_HOUSE_1F = 37
local PALLET_TOWN = 0
local ROUTE_3 = 0x0E
local ROUTE_3_WIDTH = 35
local SIGHT_Y, SIGHT_X = 6, 12
local BIT_WARP_FROM_CUR_SCRIPT = 3
local PARTY_LENGTH = 6
local PARTYMON_STRUCT_LENGTH = 44

local function regions()
	local out = dump.standard_regions(sym)
	out[#out + 1] = { name = "trainerInit", addr = sym:addr("wBuffer"), size = 30 }
	return out
end

scenario.run(function()
	navigate.boot_to_main_menu()
	navigate.new_game_to_bedroom()

	-- Reach a settled overworld before arming the script warp. This is the same
	-- sequencing as lib/sight.lua; hWarpDestinationMap shares volatile HRAM.
	navigate.walk("RIGHT", 1)
	navigate.walk("UP", 5)
	navigate.walk_until_map("RIGHT", REDS_HOUSE_1F)
	navigate.walk("DOWN", 6)
	navigate.walk("LEFT", 4)
	navigate.walk_until_map("DOWN", PALLET_TOWN)
	navigate.walk("DOWN", 1)
	scenario.wait(60)

	scenario.exec(function()
		seed.debug_new_game(sym, text:encode(seed.PLAYER_NAME))
		local view = sym:addr("wOverworldMap") + 7 + ROUTE_3_WIDTH
			+ (ROUTE_3_WIDTH + 6) * (SIGHT_Y >> 1) + (SIGHT_X >> 1)
		local ptr = sym:addr("wCurrentTileBlockMapViewPointer")
		emu:write8(ptr, view & 0xFF)
		emu:write8(ptr + 1, (view >> 8) & 0xFF)
		emu:write8(sym:addr("wYCoord"), SIGHT_Y)
		emu:write8(sym:addr("wXCoord"), SIGHT_X)
		emu:write8(sym:addr("wDestinationWarpID"), 0xFF)
		emu:write8(sym:addr("hWarpDestinationMap"), ROUTE_3)
		local flags = sym:addr("wStatusFlags3")
		emu:write8(flags, emu:read8(flags) | (1 << BIT_WARP_FROM_CUR_SCRIPT))
	end)

	local deadline = scenario.frame() + 900
	while navigate.read8("wCurMap") ~= ROUTE_3 do
		assert(scenario.frame() < deadline, "trainer_battle_init: Route 3 warp never fired")
		scenario.wait(1)
	end

	-- The sight script walks the trainer up, prints its challenge, transitions,
	-- and initializes the battle. Answer every text wait and stop on state.
	deadline = scenario.frame() + 7200
	while true do
		local in_battle = navigate.read8("wIsInBattle")
		local count = navigate.read8("wEnemyPartyCount")
		local species = navigate.read8("wEnemyMonSpecies")
		if in_battle == 2 and count > 0 and species > 0 then
			break
		end
		assert(scenario.frame() < deadline,
			"trainer_battle_init: trainer battle never initialized")
		input.tap("A", 2, 8)
	end

	-- Mirror the port gate's 30-byte deterministic projection in wBuffer.
	scenario.exec(function()
		local bytes = {
			emu:read8(sym:addr("wCurOpponent")),
			emu:read8(sym:addr("wTrainerClass")),
			emu:read8(sym:addr("wTrainerNo")),
			emu:read8(sym:addr("wEnemyPartyCount")),
		}
		for i = 0, PARTY_LENGTH - 1 do
			bytes[#bytes + 1] = emu:read8(sym:addr("wEnemyPartySpecies") + i)
		end
		for i = 0, PARTY_LENGTH - 1 do
			bytes[#bytes + 1] = emu:read8(sym:addr("wEnemyMon1Level")
				+ i * PARTYMON_STRUCT_LENGTH)
		end
		for _, label in ipairs({
			"wEnemyMonPartyPos", "wEnemyMonSpecies", "wEnemyMonLevel", "wAICount",
		}) do
			bytes[#bytes + 1] = emu:read8(sym:addr(label))
		end
		for i = 0, 2 do
			bytes[#bytes + 1] = emu:read8(sym:addr("wAmountMoneyWon") + i)
		end
		for i = 0, 1 do
			bytes[#bytes + 1] = emu:read8(sym:addr("wTrainerBaseMoney") + i)
		end
		bytes[#bytes + 1] = emu:read8(sym:addr("wIsInBattle"))
		for i = 0, 3 do
			bytes[#bytes + 1] = emu:read8(sym:addr("wTrainerName") + i)
		end
		assert(#bytes == 30, "trainer_battle_init: projection length drift")
		for i, value in ipairs(bytes) do
			emu:write8(sym:addr("wBuffer") + i - 1, value)
		end
		dump.write("trainer_battle_init", regions(), {
			frame = scenario.frame(),
			description = "Route 3 BUG CATCHER set 4 through trainer sight and " ..
				"DisplayEnemyTrainerTextAndStartBattle; dumped after first-mon selection",
		})
	end)
end)
