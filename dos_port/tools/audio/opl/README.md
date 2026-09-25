# OPL3 Patches (`tools/audio/opl/patches.yaml`)

This directory contains declarative patch definitions for 2-operator FM synthesis on OPL2/OPL3 Yamaha YM3812 / YMF262 sound chips in the Pokémon Yellow MS-DOS port.

`patches.yaml` is the human-owned Tier-2 source of truth for all OPL patches used across the game's music and sound effects.

## Patch Format

Each patch entry in `patches.yaml` defines the register parameters for the two operators (Modulator and Carrier):

```yaml
patches:
  duty_50:
    name: duty_50
    description: 50% square wave (symmetrical pulse)
    modulator:
      mult: 1          # Frequency multiplier (0-15)
      ksl: 0           # Key scale level (0-3)
      tl: 18           # Total level / modulation depth (0-63, 0 = max modulation)
      ar: 15           # Attack rate (0-15, 15 = instant)
      dr: 0            # Decay rate (0-15)
      sl: 0            # Sustain level (0-15, 0 = loudest sustain)
      rr: 0            # Release rate (0-15)
      ws: 0            # Waveform select (0-7, 0 = sine)
      vib: false       # Frequency vibrato
      eg: true         # Envelope type (true = sustain indefinitely)
      ksr: false       # Key scale rate
      am: false        # Amplitude modulation (tremolo)
    carrier:
      mult: 1
      ksl: 0
      tl: 0            # Base carrier attenuation (0-63)
      ar: 15
      dr: 0
      sl: 0
      rr: 0
      ws: 0
      vib: false
      eg: true
      ksr: false
      am: false
    feedback: 4        # Operator 1 feedback strength (0-7)
    connection: 0      # 0 = FM (series mod->car), 1 = AM (parallel additive)
```

## Compilation

Run `python3 tools/audio/gen_opl_patches.py` to compile `patches.yaml` and song base channel overrides into `assets/opl_patches.inc`.
This is also run automatically by `make -C dos_port assets`.
