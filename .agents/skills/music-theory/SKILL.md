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

## Terminology — track vs voice vs channel

Shared convention — use these words consistently with each other and in
comments / commit messages, since they otherwise collide:

- **Track** — a whole song / piece: the thing named by a `MUSIC_*` label
  (e.g. `Music_GymLeaderBattle`) and selected by the `TRACK=` audition knob.
  Synonym in code and analysis output: **song**.
- **Voice** — a single melodic line (melody, bass, an inner line, an added
  harmony line). This is the music-theory unit: voice leading, doubling, and
  polyphony / "voice count" all count voices.
- **Channel** — the concrete carrier of a voice: a GB hardware channel (1–4),
  a MIDI channel, or one entry in an enhancement YAML's `channels:` list. One
  channel normally carries one voice; a chord written as an `n`-list packs
  several voices onto a single channel.
- **Part** — MT-32-only term for its eight melodic parts + rhythm part. Use it
  only when discussing MT-32 routing, not as a synonym for voice or channel.

Rule of thumb between us: **"track" = the whole song, "voice" = one line.**
When you mean the YAML / hardware carrier, say **"channel."**

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
- **Never double the GB melody in unison** — wastes a voice, creates parallel 8ves.
  (Exception: percussion channels — `rhythm: true`, `percussion: true`, or a GM
  percussion program — may share pitches freely; the linter exempts them automatically.)
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


