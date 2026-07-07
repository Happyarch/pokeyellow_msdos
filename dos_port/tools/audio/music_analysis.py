#!/usr/bin/env python3
"""music_analysis.py — deterministic pre-LLM song analysis (Phase E).

Runs BEFORE any LLM involvement (audio plan: "deterministic analysis before
the LLM; its job is 'given this harmonic structure, add orchestration'").
Consumes the same frame-exact simulation gb_to_midi.py uses (pret_audio IR →
ChanSim NoteEv lists) and writes one YAML per song to tools/audio/analysis/:

  grid       — the beat map the enhancement compiler + yaml_lint use to turn
               musical positions (measure/beat) into frames. Beat = quarter
               note = 48 engine length-units (note_type 12 sixteenth × 4 —
               invariant across speeds: speed 12 → len 1 = a 16th, speed 8 →
               len 1 = a 16th-triplet, 6 per quarter, still 48 units). Frame
               offsets are integrated through the song's tempo timeline.
               Measure 1 beat 1 = frame 0 (schema law; pickups shift bars).
  key        — Krumhansl-Schmuckler pitch-class correlation (duration
               weighted), top candidate + runner-up with scores.
  chords     — per half-measure template match over ch1-3 sounding pitches
               (duration-weighted, bass-aware), merged runs, Roman numerals
               relative to the detected key.
  melody     — which GB channel carries the melody (highest mean pitch of
               ch1/ch2), its range, and per-phrase contour.
  phrases    — melody-channel segmentation at rests ≥ half a beat.
  repeats    — measure-level repetition map (orchestrate-once tagging): for
               every measure, the earliest measure with identical content
               across all channels, plus maximal repeated spans.
  density    — per-channel note onsets per beat (overall and per measure).

Meter defaults to 4/4; songs in other meters get an entry in METER_OVERRIDES
(the grid, chords and repeats all key off it). The output directory is
generated data — regenerate at will, never hand-edit (the enhancement YAML
in enhancements/ is the hand-authored layer).
"""

from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass
from fractions import Fraction
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pret_audio import AudioROM                             # noqa: E402
from gb_to_midi import (                                    # noqa: E402
    NoteEv, Song, build_addr_map, simulate_song, songs_from_headers,
)

ANALYSIS_OUT = Path(__file__).resolve().parent / "analysis"

UNITS_PER_BEAT = 48          # engine length-units per quarter note

# Songs not in 4/4. Everything else assumes [4, 4]; add entries as the
# score-analysis descriptions (or your ears) identify them.
METER_OVERRIDES: dict[str, tuple[int, int]] = {
    # "Music_JigglypuffSong": (3, 4),
}

NOTE_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

# Krumhansl-Kessler key profiles (duration-weighted pc correlation).
KK_MAJOR = [6.35, 2.23, 3.48, 2.33, 4.38, 4.09,
            2.52, 5.19, 2.39, 3.66, 2.29, 2.88]
KK_MINOR = [6.33, 2.68, 3.52, 5.38, 2.60, 3.53,
            2.54, 4.75, 3.98, 2.69, 3.34, 3.17]

# Chord templates: name suffix -> (pc set relative to root, weight bonus for
# completeness). Triads before sevenths so ties prefer the simpler reading.
CHORD_TEMPLATES: list[tuple[str, frozenset[int]]] = [
    ("", frozenset({0, 4, 7})),          # major
    ("m", frozenset({0, 3, 7})),         # minor
    ("dim", frozenset({0, 3, 6})),
    ("aug", frozenset({0, 4, 8})),
    ("7", frozenset({0, 4, 7, 10})),
    ("maj7", frozenset({0, 4, 7, 11})),
    ("m7", frozenset({0, 3, 7, 10})),
]

MAJOR_DEGREES = {0: "I", 2: "II", 4: "III", 5: "IV", 7: "V", 9: "VI", 11: "VII"}
FLAT_OF = {1: "II", 3: "III", 6: "V", 8: "VI", 10: "VII"}


def note_name(midi: int) -> str:
    return f"{NOTE_NAMES[midi % 12]}{midi // 12 - 1}"      # C4 = 60


