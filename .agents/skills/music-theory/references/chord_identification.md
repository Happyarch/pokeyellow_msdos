# Chord Identification from GB Channels

GB tracks imply harmony but never state explicit chords. This reference
teaches you to infer them.

---

## The Method

### Step 1: Establish the key

- Look at the first and last bass notes — they're almost always the tonic.
- Check for accidentals that indicate major vs minor.
- Pokémon Yellow mostly uses major keys (C, G, D, F, B♭ are common).
  Minor keys appear in Lavender Town, some caves, and Team Rocket themes.

### Step 2: Read the bass note on each beat

The bass (usually wave channel, sometimes pulse 2) gives you the chord root
or inversion bass. In GB music, the bass note is the root ~80% of the time.

**Arpeggiated bass**: when the bass plays C–G–C–G in eighth notes, the
chord is C major (root + 5th). Collect all pitches within the beat.

**Walking bass**: stepwise bass motion (C–D–E–F) usually means passing
chords. The structural chords are on the strong beats (beats 1 and 3 in 4/4).

### Step 3: Read the melody on strong beats

The melody note on each strong beat is almost always a chord tone.
Combine it with the bass to narrow down the chord:

| Bass | Melody | Most likely chord |
|------|--------|------------------|
| C | E | C major (root + 3rd) |
| C | E♭ | C minor (root + ♭3rd) |
| C | G | C major or C minor (root + 5th — need the 3rd from elsewhere) |
| C | B | Cmaj7 (root + 7th) or Am/C (if A is in another voice) |
| E | C | C/E (first inversion) |
| G | C or E | C/G (second inversion) — rare in GB, usually passing |

### Step 4: Check inner voices

Pulse 2 or the wave channel often plays a counter-melody or sustained chord
tone that confirms the 3rd or 5th. This resolves ambiguity from step 3.

### Step 5: Match to diatonic chords

Prefer the simplest diatonic explanation. In C major:
- C–E–G = I
- D–F–A = ii
- E–G–B = iii
- F–A–C = IV
- G–B–D = V
- A–C–E = vi
- B–D–F = vii°

Only invoke chromatic chords (applied dominants, modal mixture) if the
pitches genuinely don't fit the diatonic collection.

---

## Passing Tones vs. Chord Tones

Not every note belongs to the chord. Distinguish:

- **Chord tone**: approached by any motion, can be sustained, falls on
  a strong beat
- **Passing tone**: approached and left by step in the same direction,
  usually on a weak beat
- **Neighbor tone**: steps away from a chord tone and returns to it
- **Anticipation**: arrives early (weak beat) before the chord changes
- **Suspension**: held over from the previous chord into the next, then
  resolves down by step

**Rule of thumb**: if a note is on a weak beat and is approached/left by
step, it's probably embellishing. Don't build your chord analysis on it.

---

## Harmonic Function

Once you have the chords, classify them by function:

| Function | Scale degrees | Chords (major) | Character |
|----------|--------------|-----------------|-----------|
| **Tonic (T)** | 1, 3, 5 | I, iii, vi | Stability, home |
| **Subdominant (S)** | 2, 4, 6 | ii, IV | Moving away |
| **Dominant (D)** | 5, 7 | V, vii° | Tension → resolution |

The cycle **T → S → D → T** is the backbone. GB Pokémon music follows
this cycle faithfully — it's common-practice tonal music.

### Functional triggers (from Quinn)

| Function | Triggers | Associates | Dissonances |
|----------|----------|-----------|-------------|
| **T** | 1 and 3 | 5 and 6 | 5 (if 6 present), 7 |
| **S** | 4 and 6 | 1 and 2 | 1 (if 2 present), 3 |
| **D** | 5 and 7 | 2 | 4 and 6 |

---

## Cadences

Cadences end phrases. Recognizing them tells you where to thin or thicken
your arrangement:

| Cadence | Progression | Melody ends on | Strength |
|---------|------------|---------------|----------|
| PAC | V → I | *do* (scale degree 1) | Strongest — full closure |
| IAC | V → I | 3rd or 5th | Moderate |
| HC | → V | (open) | Weak — phrase continues |
| Deceptive | V → vi | (surprise) | Avoids closure |

**Compound cadences** include a cadential 6/4 before the V:
I⁶₄ → V → I. Very common in classical and GB music alike.

---

## Common Pokémon Progressions

These patterns recur across the soundtrack:

| Pattern | Example songs |
|---------|--------------|
| I – IV – V – I | Many town themes |
| I – vi – IV – V | Pokémon Center, road themes |
| i – iv – V – i | Lavender Town, cave themes |
| I – V – vi – IV | Some route themes |
| I → V⁶₅ → I (neighbor) | Very common tonic prolongation |
| I → IV → I (embellishing) | Opening measures of many themes |

The harmonic rhythm is usually **one chord per measure** or **two chords
per measure** in 4/4 time. Faster harmonic rhythm (one chord per beat)
signals a cadential approach.

---

## Prolongation (Why Some "Chord Changes" Aren't Real)

Many apparent chord changes are just prolongations of a single function:

- **I → V⁶₅ → I**: the V is a neighbor chord, not a real dominant. Tonic
  throughout. Your pad can sustain.
- **I → V⁶₄ → I⁶**: the V is a passing chord. Still tonic.
- **IV → ii⁶**: same bass note (*fa*), same function (S). Change of figure.
- **I → I⁶**: change of bass, same function.

**For arrangement**: don't change your voicing for every passing chord.
Sustain through prolongations and move on structural chord changes.
