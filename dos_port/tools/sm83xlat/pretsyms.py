#!/usr/bin/env python3
"""pretsyms.py — the pret-side symbol universe a script line can legally name.

`scripts/` references four disjoint namespaces and the source gives no syntactic
hint which is which:

  * RAM labels        `wCurrentMapScriptFlags`, `hTextID`, `wSpritePlayerStateData1FacingDirection`
  * constants         `EVENT_BEAT_MISTY`, `PAD_CTRL_PAD`, `TM_BUBBLEBEAM`, `SPRITE_BLUE`
  * routine labels    `TalkToTrainer`, `DisplayTextID`
  * script-local      `SCRIPT_CERULEANGYM_DEFAULT`, `TEXT_PEWTERMART_CLERK`

Only the first has a shared mapping already built (`tables/symbols.json`). This
module builds the rest, because "does this name resolve?" has to be answerable
before `unresolved-symbol` means anything: a probe that cannot see pret's
constants reports its own blind spot as the corpus's largest problem.

THREE DEFINITION MECHANISMS THAT ARE EASY TO MISS
-------------------------------------------------
1. **`dw_const` defines its second argument.** `dw_const Foo, TEXT_BAR` expands
   to `dw Foo` + `const TEXT_BAR`, so every `TEXT_*` and `SCRIPT_*` name is
   defined *inside a script file*, by the pointer table that uses it. Nothing in
   `constants/` mentions them.
2. **`const_export` in `data/maps/objects/*.asm`** defines the per-map object
   ids (`OAKSLAB_RIVAL`). Those are map data, not constants/.
3. **`ram/wram.asm` generates names.** `wSpritePlayerStateData1FacingDirection`
   is not written anywhere: it is `spritestatedata1`'s `\\1FacingDirection` field
   applied to `wSpritePlayerStateData1`, and the numbered siblings come from a
   `FOR n, 1, NUM_SPRITESTATEDATA_STRUCTS - 1` loop with `{02d:n}`
   interpolation. Both are expanded here.

`constants/hardware.inc` is a `.inc`, not a `.asm`, and spells its definitions
`def PAD_CTRL_PAD equ %1111_0000` in lower case — so the scan is over
`constants/*` with a case-insensitive pattern. That one file holds 116 of the
references the first version of this probe reported as unresolved.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, Optional, Set

# rgbasm built-in operators and functions that lex as identifiers.
BUILTINS = {
    "BANK", "HIGH", "LOW", "DEF", "SIZEOF", "STARTOF", "ISCONST",
    "bank", "high", "low", "def", "sizeof", "startof",
}

# Struct macros in macros/ram.asm, as field-suffix lists. Read off the macro
# bodies; a suffix missing here surfaces as an unresolved symbol, not as a
# silently-wrong address, which is the failure mode worth having.
STRUCT_FIELDS: Dict[str, tuple] = {
    "box_struct": (
        "Species", "HP", "BoxLevel", "Status", "Type", "Type1", "Type2",
        "CatchRate", "Moves", "OTID", "Exp", "HPExp", "AttackExp",
        "DefenseExp", "SpeedExp", "SpecialExp", "DVs", "PP",
    ),
    "party_struct": (
        "Species", "HP", "BoxLevel", "Status", "Type", "Type1", "Type2",
        "CatchRate", "Moves", "OTID", "Exp", "HPExp", "AttackExp",
        "DefenseExp", "SpeedExp", "SpecialExp", "DVs", "PP",
        "Level", "Stats", "MaxHP", "Attack", "Defense", "Speed", "Special",
    ),
    "battle_struct": (
        "Species", "HP", "PartyPos", "BoxLevel", "Status", "Type", "Type1",
        "Type2", "CatchRate", "Moves", "DVs", "Level", "Stats", "MaxHP",
        "Attack", "Defense", "Speed", "Special", "PP",
    ),
    "spritestatedata1": (
        "PictureID", "MovementStatus", "ImageIndex", "YStepVector", "YPixels",
        "XStepVector", "XPixels", "IntraAnimFrameCounter", "AnimFrameCounter",
        "FacingDirection", "YAdjusted", "XAdjusted", "CollisionData", "End",
    ),
    "spritestatedata2": (
        "WalkAnimationCounter", "YDisplacement", "XDisplacement", "MapY",
        "MapX", "MovementByte1", "GrassPriority", "MovementDelay",
        "OrigFacingDirection", "PictureID", "ImageBaseOffset", "End",
    ),
    "sprite_oam_struct": ("YCoord", "XCoord", "TileID", "Attributes"),
}

_INT = re.compile(r"^\s*(?:\$([0-9A-Fa-f]+)|%([01_]+)|(-?\d+))\s*$")
_NAME = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")


#: pret directories scanned for column-0 code/data labels. `scripts/` is scanned
#: by the parser itself, so it is not repeated here.
#:
#: `text/` is in the list because `text_far _PewterMartYoungsterText` names a
#: label defined there. Leaving it out reported ~2,900 phantom unresolved
#: references — every text pointer in the corpus.
LABEL_DIRS = ("home", "engine", "audio", "data", "gfx", "text")


@dataclass
class Universe:
    ram: Set[str] = field(default_factory=set)
    constants: Set[str] = field(default_factory=set)
    labels: Set[str] = field(default_factory=set)
    values: Dict[str, int] = field(default_factory=dict)
    script_constants: Set[str] = field(default_factory=set)
    #: names that exist only because a FOR bound could not be evaluated and the
    #: loop was over-generated. Reported so a resolution is never credited to
    #: over-approximation without saying so.
    over_generated: Set[str] = field(default_factory=set)

    def __contains__(self, name: str) -> bool:
        return (name in self.ram or name in self.constants or name in self.labels
                or name in self.script_constants or name in BUILTINS)


def _parse_int(text: str) -> Optional[int]:
    m = _INT.match(text)
    if not m:
        return None
    if m.group(1) is not None:
        return int(m.group(1), 16)
    if m.group(2) is not None:
        return int(m.group(2).replace("_", ""), 2)
    return int(m.group(3))


def _eval(expr: str, values: Dict[str, int]) -> Optional[int]:
    """Evaluate the small integer expressions FOR bounds are written with.

    Deliberately tiny: integers, known constant names, + - * and parentheses.
    Anything else returns None and the caller over-generates rather than
    guessing a bound.
    """
    e = expr.strip()
    direct = _parse_int(e)
    if direct is not None:
        return direct
    subst = e
    for name in sorted(set(_NAME.findall(e)), key=len, reverse=True):
        if name not in values:
            return None
        subst = re.sub(rf"\b{re.escape(name)}\b", str(values[name]), subst)
    subst = re.sub(r"\$([0-9A-Fa-f]+)", lambda m: str(int(m.group(1), 16)), subst)
    subst = re.sub(r"%([01_]+)",
                   lambda m: str(int(m.group(1).replace("_", ""), 2)), subst)
    # Shifts and masks are needed for the flag-constant idiom
    # `DEF MONEY_SIGN EQU 1 << BIT_MONEY_SIGN`, which is how every BIT_*/mask
    # pair in constants/ is written.
    if not re.fullmatch(r"[0-9+\-*/()<>|&~^ ]+", subst):
        return None
    try:
        return int(eval(subst, {"__builtins__": {}}, {}))  # noqa: S307 — bounded charset above
    except Exception:
        return None


def _scan_constants(paths, uni: Universe) -> None:
    """Walk `const`-enumerated and `equ`-defined names, tracking values.

    Values matter for exactly one thing here — evaluating the `FOR` bounds in
    wram.asm — but the same table is what Stage 1's constants.json is built on,
    so it is collected properly rather than as a name set.
    """
    for p in paths:
        try:
            text = p.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            continue
        value = 0
        inc = 1
        rs = 0
        for raw in text.splitlines():
            line = raw.split(";")[0].strip()
            if not line:
                continue
            m = re.match(r"^(const_def|object_const_def)\b\s*(.*)$", line, re.I)
            if m:
                if m.group(1).lower() == "object_const_def":
                    # macros/scripts/maps.asm: object_const_def == const_def 1
                    value, inc = 1, 1
                    continue
                args = [a.strip() for a in m.group(2).split(",") if a.strip()]
                value = _eval(args[0], uni.values) if args else 0
                value = 0 if value is None else value
                inc = 1
                if len(args) > 1:
                    got = _eval(args[1], uni.values)
                    inc = 1 if got is None else got
                continue
            m = re.match(r"^(const|const_export|shift_const)\s+([A-Za-z_][A-Za-z0-9_]*)",
                         line, re.I)
            if m:
                name = m.group(2)
                uni.constants.add(name)
                uni.values.setdefault(name, value if m.group(1).lower() != "shift_const"
                                      else (1 << value if 0 <= value < 32 else value))
                value += inc
                continue
            m = re.match(r"^const_next\s+(.+)$", line, re.I)
            if m:
                got = _eval(m.group(1), uni.values)
                if got is not None:
                    value = got
                continue
            m = re.match(r"^const_skip\b\s*(.*)$", line, re.I)
            if m:
                n = _eval(m.group(1), uni.values) if m.group(1).strip() else 1
                value += inc * (1 if n is None else n)
                continue
            m = re.match(r"^(?:def\s+)?([A-Za-z_][A-Za-z0-9_]*)\s+equs?\s+(.*)$",
                         line, re.I)
            if m:
                uni.constants.add(m.group(1))
                # `DEF NUM_POKEMON EQU const_value - 1` reads the enumerator's
                # running value. It is not a symbol, so it is substituted here
                # rather than looked up — without this, NUM_POKEMON, NUM_BADGES
                # and friends have a name but no value.
                expr = re.sub(r"\bconst_value\b", str(value), m.group(2))
                got = _eval(expr, uni.values)
                if got is not None:
                    uni.values.setdefault(m.group(1), got)
                continue
            # rsset-style struct offsets: `DEF MON_MAXHP rw`, `def OBJ_SIZE rb 0`.
            # The value is the running _RS counter, so it has to be tracked, not
            # just the name: scripts do arithmetic on these
            # (`ld bc, MON_MAXHP - MON_HP` in Daycare) and `OBJ_SIZE` is a plain
            # size the emitter has to write as a number.
            m = re.match(r"^rsreset\b", line, re.I)
            if m:
                rs = 0
                continue
            m = re.match(r"^rsset\s+(.+)$", line, re.I)
            if m:
                got = _eval(m.group(1), uni.values)
                if got is not None:
                    rs = got
                continue
            m = re.match(r"^(?:def\s+)?([A-Za-z_][A-Za-z0-9_]*)\s+r([bwl])\b\s*(.*)$",
                         line, re.I)
            if m:
                name, kind, count = m.group(1), m.group(2).lower(), m.group(3).strip()
                uni.constants.add(name)
                uni.values.setdefault(name, rs)
                n = _eval(count, uni.values) if count else 1
                width = {"b": 1, "w": 2, "l": 4}[kind]
                rs += width * (1 if n is None else n)
                continue
            # Enumerator macros defined inside constants/ itself. Each consumes
            # a `const` slot and defines derived names alongside it; the derived
            # names are what scripts actually reference (OPP_*, *_WIDTH, TM_*).
            m = re.match(r"^(map_const|trainer_const|add_tm|add_hm|music_const|"
                         r"toggle_consts_for)\s+([A-Za-z_][A-Za-z0-9_]*)", line, re.I)
            if m:
                what, name = m.group(1).lower(), m.group(2)
                if what == "map_const":
                    uni.constants.update({name, name + "_WIDTH", name + "_HEIGHT"})
                    uni.values.setdefault(name, value)
                    value += inc
                elif what == "trainer_const":
                    uni.constants.update({name, "OPP_" + name})
                    uni.values.setdefault(name, value)
                    value += inc
                elif what in ("add_tm", "add_hm"):
                    prefix = "TM_" if what == "add_tm" else "HM_"
                    uni.constants.update({prefix + name, name + "_TMNUM"})
                    uni.values.setdefault(prefix + name, value)
                    value += inc
                elif what == "music_const":
                    # DEF \1 EQUS "((\2 - SFX_Headers_1) / 3)" — the constant
                    # expands to an expression naming an AUDIO LABEL, which is
                    # why scripts referencing MUSIC_* also reference Music_*.
                    uni.constants.add(name)
                else:  # toggle_consts_for
                    uni.constants.update({f"TOGGLEMAP{name}_ID",
                                          f"TOGGLEMAP{name}_NAME"})
                continue


def _expand_interp(text: str, n: int) -> str:
    """Apply rgbasm's `{d:n}` / `{02d:n}` interpolation for one loop index."""
    def sub(m):
        spec = m.group(1)
        if spec.startswith("0"):
            width = int(spec[1:-1] or 0)
            return f"{n:0{width}d}"
        return str(n)
    return re.sub(r"\{(0?\d*d):n\}", sub, text)


