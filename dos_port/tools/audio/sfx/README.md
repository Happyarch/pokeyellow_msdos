# SFX Sound Profiles (`tools/audio/sfx/*.yaml`)

This directory contains declarative sound-design profiles for sound effects in the Pokémon Yellow MS-DOS port.

These files are **human-owned Tier-2 configuration sources** — never wiped by `make assets`. They configure which OPL3 FM patches and volume offsets are used when an SFX is triggered in-game, transforming the generic screechy noise channel into faithful, pleasant sound effects (doors, footsteps, combat thuds, menu clicks).

## File Naming

One file per sound effect named after its constant in `assets/audio_constants.inc` (without the `SFX_` prefix, case-insensitive, e.g. `Go_Outside.yaml` or `SFX_Go_Outside.yaml`).

## Excluded: Pokémon Cries

**No YAML profiles should ever be created for Pokémon cries (`SFX_CRY_*`).**

Cries in Generation 1 are not static single-channel sound effects. They are dynamic 3-channel Game Boy APU routines utilizing rapid 60 Hz duty-cycle modulation, 11-bit frequency overflow, and chaotic 7-bit/15-bit LFSR scrambling. They cannot be represented by static OPL FM patch overrides.

Instead, Pokémon cries route through the dedicated cry engine (Sound Blaster DSP direct mode/DMA, Covox/DSS DAC, GUS DRAM, or native SID pulse-width modulation). `tools/audio/gen_sfx_data.py` will reject any attempt to define a cry profile in this directory.

## Schema

```yaml
schema: 1
sfx: SFX_GO_OUTSIDE             # Constant from assets/audio_constants.inc

# Channel overrides (keyed by GB software channel id: 5=pulse1, 6=pulse2, 7=wave, 8=noise)
channels:
  8:
    patch: noise_soft_whoosh    # Patch name from gen_opl_patches.py PATCHES
    volume: 90                  # Volume scaling (0-127, default: 100)
```

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
