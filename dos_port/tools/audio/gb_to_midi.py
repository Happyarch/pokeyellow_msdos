#!/usr/bin/env python3
"""gb_to_midi.py — pret music IR → baseline SMF type-1 MIDI files (Phase B).

Interprets each song's channel command streams (via pret_audio.py's parsed
items and ChannelTimer, replicating the engine's note-delay accumulation
exactly) and writes one .mid per song to dos_port/assets/midi/<target>/.

Timing model: 1 MIDI tick = 1 engine frame (1/60 s). The SMF division is 60
ticks/quarter with a fixed tempo meta of 1,000,000 µs/quarter, so ticks are
frames and midi_to_stream.py recovers exact frame deltas. GB `tempo` commands
are folded into note durations (as the engine does), never into MIDI tempo.

Loop model: each channel is simulated until its infinite `sound_loop 0`
returns to an already-seen (position, state) pair, yielding (intro, period).
The song loop is period = lcm(channel periods) starting at the latest channel
intro end; `loopStart`/`loopEnd` marker meta events carry it to
midi_to_stream.py. The .mid itself contains intro + one full loop.

Channel → MIDI mapping: GB ch1/2/3 → MIDI channels 1/2/3 (0-based; MT-32
parts 1-3), noise ch4 → MIDI channel 9 (drums; MT-32 rhythm part). Note
numbers: pulse = pitch + 12*octave + 24 (octave 4 C_ = GB freq $705 ≈ 523 Hz
= C5 = 72 ✓); the wave channel sounds one octave lower for the same register
value, so ch3 = pitch + 12*octave + 12. Drum instrument ids (noise SFX ids)
map to GM drum notes via DEFAULT_DRUM_MAP + per-song overrides.

Hand-tuning lives in tools/audio/overrides/<SongLabel>.yaml (see the README
there); generated output is never edited by hand.
"""

from __future__ import annotations

import argparse
import math
import struct
import sys
from bisect import bisect_right
from itertools import combinations
from dataclasses import dataclass, field
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pret_audio import AudioROM, ChannelTimer, Cmd, Label  # noqa: E402
from gen_audio_data import parse_music_constants, sound_id  # noqa: E402
from mt32_presets import resolve_program  # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
MIDI_OUT = ROOT / "dos_port" / "assets" / "midi"
OVERRIDES_DIR = Path(__file__).resolve().parent / "overrides"

MAX_SIM_FRAMES = 60 * 60 * 20          # 20 min safety cap per channel
MAX_LOOP_FRAMES = 60 * 60 * 8          # unroll nested loops up to 8 min
DIVISION = 60                          # ticks/quarter; with 1e6 µs/quarter
TEMPO_USEC = 1_000_000                 # → 1 tick = 1 frame = 1/60 s

# GM programs (0-based) used for both targets until overrides tune them; the
# MT-32 default timbre bank uses different numbering — real MT-32 choices are
# hand-tuning work in overrides/ (auditioned via MUNT, Phase B tasks 3-4).
DEFAULT_PROGRAM = {1: 80, 2: 80, 3: 38}      # square lead ×2, synth bass
DEFAULT_VOLUME = {1: 100, 2: 96, 3: 110}     # CC7
DEFAULT_DRUM_VELOCITY = 100

# Noise-instrument id → GM drum note. First guess: pokeyellow's music drums
# are triangle/snare-ish noise bursts; refine per song in overrides.
DEFAULT_DRUM_MAP = {
    1: 42, 2: 38, 3: 38, 4: 38, 5: 38,       # hats/snares
    6: 36, 7: 36, 8: 36,                      # kicks
    9: 49, 10: 46, 11: 42, 12: 46,            # cymbal/open hat
    13: 41, 14: 43, 15: 45, 16: 47,           # toms
    17: 38, 18: 38, 19: 38,
}
DEFAULT_DRUM_NOTE = 38


# ---------------------------------------------------------------------------
# Events
# ---------------------------------------------------------------------------
@dataclass
class NoteEv:
    frame: int
    dur: int
    chan: int            # GB channel 1-4 (4 = noise/drums)
    key: int             # midi note, or noise instrument id when chan == 4
    vel: int


@dataclass
class PanEv:
    frame: int
    chan: int
    value: int           # CC10


