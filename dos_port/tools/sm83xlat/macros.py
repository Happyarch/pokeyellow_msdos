#!/usr/bin/env python3
"""macros.py — classification table for every rgbasm macro pret's `scripts/` uses.

A macro is not a line of code; it is a promise about several lines of code. The
dataflow that decides whether a `jr z` still reads the flag it was written for
has to know what each macro EXPANDED to — which registers it clobbered, which
flags it wrote — or it reasons about a corpus with holes in it. So every macro
name that occurs in `scripts/` gets a row here stating its class and its
declared effects, and a name with no row is a bail (`unknown-macro`), never a
pass-through.

The measured universe is 84 distinct leading tokens across 251 files, of which
23 are SM83 mnemonics (see isa.py) and the rest are here.

TWO FACTS THAT SHAPE THE TABLE
------------------------------
1. **The event macros carry assembly-time state.** `CheckEventReuseHL` emits its
   `ld hl` only `IF event_byte != ((\\1) / 8)` — where `event_byte` is a DEF set
   by whichever event macro ran last, in source order, across the whole file.
   The expansion of one line therefore depends on a line above it. Rows for the
   Reuse* family record `state_dependent=True` so the IR stage has to resolve
   `event_byte` rather than assume a fixed expansion.

2. **`text_asm` is the seam, not an instruction.** It emits one byte (TX_START_ASM)
   into a text stream and everything after it, up to the next label, is SM83
   code the text engine calls. The parser uses it to switch modes; it is the
   reason a "text pointer table" file also contains 13,306 imperative lines.

Effect columns mirror isa.Effect: "-" unaffected, "0" reset, "1" set,
"*" computed. `clobbers` names registers whose value the expansion destroys.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Dict, Optional, Tuple

# Macro classes.
DATA_TEXT = "data-text"          # bytes in a text-command stream (Tier-1 data)
DATA_TABLE = "data-table"        # pointer/table data (dw_const, trainer, ...)
DATA_BYTES = "data-bytes"        # raw db/dw — needs content classification
CODE_EVENT = "code-event"        # expands to SM83 touching wEventFlags
CODE_CALL = "code-call"          # expands to a call/jump (predef, farcall, ...)
CODE_COORD = "code-coord"        # screen-coordinate load — always a bail
CODE_MISC = "code-misc"          # other code-emitting macro
CONTROL = "control"              # assembler control that emits nothing
TEXT_MARKER = "text-marker"      # text_asm: the data -> code seam


@dataclass(frozen=True)
class MacroInfo:
    name: str
    cls: str
    z: str = "-"
    n: str = "-"
    h: str = "-"
    c: str = "-"
    clobbers: Tuple[str, ...] = ()
    #: True when the expansion depends on assembly-time state carried from an
    #: earlier line (the `event_byte` DEF).
    state_dependent: bool = False
    #: Set when this macro can never be lowered by rule; the value is the
    #: reason code the probe reports.
    always_bail: Optional[str] = None
    #: Arg counts this row covers. None means "any".
    argc: Optional[Tuple[int, ...]] = None
    note: str = ""

    @property
    def flag_transparent(self) -> bool:
        return self.z == "-" and self.n == "-" and self.h == "-" and self.c == "-"


_T: Dict[str, list] = {}


def _m(name: str, cls: str, **kw) -> None:
    _T.setdefault(name, []).append(MacroInfo(name, cls, **kw))


# ---------------------------------------------------------------------------
# Text-stream data. The transpiler emits POINTERS and IDs for these and needs no
# charmap knowledge — pret already keeps the glyphs in text/, which holds zero
# instructions. See the plan's "The Tier boundary is pret's own".
# ---------------------------------------------------------------------------
for _n in ("text_far", "text_end", "text_waitbutton", "text_promptbutton",
           "text_start", "text_low", "text_pause", "text_scroll",
           "text_ram", "text_bcd", "text_move", "text_box", "text_dots",
           "text_decimal", "text", "line", "para", "cont", "next", "done",
           "prompt", "page", "dex"):
    _m(_n, DATA_TEXT)

# Sound commands inside a text stream — one byte each, no operands.
for _n in ("sound_get_item_1", "sound_get_item_2", "sound_get_key_item",
           "sound_level_up", "sound_pokedex_rating", "sound_caught_mon",
           "sound_dex_page_added", "sound_cry_pikachu", "sound_cry_pidgeot",
           "sound_cry_dewgong", "sound_get_item_1_duplicate"):
    _m(_n, DATA_TEXT)

# Text-script IDs: a single byte that hands the whole box to a named engine
# routine. Data here, but each one names a port routine that must exist.
for _n in ("script_pokecenter_nurse", "script_mart", "script_bills_pc",
           "script_players_pc", "script_pokecenter_pc", "script_prize_vendor",
           "script_cable_club_receptionist", "script_vending_machine"):
    _m(_n, DATA_TEXT)

_m("text_asm", TEXT_MARKER, note="TX_START_ASM: everything after this is code")

# Pikachu cry/emotion id loads. These are CODE, not stream bytes:
# `ldpikaemotion e, PikachuEmotion27` is `ld e, (X_id - Table) / 2`. They are
# flag-transparent, and BillsHouse_2 exploits exactly that — three of them sit
# between a `cp` and the `ret z` that reads its ZF. Classifying them as data
# would have put a data item in the middle of a live flag chain.
_m("ldpikacry", CODE_MISC, note="ld <reg>, cry index — flag-transparent")
_m("ldpikaemotion", CODE_MISC, note="ld <reg>, emotion index — flag-transparent")

# ---------------------------------------------------------------------------
# Table data.
# ---------------------------------------------------------------------------
_m("def_text_pointers", DATA_TABLE)
_m("def_script_pointers", DATA_TABLE)
_m("def_trainers", DATA_TABLE)
_m("dw_const", DATA_TABLE)
_m("trainer", DATA_TABLE, note="5 slots: bit, range, before, after, end x2")
_m("dbmapcoord", DATA_TABLE,
   note="db y,x — a MAP coordinate, identical on both sides, needs NO projection")
_m("map_coord_movement", DATA_TABLE, note="dbmapcoord + dw movement data")
_m("db", DATA_BYTES, note="content-classified: a quoted run is Tier-1 text")
_m("dw", DATA_BYTES)
_m("dn", DATA_BYTES)
_m("dab", DATA_BYTES)

# ---------------------------------------------------------------------------
# Screen coordinates — the 16-site bail list. The port's tilemap stride is
# context-dependent (global SCREEN_WIDTH=40 vs text.asm's stride-20 vs the
# runtime text_row_stride), so any rule here would be a guess dressed as a
# lowering. 16 lines in 5 files: GameCorner x8, BikeShop x3, CeladonMartRoof x2,
# VermilionDock x3.
# ---------------------------------------------------------------------------
for _n in ("hlcoord", "bccoord", "decoord", "coord",
           "hlbgcoord", "bcbgcoord", "debgcoord", "bgcoord",
           "hlowcoord", "bcowcoord", "deowcoord", "owcoord",
           "dwcoord", "ldcoord_a", "lda_coord"):
    _m(_n, CODE_COORD, clobbers=("hl",), always_bail="screen-coord-projection")

# ---------------------------------------------------------------------------
# Banking / dispatch macros. Each expands to a call, so each inherits the
# callee-ABI question rather than escaping it.
# ---------------------------------------------------------------------------
_m("farcall", CODE_CALL, clobbers=("a", "b", "hl"),
   note="ld b,BANK / ld hl,\\1 / call Bankswitch")
_m("callfar", CODE_CALL, clobbers=("a", "b", "hl"),
   note="ld hl,\\1 / ld b,BANK / call Bankswitch — same effect, opposite order")
_m("farjp", CODE_CALL, clobbers=("a", "b", "hl"))
_m("jpfar", CODE_CALL, clobbers=("a", "b", "hl"))
_m("predef", CODE_CALL, clobbers=("a",),
   note="ld a,id / call Predef — pret leaves the predef id in A")
_m("predef_jump", CODE_CALL, clobbers=("a",))
_m("predef_id", CODE_CALL, clobbers=("a",))
_m("tx_pre", CODE_CALL, clobbers=("a",))
_m("tx_pre_jump", CODE_CALL, clobbers=("a",))

_m("lb", CODE_MISC, clobbers=("bc",),
   note="lb bc,hi,lo -> one 16-bit load; the port writes mov bx,(hi<<8)|lo")

# ---------------------------------------------------------------------------
# Event macros. Flags and clobbers below are read off macros/scripts/events.asm.
#
# The single most important row is SetEvent/ResetEvent being FLAG-TRANSPARENT
# while CheckEvent WRITES Z: pret leans on both properties, and the port's
# events.inc macros must preserve them or every event-gated branch in 251 files
# is subtly wrong at once.
# ---------------------------------------------------------------------------
_m("CheckEvent", CODE_EVENT, z="*", n="0", h="1", clobbers=("a",), argc=(1,),
   note="ld a,[wEventFlags+n] / bit b,a — preserves C")
_m("CheckEvent", CODE_EVENT, z="*", n="*", h="*", c="*", clobbers=("a",), argc=(2,),
   always_bail="checkevent-carry-form",
   note="2-arg form returns the bit in CARRY via rrca/add a. 3 sites; the "
        "port's events.inc CheckEvent is 1-arg only, so this cannot pass through")
_m("CheckEventReuseA", CODE_EVENT, z="*", n="0", h="1", clobbers=("a",),
   state_dependent=True)
_m("CheckEventAfterBranchReuseA", CODE_EVENT, z="*", n="0", h="1", clobbers=("a",),
   state_dependent=True)
_m("CheckEventHL", CODE_EVENT, z="*", n="0", h="1", clobbers=("hl",))
_m("CheckEventReuseHL", CODE_EVENT, z="*", n="0", h="1", clobbers=("hl",),
   state_dependent=True)
_m("CheckEventForceReuseHL", CODE_EVENT, z="*", n="0", h="1")
_m("CheckEventAfterBranchReuseHL", CODE_EVENT, z="*", n="0", h="1", clobbers=("hl",),
   state_dependent=True)
_m("CheckAndSetEvent", CODE_EVENT, z="*", n="0", h="1", clobbers=("hl",))
_m("CheckAndResetEvent", CODE_EVENT, z="*", n="0", h="1", clobbers=("hl",))
_m("CheckAndSetEventReuseHL", CODE_EVENT, z="*", n="0", h="1", clobbers=("hl",),
   state_dependent=True)
_m("CheckAndResetEventReuseHL", CODE_EVENT, z="*", n="0", h="1", clobbers=("hl",),
   state_dependent=True)
_m("CheckAndSetEventA", CODE_EVENT, z="*", n="0", h="1", clobbers=("a",))
_m("CheckAndResetEventA", CODE_EVENT, z="*", n="0", h="1", clobbers=("a",))
# Counter-intuitive on purpose, and pret says so in a comment: these set Z when
# the events ARE set, the opposite polarity to every other Check*.
_m("CheckBothEventsSet", CODE_EVENT, z="*", n="1", h="*", c="*", clobbers=("a",),
   argc=(2,),
   note="and + cp: Z SET when both events are set — inverse of CheckEvent")
_m("CheckEitherEventSet", CODE_EVENT, z="*", n="0", h="1", c="0", clobbers=("a",),
   argc=(2,))
# THIS TABLE DESCRIBES PRET, NOT THE PORT. The 3-arg forms are valid rgbasm —
# the third argument is a "try to reuse a" hint that changes whether the macro
# re-loads wEventFlags — so they get a row and PARSE cleanly. What they do not
# have is a port counterpart: events.inc defines the 2-arg macros only, and
# silently truncating to those would re-load A where pret deliberately did not.
# So the row exists and carries an always_bail: recognised, and refused.
_m("CheckBothEventsSet", CODE_EVENT, z="*", n="1", h="*", c="*", clobbers=("a",),
   argc=(3,), always_bail="event-macro-reuse-a-hint")
_m("CheckEitherEventSet", CODE_EVENT, z="*", n="0", h="1", c="0", clobbers=("a",),
   argc=(3,), always_bail="event-macro-reuse-a-hint")
_m("CheckEitherEventSetReuseA", CODE_EVENT, z="*", n="0", h="1", c="0",
   clobbers=("a",), state_dependent=True)

_m("SetEvent", CODE_EVENT, clobbers=("hl",), note="ld hl / set b,[hl] — NO flags")
_m("SetEventReuseHL", CODE_EVENT, clobbers=("hl",), state_dependent=True)
_m("SetEventForceReuseHL", CODE_EVENT)
_m("SetEventAfterBranchReuseHL", CODE_EVENT, clobbers=("hl",), state_dependent=True)
_m("SetEvents", CODE_EVENT, clobbers=("hl",))
_m("ResetEvent", CODE_EVENT, clobbers=("hl",))
_m("ResetEventReuseHL", CODE_EVENT, clobbers=("hl",), state_dependent=True)
_m("ResetEventForceReuseHL", CODE_EVENT)
_m("ResetEventAfterBranchReuseHL", CODE_EVENT, clobbers=("hl",), state_dependent=True)
_m("ResetEvents", CODE_EVENT, clobbers=("hl",))
# The Range forms expand to a variable-length run of ld/or/and driven by
# assembly-time arithmetic on the two event indices. Modelling them means
# reimplementing the macro; 9 sites total, so they are hand-work by design.
_m("SetEventRange", CODE_EVENT, z="*", n="0", h="*", c="0", clobbers=("a", "hl"),
   always_bail="event-range-macro")
_m("ResetEventRange", CODE_EVENT, z="*", n="0", h="*", c="0", clobbers=("a", "hl"),
   always_bail="event-range-macro")
_m("EventFlagAddress", CODE_EVENT, note="ld <reg>, wEventFlags+n — no flags")
_m("EventFlagAddressA", CODE_EVENT)
_m("AEventFlagAddress", CODE_EVENT, clobbers=("a",))
_m("EventFlagBit", CODE_EVENT, note="ld <reg>, bit index — no flags")
_m("AdjustEventBit", CODE_EVENT, z="*", n="0", h="*", c="*", clobbers=("a",))

# ---------------------------------------------------------------------------
# Assembler control that emits no bytes.
# ---------------------------------------------------------------------------
for _n in ("EXPORT", "ASSERT", "const_def", "const", "const_next", "const_skip",
           "table_width", "assert_table_length", "vc_patch", "vc_patch_end",
           "vc_hook", "vc_assert", "DEF", "REDEF", "PURGE", "OPT"):
    _m(_n, CONTROL)


def lookup(name: str, argc: int) -> Optional[MacroInfo]:
    """Find the row for `name` at this argument count, or None (-> unknown-macro)."""
    rows = _T.get(name)
    if rows is None:
        return None
    for r in rows:
        if r.argc is None or argc in r.argc:
            return r
    # A known macro used at an argument count no row covers is exactly as
    # unknown as an unknown macro — its expansion is a different program.
    return None


def known(name: str) -> bool:
    return name in _T


CODE_CLASSES = {CODE_EVENT, CODE_CALL, CODE_COORD, CODE_MISC}
DATA_CLASSES = {DATA_TEXT, DATA_TABLE, DATA_BYTES}
