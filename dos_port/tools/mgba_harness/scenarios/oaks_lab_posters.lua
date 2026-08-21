---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- oaks_lab_posters — golden for DisplayOakLabLeftPoster
-- (pret engine/events/hidden_events/oaks_lab_posters.asm).
--
-- WHAT IT PROVES: standing below the LEFT poster in Oak's Lab and facing UP runs the
-- real A-press dispatch —
--   CheckForHiddenEventOrBookshelfOrCardKeyDoor -> CheckForHiddenEvent
--   -> DisplayOakLabLeftPoster -> EnableAutoTextBoxDrawing
--   -> tx_pre_jump PushStartText -> PrintPredefTextID
-- putting "Push START to / open the MENU!" on screen. That tx_pre_jump tail is the
-- reason this one is worth gating: it is a predef-text JUMP at a routine tail, the
-- shape faithdiff cannot see through (it reports the added PrintPredefTextID call),
-- so a runtime witness is the only check that the jump lands anywhere real.
--
-- SCOPE, stated so it is not inferred: this scenario reads the LEFT poster only.
-- DisplayOakLabRightPoster (x=5) is a DIFFERENT handler with a CountSetBits branch on
-- the dex count, and it is NOT witnessed here. The port gate can drive it with
-- OAKS_LAB_POSTER=right, but no golden is registered for it.
--
-- REWRITTEN 2026-08-21: the previous version had never been executed and walked to
-- the poster with navigate.walk_to(), which does not exist in lib/navigate.lua.

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local gbtext = require("lib.gbtext")
local hidden_object = require("lib.hidden_object")

local sym = symbols.load()
local text = gbtext.load()

-- constants/map_constants.asm: map_const OAKS_LAB, 5, 6 ; $28
local OAKS_LAB = 0x28
local OAKS_LAB_WIDTH = 5

hidden_object.run(sym, text, {
	name = "oaks_lab_posters",
	map = OAKS_LAB,
	width = OAKS_LAB_WIDTH,
	-- data/events/hidden_events.asm: hidden_event 0, 4, DisplayOakLabLeftPoster,
	-- SPRITE_FACING_UP -> the prop is (y=0, x=4), so the player stands at (y=1, x=4).
	y = 1,
	x = 4,
	facing = 4, -- SPRITE_FACING_UP
	text = text:encode("Push START"),
	description = "DisplayOakLabLeftPoster: read the left poster facing UP in Oak's Lab",
})
