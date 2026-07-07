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
  GM is a secondary mapping of the same MIDI data. Baseline aesthetic: same voice
  count as the GB (no re-orchestration), but with reverb, depth, and instrument
  character. SFX stay basic and get less attention.
  *Amended 2026-07-06*: an optional **additive enhancement layer** (Phase E, the
  LLM-assisted arranger — see `docs/llm_arranger_design_notes.md`) can add tiered
  extra channels per song on top of that baseline. The base 4 GB channels remain
  untouchable; unenhanced songs keep the baseline aesthetic.
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
| Music enhancement | LLM-assisted **additive** arrangement layer (tiered YAML, floor-up OPL3→MT-32); base 4 GB channels untouchable — see Phase E |
| Phasing | A: Engine+OPL → B: MIDI/MT-32 → C: Pikachu PCM → D: Tandy + speaker SFX → E: LLM arranger (E depends only on B; C/D can interleave) |

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
| `music_analysis.py` *(Phase E)* | Deterministic pre-LLM analysis over the `pret_audio.py` IR: key estimation, chord progression, phrase boundaries, cadences, repeated motifs (orchestrate-once tagging), melodic contour, rhythmic density. |
| `enhancements/*.yaml` *(Phase E)* | Per-song **additive** arrangement channels, tier-tagged (1 = OPL3+MT-32, 2–3 = MT-32/GM only), musical positions (measure/beat/duration — never frame deltas), explicit per-target patch fields. Hand-crafted or LLM-drafted; always human-auditioned. Never clobbered by `make assets`. |
| `yaml_lint.py` *(Phase E)* | Structural validation of enhancement YAML before audition: notes in declared range, valid beat/measure refs, per-tick voice count within target polyphony, no unison-doubling of the base melody, patch fields present for the entry's tier. |

---

## Phase E — LLM music arranger (additive enhancement layer)

Full design record: `docs/llm_arranger_design_notes.md` (multi-model design review,
2026-07-06). This section records the *decisions*; the notes hold the rationale.

**What it is**: an LLM acts as a music-theory assistant that drafts extra
orchestration channels per song as **declarative YAML** — never binary MIDI, never
bytecode, never edits to authoritative assets. Deterministic Python owns all timing,
merging, tier filtering, and polyphony management. A human auditions every change by
ear; there is no auto-acceptance.

**Compatibility with Phases A–D (verified 2026-07-06)**: nothing already built
changes. `pret_audio.py` is the arranger's input (its IR + timing evaluator feed
`music_analysis.py`); `gen_audio_data.py`/`audio_rom.inc` stay byte-exact and
authoritative for the base 4 channels; the translated engine + virtual APU still
drives the base channels on every shim device. Enhancements are additive layers on
top, at the tool level and at the driver level.

**Tiers (designed from the floor up — §5 of the notes)**:

| Tier | Designed/auditioned on | Plays on | Example |
|------|------------------------|----------|---------|
| 1 | OPL3 (emulation) | OPL3 + MT-32/GM | Bass reinforcement, core harmony |
| 2 | MT-32 (MUNT) | MT-32/GM only | String pads, reverb-heavy parts |
| 3 | MT-32 (MUNT) | MT-32/GM only | Color flourishes, choir, synth leads |
| — | — | Tandy/speaker | Base 4 GB channels only |

Tier 1 is authored against the more constrained hardware and cascades *up* to MT-32
for free; tiers 2–3 exploit LA-synthesis capabilities with no FM equivalent and never
cascade down. The compiler drops lowest-tier channels first when a target's polyphony
is exceeded (whole-layer removal in v1; chord thinning deferred).

