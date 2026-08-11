---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- dump.lua — write a scenario's GB state to GOLDEN.BIN + JSON sidecar.
--
-- Binary layout: the regions concatenated in listed order, nothing else; the
-- sidecar (<name>.json) is the layout's source of truth — the differ
-- (golden_diff.py, Session E) reads region names/addresses/sizes/offsets from
-- it, never assumes them. Reads go through emu:readRange at frame-callback
-- time, i.e. at the vblank boundary, when VRAM/OAM are bus-readable and the
-- frame's state is consistent.
--
-- ⚠ dump.write calls emu:readRange, so from a scenario body it must be
-- wrapped in scenario.exec (mGBA bindings error outside the main Lua state).
--
-- Usage (inside a scenario body):
--   local dump = require("lib.dump")
--   scenario.exec(function()
--       dump.write("smoke_title", dump.standard_regions(sym), { frame = scenario.frame() })
--   end)
--   -- → $GOLDEN_DIR/smoke_title.bin + smoke_title.json

local dump = {}

assert(emu and emu.readRange, "dump: emu:readRange missing — not running under mGBA scripting?")

-- Struct/field lengths, from pret's constants — never a magic number.
--   party_struct  (macros/ram.asm:20) = PARTYMON_STRUCT_LENGTH ($2C)
--   battle_struct (macros/ram.asm:39) = species, HP, box level, status, 2 types,
--                 catch rate, moves, DVs, level, 5 stats, PP
local NUM_MOVES, NUM_STATS = 4, 5
local NAME_LENGTH = 11
local BAG_ITEM_CAPACITY = 20
local PARTYMON_STRUCT_LENGTH = 0x2C
local BATTLEMON_STRUCT_LENGTH = 1 + 2 + 1 + 1 + 2 + 1 + NUM_MOVES + 2 + 1
	+ 2 * NUM_STATS + NUM_MOVES -- = 29

-- The video regions every golden carries (fidelity plan, Stage 1.1). The real
-- GB wTileMap is 20×18 = 360 B at stride 20; the differ extracts the port's
-- matching 20×18 subwindow from its 40×25 canvas using the sidecar.
function dump.video_regions(sym)
	return {
		{ name = "wTileMap",   addr = sym:addr("wTileMap"), size = 20 * 18 },
		{ name = "vram_tiles", addr = 0x8000,               size = 0x1800 },
		{ name = "oam",        addr = 0xFE00,               size = 160 },
		dump.palette_region(),
	}
end