# ---------------------------------------------------------------------------
# Beat map
# ---------------------------------------------------------------------------
def build_grid(song: Song, tempo_at, meter: tuple[int, int]) -> dict:
    """Frame offset of every beat from frame 0 to song.end.

    Integrates 48 length-units per beat through the tempo timeline with
    exact rational arithmetic (frames = units * tempo / 256), rounding only
    on output — matches the engine within the ±1-frame frac wobble."""
    beats: list[int] = []
    f = Fraction(0)
    while f < song.end:
        beats.append(int(f))
        t = tempo_at(int(f))
        f += Fraction(UNITS_PER_BEAT * t, 256)
    per_measure = meter[0]
    return {
        "meter": list(meter),
        "units_per_beat": UNITS_PER_BEAT,
        "beats_per_measure": per_measure,
        "measures": (len(beats) + per_measure - 1) // per_measure,
        "beat_frames": beats,
    }


def pos_of(frame: int, grid: dict) -> tuple[int, float]:
    """frame -> (measure, beat), 1-based, fractional beat."""
    beats = grid["beat_frames"]
    lo, hi = 0, len(beats) - 1
    while lo < hi:                       # rightmost beat with frame <= target
        mid = (lo + hi + 1) // 2
        if beats[mid] <= frame:
            lo = mid
        else:
            hi = mid - 1
    span = (beats[lo + 1] - beats[lo]) if lo + 1 < len(beats) else 1
    frac = (frame - beats[lo]) / span if span else 0.0
    bpm = grid["beats_per_measure"]
    return lo // bpm + 1, lo % bpm + 1 + round(frac, 2)


# ---------------------------------------------------------------------------
# Key estimation
# ---------------------------------------------------------------------------
def estimate_key(notes: list[NoteEv]) -> dict:
    weights = [0.0] * 12
    for n in notes:
        if n.chan == 4:
            continue
        weights[n.key % 12] += n.dur
    total = sum(weights)
    if not total:
        return {"tonic": None, "mode": None, "score": 0.0}

    def corr(profile: list[float], rot: int) -> float:
        xs = [weights[(i + rot) % 12] for i in range(12)]
        mx, mp = sum(xs) / 12, sum(profile) / 12
        num = sum((x - mx) * (p - mp) for x, p in zip(xs, profile))
        dx = sum((x - mx) ** 2 for x in xs) ** 0.5
        dp = sum((p - mp) ** 2 for p in profile) ** 0.5
        return num / (dx * dp) if dx and dp else 0.0

    cands = [(corr(KK_MAJOR, r), r, "major") for r in range(12)]
    cands += [(corr(KK_MINOR, r), r, "minor") for r in range(12)]
    cands.sort(reverse=True)
    (s0, r0, m0), (s1, r1, m1) = cands[0], cands[1]
    return {
        "tonic": NOTE_NAMES[r0], "mode": m0, "score": round(s0, 3),
        "runner_up": {"tonic": NOTE_NAMES[r1], "mode": m1,
                      "score": round(s1, 3)},
        "ambiguous": bool(s0 - s1 < 0.05),
    }


# ---------------------------------------------------------------------------
# Chords
# ---------------------------------------------------------------------------
def roman(root_pc: int, quality: str, key: dict) -> str:
    if key["tonic"] is None:
        return "?"
    tonic = NOTE_NAMES.index(key["tonic"])
    deg = (root_pc - tonic) % 12
    if key["mode"] == "minor":           # natural-minor scale degrees
        base = {0: "I", 2: "II", 3: "III", 5: "IV", 7: "V", 8: "VI",
                10: "VII"}.get(deg)
        flat = {1: "bII", 4: "bIII", 6: "bV", 9: "bVI", 11: "bVII"}.get(deg)
    else:
        base = MAJOR_DEGREES.get(deg)
        flat = ("b" + FLAT_OF[deg]) if deg in FLAT_OF else None
    numeral = base or flat or "?"
    if quality in ("m", "m7", "dim"):
        numeral = numeral.lower()
    if quality == "dim":
        numeral += "°"
    elif quality in ("7", "maj7", "m7"):
        numeral += "7"
    elif quality == "aug":
        numeral += "+"
    return numeral


