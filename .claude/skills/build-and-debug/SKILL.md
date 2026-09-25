---
name: build-and-debug
description: >
  Build, run, and debug reference for the Pokémon Yellow DOS port. Invoke when
  building or running the port, regenerating assets, configuring/launching
  DOSBox-X, debugging emulated GB memory (DUMP.BIN / FRAME.BIN dumps, or the
  live dosbox-mcp screenshot / dump_frame tools), running the golden fidelity
  harness (mGBA ground truth vs DOSBox-X port), auditioning music (host-side
  dgad vs in-DOS DEBUG_AUDIO TRACK= loop), or using a dos_port/tools/
  dev tool (colorize.py + colors/editor.py, map_editor/editor.py, ui_layout/editor.py,
  read_perf.py, read_seamlog.py, audit_memmap.py, unnamed.py, saveconv.py).
  Also holds the repo layout map and the key reference URLs. Triggers: "build the port",
  "make -C dos_port", "SKIP_TITLE", "make assets", "regenerate assets",
  "DEBUG_DUMP / DEBUG_TRANSITION / DEBUG_WALK_NORTH", "FRAME.BIN", "render_frame.py",
  "DOSBox-X config", "linker section / .rodata / orphan section",
  "goldencheck / make fidelity / make goldens", "GBSTATE.BIN",
  "golden scenario / scenario_manifest.json / mGBA harness / mgba-mcp",
  "run_headless.sh / headless run / PKMN.IMG / mcopy",
  "static_gate / pre-commit hook / CI", "audition / listen to / play <track> music",
  "DEBUG_AUDIO / TRACK= / dgad / MUNT", "where is <file> in the repo",
  "Pan Docs / DPMI spec / RBIL", "colorize.py / palette editor / repaint PNG",
  "map_editor / overworld map tool", "ui_layout editor / layout sidecar",
  "PERF.BIN / read_perf.py", "SEAMLOG.BIN / read_seamlog.py", "audit_memmap.py",
  "unnamed.py / unnamed symbols", "saveconv.py / .sav .dsv",
  "screenshot / take a picture of the screen",
  "page fault / DPMI register dump / what is on screen", "raw screenshot",
  "tile_inspector.py / tile coordinates / inspect tiles / P: (y, x) / R: [y0, y1]×[x0, x1]".
---

# Build & Debug Reference

Everything for building, running, and getting ground truth out of the DOS port.
Deep reference materials, debugger protocols, and tool manuals have been modularized into `references/` within this skill directory.

---

## Repo Layout & Architecture

```
/                          ← pret/pokeyellow SM83 source (read-only reference)
  constants/hardware.inc   ← GB hardware register definitions (offsets reference)
  home/, engine/           ← core GB routines (translation source)
  ram/wram.asm, hram.asm   ← GB memory layout definitions
dos_port/
  include/
    gb_memmap.inc          ← EBP-relative offsets for GB memory regions
    gb_macros.inc          ← BUG_FIX_LEVEL macro, BUG/GLITCH comment conventions
  boot/
    entry.asm              ← DPMI entry, memory alloc, CLI flags, main loop
    video.asm              ← VGA Mode 13h setup, 1:1 native 320×200 present
    timing.asm             ← PIT 60 Hz tick ISR, vblank sync
  src/home/, src/engine/   ← faithful x86 translations of pret routines
  src/ppu/ppu.asm          ← software PPU: native-width BG surface + window + OAM
  src/input/joypad.asm     ← INT 9h keyboard ISR → GB joypad state
  tools/
    README.md              ← directory map (generators vs tools vs shared libs)
    generators/            ← gen_*.py Tier-1 asset generators (make assets)
    dsv2sav.c              ← portable standalone C save converter (DOS .dsv ↔ GB .sav)
    static_gate            ← whole-tree static lint ratchet (run by pre-commit)
    fidelity_gate          ← per-change, per-label fidelity verification chain
    run_headless.sh        ← headless execution and dump extraction harness
    scenario_manifest.json ← golden-scenario registry (core and full tiers)
    dosbox_mcp/            ← MCP server for live symbolic DOSBox-X debugging
    dosbox-x/              ← dosbox-x submodule (branch mcp-debug)
    mgba/, mgba_harness/   ← mGBA submodule + Lua fidelity runner
    goldencheck.sh         ← build + headless run of one scenario vs its golden
    golden_diff.py         ← structural state differ (tilemap, VRAM, OAM, WRAM)
docs/
  assembly.md              ← full build flags, toolchain, container bootstrap
  testing.md               ← testing tiers overview and gate disciplines
  references/README.md     ← index of local Pan Docs, RBIL, DPMI, and Mode 13h docs
```

