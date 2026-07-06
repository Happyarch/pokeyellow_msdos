-- Session A exit-gate script: prove the headless Lua entry point works
-- against the sha1-verified golden ROM.
--
--   tools/mgba_build/mgba-lua-runner -s tools/mgba_harness/hello_wram.lua \
--       <pret-golden>/pokeyellow.gbc
--
-- Asserts the API surface the harness plan needs (memory, input, frame
-- callbacks, socket, file I/O), then after some intro frames reads a known
-- WRAM address and prints it. Addresses are hardcoded here only because
-- symbols.lua (Session B) doesn't exist yet.

local FRAMES_BEFORE_DUMP = 600
local wTileMap = 0xC3A0 -- pret wTileMap (20x18 BG tilemap in WRAM)

assert(emu, "emu object missing")
assert(emu.memory and emu.memory.wram, "wram memory domain missing")
assert(callbacks and callbacks.add, "callbacks API missing")
assert(socket and socket.bind, "socket API missing")
assert(io and io.open, "file I/O missing")
console:log("API surface OK: memory / callbacks / socket / io present")
console:log("ROM title: " .. emu:getGameTitle())
console:log("joypad state via getKeys(): " .. tostring(emu:getKeys()))

local frames = 0
callbacks:add("frame", function()
	frames = frames + 1
	if frames == FRAMES_BEFORE_DUMP then
		local raw = emu:readRange(wTileMap, 20)
		local hex = {}
		for i = 1, #raw do
			hex[i] = string.format("%02X", raw:byte(i))
		end
		console:log(string.format("wTileMap[0..19] @ %04X after %d frames: %s",
			wTileMap, frames, table.concat(hex, " ")))
		console:log("HELLO_WRAM_OK")
		os.exit(0)
	end
end)