-- The CGB palette RAM, which is NOT memory-mapped: it is reached only through
-- the index/data port pairs BCPS/BCPD ($FF68/$FF69) and OCPS/OCPD ($FF6A/$FF6B),
-- so emu:readRange cannot see it and the bytes are supplied directly via `data`.
--
-- 8 BG palettes then 8 OBJ palettes, four BGR555 u16 each, colour 0 first --
-- exactly the order dos_port/src/debug/debug_dump.asm:ComposeCGBPalettes builds
-- on the port side. The index is written WITHOUT the auto-increment bit and
-- re-written for every byte, so the read does not depend on the emulator's
-- auto-increment behaviour.
--
-- gb_addr is GBSTATE_FLAT_ADDR (0xFFFFFFFF), the port's "composed, not
-- memory-mapped" sentinel: this region has no address that means the same thing
-- on both sides, so the differ must not cross-check one. Publishing $FF68 here
-- would be a fiction -- that is the port register, not where the bytes live.
function dump.palette_region()
	local bytes = {}
	for _, ports in ipairs({ { 0xFF68, 0xFF69 }, { 0xFF6A, 0xFF6B } }) do
		for i = 0, 63 do
			emu:write8(ports[1], i)
			bytes[#bytes + 1] = string.char(emu:read8(ports[2]))
		end
	end
	return {
		name = "cgb_palettes",
		addr = 0xFFFFFFFF,
		size = 128,
		data = table.concat(bytes),
	}
end

-- The WRAM game-data regions (fidelity expansion, Stage 1a).
--
-- MIRRORED BY (join key = the name string; the differ cross-checks each region's
-- gb_addr against the port's, so a memmap drift on either side fails loudly):
--   dos_port/src/debug/debug_dump.asm  — `gbstate_regions` table
--   dos_port/tools/golden_diff.py      — region policy (skips/masks/decoders)
--
-- Every address is resolved from pret's .sym (sym:addr errors on an unknown
-- label) and every size is a symbol difference or a named length constant — so
-- this tracks pret's wram.asm the way the port table tracks gb_memmap.inc.
function dump.wram_regions(sym)
	local owned, seen = sym:addr("wPokedexOwned"), sym:addr("wPokedexSeen")
	return {
		-- player / save-block game data (compared in EVERY scenario)
		{ name = "wPlayerName", addr = sym:addr("wPlayerName"), size = NAME_LENGTH },
		-- count + species list + $FF sentinel + 6 structs + 6 OT names + 6 nicks
		{ name = "wPartyData",  addr = sym:addr("wPartyCount"),
		  size = sym:addr("wPartyMonNicksEnd") - sym:addr("wPartyCount") },
		-- owned + seen flag arrays, back to back (each NUM_POKEMON bits)
		{ name = "wPokedex",    addr = owned, size = 2 * (seen - owned) },
		{ name = "wBagItems",   addr = sym:addr("wNumBagItems"),
		  size = 1 + BAG_ITEM_CAPACITY * 2 + 1 },
		{ name = "wPlayerMoney", addr = sym:addr("wPlayerMoney"), size = 3 }, -- BCD
		-- wOptions, wObtainedBadges, wUnusedObtainedBadges, wLetterPrintingDelayFlags
		{ name = "wOptionsBlock", addr = sym:addr("wOptions"),
		  size = sym:addr("wPlayerID") - sym:addr("wOptions") },
		{ name = "wPlayerID",   addr = sym:addr("wPlayerID"), size = 2 },
		-- battle / transient mon state (skipped per-scenario where unloaded)
		{ name = "wLoadedMon",  addr = sym:addr("wLoadedMon"), size = PARTYMON_STRUCT_LENGTH },
		-- wIsInBattle, wD057, wCurOpponent, wBattleType
		{ name = "wBattleFlags", addr = sym:addr("wIsInBattle"),
		  size = sym:addr("wBattleType") + 1 - sym:addr("wIsInBattle") },
		{ name = "wEnemyMonNick",  addr = sym:addr("wEnemyMonNick"),  size = NAME_LENGTH },
		{ name = "wEnemyMon",      addr = sym:addr("wEnemyMon"),      size = BATTLEMON_STRUCT_LENGTH },
		{ name = "wBattleMonNick", addr = sym:addr("wBattleMonNick"), size = NAME_LENGTH },
		{ name = "wBattleMon",     addr = sym:addr("wBattleMon"),     size = BATTLEMON_STRUCT_LENGTH },
	}
end

-- Every golden's region set: video + WRAM. One edit here upgrades every scenario
-- on the next `make goldens`.
function dump.standard_regions(sym)
	local regions = dump.video_regions(sym)
	for _, r in ipairs(dump.wram_regions(sym)) do
		regions[#regions + 1] = r
	end
	return regions
end

-- Minimal JSON encoder — enough for the sidecar (numbers, strings, booleans,
-- arrays, string-keyed objects; deterministic key order for stable diffs).
local function json_encode(v, indent)
	indent = indent or ""
	local t = type(v)
	if t == "number" then
		return (v % 1 == 0) and ("%d"):format(v) or ("%g"):format(v)
	elseif t == "boolean" then
		return tostring(v)
	elseif t == "string" then
		return ('"%s"'):format(v:gsub('[\\"]', '\\%0'):gsub("\n", "\\n"))
	elseif t == "table" then
		local inner = indent .. "  "
		if #v > 0 or next(v) == nil then -- array (or empty)
			local parts = {}
			for _, item in ipairs(v) do
				parts[#parts + 1] = inner .. json_encode(item, inner)
			end
			if #parts == 0 then
				return "[]"
			end
			return "[\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "]"
		end
		local keys = {}
		for k in pairs(v) do
			assert(type(k) == "string", "json: non-string object key")
			keys[#keys + 1] = k
		end
		table.sort(keys)
		local parts = {}
		for _, k in ipairs(keys) do
			parts[#parts + 1] = ('%s"%s": %s'):format(inner, k, json_encode(v[k], inner))
		end
		return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "}"
	end
	error("json: cannot encode " .. t)
end

local function hex(n)
	-- Eight digits for anything above the 16-bit GB space, so the
	-- GBSTATE_FLAT_ADDR sentinel (0xFFFFFFFF) is not truncated to 0xFFFF --
	-- which would collide with a real GB address in the sidecar.
	if n > 0xFFFF then
		return ("0x%08X"):format(n)
	end
	return ("0x%04X"):format(n)
end

-- Dump `regions` (ordered {name, addr, size} list) as
-- $GOLDEN_DIR/<scenario>.bin + <scenario>.json. `extra` is merged into the
-- sidecar top level (scenario-specific keys: frame, port subwindow offset…).
function dump.write(scenario_name, regions, extra)
	local dir = os.getenv("GOLDEN_DIR") or "."
	local base = dir .. "/" .. scenario_name

	local blobs = {}
	local sidecar_regions = {}
	local offset = 0
	for _, r in ipairs(regions) do
		-- A region may supply its own bytes (r.data) when the state it captures
		-- is not in the address space at all -- see dump.palette_region.
		local data = r.data or emu:readRange(r.addr, r.size)
		assert(#data == r.size,
			("dump: region %s produced %d bytes, wanted %d"):format(r.name, #data, r.size))
		blobs[#blobs + 1] = data
		sidecar_regions[#sidecar_regions + 1] = {
			name = r.name,
			gb_addr = hex(r.addr),
			size = r.size,
			file_offset = offset,
		}
		offset = offset + r.size
	end

	local bin, err = io.open(base .. ".bin", "wb")
	assert(bin, ("dump: cannot write %s.bin: %s"):format(base, tostring(err)))
	bin:write(table.concat(blobs))
	bin:close()

	local sidecar = {
		scenario = scenario_name,
		rom_title = emu:getGameTitle(),
		total_size = offset,
		regions = sidecar_regions,
	}
	for k, v in pairs(extra or {}) do
		sidecar[k] = v
	end
	local js = io.open(base .. ".json", "w")
	assert(js, ("dump: cannot write %s.json"):format(base))
	js:write(json_encode(sidecar) .. "\n")
	js:close()

	console:log(("dump: wrote %s.bin (%d bytes, %d regions) + sidecar"):format(
		base, offset, #regions))
end

return dump
