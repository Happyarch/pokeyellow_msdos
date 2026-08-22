---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- cable_club_nolink — golden for the link receptionist's NO-PEER path
-- (pret engine/link/cable_club_npc.asm, link cable plan Stage 2 step 4).
--
-- WHAT IT PROVES: talking to the Pewter Pokecenter link receptionist with the
-- pokedex but NO link partner runs the real dispatch —
--   OverworldLoop A press -> IsSpriteOrSignInFrontOfPlayer -> (port:
--   CheckNPCInteraction -> generated SCRIPT entry -> CableClubReceptionistScript;
--   ROM: DisplayTextID's TX_SCRIPT_CABLE_CLUB_RECEPTIONIST case) -> CableClubNPC
-- through the WelcomeText, the full 90-frame .establishConnectionLoop clock
-- race (each frame arms as slave then kicks as master; with no partner nothing
-- is delivered), wLinkTimeoutCounter expiring into .failedToEstablishConnection,
-- and the "This area is / reserved for 2 / friends who are / linked by cable."
-- text — whose two `cont` page waits both sides answer with A. The dump lands
-- with the LAST page on screen and .didNotConnect's WRAM aftermath latched:
-- hSerialConnectionStatus $FF, wUnknownSerialCounter zeroed, poll count zeroed.
--
-- SCOPE, stated so it is not inferred: this is the receptionist's TIMEOUT path
-- only. The connected path (save prompt -> Serial_SyncAndExchangeNybble ->
-- LinkMenu) has no single-instance golden — it needs a peer, and it is covered
-- end-to-end by tools/linkcheck.sh (two DOSBox-X instances over a nullmodem).
--
-- MAP/TILE (verified against maps/PewterPokecenter.blk decoded through
-- gfx/blocksets/pokecenter.bst + Pokecenter_Coll): the receptionist is
-- `object_event 11, 2, SPRITE_LINK_RECEPTIONIST, STAY, DOWN` and the tile below
-- her, (y=3, x=11), is open floor reachable from the door — the real talking
-- tile. Facing is turned by pressing UP into her tile: NPC collision blocks the
-- step, so the tap turns without moving (hidden_object.lua's facing rule).
-- Every NPC on this map is STAY, so nothing wanders between runs.

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
local BIT_WARP_FROM_CUR_SCRIPT = 3 -- constants/ram_constants.asm
local EVENT_GOT_POKEDEX = 37 -- pret constants/event_constants.asm

local PEWTER_POKECENTER = 0x3A -- constants/map_constants.asm: map_const 7, 4
local MAP_WIDTH_BLOCKS = 7
local TALK_Y, TALK_X = 3, 11 -- below `object_event 11, 2` (see header)
local SPRITE_FACING_UP = 4

-- The link-state WRAM the no-peer path mutates, on top of dump.standard_regions.
-- MIRRORED BY the %ifdef DEBUG_CABLECLUB gbregion rows in
-- dos_port/src/debug/debug_dump.asm — the differ joins by NAME, so the two lists
-- must agree. Scenario-local on purpose (dump.wram_regions would relayout every
-- committed golden).
local function regions()
	local r = dump.standard_regions(sym)
	for _, extra in ipairs({
		{ name = "linkStatus",    addr = sym:addr("hSerialConnectionStatus"), size = 1 },
		{ name = "linkTimeout",   addr = sym:addr("wLinkTimeoutCounter"),     size = 1 },
		{ name = "serialCounter", addr = sym:addr("wUnknownSerialCounter"),   size = 2 },
		{ name = "menuPollCount", addr = sym:addr("wMenuJoypadPollCount"),    size = 1 },
		{ name = "wPlayerMapPos", addr = sym:addr("wCurMap"),                 size = 5 },
	}) do
		r[#r + 1] = extra
	end
	return r
end

scenario.run(function()
	navigate.boot_to_main_menu()
	navigate.new_game_to_bedroom()

	-- bedroom (2F) -> 1F -> Pallet Town (route notes in start_menu.lua)
	navigate.walk("RIGHT", 1)
	navigate.walk("UP", 5)
	navigate.walk_until_map("RIGHT", REDS_HOUSE_1F)
	navigate.walk("DOWN", 6)
	navigate.walk("LEFT", 4)
	navigate.walk_until_map("DOWN", PALLET_TOWN)
	-- Settle before arming the script warp: see sight.lua's ⚠ header note
	-- (hWarpDestinationMap is a many-way HRAM union; armed mid-EnterMap it is
	-- consumed by the wrong consumer or overwritten).
	navigate.walk("DOWN", 1)
	scenario.wait(60)

	scenario.exec(function()
		seed.player(sym, text:encode(seed.PLAYER_NAME))
		-- The receptionist's gate: without the pokedex CableClubNPC takes the
		-- "making preparations" branch, not the 90-frame race. The port gate
		-- seeds the same flag (DEBUG_CABLECLUB, src/home/overworld.asm).
		seed.set_event(sym, EVENT_GOT_POKEDEX)
		-- sight.lua's script warp: coords survive because wDestinationWarpID=$FF
		-- skips LoadDestinationWarpPosition, so the view pointer must be derived
		-- here with pret's own formula (macros/coords.asm, event_displacement).
		local view = sym:addr("wOverworldMap") + 7 + MAP_WIDTH_BLOCKS
			+ (MAP_WIDTH_BLOCKS + 6) * (TALK_Y >> 1) + (TALK_X >> 1)
		local ptr = sym:addr("wCurrentTileBlockMapViewPointer")
		emu:write8(ptr, view & 0xFF)
		emu:write8(ptr + 1, (view >> 8) & 0xFF)
		emu:write8(sym:addr("wYCoord"), TALK_Y)
		emu:write8(sym:addr("wXCoord"), TALK_X)
		emu:write8(sym:addr("wDestinationWarpID"), 0xFF)
		emu:write8(sym:addr("hWarpDestinationMap"), PEWTER_POKECENTER)
		local flags = sym:addr("wStatusFlags3")
		emu:write8(flags, emu:read8(flags) | (1 << BIT_WARP_FROM_CUR_SCRIPT))
	end)

	local deadline = scenario.frame() + 900
	while navigate.read8("wCurMap") ~= PEWTER_POKECENTER do
		assert(scenario.frame() < deadline,
			"cable_club_nolink: script warp to the Pokecenter never fired")
		scenario.wait(1)
	end
	local y, x = navigate.coords()
	assert(y == TALK_Y and x == TALK_X,
		("cable_club_nolink: warp moved the player off the talk tile — got (%d,%d)")
			:format(y, x))

	-- Turn to face the receptionist (press into her tile; NPC collision turns
	-- without stepping — hidden_object.lua's facing rule, incl. why a direct
	-- facing write does not survive the overworld loop).
	local turn_deadline = scenario.frame() + 300
	while navigate.read8("wSpritePlayerStateData1FacingDirection") ~= SPRITE_FACING_UP do
		assert(scenario.frame() < turn_deadline,
			"cable_club_nolink: player never turned to face UP")
		input.tap("UP", 2, 8)
	end
	local ty, tx = navigate.coords()
	assert(ty == TALK_Y and tx == TALK_X,
		("cable_club_nolink: turning moved the player to (%d,%d) — the receptionist "
			.. "tile should be NPC-blocked"):format(ty, tx))
	scenario.wait(10)

	-- Talk. The welcome text ("Welcome to the / Cable Club!") ends in `done`
	-- with no wait, the 90-frame race runs with no input, and the failure text
	-- then breaks twice on `cont`. dialog_until_text taps A only on the ▼
	-- prompt, so it answers exactly those two page waits and stops when the
	-- LAST page ("friends who are / linked by cable.") is on screen — the same
	-- pages the port's AUTOKEY_APRESS answers.
	input.tap("A", 2, 8)
	local last_page = text:encode("linked by cable.")
	navigate.dialog_until_text(last_page, 1200)
	-- Settle: PrintText returns, CableClubNPC's .didNotConnect latches the WRAM
	-- aftermath, and DisplayTextID's tail parks holding the box open.
	scenario.wait(60)
	assert(navigate.tilemap():find(last_page, 1, true),
		"cable_club_nolink: failure-text last page vanished after settling")

	scenario.exec(function()
		dump.write("cable_club_nolink", regions(), {
			frame = scenario.frame(),
			description = "Pewter Pokecenter link receptionist talked to with no "
				.. "peer: 90-frame establish race expired, failure text last page "
				.. "on screen, .didNotConnect aftermath in WRAM",
		})
	end)
end)