class TempoTimeline:
    """Global music tempo as a function of frame, recorded from channel 1.

    After channel 1's loop is detected, lookups beyond the simulated range
    fold into the periodic region (tempo changes inside the loop repeat)."""

    def __init__(self):
        self.frames = [0]
        self.tempos = [0x0100]           # engine init value
        self.fold = None                 # (intro_end, period)

    def set(self, frame: int, tempo: int):
        if frame == self.frames[-1]:
            self.tempos[-1] = tempo
        else:
            self.frames.append(frame)
            self.tempos.append(tempo)

    def seal(self, intro_end: int, period: int):
        self.fold = (intro_end, period)

    def at(self, frame: int) -> int:
        if self.fold and frame >= self.fold[0] + self.fold[1]:
            frame = self.fold[0] + (frame - self.fold[0]) % self.fold[1]
        return self.tempos[bisect_right(self.frames, frame) - 1]


# ---------------------------------------------------------------------------
# Channel interpreter
# ---------------------------------------------------------------------------
class ChanSim:
    def __init__(self, rom: AudioROM, amap, gb_chan: int, start_label: str,
                 tempo: TempoTimeline, tempo_owner: bool,
                 record_tempo: bool):
        self.rom = rom
        self.amap = amap
        self.chan = gb_chan
        self.bank = rom.sym_bank[start_label]
        self.pc = rom.symtab[start_label]
        self.tempo = tempo
        self.tempo_owner = tempo_owner
        self.record_tempo = record_tempo
        self.stack: list[int] = []
        self.loopctr = 1
        self.timer = ChannelTimer()
        self.frame = 0
        self.octave = 1
        self.speed = 1
        self.vol = 15
        self.fade = 0
        self.notes: list[NoteEv] = []
        self.pans: list[PanEv] = []
        self.intro_end: int | None = None
        self.period: int | None = None
        self._snaps: dict[tuple, int] = {}

    # engine-visible state that can make a repeated pass render differently.
    # timer.frac is deliberately absent: the infinite-loop jump resets it to
    # 0 (see `sound_loop` below), so it is always 0 at snapshot time.
    def _state_key(self, target: int) -> tuple:
        return (target, self.octave, self.speed, self.vol, self.fade,
                self.loopctr, tuple(self.stack),
                self.tempo.at(self.frame))

    def _advance(self, length: int):
        t = self.tempo.at(self.frame)
        self.frame += self.timer.note_frames(length - 1, self.speed, t)

    def _velocity(self) -> int:
        if self.chan == 3:                    # NR32 output level 0-3
            return {0: 0, 1: 110, 2: 80, 3: 60}.get(self.vol, 96)
        if self.vol == 0:
            return 45 if self.fade else 0     # fade-in from silence
        return 15 + 7 * self.vol              # 1..15 → 22..120

    def _note_key(self, pitch: int) -> int:
        base = 12 if self.chan == 3 else 24   # wave sounds an octave lower
        return base + 12 * self.octave + pitch

    def run(self, until: int | None = None, detect_loop: bool = False) -> str:
        """Returns 'loop' (intro_end/period set), 'end', or 'horizon'."""
        while True:
            if self.frame > MAX_SIM_FRAMES:
                raise RuntimeError(f"chan {self.chan}: runaway simulation")
            if until is not None and self.frame >= until:
                return "horizon"
            it = self.amap.get((self.bank, self.pc))
            if not isinstance(it, Cmd):
                raise RuntimeError(
                    f"chan {self.chan}: no command at "
                    f"bank ${self.bank:02x}:{self.pc:04x} ({it!r})")
            name, a = it.name, it.args
            next_pc = self.pc + it.size

            if name == "note":
                if self.chan == 4:            # 1-byte drum form (unused)
                    self._emit_drum(a[0], a[1])
                else:
                    vel = self._velocity()
                    start = self.frame
                    self._advance(a[1])
                    if vel:
                        self.notes.append(NoteEv(
                            start, self.frame - start, self.chan,
                            self._note_key(a[0]), vel))
            elif name == "rest":
                self._advance(a[0])
            elif name == "drum_note":
                self._emit_drum(a[0], a[1])
            elif name in ("note_type", "drum_speed"):
                self.speed = a[0]
                if len(a) > 1:
                    self.vol, self.fade = a[1], a[2]
            elif name == "octave":
                self.octave = a[0]
            elif name == "tempo":
                if self.record_tempo:
                    self.tempo.set(self.frame, a[0])
                elif not self.tempo_owner:
                    raise RuntimeError(
                        f"tempo command on non-first channel {self.chan} — "
                        "the shared tempo timeline assumes the first header "
                        "channel owns tempo")
            elif name == "stereo_panning":
                bit = 1 << (self.chan - 1)
                left, right = a[0] & bit, a[1] & bit
                val = 64 if (left and right) or not (left or right) \
                    else (20 if left else 108)
                self.pans.append(PanEv(self.frame, self.chan, val))
            elif name == "sound_call":
                self.stack.append(next_pc)
                next_pc = self.rom.symtab[a[0]]
            elif name == "sound_loop":
                count, target = a
                if count == 0:
                    # Reset the fractional accumulator at the loop seam so
                    # every pass through the body renders identically (else
                    # frac can cycle for up to 256 passes before the state
                    # repeats — Music_CinnabarMansion does). Costs at most
                    # ±1 frame on the first note after the seam vs the real
                    # engine; the OPL path runs the real engine regardless.
                    self.timer.frac = 0
                    taddr = self.rom.symtab[target]
                    if detect_loop:
                        key = self._state_key(taddr)
                        if key in self._snaps:
                            self.intro_end = self._snaps[key]
                            self.period = self.frame - self.intro_end
                            return "loop"
                        self._snaps[key] = self.frame
                    next_pc = taddr
                elif self.loopctr == count:
                    self.loopctr = 1          # fall through
                else:
                    self.loopctr += 1
                    next_pc = self.rom.symtab[target]
            elif name == "sound_ret":
                if self.stack:
                    next_pc = self.stack.pop()
                else:
                    return "end"
            elif name in ("duty_cycle", "duty_cycle_pattern", "vibrato",
                          "toggle_perfect_pitch", "pitch_slide", "volume",
                          "execute_music"):
                pass                          # timbre/expression: no MIDI v1
            else:
                raise RuntimeError(
                    f"chan {self.chan}: unhandled command {name!r} at "
                    f"bank ${self.bank:02x}:{self.pc:04x}")
            self.pc = next_pc

    def _emit_drum(self, instrument: int, length: int):
        start = self.frame
        self._advance(length)
        if instrument:                        # id 0 = rest-like
            self.notes.append(NoteEv(start, self.frame - start, 4,
                                     instrument, DEFAULT_DRUM_VELOCITY))


