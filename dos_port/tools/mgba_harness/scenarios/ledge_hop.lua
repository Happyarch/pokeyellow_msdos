---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- ledge_hop — golden for the port's DEBUG_LEDGE gate (differ class "datastruct":
-- WRAM game data only, no video compare).
--
-- The suite's only ledge coverage, and the currency mechanism for
-- regression-overworld-ledge-hop-never-advanced: a real DOWN press arms the hop
-- (HandleLedges: BIT_LEDGE_OR_FISHING, wJoyIgnore=$FF, two simulated DOWN
-- steps), the live overworld loop plays it out, HandleMidJump's teardown clears
-- the state, and a SECOND DOWN takes a normal post-teardown step. If the
-- teardown ever stops running again, the second press is swallowed
-- (wJoyIgnore stays $FF) and wYCoord/wMovementFlags/wJoyIgnore all diverge.
--
-- THE TILE MAP, measured off pret data (maps/Route1.blk + gfx/blocksets/
-- overworld.bst, OVERWORLD tileset) rather than eyeballed:
--   (8,7)  = $2C  land; LedgeTiles has (FACING_DOWN, $2C, $37, PAD_DOWN)
--   (9,7)  = $37  the ledge tile (impassable on foot)  <- hop crosses it
--   (10,7) = $2C  landing tile
--   (11,7) = $2C  post-teardown step target
-- Column 7 avoids both Route 1 NPCs (YOUNGSTER1 wanders UP_DOWN in column 5,
-- YOUNGSTER2 LEFT_RIGHT on row 13) and no tile on the path is grass, so neither
-- NPC wander nor a wild encounter can diverge the sides.

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

local REDS_HOUSE_1F = 37 -- pret constants/map_constants.asm
local PALLET_TOWN = 0
local ROUTE_1 = 12
local ROUTE_1_WIDTH = 10 -- blocks; constants/map_constants.asm
local BIT_WARP_FROM_CUR_SCRIPT = 3 -- constants/ram_constants.asm
local BIT_LEDGE_OR_FISHING = 6     -- constants/ram_constants.asm (wMovementFlags)