---

## Toolchain & Linker Sections

- **Assembler**: NASM (Intel syntax, `-f coff -I include/ -I . -O0`).
- **Target**: 386+, 32-bit protected mode via CWSDPMI.
- **Linker**: `i386-pc-msdosdjgpp-ld` (from `binutils-djgpp`). Linker script: `dos_port/link.ld`.
- **Entry Point**: `start` (not `_start`).
- **Interactive Shell is zsh, NOT bash**: Unquoted `$var` is not word-split; use `${=var}` or pass args explicitly. Array indexing is 1-based, and `$pipestatus[1]` is used instead of `$PIPESTATUS`.

> [!CRITICAL]
> **Linker Sections & Orphan Section Hazard**:
> `link.ld` must explicitly map every input section into a loaded output section (`.text` / `.data`). The `coff-go32-exe` loader only loads sections recorded in its headers. Any **orphan section** ld places elsewhere receives a VMA, but its bytes **never reach memory at runtime**, silently reading back as zeros with **no page fault**. All embedded asset data must reside in `.data` (or `.text`), never in unmapped sections like `.rodata`.

---

## Build Commands & Workflow

Full reference: [docs/assembly.md](../../docs/assembly.md) (build flags, fresh container bootstrap, DOSBox-X configuration).

Output binary is **`dos_port/PKMN.EXE`** packaged inside partitioned FAT disk image **`dos_port/PKMN.IMG`**.

```sh
# Reference ROM (requires rgbds pinned in .rgbds-version — 1.0.3)
make compare

# Build DOS port (PKMN.EXE + PKMN.IMG)
make -C dos_port
make -C dos_port SKIP_TITLE=1          # bypass title screen, boot straight to overworld
make -C dos_port BUG_FIX_LEVEL=1       # 1=critical fixes, 2=all fixes

# Asset regeneration (required after changing generators or pret source)
make -C dos_port assets                # regenerates out-of-date assets/*.inc
make -C dos_port regen                 # force-regenerates all Tier-1 assets

# Build & Run convenience scripts
dos_port/build                         # build wrapper (passes arguments to make)
dos_port/run                           # build + launch in DOSBox-X (uses dosbox-x.conf)
dos_port/run SKIP_TITLE=1              # boot directly into Pallet Town
dos_port/run /NOSOUND /LOOP            # arguments with '/' pass directly to PKMN.EXE

# Clean targets
make -C dos_port clean                 # safe: removes $(ALL_OBJS), PKMN.EXE, .nasmflags, pkmn.sym
make -C dos_port clean-image           # deletes PKMN.IMG (also clears any internal save)

# Quick syntax check of a single source file
nasm -f coff -I dos_port/include -I dos_port -o /dev/null dos_port/src/home/copy2.asm
```

> [!WARNING]
> **Avoid root-level `make clean` / `make tidy`.** It wipes pre-built graphics intermediates (`.2bpp`) needed by `make assets`. Only use `make -C dos_port clean`.
> **Never hand-edit generated `assets/*.inc` files.** Edit the generator or sidecar JSON and re-run `make assets`.

---

## Debugging: Emulated GB Memory & Headless Dumps

The screen is rendered via a software PPU: distinct logic bugs frequently collapse to the same "all-white" or "all-garbage" image. **Do not debug by staring at pixels.** Inspect ground truth in emulated GB memory at `[EBP + addr]`.

### Memory Dumps (`DUMP.BIN`)
`src/debug/debug_dump.asm` exfiltrates raw emulated GB memory windows to `DUMP.BIN` on the emulated C: drive (inside `PKMN.IMG`) with no PPU or palette confound. Edit the `windows:` table in `debug_dump.asm` to target specific addresses.