# ---------------------------------------------------------------------------
# Song assembly
# ---------------------------------------------------------------------------
def build_addr_map(rom: AudioROM) -> dict:
    amap = {}
    for sec in rom.sections:
        addr = sec.start
        for sf in sec.files:
            for it in sf.items:
                if it.size:
                    amap.setdefault((sec.bank, addr), it)
                addr += it.size
    return amap


def songs_from_headers(rom: AudioROM) -> dict[str, list[tuple[int, str]]]:
    """Header label -> [(gb_channel, start_label), …], music headers only."""
    songs: dict[str, list[tuple[int, str]]] = {}
    for sec in rom.sections:
        if not sec.name.startswith("Music Headers"):
            continue
        cur = None
        for sf in sec.files:
            for it in sf.items:
                if isinstance(it, Label):
                    cur = it.name
                    songs[cur] = []
                elif isinstance(it, Cmd) and it.name == "channel":
                    hw = (it.encode(rom.symtab, 0)[0] & 0x0F) + 1
                    songs[cur].append((hw, it.args[0]))
    return {k: v for k, v in songs.items() if v}


@dataclass
class Song:
    label: str
    notes: list[NoteEv] = field(default_factory=list)
    pans: list[PanEv] = field(default_factory=list)
    loop_start: int | None = None
    end: int = 0                     # loop_start + period, or last note off
    warnings: list[str] = field(default_factory=list)


