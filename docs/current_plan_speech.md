# Current Plan: IBM Speech Adapter support (talking dialog)

Status: **DRAFT FOR REVIEW — toy feature, non-timebound.** Written 2026-09-12
as a for-fun exploration: speech synthesis for NPC dialog and signs through the
IBM PCjr Speech Attachment / PS/2 Speech Adapter (TI TMS5220). Not serious
code; intended home is a branch (see "Placement" below). Re-verify file:line
claims against HEAD at build time.

## Placement: branch, but make-gated inside it

- Develop on a **branch** so `master` and the fidelity gates stay pristine; the
  whole thing deletes in one `git branch -D` if the joke stops being funny.
- Write it in the `DEBUG_AUDIO` shape anyway: `make SPEECH=1` compiles the
  driver in and builds the LPC assets; `/SPEECH` at runtime activates it;
  default build has hooks `%ifdef`'d out and zero footprint. A merge is then
  just "prove `GBSTATE.BIN` is identical with the flag off," which the suite
  does for free.

## Hardware facts (hound, 2026-09-12)

- **IBM PCjr Speech Attachment** (1984, sidecar): TMS5220(C), 32 KB ROM with
  BIOS speech routines + 196-word vocabulary, Intel 8255 PPI gating LPC + CVSD
  sections, disk/cartridge-loaded voice data supported (Bouncy Bee precedent:
  same voice talent for ROM + disk samples).
- **IBM PS/2 Speech Adapter** (1987, ISA): same TMS5220C architecture, shifted
  addresses (the 8-Bit Guy finding — PCjr games hacked onto the ISA card by
  shifting ports); needs its breakout box to hear anything; runs PCjr software
  modulo speed quirks. **The ISA card is the target.**
- **MAME has the chip core**: `mame/src/devices/sound/tms5220.cpp` (full
  TMS5220 emulation; an FPGA reimplementation was built on it). Whether MAME's
  PCjr driver wires the whole attachment needs verifying at build time — the
  chip core is the load-bearing piece. No DOSBox support (either fork) is
  known; assume a custom test rig (stage 3).
- The TMS5220 speaks **LPC frames, not text** (no phoneme mode — that is the GI
  SP0256 family). The 196-word ROM vocab cannot cover game dialog, so this is a
  **Speak-from-RAM design**: every speakable line is offline-synthesized to
  TMS5220-compatible LPC frames, baked as Tier-1 generated data, streamed by a
  new driver. Sizing: LPC ~150-225 bytes/sec, a few hundred lines ≈ a couple
  hundred KB against an 8 MB EXE.

## Scope: what talks, what does not

Speakable (all mapped 2026-09-12 against the text engine):
`ShowTextStream` (`src/engine/overworld/map_sprites.asm:799` — NPC plain dialog
+ signs), `DisplayTextID` plain tail (`src/home/text_script.asm:316-317` —
A-press dialog), `TalkToTrainer` before-battle text
(`src/home/trainers.asm:341-343`), `DisplaySignText`
(`src/home/overworld_text.asm:80`), and `PrintEndBattleText`
(`src/home/trainers.asm:670`, called only from `TrainerBattleVictory`,
`src/engine/battle/core.asm:6404`) as the single battle exception (trainer win
line). Excluding `PrintBattleText` (`src/engine/battle/core.asm:1423`, 94
callers) excludes all battle spam while keeping the win line — no heuristics.

## Sync: v2 speech-clocked typing from day one

No v1 milestone — single build, sidecar chain included from the start. The
speech is the master clock; the reveal follows it. The chip reports no position
back, so everything is baked offline and estimated at runtime.

- **Asset chain** (deterministic, re-runnable): pret dialog label → transcript →
  TTS (**must emit word timestamps**, a hard engine requirement) → LPC frames +
  per-line timing sidecar `[{word, glyph_start, glyph_end, lpc_frame}, ...]`.
  Glyph indices count rendered glyphs only (post-command-strip — exactly the
  `.glyph` sequence at `src/home/text.asm:863-867`). Static-only streams speak;
  dynamic lines (runtime names/numbers) stay silent — documented, not a bug.
- **Runtime** (pending-utterance struct): `lpc_ptr`, `sidecar_ptr`, `word_idx`,
  `glyphs_typed`, `speech_start_tick`. Frame position estimated:
  `current_frame = (now - start) × frames_per_tick` (chip consumes at a fixed
  clock; FIFO top-up paces off chip status). `PrintLetterDelay`
  (`src/home/print_text.asm:38`) patch: speech active with sidecar → reveal
  through `glyph_end` of elapsed words; otherwise existing fixed-delay path.
- **Edge cases (decided):** early box close / mash-through → TMS5220 stop/reset,
  speech never outlives its box; instant-text option → schedule collapses,
  reveal-all with async speech (graceful v1 degradation); glyph counter persists
  across `dialog_window_scroll`; ▼-wait falls out free (typing completes with
  the utterance, then the box waits).
- **Verify at build:** skip/fast-forward semantics during reveal;
  `TEXT_DELAY_MASK` values in `wOptions`.

## Stages

- [ ] **0. Groundwork.** Mirror TMS5220 datasheet + PCjr Speech Tech Ref into
  `docs/sound/`; confirm MAME PCjr speech-attachment coverage; select LPC
  encoder (test phrase → MAME-core decode → ear-check) and TTS engine
  (word-timestamp requirement).
- [ ] **1. Asset pipeline.** Transcript extractor over pret dialog/sign sources
  (reuse `gb_text` parsing) → TTS → LPC blobs `assets/speech_*.inc` +
  sidecars + label→blob index. Silent-on-dynamic documented.
- [ ] **2. Driver `src/audio/speech_drv.asm`** (port-only HAL,
  `DEVIATION{class=HAL}` header): ISA-card port map (PCjr-shifted); FIFO top-up
  from `audio_tick`, non-blocking (game runs under speech); frame estimator;
  v2 `PrintLetterDelay` patch; stop/reset path; `/SPEECH` flag; hooks at the 5
  speakable sites consumed at `TX_START`.
- [ ] **3. Test rig.** Host-side: LPC→MAME-core→WAV ear-check, no emulator.
  In-DOS: DOSBox-X patched with MAME's `tms5220` core behind the ISA ports
  (Scali IMFC precedent — custom build, documented, not upstreamed).
  `run-speech` script; `DEBUG_AUDIO TRACK=... /LOOP` shape reused.
- [ ] **4. Gates.** `lint_pret_labels` 0, `static_gate` clean, fidelity green
  with byte-identical `GBSTATE.BIN` (speech is output-only — assert it);
  ear-checks: dialog line, sign, silent battle, talking trainer win.

## Risks

Encoder output incompatible with 'final' chirp/LPC tables (round-trip test in
stage 0 exists for this); steal of `PrintLetterDelay` timing breaking
non-speech text (guard: sidecar-present gate + instant-text collapse);
copyrighted attachment ROM routines — clean-room the FIFO protocol from the
datasheet + MAME source, never redistribute the ROM; no real-hardware reference.
