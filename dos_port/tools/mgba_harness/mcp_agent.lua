---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- mcp_agent.lua — resident command agent for the mgba-mcp bridge (fidelity
-- plan Stage 1.5). Loaded into mgba-lua-runner; serves a newline-delimited
-- JSON command protocol over TCP 127.0.0.1:$MGBA_MCP_PORT (default 8765) for
-- tools/mgba_mcp/server.py.
--
-- Execution model: the runner's C loop calls runFrame + the "frame" callback
-- forever. This agent gives that loop debugger semantics — while no
-- time-advancing command is pending it BLOCKS inside the frame callback
-- (polling the socket), so the emulator sits paused between commands.
-- run_frames / press release the callback for exactly N frames, then the
-- reply is sent and the agent blocks again. Non-advancing commands (read,
-- screenshot, save/load state) execute immediately while paused.
--
-- Every mGBA binding is called from the frame callback = the main Lua state,
-- so the coroutine context rule (lib/scenario.lua) doesn't apply here.
--
-- Protocol (one JSON object per line, reply per command):
--   {"cmd":"ping"}                                → {"ok":true,"frame":N}
--   {"cmd":"read","addr":"wTileMap"|49056,"len":N}→ {"ok":true,"hex":"..."}
--   {"cmd":"run_frames","n":N}                    → after N frames
--   {"cmd":"press","keys":["START"],"hold":H,"gap":G} → hold H, release, +G
--   {"cmd":"save_state","path":P} / {"cmd":"load_state","path":P}
--   {"cmd":"screenshot","path":P}
--   {"cmd":"quit"}                                → reply, then os.exit(0)

local PORT = tonumber(os.getenv("MGBA_MCP_PORT") or "8765")

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local sym = symbols.load()

-- GB_KEY snapshot (same trick as lib/input.lua)
local GB_KEY = {}
for _, name in ipairs({ "A", "B", "SELECT", "START", "RIGHT", "LEFT", "UP", "DOWN" }) do
	GB_KEY[name] = assert(C.GB_KEY[name], "mcp_agent: C.GB_KEY." .. name .. " missing")
end

-- --- tiny JSON (encode: strings/numbers/bools/flat tables; decode: via load
-- of a converted literal is unsafe — use a minimal recursive parser) -------
local json = {}

