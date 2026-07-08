#!/usr/bin/env python3
"""gen_opl_patches.py — generate the OPL shim's FM patch + attenuation tables.

Output: assets/opl_patches.inc (Tier-1 generated data, DO NOT EDIT BY HAND).

THE PATCHES DICT BELOW IS THE HAND-TUNING SURFACE (audio plan: "hand-editable
FM patch table"). Edit it here, re-run `make assets`, audition in DOSBox-X.

All patches are OPL2-compatible 2-op (waveforms 0-3 only, no 4-op), per the
plan's SB Pro floor. Each patch is 11 bytes, the order the shim expects:

    [m20, m40, m60, m80, mE0,  c20, c40, c60, c80, cE0,  C0]

    x20  AM|VIB|EGT(sustain)|KSR|MULT      x60  attack<<4 | decay
    x40  KSL<<6 | total level (0-63)       x80  sustain<<4 | release
    xE0  waveform select (0-3 on OPL2)     C0   feedback<<1 | connection
                                                (pan bits added at runtime)

The GB envelope is emulated in software (the shim rewrites the carrier TL
every tick from the virtual APU's NRx2 state), so every patch here uses an
organ-style FM envelope: instant attack, full sustain, quick release — the
audible volume shape comes from the GB data, not from OPL EG settings.
"""

from __future__ import annotations

import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "opl_patches.inc"

# EG constants shared by all patches: attack=15 (instant), decay=0,
# sustain level=0 (loudest), release=7 (quick, clickless).
AD = 0xF0
# Eased attack for the pulse voices (user audition 2026-07-07: "let off the
# attack some"): rate 12 = a few ms of onset ramp, declicking each key-on
# without smearing fast 16th-note figures. Wave keeps AD (long held notes,
# already ear-signed-off); noise keeps AD (drum hits must stay instant).
AD_PULSE = 0xC0
SR = 0x07
SUS = 0x20  # reg 0x20 bit 5: sustaining envelope (hold at sustain level)
# Carrier Key Scale Level, reg x40 bits 6-7. Value 2 (0x80) = 1.5 dB/oct —
# the gentle treble shelf a real GB speaker imposes; tames the piercing
# top-octave notes (user audition 2026-07-07, Lavender C6-B6 melody:
# "eardrum destroyers on good tweeters"). NB the OPL bit values are
# swapped vs intuition: 1 = 3.0 dB/oct, 2 = 1.5 dB/oct (YMF262 doc).
KSL = 0x80

