# Current Plan: Innovation SSI-2001 (SID) support

Status: **DRAFT FOR REVIEW** — written 2026-09-12. No sequencing constraint
stated; suggested after the Tandy path is stable since the SID driver mirrors
its structure. Re-verify file:line claims against HEAD at build time.

## Why this is cheap (thesis)

- Pinned DOSBox-X emulates it: `[innova]` (`innova=false`, `samplerate=22050`,
  `sidbase=280`, `quality=0`, `dosbox-x.reference.full.conf:2044-2055`);
  DOSBox-X sound guide confirms the `[innova]` section. Config-only, like IMFC.
- Tandy proved the pattern: a near-1:1 APU shim with music+SFX voiced together,
  no per-song files, no enhancements/overrides. SID follows it — one new shim
  file, one flag, one dispatch arm.
- SFX routing is settled by precedent, twice over: Tandy voices music+SFX on the
  PSG (`tandy_pass`, `tandy_shim.asm:151-213`); MIDI mode keeps SFX on OPL while
  music rides the stream (`mpu401.asm:10-16`). **SID carries music+SFX; the
  speaker carries only the PCM cry fallback** (`pikachu_pcm.asm:83-94`). Routing
  SFX to the speaker would collapse wave+noise+two pulses into one 1-bit beep
  (`spk_shim.asm:3-7`) — a downgrade, not a simplification.

## Hardware facts (hound, 2026-09-12)

- 1989, Innovation Computer Corp: one MOS 6581 SID + game port + mono RCA.
  32 I/O ports with SID registers directly on the ISA bus. Base `0x280` default,
  jumpers `2A0/2C0/2E0`. Card clocks the SID at **~0.89 MHz** (not the C64's
  ~1 MHz) — the driver's freq-word constant must use the card clock.
- SID map (29 usable, base+`0x00-0x1C`): 7 regs/voice (freq lo/hi, pulse-width
  lo/hi, control, AD, SR) + filter cutoff/resonance/routing + mode/volume.
  Detection: effectively write-only → **flag IS the detection**, exactly like
  Tandy (`tandy_shim.asm:29-31`).

## Channel mapping (decided: Tandy philosophy, SID specifics)

- ch0/ch1 pulse → V1/V2 pulse waveform; GB duty maps onto the 12-bit pulse
  width (cleaner than Tandy's fixed 50%).
- ch2 wave → V3 triangle at pitch, volume from NR32.
- Envelopes: no per-voice volume register on the SID → ride the Sustain nibble
  per tick from GB `envvol` (gate stays on; Attack/Decay/Release 0). No
  re-trigger clicks.

## Noise handling — IN CONSIDERATION, not decided

The SID has 3 voices for 4 GB channels and noise consumes a whole voice. Two
options explored, neither adopted:

- **(a) V3-steal.** Noise preempts V3 (save state, rewrite control reg, restore
  on note-off). Precedent: every C64 drums+bass game. Upside: no new driver
  path, no blocking, transients are tens of ms. Psychoacoustic masking argues
  the bass gap is inaudible under the hit, but that is reasoning, not
  measurement.
- **(b) Speaker-noise.** Route noise to the PC speaker. Downside, measured from
  the tree: real noise needs kHz bit-banging with interrupts off (the
  `spk_pcm.asm` PWM shape) — drum hits would freeze gameplay; 60 Hz-tick
  updates aren't noise but buzz; 1-bit timbre mismatches the SID mix;
  double-books the cry channel.
- **Deciding measurement (proposed, not run):** per-song overlap stats from
  `gb_to_midi.simulate_song` — fraction of noise-on frames overlapping a
  sounding wave note + overlap duration distribution. If collisions are
  rare/short, (a) is confirmed with data; if a theme rides constant noise over
  legato bass, that song gets a documented arranger exception, not a driver
  complication. Also to verify by ear: the steal transition click behavior with
  Release 0.

## Stages

- [ ] **0. Preconditions.** `/SID` flag name checked against `find_token`
  substring behavior in `boot/entry.asm`; `docs/sound/` SID register + SSI-2001
  port reference mirrored; claims in this file re-verified against HEAD.
- [ ] **1. Driver `src/audio/sid_shim.asm`** (port-only HAL,
  `DEVIATION{class=HAL}` header): `SID_BASE 0x280` hardcoded (Tandy hardcodes
  `0xC0` — recommend same, no `/SIDBASE=`); `sid_write`; `sid_setfreq` with
  card-clock constant; duty→pulse-width map; sustain-riding envelope;
  length/sweep per the Tandy/OPL software pattern; noise path per whichever
  option "Noise handling" resolves to; `sid_silence` + hook into
  `pikachu_pcm.asm:78-81` pre-clip cut; self-guard `g_sid_on`.
- [ ] **2. Dispatch.** `g_shim_device=4`; `audio_hal.asm` init + one `audio_tick`
  arm (`.tandy` shape); `entry.asm` `/SID` parse with stated precedence if
  combined with `/TANDY`; MIDI-coexistence guard mirroring
  `tandy_shim.asm:504-509` (SFX-only voicing under a MIDI stream — 3 lines,
  free).
- [ ] **3. SFX table.** SID waveform/ADSR per SFX id. `tools/audio/sfx/*.yaml` +
  `gen_sfx_data.py` emit OPL patch indices, meaningless to the SID —
  shim-owned constants recommended (20-odd entries, no regen machinery). This is
  driver data, not song enhancements; the "no enhancements or overrides" call
  stands.
- [ ] **4. Runners.** `run-sid` (+`.ps1`): `sbtype=none, oplmode=none`,
  `[innova] innova=true`, speaker left enabled for the PCM cry; `DEBUG_AUDIO
  TRACK=... /LOOP` unchanged.
- [ ] **5. Gates.** `lint_pret_labels` 0, `static_gate` clean, fidelity green
  with byte-identical `GBSTATE.BIN` (engine untouched — assert it); in-DOS ear
  check: music, a noise-heavy battle (whichever noise option), Pikachu cry
  fallback with no SB.

## Risks

Steal-transition clicks (verify by ear); card-clock pitch constant (verify by
ear against a known pitch — tuner or A/B with OPL); no real-hardware reference
— DOSBox-X `[innova]` is the truth; host-side SID audition deferred (in-DOS
`/LOOP` is the reference from day one, same as Tandy).