### Back-Buffer Dumps (`FRAME.BIN`)
`src/debug/debug_dump.asm:DumpBackbuffer` writes the raw software-PPU back buffer (`GB_BACKBUF`, 320×200 8bpp palette-indexed bytes) to `FRAME.BIN`:
```sh
# Render FRAME.BIN to PNG on host (uses conspicuous debug palette unless PAL.BIN is supplied)
python3 dos_port/tools/render_frame.py FRAME.BIN out.png [PAL.BIN]
```

### Scripted Headless Execution (`run_headless.sh`)
Always use `dos_port/tools/run_headless.sh` for headless probes. It automatically creates a scratch copy of `PKMN.IMG`, removes stale dumps, attaches an auto-exit configuration, runs under dummy SDL drivers, and extracts output artifacts:
```sh
dos_port/tools/run_headless.sh "DEBUG_DUMP=1" /tmp/probe
# Inspect /tmp/probe/DUMP.BIN or /tmp/probe/FRAME.BIN on host
```

> [!WARNING]
> **Image Contention Trap**: If an interactive `dos_port/run` session is open, it holds `PKMN.IMG` open read-write. Running headless against the same image will silently lose output dumps due to cached FAT writeback conflicts. `run_headless.sh` and `goldencheck.sh` operate on copies of the image to avoid this.

### Enumerating `DEBUG_*` Flags
There are ~112 compile-time debug harnesses in `dos_port/Makefile` (e.g. `DEBUG_TRANSITION`, `DEBUG_WALK_NORTH`, `DEBUG_BAGMENU`, `DEBUG_ANIM_DEMO=1 ANIM=<MOVE>`, `DEBUG_AUDIO`):
```sh
grep -ohE 'DEBUG_[A-Z0-9_]+' dos_port/Makefile | sort -u
```

---

## Live Symbolic Debugging via `dosbox-mcp`

The `dosbox-x-mcp` fork and `tools/dosbox_mcp/server.py` MCP server provide interactive symbolic debugging: execution breakpoints, watchpoints, disassembly, and register/memory inspection.

### Launching
```sh
dos_port/run-mcp [make args] [/EXE flags]
```
Launches DOSBox-X with the live MCP socket bridge connected.

### Canonical MCP Workflow
1. `pause_exec()` — pause free-running emulator.
2. `set_breakpoint("OverworldLoop")` — arm breakpoint on any symbol in `pkmn.sym` (global or local) or hex address.
3. `continue_exec()` — resume execution and await breakpoint.
4. `wait_break()` — collect break notification without tearing down socket.
5. `where()` — inspect nearest symbol at or below `EIP`.
6. Inspect state with `get_registers()`, `gb_read()`, `x86_read()`, `disassemble()`, `dump_frame()`, or `screenshot()`.

### `dump_frame` vs `screenshot`

| Method | Source | Requirements | Captures Crash/Console? |
|---|---|---|---|
| `dump_frame` | PPU back buffer (`GB_BACKBUF`) | Live game in pmode, selectors valid | No (fails on fault) |
| `screenshot` | Emulated display output | Any emulator state | **Yes** — captures DPMI page faults and console text |

### Essential Debugger Traps
1. **BP vs BPLM**: `set_breakpoint` sets an execution breakpoint. `set_watchpoint` (`BPLM`) is a memory-change watchpoint (never fires on unchanged code bytes).
2. **Double-Quote Hex Literals**: Expression parser parses unquoted `AF`, `BP`, `DX` as registers/flags. Always double-quote: `EV "AF"`.
3. **RUN-Outstanding Rule**: While a RUN is pending, `wait_break()` is the **only** call that can proceed. If the guest hangs upstream of breakpoints, trigger break manually with `Alt+Pause`.
4. **Process Management**: **NEVER `pkill -f dosbox`** (this kills `server.py` and disconnects MCP tools). Kill the binary specifically: `pkill -f dosbox-x-mcp`.

> [!WARNING]
> **Required Subskill**: If your task touches debugger internals, SYMF symbol loading, selector translation, or socket timeouts, you **MUST read [`references/dosbox_mcp.md`](references/dosbox_mcp.md) in full** using the read tool before proceeding. Do not guess protocols or rely on memory.

---

