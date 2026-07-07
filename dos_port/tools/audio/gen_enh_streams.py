#!/usr/bin/env python3
"""gen_enh_streams.py — tier-1 enhancement YAML → OPL frame-delta streams.

Compiles the tier-1 channels of every enhancements/<Song>.yaml (through
yaml_lint's resolver, so a file the linter rejects is skipped with a
message, never breaking the build) into assets/enh_streams.inc for
src/audio/opl_enh.asm: notes pre-assigned to a pool of spare FM voices,
fnum/block and carrier levels precomputed — the player just writes
registers on cue. Deterministic Python owns all timing and polyphony
(audio plan, Phase E).

Stream format (consumed by src/audio/opl_enh.asm):
    header:  dw loop_off        ; byte offset of the loop point measured from
                                ; the first op byte; 0xFFFF = song plays once
    ops:     0x01-0x7F          ; wait N frames
             0x80|v  (v = 0-9)  ; key off pool voice v
             0xA0|v             ; key on pool voice v; 5 data bytes follow:
                                ;   patch  (OplPatches index)
                                ;   a0     (fnum low 8)
                                ;   b0     (block<<2 | fnum hi 2, NO key bit)
                                ;   c0     (patch C0 | pan bits $10/$20/$30)
                                ;   lvl    (carrier TL 0-63, master att and
                                ;           patch KSL applied by the player)
             0xF0               ; end of stream: stop playback
             0xF1               ; end of stream: jump to loop_off

Pool voices 0-4 map to OPL voices 4-8 (first register array; the APU shim
owns 0-3). Pool voices 5-9 map to the second array's voices 0-4 (OPL3
only; on OPL2 the player drops their events whole — same philosophy as
the tier drop). The generator warns whenever a song needs the pool's
OPL3-only half.

Sound-id addressing matches music_streams.inc: four 256-entry dd tables
(EnhStreamTable_Bank1..4) indexed by positional sound id, table picked
from wAudioROMBank at runtime.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pret_audio import AudioROM                       # noqa: E402
from gen_audio_data import sound_id                   # noqa: E402
from gen_opl_patches import PATCHES, PATCH_ORDER      # noqa: E402
from yaml_lint import lint                            # noqa: E402

ROOT = Path(__file__).resolve().parents[3]
ASSETS = ROOT / "dos_port" / "assets"
ENHANCE_DIR = Path(__file__).resolve().parent / "enhancements"

POOL_SIZE = 10
POOL_OPL2_SAFE = 5
PAN_BITS = {"left": 0x10, "right": 0x20, "center": 0x30}
END_STOP = 0xF0
END_LOOP = 0xF1


def fnum_block(midi_note: int) -> tuple[int, int]:
    """MIDI note -> (fnum, block), fnum kept in [512, 1023] when possible."""
    freq = 440.0 * 2 ** ((midi_note - 69) / 12)
    for block in range(8):
        fnum = round(freq * (1 << (20 - block)) / 49716)
        if fnum <= 1023:
            return fnum, block
    return 1023, 7


def carrier_level(patch_name: str, vel: int, volume: int) -> int:
    """Patch carrier TL + a velocity/volume attenuation add (0.75 dB units)."""
    base_tl = PATCHES[patch_name][6] & 0x3F
    eff = min(127, vel * volume // 127)
    return min(63, base_tl + (127 - eff) // 8)


def compile_song(resolved, analysis, warn) -> tuple[bytes, int] | None:
    """Tier-1 ResolvedChannels -> (ops, loop_off), None if empty/unfittable."""
    loop_start = analysis["frames"]["loop_start"]
    end = analysis["frames"]["end"]

    # flatten tier-1 notes, remembering per-channel patch/pan/volume
    notes = []           # (frame, dur, key, vel, patch_idx, c0, chan_idx)
    for ci, ch in enumerate(c for c in resolved if c.tier == 1):
        patch_idx = PATCH_ORDER.index(ch.opl_patch)
        c0 = (PATCHES[ch.opl_patch][10] & 0x0F) | PAN_BITS[ch.pan]
        for n in ch.notes:
            if loop_start is not None and \
                    n.frame < loop_start < n.frame + n.dur:
                warn(f"note at frame {n.frame} crosses the loop start "
                     f"({loop_start}) — shorten it or move it; song skipped")
                return None
            lvl = carrier_level(ch.opl_patch, n.vel, ch.volume)
            notes.append((n.frame, n.dur, n.key, patch_idx, c0, lvl, ci))
    if not notes:
        return None
    notes.sort()

    # greedy voice assignment: prefer the voice this channel used last
    # (patch-cache locality), else the lowest free pool voice
    free_at = [0] * POOL_SIZE
    last_voice = {}
    events = []          # (frame, order, bytes) — offs (0) before ons (1)
    used_high = False
    for frame, dur, key, patch_idx, c0, lvl, ci in notes:
        v = last_voice.get(ci)
        if v is None or free_at[v] > frame:
            v = next((i for i in range(POOL_SIZE) if free_at[i] <= frame),
                     None)
            if v is None:
                warn(f"more than {POOL_SIZE} simultaneous tier-1 notes at "
                     f"frame {frame}; song skipped")
                return None
        last_voice[ci] = v
        used_high |= v >= POOL_OPL2_SAFE
        free_at[v] = frame + dur
        fnum, block = fnum_block(key)
        events.append((frame, 1, bytes((0xA0 | v, patch_idx, fnum & 0xFF,
                                        (block << 2) | (fnum >> 8), c0,
                                        lvl))))
        events.append((min(frame + dur, end), 0, bytes((0x80 | v,))))
    if used_high:
        warn(f"peak polyphony uses pool voices >= {POOL_OPL2_SAFE} — those "
             "notes are OPL3-only (dropped whole on OPL2)")

    events.sort(key=lambda e: (e[0], e[1]))
    ops = bytearray()
    loop_off = 0xFFFF
    pos = 0

    def wait_until(target):
        nonlocal pos
        while target > pos:
            step = min(127, target - pos)
            ops.append(step)
            pos += step

    for frame, _, data in events:
        if loop_start is not None and loop_off == 0xFFFF \
                and frame >= loop_start:
            wait_until(loop_start)
            loop_off = len(ops)
        wait_until(frame)
        ops += data
    if loop_start is not None and loop_off == 0xFFFF:
        wait_until(loop_start)
        loop_off = len(ops)
    wait_until(end)
    ops.append(END_LOOP if loop_start is not None else END_STOP)
    if len(ops) > 0xFFFE:
        raise ValueError(f"stream too large for dw loop_off ({len(ops)})")
    return bytes(ops), loop_off


def emit_inc(streams, table, banks) -> str:
    lines = ["; enh_streams.inc — generated by tools/audio/gen_enh_streams.py."
             " DO NOT EDIT BY HAND.",
             ";",
             "; Tier-1 OPL enhancement streams for src/audio/opl_enh.asm.",
             "; Per stream: dw loop_off (from first op byte; 0xFFFF = play"
             " once), then ops:",
             ";   01-7F wait N frames | 80|v key off pool voice v",
             ";   A0|v key on voice v (+patch,a0,b0,c0,lvl)",
             ";   F0 end: stop        | F1 end: jump to loop_off",
             ";",
             "; EnhStreamTable_BankN: 256 dd per audio bank slot, indexed by",
             "; sound id (same (id, bank) addressing as music_streams.inc).",
             ""]
    for slot, bank in enumerate(banks, 1):
        lines.append(f"EnhStreamTable_Bank{slot}:  ; GB bank ${bank:02x}")
        by_id = table.get(bank, {})
        for base in range(0, 256, 8):
            row = ", ".join(
                (f"EnhStream_{by_id[i]}" if i in by_id else "0")
                for i in range(base, base + 8))
            lines.append(f"    dd {row}")
        lines.append("")
    total = 0
    for label, (ops, loop_off) in sorted(streams.items()):
        total += len(ops) + 2
        lines.append(f"EnhStream_{label}:  ; {len(ops)} bytes")
        lines.append(f"    dw 0x{loop_off:04X}")
        for i in range(0, len(ops), 16):
            row = ", ".join(f"0x{b:02X}" for b in ops[i:i + 16])
            lines.append(f"    db {row}")
        lines.append("")
    lines.append(f"; total enhancement stream bytes: {total}")
    lines.append("")
    return "\n".join(lines)


def main():
    rom = AudioROM()
    streams = {}
    table: dict[int, dict[int, str]] = {}
    for path in sorted(ENHANCE_DIR.glob("*.yaml")):
        label = path.stem
        rep, resolved, analysis = lint(path)
        if rep.errors:
            print(f"  {label}: lint FAILED — skipped "
                  f"({len(rep.errors)} errors; run yaml_lint.py for detail)")
            continue
        msgs = []
        result = compile_song(resolved, analysis, msgs.append)
        for m in msgs:
            print(f"  {label}: {m}")
        if result is None:
            continue
        streams[label] = result
        bank = rom.sym_bank[label]
        table.setdefault(bank, {})[sound_id(rom, label)] = label

    out = ASSETS / "enh_streams.inc"
    out.write_text(emit_inc(streams, table, rom.banks()))
    total = sum(len(o) + 2 for o, _ in streams.values())
    print(f"enh_streams.inc: {len(streams)} streams, {total} bytes")


if __name__ == "__main__":
    main()
