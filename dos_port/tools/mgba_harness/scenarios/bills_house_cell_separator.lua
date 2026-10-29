---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- bills_house_cell_separator — GROUND TRUTH timing for the Bill's-house
-- cell-separator cutscene. Twin of the port's AUTOKEY_BILLHOUSE table.
--
-- WHAT IS MEASURED
--   Start: standing on Route 25 outside Bill's door (manifest seed_save, the same
--          battery image the port loads as POKEMON.DSV).
--   End:   BillsHouseScript8 — Bill is out of the machinery and the SS TICKET box
--          is on screen.
--   The deliverable is that span's FRAME COUNT on both sides, because the report
--   is that the port takes far longer than the GB's "few seconds".
--
-- WHY TAPS, NOT HOLDS
--   scripts/BillsHouse.asm sets wJoyIgnore = PAD_BUTTONS|PAD_CTRL_PAD in Script2
--   (Bill's walk) and in BillsHousePikachuConfused (entry emote + emote bubbles),
--   so held input is dropped for seconds at a time. A tap that gets eaten costs
--   nothing; a hold that gets eaten walks into a wall.
--
-- WHY TRAINS, NOT 3s SPACING
--   The typewriter page time is not fixed. A fixed cadence drifts and strands the
--   game parked on the YES/NO ("Help me out here!"). One A per 25 frames clears the
--   whole box; at the YES/NO the first press takes the default YES, and while Bill
--   walks the rest are ignored.
--
-- GEOMETRY (data/maps/objects/*.asm, text/BillsHouse.asm)
--   Route 25:  warp_event 45, 3, BILLS_HOUSE, 1  -> start (45,4), one tap UP
--   BillsHouse: warps (2,7)/(3,7); Bill's costume object_event 6, 5
--               PC hidden event at (1,4), read from (1,5) facing UP
--   Pikachu runs up to Bill from BELOW, so (6,6) is taken: the talk tile is
--   (5,5) facing RIGHT, i.e. approach from the LEFT.
--
-- KEEP IN SYNC: every frame number below must equal AUTOKEY_BILLHOUSE in
-- src/debug/debug_dump.asm, or the two counts are not comparable.

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local input = require("lib.input")
local scenario = require("lib.scenario")

local sym = symbols.load()

local T = {
	boot_start  = 400,   -- START to leave the title
	boot_a1     = 470,
	boot_start2 = 560,
	boot_a2     = 640,
	boot_start3 = 730,
	boot_a3     = 810,   -- CONTINUE
	boot_a_info = 995,   -- the save-info panel's own A
	door        = 1400,  -- one tap UP into the house
	emote_wait  = 2000,  -- entry Pikachu confused emote (wJoyIgnore)
	right1      = 2060,  -- 3 taps: (2,7) -> (5,7)
	right2      = 2095,
	right3      = 2130,
	up1         = 2200,  -- (5,7) -> (5,6)
	up2         = 2235,  -- (5,6) -> (5,5)
	face_right  = 2265,  -- blocked by Bill (6,5) -> facing RIGHT
	talk        = 2290,  -- opens _BillsHouseBillImNotAPokemonText
	train_from  = 2475,  -- A train: 4 <PARA> + YES/NO + separation text
	train_n     = 60,
	train_step  = 25,
	bill_wait   = 4700,  -- Bill walks + hides + Pikachu emote
	left1       = 4800,  -- 4 taps: (5,5) -> (1,5)
	left2       = 4835,
	left3       = 4870,
	left4       = 4905,
	pc_face_up  = 4970,  -- blocked by the PC (1,4) -> facing UP
	cut_from    = 5050,  -- A train through the cell-separator text
	cut_n       = 60,
	cut_step    = 25,
}

-- Absolute-frame tap: yield until `at`, then press 4 frames (the port's cadence).
local function tap_at(at, keys)
	while scenario.frame() < at do
		scenario.wait(1)
	end
	input.tap(keys, 4, 8)
end

local function wait_until(at)
	while scenario.frame() < at do
		scenario.wait(1)
	end
end

local function train(from, n, step)
	for i = 0, n - 1 do
		tap_at(from + i * step, "A")
	end
end

scenario.run(function()
	-- title -> main menu -> CONTINUE -> save-info panel
	tap_at(T.boot_start,  "START")
	tap_at(T.boot_a1,     "A")
	tap_at(T.boot_start2, "START")
	tap_at(T.boot_a2,     "A")
	tap_at(T.boot_start3, "START")
	tap_at(T.boot_a3,     "A")
	tap_at(T.boot_a_info, "A")

	-- into the house, then wait out the entry emote
	tap_at(T.door, "UP")
	wait_until(T.emote_wait)

	-- walk to the tile LEFT of Bill and face him
	tap_at(T.right1,     "RIGHT")
	tap_at(T.right2,     "RIGHT")
	tap_at(T.right3,     "RIGHT")
	tap_at(T.up1,        "UP")
	tap_at(T.up2,        "UP")
	tap_at(T.face_right, "RIGHT")
	tap_at(T.talk,       "A")
	train(T.train_from, T.train_n, T.train_step)

	-- Bill walks to the separator and hides; Pikachu emotes over him
	wait_until(T.bill_wait)

	-- over to the PC at (1,4) and use it
	tap_at(T.left1,      "LEFT")
	tap_at(T.left2,      "LEFT")
	tap_at(T.left3,      "LEFT")
	tap_at(T.left4,      "LEFT")
	tap_at(T.pc_face_up, "UP")
	train(T.cut_from, T.cut_n, T.cut_step)

	scenario.log(("bills_house_cell_separator: reached frame %d"):format(scenario.frame()))
end)
