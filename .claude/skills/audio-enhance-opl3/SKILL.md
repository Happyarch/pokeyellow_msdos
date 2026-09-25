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
- The APU shim uses 4 (music) + up to 4 (SFX) — note `/SFXOVERLAP` is **not
  implemented yet**: `src/audio/opl_enh.asm:14` records it as "still deferred —
  will contend here when it lands" (re-check the line number if the file's
  header comment changes length; the claim itself is current). Budget as if
  it will land, but do not go looking for the flag.
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
Timed mid-song program switches are MT-32/GM-only (see the
`audio-enhance-mt32` skill) — OPL3 FM voices keep one fixed patch per
voice; switches never apply to tier-1 `opl_patch`.

### Patch fields required
Every tier-1 enhancement channel must specify patch fields for all targeted synth backends:
```yaml
opl_patch: <name from tools/audio/opl/patches.yaml>
mt32_patch: <MT-32 factory preset name or custom timbre name>
gm_program: <GM program name or number>
imfc_voice: <IMFC preset name from imfc_presets.py, custom voice, or {bank: B, program: P}>
```
**Always use real-word patch names rather than numbers**: Magic numbers are obscure, hard to review, and create numbering ambiguity between 0-based and 1-based tools. Use readable names everywhere (e.g. `mt32_patch: "Str Sect 1"`, `gm_program: "String Ensemble 1"`, `imfc_voice: "String1"`).

`imfc_voice` is a standard target field and should be specified for all new and revised channels. Toolchain fallbacks to Bank 2 ROM presets exist solely as a transitional bridge for legacy files where IMFC patches have not yet been routed. `yaml_lint.py` currently enforces that `opl_patch`, `mt32_patch`, and `gm_program` are present for tier 1.


### Volume control & Base Channel Overrides
Specify device-scoped volumes (`opl_volume`, `mt32_volume`, `gm_volume`, `imfc_volume`: `<0-127>`). For OPL3, `opl_volume` maps to carrier total-level. Device-scoped keys are preferred; legacy `volume` is deprecated and produces lint warnings.
To override the base GB channels on OPL for a song, specify `opl_base_channels:` at the root of the enhancement YAML (e.g. `opl_base_channels: { ch1: duty_clean, ch2: duty_clean }`).


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
voice count within OPL3 polyphony, no unison doubling of base melody, all
three patch fields present. Percussion channels (`rhythm: true`,
`percussion: true`, or a GM percussion program — Timpani 48 / Percussive
family 113–120) are exempt from the pitched-voice rules — unison-doubling,
in-channel overlap, and pitch range — since drums/hits share pitches by
nature; the OPL3 voice budget (polyphony) still counts them.

After lint passes: if you added timed program switches to a song, register
its exact per-channel switch counts in the `switched` dict in
`dos_port/tools/audio/test_switches.py` (every unregistered song must
resolve zero switches — a silently dropped switch still lints clean, so
only those numbers catch it), and bump the file counts there when adding a
song. Then run `python3 dos_port/tools/audio/test_switches.py` to green.

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
4. **Writing voices that only work with reverb** — OPL3 has no reverb.
   If a voice needs reverb to sound good, it belongs in tier 2–3.
5. **Exceeding voice budget** — when the added channels exceed the free
   melodic parts, the compiler drops whole layers **highest tier number
   (lowest priority) first** (`gb_to_midi.py:enhancement_tracks`), so
   tier-1 is the last to go — but if you stay within budget, nothing
   gets dropped.

---

## Reference Index

| File | What it covers | When to read it |
|------|---------------|-----------------|
| [hardware_constraints.md](references/hardware_constraints.md) | OPL3 voice count, channel layout, available patches, FM synthesis characteristics | When you need to know what's technically possible |
| examples/ | Hand-crafted worked example (when available) | Before writing your first arrangement — see what good output looks like |
| music-theory skill | All theory references | Always read first |

## Auditioning music (listen to a track — do NOT tailspin into rebuilds)

