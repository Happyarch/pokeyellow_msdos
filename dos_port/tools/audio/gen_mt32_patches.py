#!/usr/bin/env python3
"""gen_mt32_patches.py — MT-32 SysEx setup blob from YAML (Phase B).

Reads tools/audio/mt32/timbres.yaml (hand-editable — the MT-32 counterpart
of gen_opl_patches.py's PATCHES dict) and writes assets/mt32_sysex.inc: a
sequence of length-prefixed Roland DT1 SysEx messages that mpu401.asm's
mt32_upload sends, paced, at audio_init when /MT32 is active.

Reference: docs/sound/Roland_MT_32_Midi_Implementation.md.
  DT1: F0 41 10 16 12 <addr hi mid lo> <data...> <sum> F7, data ≤ 256 bytes
  (we chunk at 128); checksum = two's complement of sum(addr+data) mod 128.
  Addresses are 7-bit per byte (carry at 0x80).

Messages emitted (in send order):
  1. LCD greeting            (20 00 00, exactly 20 ASCII chars)
  2. System area             (10 00 01, 22 bytes: reverb mode/time/level,
                              partial reserves ×9 — one message per the
                              *4-6 rule — MIDI channel table ×9, master
                              volume)
  3. Custom timbres          (08 <i*2> 00, 246 bytes each: 14 common +
                              4 × 58 partial params, chunked)
  4. Patch Memory rewrites   (05 ..., 8 bytes per patch slot) so a program
                              change can select a custom timbre
  5. Rhythm setup entries    (03 01 10 + (key-24)*4, 4 bytes per key)
"""

from __future__ import annotations

import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[3]
ASSETS = ROOT / "dos_port" / "assets"
DEFS = Path(__file__).resolve().parent / "mt32" / "timbres.yaml"

MFR_ROLAND, DEV_ID, MDL_MT32, CMD_DT1 = 0x41, 0x10, 0x16, 0x12
CHUNK = 128                       # data bytes per DT1 (limit is 256 total)

# ---------------------------------------------------------------------------
# Timbre parameter layouts (name, default) — defaults are a plain sustained
# square-wave synth partial; YAML entries override sparsely by name.
# ---------------------------------------------------------------------------
COMMON_PARAMS = [
    ("structure12", 0), ("structure34", 0), ("partial_mute", 0b0001),
    ("env_mode", 0),
]

PARTIAL_PARAMS = [
    ("wg_pitch_coarse", 36), ("wg_pitch_fine", 50), ("wg_pitch_keyfollow", 12),
    ("wg_pitch_bender_sw", 1), ("wg_waveform", 0), ("wg_pcm_wave", 0),
    ("wg_pulse_width", 50), ("wg_pw_velo_sens", 7),
    ("penv_depth", 0), ("penv_velo_sens", 0), ("penv_time_keyf", 0),
    ("penv_time1", 0), ("penv_time2", 0), ("penv_time3", 0), ("penv_time4", 0),
    ("penv_level0", 50), ("penv_level1", 50), ("penv_level2", 50),
    ("penv_sus_level", 50), ("penv_end_level", 50),
    ("plfo_rate", 40), ("plfo_depth", 0), ("plfo_mod_sens", 0),
    ("tvf_cutoff", 100), ("tvf_resonance", 0), ("tvf_keyfollow", 8),
    ("tvf_bias_point", 64), ("tvf_bias_level", 7),
    ("tvf_env_depth", 0), ("tvf_env_velo_sens", 0),
    ("tvf_env_depth_keyf", 0), ("tvf_env_time_keyf", 0),
    ("tvf_env_time1", 0), ("tvf_env_time2", 0), ("tvf_env_time3", 0),
    ("tvf_env_time4", 0), ("tvf_env_time5", 0),
    ("tvf_env_level1", 100), ("tvf_env_level2", 100), ("tvf_env_level3", 100),
    ("tvf_env_sus_level", 100),
    ("tva_level", 100), ("tva_velo_sens", 50),
    ("tva_bias_point1", 0), ("tva_bias_level1", 0),
    ("tva_bias_point2", 0), ("tva_bias_level2", 0),
    ("tva_env_time_keyf", 0), ("tva_env_time_velo", 0),
    ("tva_env_time1", 1), ("tva_env_time2", 1), ("tva_env_time3", 1),
    ("tva_env_time4", 1), ("tva_env_time5", 10),
    ("tva_env_level1", 100), ("tva_env_level2", 100), ("tva_env_level3", 100),
    ("tva_env_sus_level", 100),
]
assert len(PARTIAL_PARAMS) == 58, len(PARTIAL_PARAMS)

PATCH_PARAMS = [                  # Patch Memory record (8 bytes)
    ("timbre_group", 2),          # 0/1 preset A/B, 2 memory, 3 rhythm
    ("timbre_number", 0), ("key_shift", 24), ("fine_tune", 50),
    ("bender_range", 12), ("assign_mode", 0), ("reverb_switch", 1),
    ("dummy", 0),
]


def build_block(params: list[tuple[str, int]], src: dict, where: str) -> bytes:
    known = {n for n, _ in params}
    unknown = set(src) - known - {"name", "partials"}
    if unknown:
        raise ValueError(f"{where}: unknown parameter(s) {sorted(unknown)}")
    out = bytearray()
    for name, default in params:
        val = src.get(name, default)
        if not 0 <= int(val) <= 127:
            raise ValueError(f"{where}: {name} = {val} out of 0-127")
        out.append(int(val))
    return bytes(out)