**Settled decisions** (answers to the notes' §7 open questions):

1. Integrated here as **Phase E** (this section + task list), not a separate doc;
   the notes file remains the design rationale record.
2. Phase E starts **after Phase B** — it builds on `gb_to_midi.py` and
   `midi_to_stream.py`. Phases C/D are independent and may interleave.
3. `music_analysis.py` lives in **`tools/audio/`** with the rest of the pipeline.
4. **OPL3 tier-1 playback ships in Phase E** (not A): a small frame-delta stream
   player drives the enhancement voices on spare FM channels (OPL3 has 18; the
   shim uses 4 + 4 with `/SFXOVERLAP`, leaving ~10) alongside — not instead of —
   the faithful APU shim. Phase A's shim is unchanged.
5. **Explicit per-target patch fields** in the YAML: tier-1 entries carry
   `opl_patch` + `mt32_patch` + `gm_program`; tier 2–3 entries carry MT-32/GM
   fields only. `yaml_lint.py` enforces this. No auto-mapping table.

**Method locked in from the review consensus**: musical positions
(measure/beat/duration), never frame deltas, in anything the LLM touches;
deterministic analysis *before* the LLM (its job is "given this harmonic structure,
add orchestration"); repeated motifs orchestrated once and duplicated by the
compiler; the first song's enhancement YAML is **hand-crafted by ear before any LLM
involvement** — it proves the format end-to-end and becomes the few-shot example.
Rejected: importance vectors, LLM confidence scores, edit-operation diffs,
separate harmony/orchestration passes (rationale in the notes, §2–3).

**Skills**: three project skills — `music-theory` (standalone, ≤500-line SKILL.md +
references distilled from Open Music Theory, CC BY-SA), `audio-enhance-opl3`
(tier-1 pass), `audio-enhance-mt32` (tier 2–3 pass; must read existing tier-1
entries first). They live in `.claude/skills/` (the project's skill location; the
notes' `.agents/skills/` path is superseded). Textbook prep: extract the ~20
relevant Open Music Theory files, strip figures/exercises/frontmatter, distill via
the two-model workflow (Gemini distills, Claude writes the skill files).

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
  - `[x]` `tools/audio/pret_audio.py` parser lib + IR + timing evaluator —
        byte-exact: 45,174 bytes across banks 02/08/1F/20, 0 mismatches vs the
        golden ROM (build a pristine merge-base worktree for it; repo root no
        longer links as a GB ROM due to the port's WRAM enlargements).
  - `[x]` `gen_audio_data.py` + ROM byte-compare test (`test_audio_data.py`:
        sha1 + bank images + section extents + CryData + cross-bank SFX ID
        parity, all green); emits `assets/audio_rom.inc` (4×16 KB bank images
        at true GB addresses), `audio_constants.inc` (positional IDs +
        boundaries + vendored table addresses), `cry_data.inc`; wired into
        `make assets`.
  - `[x]` Translate `home/audio.asm` gateway + engine (`Audio1_UpdateMusic`, all
        command handlers, `AudioN_PlaySound` wrappers, cry modifiers, fades,
        low-health alarm), writing to the virtual APU block — commit `52d57448`.
        Pret's four PlaySound copies unified as `AudioCommon_PlaySound` with
        per-engine param blocks; audio_stubs.asm + stray PlaySound stub retired;
        the wrong nominal `MUSIC_MEET_*` placeholders replaced by the generated
        constants. **PlaySound is gated on `g_audio_engine_online` (0) until the
        tick hook lands — the next task must set it in `audio_init`** (without
        the tick, a started sound never ends and `WaitForSoundToFinish` would
        spin forever; it pumps `DelayFrame` per iteration). Not yet translated
        (ride along with later tasks): `PlayCry`/`GetCryData` (data is in
        `CryData` already; stub in pokedex.asm), `PlayTrainerMusic`
        (home/trainers.asm), `StopMusic` (home/overworld.asm), real
        `StopAllSounds` (ret-stub in init.asm).
  - `[x]` Audio tick hook in `DelayFrame` (order per pret home/vblank.asm:
        `FadeOutAudio` → `Music_DoLowHealthAlarm` → `Audio1_UpdateMusic` →
        shim pass); `audio_init` (sets `g_audio_engine_online`)/`audio_shutdown`
        in `boot/entry.asm` — `src/audio/audio_hal.asm`; real `StopAllSounds`
        in init.asm (pret home/init.asm body). **Engine verified live** via the
        new `DEBUG_AUDIO` gate: 120 ticks of Pallet Town BGM through the real
        gateway produce byte-correct engine RAM + virtual APU state (ids $BA on
        CHAN1-3, tempo $00A0, note speeds 12, duty $80, envelopes matching
        channel volumes, NRx4 restart bits held for the shim, wave RAM loaded,
        rAUDTERM $77 from the mono panning row).
  - `[x]` `opl_shim` + `gen_opl_patches.py`; stereo via rAUDTERM —
        `src/audio/opl_shim.asm`: per-tick APU→FM mirror on OPL voices 0-3
        (duty→patch variants, software GB envelope/sweep/length emulation,
        NR50 master att incl. fades, NR51→OPL3 C0 pan + TL mute, NRx4 restart
        consumption); AdLib detect + OPL2/OPL3 probe at 388h in `opl_init`.
        Patches/att tables are Tier-1 (`assets/opl_patches.inc`; hand-tune the
        PATCHES dict in the generator). Verified headless via `DEBUG_AUDIO`
        (now the audible milestone demo: BGM → menu blip duck → cry → BGM):
        OPL3 detected, voices keyed, B0/TL values math-checked, SFX lifecycle
        clean. **`/SFXOVERLAP` deferred**: overlap mode needs a per-class APU
        shadow + duck bypass in the engine (SFX writes land in the same 4 APU
        registers as music, so dedicated SFX voices need the engine to write
        two shadows) — rides with the config/flags task or later polish.
  - `[x]` Detection/config: `BLASTER` env parse (A/I/D fields →
        `g_sb_base/irq/dma`), DSP reset + `E1h` version probe (bounded polls;
        recorded for the Phase C PCM player), OPL2/3 probe (in `opl_init`,
        task 6), `/NOSOUND` cmdline flag (skips probes, engine stays offline).
        Fixed a latent DPMI bug on the way: `INT 21h AH=62h` returns a PSP
        *selector* under a DPMI host (and the env pointer at PSP+2Ch is also a
        selector) — new `seg_to_flat` helper (boot/entry.asm, DPMI 0006h with
        raw-segment fallback) now used by both the env parse and the existing
        `/FIXALL` cmdline scan, which had the same bug. Verified in DOSBox-X:
        BLASTER=A220 I7 D1 parsed, DSP 4.05 detected, OPL3 found.
        Device-select flags (`/MT32 /GM /SB /TANDY /SPK /SFXOVERLAP`, `/A… /I…`
        overrides) deferred to the phases that add those devices.
  - `[~]` Retire audio stubs — DONE for `audio_stubs.asm` (deleted; all four
        routines are real now), the stray `PlaySound` stub, and the real
        `WaitForSoundToFinish` (spins on CHAN5/6/8, pumps `DelayFrame`).
        **Deferred per user**: the call-site sweep (un-eliding `TODO-HW` audio
        calls incl. `TX_SOUND_*` text codes, map-music on `EnterMap`,
        `PlayDefaultMusic` in the overworld loop) — it would collide with
        master's in-flight overworld rewrite. Until then normal gameplay is
        mostly silent by omission (a few live SFX call sites already sound);
        the `DEBUG_AUDIO` build is the audible demo.
  - **Milestone: Pallet Town BGM + menu SFX + a Pokémon cry on OPL3 in
    DOSBox-X — REACHED (state-verified headless 2026-07-06; audible via
    `dos_port/run DEBUG_AUDIO=1`: ~5 s BGM → menu blip duck → Nidoran cry →
    BGM, then auto-exit). User audition 2026-07-06: "a little harsh and
    grating, but musically accurate" — timbre tuning deferred; when picking
    it up, soften the first-draft patches in `gen_opl_patches.py` (lower
    modulator levels / feedback, maybe gentler duty-variant spread), then
    `make assets` + re-listen.**

- `[~]` **Phase B — MIDI / MT-32 flagship** — infrastructure COMPLETE
  (2026-07-07); remaining hand work is by-ear tuning via the audition loop.
  - `[x]` `gb_to_midi.py` + `overrides/` schema + `midi_to_stream.py`.
        Engine-exact simulation on pret_audio.py (ChannelTimer math, per-
        channel loop detection with frac reset at the seam, loop rewind,
        lcm fallback for the phasing songs — CinnabarMansion/Lavender get a
        seam warning). 49 songs → SMF (1 tick = 1 frame, division 60) →
        assets/music_streams.inc (~150 KB, per-bank id tables since sound
        ids collide across banks). All streams round-trip verified: frame
        totals, loop landing, no stuck/double notes over 3 loop passes.
        Overrides: tools/audio/overrides/<Song>.yaml (README + PalletTown
        example) — programs per target, CC7, pan, drum map.
  - `[x]` `mpu401.asm`: UART-mode driver, flat-stream sequencer, CC7 fade
        (NR50 mirror scales snooped per-channel CC7 bases, so engine fades
        apply to MIDI). Engine keeps running music for authentic
        bookkeeping; opl_shim mutes non-SFX voices in MIDI mode (MT-32+SB
        combo); AudioCommon_PlaySound mirrors starts/stop-alls. /MT32 /GM
        flags. Headless-verified both ways (state dump + no-flag regression).
  - `[x]` `gen_mt32_patches.py` + init-time SysEx upload (paced 3 PIT
        ticks, checksummed, 128-byte DT1 chunks, 7-bit address carry).
        Hand-editable tools/audio/mt32/timbres.yaml: LCD text, reverb,
        partial reserves (single message), channel table, custom-timbre
        schema (14 common + 4×58 partial params, sparse with defaults),
        patch/rhythm rewrites.
  - `[x]` `audition.py` host loop (plays assets/midi/<target>/<Song>.mid to
        an ALSA port — MUNT/fluidsynth — with the setup SysEx prepended,
        paced, so the ear hears what boot programs); `dos_port/run-mt32`
        (DOSBox-X built-in MUNT + /MT32). End-to-end PROVEN headless:
        DOSBox-X log shows "MT32: LCD-Message: POKEMON YELLOW  DOS!" — the
        full chain timbres.yaml → blob → mt32_upload → MPU-401 UART → MUNT.
  - `[x]` GM mapping mode (`/GM`): MIDI mode minus the Roland SysEx, same
        streams (current programs are GM-numbered for both targets). The
        open question resolved for now: GM shares the stream set until
        MT-32 overrides diverge (custom timbres); revisit with dual
        per-target stream tables then.
  - **Milestone: patches uploading clean + LCD greeting visible — DONE
    (MUNT log). Hand-tuned Pallet Town + a battle theme = by-ear work in
    the audition loop (overrides/*.yaml + mt32/timbres.yaml), pending a
    listening session: `mt32emu-qt &` then
    `tools/audio/audition.py Music_PalletTown`, or in-game via
    `dos_port/run-mt32 DEBUG_AUDIO=1`.**

- `[x]` **Phase C — Pikachu PCM** — DONE (2026-07-07); both device paths
  user-confirmed audible (SB direct mode + speaker PWM via run-spk).
  Remaining call sites (bills_pc / scripts / pikachu-emotion) land with
  their systems and are tracked by pret cross-ref, not by this phase.
  - `[x]` `gen_pika_pcm.py`: the pret WAVs are the raw 1-bit GB streams as
        0/255 bytes @ 22050 Hz, so the generator does what the GB's analog
        output stage did — low-pass filters (127-tap Blackman sinc, 4.5 kHz
        cutoff; 0.1% HF energy left), decimates to 11025 Hz, one shared
        normalization gain, per-clip DC removal + 3 ms edge ramps. One
        724 KB blob (assets/pika_pcm.bin, incbin'd) + PikachuCriesPointerTable
        (pret name; port format dd ptr, dd samples) shared by BOTH players
        — the speaker player derives its PWM scale at run time.
  - `[x]` `sb_pcm.asm`: DSP direct mode (cmd $10 per sample), speaker-on/off
        $D1/$D3 for pre-4.xx DSPs, all handshakes bounded. Pacing: PIT ch0
        can't be touched (it's the 60 Hz tick), so the pacer *latches* it —
        mode-3 counts decrement by 2/clock, elapsed = (prev−cur mod
        PIT_DIVISOR)/2, accumulated 24.8 fixed point (exact average rate,
        jitter self-corrects). Pacer exported for spk_pcm.
  - `[x]` `spk_pcm.asm`: RealSound-style PWM — ch2 mode 0 lobyte-only, count
        ∝ inverted sample, carrier at 2× sample rate (~22 kHz, above
        hearing), gate restored + ch2 back to mode 3 after.
  - `[x]` `PlayPikachuSoundClip` (src/engine/pikachu/pikachu_pcm.asm, pret
        label; DL = clip index): 3-frame lead-in, bounds check, dispatch
        g_sb_present → sb_pcm / else spk_pcm (engine offline → silent skip),
        clears CHAN5-8 sound IDs after, like pret. Blocking cli playback is
        authentic (GB froze too). All held notes are cut before the clip
        (opl_silence + midi_all_notes_off, both exported for this): the
        shim's software envelopes freeze during cli, so held FM/MIDI notes
        would drone through the clip — the GB's hardware envelopes kept
        decaying through its freeze (user-confirmed audibly 2026-07-07).
        Voices re-key on their next note events. Call sites wired: status
        screen (full pret
        branch: wMonDataLocation / IsThisPartyMon+BoxMonStarterPikachu →
        clip 16 / PlayCry-TODO). bills_pc / scripts / pikachu-emotion sites
        follow when those systems land (tracked by pret cross-ref).
  - **Milestone: Pikachu audible on both SB and speaker-only configs —
    state-verified headless 2026-07-07 (DEBUG_AUDIO harness plays PikachuCry1
    after the Phase A demo; $D240 snapshot: device=1/SB and device=2/speaker
    each played 9312/9312 samples, music resumed, CHAN5-8 cleared; DEBUG_STATUS
    FRAME.BIN regression clean). Both paths user-confirmed audible
    2026-07-07 (SB, then speaker via run-spk) — MILESTONE REACHED.
    Audible checks: `dos_port/run DEBUG_AUDIO=1` (SB direct mode);
    `dos_port/run-spk DEBUG_AUDIO=1` (speaker cry, music stays on OPL);
    `SPK_ONLY=1 dos_port/run-spk DEBUG_AUDIO=1` (true speaker-only box).**

- `[x]` **Phase D — Tandy + speaker SFX + polish** — DONE (2026-07-07); code
  state-verified headless + both new device paths user-confirmed audible
  (run-tandy / speaker-only run-spk). Only the optional sb_pcm DMA upgrade
  stays deferred (below).
  - `[x]` SN76489 docs in: `docs/sound/tandy_sound_reference.md` (Tandy 1000 SX
        Tech Ref extract, local-only ARR like the other sound specs; full PDF
        alongside) + `docs/references/smspower/` (SMS Power SN76489 page,
        committed). `tandy_shim` (src/audio/tandy_shim.asm): near-1:1 APU pass
        at port C0h — pulse1/2 → tones 1/2, wave → tone 3 an octave down with
        NR32-level attenuation, noise → PSG noise (nearest of the 3 fixed
        shift rates, GB 7-bit LFSR → periodic / 15-bit → white, LFSR reset on
        retrigger). Same software envelope/sweep/length/NR50/NR51-mute
        emulation as opl_shim; attenuation via generated 2 dB-step tables
        (assets/tandy_tables.inc, gen_tandy_tables.py). The PSG is write-only
        — no probe exists, so the /TANDY flag IS the detection.
  - `[x]` `spk_shim` (src/audio/spk_shim.asm): SFX-only — when an SFX owns a
        pulse channel (wChannelSoundIDs CHAN5/CHAN6), the highest-priority
        audible one drives PIT ch2 mode 3 through the port-61h gate; envelope
        decay-to-zero / length / sweep tracked in software so notes end and
        pokeball arcs bend. Selected by /SPK or as the automatic fallback
        when no OPL answers — a no-card box now blips. Shares PIT ch2 with
        spk_pcm via spk_silence (also called pre-Pikachu-clip, with
        tandy_silence, alongside the Phase C opl/midi cuts).
  - `[x]` Options-menu stereo bits (`wOptions` MONO/EARPHONE) → rAUDTERM: found
        already complete since Phase A — Audio1_ApplyMonoStereo + the
        enable/disable mask tables are translated in engine_1.asm and
        opl_shim's voice_pan consumes the result; the options-menu *UI* rides
        with the menus system, not this plan. Tandy/speaker are mono devices;
        they honor NR51's both-bits-clear rest/duck semantics only.
  - `[x]` Device dispatch: g_shim_device in audio_hal (exactly one shim pass
        per tick: OPL / SN76489 / speaker), /TANDY + /SPK parsed in
        parse_cmdline (g_cfg_shim), audio_shutdown silences all three.
        Debug: $D246 device, $D248+ tandy, $D250+ spk snapshots (window 9).
        Headless DEBUG_AUDIO verification 2026-07-07, all three paths:
        default → device 1, OPL keyed, clip on SB DSP 9312/9312;
        `/TANDY` + sbtype none → device 2, PSG atts 4/1/0/15 + tone divider
        $BF mid-music, clip on speaker PWM; no flags + no OPL → device 3
        fallback, 7 PIT-divisor writes from the blip + cry, clip on PWM.
  - `[ ]` Optional (deferred): upgrade `sb_pcm` to auto-init DMA (pull 8237 doc
        first; DPMI 0100h DOS-memory buffer, 64 KB-boundary safe). Only
        matters if a non-blocking cry is ever wanted.
  - **Milestone: audible checks — user-confirmed 2026-07-07, MILESTONE
    REACHED. Commands: `dos_port/run-tandy DEBUG_AUDIO=1` (music + SFX +
    cry on the 3-voice PSG, Pikachu on speaker PWM) and
    `SPK_ONLY=1 dos_port/run-spk DEBUG_AUDIO=1` (menu blip + cry pulse
    audible as speaker beeps, music silent by design).**

- `[ ]` **Phase E — LLM music arranger** (starts after B; see the Phase E section)
  - `[ ]` Pin the enhancement YAML schema (musical positions, tier tags, explicit
        per-target patch fields) — everything downstream depends on it.
  - `[ ]` `music_analysis.py` in `tools/audio/` (key, chords, phrases,
        repeated-motif tagging, contour, density) over the `pret_audio.py` IR.
  - `[ ]` **Hand-craft one song's enhancement YAML by ear** (e.g. Pallet Town or
        Pokémon Center) — proves YAML → merge → compile → audition end-to-end and
        becomes the few-shot worked example. Do this before any LLM involvement.
  - `[ ]` `yaml_lint.py` structural validation (range, beat refs, polyphony,
        unison-doubling, tier/patch-field consistency).
  - `[ ]` `gb_to_midi.py`: enhancement merge + per-target tier filtering (whole-layer
        drop when polyphony exceeded; chord thinning deferred).
  - `[ ]` OPL enhancement stream player: tier-1 voices on spare FM channels
        alongside the faithful shim (voice budget ~10 after shim + /SFXOVERLAP).
  - `[ ]` Textbook prep: extract + strip the ~20 Open Music Theory files; two-model
        distillation (Gemini distills → Claude writes skill files).
  - `[ ]` Skills in `.claude/skills/`: `music-theory` (+ references),
        `audio-enhance-opl3` (tier 1, few-shot example), `audio-enhance-mt32`
        (tiers 2–3, reads tier-1 entries first).
  - `[ ]` LLM arrangement passes per song (OPL3 tier-1 pass → audition → MT-32
        tier-2/3 pass → audition); human ear is the quality gate throughout.
  - **Milestone: one song with a hand-crafted tier-1 layer audible on OPL3 and
    MT-32; then one LLM-drafted arrangement surviving lint + audition.**

## Open questions / deferred

- Exact OPL voicing for the wave channel (per-instrument FM approximations vs. one
  generic patch) — decide during Phase A patch tuning.
- Whether GM gets independent override columns or derives mechanically from the
  MT-32 overrides — decide when Phase B tuning starts.
- DMA upgrade for `sb_pcm` (only matters if a non-blocking cry is ever wanted).
- Covox/LPT-DAC output: declined for now; the APU-emu-to-PCM mixing it would need is
  out of scope for this plan.
