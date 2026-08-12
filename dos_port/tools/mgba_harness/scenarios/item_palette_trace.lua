---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- item_palette_trace — GROUND TRUTH for the item_potion_use palette divergence.
--
-- THE QUESTION. item_potion_use's golden has ALL 64 CGB palette entries white
-- (a full whiteout, rBGP = rOBP0 = rOBP1 = 0) while the port holds real colours
-- at its dump. Two hypotheses:
--   (a) the port omits a GBPalWhiteOutWithDelay3 on this exit; or
--   (b) the golden's STATE-DRIVEN dump lands inside a whiteout phase that the
--       port's FIXED-FRAME dump (AUTOKEY_DUMP_FRAME=900) misses.
--
-- (a) is already weakened: faithdiff StartMenu_Item is 22 pret / 24 port with
-- 21 matched and NO GBPalWhiteOut / LoadGBPal line in the diff, so the port has
-- those calls where pret does.
--
-- WHY A PREVIOUS ATTEMPT FAILED, so nobody repeats it: the port side was probed
-- at six dump frames 60 apart (760..1000) and read "never white" at all six.
-- That proves nothing. GBPalWhiteOutWithDelay3 is a whiteout followed by
-- Delay3, so the white window is ~3 FRAMES; 60-frame sampling cannot see it.
-- Sampling must be PER FRAME, which is what this recorder does.
--
-- WHAT THIS MEASURES: every frame of the real item flow, log rBGP/rOBP0/rOBP1
-- whenever they change, and count how long each whiteout lasts. Then read the
-- state at the exact instant item_potion_use.lua dumps.
--   A whiteout of a few frames, with colour restored after  -> (b): a phase
--     artifact. The port is not wrong; the two dumps photograph different
--     moments, and the fix is the harness clock (or a mask when gating).
--   Whiteout that PERSISTS to the dump and beyond                -> (a): the
--     port genuinely fails to reach that state, and the fix is in the port.
-- Record the frame counts, not the impression.
--
-- No golden is written and none should be: `make goldens-verify` skips *_trace.
--
-- Run: dos_port/tools/mgba_harness/make_goldens.sh item_palette_trace

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local gbtext = require("lib.gbtext")
local scenario = require("lib.scenario")
local seed = require("lib.seed")
local navigate = require("lib.navigate")

local sym = symbols.load()
local text = gbtext.load()
navigate.init(sym, text)

-- Per-frame watcher. Registered before scenario.run so it sees every frame; it
-- only reads, so it cannot perturb the run.
local timeline = {}
local wframe = 0
local last = nil
local white_frames = 0          -- total frames spent fully white
local white_runs = {}           -- length of each contiguous white run
local cur_run = 0

callbacks:add("frame", function()
	wframe = wframe + 1
	local bgp, obp0, obp1 = emu:read8(0xFF47), emu:read8(0xFF48), emu:read8(0xFF49)
	local is_white = (bgp == 0 and obp0 == 0 and obp1 == 0)
	if is_white then
		white_frames = white_frames + 1
		cur_run = cur_run + 1
	elseif cur_run > 0 then
		white_runs[#white_runs + 1] = { start = wframe - cur_run, len = cur_run }
		cur_run = 0
	end
	local key = ("%02X%02X%02X"):format(bgp, obp0, obp1)
	if key ~= last then
		last = key
		if #timeline < 500 then
			timeline[#timeline + 1] = ("f%-6d rBGP=%02X rOBP0=%02X rOBP1=%02X%s")
				:format(wframe, bgp, obp0, obp1, is_white and "   <-- FULLY WHITE" or "")
		end
	end
end)

local function probe(what)
	local bgp, obp0, obp1 = emu:read8(0xFF47), emu:read8(0xFF48), emu:read8(0xFF49)
	console:log(("---- %s (frame %d): rBGP=%02X rOBP0=%02X rOBP1=%02X %s"):format(
		what, wframe, bgp, obp0, obp1,
		(bgp == 0 and obp0 == 0 and obp1 == 0) and "FULLY WHITE" or "coloured"))
end

scenario.run(function()
	navigate.boot_to_main_menu()
	navigate.new_game_to_bedroom()

	scenario.exec(function()
		seed.debug_new_game(sym, text:encode(seed.PLAYER_NAME))
		emu:write8(sym:addr("wPartyMon1HP"), 0)
		emu:write8(sym:addr("wPartyMon1HP") + 1, 1)
	end)

	-- Exactly item_potion_use.lua's navigation, so the dump instant matches.
	navigate.open_start_menu()
	navigate.choose(text:encode("ITEM"))
	navigate.wait_for_text(text:encode("POTION"))
	scenario.wait(30)
	navigate.choose(text:encode("POTION"))
	navigate.ensure_text("A", text:encode("USE"))
	scenario.wait(30)
	navigate.choose(text:encode("USE"))
	navigate.wait_for_text(text:encode("Use item on which"))
	scenario.wait(30)
	navigate.choose(text:encode("SNORLAX"), nil, 1)
	navigate.wait_for_text(text:encode("recovered"))
	navigate.dismiss_text(text:encode("recovered"))
	scenario.exec(function() probe("after the heal message") end)

	navigate.wait_for_text(text:encode("ANTIDOTE"))
	scenario.wait(30)
	navigate.choose(text:encode("ANTIDOTE"))
	navigate.ensure_text("A", text:encode("USE"))
	scenario.wait(30)
	navigate.choose(text:encode("USE"))
	navigate.wait_for_text(text:encode("Use item on which"))
	scenario.wait(30)
	navigate.choose(text:encode("SNORLAX"), nil, 1)
	navigate.wait_for_text(text:encode("effect"))
	navigate.dismiss_text(text:encode("effect"))
	scenario.wait(30) -- the same settle item_potion_use.lua does before dumping

	scenario.exec(function()
		probe("THE DUMP INSTANT (item_potion_use dumps here)")
	end)

	-- CRITICAL FOLLOW-ON: keep watching PAST the dump. If the white run ends
	-- shortly after, the dump landed inside a transient (RestoreScreenTiles...
	-- reloads tile patterns with the LCD off, which is slow) and this is a PHASE
	-- artifact, not a missing whiteout. If it persists, it is a settled state.
	scenario.wait(400)
	scenario.exec(function()
		probe("400 FRAMES AFTER the dump instant")
		console:log("========== rBGP/rOBP0/rOBP1 change timeline ==========")
		for _, line in ipairs(timeline) do console:log("  " .. line) end
		console:log(("========== %d transitions =========="):format(#timeline))
		console:log(("TOTAL frames fully white: %d of %d"):format(white_frames, wframe))
		console:log("contiguous white runs (start,length):")
		for _, r in ipairs(white_runs) do
			console:log(("   f%-6d len=%d"):format(r.start, r.len))
		end
		if cur_run > 0 then
			console:log(("   f%-6d len=%d (STILL WHITE at the dump)"):format(wframe - cur_run, cur_run))
		end
	end)
end)
