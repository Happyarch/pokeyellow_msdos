# Plan: Dedicated Pokémon Cry Audio Engine & Multi-Device Routing

Status: **COMPLETE & ARCHIVED — landed 2026-09-24.**
Proposes a dedicated audio subsystem for Pokémon cries across all supported DOS sound devices, replacing the unconvincing OPL FM synthesis with true DAC playback on Sound Blaster, Covox, and GUS, while providing faithful hardware-appropriate fallbacks for Tandy PSG, CMS, and Innovation SSI-2001 (SID).

---

## 1. Thesis & Motivation

Pokémon cries in Generation 1 are not standard musical chiptune melodies or simple sound effects. They are specialized, hardware-abusing routines that exploit idiosyncratic properties of the Game Boy APU:
1. **Rapid 60 Hz Duty Cycle Swapping (`$FC`)**: Swapping between four 2-bit duty cycles (12.5%, 25%, 50%, 75%) frame-by-frame creates 70 complex, vocal-like evolving timbres.
2. **Exponential Pitch Curves & 11-Bit Register Overflow**: The 11-bit frequency math $f = \frac{131072}{2048 - x}$ causes non-linear pitch arcs, and adding the 8-bit pitch modifier overflows past 2047, wrapping high screeching frequencies into deep guttural drops.
3. **Chaotic 7-bit vs 15-bit LFSR Parameter Scrambling**: Adding the 8-bit pitch modifier directly to the raw noise register byte scrambles the clock divider and toggles bit 3 (switching between metallic 7-bit ring-mod-style buzz and 15-bit white noise).
4. **Pitch Shift Cancellation Noise Tails**: Once both pulse channels reach their final release note, `wCryPitch` is wiped from memory while the noise channel continues playing, abruptly snapping lingering noise notes back to their unshifted base parameters (producing the iconic ending grumbles/crashes in Doduo, Drowzee, etc.).
5. **Pulse-Only Time Stretching**: Stretching modifies pulse note durations via an 8.8 fixed-point frame accumulator, altering the relative alignment of the un-stretched noise channel.

### Why 2-Operator FM (OPL2/OPL3) Fails
Yamaha OPL2/3 FM synthesizers cannot reproduce these behaviors:
- OPL has **no variable pulse width** (no 12.5%, 25%, 50%, 75% duty cycles, and no ability to modulate duty cycle frame-by-frame).
- OPL has **no LFSR noise generator on melodic channels**. The port's `opl_shim.asm` must approximate noise using Voice 3 operator feedback (patch 5), resulting in muffled or screechy FM static.
- Static YAML patch overrides (`tools/audio/sfx/*.yaml`) cannot capture dynamic 3-channel APU routines.

### The Solution: A Dedicated Cry Audio Engine
Separate Pokémon cries from standard game SFX:
- Route cries through **digital PCM DACs** whenever available (Sound Blaster DSP, Covox Speech Thing / Disney Sound Source, Gravis UltraSound).
- Route cries to **native pulse-width / PSG synthesis** on non-DAC chiptune cards (Tandy SN76489, CMS SAA1099, Innovation SSI-2001 SID).
- Mute all base music channels and active enhancements while a cry is sounding, mirroring original Game Boy behavior where the cry cuts through the entire soundscape cleanly.

---

## 2. Hardware Architecture & Device Routing

| Device Category | Target Devices | Cry Playback Strategy | Coexistence / Music Handling |
| :--- | :--- | :--- | :--- |
| **Primary DAC** | **Sound Blaster** (1.0, 1.5, 2.0, Pro, 16, AWE32) | 8-bit unsigned PCM via DSP DAC (`sb_pcm_play` direct mode or single-cycle DMA). | Cut/pause OPL music & enhancements during cry; restore/re-key after. |
| **Parallel DAC** | **Covox Speech Thing** & **Disney Sound Source** | 8-bit unsigned PCM streamed to LPT port at 7 kHz. | Already implemented via `covox_shim.asm` software APU emulation. |
| **Wavetable / Sampler**| **Gravis UltraSound (GUS)** | One-shot sample triggered from onboard DRAM across GF1 hardware voice channels. | GF1 hardware mixing; music on OPL or GUS. |
| **Variable Pulse Chiptune** | **Innovation SSI-2001 (MOS 6581 SID)** | 1. Companion DAC (SB/Covox) if present.<br>2. Native SID synthesis: 12-bit programmable pulse width ($02/$03, $09/$0A) for duty modulation + 23-bit LFSR noise.<br>3. PC Speaker PWM fallback if standalone. | SID voices cut held notes during cry; native voices or speaker play cry. |
| **PSG Chiptune** | **Tandy 1000 / PCjr** (SN76489), **Game Blaster / CMS** (2× SAA1099) | Native PSG synthesis: 3 square channels + hardware LFSR noise. | Tandy/CMS voices 0-3 take over; held notes cut. |
| **Minimal Fallback** | **PC Speaker** | 1-bit timer PWM via PIT Channel 2 (`spk_pcm.asm`). | CPU-polled PWM with interrupts disabled. |
| **FM Fallback** | **AdLib** (standalone OPL2 without Sound Blaster) | Legacy FM voice approximation (existing `opl_pass` path). | Voices 0-3 take over FM channels. |

---

## 3. Muting & Audio Isolation Contract

On the original Game Boy, Pokémon cries take absolute priority:
- Channels 5, 6, and 8 completely supersede the music on Pulse 1, Pulse 2, and Noise.
- The Wave channel is silenced or ducks so the cry is completely unobstructed.
- In our DOS port:
  1. **Base Music Voices**: When a cry starts, silence active voices (`opl_silence`, `tandy_silence`, `covox_silence`, `spk_silence`, `midi_all_notes_off`).
  2. **Tier-1 OPL Enhancements**: Call `enh_seq_stop` or mute enhancement slots so extra FM channels do not drone over the cry.
  3. **Post-Cry Recovery**: Once the cry finishes, the audio engine naturally re-keys music channels on subsequent note events.

