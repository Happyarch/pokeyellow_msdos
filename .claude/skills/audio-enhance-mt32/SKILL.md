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
Tier 2–3 entries carry MT-32, GM, and IMFC patch fields (no `opl_patch` — these
never play on OPL3):
```yaml
mt32_patch: <MT-32 factory preset name or custom timbre name>
gm_program: <GM program name or number>
imfc_voice: <IMFC preset name from imfc_presets.py, custom voice, or {bank: B, program: P}>
mt32_volume: <0-127, optional, default 96>
gm_volume: <0-127, optional, default 96>
imfc_volume: <0-127, optional, default 96>
```
**Always use real-word patch names rather than numbers**: Magic numbers are obscure, hard to review, and create numbering ambiguity between 0-based and 1-based files. Use readable names everywhere (e.g. `mt32_patch: "Str Sect 1"`, `gm_program: "String Ensemble 1"`, `imfc_voice: "String1"`).

`imfc_voice` is a standard target field and is required for all new arrangements. Toolchain fallbacks to Bank 2 ROM presets exist solely as a temporary transitional bridge until patches are routed for all tracks.
Device-scoped keys (`mt32_volume`, `gm_volume`, `imfc_volume`) are preferred; legacy `volume` is deprecated and produces lint warnings. Mixing `volume` with device-scoped keys is an error.
Custom timbre names defined in `tools/audio/mt32/mt-32_custom_timbres.yaml` (symlinked as `timbres.yaml`) can be used as strings
(e.g. `mt32_patch: "NightWind"` or `mt32_program: "Theremin"`). The build pipeline
compiles on-the-fly setup SysEx (pointing the patch slot to the custom timbre) and
cleanup SysEx (eagerly restoring the patch slot to factory parameters on track
stop/unload, keeping all 128 factory presets intact).
Custom IMFC voices defined in `tools/audio/imfc/imfc_custom_voices.yaml` or factory presets from `imfc_presets.py` can similarly be referenced by name (e.g. `imfc_voice: "HarpsiLead"` or `imfc_voice: "SoloVio"`).


`yaml_lint.py` enforces: tier 2–3 entries must NOT have `opl_patch`,
and must have both `mt32_patch` and `gm_program`. It also runs the same
range, polyphony, and unison-doubling checks as tier 1. **Percussion

channels are exempt from the pitched-voice rules** (unison-doubling,
in-channel note overlap, and pitch range): a channel counts as percussion
when it sets `rhythm: true` (GM/MT-32 drum part on MIDI ch 10 — the note
number *is* the drum, so `transpose` is rejected), sets `percussion: true`
(a percussion timbre kept on its own melodic channel, pitched and with its
own patch), or names a GM percussion program (Timpani 48, or the Percussive
family 113–120). This is intrinsic to the file — there is no CLI flag to
remember, and the asset pipeline sees the same verdict you do.

After lint passes: if you added timed program switches to a song, register
its exact per-channel switch counts in the `switched` dict in
`dos_port/tools/audio/test_switches.py` (every unregistered song must
resolve zero switches — a silently dropped switch still lints clean, so
only those numbers catch it), and bump the file counts there when adding a
song. Then run `python3 dos_port/tools/audio/test_switches.py` to green.

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
  ├─ "A voice should change timbre mid-song?"
  │     └─► Timed program switches (this skill, below) +
  │         references/hardware_constraints.md — numbering + lint detail
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

## Timed program switches (MT-32 / GM / IMFC)

A channel can change its patch mid-song: a per-channel `switches:` list in
`overrides/*.yaml` (GB voices) and `enhancements/*.yaml` (added voices)
emits a program change on that channel's stream. **MIDI/IMFC-path-only:
OPL3 FM voices are fixed-patch per voice — switches NEVER apply to tier-1
`opl_patch`.** (Tier-1 voices keep their baseline patch fields and cascade up;
a switch rides `mt32_program`, `gm_program`, and optional `imfc_program`.)


### Placement law — between notes only

A switch must never fall strictly inside a same-channel note span —
`yaml_lint.py` reports that as an ERROR. Legal placements: inside a rest,
exactly at a note-off boundary, or coincident with a note-on (the new patch
sounds from that note). Musical rule of thumb: **arm in silence, sound on
phrase boundaries and downbeats** — the timbre analogue of "rest where the
GB rests": never switch under a sounding note.

### Worked example — Music_Cities2 ch2 trumpet → violin → trumpet (canonical override)

This is the canonical example of **override switching** (re-voicing a base GB
channel mid-song in `tools/audio/overrides/Music_Cities2.yaml`):

```yaml
# tools/audio/overrides/Music_Cities2.yaml
channels:
  2:
    mt32_program: "Trumpet 1"
    gm_program: "Trumpet"
    volume: 104
    pan: 80
    switches:
      - {m: 14, b: 1, mt32_program: "Violin 1", gm_program: "Violin"}
      - {m: 18, b: 2.5, mt32_program: "Trumpet 1", gm_program: "Trumpet"}
```