def _scan_ram(root: Path, uni: Universe) -> None:
    for p in sorted((root / "ram").glob("*.asm")):
        lines = p.read_text(encoding="utf-8").splitlines()
        i = 0
        while i < len(lines):
            raw = lines[i].split(";")[0]
            m = re.match(r"^FOR\s+n\s*,\s*(.+)$", raw.strip(), re.I)
            if m:
                args = [a.strip() for a in m.group(1).split(",")]
                if len(args) == 1:
                    lo_v, hi_v = 0, _eval(args[0], uni.values)
                else:
                    lo_v, hi_v = _eval(args[0], uni.values), _eval(args[1], uni.values)
                body = []
                j = i + 1
                depth = 1
                while j < len(lines):
                    s = lines[j].split(";")[0].strip()
                    if re.match(r"^FOR\b", s, re.I):
                        depth += 1
                    if re.match(r"^ENDR\b", s, re.I):
                        depth -= 1
                        if depth == 0:
                            break
                    body.append(lines[j])
                    j += 1
                over = lo_v is None or hi_v is None
                rng = range(0, 64) if over else range(int(lo_v), int(hi_v))
                for n in rng:
                    for b in body:
                        for name in _ram_names(_expand_interp(b, n), uni):
                            if over:
                                uni.over_generated.add(name)
                i = j + 1
                continue
            _ram_names(raw, uni)
            i += 1