Two paths, fastest first. The arranger skills (`audio-enhance-opl3` /
`audio-enhance-mt32`) own *what* to write; this section owns *how to hear it*.

**1. Host-side (seconds, no DOS boot)** — `dgad` (pkmn-audio-dbg) renders
any device headless to WAV for verification. (Its interactive GUI is for
human ear-checks, not agent workflows.) `tools/audio/audition.py` is
deprecated — do not document or use it.

```sh
# OPL3 — instant host FM synthesis, zero external synths needed:
dgad --headless --track Music_PalletTown --device opl3 --out pal.wav
# Fuzzy song matching:
dgad --headless --track palet --device opl3 --out pal.wav   # resolves to Music_PalletTown

# MIDI targets:
dgad --headless --track Music_Celadon --device mt32 --out cel.wav
dgad --headless --track Music_Celadon --device gm --out cel_gm.wav
# IMFC path (all mapped tracks render-verified this way):
dgad --headless --track Music_Celadon --device imfc --out cel_imfc.wav

# Useful batch flags (see `dgad --help`):
#   --frames N    render N 60 Hz frames (default: full track length)
#   --no-enh      disable the enhancement layer (GB baseline only)
#   --project-dir <path>  override the project root directory
```
Batch renders print peak/nonzero stats — nonzero==0 means silence (broken map).

**2. In-DOS (end-to-end, real drivers)** — only when verifying the actual
driver path (OPL shim, MPU-401, Tandy/speaker). The track is a make variable —
**never edit the Makefile or debug_dump.asm to swap songs**:

```sh
dos_port/run DEBUG_AUDIO=1 TRACK=MUSIC_CELADON /LOOP   # OPL3, loops forever
dos_port/run-mt32 DEBUG_AUDIO=1 TRACK=MUSIC_CELADON /LOOP  # MT-32 via MUNT
```

`TRACK=` takes any `MUSIC_*` constant from `assets/audio_constants.inc`
(default `MUSIC_GAME_CORNER`); the bank resolves via the generated
`<name>_BANK` constant. Without `/LOOP` the harness plays the Phase-A demo
sequence (music + SFX + cry + PCM) then dumps audio state to `DUMP.BIN` and
exits — that's the byte-verification mode, not the listening mode.

**Enhancements on/off (A/B) — host-side vs in-DOS:**
- **Host-side (`dgad`)**:
  - Works identically for **both OPL3 and MT-32/GM**: press `[Space]` to toggle
    enhancements On/Off or `[Tab]` to flip between working copy and previous
    revisions mid-playback without stopping or rebuilding anything.
- **In-DOS (end-to-end driver verification)**:
  - **OPL3**: the tier-1 layer is a *runtime* overlay (`opl_enh.asm` streams) —
    the `/NOENH` exe flag disables it live: `dos_port/run DEBUG_AUDIO=1
    TRACK=... /LOOP /NOENH`. No rebuild of assets needed.
  - **MT-32/GM**: in the DOS executable, enhancements are **baked into the MIDI
    stream at asset-gen time** (`gb_to_midi.py` folds `enhancements/<Song>.yaml` in;
    `mpu401.asm` does not evaluate `/NOENH`). In-DOS verification of the plain
    stream requires regenerating assets:
    ```sh
    python3 tools/audio/gb_to_midi.py --target mt32 --songs GameCorner --no-enhance
    python3 tools/audio/midi_to_stream.py --target mt32
    dos_port/run-mt32 DEBUG_AUDIO=1 TRACK=MUSIC_GAME_CORNER /LOOP
    make -C dos_port assets   # afterwards: restore the enhanced streams
    ```
    (`mpu401.o` depends on `music_streams.inc` in the Makefile, so the rebuild
    picks the regen up automatically.)
- A song with no `tools/audio/enhancements/<Song>.yaml` sounds identical with or
  without any of this: enhanced == plain until a YAML exists. Which songs have
  one changes — list it, don't recall it
  (`ls dos_port/tools/audio/enhancements/*.yaml`). At 2026-09-11 there are 16 YAML files
  (see `docs/audio_enhancement_status.md` for live per-track statuses).