def simulate_song(rom: AudioROM, amap, label: str,
                  channels: list[tuple[int, str]]) -> Song:
    song = Song(label)
    tempo = TempoTimeline()

    # pass 1: per-channel loop detection (channel 1 records the tempo map)
    detect = []
    for i, (gc, start) in enumerate(channels):
        sim = ChanSim(rom, amap, gc, start, tempo,
                      tempo_owner=(i == 0), record_tempo=(i == 0))
        res = sim.run(until=MAX_SIM_FRAMES, detect_loop=True)
        if res == "horizon":
            raise RuntimeError(f"{label} ch{gc}: no loop/end before cap")
        detect.append((gc, res, sim))
        if i == 0 and res == "loop":
            tempo.seal(sim.intro_end, sim.period)

    periods = [s.period for _, r, s in detect if r == "loop"]
    intro_ends = [s.intro_end for _, r, s in detect if r == "loop"]
    finite_ends = [s.frame for _, r, s in detect if r == "end"]
    if periods:
        period = math.lcm(*periods)
        # Nested-loop songs (independent per-channel loop lengths) only
        # repeat exactly at the lcm of the channel periods — for
        # Music_Lavender that 18240f (~5 min) 80-measure meta-cycle IS the
        # piece, so unroll to it whenever it's stream-feasible; a shorter
        # seam phase-jumps the ostinato/drum channels back into sync.
        # The cap is absolute, not relative: Music_CinnabarMansion phases
        # 2328/1728/3888/216-frame loops whose lcm is ~7 hours — a flat
        # stream can't carry that, so it alone falls back to the longest
        # channel period and takes the phase-jump at the seam.
        if period > MAX_LOOP_FRAMES:
            # Partial unroll (Music_CinnabarMansion): the full lcm is ~7 h —
            # sq2's 2328f loop (the score's 21-9/16-bar "haphazard" figure)
            # carries a prime factor 97 no other channel shares. Choose the
            # subset of periods whose lcm fits the cap and leaves the MOST
            # channels seamless; only the leftovers phase-jump at the seam.
            # For Mansion: sq1/wave/noise unroll cleanly to 15552f (~4.3 min)
            # and only the deliberately unpredictable sq2 jumps — the one
            # channel a listener can't track anyway.
            full = period
            uniq = sorted(set(periods))
            best = (sum(1 for p in periods if max(periods) % p == 0),
                    max(periods))
            for r in range(len(uniq), 0, -1):
                for sub in combinations(uniq, r):
                    lcm = math.lcm(*sub)
                    if lcm <= MAX_LOOP_FRAMES:
                        cand = (sum(1 for p in periods if lcm % p == 0), lcm)
                        if cand > best:
                            best = cand
            period = best[1]
            jumping = sorted({p for p in periods if period % p})
            song.warnings.append(
                f"channel periods {uniq} have lcm {full}f > cap "
                f"{MAX_LOOP_FRAMES}f; partially unrolled to {period}f — "
                f"period(s) {jumping} phase-jump at the seam")
        elif period != max(periods):
            song.warnings.append(
                f"channel periods {sorted(set(periods))} differ; "
                f"unrolled to lcm {period}f for a seamless nested loop")
        loop_start = max(intro_ends + finite_ends)
        song.loop_start = loop_start
        song.end = loop_start + period
    # else: song.end set from notes below

    # pass 2: clean re-simulation to the song end (tempo map already known)
    for i, (gc, start) in enumerate(channels):
        sim = ChanSim(rom, amap, gc, start, tempo,
                      tempo_owner=(i == 0), record_tempo=False)
        sim.run(until=song.end if periods else None, detect_loop=False)
        song.notes += sim.notes
        song.pans += sim.pans

    if not periods:
        song.end = max((n.frame + n.dur for n in song.notes), default=0)

    if song.loop_start is not None:
        _rewind_loop(song)

    song.notes = [n for n in song.notes if n.frame < song.end]
    song.pans = [p for p in song.pans if p.frame < song.end]
    if song.loop_start is not None:
        for n in song.notes:
            if n.frame < song.loop_start < n.frame + n.dur:
                song.warnings.append(
                    f"ch{n.chan} note (key {n.key}) spans the loop point — "
                    "loop restart will retrigger it")
    return song


def _rewind_loop(song: Song):
    """Slide loop_start earlier while the preceding period is event-identical.

    Loop detection needs one full pass through the body before the state
    repeats, so it reports the loop one period late for songs whose body
    starts right after setup (most of them). Rewinding halves the emitted
    stream for those songs."""
    period = song.end - song.loop_start

    def window(a):
        evs = [(n.frame - a, n.chan, n.key, n.vel, n.dur)
               for n in song.notes if a <= n.frame < a + period]
        evs += [(p.frame - a, p.chan, "pan", p.value, 0)
                for p in song.pans if a <= p.frame < a + period]
        return sorted(evs)

    while song.loop_start - period >= 0 and \
            window(song.loop_start - period) == window(song.loop_start):
        song.loop_start -= period
        song.end -= period


# ---------------------------------------------------------------------------
# Overrides
# ---------------------------------------------------------------------------
def load_overrides(label: str) -> dict:
    path = OVERRIDES_DIR / f"{label}.yaml"
    if not path.exists():
        return {}
    data = yaml.safe_load(path.read_text()) or {}
    known = {"channels", "drums"}
    unknown = set(data) - known
    if unknown:
        raise ValueError(f"{path.name}: unknown top-level keys {unknown}")
    return data


