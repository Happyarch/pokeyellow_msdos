#!/usr/bin/env python3
"""opl_renderer.py — Host-side OPL3 renderer and stream coordinator.

Connects pret_audio (base GB channels), gen_enh_streams / yaml_lint (Tier 1),
and libnukedopl.so to produce bit-exact OPL3 FM audio at 49.7 kHz on the host.
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
LIB_PATH = AUDIO_DIR / "libnukedopl.so"

sys.path.insert(0, str(AUDIO_DIR))
from pret_audio import AudioROM
from gen_audio_data import parse_music_constants
from gen_opl_patches import PATCHES, PATCH_ORDER
from gb_to_midi import simulate_song, build_addr_map, songs_from_headers, NoteEv
from yaml_lint import lint

MOD_SLOTS = [0x00, 0x01, 0x02, 0x08, 0x09, 0x0A, 0x10, 0x11, 0x12]
PAN_BITS = {"left": 0x10, "right": 0x20, "center": 0x30}
POOL_SIZE = 10
POOL_OPL2_SAFE = 5


def ensure_synth_built():
    """Ensures libnukedopl.so is compiled."""
    if not LIB_PATH.exists():
        src = AUDITION_DIR / "opl_synth.cpp"
        nuked = ROOT / "dos_port" / "tools" / "dosbox-x" / "src" / "hardware" / "nukedopl.cpp"
        inc = ROOT / "dos_port" / "tools" / "dosbox-x" / "src" / "hardware"
        cmd = [
            "g++", "-O3", "-shared", "-fPIC",
            f"-I{inc}", str(nuked), str(src),
            "-o", str(LIB_PATH)
        ]
        subprocess.run(cmd, check=True)


def fnum_block(midi_note: int) -> tuple[int, int]:
    freq = 440.0 * 2 ** ((midi_note - 69) / 12)
    for block in range(8):
        fnum = round(freq * (1 << (20 - block)) / 49716)
        if fnum <= 1023:
            return fnum, block
    return 1023, 7


def carrier_level(patch_name: str, vel: int, volume: int) -> int:
    base_tl = PATCHES[patch_name][6] & 0x3F
    eff = min(127, vel * volume // 127)
    return min(63, base_tl + (127 - eff) // 8)


class OplEngine:
    def __init__(self, samplerate: int = 49716):
        ensure_synth_built()
        self.lib = ctypes.CDLL(str(LIB_PATH))
        self.lib.opl_create.restype = ctypes.c_void_p
        self.lib.opl_create.argtypes = [ctypes.c_uint32]
        self.lib.opl_destroy.argtypes = [ctypes.c_void_p]
        self.lib.opl_reset.argtypes = [ctypes.c_void_p, ctypes.c_uint32]
        self.lib.opl_write.argtypes = [ctypes.c_void_p, ctypes.c_uint16, ctypes.c_uint8]
        self.lib.opl_generate.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_uint32]

        self.samplerate = samplerate
        self.chip = self.lib.opl_create(samplerate)
        self.voice_patches = [None] * 18
        self.voice_fnums = [0] * 18
        self.voice_blocks = [0] * 18
        self.voice_keyed = [False] * 18
        self.frac_acc = 0.0

        # Max buffer for 1 frame @ 60Hz: 829 samples * 2 channels
        self.frame_buf = (ctypes.c_int16 * (1024 * 2))()
        self.reset()

    def __del__(self):
        if hasattr(self, "chip") and self.chip:
            self.lib.opl_destroy(self.chip)
            self.chip = None

    def reset(self):
        self.lib.opl_reset(self.chip, self.samplerate)
        # OPL3 mode + 2-op enable
        self.lib.opl_write(self.chip, 0x105, 0x01)
        self.lib.opl_write(self.chip, 0x001, 0x20)
        self.lib.opl_write(self.chip, 0x104, 0x00)
        self.voice_patches = [None] * 18
        self.voice_fnums = [0] * 18
        self.voice_blocks = [0] * 18
        self.voice_keyed = [False] * 18
        self.frac_acc = 0.0

    def write_reg(self, reg: int, val: int):
        self.lib.opl_write(self.chip, reg, val & 0xFF)

    def load_patch(self, voice: int, patch_name: str, pan: str = "center"):
        if voice < 0 or voice >= 18:
            return
        self.voice_patches[voice] = patch_name
        patch = PATCHES[patch_name]
        arr_base = 0x100 if voice >= 9 else 0x000
        v_local = voice % 9
        mod_slot = arr_base + MOD_SLOTS[v_local]
        car_slot = mod_slot + 3
        pan_b = PAN_BITS.get(pan, 0x30)

        # Modulator
        self.write_reg(0x20 + mod_slot, patch[0])
        self.write_reg(0x40 + mod_slot, patch[1])
        self.write_reg(0x60 + mod_slot, patch[2])
        self.write_reg(0x80 + mod_slot, patch[3])
        self.write_reg(0xE0 + mod_slot, patch[4])
        # Carrier
        self.write_reg(0x20 + car_slot, patch[5])
        self.write_reg(0x40 + car_slot, patch[6])
        self.write_reg(0x60 + car_slot, patch[7])
        self.write_reg(0x80 + car_slot, patch[8])
        self.write_reg(0xE0 + car_slot, patch[9])
        # Feedback / connection / pan
        self.write_reg(arr_base + 0xC0 + v_local, (patch[10] & 0x0F) | pan_b)

    def key_on(self, voice: int, midi_note: int, vel: int = 100, volume: int = 127):
        if voice < 0 or voice >= 18:
            return
        patch_name = self.voice_patches[voice] or "duty_50"
        tl = carrier_level(patch_name, vel, volume)
        arr_base = 0x100 if voice >= 9 else 0x000
        v_local = voice % 9
        car_slot = arr_base + MOD_SLOTS[v_local] + 3

        # Update carrier TL
        patch_ksl = PATCHES[patch_name][6] & 0xC0
        self.write_reg(0x40 + car_slot, patch_ksl | tl)

        fnum, block = fnum_block(midi_note)
        self.voice_fnums[voice] = fnum
        self.voice_blocks[voice] = block
        self.voice_keyed[voice] = True

        self.write_reg(arr_base + 0xA0 + v_local, fnum & 0xFF)
        self.write_reg(arr_base + 0xB0 + v_local, 0x20 | (block << 2) | ((fnum >> 8) & 0x03))

    def key_off(self, voice: int):
        if voice < 0 or voice >= 18 or not self.voice_keyed[voice]:
            return
        arr_base = 0x100 if voice >= 9 else 0x000
        v_local = voice % 9
        block = self.voice_blocks[voice]
        fnum = self.voice_fnums[voice]
        self.voice_keyed[voice] = False
        self.write_reg(arr_base + 0xB0 + v_local, (block << 2) | ((fnum >> 8) & 0x03))

    def generate_frame(self) -> bytes:
        """Generates one 60 Hz frame of stereo 16-bit PCM audio."""
        self.frac_acc += self.samplerate / 60.0
        samples = int(self.frac_acc)
        self.frac_acc -= samples
        self.lib.opl_generate(self.chip, ctypes.cast(self.frame_buf, ctypes.c_void_p), samples)
        return bytes(self.frame_buf)[:samples * 4]


class SongSession:
    """Coordinates base channels and enhancement stream for seamless live playback."""

    def __init__(self, song_label: str):
        self.song_label = song_label
        self.engine = OplEngine()
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
        self.loop_start = self.base_song.loop_start or 0
        self.loop_end = self.base_song.end or max((n.frame + n.dur for n in self.base_song.notes), default=600)
        self.total_frames = self.loop_end

        # Base notes per frame
        self.base_events: dict[int, list[tuple[str, int, any]]] = {}
        for n in self.base_song.notes:
            v = n.chan - 1 # 0: pulse1, 1: pulse2, 2: wave, 3: noise
            self.base_events.setdefault(n.frame, []).append(("on", v, (n.key, n.vel)))
            off_f = min(n.frame + n.dur, self.total_frames)
            self.base_events.setdefault(off_f, []).append(("off", v, None))

        # Setup base patches
        self.engine.load_patch(0, "duty_50", "center")
        self.engine.load_patch(1, "duty_50", "center")
        self.engine.load_patch(2, "wave", "center")
        self.engine.load_patch(3, "noise", "center")

        # Enhancement layers
        self.enh_events: dict[int, list[tuple[str, int, any]]] = {}
        self.enh_channels = []
        self.enable_base = True
        self.enable_enh = True
        self.solo_enh = False
        self.tier_filter = {1}
        self.current_frame = 0

    def load_enhancement(self, yaml_content: str | Path | None):
        """Compiles enhancement notes into pool voice events (voices 4-13)."""
        self.enh_events.clear()
        self.enh_channels.clear()
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
            print(f"  [OPL] Enhancement lint errors: {rep.errors}")
            return

        self.enh_channels = resolved
        tier1 = [c for c in resolved if c.tier in self.tier_filter and c.notes]
        if not tier1:
            return

        # Flatten notes with patch & pan
        notes = []
        for ci, ch in enumerate(tier1):
            patch = ch.opl_patch or "soft_pad"
            pan = ch.pan
            for n in ch.notes:
                notes.append((n.frame, n.dur, n.key, n.vel, ch.volume, patch, pan, ci))
        notes.sort()

        # Pool allocation (voices 4..13)
        free_at = [0] * POOL_SIZE
        last_voice = {}
        for frame, dur, key, vel, vol, patch, pan, ci in notes:
            v = last_voice.get(ci)
            if v is None or free_at[v] > frame:
                v = next((i for i in range(POOL_SIZE) if free_at[i] <= frame), None)
                if v is None:
                    continue # Polyphony cap reached
            last_voice[ci] = v
            free_at[v] = frame + dur
            opl_v = 4 + v # Voice 4..13

            self.enh_events.setdefault(frame, []).append(("on", opl_v, (key, vel, vol, patch, pan)))
            off_f = min(frame + dur, self.total_frames)
            self.enh_events.setdefault(off_f, []).append(("off", opl_v, None))

    def silence_enhancements(self):
        for v in range(4, 14):
            self.engine.key_off(v)

    def silence_base(self):
        for v in range(4):
            self.engine.key_off(v)

    def tick(self) -> bytes:
        """Services one 60 Hz frame and returns stereo PCM audio."""
        f = self.current_frame

        # Service Base Events
        if self.enable_base and not self.solo_enh:
            for ev_type, v, args in self.base_events.get(f, []):
                if ev_type == "on":
                    key, vel = args
                    self.engine.key_on(v, key, vel)
                elif ev_type == "off":
                    self.engine.key_off(v)
        else:
            self.silence_base()

        # Service Enhancement Events
        if self.enable_enh or self.solo_enh:
            for ev_type, opl_v, args in self.enh_events.get(f, []):
                if ev_type == "on":
                    key, vel, vol, patch, pan = args
                    self.engine.load_patch(opl_v, patch, pan)
                    self.engine.key_on(opl_v, key, vel, vol)
                elif ev_type == "off":
                    self.engine.key_off(opl_v)
        else:
            self.silence_enhancements()

        # Advance frame
        self.current_frame += 1
        if self.current_frame >= self.total_frames:
            self.current_frame = self.loop_start
            # Silence all voices on loop wrap to prevent stuck notes
            for v in range(18):
                self.engine.key_off(v)

        return self.engine.generate_frame()

    def seek_relative(self, frames: int):
        target = max(0, min(self.total_frames - 1, self.current_frame + frames))
        self.current_frame = target
        for v in range(18):
            self.engine.key_off(v)
