---
name: audio-enhance-mt32
description: >
  Tier 2–3 MT-32/GM enhancement pass for the LLM music arranger. Adds
  channels that exploit LA synthesis capabilities with no OPL3 equivalent.
  Must read existing tier-1 entries first — tier 2–3 is additive on top
  of tier 1, never duplicating it. Read the music-theory skill first.
  Triggers: "tier 2 arrangement", "tier 3 arrangement", "MT-32 enhancement",
  "LA synthesis arrangement", "enhance for MT-32", "add MT-32 voices",
  "premium arrangement".
---

# Tier 2–3 Enhancement Pass — MT-32 / GM

**Read the `music-theory` skill first.** This skill assumes you already
know chord identification, voice leading, and voicing rules.

**Read the existing tier-1 entries in the song's YAML before writing
anything.** Tier 2–3 is additive on top of tier 1. Never duplicate a
tier-1 voice. Your job is to add things that FM synthesis *cannot* do.

---

## Your Role

Tier-1 (OPL3) enhancements provide the core harmonic foundation —
pads, bass reinforcement, basic harmony. They cascade up to MT-32
for free. Your tier 2–3 additions exploit what LA synthesis offers
beyond 2-op FM:

- Lush, evolving string pads with natural attack envelopes
- Choir and vocal textures
- Reverb-rich atmospheric parts
- Complex timbres (layered partials, ring modulation)
- Subtle dynamic shaping within sustained notes

---

## Constraints

### Voice budget
- MT-32 has **32 partial oscillators** across 8 melodic parts + 1 rhythm
- Each patch uses 1–4 partials (most use 2)
- Partial reserves in `timbres.yaml` allocate partials per part
- Tier-1 voices already consume some partials (they cascade up)
- **Budget**: total tier-1 + tier 2–3 voices should not exceed what the
  partial reserve allows. Check `timbres.yaml` for the current allocation.
- Typical budget: **3–5 tier 2–3 voices** on top of the tier-1 base

### GM fallback
GM mode uses the same MIDI streams minus the Roland SysEx. All tier 2–3
voices play on GM too (GM has no partial limits, just 16 channels /
polyphony varies by synth — assume 24-note polyphony minimum).

### Patch fields required
Tier 2–3 entries carry MT-32 and GM fields only (no `opl_patch` — these
never play on OPL3):
```yaml
mt32_patch: <MT-32 patch number or custom timbre name>
gm_program: <GM program number>
```
`yaml_lint.py` enforces: tier 2–3 entries must NOT have `opl_patch`,
and must have both `mt32_patch` and `gm_program`.

---

## Decision Flowchart — When to Check References

```
START: You're writing tier 2–3 enhancements for a song
  │
  ├─ "What tier-1 voices already exist?"
  │     └─► Read the song's enhancement YAML — tier-1 entries are there.
  │         DO NOT duplicate them. Complement them.
  │
  ├─ "What's the harmony / voice leading?"
  │     └─► music-theory skill (same as tier-1 pass)
  │
  ├─ "What can MT-32 do that I should exploit?"
  │     └─► references/hardware_constraints.md (this skill)
  │
  ├─ "What patch should I use?"
  │     └─► references/hardware_constraints.md — patch selection guide
  │
  └─ "How should the YAML look?"
        └─► examples/ (this skill — once the hand-crafted example exists)
```

---

## Workflow

### 1. Read the existing tier-1 YAML
Understand what's already there. Note:
- Which chord tones are covered
- What register each tier-1 voice occupies
- Where there are still gaps

### 2. Identify what tier 1 *can't* do
Ask: "What would make this track sound premium that FM can't deliver?"
- A warm string pad with a slow, bowed attack?
- A choir "aah" sustaining through the chorus?
- A reverb-soaked atmospheric layer in a cave theme?
- A synth lead doubling the melody an octave up with a unique timbre?

### 3. Assign tiers
- **Tier 2**: core MT-32-only additions. String pads, brass ensembles,
  warm piano comping. Things that add *body*.
- **Tier 3**: color and flourish. Choir accents, synth textures,
  arpeggiated bells, harp glissandos. Things that add *sparkle*.

Tier 3 is dropped first if polyphony is tight. Make tier 2 the
essential premium layer; tier 3 is the luxury layer.

### 4. Write parts that complement, not compete
Your voices fill different space than tier 1:
- Different register (tier 1 has a tenor pad → tier 2 adds alto strings)
- Different rhythm (tier 1 is sustained → tier 2 adds gentle arpeggiation)
- Different timbre (tier 1 is organ-like FM → tier 2 is warm strings)

### 5. Check voice leading (same rules apply)
Parallel 5ths/8ves, resolution, voicing — all the same rules from the
music-theory skill. Check against GB channels, tier-1 voices, AND your
other tier 2–3 voices.

---

## Arrangement Priorities by Track Type

| Track type | Tier-2 additions | Tier-3 additions |
|-----------|-----------------|-----------------|
| Town theme | String pad, warm piano | Choir accent at cadences |
| Route theme | Strings + light brass | Harp or bell ornaments |
| Battle theme | Brass ensemble, driving strings | Synth lead doubling |
| Gym leader | Full string section + brass | Choir, timpani rolls |
| Cave/dungeon | Reverb pad (one voice) | Nothing — keep sparse |
| Lavender Town | Maybe one ethereal pad | Nothing — respect the mood |
| Fanfare | Brief full ensemble hit | Cymbal/chime accent |

---

## Common Mistakes (Tier 2–3 Specific)

1. **Duplicating tier-1 voices** — if tier 1 already has a tenor pad on
   the 3rd, don't add another pad on the 3rd. Add the 5th, or move to
   a different register / timbre.
2. **Over-orchestrating** — MT-32 can do a lot, but Pokémon Yellow is
   still 4-channel Game Boy music at heart. Don't turn Pallet Town into
   a film score. The base aesthetic is "same voice count, but with
   depth and character."
3. **Ignoring partial limits** — a 4-partial string patch on 4 voices
   uses 16 of 32 available partials. Leave room for tier-1 cascaded
   voices and the base melody.
4. **Writing GM-incompatible parts** — GM has a different (and usually
   weaker) sound. Don't rely on MT-32-specific timbral quirks. The
   notes should sound acceptable on any GM synth. Use `gm_program` to
   pick the closest equivalent.
5. **Filling silence** — same rule as always. Rest where the GB rests.

---

## Reference Index

| File | What it covers | When to read it |
|------|---------------|-----------------|
| [hardware_constraints.md](references/hardware_constraints.md) | MT-32 partial count, part layout, patch selection, LA synthesis capabilities, GM differences | When you need to know what's technically possible |
| examples/ | Hand-crafted worked example (when available) | Before writing your first arrangement |
| music-theory skill | All theory references | Always read first |
| audio-enhance-opl3 skill | Tier-1 constraints and approach | To understand what you're building on top of |
