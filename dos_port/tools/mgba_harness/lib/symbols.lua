---@diagnostic disable: undefined-global -- emu/C/callbacks/console/socket are mGBA runtime globals (runner.c)
-- symbols.lua — parse an rgbds .sym file (pokeyellow.sym) so harness scripts
-- address GB memory by pret label, never by hardcoded number.
--
-- The .sym comes from the sha1-verified golden ROM build in the pinned
-- pristine pret worktree (../pokeyellow_msdos-pret-golden/ — see the
-- fidelity-harness plan, Session A note: branch pret trees do NOT build).
--
-- Usage:
--   local symbols = require("lib.symbols")
--   local sym = symbols.load()                -- $PKMN_SYM, then default guess
--   local sym = symbols.load("/path/to.sym")  -- explicit
--   sym:addr("wTileMap")   --> 0xC3A0  (errors loudly on unknown label)
--   sym:get("DrawHPBar")   --> { bank = 0x12, addr = 0x4B7B }  or nil

local symbols = {}

-- Fallback used when $PKMN_SYM is unset and no path is given; only right when
-- cwd is the repo root of a worktree sitting beside the pinned golden one.
local DEFAULT_SYM = "../pokeyellow_msdos-pret-golden/pokeyellow.sym"

local Sym = {}
Sym.__index = Sym

-- Full bank:addr pair, or nil if the label doesn't exist.
function Sym:get(label)
	return self.by_label[label]
end

-- Plain GB address for a label; errors on a missing label so a typo can't
-- silently read address 0 (goldens generated off the wrong address are worse
-- than no goldens).
function Sym:addr(label)
	local entry = self.by_label[label]
	if not entry then
		error(("symbols: label %q not in %s"):format(label, self.path), 2)
	end
	return entry.addr
end

function symbols.load(path)
	path = path or os.getenv("PKMN_SYM") or DEFAULT_SYM
	local f, err = io.open(path, "r")
	if not f then
		error(("symbols: cannot open sym file %q (%s) — set $PKMN_SYM to the "
			.. "golden pokeyellow.sym"):format(path, tostring(err)))
	end
	local by_label = {}
	local count = 0
	for line in f:lines() do
		-- rgbds format: "BB:AAAA LabelName" (hex), ';' comments
		local bank, addr, label = line:match("^(%x+):(%x+)%s+(%S+)")
		if bank and label:sub(1, 1) ~= ";" then
			by_label[label] = {
				bank = tonumber(bank, 16),
				addr = tonumber(addr, 16),
			}
			count = count + 1
		end
	end
	f:close()
	if count == 0 then
		error(("symbols: %q parsed to zero symbols — not an rgbds .sym?"):format(path))
	end
	return setmetatable({ path = path, by_label = by_label, count = count }, Sym)
end

return symbols
