---
name: audio-enhance-opl3
description: >
  Tier-1 OPL3 enhancement pass for the LLM music arranger. Produces
  conservative extra channels that must sound good through 2-op FM
  synthesis (OPL3). These enhancements cascade up to MT-32/GM for free.
  Read the music-theory skill first. Triggers: "tier 1 arrangement",
  "OPL3 enhancement", "FM arrangement", "tier-1 pass", "add OPL voices",
  "enhance for Sound Blaster".
---

# Tier-1 Enhancement Pass — OPL3

**Read the `music-theory` skill first.** This skill assumes you already
know chord identification, voice leading, and voicing rules.

You are writing **tier-1 enhancements** — conservative additions that
must sound good through 2-op FM synthesis on an OPL3 chip. Because FM
is the more constrained target, anything that sounds good here will
sound *at least as good* on MT-32/GM (the "design from the floor up"
principle).

---

## Your Constraints

### Voice budget
- OPL3 has 18 FM voices total
- The APU shim uses 4 (music) + up to 4 (SFX with `/SFXOVERLAP`)
- **~10 spare voices** for your enhancements
- Budget per song: **4–6 tier-1 voices** (leave headroom for SFX overlap
  and tier 2–3 on MT-32)

### What FM can do well
- Sustained pads (organ-like, strings-ish)
- Brass-like stabs
- Bass reinforcement (sub-bass, octave doubling)
- Bell-like tones
- Simple arpeggiated patterns

### What FM can NOT do well
- Realistic strings (no vibrato modulation, no attack nuance)
- Choir / vocal pads
- Complex evolving timbres
- Reverb tails (no built-in reverb on OPL3)
- Anything that relies on sample-based realism

**Stick to what FM does well.** The MT-32 tiers exist for the rest.

### Patch fields required
Every tier-1 enhancement channel must specify all three patch fields:
```yaml
opl_patch: <name from gen_opl_patches.py palette>
mt32_patch: <MT-32 patch number>
gm_program: <GM program number>
```
The compiler uses the appropriate field per target. `yaml_lint.py`
enforces that all three are present for tier 1.

---

## Decision Flowchart — When to Check References

```
START: You're writing a tier-1 enhancement for a song
  │
  ├─ "What's the harmony here?"
  │     └─► music-theory skill → references/chord_identification.md
  │
  ├─ "Will this voice-leading work?"
  │     └─► music-theory skill → references/voice_leading.md
  │
  ├─ "Is this voicing too muddy / too high?"
  │     └─► music-theory skill → references/voicing_and_ranges.md
  │
  ├─ "What's the original track doing with its channels?"
  │     └─► music-theory skill → references/gb_music_idioms.md
  │
  ├─ "What OPL3 voices are available? What patches exist?"
  │     └─► references/hardware_constraints.md (this skill)
  │
  └─ "How should the YAML look?"
        └─► examples/ (this skill — once the hand-crafted example exists)
```

---

## Workflow

### 1. Read the analysis
`music_analysis.py` output gives you: key, chord progression, phrase
boundaries, cadences, repeated motifs, melodic contour, rhythmic density.

### 2. Identify gaps
What's missing from the 4 GB channels?
- **Thin harmony** → add a pad (3rd or 5th of chord, sustained)
- **Weak bass** → add bass reinforcement (root octave below wave channel)
- **No inner voice** → add a tenor/alto pad on chord tones
- **Rhythmic drive needed** → add rhythmic comping (stabs on beats 2&4)

### 3. Choose conservatively
Tier 1 is the **foundation**. It should:
- Sound complete on its own (OPL3-only users hear only this)
- Not over-orchestrate — leave room for tiers 2–3
- Use 1–3 voices for quiet tracks, 3–5 for energetic ones
- Never exceed 6 tier-1 voices per song

### 4. Write the YAML
Use musical positions (measure/beat/duration), never frame deltas.
Tag every channel as `tier: 1`. Specify all three patch fields.

### 5. Check voice leading
Run through the voice-leading checklist against ALL existing GB channels
AND any other added voices. Parallel 5ths between your added bass and
the wave channel are the most common mistake.

### 6. Validate
`yaml_lint.py` checks: notes in range, valid beat/measure refs, per-tick
voice count within OPL3 polyphony, no unison doubling of base melody,
all three patch fields present.

---

## Arrangement Priorities by Track Type

| Track type | Priority additions | Voice count |
|-----------|-------------------|-------------|
| Town theme | Warm pad (3rd/5th), gentle bass | 1–2 |
| Route theme | Pad + optional counter-melody | 2–3 |
| Battle theme | Bass reinforcement + rhythmic stabs | 3–5 |
| Gym leader/champion | Full inner harmony + driving bass | 4–6 |
| Cave/dungeon | One sparse pad at most | 0–1 |
| Fanfare/jingle | Brief chord fill for the climax | 1–2 |
| Pokémon Center | Light warm pad | 1 |
| Lavender Town | Almost nothing — don't soften the eeriness | 0–1 |

---

## Common Mistakes (Tier-1 Specific)

1. **Over-orchestrating quiet tracks** — Pallet Town doesn't need 6 FM
   voices. It needs 1–2 at most.
2. **Using patches that clash with the APU shim's FM sound** — your
   enhancement patches should complement the duty-cycle pulse patches,
   not fight them. Use different timbral families.
3. **Forgetting that OPL3 is the audition target** — test in OPL3
   emulation first, not MT-32. If it doesn't sound good on FM, it
   doesn't ship.
4. **Writing parts that only work with reverb** — OPL3 has no reverb.
   If a part needs reverb to sound good, it belongs in tier 2–3.
5. **Exceeding voice budget** — the compiler drops lowest-tier channels
   first when polyphony is exceeded, but if you stay within budget,
   nothing gets dropped.

---

## Reference Index

| File | What it covers | When to read it |
|------|---------------|-----------------|
| [hardware_constraints.md](references/hardware_constraints.md) | OPL3 voice count, channel layout, available patches, FM synthesis characteristics | When you need to know what's technically possible |
| examples/ | Hand-crafted worked example (when available) | Before writing your first arrangement — see what good output looks like |
| music-theory skill | All theory references | Always read first |

## Auditioning (how to actually hear it)

The listen loop lives in the **build-and-debug** skill ("Auditioning music").
Short form: host-side `tools/audio/audition.py --target gm <Song>` for fast
iteration, then the real OPL3 shim end-to-end with
`dos_port/run DEBUG_AUDIO=1 TRACK=<MUSIC_* constant> /LOOP`. The track is the
`TRACK=` make variable — never edit the Makefile or debug_dump.asm to swap
songs, and never do full DOS rebuilds just to hear a YAML tweak.
