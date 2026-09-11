# Enhancement YAML — pinned schema (v2)

Per-song **additive** arrangement channels for the LLM music arranger
(audio plan, Phase E). One file per song: `enhancements/<SongLabel>.yaml`
(same label as `overrides/`, e.g. `Music_PalletTown.yaml`).

These files are **authoritative hand/LLM-authored sources** — never
generated, never clobbered by `make assets`, always human-auditioned
before they ship. Everything downstream (`yaml_lint.py`, the merge in
`gb_to_midi.py`, the OPL enhancement stream player) implements *this*
document; change the schema here first, bump `schema:`, and update the
consumers together.

Design rationale: `docs/llm_arranger_design_notes.md`; decisions:
`docs/current_plan_audio.md` (Phase E section). Authoring guidance lives
in the skills (`music-theory`, `audio-enhance-opl3`, `audio-enhance-mt32`).

---

## Ground rules (from the plan, restated as schema law)

1. **Musical positions only** — measure/beat/duration. Never frame
   deltas, never MIDI ticks, anywhere in this file.
2. **Additive only** — channels here are *extra* voices. The base 4 GB
   channels are untouchable and are not represented in this file.
3. **Tier-tagged** — every channel carries `tier: 1|2|3`.
   Tier 1 plays on OPL3 *and* MT-32/GM; tiers 2–3 on MT-32/GM only.
4. **Explicit per-target patches** — tier 1: `opl_patch` + `mt32_patch`
   + `gm_program`, all three. Tiers 2–3: `mt32_patch` + `gm_program`,
   and `opl_patch` must be absent. No auto-mapping.
5. **Motifs are orchestrated once** — repeated material goes in
   `patterns:` and is instantiated by reference; the compiler duplicates.

## Timing model

- The base pipeline is frame-exact (1 MIDI tick = 1 frame = 1/60 s; GB
  tempo is folded into note durations, not MIDI tempo). Musical
  positions are resolved to frames through the song's **beat map**
  emitted by `music_analysis.py` (`analysis/<SongLabel>.yaml`): the
  frame offset of every measure/beat, derived from the song's
  `note_type` speeds and `tempo` commands.
- **Measure 1, beat 1 = frame 0** — the very start of the song,
  including any intro. Measures/beats are 1-based. `b` may be
  fractional (`1.5` = the off-eighth after beat 1 in a quarter-note
  beat). Durations (`d`) are in beats, fractional allowed.
- The meter comes from the analysis file (`meter: [4, 4]` unless the
  analysis says otherwise); a `beat` is the meter's denominator note.
- **Loop**: events cover exactly what the base `.mid` covers — the
  intro plus one full loop body. The merged song inherits the base
  song's `loopStart`/`loopEnd`; events past the loop end are a lint
  error. For songs whose loop return differs from the first statement
  (see the score-analysis skill), author against the loop *body* — it,
  not the first statement, is what repeats.
- **Unrolled songs** (loop ramp-and-hold): a file opts in with top-level
  `unroll: N` (default 1). The merged span is then intro + N loop
  bodies and the loop region is the *final* body — intro + ramp play
  once, the hold body loops forever (this mirrors the engine, whose
  `.mainloop` runs past the intro). Non-`evolving` channels author
  intro + one body and the compiler repeats the body across iterations;
  an `evolving: true` channel authors every iteration explicitly
  (ramps). Positions past the first body resolve by loop-period folding
  through the analysis beat map. Tier 1 + `evolving` is an error: the
  OPL enhancement stream plays exactly one loop body, so a tier-1 ramp
  is unrepresentable (the OPL path accordingly sees intro + first body
  only). First use: `Music_MeetEvilTrainer.yaml` (`unroll: 2`,
  heartbeat ramp into a tachycardic hold).

## File shape

