# Current Plan: Innovation SSI-2001 (SID) support

Status: **APPROVED FOR BUILD on `experimental-audio-devices`** — revised
with first-hand datasheet intel (vision transcription + machine-checked
tables). Tandy-stability sequencing is moot (Tandy stable since build; SID is
branch-isolated). Move fast outside master; `--no-verify` on commits while
remote. File:line claims re-verify against HEAD at build time.

Numbering: stages are `N`, substeps are `N.N` — one scheme, no NX mixes.

## Why this is cheap (thesis)

- Pinned DOSBox-X emulates it: `[innova]` (`innova=false`, `samplerate=22050`,
  `sidbase=280`, `quality=0`, `dosbox-x.reference.full.conf:2044-2055`).
  Config-only, like IMFC.
- Tandy proved the pattern: near-1:1 APU shim, music+SFX voiced together, no
  per-song files, no enhancements/overrides. SID follows it — one shim file,
  one flag, one dispatch arm.
- **SID carries music+SFX; the speaker carries only the PCM cry fallback**
  (`pikachu_pcm.asm:83-94`). Settled twice over, not re-litigated.

## Hardware facts (measured)

Chip claims first-hand from `docs/sound/MOS_6581_SID_Nov_1981.pdf` via
`MOS_6581_SID_Nov_1981_VISION.txt` (Appendix A machine-checked). Card claims
from the nerdlypleasures mirror + AmiBay corroboration. Full detail lives in
`docs/sound/`; this section is the load-bearing subset:

- 1989 Innovation Computer Corp: one MOS 6581 + game port + mono RCA. 32 I/O
  ports, SID regs on the ISA bus. Bases `0x280` (default) / `2A0` / `2C0` /
  `2E0`. Card clock **14.31818/16 = 0.89488625 MHz**. No original Innovation
  manual survives (confirmed gap); VOGONS primaries deferred.
- Table 1: **29 regs `$00–$1C`**; `$00–$18` write-only, `$19–$1C` read-only.
  Voice stride 7. Control bit7→0: **NOISE PULSE SAW TRI TEST RING SYNC GATE**.
  The `$1C`-vs-`$1D` dissenter is moot — the driver never writes past `$18`.
- Driver is **write-only `$00–$18`**: POT regs useless on-card (pins
  unconnected), OSC3/ENV3 have no shim use. **Flag IS the detection**
  (write-only, like Tandy).
