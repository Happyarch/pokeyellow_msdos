# Current Plan: Game Blaster / CMS support — SEEDLING

Status: **SEEDLING — serious future consideration, not scheduled.** Written
2026-09-12 as a placeholder so the idea holds its slot; expand into a full
spec before building. Re-verify file:line claims against HEAD at build time.

## Thesis

The Game Blaster (Creative CMS) is Tandy's bigger sibling: 2× Philips SAA1099,
12 square-wave voices, same APU-shim philosophy, no channel-count mismatch to
solve (unlike the SID's 4→3). It slots between Tandy and OPL3 in the lineup.
Emulator support confirmed in-tree: `sbtype=gb` forces CMS
(`sblaster.cpp:4248-4264`), `gameblaster.cpp` in
`src/hardware/Makefile.am:10`, MAME-derived CMS core (`CHANGELOG:10109`).

## Hardware facts (verify at build — recorded from general knowledge, not yet
measured against the vendored source)

- 2× SAA1099, 6 voices each (square + noise generators, per-channel amplitude
  + envelope generators). CMS base `0x220` (verify against `gameblaster.cpp`).
- Detection story unclear from memory — the driver may need flag-IS-detection
  like Tandy (`tandy_shim.asm:29-31`) or a real probe; decide from the vendored
  source at build time. Either pattern already exists in-tree.
- No per-song arrangement files: 1:1 channel mapping like Tandy, music+SFX
  voiced together through one pass.

## Mapping (proposed)

- GB ch0/ch1 pulse → 2 SAA square voices (duty: SAA1099 squares are fixed
  shape like the SN76489 — duty collapses, same as Tandy); ch2 wave → square
  at pitch (triangle-closest doesn't exist here; plain square, Tandy-octave
  treatment optional); ch3 noise → SAA noise generator.
- 8 spare voices: deliberately unused in v1 (a 12-voice chip playing 4
  channels is fine — headroom is not a defect). Tempting v2 uses (detuned
  doubling, echo) are explicitly out of scope: this is a port, not a remix.
- Envelopes in software per tick (Tandy pattern, `tandy_shim.asm:219-476`) onto
  SAA amplitude registers; SFX table (waveform/amplitude per SFX id) as
  shim-owned constants — the `tools/audio/sfx/*.yaml` OPL indices don't
  transfer (same finding as the SID draft).
- Dispatch: new `g_shim_device` value + `/GB` (or `/CMS` — decide at build;
  check `find_token` substring behavior in `boot/entry.asm` first) flag, one
  `audio_tick` arm, MIDI-coexistence guard mirroring
  `tandy_shim.asm:504-509`; `run-gb` appends the `sbtype=gb` stanza.

## Stages

- [ ] **0. Groundwork.** SAA1099 register map + base address verified against
  vendored `gameblaster.cpp`; flag name decided; detection story settled.
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
