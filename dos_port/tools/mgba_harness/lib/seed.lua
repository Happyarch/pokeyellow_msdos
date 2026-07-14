---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- seed.lua — deterministic WRAM seeding for golden scenarios, mirroring the
-- port's PrepareNewGameDebug (dos_port/src/engine/debug/debug_party.asm).
--
-- The port's debug seed calls _AddPartyMon, whose DVs come from Random_ — so
-- its exact bytes cannot be reproduced by construction. Instead this module
-- IS the spec: explicit species/levels/move-pokes (copied from
-- DebugNewGameParty), a fixed DV constant, and every derived field computed
-- by pret's own formulas from data read out of the sha1-verified ROM
-- (BaseStats/Moves/MonsterNames/IndexToPokedex via the cart0 domain). The
-- port harness must converge to this same spec (deterministic-DV knob —
-- fidelity plan, Session D/E).
--
-- Struct layout = pret party mon struct (44 B), all multi-byte fields
-- big-endian (MON_HP/MON_OT_ID/MON_EXP/stat-exp/stats) — the Gen-2
-- forward-compat hard rule rides on offset 7 (catch rate) surviving intact.
--
-- ⚠ Every function here touches emu:* — call only inside scenario.exec
-- thunks (main Lua state), after the game is in the overworld.

local seed = {}

local PARTYMON_STRUCT_LENGTH = 44
local NAME_LENGTH = 11
local NUM_POKEMON = 151
local TERMINATOR = 0x50 -- "@"

-- Fixed DV spec: Atk 9 / Def 8 / Spd 7 / Spc 6 (→ HP DV 10, from the LSBs).
-- Distinct per-stat values so a swapped-stat rendering bug shows distinct
-- numbers. The port's Session-D knob must write these same two bytes.
seed.DV_BYTES = { 0x98, 0x76 }
local DV = { atk = 9, def = 8, spd = 7, spc = 6, hp = 10 }

-- The port's debug party, verbatim from DebugNewGameParty + the move pokes in
-- PrepareNewGameDebug (internal species indices; moves poked AFTER PP is
-- written, so poked slots keep the pre-poke PP — port quirk, kept faithful).
local FLY, CUT, SURF, STRENGTH = 19, 15, 57, 70
seed.DEBUG_PARTY = {
	{ species = 132, level = 80, pokes = { [1] = FLY, [2] = CUT, [3] = SURF, [4] = STRENGTH } }, -- SNORLAX
	{ species = 144, level = 80 }, -- PERSIAN
	{ species = 100, level = 15 }, -- JIGGLYPUFF
	{ species = 84,  level = 5,  pokes = { [3] = SURF } }, -- STARTER_PIKACHU
	{ species = 180, level = 50 }, -- CHARIZARD
	{ species = 19,  level = 34 }, -- LAPRAS
}

-- Player identity spec: OT/menu name and trainer ID shared by the port
-- harness (Session D seeds the same; wPlayerID 0 matches its zeroed WRAM).
seed.PLAYER_NAME = "RED"
seed.PLAYER_ID = 0x0000

-- The port's debug bag, verbatim from DebugNewGameItemsList
-- (dos_port/src/engine/debug/debug_party.asm) — {item id, quantity} pairs,
-- ids per constants/item_constants.asm.
seed.DEBUG_ITEMS = {
	{ 20, 1 },  -- POTION
	{ 11, 3 },  -- ANTIDOTE
	{ 1, 99 },  -- MASTER_BALL
	{ 5, 1 },   -- TOWN_MAP
	{ 6, 1 },   -- BICYCLE
	{ 16, 99 }, -- FULL_RESTORE
	{ 29, 99 }, -- ESCAPE_ROPE
	{ 40, 99 }, -- RARE_CANDY
	{ 43, 1 },  -- SECRET_KEY
	{ 48, 1 },  -- CARD_KEY
	{ 52, 99 }, -- FULL_HEAL
	{ 53, 99 }, -- REVIVE
	{ 60, 99 }, -- FRESH_WATER
	{ 63, 1 },  -- S_S_TICKET
	{ 74, 1 },  -- LIFT_KEY
	{ 79, 99 }, -- PP_UP
}

