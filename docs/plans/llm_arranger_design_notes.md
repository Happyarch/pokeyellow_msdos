# LLM Music Arranger — Multi-Model Design Notes

Condensed record of the design conversation across four models (Gemini 3.1 Pro,
ChatGPT, Claude Opus 4.6) plus the user's own input, for Fable to review and
potentially integrate into `current_plan_audio.md`.

Status: **integrated into the plan** (2026-07-06) — adopted as **Phase E** of
`current_plan_audio.md`, which now holds the settled decisions and task list; this
file remains the design-rationale record. The §7 open questions were answered
(user + Fable review): (1) integrated as a plan section/phase; (2) Phase E starts
after Phase B, C/D independent; (3) `music_analysis.py` lives in `tools/audio/`;
(4) OPL3 tier-1 playback ships in Phase E via an enhancement stream player on
spare FM voices alongside the unchanged Phase A shim; (5) explicit per-target
patch fields in the YAML (tier 1: opl+mt32+gm; tiers 2–3: mt32/gm only), no
auto-mapping. Compatibility check: nothing built in Phase A is invalidated —
the arranger is additive tooling on top of the `pret_audio.py` IR.

---

## 1. The Idea (user's, refined with Gemini 3.1 Pro)

**Goal**: Use an LLM as a "music theory creative assistant" to orchestrate the
original 4-channel GB tracks into richer arrangements for MT-32/GM (32 voices)
and potentially OPL3 (18 voices). The LLM never edits authoritative assets and
never emits executable runtime data.

### Core pipeline

```
GB asm macros (pret source, read-only)
      │
pret_audio.py  (existing parser → IR)
      │
LLM arranger  (receives IR + music theory context + hardware constraints)
      │
Declarative YAML enhancement file  (new channels, tagged by tier)
      │
gb_to_midi.py  (merges base 4 GB channels + enhancements, tier-filters
                 by target hardware, computes all timing)
      │
midi_to_stream.py → flat 60 Hz frame-delta streams for DOS drivers
```

### Key architectural constraints (settled in original design session)

- The LLM outputs **declarative YAML only** — never binary MIDI, never bytecode.
- Enhancement YAML lives alongside the existing `overrides/*.yaml` hand-tuning
  files. `make assets` never clobbers overrides.
- The base 4 GB channels are **untouchable** — enhancements are additive only.
- All timing, polyphony management, and hardware-specific compilation remain in
  deterministic Python tools.

### Cascade / graceful degradation

One "maximalist" arrangement per song, tagged by tier. Tiers are designed
**from the floor up** — tier 1 is designed and auditioned on OPL3 (the more
constrained hardware), then cascades *up* to MT-32 for free. See §5 for the
full rationale.

| Tier | Designed for | Plays on | Example |
|------|-------------|----------|---------|
| 1 | OPL3 | OPL3 + MT-32/GM | Bass reinforcement, core harmony |
| 2 | MT-32 | MT-32/GM only | Lush string pads, reverb-heavy parts |
| 3 | MT-32 | MT-32/GM only | Color flourishes, choir, synth leads |
| — | — | Tandy | Base 4 GB channels only (no enhancements) |

The compiler counts active voices per tick and drops lowest-tier channels first
when the target hardware's polyphony limit is exceeded.

### Skill structure (three skills, shared theory)

The music theory knowledge is pass-invariant — voice leading rules don't change
between OPL3 and MT-32 targets. What changes per pass is the hardware
constraints and the creative direction. This maps to three skills:

