#!/usr/bin/env python3
"""yaml_lint.py — structural validation of enhancement YAML (Phase E).

Implements exactly the lint contract in enhancements/README.md (§1-8):
schema/song identity, tier/patch-field consistency, patch-reference
resolution, position/beat-map validity, note range, per-frame polyphony
budgets, unison-doubling against the base GB channels, and voice-budget
warnings.

Also the single source of truth for *resolving* an enhancement file:
`lint(path)` returns (report, resolved) where `resolved` maps every
channel to concrete frame-domain note events (transpose applied, patterns
instantiated, positions converted through the song's analysis beat map).
gb_to_midi's --enhance merge imports this — merge and lint can never
disagree.

Exit status: 0 clean (warnings are informational), 1 any error, 2 usage.
"""

from __future__ import annotations

import argparse
import math
import re
import sys
from dataclasses import dataclass, field, replace
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pret_audio import AudioROM                              # noqa: E402
from gb_to_midi import build_addr_map, simulate_song, songs_from_headers  # noqa: E402
import music_analysis                                        # noqa: E402
from gen_opl_patches import PATCHES                          # noqa: E402

HERE = Path(__file__).resolve().parent
ENHANCE_DIR = HERE / "enhancements"
ANALYSIS_DIR = HERE / "analysis"
TIMBRES_YAML = HERE / "mt32" / "timbres.yaml"

SCHEMA_VERSION = 1
PANS = {"left", "center", "right"}

# Usable MIDI note ranges (hard lint bounds; musical guidance is the
# skills' job). OPL3 fnum/block covers ~A0-C8; MT-32 keys 12-108.
RANGE_TIER1 = (21, 108)          # must be playable on OPL3 *and* MT-32
RANGE_TIER23 = (12, 108)         # MT-32/GM only

# Budgets (README §6/§8). OPL3: 18 voices - 4 shim music - 4 SFX overlap.
OPL_TIER1_HARD_MAX = 10          # simultaneous tier-1 sounding notes
OPL_TIER1_WARN = 6
MT32_PARTIALS_WARN = 30          # worst-case estimate, 2 partials/note
ADDED_PARTS_WARN = 5             # free MT-32 melodic parts

# GM programs (1-based) that are inherently percussion: Timpani (48) plus the
# whole GM "Percussive" family (113-120: tinkle bell, agogo, steel drums,
# woodblock, taiko, melodic tom, synth drum, reverse cymbal). A channel whose
# gm_program is in this set — or that sets `rhythm: true` (GM/MT-32 drum part
# on MIDI ch 10) or `percussion: true` (a percussion timbre on its own melodic
# channel) — is judged by ear, not by the pitched voice-leading rules: it may
# share pitches with the base melody, stack simultaneous hits in one channel,
# and ignore the melodic range. See _is_percussive().
PERCUSSION_PATCHES = {48, 113, 114, 115, 116, 117, 118, 119, 120}


def _is_percussive(ch: dict, gm, is_rhythm: bool) -> bool:
    """A channel is percussive if it routes to the drum part, is explicitly
    tagged, or names a GM percussion program. Intrinsic to the file — no
    caller opt-in — so the asset pipeline sees the same verdict a human does."""
    return (is_rhythm
            or bool(ch.get("percussion", False))
            or (isinstance(gm, int) and gm in PERCUSSION_PATCHES))


NOTE_RE = re.compile(r"^([A-Ga-g])([#b]?)(-?\d)$")
PC = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def parse_note(tok) -> int | None:
    """'C#4' / 'Db4' / raw MIDI int -> MIDI note (C4 = 60), None if bad."""
    if isinstance(tok, int):
        return tok if 0 <= tok <= 127 else None
    m = NOTE_RE.match(str(tok).strip())
    if not m:
        return None
    pc = PC[m.group(1).upper()] + {"#": 1, "b": -1, "": 0}[m.group(2)]
    val = (int(m.group(3)) + 1) * 12 + pc
    return val if 0 <= val <= 127 else None


