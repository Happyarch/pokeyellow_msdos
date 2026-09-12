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
`tools/audio/mt32/timbres.yaml` defines custom synthesis timbres uploaded
into MT-32 User Timbre RAM (`08 00 00`..`08 7E 00`) via SysEx at game init.
Up to 64 custom timbres can reside in Timbre RAM. Use custom timbres when:
- You need a specific partial configuration (e.g. analog saw, authentic vocal vowel)
- Preset patches don't match the desired sound
- You want to reduce partial usage (a 1-partial custom patch is cheaper)

**On-the-fly dynamic patch pointer remapping & eager restore**:
Rather than permanently overwriting factory patch memory at boot (which would
destroy factory presets like #12 `Elec Org 4` or #27 `Syn Brass 1` for all other
tracks), custom timbres are assigned a target patch slot in `timbres.yaml`
(`patch: <1-128>`) and remapped on the fly:
1. **Declare by name**: In track YAMLs (`overrides/*.yaml` or
   `enhancements/*.yaml`), specify the timbre by name as a string:
   `mt32_program: "Theremin"` or `mt32_patch: "NightWind"`.
2. **Setup SysEx on track start**: When the track begins, the sound driver
   transmits a tiny length-prefixed DT1 SysEx message (18 bytes per custom
   patch, ~5.4 ms over UART) that points that patch slot to the custom timbre.
3. **Eager Cleanup SysEx on track stop/unload**: When the track ends or another
   track loads, the driver transmits a companion cleanup SysEx (18 bytes) that
   immediately restores the modified patch slot back to factory parameters.
4. **Clean factory state**: All 128 factory presets remain 100% available and
   undistorted for any subsequent track.

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
the 8 melodic parts, the compiler drops whole layers **highest tier
number (lowest priority) first** — tier 3 before tier 2 before tier 1
(`gb_to_midi.py:enhancement_tracks`).

---

## Timed program switches (MIDI path)

A per-channel `switches:` list (in `overrides/*.yaml` for GB voices,
`enhancements/*.yaml` for added voices) emits a MIDI program change on that
channel mid-song. The full arranger workflow — placement law, worked
example, loop intents — lives in the
[skill](../SKILL.md#timed-program-switches-mt-32gm-only); this section is
the numbering and verification detail.

### Per-target programs

Every switch carries the same pair as its channel: `mt32_program` for the
MT-32 stream, `gm_program` for the GM stream. The two maps do NOT align
(the same reason the channel-level `mt32_patch` / `gm_program` pair
exists), so give both on every switch.

### The numbering trap — ship preset NAMES, not numbers

If a number must be read or written, know which convention the file uses:

| File | Integer convention |
|------|--------------------|
| `overrides/*.yaml` | **0-BASED** (raw MIDI Program Change byte: 0–127) |
| `enhancements/*.yaml` | **1-BASED** (Roland manual convention, same as `mt32_patch` / `gm_program`: 1–128) |

A bare `64` therefore means two different patches depending on which file
it sits in. **Avoid the trap by shipping preset NAMES** (strings, e.g.
`mt32_program: "Violin 1"`) — names are convention-free, and they are what
the skill's worked example uses. If a number is unavoidable, check the
table first: the file's base is the whole ballgame.

### Placement verification (what the linter checks)

- **ERROR**: a switch strictly inside a same-channel note span. Move it
  into a rest, onto a note-off boundary, or coincident with a note-on.
- **WARN (case-aware)**: a switch in the intro, just before loop entry, or
  creating first-pass divergence (init X + mid-loop switch to Y). Each maps
  to one of the skill's four loop intents — confirm the intent matches,
  then move the switch or keep it deliberately. The toolchain flags; it
  never auto-fixes.
- **Tier is per-channel**: a switch never changes a channel's tier. If the
  compiler drops a whole layer (highest tier number first — tier 3 before
  tier 2 before tier 1), that layer's switches go with it; surviving layers
  are unaffected.
- **MIDI-path-only**: switches emit on the MT-32/GM MIDI streams. OPL3 FM
  voices are fixed-patch per voice; there is no OPL3 program-change
  mechanism, so switches never touch `opl_patch`.

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