function json.encode(v)
	local t = type(v)
	if t == "number" then
		return (v % 1 == 0) and ("%d"):format(v) or ("%g"):format(v)
	elseif t == "boolean" then
		return tostring(v)
	elseif t == "string" then
		return ('"%s"'):format(v:gsub("[\\\"]", "\\%0"):gsub("\n", "\\n"))
	elseif t == "table" then
		if #v > 0 or next(v) == nil then
			local parts = {}
			for _, item in ipairs(v) do parts[#parts + 1] = json.encode(item) end
			return "[" .. table.concat(parts, ",") .. "]"
		end
		local parts = {}
		for k, val in pairs(v) do
			parts[#parts + 1] = ('"%s":%s'):format(k, json.encode(val))
		end
		return "{" .. table.concat(parts, ",") .. "}"
	end
	error("json: cannot encode " .. t)
end

-- Minimal JSON decoder (objects/arrays/strings/numbers/true/false/null).
function json.decode(s)
	local pos = 1
	local function skip()
		pos = s:find("[^ \t\r\n]", pos) or #s + 1
	end
	local parse_value
	local function parse_string()
		local out = {}
		pos = pos + 1
		while true do
			local c = s:sub(pos, pos)
			if c == "" then error("json: unterminated string") end
			if c == '"' then pos = pos + 1 return table.concat(out) end
			if c == "\\" then
				local e = s:sub(pos + 1, pos + 1)
				local map = { n = "\n", t = "\t", r = "\r", ["\""] = "\"", ["\\"] = "\\", ["/"] = "/" }
				out[#out + 1] = map[e] or e
				pos = pos + 2
			else
				out[#out + 1] = c
				pos = pos + 1
			end
		end
	end
	parse_value = function()
		skip()
		local c = s:sub(pos, pos)
		if c == '"' then return parse_string() end
		if c == "{" then
			local obj = {}
			pos = pos + 1
			skip()
			if s:sub(pos, pos) == "}" then pos = pos + 1 return obj end
			while true do
				skip()
				local k = parse_string()
				skip()
				assert(s:sub(pos, pos) == ":", "json: expected :")
				pos = pos + 1
				obj[k] = parse_value()
				skip()
				local d = s:sub(pos, pos)
				pos = pos + 1
				if d == "}" then return obj end
				assert(d == ",", "json: expected , or }")
			end
		end
		if c == "[" then
			local arr = {}
			pos = pos + 1
			skip()
			if s:sub(pos, pos) == "]" then pos = pos + 1 return arr end
			while true do
				arr[#arr + 1] = parse_value()
				skip()
				local d = s:sub(pos, pos)
				pos = pos + 1
				if d == "]" then return arr end
				assert(d == ",", "json: expected , or ]")
			end
		end
		local lit = s:match("^[%w%.%+%-eE]+", pos)
		if lit then
			pos = pos + #lit
			if lit == "true" then return true end
			if lit == "false" then return false end
			if lit == "null" then return nil end
			local n = tonumber(lit)
			if n then return n end
		end
		error("json: unexpected input at " .. pos)
	end
	local v = parse_value()
	return v
end

-- --- server state ----------------------------------------------------------
local server, berr = socket.bind(nil, PORT)
if not server then error("mcp_agent: cannot bind port " .. PORT .. ": " .. tostring(berr)) end
local lok, lerr = server:listen()
if lerr then error("mcp_agent: listen failed: " .. tostring(lerr)) end
local _ = lok
console:log(("mcp_agent: listening on 127.0.0.1:%d"):format(PORT))

local client = nil
local rbuf = ""
-- pending time-advance: { kind = "run"|"hold"|"gap", n = frames, keys, gap }
local pending = nil

local function reply(obj)
	if client then
		client:send(json.encode(obj) .. "\n")
	end
end

local function resolve_addr(a)
	if type(a) == "number" then return a end
	return sym:addr(a)
end

local function keys_mask(keys)
	local m = 0
	for _, name in ipairs(keys) do
		local bit = GB_KEY[name:upper()]
		if not bit then error(("unknown key %q"):format(name)) end
		m = m | (1 << bit)
	end
	return m
end

local function handle(cmd)
	local ok, err = pcall(function()
		local c = cmd.cmd
		if c == "ping" then
			reply({ ok = true, frame = emu:currentFrame() })
		elseif c == "read" then
			local addr = resolve_addr(cmd.addr)
			local n = cmd.len or 1
			local data = emu:readRange(addr, n)
			reply({ ok = true, addr = addr, hex = (data:gsub(".", function(ch)
				return ("%02x"):format(ch:byte())
			end)), frame = emu:currentFrame() })
		elseif c == "run_frames" then
			pending = { kind = "run", n = cmd.n or 1 }
		elseif c == "press" then
			emu:setKeys(keys_mask(cmd.keys or { "A" }))
			pending = { kind = "hold", n = cmd.hold or 2, gap = cmd.gap or 10 }
		elseif c == "save_state" then
			local okk = emu:saveStateFile(cmd.path, 0)
			reply({ ok = okk and true or false, path = cmd.path })
		elseif c == "load_state" then
			local okk = emu:loadStateFile(cmd.path, 0)
			reply({ ok = okk and true or false, path = cmd.path })
		elseif c == "screenshot" then
			emu:screenshot(cmd.path)
			reply({ ok = true, path = cmd.path })
		elseif c == "quit" then
			reply({ ok = true, bye = true })
			os.exit(0)
		else
			reply({ ok = false, error = "unknown cmd " .. tostring(c) })
		end
	end)
	if not ok then
		reply({ ok = false, error = tostring(err) })
	end
end

local function pump_socket(timeout_ms)
	-- The wrapper (lua.c _socketLuaSource) exposes receive/hasdata/accept;
	-- timed waits go through the raw handle at ._s:select(ms).
	-- accept
	if not client then
		if server._s:select(timeout_ms) > 0 then
			local s = server:accept()
			if type(s) == "table" then
				client = s
				rbuf = ""
				console:log("mcp_agent: client connected")
			end
		end
		return
	end
	-- read
	if client._s:select(timeout_ms) > 0 then
		local data, err = client:receive(4096)
		if not data then
			console:log("mcp_agent: client disconnected (" .. tostring(err) .. ")")
			client = nil
			return
		end
		rbuf = rbuf .. data
		while true do
			local line, rest = rbuf:match("^([^\n]*)\n(.*)$")
			if not line then break end
			rbuf = rest
			if line ~= "" then
				local okd, cmd = pcall(json.decode, line)
				if okd and type(cmd) == "table" then
					handle(cmd)
				else
					reply({ ok = false, error = "bad json: " .. tostring(cmd) })
				end
			end
			if pending then break end -- time must advance before more commands
		end
	end
end

callbacks:add("frame", function()
	if pending then
		pending.n = pending.n - 1
		if pending.n > 0 then return end
		if pending.kind == "hold" then
			emu:setKeys(0)
			pending = { kind = "gap", n = pending.gap }
			if pending.n > 0 then return end
		end
		local done = pending.kind
		pending = nil
		reply({ ok = true, frame = emu:currentFrame(), done = done })
		-- fall through to block below
	end
	-- paused: block here polling the socket until a command advances time
	while not pending do
		pump_socket(50)
	end
end)