def chan_setting(ov: dict, chan: int, key: str, default):
    return ov.get("channels", {}).get(chan, {}).get(key, default)


def drum_key(ov: dict, instrument: int) -> int:
    m = ov.get("drums", {}).get("map", {})
    return m.get(instrument,
                 DEFAULT_DRUM_MAP.get(instrument, DEFAULT_DRUM_NOTE))


# ---------------------------------------------------------------------------
# SMF writer (format 1, hand-rolled; stdlib only)
# ---------------------------------------------------------------------------
def vlq(n: int) -> bytes:
    out = [n & 0x7F]
    n >>= 7
    while n:
        out.append(0x80 | (n & 0x7F))
        n >>= 7
    return bytes(reversed(out))


def track_chunk(events: list[tuple[int, bytes]]) -> bytes:
    """events: (abs_tick, raw event bytes incl. status), pre-sorted."""
    data = bytearray()
    last = 0
    for tick, ev in events:
        data += vlq(tick - last) + ev
        last = tick
    data += vlq(0) + b"\xff\x2f\x00"          # end of track
    return b"MTrk" + struct.pack(">I", len(data)) + bytes(data)


def meta(mtype: int, payload: bytes) -> bytes:
    return bytes((0xFF, mtype)) + vlq(len(payload)) + payload


# ---------------------------------------------------------------------------
# Enhancement layer (Phase E) — see enhancements/README.md for the schema
# ---------------------------------------------------------------------------
PAN_CC = {"left": 20, "center": 64, "right": 108}
FREE_MELODIC_CH = [4, 5, 6, 7, 8]      # 0-based; base music uses 1-3 + 9


def load_enhancement(label: str):
    """Lint + resolve enhancements/<label>.yaml; None if absent or invalid.

    Lint errors are non-fatal for the batch: the song falls back to its
    base-only MIDI so `make assets`-style regeneration never breaks on a
    work-in-progress arrangement."""
    path = Path(__file__).resolve().parent / "enhancements" / f"{label}.yaml"
    if not path.exists():
        return None
    from yaml_lint import lint         # lazy: yaml_lint imports this module
    rep, resolved, _ = lint(path)
    if rep.errors:
        print(f"    ENHANCE: {path.name} failed lint — layer skipped:")
        for e in rep.errors:
            print(f"      ERROR: {e}")
        return None
    for w in rep.warnings:
        print(f"    ENHANCE warn: {w}")
    return resolved


def enhancement_tracks(resolved, song: Song, target: str) -> list[bytes]:
    """One SMF track per enhancement channel on the free melodic channels.

    Tier filter: stable-sorted by tier so when the added channels exceed
    the 5 free MT-32 melodic parts, whole layers drop lowest-priority
    (highest tier number) first — the plan's whole-layer drop, v1."""
    chans = sorted((c for c in resolved if c.notes), key=lambda c: c.tier)
    for c in chans[len(FREE_MELODIC_CH):]:
        print(f"    ENHANCE: dropped {c.name!r} (tier {c.tier}) — only "
              f"{len(FREE_MELODIC_CH)} free melodic parts")
    tracks = []
    for mc, c in zip(FREE_MELODIC_CH, chans):
        prog = c.gm_program - 1
        if target == "mt32":
            if isinstance(c.mt32_patch, int):
                prog = c.mt32_patch - 1
            else:
                print(f"    ENHANCE warn: {c.name!r} custom timbre "
                      f"{c.mt32_patch!r} not wired into the merge yet — "
                      "falling back to gm_program")
        evs: list[tuple[int, int, bytes]] = [
            (0, 1, meta(0x03, f"enh {c.name} tier{c.tier}".encode())),
            (0, 1, bytes((0xC0 | mc, prog))),
            (0, 1, bytes((0xB0 | mc, 7, c.volume))),
            (0, 1, bytes((0xB0 | mc, 10, PAN_CC[c.pan]))),
        ]
        for n in c.notes:
            off = min(n.frame + n.dur, song.end)
            evs.append((n.frame, 2, bytes((0x90 | mc, n.key, n.vel))))
            evs.append((off, 0, bytes((0x80 | mc, n.key, 64))))
        evs.sort(key=lambda e: (e[0], e[1]))
        tracks.append(track_chunk([(t, b) for t, _, b in evs]))
    return tracks