-- ---------------------------------------------------------------------------
-- ROM readers (cart0 domain: flat offset = bank*0x4000 + addr%0x4000)
-- ---------------------------------------------------------------------------

local function flat(entry)
	if entry.addr < 0x4000 then
		return entry.addr
	end
	return entry.bank * 0x4000 + (entry.addr - 0x4000)
end

local function rom(sym, label, offset, len)
	local cart = assert(emu.memory.cart0, "seed: cart0 memory domain missing")
	return cart:readRange(flat(sym:get(label) or error("seed: no sym " .. label)) + offset, len)
end

-- pret base stats record (28 B, indexed by pokedex number):
-- 0 dex# | 1-5 hp/atk/def/spd/spc | 6-7 types | 8 catch | 9 base exp |
-- 10 pic dims | 11-14 pic ptrs | 15-18 level-1 moves | 19 growth | 20-26 tmhm
local function base_stats(sym, dex)
	local rec = rom(sym, "BaseStats", 28 * (dex - 1), 28)
	assert(rec:byte(1) == dex,
		("seed: BaseStats[%d] dex byte is %d — flat ROM addressing broken?"):format(dex, rec:byte(1)))
	return rec
end

local function index_to_dex(sym, internal)
	-- PokedexOrder is the internal→dex data table (IndexToPokedex is the
	-- routine that reads it)
	return rom(sym, "PokedexOrder", internal - 1, 1):byte(1)
end

local function monster_name(sym, internal) -- 10 B, @-padded
	return rom(sym, "MonsterNames", 10 * (internal - 1), 10)
end

local function move_pp(sym, move) -- Moves record: anim/effect/power/type/acc/pp
	return rom(sym, "Moves", 6 * (move - 1) + 5, 1):byte(1)
end

-- GetMonLearnset (pret engine/pokemon/evos_moves.asm:617): index
-- EvosMovesPointerTable by internal species id, follow the pointer, then skip the
-- evolution data — which, exactly as pret does it, means scanning bytes until a 0
-- (no interior byte of an evo entry is ever 0, and a single 0 terminates the list).
-- Returns the learnset as an ordered {level, move} list (sorted by level).
local function mon_learnset(sym, internal)
	local entry = sym:get("EvosMovesPointerTable") or error("seed: no sym EvosMovesPointerTable")
	local cart = assert(emu.memory.cart0, "seed: cart0 memory domain missing")
	local ptr_bytes = cart:readRange(flat(entry) + 2 * (internal - 1), 2)
	local ptr = ptr_bytes:byte(1) | (ptr_bytes:byte(2) << 8)
	-- the evos/moves data lives in the same bank as its pointer table
	local off = entry.bank * 0x4000 + (ptr - 0x4000)

	local data = cart:readRange(off, 256)
	local i = 1
	while data:byte(i) ~= 0 do -- skip evolution data
		i = i + 1
		assert(i < 256, "seed: runaway evolution data — bad learnset pointer?")
	end
	i = i + 1 -- past the terminator; learnset = (level, move) pairs, 0-terminated

	local learnset = {}
	while data:byte(i) ~= 0 do
		learnset[#learnset + 1] = { level = data:byte(i), move = data:byte(i + 1) }
		i = i + 2
		assert(i < 256, "seed: runaway learnset")
	end
	return learnset
end

-- WriteMonMoves (pret evos_moves.asm:498), with wLearningMovesFromDayCare = 0 —
-- which is what _AddPartyMon sets before its `predef WriteMonMoves` (add_mon.asm:197).
--
-- This is THE step that makes a party mon's moves the ones it would actually know
-- at its level: _AddPartyMon first copies the species' four base-stats moves, then
-- WriteMonMoves walks the level-up learnset and folds in every move at or below the
-- mon's level (skipping duplicates, filling an empty slot, else shifting slot 1 out
-- and appending at slot 4). Seeding only the base moves — as this file used to —
-- produces a party the real game would never produce.
local function write_mon_moves(moves, learnset, level)
	for _, entry in ipairs(learnset) do
		if level < entry.level then
			break -- learnset is sorted by level
		end
		local known, empty = false, nil
		for slot = 1, 4 do
			if moves[slot] == entry.move then
				known = true
				break
			end
			if empty == nil and moves[slot] == 0 then
				empty = slot
			end
		end
		if not known then
			if empty then
				moves[empty] = entry.move
			else -- no free slot: shift moves up (deleting move 1), append at 4
				moves[1], moves[2], moves[3], moves[4] = moves[2], moves[3], moves[4], entry.move
			end
		end
	end
	return moves
