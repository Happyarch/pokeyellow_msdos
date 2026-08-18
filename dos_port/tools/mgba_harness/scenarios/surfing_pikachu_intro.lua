---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- surfing_pikachu_intro — golden for the port's DEBUG_SURFING_PIKACHU_INTRO gate
-- (backlog item 34 / archived docs/plans/surfing_pikachu.md Stage 8).
--
-- WHY THE INTRO, NOT GAMEPLAY: SurfingPikachuMinigame's water/wave/scoring loop
-- is driven by Random (SurfingMinigame_ChooseNextWaveSequence and the wave
-- generator) and by a 3-frame-buffered joypad (SurfingPikachu_GetJoypad_3FrameBuffer,
-- pret engine/minigame/surfing_pikachu.asm:2531) — RNG-derived state is
-- structurally uncomparable across emulators here (see fish_old_rod.lua's header
-- and tools/mgba_harness/scenarios/battle_thrash.lua:29). SurfingPikachuMinigameIntro
-- draws a fully scripted "Pikachu's Beach" title screen via
-- DrawSurfingPikachuMinigameIntroBackground with NO RNG input at all, so it is
-- the only deterministic surface this minigame offers.
--
-- FORCED ENTRY, SYMMETRIC WITH THE PORT GATE (maintainer directive). The port's
-- RunSurfingPikachuTest (dos_port/src/debug/debug_dump.asm ~7329) does not
-- navigate to the Summer Beach House and talk to the NPC — it calls
-- PrepareNewGameDebug, ORs the SURF_SELECT bit into wPikachuMapScriptFlags, and
-- calls SurfingPikachuMinigame directly. This scenario is symmetric: it seeds
-- state with seed.debug_new_game (the same seed every PrepareNewGameDebug-fed
-- golden scenario uses — see status_p1.lua, fish_old_rod.lua, etc. — byte-for-byte
-- matching PrepareNewGameDebug's party/bag/pokedex/money/badges, so no wram_skip
-- is needed for them), then drives the game's OWN dispatch into the minigame
-- through the real Summer Beach House NPC script (scripts/SummerBeachHouse.asm:
-- SummerBeachHouseSurfinDudeText) via the established script-warp technique
-- (lib/sight.lua; see surf_round_trip.lua's header for why a same-map coordinate
-- poke doesn't work and the script-warp does). This is NOT a multi-hour Route 19
-- journey: SUMMER_BEACH_HOUSE ($F8) is warped into directly, landing next to its
-- one interactive NPC (data/maps/objects/SummerBeachHouse.asm:
-- object_event 2, 3, SPRITE_FISHING_GURU, STAY, DOWN -- object_event's params
-- are (X, Y), so this is raw X=2, Y=3; confirmed against route3_sight.lua,
-- whose spec.y=6 matches Route3's own `object_event 10, 6, SPRITE_YOUNGSTER`
-- raw Y verbatim), which is then engaged
-- with two real button presses (A to talk, A again for the YES/NO prompt — YES
-- is the default cursor position, same convention as bills_pc_ops.lua's release
-- confirm). Every instruction from the warp onward is the SAME farcall
-- SurfingPikachuMinigame -> SurfingPikachuMinigameIntro chain pret ships.
--
-- BYPASSING THE NPC'S OWN PRECONDITION. SummerBeachHouseSurfinDudeText itself
-- gates on wPikachuSpawnStateFlags bit BIT_PIKACHU_SPAWN_SURFING (constants/
-- pikachu_emotion_constants.asm:57 -- bit 6) before offering the minigame; this
-- flag is not something PrepareNewGameDebug or the normal new-game flow sets
-- (it is set only after riding Surf near the beach on a real playthrough), so
-- it is seeded directly here. This is the ONE piece of state that does not come
-- from seed.debug_new_game, and it exists to reach the SAME farcall the port
-- gate reaches unconditionally.
--
-- DETERMINISTIC CHECKPOINT — CONTENT-BASED, NOT A RAW FRAME COUNT.
-- DrawSurfingPikachuMinigameIntroBackground (pret engine/minigame/
-- surfing_pikachu.asm:2403) writes the ENTIRE intro canvas into wTileMap
-- (SCREEN_AREA = 360 bytes at the real $C3A0, the same address on both sides --
-- the port's DEVIATION at that label only changes how the port stages the
-- follow-on GB_TILEMAP0 mirror, not the wTileMap write itself) in one
-- synchronous burst with NO DelayFrame calls inside it and NO RNG or input
-- read anywhere in the routine or its caller up to that point. So wTileMap is
-- fully deterministic content, independent of exactly how many real-time frames
-- either side took to get there -- exactly the "compare state reached, not
-- frames elapsed" style every other navigation-driven scenario here already
-- uses (see sight.lua's cur_script poll, fish_old_rod's stale-byte-then-poll
-- pattern).
--
-- The one place raw frame alignment matters is OAM (defect 1: no OBJ ever
-- drawn), because the intro Pikachu is a live SpawnAnimatedObject that RunObjectAnimations
-- publishes once per SurfingPikachuMinigameIntro.loop iteration, and its X
-- coordinate advances over time (SurfingMinigameAnimatedObjectFn_IntroAnimationPikachu).
-- This scenario anchors on a SENTINEL-THEN-POLL on wSurfingMinigameIntroAnimationFinished
-- (seeded to $FF, which pret unconditionally zeroes with a bare `xor a / ld
-- [wSurfingMinigameIntroAnimationFinished], a` immediately before `.loop:`
-- begins -- the same "seed a value nothing else can produce, poll for the
-- real code to overwrite it" contract fish_old_rod.lua and surf_round_trip.lua
-- already use for wTileInFrontOfPlayer), then advances exactly ONE emulated
-- frame (one DelayFrame call, matching `.loop`'s single iteration -- confirmed
-- against the pret source: RunObjectAnimations + DelayFrame execute exactly
-- once between the flag going 0 and the next poll). The port's matching debug
-- hook (SurfingPikachuIntroDebugFrameHook, gated DEBUG_SURFING_PIKACHU_INTRO)
-- counts the identical loop iteration. At that instant the intro Pikachu has
-- NOT moved from its spawn coordinates (SURFING_MINIGAME_FLAT_WATER_Y,
-- SURFING_MINIGAME_CENTER_X): the object's own per-2-frame pixel step means
-- its FIRST horizontal move happens on iteration 2, not iteration 1 (measured
-- against a real run of this scenario -- see the harness report). So OAM/X/Y
-- position IS compared, with no frame-alignment slack needed.

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

local REDS_HOUSE_1F = 37       -- pret constants/map_constants.asm
local PALLET_TOWN = 0
local SUMMER_BEACH_HOUSE = 0xF8 -- constants/map_constants.asm ($F8)
local BEACH_HOUSE_WIDTH = 7     -- blocks; constants/map_constants.asm map_const row
local BIT_WARP_FROM_CUR_SCRIPT = 3 -- constants/ram_constants.asm
local BIT_PIKACHU_SPAWN_SURFING = 6 -- constants/pikachu_emotion_constants.asm

-- RAW ADDRESSES, not sym:addr — the pinned golden ROM (7caf2e09) predates
-- upstream PR #163 ("Labels and constants for Surfing Pikachu minigame",
-- 51cb4a12d) which is what gave these two bytes their wPikachuSpawnStateFlags/
-- wPikachuMapScriptFlags labels; pokeyellow.sym at the pin has neither symbol
-- (measured: `grep wPikachu…` on it returns only wSurfingMinigameIntroAnimationFinished).
-- The pinned scripts/SummerBeachHouse.asm still reads/writes the same two bytes,
-- just unlabeled (`ld a, [wd471]` / `bit 6, a`; `ld hl, wd492` / `bit 0, [hl]` /
-- `set 1, [hl]`), and dos_port/CLAUDE.md's own save-system notes independently
-- confirm wPikachuMapScriptFlags = 0xD492. Do not "fix" this to sym:addr without
-- re-pinning the golden ROM to a commit that has the label.
local WD471_PIKACHU_SPAWN_STATE_FLAGS = 0xD471


