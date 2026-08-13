---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- battle_anim_blink — Stage 6's shake/blink witness. Fourth of the family, and
-- the first one whose landmark is NOT a frame block.
--
-- WHAT IT WITNESSES. After a move's own animation, MoveAnimation calls
-- PlayApplyingAttackAnimation, which dispatches on wAnimationType
-- (engine/battle/animations.asm:506). Type 4 -- "player mon has used a damaging
-- move without a side effect" -- is BlinkEnemyMonSprite -> AnimationBlinkEnemyMon
-- -> AnimationBlinkMon, which loops six times over
-- {hide pic, 5 frames, show pic, 5 frames}. STRENGTH selects exactly that arm.
--
-- THE LANDMARK is the FIRST hidden-pic instant: AnimationHideMonPic has cleared
-- the enemy's 7x7 pic block from the tilemap, the move animation is over, and
-- damage has NOT been applied yet (ApplyAttackToEnemyPokemon runs after
-- MoveAnimation returns). Both halves are checked below, because "the pic block
-- is blank" alone is not enough -- a blank block plus full enemy HP is what pins
-- this to the blink rather than to a later hide.
--
-- WHY NO EXISTING SCENARIO COVERS IT: battle_anim_physical stops EARLIER (inside
-- the move animation's first frame block) and battle_faint stops LATER (after the
-- KO and the HUD restage). The blink sits between them and nothing had ever
-- compared it.

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

local SLEEP_TURNS = 7 -- keep the enemy from introducing an RNG-dependent turn
local TILEMAP_ADDR, TILEMAP_W = 0xC3A0, 20
local BLANK = 0x7F
-- the enemy pic is a 7x7 block at GB (12,0) -- pret AnimationHideMonPic's
-- enemy-turn branch (`ld a, 12`), which the port mirrors as BCOORD(12,0).
local PIC_COL, PIC_ROW, PIC_SIZE = 12, 0, 7

local function enemyPicHidden(tilemap)
	for r = PIC_ROW, PIC_ROW + PIC_SIZE - 1 do
		for c = PIC_COL, PIC_COL + PIC_SIZE - 1 do
			if tilemap:byte(r * TILEMAP_W + c + 1) ~= BLANK then
				return false
			end
		end
	end
	return true
end

scenario.run(function()
	battle.enter_wild(sym, text)
	input.tap("A", 2, 8)
	navigate.dialog_until_text(text:encode("FIGHT"), 3600)
	scenario.wait(30)

	scenario.exec(function()
		emu:write8(sym:addr("wEnemyMonStatus"), SLEEP_TURNS)
	end)

	navigate.choose(text:encode("FIGHT"))
	navigate.ensure_text("A", text:encode("STRENGTH"), 3600)
	scenario.wait(30)
	navigate.choose(text:encode("STRENGTH"))

	-- Damage is applied only after MoveAnimation returns, so full enemy HP is
	-- what separates a blink hide from any later one.
	local hpAddr = sym:addr("wEnemyMonHP")
	local found = false
	for _ = 1, 3600 do
		local tilemap = scenario.read_range(TILEMAP_ADDR, TILEMAP_W * 18)
		-- read_range, not emu:read8 -- direct emu access outside scenario.exec
		-- raises "Function called from invalid context".
		local hp = scenario.read_range(hpAddr, 2) -- big-endian word
		local alive = hp:byte(1) ~= 0 or hp:byte(2) ~= 0
		if enemyPicHidden(tilemap) and alive then
			found = true
			break
		end
	end
	assert(found, "battle_anim_blink: the enemy pic was never hidden with the mon still alive")

	scenario.exec(function()
		dump.write("battle_anim_blink", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "first hidden-pic instant of AnimationBlinkMon (wAnimationType 4, " ..
				"BlinkEnemyMonSprite) after the real FIGHT -> STRENGTH move animation " ..
				"and before damage is applied",
		})
	end)
end)
