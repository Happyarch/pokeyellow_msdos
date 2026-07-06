---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- navigate.lua — state-aware game navigation for golden scenarios.
--
-- Everything here polls emulated state (tilemap text, wCurMap, coords)
-- instead of relying on blind frame counts, so scenarios are robust to
-- timing details while inputs stay a pure function of state (deterministic).
-- Dialog advancing taps A only while the ▼ more-text prompt is visible —
-- that's what makes menu appearances race-free (a menu never shows ▼, so a
-- stray A can't select the wrong thing).
--
-- All functions yield frames → scenario-body only. Needles are charmap byte
-- strings from gbtext (text:encode("NEW GAME")); call navigate.init first.

local scenario = require("lib.scenario")
local input = require("lib.input")

local navigate = {}

local sym, text
local CURSOR, ARROW -- "▶" / "▼" charmap bytes

local TILEMAP_COLS, TILEMAP_ROWS = 20, 18

function navigate.init(sym_, text_)
	sym, text = sym_, text_
	CURSOR = text:encode("▶")
	ARROW = text:encode("▼")
end

function navigate.tilemap()
	return scenario.read_range(sym:addr("wTileMap"), TILEMAP_COLS * TILEMAP_ROWS)
end

function navigate.read8(label)
	return scenario.read_range(sym:addr(label), 1):byte(1)
end

local function rows_of(tm)
	local rows = {}
	for r = 0, TILEMAP_ROWS - 1 do
		rows[r + 1] = tm:sub(r * TILEMAP_COLS + 1, (r + 1) * TILEMAP_COLS)
	end
	return rows
end

local function row_containing(tm, needle)
	for r, row in ipairs(rows_of(tm)) do
		if row:find(needle, 1, true) then
			return r
		end
	end
	return nil
end

local function deadline(max_frames, what)
	local limit = scenario.frame() + max_frames
	return function()
		if scenario.frame() > limit then
			local y, x = navigate.coords()
			error(("navigate: timed out (%d frames) %s [map %d @ (%d,%d)]"):format(
				max_frames, what, navigate.read8("wCurMap"), y, x))
		end
	end
end

-- Poll until `needle` is on screen (default 1800 frames = 30 s emulated).
function navigate.wait_for_text(needle, max_frames)
	local check = deadline(max_frames or 1800, "waiting for text")
	while not navigate.tilemap():find(needle, 1, true) do
		check()
		scenario.wait(4)
	end
end

function navigate.wait_text_gone(needle, max_frames)
	local check = deadline(max_frames or 600, "waiting for text to clear")
	while navigate.tilemap():find(needle, 1, true) do
		check()
		scenario.wait(4)
	end
end

-- Advance dialog (tap A only on the ▼ prompt) until `needle` appears.
function navigate.dialog_until_text(needle, max_frames)
	local check = deadline(max_frames or 7200, "advancing dialog to text")
	while true do
		local tm = navigate.tilemap()
		if tm:find(needle, 1, true) then
			return
		elseif tm:find(ARROW, 1, true) then
			input.tap("A", 2, 4)
		else
			scenario.wait(4)
		end
		check()
	end
end

-- Advance dialog until the current map id equals `map_id`.
function navigate.dialog_until_map(map_id, max_frames)
	local check = deadline(max_frames or 7200, "advancing dialog to map " .. map_id)
	while navigate.read8("wCurMap") ~= map_id do
		if navigate.tilemap():find(ARROW, 1, true) then
			input.tap("A", 2, 4)
		else
			scenario.wait(4)
		end
		check()
	end
end

-- Move the ▶ cursor to the menu row containing `needle` and press A.
-- `cursor_delta`: rows the cursor sits below the item's text row (0 for
-- ordinary menus; the party list points at the HP-bar row, one below the
-- nickname → pass 1).
function navigate.choose(needle, max_frames, cursor_delta)
	cursor_delta = cursor_delta or 0
	local check = deadline(max_frames or 1200, "choosing menu item")
	while true do
		local tm = navigate.tilemap()
		local rt = row_containing(tm, needle)
		local rc = row_containing(tm, CURSOR)
		if rt and rc then
			if rc == rt + cursor_delta then
				input.tap("A", 2, 8)
				return
			end
			input.tap(rt + cursor_delta > rc and "DOWN" or "UP", 2, 6)
		else
			scenario.wait(4) -- menu not fully drawn yet
		end
		check()
	end
end

-- Tap `keys` until `needle` shows up (retries: screens flush the joypad
-- while drawing, so a single tap can be swallowed).
function navigate.tap_until(keys, needle, max_frames)
	local check = deadline(max_frames or 1800, "tapping for text")
	while true do
		input.tap(keys, 2, 8)
		for _ = 1, 15 do
			if navigate.tilemap():find(needle, 1, true) then
				return
			end
			scenario.wait(4)
		end
		check()
	end
end

-- Player coordinates (wYCoord, wXCoord are adjacent).
function navigate.coords()
	local yx = scenario.read_range(sym:addr("wYCoord"), 2)
	return yx:byte(1), yx:byte(2)
end

