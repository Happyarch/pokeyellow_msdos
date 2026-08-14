---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- slots_screen — the LAST unmeasured row in the CGB colour plan's Stage 0 table.
--
-- WHAT THIS IS FOR, and why it needs no port support at all. Stage 0 asked, for
-- every screen: can its per-cell CGB attributes be re-expressed per TILE ID? A
-- screen that can needs no compositor work. Twelve of thirteen tables were
-- measured against goldens; `Slots` never was, and got mislabelled "blocked" for
-- want of this file.
--
-- The census runs on the GOLDEN'S OWN wTileMap + vram_tiles: does any tile id
-- appear under two palettes that differ where that tile actually has pixels?
-- That is a property of the HARDWARE screen. It needs NOTHING from the port —
-- which matters here, because the port cannot draw this screen at all:
-- dos_port/src/engine/slots/game_corner_slots.asm is written but absent from the
-- Makefile source list, so the stub's `ret` is what links (zero callers). This
-- scenario is therefore a MEASUREMENT capture, not a port-vs-hardware diff, and
-- it is expected to have no port side until that feature is linked.
--
-- WHY SLOTS IS THE LIKELY COLLIDER. PalPacket_Slots is
--   PAL_SET PAL_SLOTS1, PAL_SLOTS2, PAL_SLOTS3, PAL_SLOTS4
-- the only screen in the game using four DISTINCT palettes. A slot machine shows
-- the same reel-symbol graphics in three side-by-side columns. If two reels draw
-- the same symbol tile id under palettes that differ at an index that symbol
-- uses, per-tile-id resolution cannot express it — exactly the collision class
-- the per-cell attribute layer exists for.
--
-- ENTRY, and the one thing to check on first run. Reaching Celadon on foot is a
-- long route, so this uses battle_ghost.lua's script-warp seeding verbatim: seed
-- a debug new game, then warp straight into GAME_CORNER ($87). The player is
-- then stood at a machine and presses A.
--
-- SLOT_X / SLOT_Y ARE DERIVED FROM THE HIDDEN-EVENT TABLE, not guessed. In Gen 1
-- the slot machines are hidden objects, and the table stores the OBJECT's tile,
-- not the player's:
--   data/events/hidden_events.asm:95-96  `hidden_event` emits `db \2` (y) then
--       `db \1` (x), so `hidden_event 18, 15, StartSlotMachine, ANY_FACING` is
--       the machine at y=15, x=18 — the argument order in the source is (x, y).
--   engine/overworld/hidden_events.asm:85-88  `.facingRight` does
--       `ld a,[wXCoord] / inc a / cp c`, then compares wYCoord against b — so a
--       player facing RIGHT matches the object at (same y, wXCoord + 1).
-- Hence the standing tile is (y = 15, x = 18 - 1).
--
-- *** THE MACHINES ARE ONLY PLAYABLE FROM THE SIDE — MEASURED, and it is the
-- opposite of what the map's shape suggests. *** The obvious approach is to
-- stand on the open floor below the bottom machine row and face UP. It runs, the
-- hidden object matches, and NOTHING HAPPENS: `AbleToPlaySlotsCheck`
-- (engine/slots/game_corner_slots2.asm:2-4) opens with
--     ld a, [wSpritePlayerStateData1ImageIndex] / and $8 / jr z, .done
-- and for the player that byte tracks facing, whose constants are
--     DOWN $00  UP $04  LEFT $08  RIGHT $0C   (constants/sprite_data_constants.asm:3-6)
-- so bit 3 is set for LEFT and RIGHT ONLY. Facing UP or DOWN falls straight to
-- `.done` with a = 0, storing wCanPlaySlots = 0, and `StartSlotMachine` returns
-- without drawing or printing anything at all.
-- Measured on the ROM at (16,18) facing UP: facing=$04, imageidx=$04,
-- wCanPlaySlots=0, reels never live for 3600 frames. That silence is why this is
-- worth a comment — the failure mode announces nothing.
-- It also explains the map: the hidden events sit at x = 1, 6, 7, 12, 13, 18,
-- which are exactly the columns flanking the walkable aisles at x = 2, 5, 8, 11,
-- 14, 17. You stand in an aisle and face sideways.
--
-- ANY_FACING is the hidden object's function ARGUMENT (a slots-message selector),
-- not a facing relaxation: three machines carry SLOTS_OUTOFORDER /
-- SLOTS_OUTTOLUNCH / SLOTS_SOMEONESKEYS instead and refuse to play. Fallback
-- aisle/machine pairs, all ANY_FACING at y = 15:
--     x=17 face RIGHT -> 18     x=14 face LEFT  -> 13
--     x=11 face RIGHT -> 12     x=8  face LEFT  -> 7
--     x=5  face RIGHT -> 6      x=2  face LEFT  -> 1
-- Walkability of the chosen tile is corroborated by an NPC: GAMECORNER_GAMBLER
-- stands at (11,15) (data/maps/objects/GameCorner.asm:33), the same block ($21)
-- and the same quadrant as (17,15).
--
-- It stays self-checking regardless: the landed coords are asserted and the wait
-- for the reels has a deadline, so a wrong coordinate FAILS LOUDLY rather than
-- producing a quietly wrong golden.

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

local GAME_CORNER = 0x87          -- constants/map_constants.asm:217
local GAME_CORNER_WIDTH = 10      -- blocks; same line
local BIT_WARP_FROM_CUR_SCRIPT = 3 -- constants/ram_constants.asm
local SEED_COINS = 0x50           -- BCD; plenty to bet with
local COIN_CASE = 0x45            -- constants/item_constants.asm:81

