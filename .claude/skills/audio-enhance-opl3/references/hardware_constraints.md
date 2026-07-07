# OPL3 Hardware Constraints for Tier-1 Enhancements

Quick-reference for what OPL3 can and can't do. For the full register-level
reference, see `docs/sound/OPL3_YMF262.md`.

---

## Voice Count

- **18 melodic voices** in OPL3 mode (9 per register array)
- Each voice uses **2 operators** (carrier + modulator) in standard mode
- 4-operator mode available on 6 voices (pairs voices 0+3, 1+4, 2+5 from
  each array) — richer timbre but halves usable voice count for those slots
- **Rhythm mode** repurposes the 6 operators of channels 7–9 into five
  percussion instruments (bass drum 2 ops; snare, hi-hat, tom, cymbal
  1 op each) — rarely worth it for this project (the GB noise channel
  handles percussion via the shim)

### Voice budget for enhancements
| Usage | Voices |
|-------|--------|
| APU shim (music channels 1–4) | 4 |
| APU shim (SFX overlap, /SFXOVERLAP) | up to 4 |
| **Available for enhancements** | **~10** |
| Recommended per-song tier-1 budget | 4–6 |

Leave 4–6 voices as headroom for SFX overlap and future needs.

---

## Available Patch Palette

Enhancement patches come from `gen_opl_patches.py` (Tier-1 data,
`assets/opl_patches.inc`). The shim already uses 4 pulse-duty variants
+ a wave-channel approximation + a noise patch. Enhancement patches
should use **different timbral families** to avoid clashing.

Good candidates for enhancement patches:
- **Organ-like sustained** (low feedback, sine-ish carrier)
- **Soft pad** (low modulator depth, slow attack)
- **Brass stab** (high modulator depth, fast attack, short sustain)
- **Sub-bass** (sine carrier, no modulator, low octave)
- **Bell/chime** (high frequency ratio modulator)

The exact patch names and parameters are in `gen_opl_patches.py`'s
`PATCHES` dict. When the palette doesn't cover what you need, add a
new patch to the generator — don't hand-encode register values.

---

## FM Synthesis Characteristics (What Shapes Your Arrangement)

### Things FM does well
- **Sustained tones**: organ, pad, brass — hold a note cleanly
- **Punchy attacks**: brass stabs, plucked sounds — fast transients
- **Clean bass**: sine waves in low registers — solid foundation
- **Bell-like tones**: metallic, crystalline — good for accents

### Things FM does poorly
- **Realistic strings**: no bowing nuance, no natural vibrato envelope
- **Choir/vocal**: no formant structure
- **Evolving textures**: OPL3 has no real-time parameter automation
  (the shim doesn't interpolate register writes between ticks)
- **Reverb/space**: no built-in effects — dry only
- **Subtle dynamics**: volume is 0–63 in ~0.75 dB steps (coarse),
  no velocity sensitivity per note

### Implications for arrangement
- Pads will sound **organ-like**, not string-like. Embrace it.
- Don't write parts that rely on dynamic shaping within a note.
- Rhythmic parts work best when the attack/decay of the patch does
  the shaping (fast attack, controlled decay).
- Low bass works great (sine carrier) — use it for reinforcement.

---

## Stereo

- OPL3 supports per-voice L/R/both panning (register C0h bits 4–5)
- The shim mirrors GB's `rAUDTERM` stereo assignments
- Enhancement voices can set their own pan in the YAML (`pan: left`,
  `right`, or `center`)
- Dual-OPL2 boards (SB Pro 1.0) have per-chip L/R — same effective
  capability but voices are split across two chips

---

## Timing

- Enhancement voices are driven by a **frame-delta stream player**
  at 60 Hz (same as the APU shim tick rate)
- Note events resolve to the nearest frame (16.7 ms granularity)
- This is identical to the GB engine's timing resolution — no audible
  timing artifacts
