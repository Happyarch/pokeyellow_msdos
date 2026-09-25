#!/usr/bin/env python3
"""gen_imfc_custom_patches.py — IBM Music Feature Card (IMFC) custom voice compiler.

Reads tools/audio/imfc/imfc_custom_voices.yaml and compiles assets/imfc_sysex.inc:
a sequence of length-prefixed Yamaha SysEx messages sent at boot by imfc_upload.

SysEx format (Yamaha FB-01 / IMFC):
  F0 43 75 0s <command...> F7

Architecture:
  - Bank 0: Custom RAM Bank A (voices 1-48)
  - Bank 1: Custom RAM Bank B (voices 49-96)
  - Banks 2-6: ROM 1-5 (240 presets)
"""

from __future__ import annotations

import sys
from pathlib import Path
from typing import Any
import yaml

AUDIO_DIR = Path(__file__).resolve().parent
ROOT = AUDIO_DIR.parents[2]
ASSETS = ROOT / "dos_port" / "assets"
CUSTOM_VOICES_YAML = AUDIO_DIR / "imfc" / "imfc_custom_voices.yaml"


def pack_voice_definition(voice: dict[str, Any]) -> bytes:
    """Pack a custom voice dictionary into a 64-byte Yamaha FB-01 VoiceDefinition."""
    data = bytearray(64)

    # +00~+06: Instrument name (7 ASCII characters, space-padded)
    name = str(voice.get("name", "Custom"))[:7].ljust(7)
    data[0:7] = name.encode("ascii", errors="replace")

    # +07: Reserved
    data[7] = 0

    # +08: LFO speed (0..255)
    lfo = voice.get("lfo", {})
    data[8] = int(lfo.get("speed", 0)) & 0xFF

    # +09: <a*******> <a>: LFO load mode (1=enable) / <*>: AMD (0..127)
    amd = int(lfo.get("amd", 0)) & 0x7F
    load_mode = 1 if lfo.get("load_mode", True) else 0
    data[9] = (load_mode << 7) | amd

    # +0A: <a*******> <a>: LFO sync mode (1=sync ON) / <*>: PMD (0..127)
    pmd = int(lfo.get("pmd", 0)) & 0x7F
    sync_mode = 1 if lfo.get("sync", True) else 0
    data[10] = (sync_mode << 7) | pmd

    # +0B: <0abcd000> Operator enable: a=OP4, b=OP3, c=OP2, d=OP1 (0x78 for all 4 enabled)
    data[11] = 0x78

    # +0C: <11aaabbb> <a>: Feedback level (0..7) / <b>: Algorithm (0..7)
    fb = int(voice.get("feedback", 0)) & 0x07
    alg = int(voice.get("algorithm", 0)) & 0x07
    data[12] = 0xC0 | (fb << 3) | alg

    # +0D: <0aaa00bb> <a>: PMS (0..7) / <b>: AMS (0..3)
    pms = int(voice.get("pms", 0)) & 0x07
    ams = int(voice.get("ams", 0)) & 0x03
    data[13] = (pms << 4) | ams

    # +0E: <0**00000> <*>: LFO wave form (0=saw, 1=square, 2=triangle, 3=S&H)
    wf = int(lfo.get("waveform", 2)) & 0x03
    data[14] = (wf << 5)

    # +0F: Transpose (-128..127)
    tr = int(voice.get("transpose", 0))
    data[15] = tr & 0xFF

    # +10..+2F: 4 operators (8 bytes each, OP1..OP4)
    operators = voice.get("operators", [])
    for op_idx in range(4):
        op = operators[op_idx] if op_idx < len(operators) else {}
        base = 16 + op_idx * 8

        tl = int(op.get("tl", 0)) & 0x7F
        mult = int(op.get("mult", 1)) & 0x0F
        dt = int(op.get("dt", 3)) & 0x07
        ar = int(op.get("ar", 31)) & 0x1F
        d1r = int(op.get("d1r", 0)) & 0x1F
        d2r = int(op.get("d2r", 0)) & 0x1F
        sl = int(op.get("sl", 15)) & 0x0F
        rr = int(op.get("rr", 15)) & 0x0F
        kls = int(op.get("kls", 0)) & 0x0F
        krs = int(op.get("krs", 0)) & 0x03

        # Byte 0: <0*******> Total Level (TL)
        data[base + 0] = tl

        # Byte 1: <a***bbbb> <a>: KLS bit 0 / <*...>: Vel sens to TL / <b>: unused
        data[base + 1] = (kls & 1) << 7

        # Byte 2: <aaaabbbb> <a>: KLS depth / <b>: addition to TL
        data[base + 2] = (kls << 4) & 0xF0

        # Byte 3: <abbbcccc> <a>: KLS bit 1 / <b>: Detune (DT) / <c>: Multiple
        data[base + 3] = ((kls & 2) << 6) | (dt << 4) | mult

        # Byte 4: <aa0*****> <a>: KRS depth / <*>: Attack Rate (AR)
        data[base + 4] = (krs << 6) | ar

        # Byte 5: <abb*****> <a>: Carrier(1)/Modulator(0) / <b>: Vel to AR / <*>: Decay 1 Rate (D1R)
        # In Yamaha FB-01, bit 7 of byte 5 marks carrier operators per algorithm
        is_carrier = 1 if alg in (7,) or (alg in (4, 5, 6) and op_idx == 0) or (alg == 3 and op_idx in (0, 2)) or (alg in (1, 2) and op_idx == 0) or (alg == 0 and op_idx == 0) else 0
        data[base + 5] = (is_carrier << 7) | d1r

        # Byte 6: <aa0*****> <a>: Inharmonic / <*>: Decay 2 Rate (D2R)
        data[base + 6] = d2r

        # Byte 7: <aaaabbbb> <a>: Sustain Level (SL) / <b>: Release Rate (RR)
        data[base + 7] = (sl << 4) | rr

    # +30..+39: Reserved
    # +3A: Mono/poly & portamento
    data[0x3A] = 0
    # +3B: Pitchbender range & PMD controller
    data[0x3B] = 2  # +/- 2 semitones

    return bytes(data)


