# Current Plan: IBM Music Feature Card (IMFC) support

Status: **DEFERRED DRAFT** — revisit after all track enhancements are approved
(currently the audio work is in the MT-32/OPL enhancement + approval loop;
`enhancement_approvals.json` is the gate). Written 2026-09-12 as a rough spec
to be revised at build time (a few weeks to a month out). The hardware research
and pipeline analysis behind it are in the 2026-09-12 session; re-verify the
"measured" claims below before building since the tree will have moved.

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
- Sequence AFTER enhancement approvals freeze the tiers (this plan's cost basis).
- `docs/sound/` gets mirrored IBM/FB-01 references like the other devices carry.

## Open decisions (resolve at revision time)

1. Tier-1 on IMFC: 4th patch field (`imfc_voice`) per tier-1 channel vs IMFC plays
   base + tiers 2-3 only. Lean: 4th field.
2. Drums convention: reserve MIDI ch8 for mapped percussion vs melodic-percussion
   voices.
3. Stream file: separate `assets/imfc_streams.inc` (recommended) vs rebuilding
   shared `music_streams.inc` per target (check how `--target gm` coexists with
   mt32 — `Makefile:4450-4460` only wires `stamp-mt32`).
4. Audition backend: MAME `fb01` (needs copyrighted `fb01.zip` + `hd44780` ROMs)
   vs `ymfm` YM2164 core + own MIDI interpreter (BSD, no ROMs, more work) vs
   DOSBox-Staging `imfc=true`.
5. `/IMFC` vs `/MT32`/`/GM` coexistence: priority (MT32 > IMFC > GM?) or
   first-wins like `entry.asm:337-345`.

## Stages

- [ ] **0. Preconditions.** All `enhancement_approvals.json` entries approved;
  `docs/sound/` IBM/FB-01 references mirrored; re-verify the "measured" claims
  in this file against HEAD (file paths + line numbers drift).
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
