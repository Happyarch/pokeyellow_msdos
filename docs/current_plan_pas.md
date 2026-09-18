# Current Plan: Pro Audio Spectrum 16 emulation in the DOSBox-X fork (`pas16` branch)

Status: **IN BUILD (round-robin subagents, serial).** Target is the PAS16
only — not Plus/16D, not the original 8-bit PAS (decided 2026-09-18).
Emulator-side work only: a native PAS16 backend in our DOSBox-X fork so a
future game-side driver has a validation oracle. `--no-verify` on commits
while remote.

Numbering: stages are `N`, substeps are `N.N` — one scheme, no NX mixes.

## Why (thesis)

- 86Box v4.2 emulates PAS Plus/16/16D, but our golden harness runs our
  DOSBox-X fork — which emulates no PAS at all (closed `sbtype` list, no
  `pas=` key). A game-side PAS driver cannot be validated without a fork
  backend.
- License is clean: 86Box ships GPL v2 `COPYING`; `snd_pas16.c` carries
  author/copyright lines but no "v2 only" notice (GPL §9: no version
  lock-in). Our fork is GPL v2-or-later. Combination stays GPL-2.0+ with
  notices kept and changes marked.
- Method: **reuse 86Box hardware knowledge, not code verbatim.** Re-express
  the register behavior in the fork's house style (`class PAS :
  public Module_base`, `control->GetSection`, `IO_Register*Handler`,
  `MIXER_AddChannel`, `PIC_*`, `DMA_*`, `AddExitFunction` —
  `innova.cpp`/`disney.cpp` are the templates). 86Box-isms through every
  integration point would sink an upstream PR; the register state machine
  arrives cleaner re-expressed. Keep `snd_pas16.c` as the executable oracle
  for behavioral diffs.

## References (local-only, NEVER committed)

`/tmp/pas_ref/` (downloaded 2026-09-18, kept out of the repo — licensing
hygiene, no mirrors):

- `snd_pas16.c` — 86Box PAS/Plus/16 emulation (123 KB). Behavioral oracle:
  port decode, register semantics, mixer tables, IRQ/DMA, PIT rate gen.
  Knowledge source, not code source.
- `PAS16_kernel_doc.html` — kernel OSS PAS16 docs (card support list,
  `pas2=` parameters, YM3812/OPL3 config notes).
- `nerdly_pas16.html` — card history + direct-hardware-write evidence.
- `86box_v42.html` — Plus/16/16D announcement (emulation-policy evidence).

Further programming detail (not yet fetched — stage 2 only if needed):
MIDAS `pas.inc` SDK fragment (mixer protocol, `INT 2Fh` hooks), Linux
`sound/oss/pas2_card.c` (GPL-clean register behavior cross-check).

## Hardware facts (from research 2026-09-18; verify against oracle at build)

- PAS16 (May 1992): 16-bit stereo record/play (MVA416 codec), MVA508 mixer,
  OPL3, Zilog SCSI, MPU-401 MIDI + game port, Thunder SB 2.0-compat side,
  MVD101 chipset. Base `0x388` (alts `0x384/0x38C/0x288`); PAS IRQ7/DMA3,
  SB side `220/IRQ5/DMA1`; jumperless, configured by `MVSOUND.SYS`.
- Register blocks (base-relative): `B88/B89/B8A/B8B` mixer+IRQ+filter,
  `F88–F8A` PCM, `1388–138B` PIT (rate/count, 1193180 Hz clock),
  `F388–F38B` IO config, `F788/F789/FB8A` SB/MPU compat, `178A/178B/1B88`
  MIDI, board/model IDs (`FC00`, `FF88`), wait states, sys-config nibbles.
- OPL3 side: wire to the fork's existing OPL emulation (no new FM code).
  MPU-compat bit: route through the fork's existing `mpu401.cpp`,
  following the house pattern for card-side MPU enablement.
- Explicitly out: NCR5380 SCSI side, SB-DSP side (fork has a real SB),
  Plus/16D/original-PAS variants, the game-side `pas_shim` driver.

## House style + annotation ruling

- New files carry the fork's GPL header (DOSBox Team form, current year),
  plus an attribution comment naming the knowledge sources (86Box
  `snd_pas16.c` authors, kernel docs). No 86Box expression copied; every
  behavioral block re-derived. Changes marked per GPL §2a from the first
  commit.
- Config section `[pas]`: `pas` (bool, default false), `pasbase`
  (`0x388`), `pasirq`, `pasdma`, `pasrate` — innova/disney key conventions.
- This repo's `lint_pret_labels`/annotation rules do NOT apply to the fork
  (C++ emulator code, not the NASM port); the fork's own build + warnings
  are the gate.

## Stages

- [x] **0. Branch + references.** `pas16` branch cut off `mcp-debug`
  (clean, in sync); four references in `/tmp/pas_ref/` (verified types).
- [ ] **1. Skeleton `src/hardware/pas.cpp`.**
  - [ ] 1.1 `class PAS : public Module_base`, `[pas]` section keys,
    `PAS_Init` declared/registered in `src/dosbox.cpp` beside
    `DISNEY_Init`/`INNOVA_Init`, teardown via `AddExitFunction`.
  - [ ] 1.2 Builds inside the fork tree, defaults off, zero behavior
    (port handlers registered but inert, or unregistered until stage 2 —
    agent picks the smaller diff, documents it).
  - Acceptance: fork builds clean (existing build path), no behavior
    change with `pas=false` (default).
- [ ] **2. Registers + mixer.**
  - [ ] 2.1 Base-relative port decode + register file (blocks above),
    re-expressed against `inout.h`.
  - [ ] 2.2 MV508 mixer with attenuation tables + PCM control semantics;
    mute/filter paths.
  - [ ] 2.3 Cross-check each block against `/tmp/pas_ref/snd_pas16.c`
    behavior (oracle, not source).
  - Acceptance: register reads/writes match oracle semantics (documented
    walk-through, no behavioral test harness yet).
- [ ] **3. Plumbing.**
  - [ ] 3.1 DMA + IRQ via fork `DMA_*`/`PIC_*` APIs; PIT rate generation.
  - [ ] 3.2 OPL side wired to existing OPL emulation; MPU-compat routed to
    `mpu401.cpp` per the house pattern.
  - Acceptance: PCM bytes in → mixer audio out in-emulator; OPL voices
    audible through the PAS mixer path.
- [ ] **4. Bring-up + validation.**
  - [ ] 4.1 Enable in the custom conf; validate with a known PAS program
    (MVDIAG or a native-support game).
  - [ ] 4.2 Behavioral cross-check vs 86Box running the same inputs
    (register traces and/or recorded audio diff).
  - Acceptance: native PAS program produces correct audio in our fork;
    becomes the golden oracle for the future game-side driver.
- [ ] **5. Docs + changelog.** Fork docs section, changelog entry, kept
  PR-shaped throughout. Upstream PR itself is deferred, not this plan's
  acceptance.

## Risks

86Box PAS has open sound-bug issues (#4313, #4441) — the oracle is
usable-but-imperfect; disagreements arbitrate toward docs + real-hardware
reports, never blindly toward either emulator. Fork merge drift: `pas16`
rebases onto `mcp-debug` if upstream moves under it. Scope creep into
SCSI/SB-DSP/MPU-new is the failure mode — stage definitions forbid it.
