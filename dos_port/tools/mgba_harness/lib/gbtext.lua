---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- gbtext.lua — encode readable text to Gen-1 charmap bytes for tilemap
-- assertions ("does the screen say NEW GAME?").
--
-- The mapping is parsed from pret's constants/charmap.asm at runtime — the
-- project's no-hand-encoded-charmap-bytes rule applies to harness predicates
-- too: bytes come from the pret source, never typed in.
--
-- Usage:
--   local gbtext = require("lib.gbtext")
--   local text = gbtext.load()          -- $PKMN_CHARMAP or constants/charmap.asm
--   local needle = text:encode("NEW GAME")
--   if tilemap:find(needle, 1, true) then ...

local gbtext = {}

local DEFAULT_CHARMAP = "constants/charmap.asm" -- right when cwd = repo root

local Text = {}
Text.__index = Text

-- UTF-8 string → charmap byte string. GREEDY, like pret's own assembler: at each
-- position the LONGEST matching charmap token wins, so the apostrophe ligatures
-- ("'s" $BD, "'t" $BE, "'d" $BB, "'l" $BC, "'m" $E5, "'r" $E4, "'v" $BF) and the
-- control tokens ("<PLAYER>" $52, "<PKMN>" $4A, ...) encode as the SINGLE TILES
-- they are. Falls back to one tile per glyph ("é", "▶", "▼"), and errors on any
-- unmapped character so a typo'd assertion cannot silently never-match.
--
-- Before this was greedy, a needle containing an apostrophe simply COULD NOT BE
-- WRITTEN: encode() hit "'" with no single-tile entry and raised. Scenarios worked
-- around it by picking apostrophe-free substrings and documenting the trap
-- (dex_rating_oak_pc used "PROF.OAK" rather than "PROF.OAK\'s PC"), and
-- safari_game_over asked for "Time\'s up!" — which is exactly the text on screen —
-- and timed out for 1800 frames against a needle it could never build.
-- The port itself was never affected: its far-text generators take pret\'s own
-- assembled bytes, which is why assets/bills_house_pc_text.inc already contains
-- 0x91,0xBD for "TELEPORTER\'s".
function Text:encode(s)
	local out = {}
	local i, n = 1, #s
	while i <= n do
		local matched = false
		-- Longest token first: "'s" must beat "'" (which is itself a real tile,
		-- $E0), and "<PLAYER>" must beat "<".
		for _, tok in ipairs(self.tokens) do
			if #tok <= n - i + 1 and s:sub(i, i + #tok - 1) == tok then
				out[#out + 1] = string.char(self.by_char[tok])
				i = i + #tok
				matched = true
				break
			end
		end
		if not matched then
			-- single glyph (may be multi-BYTE utf8: "é", "▶", "▼")
			local nexti = utf8.offset(s, 2, i) or (n + 1)
			local ch = s:sub(i, nexti - 1)
			local byte = self.by_char[ch]
			if not byte then
				error(("gbtext: %q (in %q) has no charmap entry"):format(ch, s), 2)
			end
			out[#out + 1] = string.char(byte)
			i = nexti
		end
	end
	return table.concat(out)
end

function gbtext.load(path)
	path = path or os.getenv("PKMN_CHARMAP") or DEFAULT_CHARMAP
	local f, err = io.open(path, "r")
	if not f then
		error(("gbtext: cannot open charmap %q (%s) — set $PKMN_CHARMAP to pret's "
			.. "constants/charmap.asm"):format(path, tostring(err)))
	end
	local by_char = {}
	for line in f:lines() do
		-- entries look like:  charmap "A", $80  — keep single-glyph mappings
		-- (one UTF-8 char, e.g. "é"/"▶"); control/multi-char entries like
		-- "<PKMN>" are not single text tiles
		local ch, byte = line:match('charmap%s+"(.-)",%s+%$(%x+)')
		-- first-wins: the primary (Latin) block precedes the Japanese block,
		-- which reuses the same byte range
		-- Multi-char tokens are KEPT now (they are single tiles on screen); the
		-- greedy encoder above picks the longest match. first-wins still holds.
		if ch and ch ~= "" and not by_char[ch] then
			by_char[ch] = tonumber(byte, 16)
		end
	end
	f:close()
	if not by_char["A"] then
		error(("gbtext: %q parsed without an 'A' mapping — wrong file?"):format(path))
	end
	-- Tokens longer than one BYTE, sorted longest-first, for the greedy match.
	local tokens = {}
	for tok in pairs(by_char) do
		if #tok > 1 then
			tokens[#tokens + 1] = tok
		end
	end
	table.sort(tokens, function(a, b)
		if #a ~= #b then return #a > #b end
		return a < b
	end)
	return setmetatable({ path = path, by_char = by_char, tokens = tokens }, Text)
end

return gbtext
