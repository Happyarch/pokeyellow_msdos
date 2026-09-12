# Per-song MIDI overrides (`tools/audio/overrides/*.yaml`)

Hand-tuning for the MIDI/MT-32 path lives here — **checked in, never
regenerated**. `gb_to_midi.py` looks for `<HeaderLabel>.yaml` (e.g.
`Music_PalletTown.yaml`) while generating `assets/midi/<target>/*.mid`;
absent files fall back to the defaults in `gb_to_midi.py`.

This is Phase B's counterpart of `gen_opl_patches.py`'s PATCHES dict: the
place where the audition loop (MUNT via `audition.py`, Phase B task 4)
iterates. `make assets` reads these; it never writes them.

## Schema

```yaml
channels:            # keyed by GB channel number (1, 2 = pulse; 3 = wave)
  1:
    mt32_program: "Square Wave"
                     # program change sent when --target mt32. Prefer a
                     # factory-bank preset NAME (hand-editable; full list in
                     # tools/audio/mt32_presets.py, lookup is case- and
                     # punctuation-insensitive); a raw 0-based program
                     # number 0-127 also works.
    gm_program: 80   # program change sent when --target gm; GM level-1
                     # names accepted too ("Lead 1 (square)")
    program: 80      # fallback used when the per-target key is absent
                     # (a name here resolves against the active target)
    volume: 100      # CC7 sent at song start (0-127)
    pan: 64          # CC10 at song start (0-127); when set, the song's own
                     # stereo_panning commands are suppressed for this channel
  3:
    mt32_program: "Warm Bell"
    volume: 110
drums:               # GB channel 4 (noise) → MIDI channel 10
  velocity: 100      # fixed note-on velocity for all drum hits
  map:               # noise-instrument id (drum_note's first argument, a
    1: 42            # noise SFX id) → GM drum note. Ids not listed fall
    2: 38            # back to DEFAULT_DRUM_MAP in gb_to_midi.py.
```

All keys are optional. Unknown top-level keys are an error (typo guard).

### switches:

Timed mid-song program changes, for songs whose arrangement re-voices a
GB channel partway through. A `switches:` list nests under
`channels.<n>` for n in {1, 2, 3} — never under `drums:` (GB channel 4
maps to MIDI channel 10 and has no program to change).

```yaml
channels:
  2:
    mt32_program: "Trumpet 1"
    gm_program: "Trumpet"
    switches:
      - {m: 14, b: 1, mt32_program: "Violin 1", gm_program: "Violin"}
      - {m: 18, b: 2.5, mt32_program: "Trumpet 1", gm_program: "Trumpet"}
```

Shape: each entry is `{m, b, mt32_program?, gm_program?, program?}` —
`m`/`b` are 1-based measure/beat (`b` may be fractional, same positions
as enhancement events); there is no duration — a switch is
instantaneous. Per-target keys work exactly like the channel-level ones:
`program` is the fallback when the per-target key is absent, resolved
against the active target by `resolve_program()` (`mt32_presets.py`).

**Override program ints are 0-BASED — the value is sent as the raw
Program Change byte.** `mt32_program: 56` selects factory patch 57
("Trumpet"), while the same chair in an enhancement file is
`mt32_patch: 57` (enhancement files are 1-BASED — see
`enhancements/README.md`). Prefer names and the basis never matters:
`mt32_program: "Trumpet"` switching to `mt32_program: "Violin"` reads
the same on every target.

Semantics:

- A switch coincident with a note boundary fires at order 1: after
  note-offs, before note-ons — the closing sonority keeps the old patch,
  the arriving one takes the new.
- Loop: a switch in the intro fires once and latches (it stays in force
  through the loop unless an in-loop switch overrides it); a switch
  before the loop entry holds for the whole loop; in-loop switches fire
  every pass. A first pass that therefore sounds different from every
  later pass is a deliberate device — lint WARNs, never auto-fixes.
- Seam: place switches in channel silence. A switch under a sustained
  note re-voices a sounding sonority mid-decay and is a lint ERROR.
- Unrolled songs: body switches duplicate per iteration; intro switches
  play once (the same intro/body split as enhancement events).

Enforced by `yaml_lint.py`: unknown keys and out-of-range positions are
errors, first-pass divergence is a warning, under-sustain placement is
an error.

Notes:
- GB `tempo`, note lengths and loop points come from the engine simulation
  and are not overridable — the MIDI is timing-faithful by construction.
- The MT-32 factory bank is NOT GM — a GM-numbered `mt32_program` selects
  a different (often absurd) instrument: GM 80 "Lead 1 (square)" lands on
  factory patch "Sax 3". This is exactly why names are preferred: the YAML
  then says what it sounds like. (Verified by ear 2026-07-07 — the default
  80/80/38 played Celadon as two saxes + a bell.)
- Custom timbres defined in `mt32/timbres.yaml` can be specified directly by
  name as a string: e.g., `mt32_program: "Theremin"` or `mt32_program: "JigglyVox"`.
  The build pipeline generates per-song SysEx messages that remap the patch pointer
  on the fly when the track starts, and eagerly restore it back to factory
  parameters when the track finishes or stops. Factory presets are never
  permanently overwritten at boot.
