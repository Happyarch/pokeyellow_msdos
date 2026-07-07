# Voicing, Spacing, and Register Ranges

This reference covers how to place notes vertically — which octave, how
far apart, what to double, and what to avoid.

---

## Register Ranges

### Practical ranges for arrangement parts

| Voice | Range | Notes |
|-------|-------|-------|
| Bass reinforcement | C2–E3 | Keep intervals wide (≥P5). Octaves safest. |
| Tenor pad | C3–G4 | Core harmony voice. Can sustain or move. |
| Alto pad | F3–C5 | Counter-melody territory. |
| Melody (GB pulse 1) | C4–C6 | Already occupied — don't compete. |

These are practical ranges for the **arrangement context**, not absolute
instrument limits. OPL3 and MT-32 can produce notes outside these, but
parts written in these ranges will sound best and avoid clashing.

### OPL3-specific
FM synthesis has no hard range limit, but very low notes (below C2)
become indistinct rumbles and very high notes (above C6) become piercing.
Stay within the ranges above.

### MT-32-specific
Each MT-32 patch has a defined key range. The default range covers most
of the above, but extreme registers may trigger fallback patches. The
`timbres.yaml` file can adjust key ranges if needed.

---

## Spacing Rules

### Below C3: Wide spacing only
Low intervals sound muddy due to the harmonic series. Rules:

| Interval below C3 | OK? |
|-------------------|-----|
| P8 (octave) | ✓ Best choice |
| P5 | ✓ Acceptable |
| P4 | ✗ Muddy |
| M3, m3 | ✗ Very muddy |
| M2, m2 | ✗ Unusable mud |

**Practical rule**: below C3, only use octaves and fifths. Above C3,
thirds and sixths sound fine.

### Adjacent upper voices: stay within an octave
Between any two adjacent non-bass voices, don't exceed a P8. Larger
gaps create a hole in the texture that sounds hollow.

```
GOOD:                    BAD:
Alto: E4                 Alto: E4
Tenor: A3  (P5 apart)   Tenor: C3  (M10 apart — gap too wide)
```

### Bass to tenor: can exceed an octave
The bass naturally sits further from the upper voices. A gap of a 10th
or even two octaves between bass and tenor is normal and sounds fine.

---

## Open vs. Close Position

**Close position**: all upper voices within an octave of each other.
Sounds thick and full. Good for: battle themes, climactic moments,
fanfares.

```
Close: C4–E4–G4 (all within P5)
```

**Open position**: upper voices spread across more than an octave.
Sounds spacious and transparent. Good for: town themes, peaceful
areas, atmospheric sections.

```
Open: C3–G3–E4 (spread across M10)
```

**For GB arrangement**: since you're adding only 1–3 voices on top of
existing channels, open position is usually more appropriate — it fills
in the gaps rather than clustering near the melody.

---

## Doubling

### What to double
- **Root**: safest choice, always works
- **5th**: fine, especially in open position
- **3rd**: use sparingly — can make the chord sound thick/lopsided

### What NOT to double
- **Leading tone** (*ti*, scale degree 7): creates voice-leading
  problems because both doubled voices want to resolve to *do*,
  creating parallel octaves or an awkward voice-leading choice
- **Chord 7th**: the 7th needs to resolve down; doubling it means
  two voices resolving to the same note
- **Chromatic alterations**: any altered note (♯4, ♭6, etc.) has a
  strong tendency — doubling it doubles the problem

### In the GB context
The melody already occupies one chord tone. Your added parts should
fill in **different** chord tones rather than doubling the melody.
If the melody is on the 3rd, your pad should be on the root or 5th.

**Never double the melody in unison** — it wastes a voice, sounds thin
rather than rich, and creates de facto parallel octaves with itself.
Doubling at the octave below is acceptable (bass reinforcement) but
should be a deliberate choice, not a default.

---

## Texture and Density Matching

### Sparse textures (1 added voice)
- Towns, Pokémon Centers, quiet routes
- One sustained pad on the 3rd or 5th, mid register
- Let the GB track breathe

### Medium textures (2 added voices)
- Routes, gyms, menus with drama
- Pad + bass reinforcement, or pad + counter-melody
- More filling but still transparent

### Dense textures (3+ added voices)
- Battle themes, climactic moments, title screen
- Full harmony: bass + two inner voices
- Can include rhythmic elements

### Rule of thumb
Count the total active voices (GB channels + your additions). For
Pokémon Yellow's aesthetic:
- Town music: 5–6 total voices max
- Battle music: 7–8 total voices max
- Never exceed the target hardware's polyphony limit

---

## Checklist

```
For each added voice:
  □ Within the practical range for its voice type
  □ Below C3: only octaves and fifths with other low voices
  □ Adjacent to upper voices: within an octave
  □ Not doubling the melody in unison
  □ Not doubling the leading tone or chord 7th
  □ Texture density matches the emotional context
  □ Open/close position is deliberate, not accidental
```
