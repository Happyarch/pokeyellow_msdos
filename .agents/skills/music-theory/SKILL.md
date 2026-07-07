---
name: music-theory
description: >
  Standalone music theory knowledge for analyzing and arranging Game Boy
  video-game music. Covers chord identification from melody+bass, voice
  leading, voicing/spacing, harmonic function, and common arrangement
  mistakes. Loaded by audio-enhance-opl3 and audio-enhance-mt32 but can
  also be invoked independently for analysis or reviewing hand-written
  arrangements. Triggers: "music theory", "chord identification",
  "voice leading", "voicing", "harmonic analysis", "arrangement review",
  "what chord is this", "parallel fifths", "how to harmonize".
---

# Music Theory for Game Boy Arrangement

You are adding orchestration to 4-channel Game Boy music. This skill gives
you the minimum theory to do that well, with pointers to deeper reference
when you need it.

**Your job is narrow**: given a GB track (melody, bass, inner voice, noise)
with analyzed harmony, add extra channels that sound good and don't break
voice-leading rules. You are NOT doing free composition, large-scale form
analysis, or atonal theory.

---

## The Arrangement Workflow

Every arrangement pass follows this sequence:

1. **Identify the key** — read the analysis or infer from opening/closing notes
2. **Read the chord progression** — from `music_analysis.py` output or by ear
3. **Decide what's missing** — does the track need warmth? drive? depth?
4. **Choose a texture** — pad, counter-melody, bass reinforcement, rhythmic comp
5. **Write the notes** — chord tones on strong beats, follow voice-leading rules
6. **Check your work** — run through the checklist below

---

## When to Consult References — Decision Flowchart

```
START: You're about to write or review an arrangement
  │
  ├─ "I need to figure out what chords the GB track is playing"
  │     └─► Read: references/chord_identification.md
  │           Covers: inferring harmony from melody+bass, arpeggiated
  │           patterns, passing tones vs chord tones, common Pokémon
  │           progressions, harmonic function (T/S/D)
  │
  ├─ "I've got the chords. Now I need to write parts that don't clash"
  │     └─► Read: references/voice_leading.md
  │           Covers: parallel 5ths/8ves prohibition, resolution rules,
  │           contrary motion, common tones, voice crossing, the full
  │           checklist with correct/incorrect examples
  │
  ├─ "My parts sound muddy / too high / too crowded"
  │     └─► Read: references/voicing_and_ranges.md
  │           Covers: register ranges for each voice type, open vs close
  │           position, spacing rules, doubling do's and don'ts, what
  │           to avoid below C3
  │
  ├─ "I don't understand how the original GB track is structured"
  │     └─► Read: references/gb_music_idioms.md
  │           Covers: how the original composers used each of the 4
  │           channels (arpeggiated bass, pulse melody, wave as
  │           secondary voice, noise patterns), common textures per
  │           game-area type, phrasing conventions
  │
  └─ "I hit something weird — modal mixture, applied dominants,
      a modulation, or I need the textbook definition of something"
        └─► Read: references/textbook/
              Contains the stripped Open Music Theory chapters:
              intervals, triads, harmonic functions, cadences,
              counterpoint species, embellishing tones, applied chords,
              modal mixture, modulation. Deep fallback — read only the
              section you need.
              Source: docs/references/openmusictheory.github.io/
                      open_music_theory_distilled.md
```

---

## Quick-Reference Card (always in context)

### Voice-Leading Prohibitions
- **No parallel P5→P5 or P8→P8** between any pair of voices (including GB channels)
- **No direct/hidden 5ths or 8ves** into a perfect interval by similar motion (outer voices)
- **No voice crossing** — keep each part in its lane

### Voice-Leading Preferences
- Resolve *ti* → *do* (leading tone up), chord 7ths down by step
- Retain common tones between consecutive chords
- Prefer contrary motion; move inner voices by step
- Leaps > P5 should be followed by step in the opposite direction

### Voicing Minimums
- Double the **root** (not the leading tone, not the 7th)
- **Never double the GB melody in unison** — wastes a voice, creates parallel 8ves
- Below C3: keep intervals ≥ P5 (octaves safest); it gets muddy otherwise
- Adjacent upper voices: stay within a P8 of each other

### Phrasing
- **Rest where the GB rests** — don't fill silence
- **Match cadence weight**: full voicing at PAC, thin at HC, don't pile on deceptive cadences
- **Match texture to context**: town = warm pads, battle = driving rhythm, cave = sparse

### Harmonic Function Cycle (the spine of tonal music)
> **T → S → D → T** → repeat
>
> T = I, iii, vi · S = ii, IV · D = V, vii°

---

## Reference Index

| File | What it covers | When to read it |
|------|---------------|-----------------|
| [chord_identification.md](references/chord_identification.md) | Inferring chords from GB channels, harmonic function, cadences, common Pokémon progressions | Before writing any arrangement — you must know the harmony first |
| [voice_leading.md](references/voice_leading.md) | Parallel motion rules, resolution rules, contrary/oblique/similar motion, worked examples | While writing parts, or when reviewing for errors |
| [voicing_and_ranges.md](references/voicing_and_ranges.md) | Register ranges, spacing, doubling, open/close position | When parts sound muddy, thin, or out of range |
| [gb_music_idioms.md](references/gb_music_idioms.md) | How original composers used 4 GB channels, texture patterns per area type | Before starting any arrangement — understand what you're adding to |
| [textbook/](references/textbook/) | Full stripped Open Music Theory chapters (intervals, triads, counterpoint, chromatic harmony) | Deep fallback for anything unusual not covered above |