# ---------------------------------------------------------------------------
# SysEx assembly
# ---------------------------------------------------------------------------
def addr_add(addr: int, offset: int) -> tuple[int, int, int]:
    """21-bit address + byte offset with 7-bit-per-byte carry."""
    lin = ((addr >> 16) & 0x7F) * 128 * 128 + ((addr >> 8) & 0x7F) * 128 \
        + (addr & 0x7F) + offset
    return (lin >> 14) & 0x7F, (lin >> 7) & 0x7F, lin & 0x7F


def dt1(addr: int, data: bytes) -> list[bytes]:
    msgs = []
    for off in range(0, len(data), CHUNK):
        chunk = data[off:off + CHUNK]
        a = addr_add(addr, off)
        payload = bytes(a) + chunk
        csum = (128 - sum(payload) % 128) % 128
        msgs.append(bytes((0xF0, MFR_ROLAND, DEV_ID, MDL_MT32, CMD_DT1))
                    + payload + bytes((csum, 0xF7)))
    return msgs


def build_messages(defs: dict) -> list[bytes]:
    msgs: list[bytes] = []

    lcd = defs.get("lcd", "POKEMON YELLOW DOS")[:20].ljust(20)
    if not all(32 <= ord(c) <= 127 for c in lcd):
        raise ValueError("lcd: ASCII 32-127 only")
    msgs += dt1(0x200000, lcd.encode())

    sysd = defs.get("system", {})
    reserves = sysd.get("partial_reserves", [10, 10, 4, 1, 1, 1, 1, 1, 3])
    if len(reserves) != 9 or sum(reserves) > 32:
        raise ValueError("partial_reserves: 9 values summing to <= 32")
    # midi_channels: part<-channel routing, 9 values (parts 1-8 + rhythm).
    # The in-game-verified table is [2,3,4,5,6,7,8,9,9] (see timbres.yaml's
    # note). Do NOT assume the Roland "0 = MIDI ch 1" spec and "correct" this
    # to [1,2,3,...] — that shifts every voice down a part in-game. This
    # default only applies if timbres.yaml omits the key; keep it correct.
    channels = sysd.get("midi_channels", [2, 3, 4, 5, 6, 7, 8, 9, 9])
    if len(channels) != 9:
        raise ValueError("midi_channels: need 9 values (parts 1-8 + rhythm)")
    system = bytes((
        sysd.get("reverb_mode", 1),      # hall
        sysd.get("reverb_time", 5),
        sysd.get("reverb_level", 4),
        *reserves, *channels,
        sysd.get("master_volume", 100),
    ))
    msgs += dt1(0x100001, system)        # 10 00 01 .. 10 00 16 contiguous

    for i, tim in enumerate(defs.get("timbres", []) or []):
        name = tim.get("name", f"Custom {i+1}")
        if len(name) > 10:
            raise ValueError(f"timbre {name!r}: name > 10 chars")
        partials = tim.get("partials", []) or []
        if not 1 <= len(partials) <= 4:
            raise ValueError(f"timbre {name!r}: 1-4 partials")
        mute_default = (1 << len(partials)) - 1   # unmute what's defined
        common = {k: v for k, v in tim.items() if k not in ("name", "partials")}
        common.setdefault("partial_mute", mute_default)
        data = name.ljust(10).encode() \
            + build_block(COMMON_PARAMS, common, f"timbre {name!r}")
        for pi in range(4):
            src = partials[pi] if pi < len(partials) else {}
            data += build_block(PARTIAL_PARAMS, src,
                                f"timbre {name!r} partial {pi+1}")
        assert len(data) == 246, len(data)
        msgs += dt1(0x080000 + ((i * 2) << 8), data)   # Timbre Memory #i+1

    for pat in defs.get("patches", []) or []:
        num = pat["number"]                  # 1-128, what a program change selects
        if not 1 <= num <= 128:
            raise ValueError(f"patch number {num} out of 1-128")
        rec = {k: v for k, v in pat.items() if k != "number"}
        msgs += dt1(0x050000 + (num - 1) * 8,
                    build_block(PATCH_PARAMS, rec, f"patch #{num}"))

    for rd in defs.get("rhythm", []) or []:
        key = rd["key"]                      # MIDI note on the rhythm part
        if not 24 <= key <= 87:
            raise ValueError(f"rhythm key {key} out of 24-87")
        data = bytes((rd.get("timbre", 0), rd.get("level", 100),
                      rd.get("pan", 7), rd.get("reverb", 1)))
        msgs += dt1(0x030110 + (key - 24) * 4, data)

    return msgs


def emit_inc(msgs: list[bytes]) -> str:
    lines = ["; mt32_sysex.inc — generated by tools/audio/gen_mt32_patches.py."
             " DO NOT EDIT BY HAND.",
             "; Length-prefixed Roland DT1 messages; dw 0 terminates. Sent by",
             "; mt32_upload (src/audio/mpu401.asm) at init when /MT32.",
             "",
             "Mt32SysexBlob:"]
    for msg in msgs:
        lines.append(f"    dw {len(msg)}")
        for i in range(0, len(msg), 16):
            row = ", ".join(f"0x{b:02X}" for b in msg[i:i + 16])
            lines.append(f"    db {row}")
    lines.append("    dw 0")
    lines.append("")
    return "\n".join(lines)


def main():
    defs = yaml.safe_load(DEFS.read_text()) or {}
    known = {"lcd", "system", "timbres", "patches", "rhythm"}
    unknown = set(defs) - known
    if unknown:
        raise ValueError(f"timbres.yaml: unknown top-level keys {unknown}")
    msgs = build_messages(defs)
    (ASSETS / "mt32_sysex.inc").write_text(emit_inc(msgs))
    total = sum(len(m) for m in msgs)
    print(f"mt32_sysex.inc: {len(msgs)} messages, {total} bytes")


if __name__ == "__main__":
    main()
