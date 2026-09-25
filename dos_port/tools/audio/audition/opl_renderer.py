#!/usr/bin/env python3
"""opl_renderer.py — Host-side OPL3 renderer and stream coordinator.

Connects pret_audio (base GB channels), gen_enh_streams / yaml_lint (Tier 1),
and libnukedopl.so to produce bit-exact OPL3 FM audio at 49.7 kHz on the host.
"""

from __future__ import annotations

import ctypes
import struct
import os
from pathlib import Path
import subprocess
import sys
import tempfile

AUDITION_DIR = Path(__file__).resolve().parent
AUDIO_DIR = AUDITION_DIR.parent
ROOT = AUDIO_DIR.parents[2]
LIB_PATH = AUDIO_DIR / "libnukedopl.so"
GB_LIB_PATH = AUDIO_DIR / "libgbapu.so"
CACHE_DIR = AUDIO_DIR / ".gb_cache"

sys.path.insert(0, str(AUDIO_DIR))
from pret_audio import AudioROM
from gen_audio_data import parse_music_constants
from gen_opl_patches import PATCHES, PATCH_ORDER
from gb_to_midi import simulate_song, build_addr_map, songs_from_headers, NoteEv
from yaml_lint import lint, first_body_notes

MOD_SLOTS = [0x00, 0x01, 0x02, 0x08, 0x09, 0x0A, 0x10, 0x11, 0x12]
PAN_BITS = {"left": 0x10, "right": 0x20, "center": 0x30}
POOL_SIZE = 10
POOL_OPL2_SAFE = 5


OPL_VOL_TABLE = [63, 31, 23, 19, 15, 13, 11, 9, 7, 6, 5, 4, 3, 2, 1, 0]

# Global FM noise-voice trim, OPL TL units (~0.75 dB each). GB noise through
# FM is harsher than the GB LFSR at equal TL and sat over every mix
# (Routes1 audition 2026-09-19). Mirrors NOISE_V3_TRIM in
# dos_port/src/audio/opl_shim.asm (voice_volume); tune by ear in both.
NOISE_V3_TRIM = 6

DRUM_PARAMS: dict[int, tuple[int, int, int]] = {
    1: (12, 1, 51),
    2: (11, 1, 51),
    3: (10, 1, 51),
    4: (8, 1, 51),
    5: (8, 4, 55),
    6: (5, 1, 42),
    7: (4, 1, 43),
    8: (8, 1, 16),
    9: (8, 2, 35),
    10: (8, 2, 37),
    11: (8, 2, 38),
    12: (10, 1, 16),
    13: (10, 2, 17),
    14: (10, 2, 80),
    15: (10, 1, 24),
    16: (9, 1, 40),
    17: (9, 1, 34),
    18: (7, 1, 34),
    19: (6, 1, 34),
}


def ensure_synth_built():
    """Ensures libnukedopl.so and libgbapu.so are compiled."""
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

    if not GB_LIB_PATH.exists():
        build_script = AUDIO_DIR / "build_gb_apu.sh"
        subprocess.run(["bash", str(build_script)], check=True)


class GbApuEngine:
    """CTypes wrapper around Shay Green's Basic_Gb_Apu (Gb_Snd_Emu)."""
    def __init__(self, samplerate: int = 49716):
        ensure_synth_built()
        self.samplerate = samplerate
        self.lib = ctypes.CDLL(str(GB_LIB_PATH))
        self.lib.gb_apu_create.restype = ctypes.c_void_p
        self.lib.gb_apu_create.argtypes = [ctypes.c_long]
        self.lib.gb_apu_destroy.argtypes = [ctypes.c_void_p]
        self.lib.gb_apu_reset.argtypes = [ctypes.c_void_p]
        self.lib.gb_apu_write.argtypes = [ctypes.c_void_p, ctypes.c_uint16, ctypes.c_uint8]
        self.lib.gb_apu_end_frame.argtypes = [ctypes.c_void_p]
        self.lib.gb_apu_samples_avail.restype = ctypes.c_long
        self.lib.gb_apu_samples_avail.argtypes = [ctypes.c_void_p]
        self.lib.gb_apu_read_samples.restype = ctypes.c_long
        self.lib.gb_apu_read_samples.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_int16), ctypes.c_long]

        self.chip = self.lib.gb_apu_create(self.samplerate)

    def __del__(self):
        if hasattr(self, "chip") and self.chip:
            self.lib.gb_apu_destroy(self.chip)
            self.chip = None

    def reset(self):
        if self.chip:
            self.lib.gb_apu_reset(self.chip)

    def write_reg(self, addr: int, val: int):
        if self.chip:
            self.lib.gb_apu_write(self.chip, addr, val)

    def end_frame(self):
        if self.chip:
            self.lib.gb_apu_end_frame(self.chip)

    def generate_frame(self) -> bytes:
        if not self.chip:
            return b""
        self.end_frame()
        avail = self.lib.gb_apu_samples_avail(self.chip)
        if avail <= 0:
            return b""
        buf = (ctypes.c_int16 * avail)()
        read = self.lib.gb_apu_read_samples(self.chip, buf, avail)
        # Normalize GB APU chip output to NukedOPL3 chip output level.
        # Measured: GB is ~1.8× louder RMS at full scale across music+SFX.
        # Scale=0.55 gives GB/OPL RMS ≈ 0.94 average — real loudness differences
        # remain audible; this corrects the systematic chip-level offset only.
        GB_LEVEL_SCALE = 0.55
        raw = ctypes.string_at(buf, read * 2)
        samples = struct.unpack(f"<{read}h", raw)
        scaled = struct.pack(f"<{read}h",
            *[max(-32768, min(32767, int(s * GB_LEVEL_SCALE))) for s in samples])
        return scaled


    def trigger_pulse(self, chan: int, freq: int, duty: int = 2, vol: int = 15, fade_period: int = 0, fade_dir: int = 0):
        base = 0xFF10 if chan == 0 else 0xFF15
        d_val = (duty & 3) << 6
        env_val = ((vol & 0x0F) << 4) | ((fade_dir & 1) << 3) | (fade_period & 7)
        freq_lo = freq & 0xFF
        freq_hi = 0x80 | ((freq >> 8) & 0x07)
        self.write_reg(base + 1, d_val)
        self.write_reg(base + 2, env_val)
        self.write_reg(base + 3, freq_lo)
        self.write_reg(base + 4, freq_hi)

    def trigger_wave(self, freq: int, vol_code: int = 1):
        self.write_reg(0xFF1A, 0x80)
        self.write_reg(0xFF1C, (vol_code & 3) << 5)
        self.write_reg(0xFF1D, freq & 0xFF)
        self.write_reg(0xFF1E, 0x80 | ((freq >> 8) & 0x07))

    def trigger_noise(self, nr43: int, vol: int = 15, fade_period: int = 0, fade_dir: int = 0):
        env_val = ((vol & 0x0F) << 4) | ((fade_dir & 1) << 3) | (fade_period & 7)
        self.write_reg(0xFF21, env_val)
        self.write_reg(0xFF22, nr43 & 0xFF)
        self.write_reg(0xFF23, 0x80)

    def silence_channel(self, chan: int):
        if chan == 0:
            self.write_reg(0xFF12, 0x00)
            self.write_reg(0xFF14, 0x80)
        elif chan == 1:
            self.write_reg(0xFF17, 0x00)
            self.write_reg(0xFF19, 0x80)
        elif chan == 2:
            self.write_reg(0xFF1A, 0x00)
        elif chan == 3:
            self.write_reg(0xFF21, 0x00)
            self.write_reg(0xFF23, 0x80)