- `Fn = Fout × 18.7478755` (A4 = `$2039`). Appendix A tables are 1.0 MHz —
  never reuse; printed Fn wobbles ±1 LSB (D6# +8), use printed values only as
  cross-check.
- `PWout = PWn/40.95 %`; 2048 = square. Table 2 rates scale by **1 MHz/Ø2**
  (datasheet rule) → ~1.12× on-card.
- **Noise lock-up is silicon-real**: waveforms AND; noise + anything wedges
  until TEST pulse (RES pin unavailable on ISA). Driver rule: single-waveform
  control bytes only.
- Filter OFF v1 (`$18` = mode 0 + volume). Banked: `FCout = (30 + FCn×5.8)`
  Hz at 2200 pF, BP 6 dB/oct, modes additive, FILTEX = pin 26, 3OFF = bit 7.
- Emulator pitch risk retired (pinned tree `SID_FREQ 894886` = card clock);
  ear-verify anyway. ISA timing no constraint (Tacc 300 ns). Bring-up: zero
  `$00–$18`, params, `$18`, gate last.

## Channel mapping (decided)

- ch0/ch1 pulse → V1/V2 pulse; GB duty → 12-bit PW. ch2 wave → V3 triangle,
  volume from NR32.
- Sustain-riding from GB `envvol` (gate on; A/D/R 0). `$18` volume nibble
  mirrors NR50 (fallback fixed `$F` if awkward at build).
- No per-song files, no enhancements/overrides. SFX table = shim-owned
  constants.

## Noise handling (decided: V3-steal default, song-checked)

Maintainer ear: noise is rare; V3 drops when ch4 fires — uniform rule, no
per-song exceptions (the 0.3 metric exceptions were dropped by maintainer
decision). Mechanics: save V3 `$0E–$14`, noise control + ADSR, restore on
note-off, TEST pulse on release, ear-check transitions at Release 0.
Speaker-noise rejected (standing downsides).

## House style + annotation ruling (maintainer decisions)

- `innova_shim.asm` follows the device-shim house style (`tandy_shim.asm:1-60`
  template): mapping table + software-emulation list header, `gb_memmap.inc`,
  `section .text`, port/clock `equ`s, per-voice state `equ`s,
  `innova_init/pass/silence/shutdown/dbg_snapshot` + `g_innova_on`, NRx4-restart
  consume, virtual APU `[ebp+$FF10..$FF26]`, absent-hardware → silence.
- **No DEVIATION annotation on any port-only file** (`innova_shim` ships with the
  `audio_hal`-style `Port-only module (no pret counterpart...)` header only).
  The four existing HAL DEVIATION headers (opl/tandy/spk/mpu401) and the
  cms/gus/imfc draft wording are known-inconsistent legacy — left alone, not
  precedent.

## Stages

- [x] **0.1. References mirrored.** PDFs, VISION.txt, SVGs, HTML mirrors,
  index rows. Done.
- [x] **0.2. Preconditions (read-only, remote-safe).**
  - [x] 0.2.1 `/INNOVA` flag: `find_token` is plain substring search
    (entry.asm); `/INNOVA` collides with no existing token. Precedence
    decided: TANDY > INNOVA > SPK — `/INNOVA` fills-if-unset between the `/TANDY`
    force and the `/SPK` fill; needs a new `arg_innova`
    string.
  - [x] 0.2.2 Cited file:lines re-verified; drift corrected: mpu401 seq
    entries are 234/339/370 (not 205-369), snapshot at 486+ (not 415-429);
    vblank audio block is 203-206; spk_shim 1-bit case is 6-12. Rest confirm:
    tandy 29-31, pass at 151, guard cmp at 506 (inside cited 504-509);
    mpu401 detect 72 + absent-fallback 97-100 + upload 168; audio_hal
    67-95/97-133; entry 331-345; pikachu_pcm 78-81.
  - [x] 0.2.3 `g_shim_device=4` is free (0 none, 1 OPL, 2 SN76489, 3
    speaker; audio_hal.asm:75-82,161); stage 2 adds the 4th tick arm plus
    init/shutdown calls.
  - [x] 0.2.4 agy REVIEW.txt reconciled (22 items into VISION.txt): row 93
    59056/E6B0, row 18 776/0308, B7 asterisk 17-bit values, Tc typical 500,
    A4 decoder bypass, stacked FILT labels, print typos restored as printed.
    No .md impact (distillations already correct).
- [x] **0.3. Noise song-check (host-side, remote-safe).**
  - [x] 0.3.1 `simulate_song` overlap stats over all 49 base songs (script
    at `/tmp/opencode/noise_overlap.py`; victim = min-overlap pitched
    channel, tie-break V3>V2>V1).
  - [x] 0.3.2 V3 across the board (maintainer decision): 33 songs use no
    noise at all and 13 of 16 noise songs minimize dropout on V3; the three
    metric exceptions (Dungeon1→V2 thin margin, Lavender→V1 with
    lead-salience caveat, YellowUnusedSong→V1) are dropped for one uniform
    rule — no per-song steal table in the driver.
  - [x] 0.3.3 Table recorded here. Acceptance met: every base song steals
    V3 (49 × V3, uniform).
- [x] **1. Driver `src/audio/innova_shim.asm`.**
  - [x] 1.1 Skeleton: house-style header, equs (`INNOVA_BASE 0x280`,
    card-clock const), per-voice state, six globals. No DEVIATION.
  - [x] 1.2 `innova_write` (blind OUTs; no pacing needed).
  - [x] 1.3 `innova_setfreq` (×18.7478755, hi/lo split, clamp).
  - [x] 1.4 Tick pass: virtual-APU read; V1/V2 pulse + duty→PW; V3 triangle
    + NR32; sustain-riding; NR50→VOL; restart-consume; length/sweep
    (Tandy/OPL pattern).
  - [x] 1.5 V3-steal per 0.3 table: save/restore `$0E–$14`, TEST pulse on
    release, single-waveform invariant.
  - [x] 1.6 `innova_silence` (zero `$00–$18`) + `pikachu_pcm` pre-clip hook +
    `g_innova_on` guards.
  - [x] 1.7 `innova_dbg_snapshot` (mpu401 shape).
  - Acceptance: nasm clean, lint 0, silence is silent, one note per voice at
    tuner-verified pitch.
- [x] **2. Dispatch.**
  - [x] 2.1 `g_shim_device=4`: `audio_hal.asm` init + one `audio_tick` arm
    (`.tandy` shape). Done in-tree (externs + `.innova` tick/init/shutdown).
  - [x] 2.2 `/INNOVA` parse + 0.2.1 precedence rule. Done in-tree (`arg_innova`,
    TANDY > INNOVA > SPK force priority). Explicit-only since 2026-09-18
    (never auto-selected — see `current_plan_covox.md` Device selection).
  - [x] 2.3 MIDI-coexistence guard (tandy shape: SFX-only voicing under
    `g_midi_music`, incl. steal entry/tick handling). Done in-tree.
  - [ ] 2.3 MIDI-coexistence guard (tandy 504-509 shape: SFX-only under a
    MIDI stream).
  - Acceptance: `/INNOVA` alone → SID music+SFX; `/INNOVA`+`/TANDY` → documented
    winner; `/INNOVA`+`/MT32` → MIDI music + SID SFX.
- [x] **3. SFX table.**
  - [x] 3.1 Enumerated 31 SFX yamls, cross-checked vs `sfxheaders*.asm`
    (31/31 match): 16 noise-driven (ch8 → V3-steal), 15 pitched-only.
  - [x] 3.2 No per-id table needed (audited): pitched rides the live mapping,
    steal latches live NR42/43/41, yaml vol/patch columns are OPL-mixer-only,
    ids repeat across banks (no bank key). Audit table lives as a header
    comment in `innova_shim.asm`; `sfx_data.inc`/generator untouched.
  - [x] 3.3 Ear-check list recorded (catch sequence covers pulse+steal+wave;
    battle for transitions). In-DOS, maintainer-run.
  - Acceptance: every SFX audible and recognizable; no combined-waveform
    byte escapes (lock-up rule holds).
- [ ] **4. Runners.**
  - [ ] 4.1 `run-innova` (+`.ps1`): `sbtype=none, oplmode=none`, `[innova]
    innova=true`, speaker on for PCM cry.
  - [ ] 4.2 `DEBUG_AUDIO TRACK=... /LOOP` smoke.
  - Acceptance: cold DOSBox-X boot to music with the pinned conf.
- [ ] **5. Gates + acceptance.**
  - [ ] 5.1 `lint_pret_labels` 0, `static_gate` clean (gate before master
    merge; `--no-verify` while remote).
  - [ ] 5.2 Fidelity green, `GBSTATE.BIN` byte-identical (engine untouched —
    assert).
  - [ ] 5.3 Ear checklist: music set, noise-heavy battle, Pikachu cry with
    no SB, A4 tuner check.
  - [ ] 5.4 Master-merge needs maintainer sign-off; VOGONS gap stays
    deferred.

## Build-flag convention (matches the other-shim ifdef pass)

- Makefile `Audio device / data inclusion flags` block: `ENABLE_AUDIO_INNOVA`,
  `ENABLE_AUDIO_OPL`, `ENABLE_AUDIO_SPK` added alongside the existing
  `ENABLE_PIKA_PCM` / `ENABLE_AUDIO_MIDI` / `ENABLE_AUDIO_OPL_ENH` /
  `ENABLE_AUDIO_TANDY`, each `?= 1` with a matching
  `NASMFLAGS += -D ENABLE_...=$(ENABLE_...)` line. `0` builds the stub.
- Shim guard shape (tandy/mpu401 pattern): `%ifndef ENABLE_AUDIO_X` /
  `%define ENABLE_AUDIO_X 1` / `%if ENABLE_AUDIO_X != 0` wrapping the full
  driver, `%else` providing `ret`-only entry points plus a zeroed
  `g_*_on`/`g_*_present` byte so `audio_hal` links unchanged. Applies to
  `innova_shim.asm` (`ENABLE_AUDIO_INNOVA`), `opl_shim.asm`
  (`ENABLE_AUDIO_OPL`), `spk_shim.asm` (`ENABLE_AUDIO_SPK`).
- `AUDIO_SRCS` lists `src/audio/innova_shim.asm` with the other shims; no
  asset dep (duty/sustain tables are inline consts, not generated blobs).

## Risks

Steal-transition clicks (ear-check); TEST-hygiene bug class (invisible in
DOSBox-X if reSID doesn't model lock-up — real-silicon-only, mitigated by
the single-waveform rule); no real-hardware reference (`[innova]` is truth);
agy review pending (folds in as corrections); host-side audition deferred,
in-DOS `/LOOP` is the reference from day one.

(End of file)
