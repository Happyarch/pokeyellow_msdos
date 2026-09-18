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

- [x] **0a. References mirrored (2026-09-18, branch `experimental-audio-devices`).**
  `docs/sound/MOS_6581_SID_Nov_1981.pdf` (6502.org, 19pp, preferred over the
  archive.org copy) + `docs/sound/C64_PRG_Ch4_Programming_Sound.pdf` (Ch.4, 26pp),
  both gitignored/ARR local-only; committed mirrors
  `docs/references/nerdlypleasures/SID_and_DOS_-_Nerdly_Pleasures.html` +
  `docs/references/c64wiki/SID_-_C64-Wiki.html` + notes
  `docs/references/amibay/SSI-2001-replica-notes.md`; index rows in
  `docs/references/README.md`. Patent dropped (not useful); full-book fallback
  excised to sound-section only; replica schematics excluded (not a programming
  manual); VOGONS primaries deferred.
  Derivatives follow the one-.md-per-doc convention: `MOS_6581_SID_Nov_1981.md`
  (189 lines) + `C64_PRG_Ch4_Programming_Sound.md` (136 lines) +
  `SID_SSI-2001_Notes.md` (93 lines) + `sid_voice_filter_path.svg` +
  `sid_isa_port_map.svg`, all in gitignored `docs/sound/`.
- [ ] **0b. Preconditions.** `/SID` flag name checked against `find_token`
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

Steal-transition clicks (ear-check); TEST-hygiene bug class (invisible in
DOSBox-X if reSID doesn't model lock-up — real-silicon-only, mitigated by
the single-waveform rule); no real-hardware reference (`[innova]` is truth);
agy review pending (folds in as corrections); host-side audition deferred,
in-DOS `/LOOP` is the reference from day one.

(End of file)
