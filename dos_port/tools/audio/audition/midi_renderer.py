#!/usr/bin/env python3
"""midi_renderer.py — Host-side MIDI renderer and ALSA sequencer stream coordinator.

Coordinates base GB channels and Tier 1/2/3 enhancement streams for MT-32 and General MIDI,
supporting position-locked [Tab] A/B toggle, [Space] mute, [M] solo, and live hot-reload.
"""

from __future__ import annotations

import ctypes
import os
import time
from pathlib import Path
import subprocess
import sys
import tempfile

AUDITION_DIR = Path(__file__).resolve().parent
AUDIO_DIR = AUDITION_DIR.parent
ROOT = AUDIO_DIR.parents[2]
MIDI_LIB_PATH = AUDIO_DIR / "libmidiout.so"
CACHE_DIR = AUDIO_DIR / ".gb_cache"

sys.path.insert(0, str(AUDIO_DIR))
from pret_audio import AudioROM
from gen_audio_data import parse_music_constants
from gb_to_midi import (
    simulate_song, build_addr_map, songs_from_headers, NoteEv, Song,
    load_overrides, chan_setting, DEFAULT_PROGRAM, DEFAULT_VOLUME,
    DEFAULT_DRUM_VELOCITY, drum_key, FREE_MELODIC_CH, unroll_for,
    override_switch_events, build_program_timeline, program_at,
    resolve_switch_program
)
from mt32_presets import resolve_program
from yaml_lint import lint
from opl_renderer import (
    GbApuEngine, DRUM_PARAMS, midi_key_to_gb_freq, midi_key_to_gb_wave_freq
)

PAN_CC = {"left": 20, "right": 108, "center": 64}


def _msg_order(msg: bytes) -> int:
    """Playback order inside one frame: offs (0), prog/CC (1), ons (2)."""
    st = msg[0] & 0xF0
    if st == 0x80 or (st == 0x90 and msg[2] == 0):
        return 0
    if st == 0x90:
        return 2
    return 1


def ensure_midi_built():
    """Ensures libmidiout.so is compiled."""
    if not MIDI_LIB_PATH.exists():
        src = AUDITION_DIR / "midi_out.cpp"
        cmd = [
            "g++", "-O3", "-shared", "-fPIC",
            str(src), "-lasound",
            "-o", str(MIDI_LIB_PATH),
        ]
        subprocess.run(cmd, check=True)


class MidiOutClient:
    def __init__(self, dest_client: int, dest_port: int, client_name: str = "Audition"):
        ensure_midi_built()
        self.lib = ctypes.CDLL(str(MIDI_LIB_PATH))
        self.lib.midi_open.restype = ctypes.c_void_p
        self.lib.midi_open.argtypes = [ctypes.c_char_p, ctypes.c_int, ctypes.c_int]
        self.lib.midi_send_bytes.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int]
        self.lib.midi_all_notes_off.argtypes = [ctypes.c_void_p]
        self.lib.midi_close.argtypes = [ctypes.c_void_p]

        self.handle = self.lib.midi_open(client_name.encode("utf-8"), dest_client, dest_port)
        if not self.handle:
            raise RuntimeError(f"Failed to open ALSA MIDI sequencer port to {dest_client}:{dest_port}")

    def __del__(self):
        if hasattr(self, "handle") and self.handle:
            self.lib.midi_close(self.handle)
            self.handle = None

    def send(self, data: bytes):
        if getattr(self, "handle", None) and data:
            self.lib.midi_send_bytes(self.handle, data, len(data))

    def all_notes_off(self, channels: list[int] | None = None):
        if not getattr(self, "handle", None):
            return
        if channels is None:
            self.lib.midi_all_notes_off(self.handle)
        else:
            for ch in channels:
                self.send(bytes((0xB0 | ch, 123, 0)))  # All Notes Off
                self.send(bytes((0xB0 | ch, 120, 0)))  # All Sound Off