-- Mirrors the %ifdef DEBUG_LEDGE gbregion rows in dos_port/src/debug/debug_dump.asm.
-- The differ joins by NAME and cross-checks each address, so the two lists must
-- agree. Scenario-local on purpose: adding them to dump.wram_regions would change
-- every committed golden's .bin layout.
local function regions()
	local r = dump.standard_regions(sym)
	for _, x in ipairs({
		{ name = "wPlayerMapPos", addr = sym:addr("wCurMap"), size = 5 },
		{ name = "wMovementFlags", addr = sym:addr("wMovementFlags"), size = 1 },
		{ name = "wStatusFlags5to7", addr = sym:addr("wStatusFlags5"), size = 4 },
		{ name = "wSimJoypad", addr = sym:addr("wSimulatedJoypadStatesIndex"), size = 2 },
		{ name = "wSimJoypadEnd", addr = sym:addr("wSimulatedJoypadStatesEnd"), size = 2 },
		{ name = "wJoyIgnore", addr = sym:addr("wJoyIgnore"), size = 1 },
		{ name = "wPlayerDir", addr = sym:addr("wPlayerDirection"), size = 1 },
		{ name = "wWalkCounter", addr = sym:addr("wWalkCounter"), size = 1 },
	}) do
		r[#r + 1] = x
	end
	return r
end

scenario.run(function()
	navigate.boot_to_main_menu()
	navigate.new_game_to_bedroom()

	-- bedroom (2F) -> 1F -> Pallet Town (route notes in start_menu.lua / sight.lua)
	navigate.walk("RIGHT", 1)
	navigate.walk("UP", 5)
	navigate.walk_until_map("RIGHT", REDS_HOUSE_1F)
	navigate.walk("DOWN", 6)
	navigate.walk("LEFT", 4)
	navigate.walk_until_map("DOWN", PALLET_TOWN)
	navigate.walk("DOWN", 1)
	scenario.wait(60) -- let the arrival's EnterMap finish before seeding coords

	scenario.exec(function()
		seed.debug_new_game(sym, text:encode(seed.PLAYER_NAME))
		-- Script warp onto Route 1 at (8,7) — the mechanism lib/sight.lua uses
		-- (see its header for why a same-map coordinate poke does not work and
		-- why the view pointer must be computed by hand; the formula is pret's
		-- macros/coords.asm event_displacement, and it is self-checking: a wrong
		-- value puts the wrong tile under the player and the hop never arms,
		-- tripping the deadline below instead of producing a quietly wrong golden).
		local view = sym:addr("wOverworldMap") + 7 + ROUTE_1_WIDTH
			+ (ROUTE_1_WIDTH + 6) * (8 >> 1) + (7 >> 1)
		local ptr = sym:addr("wCurrentTileBlockMapViewPointer")
		emu:write8(ptr, view & 0xFF)
		emu:write8(ptr + 1, (view >> 8) & 0xFF)
		emu:write8(sym:addr("wYCoord"), 8)
		emu:write8(sym:addr("wXCoord"), 7)
		emu:write8(sym:addr("wDestinationWarpID"), 0xFF)
		emu:write8(sym:addr("hWarpDestinationMap"), ROUTE_1)
		local flags = sym:addr("wStatusFlags3")
		emu:write8(flags, emu:read8(flags) | (1 << BIT_WARP_FROM_CUR_SCRIPT))
	end)
	do
		local deadline = scenario.frame() + 900
		while navigate.read8("wCurMap") ~= ROUTE_1 do
			assert(scenario.frame() < deadline,
				"ledge_hop: the script warp to Route 1 never fired")
			scenario.wait(2)
		end
	end
	do
		local y, x = navigate.coords()
		assert(y == 8 and x == 7,
			("ledge_hop: the warp moved the player off (8,7) — at (%d,%d)"):format(y, x))
	end
	scenario.wait(30)

	-- Press DOWN into the ledge. Retried, not tapped once: wJoyIgnore is $FF for
	-- the whole of EnterMap and is cleared only on its last line, so a single tap
	-- after the warp can be swallowed (same measurement as surf_round_trip's bump).
	-- The WHOLE hop (arm + two 8-frame simulated steps + 16-iteration arc +
	-- teardown) completes in ~20-35 frames — less than one 42-frame tap cycle —
	-- so this loop must accept "already landed on (10,7), state torn down" and
	-- must NOT insist on observing BIT_LEDGE_OR_FISHING mid-flight (measured: the
	-- first cut asserted 'MOVED without a hop' at (10,7), which IS the hop's
	-- outcome, seen after the fact).
	do
		local deadline = scenario.frame() + 900
		while true do
			local y, x = navigate.coords()
			if y == 10 and x == 7
				and navigate.read8("wMovementFlags") & (1 << BIT_LEDGE_OR_FISHING) == 0
				and navigate.read8("wWalkCounter") == 0 then
				break -- hop played out and tore down
			end
			assert((y == 8 or y == 9 or y == 10) and x == 7,
				("ledge_hop: player at (%d,%d) — a normal walk to y=9 is impossible " ..
				 "((9,7) is the $37 ledge tile), so something other than the hop moved us")
				:format(y, x))
			assert(scenario.frame() < deadline,
				"ledge_hop: the hop never armed or never tore down " ..
				"(HandleLedges / HandleMidJump)")
			if y == 8 and navigate.read8("wMovementFlags")
				& (1 << BIT_LEDGE_OR_FISHING) == 0 then
				input.tap("DOWN", 12, 30) -- not armed yet: (re)press into the ledge
			else
				scenario.wait(2) -- mid-hop or mid-teardown: just wait
			end
		end
	end
	scenario.log("ledge_hop: hop landed and tore down at frame " .. scenario.frame())
	scenario.wait(30)

	-- Post-teardown NORMAL step to (11,7) — the byte that proves input works again.
	do
		local deadline = scenario.frame() + 900
		while true do
			local y, x = navigate.coords()
			if y == 11 and x == 7 then break end
			assert(scenario.frame() < deadline,
				"ledge_hop: the post-teardown DOWN step never moved the player to (11,7)")
			input.tap("DOWN", 12, 30)
		end
		while navigate.read8("wWalkCounter") ~= 0 do
			scenario.wait(2)
		end
	end
	scenario.wait(60) -- settle

	scenario.exec(function()
		dump.write("ledge_hop", regions(), {
			frame = scenario.frame(),
			description = "Route 1 ledge hop: DOWN at (8,7) arms the hop over the $37 " ..
				"ledge tile, the two simulated steps land on (10,7), HandleMidJump " ..
				"tears the state down, and a post-teardown DOWN step reaches (11,7)",
		})
	end)
end)
