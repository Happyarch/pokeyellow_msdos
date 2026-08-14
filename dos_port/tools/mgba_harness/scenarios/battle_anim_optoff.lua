---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- battle_anim_optoff — Stage 6's animations-OFF witness, and the last of the
-- family. With wOptions BIT_BATTLE_ANIMATION set, MoveAnimation skips
-- ShareMoveAnimations and PlayAnimation for a flat 30-frame delay
-- (engine/battle/animations.asm:437-446) and only then calls
-- PlayApplyingAttackAnimation.
--
-- THE LANDMARK IS INSIDE THAT DISABLED ARM, and that choice is the whole point.
-- An earlier version of this scenario stopped at battle_anim_blink's shared
-- hidden-pic landmark and PASSED while proving nothing: at that instant the only
-- surfaces separating the animated route from this one are 79 VRAM tile slots
-- (49..127) and the wOptions byte, and every one of those slots is inside this
-- family's _BATTLE_VRAM_MASKS_MENU ($8000-$87FF, slots 0x00-0x7F). A port that
-- ignored the option would still have passed. Stopping inside the arm fixes that
-- by construction: the port must TAKE the arm to dump at all, so a port that
-- animated anyway never reaches the checkpoint and the run fails loudly.
--
-- The reference stops at the matching ROM instant: the move-used message fully
-- printed with the enemy pic still up. Nothing moves during the 30-frame delay,
-- so the state is static across the whole window and the two sides need not
-- agree on a frame number.

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
local BIT_BATTLE_ANIMATION = 7 -- constants/ram_constants.asm; 1 = animations OFF
local TILEMAP_ADDR, TILEMAP_W = 0xC3A0, 20
local BLANK = 0x7F
-- the enemy pic is a 7x7 block at GB (12,0) -- pret AnimationHideMonPic's
-- enemy-turn branch (`ld a, 12`), which the port mirrors as BCOORD(12,0).
local PIC_COL, PIC_ROW, PIC_SIZE = 12, 0, 7
local MOVE_SLOT = 3 -- 0-based; STRENGTH sits in the debug party's move slot 4

local function enemyPicVisible(tilemap)
	for r = PIC_ROW, PIC_ROW + PIC_SIZE - 1 do
		for c = PIC_COL, PIC_COL + PIC_SIZE - 1 do
			if tilemap:byte(r * TILEMAP_W + c + 1) ~= BLANK then
				return true
			end
		end
	end
	return false
end

scenario.run(function()
	battle.enter_wild(sym, text)
	input.tap("A", 2, 8)
	navigate.dialog_until_text(text:encode("FIGHT"), 3600)
	scenario.wait(30)

	scenario.exec(function()
		emu:write8(sym:addr("wEnemyMonStatus"), SLEEP_TURNS)
		-- THE SUBJECT: battle animations OFF. The port gate sets the identical
		-- bit, and wOptions lives in the compared wOptionsBlock region, so the
		-- pin is compared rather than assumed.
		local opts = sym:addr("wOptions")
		emu:write8(opts, emu:read8(opts) | (1 << BIT_BATTLE_ANIMATION))
	end)

	navigate.choose(text:encode("FIGHT"))
	navigate.ensure_text("A", text:encode("STRENGTH"), 3600)
	scenario.wait(30)
	-- PP BEFORE the turn. pret's order is DisplayUsedMoveText -> DecrementPP ->
	-- ... -> PlayMoveAnimation (core.asm:3289-3346), so the message alone lands
	-- in the small window BEFORE the decrement while the port's checkpoint is
	-- inside MoveAnimation, i.e. after it. Measured, not guessed: the first
	-- version stopped on the message alone and diverged on exactly wBattleMon
	-- PP 4 and wPartyData mon 0 PP 4 (want $05, got $04). Waiting for the
	-- decrement aligns the two instants.
	local ppAddr = sym:addr("wBattleMonPP") + MOVE_SLOT
	local ppBefore = scenario.read_range(ppAddr, 1):byte(1)
	navigate.choose(text:encode("STRENGTH"))

	-- The move-used message complete, the PP spent, AND the enemy pic still up.
	-- That triple is true only between DecrementPP and the applying-attack
	-- animation, which is exactly the disabled arm's delay window. Requiring the
	-- whole "used STRENGTH!" string rather than a prefix rules out catching the
	-- text mid-print, when the tilemap would not yet match the port's.
	local msg = text:encode("used STRENGTH!")
	local found = false
	for _ = 1, 3600 do
		local tilemap = scenario.read_range(TILEMAP_ADDR, TILEMAP_W * 18)
		local pp = scenario.read_range(ppAddr, 1):byte(1)
		if tilemap:find(msg, 1, true) and pp < ppBefore and enemyPicVisible(tilemap) then
			found = true
			break
		end
	end
	assert(found, "battle_anim_optoff: never reached the post-DecrementPP window with the pic up")

	scenario.exec(function()
		dump.write("battle_anim_optoff", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "inside MoveAnimation's animations-disabled arm (wOptions " ..
				"BIT_BATTLE_ANIMATION set): the move-used message is printed, the enemy " ..
				"pic is up and no move animation ran",
		})
	end)
end)