def midi_key_to_gb_freq(key: int) -> int:
    f = 440.0 * (2.0 ** ((key - 69) / 12.0))
    denom = 131072.0 / f
    return max(0, min(2047, int(round(2048.0 - denom))))


def midi_key_to_gb_wave_freq(key: int) -> int:
    f = 440.0 * (2.0 ** ((key - 69) / 12.0))
    denom = 65536.0 / f
    return max(0, min(2047, int(round(2048.0 - denom))))


def fnum_block(midi_note: int) -> tuple[int, int]:
    freq = 440.0 * 2 ** ((midi_note - 69) / 12)
    for block in range(8):
        fnum = round(freq * (1 << (20 - block)) / 49716)
        if fnum <= 1023:
            return fnum, block
    return 1023, 7


def nr43_to_fnum_block(nr43: int) -> tuple[int, int]:
    s = (nr43 >> 4) + 1
    r = nr43 & 0x07
    if r == 0:
        hz = 524288 >> s
    else:
        divisor = r << s
        hz = 262144 // divisor if divisor else 262144

    fnum = (hz << 13) // 49716
    block = 7
    while fnum < 512 and block > 0:
        fnum <<= 1
        block -= 1
    if fnum > 1023:
        fnum = 1023
    return fnum, block


PITCH_TABLE = [
    0xF82C, 0xF89D, 0xF907, 0xF96B, 0xF9CA, 0xFA23,
    0xFA77, 0xFAC7, 0xFB12, 0xFB58, 0xFB9B, 0xFBDA,
]


def calculate_gb_freq(pitch: int, octave: int) -> int:
    val = PITCH_TABLE[pitch % 12]
    if val >= 0x8000:
        val -= 0x10000
    shifts = 7 - octave
    if shifts > 0:
        val >>= shifts
    return (val + 0x0800) & 0x7FF


