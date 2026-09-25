# SFX Sound Profiles (`tools/audio/sfx/*.yaml`)

This directory contains declarative sound-design profiles for sound effects in the Pokémon Yellow MS-DOS port.

These files are **human-owned Tier-2 configuration sources** — never wiped by `make assets`. They configure which OPL3 FM patches and volume offsets are used when an SFX is triggered in-game, transforming the generic screechy noise channel into faithful, pleasant sound effects (doors, footsteps, combat thuds, menu clicks).

## File Naming

One file per sound effect named after its constant in `assets/audio_constants.inc` (without the `SFX_` prefix, case-insensitive, e.g. `Go_Outside.yaml` or `SFX_Go_Outside.yaml`).

## Pokémon Cries (`SFX_CRY_*`)

All 38 canonical base Pokémon cries (`SFX_CRY_00` .. `SFX_CRY_25`) are defined as YAML profiles in this directory.

Cries in Generation 1 are dynamic Game Boy APU routines utilizing rapid duty-cycle modulation, pitch sweeps, and noise scrambling.
- **Default Playback (`playback: soft_apu`)**: When Sound Blaster hardware is available, cries synthesize APU audio to 8-bit unsigned PCM at 22,050 Hz and stream directly via 8237 single-cycle DMA in the background (`src/home/pokemon.asm:PlayCry` -> `sb_cry_play`).
- **FM Fallback (`channels:`)**: For users on cards without PCM DAC hardware (such as standalone AdLib / OPL2) or when `/NO_SB` is specified, `PlayCry` jumps to its fallback path (`GetCryData` -> `PlaySound`), which plays the cry through the OPL FM synthesizer. The patches defined under `channels:` (e.g. `pulse_soft`, `noise_soft_whoosh`) customize the FM voices for these systems, eliminating harsh high-frequency noise bursts.

## Schema

```yaml
schema: 1
sfx: SFX_GO_OUTSIDE             # Constant from assets/audio_constants.inc
playback: soft_apu              # Optional: 'soft_apu' routes via Sound Blaster DMA PCM; defaults to 'fm'

# Channel overrides (keyed by GB software channel id: 5=pulse1, 6=pulse2, 7=wave, 8=noise)
# For 'soft_apu', channels serves as the FM fallback profile for AdLib / OPL2 systems.
channels:
  8:
    patch: noise_soft_whoosh    # Patch name from tools/audio/opl/patches.yaml
    volume: 90                  # Volume scaling (0-127, default: 100)
```

### Playback Routing (`playback:`)

- `fm` (default): Sound effect plays via 2-operator FM synthesis on the OPL3/OPL2 chip using the specified patch overrides.
- `soft_apu`: When Sound Blaster DMA is available, the SFX bytecode is synthesized to 8-bit unsigned PCM at 22,050 Hz via the virtual APU core (`cry_synth.asm:sfx_render_clip`) and streamed asynchronously via 8237 single-cycle DMA in the background (`sb_pcm.asm:sb_sfx_dma_play`). If Sound Blaster is absent or busy, it seamlessly falls back to the FM profile defined in `channels:`.

## Available Patches

Defined in `tools/audio/gen_opl_patches.py`:
- `noise_soft_whoosh`: Soft, breathy air rush (doors, steps, ledges, running).
- `noise_heavy_thud`: Low, punchy 808-style acoustic impact (Tackle, Mega Kick, faint thud).
- `noise_crunch`: Crisp mid-frequency bite for neutral combat hits.
- `noise_click`: Micro-transient snick for menu open, button clicks.
- `noise_poof`: Soft decaying white puff for ball opening / smoke.
- `pulse_soft`: Rounded duty cycle for high-pitched sweeps.
- Plus standard base patches: `duty_125`, `duty_25`, `duty_50`, `duty_75`, `duty_clean`, `wave`.

## Auditioning

Fast host-side auditioning with live hot-reload and a default 2.5s loop delay:

```bash
tools/audio/audition.py SFX_GO_OUTSIDE
tools/audio/audition.py SFX_SUPER_EFFECTIVE --delay 2.5
```

Controls:
- `[Space]`: Retrigger sound immediately.
- `[Tab]`: Instant A/B toggle between default generated APU sound (the current screech) and the tuned YAML profile.
- `[` / `]`: Decrease / increase replay delay by 0.5s.
- `[P]`: Pause / resume automatic replay loop.
- `[Q]`: Quit.
