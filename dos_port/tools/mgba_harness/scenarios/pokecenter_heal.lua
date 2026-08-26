---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- pokecenter_heal — golden scenario for Pokemon Center healing flow:
-- DisplayPokemonCenterDialogue_ (engine/events/pokecenter.asm), HealParty,
-- AnimateHealingMachine, and SetLastBlackoutMap.
--
-- Talks to Nurse Joy at Viridian Pokemon Center with a damaged/statused/fainted
-- party, confirms YES to heal, observes the healing sequence and dialog, and
-- dumps GBSTATE.BIN asserting full party recovery.

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local gbtext = require("lib.gbtext")
local input = require("lib.input")
local dump = require("lib.dump")
local scenario = require("lib.scenario")
local seed = require("lib.seed")
local navigate = require("lib.navigate")

local sym = symbols.load()
local text = gbtext.load()
navigate.init(sym, text)

local VIRIDIAN_POKECENTER = 0x29 -- constants/map_constants.asm: map_const 7, 4
local MAP_WIDTH_BLOCKS = 7
local BIT_WARP_FROM_CUR_SCRIPT = 3 -- constants/ram_constants.asm
local SPRITE_FACING_UP = 4         -- constants/sprite_data_constants.asm

local TALK_Y, TALK_X = 3, 3 -- in front of counter facing Nurse Joy (object_event 3, 1)

scenario.run(function()
	navigate.boot_to_main_menu()
	navigate.new_game_to_bedroom()
	scenario.wait(60)

	scenario.exec(function()
		seed.player(sym, text:encode(seed.PLAYER_NAME))
		seed.party(sym, text:encode(seed.PLAYER_NAME))
		seed.items(sym)
		seed.pokedex(sym)
		seed.badges(sym)
		seed.money(sym, "\x00\x10\x00") -- $1,000

		-- Damage mon 1 to 1 HP + PSN (status $08), mon 2 to 0 HP (fainted)
		local mon1_hp = sym:addr("wPartyMon1HP")
		emu:write8(mon1_hp, 0x00)
		emu:write8(mon1_hp + 1, 0x01)
		emu:write8(sym:addr("wPartyMon1Status"), 0x08)

		local mon2_hp = sym:addr("wPartyMon2HP")
		emu:write8(mon2_hp, 0x00)
		emu:write8(mon2_hp + 1, 0x00)
		emu:write8(sym:addr("wPartyMon2Status"), 0x00)

		-- Script warp straight into VIRIDIAN_POKECENTER (block (0,0) view pointer)
		local view = sym:addr("wOverworldMap") + 3 * (MAP_WIDTH_BLOCKS + 6) + 3
		local ptr = sym:addr("wCurrentTileBlockMapViewPointer")
		emu:write8(ptr, view & 0xFF)
		emu:write8(ptr + 1, (view >> 8) & 0xFF)
		emu:write8(sym:addr("wYCoord"), TALK_Y)
		emu:write8(sym:addr("wXCoord"), TALK_X)
		emu:write8(sym:addr("wDestinationWarpID"), 0xFF)
		emu:write8(sym:addr("hWarpDestinationMap"), VIRIDIAN_POKECENTER)
		local flags = sym:addr("wStatusFlags3")
		emu:write8(flags, emu:read8(flags) | (1 << BIT_WARP_FROM_CUR_SCRIPT))
	end)

	do
		local deadline = scenario.frame() + 900
		while navigate.read8("wCurMap") ~= VIRIDIAN_POKECENTER do
			assert(scenario.frame() < deadline, "pokecenter_heal: script warp to Pokecenter never fired")
			scenario.wait(2)
		end
	end
	do
		local sy, sx = navigate.coords()
		assert(sy == TALK_Y and sx == TALK_X,
			("pokecenter_heal: warp moved player off (%d,%d) — at (%d,%d)"):format(TALK_Y, TALK_X, sy, sx))
	end
	scenario.wait(200)

	-- Turn UP toward Nurse Joy
	input.tap("UP", 2, 8)
	scenario.wait(30)


	-- Talk to Nurse Joy: tap A through greeting until HEAL/CANCEL menu appears
	local heal_menu_text = text:encode("HEAL")
	navigate.tap_until("A", heal_menu_text, 1800)
	scenario.wait(20)

	-- Select HEAL (item 0 at top of menu)
	input.tap("A", 2, 8)
	scenario.wait(30)
	input.tap("A", 2, 8) -- dismiss "OK. We'll need..." -> machine anim starts

	-- Wait through nurse bowing, machine animation, and audio jingle
	local fit_text = text:encode("fighting fit")
	navigate.dialog_until_text(fit_text, 3600)
	scenario.wait(20)
	input.tap("A", 2, 8) -- advance "fighting fit" prompt to farewell text

	local farewell_text = text:encode("you again!")
	navigate.wait_for_text(farewell_text, 1800)
	scenario.wait(20)
	navigate.dismiss_text(farewell_text, 600)
	scenario.wait(60) -- let overworld settle

	-- Assert that party is fully healed
	scenario.exec(function()
		local hp1_hi = emu:read8(sym:addr("wPartyMon1HP"))
		local hp1_lo = emu:read8(sym:addr("wPartyMon1HP") + 1)
		local max1_hi = emu:read8(sym:addr("wPartyMon1MaxHP"))
		local max1_lo = emu:read8(sym:addr("wPartyMon1MaxHP") + 1)
		local cur1 = (hp1_hi << 8) | hp1_lo
		local max1 = (max1_hi << 8) | max1_lo
		local st1 = emu:read8(sym:addr("wPartyMon1Status"))
		assert(cur1 == max1 and max1 > 0 and st1 == 0,
			("pokecenter_heal: party mon 1 not healed! HP=%d/%d, status=%d"):format(cur1, max1, st1))

		local hp2_hi = emu:read8(sym:addr("wPartyMon2HP"))
		local hp2_lo = emu:read8(sym:addr("wPartyMon2HP") + 1)
		local max2_hi = emu:read8(sym:addr("wPartyMon2MaxHP"))
		local max2_lo = emu:read8(sym:addr("wPartyMon2MaxHP") + 1)
		local cur2 = (hp2_hi << 8) | hp2_lo
		local max2 = (max2_hi << 8) | max2_lo
		local st2 = emu:read8(sym:addr("wPartyMon2Status"))
		assert(cur2 == max2 and max2 > 0 and st2 == 0,
			("pokecenter_heal: party mon 2 not healed! HP=%d/%d, status=%d"):format(cur2, max2, st2))

		dump.write("pokecenter_heal", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "Viridian Pokecenter healing flow complete: nurse animated healing machine, "
				.. "party healed from damaged/status/fainted to full, and farewell text dismissed",
		})
	end)
end)