@dataclass
class ResolvedNote:
    frame: int
    dur: int
    key: int                     # MIDI note
    vel: int


@dataclass
class ResolvedChannel:
    name: str
    tier: int
    opl_patch: str | None
    mt32_patch: int | str
    gm_program: int
    pan: str
    volume: int
    is_rhythm: bool = False
    is_percussion: bool = False
    notes: list[ResolvedNote] = field(default_factory=list)


@dataclass
class Report:
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)

    def err(self, msg: str):
        self.errors.append(msg)

    def warn(self, msg: str):
        self.warnings.append(msg)


class BeatMap:
    def __init__(self, grid: dict, end_frame: int,
                 loop_start: int | None = None,
                 loop_pos: dict | None = None):
        self.beats = grid["beat_frames"]
        self.bpm = grid["beats_per_measure"]
        self.end = end_frame
        self.span_end = end_frame    # lint() widens this for unroll > 1
        self.span_bodies = 1         # ...along with this, for messages
        # Loop-body geometry for unrolled (multi-iteration) songs. The body
        # is beats [body_start, len(beats)) = frames [loop_frame, end);
        # period folds any later beat index back into it. One-shots
        # (loop_start None) keep period None: past-the-end stays an error.
        self.period = None
        self.body_start = 0.0
        self.body_len = float(len(self.beats))
        self.loop_frame = 0
        if loop_start is not None and loop_pos is not None:
            self.loop_frame = loop_start
            self.body_start = self.index_of(loop_pos["m"],
                                            loop_pos.get("b", 1))
            # Total beats in intro + one body, from the musical length —
            # NOT len(beats): a beat map may omit the final (zero-width)
            # beat when nothing starts on it (m9b4 here: its frame IS end).
            total = grid["measures"] * grid["beats_per_measure"]
            self.body_len = total - self.body_start
            self.period = end_frame - loop_start

    def frame_at(self, beat_index: float) -> float:
        """Fractional beat index (0-based) -> frame, linear inside a beat.
        Past the one-body beat list, folds by loop period (unrolled songs);
        without a loop that stays out-of-song, caught by the caller."""
        f = float(beat_index)
        if self.period is not None and f >= len(self.beats):
            rel = f - self.body_start
            k = math.floor(rel / self.body_len + 1e-9)
            local = self.body_start + (rel - k * self.body_len)
            if local >= len(self.beats):
                # Past the listed beats: the omitted zero-width final beat
                # (its frame IS the body end). Continuous with the approach
                # from below, which interpolates beats[-1] -> end.
                return self.loop_frame + (k + 1) * self.period
            return (self.loop_frame + k * self.period
                    + (self._raw(local) - self.loop_frame))
        return self._raw(f)

    def _raw(self, f: float) -> float:
        i = int(f)
        frac = f - i
        if i >= len(self.beats):
            return float(self.end + 1)   # out of song → caught by caller
        base = self.beats[i]
        nxt = self.beats[i + 1] if i + 1 < len(self.beats) else self.end
        return base + frac * (nxt - base)

    def index_of(self, m: int, b: float) -> float:
        return (m - 1) * self.bpm + (b - 1)


def load_timbre_names() -> set[str]:
    try:
        t = yaml.safe_load(TIMBRES_YAML.read_text()) or {}
    except FileNotFoundError:
        return set()
    names = set()
    for entry in t.get("timbres") or []:
        if isinstance(entry, dict) and "name" in entry:
            names.add(str(entry["name"]))
    return names


def load_analysis(label: str) -> dict:
    """analysis/<label>.yaml, generated on the fly if absent."""
    p = ANALYSIS_DIR / f"{label}.yaml"
    if p.exists():
        return yaml.safe_load(p.read_text())
    rom = AudioROM()
    amap = build_addr_map(rom)
    songs = songs_from_headers(rom)
    return music_analysis.analyze(rom, amap, label, songs[label])