# name -> 11-byte patch. Pulse duty variants map the GB's 4 duty cycles onto
# increasing FM brightness (more modulator level / feedback = buzzier).
# GB duty 75% is aurally identical to 25% (inverted waveform), so it shares
# the 25% timbre.
#
# Pulse softening pass (user audition 2026-07-07, Lavender Town: "very
# grating on almost all channels") — same reasoning as the wave fix below:
# the GB speaker's low-pass is part of the intended sound and clean FM has
# no equivalent, so tame the high-harmonic sources while preserving the
# duty-cycle brightness ORDERING (125 buzziest > 25/75 > 50 roundest):
#   - feedback halved across the pulses (6/5/3 -> 3/2/1) — feedback
#     self-brightening was the dominant edge, as it was on the wave
#   - modulator TL backed off ~7.5 dB (m40 +0x0A) — sidebands stay, whistle
#     goes
PATCHES = {
    #                m20        m40   m60  m80  mE0   c20        c40   c60  c80  cE0   C0
    "duty_125": [SUS | 0x01, 0x16, AD_PULSE, SR, 0x00, SUS | 0x01, KSL | 0x00, AD_PULSE, SR, 0x00, 0x06],
    "duty_25":  [SUS | 0x01, 0x1A, AD_PULSE, SR, 0x00, SUS | 0x01, KSL | 0x00, AD_PULSE, SR, 0x00, 0x04],
    "duty_50":  [SUS | 0x02, 0x1E, AD_PULSE, SR, 0x00, SUS | 0x01, KSL | 0x00, AD_PULSE, SR, 0x00, 0x02],
    "duty_75":  [SUS | 0x01, 0x1A, AD_PULSE, SR, 0x00, SUS | 0x01, KSL | 0x00, AD_PULSE, SR, 0x00, 0x04],
    # Wave channel: soft, rounded bass/counter-melody voice. The GB wave is
    # harsh at the source too, but the console's tiny speaker low-passes the
    # highs away; clean FM has nothing rolling them off, so we emulate that by
    # stripping the patch's high-harmonic sources (user audition 2026-07-07):
    #   - sine carrier (cE0 0x00, was half-sine 0x01) — half-sine is bright
    #   - no feedback (C0 0x00, was 0x04 = fb 2) — feedback self-brightens the
    #     modulator, the biggest edge; gone now
    #   - gentler modulator (m40 0x28, was 0x18) — keeps a little FM warmth;
    #     0x28 is the "just a hair softer" final nudge (user audition 2026-07-07)
    # Carrier base TL 0x06 (~4.5 dB): the wave holds a flat NR32 level while the
    # pulses decay via their envelopes, so at parity it read as too loud.
    "wave":     [SUS | 0x01, 0x28,  AD,  SR, 0x00, SUS | 0x01, 0x06,  AD,  SR, 0x00, 0x00],
    # Noise channel: high-multiple modulator at full level with max feedback
    # produces dense inharmonic hash — the closest 2-op non-rhythm-mode noise.
    "noise":    [SUS | 0x0F, 0x00, 0xF0, 0x06, 0x00, SUS | 0x01, 0x00, 0xF0, 0x06, 0x00, 0x0E],
    # --- Tier-1 enhancement patches (Phase E) ------------------------------
    # Indices 6+; the APU shim only ever loads 0-5, the enh stream player
    # (opl_enh.asm) loads these by the index gen_enh_streams.py bakes in.
    # A timbral family deliberately *unlike* the buzzy pulse variants above:
    # clean sines, so added voices sit under the shim's pulses, not fight them.
    #
    # Sub-bass reinforcement: pure carrier sine (modulator fully attenuated ->
    # no FM sidebands), the deep low end the GB deliberately omitted (small
    # speaker; see the Pallet Town score note). Carrier TL is the player's
    # per-note volume slot.
    "sub_bass": [SUS | 0x01, 0x3F,  AD,  SR, 0x00, SUS | 0x01, 0x00,  AD,  SR, 0x00, 0x00],
    # Soft pad: sine carrier with a gentle 1:1 modulator (TL 0x18) for a hair
    # of warmth — organ-like, not string-like (FM can't do bowed strings).
    # Instant-attack/full-sustain like every patch here; the held note length
    # comes from the YAML, the volume from the player. Warm, never buzzy.
    "soft_pad": [SUS | 0x01, 0x18,  AD,  SR, 0x00, SUS | 0x01, 0x00,  AD,  SR, 0x00, 0x00],
    # Clean base-channel voice for songs where two duty-cycle pulse channels
    # form a chord and the FM buzz (feedback + modulator sidebands) reads as
    # a mistuned clash rather than a blend — Mt. Moon Cave's augmented-triad
    # ch1/ch2 arpeggio (user audition 2026-07-07: "trying to make chords and
    # failing" / "plucking an untuned guitar"). Pure carrier sine (modulator
    # silent), no feedback, instant attack: closest FM equivalent of the
    # thin, low-harmonic real GB square wave, so simultaneous dissonant
    # chords stay in tune even when they don't stay consonant (by design —
    # the augmented harmony IS the point). Carrier keeps the KSL treble
    # shelf like the other base-channel voices.
    "duty_clean": [SUS | 0x01, 0x3F, AD, SR, 0x00, SUS | 0x01, KSL | 0x00, AD, SR, 0x00, 0x00],
}

