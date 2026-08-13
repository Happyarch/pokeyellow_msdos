---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- battle_anim_ball — Stage 6's ball-animation witness. Third of the family
-- after battle_anim_physical and battle_anim_elemental, and it uses the same
-- landmark: the first frame whose hardware OAM differs from the parked control
-- state, i.e. the first live frame block of the toss.
--
-- WHY IT IS NOT ball_catch. ball_catch (id 20) drives this exact route but is
-- differ class "datastruct" (WRAM only) and dumps only once wBattleResult goes
-- 2 -- after the capture has RESOLVED, by which point every toss frame block
-- has been cleaned up. It reaches the code and compares a surface where the
-- animation cannot show. This scenario stops much earlier, with the party still
-- at 5 (the caught mon not yet appended).
--
-- WHICH ANIMATION. pret picks the toss animation by item
-- (engine/battle/animations.asm:2795): POKE_BALL -> TOSS_ANIM, GREAT_BALL ->
-- GREATTOSS_ANIM, everything else -> ULTRATOSS_ANIM. This route throws a MASTER
-- BALL, so the animation under test is ULTRATOSS_ANIM ($C6), NOT the TOSS_ANIM
-- ($C1) the Stage-6 spec names -- a port checkpoint keyed on TOSS_ANIM here
-- would silently never fire.

local here = debug.getinfo(1, "S").source:match("^@(.*)$")
local root = here and here:match("^(.*)[/\\]scenarios[/\\][^/\\]+$") or "."
package.path = root .. "/?.lua;" .. package.path

local symbols = require("lib.symbols")
local gbtext = require("lib.gbtext")
local input = require("lib.input")
local dump = require("lib.dump")
local scenario = require("lib.scenario")
local navigate = require("lib.navigate")
local battle = require("lib.battle")

local sym = symbols.load()
local text = gbtext.load()
navigate.init(sym, text)

local OAM_ADDR, OAM_SIZE = 0xFE00, 160

scenario.run(function()
	battle.enter_wild(sym, text)

	-- A dismisses "appeared!"; send-out runs unattended; menu box parks.
	input.tap("A", 2, 8)
	navigate.dialog_until_text(text:encode("FIGHT"), 3600)
	scenario.wait(30) -- settle: menu parked in its input loop

	-- one party slot free, mirroring the port gate (ball_catch's AddPartyMon
	-- path). The capture never completes here, but both sides must still make
	-- the identical write for wPartyData to compare.
	scenario.exec(function()
		emu:write8(sym:addr("wPartyCount"), 5)
	end)

	navigate.choose(text:encode("ITEM"))
	navigate.ensure_text("A", text:encode("MASTER BALL"))
	scenario.wait(30) -- settle: a tap into a just-drawn list is swallowed

	-- The control state, captured with the bag list up and before the throw.
	-- Menu OAM is already nonzero, so nonzero is not evidence of a frame block;
	-- the live toss frame must CHANGE it.
	local parked = scenario.read_range(OAM_ADDR, OAM_SIZE)
	navigate.choose(text:encode("MASTER BALL"))

	local live
	for _ = 1, 3600 do
		local oam = scenario.read_range(OAM_ADDR, OAM_SIZE)
		if oam ~= parked then
			live = oam
			break
		end
	end
	assert(live, "battle_anim_ball: the MASTER BALL toss never produced a changed OAM frame")

	scenario.exec(function()
		dump.write("battle_anim_ball", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "first live OAM frame block of the MASTER BALL toss " ..
				"(ULTRATOSS_ANIM) thrown from the real battle ITEM menu, before " ..
				"the capture resolves and the party grows",
		})
	end)
end)