```yaml
schema: 1                    # this document's version; lint rejects others
song: Music_PalletTown       # must match the file name and a real song label

channels:
  - name: warm_pad           # unique slug within the file
    tier: 1
    opl_patch: soft_pad      # name from gen_opl_patches.py PATCHES (tier 1 only)
    mt32_patch: 33           # 1-based MT-32 preset, or a custom-timbre name
                             #   from mt32/timbres.yaml (string)
    gm_program: 89           # 1-based GM program
    pan: center              # left | center | right (default center)
    volume: 80               # 0-127, MIDI CC7; OPL player maps to TL
    velocity: 96             # default per-note velocity (optional, default 96)
    transpose: 0             # semitones, applied to every note (optional)
    events:
      # literal note: measure, beat, duration-in-beats, note(s)
      - {m: 5, b: 1,   d: 4,   n: [E4, G4]}     # list = chord
      - {m: 6, b: 1.5, d: 0.5, n: C5, v: 72}    # v = per-note velocity
      # pattern instance: place a named pattern at a measure
      - {at: 9,  pattern: pad_a}
      - {at: 13, pattern: pad_a, transpose: 2}  # instance-level transpose

  - name: string_swell
    tier: 2                  # MT-32/GM only — no opl_patch allowed
    mt32_patch: 49
    gm_program: 49
    events:
      - {m: 9, b: 1, d: 8, n: [G4, B4, D5]}

patterns:
  pad_a:
    measures: 4              # declared span; instances occupy [at, at+measures)
    events:                  # positions relative to the pattern start
      - {m: 1, b: 1, d: 8, n: [C4, E4]}
      - {m: 3, b: 1, d: 8, n: [D4, F4]}
```

### Field reference

| Field | Type | Rules |
|-------|------|-------|
| `schema` | int | Must be `1` or `2`. `2` adds `switches:`; v1 files stay valid without edits. |
| `unroll` | int ≥ 1 | Loop ramp-and-hold span: intro + N loop bodies, loop region = final body. Default 1 (intro + one body). |
| `song` | string | Song label as in `music_constants.asm` / stream names; must match the filename. |
| `channels[].name` | slug | Unique within the file; used in lint/audition reports. |
| `channels[].tier` | 1, 2, 3 | Tier 1 = OPL3+MT-32/GM; 2–3 = MT-32/GM only (3 dropped before 2 under polyphony pressure). |
| `channels[].evolving` | bool | Default false. True = author every unrolled iteration explicitly (ramps). Non-evolving channels auto-duplicate their body across iterations. Tier 1 + `evolving: true` is an error (OPL plays one body). |
| `channels[].name` | slug | Unique within the file; used in lint/audition reports. |
| `channels[].tier` | 1, 2, 3 | Tier 1 = OPL3+MT-32/GM; 2–3 = MT-32/GM only (3 dropped before 2 under polyphony pressure). |
| `channels[].opl_patch` | string | Required iff tier 1. A `PATCHES` key in `gen_opl_patches.py`. |
| `channels[].mt32_patch` | int or string | Required. Int = **1-based** preset number (Program Change byte is value − 1); string = custom timbre name defined in `mt32/timbres.yaml`. |
| `channels[].gm_program` | int | Required. **1-based** GM program. GM and MT-32 numbering do **not** align — pick independently. |
| `channels[].pan` | enum | `left`/`center`/`right`. MIDI CC10 (0/64/127); OPL3 register C0h bits 4–5. |
| `channels[].volume` | int 0–127 | CC7 once at song start; OPL player maps to carrier total-level. Default 96. |
| `channels[].velocity` | int 1–127 | Default note velocity (OPL quantizes coarsely). Default 96. |
| `channels[].transpose` | int | Semitones, whole channel. Default 0. |
| `events[]` note | `{m, b, d, n, v?}` | `m`/`b` 1-based (b fractional ok), `d` in beats > 0, `n` = note name or list (chord). |
| `events[]` pattern | `{at, pattern, transpose?}` | `at` = measure the pattern's measure 1 lands on. Instances of the same channel must not overlap each other or literal notes. |
| `patterns.<name>.measures` | int | Span; instance events must fit inside it. |
| Note names | string | Scientific pitch, **C4 = MIDI 60** (matches `gb_to_midi.py`, where GB octave-4 C ≈ 523 Hz = C5 = 72). `C#4`/`Db4` accepted; a raw MIDI int is also accepted. |

### switches:

