---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- in_game_trade — golden for the newly translated trade cinematic
-- (engine/movie/trade.asm) via the Route 2 Trade House NPC trade: index 1 in
-- data/events/trades.asm (TRADE_FOR_MILES) — give CLEFAIRY, receive MR.MIME
-- nicknamed "MILES". This is the single-player fidelity anchor for
-- retiring the InternalClockTradeAnim/TradeAnimCommon stubs (link cable plan
-- Stage 3 step 4): DoInGameTradeDialogue (engine/events/in_game_trades.asm)
-- through InternalClockTradeAnim -> TradeAnimCommon and back.
--
-- FLOW DRIVEN (pret engine/events/in_game_trades.asm, home/yes_no.asm,
-- home/pokemon.asm — cite file:line in the task report, this header only
-- summarizes): talk to GAMEBOY_KID -> WannaTrade1Text (2-page far text,
-- para-break needs one A) -> YesNoChoice (cursor DEFAULTS TO YES —
-- home/yes_no.asm:InitYesNoTextBoxParameters sets wTwoOptionMenuID=0, and
-- DisplayTwoOptionMenu only defaults to NO when that id's
-- BIT_SECOND_MENU_OPTION_DEFAULT is set, which YES_NO_MENU id 0 never sets —
-- so this scenario needs no cursor move here, only a confirming A) ->
-- DisplayPartyMenu (cursor defaults to slot 0 — home/pokemon.asm:
-- PartyMenuInit reads [wPartyAndBillsPCSavedMenuItem], 0 on this fresh boot)
-- -> select CLEFAIRY (party slot index 2: DebugNewGameParty's JIGGLYPUFF row
-- swapped species-for-species on the port side under DEBUG_TRADE_GOLDEN —
-- src/engine/debug/debug_party.asm; mirrored here as `party[3]`, Lua's
-- 1-indexed) -> ConnectCableText (1-page, `prompt`) -> InternalClockTradeAnim
-- (the real cinematic, ~30-40s per the plan doc) -> TradedForText ->
-- Thanks1Text ("Hey thanks!", `done`-terminated — no ▼, needs
-- navigate.dismiss_text's tap-until-gone idiom, not dialog_until_text's
-- arrow-driven one).
--
-- MAP/TILE: ROUTE_2_TRADE_HOUSE ($30, map_const width 4 —
-- constants/map_constants.asm) has GAMEBOY_KID at tile (y=1,x=4) facing DOWN
-- (`object_event 4, 1, SPRITE_GAMEBOY_KID, STAY, DOWN` —
-- data/maps/objects/Route2TradeHouse.asm; object_event's arg order is x,y —
-- macros/scripts/maps.asm:7-8). The talk tile is one south, (y=2,x=4) facing
-- UP — the standard shop-counter arrangement (every Mart/PC clerk in the
-- game stands the same way), open floor per Route2TradeHouse.blk's block
-- row 1 col 2 (block value 2) decoded through the HOUSE tileset.
--
-- DETERMINISM (see the task report for the full analysis): the received
-- MR.MIME's DVs (engine/pokemon/add_mon.asm:114-116, `call Random` x2 — NOT
-- the debug harness's PrepareNewGameDebug DV fixup, which only runs once at
-- initial party construction, before this mon exists) and OT ID
-- (engine/events/in_game_trades.asm:187-190, `call Random` -> hRandomAdd)
-- are both derived from Random_ (home/random.asm -> engine/math/random.asm),
-- which reads rDIV — i.e. real CPU-cycle timing, not a fixed seed. Two runs
-- of THIS EXACT script are reproducible (mGBA is a deterministic emulator;
-- identical input timing -> identical DIV samples), which is what the task's
-- self-check #2 (regen twice, diff) measures — but the bytes are NOT
-- predictable from the trade tables alone, and are not expected to land on
-- the same bytes the DOS port's own RNG timing HAL produces.

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

local ROUTE_2_TRADE_HOUSE = 0x30   -- constants/map_constants.asm: map_const 4, 4
local MAP_WIDTH_BLOCKS = 4
local BIT_WARP_FROM_CUR_SCRIPT = 3 -- constants/ram_constants.asm
local SPRITE_FACING_UP = 4         -- constants/sprite_data_constants.asm