-- Walk `tiles` tiles in `dir`, one press/release per tile, re-measuring the
-- remaining distance each step — a held direction latches extra steps before
-- a release lands, so this self-corrects any overshoot (walking back if
-- needed) and returns exactly on target (or when the map changes mid-walk).
-- Errors with map+coords if blocked.
local AXIS = {
	UP = { "y", -1, "UP", "DOWN" },
	DOWN = { "y", 1, "DOWN", "UP" },
	LEFT = { "x", -1, "LEFT", "RIGHT" },
	RIGHT = { "x", 1, "RIGHT", "LEFT" },
}
-- Wait until the player's coords hold still longer than one step animation
-- (16 frames) — a release near a step boundary can latch one more full step,
-- so only a stationary read is trustworthy.
local function wait_stationary(check)
	local ly, lx = navigate.coords()
	local still = 0
	while still < 18 do
		check()
		scenario.wait(1)
		local y, x = navigate.coords()
		if y == ly and x == lx then
			still = still + 1
		else
			ly, lx, still = y, x, 0
		end
	end
end

function navigate.walk(dir, tiles, max_frames)
	local a = AXIS[dir] or error("navigate: bad direction " .. tostring(dir))
	local axis, sign, fwd, back = table.unpack(a)
	local sy, sx = navigate.coords()
	local target = (axis == "y" and sy or sx) + sign * tiles
	local map0 = navigate.read8("wCurMap")
	local check = deadline(max_frames or (tiles * 120 + 300), "walking " .. dir)
	while true do
		local y, x = navigate.coords()
		local cur = axis == "y" and y or x
		if cur == target or navigate.read8("wCurMap") ~= map0 then
			break
		end
		input.hold((target - cur) * sign > 0 and fwd or back)
		while true do
			local yy, xx = navigate.coords()
			if (axis == "y" and yy or xx) ~= cur or navigate.read8("wCurMap") ~= map0 then
				break
			end
			check()
			scenario.wait(1)
		end
		input.release()
		wait_stationary(check) -- absorb any latched extra step before re-measuring
	end
	input.release()
end

-- Hold a direction until the map changes (stairs/door warps).
function navigate.walk_until_map(dir, map_id, max_frames)
	local check = deadline(max_frames or 900, "walking to map " .. map_id)
	input.hold(dir)
	while navigate.read8("wCurMap") ~= map_id do
		check()
		scenario.wait(2)
	end
	input.release()
	scenario.wait(30) -- map fade-in
end

-- Power-on → main menu (NEW GAME visible). Same logic as smoke_title.
function navigate.boot_to_main_menu()
	local needle = text:encode("NEW GAME")
	scenario.wait(180) -- copyright screen (not skippable)
	local check = deadline(3600, "reaching the main menu")
	while not navigate.tilemap():find(needle, 1, true) do
		input.tap("START", 2, 28)
		check()
	end
	scenario.wait(30)
end

-- Main menu → Oak speech → both naming menus (preset picks) → bedroom
-- (REDS_HOUSE_2F) with player control. Names are presets for determinism;
-- seed.player overwrites wPlayerName with the harness spec afterwards anyway.
--
-- ⚠ wCurMap is already REDS_HOUSE_2F while Oak is still talking, so the map
-- id can NOT signal the end of the intro. Instead the tail loop fuses dialog
-- mashing with a START probe: A on the ▼ prompt, START otherwise — the
-- moment the START menu actually opens (EXIT on screen) the player provably
-- has control. The menu is then closed again so scenarios can seed WRAM
-- before its first rendered appearance.
local REDS_HOUSE_2F = 38 -- pret constants/map_constants.asm
function navigate.new_game_to_bedroom()
	navigate.choose(text:encode("NEW GAME"))
	navigate.dialog_until_text(text:encode("NEW NAME")) -- player naming menu
	navigate.choose(text:encode("YELLOW"))
	navigate.wait_text_gone(text:encode("NEW NAME"))
	navigate.dialog_until_text(text:encode("NEW NAME")) -- rival naming menu
	navigate.choose(text:encode("BLUE"))
	navigate.wait_text_gone(text:encode("NEW NAME"))

	local exit_text = text:encode("EXIT")
	local check = deadline(7200, "finishing the intro (START probe)")
	while true do
		local tm = navigate.tilemap()
		if tm:find(exit_text, 1, true) then
			break
		elseif tm:find(ARROW, 1, true) then
			input.tap("A", 2, 4)
		else
			input.tap("START", 2, 10)
		end
		check()
	end
	assert(navigate.read8("wCurMap") == REDS_HOUSE_2F,
		"navigate: intro ended on an unexpected map")
	input.tap("B", 2, 10) -- close the probe menu; scenarios seed then reopen
	navigate.wait_text_gone(exit_text)
	scenario.log(("navigate: in bedroom with control at frame %d"):format(scenario.frame()))
end

-- Open the START menu (EXIT is unique to it) and let it settle. The tap is
-- retried: right after a dialog/fade the joypad can still be ignored and a
-- single press would be swallowed.
function navigate.open_start_menu()
	local exit_text = text:encode("EXIT")
	local check = deadline(1800, "opening the START menu")
	while true do
		input.tap("START", 2, 8)
		for _ = 1, 15 do
			if navigate.tilemap():find(exit_text, 1, true) then
				scenario.wait(30)
				return
			end
			scenario.wait(4)
		end
		check()
	end
end

return navigate