Timed mid-song patch changes for tier-2/3 channels (`schema: 2`). A
`switches:` list nests under a channel; each entry is
`{m, b, mt32_patch?, gm_program?, program?}` — `m`/`b` are 1-based
measure/beat (`b` fractional ok), no duration: a switch is
instantaneous. `program` is the fallback when the per-target key is
absent. Ints here are **1-based** (Program Change byte is value − 1),
same as channel-level `mt32_patch`/`gm_program` — the opposite basis
from overrides, where ints are 0-based raw PC bytes (see
`overrides/README.md`).

```yaml
  - name: hc_pad             # PROSPECTIVE — pilot sketch, lands later;
                             # author nothing against it yet
    tier: 2
    mt32_patch: 49           # strings in, choir on the V arrival
    gm_program: 49
    switches:
      - {m: 13, b: 1, mt32_patch: 35, gm_program: 53}
    events:
      - {m: 1, b: 1, d: 8, n: [C4, E4]}
```

Rules:

- Tier is per-channel: a switch never changes tier. Whole-layer drop
  (tier 3 → 2 → 1 under polyphony pressure) drops the channel with its
  switches.
- Switches are MT-32/GM-side only and this includes tier 1: a tier-1
  channel may carry switches (e.g. a pad that is strings under one
  section, voices under another) — the OPL enhancement stream player
  bakes the channel's tick-0 `opl_patch` per key-on and has no
  patch-select op, so the OPL side keeps its tick-0 timbre across switch
  points by construction. Per-target divergence of this kind already
  ships on base channels (override switches), so no new inconsistency
  class is created.
- `opl_patch` inside a switch entry is REJECTED (unknown key): there is
  no encoding by which the OPL side could honor it.
- Rhythm channels cannot switch.
- Loop/unroll follows events: non-`evolving` channels auto-duplicate
  body switches across iterations (intro switches fire once and latch);
  an `evolving: true` channel authors switches per iteration explicitly.
  Seam discipline matches overrides: in channel silence, never under a
  sustain (lint ERROR); first-pass divergence is a WARN, never auto-fix.
- `schema: 2` opts a file into `switches:`; `schema: 1` files stay valid
  without edits.

## Lint contract (`yaml_lint.py` implements exactly this)

1. `schema == 1 or 2` (`2` opts into `switches:`); `song` matches filename and a known song label.
2. Tier/patch-field consistency (rule 4 above).
3. All patch references resolve: `opl_patch` ∈ `PATCHES`, custom
   `mt32_patch` strings ∈ `timbres.yaml`, ints in 1–128.
4. Every position resolves inside the song per the analysis beat map;
   nothing past the loop end (intro + `unroll` loop bodies); pattern instances fit their declared span
   and don't overlap within a channel.
5. Note range: within the target's usable range (per the hardware
   constraint references) after channel + instance transpose.
6. Per-tick (frame) polyphony within budget per target: OPL3 = base 4
   + tier-1 voices ≤ shim budget (see `audio-enhance-opl3` skill);
   MT-32 = worst-case partial count within the reserve plan.
7. **No unison doubling** of a base GB channel (same pitch, overlapping
   time) — octaves are fine, unisons are a wasted voice and parallel
   octaves by construction.
8. Per-song voice budget: warn > 6 tier-1 channels or > 5 total added
   melodic parts (only 5 free MT-32 melodic parts exist).
9. Unroll consistency: `unroll` is an integer ≥ 1 (default 1); `unroll` >
    1 needs a looped song. Non-`evolving` channels must not span loop-body
    boundaries (shorten the note or set `evolving: true`); `evolving` tier-1
    channels are an error.
10. Switches (`schema: 2` only): positions resolve per rule 4; per-target
    patch references resolve per rule 3. `opl_patch` inside a switch entry,
    and switches on rhythm channels are errors (tier-1 channels may carry
    switches — see the switches section). Under-sustain placement is an
    error; first-pass divergence is a warning.

## Compile path

```
enhancements/<Song>.yaml ──┐
analysis/<Song>.yaml ──────┤  (beat map: musical pos → frame)
                           ▼
        gb_to_midi.py --enhance     merge + per-target tier filter
                           │        (whole-layer drop, tier 3 → 2 → 1,
                           ▼         when a target's polyphony is exceeded)
     assets/midi/<target>/<Song>.mid   →   midi_to_stream.py   (MT-32/GM)
                           │
                           └─→ OPL enhancement stream (tier 1 only)
                               played on spare FM voices alongside the shim
```
