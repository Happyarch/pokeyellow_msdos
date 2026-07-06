---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- input.lua — frame-stepped joypad helpers for harness scenarios.
--
-- All helpers here run inside the scenario coroutine (lib/scenario.lua body)
-- and each advances at least one emulated frame: emu:setKeys can only run on
-- the main Lua state (see scenario.lua's context rule), so every key change
-- is a yielded thunk carried across one frame boundary. Key state is level,
-- not edge — it persists until changed.
--
-- Usage (inside a scenario body):
--   local input = require("lib.input")
--   input.tap("START")             -- press 2 frames, release, wait 10
--   input.tap({"UP", "B"}, 2, 0)   -- chord, no extra post-release gap
--   input.hold("RIGHT") ... input.release()

local input = {}

assert(C and C.GB_KEY, "input: C.GB_KEY constants missing — not running under mGBA scripting?")

-- Default frame counts: the game polls the pad once per frame, so 2 held
-- frames guarantees a read; 10 released frames lets a menu consume the edge
-- before the next tap (Gen 1 joypad logic is edge-triggered per frame).
local DEFAULT_HOLD = 2
local DEFAULT_GAP = 10

-- C.GB_KEY is itself context-bound (indexing it from a coroutine thread
-- errors like any emu:* call), so snapshot the constants into a plain table
-- now, at module load time on the main state.
local GB_KEY = {}
for _, name in ipairs({ "A", "B", "SELECT", "START", "RIGHT", "LEFT", "UP", "DOWN" }) do
	GB_KEY[name] = assert(C.GB_KEY[name], "input: C.GB_KEY." .. name .. " missing")
end

-- "A" or {"A","B"} → mGBA key bitmask.
function input.mask(keys)
	if type(keys) == "string" then
		keys = { keys }
	end
	local m = 0
	for _, name in ipairs(keys) do
		local bit = GB_KEY[name]
		if not bit then
			error(("input: unknown key %q (want A/B/SELECT/START/RIGHT/LEFT/UP/DOWN)"):format(name), 2)
		end
		m = m | (1 << bit)
	end
	return m
end

-- Set the pad state before the next frame (yields once; that frame sees it).
function input.hold(keys)
	local mask = input.mask(keys)
	coroutine.yield(function()
		emu:setKeys(mask)
	end)
end

function input.release()
	coroutine.yield(function()
		emu:setKeys(0)
	end)
end

-- Hold `keys` for exactly `frames` frames, then release. The release itself
-- rides one more frame boundary (keys-up frame).
function input.press_for(keys, frames)
	input.hold(keys) -- frame 1 of the hold
	for _ = 2, frames do
		coroutine.yield()
	end
	input.release() -- one keys-up frame
end

-- The workhorse: press, release, and give the game `gap` frames to react
-- (inclusive of the release frame).
function input.tap(keys, hold, gap)
	input.press_for(keys, hold or DEFAULT_HOLD)
	for _ = 2, gap or DEFAULT_GAP do
		coroutine.yield()
	end
end

return input
