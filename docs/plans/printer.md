# Current Plan: Game Boy Printer Tier + DOS Printing Backend

Planned 2026-08-20 (planning-only session; maintainer-approved). Port pret's
Game Boy Printer engine faithfully and give it a port-only DOS printing backend
(ESC/P over LPT1, print-to-file, color enhancement). Completes "Group C: port
the Printer tier" of `docs/current_plan_script_linking.md` (the `HallOfFamePC`
half stays there) and graduates `celadon_mansion_3f.asm`,
`pokemon_fan_club.asm`, `summer_beach_house.asm` from `ITEMS_CHECK_SRCS`.

## Binding constraints

- **This plan does no serial/link-layer work** — it intercepts inside the
  printer engine at the software/hardware seam: no rSB/rSC emulation, no
  `home/serial.asm` work. (The 2026-08-17 "link stays unwired" directive was
  superseded 2026-08-21: `docs/current_plan_link_cable.md` now owns
  `home/serial.asm` and the transports. The two seams are disjoint — the
  printer keeps its in-memory device fork, the link plan keeps the serial
  mirror — and neither plan touches the other's cut point.)
- **Real printers cannot be verified** (maintainer, 2026-08-20). The backend is
  written strictly against the Epson ESC/P Reference Manual using the most
  conservative command subset, with runtime escape hatches (`/PRINT9`,
  `/PRNFILE`, documented constants). Every status claim is worded
  "spec-conformant" / "verified under DOSBox-X emulation" — NEVER "works on
  real hardware."
- Pret labels preserved; mirrors at `dos_port/src/<pret path>`; structured
  `DEVIATION{}`/`STUB{}` annotations; text strings generated; faithdiff +
  lint_pret_labels + static_gate per change; golden suite for behavior.

## Maintainer rulings (settled 2026-08-20)

1. **Projection for the four new print screens** (fan-club portrait, surfing
   high score, PC-box pages 1-4): GB-centered +10 col / +3 row, per the diploma
   precedent (`src/engine/events/diploma2.asm:52`). Record in
   `docs/ui_projection.md` during Stage 0.
2. **No-printer default**: pret's own error path ("Printer Error 2", B cancels)
   — matches real hardware with no printer attached. No silent file fallback.
3. **PCL deferred**: ESC/P (24-pin + 9-pin mode + color) and print-to-file ship
   now; the verified PCL grammar is recorded below for a possible future
   backend (untestable under DOSBox-X's Epson-only emulation).
4. **Design principle — the driver IS a virtual GB Printer, on the APU model.**
   Like the audio path (faithful GB APU model in front, OPL3/MT-32 enhancement
   at the output stage), the print path keeps a faithful GB Printer device
   model in front — it consumes the genuine packet protocol (INIT/DATA/PRINT,
   checksums, margins, exposure, palette byte) exactly as the real hardware
   would, minus the serial wire — and puts all enhancement (color, density
   modes) in the output backend. **Unlike music, there are NO manual per-item
   enhancement files (.yaml or otherwise)**: print enhancement is fully
   algorithmic — color resolves from CGB palette state captured at print time,
   dithering is deterministic from the exposure byte. Do not introduce an
   enhancement-data layer.

## Architecture

### The seam: full pret state machine + in-memory virtual GB Printer device

Port everything above `Printer_PrepareToSend` (pret `engine/printer/serial.asm:272`)
**verbatim** — the 20-state `PrinterTransmissionJumptable`, packet staging,
checksum, `Printer_Convert2RowsTo2bpp` band converter, `PrinterDataPacket1..6` —
and replace only the rSB/rSC kick inside `Printer_PrepareToSend` with
`call PrintDev_ConsumePacket` (port-only). One `DEVIATION{class=HAL}` at that
site is the entire hardware boundary.

- `PrintDev_ConsumePacket` reads what the wire would carry (`wPrinterDataHeader`,
  `wPrinterSendDataSource1` payload of `wPrinterDataSize` bytes,
  `wPrinterChecksum`) and interprets the four live packet shapes: INIT resets
  the band accumulator; DATA($280) appends one 640-byte 2bpp band; DATA(0)
  closes; PRINT (4-byte payload: sheets, margins `wcae2`, palette %11100100,
  exposure `wPrinterSettingsTempCopy`) renders the page via the backend. On
  completion it publishes `wPrinterHandshake=$81`, `wPrinterStatusFlags` per
  outcome, `wPrinterOpcode=0`. Completion is synchronous; the jumptable's
  opcode-wait falls through next frame, so pret's CHECKING LINK → TRANSMITTING
  → PRINTING status flow runs unmodified (same timing class as the port's
  synchronous `CopyVideoData` precedent).
- **Errors are real, not faked**: LPT open/write failure → handshake $FF /
  status $FF → pret `PRINTER_ERROR_2`; paper-out (int 17h status bit 5 /
  timeout) → status bit 5 → `PRINTER_ERROR_3`. `GBPrinter_CheckForErrors` is a
  verbatim translation. Battery/temperature bits stay unused.
- `Printer_StopIfPressB`'s direct cancel burst → `call PrintDev_Cancel` (HAL
  DEVIATION at the site).
- **`PrinterSerial_` (serial.asm:452-632) is NOT ported** — the per-byte
  interrupt pump is meaningless without a wire; the device consumes packets
  whole. Documented-unported header note (nothing links it; not a `STUB{}`).
  Likewise pret `home/printer.asm`'s `PrinterSerial` trampoline +
  `SerialFunction` VBlank poller stay unported; update
  `dos_port/src/home/printer.asm`'s header from "TODO-HW: serial" to
  "superseded by the in-memory device (this plan)".
- **printer2.asm's dead half stays unported**: `PrinterDebug` + its clone
  engine (~790 lines) — only caller is inside a pret `; unreferenced` block
  (`engine/movie/title.asm:209-213`). The live `Printer_GetMonStats` (fan-club
  portrait screen) IS ported in full.
- rIE/rIF save/restore in the entry points → GB-shadow writes per the
  surfing-minigame precedent (`src/engine/minigame/surfing_pikachu.asm:356-390`).

### Files, Makefile, WRAM

New pret mirrors (all labels keep pret names; every routine complete):
- `dos_port/src/engine/printer/serial.asm` — pret serial.asm:1-450 (state
  machine, staging, checksum, band converter, packet templates).
- `dos_port/src/engine/printer/printer.asm` — all 5 entry points
  (`PrintPokedexEntry`, `PrintPCBox`, `PrintDiploma`, `PrintFanClubPortrait`,
  `PrintSurfingMinigameHighScore`), page loops, `Printer_StopIfPressB`,
  tile-buffer copy pair, music helpers, error/status UI,
  `Printer_PrepareSurfingMinigameHighScoreTileMap`, `Diploma_Surfing_CopyBox`,
  `CopySurfingMinigameScore`, `PrintPCBox_DrawPage1..4`.
- `dos_port/src/engine/printer/printer2.asm` — `Printer_GetMonStats` + gfx
  includes.

Port-only backend — new `dos_port/src/print/` + `PRINT_SRCS` Makefile bucket
(model: `SAVE_SRCS`, Makefile:499-500):
- `src/print/print_dev.asm` — virtual GB Printer device (packet consumer, band
  accumulator ≤9×640 B, checksum verify, cancel, status/error mapping) +
  `g_cfg_prn*` flag bytes in its `.data` + `g_print_pal_buf` in `.bss`.
- `src/print/escp.asm` — ESC/P page emitter (dither, band assembly, color
  planes).
- `src/print/lpt_dos.asm` — DOS transport (LPT1 handle path, int 17h probe,
  `.PRN` file writer).

Integration:
- **Delete `src/engine/printer/printer_stubs.asm`** (loud-collision rule);
  `label_status --callers` sweep on `PrintPokedexEntry`/`PrintPCBox`; repoint
  extern comments (`src/engine/menus/pokedex.asm:127`,
  `src/engine/pokemon/bills_pc.asm:109`); revisit
  `Pokedex_PrepareDexEntryForPrinting`'s TODO-HW (pokedex.asm:1066+ — it
  finally gains its caller). `update_label_db` after retirement (serialized
  resource — never concurrent with another agent's build/rescan).
- Add `ReloadMapAfterPrinter` to `src/home/overworld.asm` (beside
  `ReloadMapAfterSurfingMinigame`). It is **load-bearing**: measured 2026-08-20,
  the port preserves pret's union — `wOverworldMap` = `wPrinterData` = 0xCE4A
  in the linked defines — so printing trashes the map buffer exactly as on GB.
- Reconcile `src/engine/events/diploma2.asm` with the newly real
  `Diploma_Surfing_CopyBox` label (faithdiff will flag today's dropped calls).
- Graduate the 3 scripts from `ITEMS_CHECK_SRCS` (Makefile:2983-2990); tick
  script_linking Group C (printer half).
- WRAM: `assets/pret_ram.inc:1198-1221` already carries the printer block at
  shifted addresses (`wPrinterData` 0xCE4A … `wPrinterTileBuffer` 0xD0DA …
  `wPrinterDataEnd` 0xD257; `wPrinterConnectionOpen` 0xE267, `wPrinterOpcode`
  0xE268). **One gap: `wcae2`** fails `gen_pret_ram.py`'s name filter —
  hand-add `%define wcae2 0xD244` to gb_memmap.inc, rerun
  `check_ram_collisions.py` + `audit_memmap.py`.
- **Stale-comment sweep (found 2026-08-20)**: gb_memmap.inc:1266-1278 echo-RAM
  layout comment and the "end = $F100" note above the `wOverworldMap` define
  still describe the pre-expansion $E800 location (CLAUDE.md's clamp paragraph
  too — flag to maintainer; CLAUDE.md edits are theirs). Fix while editing that
  region for `wcae2`.

Generated data (two-tier rule):
- `tools/generators/gen_printer_strings.py` → `assets/printer_strings.inc`
  (status texts pret printer.asm:582-629, PC-box strings, surf strings,
  printer2 `.OT`/`.IDNo`/`.Stats`/`.Blank`). Pointer tables stay hand-written
  `dd` in the `.asm`.
- Extend `gen_surfing_pikachu.py` (surfing_pikachu_2.2bpp + high_score_1/2
  tilemaps); new `gen_printer_gfx_inc.py` (gfx/printer/hp.1bpp + lv.1bpp).

Capture projection: `Printer_CopyTileMapToPrinterTileBuffer` (pret: flat
360-byte copy) becomes a parameterized 18-row gather (base offset + row-stride
descriptor set by each entry point beside its page draw; Pokédex uses its
stride-20 scratch, the other screens the GB-centered +10/+3 window). Inverse
for `Printer_CopyTileMapFromPrinterTileBuffer`. One
`DEVIATION{class=projection}` each.

### ESC/P backend (conservative, spec-only)

Grayscale default (verified against the Epson ESC/P Reference Manual,
files.support.epson.com/pdf/general/escp2ref.pdf):
- `ESC @`, `ESC U 1` (unidirectional), `ESC 3 24` (24/180" — gapless 24-dot
  bands; the value 24 is correct on BOTH 9-pin (n/216) and 24-pin (n/180)
  families — do not generalize it), then per band `ESC * 39 nL nH` (180×180
  dpi, 3 bytes/column, bit 7 = topmost dot) with 320 columns (2×2 scaling of
  the 160-px band ≈ 1.78" strip ≈ real GB Printer width), CR LF; margins via
  `ESC J` blank lines from the `wcae2` nibbles (fixed documented scale
  constant); final FF ejects deterministically (else the page waits on the
  emulator's `[printer] timeout`). **Avoid m=40/72/73** — reported corrupted
  in DOSBox-X's emulation.
- 4 GB shades → 2×2 ordered-dither cell (0 / 1 / 2-checker / 4 dots), scaled
  by the packet's exposure byte — the already-ported Options "PRINT:"
  brightness (`src/engine/menus/options.asm:338-395`) flows through untouched
  pret plumbing. The palette byte (%11100100) is honored as the shade mapping.
  Zero new UI.
- `/PRINT9`: conservative 9-pin mode, `ESC * 0` (60 dpi horizontal, 8-dot
  columns, 1×1; slight vertical squash on real 9-pin hardware accepted and
  documented).

Color (`/PRNCOLOR`, never auto-enabled — mono printers ignore `ESC r` and
would overstrike all planes black):
- Per band, one pass per plane with CR (no LF) between: `ESC r 4` yellow →
  `ESC r 1` magenta → `ESC r 2` cyan → `ESC r 0` black (K plane for dark
  pixels), yellow first (ribbon hygiene). Skip planes empty in the band.
  Leave the printer in black (`ESC r 0`) at job end.

Transport (`lpt_dos.asm`, the dsv_io reflected-int-21h idiom exactly —
`src/save/dsv_io.asm:40-89, 396-494`):
- AH=3Dh open literal `"LPT1"` (DOSBox-X registers LPT1..9, NO "PRN" alias);
  AX=4400h get device info **with DH=0** (pre-DOS-6 requirement), OR bit 5,
  AX=4401h set raw mode (**required** — DOS cooked mode stops output at the
  first 0x1A and expands tabs; proven from FreeDOS kernel `cooked_write`);
  AH=40h chunked writes; AH=3Eh close. Optional int 17h AH=02h presence probe
  → graceful error-2 instead of a hang. Failure: CF + `g_print_failed` + the
  GB status flags (pret's own error UI reports it).
- `/PRNFILE`: same ESC/P byte stream → `PRINT001.PRN` (first free name).
  Chosen over BMP: one emitter path, byte-diffable, host-convertible
  (PrinterToPDF renders color ESC/P); DOSBox-X's PNG output covers images.
- Trap noted for any future direct port I/O: the `out dx, al` EAX-aliasing
  pointer-corruption precedent (`boot/video.asm:229-241`). The handle path
  avoids port I/O entirely.

Flags: `/PRINT9`, `/PRNCOLOR`, `/PRNFILE` — bare tokens per the entry.asm
convention (`boot/entry.asm:75-82, 247-322`); flag bytes in print_dev.asm
`.data`; `dos_port/run:9` header updated. LPT2+ selector deferred (DOS device
names beyond LPT1 vary; that is a different transport — int 17h or direct I/O).

Deferred backends, documented for the future:
- **PCL** (grammar verified from HP's PCL Implementor's Guide raster chapter):
  `ESC E`; `ESC *t150R` resolution; `ESC *r1A` start raster; `ESC *b0M`
  compression; `ESC *b<n>W` per row; `ESC *rC` end; FF. Color = PCL3 planes
  `ESC *r-3U` (CMY) / `ESC *r-4U` (KCMY, DeskJet 550C+) with `ESC *b<n>V`
  (plane) / `ESC *b<n>W` (last plane of row). Not testable under DOSBox-X
  (Epson-only emulation) — that is why it is deferred.
- **PostScript**: print-to-file territory; not a DOS-era popular-printer
  protocol.

### Color capture: port-only palette sidecar

At `Printer_CopyTileMapToPrinterTileBuffer` time, also capture per-cell color:
tile ID → physical tile index (same signed $8000/$9000 addressing as
`Printer_Convert2RowsTo2bpp`) → `tile_pal[phys]` (`src/ppu/ppu.asm`) →
`bg_slot_pal[slot]` palette ID (`src/home/palettes.asm:68`) → one byte in
`g_print_pal_buf` (360 bytes, `.bss` of print_dev.asm — NOT in GB WRAM, per
the squatter-eviction rule at gb_memmap.inc:1394-1399). RGB resolved at
emission from `pal_rgb_table` (RGB6 ×255/63 — the `tools/render_frame.py` /
PAL.BIN math), then CMY(K) plane dither. Snapshot at capture time is mandatory
(`PrintPokedexEntry` redraws the dex UI while page 1 "transmits"). BG tiles
only (the GB print raster is BG-only; the fan-club photo is drawn as BG
tiles). Annotation: `DEVIATION{class=HAL}` at the capture routine (read-only
over renderer state, feeds the device below the seam, invisible to pret code).

### Verification

- **No tracked-conf changes**: repo confs stay printer-less. New
  `tools/printcheck.sh` (modeled on run_headless.sh) sed-derives a conf adding
  `parallel1=printer` + a `[printer]` section with `docpath` pinned to its
  scratch dir, launching the fork binary `tools/dosbox-x-mcp/dosbox-x-mcp`
  (verifiably built `--enable-printer`; measured 2026-08-20 the system
  /usr/bin/dosbox-x also has printer support, but the fork is the harness
  binary).
- **Automated pixel regression** — new port-only scenario class (e.g.
  `portonly_print`) in `tools/scenario_manifest.json` / golden_diff.py:
  artifact is the emitted page PNG set (`printoutput=png`, fixed dpi,
  `multipage=false`), compared against committed goldens. mGBA cannot produce
  printer output, so this class is port-only by design. **First task: a
  determinism probe** (two identical runs, pixel diff) before blessing any
  golden. Scenarios: (1) beach-house machine print (shortest path, no minigame
  prerequisite — seed save + autokey); (2) Pokédex PRNT with an owned mon
  (two-page path, both margin values). DOSBox-X's printer renders `ESC r`
  color (verified in its printer.cpp source, 2026-08-20 — the wiki's "B/W
  only" note is stale), so the color variant gets a color PNG golden.
- **One mGBA-comparable GBSTATE golden** — `print_surf_cancel`: in mGBA with
  no printer the serial reads $FF → pret deterministically lands on ERROR_2;
  the scenario prints, waits, presses B, dumps GBSTATE. The port runs the same
  keys (its print succeeds — mask transmission-state/status/handshake bytes),
  comparing the 360-byte `wPrinterTileBuffer` + `wcae2` +
  `wPrinterSettingsTempCopy`. This cross-checks the capture layer against
  ground truth.
- **Human PDF loop**: `printcheck.sh --ps` → `printoutput=ps, multipage=true`
  → doc1.ps → `ps2pdf` (measured installed 2026-08-20; there is NO CUPS on
  this host — the "virtual printer" in GTK apps is toolkit-internal
  Print-to-File, unreachable from DOSBox-X, and `printoutput=printer` is
  WIN32-only in the fork source). Optional cross-check: `parallel1=file` raw
  capture byte-diffed against `/PRNFILE` output (identical streams expected).
- **Gates per change**: `make assets` → build → `faithdiff` per ported label →
  `lint_pret_labels --no-scan --strict-claims` (0) → `static_gate` →
  `make fidelity` core; full suite before merge.

## Stages

### Stage 0 — groundwork (no behavior)
- [x] Add `%define wcae2 0xD244` to gb_memmap.inc (union comment included);
      `check_ram_collisions.py` + `audit_memmap.py` clean
- [x] Sweep the stale pre-expansion wOverworldMap comments
      (gb_memmap.inc:1266-1278 + the "end = $F100" note); flag CLAUDE.md's
      clamp-paragraph addresses to the maintainer
- [x] `gen_printer_strings.py` → `assets/printer_strings.inc`; extend
      `gen_surfing_pikachu.py`; new `gen_printer_gfx_inc.py`; wire into
      `make assets`
- [x] Record the GB-centered +10/+3 ruling for the four print screens in
      `docs/ui_projection.md`

### Stage 1 — serial.asm mirror (state machine)
- [x] Translate `dos_port/src/engine/printer/serial.asm` (pret :1-450);
      `Printer_PrepareToSend` → minimal ACK-only `PrintDev_ConsumePacket`
      (handshake $81 / flags 0 / opcode 0, data discarded)
- [x] `PrinterSerial_` documented-unported header note; faithdiff + lint
      clean; assembles (check-only until Stage 2 links)

### Stage 2 — printer.asm/printer2.asm mirrors + integration
- [x] Translate `dos_port/src/engine/printer/printer.asm` in full (entry
      points, parameterized capture pair + projection DEVIATIONs,
      `Printer_StopIfPressB` → `PrintDev_Cancel`, error/status UI, surf
      high-score tilemap builder, PC-box pages)
- [x] Translate `Printer_GetMonStats` (printer2.asm); PrinterDebug half
      documented-unported
- [x] `ReloadMapAfterPrinter` in `src/home/overworld.asm`; reconcile
      diploma2.asm with `Diploma_Surfing_CopyBox`
- [x] Delete `printer_stubs.asm`; `label_status --callers` sweep; repoint
      externs; `update_label_db`
- [x] Graduate the 3 scripts from `ITEMS_CHECK_SRCS`; tick script_linking
      Group C (printer half)
- [x] Gate: build + static_gate + fidelity core + visual DOSBox-X pass of all
      5 entry points (ACK-only device: full UI flow, instant "print")

### Stage 3 — real virtual device + capture golden
- [x] `print_dev.asm` proper: packet parse, band accumulation (≤9×640 B),
      checksum verify, cancel, status/error mapping contract
- [x] `print_surf_cancel` GBSTATE golden (mGBA ground truth, masked
      transmission state, tile-buffer comparison)

### Stage 4 — ESC/P grayscale + transport + flags
- [x] `escp.asm`: init/spacing/band loop per the verified sequences; 2×2
      exposure-scaled dither; margins via ESC J; FF; `/PRINT9` m=0 mode
- [x] `lpt_dos.asm`: reflected-int-21h LPT1 open + raw-mode IOCTL (DH=0) +
      chunked AH=40h writes + int 17h probe; errors → GB status flags;
      `/PRNFILE` → PRINTnnn.PRN
- [x] entry.asm tokens `/PRINT9 /PRNCOLOR /PRNFILE`; `dos_port/run` header
- [x] `tools/printcheck.sh` (fork binary, scratch docpath); PNG determinism
      probe; bless beach-house + Pokédex PNG goldens under the new
      `portonly_print` scenario class; `--ps` PDF path for human review

### Stage 5 — color
- [x] Palette sidecar capture (`g_print_pal_buf`) + HAL DEVIATION at the
      capture routine
- [x] CMY(K) plane dither + `ESC r` pass loop (yellow→magenta→cyan→black);
      `/PRNCOLOR` gating; color PNG golden variant

### Stage 6 — docs + bookkeeping
- [x] Evidence-discipline wording sweep (docs, comments, this plan's status
      lines): "spec-conformant + verified under DOSBox-X emulation" only
- [x] Stigmergy feature memory updated to final state;
      `link-layer-planned-transports` not touched by PRINTER work (it is now
      owned by `docs/current_plan_link_cable.md` Stage 0, reopened 2026-08-21)
- [x] Archive: `git mv docs/current_plan_printer.md docs/plans/printer.md`

## Key references for implementers

- Epson ESC/P Reference Manual — `ESC *` density table, `ESC 3`/`ESC J`,
  `ESC r` (files.support.epson.com/pdf/general/escp2ref.pdf).
- DOSBox-X fork source `dos_port/tools/dosbox-x/src/hardware/parport/
  printer.cpp` — implemented command set (m=0-6/32-40/71-73), `ESC r` color
  with OR-composited palette, `outputPage` backends (`printer` is WIN32-only).
- FreeDOS kernel `chario.c` `cooked_write` — the 0x1A stop / tab expansion
  that makes raw mode mandatory.
- pret cut-point map: seam at `engine/printer/serial.asm:272`
  (`Printer_PrepareToSend`); band = 640 B = 40 tiles 2bpp; PRINT payload =
  sheets/margins/palette/exposure (serial.asm:355-364).
- Port idioms: `src/save/dsv_io.asm` (reflected int 21h),
  `boot/entry.asm` (flag parsing), `tools/render_frame.py` (RGB6 math),
  `tools/run_headless.sh` (harness shape).