```
.agents/skills/
  music-theory/
    SKILL.md                          ← ≤500 lines. The "always must know"
                                         essentials (see content guide below).
                                         Standalone knowledge skill — can also
                                         be invoked independently for analysis
                                         or reviewing hand-written arrangements.
    references/
      chord_identification.md         ← inferring chords from monophonic GB
                                         channels, common Pokémon progressions
      voice_leading.md                ← full rule set with correct vs incorrect
                                         examples
      voicing_and_ranges.md           ← instrument ranges, spacing rules,
                                         register-specific guidance
      gb_music_idioms.md              ← how the original composers used the 4
                                         channels: arpeggio bass, pulse melody,
                                         wave as secondary voice, noise patterns
    references/textbook/
      tonal_harmony_stripped.md       ← stripped-down textbook (see prep below).
                                         Deep fallback, rarely read.

  audio-enhance-opl3/
    SKILL.md                          ← "Read music-theory first. You are doing
                                         a tier-1 pass. Conservative enhancements
                                         that must sound good through 2-op FM."
    references/
      hardware_opl3.md                ← voice limits, FM timbral characteristics
    examples/
      pallettown_tier1.yaml           ← hand-crafted worked example (few-shot)

  audio-enhance-mt32/
    SKILL.md                          ← "Read music-theory first. Tier-1 OPL3
                                         enhancements already exist in the YAML —
                                         read them, don't duplicate. Add things
                                         FM can't do (LA synthesis capabilities)."
    references/
      hardware_mt32.md                ← partial limits, SysEx, LA synthesis
    examples/
      pallettown_tier23.yaml          ← worked example of MT-32-only layers
```

#### music-theory SKILL.md — what goes in (≤500 lines)

The LLM's job is narrow: "given a 4-channel GB track with analyzed harmony,
add tasteful orchestration." Only the theory that serves that job:

1. **Chord identification from melody + bass** — GB tracks imply harmony but
   rarely state it. "Melody plays B, bass plays G → probably G major." This
   is the #1 skill the LLM needs.
2. **Voice leading essentials** — avoid parallel 5ths/octaves, resolve leading
   tones, retain common tones between chords. ~20 concrete rules.
3. **Voicing/spacing** — open vs close position, don't crowd below C3, keep
   inner voices in comfortable ranges.
4. **What not to do** — don't double the melody in unison, don't cross voices,
   don't add density during rests/breaths, match phrase endings.
5. **Texture vocabulary** — when to use sustained pads vs arpeggios vs rhythmic
   comping. Which textures fit which emotional context (town = warm pads,
   battle = driving rhythmic, cave = sparse reverb).

**Excluded from all skill files** (irrelevant to this project):
- Atonal theory, serialism, set theory
- Advanced modulation (GB music mostly stays in key)
- Music history, performance practice
- Full orchestration for large ensembles
- Acoustics, psychoacoustics

#### Textbook source selection

Two open-source (CC BY-SA) music theory textbooks were evaluated:

| | **intmus/inttheory** | **openmusictheory** |
|---|---|---|
| Size | 156 content files, ~933 KB | ~130 files, ~524 KB |
| Structure | Semester-by-semester course (assignments interleaved) | **Topic-based** (one file per concept) |
| Extraction | Surgical — useful chapters mixed with rhythm/meter/clefs | Easy — grab the 15–20 relevant files, drop the rest |
| License | CC BY-SA | CC BY-SA |
| Status | Active (2026, has its own LLM agent system) | Dormant (~2014, but content is mature) |

