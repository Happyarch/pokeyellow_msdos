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

-- UTF-8 string → charmap byte string (one tile per glyph: "é", "▶", "▼" are
-- single tiles); errors on any unmapped character so a typo'd assertion can't
-- silently never-match.
function Text:encode(s)
	local out = {}
	for _, cp in utf8.codes(s) do
		local ch = utf8.char(cp)
		local byte = self.by_char[ch]
		if not byte then
			error(("gbtext: %q (in %q) has no single-tile charmap entry"):format(ch, s), 2)
		end
		out[#out + 1] = string.char(byte)
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
		if ch and utf8.len(ch) == 1 and not by_char[ch] then
			by_char[ch] = tonumber(byte, 16)
		end
	end
	f:close()
	if not by_char["A"] then
		error(("gbtext: %q parsed without an 'A' mapping — wrong file?"):format(path))
	end
	return setmetatable({ path = path, by_char = by_char }, Text)
end

return gbtext
