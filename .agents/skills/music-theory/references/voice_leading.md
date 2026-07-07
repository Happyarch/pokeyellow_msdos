# Voice Leading Rules

Voice leading governs how individual lines move from chord to chord.
These rules apply to **every pair of voices** — including between your
added parts and the existing GB channels.

---

## Absolute Prohibitions

### 1. No parallel perfect fifths (P5 → P5)

Two voices a P5 apart, both moving in the same direction to another P5.

```
BAD:                         GOOD:
Voice A:  C → D              Voice A:  C → D
Voice B:  G → A (P5 → P5)   Voice B:  G → F (P5 → m6, contrary)
```

This includes compound intervals: P5 → P12 counts as parallel fifths.

### 2. No parallel perfect octaves (P8 → P8)

Same principle. Two voices an octave apart moving in parallel.

```
BAD:                         GOOD:
Voice A:  C → D              Voice A:  C → D
Voice B:  C → D (P8 → P8)   Voice B:  C → B (P8 → M3, contrary)
```

### 3. No direct (hidden) fifths or octaves

Two voices moving in **similar motion** (both up or both down) into a
P5 or P8, even if the starting interval is different. Most critical
between the outer voices (highest and lowest sounding parts).

```
BAD:                         ACCEPTABLE (inner voices):
Melody:   E → G (up)        Inner:  E → G (up)
Bass:     F → C (up → P5)   Inner2: A → C (up → P5, both inner)
```

**Exception**: direct fifths between inner voices are less problematic
and sometimes unavoidable. Focus enforcement on outer-voice pairs.

---

## Resolution Rules

### 4. Leading tone (*ti*) resolves up to *do*

Especially in outer voices. In inner voices, the leading tone may
occasionally drop to *sol* (5th of the tonic chord) to avoid doubling
problems — but only in inner voices.

```
GOOD:                        BAD:
V → I                        V → I
B → C (ti → do, up by step)  B → A (ti drops — avoid in soprano/bass)
```

### 5. Chord 7ths resolve down by step

The 7th of a V7 (or any seventh chord) steps down:

```
V7 → I in C major:
F → E (the 7th, fa, resolves down to mi)
```

### 6. Diminished 5ths resolve inward, augmented 4ths resolve outward

The tritone (B–F in C major) resolves:
- B → C (up by step)
- F → E (down by step)

---

## Motion Types

| Type | Definition | Usage |
|------|-----------|-------|
| **Contrary** | Voices move in opposite directions | Best — maximizes independence |
| **Oblique** | One voice holds, the other moves | Good — creates variety |
| **Similar** | Both move same direction, different intervals | Fine with imperfect consonances |
| **Parallel** | Both move same direction, same interval | Fine for 3rds/6ths; forbidden for P5/P8 |

### Preference order
Contrary > oblique > similar > parallel

Use **contrary motion** whenever possible, especially between outer
voices. It creates the strongest sense of independent lines.

---

## Stepwise Motion and Leaps

- **Inner voices**: move by step or common tone whenever possible.
  Leaps of a 3rd are fine. Leaps of a P4 or P5 are acceptable but
  should be followed by stepwise motion in the opposite direction.
- **Avoid leaps > P5** in inner voices entirely (unless octave leaps
  for register changes, which should be rare).
- **Bass**: leaps are freer (P4, P5, P8 are normal bass motion).
- **Melody**: already fixed by the GB track — just don't create
  problems against it.

---

## Common Tones

When two consecutive chords share a pitch, keep it in the same voice:

```
I → V in C major:
  I  = C E G
  V  = G B D
  Common tone: G — keep it in the same voice, move the others
```

This minimizes motion and creates smoother connections.

---

## Voice Crossing and Overlap

### Voice crossing
An upper part goes below a lower part (or vice versa). Avoid — it
muddies the texture and makes parts hard to distinguish.

```
BAD:
Beat 1:  Alto=E4, Tenor=C4  (alto above tenor — normal)
Beat 2:  Alto=B3, Tenor=D4  (alto below tenor — crossed!)
```

### Voice overlap
One voice leaps past where the other voice *was* on the previous beat.

```
BAD:
Beat 1:  Alto=E4, Tenor=C4
Beat 2:  Alto=—,  Tenor=F4  (tenor goes above alto's previous E4)
```

---

## Consecutive Imperfect Consonances

Parallel 3rds and 6ths are allowed and sound fine, but **don't use more
than three in a row**. After three, the voices lose independence and
start to sound like a single thickened line rather than two distinct parts.

---

## GB-Specific Considerations

1. **Check against ALL existing channels**, not just the one closest
   in register. Parallel 5ths between your added tenor and the wave-channel
   bass are just as illegal as between your tenor and the melody.

2. **The melody is fixed** — you can't rewrite pulse 1. Your added parts
   must conform to wherever the melody goes.

3. **The bass is fixed** — when adding bass reinforcement, ensure you're
   doubling at the octave (parallel 8ves with yourself are fine; parallel
   8ves between two *independent* voices are not — but bass doubling at
   the fixed octave is standard practice, not independent voice leading).

4. **Arpeggiated channels complicate checking** — when pulse 2 arpeggiates
   C–E–G–E, check your voice leading against the *strong-beat* notes
   primarily, not every sixteenth note.

---

## Checklist (Copy This Into Your Working Memory)

```
For each pair of (added voice, existing/added voice):
  □ No parallel P5 → P5
  □ No parallel P8 → P8
  □ No direct P5 or P8 (similar motion into perfect interval, outer voices)

For each added voice individually:
  □ Leading tones resolve up (especially soprano/bass)
  □ Chord 7ths resolve down by step
  □ Common tones retained where possible
  □ Stepwise motion preferred; leaps ≤ P5, corrected by step
  □ No crossing below the voice beneath or above the voice above
  □ No more than 3 parallel 3rds or 6ths in succession
```