**Selected: [Open Music Theory](https://github.com/openmusictheory/openmusictheory.github.io)**
(`openmusictheory/openmusictheory.github.io`, `master` branch).

The topic-based file structure means the relevant files can be extracted
almost surgically. Fork it, strip it, sync the stripped version into
`docs/sound/music_theory/` (or directly into the skill's `references/textbook/`).

**Files to extract** (the ~15–20 that cover our needs):

Functional harmony:
- `harmonicFunctions.md`, `harmonicSyntax1.md`, `harmonicSyntax2.md`
- `harmonicAnalysis.md`, `functions.md`

Cadences & phrasing:
- `cadenceTypes.md`

Counterpoint & voice leading:
- `speciesIntro.md`, `firstSpecies.md`, `secondSpecies.md`,
  `thirdSpecies.md`, `fourthSpecies.md`, `cantusFirmus.md`
- `tendency.md`, `tendencyTonesFunctionalDissonances.md`
- `motionTypes.md` (parallel/contrary/oblique)

Voicing & embellishment:
- `embellishingTones.md`
- `melodicKeyboardStyle.md`, `KBVLschemata.md`
- `thoroughbassFigures.md`, `RNfromFB.md`

Fundamentals (light reference):
- `intervals.md`, `triads.md`, `scales.md`, `keySignatures.md`

Chromatic harmony (for tracks that modulate):
- `alteredSubdominants.md`, `appliedChords.md`, `Modulation.md`,
  `modalMixture.md`

**Files to exclude entirely** (not relevant to this project):
- Pop/rock form & harmony (`popRock*.md`) — wrong idiom
- Sonata theory (`SonataTheory-*.md`) — large-scale form analysis
- Atonal/post-tonal (`atonal.md`, `atonalGlossary.md`, pitch-class set
  files) — GB music is tonal
- Aural skills, notation basics, poetry analysis
- All media assets, CSS, JS, Jekyll config

#### Stripping the textbook for LLM ingestion

Before the extracted files enter the repo, strip them to a slim
LLM-friendly markdown file:

- **Remove all figures/images** — an LLM can't use them, they waste tokens.
- **Remove excess formatting** — Jekyll frontmatter, page numbers, publisher
  boilerplate, embedded media links, CSS class references.
- **Remove exercise sets and discussion prompts** — not actionable for our use.
- **Keep**: the prose explanations, rules, and any inline musical examples
  written as text (note names, chord symbols, Roman numerals).

The result is `tonal_harmony_stripped.md` (or a small set of stripped files)
— a deep fallback reference the LLM reads only when the distilled skill
references don't cover something unusual.

#### Distillation workflow (two-model pipeline)

Play to each model's strengths:

1. **Gemini ingests the stripped textbook** (large context window). Prompt:
   "Distill this to only the concepts needed for adding harmony and
   orchestration to simple 4-channel Game Boy video game music. Focus on:
   chord identification from melody+bass, voice leading, voicing/spacing,
   common mistakes. Output structured markdown."
2. **Gemini produces a raw distillation** — substantively correct but likely
   too verbose and poorly structured for a skill file.
3. **Claude writes the actual skill files** from Gemini's distillation —
   tightens language, structures for the skill format, adds GB-specific
   examples, splits across `SKILL.md` (~300 lines) and `references/`
   (~200–400 lines each).

Key design points:
- **music-theory** is loaded by both pass skills but exists independently. It
  can be invoked standalone for analysis or review without generating anything.
- **audio-enhance-mt32** explicitly tells the LLM that tier-1 enhancements
  already exist in the YAML file and to read them before adding tiers 2–3. The
  MT-32 pass is truly additive on the OPL3 pass.
- Each pass skill carries its own **worked example** (`examples/`) — the
  hand-crafted enhancement YAML from recommendation M. Few-shot prompting with
  a concrete example anchors output quality more than theory text alone.

### Human-in-the-loop workflow

The user auditions every modification by ear and provides natural-language
feedback ("the strings are too busy in measure 12, thin them out"). The LLM
revises iteratively. This is the quality gate — no auto-acceptance.

---

## 2. ChatGPT's Review — Key Recommendations

### Agreed upon by all reviewers (implement these):

**A. Don't expose delta-times to the LLM.** Use musical positions instead:
```yaml
events:
  - measure: 1
    beat: 1
    duration: quarter
    note: G3
```
The compiler derives frame deltas from tempo/PPQN/frame rate. Eliminates LLM
arithmetic errors.

**B. Run deterministic music analysis before invoking the LLM.** Python computes:
key estimation, chord progression, phrase boundaries, cadence points, repeated
sections/motifs, melodic contour, rhythmic density. The LLM receives structured
analysis, not raw note data. Its job becomes "given this harmonic structure,
add orchestration" — much easier.

**C. Detect repeated motifs; orchestrate each once.** If a song has form
`A B A C`, the analysis phase tags the two A phrases as identical. The LLM
orchestrates motif A once; the compiler duplicates. Prevents inconsistency.

**D. The compiler owns all polyphony management.** Voice allocation, tier
filtering, and any future chord thinning happen in deterministic Python, never
in the LLM's output.

**E. Provide orchestration constraints in the prompt.** Examples: never double
melody in unison, avoid parallel octaves, keep pads below melody, max interval
= octave, avoid bass below C2, leave rests where GB leaves rests.

### ChatGPT suggestions that were rejected or deferred:

**F. Multi-axis importance vectors** (harmonic: 10, melodic: 1, etc.) —
over-engineered. Named tiers (3–4 levels) are sufficient for ~51 songs going
from 4 to 8–12 channels.

**G. Voice stealing / chord thinning** (thin `[C,E,G,B]` → `[C,G]` instead of
dropping a whole layer) — requires harmonic-function awareness in the compiler.
Deferred to a later version; whole-layer removal is fine for v1.

**H. LLM confidence scores** (`confidence: 0.97`) — LLM confidence is
uncalibrated. The human audition loop is the actual quality gate. Skip this.

**I. Edit operations** (`add_pad`, `reinforce_bass`) instead of full channel
generation — actually harder for the LLM (requires understanding current state
and generating diffs). Full channel generation with compile-time merge is
simpler and more auditionable.

**J. Separate harmony from orchestration into distinct pipeline stages** —
conceptually clean but adds pipeline complexity for marginal benefit at this
scale. One LLM pass that receives analyzed harmony and produces orchestrated
channels is sufficient.

**K. Musical "roles"** (`StringsPad` → deterministic expansion to violin/viola/
cello) — interesting for a larger system but unnecessary when the LLM is
already specifying concrete instruments per channel.

---

## 3. Claude Opus 4.6's Review — Additional Recommendations

### New points not raised by other reviewers:

**L. Pin the YAML schema concretely before building tools.** Everything
downstream depends on the enhancement format. Proposed sketch:
```yaml
song: MUSIC_PALLET_TOWN
tempo_bpm: 112
key: G_MAJOR

enhancements:
  - name: string_pad
    tier: 2
    mt32_patch: 49
    gm_program: 49
    opl_patch: strings_sustained
    range: [G3, C5]
    events:
      - measure: 1
        beat: 1
        note: G3
        duration: whole
      # ...
```

**M. Hand-craft one song's enhancement YAML by ear before involving the LLM.**
This proves the mechanical pipeline works (YAML → merge → compile → audition)
and produces the worked example that anchors the LLM's few-shot prompt. Highest
single-impact recommendation.

**N. Add `yaml_lint.py` structural validation between LLM output and audition.**
Checks: notes within declared range, no unintended unisons with base melody,
beat/measure references valid for time signature, total voice count per tick
within hardware limit, no impossible intervals. Catches structural errors so
human review focuses on aesthetics.

**O. Don't auto-cascade MT-32 arrangements to OPL3.** The timbral gap between
LA synthesis (MT-32) and 2-op FM (OPL3) means cascaded arrangements often
won't sound good without per-device tuning. For v1: MT-32/GM gets the full
enhancement pipeline; OPL3 stays on the APU shim (faithful GB sound through FM).
OPL3-specific enhancements can be written separately later if desired.

**P. Use a worked example (few-shot) in the LLM prompt, not just theory rules.**
One complete hand-crafted enhancement of a simple track (e.g., Pokémon Center)
in the prompt will do more for output quality than any amount of theory text.

---

## 4. Consolidated Recommendations, Ranked

| # | What | Effort | Impact |
|---|------|--------|--------|
| 1 | Hand-craft one song's YAML first, LLM second (M) | Low | Critical |
| 2 | Use beat/measure/duration, not deltas (A) | Low | High |
| 3 | Deterministic analysis before LLM (B) | Medium | High |
| 4 | Pin the YAML schema (L) | Low | High |
| 5 | Add yaml_lint.py validation (N) | Medium | High |
| 6 | Detect repeated motifs, orchestrate once (C) | Medium | High |
| 7 | Named tiers (3–4), not integers or vectors (F) | Low | Medium |
| 8 | Worked example in LLM prompt (P) | Low | Medium |
| 9 | Orchestration constraints in prompt (E) | Low | Medium |
| 10 | Design from the floor up (Q) | Zero | Medium |
| 11 | Skip confidence scores (H) | Zero | Low |
| 12 | Defer voice stealing to later (G) | Zero | Low |

---

## 5. Design from the Floor Up (post-review refinement)

The original Opus 4.6 review recommended not auto-cascading MT-32 arrangements
to OPL3 due to the timbral gap between LA synthesis and 2-op FM. The follow-up
discussion produced a better solution: **invert the design direction**.

Instead of designing for MT-32 and cascading *down* (risking bad-sounding FM
patches), design tier-1 enhancements for **OPL3 first**. If a bass
reinforcement sounds good as a 2-op FM patch, it will sound *at least as good*
through MT-32's LA synthesis. The hard direction is down, not up. Then add
MT-32-only tiers on top that exploit capabilities with no OPL3 equivalent.

This is the "mobile-first" principle applied to audio.

### Revised tier table

| Tier | Designed for | Auditioned on | Plays on | Example |
|------|-------------|---------------|----------|---------|
| 1 | OPL3 | OPL3 emulation | OPL3 + MT-32/GM | Bass reinforcement, core harmony |
| 2 | MT-32 | MUNT | MT-32/GM only | Lush string pads, reverb-heavy parts |
| 3 | MT-32 | MUNT | MT-32/GM only | Color flourishes, choir, synth leads |

- Tier 1 enhancements cascade *up* to MT-32 for free (better patches, same
  notes). No timbral mismatch because the floor hardware set the constraints.
- Tiers 2–3 are things you'd never conceive of when designing for FM — they
  only exist for the premium tier and are never cascaded down.
- Tandy still gets zero enhancements (base 4 GB channels only via APU shim).

### Caveat

Don't leave MT-32 quality on the table by *only* thinking in OPL3 terms.
The MT-32-only tiers exist precisely for enhancements that have no natural
FM equivalent. The workflow is: OPL3 base enhancements first → audition →
then ask "what could MT-32 add on top that FM can't do?" → tier 2–3.

---

## 6. Pipeline Diagram (consensus across all reviews)

```
GB Assembly (pret macros, read-only)
        │
        ▼
  pret_audio.py  (parser → IR)          ← exists, byte-verified
        │
        ▼
  music_analysis.py  (NEW)
  key, chords, phrases, repeats, contour
        │
        ▼
  Human hand-crafts first enhancement   ← proves format + becomes few-shot example
        │
        ▼
  [Later] llm_enhance.py               ← feeds analysis + example + constraints to LLM
        │
        ▼
  yaml_lint.py  (structural validation) ← catches errors before audition
        │
        ▼
  gb_to_midi.py  (merges base + enhancements, tier-filters per target)
        │
        ├── midi_to_stream.py → MT-32 flat streams  (tiers 1+2+3)
        ├── midi_to_stream.py → GM flat streams     (tiers 1+2+3)
        └── midi_to_stream.py → OPL3 streams        (tier 1 only)
```

---

## 7. Open Questions for Fable

1. Should this feature be added as a new section to `current_plan_audio.md`, or
   kept as a separate future-phase document?
2. Where in the phasing does this land? After Phase B (MIDI/MT-32 flagship) is
   complete, since the enhancement pipeline builds on top of `gb_to_midi.py` and
   `midi_to_stream.py`?
3. The `music_analysis.py` tool — should it be part of the audio tooling
   (`tools/audio/`) or a standalone analysis step?
4. With the "design from the floor up" approach, does OPL3 enhancement belong
   in Phase A (alongside the OPL shim) or as a separate phase after Phase B?
5. For tier-1 (OPL3-targeted) enhancements, should the YAML specify both
   `opl_patch:` and `mt32_patch:` (letting the compiler pick per target), or
   should the compiler auto-map OPL patch names to MT-32 programs?
