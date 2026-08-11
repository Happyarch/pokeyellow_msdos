---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- battle_palette_trace — GROUND TRUTH for the battle OBJ pal4-7 divergence.
--
-- THE QUESTION THIS EXISTS TO ANSWER. The cgb_palettes golden region reports
-- battle_intro's OBJ palettes 4-7 as the four base palettes under the IDENTITY
-- mapping ($E4), while the port composes them from its live IO_OBP1, which is 0
-- there. Solving the golden's palette RAM for "the rOBP1 value" cannot
-- distinguish two very different explanations, because pret's
-- UpdateCGBPal_OBP1 compares rOBP1 against wLastOBP1 and TRANSFERS ONLY ON
-- CHANGE -- so palette RAM holds the mapping as of the LAST TRANSFER, not the
-- current register:
--
--   (a) hardware really holds rOBP1 = $E4 at this checkpoint, and there is a
--       writer on the battle-entry path the port is missing; or
--   (b) hardware's rOBP1 is something else (very possibly 0, matching the
--       port) and palette RAM is merely STALE from an earlier transfer -- in
--       which case there is no missing writer at all, and the port's model is
--       wrong rather than its register: it recomputes OBJ 4-7 from the current
--       register every frame (commit_palette) instead of writing them on
--       transfer.
--
-- Reading rOBP1 directly is the only thing that separates (a) from (b), and no
-- golden records it: every scenario's regions are wTileMap / vram_tiles / oam /
-- WRAM datastructs plus the composed cgb_palettes, and none of those is the raw
-- register. Enumerating pret is not a substitute either -- that was already done
-- (every `ldh [rOBP1], a` site in home/ + engine/ with its source value; the
-- only $E4 is ghost_marowak_anim.asm:4, and the fade tables end at $E0/$00/$FF),
-- which is what makes (b) the live hypothesis rather than a guess.
--
-- WHAT TO CONCLUDE FROM THE OUTPUT:
--   rOBP1 == $E4  -> hypothesis (a). Find the writer; the sticky model is not
--                    what is biting here.
--   rOBP1 != $E4  -> hypothesis (b) CONFIRMED, and the port needs a real
--                    wLast*-gated transfer (write the slot palettes when the
--                    register changes) rather than a per-frame recompute. That
--                    is a HAL change touching every screen the region compares,
--                    so it wants this measurement first.
-- Either way, record the number, not the inference.
--
-- Two checkpoints, because they disagree in the golden and the difference is
-- the whole point: battle_intro (OBJ 4-7 == OBJ 0-3, identity) and battle_menu
-- (OBJ 4-7 permuted, the $6C mapping SetAnimationPalette writes). If the
-- registers differ between them while palette RAM differs the same way, the
-- transfer is tracking the register and (a) holds; if the register is constant
-- across both while palette RAM changes, the staleness is real.
--
-- Palette RAM is not memory-mapped: it is reached through the index/data port
-- pairs BCPS/BCPD ($FF68/$FF69) and OCPS/OCPD ($FF6A/$FF6B). The index is
-- written WITHOUT the auto-increment bit and re-written for every byte, so the
-- read does not depend on the emulator's auto-increment side effects. Colours
-- are CGB BGR555, little-endian, 0-31 per channel (the port's DAC is 0-63, so a
-- port value is 2x the value here).
--
-- No golden is written and none should be: this is a *_trace recorder, which
-- `make goldens-verify` skips by design.
--
-- Run: dos_port/tools/mgba_harness/make_goldens.sh battle_palette_trace

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local gbtext = require("lib.gbtext")
local input = require("lib.input")
local scenario = require("lib.scenario")
local navigate = require("lib.navigate")
local battle = require("lib.battle")

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

local function decode(bytes, pal, col)
	local lo = bytes[pal * 8 + col * 2 + 1]
	local hi = bytes[pal * 8 + col * 2 + 2]
	return lo | (hi << 8)
end

local function report(label, bytes)
	console:log(("=== %s ==="):format(label))
	for pal = 0, 7 do
		local parts = {}
		for col = 0, 3 do
			local v = decode(bytes, pal, col)
			parts[#parts + 1] = ("(%2d,%2d,%2d)"):format(v & 31, (v >> 5) & 31, (v >> 10) & 31)
		end
		console:log(("  pal%d %s"):format(pal, table.concat(parts, " ")))
	end
end

-- Recover the DMG register that maps OBJ base palettes 0-3 onto slots 4-7, the
-- same solve golden_diff's readers have been doing by hand -- but here we can
-- print it NEXT TO the real register and see whether they agree.
local function solve_obp1(obj)
	local hits = {}
	for v = 0, 255 do
		local ok = true
		for i = 0, 3 do
			for c = 0, 3 do
				local idx = (v >> (2 * c)) & 3
				if decode(obj, 4 + i, c) ~= decode(obj, i, idx) then ok = false break end
			end
			if not ok then break end
		end
		if ok then hits[#hits + 1] = ("%02X"):format(v) end
	end
	return hits
end

local function probe(what)
	console:log(("---------- %s (frame %d) ----------"):format(what, scenario.frame()))
	console:log(("rBGP=%02X rOBP0=%02X rOBP1=%02X hOnCGB=%d wOnSGB=%d"):format(
		emu:read8(0xFF47), emu:read8(0xFF48), emu:read8(0xFF49),
		emu:read8(sym:addr("hOnCGB")), emu:read8(sym:addr("wOnSGB"))))
	local bg = read_palette_ram(0xFF68, 0xFF69)
	local obj = read_palette_ram(0xFF6A, 0xFF6B)
	report("CGB BG palette RAM (BCPS/BCPD)", bg)
	report("CGB OBJ palette RAM (OCPS/OCPD)", obj)
	local hits = solve_obp1(obj)
	console:log(("OBJ 4-7 solve for the mapping register: %s"):format(
		#hits > 0 and table.concat(hits, " ") or "NO CONSISTENT VALUE"))
	console:log(("  ^ compare against the real rOBP1=%02X above. Equal => palette RAM"):format(
		emu:read8(0xFF49)))
	console:log("    tracks the register here. Different => the transfer is stale (wLastOBP1 gate).")
end

scenario.run(function()
	-- Checkpoint 1: the battle_intro golden's parked "Wild PIDGEY appeared!" box.
	battle.enter_wild(sym, text)
	assert(navigate.tilemap():find(text:encode("appeared"), 1, true),
		"battle_palette_trace: intro text vanished before the probe")
	scenario.exec(function() probe("battle_intro checkpoint: intro box parked") end)

	-- Checkpoint 2: the battle_menu golden's FIGHT/PKMN/ITEM/RUN menu, reached the
	-- same way battle_menu.lua reaches it (A dismisses "appeared!", the send-out
	-- runs unattended, the menu box ends the sequence).
	local fight = text:encode("FIGHT")
	input.tap("A", 2, 8)
	navigate.dialog_until_text(fight, 3600)
	scenario.wait(30)
	assert(navigate.tilemap():find(fight, 1, true),
		"battle_palette_trace: menu vanished before the probe")
	scenario.exec(function() probe("battle_menu checkpoint: action menu open") end)
end)