Section geometry (E major, 18 measures): the loop body is mm3–18, the
lyrical passage is mm14–18, and both switches sit on note boundaries (the
new patch sounds immediately on the arriving note):

- `m: 14, b: 1` switches to "Violin 1" / "Violin" at the pickup downbeat
  (24.05s) where the texture thins into the lyrical section; violin
  carries through the lyrical phrase in mm. 14–17 and the resolution.
- `m: 18, b: 2.5` switches back to "Trumpet 1" / "Trumpet" at 32.13s,
  right on the fast 16th-note fanfare pickup run (`B4, C#5, D#5, E5, F#5, G#5, A5`),
  giving the trumpet its punchy attacks back before the loop wrap at 33.3s.
- **Trap avoided**: A score transcription note claimed sq2 was silent in
  mm13b2–15 and m18b2–intro. In actual GB hardware simulation, channel 2
  holds continuous sustains across those measures, so placing switches at
  m15b4 or m18b2 fell strictly mid-note (a `yaml_lint.py` ERROR). Placing
  at note boundaries (`m: 14, b: 1` and `m: 18, b: 2.5`) aligns with note-offs,
  satisfying the linter.

### Loop semantics — four intents

| Intent | Shape | What to place |
|--------|-------|---------------|
| Loop same as init | Loop body keeps the init patch | Nothing — the channel already holds it at loop entry |
| Loop different | Whole loop under a second patch | One switch just before loop entry; it latches for the whole loop |
| In-loop changes | Patch changes inside the body | Switches inside the body; they fire every pass |
| First pass diverges | First pass X, later passes Y | Init X + one mid-loop switch to Y (X→Y once, then Y→Y) — a deliberate device only, not a default |

`yaml_lint.py` raises case-aware WARNs for suspicious placements (switches
in the intro, just before loop entry, or creating first-pass divergence) —
the WARN is a prompt to confirm the intent above, not a failure.
**Placement is the answer: move the switch; the toolchain never
auto-fixes.**

### Programs, tiers, and names

Each switch carries per-target programs: `mt32_program`, `gm_program`, and `imfc_program`.
IMFC is a full target alongside MT-32 and GM, not optional; toolchain switch fallbacks exist
only as a transitional bridge until patches are routed for all tracks.
The preset maps do not align across devices, so specify each target's program when re-voicing.
**Ship preset NAMES, not numbers**: integer programs are 0-BASED in overrides files but 1-BASED
in enhancements files, and a bare number is ambiguous across the two. Names sidestep the trap;
the full numbering detail lives in
[hardware_constraints.md](references/hardware_constraints.md#timed-program-switches-midi-path).
Tier is per-channel: a switch never changes a channel's tier, and if the
compiler drops a whole layer (highest tier number first), that layer's
switches vanish with it.



### Say it in voices, verify it in channels

Arrangement intent is stated in theory-voice terms ("the second voice drops
to a pedal"), but switch placement is verified in hardware-channel terms
(no note span on that channel contains the switch frame). Transcription
prose likewise describes theory voices, not hardware channels — one
hardware channel may carry multiple theory voices, so a "voice" changing
character does not imply a channel boundary.

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
| [hardware_constraints.md](references/hardware_constraints.md) | MT-32 partial count, part layout, patch selection, LA synthesis capabilities, GM differences, timed-switch numbering + lint detail | When you need to know what's technically possible |
| examples/ | Hand-crafted worked example (when available) | Before writing your first arrangement |
| music-theory skill | All theory references | Always read first |
| audio-enhance-opl3 skill | Tier-1 constraints and approach | To understand what you're building on top of |

## Verifying a mapping renders (agents) — auditioning (humans) hears it

Agents cannot listen. What an agent checks after writing voices: batch-render
the track and confirm it produces signal (nonzero stats, no crash). That proves
the map resolves and plays — nothing about whether it sounds good. Voice choice,
balance, and timbre are human ear judgments in the dgad GUI.
The listen loop is documented in the **`audio-enhance-opl3`** skill.
Short form: `dgad --headless --track <Song> --device mt32 --out take.wav`
(fuzzy match like `--track celadon`; `--device mt32` is the default;
`--device imfc` renders the IMFC path, `--device gm`/`opl3`/`gbapu` the rest).
`--project-dir <repo>` overrides the project root when run outside the tree.
Batch renders print peak/nonzero stats — nonzero==0 means silence (broken map).

`dgad` (pkmn-audio-dbg) replaces `tools/audio/audition.py`, which is deprecated.
Agents verify with batch renders + peak/nonzero stats; the interactive GUI
is human territory (voice/timbre ear judgments). `dgad --help` lists all flags.

End-to-end in-DOS verification via `dos_port/run-mt32 DEBUG_AUDIO=1 TRACK=<MUSIC_* constant> /LOOP`.
The track is the `TRACK=` make variable — never edit the Makefile or
debug_dump.asm to swap songs.