def encode_voice_sysex(voice_bytes: bytes, inst: int = 0) -> list[bytes]:
    """Encodes a 64-byte voice definition into 128 4-bit nibbles and checksum.

    Returns the Yamaha FB-01 1-voice SysEx message:
      F0 43 75 00 (0x08 | inst) 00 01 00 <128 nibbles> <checksum> F7
    """
    assert len(voice_bytes) == 64, f"Voice definition must be 64 bytes, got {len(voice_bytes)}"

    nibbles = bytearray()
    for b in voice_bytes:
        # Low nibble first, then high nibble
        nibbles.append(b & 0x0F)
        nibbles.append((b >> 4) & 0x0F)

    assert len(nibbles) == 128

    # Checksum: low 7 bits of 2's complement of the sum of data bytes
    chk = (-sum(nibbles)) & 0x7F

    # SysEx frame:
    # F0 43 75 00 (0x08 | inst) 00 <byteCountHigh: 0x01> <byteCountLow: 0x00> <nibbles...> <chk> F7
    msg = bytearray([0xF0, 0x43, 0x75, 0x00, 0x08 | (inst & 0x07), 0x00, 0x01, 0x00])
    msg.extend(nibbles)
    msg.append(chk)
    msg.append(0xF7)
    return bytes(msg)


def encode_store_voice_sysex(inst: int, slot: int) -> bytes:
    """Store the voice currently in instrument buffer into Custom Bank slot (0..95).

    Slot 0..47 = Bank 0 (Custom Bank A)
    Slot 48..95 = Bank 1 (Custom Bank B)
    F0 43 75 00 (0x28 | inst) 0x40 <slot> F7
    """
    return bytes([0xF0, 0x43, 0x75, 0x00, 0x28 | (inst & 0x07), 0x40, slot & 0x7F, 0xF7])


