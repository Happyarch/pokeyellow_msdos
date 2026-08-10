---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- oak_palette_trace — GROUND TRUTH for the Oak-speech palette defect.
--
-- The port renders Prof. Oak, the rival and the player as solid black on the
-- new-game screen. The golden suite cannot see this: every scenario's regions
-- are wTileMap / vram_tiles / oam / WRAM datastructs and NOT palette RAM, so a
-- purely chromatic defect passes green. This trace reads what no golden records
-- -- the CGB BG and OBJ palette RAM the PPU actually paints from -- at the same
-- checkpoint oak_intro parks at, over the same real boot->menu->NEW GAME route.
--
-- Palette RAM is not memory-mapped: it is reached through the index/data port
-- pairs BCPS/BCPD ($FF68/$FF69) and OCPS/OCPD ($FF6A/$FF6B). The index is
-- written WITHOUT the auto-increment bit and re-written for every byte, so the
-- read does not depend on the emulator's auto-increment side effects.
--
-- Colours are CGB BGR555, little-endian: bit 0-4 red, 5-9 green, 10-14 blue,
-- each 0-31. The port's DAC is 0-63, so a port value is 2x the value here.
--
-- No golden is written and none should be: this is a *_trace recorder, which
-- `make goldens-verify` skips by design.
--
-- Run: dos_port/tools/mgba_harness/make_goldens.sh oak_palette_trace

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local gbtext = require("lib.gbtext")
local scenario = require("lib.scenario")
local navigate = require("lib.navigate")

local sym = symbols.load()
local text = gbtext.load()
navigate.init(sym, text)

-- Read one 64-byte palette bank through its index/data port pair.
local function read_palette_ram(index_port, data_port)
	local bytes = {}
	for i = 0, 63 do
		emu:write8(index_port, i)
		bytes[i + 1] = emu:read8(data_port)
	end
	return bytes
end

local function report(label, bytes)
	console:log(("=== %s ==="):format(label))
	for pal = 0, 7 do
		local parts = {}
		for col = 0, 3 do
			local lo = bytes[pal * 8 + col * 2 + 1]
			local hi = bytes[pal * 8 + col * 2 + 2]
			local v = lo | (hi << 8)
			parts[#parts + 1] = ("(%2d,%2d,%2d)"):format(v & 31, (v >> 5) & 31, (v >> 10) & 31)
		end
		console:log(("  pal%d %s"):format(pal, table.concat(parts, " ")))
	end
end

scenario.run(function()
	navigate.boot_to_main_menu()
	navigate.choose(text:encode("NEW GAME"))
	-- Same checkpoint as the oak_intro golden: Oak's pic is up and faded in, page 1
	-- typed, parked at the <PARA> key-wait. Nothing is pressed, so it holds there.
	navigate.wait_for_text(text:encode("Welcome to the"))
	scenario.wait(45)

	scenario.exec(function()
		console:log(("frame %d — Oak speech, page 1 parked at the <PARA> wait"):format(scenario.frame()))
		console:log(("rBGP=%02X rOBP0=%02X rOBP1=%02X hOnCGB=%d"):format(
			emu:read8(0xFF47), emu:read8(0xFF48), emu:read8(0xFF49),
			emu:read8(sym:addr("hOnCGB"))))
		report("CGB BG palette RAM (BCPS/BCPD)", read_palette_ram(0xFF68, 0xFF69))
		report("CGB OBJ palette RAM (OCPS/OCPD)", read_palette_ram(0xFF6A, 0xFF6B))
	end)
end)
