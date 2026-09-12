# Current Plan: Talking dialog (DECtalk first, IBM Speech Adapter maybe)

Status: **DRAFT FOR REVIEW — toy feature, non-timebound.** Written 2026-09-12,
revised same day to DECtalk-first ordering (may end up the only backend; no
hardware owned — write against emulators). Not serious code; intended home is a
branch (see "Placement" below). Re-verify file:line claims against HEAD at
build time.

## Placement: branch, but make-gated inside it

- Develop on a **branch** so `master` and the fidelity gates stay pristine; the
  whole thing deletes in one `git branch -D` if the joke stops being funny.
- Write it in the `DEBUG_AUDIO` shape anyway: `make SPEECH=1` compiles the
  driver(s) in; `/DTALK` (DECtalk) or `/SPEECH` (TMS5220 path, if ever built)
  at runtime activates; default build has hooks `%ifdef`'d out and zero
  footprint. A merge is then just "prove `GBSTATE.BIN` is identical with the
  flag off," which the suite does for free.

## Backend A (primary): DECtalk over serial

DECtalk speaks **ASCII text over RS-232** — the entire TTS/LPC asset pipeline
collapses to sending strings down a wire. No per-line blobs, no sidecars.

- **Targets:** DTC-01 (1984 serial box, 9600 baud default; MAME emulates it
  maturely, `dectalk.zip`) for emulation; DECtalk Express (1994 serial box,
  9600 8N1 XON/XOFF, built-in speaker) for real iron. Avoid the DECtalk PC ISA
  card: MAME's ISA emulation is rough (microcode won't load — mamedev #12501).
- **Protocol:** ASCII lines + punctuation; inline `[:name]` voices (Oak = Paul,
  rival = Frank, NPCs rotating — per-character voices free), `[:rate]` to tune
  to typing speed, `[:phoneme]` for the Jigglypuff scenario. DTC-01 escape
  sequences per EK-DTC01-RM-003 (mirrored to `docs/sound/` in stage 0).
- **Sync is device-clocked and documented:** `DT_INDEX_REPLY` (manual pp. 50-54)
  makes the unit send an escape-sequence reply as each index mark is spoken;
  `DT_INDEX_QUERY` polls the last-spoken mark; `DT_SYNC` gates host commands
  behind speech completion; `DT_STOP` kills speech instantly + reinitializes
  buffers (the mash-through path, specified). Inject index marks at word
  boundaries; drive the reveal off incoming replies. No estimation anywhere.
- **Transcript upgrade over the TMS5220 design:** scrape rendered dialog rows
  from the tilemap at box-open, inverse-charmap-decode to ASCII — names and
  numbers resolve at render, so **even dynamic lines speak**. Marks injected at
  scrape time; word↔glyph mapping known at runtime. Zero transcript assets.
- **Serial coexistence:** `com_uart.asm` is single-instance and link-owned, so
  speech gets a dedicated **poll-only shim on the non-link COM** — TX via
  bounded-polled THRE (existing `TX_POLL_BOUND` pattern), RX tick-polled in
  `audio_tick` for index replies. No ISR, no vector conflicts (cross-IRQ
  COM1+COM2 pairing is clean), link code untouched. DOSBox-X side follows the
  `linkcheck.sh` pattern (`serial1=nullmodem` + `serial2=` at the DECtalk
  backend); tracked conf stays clean.
- **Test rigs (no audio emulation needed — it's serial):** host-side DECtalk
  speak-window WAV export or the standalone MAME-core emulator (dectalk.nu) for
  second-scale ear-checks; in-DOS DOSBox-X serial passthrough → MAME DTC-01, or
  `directserial` → a real Express. `run-dtalk` script mirrors `run-mt32`'s
  conf-append shape.

## Backend B (deferred, maybe never): IBM Speech Adapter (TMS5220)

- **IBM PCjr Speech Attachment** (1984, sidecar): TMS5220(C), 32 KB ROM (BIOS
  routines + 196-word vocab), 8255 PPI, disk-loaded voice data (Bouncy Bee).
- **IBM PS/2 Speech Adapter** (1987, ISA): same chip, shifted addresses (the
  8-Bit Guy finding); needs its breakout box. Would-be target if revived.
- MAME chip core `mame/src/devices/sound/tms5220.cpp` is real; MAME PCjr
  attachment coverage unverified; no DOSBox support known — would need a Scali
  style DOSBox-X patch. Design if revived: Speak-from-RAM LPC blobs as Tier-1
  data, offline TTS→LPC chain with word timestamps, frame-estimator reveal.
  Static-only streams (dynamic lines silent). All superseded by Backend A until
  someone wants the ISA card specifically.

## Scope: what talks, what does not (both backends)

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

No v1 milestone — single build. The speech is the master clock; the reveal
follows it. On DECtalk the clock signal is real (index replies); the estimator
below applies only if Backend B is ever revived.

- **Runtime** (pending-utterance struct): scraped ASCII + word↔glyph map,
  `word_idx`, `glyphs_typed`. `PrintLetterDelay`
  (`src/home/print_text.asm:38`) patch: marks elapsed → reveal through the
  word's `glyph_end`; otherwise existing fixed-delay path. RX polled per tick;
  reply timeout → reveal-all fallback (backend without mark support).
- **Edge cases (decided):** early box close / mash-through → `DT_STOP`, speech
  never outlives its box; instant-text option → reveal-all with async speech;
  glyph counter persists across `dialog_window_scroll`; ▼-wait falls out free
  (typing completes with the utterance, then the box waits).
- **Verify at build:** skip/fast-forward semantics during reveal;
  `TEXT_DELAY_MASK` values in `wOptions`; mark-echo latency through the
  DOSBox-X serial path (passthrough buffering could delay replies — measure
  with a stopwatch utterance before trusting tight sync).

## Stages

- [ ] **0. Groundwork.** Mirror EK-DTC01-RM-003 (at minimum the Ch.1/3 sync +
  escape-sequence pages) into `docs/sound/`; stand up one backend (MAME DTC-01
  or speak-window) and speak a test line; measure serial reply latency.
- [ ] **1. Driver `src/audio/dtalk_drv.asm`** (port-only HAL,
  `DEVIATION{class=HAL}` header): poll-only UART shim (non-link COM, 9600 8N1
  XON/XOFF); line sender with `[:name]`/`[:rate]` prefixes + word-boundary
  index marks; RX mark parser feeding the pending-utterance struct; `DT_STOP`
  path; `/DTALK` flag; hooks at the 5 speakable sites.
- [ ] **2. Transcript + reveal.** Tilemap-row scraper + inverse-charmap decode
  (dynamic lines included); v2 `PrintLetterDelay` patch with timeout fallback;
  per-character voice assignment table.
- [ ] **3. Runners + rig.** `run-dtalk` (serial1 nullmodem-compatible,
  serial2 → backend); host-side WAV reference flow documented.
- [ ] **4. Gates.** `lint_pret_labels` 0, `static_gate` clean, fidelity green
  with byte-identical `GBSTATE.BIN` (speech is output-only — assert it);
  ear-checks: dialog line, sign, silent battle, talking trainer win, one
  per-character voice swap.
- [ ] **5. (Deferred, maybe never) Backend B.** TMS5220 ISA path per the design
  above, `make SPEECH=1` + `/SPEECH`, behind the same 5 hooks.

## Risks

DOSBox-X serial passthrough latency vs mark timing (measured in stage 0);
`[:name]` voice availability varying across DECtalk versions (pin per-backend
voice table); MAME DTC-01 ROM (`dectalk.zip`) redistributability — document,
never vendor; no real-hardware reference unless an Express turns up.
