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
- 8 spare voices: deliberately unused in v1. Headroom is explicitly NOT a
  defect — and it is the tier-1 enhancement budget (12 voices vs 4 needed).
  Candidate v2 technique (recorded, not designed): noise-channel simulation
  by bunching pulse channels with volume varied as sine × PRNG amplitude.
  Detuned doubling / echo stay out of scope: this is a port, not a remix.
- Envelopes in software per tick (Tandy pattern, `tandy_shim.asm:219-476`) onto
  SAA amplitude registers; SFX table (waveform/amplitude per SFX id) as
  shim-owned constants — the `tools/audio/sfx/*.yaml` OPL indices don't
  transfer (same finding as the SID draft).
- Dispatch: `DEV_CMS` nibble — device 6 in the Covox-plan nibble word
  (`g_audio_devices`, 0 none / 1 OPL / 2 Tandy / 3 SPK / 4 Innova / 5 Covox /
  6 CMS); explicit-only like Innova/Covox (never auto-set). Flag `/GB` vs
  `/CMS` still open — decide at build (check `find_token` substring behavior
  in `boot/entry.asm` first). One `audio_tick` arm; MIDI-coexistence guard
  mirroring `tandy_shim.asm:504-509`; runner appends the `sbtype=gb` stanza
  (`run-gb` + `.ps1`, run-tandy pattern).

## Stages

- [ ] **0. Groundwork (references DONE 2026-09-18).** `docs/sound/`
  holds the vision-transcribed `SAA1099_Philips_1984.md` + 3 SVGs (local-only,
  gitignored); `docs/references/` holds `gameblst.txt` (UTF-8) + `cms.4.html`.
  Remaining: flag name (`/GB` vs `/CMS`), detection probe-vs-flag decision
  (CT-1302 latch probe documented in `cms.4.html`).
- [ ] **1. Driver `src/audio/cms_shim.asm`** (port-only HAL,
  `DEVIATION{class=HAL}` header): init/silence, per-tick 4-channel pass,
  software envelopes, noise mapping, SFX amplitude table, self-guard.
- [ ] **2. Dispatch + runner.** Flag parse, `audio_hal.asm` arm, `run-gb`
  (+`.ps1`).
- [ ] **3. Ear-checks.** Music set, noise-heavy battle, Pikachu cry fallback
  (SAA has no DAC — SB/speaker path, same as Tandy).
- [ ] **4. Gates.** `lint_pret_labels` 0, `static_gate` clean, fidelity green
  with byte-identical `GBSTATE.BIN` (output-only — assert it).

## Risks

Near-zero structural risk (closest existing-shape build after Tandy itself);
main risk is underwhelming differentiation vs Tandy+OPL3 (say so in the final
spec — the defense is period-completeness, not sound).