def gb_freq_to_fnum_block(freq: int, is_wave: bool = False) -> tuple[int, int]:
    denom = 2048 - (freq & 0x7FF)
    if denom <= 0:
        return 1023, 7
    hz = (131072 // 2) // denom if is_wave else 131072 // denom
    fnum = (hz << 13) // 49716
    block = 7
    while fnum < 512 and block > 0:
        fnum <<= 1
        block -= 1
    if fnum > 1023:
        fnum = 1023
    return fnum, block


def carrier_level(patch_name: str, vel: int, volume: int) -> int:
    base_tl = PATCHES[patch_name][6] & 0x3F
    eff = min(127, vel * volume // 127)
    return min(63, base_tl + (127 - eff) // 8)


class OplEngine:
    def __init__(self, samplerate: int = 48000):
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
        self.env_vol = [0] * 18
        self.env_period = [0] * 18
        self.env_dir = [0] * 18
        self.env_acc = [0] * 18
        self.base_tl = [0] * 18
        self.frac_acc = 0.0

        # Max buffer for 1 frame @ 60Hz: 1024 samples * 2 channels
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
        self.env_vol = [0] * 18
        self.env_period = [0] * 18
        self.env_dir = [0] * 18
        self.env_acc = [0] * 18
        self.base_tl = [0] * 18
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
        self.base_tl[voice] = patch[6] & 0x3F

    def key_on(
        self,
        voice: int,
        midi_note: int,
        vel: int = 100,
        volume: int = 127,
        fade: int = 0,
        is_drum: bool = False,
    ):
        if voice < 0 or voice >= 18:
            return
        patch_name = self.voice_patches[voice] or "duty_50"
        patch = PATCHES[patch_name]
        patch_ksl = patch[6] & 0xC0
        base_patch_tl = patch[6] & 0x3F
        self.base_tl[voice] = base_patch_tl

        arr_base = 0x100 if voice >= 9 else 0x000
        v_local = voice % 9
        car_slot = arr_base + MOD_SLOTS[v_local] + 3

        # Declick: if already keyed on, key off first to reset OPL phase & envelope
        if self.voice_keyed[voice]:
            block = self.voice_blocks[voice]
            fnum = self.voice_fnums[voice]
            self.write_reg(arr_base + 0xB0 + v_local, (block << 2) | ((fnum >> 8) & 0x03))
            self.voice_keyed[voice] = False

        if is_drum or voice == 3:
            # GB Channel 4 noise drum hit: look up authentic parameters from DRUM_PARAMS
            params = DRUM_PARAMS.get(midi_note, (8, 1, 34))
            init_vol, fade_period, nr43 = params
            fnum, block = nr43_to_fnum_block(nr43)
            self.env_vol[voice] = init_vol
            self.env_period[voice] = fade_period
            self.env_dir[voice] = 0  # always decays
            self.env_acc[voice] = 0
            tl = min(63, base_patch_tl + OPL_VOL_TABLE[init_vol]
                     + (NOISE_V3_TRIM if voice == 3 else 0))
        elif voice in (0, 1):
            # GB Pulse channels: recover GB volume (0..15) and simulate envelope decay
            gb_vol = min(15, max(1, (vel - 15) // 7))
            self.env_vol[voice] = gb_vol
            self.env_period[voice] = abs(fade) if fade != 0 else 0
            self.env_dir[voice] = 1 if fade < 0 else 0
            self.env_acc[voice] = 0
            fnum, block = fnum_block(midi_note)
            tl = min(63, base_patch_tl + OPL_VOL_TABLE[gb_vol])
        elif voice == 2:
            # GB Wave channel: holds flat level without envelope decay
            self.env_period[voice] = 0
            fnum, block = fnum_block(midi_note)
            tl = carrier_level(patch_name, vel, volume)
        else:
            # Enhancement voices (4..13): soft sustaining pad/bass
            self.env_period[voice] = 0
            fnum, block = fnum_block(midi_note)
            tl = carrier_level(patch_name, vel, volume)

        self.voice_fnums[voice] = fnum
        self.voice_blocks[voice] = block
        self.voice_keyed[voice] = True

        # Write carrier TL before key-on (avoid loud attack burst)
        self.write_reg(0x40 + car_slot, patch_ksl | tl)
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

    def key_on_raw(
        self,
        voice: int,
        fnum: int,
        block: int,
        init_vol: int,
        fade_period: int,
        fade_dir: int,
        patch_name: str,
        vol_scale: int = 100,
    ):
        """Keys on an authentic GB channel with direct fnum/block, envelope parameters, and patch."""
        if voice < 0 or voice >= 18:
            return
        patch = PATCHES.get(patch_name, PATCHES["duty_50"])
        patch_ksl = patch[6] & 0xC0
        base_patch_tl = patch[6] & 0x3F
        self.base_tl[voice] = base_patch_tl
        self.voice_patches[voice] = patch_name

        arr_base = 0x100 if voice >= 9 else 0x000
        v_local = voice % 9
        car_slot = arr_base + MOD_SLOTS[v_local] + 3

        if self.voice_keyed[voice]:
            old_b = self.voice_blocks[voice]
            old_f = self.voice_fnums[voice]
            self.write_reg(arr_base + 0xB0 + v_local, (old_b << 2) | ((old_f >> 8) & 0x03))
            self.voice_keyed[voice] = False

        self.env_vol[voice] = min(15, max(0, init_vol))
        self.env_period[voice] = fade_period
        self.env_dir[voice] = fade_dir
        self.env_acc[voice] = 0

        # Volume scale: nominal 100%. Every ~10% delta is approx 1 TL step (0.75 dB)
        att_adj = (100 - vol_scale) // 10 if vol_scale < 100 else -min(6, (vol_scale - 100) // 10)
        tl = min(63, max(0, base_patch_tl + OPL_VOL_TABLE[self.env_vol[voice]] + att_adj))

        self.voice_fnums[voice] = fnum
        self.voice_blocks[voice] = block
        self.voice_keyed[voice] = True

        self.write_reg(0x40 + car_slot, patch_ksl | tl)
        self.write_reg(arr_base + 0xA0 + v_local, fnum & 0xFF)
        self.write_reg(arr_base + 0xB0 + v_local, 0x20 | (block << 2) | ((fnum >> 8) & 0x03))

    def step_envelopes(self):
        """Steps software volume envelopes for active voices once per 60 Hz tick.

        Faithfully emulates opl_shim.asm:voice_envelope + voice_volume:
        step threshold = 60 * period (with 64 accumulated per tick).
        """
        for voice in range(4):
            if not self.voice_keyed[voice] or self.env_period[voice] == 0:
                continue

            period = self.env_period[voice]
            self.env_acc[voice] += 64
            step_threshold = 60 * period
            if self.env_acc[voice] >= step_threshold:
                self.env_acc[voice] -= step_threshold
                if self.env_dir[voice] == 0:
                    if self.env_vol[voice] > 0:
                        self.env_vol[voice] -= 1
                else:
                    if self.env_vol[voice] < 15:
                        self.env_vol[voice] += 1

                patch_name = self.voice_patches[voice] or "duty_50"
                patch_ksl = PATCHES[patch_name][6] & 0xC0
                tl = min(63, self.base_tl[voice] + OPL_VOL_TABLE[self.env_vol[voice]])

                arr_base = 0x100 if voice >= 9 else 0x000
                v_local = voice % 9
                car_slot = arr_base + MOD_SLOTS[v_local] + 3
                self.write_reg(0x40 + car_slot, patch_ksl | tl)

                # Once noise channel decays to complete silence, key it off
                if voice == 3 and self.env_vol[voice] == 0:
                    self.key_off(3)

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

        # Base notes per frame: tuple (key, vel, fade, is_drum)
        self.base_events: dict[int, list[tuple[str, int, any]]] = {}
        for n in self.base_song.notes:
            v = n.chan - 1  # 0: pulse1, 1: pulse2, 2: wave, 3: noise
            is_drum = (n.chan == 4)
            fade = getattr(n, "fade", 0)
            self.base_events.setdefault(n.frame, []).append(("on", v, (n.key, n.vel, fade, is_drum)))
            off_f = min(n.frame + n.dur, self.total_frames)
            self.base_events.setdefault(off_f, []).append(("off", v, None))

        # Setup base patches (Mt. Moon Cave / Cinnabar Mansion override to duty_clean)
        pulse_patch = "duty_clean" if self.song_label in ("Music_Dungeon2", "Music_CinnabarMansion") else "duty_50"
        self.engine.load_patch(0, pulse_patch, "center")
        self.engine.load_patch(1, pulse_patch, "center")
        self.engine.load_patch(2, "wave", "center")
        self.engine.load_patch(3, "noise", "center")

        # Game Boy APU engine / pre-rendered PCM cache for authentic GB sound toggle
        cache_file = CACHE_DIR / "music" / f"{self.song_label}.pcm"
        if cache_file.exists():
            self.gb_pcm = cache_file.read_bytes()
            self.gb_engine = None
        else:
            self.gb_pcm = None
            self.gb_engine = None

        self.gb_sound = False
        self.active_base_notes: dict[int, tuple[int, int, int, bool]] = {}

        # Enhancement layers
        self.enh_events: dict[int, list[tuple[str, int, any]]] = {}
        self.enh_channels = []
        self.enable_base = True
        self.enable_enh = True
        self.solo_enh = False
        self.muted_base: set[int] = set()  # GB voices 0-3 muted in all paths
        self.tier_filter = {1}
        self.current_frame = 0

    def toggle_gb_sound(self) -> bool:
        self.gb_sound = not self.gb_sound
        if self.gb_sound:
            self.silence_base()
            self.silence_enhancements()
            if self.gb_pcm is None:
                if self.gb_engine is None:
                    self.gb_engine = GbApuEngine(samplerate=self.engine.samplerate)
                # Immediately trigger currently sounding notes on GB APU
                for v, (key, vel, fade, is_drum) in self.active_base_notes.items():
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
            if self.gb_engine:
                self.gb_engine.reset()
            # Immediately trigger currently sounding notes on OPL3
            for v, (key, vel, fade, is_drum) in self.active_base_notes.items():
                self.engine.key_on(v, key, vel=vel, fade=fade, is_drum=is_drum)
        return self.gb_sound

    def resume_playback(self):
        """Restores currently sounding notes when unpausing."""
        if self.gb_sound:
            if self.gb_pcm is not None:
                return  # Direct PCM streaming needs no note state
            if self.gb_engine is None:
                self.gb_engine = GbApuEngine(samplerate=self.engine.samplerate)
            for v, (key, vel, fade, is_drum) in self.active_base_notes.items():
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
            for v, (key, vel, fade, is_drum) in self.active_base_notes.items():
                self.engine.key_on(v, key, vel=vel, fade=fade, is_drum=is_drum)

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

        # The OPL stream loops a single body: scope unrolled files down to
        # intro + first body (dup copies and evolving later bodies are an
        # MT-32/GM affair).
        resolved = first_body_notes(resolved, analysis)
        self.enh_channels = resolved
        tier1 = [c for c in resolved if c.tier in self.tier_filter and c.notes]
        if not tier1:
            return

        # Flatten notes with patch & pan
        notes = []
        for ci, ch in enumerate(tier1):
            patch = ch.opl_patch or "soft_pad"
            pan = ch.pan
            vol = getattr(ch, "opl_volume", ch.volume)
            for n in ch.notes:
                notes.append((n.frame, n.dur, n.key, n.vel, vol, patch, pan, ci))
        notes.sort()

        # Pool allocation (voices 4..13)
        free_at = [0] * POOL_SIZE
        last_voice = {}
        for frame, dur, key, vel, vol, patch, pan, ci in notes:
            v = last_voice.get(ci)
            if v is None or free_at[v] > frame:
                v = next((i for i in range(POOL_SIZE) if free_at[i] <= frame), None)
                if v is None:
                    continue  # Polyphony cap reached
            last_voice[ci] = v
            free_at[v] = frame + dur
            opl_v = 4 + v  # Voice 4..13

            self.enh_events.setdefault(frame, []).append(("on", opl_v, (key, vel, vol, patch, pan)))
            off_f = min(frame + dur, self.total_frames)
            self.enh_events.setdefault(off_f, []).append(("off", opl_v, None))

    def toggle_base_mute(self, v: int) -> bool:
        """Toggles mute on one GB base voice (0-3); returns muted state."""
        if v in self.muted_base:
            self.muted_base.remove(v)
        else:
            self.muted_base.add(v)
            self.engine.key_off(v)
        return v in self.muted_base

    def silence_enhancements(self):
        for v in range(4, 14):
            self.engine.key_off(v)

    def silence_base(self):
        for v in range(4):
            self.engine.key_off(v)

    def silence_all(self):
        """Immediately silences both OPL3 and Game Boy APU chips."""
        for v in range(18):
            self.engine.key_off(v)
            arr_base = 0x100 if v >= 9 else 0x000
            v_local = v % 9
            car_slot = arr_base + MOD_SLOTS[v_local] + 3
            self.engine.write_reg(0x40 + car_slot, 0x3F)
        if hasattr(self, "gb_engine") and self.gb_engine is not None:
            self.gb_engine.reset()

    def tick(self) -> bytes:
        """Services one 60 Hz frame and returns stereo PCM audio."""
        f = self.current_frame

        # Track active base notes for instant seamless G/Pause transitions
        # (muted voices never enter: they stay silent across toggles/resume).
        for ev_type, v, args in self.base_events.get(f, []):
            if ev_type == "on":
                if v in self.muted_base:
                    self.active_base_notes.pop(v, None)
                    self.engine.key_off(v)
                else:
                    self.active_base_notes[v] = args
            elif ev_type == "off":
                self.active_base_notes.pop(v, None)

        # Boolean logic: enhancements auto-disabled when gb_sound is active without modifying user setting
        effective_enh = (self.enable_enh or self.solo_enh) and (not self.gb_sound)
        effective_base = self.enable_base and not self.solo_enh

        if self.gb_sound:
            self.silence_base()
            self.silence_enhancements()
            if self.gb_pcm is not None:
                frame_len = (self.engine.samplerate // 60) * 4
                offset = f * frame_len
                if offset + frame_len <= len(self.gb_pcm):
                    frame_pcm = self.gb_pcm[offset : offset + frame_len]
                else:
                    frame_pcm = b"\x00" * frame_len
            else:
                if self.gb_engine is None:
                    self.gb_engine = GbApuEngine(samplerate=self.engine.samplerate)
                for ev_type, v, args in self.base_events.get(f, []):
                    if ev_type == "on":
                        if v in self.muted_base:
                            continue
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
                        self.gb_engine.silence_channel(v)

                frame_pcm = self.gb_engine.generate_frame()
            self.engine.generate_frame()  # Keep OPL chip clocks in sync
        else:
            # Service Base Events on OPL3
            if effective_base:
                for ev_type, v, args in self.base_events.get(f, []):
                    if ev_type == "on":
                        if v in self.muted_base:
                            self.engine.key_off(v)
                            continue
                        key, vel, fade, is_drum = args
                        self.engine.key_on(v, key, vel=vel, fade=fade, is_drum=is_drum)
                    elif ev_type == "off":
                        self.engine.key_off(v)
            else:
                self.silence_base()

            # Service Enhancement Events on OPL3
            if effective_enh:
                for ev_type, opl_v, args in self.enh_events.get(f, []):
                    if ev_type == "on":
                        key, vel, vol, patch, pan = args
                        self.engine.load_patch(opl_v, patch, pan)
                        self.engine.key_on(opl_v, key, vel, vol)
                    elif ev_type == "off":
                        self.engine.key_off(opl_v)
            else:
                self.silence_enhancements()

            self.engine.step_envelopes()
            frame_pcm = self.engine.generate_frame()
            if self.gb_engine is not None:
                self.gb_engine.generate_frame()  # Keep GB APU clocks in sync

        # Advance frame
        self.current_frame += 1
        if self.current_frame >= self.total_frames:
            self.current_frame = self.loop_start
            # Silence all voices on loop wrap to prevent stuck notes
            for v in range(18):
                self.engine.key_off(v)
            if self.gb_sound and self.gb_engine is not None:
                self.gb_engine.reset()

        return frame_pcm

    def seek_relative(self, frames: int):
        target = max(0, min(self.total_frames - 1, self.current_frame + frames))
        self.current_frame = target
        for v in range(18):
            self.engine.key_off(v)
        if self.gb_sound and self.gb_engine is not None:
            self.gb_engine.reset()


def sfx_from_headers(rom: AudioROM) -> dict[str, list[tuple[int, str]]]:
    """Header label -> [(gb_channel, start_label), ...], SFX headers only."""
    from pret_audio import Label, Cmd
    sfx_map: dict[str, list[tuple[int, str]]] = {}
    for sec in rom.sections:
        if not sec.name.startswith("Sound Effect Headers"):
            continue
        cur = None
        for sf in sec.files:
            for it in sf.items:
                if isinstance(it, Label):
                    cur = it.name
                    sfx_map[cur] = []
                elif isinstance(it, Cmd) and it.name == "channel" and cur:
                    hw = (it.encode(rom.symtab, 0)[0] & 0x0F) + 1
                    sfx_map[cur].append((hw, it.args[0]))
    return {k: v for k, v in sfx_map.items() if v}


def simulate_sfx_events(rom: AudioROM, amap, channels: list[tuple[int, str]]) -> tuple[dict[int, list[tuple]], int]:
    """Interprets SFX channel command streams into frame-by-frame OPL event dispatch.

    Returns:
      (events_by_frame, total_duration_frames)
    """
    from pret_audio import Cmd
    events: dict[int, list[tuple]] = {}
    max_frame = 0

    for hw, start_lbl in channels:
        v = hw - 5  # 0: pulse1, 1: pulse2, 2: wave, 3: noise
        bank = rom.sym_bank[start_lbl]
        pc = rom.symtab[start_lbl]
        frame = 0
        speed = 1
        duty = 2
        octave = 3
        stack = []
        loopctr = 1
        vol = 15
        fade_dir = 0
        fade_period = 0

        while frame < 1200:  # 20 second safety cap
            it = amap.get((bank, pc))
            if not isinstance(it, Cmd):
                break
            pc += it.size

            if it.name == "sound_ret":
                if stack:
                    bank, pc = stack.pop()
                else:
                    events.setdefault(frame, []).append(("off", v, None))
                    break
            elif it.name == "sound_call":
                stack.append((bank, pc))
                target = it.args[0]
                bank, pc = rom.sym_bank[target], rom.symtab[target]
            elif it.name == "sound_loop":
                cnt, target = it.args
                if cnt == 0:
                    events.setdefault(frame, []).append(("off", v, None))
                    break  # cap infinite loops for SFX preview
                if loopctr < cnt:
                    loopctr += 1
                    bank, pc = rom.sym_bank[target], rom.symtab[target]
                else:
                    loopctr = 1
            elif it.name == "duty_cycle":
                duty = it.args[0]
            elif it.name == "duty_cycle_pattern":
                pass
            elif it.name == "octave":
                octave = it.args[0]
            elif it.name == "noise_note":
                length, v_note, fade, nr43 = it.args
                f_dir = 1 if fade < 0 else 0
                f_per = abs(fade)
                dur = length * speed
                fnum, block = nr43_to_fnum_block(nr43)
                events.setdefault(frame, []).append(("noise", v, (fnum, block, v_note, f_per, f_dir), (nr43, v_note, f_per, f_dir)))
                frame += dur
                events.setdefault(frame, []).append(("off", v, None, None))
            elif it.name == "square_note":
                length, v_note, fade, freq = it.args
                f_dir = 1 if fade < 0 else 0
                f_per = abs(fade)
                dur = length * speed
                fnum, block = gb_freq_to_fnum_block(freq, is_wave=(v == 2))
                events.setdefault(frame, []).append(("square", v, (fnum, block, v_note, f_per, f_dir, duty), (freq, duty, v_note, f_per, f_dir)))
                frame += dur
                events.setdefault(frame, []).append(("off", v, None, None))
            elif it.name == "note":
                pitch, length = it.args
                dur = length * speed
                freq = calculate_gb_freq(pitch, octave)
                fnum, block = gb_freq_to_fnum_block(freq, is_wave=(v == 2))
                events.setdefault(frame, []).append(("square", v, (fnum, block, vol, fade_period, fade_dir, duty), (freq, duty, vol, fade_period, fade_dir)))
                frame += dur
                events.setdefault(frame, []).append(("off", v, None, None))
            elif it.name == "rest":
                dur = it.args[0] * speed
                events.setdefault(frame, []).append(("off", v, None, None))
                frame += dur
            elif it.name == "note_type":
                speed = it.args[0]
                if len(it.args) > 1:
                    vol = it.args[1]
                    fade = it.args[2]
                    fade_dir = 1 if fade < 0 else 0
                    fade_period = abs(fade)
            elif it.name == "pitch_sweep":
                sweep_time = it.args[0]
                sweep_shift = it.args[1]
                sweep_dir = 1 if sweep_shift < 0 else 0
                nr10_val = ((sweep_time & 7) << 4) | (sweep_dir << 3) | (abs(sweep_shift) & 7)
                events.setdefault(frame, []).append(("sweep", v, None, nr10_val))
            elif it.name in ("tempo", "volume", "toggle_perfect_pitch", "vibrato", "execute_music"):
                pass

        if frame > max_frame:
            max_frame = frame

    return events, max_frame


class SfxSession:
    """Coordinates authentic SFX playback, YAML profile hot-reloading, and A/B replay loops."""

    DUTY_PATCHES = {0: "duty_125", 1: "duty_25", 2: "duty_50", 3: "duty_75"}

    def __init__(self, sfx_query: str, delay_seconds: float = 2.5):
        self.engine = OplEngine()
        self.rom = AudioROM(ROOT)
        self.amap = build_addr_map(self.rom)
        self.sfx_headers = sfx_from_headers(self.rom)
        self.consts, _ = parse_music_constants()

        self.canonical_name, self.header_label = self._resolve_sfx(sfx_query)
        if self.header_label not in self.sfx_headers:
            raise ValueError(f"SFX header {self.header_label!r} not found in headers")

        self.ch_list = self.sfx_headers[self.header_label]
        self.events, self.sfx_frames = simulate_sfx_events(self.rom, self.amap, self.ch_list)

        cache_file = CACHE_DIR / "sfx" / f"{self.canonical_name}.pcm"
        if not cache_file.exists():
            cache_file = CACHE_DIR / "sfx" / f"{self.header_label}.pcm"
        if cache_file.exists():
            self.gb_pcm = cache_file.read_bytes()
            self.gb_engine = None
        else:
            self.gb_pcm = None
            self.gb_engine = None

        self.delay_seconds = max(0.2, float(delay_seconds))
        self.delay_frames = int(self.delay_seconds * 60)
        self.total_cycle_frames = self.sfx_frames + self.delay_frames

        self.gb_sound = False  # False = A (Tuned OPL3), True = B (Real Game Boy)
        self.auto_alternate = False
        self.is_raw = False
        self.playback = "fm"
        self.is_soft_apu = False
        self.profile = {}
        self.current_frame = 0
        self.paused = False
        self.sweep_val = 0
        self.sweep_acc = 0
        self.current_gb_freq = 0

        # Find YAML file if it exists (case-insensitive stem matching)
        self.yaml_path = None
        sfx_dir = AUDIO_DIR / "sfx"
        if sfx_dir.exists():
            clean_name = self.canonical_name.lower().replace("sfx_", "").replace("_", "")
            for p in sfx_dir.glob("*.yaml"):
                p_clean = p.stem.lower().replace("sfx_", "").replace("_", "")
                if p_clean == clean_name:
                    self.yaml_path = p
                    break

        # Point A (Tuned) vs Point B (Raw Default) for Tab A/B testing
        self.slot_a_profile = {}
        self.slot_b_profile = {}
        self.slot_a_label = self.yaml_path.name if self.yaml_path else "Tuned Default"
        self.slot_b_label = "Raw Default"
        self.active_slot = "A"

        if self.yaml_path and self.yaml_path.exists():
            self.load_yaml(self.yaml_path)
        else:
            self.profile = {}
            self.slot_a_profile = {}

        self.retrigger()

    def _resolve_sfx(self, query: str) -> tuple[str, str]:
        q = query.strip()
        if q in self.consts:
            return q, self.consts[q]
        uq = q.upper()
        if uq in self.consts:
            return uq, self.consts[uq]
        if f"SFX_{uq}" in self.consts:
            c = f"SFX_{uq}"
            return c, self.consts[c]
        for c, h in self.consts.items():
            if c.startswith("SFX_") and (h == q or h.lower() == q.lower()):
                return c, h
        clean_q = q.lower().replace("sfx_", "").replace("_", "")
        for c, h in self.consts.items():
            if not c.startswith("SFX_"):
                continue
            clean_c = c.lower().replace("sfx_", "").replace("_", "")
            if clean_q == clean_c:
                return c, h
        for c, h in self.consts.items():
            if not c.startswith("SFX_"):
                continue
            if clean_q in c.lower().replace("_", ""):
                return c, h
        raise ValueError(f"Sound effect {query!r} could not be resolved.")

    def load_yaml(self, path_or_content: Path | str):
        import yaml
        if isinstance(path_or_content, Path):
            data = yaml.safe_load(path_or_content.read_text(encoding="utf-8")) or {}
        else:
            data = yaml.safe_load(path_or_content) or {}
        self.playback = data.get("playback", "fm")
        self.is_soft_apu = (self.playback == "soft_apu")
        self.slot_a_profile = data.get("channels", {})
        if self.is_soft_apu:
            self.slot_a_label = "Soft APU (SB DMA)"
            self.slot_b_label = "FM Fallback"
            self.gb_sound = (self.active_slot == "A")
            self.profile = self.slot_a_profile
        else:
            self.slot_a_label = self.yaml_path.name if self.yaml_path else "Tuned Default"
            self.slot_b_label = "Raw Default"
            if self.active_slot == "A":
                self.profile = self.slot_a_profile
            else:
                self.profile = self.slot_b_profile

    def set_delay(self, seconds: float):
        self.delay_seconds = max(0.2, min(30.0, float(seconds)))
        self.delay_frames = int(self.delay_seconds * 60)
        self.total_cycle_frames = self.sfx_frames + self.delay_frames

    def toggle_slot(self) -> str:
        """Toggles between Point A and Point B for Tab A/B testing."""
        self.active_slot = "B" if self.active_slot == "A" else "A"
        if getattr(self, "is_soft_apu", False):
            self.gb_sound = (self.active_slot == "A")
            self.profile = self.slot_a_profile
        else:
            self.profile = self.slot_a_profile if self.active_slot == "A" else self.slot_b_profile
        self.retrigger()
        return self.active_slot

    def toggle_mode(self) -> str:
        return self.toggle_slot()

    def toggle_gb_sound(self) -> bool:
        """Toggles between OPL3 FM synthesis and authentic Real Game Boy sound chip."""
        self.gb_sound = not self.gb_sound
        if getattr(self, "is_soft_apu", False):
            self.active_slot = "A" if self.gb_sound else "B"
        if self.gb_sound and self.gb_pcm is None and self.gb_engine is None:
            self.gb_engine = GbApuEngine(samplerate=self.engine.samplerate)
        self.retrigger()
        return self.gb_sound

    def toggle_auto_alternate(self) -> bool:
        """Toggles hands-free automatic alternation between Point A and Point B."""
        self.auto_alternate = not self.auto_alternate
        return self.auto_alternate

    def toggle_raw(self) -> str:
        return self.toggle_slot()

    def silence_all(self):
        """Immediately silences both OPL3 and Game Boy APU chips."""
        for v in range(4):
            self.engine.key_off(v)
            arr_base = 0x100 if v >= 9 else 0x000
            v_local = v % 9
            car_slot = arr_base + MOD_SLOTS[v_local] + 3
            self.engine.write_reg(0x40 + car_slot, 0x3F)
        if hasattr(self, "gb_engine") and self.gb_engine is not None:
            self.gb_engine.reset()

    def retrigger(self):
        self.current_frame = 0
        self.sweep_acc = 0
        for v in range(4):
            self.engine.key_off(v)
        if hasattr(self, "gb_engine") and self.gb_engine is not None:
            self.gb_engine.reset()

    def step_sweep(self):
        """Steps pulse 1 hardware sweep emulation (128 Hz base clock)."""
        if not self.engine.voice_keyed[0]:
            return
        period = (self.sweep_val >> 4) & 7
        if period == 0:
            return
        shift = self.sweep_val & 7
        sweep_dir = (self.sweep_val >> 3) & 1
        threshold = period * 60
        self.sweep_acc += 128
        freq_changed = False
        while self.sweep_acc >= threshold:
            self.sweep_acc -= threshold
            if shift > 0:
                delta = self.current_gb_freq >> shift
                if sweep_dir == 0:
                    self.current_gb_freq += delta
                    if self.current_gb_freq >= 2048:
                        self.engine.key_off(0)
                        return
                else:
                    self.current_gb_freq = max(0, self.current_gb_freq - delta)
                freq_changed = True
        if freq_changed:
            fnum, block = gb_freq_to_fnum_block(self.current_gb_freq)
            self.engine.voice_fnums[0] = fnum
            self.engine.voice_blocks[0] = block
            self.engine.write_reg(0xA0, fnum & 0xFF)
            self.engine.write_reg(0xB0, 0x20 | (block << 2) | ((fnum >> 8) & 0x03))

    def tick(self) -> bytes:
        frame_len = (self.engine.samplerate // 60) * 4
        if self.paused:
            return b"\x00" * frame_len

        f = self.current_frame
        if f <= self.sfx_frames:
            for ev in self.events.get(f, []):
                ev_type = ev[0]
                v = ev[1]

                if self.gb_sound:
                    if self.gb_pcm is None:
                        if self.gb_engine is None:
                            self.gb_engine = GbApuEngine(samplerate=self.engine.samplerate)
                        if ev_type == "noise":
                            nr43, vol, fade_p, fade_d = ev[3]
                            self.gb_engine.trigger_noise(nr43, vol=vol, fade_period=fade_p, fade_dir=fade_d)
                        elif ev_type == "square":
                            freq, duty, vol, fade_p, fade_d = ev[3]
                            if v in (0, 1):
                                self.gb_engine.trigger_pulse(v, freq, duty=duty, vol=vol, fade_period=fade_p, fade_dir=fade_d)
                            elif v == 2:
                                self.gb_engine.trigger_wave(freq, vol_code=1)
                        elif ev_type == "sweep":
                            if v == 0:
                                self.gb_engine.write_reg(0xFF10, ev[3])
                        elif ev_type == "off":
                            self.gb_engine.silence_channel(v)
                else:
                    hw_chan = v + 5
                    ch_cfg = self.profile.get(hw_chan, {}) if not self.is_raw else {}

                    if ev_type == "noise":
                        fnum, block, vol, fade_p, fade_d = ev[2]
                        patch = ch_cfg.get("patch", "noise_soft_whoosh" if not self.is_raw and self.profile else "noise")
                        vol_scale = ch_cfg.get("volume", 100) if not self.is_raw else 100
                        self.engine.load_patch(v, patch, "center")
                        self.engine.key_on_raw(v, fnum, block, vol, fade_p, fade_d, patch, vol_scale)
                    elif ev_type == "square":
                        fnum, block, vol, fade_p, fade_d, duty = ev[2]
                        if v == 0 and len(ev) > 3 and ev[3] is not None:
                            self.current_gb_freq = ev[3][0]
                        def_patch = "wave" if v == 2 else self.DUTY_PATCHES.get(duty, "duty_50")
                        patch = ch_cfg.get("patch", def_patch)
                        vol_scale = ch_cfg.get("volume", 100) if not self.is_raw else 100
                        self.engine.load_patch(v, patch, "center")
                        self.engine.key_on_raw(v, fnum, block, vol, fade_p, fade_d, patch, vol_scale)
                    elif ev_type == "sweep":
                        if v == 0 and len(ev) > 3 and ev[3] is not None:
                            self.sweep_val = ev[3]
                            self.sweep_acc = 0
                    elif ev_type == "off":
                        if v == 0:
                            self.current_gb_freq = 0
                            self.sweep_val = 0
                        self.engine.key_off(v)
                        if f < self.sfx_frames:
                            arr_base = 0x100 if v >= 9 else 0x000
                            v_local = v % 9
                            car_slot = arr_base + MOD_SLOTS[v_local] + 3
                            self.engine.write_reg(0x40 + car_slot, 0x3F)

            if not self.gb_sound:
                self.step_sweep()
                self.engine.step_envelopes()
        else:
            for v in range(4):
                self.engine.key_off(v)
                arr_base = 0x100 if v >= 9 else 0x000
                v_local = v % 9
                car_slot = arr_base + MOD_SLOTS[v_local] + 3
                self.engine.write_reg(0x40 + car_slot, 0x3F)
            if self.gb_sound and self.gb_engine is not None:
                self.gb_engine.reset()

        self.current_frame += 1
        if self.current_frame >= self.total_cycle_frames:
            if self.auto_alternate:
                self.toggle_slot()
            self.retrigger()

        if self.gb_sound:
            self.engine.generate_frame()  # Keep OPL chip clocks in sync
            if self.gb_pcm is not None:
                offset = f * frame_len
                if offset + frame_len <= len(self.gb_pcm):
                    return self.gb_pcm[offset : offset + frame_len]
                return b"\x00" * frame_len
            return self.gb_engine.generate_frame()
        else:
            if self.gb_engine is not None:
                self.gb_engine.generate_frame()  # Keep GB APU clocks in sync
            raw = self.engine.generate_frame()
            if f == self.sfx_frames:
                # Replicate Game Boy analog AC-coupling discharge (smooth ~3ms RC decay)
                import math
                import struct
                decay_samples = 140
                total_words = len(raw) // 2
                vals = list(struct.unpack(f"<{total_words}h", raw))
                for i in range(decay_samples):
                    factor = math.exp(-5.0 * i / decay_samples)
                    vals[i * 2] = int(vals[i * 2] * factor)
                    vals[i * 2 + 1] = int(vals[i * 2 + 1] * factor)
                for i in range(decay_samples, total_words // 2):
                    vals[i * 2] = 0
                    vals[i * 2 + 1] = 0
                # Now that frame 15 decay has been generated, silence carrier level for subsequent frames
                for v in range(4):
                    arr_base = 0x100 if v >= 9 else 0x000
                    v_local = v % 9
                    car_slot = arr_base + MOD_SLOTS[v_local] + 3
                    self.engine.write_reg(0x40 + car_slot, 0x3F)
                return struct.pack(f"<{total_words}h", *vals)
            elif f > self.sfx_frames:
                return b"\x00" * frame_len
            return raw



