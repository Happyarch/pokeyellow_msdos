---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- battle_safari_result — the RESULT/EXIT half of the per-battle-type box, for
-- SAFARI. battle_safari (id 71) photographs the MENU; this one takes a turn and
-- follows the battle to its end.
--
-- WHY IT EXISTS AT ALL, AND WHY IT COULD NOT BEFORE. The port's Safari turn tail
-- lives in production's _InitBattleCommon.specialBattleLoop — the out-of-balls
-- exit, PrintSafariZoneBattleText, and the flee roll. Measured 2026-08-14 with
-- four in-WRAM markers: that loop was entered by NO scenario, because
-- battle_safari's gate calls DisplayBattleMenu directly. A result scenario built
-- on that gate would have witnessed the GATE's logic, not the port's. The port
-- side now enters the real loop through a %ifdef'd trampoline (42ee0a359).
--
-- BAIT, NOT BALL. A Safari ball attempts a CATCH, which is a roll, and a
-- successful catch exits through UseBagItem's carry return before the flee tail
-- runs at all. Bait takes the turn with no catch attempt, so the tail runs.
-- The cursor opens on BALL and ONE RIGHT reaches BAIT:
--     row 14 |?>BALL???.....BAIT.?|
--     row 16 |?.THROW.ROCK..RUN..?|
--
-- THE FLEE IS MADE RNG-FREE, NOT SEEDED, and that is the whole reason this
-- scenario is deterministic across two emulators that share no RNG stream.
-- pret's tail (core.asm:189-192) opens
--     ld a, [wEnemyMonSpeed + 1]
--     add a
--     jp c, EnemyRan
-- so a speed LOW byte above 127 runs the mon OUTRIGHT, before Random is ever
-- called; the bait/rock factors and the `cp b` comparison below it are reached
-- only when that carry is clear. wEnemyMonSpeed is big-endian, so +1 IS the low
-- byte, exactly as pret indexes it. The spec PIDGEY's speed is 21, so both sides
-- pin it to $80.
--
-- LANDMARK: the enemy pic GONE *and* "ran!" on the tilemap. Both halves are
-- needed and neither alone is enough:
--   * "ran!" alone fires during PrintText, BEFORE pret's `jpfar
--     AnimationSlideEnemyMonOff` tail — at which instant the two sides disagree
--     about the pic band by construction;
--   * a blank pic band alone is true of plenty of earlier phases.
-- Together they are true only after EnemyRan has run to its end, which is
-- exactly where the port's gate dumps (its call into the loop returns when the
-- slide's tail-jump returns).

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

local BATTLE_TYPE_SAFARI = 2   -- constants/battle_constants.asm
local SAFARI_BALLS = 30        -- pret's count on Safari Zone entry
local RUNAWAY_SPEED_LO = 0x80  -- >= $80 → `add a` carries → jp c, EnemyRan

local TILEMAP_W = 20
local BLANK = 0x7F
-- The enemy mon pic is a 7x7 block at GB (12,0) — pret's hlcoord 12,0, the same
-- rectangle battle_anim_optoff checks for the opposite reason.
local PIC_COL, PIC_ROW, PIC_SIZE = 12, 0, 7

local function enemyPicGone(tilemap)
	for r = PIC_ROW, PIC_ROW + PIC_SIZE - 1 do
		for c = PIC_COL, PIC_COL + PIC_SIZE - 1 do
			if tilemap:byte(r * TILEMAP_W + c + 1) ~= BLANK then
				return false
			end
		end
	end
	return true
end

scenario.run(function()
	battle.enter_wild(sym, text)

	local btype = sym:addr("wBattleType")
	local balls = sym:addr("wNumSafariBalls")
	local speedLo = sym:addr("wEnemyMonSpeed") + 1
	local bait = text:encode("BAIT")
	local ran = text:encode("ran!")

	-- A dismisses "appeared!"; the Safari menu then draws itself.
	input.tap("A", 2, 8)

	-- Phase 1 — wait for the menu, holding battle_safari's two pins. They are
	-- re-asserted every frame for that scenario's reason: the frame on which
	-- DisplayBattleMenu reads wBattleType differs between the emulators, and the
	-- ball count is PRINTED into a compared tilemap.
	local menuUp = false
	for i = 1, 3600 do
		scenario.exec(function()
			emu:write8(btype, BATTLE_TYPE_SAFARI)
			emu:write8(balls, SAFARI_BALLS)
		end)
		if navigate.tilemap():find(bait, 1, true) then
			menuUp = true
			break
		end
		if i % 4 == 0 then
			input.tap("A", 2, 6)
		end
	end
	assert(menuUp, "battle_safari_result: the Safari menu never drew")

	scenario.wait(30) -- settle: menu parked in HandleMenuInput

	-- Phase 2 — the pin, then the selection. THE PIN GOES HERE, NOT EARLIER:
	-- staged before the encounter it is overwritten by the enemy load. The port
	-- gate pins at the same boundary, immediately before entering the loop.
	scenario.exec(function()
		emu:write8(speedLo, RUNAWAY_SPEED_LO)
	end)
	input.tap("RIGHT", 2, 10)   -- BALL -> BAIT
	input.tap("A", 2, 10)       -- select BAIT

	-- Phase 3 — drive the bait text to its end and stop on the landmark.
	-- The A taps are not optional: the tail prints through
	-- PrintSafariZoneBattleText and EnemyRan's own PrintText, both of which park
	-- in WaitForTextScrollButtonPress. Measured on the PORT side first — with no
	-- taps after the selection its run hung for the full 150 s harness timeout
	-- and produced no dump at all.
	--
	-- The wBattleType pin STOPS here, deliberately. battle_oldman_result was
	-- measured holding wBattleType past the battle's resolution and pinning the
	-- golden into a state the flow had just torn down; the flee tail is past the
	-- last read of it, so re-asserting can only invent state.
	-- navigate.tilemap() READS THROUGH THE COROUTINE and therefore must NOT be
	-- called inside a scenario.exec thunk (exec runs on the main Lua state, and
	-- a yield from there fails with "attempt to yield from outside a coroutine").
	-- battle_safari has the same split for the same reason; this cost one golden
	-- generation to rediscover.
	local dumped = false
	for _ = 1, 600 do
		scenario.exec(function()
			emu:write8(speedLo, RUNAWAY_SPEED_LO)
		end)
		local tilemap = navigate.tilemap()
		if tilemap:find(ran, 1, true) and enemyPicGone(tilemap) then
		scenario.exec(function()
			dump.write("battle_safari_result", dump.standard_regions(sym), {
				frame = scenario.frame(),
				description = "the SAFARI turn tail run to its end: BAIT taken " ..
					"through the real special-battle menu loop, the enemy's " ..
					"doubled speed low byte carrying straight into EnemyRan, " ..
					"the wild mon's \"ran!\" message printed and its pic slid " ..
					"off by AnimationSlideEnemyMonOff",
			})
			dumped = true
		end)
			break
		end
		input.tap("A", 2, 4)
	end

	assert(dumped, "battle_safari_result: never reached the post-EnemyRan state " ..
		"(the \"ran!\" message with the enemy pic slid off) — the bait turn did " ..
		"not run the flee roll, or the speed pin did not take")
end)
