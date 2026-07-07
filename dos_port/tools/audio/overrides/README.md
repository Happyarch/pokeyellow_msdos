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

Notes:
- GB `tempo`, note lengths and loop points come from the engine simulation
  and are not overridable — the MIDI is timing-faithful by construction.
- The MT-32 factory bank is NOT GM — a GM-numbered `mt32_program` selects
  a different (often absurd) instrument: GM 80 "Lead 1 (square)" lands on
  factory patch "Sax 3". This is exactly why names are preferred: the YAML
  then says what it sounds like. (Verified by ear 2026-07-07 — the default
  80/80/38 played Celadon as two saxes + a bell.)
- Once `timbres.yaml` uploads custom timbres, its Patch Memory rewrites
  redefine slots and the factory names for those slots stop being true —
  point `mt32_program` at the rewritten slot number per the timbres.yaml
  header comment.
