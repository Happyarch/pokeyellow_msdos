#!/usr/bin/env python3
"""Stage 0 acceptance + the lexer/ISA axioms it rests on.

Stage 0's acceptance is *zero parse errors over all 251 files*, so the headline
test is exactly that. The rest pin the axioms a wrong row in would corrupt every
one of the 251 files at once — which is the whole reason the tables are
enumerated by hand rather than derived.

Run:  python3 -m pytest dos_port/tools/sm83xlat/tests/ -q
"""
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
TOOL = HERE.parent
ROOT = TOOL.parents[2]
sys.path.insert(0, str(TOOL))

import isa          # noqa: E402
import lexer        # noqa: E402
import macros       # noqa: E402
import parser as sparser  # noqa: E402
import probe        # noqa: E402
import pretsyms     # noqa: E402


# --------------------------------------------------------------------------
# Stage 0 acceptance
# --------------------------------------------------------------------------

def test_every_script_parses():
    """Zero parse errors across the corpus. A parse failure is a tool bug."""
    files = sparser.parse_corpus(ROOT)
    assert len(files) == 251


def test_no_item_is_unclassified():
    """Every ITEM resolves to an ISA row or a macro row.

    An unclassified item would be counted as imperative-and-bailed, which keeps
    the histogram honest — but it would also mean the tool does not know what
    the line says, and the histogram is supposed to be a work queue, not a work
    queue with an unmeasured hole in it.
    """
    unknown = [(it.where, it.line.raw.strip(), it.reason)
               for f in sparser.parse_corpus(ROOT) for it in f.items
               if it.kind == sparser.KIND_UNKNOWN]
    assert unknown == []


def test_branch_count_decomposes():
    """913 active conditional branches + 7 dead ones = the 920 measured.

    Stated as a decomposition rather than a total on purpose: an aggregate that
    lands where expected is not evidence until you say what it is made of.
    """
    files = sparser.parse_corpus(ROOT)
    active = dead = 0
    for f in files:
        for it in f.items:
            if it.kind == sparser.KIND_INSN and it.decoded and it.decoded.condition:
                if it.active:
                    active += 1
                else:
                    dead += 1
    assert (active, dead) == (913, 7)
    assert active + dead == 920


# --------------------------------------------------------------------------
# Lexer axioms
# --------------------------------------------------------------------------

def test_label_without_colon():
    """`.BagFull` has no colon in CeruleanGym.asm. Requiring one loses branch targets."""
    ln = lexer.lex_line("x.asm", 1, ".BagFull")
    assert ln.kind == lexer.LABEL and ln.local and ln.label == ".BagFull"
    ln = lexer.lex_line("x.asm", 1, "CeruleanGymReceiveTM11:")
    assert ln.kind == lexer.LABEL and not ln.local
    ln = lexer.lex_line("x.asm", 1, "PalletTown_h::")
    assert ln.kind == lexer.LABEL and ln.exported


def test_semicolon_inside_a_string_is_not_a_comment():
    code, comment = lexer.split_comment('\tdb "A;B@" ; real comment')
    assert '"A;B@"' in code
    assert comment.strip() == "real comment"


def test_operand_split_respects_brackets_and_parens():
    assert lexer.split_operands("a, [wEventFlags + event_byte]") == \
        ["a", "[wEventFlags + event_byte]"]
    assert lexer.split_operands("EVENT_X, (1 << BIT_A) | 2, Foo") == \
        ["EVENT_X", "(1 << BIT_A) | 2", "Foo"]


def test_column_zero_directive_is_not_a_label():
    ln = lexer.lex_line("x.asm", 1, "IF DEF(_DEBUG)")
    assert ln.kind == lexer.DIRECTIVE and ln.head == "IF"


# --------------------------------------------------------------------------
# Conditional assembly: the port builds neither _DEBUG nor _YELLOW_VC
# --------------------------------------------------------------------------

def test_debug_bodies_are_parsed_but_inactive():
    f = sparser.parse_file(ROOT / "scripts" / "CeruleanCity.asm", ROOT)
    dead = [i for i in f.items if not i.active]
    assert dead, "the IF DEF(_DEBUG) body should be parsed and marked inactive"
    assert any("DebugPressedOrHeldB" in i.line.raw for i in dead)


def test_yellow_vc_takes_the_else_branch():
    """SummerBeachHouse bits a DIFFERENT flag under _YELLOW_VC. The port is not VC."""
    f = sparser.parse_file(ROOT / "scripts" / "SummerBeachHouse.asm", ROOT)
    live = [i.line.raw for i in f.items if i.active]
    dead = [i.line.raw for i in f.items if not i.active]
    assert any("BIT_PIKACHU_SPAWN_SURFING" in s for s in live)
    assert any("BIT_PIKACHU_SPAWN_STARTER" in s for s in dead)


# --------------------------------------------------------------------------
# ISA axioms — the rows a mistake in would be wrong across all 251 files
# --------------------------------------------------------------------------

def test_res_and_set_write_no_flags():
    """The CeruleanGym_Script hazard in one assertion.

    `bit` sets Z, `res` leaves it, and `call nz` two lines later still reads the
    `bit`. If `res` ever reads as a flag writer here, the lowering is free to
    emit `and byte [...], ~MASK` and the branch fires on garbage.
    """
    assert isa.decode("res", ["BIT_CUR_MAP_LOADED_2", "[hl]"]).effect.flag_transparent
    assert isa.decode("set", ["0", "[hl]"]).effect.flag_transparent
    assert isa.decode("ld", ["a", "[wFoo]"]).effect.flag_transparent


def test_bit_writes_z_but_preserves_c():
    """x86 `test` CLEARS CF; SM83 `bit` leaves it. One of three asymmetric cases."""
    eff = isa.decode("bit", ["3", "a"]).effect
    assert eff.writes_z and not eff.writes_c


