---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- pewter_gym_statues — golden for GymStatues
-- (pret engine/events/hidden_events/gym_statues.asm).
--
-- WHAT IT PROVES: reading a gym statue facing UP runs the real A-press dispatch —
--   CheckForHiddenEventOrBookshelfOrCardKeyDoor -> CheckForHiddenEvent
--   -> GymStatues -> EnableAutoTextBoxDrawing -> the MapBadgeFlags scan for wCurMap
--   -> wBeatGymFlags test -> tx_pre_id GymStatueText1 -> PrintPredefTextID
-- putting "<CITY> #MON GYM / LEADER: <NAME>" on screen.
--
-- Two things only a runtime witness can check here: the MapBadgeFlags TABLE SCAN
-- (a data table the port generates, walked with `cp $ff` termination), and the
-- text_ram splice — GymStatueText1 is text_ram wGymCityName + text_ram
-- wGymLeaderName, so the string on screen is assembled from WRAM the handler
-- populated, not from a static stream.
--
-- BRANCH: with no badges, wBeatGymFlags fails the AND/CP and selects GymStatueText1
-- (the "haven't beaten it" text). GymStatueText2 is NOT witnessed here.
--
-- REPLACES the committed draft indigo_plateau_statues.lua, which never left Red's
-- bedroom. Its target, IndigoPlateauStatues, is a BOOKSHELF TILE on INDIGO_PLATEAU
-- ($30 in the PLATEAU tileset) whose statues are impassable pillars read from the
-- side, and it remains unwitnessed. A gym statue is the same dispatch with an open
-- floor in front of it, which is why this is the instance that got gated.
--
-- WALKABILITY: player (11,3) is four $11 tiles, all passable; the statue at (10,3)
-- is $22/$23/$32/$33 and impassable, so pressing UP turns without moving.

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local gbtext = require("lib.gbtext")
local hidden_object = require("lib.hidden_object")

local sym = symbols.load()
local text = gbtext.load()

-- constants/map_constants.asm: map_const PEWTER_GYM, 5, 7 ; $36
local PEWTER_GYM = 0x36
local PEWTER_GYM_WIDTH = 5

hidden_object.run(sym, text, {
	name = "pewter_gym_statues",
	map = PEWTER_GYM,
	width = PEWTER_GYM_WIDTH,
	-- data/events/hidden_events.asm: hidden_event 10, 3, GymStatues, SPRITE_FACING_UP
	-- -> the prop is (y=10, x=3), so the player stands at (y=11, x=3).
	y = 11,
	x = 3,
	facing = 4, -- SPRITE_FACING_UP
	text = text:encode("GYM"),
	description = "GymStatues: read the left statue facing UP in Pewter Gym with no badges",
})
