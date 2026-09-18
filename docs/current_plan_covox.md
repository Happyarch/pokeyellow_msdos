# Current Plan: Covox / Disney Sound Source support (`/COVOX`, device 5)

Status: **IN BUILD (round-robin subagents, serial).** Last-resort laptop device
(parallel-port DAC for machines with no sound card). Covox is explicit-only —
never auto-selected; INNOVA likewise dropped from the auto chain (explicit
`/INNOVA` only). Stage 0.4 (chain simplification + bitmask) lands first — it
owns `audio_hal.asm`/`entry.asm`, which stage 2 hooks into.
`--no-verify` on commits while remote.

Numbering: stages are `N`, substeps are `N.N` — one scheme, no NX mixes.

## Why this is cheap (thesis)

- Pinned DOSBox-X emulates it: `disney=true` in `[speaker]` (`disney=false`
  default), Covox Speech Thing / Voice Master / Intersound MDO compatible.
  Config-only, like IMFC/Innova.
- No chip to program: an 8-bit DAC has no voices, so there is no
  waveform-*mapping* problem — only a *rendering* problem (synthesize the 4 GB
  voices as PCM, sum, `OUT 378h`). Simpler than every other shim.
- Precedent: DOS trackers mixed up to 4 channels to Covox in software (Modplay
  "up to 4 channel COVOX output", Inertia Player, FastTracker with dithering);
  Galaxy Music Player did it on an 8088. The 386 mixing budget is ample —
  mixing math is not the constraint; port-I/O rate and tick pacing are.
- Prior decision revisited: `docs/plans/audio.md:776-777` declined LPT-DAC
  ("the APU-emu-to-PCM mixing it would need is out of scope for this plan").
  This plan re-opens it as its own work item; that line stands as history.

## Hardware facts (researched 2026-09-18, second-hand except where noted)

- Covox Speech Thing (1987, ~$70): passive 8-bit R-2R DAC on the LPT data
  lines. No clock, no logic, no buffer, no DMA/IRQ. The CPU outputs one byte
  per sample (`OUT 378h,AL`); rate = whatever the CPU sustains (286 ≈ 12 kHz,
  486SX/33 ≈ 44 kHz — fidelity scales with CPU). Original has a ~3 kHz RC
  low-pass; quality lives/dies on resistor matching.
  Source: https://en.wikipedia.org/wiki/Covox_Speech_Thing
- Disney Sound Source (1990, $14): custom IC — timing generator + **16-byte
  FIFO** + DAC, fixed output **7 kHz ±5%**, autodetect/flow control, software
  on/off, 9 V battery. Backward compatible with Covox raw writes. The FIFO
  absorbs burst-then-idle writes and re-clocks them steady — the architectural
  match for our 60 Hz tick pacing (tick-jitter fix, not just convenience).
  Source: Wikipedia; https://dosbox-x.com/wiki/Guide:Sound-card-support-in-DOSBox%E2%80%90X
- **Primary source located, NOT yet digested:** *The Sound Source Programmer's
  Guide* (5pp PDF) at
  https://archive.org/download/dss-programmers-guide/dss-programmers-guide.pdf
  — scanned; text extraction returns garbage. Needs vision transcription to
  `docs/sound/` (gitignored ARR) following the SID VISION pipeline.
  FIFO/autodetect/flow-control details live there. Backup: VOGONS DSS pinout +
  2015 reverse-engineering thread (deferred — register-level interface already in hand).

## Channel mapping (decided)