-- Landing tile: adjacent-right of the Surfin' Dude NPC (raw Y=3, X=2 -- see
-- the header note on object_event's (X,Y) param order), facing LEFT toward
-- it. This is a direct script-warp to the interaction tile, the same one-shot
-- placement sight.lua uses for its trainer-sight tiles -- not the map's own
-- (2,7) door landing (warp_event 2,7,LAST_MAP,1 in the same object file) plus
-- a walk. MEASURED (not guessed): a player placed here and left-blocked
-- without opening a text box would mean the NPC sits elsewhere; this position
-- was confirmed by reading wSprite01StateData2MapY/MapX directly (0xC214/
-- 0xC215 -- unlabeled at the pinned golden's sym, see the WD471 note below for
-- why) = (7,6), i.e. raw (3,2) plus the object_event macro's own +4 encoding
-- bias, and by successfully opening the NPC's dialog from here.
local NPC_Y, NPC_X = 3, 2
local LAND_Y, LAND_X = 3, 3

-- Mirrors the %ifdef DEBUG_SURFING_PIKACHU_INTRO gbregion rows in
-- dos_port/src/debug/debug_dump.asm. The differ joins by NAME and cross-checks
-- each address, so the two lists must agree. Scenario-local on purpose (see
-- surf_round_trip.lua's header for why this isn't added to dump.wram_regions).
-- wCurMap and wPikachuSpawnStateFlags are deliberately NOT in the compared
-- regions -- both are ENTRY-MECHANISM artifacts (see the port's matching
-- gbregion comment in dos_port/src/debug/debug_dump.asm's
-- DEBUG_SURFING_PIKACHU_INTRO block), not evidence about the rendering
-- defects this scenario defends. They are still asserted against explicitly
-- above (the script-warp landing check, and the precondition write is
-- observably necessary for the NPC dialog to proceed at all), just not
-- carried into the golden comparison.
local function regions()
	local r = dump.standard_regions(sym)
	-- Name kept <= 20 chars to match the port's GBSTATE_NAME_LEN limit
	-- (dos_port/src/debug/debug_dump.asm) -- the differ joins by NAME.
	r[#r + 1] = { name = "wSurfIntroFinished",
	              addr = sym:addr("wSurfingMinigameIntroAnimationFinished"), size = 1 }
	-- The BG map at $9800: the bytes the PPU actually samples on this side, and
	-- the port's compositor on the other. No other region reaches it -- the
	-- shared "vram_tiles" row is 0x1800 from 0x8000 and stops one byte short,
	-- and "wTileMap" is the WRAM staging buffer, correct on both sides whether
	-- or not anything commits it. Without this the scenario could not detect a
	-- reverted SurfingMinigame_MirrorIntroCanvas (measured 2026-08-18: it still
	-- reported PASS with that call removed). 32*32 = the full BG map; the
	-- differ masks the area outside the 20x18 visible window.
	r[#r + 1] = { name = "bgmap0", addr = 0x9800, size = 32 * 32 }
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
	-- Settle: see sight.lua's warning -- the door step-out's EnterMap must
	-- finish before the script-warp is armed, or its consumer swallows it.
	navigate.walk("DOWN", 1)
	scenario.wait(60)

	scenario.exec(function()
		seed.debug_new_game(sym, text:encode(seed.PLAYER_NAME))
		-- Bypass SummerBeachHouseSurfinDudeText's own precondition (see header).
		local flags = WD471_PIKACHU_SPAWN_STATE_FLAGS
		emu:write8(flags, emu:read8(flags) | (1 << BIT_PIKACHU_SPAWN_SURFING))

		local view = sym:addr("wOverworldMap") + 7 + BEACH_HOUSE_WIDTH
			+ (BEACH_HOUSE_WIDTH + 6) * (LAND_Y >> 1) + (LAND_X >> 1)
		local ptr = sym:addr("wCurrentTileBlockMapViewPointer")
		emu:write8(ptr, view & 0xFF)
		emu:write8(ptr + 1, (view >> 8) & 0xFF)
		emu:write8(sym:addr("wYCoord"), LAND_Y)
		emu:write8(sym:addr("wXCoord"), LAND_X)
		emu:write8(sym:addr("wDestinationWarpID"), 0xFF)
		emu:write8(sym:addr("hWarpDestinationMap"), SUMMER_BEACH_HOUSE)
		local status3 = sym:addr("wStatusFlags3")
		emu:write8(status3, emu:read8(status3) | (1 << BIT_WARP_FROM_CUR_SCRIPT))
	end)

	do
		local deadline = scenario.frame() + 900
		while navigate.read8("wCurMap") ~= SUMMER_BEACH_HOUSE do
			assert(scenario.frame() < deadline,
				"surfing_pikachu_intro: the script warp to SUMMER_BEACH_HOUSE never fired")
			scenario.wait(1)
		end
		local y, x = navigate.coords()
		scenario.log(("surfing_pikachu_intro: on map %d at (%d,%d)"):format(SUMMER_BEACH_HOUSE, y, x))
		assert(y == LAND_Y and x == LAND_X,
			"surfing_pikachu_intro: the warp moved the player off the seeded landing tile")
	end
	scenario.wait(60)
	-- wJoyIgnore holds through the whole of EnterMap and only clears on its last
	-- line (surf_round_trip.lua's measured note: "a single tap after the warp is
	-- swallowed"), so RETRY the facing tap rather than trusting one shot.
	-- wPlayerDirection (ram/wram.asm) holds the D-PAD DIRECTION BIT of the last
	-- move/turn, NOT a SPRITE_FACING_* constant — D_LEFT = $02 (measured: after
	-- an unblocked LEFT walk this read back 0x02, not 0x08).
	local D_LEFT = 0x02
	do
		local deadline = scenario.frame() + 600
		while navigate.read8("wPlayerDirection") ~= D_LEFT do
			assert(scenario.frame() < deadline,
				"surfing_pikachu_intro: the player never turned to face the NPC (LEFT)")
			input.tap("LEFT", 2, 20)
		end
	end
	do
		local y, x = navigate.coords()
		assert(y == LAND_Y and x == LAND_X,
			("surfing_pikachu_intro: facing tap moved the player to (%d,%d), expected to stay " ..
			 "at (%d,%d) with the NPC blocking"):format(y, x, LAND_Y, LAND_X))
	end
	scenario.wait(30)
	-- BIT_PIKACHU_MAP_PAUSE_IGT (wPikachuMapScriptFlags bit 0) starts clear on a
	-- fresh seed.debug_new_game on both sides, so this always takes the LONG,
	-- multi-page _SummerBeachHouseSurfinDudeText1 branch ("Whoa! ... Give it a
	-- go?"), never the short Text3 ("Wanna go SURF?"). Retry the opening A: a
	-- single tap can be swallowed by wJoyIgnore right after the warp/interaction
	-- start (same trap as the facing tap above).
	do
		local needle = text:encode("Whoa")
		local deadline = scenario.frame() + 600
		while not navigate.tilemap():find(needle, 1, true) do
			assert(scenario.frame() < deadline,
				"surfing_pikachu_intro: talking to the Surfin' Dude never opened a text box")
			input.tap("A", 2, 20)
		end
	end
	-- Advance the three-page text to its last page ("Give it a go?"), which has
	-- no ▼ (it is PrintText's final page, followed directly by YesNoChoice).
	navigate.dialog_until_text(text:encode("Give it a go"))
	-- YesNoChoice draws its box after PrintText returns; YES is the default
	-- cursor, matching bills_pc_ops.lua's release-confirm convention.
	scenario.wait(60)
	input.tap("A", 2, 10)

	-- Seed the sentinel the intro's own code is guaranteed to overwrite (see header),
	-- THEN poll for it -- so a hang here proves the farcall never happened rather than
	-- racing a byte that might already read 0.
	scenario.exec(function()
		emu:write8(sym:addr("wSurfingMinigameIntroAnimationFinished"), 0xFF)
	end)
	do
		local addr = sym:addr("wSurfingMinigameIntroAnimationFinished")
		local deadline = scenario.frame() + 1800
		while scenario.read_range(addr, 1):byte(1) ~= 0 do
			assert(scenario.frame() < deadline,
				"surfing_pikachu_intro: wSurfingMinigameIntroAnimationFinished never went to 0 " ..
				"-- SurfingPikachuMinigameIntro was not reached (NPC dialog/YES-choice failed?)")
			scenario.wait(1)
		end
	end
	scenario.log(("surfing_pikachu_intro: intro loop entered at frame %d"):format(scenario.frame()))

	-- Exactly one `.loop` iteration (one DelayFrame) -- see header for why this
	-- is the checkpoint: OAM is now published, and the intro Pikachu has not
	-- moved from its spawn X yet.
	scenario.wait(1)

	scenario.exec(function()
		dump.write("surfing_pikachu_intro", regions(), {
			frame = scenario.frame(),
			description = "SurfingPikachuMinigameIntro, one loop iteration after " ..
				"wSurfingMinigameIntroAnimationFinished goes to 0 -- the deterministic " ..
				"post-DrawSurfingPikachuMinigameIntroBackground checkpoint (no RNG, no " ..
				"player input read by this routine or its caller up to here)",
		})
	end)
end)
