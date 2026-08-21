---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- route_15_binoculars — golden for Route15GateLeftBinoculars
-- (pret engine/events/hidden_events/route_15_binoculars.asm).
--
-- WHAT IT PROVES: standing below the LEFT binoculars on Route 15 Gate 2F and facing
-- UP runs the real A-press dispatch —
--   CheckForHiddenEventOrBookshelfOrCardKeyDoor -> CheckForHiddenEvent
--   -> Route15GateLeftBinoculars -> EnableAutoTextBoxDrawing
--   -> tx_pre Route15UpstairsBinocularsText (predef text)
--   -> wCurPartySpecies = ARTICUNO -> PlayCry -> DisplayMonFrontSpriteInBox
-- so the dump captures both the predef text stream on screen AND the Articuno
-- front-sprite pop-up box (a VRAM/tilemap surface, which is why this scenario is
-- class "default" and not "datastruct" — the mon box is the interesting half and a
-- WRAM-only comparison could not see it).
--
-- REWRITTEN 2026-08-21. The previous version had never been executed and could not
-- have run: it called seed.warp(), which does not exist in lib/seed.lua; it used map
-- id 197, which is DIGLETTS_CAVE ($C5) and not ROUTE_15_GATE_2F ($B9); and it stood
-- the player ON the prop tile, which matches no hidden event (see lib/hidden_object.lua).

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local gbtext = require("lib.gbtext")
local hidden_object = require("lib.hidden_object")

local sym = symbols.load()
local text = gbtext.load()

-- constants/map_constants.asm: map_const ROUTE_15_GATE_2F, 4, 4 ; $B9
local ROUTE_15_GATE_2F = 0xB9
local ROUTE_15_GATE_2F_WIDTH = 4

hidden_object.run(sym, text, {
	name = "route_15_binoculars",
	map = ROUTE_15_GATE_2F,
	width = ROUTE_15_GATE_2F_WIDTH,
	-- data/events/hidden_events.asm: hidden_event 2, 1, Route15GateLeftBinoculars,
	-- SPRITE_FACING_UP -> the prop is (y=2, x=1), so the player stands at (y=3, x=1).
	y = 3,
	x = 1,
	facing = 4, -- SPRITE_FACING_UP
	text = text:encode("Looked into"),
	description = "Route15GateLeftBinoculars: read the left binoculars facing UP on Route 15 Gate 2F",
})