def segment_chords(notes: list[NoteEv], grid: dict, key: dict) -> list[dict]:
    """Best template match per half measure, merged over identical runs."""
    beats = grid["beat_frames"]
    bpm = grid["beats_per_measure"]
    half = max(1, bpm // 2)
    melodic = [n for n in notes if n.chan != 4]
    segs = []
    for start_idx in range(0, len(beats), half):
        a = beats[start_idx]
        b = beats[start_idx + half] if start_idx + half < len(beats) else None
        if b is None:
            b = a + (beats[-1] - beats[-2] if len(beats) > 1 else 1) * half
        w = [0.0] * 12
        bass_pitch, bass_w = None, 0.0
        for n in melodic:
            ov = min(n.frame + n.dur, b) - max(n.frame, a)
            if ov <= 0:
                continue
            w[n.key % 12] += ov
            if bass_pitch is None or n.key < bass_pitch or \
                    (n.key == bass_pitch and ov > bass_w):
                bass_pitch, bass_w = n.key, ov
        total = sum(w)
        if not total:
            segs.append(None)
            continue
        best = None
        for root in range(12):
            for qual, tpl in CHORD_TEMPLATES:
                inside = sum(w[(root + pc) % 12] for pc in tpl)
                covered = sum(1 for pc in tpl if w[(root + pc) % 12] > 0)
                if covered < max(2, len(tpl) - 1):
                    continue
                score = inside / total + 0.1 * (covered / len(tpl))
                if bass_pitch is not None and bass_pitch % 12 == root:
                    score += 0.15        # root position
                if best is None or score > best[0]:
                    best = (score, root, qual)
        if best is None:
            segs.append(None)
            continue
        _, root, qual = best
        segs.append((root, qual))

    out: list[dict] = []
    for i, seg in enumerate(segs):
        if seg is None:
            continue
        root, qual = seg
        m = (i * half) // bpm + 1
        b = (i * half) % bpm + 1
        name = NOTE_NAMES[root] + qual
        if out and out[-1]["chord"] == name:
            out[-1]["half_measures"] += 1
            continue
        out.append({"m": m, "b": b, "chord": name,
                    "roman": roman(root, qual, key), "half_measures": 1})
    return out


# ---------------------------------------------------------------------------
# Melody, phrases, contour
# ---------------------------------------------------------------------------
def pick_melody_channel(notes: list[NoteEv]) -> int:
    stats = {}
    for ch in (1, 2):
        ns = [n for n in notes if n.chan == ch]
        if ns:
            stats[ch] = sum(n.key * n.dur for n in ns) / sum(n.dur for n in ns)
    if not stats:
        return 1
    return max(stats, key=stats.get)


def contour_of(pitches: list[int]) -> str:
    if len(pitches) < 2:
        return "static"
    first, last, peak, valley = (pitches[0], pitches[-1],
                                 max(pitches), min(pitches))
    if peak > max(first, last) + 2:
        return "arch"
    if valley < min(first, last) - 2:
        return "valley"
    if last > first + 2:
        return "rising"
    if last < first - 2:
        return "falling"
    return "level"


def find_phrases(notes: list[NoteEv], mel_ch: int, grid: dict,
                 end: int) -> list[dict]:
    mel = sorted((n for n in notes if n.chan == mel_ch),
                 key=lambda n: n.frame)
    if not mel:
        return []
    beats = grid["beat_frames"]
    beat_len = beats[1] - beats[0] if len(beats) > 1 else 60
    phrases, cur = [], [mel[0]]
    for prev, n in zip(mel, mel[1:]):
        gap = n.frame - (prev.frame + prev.dur)
        if gap >= beat_len // 2:
            phrases.append(cur)
            cur = [n]
        else:
            cur.append(n)
    phrases.append(cur)
    out = []
    for ph in phrases:
        pitches = [n.key for n in ph]
        sm, sb = pos_of(ph[0].frame, grid)
        em, eb = pos_of(min(ph[-1].frame + ph[-1].dur, end - 1), grid)
        out.append({
            "start": {"m": sm, "b": sb}, "end": {"m": em, "b": eb},
            "notes": len(ph), "contour": contour_of(pitches),
            "range": [note_name(min(pitches)), note_name(max(pitches))],
        })
    return out


# ---------------------------------------------------------------------------
# Repetition map (orchestrate-once tagging)
# ---------------------------------------------------------------------------
def measure_fingerprints(notes: list[NoteEv], grid: dict) -> list[tuple]:
    beats = grid["beat_frames"]
    bpm = grid["beats_per_measure"]
    bounds = [beats[i] for i in range(0, len(beats), bpm)]
    bounds.append(bounds[-1] + (bounds[-1] - bounds[-2])
                  if len(bounds) > 1 else bounds[-1] + 1)
    fps = []
    for i in range(len(bounds) - 1):
        a, b = bounds[i], bounds[i + 1]
        evs = sorted((n.frame - a, n.chan, n.key, n.dur)
                     for n in notes if a <= n.frame < b)
        fps.append(tuple(evs))
    return fps


def repetition_map(fps: list[tuple]) -> dict:
    first: dict[tuple, int] = {}
    same_as = []
    for i, fp in enumerate(fps):
        j = first.setdefault(fp, i)
        same_as.append(j + 1)            # 1-based measures
    spans = []
    i = 0
    while i < len(same_as):
        if same_as[i] != i + 1:
            j = i
            while (j + 1 < len(same_as)
                   and same_as[j + 1] == same_as[j] + 1
                   and same_as[j + 1] != j + 2):
                j += 1
            spans.append({"measures": [i + 1, j + 1],
                          "same_as": [same_as[i], same_as[j]]})
            i = j + 1
        else:
            i += 1
    return {"measure_same_as": same_as, "repeated_spans": spans}


# ---------------------------------------------------------------------------
# Density
# ---------------------------------------------------------------------------
def densities(notes: list[NoteEv], grid: dict) -> dict:
    n_beats = max(1, len(grid["beat_frames"]))
    out = {}
    for ch in (1, 2, 3, 4):
        cnt = sum(1 for n in notes if n.chan == ch)
        if cnt:
            out[f"ch{ch}"] = round(cnt / n_beats, 2)
    return out


# ---------------------------------------------------------------------------
# Driver
# ---------------------------------------------------------------------------
def analyze(rom: AudioROM, amap, label: str, channels) -> dict:
    song = simulate_song(rom, amap, label, channels)
    meter = METER_OVERRIDES.get(label, (4, 4))

    # tempo lookup for the grid: re-derive from a fresh simulation's timeline
    # is overkill — the sealed timeline lives inside simulate_song; rebuild a
    # minimal one from note-exact data instead: simulate channel 1 again.
    from gb_to_midi import TempoTimeline, ChanSim
    tl = TempoTimeline()
    sim = ChanSim(rom, amap, channels[0][0], channels[0][1], tl,
                  tempo_owner=True, record_tempo=True)
    res = sim.run(until=song.end, detect_loop=True)
    if res == "loop":
        tl.seal(sim.intro_end, sim.period)

    grid = build_grid(song, tl.at, meter)
    key = estimate_key(song.notes)
    mel_ch = pick_melody_channel(song.notes)
    fps = measure_fingerprints(song.notes, grid)

    loop_pos = (pos_of(song.loop_start, grid)
                if song.loop_start is not None else None)
    return {
        "song": label,
        "frames": {"end": song.end, "loop_start": song.loop_start},
        "grid": grid,
        "loop": ({"m": loop_pos[0], "b": loop_pos[1]} if loop_pos else None),
        "key": key,
        "melody_channel": mel_ch,
        "chords": segment_chords(song.notes, grid, key),
        "phrases": find_phrases(song.notes, mel_ch, grid, song.end),
        "repeats": repetition_map(fps),
        "density": densities(song.notes, grid),
        "warnings": song.warnings + (
            ["meter assumed 4/4 (no METER_OVERRIDES entry)"]
            if label not in METER_OVERRIDES else []),
    }


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("songs", nargs="*",
                    help="song labels (default: every music header)")
    ap.add_argument("--print", action="store_true", dest="print_",
                    help="dump YAML to stdout instead of analysis/")
    args = ap.parse_args()

    rom = AudioROM()
    amap = build_addr_map(rom)
    songs = songs_from_headers(rom)
    targets = args.songs or sorted(songs)
    unknown = [s for s in targets if s not in songs]
    if unknown:
        ap.error(f"unknown songs: {unknown}; known: {sorted(songs)[:5]}…")

    ANALYSIS_OUT.mkdir(exist_ok=True)
    for label in targets:
        result = analyze(rom, amap, label, songs[label])
        text = yaml.safe_dump(result, sort_keys=False, width=100,
                              allow_unicode=True)
        if args.print_:
            print(f"# ==== {label} ====\n{text}")
        else:
            (ANALYSIS_OUT / f"{label}.yaml").write_text(text)
            k = result["key"]
            print(f"{label}: {k['tonic']} {k['mode']} "
                  f"({result['grid']['measures']} measures, "
                  f"{len(result['chords'])} chord segs, "
                  f"{len(result['phrases'])} phrases)")


if __name__ == "__main__":
    main()
