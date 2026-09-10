#!/usr/bin/env python3
"""midi_renderer.py — Host-side MIDI renderer and ALSA sequencer stream coordinator.

Coordinates base GB channels and Tier 1/2/3 enhancement streams for MT-32 and General MIDI,
supporting position-locked [Tab] A/B toggle, [Space] mute, [M] solo, and live hot-reload.
"""

from __future__ import annotations

import ctypes
import os
from pathlib import Path
import subprocess
import sys
import tempfile

AUDITION_DIR = Path(__file__).resolve().parent
AUDIO_DIR = AUDITION_DIR.parent
ROOT = AUDIO_DIR.parents[2]
MIDI_LIB_PATH = AUDIO_DIR / "libmidiout.so"

sys.path.insert(0, str(AUDIO_DIR))
from pret_audio import AudioROM
from gen_audio_data import parse_music_constants
from gb_to_midi import (
    simulate_song, build_addr_map, songs_from_headers, NoteEv, Song,
    load_overrides, chan_setting, DEFAULT_PROGRAM, DEFAULT_VOLUME,
    DEFAULT_DRUM_VELOCITY, drum_key, FREE_MELODIC_CH
)
from mt32_presets import resolve_program
from yaml_lint import lint

PAN_CC = {"left": 20, "right": 108, "center": 64}


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

        self.base_song = simulate_song(self.rom, self.amap, self.song_label, self.headers[self.song_label])
        self.ov = load_overrides(self.song_label)
        self.loop_start = self.base_song.loop_start or 0
        self.loop_end = self.base_song.end or max((n.frame + n.dur for n in self.base_song.notes), default=600)
        self.total_frames = self.loop_end

        self.base_init_msgs: list[bytes] = []
        self.base_events: dict[int, list[bytes]] = {}
        self.enh_init_msgs: list[bytes] = []
        self.enh_events: dict[int, list[bytes]] = {}
        self.enh_channels_list: list[int] = []

        self.enable_base = True
        self.enable_enh = True
        self.solo_enh = False
        self.current_frame = 0

        # Send SysEx setup if provided
        if sysex_setup:
            for msg in sysex_setup:
                self.midi.send(msg)

        self._compile_base()
        self.send_init()

    def _compile_base(self):
        self.base_events.clear()
        self.base_init_msgs.clear()
        prog_key = "mt32_program" if self.target == "mt32" else "gm_program"
        used = sorted(set(n.chan for n in self.base_song.notes))
        for gc in used:
            mc = 9 if gc == 4 else gc  # MIDI channel 1, 2, 3, or 9
            if gc != 4:
                prog = resolve_program(
                    chan_setting(self.ov, gc, prog_key,
                                 chan_setting(self.ov, gc, "program", DEFAULT_PROGRAM[gc])),
                    self.target, f"{self.base_song.label} ch{gc} {prog_key}")
                self.base_init_msgs.append(bytes((0xC0 | mc, prog)))
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

    def load_enhancement(self, yaml_content: str | Path | None):
        self.silence_enhancements()
        self.enh_events.clear()
        self.enh_init_msgs.clear()
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
            if not c.is_rhythm:
                self.enh_init_msgs.append(bytes((0xC0 | mc, prog)))
            self.enh_init_msgs.append(bytes((0xB0 | mc, 7, c.volume)))
            self.enh_init_msgs.append(bytes((0xB0 | mc, 10, PAN_CC.get(c.pan, 64))))

            for n in c.notes:
                off = min(n.frame + n.dur, self.total_frames)
                self.enh_events.setdefault(n.frame, []).append(bytes((0x90 | mc, n.key, n.vel)))
                self.enh_events.setdefault(off, []).append(bytes((0x80 | mc, n.key, 64)))

        if self.enable_enh or self.solo_enh:
            for msg in self.enh_init_msgs:
                self.midi.send(msg)

    def send_init(self):
        for msg in self.base_init_msgs:
            self.midi.send(msg)
        if self.enable_enh or self.solo_enh:
            for msg in self.enh_init_msgs:
                self.midi.send(msg)

    def silence_enhancements(self):
        self.midi.all_notes_off(self.enh_channels_list or FREE_MELODIC_CH)

    def silence_base(self):
        self.midi.all_notes_off([1, 2, 3, 9])

    def silence_all(self):
        self.midi.all_notes_off()

    def tick(self):
        f = self.current_frame
        if self.enable_base and not self.solo_enh:
            for msg in self.base_events.get(f, []):
                self.midi.send(msg)

        if self.enable_enh or self.solo_enh:
            for msg in self.enh_events.get(f, []):
                self.midi.send(msg)

        self.current_frame += 1
        if self.current_frame >= self.total_frames:
            self.current_frame = self.loop_start
            self.silence_all()
            self.send_init()

    def seek_relative(self, frames: int):
        target = max(0, min(self.total_frames - 1, self.current_frame + frames))
        self.silence_all()
        self.current_frame = target
        self.send_init()
