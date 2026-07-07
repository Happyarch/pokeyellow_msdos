# MT-32 Hardware Constraints for Tier 2–3 Enhancements

Quick-reference for what MT-32 offers beyond OPL3. For the full SysEx
and patch memory reference, see `docs/sound/` (MT-32 sections in the
MIDI/SB manuals).

---

## Architecture

The MT-32 uses **LA (Linear Arithmetic) synthesis**: each patch combines
up to 4 **partial oscillators**, each of which is either:
- A **PCM sample** (attack transient from ROM — piano hammer, string bow)
- A **synthesized waveform** (square, sawtooth) with TVA/TVF envelopes

This gives MT-32 patches a **realistic attack + sustained synth body**
that OPL3's pure FM can't match.

---

## Voice / Partial Budget

| Resource | Count |
|----------|-------|
| Partial oscillators | **32 total** |
| Melodic parts | 8 (MIDI channels 2–9) |
| Rhythm part | 1 (MIDI channel 10) |
| Partials per patch | 1–4 (most preset patches use 2) |

### Partial reserves
The `timbres.yaml` file sets a **partial reserve** for each part in a
single SysEx message. The reserves determine the *guaranteed minimum*
partials per part. Excess partials are shared dynamically.

**Example**: if 8 parts each reserve 3 partials = 24 reserved, leaving
8 dynamic. Parts that need more than their reserve steal from the pool.

### Budget for enhancements
- Tier-1 cascaded voices use some partials (typically 2 per voice × 4–6
  voices = 8–12 partials)
- Tier 2–3 voices get the remainder
- A 2-partial string patch × 4 tier-2 voices = 8 more partials
- **Stay under 28–30 total** to avoid voice stealing during peaks

### What happens when partials run out
The MT-32 steals the oldest/quietest note's partials. This causes
audible note cuts. Avoid it by staying within budget. The compiler
counts worst-case per-tick partial usage and warns if over limit.

---

## What LA Synthesis Can Do That FM Can't

| Capability | MT-32 | OPL3 |
|-----------|-------|------|
| PCM attack transients | ✓ (piano, strings, brass from ROM) | ✗ |
| Natural vibrato with LFO | ✓ (per-partial, pitch + filter) | Limited (no per-voice LFO) |
| Filter sweeps (TVF) | ✓ (resonant low-pass per partial) | ✗ |
| Amplitude envelopes (TVA) | ✓ (5-stage ADSR per partial) | Rough (4-bit ADSR) |
| Built-in reverb | ✓ (3 modes: room, hall, plate) | ✗ |
| Ring modulation | ✓ (between partial pairs) | ✗ |
| Key velocity response | ✓ | ✗ |

### Patches that exploit these
- **Strings**: PCM bow attack + sustained sawtooth body + slow vibrato
- **Choir**: PCM "aah" sample + sustained pad body
- **Piano**: PCM hammer attack + quick decay synth body
- **Brass ensemble**: PCM swell + sustained brass body + reverb
- **Atmospheric pads**: filter sweep + reverb + slow attack

---

## Patch Selection Guide

### Using preset patches (program change)
The MT-32 has 128 preset patches. Numbers below are **1-based** (Roland
manual convention; the MIDI Program Change byte is the number minus 1).
The MT-32 and GM patch maps are **different** — always give both fields:

| Use case | MT-32 preset (`mt32_patch`) | GM equivalent (`gm_program`) | Notes |
|----------|---------------------------|------------------------------|-------|
| String pad | 49 Str Sect 1, 50 Str Sect 2 | 49 String Ensemble 1 | 2–4 partials |
| Warm/atmospheric pad | 33 Fantasy, 38 Atmosphere, 42 Ice Rain | 89 Pad 1 (New Age), 100 FX 4 (Atmosphere) | The MT-32 synth-pad group is 33–48 |
| Brass | 96 Brs Sect 1, 89 Trumpet 1 | 62 Brass Section, 57 Trumpet | Punchy, good for stabs |
| Choir | 35 Chorale | 53 Choir Aahs | Partial-hungry (often 4) |
| Piano | 1 Acou Piano 1 | 1 Acoustic Grand | Good for comping |
| Bell/chime | 23 Celesta 1, 103 Tube Bell, 39 Warm Bell | 9 Celesta, 15 Tubular Bells | Accent use |

### Using custom timbres
`timbres.yaml` can define custom timbres uploaded via SysEx at init.
Custom timbres are stored in MT-32's timbre memory (64 slots: 2 banks
of 32). Use custom timbres when:
- You need a specific partial configuration
- Preset patches don't match the desired sound
- You want to reduce partial usage (a 1-partial custom patch is cheaper)

### GM equivalents
For `gm_program`, use the closest GM equivalent. **GM and MT-32 patch
numbers do NOT align** — GM was standardized later with a different
layout (this is why unpatched MT-32 games sound wrong on GM synths and
vice versa). Pick each number independently from its own map. GM map:
`docs/sound/general_midi_level_1_developer_guidelines.md`.

---

## MIDI Channel Assignment

| Channel | Usage |
|---------|-------|
| 1 | Unassigned in the MT-32's default part table (usable only if reassigned via SysEx) |
| 2–9 | Melodic parts (available for base + enhancement) |
| 10 | Rhythm part (drum map) |
| 11–16 | GM only (MT-32 ignores channels > 10) |

Enhancement voices are assigned to channels by the compiler. The base
GB music uses **3 melodic parts + the rhythm part** (`gb_to_midi.py`:
GB ch1/2/3 → melodic, noise ch4 → channel 10 drums), leaving **5
melodic parts** for tier 1 + tier 2–3 combined. If the total exceeds
the 8 melodic parts, the compiler drops lowest-tier channels.

---

## Reverb

MT-32 has built-in reverb (set via SysEx at init):
- **Mode 0**: Room — short, tight
- **Mode 1**: Hall — medium, spacious
- **Mode 2**: Plate — bright, diffuse

Reverb level and time are global (not per-part). The current
`timbres.yaml` sets reverb mode, level, and time for the whole session.

**For arrangement**: you can *assume* reverb is present on MT-32 and
write parts that benefit from it (sustained strings, choir). But the
notes must still sound acceptable *without* reverb (for GM synths that
may have weaker or no reverb).
