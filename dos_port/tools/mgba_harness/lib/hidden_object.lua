---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- hidden_object.lua — the shared body of the hidden-object / bookshelf goldens
-- (2026-08-21). One scenario file per prop supplies only that prop's numbers;
-- everything below is identical across them, so a fix or an extra compared region
-- lands on all of them at once. Deliberately the same shape as sight.lua, and the
-- ground-truth twin of the port's single DEBUG_HIDDENOBJ gate
-- (src/home/overworld.asm EnterMap + the hiddenobj_gate block in the Makefile).
--
-- WHAT IT DOES: new game -> Pallet Town -> script-warp onto the target map, standing
-- IN FRONT OF the prop and facing it -> press A -> wait for the prop's text -> dump.
--
-- *** THE PLAYER TILE IS NOT THE PROP TILE. ***
-- home/hidden_events.asm:CheckForHiddenEvent matches each `hidden_event` row through
-- CheckIfCoordsInFrontOfPlayerMatch — the tile IN FRONT of the player for the current
-- facing. A prop at (y,x) read facing UP therefore needs the player at (y+1, x).
-- Seeding the player ONTO the prop tile matches nothing, and the dispatch reports no
-- event without any error: measured on the port side as a correctly rendered room
-- with no dialog at all. spec.y/spec.x below are the PLAYER's tile.
--
-- THE SCRIPT WARP is sight.lua's, for the same reason and with the same ⚠ sequencing
-- requirement — read that file's header before changing any of this. In short:
--   wDestinationWarpID = $FF   "not a warp arrival", so the hand-set coords survive
--   hWarpDestinationMap = <map>
--   wStatusFlags3 BIT_WARP_FROM_CUR_SCRIPT -> OverworldLoopLessDelay -> WarpFound2
-- and it must be armed only once the player is SETTLED in Pallet Town, because
-- hWarpDestinationMap ($FF8B) is a union shared with a dozen other HRAM cells and a
-- value left sitting for a few frames is overwritten by unrelated code.
--
-- The view pointer is derived with pret's own formula (macros/coords.asm,
-- event_displacement) because LoadDestinationWarpPosition is skipped by the $FF above
-- and nothing else in the load path computes it.

local scenario = require("lib.scenario")
local navigate = require("lib.navigate")
local seed = require("lib.seed")
local dump = require("lib.dump")
local input = require("lib.input")

local hidden_object = {}

local REDS_HOUSE_1F = 37 -- pret constants/map_constants.asm
local PALLET_TOWN = 0
local BIT_WARP_FROM_CUR_SCRIPT = 3 -- constants/ram_constants.asm

-- spec fields:
--   name        scenario name (also the dump name)
--   map         pret map id (wCurMap) of the prop's map
--   width       that map's WIDTH in blocks (constants/map_constants.asm) — the view
--               pointer formula needs it
--   y, x        the tile the PLAYER STANDS ON (see the note above)
--   facing      SPRITE_FACING_* value (constants/sprite_data_constants.asm:
--               DOWN 0, UP 4, LEFT 8, RIGHT 12)
--   text        encoded needle proving the prop's own text reached the screen
--   settle      frames to wait after the text appears before dumping (default 60)
--   before      optional fn(sym) run while still in Pallet Town, for event seeding
--   description dump sidecar description
function hidden_object.run(sym, text, spec)
	navigate.init(sym, text)

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
		-- Settle: see the ⚠ note in the header and in sight.lua.
		navigate.walk("DOWN", 1)
		scenario.wait(60)

		scenario.exec(function()
			seed.player(sym, text:encode(seed.PLAYER_NAME))
			if spec.before then
				spec.before(sym)
			end
			local view = sym:addr("wOverworldMap") + 7 + spec.width
				+ (spec.width + 6) * (spec.y >> 1) + (spec.x >> 1)
			local ptr = sym:addr("wCurrentTileBlockMapViewPointer")
			emu:write8(ptr, view & 0xFF)
			emu:write8(ptr + 1, (view >> 8) & 0xFF)
			emu:write8(sym:addr("wYCoord"), spec.y)
			emu:write8(sym:addr("wXCoord"), spec.x)
			emu:write8(sym:addr("wDestinationWarpID"), 0xFF)
			emu:write8(sym:addr("hWarpDestinationMap"), spec.map)
			local flags = sym:addr("wStatusFlags3")
			emu:write8(flags, emu:read8(flags) | (1 << BIT_WARP_FROM_CUR_SCRIPT))
		end)

		local deadline = scenario.frame() + 900
		while navigate.read8("wCurMap") ~= spec.map do
			assert(scenario.frame() < deadline,
				spec.name .. ": script warp to map " .. spec.map .. " never fired")
			scenario.wait(1)
		end
		local y, x = navigate.coords()
		assert(y == spec.y and x == spec.x,
			spec.name .. (": the warp moved the player off the seeded tile — got (%d,%d)")
				:format(y, x))

		-- TURN to face the prop by pressing its direction, rather than writing
		-- wSpritePlayerStateData1FacingDirection directly. A direct write does NOT
		-- survive here: the overworld loop re-derives the player's facing from the
		-- joypad every frame, so a byte poked after arrival is gone long before the A
		-- press and the dispatch then sees the arrival facing (measured: the warp
		-- landed correctly at map 185 (3,1) and the A press still produced no dialog).
		-- Every prop this helper reads is a wall tile, so pressing into it turns the
		-- player without moving them — which is exactly what a real player does.
		local face_key = ({ [0] = "DOWN", [4] = "UP", [8] = "LEFT", [12] = "RIGHT" })[spec.facing]
		assert(face_key, spec.name .. ": unknown facing " .. tostring(spec.facing))
		-- navigate.read8, not emu:read8 — raw emu access outside a scenario.exec block
		-- raises "Function called from invalid context".
		local turn_deadline = scenario.frame() + 300
		while navigate.read8("wSpritePlayerStateData1FacingDirection") ~= spec.facing do
			assert(scenario.frame() < turn_deadline,
				spec.name .. ": player never turned to face " .. face_key)
			input.tap(face_key, 2, 8)
		end
		-- Confirm the turn did not also MOVE us: a prop on a walkable tile would step
		-- the player onto it and the tile in front would then be the wrong one.
		local ty, tx = navigate.coords()
		assert(ty == spec.y and tx == spec.x,
			spec.name .. (": turning moved the player to (%d,%d) — the prop tile is walkable, "
				.. "so this scenario needs a different approach tile"):format(ty, tx))
		scenario.wait(10)

		-- The A press is the real one: it reaches
		-- CheckForHiddenEventOrBookshelfOrCardKeyDoor through the overworld loop, so
		-- the prop's handler runs in production rather than being called directly.
		input.tap("A", 2, 8)
		-- wait_for_text, NOT dialog_until_text: the latter keeps tapping A to ADVANCE
		-- the dialog, which walks this side past the text and into whatever the handler
		-- does next, while the port (AUTOKEY_QUIET presses nothing) stays parked at the
		-- text. The two sides then dump different states and every cell diverges.
		-- Measured on route_15_binoculars: 143/360 tilemap cells and 65 VRAM slots,
		-- the latter being the Articuno pic that only the advanced side had loaded.
		-- Both sides now park on the SAME stable state: the prop's text on screen,
		-- waiting for a button press that never comes.
		navigate.wait_for_text(spec.text)
		scenario.wait(spec.settle or 60)

		scenario.exec(function()
			dump.write(spec.name, dump.standard_regions(sym), {
				frame = scenario.frame(),
				description = spec.description,
			})
		end)
	end)
end

return hidden_object
