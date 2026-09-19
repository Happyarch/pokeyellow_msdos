# Current Plan: Game Blaster / CMS support (`/GB`, device 8)

Status: **IN BUILD (round-robin subagents, serial).** References done;
stages below run serially. `--no-verify` on commits while remote.

## Thesis

The Game Blaster (Creative CMS) is Tandy's bigger sibling: 2× Philips SAA1099,
12 square-wave voices, same APU-shim philosophy, no channel-count mismatch to
solve (unlike the SID's 4→3). It slots between Tandy and OPL3 in the lineup.
Emulator support confirmed in-tree: `sbtype=gb` forces CMS
(`sblaster.cpp:4248-4264`), `gameblaster.cpp` in
`src/hardware/Makefile.am:10`, MAME-derived CMS core (`CHANGELOG:10109`).

## Hardware facts (measured 2026-09-18 against `docs/sound/SAA1099_Philips_1984.md`)

- 2× SAA1099, 6 voices each: square tone generators (8 octaves × 256 tones,
  31 Hz–7.81 kHz at 8 MHz), 2 noise generators + 6 four-way mixers per chip,
  per-channel L/R 4-bit amplitude, 2 envelope controllers with 8 modes.
  Full Tables 2/3 in the .md §§5–6.
- **Non-square hardware voices exist** (Fig.5 rows f/h: repetitive triangle +
  sawtooth train, ≤1 kHz at 4-bit / ≤2 kHz at 3-bit, clocked by a freq gen).
  The old "duty collapses like Tandy" line below is WRONG for ch2 — see Mapping.
- Card programming (`gameblst.txt`, `docs/references/gameblst.txt`): 4-port
  scheme `2x0`–`2x3` (voices 1–6 addr `2x1`/data `2x0`, voices 7–12 addr
  `2x3`/data `2x2`); jumper bases incl. 220h default; `$1C` reset/enable;
  `$14` freq enable; `$00`–`$05` L/R amplitude; `$08`–`$0D` tone +
  `$10`–`$12` paired octaves; `$15`/`$16` noise. No IRQ/DMA (write-only PSG,
  CPU-driven). Chip address latch persists — repeat data writes need no
  re-addressing.
- Detection is REAL (not flag-only): CT-1302 latch probe — write latch at
  `2x6`/`2x7`, read back at `2xA`/`2xB`, plus port `2x4` always `$7F`
  (NetBSD `cms.4`, `docs/references/cms.4.html`; schlae reverse-engineering
  deliberately not mirrored — schematics aren't programming docs). Decide
  probe-vs-flag at build; both patterns exist in-tree.
- Clocks: datasheet nominal 8 MHz; CMS board 7.159 MHz is second-hand
  (Nerdly) — rescale rates proportionally if confirmed. No divider equations
  in the datasheet: pitch authorities are the octave table + gameblst note
  table (C=55 Hz octave, A=3 … G#=242 as printed).
- Mismatches catalogued, datasheet normative (`SAA1099_Philips_1984.md` §9.7):
  gameblst "sine" = loose word for single tone; gameblst counts 4 noise gens
  (2 chips × 2) vs 2 per chip; gameblst noise rates 28/14/6.8 kHz lack the
  `11` follow mode (datasheet 31.3/15.6/7.6 kHz + follow); envelopes absent
  from gameblst entirely.

## Mapping (measured; corrects the seedling draft)

- GB ch0/ch1 pulse → 2 SAA square voices (duty collapses — SAA squares are
  fixed shape like the SN76489, Tandy treatment).
- GB ch2 wave → envelope-driven NON-square voice (Fig.5 rows f/h: repetitive
  triangle / sawtooth train, ≤1–2 kHz), NOT plain square — the seedling
  "triangle-closest doesn't exist" line was wrong. Pitch via Fn + paired
  octave regs; amplitude via ARn/ALn (note: envelope drive halves resolution
  to 8 levels and caps active output at 7/8 of programmed amplitude).
- GB ch3 noise → SAA noise generator (`11` follow mode tracks a freq gen;
  else 31.3/15.6/7.6 kHz presets). No steal contortions — mixer channel
  selects noise-only.
- Pikachu cry: SAA has no DAC, so the speaker KEEPS its PCM field under a GB
  winner (decided 2026-09-18) — cry fallback is SB DSP, then speaker PWM,
  same as Tandy. Unlike Covox (which takes PCM and drops speaker SFX), a GB
  winner takes music+SFX only; speaker holds PCM-only.
- 8 spare voices: deliberately unused in v1. Headroom is explicitly NOT a
  defect — and it is the tier-1 enhancement budget (12 voices vs 4 needed).
  Candidate v2 technique (recorded, not designed): noise-channel simulation
  by bunching pulse channels with volume varied as sine × PRNG amplitude.
  Detuned doubling / echo stay out of scope: this is a port, not a remix.
- Envelopes in software per tick (Tandy pattern, `tandy_shim.asm:219-476`) onto
  SAA amplitude registers; SFX table (waveform/amplitude per SFX id) as
  shim-owned constants — the `tools/audio/sfx/*.yaml` OPL indices don't
  transfer (same finding as the SID draft).
- Dispatch: `DEV_CMS` = device 8, nibble 0 of `g_audio_devices2`
  (`FORCE_CMS` = bit 8 of `g_audio_forced`); explicit-only, never auto-set.
  Flag `/GB` (decided 2026-09-18; `find_token` check is stage 0.5's job
  alongside the config-device work). Solved tick slot, same as every shim;
  MIDI-coexistence guard mirroring `tandy_shim.asm:504-509`; runner appends
  the `sbtype=gb` stanza (`run-gb` + `.ps1`, run-tandy pattern).

## Device selection (decided 2026-09-18)

- 64-bit selection across two dwords: `g_audio_devices` (word 1, devices 0–7
  roles, unchanged) + `g_audio_devices2: dd` (word 2: **DEV_CMS nibble 0 =
  device 8**, DEV_DISNEY nibble 1 = device 9, rest reserved).
  `g_audio_forced` is already a full dword with only the low 8 bits used —
  `FORCE_CMS = bit 8`. No 64-bit ops needed (386 has none); init reads two
  dwords, the tick path is untouched.
- The mask costs nothing per tick (measured, not assumed): `audio_tick` is
  three blind indirect calls (`call [g_tick_shim/enh/midi]`,
  `audio_hal.asm:115-117`), unused slots point at `tick_noop`; the mask is
  read once at init (solve `:140-224`). Selection state is config/debug, not
  hot path.
- Parameters stay per-device words (`g_covox_rate` pattern: parsed once, zero
  per-tick cost) — they don't fit nibbles and don't belong in the mask.
- Explicit-only, never auto-selected; **no CT-1302 probe** (flag IS the
  detection, Tandy/Innova precedent; probe documented as a future option).
  Force priority extended: TANDY > INNOVA > COVOX > **GB** > SPK.
- Device source precedence (new, all devices): `/FLAG` command line >
  `POKEMON.CFG [audio] device` > auto-fill (OPL probe / speaker). Stage 0.5
  builds this mechanism once for every device; CMS is its first consumer.

## Stages

- [x] **0. Groundwork (references DONE 2026-09-18).** `docs/sound/`
  holds the vision-transcribed `SAA1099_Philips_1984.md` + 3 SVGs (local-only,
  gitignored); `docs/references/` holds `gameblst.txt` (UTF-8) + `cms.4.html`.
  Flag `/GB` decided; detection = flag-only, no probe (decided 2026-09-18).
- [x] **0.5. Config device + override (FIRST dispatch — shared mechanism).**
  - [x] 0.5.1 `g_audio_devices2: dd` + `FORCE_CMS` bit 8; GB between COVOX
    and SPK; `.wGb` stub arm = auto-fallback until stage 2.
  - [x] 0.5.2 `[audio] device` string parsed once at boot
    (`g_cfg_audio_device`, 0xFF=auto).
  - [x] 0.5.3 Precedence `/FLAG` > config > auto-fill, all devices; `arg_gb`
    substring-safe.
- [ ] **1. Driver `src/audio/cms_shim.asm`** (port-only HAL, no DEVIATION —
  current house rule, not the seedling's `DEVIATION{class=HAL}` line).
  - [x] 1.1 Skeleton: house-style header, `CMS_BASE 0x220` + port-pair equs,
    per-voice state, six globals. No DEVIATION. `ENABLE_AUDIO_CMS` guard.
  - [x] 1.2 Tick pass: ch0/ch1 → square v1/v2 (duty collapses); ch2 → v3
    envelope triangle (Fig.5 row f, $18 fixed at init); ch3 → v4 noise
    presets (normative Table 3 over `11`-follow `[?]`); GB-unit
    envelope/sweep/length; restart-consume; NR50 master; NR51 mute; MIDI
    SFX-only guard (tandy shape); §9.2 bring-up; repeat-write elision via
    `cms_wreg`. Known limit: wave notes above ~1 kHz envelope ceiling
    flatten in HW — 1.3 tuner item.
  - [x] 1.3 `cms_silence` (SE=0 + FE/NE off + six amps zeroed, caches
    synced, KEY stays — tandy shape) + `cms_commit_se` SE restore +
    shutdown tail-jump; pre-clip hook-in recorded (after `covox_silence`,
    pikachu_pcm:90-91, stage-2 wiring); snapshot +0x89..+0x8C (verified
    free, byte map in header; window extension is stage 2/3). Tuner
    cross-check: DISCREPANCY vs gameblst note table (divider law, opposite
    curvature; octave split at 62 Hz) — recorded, map unchanged, ear
    stage decides.
  - Acceptance: nasm clean both guard modes, lint 0, silence is silent,
    tuner-verified pitch per voice.
- [x] **2. Dispatch + runner.**
  - [x] 2.1 Device-8 solve arm (`cms_init` + word-2 role nibble music+sfx,
    no PCM; speaker keeps PCM-only). `cms_shutdown` in shutdown path.
  - [x] 2.2 `/GB` end-to-end verified (flag → bit 8 → arm → init → tick).
    Config `device 8` lands on the same arm.
  - [x] 2.3 MIDI-coexistence verified (1.2 guard correct, tandy shape).
  - [x] 2.4 `run-gb` (+`.ps1`, +x): `/GB`, `sbtype=gb`, `oplmode=none`,
    speaker on (PCM cry fallback live; no DSP under `sbtype=gb`).
  - Acceptance (static traces walked): `/GB` alone → CMS music+SFX;
    `/GB`+`/TANDY` → TANDY wins; `/GB`+`/MT32` → MIDI music + CMS SFX.
  - Follow-ups landed: `ENABLE_AUDIO_CMS` passthrough, window-9 CMS bytes
    (+0x89..8C, file 0x23C..0x23F; MIDI +0x49..4C joins undumped head),
    stale 0.5 comments repaired.
- [ ] **3. Verification + ear-checks (static DONE, ears maintainer-run).**
  - [x] 3.0 Static: 5 traces re-walked (stub combo silent-no-hang, default
    dark; speaker PCM present under GB winner, absent from CMS nibble);
    37/37 nasm matrix; lint 0, no new tokens; runner diff = swaps only,
    keys pinned, `bash -n` clean; snapshot map (CMS file `0x23C..0x23F`,
    neighbors recorded).
  - [ ] 3.1 Cold boot `run-gb` → CMS music (snapshot `0x23C` tells init
    from keying failures).
  - [ ] 3.2 Catch sequence (squares + envelope-triangle bass + preset noise).
  - [ ] 3.3 Noise-heavy battle (no stuck noise after).
  - [ ] 3.4 Pikachu cry via speaker PWM (`pika_dbg_device=2`; never 3 here).
  - [ ] 3.5 Tuner spot-checks (divider-law discrepancy: D3 vs D#3 split,
    chromatic A→G# curvature) + ceiling check (wave flattens above ~1 kHz).
- [ ] **4. Gates.** `lint_pret_labels` 0, `static_gate` clean, fidelity green
  with byte-identical `GBSTATE.BIN` (output-only — assert it).

## Risks

Near-zero structural risk (closest existing-shape build after Tandy itself);
main risk is underwhelming differentiation vs Tandy+OPL3 (say so in the final
spec — the defense is period-completeness, not sound).