# ---------------------------------------------------------------------------
# Event resolution (shared with the gb_to_midi merge)
# ---------------------------------------------------------------------------
def _resolve_events(events, bm: BeatMap, base_transpose: int,
                    default_vel: int, patterns: dict, rep: Report,
                    ctx: str, at_measure: int = 0,
                    allow_patterns: bool = True) -> list[ResolvedNote]:
    out: list[ResolvedNote] = []
    for i, ev in enumerate(events or []):
        where = f"{ctx} event {i + 1}"
        if not isinstance(ev, dict):
            rep.err(f"{where}: not a mapping")
            continue
        if "pattern" in ev:
            if not allow_patterns:
                rep.err(f"{where}: nested pattern instance")
                continue
            pname = ev.get("pattern")
            pat = patterns.get(pname)
            if pat is None:
                rep.err(f"{where}: unknown pattern {pname!r}")
                continue
            at = ev.get("at")
            if not isinstance(at, int) or at < 1:
                rep.err(f"{where}: pattern instance needs integer at >= 1")
                continue
            tr = base_transpose + int(ev.get("transpose", 0))
            span = pat.get("measures")
            inst = _resolve_events(pat.get("events"), bm, tr, default_vel,
                                   patterns, rep, f"{ctx} pattern {pname}",
                                   at_measure=at - 1, allow_patterns=False)
            if isinstance(span, int):
                limit = bm.frame_at(bm.index_of(at + span, 1))
                for n in inst:
                    if n.frame + n.dur > limit:
                        rep.err(f"{where}: pattern {pname!r} events exceed "
                                f"its declared {span}-measure span")
                        break
            out += inst
            continue
        missing = [k for k in ("m", "b", "d", "n") if k not in ev]
        if missing:
            rep.err(f"{where}: missing {missing}")
            continue
        m, b, d = ev["m"], ev["b"], ev["d"]
        if not isinstance(m, int) or m < 1 or not isinstance(b, (int, float)) \
                or b < 1 or not isinstance(d, (int, float)) or d <= 0:
            rep.err(f"{where}: bad m/b/d ({m}/{b}/{d})")
            continue
        idx = bm.index_of(m + at_measure, b)
        f0 = bm.frame_at(idx)
        f1 = bm.frame_at(idx + d)
        if f1 > bm.span_end:
            nb = bm.span_bodies
            rep.err(f"{where}: m{m + at_measure} b{b} d{d} runs past the "
                    f"song end (frame {int(f1)} > {bm.span_end}); events must "
                    f"stay inside intro + {nb if nb > 1 else 'one'} "
                    f"loop body" + ("ies" if nb > 1 else ""))
            continue
        vel = ev.get("v", default_vel)
        if not isinstance(vel, int) or not 1 <= vel <= 127:
            rep.err(f"{where}: bad velocity {vel!r}")
            continue
        keys = ev["n"] if isinstance(ev["n"], list) else [ev["n"]]
        for tok in keys:
            key = parse_note(tok)
            if key is None:
                rep.err(f"{where}: bad note {tok!r}")
                continue
            out.append(ResolvedNote(int(round(f0)),
                                    max(1, int(round(f1 - f0))),
                                    key + base_transpose, vel))
    return out


def first_body_notes(resolved: list[ResolvedChannel],
                     analysis: dict) -> list[ResolvedChannel]:
    """Scoped view for the 1-body OPL path: intro + first loop body only.

    Unrolled files resolve the full span (lint + the MT-32/GM merge need
    it); the OPL enhancement stream loops a single body, so it must not
    see auto-duplicated copies or evolving later bodies. Returns new
    channels with notes filtered — verdicts were already recorded by
    lint(), this changes no judgment."""
    frames = analysis["frames"]
    if frames.get("loop_start") is None:
        return resolved
    cutoff = frames["end"]          # loop_start + one period by construction
    return [replace(c, notes=[n for n in c.notes
                              if n.frame + n.dur <= cutoff])
            for c in resolved]


