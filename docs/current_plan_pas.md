# Current Plan: Pro Audio Spectrum 16 emulation in the DOSBox-X fork (`pas16` branch)

Status: **IN BUILD (round-robin subagents, serial per track; fork and game
tracks run in PARALLEL — disjoint files).** Emulator target is the PAS16
only; Plus + 16D join the FORK later (same 86Box set, game never uses them).
The game itself uses PAS16 only. `--no-verify` on commits while remote.

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
- [x] **1. Skeleton `src/hardware/pas.cpp`.**
  - [x] 1.1 `class PAS : public Module_base`, `[pas]` section keys
    (`pas`/`pasbase`/`pasirq`/`pasdma`/`pasrate`), `PAS_Init` declared +
    section registered in `src/dosbox.cpp`, `AddExitFunction` teardown.
    GPL header + attribution, zero 86Box-isms, no port handlers yet.
  - [x] 1.2 Build-list entry (`Makefile.am` one token; MSVC `vcxproj`
    deferred to a later stage).
  - Acceptance: no behavior change with `pas=false` (default); `PAS_Init`
    defined-not-yet-called (sdlmain call site is stage 2 entry).
- [x] **2. Registers + mixer.**
  - [x] 2.1 Base-relative port decode + register file (`pas_read`/
    `pas_write`, 15 windows; unmapped → 0xFF/ignore; 1388–8B uninstalled
    for stage-3 PIT; OPL aliases left live until stage-3 routing).
  - [x] 2.2 MV508 mixer (re-expressed dB tables, index/data protocol,
    Linux-driver reset defaults, mute/filter stored; FIR deferred).
  - [x] 2.3 Oracle cross-check per block (all agree with oracle code;
    four header-vs-code mismatches resolved toward code and noted).
  - Zero 86Box-isms; committed `1126a1416`, mirrored to `mcp-debug`.
