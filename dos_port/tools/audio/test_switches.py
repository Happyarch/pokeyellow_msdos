#!/usr/bin/env python3
"""test_switches.py — timed mid-song MT-32/GM program switches.

Covers the toolchain side of the switches plan:
  * gb_to_midi: resolve_switch_program (both numberings + fallback chain),
    build_program_timeline / program_at, fold_switch_frames,
    override_switch_events emission (ticks, programs, off->prog->on order),
    enhancement_tracks emission on the assigned free part.
  * yaml_lint: every switch rule, positive + negative (overrides via
    lint_overrides, enhancements via lint).
  * audition/midi_renderer: timelines + send_init(at_frame) on the re-sync
    paths (fabricated session — no ALSA hardware needed).
  * Cities2 pilot: 303 base notes + 2 timed 0xC0s at frames 1443/1928.
  * Compatibility: all 16 enhancement + all override files lint clean;
    switchless songs emit exactly one tick-0 0xC0 per melodic channel.

Usage:
    python3 dos_port/tools/audio/test_switches.py
"""

from __future__ import annotations

import struct
import sys
import tempfile
import unittest
from pathlib import Path

import yaml

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from pret_audio import AudioROM  # noqa: E402
from gb_to_midi import (  # noqa: E402
    build_addr_map, simulate_song, songs_from_headers,
    write_midi, load_overrides, channel_switches, resolve_switch_program,
    build_program_timeline, program_at, fold_switch_frames,
    override_switch_events, enhancement_tracks,
)
from yaml_lint import (  # noqa: E402
    lint, lint_overrides, load_analysis, BeatMap, first_body_notes,
    load_timbre_names, _resolve_switch_positions, Report,
)
from midi_to_stream import parse_midi  # noqa: E402
from gen_opl_patches import PATCHES  # noqa: E402


def read_vlq(data: bytes, pos: int):
    val = 0
    while True:
        b = data[pos]
        pos += 1
        val = (val << 7) | (b & 0x7F)
        if not b & 0x80:
            return val, pos


def track_events(mid_path: Path, want_text: bytes):
    """[(tick, status, data)] of the track whose first text meta matches."""
    data = mid_path.read_bytes()
    ntrk = struct.unpack(">H", data[10:12])[0]
    pos = 14
    for _ in range(ntrk):
        assert data[pos:pos + 4] == b"MTrk"
        length = struct.unpack(">I", data[pos + 4:pos + 8])[0]
        p, end = pos + 8, pos + 8 + length
        tick = 0
        evs = []
        first_text = None
        while p < end:
            delta, p = read_vlq(data, p)
            tick += delta
            status = data[p]
            if status == 0xFF:
                mtype = data[p + 1]
                mlen, p2 = read_vlq(data, p + 2)
                payload = data[p2:p2 + mlen]
                p = p2 + mlen
                if mtype == 0x03 and first_text is None:
                    first_text = payload
                continue
            kind = status & 0xF0
            if kind in (0xC0, 0xD0):
                payload = data[p + 1:p + 2]
                p += 2
            else:
                payload = data[p + 1:p + 3]
                p += 3
            evs.append((tick, status, payload))
        if first_text == want_text:
            return evs
        pos = end
    raise AssertionError(f"no track with text {want_text!r}")


CITIES2_SWITCHES = [
    {"m": 15, "b": 4, "mt32_program": "Violin 1", "gm_program": "Violin"},
    {"m": 18, "b": 2, "mt32_program": "Trumpet 1", "gm_program": "Trumpet"},
]


class SwitchTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.rom = AudioROM()
        cls.amap = build_addr_map(cls.rom)
        cls.songs = songs_from_headers(cls.rom)
        cls.song = simulate_song(cls.rom, cls.amap, "Music_Cities2",
                                 cls.songs["Music_Cities2"])
        cls.ov = load_overrides("Music_Cities2")
        cls.analysis = load_analysis("Music_Cities2")
        cls.tmp = Path(tempfile.mkdtemp(prefix="switchtest_"))

    # -- shared helper unit tests --------------------------------------
    def test_resolve_overrides_numbering(self):
        self.assertEqual(
            resolve_switch_program(80, None, None, None, None, 0,
                                   "mt32", "t", one_based=False), 80)
        self.assertEqual(
            resolve_switch_program("Violin 1", None, None, None, None, 0,
                                   "mt32", "t", one_based=False), 52)
        self.assertEqual(
            resolve_switch_program(None, "Violin", None, None, None, 0,
                                   "gm", "t", one_based=False), 40)

    def test_resolve_enhancement_numbering(self):
        self.assertEqual(
            resolve_switch_program(49, 49, 1, 1, None, None,
                                   "mt32", "t", one_based=True), 48)
        self.assertEqual(
            resolve_switch_program(49, 49, 1, 1, None, None,
                                   "gm", "t", one_based=True), 48)
        with self.assertRaises(ValueError):
            resolve_switch_program(0, None, 1, 1, None, None,
                                   "mt32", "t", one_based=True)
        with self.assertRaises(ValueError):
            resolve_switch_program(128, None, None, None, None, 0,
                                   "mt32", "t", one_based=False)

    def test_resolve_fallback_chain(self):
        # switch key -> channel base -> `program` -> default
        self.assertEqual(
            resolve_switch_program(None, None, "Cello 1", "Cello", None, 80,
                                   "mt32", "t", one_based=False), 54)
        self.assertEqual(
            resolve_switch_program(None, None, None, None, "Square Wave",
                                   80, "mt32", "t", one_based=False), 47)
        self.assertEqual(
            resolve_switch_program(None, None, None, None, None, 80,
                                   "gm", "t", one_based=False), 80)
        with self.assertRaises(ValueError):
            resolve_switch_program(None, None, None, None, None, None,
                                   "gm", "t", one_based=False)
        with self.assertRaises(ValueError):
            resolve_switch_program(True, None, None, None, None, 0,
                                   "mt32", "t", one_based=False)

    def test_resolve_string_mt32_errors(self):
        # Factory names are fine; anything else raises (switches ERROR).
        self.assertEqual(
            resolve_switch_program("Trumpet 1", None, None, None, None, 0,
                                   "mt32", "t", one_based=False), 88)
        with self.assertRaises(ValueError):
            resolve_switch_program("No Such Patch", None, None, None,
                                   None, 0, "mt32", "t", one_based=False)

    def test_timeline_and_program_at(self):
        tl = build_program_timeline(88, [(1914, 88), (1637, 52)])
        self.assertEqual(tl, [(0, 88), (1637, 52), (1914, 88)])
        self.assertEqual(program_at(tl, 0), 88)
        self.assertEqual(program_at(tl, 1636), 88)
        self.assertEqual(program_at(tl, 1637), 52)
        self.assertEqual(program_at(tl, 1913), 52)
        self.assertEqual(program_at(tl, 1914), 88)
        self.assertEqual(program_at(tl, 99999), 88)
        # frame-0 switch overrides tick-0; same-prog restates collapse
        self.assertEqual(build_program_timeline(88, [(0, 52)]), [(0, 52)])
        self.assertEqual(build_program_timeline(88, [(0, 88)]), [(0, 88)])

    def test_fold_switch_frames(self):
        e1, e2 = {"m": 1}, {"m": 2}
        # intro fires once; body duplicates across both bodies
        got = fold_switch_frames([(100, e1), (300, e2)],
                                 first_body=222, period=1776, unroll=2)
        self.assertEqual([(f, e) for f, e in got],
                         [(100, e1), (300, e2), (2076, e2)])
        # later-body positions fold back into first-body coordinates
        got = fold_switch_frames([(222 + 1776 + 10, e1)],
                                 first_body=222, period=1776, unroll=2)
        self.assertEqual([f for f, _ in got], [232, 2008])

    def test_channel_switches_accessor(self):
        self.assertEqual(len(channel_switches(self.ov, 2)), 2)
        self.assertEqual(channel_switches(self.ov, 1), [])
        self.assertEqual(channel_switches({}, 2), [])
        self.assertEqual(channel_switches({"channels": {2: None}}, 2), [])

    # -- writer: Cities2 pilot ------------------------------------------
    def test_cities2_base_note_count(self):
        self.assertEqual(len(self.song.notes), 303)
        self.assertEqual(self.song.loop_start, 222)
        self.assertEqual(self.song.end, 1998)

    def test_cities2_switch_frames(self):
        evs = override_switch_events("Music_Cities2", self.ov, self.song,
                                     "mt32")
        self.assertEqual([f for f, _ in evs[2]], [1443, 1928])
        self.assertEqual([p for _, p in evs[2]], [52, 88])
        evs_gm = override_switch_events("Music_Cities2", self.ov, self.song,
                                        "gm")
        self.assertEqual([f for f, _ in evs_gm[2]], [1443, 1928])
        self.assertEqual([p for _, p in evs_gm[2]], [40, 56])

    def test_cities2_mid_parseback(self):
        for target, progs in (("mt32", [52, 88]), ("gm", [40, 56])):
            out = self.tmp / f"Cities2_{target}.mid"
            write_midi(out, self.song, self.ov, target)
            events, loop_start, end = parse_midi(out)
            self.assertEqual(loop_start, 222)
            self.assertEqual(end, 1998)
            ons = [m for _, m in events
                   if m[0] & 0xF0 == 0x90 and m[2] != 0]
            self.assertEqual(len(ons), 303)
            # tick-0 program + the two timed switches on MIDI ch 2
            pcs = [(t, m[1]) for t, m in events if m[0] == 0xC2]
            self.assertEqual(pcs, [(0, pcs[0][1]),
                                   (1443, progs[0]), (1928, progs[1])])

    def test_cities2_stream_carry(self):
        # Downstream needs NO changes: the timed 0xC0s flow through
        # midi_to_stream into the flat stream in order (regression fixture:
        # switches coincident with note edges pass through; the ==end case
        # stays a lint ERROR, so the stream never legitimately sees one).
        from midi_to_stream import build_stream
        out = self.tmp / "Cities2_stream.mid"
        write_midi(out, self.song, self.ov, "mt32")
        events, loop_start, end = parse_midi(out)
        ops, loop_off = build_stream(events, loop_start, end)
        self.assertNotEqual(loop_off, 0xFFFF)
        # At frame 1443, the timed switch selects Violin 1 (52)
        i52 = ops.find(bytes((0xC2, 52)))
        self.assertGreater(i52, 0)
        # At frame 1928, the timed switch re-asserts Trumpet 1 (88)
        i88 = ops.find(bytes((0xC2, 88)), i52 + 1)
        self.assertNotEqual(i88, -1)
        # edge-coincident switch: off -> prog -> on survives the stream.
        ov = yaml.safe_load((HERE / "overrides"
                             / "Music_Cities2.yaml").read_text())
        ov["channels"][2]["switches"] = [
            {"m": 16, "b": 1, "mt32_program": "Violin 1",
             "gm_program": "Violin"}]
        out2 = self.tmp / "Cities2_edge_stream.mid"
        write_midi(out2, self.song, ov, "mt32")
        events2, ls2, end2 = parse_midi(out2)
        ops2, _ = build_stream(events2, ls2, end2)
        i = ops2.find(bytes((0xC2, 52)))
        self.assertNotEqual(i, -1)
        self.assertIn(bytes((0x82, 71, 64)), ops2[:i])
        self.assertIn(bytes((0x92, 71)), ops2[i:])

    def test_cities2_off_prog_on_ordering(self):
        # Legal edge switch (m16 b1 = frame 1665 = note off + note on):
        # the .mid must carry off -> prog -> on at the shared tick.
        ov = yaml.safe_load((HERE / "overrides"
                             / "Music_Cities2.yaml").read_text())
        ov["channels"][2]["switches"] = [
            {"m": 16, "b": 1, "mt32_program": "Violin 1",
             "gm_program": "Violin"}]
        out = self.tmp / "Cities2_edge.mid"
        write_midi(out, self.song, ov, "mt32")
        evs = track_events(out, b"GB ch2")
        at = [(s, bytes(b)) for t, s, b in evs if t == 1665]
        kinds = [("off" if (s == 0x82 or (s == 0x92 and b[1] == 0))
                  else "prog" if s == 0xC2
                  else "on" if s == 0x92 else f"{s:#x}")
                 for s, b in at]
        self.assertIn("off", kinds)
        self.assertIn("prog", kinds)
        self.assertIn("on", kinds)
        self.assertLess(kinds.index("off"), kinds.index("prog"))
        self.assertLess(kinds.index("prog"), kinds.index("on"))

    def test_switchless_song_single_tick0(self):
        rom_ov = load_overrides("Music_Cities1")
        song = simulate_song(self.rom, self.amap, "Music_Cities1",
                             self.songs["Music_Cities1"])
        out = self.tmp / "Cities1.mid"
        write_midi(out, song, rom_ov, "mt32")
        events, _, _ = parse_midi(out)
        for mc in (1, 2, 3):
            pcs = [(t, m[1]) for t, m in events if m[0] == (0xC0 | mc)]
            self.assertEqual(len(pcs), 1, f"MIDI ch {mc}: {pcs}")
            self.assertEqual(pcs[0][0], 0)

    # -- yaml_lint: overrides --------------------------------------------
    def _ov_path(self, switches, chan=2):
        doc = yaml.safe_load((HERE / "overrides"
                              / "Music_Cities2.yaml").read_text())
        doc["channels"][chan]["switches"] = switches
        p = self.tmp / "Music_Cities2.yaml"
        p.write_text(yaml.safe_dump(doc))
        return p

    def test_overrides_pilot_points_are_mid_note(self):
        # The spec'd m15b4/m18b2 points resolve to 1637/1914, both strictly
        # inside ch2 sustained notes — the mid-note rule fires. This test
        # pins the measured state (see report); move the points to note
        # edges to make it clean.
        p = self._ov_path(CITIES2_SWITCHES)
        rep, resolved = lint_overrides(p)
        self.assertTrue(rep.errors)
        self.assertTrue(any("strictly inside" in e and "1637" in e
                            for e in rep.errors))

    def test_overrides_legal_edge_points_clean(self):
        p = self._ov_path([
            {"m": 16, "b": 1, "mt32_program": "Violin 1",
             "gm_program": "Violin"},
            {"m": 18, "b": 2.5, "mt32_program": "Trumpet 1",
             "gm_program": "Trumpet"},
        ])
        rep, resolved = lint_overrides(p)
        self.assertEqual(rep.errors, [])
        self.assertEqual(rep.warnings, [])
        self.assertEqual([f for f, _ in resolved[2]], [1665, 1928])

    def test_overrides_shape_errors(self):
        for bad, needle in [
            ({"switches": "nope"}, "must be a list"),
            ([{"m": 0, "b": 1, "gm_program": 40}], "m must be"),
            ([{"m": 1, "b": 0, "gm_program": 40}], "b must be"),
            ([{"m": 1, "b": 1}], "at least one program key"),
            ([{"m": 1, "b": 1, "gm_program": 40, "opl_patch": "x"}],
             "opl_patch"),
            ([{"m": 1, "b": 1, "gm_program": 40, "bogus": 1}],
             "unknown keys"),
            ([{"m": 1, "b": 1, "gm_program": 128}], "out of 0-127"),
            ([{"m": 1, "b": 1, "mt32_program": "No Such Patch"}],
             "unknown mt32"),
            ([{"m": 1, "b": 1, "gm_program": "No Such GM"}], "unknown gm"),
        ]:
            if isinstance(bad, dict) and "switches" in bad and \
                    not isinstance(bad["switches"], list):
                doc = yaml.safe_load((HERE / "overrides"
                                      / "Music_Cities2.yaml").read_text())
                doc["channels"][2].update(bad)
                p = self.tmp / "Music_Cities2.yaml"
                p.write_text(yaml.safe_dump(doc))
            else:
                p = self._ov_path(bad)
            rep, _ = lint_overrides(p)
            self.assertTrue(rep.errors, bad)
            self.assertTrue(any(needle in e for e in rep.errors),
                            (bad, rep.errors))

    def test_overrides_ch4_and_bad_channel(self):
        doc = yaml.safe_load((HERE / "overrides"
                              / "Music_Cities2.yaml").read_text())
        doc["channels"][4] = {"switches": [
            {"m": 3, "b": 1, "mt32_program": 80, "gm_program": 40}]}
        p = self.tmp / "Music_Cities2.yaml"
        p.write_text(yaml.safe_dump(doc))
        rep, _ = lint_overrides(p)
        self.assertTrue(any("channels.4" in e for e in rep.errors))
        doc = yaml.safe_load((HERE / "overrides"
                              / "Music_Cities2.yaml").read_text())
        doc["channels"][9] = {"switches": [
            {"m": 3, "b": 1, "gm_program": 40}]}
        p.write_text(yaml.safe_dump(doc))
        rep, _ = lint_overrides(p)
        self.assertTrue(any("must be 1-4" in e for e in rep.errors))

    def test_overrides_range(self):
        p = self._ov_path([{"m": 99, "b": 1, "gm_program": 40}])
        rep, _ = lint_overrides(p)
        self.assertTrue(any("past the song end" in e for e in rep.errors))
        # == end is its own ERROR (synthetic one-shot beat map)
        bm = BeatMap({"beat_frames": [0, 10, 20], "beats_per_measure": 4,
                      "measures": 1, "meter": [4, 4]}, 20, None, None)
        rep2 = Report()
        out = _resolve_switch_positions(
            [{"m": 1, "b": 3, "gm_program": 40}], bm, "channel 1", rep2,
            one_based=False, timbre_names=set(), end=20, bodies=1)
        self.assertEqual(out, [])
        self.assertTrue(any("exactly the song end" in e
                            for e in rep2.errors))
        rep3 = Report()
        out = _resolve_switch_positions(
            [{"m": 1, "b": 2, "gm_program": 40}], bm, "channel 1", rep3,
            one_based=False, timbre_names=set(), end=20, bodies=1)
        self.assertEqual([f for f, _ in out], [10])
        self.assertEqual(rep3.errors, [])

    def test_overrides_uniqueness(self):
        p = self._ov_path([
            {"m": 16, "b": 1, "gm_program": 40},
            {"m": 16, "b": 1, "gm_program": 41},
        ])
        rep, _ = lint_overrides(p)
        self.assertTrue(any("strictly increasing" in e
                            for e in rep.errors))

    def test_overrides_noop_warn(self):
        # ch2 tick-0 is Trumpet/Trumpet 1: restating it at a legal edge
        # WARNs on both targets and errors on nothing.
        p = self._ov_path([
            {"m": 16, "b": 1, "mt32_program": "Trumpet 1",
             "gm_program": "Trumpet"},
        ])
        rep, _ = lint_overrides(p)
        self.assertEqual(rep.errors, [])
        self.assertEqual(len([w for w in rep.warnings if "no-op" in w]), 2)

    def test_overrides_loop_return_no_warn(self):
        # Return-to-base at the loop entry is meaningful on every pass
        # after the first (the body switch stays latched across the wrap),
        # so the loop-aware no-op seed must not warn on it.
        p = self._ov_path([
            {"m": 3, "b": 1, "mt32_program": "Trumpet 1",
             "gm_program": "Trumpet"},
            {"m": 14, "b": 1, "mt32_program": "Violin 1",
             "gm_program": "Violin"},
        ])
        rep, _ = lint_overrides(p)
        self.assertEqual(rep.errors, [])
        self.assertEqual([w for w in rep.warnings if "no-op" in w], [])

    def test_overrides_intro_warn(self):
        p = self._ov_path([
            {"m": 1, "b": 1, "mt32_program": "Violin 1",
             "gm_program": "Violin"},
        ])
        rep, _ = lint_overrides(p)
        self.assertEqual(rep.errors, [])
        self.assertTrue(any("intro-fires-once" in w
                            for w in rep.warnings))

    def test_overrides_percussion_flip(self):
        # Tinkle Bell is 1-based GM 113 → 0-based 112 here.
        p = self._ov_path([
            {"m": 16, "b": 1, "mt32_program": "Trumpet 1",
             "gm_program": 112},
        ])
        rep, _ = lint_overrides(p)
        self.assertTrue(any("percussion" in e for e in rep.errors))

    def test_overrides_custom_timbre_errors(self):
        import yaml_lint
        real = yaml_lint.load_timbre_names
        yaml_lint.load_timbre_names = lambda: {"Fake Timbre"}
        try:
            p = self._ov_path([
                {"m": 16, "b": 1, "mt32_program": "Fake Timbre",
                 "gm_program": "Violin"},
            ])
            rep, _ = lint_overrides(p)
            self.assertTrue(any("custom timbre" in e for e in rep.errors))
        finally:
            yaml_lint.load_timbre_names = real

    # -- yaml_lint: enhancements ------------------------------------------
    def _enh_path(self, channels, **top):
        doc = {"schema": 1, "song": "Music_Cities2", "channels": channels}
        doc.update(top)
        p = self.tmp / "Music_Cities2.yaml"
        p.write_text(yaml.safe_dump(doc))
        return p

    @staticmethod
    def _ch(name, tier, switches, **kw):
        ch = {"name": name, "tier": tier, "mt32_patch": 49,
              "gm_program": 49, "switches": switches}
        ch.update(kw)
        return ch

    def test_enh_tier1_switches_allowed(self):
        # Tier-1 channels may carry MT-32/GM switches (the OPL side keeps
        # its tick-0 patch by construction); only an opl_patch key inside
        # a switch entry is an error (no patch-select op in the stream).
        p = self._enh_path([self._ch("pad", 1, [
            {"m": 16, "b": 1, "mt32_patch": 50, "gm_program": 50}])])
        rep, _, _ = lint(p)
        self.assertFalse(any("tier-1" in e and "switch" in e
                             for e in rep.errors))
        opl = next(iter(PATCHES))
        p = self._enh_path([dict(self._ch("pad", 1, [
            {"m": 16, "b": 1, "mt32_patch": 50, "gm_program": 50,
             "opl_patch": opl}]))])
        rep, _, _ = lint(p)
        self.assertTrue(any("opl_patch" in e for e in rep.errors))

    def test_enh_rhythm_switches_error(self):
        ch = self._ch("kit", 2, [{"m": 16, "b": 1, "gm_program": 49}],
                      rhythm=True)
        p = self._enh_path([ch])
        rep, _, _ = lint(p)
        self.assertTrue(any("rhythm" in e and "switch" in e
                            for e in rep.errors))

    def test_enh_string_timbre_switch_errors(self):
        import yaml_lint
        real = yaml_lint.load_timbre_names
        yaml_lint.load_timbre_names = lambda: {"Fake Timbre"}
        try:
            ch = self._ch("pad", 2, [
                {"m": 16, "b": 1, "mt32_program": "Fake Timbre",
                 "gm_program": 49}])
            p = self._enh_path([ch])
            rep, _, _ = lint(p)
            self.assertTrue(any("custom timbre" in e for e in rep.errors))
        finally:
            yaml_lint.load_timbre_names = real
        # ...while a factory name in the same slot is clean.
        ch = self._ch("pad", 2, [
            {"m": 16, "b": 1, "mt32_program": "Str Sect 1",
             "gm_program": 49}])
        p = self._enh_path([ch])
        rep, resolved, _ = lint(p)
        self.assertEqual(rep.errors, [])

    def test_enh_mid_note_and_gap(self):
        ch = self._ch("pad", 2, [
            {"m": 1, "b": 1.5, "mt32_program": 50, "gm_program": 50}],
            events=[{"m": 1, "b": 1, "d": 2, "n": 12}])
        p = self._enh_path([ch])
        rep, _, _ = lint(p)
        self.assertTrue(any("strictly inside" in e for e in rep.errors))
        # ...the same switch after the note (body, post-entry) is clean.
        ch = self._ch("pad", 2, [
            {"m": 3, "b": 1, "mt32_program": 50, "gm_program": 50}],
            events=[{"m": 1, "b": 1, "d": 2, "n": 12}])
        p = self._enh_path([ch])
        rep, resolved, _ = lint(p)
        self.assertEqual(rep.errors, [])
        self.assertEqual(rep.warnings, [])
        self.assertEqual([s.frame for s in resolved[0].switches], [222])

    def test_enh_pre_entry_warn(self):
        # key 12 (C0): far below every base pitch, so no unison static.
        ch = self._ch("pad", 2, [
            {"m": 3, "b": 1, "mt32_program": 50, "gm_program": 50}],
            events=[{"m": 16, "b": 1, "d": 1, "n": 12}])
        p = self._enh_path([ch])
        rep, _, _ = lint(p)
        self.assertTrue(any("pre-entry-holds-loop" in w
                            for w in rep.warnings))

    def test_enh_percussion_flip(self):
        # Percussive by GM program (113 = Tinkle Bell, no tag needed): a
        # switch to a pitched program flips the verdict (the tag would
        # dominate instead, so the flip needs the program verdict).
        ch = self._ch("hit", 2, [
            {"m": 16, "b": 1, "mt32_program": 50, "gm_program": 60}],
            gm_program=113)
        ch["events"] = [{"m": 16, "b": 1, "d": 1, "n": 60}]
        p = self._enh_path([ch])
        rep, _, _ = lint(p)
        self.assertTrue(any("flip" in e for e in rep.errors))
        ch["switches"] = [{"m": 16, "b": 1, "mt32_program": 50,
                           "gm_program": 114}]
        p = self._enh_path([ch])
        rep, _, _ = lint(p)
        self.assertFalse(any("flip" in e for e in rep.errors))

    def test_enh_unroll_dup_and_first_body(self):
        ch = self._ch("pad", 2, [
            {"m": 16, "b": 1, "mt32_program": 50, "gm_program": 50}])
        p = self._enh_path([ch], unroll=2)
        rep, resolved, _ = lint(p)
        self.assertEqual(rep.errors, [])
        self.assertEqual([s.frame for s in resolved[0].switches],
                         [1665, 3441])
        scoped = first_body_notes(resolved, self.analysis)
        self.assertEqual([s.frame for s in scoped[0].switches], [1665])

    def test_enh_divergence_warn(self):
        ch = dict(self._ch("ramp", 2, [
            {"m": 16, "b": 1, "mt32_program": 50, "gm_program": 50}]),
            evolving=True)
        p = self._enh_path([ch], unroll=2)
        rep, _, _ = lint(p)
        self.assertTrue(any("first-pass-divergence-confirm" in w
                            for w in rep.warnings))
        ch["switches"] = [{"m": 19, "b": 1, "mt32_program": 50,
                           "gm_program": 50}]
        p = self._enh_path([ch], unroll=2)
        rep, _, _ = lint(p)
        self.assertFalse(any("divergence" in w for w in rep.warnings))
        self.assertEqual(rep.errors, [])

    def test_enh_switches_add_zero_notes(self):
        ch = self._ch("pad", 2, [
            {"m": 16, "b": 1, "mt32_program": 50, "gm_program": 50}],
            events=[{"m": 16, "b": 1, "d": 1, "n": 12}])
        p = self._enh_path([ch])
        rep, resolved, _ = lint(p)
        self.assertEqual(len(resolved[0].notes), 1)
        self.assertFalse(any("partial" in w for w in rep.warnings))

    def test_enh_tracks_emission_and_drop(self):
        from yaml_lint import ResolvedChannel, ResolvedNote, ResolvedSwitch
        keep = ResolvedChannel("keep", 2, None, 49, 49, "center", 96,
                               False, False,
                               [ResolvedNote(1665, 50, 60, 96)],
                               [ResolvedSwitch(1665, 50, 50)])
        drop = ResolvedChannel("drop", 3, None, 49, 49, "center", 96,
                               False, False,
                               [ResolvedNote(1665, 50, 60, 96)],
                               [ResolvedSwitch(1665, 51, 51)])
        # Six melodic channels: the 6th (tier 3, "drop") is dropped with
        # its switches; the kept one emits tick-0 + timed 0xC0s.
        fill = [ResolvedChannel(f"f{i}", 2, None, 49, 49, "center", 96,
                                False, False,
                                [ResolvedNote(100, 10, 60, 96)], [])
                for i in range(4)]
        tracks = enhancement_tracks([keep] + fill + [drop], self.song,
                                    "mt32")
        self.assertEqual(len(tracks), 5)  # 5 parts; the tier-3 6th drops
        evs = track_events(self._write_tracks(tracks), b"enh keep tier2")
        pcs = [(t, b[0]) for t, s, b in evs if s == (0xC0 | 4)]
        self.assertEqual(pcs, [(0, 48), (1665, 49)])

    def _write_tracks(self, tracks):
        hdr = b"MThd" + struct.pack(">IHHH", 6, 1, len(tracks), 60)
        out = self.tmp / "enh_test.mid"
        out.write_bytes(hdr + b"".join(tracks))
        return out

    # -- audition ---------------------------------------------------------
    def _session(self, label="Music_Cities2", target="mt32"):
        # Import the way audition.py does (audio/ + audio/audition/ on the
        # path, plain `midi_renderer` module) — `import audition` would
        # grab audition.py instead of the audition/ package.
        if str(HERE / "audition") not in sys.path:
            sys.path.insert(0, str(HERE / "audition"))
        import midi_renderer as mr

        class FakeMidi:
            def __init__(self):
                self.sent = []

            def send(self, data):
                self.sent.append(bytes(data))

            def all_notes_off(self, channels=None):
                pass

        sess = mr.MidiSession.__new__(mr.MidiSession)
        song = (self.song if label == "Music_Cities2"
                else simulate_song(self.rom, self.amap, label,
                                   self.songs[label]))
        sess.song_label = label
        sess.target = target
        sess.base_song = song
        sess.ov = load_overrides(label)
        sess.loop_start = song.loop_start or 0
        sess.loop_end = song.end
        sess.total_frames = song.end
        sess.base_init_msgs = []
        sess.base_events = {}
        sess.base_timelines = {}
        sess.enh_init_msgs = []
        sess.enh_events = {}
        sess.enh_timelines = {}
        sess.enh_channels_list = []
        sess.enable_base = True
        sess.enable_enh = True
        sess.solo_enh = False
        sess.gb_sound = False
        sess.current_frame = 0
        sess.gb_events = {}
        sess.active_gb_notes = {}
        sess.gb_engine = None
        sess.gb_pcm = None
        sess.midi = FakeMidi()
        sess._compile_base()
        sess.midi.sent.clear()
        return sess

    def test_audition_base_timeline(self):
        sess = self._session()
        self.assertEqual(sess.base_timelines[2],
                         [(0, 88), (1443, 52), (1928, 88)])
        self.assertEqual(sess.base_timelines[1], [(0, 54)])
        self.assertEqual(sess.base_timelines[3], [(0, 57)])
        self.assertIn(bytes((0xC2, 52)), sess.base_events[1443])
        self.assertIn(bytes((0xC2, 88)), sess.base_events[1928])
        # re-sync at several points
        sess.send_init()
        self.assertIn(bytes((0xC2, 88)), sess.midi.sent)
        sess.midi.sent.clear()
        sess.send_init(1500)
        self.assertIn(bytes((0xC2, 52)), sess.midi.sent)
        self.assertNotIn(bytes((0xC2, 88)), sess.midi.sent)
        sess.midi.sent.clear()
        sess.send_init(sess.loop_start)
        self.assertIn(bytes((0xC2, 88)), sess.midi.sent)

    def test_audition_tick_loop_wrap_resync(self):
        sess = self._session()
        sess.current_frame = sess.total_frames - 1
        sess.tick()
        self.assertEqual(sess.current_frame, sess.loop_start)
        self.assertIn(bytes((0xC2, 88)), sess.midi.sent)

    def test_audition_smoke_approved_songs(self):
        for label in ("Music_Cities1", "Music_PalletTown",
                      "Music_Vermilion"):
            sess = self._session(label)
            for tl in sess.base_timelines.values():
                self.assertEqual(len(tl), 1)  # tick-0 only, no switches
            sess.send_init()
            sess.send_init(sess.current_frame + 10)

    def test_audition_enh_switches(self):
        sess = self._session()
        ch = self._ch("pad", 2, [
            {"m": 16, "b": 1, "mt32_program": 50, "gm_program": 50}],
            events=[{"m": 16, "b": 1, "d": 1, "n": 12}])
        p = self._enh_path([ch])
        sess.load_enhancement(p)
        self.assertEqual(sess.enh_timelines[4], [(0, 48), (1665, 49)])
        self.assertIn(bytes((0xC4, 49)), sess.enh_events[1665])
        # ...and a string mt32 switch is an ERROR here, not a silent
        # gm substitution.
        import yaml_lint
        real = yaml_lint.load_timbre_names
        yaml_lint.load_timbre_names = lambda: set()
        try:
            ch2 = self._ch("pad", 2, [
                {"m": 16, "b": 1, "mt32_program": "Str Sect 1",
                 "gm_program": 50}],
                events=[{"m": 16, "b": 1, "d": 1, "n": 12}])
            p2 = self._enh_path([ch2])
            # lint passes (factory name) — audition resolves it via the
            # shared helper exactly like the merge.
            sess.load_enhancement(p2)
            self.assertIn(bytes((0xC4, 48)), sess.enh_events[1665])
        finally:
            yaml_lint.load_timbre_names = real

    # -- compatibility ------------------------------------------------------
    def test_all_enhancements_lint_clean(self):
        files = sorted((HERE / "enhancements").glob("*.yaml"))
        self.assertEqual(len(files), 19)
        bad = []
        for path in files:
            rep, _, _ = lint(path)
            if rep.errors:
                bad.append((path.name, rep.errors))
        self.assertEqual(bad, [])

    def test_all_overrides_lint_clean(self):
        import gen_audio_data
        consts, _ = gen_audio_data.parse_music_constants()
        labels = {lbl for n, lbl in consts.items() if n.startswith("MUSIC_")}
        files = sorted((HERE / "overrides").glob("*.yaml"))
        canonical = [p for p in files if p.stem in labels]
        # 18 canonical on disk (the orphan Music_GymLeaderBattle_enh.yaml
        # matches no song label and is never read by load_overrides).
        self.assertEqual(len(canonical), 18)
        switched = {"Music_Cities2": {2: 2}, "Music_Celadon": {1: 2, 2: 2}}
        bad = []
        for path in canonical:
            rep, resolved = lint_overrides(path)
            if rep.errors:
                bad.append((path.name, rep.errors))
            if path.stem not in switched:
                self.assertEqual(resolved, {}, path.name)  # no switches yet
            else:
                self.assertEqual(
                    {c: len(v) for c, v in resolved.items()},
                    switched[path.stem], path.name)
        self.assertEqual(bad, [])


if __name__ == "__main__":
    unittest.main(verbosity=2)