class MidiSession:
    """Coordinates base GB channels and enhancement stream for MT-32/GM live playback."""

    def __init__(self, song_label: str, target: str, port_str: str, sysex_setup: list[bytes] | None = None):
        self.song_label = song_label
        self.target = target
        parts = port_str.split(":")
        if len(parts) != 2:
            raise ValueError(f"Port must be client:port, got {port_str!r}")
        dest_client, dest_port = int(parts[0]), int(parts[1])
        self.midi = MidiOutClient(dest_client, dest_port, client_name=f"Audition-{target}")

        self.rom = AudioROM(ROOT)
        self.amap = build_addr_map(self.rom)
        self.headers = songs_from_headers(self.rom)
        if song_label not in self.headers:
            matches = [h for h in self.headers if song_label.lower() in h.lower()]
            if len(matches) == 1:
                self.song_label = matches[0]
            else:
                raise ValueError(f"Song {song_label!r} not found in headers {matches}")

        # Unrolled songs (loop ramp-and-hold) extend the base span and move
        # the loop region to the hold body, exactly like the asset merge —
        # otherwise the host session would wrap into the ramp tail. Reads
        # the saved file; a live-unsaved TUI buffer lags one save behind.
        self.base_song = simulate_song(self.rom, self.amap, self.song_label,
                                       self.headers[self.song_label],
                                       unroll_for(self.song_label))
        self.ov = load_overrides(self.song_label)
        self.loop_start = self.base_song.loop_start or 0
        self.loop_end = self.base_song.end or max((n.frame + n.dur for n in self.base_song.notes), default=600)
        self.total_frames = self.loop_end

        self.base_init_msgs: list[bytes] = []
        self.base_events: dict[int, list[bytes]] = {}
        self.base_timelines: dict[int, list[tuple[int, int]]] = {}
        self.enh_init_msgs: list[bytes] = []
        self.enh_events: dict[int, list[bytes]] = {}
        self.enh_timelines: dict[int, list[tuple[int, int]]] = {}
        self.enh_channels_list: list[int] = []

        self.enable_base = True
        self.enable_enh = True
        self.solo_enh = False
        self.current_frame = 0

        # Game Boy APU engine / pre-rendered PCM cache for authentic GB sound toggle
        cache_file = CACHE_DIR / "music" / f"{self.song_label}.pcm"
        if cache_file.exists():
            self.gb_pcm = cache_file.read_bytes()
            self.gb_engine = None
        else:
            self.gb_pcm = None
            self.gb_engine = None

        self.gb_sound = False
        self.gb_events: dict[int, list[tuple]] = {}
        self.active_gb_notes: dict[int, tuple] = {}

        # Send SysEx setup if provided, PACED: the live path used to blast
        # all messages back-to-back, and MUNT's emulated MIDI input drops
        # long uploads under burst — the small Patch Memory rewrite lands
        # while the 246-byte timbre upload vanishes, leaving a patch that
        # points at empty timbre memory (silent voice). Gaps mirror the
        # SMF path's SYSEX_GAP_TICKS (66 ms) + 1 s settle in audition.py,
        # and the in-game uploader sends paced for the same reason.
        if sysex_setup:
            for msg in sysex_setup:
                self.midi.send(msg)
                time.sleep(0.066)
            time.sleep(1.0)

        self._compile_base()
        self.send_init()

    def _compile_base(self):
        self.base_events.clear()
        self.base_init_msgs.clear()
        self.base_timelines.clear()
        self.gb_events.clear()
        self.active_gb_notes.clear()
        for n in self.base_song.notes:
            v = n.chan - 1  # 0: pulse1, 1: pulse2, 2: wave, 3: noise
            is_drum = (n.chan == 4)
            fade = getattr(n, "fade", 0)
            self.gb_events.setdefault(n.frame, []).append(("on", v, (n.key, n.vel, fade, is_drum)))
            off_f = min(n.frame + n.dur, self.total_frames)
            self.gb_events.setdefault(off_f, []).append(("off", v, None))

        prog_key = "mt32_program" if self.target == "mt32" else "gm_program"
        # Timed program switches, resolved through the ONE shared helper the
        # SMF merge uses (override_switch_events) — the .mid and the live
        # audition can never disagree on what a switch means.
        sw_evs = override_switch_events(self.base_song.label, self.ov,
                                        self.base_song, self.target)
        used = sorted(set(n.chan for n in self.base_song.notes))
        for gc in used:
            mc = 9 if gc == 4 else gc  # MIDI channel 1, 2, 3, or 9
            if gc != 4:
                prog = resolve_program(
                    chan_setting(self.ov, gc, prog_key,
                                 chan_setting(self.ov, gc, "program", DEFAULT_PROGRAM[gc])),
                    self.target, f"{self.base_song.label} ch{gc} {prog_key}")
                self.base_timelines[mc] = build_program_timeline(
                    prog, sw_evs.get(gc, []))
                for f, sprog in sw_evs.get(gc, []):
                    self.base_events.setdefault(f, []).append(bytes((0xC0 | mc, sprog)))
            vol = chan_setting(self.ov, gc, "volume", DEFAULT_VOLUME.get(gc, 100))
            pan = chan_setting(self.ov, gc, "pan", 64)
            self.base_init_msgs.append(bytes((0xB0 | mc, 7, vol)))
            self.base_init_msgs.append(bytes((0xB0 | mc, 10, pan)))

            for p in self.base_song.pans:
                if p.chan == gc and "pan" not in self.ov.get("channels", {}).get(gc, {}):
                    self.base_events.setdefault(p.frame, []).append(bytes((0xB0 | mc, 10, p.value)))

            drum_vel = self.ov.get("drums", {}).get("velocity", DEFAULT_DRUM_VELOCITY)
            for n in self.base_song.notes:
                if n.chan != gc:
                    continue
                key = drum_key(self.ov, n.key) if gc == 4 else n.key
                vel = drum_vel if gc == 4 else n.vel
                if 0 <= key <= 127:
                    off = min(n.frame + n.dur, self.total_frames)
                    self.base_events.setdefault(n.frame, []).append(bytes((0x90 | mc, key, vel)))
                    self.base_events.setdefault(off, []).append(bytes((0x80 | mc, key, 64)))

        # Stable off -> prog/CC -> on ordering inside each frame, matching
        # the .mid event order (midi_to_stream's parse order) — a switch on
        # a note edge must sound between the release and the attack.
        for f in self.base_events:
            self.base_events[f].sort(key=_msg_order)

    def load_enhancement(self, yaml_content: str | Path | None):
        self.silence_enhancements()
        self.enh_events.clear()
        self.enh_init_msgs.clear()
        self.enh_timelines.clear()
        self.enh_channels_list.clear()
        if not yaml_content:
            return

        if isinstance(yaml_content, str):
            with tempfile.NamedTemporaryFile(suffix=".yaml", mode="w", delete=False) as tf:
                tf.write(yaml_content)
                tf.flush()
                tmp_path = Path(tf.name)
            try:
                rep, resolved, analysis = lint(tmp_path)
            finally:
                tmp_path.unlink(missing_ok=True)
        else:
            rep, resolved, analysis = lint(yaml_content)

        if rep.errors:
            print(f"  [MIDI] Enhancement lint errors: {rep.errors}")
            return

        chans = sorted((c for c in resolved if c.notes), key=lambda c: c.tier)
        melodic_idx = 0
        for c in chans:
            if c.is_rhythm:
                mc = 9
            else:
                if melodic_idx >= len(FREE_MELODIC_CH):
                    continue
                mc = FREE_MELODIC_CH[melodic_idx]
                melodic_idx += 1

            self.enh_channels_list.append(mc)
            prog = c.gm_program - 1
            if self.target == "mt32" and not c.is_rhythm:
                if isinstance(c.mt32_patch, int):
                    prog = c.mt32_patch - 1
                elif isinstance(c.mt32_patch, str):
                    # Custom timbre by name: select its staged slot, exactly
                    # like the .mid merge does (gb_to_midi
                    # enhancement_tracks). Unknown names keep the gm
                    # fallback; lint gates them first.
                    try:
                        prog = resolve_program(c.mt32_patch, "mt32",
                                               f"enh {c.name}")
                    except ValueError:
                        pass
            if not c.is_rhythm:
                sw_list: list[tuple[int, int]] = []
                for sw in c.switches:
                    if sw.frame >= self.total_frames:
                        continue    # frame<end filtering, like the merge
                    # A string mt32 (custom timbre) raises here — switches
                    # ERROR where tick-0 silently falls back (lint gates
                    # this first, so the raise only fires on bypass).
                    sprog = resolve_switch_program(
                        sw.mt32, sw.gm, c.mt32_patch, c.gm_program,
                        sw.prog, None, self.target,
                        f"enh {c.name} switch", one_based=True)
                    sw_list.append((sw.frame, sprog))
                    self.enh_events.setdefault(sw.frame, []).append(
                        bytes((0xC0 | mc, sprog)))
                self.enh_timelines[mc] = build_program_timeline(prog, sw_list)
            self.enh_init_msgs.append(bytes((0xB0 | mc, 7, c.volume)))
            self.enh_init_msgs.append(bytes((0xB0 | mc, 10, PAN_CC.get(c.pan, 64))))

            for n in c.notes:
                off = min(n.frame + n.dur, self.total_frames)
                self.enh_events.setdefault(n.frame, []).append(bytes((0x90 | mc, n.key, n.vel)))
                self.enh_events.setdefault(off, []).append(bytes((0x80 | mc, n.key, 64)))

        for f in self.enh_events:
            self.enh_events[f].sort(key=_msg_order)

        if self.enable_enh or self.solo_enh:
            for mc, tl in self.enh_timelines.items():
                self.midi.send(bytes((0xC0 | mc,
                                      program_at(tl, self.current_frame))))
            for msg in self.enh_init_msgs:
                self.midi.send(msg)

    def send_init(self, at_frame: int | None = None):
        """Re-sync programs + controllers for `at_frame` (default: now).

        Every path that restarts or relocates playback comes through here so
        a mid-song program switch can never desync the audition from the
        .mid: resume / reload / seek / toggles send the program active NOW;
        the loop wrap sends the program active at loop_start. base_init_msgs
        / enh_init_msgs carry only volume/pan statics now — programs always
        go through the per-channel timelines."""
        f = self.current_frame if at_frame is None else at_frame
        for mc, tl in self.base_timelines.items():
            self.midi.send(bytes((0xC0 | mc, program_at(tl, f))))
        for msg in self.base_init_msgs:
            self.midi.send(msg)
        if self.enable_enh or self.solo_enh:
            for mc, tl in self.enh_timelines.items():
                self.midi.send(bytes((0xC0 | mc, program_at(tl, f))))
            for msg in self.enh_init_msgs:
                self.midi.send(msg)

    def silence_enhancements(self):
        self.midi.all_notes_off(self.enh_channels_list or FREE_MELODIC_CH)

    def silence_base(self):
        self.midi.all_notes_off([1, 2, 3, 9])

    def silence_all(self):
        self.midi.all_notes_off()
        if hasattr(self, "gb_engine") and self.gb_engine is not None:
            self.gb_engine.reset()

    def toggle_gb_sound(self) -> bool:
        self.gb_sound = not self.gb_sound
        if self.gb_sound:
            self.silence_all()
            if self.gb_pcm is None:
                if self.gb_engine is None:
                    self.gb_engine = GbApuEngine(samplerate=48000)
                for v, (key, vel, fade, is_drum) in self.active_gb_notes.items():
                    if is_drum or v == 3:
                        params = DRUM_PARAMS.get(key, (8, 1, 34))
                        init_vol, fade_period, nr43 = params
                        self.gb_engine.trigger_noise(nr43, vol=init_vol, fade_period=fade_period, fade_dir=0)
                    elif v in (0, 1):
                        gb_vol = min(15, max(1, (vel - 15) // 7))
                        fade_period = abs(fade) if fade != 0 else 0
                        fade_dir = 1 if fade < 0 else 0
                        freq = midi_key_to_gb_freq(key)
                        self.gb_engine.trigger_pulse(v, freq, duty=2, vol=gb_vol, fade_period=fade_period, fade_dir=fade_dir)
                    elif v == 2:
                        freq = midi_key_to_gb_wave_freq(key)
                        self.gb_engine.trigger_wave(freq, vol_code=1)
        else:
            if self.gb_engine is not None:
                self.gb_engine.reset()
            self.send_init()
        return self.gb_sound

    def resume_playback(self):
        if self.gb_sound:
            if self.gb_pcm is not None:
                return  # Direct PCM streaming needs no note state
            if self.gb_engine is None:
                self.gb_engine = GbApuEngine(samplerate=48000)
            for v, (key, vel, fade, is_drum) in self.active_gb_notes.items():
                if is_drum or v == 3:
                    params = DRUM_PARAMS.get(key, (8, 1, 34))
                    init_vol, fade_period, nr43 = params
                    self.gb_engine.trigger_noise(nr43, vol=init_vol, fade_period=fade_period, fade_dir=0)
                elif v in (0, 1):
                    gb_vol = min(15, max(1, (vel - 15) // 7))
                    fade_period = abs(fade) if fade != 0 else 0
                    fade_dir = 1 if fade < 0 else 0
                    freq = midi_key_to_gb_freq(key)
                    self.gb_engine.trigger_pulse(v, freq, duty=2, vol=gb_vol, fade_period=fade_period, fade_dir=fade_dir)
                elif v == 2:
                    freq = midi_key_to_gb_wave_freq(key)
                    self.gb_engine.trigger_wave(freq, vol_code=1)
        else:
            self.send_init()

    def reload_overrides(self):
        self.ov = load_overrides(self.song_label)
        self._compile_base()
        # Full re-sync (programs active NOW + statics): re-asserting a muted
        # channel's program is inaudible, and routing everything through
        # send_init keeps the one re-sync path honest.
        self.send_init()

    def tick(self) -> bytes | None:
        f = self.current_frame
        effective_enh = (self.enable_enh or self.solo_enh) and (not self.gb_sound)
        effective_base = self.enable_base and not self.solo_enh

        if self.gb_sound:
            self.silence_all()
            if self.gb_pcm is not None:
                frame_len = (48000 // 60) * 4
                offset = f * frame_len
                if offset + frame_len <= len(self.gb_pcm):
                    frame_pcm = self.gb_pcm[offset : offset + frame_len]
                else:
                    frame_pcm = b"\x00" * frame_len
            else:
                if self.gb_engine is None:
                    self.gb_engine = GbApuEngine(samplerate=48000)
                for ev_type, v, args in self.gb_events.get(f, []):
                    if ev_type == "on":
                        self.active_gb_notes[v] = args
                        key, vel, fade, is_drum = args
                        if is_drum or v == 3:
                            params = DRUM_PARAMS.get(key, (8, 1, 34))
                            init_vol, fade_period, nr43 = params
                            self.gb_engine.trigger_noise(nr43, vol=init_vol, fade_period=fade_period, fade_dir=0)
                        elif v in (0, 1):
                            gb_vol = min(15, max(1, (vel - 15) // 7))
                            fade_period = abs(fade) if fade != 0 else 0
                            fade_dir = 1 if fade < 0 else 0
                            freq = midi_key_to_gb_freq(key)
                            self.gb_engine.trigger_pulse(v, freq, duty=2, vol=gb_vol, fade_period=fade_period, fade_dir=fade_dir)
                        elif v == 2:
                            freq = midi_key_to_gb_wave_freq(key)
                            self.gb_engine.trigger_wave(freq, vol_code=1)
                    elif ev_type == "off":
                        self.active_gb_notes.pop(v, None)
                        self.gb_engine.silence_channel(v)
                frame_pcm = self.gb_engine.generate_frame()
        else:
            if effective_base:
                for msg in self.base_events.get(f, []):
                    self.midi.send(msg)

            if effective_enh:
                for msg in self.enh_events.get(f, []):
                    self.midi.send(msg)
            frame_pcm = None

        self.current_frame += 1
        if self.current_frame >= self.total_frames:
            self.current_frame = self.loop_start
            self.silence_all()
            if self.gb_sound:
                if self.gb_engine is not None:
                    self.gb_engine.reset()
            else:
                # Re-sync to the program active at loop_start (not tick-0):
                # the hold body may run under a switched program.
                self.send_init(self.loop_start)

        return frame_pcm

    def seek_relative(self, frames: int):
        target = max(0, min(self.total_frames - 1, self.current_frame + frames))
        self.silence_all()
        self.current_frame = target
        if self.gb_sound:
            if self.gb_engine is not None:
                self.gb_engine.reset()
        else:
            self.send_init()