def _ram_names(raw: str, uni: Universe) -> list:
    """Record every RAM label a line defines, including struct-macro fields."""
    out = []
    m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)::?\s*(.*)$", raw.rstrip())
    if not m:
        return out
    base = m.group(1)
    uni.ram.add(base)
    out.append(base)
    rest = m.group(2).split(";")[0].strip()
    if rest:
        macro = rest.split(None, 1)[0]
        fields = STRUCT_FIELDS.get(macro)
        if fields:
            for suffix in fields:
                uni.ram.add(base + suffix)
                out.append(base + suffix)
    return out


def _scan_map_object_ids(root: Path, uni: Universe) -> None:
    """Per-map object ids (`OAKSLAB_RIVAL`, `BILLSHOUSE_BILL1`).

    These are `const_export`s under an `object_const_def` in
    `data/maps/objects/*.asm`, one enumeration per file starting at 1 — map
    DATA, not `constants/`. They need VALUES, not just names: scripts pass them
    to HideObject/ShowObject, and the port has no symbol of that name, so the
    emitter has to write the number.
    """
    _scan_constants(sorted((root / "data" / "maps" / "objects").glob("*.asm")), uni)
    # Any other const_export in data/ — names only; none is referenced by value.
    for p in sorted((root / "data").rglob("*.asm")):
        try:
            text = p.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            continue
        for m in re.finditer(r"^\s*const_export\s+([A-Za-z_][A-Za-z0-9_]*)", text, re.M):
            uni.constants.add(m.group(1))


def _scan_labels(root: Path, uni: Universe) -> None:
    """Column-0 labels across pret's code and data.

    Needed because a script can name a label it never calls:
    `ld c, BANK(Music_MeetJessieJames)` references an AUDIO label purely to ask
    which bank it lives in. That is also why every `MUSIC_*` reference drags a
    `Music_*` reference along with it — `music_const` defines the constant as an
    EQUS expression over the label.
    """
    for d in LABEL_DIRS:
        base = root / d
        if not base.is_dir():
            continue
        for p in base.rglob("*.asm"):
            try:
                text = p.read_text(encoding="utf-8")
            except (OSError, UnicodeDecodeError):
                continue
            for m in re.finditer(r"^([A-Za-z_][A-Za-z0-9_]*)::?", text, re.M):
                uni.labels.add(m.group(1))


def build(root: Path) -> Universe:
    uni = Universe()
    # Order matters: constants first, since the FOR bounds in ram/ are named
    # constants and the struct expansion needs them evaluated.
    const_paths = sorted(p for p in (root / "constants").iterdir() if p.is_file())
    _scan_constants(const_paths, uni)
    _scan_ram(root, uni)
    _scan_map_object_ids(root, uni)
    _scan_labels(root, uni)
    return uni