def test_sixteen_bit_add_leaves_z_alone():
    """`add hl, de` writes no Z. x86 `add esi, edx` does — a silent branch break."""
    eff = isa.decode("add", ["hl", "de"]).effect
    assert not eff.writes_z and eff.writes_c


def test_inc_dec_preserve_carry():
    assert not isa.decode("inc", ["a"]).effect.writes_c
    assert not isa.decode("dec", ["a"]).effect.writes_c
    assert isa.decode("inc", ["a"]).effect.writes_z


def test_pop_af_restores_every_flag():
    """The one stack form that is a flag WRITER."""
    assert not isa.decode("pop", ["hl"]).effect.writes_z
    assert isa.decode("pop", ["af"]).effect.writes_z
    assert isa.decode("pop", ["af"]).effect.writes_c


def test_condition_code_c_is_not_register_c():
    assert isa.decode("jr", ["c", ".foo"]).condition == "c"
    assert isa.decode("ret", ["c"]).condition == "c"
    assert isa.decode("cp", ["c"]).condition is None


def test_unknown_shape_returns_none_rather_than_approximating():
    assert isa.decode("ld", ["sp", "hl"]) is None
    assert isa.decode("rst", ["$38"]) is None


# --------------------------------------------------------------------------
# Macro table
# --------------------------------------------------------------------------

def test_setevent_is_flag_transparent_and_checkevent_is_not():
    assert macros.lookup("SetEvent", 1).flag_transparent
    assert not macros.lookup("CheckEvent", 1).flag_transparent


def test_checkevent_two_arg_form_is_a_different_program():
    """The carry-returning form. The port's events.inc CheckEvent is 1-arg only."""
    assert macros.lookup("CheckEvent", 2).always_bail == "checkevent-carry-form"


def test_screen_coord_macros_always_bail():
    for name in ("hlcoord", "hlbgcoord", "hlowcoord"):
        assert macros.lookup(name, 2).always_bail == "screen-coord-projection"


def test_ldpikaemotion_is_code_and_flag_transparent():
    """BillsHouse_2 puts three of these between a `cp` and the `ret z` reading it."""
    info = macros.lookup("ldpikaemotion", 2)
    assert info.cls in macros.CODE_CLASSES and info.flag_transparent


def test_unknown_macro_is_not_a_pass_through():
    assert macros.lookup("NoSuchMacro", 1) is None


# --------------------------------------------------------------------------
# Symbol universe
# --------------------------------------------------------------------------

def test_the_three_easily_missed_definition_mechanisms():
    uni = pretsyms.build(ROOT)
    # 1. constants/hardware.inc — a .inc, lower-case `def X equ`
    assert "PAD_CTRL_PAD" in uni.constants
    # 2. macro-generated RAM struct fields
    assert "wSpritePlayerStateData1FacingDirection" in uni.ram
    assert "wSpritePlayerStateData2MovementByte1" in uni.ram
    # 3. per-map object ids via const_export in data/maps/objects/
    assert "OAKSLAB_RIVAL" in uni.constants
    # plus the derived-constant macros
    assert "OPP_RIVAL1" in uni.constants
    assert "ROUTE_7" in uni.constants and "ROUTE_7_WIDTH" in uni.constants
    assert "TM_DIG" in uni.constants
    assert "MON_MAXHP" in uni.constants


def test_for_loop_bounds_are_evaluated_not_over_generated():
    """Over-generation would let a typo resolve. The bounds must actually evaluate."""
    uni = pretsyms.build(ROOT)
    assert uni.over_generated == set()
    assert "wPartyMon1Species" in uni.ram
    assert "wSprite01StateData1FacingDirection" in uni.ram


def test_every_script_symbol_resolves():
    """Stage 1's acceptance is >=95%. Measured at Stage 0 it is already 100%."""
    res = probe.probe(ROOT, ROOT / "dos_port")
    assert dict(res.unresolved_symbols) == {}


# --------------------------------------------------------------------------
# Two measured corrections to the plan's figures. Pinned as tests so a later
# change that silently restores the old numbers fails here rather than being
# rediscovered by hand.
# --------------------------------------------------------------------------

def test_projection_surface_is_eighteen_lines_not_sixteen():
    """The plan says 16 sites in 5 files. There are 18, in the same 5 files.

    The two extra are `ld bc, SCREEN_WIDTH * 2` (CeladonMartRoof) and
    `ld bc, SCREEN_WIDTH * 6` (VermilionDock) — row-stride advances written as
    arithmetic rather than through a coord macro, each one line after an
    `hlcoord` in a file already on the bail list. The port's stride is not
    pret's, so they are exactly as unlowerable as the macro sites; counting the
    macro rather than the geometry is what hid them.
    """
    res = probe.probe(ROOT, ROOT / "dos_port")
    assert res.histogram[probe.R_SCREEN_COORD] == 16
    assert res.histogram[probe.R_SCREEN_STRIDE] == 2


def test_inline_glyph_runs_are_twentynine_sites_in_eleven_files():
    """The plan names CeruleanGym's two. The real set is 29 across 11 files.

    8 gyms x (city name + leader name) = 16, Route23's 7 badge names,
    GameCorner's 4 currency labels, BikeShop's 2.

    Every one must be routed into a generator. Emitting them as `db` bytes would
    commit the port's most-repeated Tier-1 violation 29 times in one commit.
    """
    res = probe.probe(ROOT, ROOT / "dos_port")
    files = {s.where.split(":")[0] for s in res.inline_text_sites}
    assert len(res.inline_text_sites) == 29
    assert len(files) == 11


if __name__ == "__main__":
    import pytest
    raise SystemExit(pytest.main([__file__, "-q"]))