-- One tile south of `object_event 4, 1, SPRITE_GAMEBOY_KID, STAY, DOWN` (see
-- header). Matches dos_port's TRADE_GOLDEN_Y/X defaults (dos_port/Makefile).
local TALK_Y, TALK_X = 2, 4

-- CLEFAIRY internal index $04 (constants/pokemon_constants.asm), swapped in
-- at seed.DEBUG_PARTY's JIGGLYPUFF slot (index 3) — same slot the port's
-- DEBUG_TRADE_GOLDEN swap uses (src/engine/debug/debug_party.asm).
local CLEFAIRY = 0x04
local party = {}
for i, mon in ipairs(seed.DEBUG_PARTY) do
	party[i] = mon
end
party[3] = { species = CLEFAIRY, level = 15 }

scenario.run(function()
	navigate.boot_to_main_menu()
	navigate.new_game_to_bedroom()
	scenario.wait(60)

	scenario.exec(function()
		-- The port gate calls PrepareNewGameDebug (DEBUG_SEED_PARTY), which
		-- seeds party + bag + dex + badges + money; every dump compares the
		-- full WRAM game-data block (dump.wram_regions), so the golden must
		-- seed all of it too — same rule party_menu.lua documents.
		seed.player(sym, text:encode(seed.PLAYER_NAME))
		seed.party(sym, text:encode(seed.PLAYER_NAME), party)
		seed.items(sym)
		seed.pokedex(sym)
		seed.badges(sym)
		seed.money(sym)

		-- Script warp straight into ROUTE_2_TRADE_HOUSE — battle_ghost.lua /
		-- slots_screen.lua's pattern: the hand-computed view pointer is
		-- pret's macros/coords.asm event_displacement, and it is
		-- self-checking (a wrong value puts the wrong tile under the player
		-- and the interaction below does nothing, so the scenario times out
		-- rather than dumping something plausible).
		local view = sym:addr("wOverworldMap") + 7 + MAP_WIDTH_BLOCKS
			+ (MAP_WIDTH_BLOCKS + 6) * (TALK_Y >> 1) + (TALK_X >> 1)
		local ptr = sym:addr("wCurrentTileBlockMapViewPointer")
		emu:write8(ptr, view & 0xFF)
		emu:write8(ptr + 1, (view >> 8) & 0xFF)
		emu:write8(sym:addr("wYCoord"), TALK_Y)
		emu:write8(sym:addr("wXCoord"), TALK_X)
		emu:write8(sym:addr("wDestinationWarpID"), 0xFF)
		emu:write8(sym:addr("hWarpDestinationMap"), ROUTE_2_TRADE_HOUSE)
		local flags = sym:addr("wStatusFlags3")
		emu:write8(flags, emu:read8(flags) | (1 << BIT_WARP_FROM_CUR_SCRIPT))
	end)

	do
		local deadline = scenario.frame() + 900
		while navigate.read8("wCurMap") ~= ROUTE_2_TRADE_HOUSE do
			assert(scenario.frame() < deadline,
				"in_game_trade: the script warp to ROUTE_2_TRADE_HOUSE never fired")
			scenario.wait(2)
		end
	end
	do
		local sy, sx = navigate.coords()
		assert(sy == TALK_Y and sx == TALK_X,
			("in_game_trade: the warp moved the player off (%d,%d) — at (%d,%d)")
				:format(TALK_Y, TALK_X, sy, sx))
	end
	scenario.wait(30)

	-- Turn to FACE the GAMEBOY_KID (press into his tile; NPC collision turns
	-- without stepping — cable_club_nolink.lua's facing rule).
	local turn_deadline = scenario.frame() + 300
	while navigate.read8("wSpritePlayerStateData1FacingDirection") ~= SPRITE_FACING_UP do
		assert(scenario.frame() < turn_deadline,
			"in_game_trade: player never turned to face UP")
		input.tap("UP", 2, 8)
	end
	do
		local ty, tx = navigate.coords()
		assert(ty == TALK_Y and tx == TALK_X,
			("in_game_trade: turning moved the player to (%d,%d) — the NPC tile "
				.. "should be collision-blocked"):format(ty, tx))
	end
	scenario.wait(10)

	-- Talk. Retried, not tapped once: wJoyIgnore is $FF for a long tail after
	-- the script warp's EnterMap (fish_old_rod.lua / surf_round_trip.lua's
	-- measurement), so a single A here is routinely swallowed. WannaTrade1Text
	-- is 2 pages ("I'm looking for / CLEFAIRY! Wanna" | "trade one for /
	-- MR.MIME? ") joined by one `para` break; tap_until's repeated A both
	-- outlasts the ignore tail AND advances the para break, stopping once page
	-- 2 (unique to the second half, unlike "CLEFAIRY" which is also on page 1)
	-- is on screen.
	navigate.tap_until("A", text:encode("MR.MIME"), 1800)
	scenario.wait(20)
	assert(navigate.tilemap():find(text:encode("YES"), 1, true),
		"in_game_trade: no YES/NO box after WannaTrade1Text")

	-- Confirm. Cursor already defaults to YES (see header) — one A accepts.
	input.tap("A", 2, 8)

	-- Party menu: pick CLEFAIRY. navigate.choose polls for the row+cursor and
	-- both climbs (DOWN) and confirms (A) — cursor_delta 1 because the party
	-- list's ▶ sits on the HP-bar row, one below the nickname (status_p1.lua
	-- precedent).
	navigate.choose(text:encode("CLEFAIRY"), 1800, 1)

	-- ConnectCableText (`prompt`) -> the real InternalClockTradeAnim cinematic
	-- (~30-40s per the plan doc — no on-screen text during it, so this loop
	-- just idles through it) -> TradedForText -> Thanks1Text. A generous
	-- deadline: the anim alone can be ~2000+ frames.
	navigate.dialog_until_text(text:encode("Hey thanks"), 10800)
	-- Thanks1Text is `done`-terminated (no ▼) — dismiss_text's tap-until-gone
	-- idiom, not dialog_until_text's arrow-driven one (navigate.lua header).
	navigate.dismiss_text(text:encode("Hey thanks"), 600)

	-- Settle: DoInGameTradeDialogue's `jp PrintText` for Thanks1Text has just
	-- returned (the dos_port dump hook fires at exactly this point — see
	-- src/scripts/Route2TradeHouse.asm), TextScriptEnd runs, and control is
	-- back in OverworldLoop — a stable idle overworld frame.
	scenario.wait(60)

	-- Confirm the trade actually landed before committing a golden: the
	-- received mon's species at the last party slot must be MR.MIME (internal
	-- index; base_stats/index_to_dex etc. not needed here). navigate.read8 /
	-- scenario.read_range yield internally (lib/scenario.lua), so these MUST
	-- run at body level, never nested inside a scenario.exec thunk (that thunk
	-- already runs on the main state via pcall, not the coroutine — nesting
	-- throws "attempt to yield from outside a coroutine").
	local MR_MIME = 0x2A -- constants/pokemon_constants.asm
	local count = navigate.read8("wPartyCount")
	local last_species = scenario.read_range(
		sym:addr("wPartySpecies") + count - 1, 1):byte(1)
	assert(count == 6 and last_species == MR_MIME,
		("in_game_trade: party count %d, last species $%02X — trade did not land")
			:format(count, last_species))

	scenario.exec(function()
		dump.write("in_game_trade", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "Route 2 Trade House: CLEFAIRY traded for MR.MIME "
				.. "\"MILES\" (data/events/trades.asm TRADE_FOR_MILES) through "
				.. "DoInGameTradeDialogue -> InternalClockTradeAnim -> "
				.. "TradeAnimCommon and back, dumped after the closing Thanks1Text "
				.. "is dismissed — a stable idle overworld frame. The received "
				.. "MR.MIME's DVs and OT ID are Random_ (rDIV-timing) derived, "
				.. "not fixed by the trade tables — see the task report.",
		})
	end)
end)