end

-- ---------------------------------------------------------------------------
-- pret formulas
-- ---------------------------------------------------------------------------

-- CalcStat (home/pokemon.asm) with stat exp 0 (fresh mon, term drops out):
-- floor(2*(base+DV)*level/100) + 5, HP instead +level+10.
local function calc_stat(base, dv, level, is_hp)
	local v = (2 * (base + dv) * level) // 100
	return v + (is_hp and (level + 10) or 5)
end

-- CalcExperience growth-rate polynomials (Gen 1; rates 1/2 unused).
local function exp_for_level(level, growth)
	local n = level
	if growth == 0 then -- MEDIUM_FAST
		return n * n * n
	elseif growth == 3 then -- MEDIUM_SLOW
		return (6 * n * n * n) // 5 - 15 * n * n + 100 * n - 140
	elseif growth == 4 then -- FAST
		return (4 * n * n * n) // 5
	elseif growth == 5 then -- SLOW
		return (5 * n * n * n) // 4
	end
	error("seed: unhandled growth rate " .. tostring(growth))
end

-- ---------------------------------------------------------------------------
-- byte assembly
-- ---------------------------------------------------------------------------

local function u16be(v)
	return string.char((v >> 8) & 0xFF, v & 0xFF)
end

local function u24be(v)
	return string.char((v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF)
end

local function write_bytes(addr, str)
	for i = 1, #str do
		emu:write8(addr + i - 1, str:byte(i))
	end
end

-- One 44-byte party mon struct per the _AddPartyMon fill (pret
-- engine/pokemon/add_mon.asm), fresh non-wild mon: full HP, no status,
-- stat exp 0, OT = player.
local function build_mon(sym, mon)
	local dex = index_to_dex(sym, mon.species)
	local bs = base_stats(sym, dex)
	local hp_base, atk, def, spd, spc = bs:byte(2, 6)
	local type1, type2 = bs:byte(7, 8)
	local catch = bs:byte(9)
	local growth = bs:byte(20)

	-- KADABRA ships TWISTEDSPOON_GSC in the catch-rate byte (_AddPartyMon
	-- special case; Gen-2 held-item slot)
	if mon.species == 38 then
		catch = 0x60
	end

	-- Moves, exactly as _AddPartyMon builds them: the species' four base-stats
	-- moves, then `predef WriteMonMoves` folds in the level-up learnset for this
	-- level (add_mon.asm:179-199). PP is written AFTERWARDS, by
	-- AddPartyMon_WriteMovePP (add_mon.asm:230), so it comes from the FINAL moves.
	-- The port's `pokes` (PrepareNewGameDebug's HM overrides) are applied later
	-- still and do NOT recompute PP — a port quirk this mirrors deliberately.
	local moves = write_mon_moves({ bs:byte(16, 19) }, mon_learnset(sym, mon.species), mon.level)
	local pp = {}
	for i = 1, 4 do
		pp[i] = moves[i] ~= 0 and move_pp(sym, moves[i]) or 0
	end
	for slot, move in pairs(mon.pokes or {}) do
		moves[slot] = move
	end

	local max_hp = calc_stat(hp_base, DV.hp, mon.level, true)
	local stats = u16be(max_hp)
		.. u16be(calc_stat(atk, DV.atk, mon.level, false))
		.. u16be(calc_stat(def, DV.def, mon.level, false))
		.. u16be(calc_stat(spd, DV.spd, mon.level, false))
		.. u16be(calc_stat(spc, DV.spc, mon.level, false))

	local struct = string.char(mon.species)          -- 0 species
		.. u16be(max_hp)                             -- 1-2 current HP = max
		.. string.char(0)                            -- 3 box level
		.. string.char(0)                            -- 4 status
		.. string.char(type1, type2)                 -- 5-6 types
		.. string.char(catch)                        -- 7 catch rate (Gen-2 held item)
		.. string.char(moves[1], moves[2], moves[3], moves[4]) -- 8-11
		.. u16be(seed.PLAYER_ID)                     -- 12-13 OT ID
		.. u24be(exp_for_level(mon.level, growth))   -- 14-16 EXP
		.. string.rep("\0", 10)                      -- 17-26 stat exp
		.. string.char(seed.DV_BYTES[1], seed.DV_BYTES[2]) -- 27-28 DVs
		.. string.char(pp[1], pp[2], pp[3], pp[4])   -- 29-32 PP (pre-poke)
		.. string.char(mon.level)                    -- 33 level
		.. stats                                     -- 34-43
	assert(#struct == PARTYMON_STRUCT_LENGTH)
	return struct
end

-- ---------------------------------------------------------------------------
-- public API (inside scenario.exec only)
-- ---------------------------------------------------------------------------

-- Write wPlayerName (@-terminated, @-padded to 11) + wPlayerID.
-- `name_bytes` is already charmap-encoded (gbtext), e.g. text:encode("RED").
function seed.player(sym, name_bytes)
	assert(#name_bytes < NAME_LENGTH, "seed: player name too long")
	write_bytes(sym:addr("wPlayerName"),
		name_bytes .. string.rep(string.char(TERMINATOR), NAME_LENGTH - #name_bytes))
	write_bytes(sym:addr("wPlayerID"), u16be(seed.PLAYER_ID))
end

-- Seed the full party (default: the port's debug party). OT names = player
-- name, nicknames = species names from ROM ("kept default name" outcome,
-- matching the port's AskName stub).
function seed.party(sym, name_bytes, party)
	party = party or seed.DEBUG_PARTY
	assert(#party <= 6, "seed: party too large")

	emu:write8(sym:addr("wPartyCount"), #party)
	local species_list = ""
	for _, mon in ipairs(party) do
		species_list = species_list .. string.char(mon.species)
	end
	write_bytes(sym:addr("wPartySpecies"), species_list .. "\xFF")

	local ot = name_bytes .. string.rep(string.char(TERMINATOR), NAME_LENGTH - #name_bytes)
	for i, mon in ipairs(party) do
		write_bytes(sym:addr("wPartyMons") + PARTYMON_STRUCT_LENGTH * (i - 1), build_mon(sym, mon))
		write_bytes(sym:addr("wPartyMonOT") + NAME_LENGTH * (i - 1), ot)
		write_bytes(sym:addr("wPartyMonNicks") + NAME_LENGTH * (i - 1),
			monster_name(sym, mon.species) .. string.char(TERMINATOR))
	end
	console:log(("seed: party of %d written (spec DVs %02X %02X, OT id %04X)"):format(
		#party, seed.DV_BYTES[1], seed.DV_BYTES[2], seed.PLAYER_ID))
end

-- Seed the bag (default: the port's debug item list): wNumBagItems, then
-- (id,qty) pairs, then the $FF terminator — the layout AddItemToInventory_
-- maintains.
function seed.items(sym, items)
	items = items or seed.DEBUG_ITEMS
	assert(#items <= 20, "seed: bag overflow (max 20 slots)")
	local bytes = string.char(#items)
	for _, it in ipairs(items) do
		bytes = bytes .. string.char(it[1], it[2])
	end
	bytes = bytes .. "\xFF"
	write_bytes(sym:addr("wNumBagItems"), bytes)
	console:log(("seed: bag of %d items written"):format(#items))
end

-- Pokédex flags, mirroring the port's DebugSetPokedexEntries (all SEEN) and
-- DebugSetPokedexOwnedScatter (a deterministic ~half-set OWNED pattern), so both
-- sides show the same CONTENTS list. debug_party.asm:216-245 is the spec: NUM_POKEMON/8
-- full bytes then a tail byte masked to the leftover bits.
function seed.pokedex(sym)
	local full, tail_bits = NUM_POKEMON // 8, NUM_POKEMON % 8
	local tail_mask = (1 << tail_bits) - 1

	local seen = string.rep("\xFF", full) .. string.char(tail_mask)
	write_bytes(sym:addr("wPokedexSeen"), seen)

	local owned, a = "", 0xB5 -- pattern seed
	for _ = 1, full do
		owned = owned .. string.char(a)
		a = ((a << 3) | (a >> 5)) & 0xFF -- rol al, 3
		a = a ~ 0x5D                     -- xor al, 0x5D
	end
	owned = owned .. string.char(a & tail_mask)
	write_bytes(sym:addr("wPokedexOwned"), owned)
	console:log("seed: pokedex written (all seen, scattered owned)")
end

-- wPlayerMoney (3-byte BCD) — the port's "give max money" (debug_party.asm:182).
function seed.money(sym, bcd)
	bcd = bcd or "\x99\x99\x99"
	assert(#bcd == 3, "seed: money is 3 BCD bytes")
	write_bytes(sym:addr("wPlayerMoney"), bcd)
end

-- wObtainedBadges — the port grants every badge except EARTHBADGE (bit 7).
function seed.badges(sym, badges)
	emu:write8(sym:addr("wObtainedBadges"), badges or 0x7F)
end

-- ---------------------------------------------------------------------------
-- Stage 2: battle convergence spec (fidelity plan)
-- ---------------------------------------------------------------------------

-- Wild enemy spec: PIDGEY (internal $24), level 13, the shared DV bytes.
seed.ENEMY = { species = 0x24, level = 13 }

-- Make the next grass step encounter-deterministic in OUTCOME: wGrassRate=$FF
-- (the encounter roll passes 255/256 — mGBA is deterministic, so whichever
-- step triggers is the same run-to-run) and all 10 wGrassMons slots = the spec
-- mon, so the slot roll cannot change the result.
function seed.force_encounter(sym)
	emu:write8(sym:addr("wGrassRate"), 0xFF)
	write_bytes(sym:addr("wGrassMons"),
		string.char(seed.ENEMY.level, seed.ENEMY.species):rep(10))
	console:log("seed: forced grass encounters (10 x L13 PIDGEY, rate $FF)")
end

-- Set one wEventFlags bit (constants/event_constants.asm numbering). Event
-- flags are NOT in any compared region (see the debug_new_game note), so this
-- is pure navigation enablement — e.g. EVENT_FOLLOWED_OAK_INTO_LAB (0) turns
-- off Pallet Town's scripted Oak catch-up at the Route 1 boundary.
function seed.set_event(sym, event)
	local addr = sym:addr("wEventFlags") + (event >> 3)
	emu:write8(addr, emu:read8(addr) | (1 << (event & 7)))
end

-- After the REAL LoadEnemyMonData has run (battle intro on screen): ASSERT the
-- loader-derived parts of wEnemyMon — species, level, types, catch rate, moves,
-- PP — so a loader regression fails the scenario instead of being papered over;
-- then overwrite ONLY the RNG-derived parts: DVs → the spec bytes, the five
-- stats recomputed by pret's CalcStat from those DVs (stat exp 0), HP = MaxHP,
-- and the unmodified level+stats snapshot LoadEnemyMonData took from the rolled
-- DVs. The port's DEBUG_BATTLE_GOLDEN gate performs the same overwrite after
-- its own real LoadEnemyMonData call, so both sides converge byte-for-byte.
function seed.enemy(sym)
	local function rd(label)
		return emu:read8(sym:addr(label))
	end
	assert(rd("wEnemyMonSpecies") == seed.ENEMY.species,
		("seed.enemy: loader put species %02X in wEnemyMon"):format(rd("wEnemyMonSpecies")))
	assert(rd("wEnemyMonLevel") == seed.ENEMY.level,
		("seed.enemy: loader put level %d in wEnemyMon"):format(rd("wEnemyMonLevel")))
	assert(rd("wEnemyMonStatus") == 0, "seed.enemy: nonzero status on a fresh wild mon")

	local dex = index_to_dex(sym, seed.ENEMY.species)
	local bs = base_stats(sym, dex)
	local hp_base, atk, def, spd, spc = bs:byte(2, 6)
	assert(rd("wEnemyMonType1") == bs:byte(7) and rd("wEnemyMonType2") == bs:byte(8),
		"seed.enemy: loader types do not match BaseStats")
	assert(rd("wEnemyMonCatchRate") == bs:byte(9),
		"seed.enemy: loader catch rate does not match BaseStats")

	-- moves exactly as the wild path builds them: the 4 base-stats moves, then
	-- WriteMonMoves folds in the level-up learnset; PP from the FINAL moves.
	local moves = write_mon_moves({ bs:byte(16, 19) },
		mon_learnset(sym, seed.ENEMY.species), seed.ENEMY.level)
	for slot = 1, 4 do
		local got = emu:read8(sym:addr("wEnemyMonMoves") + slot - 1)
		assert(got == moves[slot],
			("seed.enemy: move slot %d is %02X, learnset says %02X"):format(slot, got, moves[slot]))
		local want_pp = moves[slot] ~= 0 and move_pp(sym, moves[slot]) or 0
		local got_pp = emu:read8(sym:addr("wEnemyMonPP") + slot - 1)
		assert(got_pp == want_pp,
			("seed.enemy: PP slot %d is %d, Moves table says %d"):format(slot, got_pp, want_pp))
	end

	-- overwrite the RNG-derived parts
	write_bytes(sym:addr("wEnemyMonDVs"), string.char(seed.DV_BYTES[1], seed.DV_BYTES[2]))
	local max_hp = calc_stat(hp_base, DV.hp, seed.ENEMY.level, true)
	local stats = u16be(max_hp)
		.. u16be(calc_stat(atk, DV.atk, seed.ENEMY.level, false))
		.. u16be(calc_stat(def, DV.def, seed.ENEMY.level, false))
		.. u16be(calc_stat(spd, DV.spd, seed.ENEMY.level, false))
		.. u16be(calc_stat(spc, DV.spc, seed.ENEMY.level, false))
	write_bytes(sym:addr("wEnemyMonMaxHP"), stats)
	write_bytes(sym:addr("wEnemyMonHP"), u16be(max_hp))
	-- the snapshot is 1 + NUM_STATS*2 bytes copied from wEnemyMonLevel
	write_bytes(sym:addr("wEnemyMonUnmodifiedLevel"), string.char(seed.ENEMY.level) .. stats)
	console:log(("seed: enemy DVs %02X %02X, stats %d/%d HP recomputed"):format(
		seed.DV_BYTES[1], seed.DV_BYTES[2], max_hp, max_hp))
end

-- The whole of the port's PrepareNewGameDebug (debug_party.asm:76-186) in one
-- call: identity, party, bag, pokédex, badges, money.
--
-- Every port DEBUG_* gate that reaches a real screen calls PrepareNewGameDebug,
-- so the golden must seed ALL of it — not just the parts the screen under test
-- displays. Before the WRAM regions were compared, a scenario could get away with
-- seeding only its own screen's data (status seeded the party but no bag, etc.);
-- now every scenario compares the full game-data block, so any gap shows up as a
-- divergence. Scenarios whose port gate seeds LESS (start_menu calls only
-- SeedDeterministicPlayerIdentity) must correspondingly call only seed.player.
--
-- NOT mirrored, because no compared region covers them: wEventFlags
-- (EVENT_GOT_POKEDEX), wRivalStarter, wTownVisitedFlag, wMonDataLocation.
function seed.debug_new_game(sym, name_bytes)
	seed.player(sym, name_bytes)
	seed.party(sym, name_bytes)
	seed.items(sym)
	seed.pokedex(sym)
	seed.badges(sym)
	seed.money(sym)
end

return seed