- No mapping — the DAC plays computed PCM. Per-voice rendering:
  - ch0/ch1 pulse → square at GB duty (12.5/25/50/75%) and GB pitch.
  - ch2 wave → wave-RAM wavetable **verbatim** (upsampled) — the fidelity win
    no other shim gets (OPL fakes it with an FM patch; Tandy can't do it).
    Normal music instruments load into `_AUD3WAVERAM` at note-on
    (`engine_1.asm:803-835`), so this holds for music.
  - ch3 noise → GB 15/7-bit LFSR in software per sample (cheap PRNG
    acceptable v1). No steal contortions needed.
  - Envelope/sweep/length → per-sample amplitude/pitch modulation, engine
    values, no chip registers.

## Noise / SFX handling (decided: inherited ducking, no shim logic)

- SFX ducking is **inherited, not built**: the mixer reads the virtual APU
  *after* `Audio1_UpdateMusic`, so the engine's own SFX channel-takeover flows
  through automatically — when a GB channel is repurposed for SFX, the soft
  channel follows, and SFX stay audible. Nothing to build.
- Pikachu cry: the real game's wave-RAM-rewrite trick is **absent** in the
  port — the engine writes `_AUD3WAVERAM` only at note-on and scripts bypass
  the engine cry path for blob-playing `PlayPikachuSoundClip`
  (`pikachu_pcm.asm:71-94`, verified 2026-09-18). So the cry does NOT come
  through the mixer for free. Decision: route the existing PCM blob to the DAC
  at `g_covox_rate` (resample once at build/boot, not per play), with a Covox
  arm in `PlayPikachuSoundClip` beside the SB/speaker selection. Small.

## Rate design (decided)

- Default **7 kHz** (safe on every dongle incl. real DSS hardware).
- `POKEMON.CFG [audio] covox_rate = 7000` (decimal Hz) lets faster machines go
  higher — parsed once at boot into `g_covox_rate` (`input_cfg.asm` pattern:
  static literal, compiled-in default, zero per-frame cost). Clamp at parse:
  4000–44500 (below 4 kHz Nyquist eats GB bass; above ~44.5 kHz exceeds any
  real parallel port).
- Mixer written **rate-agnostic** from day one (fixed-point phase accumulators,
  no 7 kHz constants) so the option is real.
- DSS fixed-7 kHz is a **v2-FIFO property, not a v1 branch**: v1 has one output
  mode (Covox-raw writes, accepted by DSS hardware/emulation alike), so the
  rate always applies; FIFO mode later ignores the config value.

## House style + annotation ruling

- `covox_shim.asm` follows the device-shim house style, `gb_memmap.inc`,
  `covox_init/pass/silence/shutdown/dbg_snapshot` + `g_covox_on`,
  NRx4-restart consume (read-only; the mixer never clears what the engine
  reads back — verify at build), virtual APU `[ebp+$FF10..$FF26]`.
- **No DEVIATION annotation** (port-only file; `audio_hal`-style header only).
- PCM blob resampling (if any) is Tier-1 generated data or boot-time
  computation — never hand-encoded bytes in the `.asm`.

## Device selection (decided 2026-09-18)

Per-tick `cmp`/`je` ladders are gone. All current + planned devices fit in
**one 4-byte word**: 8 devices × 4-bit nibbles (`P S M E` = PCM, SFX, MUSIC,
ENABLE, high→low bit). `g_audio_devices: dd 0` is the solved active set:

| Nibble | Device | Notes |
|---|---|---|
| 0 | MIDI stream (GM/MT-32) | music-only row; never SFX/PCM |
| 1 | OPL FM | auto via probe; SFX voice under MIDI |
| 2 | Tandy PSG | forced-only (write-only chip, no probe — flag IS the detection) |
| 3 | PC speaker | always present; SFX blips + PCM PWM |
| 4 | Innova SID | explicit-only, never auto-set |
| 5 | Covox DAC | explicit-only, never auto-set |
| 6 | Disney FIFO | v2 `/DISNEY` flag (reserved) |
| 7 | SB DSP | PCM-only row (`g_sb_present`) |

- `g_audio_forced: dd 0` records the `/FLAG`-demanded subset (low 8 bits) —
  EN means "in the solved set"; forced-vs-auto lives here because the
  nibbles are full. `parse_cmdline` sets forced bits (`/MT32|/GM`→MIDI,
  `/TANDY`, `/INNOVA`, `/COVOX`, `/DISNEY`, `/SPK`). Multiple forced shim
  bits resolve by fixed priority TANDY > INNOVA > COVOX > SPK.
- `audio_init`: `solved = forced ∩ available`, then auto-fill touches ONLY
  OPL (probe) or speaker (always present). A forced bit whose driver
  compiled out (`ENABLE_*=0`) or whose probe fails (MPU, OPL) is cleared.
  Compiled-out drivers gate on their `g_*_present` flags so a cleared bit is
  the only outcome.
- Solved path (pointers resolved at init from the role fields, called blindly
  per tick — zero compares): MIDI nibble music → music = MIDI stream,
  sfx = OPL pass if its SFX field set else speaker pass; otherwise the single
  shim pass voices music+SFX together (never double-pumped — one pass, one
  call), speaker fallback when nothing else selected. Covox/DSS have no
  speaker in the chain (DAC covers SFX + cry; speaker bit-bang moot). PCM
  selection is per-cry, not per-tick: `PlayPikachuSoundClip` branches on the
  PCM fields (DAC > SB DSP > speaker PWM).
- `g_shim_device` byte stays updated from the solved set (debug-snapshot
  compat); the tick loop reads pointers, never the byte.

## Stages

- [x] **0.1. References sufficient.** Guide PDF → `docs/sound/` + distilled
  `DSS_Programmers_Guide.md` + `dss_data_path.svg` /
  `dss_power_control.svg`; README index rows. 0.1.2 (Mark Phillips) and
  0.1.3 (VOGONS) dropped 2026-09-18 — the programming manual already carries
  the register-level interface. Reopen only if a build question needs them.
- [ ] **0.2. Preconditions (read-only, remote-safe).**
  - [ ] 0.2.1 `378h` `OUT` from protected mode under CWSDPMI (port-permission
    risk — verify with a 1-byte probe harness before building the pump).
  - [ ] 0.2.2 `/COVOX` flag: substring-safe vs existing tokens
    (`/COM1` precedent: check `find_token` collisions); explicit-only force
    bit; new `arg_covox` string.
  - [ ] 0.2.3 `DEV_COVOX` nibble 5 in `g_audio_devices`/`g_audio_forced`;
    `disney=true` runner config; `[audio]` section design for
    `input_cfg.asm` (`covox_rate`, default 7000, clamp 4000–44500 —
    maintainer-confirmed 2026-09-18).
- [ ] **0.4. Chain simplification + bitmask (FIRST dispatch — owns
  `audio_hal.asm` + `entry.asm`, lands before stage 2).**
  - [ ] 0.4.1 Mask words + `DEV_*` nibbles; `parse_cmdline` sets forced bits;
    fixed force priority TANDY > INNOVA > COVOX > SPK.
  - [ ] 0.4.2 `audio_init` solve (`forced ∩ available`, OPL-probe / SPK-only
    auto-fill, compiled-out/absent clearing); INNOVA never auto-set
    (explicit `/INNOVA` keeps working — see `current_plan_sid.md` stage 2).
  - [ ] 0.4.3 Solved tick pointers (zero per-tick compares); music/sfx/pcm
    role fields; MIDI music + OPL3-SFX split; Covox/DSS speakerless;
    `PlayPikachuSoundClip` branches on PCM fields; `g_shim_device` compat.
  - Acceptance: nasm clean all `ENABLE_*` combos, lint 0, every existing
    selection (`/TANDY`, `/SPK`, `/MT32`, `/GM`, default, `/NOSOUND`)
    behaves identically; `/INNOVA` still forces device 4.
- [ ] **1. Mixer + pump (`src/audio/covox_shim.asm`).**
  - [ ] 1.1 Skeleton: house-style header, `COVOX_DATA 0x378` equ,
    rate-agnostic fixed-point voice state, six globals. No DEVIATION.
  - [ ] 1.2 Per-tick render (see Channel mapping): duty squares, verbatim
    wave table, software LFSR noise, GB-unit envelope/sweep/length.
  - [ ] 1.3 Pump loop: per-tick sample count derived from `g_covox_rate`,
    tight `OUT` burst (`sb_pcm` `pcm_pace` is the pacing template if even
    spacing proves necessary).
  - [ ] 1.4 Cry arm in `PlayPikachuSoundClip` (blob → DAC at `g_covox_rate`)
    + `g_covox_on` guards + `covox_dbg_snapshot` (mpu401 shape).
  - Acceptance: nasm clean, lint 0, silence is silent, tuner-verified pitch
    on all four voices at 7 kHz.
- [ ] **2. Dispatch + ifdef.**
  - [ ] 2.1 `ENABLE_AUDIO_COVOX` guard (new-convention `%if/%else` stub shape).
  - [ ] 2.2 `/COVOX` parse + 0.2.2 precedence; `audio_hal.asm` device-5 arms.
  - [ ] 2.3 MIDI-coexistence guard (innova 2.3 shape: SFX-only under
    `g_midi_music`) — mixer mutes music voices unless an SFX owns the channel.
  - Acceptance: `/COVOX` alone → DAC music+SFX; `/COVOX`+`/TANDY` →
    documented winner; `/COVOX`+`/MT32` → MIDI music + DAC SFX.
- [ ] **3. Ear-checks + rate sweep.** Pitched/noise/battle coverage; catch
  sequence (pulse + wave + noise in one flow); cry via DAC; rate sweep
  7/11/22 kHz in DOSBox-X (emulation fidelity ceiling) + maintainer real-
  hardware spot-check if a dongle surfaces.
- [ ] **4. Deferred v2 (explicit non-goals).** DSS FIFO/flow-control mode
  under its own `/DISNEY` flag (decided 2026-09-18; nibble 6 reserved) — the
  FIFO section is already in `DSS_Programmers_Guide.md` §§3–6, no further
  references needed. Dithering, stereo-on-1, per-song voice tables.
  Recorded, not forgotten.

## Risks

Tick-jitter on raw writes (FIFO mode is the fix); `378h` port permission under
real DPMI hosts (0.2.1 probe retires this); LPT contention (dongle has printer
pass-through); no real-hardware reference (`disney=true` is truth); engine
audio defects stay engine-side — mixer reads post-tick state only (note OPEN
regression `regression-audio-title-screen-corruption`, unrelated to this work).

## Decision log (2026-09-18)

- Fallback: Covox explicit-only, never auto-selected; INNOVA likewise
  explicit-only. Auto-fill sets OPL or speaker only.
- Dispatch: one 4-byte nibble word (`g_audio_devices`) + `g_audio_forced`,
  music/sfx/pcm role fields, pointers solved once at init.
- v2 FIFO gets its own `/DISNEY` flag (nibble 6 reserved).
- Rate design confirmed: 7000 default, clamp 4000–44500.
- 0.1.2/0.1.3 reference fetches dropped — the manual suffices.
