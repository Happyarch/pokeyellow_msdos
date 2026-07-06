---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- scenario.lua — coroutine-based scenario runner for mgba-lua-runner.
--
-- A scenario body is plain linear code (wait → tap → dump → return); this
-- module steps it one coroutine resume per emulated frame, driven by the
-- "frame" callback the runner triggers after each core->runFrame.
--
-- ⚠ mGBA context rule: every mGBA-bound call (emu:*, console:*) hard-errors
-- "Function called from invalid context" when made from a coroutine thread
-- (lua.c _luaGetContext requires the main lua_State). So the body NEVER calls
-- emu directly; it yields **thunks** that this driver executes on the main
-- state: scenario.exec(function() emu:... end). lib/input.lua's helpers do
-- this internally. Plain Lua (io, string, math, locals) is fine in the body.
--
-- Timing model: each yield advances exactly one emulated frame; a yielded
-- thunk runs before that next frame, so its effect (e.g. setKeys) is visible
-- to it. Body completion exits the process 0; a body error, thunk error, or
-- hitting the runner's -F frame cap before the body finishes exits 1 — a
-- wedged or mistimed scenario can never masquerade as a produced golden.
--
-- Usage:
--   local scenario = require("lib.scenario")
--   scenario.run(function()
--       scenario.wait(120)
--       input.tap("START")
--       scenario.exec(function()
--           dump.write("smoke_title", regions, { frame = scenario.frame() })
--       end)
--   end)
--
-- Session C adds seed.lua (its WRAM writes are one exec thunk); the
-- boot→settle→seed→navigate→settle→dump→exit shape lives in scenario bodies,
-- this runner stays scenario-agnostic.

local scenario = {}

assert(callbacks and callbacks.add, "scenario: callbacks API missing — not running under mGBA scripting?")

local frame_count = 0
local done = false

-- Frames emulated since the script attached (the runner starts the script
-- before frame 0, so this equals the scenario's own age in frames).
function scenario.frame()
	return frame_count
end

-- Yield the body for n frames.
function scenario.wait(n)
	for _ = 1, n do
		coroutine.yield()
	end
end

-- Run fn on the main Lua state before the next frame (the only legal way to
-- reach emu:*/console:* from a scenario body). Advances one frame.
function scenario.exec(fn)
	coroutine.yield(fn)
end

-- Read GB memory from inside the body (exec + captured result); advances one
-- frame. Lets scenarios be state-aware (poll the tilemap) instead of relying
-- on blind frame counts.
function scenario.read_range(addr, size)
	local out
	coroutine.yield(function()
		out = emu:readRange(addr, size)
	end)
	return out
end

local function fail(co, err)
	console:error("scenario failed:\n" .. debug.traceback(co, tostring(err)))
	os.exit(1)
end

function scenario.run(body)
	local co = coroutine.create(body)

	callbacks:add("frame", function()
		frame_count = frame_count + 1
		if done then
			return
		end
		local ok, action = coroutine.resume(co)
		if not ok then
			fail(co, action)
		end
		if action ~= nil then
			local thunk_ok, err = pcall(action)
			if not thunk_ok then
				fail(co, err)
			end
		end
		if coroutine.status(co) == "dead" then
			done = true
			console:log(("scenario complete at frame %d"):format(frame_count))
			os.exit(0)
		end
	end)

	-- Fires when the runner's -F watchdog cap drains before the body ends.
	callbacks:add("shutdown", function()
		if not done then
			console:error(("scenario did NOT complete (frame cap hit at %d) — no golden written"):format(frame_count))
			os.exit(1)
		end
	end)
end

return scenario
