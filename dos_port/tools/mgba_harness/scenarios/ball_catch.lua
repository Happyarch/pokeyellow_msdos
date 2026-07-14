---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- ball_catch — golden for the port's DEBUG_BATTLE_GOLDEN=1 DEBUG_ITEMBALL=1
-- gate (fidelity plan Stage 2e, differ class "datastruct": WRAM game data
-- only). The convergence-spec wild PIDGEY L13 battle (battle.enter_wild), then
-- the REAL battle menu → ITEM → MASTER BALL (seeded bag slot 2, qty 99):
-- catch flow ("caught!" → dex text → dex entry screen → nickname prompt),
-- declining the nickname with B — the port's AddPartyMon keeps the default
-- species name (documented AskName stub), so declining is the converging
-- answer.
--
-- Party count is dropped to 5 before the throw (mirroring the gate) so the
-- capture takes the AddPartyMon path — the box path ends in the interactive
-- naming screen either way (SendNewMonToBox names unconditionally).
--
-- Dump point: the frame wBattleResult goes 2 (UseBagItem's post-capture tail,
-- pret core.asm:2375-2395) — the same instant the port gate dumps after its
-- mirrored tail. Polled per-frame; deterministic emulation makes the frame
-- exact across runs.
--
-- Pins: wPartyData (count 5→6, PIDGEY appended: enemy DVs $98$76 carried over,
-- stats/EXP for L13, OT = player, nick = species default); wBagItems
-- (MASTER_BALL qty 99→98, slots otherwise untouched); wPokedex (PIDGEY seen +
-- owned); wEnemyMon (the spec enemy, still loaded).

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

scenario.run(function()
	battle.enter_wild(sym, text)

	-- A dismisses "appeared!"; send-out runs unattended; menu box parks.
	input.tap("A", 2, 8)
	navigate.dialog_until_text(text:encode("FIGHT"), 3600)
	scenario.wait(30) -- settle: menu parked in its input loop

	-- one party slot free → AddPartyMon path (see header)
	scenario.exec(function()
		emu:write8(sym:addr("wPartyCount"), 5)
	end)

	-- battle menu is a 2x2 grid; ITEM is directly below FIGHT, so the row-wise
	-- cursor walk in navigate.choose lands on it
	navigate.choose(text:encode("ITEM"))
	navigate.ensure_text("A", text:encode("MASTER BALL"))
	scenario.wait(30) -- settle: a tap into a just-drawn list is swallowed
	navigate.choose(text:encode("MASTER BALL"))

	-- catch flow: "All right! PIDGEY was caught!" (<cont> scroll-wait
	-- mid-stream, so the ▼-answering walker drives it) → "New #DEX data …" →
	-- dex entry screen (arrowless button wait) → "Do you want to give a
	-- nickname to PIDGEY?". The middle beats race against the taps (measured:
	-- a "DEX data" checkpoint was already gone by its wait), so after "caught"
	-- tap A until the nickname prompt PRINTS — tap_until stops at first sight,
	-- while the text is still printing, before the YES/NO menu draws, so no
	-- tap can land on the menu (whose default is YES, the wrong answer).
	navigate.dialog_until_text(text:encode("caught"), 3600)
	navigate.dismiss_text(text:encode("caught"))
	navigate.tap_until("A", text:encode("nickname"), 3600)
	scenario.wait(60) -- let the YES/NO menu draw fully
	-- decline → default species name (port convergence). A single tap into the
	-- just-drawn menu is swallowed (joypad flush) — retry while the prompt is
	-- up, like dismiss_text does for A.
	local nick = text:encode("nickname")
	for _ = 1, 120 do
		if not navigate.tilemap():find(nick, 1, true) then
			break
		end
		input.tap("B", 2, 10)
		scenario.wait(4)
	end

	-- UseBagItem's post-capture tail sets wBattleResult = 2 right after
	-- ItemUseBall returns (ball removed from the bag last) — the dump instant.
	-- navigate.read8 advances one frame per poll, so this is a per-frame watch.
	local seen = false
	for _ = 1, 1800 do
		if navigate.read8("wBattleResult") == 2 then
			seen = true
			break
		end
	end
	assert(seen, "ball_catch: wBattleResult never went 2 (capture tail)")

	scenario.exec(function()
		dump.write("ball_catch", dump.standard_regions(sym), {
			frame = scenario.frame(),
			description = "MASTER BALL thrown at the spec wild PIDGEY L13 from the real " ..
				"battle ITEM menu; nickname declined; dumped the frame wBattleResult " ..
				"went 2 (UseBagItem post-capture tail) — party 6 with PIDGEY appended, " ..
				"MASTER_BALL 99 -> 98, dex seen+owned set",
		})
	end)
end)
