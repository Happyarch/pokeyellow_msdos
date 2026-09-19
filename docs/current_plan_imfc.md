# Current Plan: IBM Music Feature Card (IMFC) support

Status: **RESEARCH PHASE COMPLETE (2026-09-18)** — implementation stays
deferred until track remasters are done (the remaster gate supersedes the old
"enhancement approvals freeze" gate below). R1–R6 ran as serial research stages;
their outputs are folded into this file. Do not re-litigate banked decisions
without new evidence; re-verify file:line anchors at build time (they drift).

## Why this is cheap (the thesis this plan rests on)

- The pinned DOSBox-X **already emulates the IMFC**: `tools/dosbox-x/src/hardware/imfc.cpp`
  + `imfc_rom.c`, `[imfc]` section in `src/dosbox.cpp:4220-4231` (off by default,
  base `2a20`, IRQ 3). Only config + possible rebuild needed — no emulator port.
- The arrangement model transfers verbatim: `overrides/<Song>.yaml` (base ch1-3 +
  drums) + `enhancements/<Song>.yaml` (tiered additive voices, `switches:`) gain
  per-channel/per-switch IMFC instrument fields. No new arrangement model.
- Device selection is already runtime (`/MT32`→1, `/GM`→2 in `g_cfg_midi`,
  `boot/entry.asm:331-345`); `/IMFC`→3 follows the pattern. One dispatch byte,
  one 60 Hz compare in `audio_tick` (`src/audio/audio_hal.asm:67-95`, called from
  `src/home/vblank.asm:206`). Device count scales files and assets, not branches.
- Per-target musical differences are baked data, not branches: `gb_to_midi.py`
  emits per-target streams at asset-gen time. MT-32 vs GM already proves the
  shape (one sequencer, two blobs, zero extra tick conditionals).

## Research findings (R1–R6, 2026-09-18 — build inputs, not speculation)

- **R1 doc mirrors.** `docs/sound/` (gitignored, local-only): `Yamaha_FB-01_Service_Manual.pdf`
  (4.4 MB image-only scan) + `.md` distillation (SysEx taxonomy, Format 1/2 byte
  layouts, bulk framing, event list, parameter lists 5–6, transmit format) +
  `fb01_voice_nibble_packing.svg` + `fb01_config_assign.svg`;
  `Yamaha_FB-01_Owners_Manual.pdf` (72pp EN, 3.8 MB) + `.md` (architecture, banks,
  configs, protect, PC limits). `docs/references/` (tracked):
  `nerdlypleasures/IMFC_Exclusive_Commands_*` + `MT32_FB01_MIDI_Files_and_Patches_*`
  + `scalibq/IMFC_and_FB-01_*`. Open `[?]`s live inline in both `.md` files.
- **R2 verdict: custom uploads WORK.** Bank-bulk → `m_voiceDefinitionBankCustom[0..1]`,
  1-voice bulk → live instrument buffer, config → live/slot/all-16, all
  protect-gated correctly (IMFC boots writable, no battery); instrument
  assignment re-copies into YM registers → `chan_calc`, no ROM-only shortcut.
  Parameter List (`F0 43 75 71`) applies entries on the fly by INSTRUMENT number —
  setup blob MAY use list form; walker is byte-at-a-time (VOGONS buffering gotcha
  N/A); no pacing enforcement. Banks are owners-numbering 0–6 (RAM 0–1, ROM 2–6).
  Setup order: protect-OFF → config image → RAM bank images (nibble) → list tweaks.
- **R3 voice library.** 240 ROM names harvested from `imfc_rom.c` (ROM1 mixed,
  ROM2 piano/EP farm, ROM3 orchestral, ROM4 synth/bass/drums, ROM5
  organs/guitars/SFX). Gaps needing customs: choir/chorale, synth leads,
  atmosphere pads, sustainers. Custom seed: Sierra-bank extraction beats DXconvert
  (FB-01-native idioms; TX81Z waveforms are one-way-incompatible — FB-01 is
  sine-only).
- **R4 rhythm convention.** Rhythm claims INST #8 top-down on MIDI ch 8 with
  key-code splits, ONLY when the track uses `rhythm:true`; else all 8 go melodic.
  Overflow: `imfc_overflow: drop_rhythm | drop:<channel>` (default `drop_rhythm`,
  ERROR if overflowed-and-absent, WARN if stale). Drums: `imfc_drums.map:`
  GM-note → `imfc_voice` (ROM drums default, custom RAM on demand). LSL3 guard:
  SysEx by instrument number, one channel per instrument except the ch-8 rhythm
  family, park unused on ch 9–16 with `notes=0`.