# ---------------------------------------------------------------------------
# Lint proper
# ---------------------------------------------------------------------------
def lint(path: Path) -> tuple[Report, list[ResolvedChannel], dict]:
    rep = Report()
    try:
        doc = yaml.safe_load(path.read_text())
    except yaml.YAMLError as e:
        rep.err(f"YAML parse error: {e}")
        return rep, [], {}
    if not isinstance(doc, dict):
        rep.err("top level must be a mapping")
        return rep, [], {}

    # §1 identity
    if doc.get("schema") != SCHEMA_VERSION:
        rep.err(f"schema must be {SCHEMA_VERSION} (got {doc.get('schema')!r})")
    label = doc.get("song")
    if label != path.stem:
        rep.err(f"song {label!r} does not match filename {path.stem!r}")
    rom = AudioROM()
    songs = songs_from_headers(rom)
    if label not in songs:
        rep.err(f"unknown song label {label!r}")
        return rep, [], {}
    analysis = load_analysis(label)
    frames = analysis["frames"]
    bm = BeatMap(analysis["grid"], frames["end"],
                 frames.get("loop_start"), analysis.get("loop"))
    # Unrolled songs (loop ramp-and-hold): the file opts in with top-level
    # `unroll: N` (default 1). Positions may then address N loop bodies and
    # the lint span widens to loop_frame + N periods; the merged loop region
    # is the final body (see enhancements/README.md).
    unroll = doc.get("unroll", 1)
    if not isinstance(unroll, int) or unroll < 1:
        rep.err(f"unroll must be an integer >= 1 (got {doc.get('unroll')!r})")
        unroll = 1
    if unroll > 1:
        if bm.period is None:
            rep.err(f"unroll > 1 needs a looped song ({label} plays once)")
            unroll = 1
        else:
            bm.span_end = bm.loop_frame + unroll * bm.period
            bm.span_bodies = unroll

    patterns = doc.get("patterns") or {}
    if not isinstance(patterns, dict):
        rep.err("patterns: must be a mapping")
        patterns = {}

    timbre_names = load_timbre_names()
    chans_in = doc.get("channels")
    if not isinstance(chans_in, list) or not chans_in:
        rep.err("channels: must be a non-empty list")
        return rep, [], analysis

    resolved: list[ResolvedChannel] = []
    seen_names = set()
    for ci, ch in enumerate(chans_in):
        ctx = f"channel {ci + 1}"
        if not isinstance(ch, dict):
            rep.err(f"{ctx}: not a mapping")
            continue
        name = ch.get("name", f"#{ci + 1}")
        ctx = f"channel {name!r}"
        if name in seen_names:
            rep.err(f"{ctx}: duplicate name")
        seen_names.add(name)

        tier = ch.get("tier")
        if tier not in (1, 2, 3):
            rep.err(f"{ctx}: tier must be 1, 2 or 3 (got {tier!r})")
            continue

        # §2 tier/patch-field consistency, §3 references
        opl = ch.get("opl_patch")
        if tier == 1:
            if opl is None:
                rep.err(f"{ctx}: tier 1 requires opl_patch")
            elif opl not in PATCHES:
                rep.err(f"{ctx}: opl_patch {opl!r} not in gen_opl_patches "
                        f"PATCHES ({sorted(PATCHES)})")
        elif opl is not None:
            rep.err(f"{ctx}: tier {tier} must not carry opl_patch")

        is_rhythm = ch.get("rhythm", False)
        mt32 = ch.get("mt32_patch", 1 if is_rhythm else None)
        if isinstance(mt32, int):
            if not 1 <= mt32 <= 128:
                rep.err(f"{ctx}: mt32_patch {mt32} out of 1-128 (1-based)")
        elif isinstance(mt32, str):
            if mt32 not in timbre_names:
                rep.err(f"{ctx}: custom timbre {mt32!r} not defined in "
                        "mt32/timbres.yaml")
        else:
            rep.err(f"{ctx}: mt32_patch required (int 1-128 or timbre name)")

        gm = ch.get("gm_program", 1 if is_rhythm else None)
        if not isinstance(gm, int) or not 1 <= gm <= 128:
            rep.err(f"{ctx}: gm_program required, int 1-128 (1-based)")

        is_percussion = _is_percussive(ch, gm, is_rhythm)

        pan = ch.get("pan", "center")
        if pan not in PANS:
            rep.err(f"{ctx}: pan must be one of {sorted(PANS)}")
        volume = ch.get("volume", 96)
        if not isinstance(volume, int) or not 0 <= volume <= 127:
            rep.err(f"{ctx}: volume must be 0-127")
        velocity = ch.get("velocity", 96)
        transpose = ch.get("transpose", 0)
        if not isinstance(transpose, int):
            rep.err(f"{ctx}: transpose must be an integer")
            transpose = 0
        if is_rhythm and transpose:
            rep.err(f"{ctx}: rhythm channels route to the MIDI drum part where "
                    "the note number IS the drum — transpose would silently "
                    "remap every hit to a different drum; remove it")
            transpose = 0

        # Evolving channels author every loop iteration explicitly (ramps);
        # the rest author intro + one body and the compiler repeats the body.
        # Evolving tier 1 is unrepresentable: the OPL enhancement stream
        # plays exactly one loop body.
        evolving = bool(ch.get("evolving", False))
        if evolving and tier == 1:
            rep.err(f"{ctx}: evolving tier-1 channels can't loop-ramp — "
                    "the OPL enhancement stream plays exactly one loop body; "
                    "keep tier 1 identical every iteration (or ramp in tier 2+)")
        if evolving and unroll == 1:
            rep.warn(f"{ctx}: evolving set but unroll == 1 — flag has no effect")

        notes = _resolve_events(ch.get("events"), bm, transpose, velocity,
                                patterns, rep, ctx)
        if not notes:
            rep.warn(f"{ctx}: no notes")

        # §4 overlap within the channel. Melodic channels: chords go through
        # n-lists, so two *distinct* events overlapping is an authoring error.
        # Percussion stacks freely (kick + snare + hat share one channel);
        # only a same-key overlap is flagged there, since that would
        # retrigger/stick that one drum.
        if is_percussion:
            last_off: dict[int, int] = {}
            for n in sorted(notes, key=lambda n: (n.key, n.frame)):
                if n.frame < last_off.get(n.key, -1):
                    rep.err(f"{ctx}: percussion key {n.key} overlaps itself "
                            f"around frame {n.frame}")
                    break
                last_off[n.key] = n.frame + n.dur
        else:
            spans = sorted({(n.frame, n.frame + n.dur) for n in notes})
            for (a0, a1), (b0, b1) in zip(spans, spans[1:]):
                if b0 < a1:
                    rep.err(f"{ctx}: overlapping events at frames {a0}-{a1} "
                            f"and {b0}-{b1}")
                    break

        # §5 range — a melodic constraint. Percussion note numbers are drum
        # indices (ch-10) or hits on a percussion timbre, bounded to 0-127 by
        # parse_note and judged by ear, so the tier pitch window doesn't apply.
        if not is_percussion:
            lo, hi = RANGE_TIER1 if tier == 1 else RANGE_TIER23
            for n in notes:
                if not lo <= n.key <= hi:
                    rep.err(f"{ctx}: note {n.key} (frame {n.frame}) outside "
                            f"tier-{tier} range {lo}-{hi} after transpose")
                    break

        # Unroll auto-duplication: non-evolving channels author intro + one
        # body; the compiler repeats the body across iterations. Evolving
        # channels author every iteration explicitly. Duplicated copies are
        # exact offsets of lint-clean notes against periodic-identical base
        # content, so §7 needs no re-check on the copies.
        if unroll > 1 and not evolving:
            # unroll > 1 implies a looped song (enforced above), so period
            # is set; the assert is for the type checker, not the runtime.
            assert bm.period is not None
            duped: list[ResolvedNote] = []
            for n in notes:
                if n.frame < bm.loop_frame:
                    continue            # intro plays once
                if n.frame + n.dur > bm.loop_frame + bm.period:
                    rep.err(f"{ctx}: note at frame {n.frame} crosses the "
                            f"loop-body end — non-evolving channels can't "
                            f"span bodies (shorten it or set evolving: true)")
                    break
                for k in range(1, unroll):
                    duped.append(ResolvedNote(n.frame + k * bm.period,
                                              n.dur, n.key, n.vel))
            notes = sorted(notes + duped, key=lambda n: (n.frame, n.key))

        resolved.append(ResolvedChannel(name, tier, opl if tier == 1 else
                                        None, mt32, gm, pan, volume,
                                        is_rhythm, is_percussion, notes))

    # base song (for §6 polyphony and §7 unison doubling)
    amap = build_addr_map(rom)
    base = simulate_song(rom, amap, label, songs[label])
    base_mel = [n for n in base.notes if n.chan != 4]

    # §7 unison doubling — a pitched voice-leading rule, so it does not apply
    # to percussion (drums/hits share pitches by nature). Exemption is keyed
    # off the file itself (rhythm / percussion / GM percussion program) so the
    # asset pipeline enforces exactly what a human running the linter sees.
    for ch in resolved:
        if ch.is_percussion:
            continue
        for n in ch.notes:
            hit = next((b for b in base_mel if b.key == n.key
                        and b.frame < n.frame + n.dur
                        and n.frame < b.frame + b.dur), None)
            if hit:
                rep.err(f"channel {ch.name!r}: unison-doubles base ch"
                        f"{hit.chan} (MIDI {n.key}) around frame {n.frame} "
                        "— double at the octave instead")
                break

    # §6 polyphony (sweep note edges)
    def max_simultaneous(notes_list) -> int:
        edges = sorted([(n.frame, 1) for n in notes_list]
                       + [(n.frame + n.dur, -1) for n in notes_list])
        cur = peak = 0
        for _, d in edges:
            cur += d
            peak = max(peak, cur)
        return peak

    t1_notes = [n for c in resolved if c.tier == 1 for n in c.notes]
    peak1 = max_simultaneous(t1_notes)
    if peak1 > OPL_TIER1_HARD_MAX:
        rep.err(f"tier-1 peak polyphony {peak1} exceeds the OPL3 budget "
                f"({OPL_TIER1_HARD_MAX} = 18 - 4 shim - 4 SFX overlap)")
    elif peak1 > OPL_TIER1_WARN:
        rep.warn(f"tier-1 peak polyphony {peak1} > recommended "
                 f"{OPL_TIER1_WARN}")

    all_added = [n for c in resolved for n in c.notes]
    worst = max_simultaneous(all_added + base_mel) * 2   # ≈2 partials/note
    if worst > MT32_PARTIALS_WARN:
        rep.warn(f"worst-case MT-32 partial estimate {worst} > "
                 f"{MT32_PARTIALS_WARN} (2/note incl. base) — voice "
                 "stealing likely at peaks")

    # §8 budgets
    if sum(1 for c in resolved if c.tier == 1) > 6:
        rep.warn("more than 6 tier-1 channels (skill budget is 4-6)")
    n_melodic = sum(1 for c in resolved if not c.is_rhythm)
    if n_melodic > ADDED_PARTS_WARN:
        rep.warn(f"{n_melodic} melodic added channels > {ADDED_PARTS_WARN} free "
                 "MT-32 melodic parts — the compiler will drop tiers "
                 "(rhythm channels fold onto the drum part and don't count)")

    return rep, resolved, analysis


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("files", nargs="+", type=Path,
                    help="enhancement YAML file(s) (enhancements/<Song>.yaml)")
    args = ap.parse_args()
    failed = False
    for path in args.files:
        rep, resolved, _ = lint(path)
        n_notes = sum(len(c.notes) for c in resolved)
        status = "FAIL" if rep.errors else "ok"
        print(f"{path.name}: {status} — {len(resolved)} channels, "
              f"{n_notes} notes, {len(rep.errors)} errors, "
              f"{len(rep.warnings)} warnings")
        for e in rep.errors:
            print(f"  ERROR: {e}")
        for w in rep.warnings:
            print(f"  warn:  {w}")
        failed |= bool(rep.errors)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