def build_imfc_sysex_messages() -> list[bytes]:
    """Builds the sequence of raw Yamaha SysEx messages."""
    data = {}
    if CUSTOM_VOICES_YAML.exists():
        data = yaml.safe_load(CUSTOM_VOICES_YAML.read_text()) or {}

    messages: list[bytes] = []

    # 1. Memory Protect OFF (System Parameter 0x21 = 0)
    messages.append(bytes([0xF0, 0x43, 0x75, 0x00, 0x10, 0x21, 0x00, 0xF7]))

    # 2. Master Output Level (System Parameter 0x24 = 127)
    messages.append(bytes([0xF0, 0x43, 0x75, 0x00, 0x10, 0x24, 0x7F, 0xF7]))

    # 3. Configure Instruments 1..8 (inst index 0..7)
    instruments = data.get("instruments", [])
    inst_configs = {}
    for entry in instruments:
        inst_num = entry.get("inst", 1) - 1
        inst_configs[inst_num] = entry

    for i in range(8):
        cfg = inst_configs.get(i, {})
        notes = cfg.get("notes", 1)
        midi_ch = cfg.get("midi_channel", i + 1) - 1
        bank = cfg.get("bank", 2)
        prog = cfg.get("program", 1) - 1  # 0-based wire program
        level = cfg.get("level", 127)
        pan = cfg.get("pan", 64)

        prefix = [0xF0, 0x43, 0x75, 0x00, 0x18 | i]
        # param 0: number of notes
        messages.append(bytes(prefix + [0x00, notes, 0xF7]))
        # param 1: MIDI channel
        messages.append(bytes(prefix + [0x01, midi_ch, 0xF7]))
        # param 2: key limit high
        messages.append(bytes(prefix + [0x02, 127, 0xF7]))
        # param 3: key limit low
        messages.append(bytes(prefix + [0x03, 0, 0xF7]))
        # param 4: voice bank
        messages.append(bytes(prefix + [0x04, bank, 0xF7]))
        # param 5: voice number
        messages.append(bytes(prefix + [0x05, prog, 0xF7]))
        # param 8: output level
        messages.append(bytes(prefix + [0x08, level, 0xF7]))
        # param 9: pan (0=L, 64=Center, 127=R)
        messages.append(bytes(prefix + [0x09, pan, 0xF7]))
        # param 10: LFO enable
        messages.append(bytes(prefix + [0x0A, 1, 0xF7]))
        # param 12: pitchbender range
        messages.append(bytes(prefix + [0x0C, 2, 0xF7]))
        # param 13: mono/poly (0=poly)
        messages.append(bytes(prefix + [0x0D, 0, 0xF7]))

    # 4. Upload and store Custom Voices into RAM Bank 0
    custom_voices = data.get("custom_voices", [])
    for slot_idx, voice in enumerate(custom_voices):
        prog = voice.get("program", slot_idx + 1)
        slot = prog - 1  # 0-based slot (0..47 in Bank 0)
        vbytes = pack_voice_definition(voice)
        # Upload to instrument 0 buffer
        upload_msg = encode_voice_sysex(vbytes, inst=0)
        messages.append(upload_msg)
        # Store from instrument 0 buffer to RAM Bank 0 slot
        store_msg = encode_store_voice_sysex(inst=0, slot=slot)
        messages.append(store_msg)

    # Re-apply instrument 0 configuration so instrument 0 returns to its default preset
    inst0_cfg = inst_configs.get(0, {})
    i0_bank = inst0_cfg.get("bank", 2)
    i0_prog = inst0_cfg.get("program", 1) - 1
    messages.append(bytes([0xF0, 0x43, 0x75, 0x00, 0x18 | 0, 0x04, i0_bank, 0xF7]))
    messages.append(bytes([0xF0, 0x43, 0x75, 0x00, 0x18 | 0, 0x05, i0_prog, 0xF7]))

    return messages


def build_imfc_sysex_blob() -> bytes:
    """Builds the sequence of length-prefixed SysEx messages."""
    messages = build_imfc_sysex_messages()
    blob = bytearray()
    for msg in messages:
        blob.extend(len(msg).to_bytes(2, "little"))
        blob.extend(msg)
    blob.extend((0).to_bytes(2, "little"))
    return bytes(blob)


def emit_inc(blob: bytes) -> str:
    lines = [
        "; assets/imfc_sysex.inc — IBM Music Feature Card boot SysEx setup blob.",
        "; DO NOT EDIT BY HAND — generated by tools/audio/gen_imfc_custom_patches.py",
        "",
        "global ImfcSysexBlob",
        "ImfcSysexBlob:",
    ]

    p = 0
    while p < len(blob):
        msg_len = int.from_bytes(blob[p:p + 2], "little")
        p += 2
        if msg_len == 0:
            lines.append("    dw 0                          ; end of SysEx setup blob")
            break
        lines.append(f"    dw {msg_len}")
        msg = blob[p:p + msg_len]
        p += msg_len
        for i in range(0, len(msg), 16):
            chunk = msg[i:i + 16]
            hex_str = ", ".join(f"0x{b:02X}" for b in chunk)
            lines.append(f"    db {hex_str}")
        lines.append("")

    return "\n".join(lines) + "\n"


def main():
    ASSETS.mkdir(parents=True, exist_ok=True)
    blob = build_imfc_sysex_blob()
    out = ASSETS / "imfc_sysex.inc"
    out.write_text(emit_inc(blob))
    print(f"gen_imfc_custom_patches: wrote {out} ({len(blob)} bytes in blob)")


if __name__ == "__main__":
    main()
