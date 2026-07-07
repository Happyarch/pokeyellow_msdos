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
    mt32_program: 80 # program change sent when --target mt32 (MT-32 default
                     # timbre bank numbering, 0-127)
    gm_program: 80   # program change sent when --target gm (General MIDI)
    program: 80      # fallback used when the per-target key is absent
    volume: 100      # CC7 sent at song start (0-127)
    pan: 64          # CC10 at song start (0-127); when set, the song's own
                     # stereo_panning commands are suppressed for this channel
  3:
    mt32_program: 38
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
- The MT-32 default timbre bank is NOT GM: until `gen_mt32_patches.py`
  (custom timbres) and MUNT auditioning land, `mt32_program` values are
  placeholders using GM numbering and will sound approximate.