## Human-LLM Paired Debugging: Tile & Coordinate Inspector (`tile_inspector.py`)

When inspecting on-screen rendering, NPC coordinates, or UI alignment with the user, use `tile_inspector.py`.

```sh
python3 dos_port/tools/tile_inspector.py [image_or_FRAME.BIN] [--zoom 3]
```

### Coordinate Contract
Coordinates prioritize native Game Boy **$(Y, X)$ order** (row $0 \dots 24$, column $0 \dots 39$ on 320×200 canvas):
- **Points ($P$)**: `P: (Y1, X1); (Y2, X2)`
- **Rectangular Ranges ($R$)**: `R: [Y_min, Y_max]×[X_min, X_max]` (closed inclusive bounds)
- **Combined**: `P: (12, 10) | R: [10, 14]×[5, 8]`

### Coordinate Interpretation
1. **`wTileMap` Offset**: Offset in `[EBP + wTileMap]` is `Y * 40 + X` (stride 40).
2. **Centered GB Viewport**: $(GB\_Y, GB\_X) = (Y - 3, X - 10)$.
3. **Pixel Bounds**: $Y \in [Y \times 8, (Y+1) \times 8 - 1]$, $X \in [X \times 8, (X+1) \times 8 - 1]$.
4. **Overworld Step**: $Step\_Y = \lfloor Y / 2 \rfloor$, $Step\_X = \lfloor X / 2 \rfloor$.

---

## Golden Fidelity Harness (mGBA Ground Truth vs DOS Port)

Compares port state (`GBSTATE.BIN`) byte-for-byte against mGBA executing the sha1-verified golden ROM (`pokeyellow.gbc`).

### Commands
```sh
# Run one scenario end-to-end (build → headless run → diff)
make -C dos_port goldencheck SCENARIO=status_p1

# Run core pre-commit tier in parallel (~30s)
make -C dos_port fidelity

# Run full active scenario manifest in parallel
make -C dos_port fidelity-full

# Query current scenario manifest count and tiers
python3 dos_port/tools/validate_scenarios.py
```

### Essential Rules & Gotchas
- **Asset-Drift Caveat**: Fidelity gates copy assets without regenerating them. If you edited anything under `tools/generators/`, run `make -C dos_port assets` first.
- **Mask Justification**: Any divergence mask in `golden_diff.py` requires a written `why` string citing an open finding ID. (See the `faithfulness-review` skill).
- **False Witness Discipline**: Confirm the scenario's entry gate reaches the code under test. If changing a parameter produces byte-identical dumps, the scenario is not observing your routine.

> [!WARNING]
> **Required Subskill**: If your task involves debugging fidelity failures, `pgate.sh` runner mechanics, `GBSTATE.BIN` v2 format, or scenario registration, you **MUST read [`references/golden_fidelity.md`](references/golden_fidelity.md) in full** using the read tool before proceeding. Do not guess protocols or rely on memory.

---

## Other Dump Decoders & Static Audits

```sh
# Per-stage frame timing (from DEBUG_PERF build)
dos_port/tools/read_perf.py PERF.BIN
dos_port/tools/read_perf.py PERF.BIN --baseline OTHER.BIN

# Map connection walk trace (from DEBUG_SEAM build)
dos_port/tools/read_seamlog.py SEAMLOG.BIN

# Emulated GB address space overlap and boundary audit
dos_port/tools/audit_memmap.py

# Find symbols pkmn.sym could not resolve (missing global detection)
dos_port/tools/unnamed.py dos_port/pkmn.sym
```

---

## Interactive Dependency Graph & Call Analysis

Browser viewer and REST API for pret and DOS-port call graphs from `tools/translation.db`:
```sh
# Interactive browser viewer
python3 dos_port/tools/dependency_graph.py

# Headless server for agent REST queries
python3 dos_port/tools/dependency_graph.py --no-browser --port 8766
```

### Provenance Rule: `display_status` vs `status`
- The call scanner models pret `home/` and `engine/` only.
- Faithful labels from `audio/`, `data/`, `gfx/`, `ram/`, or `scripts/` land in `status = "port_only"` **by elimination**.
- The viewer resolves these via `aux_labels` / `script_labels` and displays them as **`pret-unmodeled`**.
- A label is genuinely bespoke only when `display_status == "port_only"` **AND** `aux_pret_file` is null.
- Indirect dispatch tables (`dd Label`) and ISR vectors emit no static edges; do not treat missing graph edges as proof of unreachability.