-- The aisle tile the player stands on — see the header. Machine at (y=15, x=18);
-- stand one tile WEST of it and face RIGHT (facing UP cannot play a machine).
local SLOT_Y, SLOT_X = 15, 17
local SLOT_FACE = "RIGHT"

scenario.run(function()
	navigate.boot_to_main_menu()
	navigate.new_game_to_bedroom()
	scenario.wait(60)

	scenario.exec(function()
		seed.debug_new_game(sym, text:encode(seed.PLAYER_NAME))

		-- Script warp straight into the Game Corner. The hand-computed view
		-- pointer is pret's macros/coords.asm event_displacement, exactly as
		-- battle_ghost.lua does it, and it is self-checking: a wrong value puts
		-- the wrong tile under the player and the A press below does nothing,
		-- so the scenario times out instead of dumping something plausible.
		local view = sym:addr("wOverworldMap") + 7 + GAME_CORNER_WIDTH
			+ (GAME_CORNER_WIDTH + 6) * (SLOT_Y >> 1) + (SLOT_X >> 1)
		local ptr = sym:addr("wCurrentTileBlockMapViewPointer")
		emu:write8(ptr, view & 0xFF)
		emu:write8(ptr + 1, (view >> 8) & 0xFF)
		emu:write8(sym:addr("wYCoord"), SLOT_Y)
		emu:write8(sym:addr("wXCoord"), SLOT_X)
		emu:write8(sym:addr("wDestinationWarpID"), 0xFF)
		emu:write8(sym:addr("hWarpDestinationMap"), GAME_CORNER)
		local flags = sym:addr("wStatusFlags3")
		emu:write8(flags, emu:read8(flags) | (1 << BIT_WARP_FROM_CUR_SCRIPT))
	end)

	do
		local deadline = scenario.frame() + 900
		while navigate.read8("wCurMap") ~= GAME_CORNER do
			assert(scenario.frame() < deadline,
				"slots_screen: the script warp to GAME_CORNER never fired")
			scenario.wait(2)
		end
	end
	do
		local sy, sx = navigate.coords()
		assert(sy == SLOT_Y and sx == SLOT_X,
			("slots_screen: the warp moved the player off (%d,%d) — at (%d,%d)")
				:format(SLOT_Y, SLOT_X, sy, sx))
	end
	scenario.wait(30)

	-- AbleToPlaySlotsCheck (engine/slots/game_corner_slots2.asm:1-23) gates the
	-- machine on TWO things, and missing either just prints a text box and
	-- returns -- the reels never draw and nothing announces why:
	--   * a COIN_CASE in the bag (`ld b, COIN_CASE / predef GetQuantityOfItemInBag`)
	--   * wPlayerCoins nonzero  (`ld a,[hli] / or [hl] / jr nz, .done`)
	-- So seed both. wPlayerCoins is BCD, big-endian like every GB value here.
	scenario.exec(function()
		seed.items(sym, { { COIN_CASE, 1 } })
		local coins = sym:addr("wPlayerCoins")
		emu:write8(coins, 0x00)
		emu:write8(coins + 1, SEED_COINS)
	end)

	-- Turn to FACE the machine. Not `navigate.walk(SLOT_FACE, 1)`: the tile east
	-- is the machine itself and is solid, so the step is refused and a walk
	-- helper that waits on a coordinate change would time out. Tapping against a
	-- wall still sets wSpritePlayerStateData1FacingDirection, which is what both
	-- CheckIfCoordsInFrontOfPlayerMatch and AbleToPlaySlotsCheck read.
	input.tap(SLOT_FACE, 8, 24)
	input.tap(SLOT_FACE, 8, 24)

	-- Start it. Pulsed, not held: the confirmation stream
	-- ends in its own prompt and a held A never releases it.
	local started, last_probe = false, -1
	do
		local deadline = scenario.frame() + 3600
		while not started do
			assert(scenario.frame() < deadline,
				"slots_screen: the slot screen never came up — SLOT_X/SLOT_Y are " ..
				"provisional (see this file's header) and are the first thing to check")
			input.tap("A", 8, 40)
			if (scenario.frame() // 240) ~= last_probe then
				last_probe = scenario.frame() // 240
				local py, px = navigate.coords()
				scenario.log(("slots_screen probe f=%d y=%d x=%d facing=$%02X " ..
					"curmap=%d imageidx=$%02X canplay=%d slip=%d")
					:format(scenario.frame(), py, px,
						navigate.read8("wSpritePlayerStateData1FacingDirection"),
						navigate.read8("wCurMap"),
						navigate.read8("wSpritePlayerStateData1ImageIndex"),
						navigate.read8("wCanPlaySlots"),
						navigate.read8("wSlotMachineWheel1SlipCounter")))
			end
			-- wSlotMachineWheel1SlipCounter is set to 4 as the spin begins
			-- (engine/slots/slot_machine.asm), so a nonzero value means the reels
			-- are live and the screen is fully drawn.
			started = navigate.read8("wSlotMachineWheel1SlipCounter") ~= 0
		end
	end
	scenario.log(("slots_screen: reels live at frame %d"):format(scenario.frame()))

	-- Let the wheels settle so the captured tilemap holds real symbols rather
	-- than a mid-spin blur.
	scenario.wait(180)

	scenario.exec(function()
		dump.write("slots_screen", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "Celadon Game Corner slot machine, reels drawn — the " ..
				"capture for the CGB plan's Stage 0 collision census on the " ..
				"four-palette Slots screen (PAL_SLOTS1-4)",
		})
	end)
end)