def write_midi(path: Path, song: Song, ov: dict, target: str, enhance=None):
    used = sorted({n.chan for n in song.notes})
    tracks = []

    ev0 = [(0, meta(0x51, struct.pack(">I", TEMPO_USEC)[1:])),
           (0, meta(0x03, song.label.encode()))]
    if song.loop_start is not None:
        ev0.append((song.loop_start, meta(0x06, b"loopStart")))
    ev0.append((song.end, meta(0x06, b"loopEnd")))
    ev0.sort(key=lambda e: e[0])
    tracks.append(track_chunk(ev0))

    prog_key = "mt32_program" if target == "mt32" else "gm_program"
    for gc in used:
        mc = 9 if gc == 4 else gc             # MIDI channel (0-based)
        evs: list[tuple[int, int, bytes]] = []  # (tick, order, bytes)
        evs.append((0, 1, meta(0x03, f"GB ch{gc}".encode())))
        if gc != 4:
            prog = resolve_program(
                chan_setting(ov, gc, prog_key,
                             chan_setting(ov, gc, "program",
                                          DEFAULT_PROGRAM[gc])),
                target, f"{song.label} ch{gc} {prog_key}")
            evs.append((0, 1, bytes((0xC0 | mc, prog))))
        vol = chan_setting(ov, gc, "volume", DEFAULT_VOLUME.get(gc, 100))
        pan = chan_setting(ov, gc, "pan", 64)
        evs.append((0, 1, bytes((0xB0 | mc, 7, vol))))
        evs.append((0, 1, bytes((0xB0 | mc, 10, pan))))
        for p in song.pans:
            if p.chan == gc and "pan" not in ov.get("channels", {}).get(gc, {}):
                evs.append((p.frame, 1, bytes((0xB0 | mc, 10, p.value))))
        drum_vel = ov.get("drums", {}).get("velocity", DEFAULT_DRUM_VELOCITY)
        for n in song.notes:
            if n.chan != gc:
                continue
            key = drum_key(ov, n.key) if gc == 4 else n.key
            vel = drum_vel if gc == 4 else n.vel
            if not 0 <= key <= 127:
                raise ValueError(f"{song.label} ch{gc}: key {key} out of range")
            off = min(n.frame + n.dur, song.end)
            evs.append((n.frame, 2, bytes((0x90 | mc, key, vel))))
            evs.append((off, 0, bytes((0x80 | mc, key, 64))))
        evs.sort(key=lambda e: (e[0], e[1]))
        tracks.append(track_chunk([(t, b) for t, _, b in evs]))

    if enhance:
        tracks += enhancement_tracks(enhance, song, target)

    hdr = b"MThd" + struct.pack(">IHHH", 6, 1, len(tracks), DIVISION)
    path.write_bytes(hdr + b"".join(tracks))


# ---------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--target", choices=("mt32", "gm"), default="mt32")
    ap.add_argument("--songs", help="substring filter on header labels")
    ap.add_argument("--no-enhance", action="store_true",
                    help="ignore enhancements/<Song>.yaml layers")
    args = ap.parse_args()

    rom = AudioROM(ROOT)
    amap = build_addr_map(rom)
    consts, _ = parse_music_constants()
    music_labels = {lbl for name, lbl in consts.items()
                    if name.startswith("MUSIC_") and lbl in rom.symtab}
    headers = songs_from_headers(rom)

    out_dir = MIDI_OUT / args.target
    out_dir.mkdir(parents=True, exist_ok=True)

    done = 0
    for label, channels in sorted(headers.items()):
        if label not in music_labels:
            continue                          # alternate entry points etc.
        if args.songs and args.songs not in label:
            continue
        song = simulate_song(rom, amap, label, channels)
        ov = load_overrides(label)
        enh = None if args.no_enhance else load_enhancement(label)
        write_midi(out_dir / f"{label}.mid", song, ov, args.target, enh)
        loop = (f"loop {song.loop_start}+{song.end - song.loop_start}f"
                if song.loop_start is not None else f"once {song.end}f")
        print(f"  {label:<28} {len(song.notes):5d} notes  {loop}"
              + (f"  [{sound_id(rom, label):3d}]" if label in rom.symtab else ""))
        for w in song.warnings:
            print(f"    WARNING: {w}")
        done += 1
    print(f"{done} songs -> {out_dir}")


if __name__ == "__main__":
    main()
