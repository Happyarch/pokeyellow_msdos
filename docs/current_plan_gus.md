# Current Plan: Gravis Ultrasound (GUS) support — SEEDLING

Status: **SEEDLING — serious future consideration, not scheduled.** Written
2026-09-12 as a placeholder so the idea holds its slot; expand into a full
spec before building. Re-verify file:line claims against HEAD at build time.

## Thesis

The GUS is the "sampled audio" slot: 32 hardware-mixed voices with onboard
RAM. Instead of synthesizing, we *upload* — SFX and cries as one-shot samples
first, sampled instruments for music later. Same branch of the family as the
RF5c68 side of a hypothetical Towns port. Emulator support confirmed in-tree:
`[gus]` in `dosbox-x.reference.full.conf:1960-2041` (`gus=false` default,
`gusbase=240`, `gusirq=5`, `gusdma=3`, `gustype=classic`), `gus.cpp` in
`src/hardware/Makefile.am:14`.

## Hardware facts (verify at build — recorded from general knowledge, not yet
measured against the vendored source)

- GF1 chip: 32-voice hardware mixing, output rate drops as voice count rises
  (44.1 kHz at ~14 voices); onboard DRAM (256 KB base, up to 1 MB) holds
  samples; voices programmed with start/loop/end addresses, frequency, volume,
  pan. Classic GUS programming: select voice, write registers, DMA-upload
  samples once at init (the `mt32_upload` shape: `mpu401.asm:168-196`).
- Detection: GF1 presence is probed by DRAM readback, not a flag — a real
  probe is possible here (unlike Tandy/SID write-only chips). Bounded-poll
  discipline per `mpu401.asm` regardless.
- No per-song arrangement files: samples are driver data (like the SID SFX
  table decision), not enhancements.

## Mapping (proposed)

- **v1 — SFX + cries on GUS RAM, music stays OPL.** One-shot samples triggered
  per GB SFX event; Pikachu PCM cry plays from RAM instead of blocking DSP
  PWM. Mirrors the proven combo precedent (MT-32 music + SB SFX,
  `mpu401.asm:10-18`): synth carries music, sampler carries transients.
  Small, faithful, no arrangement work.
- **v2 — sampled instruments for music.** Upload looped pulse/wave samples;
  voice frequency follows GB pitch per tick (the sustain-riding pattern from
  the SID draft, applied to sample rate instead of a nibble). Real design work:
  sample set authoring, loop-point tuning, voice budget across 32 voices.
  Explicitly later; v1 must not preclude it (voice allocator, not hardcoded
  voice assignments).
- Dispatch: new `g_shim_device` value + `/GUS` flag, one `audio_tick` arm;
  `run-gus` appends `[gus] gus=true` (tracked conf stays clean).

## Stages

- [ ] **0. Groundwork.** GF1 register map + DRAM upload protocol verified
  against vendored `gus.cpp`; sample sourcing decided (synthesized loops vs
  recorded — recorded anime cries are a copyright question, flag it now).
- [ ] **1. Driver `src/audio/gus_shim.asm`** (port-only HAL,
  `DEVIATION{class=HAL}`): DRAM probe, sample upload at init, one-shot trigger
  path for SFX/cries, voice allocator shaped for v2.
- [ ] **2. Dispatch + runner.** `/GUS` in `entry.asm`, `audio_hal.asm` arm,
  `run-gus` (+`.ps1`).
- [ ] **3. v1 ear-checks.** SFX set, Pikachu cry (GUS vs speaker A/B), music
  untouched on OPL; `DEBUG_AUDIO` loops unchanged.
- [ ] **4. Gates.** `lint_pret_labels` 0, `static_gate` clean, fidelity green
  with byte-identical `GBSTATE.BIN` (output-only — assert it).
- [ ] **5. (Later) v2 sampled-instrument music.** Own spec when v1 lands.

## Risks

Sample sourcing/copyright; GF1 programming errata (the chip is famously
quirky — budget bring-up time against real docs, not memory); v2 scope creep
swallowing v1 (hold the line: v1 ships without a single music sample).
