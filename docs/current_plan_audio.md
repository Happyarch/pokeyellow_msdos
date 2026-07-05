# Audio Subsystem (Phase 3 HAL)

This document outlines the architectural plan for the Pokémon Yellow DOS Audio subsystem, based on our brainstorming session. It introduces a Hardware Abstraction Layer (HAL) to route audio to multiple DOS-era sound devices without modifying the core game logic for each device.

## Approved Specifications

**Tandy Support**: Tandy sound will be an official target. Since the Tandy PSG maps almost 1:1 with the Game Boy APU, it is a straightforward automated target. However, it will be treated as a "minimal effort" target with very little manual fine-tuning, and users will be made aware of its raw state.

**Audio Timing**: The DOS audio driver will stick to the 60Hz update rate, matching the Game Boy's VBlank timing. This keeps the PIT timer simple and maps perfectly to the original sequence data.

**OPL3 SFX Format**: The Sound Blaster SFX generator will output a flat list of OPL3 port/value register writes per frame (essentially a lightweight VGM-style stream).

**Channel Stealing & SFX Overlap**: The generator will include a toggle to support both overlapping SFX and authentic Game Boy-style channel ducking. This allows for live A/B testing in the engine to determine which sounds better.

**Volume Control & Fading**: A `hal_fade_out` function will be added to the HAL vtable. The DOS driver will automatically scale the master volume down over time (e.g., via MIDI CC Volume messages or OPL3 volume registers) instead of baking fades into the track data.

**Routing Pikachu's Cry**: The main game engine remains blind to hardware limits. It calls `hal_play_sfx(id)` for all sound effects. The Sound Blaster HAL driver will contain the lookup table to internally route PCM cries to the DSP and standard SFX to the OPL3.

**Python Parsing Strategy**: The Python generation tools will operate directly on the `.asm` source files (e.g., `pallettown.asm`) using string/regex parsing. This makes it significantly easier to map high-level macros (like `note C_, 4`) to MIDI events compared to reverse-engineering compiled bytecode.

## Proposed Changes

### 1. The Audio HAL (Wrapper)
We will completely replace the original Game Boy audio engine (`audio/engine_*.asm`). The game will use a high-level function like `PlayMusic(BGM_PALLET_TOWN)`. 

We will introduce `src/audio/audio_hal.asm` containing an `audio_vtable`. At startup, based on user configuration, this vtable will be populated with pointers to the active hardware driver:
- `.init`
- `.play_bgm`
- `.play_sfx`
- `.tick` (Called once per frame)

### 2. Music Asset Pipeline (Generators)
We will use a two-step Python generator pipeline to adhere to the Two-Tier Data rule:
1. **PRET Macros -> Standard MIDI (`.mid`)**: A Python tool parses the original Game Boy macros (e.g., `pallettown.asm`) and generates Standard MIDI files. This fulfills your goal of enabling external VGM/MIDI playback.
2. **Standard MIDI -> Flat Stream (`.xmi`/`.bin`)**: A second pass converts the `.mid` files into a zero-overhead binary stream (similar to the Miles Sound System's `.XMI` format). The DOS assembly driver will blindly read this stream and push bytes to the hardware port, avoiding complex MIDI chunk parsing in real-time.

### 3. Sound Effects (SFX) Routing
Initially, all Sound Effects (menu blips, bumps, attacks) will be routed to the **Sound Blaster OPL3**. If a user selects MT-32 for music, they will still use Sound Blaster for SFX (a very common DOS setup). In the future, we can explore custom MT-32 patches for MIDI-only SFX.

### 4. Pikachu's Cry (PCM)
Pikachu's digitized cries will be handled by the **Sound Blaster 16 DSP** via DMA. Systems without a Sound Blaster (e.g., pure MT-32 or Tandy setups) will fall back to standard chiptune cries or silence, as playing PCM over the PC speaker is not viable.

---

# Audio HAL Implementation Tasks

- `[ ]` **Phase 1: HAL Scaffold & Hooking**
  - `[ ]` Create `src/audio/audio_hal.asm` with `audio_vtable` and dummy handlers.
  - `[ ]` Replace/stub GB audio engine routines (`PlayMusic`, `PlaySound`, etc.) in `audio/engine_*.asm` to call the HAL.
  - `[ ]` Hook the HAL `tick` function into the 60Hz game loop.

- `[ ]` **Phase 2: Generator Tools**
  - `[ ]` Create `tools/audio/gb_to_midi.py` (Parses PRET macros -> Standard `.mid`).
  - `[ ]` Create `tools/audio/midi_to_xmi.py` (Parses `.mid` -> Flat `.xmi`/`.bin` stream).
  - `[ ]` Create `tools/audio/sfx_to_opl.py` (Generates VGM-style OPL3 register dumps for SFX).

- `[ ]` **Phase 3: Hardware Drivers**
  - `[ ]` **Sound Blaster 16**
    - `[ ]` OPL3 FM synthesizer BGM/SFX playback driver.
    - `[ ]` DSP DMA driver for Pikachu's PCM cries.
  - `[ ]` **MPU-401 (MT-32 / GM)**
    - `[ ]` MPU-401 UART initialization and communication.
    - `[ ]` Flat stream `.xmi` playback logic.
    - `[ ]` MT-32 custom patch SysEx loading.
  - `[ ]` **Tandy (Minimal Effort)**
    - `[ ]` SN76489 PSG playback driver.