- [x] **3. Plumbing.**
  - [x] 3.1 DMA + IRQ via fork `DMA_*`/`PIC_*` APIs; PIT rate generation
    (1388–8B window, 1193180 Hz, prescaler model; exact curve is stage 4).
    IRQ nibble-0 wrap resolved (`pas.irq` signed).
  - [x] 3.2 OPL side wired to existing OPL emulation (no new FM code;
    non-default bases need forwarder hooks — stage 4, that module's);
    MPU-compat routed per the house pattern. FIR + PIO samples deferred
    with STAGE4 notes.
  - Committed `7314402b0`, mirrored to `mcp-debug`. Open: sdlmain
    `PAS_Init()` call site (defined-not-yet-called).
- [x] **4. Bring-up + validation (static; no emulator execution).**
  - [x] 4.1 sdlmain `PAS_Init()` call site (+ forward decl; `pas.cpp`
    init signature aligned to the no-arg house shape). Card instantiates.
  - [x] 4.2 Validation trace conf → init → scripted sequence, oracle
    agreement per step (mixer, F8A, B88/89/8A, rate, IRQ/DMA maps,
    compat bases). Prescaler exact curve NOT resolved (oracle delegates
    to its PIT module; kernel doc silent) — divide-model kept with
    retirement note. PIO carries closed; FIR + OPL-forwarder + MPU/SB
    remap stay deferred with tightened notes.
  - Committed `b67113d13`, mirrored to `mcp-debug`.
- [x] **5. Docs + changelog.** `[pas]` section documented in both
  reference confs (generator-exact shape, `[innova]` mirror) + CHANGELOG
  entry under Next version. Committed `ff19e711e`, mirrored to
  `mcp-debug`. Follow-up (not this stage): MSVC `vs/dosbox-x.vcxproj`
  + `.filters` need `pas.cpp` entries; `setup.conf` installer variant
  needs the `[pas]` block.
- [ ] **6. Plus + 16D (fork only, after stage 4).** The 86Box-covered set
  joins the emulator; game never uses them. Scoped when stage 4 lands.

## Game track (PARALLEL — disjoint files, `dos_port/src/audio/`)

The game uses PAS16 only. Selection: word-2 nibble 2 = device 10
(`DEV_PAS`, after CMS 8 / Disney 9); `FORCE_PAS` = bit 10 of the already
dword `g_audio_forced`; flag `/PAS` (explicit-only, never auto-set; flag
IS the detection); `ENABLE_AUDIO_PAS` guard (new-convention shape);
`run-pas` (+`.ps1`) runner. Cry: PAS16 has no DAC path for the blob —
SB/speaker fallback, same as Tandy/GB (speaker KEEPS PCM under a PAS
winner).

- [x] **G1. Driver `src/audio/pas_shim.asm`** (NATIVE card programming —
  card's OPL3 at PAS_BASE 0x388; the SB-DSP emulation path was never in
  scope and appears nowhere in the file).
  - [x] G1.1 Skeleton: house header, `PAS_BASE` + OPL-alias equs,
    `PS_*` state, six globals + `g_pas_on`, guard + stubs. No DEVIATION.
  - [x] G1.2 Tick pass: ch0/ch1 → OPL3 voices 0-1, ch2 → voice 2 patch 4,
    ch3 → OPL noise voice 3 (PAS PCM engine needs DMA — later stage, not
    this tick); GB-unit envelope/sweep/length; restart-consume; NR50/NR51;
    MIDI SFX-only guard. `pas_init` no-ops silently when FM doesn't
    answer (present-flag merged with on-flag).
- [x] **G2. Dispatch + runner.** Device-10 solve arm (INNOVA shape, word-2
  nibble music+sfx `0x700`, no PCM; speaker keeps PCM-only; full priority
  TANDY > INNOVA > COVOX > GB > PAS > SPK documented in-code);
  `/PAS` end-to-end (flag → bit 10; config `device pas` via 0.5 mechanism);
  MIDI-coexistence verified (G1 guard correct); `ENABLE_AUDIO_PAS`
  passthrough + listing; `run-pas` (+`.ps1`, +x); window 9 repointed to
  cover PAS bytes (MIDI-head loss documented).
  - Acceptance (static traces walked): `/PAS` alone → PAS music+SFX;
    `/PAS`+`/TANDY` → TANDY wins; `/PAS`+`/MT32` → MIDI music + PAS SFX.
- [ ] **G3. Verification + ear-checks (static DONE, ears maintainer-run).**
  - [x] G3.0 Static: 5 traces re-walked (stub combo silent-no-hang,
    default dark; speaker PCM present under PAS, absent from PAS nibble);
    39/39 nasm matrix; lint 0, no new tokens; runner diff = swaps only,
    keys match precedent, `bash -n` clean; snapshot map (PAS file
    `0x23C..0x23F`, neighbors recorded).
  - [ ] G3.1 Cold boot `run-pas` → card-OPL3 music (snapshot `0x23C`
    tells probe failure from keying failure).
  - [ ] G3.2 Catch sequence (FM squares + patch-4 voice + OPL noise).
  - [ ] G3.3 Noise-heavy battle (no drone through rests).
  - [ ] G3.4 Pikachu cry via SB/speaker (`pika_dbg_device` 1 or 2, never
    a PAS value — no PAS arm exists by design).
  - [ ] G3.5 Tuner spot-checks (opl-derived mapping — A/B vs SB OPL run;
    report per-voice loudness deltas for the linear-v1 volume path).

## Enhancement direction (decided 2026-09-18; design deferred)

- PAS16 takes tier-1 enhancements (12-voice-class headroom philosophy —
  OPL3 + PCM engine can carry them).
- PCM rhythm tracks are the candidate tier-1+ vehicle: the PCM engine
  inherits the MT-32 rhythm-channel enhancements, voiced with real drum
  samples. Needs a drum-sample asset pipeline (later problem).
- Drum capture needed: real single-hit drums (kick, snare, closed hat
  minimum; toms/open hat/crash/ride stretch) — capture chain is USB-C
  digital boom mic into phone, uncompressed WAV 44.1/48 kHz, no
  processing, peaks ≈−12 dB. Convert down to the pipeline contract (mono
  8-bit 22050 Hz WAV) at the workstation; keep the high-rate masters.

## Risks

86Box PAS has open sound-bug issues (#4313, #4441) — the oracle is
usable-but-imperfect; disagreements arbitrate toward docs + real-hardware
reports, never blindly toward either emulator. Fork merge drift: `pas16`
rebases onto `mcp-debug` if upstream moves under it. Scope creep into
SCSI/SB-DSP/MPU-new is the failure mode — stage definitions forbid it.
