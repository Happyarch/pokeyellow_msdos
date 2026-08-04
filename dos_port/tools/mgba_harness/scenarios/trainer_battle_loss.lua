---@diagnostic disable: undefined-global -- mGBA Lua runtime globals
-- trainer_battle_loss -- real Route 3 sight trainer, with one 1-HP player mon
-- and a pinned first enemy turn. The dump waits for blackout cleanup and proves
-- that EndTrainerBattle reset the script without setting the beaten event.

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

local REDS_HOUSE_1F, PALLET_TOWN, ROUTE_3 = 37, 0, 0x0E
local ROUTE_3_WIDTH, SIGHT_Y, SIGHT_X = 35, 6, 12
local BIT_WARP_FROM_CUR_SCRIPT = 3
local ROUTE3_EVENT_BYTE = 0xD7C2
local ROUTE3_EVENT_MASK = 1 << 2
local GUST = 0x10

local function regions()
	local out = dump.standard_regions(sym)
	out[#out + 1] = { name = "trainerResult", addr = sym:addr("wBuffer"), size = 24 }
	return out
end

local function read_be(label, size)
	local raw = scenario.read_range(sym:addr(label), size)
	local value = 0
	for i = 1, size do value = value * 256 + raw:byte(i) end
	return value
end

local function enter_trainer()
	navigate.boot_to_main_menu()
	navigate.new_game_to_bedroom()
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
		assert(scenario.frame() < deadline, "trainer_battle_loss: Route 3 warp never fired")
		scenario.wait(1)
	end
	deadline = scenario.frame() + 7200
	while navigate.read8("wIsInBattle") ~= 2 or navigate.read8("wEnemyMonSpecies") == 0 do
		assert(scenario.frame() < deadline, "trainer_battle_loss: trainer battle never initialized")
		input.tap("A", 2, 8)
	end
end

local function stage_result(terminal_result)
	scenario.exec(function()
		assert(terminal_result == 1, "trainer_battle_loss: terminal result is not loss")
		local bytes = { terminal_result, terminal_result }
		local function one(label) bytes[#bytes + 1] = emu:read8(sym:addr(label)) end
		one("wIsInBattle")
		one("wCurMapScript")
		one("wRoute3CurScript")
		bytes[#bytes + 1] = emu:read8(ROUTE3_EVENT_BYTE)
		one("wMiscFlags")
		for i = 0, 2 do bytes[#bytes + 1] = emu:read8(sym:addr("wPlayerMoney") + i) end
		one("wEnemyPartyCount")
		one("wEnemyMonPartyPos")
		for i = 0, 1 do bytes[#bytes + 1] = emu:read8(sym:addr("wEnemyMonHP") + i) end
		for i = 0, 1 do bytes[#bytes + 1] = emu:read8(sym:addr("wEnemyMon1HP") + i) end
		one("wPartyCount")
		for i = 0, 1 do bytes[#bytes + 1] = emu:read8(sym:addr("wPartyMon1HP") + i) end
		for i = 0, 2 do bytes[#bytes + 1] = emu:read8(sym:addr("wPartyMon1Exp") + i) end
		one("wBattleType")
		one("wCurOpponent")
		assert(#bytes == 24, "trainer_battle_loss: projection length drift")
		for i, value in ipairs(bytes) do emu:write8(sym:addr("wBuffer") + i - 1, value) end
		dump.write("trainer_battle_loss", regions(), {
			frame = scenario.frame(),
			description = "Route 3 trainer terminal loss through enemy damage, blackout, " ..
				"EndTrainerBattle no-flag path and blackout money/heal cleanup",
		})
	end)
end

scenario.run(function()
	enter_trainer()
	scenario.exec(function()
		emu:write8(sym:addr("wPartyCount"), 1)
		emu:write8(sym:addr("wPartyMon1HP"), 0)
		emu:write8(sym:addr("wPartyMon1HP") + 1, 1)
		emu:write8(sym:addr("wBattleMonHP"), 0)
		emu:write8(sym:addr("wBattleMonHP") + 1, 1)
		emu:write8(sym:addr("wBattleMonSpeed"), 0)
		emu:write8(sym:addr("wBattleMonSpeed") + 1, 0)
		emu:write8(sym:addr("wEnemyMonSpeed"), 0xFF)
		emu:write8(sym:addr("wEnemyMonSpeed") + 1, 0xFF)
		emu:write8(sym:addr("wEnemyMonHP"), 0)
		emu:write8(sym:addr("wEnemyMonHP") + 1, 0x1E)
		emu:write8(sym:addr("wEnemyMon1HP"), 0)
		emu:write8(sym:addr("wEnemyMon1HP") + 1, 0x1E)
		for i = 0, 3 do
			emu:write8(sym:addr("wEnemyMonMoves") + i, GUST)
			emu:write8(sym:addr("wEnemyMonPP") + i, 35)
		end
	end)

	navigate.dialog_until_text(text:encode("FIGHT"), 3600)
	scenario.wait(30)
	navigate.choose(text:encode("FIGHT"))
	navigate.ensure_text("A", text:encode("STRENGTH"), 3600)
	scenario.wait(30)
	navigate.choose(text:encode("STRENGTH"))

	local done = false
	local saw_loss_result = false
	for _ = 1, 7200 do
		if navigate.read8("wBattleResult") == 1 then saw_loss_result = true end
		local event = scenario.read_range(ROUTE3_EVENT_BYTE, 1):byte(1)
		if (event & ROUTE3_EVENT_MASK) == 0
			and navigate.read8("wRoute3CurScript") == 0
			and navigate.read8("wIsInBattle") == 0
			and read_be("wPartyMon1HP", 2) > 0
			and read_be("wPlayerMoney", 3) ~= 0x999999 then
			done = true
			break
		end
		input.tap("A", 2, 8)
	end
	assert(done, "trainer_battle_loss: blackout cleanup never completed without setting the trainer flag")
	assert(saw_loss_result, "trainer_battle_loss: blackout completed without publishing a loss result")
	stage_result(1)
end)