- **R5 schema design.** Fields: enhancement `imfc_voice` (name or
  `{bank,program}`), override `imfc_program`, switches carry the
  mt32+gm+imfc triple; IMFC ints 1-based 1–48 with explicit bank in BOTH files
  (breaks overrides 0-based — linted); tier-1 gets the 4th field (open decision 1
  resolved YES). Tier table `OPL3:1, MT-32:3, GM:3, IMFC:3`, inherit downward;
  five compiler joints named (`resolve_switch_program`, `enhancement_tracks`
  program select, `midi_to_stream` custom gating, tier-drop sorter, tick-0
  fallback). Custom analog: `tools/audio/imfc/voices.yaml` + `gen_imfc_patches.py`
  → `ImfcSetup_/`ImfcCleanup_` tables, RAM-bank-0 slots, per-song overwrite +
  restore. Migration: all IMFC legs additive, MT-32/GM byte-identical; `imfc_*`
  optional with drop+WARN until batch, then missing = ERROR.
- **R6 audition.** Renderer: pinned DOSBox-X's own IMFC mixer (no MUNT — wrong
  chip; no MAME — ROMs + no Parameter List; no ymfm — interpreter from scratch;
  no Staging — split truth). `MidiSession` stays event source, backend is PCM
  sink; TUI keys survive; setup retransmit full-blob on song switch only, list
  head on note edits. `run-imfc` mirrors `run-mt32` with `[imfc] imfc=true`
  (no ROMDIR check — ROM embedded). Portamento excluded (broken in oracle);
  handshake ACK is a DOS-driver concern, not TUI.

## Hardware facts (measured 2026-09-12, re-verify at build time)

- IMFC = Yamaha FB-01 module (YM2164 OPP, 4-op FM, 8 voices, stereo) + proprietary
  **parallel** MIDI interface — NOT MPU-401 UART. 16 I/O ports, base `0x2A20`,
  IRQ 3. Register map in `imfc.cpp:73-82`: PIU0/1/2 `+0..2`, PCR `+3`,
  CNTR0-2 `+4..6`, TCWR `+7`, TCR `+8` (+mirror), TSR `+C` (+mirror). Handshake
  semantics: `MusicFeatureCard` port handlers in `imfc.cpp` + IBM Options and
  Adapters manual (VCFED thread has a register summary).
- Synth: 8 MIDI channels (default 1-8), **8-note total polyphony**, each patch
  costs 1-8 notes. 240 ROM + 96 RAM patches in banks of 48; Program Change spans
  0-47 only, bank changes need SysEx config commands. SysEx is Yamaha
  `F0 43 75 ...` (nothing like Roland `F0 41 10 16 12`). Config memory first,
  then voice banks; full dump ~15 KB; ACK `F0 43 60 0x F7`.
- Gotcha: IMFC firmware has a **Parameter List** SysEx the stock FB-01 lacks;
  Sierra IMFC drivers use it. If the audition backend is a real FB-01/MAME-fb01
  rather than DOSBox-X IMFC emulation, a list→individual-SysEx translator is
  needed (Scali's approach). Non-issue if backend is DOSBox-X IMFC — verify by test.
- No rhythm channel on the FB-01 (unlike MT-32 ch10) — needs a drum convention
  (open decision 2 below).

## Banked decisions (do not re-litigate without new evidence)

- Launch flag `/IMFC`, not make-time, not a setup menu.
- Sequence AFTER track remasters are done (remaster gate; supersedes the old
  approvals-freeze wording).
- `docs/sound/` gets mirrored IBM/FB-01 references like the other devices carry.
- **R1–R6 banked (2026-09-18):** tiers shared, devices gated to max tier
  (IMFC → tier 3, inherit down); arrangements/enhancements shared, only
  overrides + patch routing differ per device; rhythm = conditional INST#8/ch-8
  mapping with `imfc_overflow` + `imfc_drums.map`; custom voices YES via SysEx
  setup/cleanup (Parameter-List form); audition via pinned DOSBox-X IMFC mixer;
  IMFC numbering 1-based with explicit bank in both YAML families.

## Open decisions (resolve at revision time)

1. Tier-1 on IMFC: RESOLVED (R5) — 4th patch field (`imfc_voice`) on every
   tier-1 channel. A silent/missing foundation tier cannot be bank-selected
   around.
2. Drums convention: RESOLVED (R4) — conditional mapping (rhythm claims INST #8
   top-down on MIDI ch 8 with key splits, only when the track uses it);
   overflow via `imfc_overflow: drop_rhythm | drop:<channel>` (default
   `drop_rhythm`); per-piece voices via `imfc_drums.map`.
3. Stream file: separate `assets/imfc_streams.inc` (recommended) vs rebuilding
   shared `music_streams.inc` per target (check how `--target gm` coexists with
   mt32 — `Makefile:4450-4460` only wires `stamp-mt32`).
4. Audition backend: RESOLVED (R6) — pinned DOSBox-X's own IMFC mixer behind
   `audition.py --target imfc` (`MidiSession` stays event source, backend is PCM
   sink); `run-imfc` mirrors `run-mt32` with `[imfc] imfc=true`. MAME (copyrighted
   ROMs + no Parameter List), ymfm (interpreter from scratch), and Staging (split
   truth) all rejected with reasons. Real-hardware FB-01 path (MIDI-OUT +
   list→individual translator) sketched only, deferred.
5. `/IMFC` vs `/MT32`/`/GM` coexistence: priority (MT32 > IMFC > GM?) or
   first-wins like `entry.asm:337-345`.

## Stages

- [x] **0. Preconditions + research.** Remaster gate replaces the old approvals
  wording; `docs/sound/` IBM/FB-01 references mirrored (R1); R2–R6 findings above
  are the build inputs — re-verify file:line anchors at build time.
- [ ] **1. Toolchain target `imfc`.** `gb_to_midi.py --target imfc` (channels
  1-8, PC 0-47 + SysEx bank-select, note-count polyphony replacing the 32-partial
  model in `yaml_lint.py:53-57`); `gen_imfc_patches.py` + `tools/audio/imfc/`
  bank definition with slot discipline mirroring `mt32/timbres.yaml:35-42` →
  `assets/imfc_sysex.inc`; `yaml_lint.py` IMFC rules (voice/bank resolution,
  8-note budget, drum rule, switch seam reuse); `midi_to_stream.py --target imfc`
  → `assets/imfc_streams.inc` (op format at `midi_to_stream.py:9-16` reuses
  verbatim); `Makefile` `stamp-imfc` + `.inc` targets mirroring
  `Makefile:4130-4144,4450-4460`; `audition.py --target imfc` backend.
- [ ] **2. DOS driver `src/audio/imfc.asm`** (new port-only HAL file, template:
  `src/audio/mpu401.asm`, 467 lines). `imfc_detect` (bounded polls, `mpu401.asm:97-100`
  fallback shape); `imfc_upload` (`mt32_upload` shape, `mpu401.asm:168-196`);
  `imfc_seq_start/stop/tick` + `imfc_all_notes_off` (ports of `mpu401.asm:205-369`,
  incl. `(id,bank)` table select and NR50→CC7 fade mirror); `imfc_dbg_snapshot`
  past `mpu401.asm:415-429`; `DEVIATION{class=HAL; ...}` header per
  `mpu401.asm:3`. Wire: `audio_hal.asm:97-133` init + one `audio_tick` arm;
  `entry.asm:parse_cmdline` `/IMFC`; `run-imfc` script mirroring `run-mt32:1-52`.
- [ ] **3. Pilot song.** One song (Pallet or Celadon) end-to-end through toolchain
  + driver before batching: validates routing table (cf. the `timbres.yaml:19-32`
  do-not-"fix" lesson — verify in-game, not by spec), upload pacing, polyphony
  accounting. `yaml_lint` clean → host audition → `run-imfc DEBUG_AUDIO=1
  TRACK=... /LOOP` in-DOS verify.
- [ ] **4. Song batch, two halves.** Per song: IMFC overrides + `imfc_voice` on
  every enhancement channel + IMFC programs on switches (names preferred — the
  0-based/1-based trap in `overrides/README.md:66-72` vs `enhancements/README.md:121-122`
  recurs; fix the IMFC basis explicitly and lint it). Record per-song approval
  (`enhancement_approvals.json`: extend or add `imfc_approved`).
- [ ] **5. Gates + acceptance.** `lint_pret_labels` 0, `static_gate` clean,
  `fidelity`/`fidelity-full` green with byte-identical `GBSTATE.BIN` on existing
  scenarios (engine state is device-independent); per-song in-DOS checklist:
  correct music, SFX/cries on OPL (the `mpu401.asm:10-18` split), fades mirror,
  clean song handover, OPL fallback with device absent.

## Risks

PIU handshake edge cases (spec + `imfc.cpp` only); Parameter List translation
(open decision 5 in §1 of the draft); 8-note polyphony forcing harder tier-drop
choices than MT-32; no real-hardware reference — emulation is the truth.