> [!WARNING]
> **Required Subskill**: If you are automating call graph queries, accessing the API manually, or integrating with the REST API (`/api/graph/pret`, `/api/graph/port`, `/api/meta`), you **MUST read [`references/dependency_graph_api.md`](references/dependency_graph_api.md) in full** using the read tool for schemas and query patterns before proceeding.

---

## Asset-Authoring Tools (Palettes, Maps, UI Layout)

Interactive pygame tools that author sidecar JSON, which `make assets` compiles to `assets/*.inc`.

```sh
# Palettes CLI & pygame shade editor
dos_port/tools/colorize.py --gen                    # compile sidecar to assets/colors/palettes.inc
dos_port/tools/colorize.py --verify                 # check sidecar validity and freshness
dos_port/tools/colorize.py --edit                   # launch pygame shade editor

# Overworld map viewer and block painter
python3 dos_port/tools/map_editor/editor.py

# UI layout editor on native 320x200 canvas
python3 dos_port/tools/ui_layout/editor.py dos_port/assets/ui_layout_<subsystem>_sidecar.json
python3 dos_port/tools/generators/gen_ui_layout.py <subsystem>
```

> [!WARNING]
> **Two-Tier Rule**: Never hand-edit `assets/*.inc`. Edit the sidecar JSON and regenerate via `make assets`.

> [!WARNING]
> **Required Subskill**: If you are authoring or modifying palettes, maps, or UI layouts, you **MUST read [`references/asset_authoring.md`](references/asset_authoring.md) in full** using the read tool for keybindings, preview modes, and sidecar schemas before editing.

---

## Save File Conversion (`dsv2sav.c`)

The port uses the `.dsv` **version 2** save format (7-byte header with `DOSV` magic, version byte `0x02`, 16-bit additive checksum, and a 32,768-byte raw SRAM payload matching standard GB `.sav` bank order).

Standalone, zero-dependency C implementation:
```sh
# Compile standalone C converter
gcc -O2 -std=c99 dos_port/tools/dsv2sav.c -o dos_port/tools/dsv2sav

# Convert between formats
dos_port/tools/dsv2sav --to-sav POKEMON.DSV POKEMON.SAV   # DOS .dsv -> GB .sav
dos_port/tools/dsv2sav --to-dsv POKEMON.SAV POKEMON.DSV   # GB .sav -> DOS .dsv

# Validate header and checksum (includes DeSmuME footer detection)
dos_port/tools/dsv2sav --verify POKEMON.DSV
```
Detailed binary structure and checksum mechanics live in the `project-conventions` skill and [dos_port/src/save/dsv_io.asm](file:///mnt/sdb1/Code/Active%20Code/pokeyellow_msdos/dos_port/src/save/dsv_io.asm).

---

## Auditioning Music

The music and SFX audition workflow is documented in `audio-enhance-opl3` and `audio-enhance-mt32`:
- **Host-side iteration**: `dgad --headless --track <Song> --device <mt32|gm|opl3|gbapu|imfc> --out take.wav` (batch render; `audition.py` is deprecated).
- **In-DOS verification**: `dos_port/run DEBUG_AUDIO=1 TRACK=<MUSIC_*> /LOOP`.

---

## Key Reference Documents

All primary reference materials are indexed and mirrored locally in **`docs/references/README.md`**:
- **Pan Docs** (GB hardware): [docs/references/pandocs/](file:///mnt/sdb1/Code/Active%20Code/pokeyellow_msdos/docs/references/pandocs/)
- **Ralf Brown's Interrupt List (RBIL)**: https://www.delorie.com/djgpp/doc/rbinter/
- **DPMI 0.9 Specification**: https://www.phatcode.net/res/262/files/dpmi09.html
- **DJGPP Hardware/Interrupt FAQ**: https://www.delorie.com/djgpp/v2faq/faq18.html
- **Michael Abrash Graphics Programming Black Book**: Mode 13h and VGA architecture.