---

## 4. Cry Sourcing: Runtime APU Synthesis vs Pre-Rendered Assets

There are two primary technical approaches for producing the 8-bit PCM audio stream for the 151 Pokémon cries:

### Approach A: Runtime Software APU Synthesis (Recommended)
- **Concept**: Extract the APU software synthesis engine from `covox_shim.asm` into a standalone synthesizer function (`cry_render_pcm`).
- When `PlayCry` is called:
  1. Read `[base_cry_id, pitch_mod, tempo_mod]` from `CryData`.
  2. Render the cry into a scratch PCM buffer in RAM (typically 4–8 KB at 11,025 Hz or 8,000 Hz). Software rendering 0.5 seconds of audio takes only 2–4 ms on a 386/486.
  3. Hand the buffer to the target DAC player (`sb_pcm_play`, GUS DRAM, etc.).
- **Pros**:
  - Zero disk / ROM footprint (no 1 MB audio asset blob).
  - 100% faithful to the Game Boy APU register math (including overflow, duty hopping, and LFSR scrambling).
  - Can synthesize custom or randomized cries dynamically.

### Approach B: Pre-Rendered PCM Asset Blob
- **Concept**: A host Python build tool (`tools/audio/gen_cries_pcm.py`) emulates the GB APU offline for all 151 species, emitting `assets/cries_pcm.bin` and an index table `assets/cries_pcm.inc`.
- Total data size: 151 cries × ~5 KB = ~750–850 KB.
- **Pros**: Zero runtime CPU rendering overhead; simple pointer-and-length lookup.
- **Cons**: Adds ~850 KB to the asset payload.

*Recommendation*: Implement **Approach A** as the primary path (reusing the already-proven, cycle-accurate APU math from `covox_shim.asm`), with the option to fall back to pre-rendered assets if runtime rendering latency on low-end 386SX hardware proves noticeable.

---

## 5. Timing & Golden Test Compatibility

In `src/home/pokemon.asm`, `PlayCry` is an inherently blocking operation:
```nasm
PlayCry:
    ...
    call GetCryData
    call PlaySound
    call WaitForSoundToFinish    ; blocks until cry completes
    ...
    ret
```
- As documented in stigmergy memory `playcry-blocking-contract-destubbed`, `WaitForSoundToFinish` must wait for the exact duration of the cry. Golden scenarios (`bills_pc_ops`, `box_change_roundtrip`, `pokedex_entry`, `route_15_binoculars`) execute autokey schedules keyed to precise frame counts.
- Any cry implementation must preserve this frame duration:
  - If using synchronous direct mode (`sb_pcm_play`), the elapsed time must accurately reflect the cry's frame count, and `DelayFrame` / frame counters must advance consistently.
  - If using asynchronous DMA or per-frame buffer filling, `WaitForSoundToFinish` will continue to spin-wait across `DelayFrame` until the sound channel clears, naturally preserving exact frame cadence.

---

## 6. Linter & Exclusion Policy

- **`tools/audio/sfx/*.yaml`**: Exclusively reserved for UI, overworld interaction, and battle sound effects.
- **Enforcement**: `tools/audio/gen_sfx_data.py` must reject any YAML targeting `SFX_CRY_*` or IDs in the `[CRY_SFX_START, CRY_SFX_END]` range with a fatal build error.
- **Documentation**: Documented in `tools/audio/sfx/README.md`.

---

## 7. Implementation Stages

- [x] **0. Linter & Policy Enforcement.**
  - [x] Update `tools/audio/gen_sfx_data.py` to validate and reject cry sound profiles.
  - [x] Update `tools/audio/sfx/README.md` documenting the exclusion.
- [x] **1. Cry APU Synthesis Core.**
  - [x] Extract the 3-channel GB APU synthesis routines from `covox_shim.asm` (pulse duty cycling, 11-bit frequency overflow, 7-bit/15-bit LFSR noise, volume envelopes) into a reusable software synthesis module `src/audio/cry_synth.asm`.
  - [x] Verify synthesis output against recorded Game Boy cry reference WAVs.
- [x] **2. Sound Blaster DSP Cry Playback.**
  - [x] Implement `sb_cry_play` in `src/audio/sb_pcm.asm`: mute base OPL and enhancement voices, play the synthesized cry via DSP direct mode (or single-cycle DMA), and restore voices.
  - [x] Hook `sb_cry_play` into `src/home/pokemon.asm:PlayCry` when `ROLE_PCM` is set on the Sound Blaster device.
- [x] **3. Audio Muting & Enhancement Coexistence.**
  - [x] Add explicit ducking/muting of Tier-1 OPL enhancements (`enh_seq_stop` or mute flag) and MT-32/GM MIDI music (`midi_all_notes_off`) during cry playback.
  - [x] Ensure music re-keys cleanly after the cry completes.
- [x] **4. Innovation SSI-2001 (SID) & PSG Integration.**
  - [x] In `innova_shim.asm`, implement 12-bit pulse-width modulation for SID Voices 1 & 2 to support the 4-step duty cycle patterns during cries.
  - [x] Wire multi-device fallback: if SID is paired with Sound Blaster or Covox, route cries to the DAC while SID plays music.
- [x] **5. Verification & Golden Suite.**
  - [x] Verify `pokedex_entry`, `party_menu`, and `battle_pikachu` golden scenarios pass with zero divergences.
  - [x] Audition cries and verify clean assembly and static gate passing 8/8.