PATCH_ORDER = ["duty_125", "duty_25", "duty_50", "duty_75", "wave", "noise",
               "sub_bass", "soft_pad", "duty_clean"]

# Per-song OPL patch overrides for the BASE channels (tier 0). Normally a
# base channel's FM patch is picked purely from the GB duty-cycle value
# (NRx1 bits 7-6), shared across every song using that duty — see
# opl_shim.asm's voice_keyon/opl_pass. Some songs need a channel-specific
# bespoke patch instead of the shared duty_* voice without disturbing every
# other song that shares it. Keyed by the numeric music id (see
# assets/audio_constants.inc's MUSIC_* equ values); each row is
# (ch1, ch2, ch3, ch4), entries either a patch name or None (no override,
# fall back to the duty-based default).
SONG_OPL_OVERRIDES = {
    0xE7: ("duty_clean", "duty_clean", None, None),  # MUSIC_DUNGEON3 (Mt. Moon Cave)
}


def att_units(ratio: float) -> int:
    """dB attenuation for an amplitude ratio, in OPL 0.75 dB TL units."""
    return min(63, round(20 * math.log10(ratio) / 0.75))


def main():
    lines = [
        "; opl_patches.inc — generated by tools/audio/gen_opl_patches.py.",
        "; DO NOT EDIT BY HAND — tune the PATCHES dict in the generator.",
        "",
        "; 11 bytes per patch: m20 m40 m60 m80 mE0  c20 c40 c60 c80 cE0  C0",
        "OPL_PATCH_SIZE equ 11",
        "OplPatches:",
    ]
    for i, name in enumerate(PATCH_ORDER):
        row = ", ".join(f"0x{b:02X}" for b in PATCHES[name])
        lines.append(f"    db {row}  ; {i}: {name}")

    # GB envelope volume (0-15) -> carrier TL attenuation. 0 = force-mute
    # (the shim special-cases it to 63 regardless, but keep the table sane).
    vol = [63] + [att_units(15 / v) for v in range(1, 16)]
    lines += [
        "",
        "; GB envelope volume 0-15 -> TL attenuation (0.75 dB units)",
        "OplVolTable:",
        "    db " + ", ".join(str(v) for v in vol),
    ]

    # NR50 master volume 0-7 -> attenuation (vol+1 out of 8).
    master = [att_units(8 / (m + 1)) for m in range(8)]
    lines += [
        "",
        "; NR50 master volume 0-7 -> TL attenuation",
        "OplMasterAttTable:",
        "    db " + ", ".join(str(v) for v in master),
    ]

    # NR32 wave output level 0-3: mute / 100% / 50% / 25%.
    lines += [
        "",
        "; NR32 wave level 0-3 -> TL attenuation (0 = mute)",
        "OplWaveLevelAtt:",
        f"    db 63, 0, {att_units(2)}, {att_units(4)}",
        "",
    ]

    # Per-song base-channel patch overrides: music_id, ch1, ch2, ch3, ch4
    # (0xFF = no override -> duty-based default). Sentinel row 0xFF ends it.
    lines += [
        "; per-song OPL patch overrides (see SONG_OPL_OVERRIDES above)",
        "OplSongPatches:",
    ]
    for music_id, chs in SONG_OPL_OVERRIDES.items():
        row = [music_id] + [PATCH_ORDER.index(c) if c else 0xFF for c in chs]
        lines.append("    db " + ", ".join(f"0x{b:02X}" for b in row)
                      + f"  ; music id 0x{music_id:02X}")
    lines.append("    db 0xFF  ; sentinel")
    lines.append("")

    OUT.write_text("\n".join(lines))
    print(f"opl_patches.inc: {len(PATCH_ORDER)} patches + attenuation tables")


if __name__ == "__main__":
    main()
