# Audio Subsystem — Phase 3 Plan

Worktree: `/mnt/sdb1/Code/Active Code/pokeyellow_msdos-audio` (branch `audio`).

Status: **planned** (implementation not started; Phase 2 game loop still in progress).
This document supersedes the preliminary Gemini spitball plan (see git history of this
file for the original). Architecture decisions below were settled in a design session
on 2026-07-05 after auditing the pret audio engine, the port's existing scaffolding,
and the hardware manuals in `docs/sound/`.

## What survived from the spitball, what changed

Kept from the Gemini draft:
- 60 Hz audio tick locked to the frame loop (matches GB VBlank; the port's PIT
  already runs at ~61.17 Hz in TIMING=SGB mode and scales pitch/tempo uniformly).
- Flat pre-resolved MIDI streams for the MPU-401 path (no SMF parsing at runtime).
- The SFX overlap-vs-ducking A/B toggle.
- Fade-out implemented at the driver layer for MIDI (CC7 scaling), not baked into data.
- Python tooling parses the pret `.asm` source (macro text), not compiled bytecode.

Changed:
- **The GB audio engine is NOT replaced.** The spitball's "HAL vtable + precompiled
  streams for everything" is dropped in favor of a hybrid: the pret engine is
  translated faithfully (per project ethos, pret labels preserved) and drives a
  **virtual APU**; thin per-device shims map APU state to hardware. Only the MIDI
  path uses precompiled streams (hand-tuned MT-32 data can't be derived at runtime).
  This makes cry pitch/tempo modifiers, ducking, fades, pitch slides, and sweeps work
  for free on every shim device instead of being reimplemented per format.
- **MT-32 is the flagship** experience (custom SysEx timbres, hand-tuned mixes);
  GM is a secondary mapping of the same MIDI data. Aesthetic: same voice count as
  the GB (no re-orchestration), but with reverb, depth, and instrument character.
  SFX stay basic and get less attention.
- **SB floor is SB Pro**, not SB16 (OPL3 *or* dual-OPL2 stereo; 8-bit DSP is enough
  for the PCM cries). Keep FM voicing OPL2-compatible.
- **PC speaker added** as a fallback device: SFX only (no music), plus a PWM PCM
  player for Pikachu's cries.
- Tandy stays a minimal-effort target, but rides the same APU shim (near-1:1 PSG
  mapping) instead of a bespoke driver.

## Decision summary

| Axis | Decision |
|---|---|
| Architecture | Hybrid: faithful pret engine translation + per-device backends |
| Non-MIDI boundary | Virtual-APU register shim (engine writes rAUD*; shim → OPL3/SN76489/speaker each tick) |
| MIDI path | Precompiled 60 Hz frame-delta flat streams via MPU-401 UART |
| Flagship | MT-32 with custom SysEx timbres; GM secondary |
| Hand-tuning | Generator + declarative override files (never hand-owned `.mid`s) |
| Audition loop | DOSBox-X + MUNT (dosbox-mcp harness); host-side auditioner as accelerant |
| SB floor | SB Pro and up |
| Pikachu PCM | SB DSP when present; PC-speaker PWM fallback (blocking — authentic, the GB blocked too) |
| PC speaker | SFX-only + PCM cry player |
| Tandy | SN76489 via APU shim, minimal polish |
| SFX overlap | Runtime toggle: authentic GB ducking vs. 4 dedicated OPL3 SFX channels |
| Phasing | A: Engine+OPL → B: MIDI/MT-32 → C: Pikachu PCM → D: Tandy + speaker SFX |

---

## Source-of-truth facts (from the audit)

### pret engine (repository root — read-only spec)

- The engine is a **bytecode interpreter** ticked once per VBlank. Four near-identical
  banked copies exist (`audio/engine_1.asm` is complete — `Audio1_UpdateMusic` + all
  command handlers + pitch tables via `audio/notes.asm`; engines 2–4 differ only in
  their `SFX_Headers_N`/`MAX_SFX_ID_N` bases, plus `engine_2.asm` hosting the shared
  init/reset helpers and battle-SFX special cases). In the port, banking collapses:
  implement `Audio1_*` fully; `Audio2_PlaySound`/`Audio3_PlaySound`/`Audio4_PlaySound`
  become thin wrappers selecting their header-table base. **All pret labels kept.**
- Gateway routines live in `home/audio.asm`: `PlayMusic`, `PlaySound`,
  `PlayDefaultMusic*`, `StopAllMusic`, `GetNextMusicByte`, `UpdateMusic6Times`, etc.
  Callers communicate via `wNewSoundID`, `wAudioROMBank`, `wChannelSoundIDs`,
  `wAudioFadeOutControl/Counter`, `wFrequencyModifier`/`wTempoModifier`.
- The macro vocabulary is **small and closed** (`macros/scripts/audio.asm`):
  music — `note`, `note_type`, `rest`, `octave`, `tempo`, `duty_cycle`,
  `duty_cycle_pattern`, `vibrato`, `pitch_slide`, `toggle_perfect_pitch`, `volume`,
  `stereo_panning`, `sound_call`/`sound_loop`/`sound_ret`, `execute_music`,
  `drum_speed`, `drum_note`; SFX extras — `square_note`, `noise_note`, `pitch_sweep`.
  Headers use `channel_count`/`channel` (3 bytes per channel entry).
- **Sound IDs are positional**: ID = (header address − `SFX_Headers_N`) / 3; music,
  SFX, cries, and the 19 noise instruments share one numbering space
  (`constants/music_constants.asm` defines the boundaries). Generators must preserve
  this numbering exactly.
- 8 software channels (CHAN1–4 music, CHAN5–8 SFX) map onto the 4 hardware channels.
  **Ducking**: a music channel skips its hardware writes while the matching SFX slot
  in `wChannelSoundIDs` is non-zero; on SFX `sound_ret` the engine restores output.
- **Cries are ordinary 3-channel SFX** (pulse1/pulse2/noise) with per-species
  frequency/tempo modifiers from `data/pokemon/cries.asm` applied at runtime — they
  work for free through the translated engine + shim.
- **Pikachu's 42 digitized cries are a separate path**: `PlayPikachuSoundClip`
  (`engine/pikachu/pikachu_pcm.asm`, inner loop in `home/pikachu_cries.asm`) streams
  raw PCM through the wave-channel DAC with interrupts off, keying off each sample
  byte's high bit — effectively 1-bit playback that monopolizes the CPU. Clean `.wav`
  copies exist beside the `.pcm` sources in `audio/pikachu_cries/`.
- Inventory: 51 song files (`audio/music/`), 396 SFX files (`audio/sfx/`, of which
  26 base cries × 4 banks), 19 noise instruments, 6 wave instruments
  (`audio/wave_samples.asm`), 42 Pikachu PCM clips.

### DOS port scaffolding (`dos_port/`)

- Audio is already stubbed on the pret label surface: `src/audio/audio_stubs.asm`
  (`StopAllMusic`, `WaitForSoundToFinish`, `PlayMusic`, `PlayDefaultMusic`), plus
  stray stubs to consolidate/retire (`PlaySound` in
  `src/engine/battle/move_effect_helpers.asm`, `GetCryData` in
  `src/engine/menus/pokedex.asm`, `StopAllSounds` in `src/init/init.asm`) and
  `TODO-HW: audio HAL (Phase 3)` elision comments at call sites across menus,
  overworld, battle, and the text engine (`TX_SOUND_*` control codes).
  Stub-file contract: `WaitForSoundToFinish` must become a real spin on state the
  driver actually clears (`wChannelSoundIDs` CHAN5–8).
- **The overworld rewrite does not threaten integration**: the audio surface is the
  pret label call sites, which are stable by project convention regardless of how
  files get reorganized.
- Timing: PIT ch0 IRQ0 `tick_isr` (`boot/timing.asm`) at ~61.17 Hz; the per-frame
  pipeline is `DelayFrame` (`src/video/frame.asm`) — the audio tick hooks there,
  right after `wait_pit_tick`.
- Hardware-IRQ pattern to copy (`boot/timing.asm`, `src/input/joypad.asm`): DPMI fn
  0204h/0205h install, `[cs:isr_ds]` DS recovery, EOI `out 0x20, 0x20`, restore in
  `entry.asm:cleanup`.
- Config: `parse_cmdline` (`boot/entry.asm`) scans PSP 0x80/0x81 for `/FIXALL` etc. —
  extend for device flags. No env-var reader exists yet; `BLASTER` parsing is new
  code (PSP environment segment).
- DMA gap: the port only allocates extended memory (DPMI 0501h). SB DMA would need a
  DOS-memory buffer (DPMI 0100h, 64 KB-boundary safe). **Avoided in v1**: the DSP
  direct-output mode (command `10h`, PIT-paced) needs no DMA and blocking is
  acceptable for the PCM cries.
- Generated data goes in `.data` (orphan sections load as zeros — `link.ld` rule);
  generators follow the `tools/gen_*.py` → `assets/*.inc` → Makefile per-`.inc` rule
  → `assets:` phony pattern.

### `docs/sound/` coverage and gaps

Covered: SB DSP reset/commands/time constants/IRQ ack/mixer (CT1345 Pro, CT1745
SB16), DSP version detection (`E1h`) and OPL2-vs-OPL3 probe (read port 388h: 06h=OPL2,
00h=OPL3), `BLASTER` env conventions; MPU-401 UART mode (`$3F`, DRR/DSR status-poll
handshake, ports 330h/331h); MT-32 SysEx (DT1 `12h` ≤256 bytes, checksum
= 128 − (sum mod 128), ≥20 ms between messages, timbre memory at `08 xx xx` stride
0x200, patch memory `05 xx xx`, partial reserves — all 9 parts in one message, total
≤32, LCD display text at `20 00 00`); GM Level 1 guidelines; SMF format / running
status / meta events (in `MIDI_Specification.md`; GM instrument map is inside that
file too, ~p.144).

**To pull into `docs/sound/`:**
- OPL3 (YMF262) register-level reference — the SB manual explicitly defers to Yamaha.
  Needed for **Phase A**.
- Tandy SN76489 PSG doc (already planned). Needed for Phase D.
- Intel 8237 DMA reference — only if/when the PCM player upgrades from direct mode
  to auto-init DMA.

---

## Runtime architecture

```
game code (pret call sites: PlaySound / PlayMusic / PlayCry / …)
        │
  L1  home/audio.asm translations  ──────────────┐ (retire audio_stubs.asm
        │                                        │  routine-by-routine)
  L2  translated engine  src/audio/engine.asm    │
      (Audio1_* handlers; Audio2/3/4_PlaySound   │
       = header-base wrappers; generated         │
       bytecode blobs from assets/audio_*.inc)   │
        │ writes rAUD10–rAUD3WAVERAM             │
  L3  virtual APU  ($FF10–$FF3F in emulated GB   │
      memory at [ebp+…] + dirty flag)            │
        │ read once per tick                     │
  L4  device shims (exactly one active)          │   L5  MIDI driver (music only)
      ├─ opl_shim   OPL3 / dual-OPL2 (SB Pro+)   │       mpu401.asm: UART init,
      ├─ tandy_shim SN76489 (near-1:1)           │       flat-stream sequencer,
      └─ spk_shim   PC speaker (SFX only,        │       CC7 fade, SysEx patch
         highest-priority channel → PIT ch2)     │       upload at init
                                                 │
  L6  PCM players (Pikachu cries, blocking OK)   │
      ├─ sb_pcm.asm  DSP direct mode 10h, PIT-paced (v1); auto-init DMA later
      └─ spk_pcm.asm PWM/RealSound, PIT ch2 mode 0, cli busy-wait
```

- **Tick**: one call from `DelayFrame` immediately after `wait_pit_tick` — runs the
  engine update (`UpdateMusic`) or the MIDI sequencer step, then the active shim's
  APU→hardware pass. Matches the GB's VBlank cadence; TIMING modes scale music the
  same way they scale movement.
- **Init/shutdown**: `audio_init` called after `joypad_init` in `boot/entry.asm`;
  `audio_shutdown` added to `cleanup` (DSP reset, speaker off, MPU-401 reset,
  KEY-OFF all FM channels, restore any hooked vectors).
- **opl_shim details**: 4 GB channels → 4 FM voices (OPL2-compatible 2-op patches);
  duty cycle selects among 4 pulse-patch variants; wave channel → closest FM
  approximation of the 6 wave instruments; noise → noise-like FM patch (rhythm mode
  optional later). Stereo register writes honor `rAUDTERM`/`wStereoPanning` on
  OPL3/dual-OPL2. **Overlap toggle**: authentic mode maps CHAN5–8 onto the same 4
  voices (engine ducking behaves exactly as on GB); overlap mode gives SFX 4
  dedicated FM channels (OPL3 has 18) so music keeps playing underneath.
- **MIDI mode routing**: MT-32/GM plays music only. SFX and synth cries stay on the
  APU-shim device — OPL if a Sound Blaster is present (the classic MT-32+SB combo),
  else the PC speaker. The engine still runs in MIDI mode for SFX/cries; only its
  music channels are inhibited in favor of the stream sequencer.
- **Fades**: on shim devices, the engine's own `wAudioFadeOutControl` logic works
  untouched. On MIDI, the driver scales CC7 across a fade triggered by the same
  control variable (the Gemini `hal_fade` idea, realized inside the MPU driver).
- **Pikachu PCM routing**: `PlayPikachuSoundClip` keeps its pret label; the port
  implementation dispatches to `sb_pcm` (if DSP detected) or `spk_pcm`. Blocking
  during playback is authentic — the GB version also froze everything. Synth-cry
  substitution only when sound is fully disabled.

### Device/config matrix

Music device: `MT32 | GM | OPL | TANDY | none` × SFX device: `OPL | TANDY | SPEAKER |
none` × PCM: `SBDSP | SPEAKER | off`.

- Command-line flags (extend `parse_cmdline`): `/MT32 /GM /SB /TANDY /SPK /NOSOUND
  /SFXOVERLAP`, plus overrides like `/A240 /I5` if the `BLASTER` env is absent/wrong.
- `BLASTER` env parsing (A/I/D/M/P fields) + DSP version via command `E1h` +
  OPL2/OPL3 probe at 388h for auto-configuration.
- Defaults: `/MT32` implies SFX on SB when `BLASTER` is present, else speaker;
  bare launch with `BLASTER` set implies `/SB`.

---

## Asset pipeline & tooling (`tools/audio/`)

Two-tier rule applies throughout: every command stream, patch table, MIDI stream, and
PCM blob is **Tier-1 generated data** (`assets/audio_*.inc`, `; DO NOT EDIT BY HAND`,
wired into `make assets`, data in `.data`). Hand-tuning lives in checked-in
**override/definition source files**, never in generated output and never in
hand-owned `.mid` files (the `assets/map_overrides/` precedent).

| Tool | Role |
|---|---|
| `pret_audio.py` | Shared parser library: the closed macro grammar → per-channel IR (headers, resolved `sound_call`/`sound_loop`, note events) + a timing evaluator replicating the engine's note-delay accumulation (length × speed × tempo with fractional part). Every other tool consumes this. |
| `gen_audio_data.py` | IR → `assets/audio_*.inc`: engine bytecode blobs + header tables (positional ID numbering preserved), noise instruments, cry-modifier table (`mon_cry` records), wave samples, pitch table. |
| `gb_to_midi.py` | IR → baseline SMF type-1 `.mid` per song (3 melodic channels + noise → channel-10 drum map), with overrides applied during generation. Also satisfies the "export the soundtrack as MIDI" side-goal. |
| `overrides/*.yaml` | Per-track hand-tuning: MT-32 patch + GM program per channel, CC7 balance, pan, reverb switch, partial reserves, drum-note mapping, tempo nudges. **This is where the hand work lives; `make assets` never clobbers it.** |
| `midi_to_stream.py` | `.mid` → 60 Hz frame-delta flat stream `.inc` for the DOS driver (deltas in frames, running status pre-resolved, loop point marker; no SMF parsing at runtime). |
| `gen_mt32_patches.py` | Human-editable YAML timbre/patch definitions → SysEx blob `.inc` (DT1 chunking ≤256 bytes, Roland checksums, single partial-reserve message for all 9 parts, LCD greeting text). |
| `gen_opl_patches.py` | Hand-editable FM patch table (4 duty variants, wave approximations, noise patch) → `.inc` for the shim. |
| `gen_pika_pcm.py` | `audio/pikachu_cries/*.wav` → 8-bit unsigned resampled blobs for the DSP player + PWM duty streams for the speaker player. |
| `audition.py` | Host-side fast loop: send generated `.mid` + SysEx to an ALSA MIDI port (standalone MUNT) for patch iteration without booting DOS. End-to-end verification then goes through DOSBox-X (MPU-401 → MUNT) driven by the existing dosbox-mcp harness. |

---

## Verification strategy

1. **Bytecode fidelity (automated)**: byte-compare `gen_audio_data.py` output against
   the assembled ROM's audio banks (baserom offsets). Proves the Python parser
   produces exactly what RGBDS produces — the parser can then be trusted as the
   foundation for the MIDI tools too.
2. **Engine fidelity (debug build)**: log virtual-APU register writes per tick for a
   song/SFX and diff against an emulator trace (BGB/SameBoy). Stretch goal; the
   byte-compare plus ear-testing covers most of it.
3. **In-game**: DOSBox-X with SB Pro/SB16 emulation and MPU-401 → MUNT, driven via
   dosbox-mcp. Per-phase milestones below are the acceptance checks.
4. **Contract checks**: `WaitForSoundToFinish` spins on `wChannelSoundIDs` CHAN5–8
   and actually terminates; `audio_shutdown` leaves hardware silent (no hung FM
   voices/speaker tone after exit).

---

## Task list

- `[ ]` **Phase A — Engine + OPL (proves everything)**
  - `[x]` Pull OPL3 (YMF262) register reference into `docs/sound/` —
        `docs/sound/OPL3_YMF262.md` (Arnost guide + ModdingWiki detection/BLASTER
        sections; raw HTML mirrored in `docs/references/moddingwiki/`).
  - `[ ]` `tools/audio/pret_audio.py` parser lib + IR + timing evaluator.
  - `[ ]` `gen_audio_data.py` + ROM byte-compare test; `assets/audio_*.inc` wired
        into `make assets`.
  - `[ ]` Translate `home/audio.asm` gateway + engine (`Audio1_UpdateMusic`, all
        command handlers, `AudioN_PlaySound` wrappers, cry modifiers, fades,
        low-health alarm), writing to the virtual APU block.
  - `[ ]` Audio tick hook in `DelayFrame`; `audio_init`/`audio_shutdown` in
        `boot/entry.asm`.
  - `[ ]` `opl_shim` + `gen_opl_patches.py`; stereo via rAUDTERM; `/SFXOVERLAP` toggle.
  - `[ ]` Detection/config: `BLASTER` env parse, DSP `E1h` version, OPL2/3 probe,
        cmdline flags.
  - `[ ]` Retire audio stubs (`audio_stubs.asm` + strays); real `WaitForSoundToFinish`;
        wire text-engine `TX_SOUND_*` codes.
  - **Milestone: Pallet Town BGM + menu SFX + a Pokémon cry on OPL3 in DOSBox-X.**

- `[ ]` **Phase B — MIDI / MT-32 flagship**
  - `[ ]` `gb_to_midi.py` + `overrides/` schema + `midi_to_stream.py`.
  - `[ ]` `mpu401.asm`: UART-mode driver, flat-stream sequencer, CC7 fade.
  - `[ ]` `gen_mt32_patches.py` + init-time SysEx upload (paced, checksummed).
  - `[ ]` `audition.py` host loop; DOSBox-X + MUNT end-to-end via dosbox-mcp.
  - `[ ]` GM mapping mode (`/GM`) from the same streams/overrides.
  - **Milestone: hand-tuned Pallet Town + a battle theme on MUNT MT-32, patches
    uploading clean, LCD greeting visible.**

- `[ ]` **Phase C — Pikachu PCM**
  - `[ ]` `gen_pika_pcm.py` (WAV → DSP blob + speaker PWM stream).
  - `[ ]` `sb_pcm.asm` direct-mode player (command 10h, PIT-paced).
  - `[ ]` `spk_pcm.asm` PWM player (PIT ch2 mode 0, cli busy-wait).
  - `[ ]` Implement `PlayPikachuSoundClip` dispatch + wire call sites (status
        screen, scripts, pikachu-emotion system as those systems land).
  - **Milestone: Pikachu audible on both SB and speaker-only configs.**

- `[ ]` **Phase D — Tandy + speaker SFX + polish**
  - `[ ]` Pull SN76489 doc into `docs/sound/`; `tandy_shim`.
  - `[ ]` `spk_shim` (SFX-only, priority-channel square wave).
  - `[ ]` Options-menu stereo bits (`wOptions` MONO/EARPHONE) → rAUDTERM emulation.
  - `[ ]` Optional: upgrade `sb_pcm` to auto-init DMA (pull 8237 doc first;
        DPMI 0100h DOS-memory buffer, 64 KB-boundary safe).

## Open questions / deferred

- Exact OPL voicing for the wave channel (per-instrument FM approximations vs. one
  generic patch) — decide during Phase A patch tuning.
- Whether GM gets independent override columns or derives mechanically from the
  MT-32 overrides — decide when Phase B tuning starts.
- DMA upgrade for `sb_pcm` (only matters if a non-blocking cry is ever wanted).
- Covox/LPT-DAC output: declined for now; the APU-emu-to-PCM mixing it would need is
  out of scope for this plan.
