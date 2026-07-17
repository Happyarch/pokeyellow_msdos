#!/usr/bin/env python3
"""Tests for the label-DB build graph (label-DB reachability plan, Verification).

    python3 dos_port/tools/test_label_db.py                 # everything
    python3 dos_port/tools/test_label_db.py Boundaries      # one fixture class

FIXTURES ARE THE GATE; THE LIVE TREE IS CORROBORATION. The risk this guards is
shipping a graph that is BIGGER rather than RIGHTER, so the deterministic
fixtures pin each rule (V1) and each refusal (V3), and the live-tree checks
(V2/V4) only corroborate direction.

Port-only debug labels are invisible to project_state's user-facing report
(WHERE l.pret_file IS NOT NULL), so these inspect the graph helpers directly.
"""

import importlib.machinery
import importlib.util
import os
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)


def _load(name, path):
    loader = importlib.machinery.SourceFileLoader(name, path)
    spec = importlib.util.spec_from_loader(name, loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


uld = _load('uld', os.path.join(HERE, 'update_label_db'))
import buildprobe  # noqa: E402

_LIVE = {}


def live():
    """One shared scan of the live default config (the slow part)."""
    if not _LIVE:
        cfg = buildprobe.probe()
        fallthrough, active = uld.scan_build_graph(cfg)
        _defs, calls, _ext = uld.scan_port(set())
        edges = [(c, e) for c, e, _k, f, ln in calls
                 if f in active and ln in active[f]]
        edges += [(e[0], e[1]) for e in fallthrough]
        graph = {}
        for caller, callee in edges:
            graph.setdefault(caller, set()).add(callee)
        reached, pending = set(), ['start']
        while pending:
            node = pending.pop()
            if node in reached:
                continue
            reached.add(node)
            pending.extend(graph.get(node, ()))
        _LIVE.update(cfg=cfg, fallthrough=fallthrough, active=active,
                     calls=calls, graph=graph, reached=reached)
    return _LIVE


class Base(unittest.TestCase):
    """Classify fixture sources with the repo roots pointed at a temp dir, so
    %include resolution exercises the real -I search order and the real
    repository-containment guard."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = self.tmp.name
        self.repo_root, self.dos_port = uld.REPO_ROOT, uld.DOS_PORT
        uld.REPO_ROOT = uld.DOS_PORT = self.dir
        self.addCleanup(self._restore)

    def _restore(self):
        uld.REPO_ROOT, uld.DOS_PORT = self.repo_root, self.dos_port
        self.tmp.cleanup()

    def write(self, name, text):
        path = os.path.join(self.dir, name)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'w', encoding='utf-8') as fh:
            fh.write(text)
        return path

    def classify(self, text, defines=None, macros=None, includes=('.',),
                 name='t.asm'):
        path = self.write(name, text)
        return uld.classify_file(path, name, dict(defines or {}),
                                 macros or uld.MacroRegistry({}), includes)

    def edges(self, text, **kw):
        macros = kw.pop('macros', None) or uld.MacroRegistry({})
        dos_exit = kw.pop('dos_exit', set())
        cf = self.classify(text, macros=macros, **kw)
        return uld.boundary_edges(cf, macros, dos_exit)

    def names(self, cf):
        return [t.name for t in cf.tokens if t.kind == 'label']


class Conditionals(Base):
    """S3 — conditional grammar and per-file define state."""

    def test_nested_if_elif_else(self):
        cf = self.classify("""
%if 1
%if 0
A:
    nop
%elif 2 > 1
B:
    ret
%else
C:
    ret
%endif
%endif
""")
        self.assertEqual(self.names(cf), ['B'])

    def test_elifdef_elifndef(self):
        src = """
%ifdef X
A:
    ret
%elifdef Y
B:
    ret
%elifndef Z
C:
    ret
%else
D:
    ret
%endif
"""
        self.assertEqual(self.names(self.classify(src, {'Y': '1'})), ['B'])
        self.assertEqual(self.names(self.classify(src, {})), ['C'])
        self.assertEqual(self.names(self.classify(src, {'Z': '1'})), ['D'])

    def test_inactive_label_occurrences_are_not_entries(self):
        # Definitions stay config-independent source facts (scan_port); the
        # GRAPH must not see a label the build never assembles.
        cf = self.classify("""
%ifdef DEBUG_OAK_INTRO
RunOakIntroTest:
    ret
%endif
Real:
    ret
""")
        self.assertEqual(self.names(cf), ['Real'])

    def test_duplicate_names_in_exclusive_branches(self):
        # debug_dump.asm defines `windows:` repeatedly in exclusive arms; a
        # name-keyed map would overwrite one occurrence with another.
        cf = self.classify("""
%ifdef A
windows:
    db 1
%else
windows:
    db 2
%endif
""", {'A': '1'})
        self.assertEqual([(t.name, t.line) for t in cf.tokens
                          if t.kind == 'label'], [('windows', 3)])

    def test_define_undef_only_in_active_branches(self):
        cf = self.classify("""
%ifdef NOPE
%define GHOST 1
%endif
%ifdef GHOST
Ghost:
    ret
%endif
%define REAL 1
%ifdef REAL
Real:
    ret
%endif
%undef REAL
%ifdef REAL
Zombie:
    ret
%endif
""")
        self.assertEqual(self.names(cf), ['Real'])

    def test_ifndef_define_constant_guard_is_per_file(self):
        # perf.asm:38-45 feeding :181 — each .asm is its own nasm invocation.
        src = """
%ifndef GUARD
%define GUARD 7
%endif
%if GUARD == 7
Ok:
    ret
%endif
"""
        self.assertEqual(self.names(self.classify(src)), ['Ok'])
        # a seeded define wins, and the guard must not clobber it
        self.assertEqual(self.names(self.classify(src, {'GUARD': '9'})), [])

    def test_valueless_define_is_truthy(self):
        cf = self.classify("""
%if SEEDED
Ok:
    ret
%endif
""", {'SEEDED': '1'})
        self.assertEqual(self.names(cf), ['Ok'])

    def test_same_line_local_label_instruction(self):
        # 31 in-tree `.done: clc` forms. The instruction must not be lost, or
        # the tail — and so the boundary — is decided by the wrong token.
        cf = self.classify("""
A:
    call Foo
.done: ret
""")
        self.assertEqual([t.text for t in cf.tokens if t.kind == 'instr'],
                         ['call Foo', 'ret'])

    def test_backslash_continuation(self):
        # debug_dump.asm:257's shape. The continued fragment must be joined,
        # not lexed as a free-standing instruction token — that would put a
        # bogus token at a boundary and decide the tail with it.
        cf = self.classify("""
BATTLEMON_STRUCT_LENGTH equ 1 + 2 + 1 \\
                            + 2 * NUM_STATS
A:
    ret
""")
        self.assertEqual([t.text for t in cf.tokens if t.kind == 'instr'], ['ret'])
        self.assertEqual(self.names(cf), ['A'])

    def test_arithmetic_is_not_evaluated_and_so_is_unknown(self):
        # The grammar is deliberately small: literals, one comparison, bare
        # truthiness. Arithmetic is UNKNOWN, and unknown guarding content is a
        # refusal — never a guessed arm.
        with self.assertRaises(uld.ScanError):
            self.classify('LEN equ 1 + 2\n%if LEN == 3\nA:\n    ret\n%endif\n')


class Includes(Base):
    """S3 — includes processed IN PLACE, for conditional state only."""

    def test_mutually_exclusive_elifdef_arms(self):
        # The scenario_registry.inc shape: last-textual-wins would break it.
        self.write('inc/reg.inc', """
%ifdef DEBUG_A
SCENARIO equ 14
%elifdef DEBUG_B
SCENARIO equ 16
%else
SCENARIO equ 0
%endif
""")
        src = """
%include "reg.inc"
%if SCENARIO == 16
Ok:
    ret
%endif
%if SCENARIO == 14
Wrong:
    ret
%endif
"""
        cf = self.classify(src, {'DEBUG_B': '1'}, includes=('inc/', '.'))
        self.assertEqual(self.names(cf), ['Ok'])

    def test_include_resolved_through_ordered_search_paths(self):
        self.write('inc/x.inc', '%define FROM_INCLUDE 1\n')
        cf = self.classify("""
%include "x.inc"
%ifdef FROM_INCLUDE
Ok:
    ret
%endif
""", includes=('include/', 'inc/', '.'))
        self.assertEqual(self.names(cf), ['Ok'])

    def test_include_body_is_not_graph_content(self):
        self.write('inc/x.inc', 'Hidden:\n    ret\n')
        cf = self.classify('%include "x.inc"\nReal:\n    ret\n',
                           includes=('inc/', '.'))
        self.assertEqual(self.names(cf), ['Real'])

    def test_include_lines_do_not_alias_this_files_active_lines(self):
        self.write('inc/x.inc', '\n\n\n\n\n%define K 1\n')
        cf = self.classify('%include "x.inc"\n%ifdef NOPE\n    call Ghost\n%endif\n',
                           includes=('inc/', '.'))
        self.assertNotIn(3, cf.active_lines)     # the guarded call line

    def test_unresolvable_include_raises(self):
        with self.assertRaises(uld.ScanError):
            self.classify('%include "nope.inc"\n', includes=('.',))

    def test_include_cycle_is_guarded(self):
        self.write('a.inc', '%include "b.inc"\n')
        self.write('b.inc', '%include "a.inc"\n%define K 1\n')
        cf = self.classify('%include "a.inc"\n%ifdef K\nOk:\n    ret\n%endif\n')
        self.assertEqual(self.names(cf), ['Ok'])


class UnknownConditions(Base):
    """S4 — refuse to guess: any real content under an unevaluable condition."""

    def test_unknown_guarding_a_ret_raises(self):
        # No label, call, section or byte directive — and it still changes
        # fall-through. This is why the rule is not a list of "graph-relevant"
        # token kinds.
        with self.assertRaises(uld.ScanError) as ctx:
            self.classify("""
A:
    call Foo
%if SomeLabelEnd - SomeLabel > 4
    ret
%endif
B:
    ret
""")
        self.assertIn('t.asm:4', str(ctx.exception))

    def test_unknown_guarding_only_an_assertion_passes(self):
        # effects.asm:270 — %if _MEPT_ENTRIES != 86 guards a pure %fatal.
        cf = self.classify("""
%define _MEPT_ENTRIES ((TableEnd - Table) / 4)
%if _MEPT_ENTRIES != 86
%fatal "arity error"
%endif
A:
    ret
""")
        self.assertEqual(self.names(cf), ['A'])

    def test_unknown_region_define_mutation_raises(self):
        # A mutation can control a later condition OUTSIDE the region.
        with self.assertRaises(uld.ScanError):
            self.classify('%if UNKNOWABLE\n%define K 1\n%endif\n')

    def test_unknown_region_nested_conditional_content_raises(self):
        with self.assertRaises(uld.ScanError):
            self.classify('%if UNKNOWABLE\n%ifdef X\nA:\n    ret\n%endif\n%endif\n')

    def test_both_arms_of_an_unknown_region_are_inactive(self):
        with self.assertRaises(uld.ScanError):
            self.classify('%if UNKNOWABLE\nA:\n    ret\n%else\nB:\n    ret\n%endif\n')

    def test_unbalanced_conditional_raises(self):
        with self.assertRaises(uld.ScanError):
            self.classify('%ifdef X\nA:\n    ret\n')
        with self.assertRaises(uld.ScanError):
            self.classify('%endif\n')

    def test_inactive_blocks_stay_stack_balanced(self):
        cf = self.classify("""
%ifdef NOPE
%if UNKNOWABLE_BUT_NEVER_EVALUATED
    ret
%endif
%endif
Ok:
    ret
""")
        self.assertEqual(self.names(cf), ['Ok'])


class Boundaries(Base):
    """S5 — data is a BOUNDARY property, not an anywhere-in-body node property."""

    def test_nonterminal_into_code_entry_emits_edge(self):
        edges = self.edges("""
section .text
EnterMapBoot:
    call Setup
EnterMap:
    ret
""")
        self.assertEqual([(e[0], e[1], e[2]) for e in edges],
                         [('EnterMapBoot', 'EnterMap', 'fallthrough')])

    def test_terminal_tail_with_trailing_data_is_legal(self):
        # OptionsMenu_TextSpeed / StartMenu_Pokemon / DisplayNamingScreen: a
        # local table after a proven terminator must not reclassify the
        # routine, and must not produce an edge.
        edges = self.edges("""
section .text
OptionsMenu_TextSpeed:
    call Draw
    ret
.Strings:
    dd 0, 1, 2
Next:
    ret
""")
        self.assertEqual(edges, [])

    def test_local_jump_table_then_more_code(self):
        edges = self.edges("""
section .text
StartMenu_Pokemon:
    call Draw
    jmp Dispatch
.Table:
    dd .a, .b
More:
    call X
Last:
    ret
""")
        self.assertEqual([(e[0], e[1]) for e in edges], [('More', 'Last')])

    def test_nonterminal_into_data_in_same_stream_raises(self):
        with self.assertRaises(uld.ScanError) as ctx:
            self.edges("""
section .text
A:
    call Foo
Table:
    db 1, 2
""")
        self.assertIn('data', str(ctx.exception))

    def test_nonterminal_running_into_padding_raises(self):
        with self.assertRaises(uld.ScanError):
            self.edges("""
section .text
A:
    call Foo
    align 4
B:
    ret
""")

    def test_interposed_data_section_is_not_a_boundary(self):
        # PlacePicSlide: returns, then its top-level slice crosses `section
        # .data` and sees `align 4` before the next top-level label. The .data
        # fragment is simply absent from the .text stream.
        edges = self.edges("""
section .text
PlacePicSlide:
    call Draw
    ret
section .data
align 4
Buffer:
    db 0
section .text
Next:
    call Y
Last:
    ret
""")
        self.assertEqual([(e[0], e[1]) for e in edges], [('Next', 'Last')])

    def test_data_entry_in_text_section_gets_no_edge(self):
        # cut.asm: section .text → UsedCut → CutTreeBlockSwaps (raw db).
        edges = self.edges("""
section .text
UsedCut:
    jmp Away
CutTreeBlockSwaps:
    db 1, 2
Next:
    ret
""")
        self.assertEqual(edges, [])

    def test_guarded_section_flip_needs_no_special_case(self):
        # overworld.asm:2499-2504 — classification runs BEFORE SECTION_RE, so
        # an inactive block's section toggles never touch the current section.
        edges = self.edges("""
section .text
A:
    call Foo
%ifdef NOPE
section .data
    db 0
section .text
%endif
B:
    ret
""")
        self.assertEqual([(e[0], e[1]) for e in edges], [('A', 'B')])

    def test_zero_byte_code_alias_chain(self):
        edges = self.edges("""
section .text
AliasA:
AliasB:
Real:
    ret
""")
        self.assertEqual([(e[0], e[1]) for e in edges],
                         [('AliasA', 'AliasB'), ('AliasB', 'Real')])

    def test_zero_byte_data_alias_chain_emits_nothing(self):
        # An alias of data must never masquerade as code.
        edges = self.edges("""
section .text
AliasOfTable:
Table:
    db 1
""")
        self.assertEqual(edges, [])

    def test_cross_file_fallthrough_raises(self):
        with self.assertRaises(uld.ScanError) as ctx:
            self.edges("""
section .text
A:
    call Foo
""")
        self.assertIn('link order', str(ctx.exception))


class Terminators(Base):
    """S6 — terminators, the calls-return axiom, and its one exception."""

    def test_terminator_forms(self):
        for tail in ('ret', 'retn', 'retf', 'jmp Somewhere', 'jmp eax',
                     'jmp [table + eax*4]', 'iret'):
            with self.subTest(tail=tail):
                self.assertEqual(self.edges(
                    f'section .text\nA:\n    call X\n    {tail}\nB:\n    ret\n'), [])

    def test_conditional_jump_is_not_a_terminator(self):
        edges = self.edges('section .text\nA:\n    cmp al, 1\n    je Foo\nB:\n    ret\n')
        self.assertEqual([(e[0], e[1]) for e in edges], [('A', 'B')])

    def test_call_is_assumed_to_return(self):
        edges = self.edges('section .text\nA:\n    call X\nB:\n    ret\n')
        self.assertEqual([(e[0], e[1]) for e in edges], [('A', 'B')])

    def test_dos_exit_pair_terminates_but_bare_int21_does_not(self):
        # audio_hal.asm:177 — a bare int 0x21 is an ordinary DOS/DPMI call.
        self.assertEqual(self.edges(
            'section .text\nA:\n    mov ax, 0x4C00\n    int 0x21\nB:\n    ret\n'), [])
        edges = self.edges(
            'section .text\nA:\n    mov ax, 0x3D00\n    int 0x21\nB:\n    ret\n')
        self.assertEqual([(e[0], e[1]) for e in edges], [('A', 'B')])

    def test_dos_exit_pair_is_counted_over_tokens_not_raw_lines(self):
        self.assertEqual(self.edges("""
section .text
A:
    mov ax, 0x4C00
%ifdef NOPE
    call Ignored
%endif
.exit: int 0x21
B:
    ret
"""), [])

    def test_any_ah_4c_exit_code_terminates_not_just_0x4C00(self):
        # Round-7 adversarial review, PROVEN DEFECT: AH=4Ch is terminate-with-
        # return-code and AL is the code, so 0x4C02/0x4C01 terminate too.
        # Matching 0x4C00 alone put two spurious edges in the DEFAULT shipping
        # graph (entry.asm setup_flat_access.fail :196-197 ->  alloc_gb_memory,
        # alloc_gb_memory.alloc_failed :240-241 -> parse_cmdline).
        for setup in ('mov ax, 0x4C00', 'mov ax, 0x4C01', 'mov ax, 0x4C02',
                      'mov ax, 0x4CFF', 'mov ax, 4c02h', 'mov ah, 0x4C'):
            with self.subTest(setup=setup):
                self.assertEqual(self.edges(
                    f'section .text\nA:\n    call X\n.fail:\n    {setup}\n'
                    f'    int 0x21\nB:\n    ret\n'), [])

    def test_non_exit_ax_values_before_int21_are_not_terminators(self):
        for setup in ('mov ax, 0x3D00', 'mov ax, 0x0101', 'mov ah, 0x09'):
            with self.subTest(setup=setup):
                edges = self.edges(
                    f'section .text\nA:\n    {setup}\n    int 0x21\nB:\n    ret\n')
                self.assertEqual([(e[0], e[1]) for e in edges], [('A', 'B')])

    def test_targeted_trailing_local_label_makes_a_terminal_tail_fall_through(self):
        # Round-7 adversarial review, PROVEN DEFECT (live under
        # `make DEBUG_ASSERTIONS=1`): the last INSTRUCTION is not always the
        # entry's last reachable point. home/window.asm:176-183 under
        # DEBUG_ASSERT_REENTRANCY is exactly this shape — control takes
        # `jmp .projection_ready`, lands on the trailing local, and falls into
        # PrintText_NoCreatingTextBox. Reading the terminal `jmp` as the tail
        # silently deleted that real edge (137 -> 136, no diagnostic).
        edges = self.edges("""
section .text
A:
    pop esi
    jmp .ready
.trap:
    int3
    jmp .trap
.ready:
B:
    ret
""")
        self.assertEqual([(e[0], e[1]) for e in edges], [('A', 'B')])

    def test_untargeted_trailing_local_label_does_not_resurrect_a_terminator(self):
        # The other direction, so the fix cannot become a false-edge generator:
        # an untargeted trailing local is unreachable and changes nothing.
        self.assertEqual(self.edges(
            'section .text\nA:\n    call X\n    ret\n.unused:\nB:\n    ret\n'), [])

    def test_address_taken_trailing_local_is_not_a_branch_target(self):
        # A local data table addressed by `mov esi, .Strings` (the
        # OptionsMenu_TextSpeed shape) must NOT make a returning routine fall
        # through — that would recreate the false positive S5 exists to stop.
        self.assertEqual(self.edges("""
section .text
A:
    mov esi, .Strings
    call PrintIt
    ret
.Strings:
    db 0x80
B:
    ret
"""), [])

    def test_qualified_local_label_is_not_lexed_as_an_instruction(self):
        # Round-7 adversarial review, LATENT: NASM's `Foo.bar:` defines local
        # `.bar` of Foo. LABEL_RE forbids the dot and LOCAL_LABEL_RE requires a
        # leading one, so it lexed as an INSTRUCTION whose text is the label —
        # non-terminal, minting a spurious edge cited at a label line. The
        # tree's three occurrences (audio/low_health_alarm.asm:88,92,97) sit in
        # `.data`, which stream_entries skips: the right count by luck.
        cf = self.classify(
            'section .text\nAlpha:\n    mov eax, 1\n    ret\nAlpha.endmark:\n'
            'Beta:\n    ret\n')
        self.assertEqual(self.names(cf), ['Alpha', 'Beta'])
        self.assertEqual(self.edges(
            'section .text\nAlpha:\n    mov eax, 1\n    ret\nAlpha.endmark:\n'
            'Beta:\n    ret\n'), [])

    def test_dos_exit_tails_are_transitive_over_jmp_chains(self):
        # Round-7 adversarial review, LATENT hole (pre-existing: the superseded
        # anywhere-reading missed it identically). RunCalcStatsTest tails
        # `jmp DebugDumpMemory` and never returns while containing no idiom.
        cf = self.classify("""
section .text
DebugDumpMemory:
    call WriteFile
    mov ax, 0x4C00
    int 0x21
RunCalcStatsTest:
    call ComputeStats
    jmp DebugDumpMemory
Innocent:
    call Thing
    jmp SomewhereThatReturns
Last:
    ret
""")
        self.assertEqual(uld.dos_exit_tails({'t.asm': cf}),
                         {'DebugDumpMemory', 'RunCalcStatsTest'})

    def test_dos_exit_tail_callee_makes_a_tail_call_unproved(self):
        with self.assertRaises(uld.ScanError) as ctx:
            self.edges('section .text\nA:\n    call DumpBackbuffer\nB:\n    ret\n',
                       dos_exit={'DumpBackbuffer'})
        self.assertIn('unproved', str(ctx.exception))

    def test_dos_exit_tails_are_detected_by_tail_not_by_presence(self):
        # DumpBackbuffer's own tail IS the idiom -> unproved return.
        # DelayFrame merely CONTAINS it on a conditional quit path and returns
        # via `ret` -> proven to return, so its callers' edges are real.
        # DumpSeamLog likewise ends in `ret` and is not in this class — which
        # is the plan's own stated reason for excluding it.
        cf = self.classify("""
section .text
DumpBackbuffer:
    call Free
.exit:
    mov ax, 0x4C00
    int 0x21
DelayFrame:
    cmp byte [pad_quit], 0
    je .done
    call cleanup
    mov ax, 0x4C00
    int 0x21
.done:
    popad
    ret
DumpSeamLog:
    mov ax, 0x4C00
    int 0x21
.never:
    ret
""")
        self.assertEqual(uld.dos_exit_tails({'t.asm': cf}), {'DumpBackbuffer'})

    def test_delayframe_shaped_callee_keeps_its_edge(self):
        # The round-7 amendment, as a fixture: the anywhere-reading of S6 would
        # delete this edge, and it is the shipping game loop.
        edges = self.edges('section .text\nOverworldLoop:\n    call DelayFrame\n'
                           'OverworldLoopLessDelay:\n    ret\n', dos_exit=set())
        self.assertEqual([(e[0], e[1]) for e in edges],
                         [('OverworldLoop', 'OverworldLoopLessDelay')])


class Macros(Base):
    """S5.4 — macro classification derived transitively, checked at boundaries."""

    def reg(self, bodies):
        return uld.MacroRegistry(
            {k: list(enumerate(v, 1)) for k, v in bodies.items()},
            {k: 'macros.inc' for k in bodies})

    def test_byte_emitting_macro_makes_a_data_entry(self):
        macros = self.reg({'text_far': ['db 0x17', 'dw %1']})
        edges = self.edges("""
section .text
A:
    jmp Away
_TextData:
    text_far SomeText
""", macros=macros)
        self.assertEqual(edges, [])

    def test_transitive_byte_emission_through_nested_macro(self):
        macros = self.reg({'dbw': ['db %1', 'dw %2'], 'outer': ['dbw 1, 2']})
        self.assertTrue(macros.emits_bytes('outer'))

    def test_non_byte_macro_that_returns_is_transparent(self):
        macros = self.reg({'hlcoord': ['lea esi, [ebp + %1]']})
        edges = self.edges('section .text\nA:\n    hlcoord 1, 2\nB:\n    ret\n',
                           macros=macros)
        self.assertEqual([(e[0], e[1]) for e in edges], [('A', 'B')])

    def test_non_byte_macro_with_terminal_expansion_raises_at_a_boundary(self):
        # Byte/non-byte alone is insufficient: a macro expanding to `ret` would
        # otherwise manufacture a fall-through edge.
        macros = self.reg({'tail_ret': ['pop eax', 'ret']})
        self.assertIs(macros.returns('tail_ret'), False)
        with self.assertRaises(uld.ScanError) as ctx:
            self.edges('section .text\nA:\n    tail_ret\nB:\n    ret\n', macros=macros)
        self.assertIn('not proven to return', str(ctx.exception))

    def test_macro_ending_in_the_dos_exit_pair_does_not_return(self):
        # Round-7 adversarial review, LATENT: MacroRegistry._resolve tested the
        # tail with prev_text hardcoded None, so `_is_dos_exit_setup(None)` was
        # always False and a macro body ending in the exit PAIR summarized as
        # "returns" — Amendment 5's bug one code path over, and a false-edge
        # generator. No macro in this tree contains int 0x21 today.
        for setup in ('mov ax, 0x4C00', 'mov ax, 0x4C02', 'mov ah, 0x4C'):
            with self.subTest(setup=setup):
                macros = self.reg({'exit_now': [setup, 'int 0x21']})
                self.assertIs(macros.returns('exit_now'), False)
        # …while an ordinary DOS call through a macro still returns.
        macros = self.reg({'dos_print': ['mov ah, 0x09', 'int 0x21']})
        self.assertIs(macros.returns('dos_print'), True)

    def test_conditional_structure_in_a_macro_body_makes_its_tail_unprovable(self):
        # Round-8 open hole 2, closed: NONMATERIAL_DIRECTIVES holds no `%`
        # directive and bodies are collected verbatim, so `%if`/`%endif`/`%rep`
        # lexed as INSTRUCTIONS — non-terminal ones — and a %endif-terminated
        # macro summarized as returns=True. The registry has no define state
        # and never sees the invocation's arguments, so it cannot answer this
        # in principle: under refuse-to-guess it must fail, not guess. The 24
        # such macros in the tree get the right answer only by luck (none
        # guards a jmp/ret); one %ifdef-guarded `jmp` makes it real.
        for body in (
                ['%ifdef DEBUG_X', 'jmp Away', '%endif', 'nop'],   # guards a jmp
                ['%if 1', 'nop', '%endif'],                        # %endif tail
                ['%rep 2', 'nop', '%endrep'],
                ['%else'],
                ['%elifdef Y'],
        ):
            with self.subTest(body=body):
                macros = self.reg({'cond_macro': body})
                self.assertIsNone(macros.returns('cond_macro'))
                with self.assertRaises(uld.ScanError) as ctx:
                    self.edges('section .text\nA:\n    call X\n    cond_macro\n'
                               'B:\n    ret\n', macros=macros)
                self.assertIn('not proven to return', str(ctx.exception))
                # The refusal names the directive that caused it (file:line).
                self.assertIn('macros.inc:', str(ctx.exception))

    def test_conditional_macro_tail_refusal_is_transitive(self):
        macros = self.reg({'inner': ['%ifdef X', 'ret', '%endif'],
                           'outer': ['nop', 'inner']})
        self.assertIsNone(macros.returns('outer'))
        with self.assertRaises(uld.ScanError):
            self.edges('section .text\nA:\n    call X\n    outer\nB:\n    ret\n',
                       macros=macros)

    def test_conditional_macro_body_still_classifies_its_byte_emission(self):
        # Scope guard: the refusal is the TAIL only. The tree's byte-emitting
        # families (dname/tmhm/dn/dc/bigdw/…) are built out of %rep/%if, so
        # refusing entry KIND too would hard-fail the shipping tree — and a
        # macro nobody uses at a tail must not break the build.
        macros = self.reg({'dname': ['%rep %0', 'db %1', '%rotate 1', '%endrep']})
        self.assertTrue(macros.emits_bytes('dname'))
        edges = self.edges("""
section .text
A:
    ret
NameTable:
    dname "RED"
""", macros=macros)
        self.assertEqual(edges, [])

    def test_unknown_macro_at_a_boundary_raises(self):
        macros = self.reg({'recursive': ['recursive']})
        self.assertIsNone(macros.emits_bytes('recursive'))
        with self.assertRaises(uld.ScanError):
            self.edges('section .text\nA:\n    call X\n    recursive\nB:\n    ret\n',
                       macros=macros)

    def test_unclassifiable_macro_at_an_entry_kind_position_raises(self):
        macros = self.reg({'recursive': ['recursive']})
        with self.assertRaises(uld.ScanError) as ctx:
            self.edges('section .text\nA:\n    recursive\nB:\n    ret\n', macros=macros)
        self.assertIn('entry kind', str(ctx.exception))

    def test_macro_bodies_are_not_classification_state(self):
        # NASM evaluates a body's conditionals at expansion, not definition.
        cf = self.classify("""
%macro thing 1
%ifdef NEVER
    ret
%endif
%endmacro
A:
    ret
""")
        self.assertEqual(self.names(cf), ['A'])

    def test_live_tree_macro_registry_classifies_the_known_families(self):
        # No hand list and no ellipsis: this asserts the DERIVATION covers the
        # families the plan names.
        macros = uld.build_macro_registry(
            [os.path.join(self.dos_port, d) for d in ('boot', 'src', 'include')])
        for name in ('text_far', 'dbw', 'dwb', 'dn', 'dc', 'dba', 'dab',
                     'bigdw', 'dname', 'tmhm', 'dbsprite', 'dbmapcoord',
                     'event_displacement', 'fly_warp'):
            with self.subTest(macro=name):
                self.assertTrue(macros.emits_bytes(name),
                                f'{name} must classify as byte-emitting')
        self.assertFalse(macros.emits_bytes('hlcoord'))


class Probe(unittest.TestCase):
    """S1 — ask GNU Make; never parse it."""

    def test_quoted_defines_round_trip_losslessly(self):
        # printf "$(NASMFLAGS)" strips this nested quoting; the env transport
        # must not. shlex is the shell that runs nasm, so this is what nasm
        # actually receives.
        cfg = buildprobe.probe()
        self.assertEqual(cfg.defines.get('PLAYER_NAME'), "'NINTEN'")
        self.assertEqual(cfg.defines.get('RIVAL_NAME'), "'SONY'")

    def test_shell_computed_define_is_resolved(self):
        self.assertTrue(buildprobe.probe().defines['PIT_DIVISOR'].isdigit())

    def test_include_search_order_is_taken_from_the_build(self):
        self.assertEqual(buildprobe.probe().includes, ('include/', '.'))

    def test_valueless_define_seeds_nasm_truthy_one(self):
        defines, includes = buildprobe.parse_nasmflags(
            '-f coff -I include/ -I . -D BARE -D VAL=2 -D Q="\'NINTEN\'"')
        self.assertEqual(defines, {'BARE': '1', 'VAL': '2', 'Q': "'NINTEN'"})
        self.assertEqual(includes, ('include/', '.'))

    def test_unparsable_define_is_a_hard_error(self):
        with self.assertRaises(buildprobe.ProbeError):
            buildprobe.parse_nasmflags('-I . -D 3BAD=1')
        with self.assertRaises(buildprobe.ProbeError):
            buildprobe.parse_nasmflags('-I . -D')

    def test_ambient_environment_cannot_alter_the_shipping_config(self):
        os.environ['DEBUG_PERF'] = '1'
        try:
            cfg = buildprobe.probe()
        finally:
            del os.environ['DEBUG_PERF']
        self.assertNotIn('dos_port/src/debug/perf.asm', cfg.link)
        self.assertNotIn('DEBUG_PERF', cfg.defines)

    def test_conditional_make_membership(self):
        # Bug 3: the regex parser reported both of these linked by default.
        default = buildprobe.probe()
        self.assertNotIn('dos_port/src/debug/debug_dump.asm', default.link)
        self.assertNotIn('dos_port/src/debug/perf.asm', default.link)
        # One override surface: --config flips membership AND defines together,
        # from one source of truth, so they cannot diverge.
        party = buildprobe.probe(['DEBUG_PARTY=1'])
        self.assertIn('dos_port/src/debug/debug_dump.asm', party.link)
        self.assertIn('DEBUG_PARTY', party.defines)
        self.assertIn('SKIP_TITLE', party.defines)

    def test_check_only_sources_are_not_linked(self):
        cfg = buildprobe.probe()
        self.assertTrue(any(p.endswith('trainer_engine.asm') for p in cfg.check))
        self.assertNotIn('dos_port/src/engine/overworld/trainer_engine.asm', cfg.link)


class LiveTree(unittest.TestCase):
    """V2/V3/V4 — corroboration against the shipping tree."""

    def test_no_hard_fail_on_the_default_tree(self):
        # Every S4/S5/S6 refusal has a fixture above proving it fires; none of
        # them may fire here, or the tool is unrunnable.
        self.assertTrue(live()['fallthrough'])

    def test_boot_chain_fallthrough_edges_exist(self):
        # The static contract. The overworld_pallet golden is separate RUNTIME
        # evidence: execution does not prove which static edge caused it.
        edges = {(e[0], e[1]) for e in live()['fallthrough']}
        for edge in (('EnterMapBoot', 'EnterMap'),
                     ('EnterMap', 'OverworldLoop'),
                     ('OverworldLoop', 'OverworldLoopLessDelay')):
            self.assertIn(edge, edges)

    def test_labels_that_must_be_reached(self):
        reached = live()['reached']
        for name in ('EnterMapBoot', 'EnterMap', 'OverworldLoop',
                     'OverworldLoopLessDelay', 'DisplayTextID',
                     'DisplayStartMenu', 'StartMenu_Pokemon', 'UsedCut',
                     'TryPushingBoulder', 'PrintStrengthText'):
            with self.subTest(label=name):
                self.assertIn(name, reached)

    def test_debug_only_entry_points_must_not_be_reached(self):
        # Bug 2: each is a `call` inside %ifdef DEBUG_*, none in this build.
        for name in ('RunAudioTest', 'RunCalcStatsTest', 'RunPartySeedTest',
                     'RunOakIntroTest', 'RunPartyMenuTest'):
            with self.subTest(label=name):
                self.assertNotIn(name, live()['reached'])

    def test_count_delta_direction(self):
        # ~385 before, ~1046+ after. "Everything reachable" is the tell that
        # the terminator rule went too lax.
        reached = len(live()['reached'])
        self.assertGreater(reached, 900)
        self.assertLess(reached, 1400)

    def test_differential_probe_moves_the_build_active_edge_set(self):
        # Compare edge SETS, not the reached count: the 25 BUG_FIX_LEVEL blocks
        # hold only 4 call/jmp-to-label lines, and their targets may already be
        # reached by other edges — a count assertion would be flaky by design,
        # while a silently no-op evaluator is exactly what this catches.
        cfg2 = buildprobe.probe(['BUG_FIX_LEVEL=2'])
        _ft2, active2 = uld.scan_build_graph(cfg2)
        calls = live()['calls']

        def active_set(active):
            return {(c, e, f, ln) for c, e, _k, f, ln in calls
                    if f in active and ln in active[f]}

        self.assertNotEqual(active_set(live()['active']), active_set(active2))


if __name__ == '__main__':
    unittest.main(verbosity=2)
