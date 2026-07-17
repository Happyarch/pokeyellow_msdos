---
name: build-and-debug
description: Build, run, and debug reference for the Pokémon Yellow DOS port. Invoke when building or running the port, regenerating assets, configuring/launching DOSBox-X, debugging emulated GB memory (DUMP.BIN / FRAME.BIN dumps instead of screenshots), running the golden fidelity harness (mGBA ground truth vs DOSBox-X port), auditioning music (host-side audition.py vs in-DOS DEBUG_AUDIO TRACK= loop), or using a dos_port/tools/ dev tool (colorize.py + colors/editor.py, map_editor/editor.py, ui_layout/editor.py, read_perf.py, read_seamlog.py, audit_memmap.py, unnamed.py, saveconv.py). Also holds the repo layout map and the key reference URLs. Triggers: "build the port", "make -C dos_port", "SKIP_TITLE", "make assets", "regenerate assets", "DEBUG_DUMP / DEBUG_TRANSITION / DEBUG_WALK_NORTH", "FRAME.BIN", "render_frame.py", "DOSBox-X config", "linker section / .rodata / orphan section", "goldencheck / make fidelity / make goldens", "GBSTATE.BIN", "golden scenario / mGBA harness / mgba-mcp", "audition / listen to / play <track> music", "DEBUG_AUDIO / TRACK= / audition.py / MUNT", "where is <file> in the repo", "Pan Docs / DPMI spec / RBIL", "colorize.py / palette editor / repaint PNG", "map_editor / overworld map tool", "ui_layout editor / layout sidecar", "PERF.BIN / read_perf.py", "SEAMLOG.BIN / read_seamlog.py", "audit_memmap.py", "unnamed.py / unnamed symbols", "saveconv.py / .sav .dsv".
---

# Build & Debug Reference

Everything for building, running, and getting ground truth out of the DOS port.
The critical linker one-liner (embedded data → `.data`; new sections must be
mapped in `link.ld`) lives in `CLAUDE.md`; the full explanation is here.

## Repo Layout

```
/                          ← pret/pokeyellow SM83 source (read-only reference)
  constants/hardware.inc   ← GB hardware register definitions (use for offsets)
  home/                    ← core GB routines (translation source)
  ram/wram.asm, hram.asm   ← GB memory layout definitions
  docs/bugs_and_glitches.md  ← known bugs in the original (reference for BUG tags)
  tools/                   ← pret's build tools (gfx.c, pkmncompress.c, etc.) — DO NOT EDIT
dos_port/
  include/
    gb_memmap.inc          ← EBP-relative offsets for GB memory regions
    gb_macros.inc          ← BUG_FIX_LEVEL macro, BUG/GLITCH comment conventions
  boot/
    entry.asm              ← DPMI entry, memory alloc, /FIXALL|/FIXCRIT parsing, main loop
    video.asm              ← VGA mode 13h, test pattern, 2× blit
    timing.asm             ← PIT 60 Hz, tick ISR, vblank sync
  src/util/
    fill_memory.asm        ← first translated routine (FillMemory)
  src/ppu/
    ppu.asm                ← software PPU: BG tile decoder + tilemap renderer
  src/input/
    joypad.asm             ← INT 9h keyboard ISR → GB joypad state
  tools/
    README.md              ← wayfinding map of this directory (generators vs
                             human-facing tools vs shared libraries)
    generators/            ← every gen_*.py Tier-1 asset generator (~60 files,
                             invoked by `make assets`, not run standalone —
                             see gen_all_assets.py / gen_map_headers.py / etc.)
                             + gb_text.py (charmap-encode helper) + gen_symfile.py
                             (PKMN.EXE COFF symtab → pkmn.sym, runs at every link)
    render_frame.py        ← render FRAME.BIN back-buffer dump to PNG
    colorize.py            ← palette CLI (--gen/--verify/--edit/--export-png/
                             --import-png); colors/editor.py is the pygame editor
    saveconv.py            ← GB .sav ↔ DOS .dsv converter — STUB, Phase 5
    dosbox_mcp/            ← MCP server for live LLM-driven DOSBox-X debugging
    dosbox-x/              ← dosbox-x fork SUBMODULE (Happyarch/dosbox-x, branch
                             mcp-debug: MCP socket bridge + SYMF symbol table)
    dosbox-x-mcp/          ← built fork binary `dosbox-x-mcp` (gitignored)
    mgba/, mgba_build/     ← vendored mGBA submodule + Lua-runner build (build_mgba.sh)
    mgba_harness/          ← golden-generation Lua scenarios + libs (fidelity harness)
    mgba_mcp/              ← MCP server for the mGBA ground-truth side (run_mgba_mcp.sh)
    goldencheck.sh         ← build + headless-run one scenario, diff vs its golden
    golden_diff.py         ← the differ (scenario table, masks, --flags)
  tests/goldens/           ← committed mGBA golden dumps (<scenario>.bin + .json)
  dosbox-x.conf            ← tracked DOSBox-X config (machine, cycles, autoexec)
  Makefile
  link.ld                  ← DJGPP linker script
docs/
  assembly.md              ← build flags, tools, dependencies (start here)
  register_map.md          ← SM83 → x86 register mapping (living doc)
  translation_log.md       ← per-routine translation notes
  glitch_safety.md         ← glitch sandbox guidance
  386_optimization_strategy.md ← Guide for fast and faithful 386 assembly optimizations
  ui_projection.md         ← per-subsystem GB→port UI coordinate registry + ; PROJ tags
  current_plan.md          ← active multi-step implementation plan (see below)
  references/
    README.md              ← reference link index
    pandocs/               ← downloaded Pan Docs markdown pages
```

## Toolchain
- Assembler: NASM, Intel syntax
- Target: 386+, 32-bit protected mode
- DPMI host: CWSDPMI (auto-loaded by `i386-pc-msdosdjgpp-ld` stub)
- Linker: `i386-pc-msdosdjgpp-ld` from `binutils-djgpp` package
- Build: `nasm -f coff` → `i386-pc-msdosdjgpp-ld`
- Entry point: `start` (not `_start`)
- Interactive shell is **zsh**, not bash: unquoted `$var` is NOT word-split
  (`set -- $pair` leaves it one word — use `${=var}` or pass args explicitly),
  and `$pipestatus`/`${(f)...}` differ from bash. Write zsh-compatible commands.

**Linker sections (critical, verified):** `link.ld` must explicitly map every
input section into a *loaded* output section (`.text`/`.data`). The
coff-go32-exe stub loads only the `.text`/`.data`/`.bss` extents it records;
any **orphan section** ld places elsewhere is given a VMA but its bytes never
reach memory, so symbols in it **read back as zero at runtime with no fault**.
This bit us hard: the overworld assets were in `section .rodata`, which had no
output rule, so `overworld_gfx`/`overworld_blocks`/`pallet_town_blk` were all
zero in memory → Pallet Town rendered all-white. `.rodata` is now folded into
`.data` in `link.ld`. Rule of thumb: put embedded data in `.data` (as the font
and title assets do), and if you ever add a new section name, add it to
`link.ld` first. Symptom of a broken/orphan section: a `rep movsb` from a
rodata label copies zeros while immediate `mov [ebp+x], imm` writes work fine.

## Build Commands

Full reference: **[docs/assembly.md](../../docs/assembly.md)** — build flags, asset flags, output files, warp format, DOSBox-X config.

Output EXE is **`dos_port/PKMN.EXE`** — DOS 8.3 name required for DOSBox-X `-c` invocation.

> **Web-session agents — fresh checkout?** (Local Arch Linux already has the
> toolchain + assets; this note is only for bare web/cloud session containers.)
> A bare `make -C dos_port` fails with `unable to open include file
> 'assets/..._gfx.inc'` because the generated assets and tileset `.2bpp` graphics
> aren't committed. Bootstrap order: build **rgbds 1.0.1 from source** (not an apt
> package) → `make` at repo root to render the `.2bpp` (its final `pokeyellow.gbc`
> link may fail — that's fine, the graphics are made first) → `make -C dos_port
> assets` → `make -C dos_port`. **Running** the EXE additionally needs a DPMI host
> (CWSDPMI.EXE / HDPMI32.EXE) the repo doesn't ship. Full step-by-step:
> [docs/assembly.md](../../docs/assembly.md) → "Fresh-Clone Bootstrap".

```sh
# Reference ROM (requires rgbds 1.0.1)
make compare

# DOS port (canonical; scripts below are wrappers)
make -C dos_port
make -C dos_port SKIP_TITLE=1          # skip title, boot straight to overworld
make -C dos_port BUG_FIX_LEVEL=1       # 1=critical fixes, 2=all fixes

# Asset regeneration (required after changing generator scripts or pret source)
make -C dos_port assets                # strip IF DEF(_DEBUG) blocks (normal)
make -C dos_port assets DEBUG_WARPS=1  # include debug warp entries
# IMPORTANT: make uses timestamps — changing DEBUG_WARPS requires explicit 'make assets'

# Convenience scripts (from repo root or dos_port/)
dos_port/build                         # build (passes args to make)
dos_port/run                           # build + launch in DOSBox-X

# Single file assembly check
nasm -f coff -o /dev/null dos_port/src/util/fill_memory.asm
```

DOSBox-X is driven by the tracked repo config **`dos_port/dosbox-x.conf`**, loaded
automatically by `dos_port/run`. It overrides the user's system config for:
- `machine = vgaonly` (Mode 13h plain VGA — required)
- `cputype = 386_prefetch`
- `cycles = fixed 23880` (386SX ~20 MHz baseline)
- `memory io optimization 1 = false` (VGA writes broken if true)
- `[autoexec]`: `mount c .` + launch `PKMN.EXE`

**Note:** All testing and debugging must occur on **DOSBox-X**, not standard DOSBox. Standard DOSBox lacks the accuracy and debugger features required for this port.

**Never hand-edit generated `assets/*.inc` files.** Fix the generator and re-run
`make assets`. The `MapHeaderPointers` table is computed at generation time — a
partial edit desyncs pointer addresses from blob offsets and silently corrupts
map loads (see `docs/translation_log.md` for the 2026-06-22 postmortem).

## Debugging (inspecting emulated GB memory)

The screen is a software PPU render: many distinct bugs collapse to the same
"all-white" / "all-garbage" picture, so **do not debug by staring at
screenshots and toggling tiles** — that loop ate two sessions on the `.rodata`
bug. Get ground truth from memory instead.

### Memory dump to a host file (primary, automatable)

`src/debug/debug_dump.asm` exfiltrates chosen windows of emulated GB memory to
`DUMP.BIN` (the dos_port dir / DOSBox-X C:), with **no PPU/palette/blit
confound** — the literal bytes at `[EBP + addr]`. It writes the file via DPMI
"Simulate Real Mode Interrupt" (INT 31h/0300h) into a conventional DOS buffer
(plain `int 21h` pointer args are NOT auto-translated under CWSDPMI), then
exits. Edit the `windows:` table to pick addresses.

```sh
make clean && make SKIP_TITLE=1 DEBUG_DUMP=1
dosbox-x -defaultdir "$PWD" -c 'mount c "'"$PWD"'"' -c c: -c PKMN.EXE -c exit
# then hexdump DUMP.BIN on the host (9 × 64-byte windows, in table order)
```

This is how the `.rodata` bug was localized: header vars and the `rep stosb`
border-fill were correct in the dump, but the whole `$4000`-asset window and
`$9000` tileset were zero — pointing at the asset load, not the map logic.

### Live debugging via dosbox-mcp (symbolic breakpoints, memory, frame dumps)

The **dosbox-x-mcp fork** (submodule `tools/dosbox-x` = Happyarch/dosbox-x
branch `mcp-debug`; built by `tools/build_dosbox_mcp.sh` into the
deliberately-renamed binary `dosbox-x-mcp` — installed to `~/.local/bin/` and
`tools/dosbox-x-mcp/`, never colliding with the system dosbox-x) + the MCP
server (`tools/dosbox_mcp/server.py`, auto-started by Claude Code via
`.claude/settings.json`) let a session drive the heavy debugger live:
symbolic execution breakpoints, GB/x86 memory reads, watchpoints,
symbol-annotated disassembly, and paused-frame PNG dumps.

**Symbols are always fresh and include NASM local labels.** The link rule
generates `pkmn.sym` from PKMN.EXE's own COFF symbol table
(`tools/generators/gen_symfile.py` — ~9.4k symbols, e.g. `_AdvancePlayerSprite.scroll`).
The server stats the file on every resolution and reloads transparently, so a
mid-session rebuild can NOT leave stale addresses (the old pkmn.map staleness
bug class is dead); if PKMN.EXE is newer than pkmn.sym it errors loudly
instead of resolving. Symbols are also auto-pushed into the debugger itself
(`SYMF`) the first time a tool touches the paused game, so the **ncurses UI**
resolves names natively: `BP CS:OverworldLoop`, `EV MySym+4`, `SYMNEAR EIP`,
`SYMLIST <pattern>`, labeled code view, `; Symbol` on call/jmp targets.
Expression precedence: register/flag name → symbol → hex literal, so even a
symbol spelled in pure hex digits (`AddBCD`) resolves as a symbol
(`EV ADDBCD` → its address); double-quote a value (`EV "ADDBCD"`) to force
the hex-literal reading, and digit-leading tokens (`7B1C`) are always hex
(NASM names can't start with a digit). Only names colliding with a
register/flag token stay unreachable by name — SYMF warns if any exist.

**Launch:** `dos_port/tools/run_with_mcp.sh` (does NOT build — run
`make SKIP_TITLE=1 DEBUG_SEED_PARTY=1` yourself first; launches the fork
binary with the MCP socket `/tmp/dosbox-mcp.sock`). It mounts the **host
`dos_port/` as C:**, so harness `FRAME.BIN`/`DUMP.BIN` files land directly on
disk there — no mcopy (unlike the isolated-`PKMN.IMG` headless pipeline
above). It does **not** pass `-break-start`: the game's runtime selectors
only exist once PKMN.EXE is loaded (at BIOS entry there is nothing to target,
and a paused emulator can't service the socket BREAK request).

**Canonical flow:**
1. `pause_exec()` once the game is running (drives the fork's BREAK request);
2. `set_breakpoint("OverworldLoop")` — any pkmn.sym symbol (incl. local
   labels like `PrepareOAMData.spriteLoop`) or hex offset;
3. `continue_exec()` — resumes and waits for the break (break reports are
   annotated: `EIP=00007B1C (OverworldLoop)`);
4. `wait_break()` — collects a break notification that outlives a RUN timeout
   *without* tearing down the socket (a teardown wedges the C-side bridge
   thread in `cond_wait`);
5. `where()` — "which routine am I in": nearest code symbol at/below EIP.

Then `gb_read`/`x86_read`/`get_registers`/`dump_frame` inspect the paused
emulator (`dump_frame` renders the back buffer to PNG). `disassemble` is
non-destructive (reads bytes, runs host `ndisasm`; does NOT write EIP) and is
symbol-annotated: label lines at symbol boundaries, `; Symbol+0x..` on
call/jmp targets. `lookup_symbol`/`search_symbols` resolve pkmn.sym names;
`load_debugger_symbols()` re-pushes SYMF explicitly (only needed when driving
the ncurses UI by hand right after a rebuild).

**Semantics that bit us (the "silent success" folly):**
- `set_breakpoint` sends `BP <cs>:<offset>` — a real execution breakpoint
  (BKPNT_PHYSICAL). **BPLM is a memory-CHANGE watchpoint**, exposed as
  `set_watchpoint` — set on *code* bytes it never fires (code doesn't change).
- **Never use raw pkmn.sym VMAs as linear addresses.** The CWSDPMI image runs
  with CS/DS base `0x00400000`; every address must resolve through the game's
  **runtime selectors** (from REGJSON/SELINFO). The MCP tools do this
  internally; the fork's SYMF table also resolves selectors lazily at each
  use. If you drop to raw `dbg_command`, resolve the base yourself.
- **Double-quote all hex args** in raw debugger commands: the expression
  parser resolves bare `AF`/`BP`/`DX`/`CF` as register/flag names — our DS
  selector is literally `"AF"`, which unquoted parses as the adjust flag (0).
  (Symbol names are exempt: identifiers that aren't registers/flags/hex fall
  through to the SYMF table, case-insensitively.)

**Failure heuristic:** a breakpoint that never fires, or reads returning all
zeros, means one of the three items above — **not** a broken socket. Check
them first.

**⚠ NEVER `pkill -f dosbox`** — the pattern also matches
`tools/dosbox_mcp/server.py` and kills the MCP server, permanently
disconnecting the session's dosbox-mcp tools. Match the fork binary precisely
(`pkill -f dosbox-x-mcp` or by PID).

**Rebuilding the debugger itself:** commit to the submodule
(`tools/dosbox-x`, branch `mcp-debug`) and run `tools/build_dosbox_mcp.sh`
(rsyncs the working tree to space-free `/tmp` staging — autotools can't take
the repo path's space — builds, installs both binary copies). Push the
submodule branch to the fork and commit the new submodule SHA in the
superproject. Upstream bumps = rebase `mcp-debug` onto the new upstream tag.

### Golden fidelity harness (mGBA ground truth vs DOSBox-X port)

The strongest ground truth of all: compare the port's GB state **byte-for-byte
against the real game**. mGBA (vendored submodule, built with Lua scripting by
`tools/build_mgba.sh`) runs the **sha1-verified golden ROM** — built in the
pinned pristine pret worktree `../pokeyellow_msdos-pret-golden` @ `7caf2e09`,
NOT the branch tree, whose pret sources are contaminated — through deterministic
Lua scenarios (`tools/mgba_harness/scenarios/*.lua`: boot → seeded party →
real-menu navigation → dump). Each scenario writes a **golden**
(`tests/goldens/<scenario>.bin` + `.json` sidecar, committed). The port side
builds the matching `DEBUG_*` image, runs it headless, and
`src/debug/debug_dump.asm:DumpGBState` writes `GBSTATE.BIN`.

`GBSTATE.BIN` is self-describing **v2**: a 16-byte `"GBST"` header (version,
scenario id, region count, directory size, total size), then a region directory
(name, GB address, size, file offset), then payloads. The port table is built
from `include/gb_memmap.inc`; the golden side resolves pret symbols. The differ
joins regions by name and cross-checks shared WRAM addresses/sizes, so memory-map
drift fails loudly instead of silently comparing the wrong bytes.

`tools/golden_diff.py` maps the port's 20×18 GB window (plus per-scenario UI
**projections** for the widescreen canvas, see `docs/ui_projection.md`) onto
the golden and diffs **tilemap cells** (charmap-decoded in the report),
**16-byte VRAM tile slots** (names a clobbered slot directly — the `$73/$74`
HUD-clobber class), **OAM entries**, and WRAM datastruct regions. WRAM reports
are field-aware (`wPartyData mon 3 DVs`, `wBagItems slot 2 quantity`, etc.) so a
bad game-data byte is actionable. Scenario class `"datastruct"` compares only
WRAM and loudly skips tilemap/VRAM/OAM with a class-level justification; use it
for post-flow game-data checks such as item effects or captures where transient
render state is not the evidence.

```sh
# Check one scenario end-to-end (build DEBUG image → headless run → diff)
make -C dos_port goldencheck SCENARIO=status_p1

# Core pre-commit tier: representative status/start/overworld/party/bag/text/
# datastruct/battle/menu coverage (currently 12 scenarios)
make -C dos_port fidelity

# Full active suite (currently 19 scenarios): core plus long-tail status,
# item, battle, and menu/dex scenarios
make -C dos_port fidelity-full

# Regenerate every Lua golden into a temp dir and diff against committed
# tests/goldens/*.bin + *.json, including legacy scenarios such as smoke_title
make -C dos_port goldens-verify

# Regenerate the committed goldens (needs build_mgba.sh output + golden worktree;
# sha1-gated against roms.sha1 — refuses an unverified ROM)
make -C dos_port goldens

# Pieces, for manual use:
tools/golden_diff.py status_p1 --flags            # print the scenario's make vars
tools/golden_diff.py status_p1 --gbstate PATH     # diff a dump you extracted yourself
tools/mgba_harness/inspect_golden.py tests/goldens/status_p1.json  # eyeball a golden
```

Rules and gotchas:
- **Masks need written justifications.** A legitimate divergence (e.g. the
  PikaPic area on the status screens) gets a per-scenario mask entry in
  `golden_diff.py`'s `SCENARIOS` table **with a `why` string** — never a bare
  mask. If an OPEN finding owns the divergence, include the finding id in the
  why-string so retiring the finding also deletes its masks. Policy + when this
  is required pre-commit → skill **`faithfulness-review`** (gate step 3).
- `goldencheck.sh` already runs against a **copy** of `PKMN.IMG` in a scratch
  dir, so it's immune to the live-session image-contention trap (below), and
  the NASMFLAGS stamp rebuilds the `DEBUG_*` objects automatically.
- Scenarios are deterministic (fixed seeds, state-aware navigation): two
  consecutive `make goldens` runs must produce byte-identical `.bin` files.
  A golden that changed without a scenario/pret change is a red flag.
- `make -C dos_port goldens-verify` is the drift check for committed goldens:
  it regenerates all Lua scenarios into a temp directory using the same pinned
  ROM/symbols and fails on any `.bin` or `.json` difference.
- New scenario = new Lua file in `tools/mgba_harness/scenarios/` + a
  `SCENARIOS` entry in `golden_diff.py` + a `DEBUG_*` harness in the port that
  reaches the same screen and calls `DumpGBState` with a new scenario id.

**Live differential debugging (mgba-mcp):** `tools/run_mgba_mcp.sh` launches
the golden ROM under the Lua runner with a resident agent
(`mgba_harness/mcp_agent.lua`, TCP 127.0.0.1:8765); `tools/mgba_mcp/server.py`
is the MCP stdio bridge — the structural twin of dosbox-mcp, but for **ground
truth**. It is not auto-registered in `.claude/settings.json` (unlike
dosbox-mcp): start the emulator side first, then the server. With both bridges
up you can read the **same pret symbol on both sides** (mGBA golden vs
DOSBox-X port) and bisect a divergence by label instead of guessing from
pixels. The agent blocks the emulator between commands; `run_frames` /
`press_buttons` advance time, everything else inspects the paused core.

### Back-buffer dump to PNG (preferred over screenshots)

`src/debug/debug_dump.asm:DumpBackbuffer` writes the full software-PPU back
buffer (`GB_BACKBUF`, 320×200 = 64000 raw palette-indexed bytes) to `FRAME.BIN`,
then exits — the **exact pixels DOSBox-X rendered**, with no compositor in the
loop (host Wayland/XWayland screenshot tools are unreliable across displays).
Render `FRAME.BIN` on the host with `dos_port/tools/render_frame.py FRAME.BIN out.png`
(values 0–3 = DMG shades, 4–11 = sprite pixels), then view the PNG.
Driven by deterministic, input-free `%ifdef` harnesses in `EnterMap`:
`DEBUG_TRANSITION` (force a north crossing; add `DEBUG_BASELINE=1` — both via the
Makefile — for pristine Pallet Town) and `DEBUG_WALK_NORTH` (drive the real
movement primitives north `DEBUG_WALK_STEPS` steps, dumping at the crossing);
plus the menu gates: `DEBUG_STARTMENU` (seeds the leaked
`hAutoBGTransferEnabled=1` state — the permanent OW-A.13 regression repro),
`DEBUG_BAGMENU` (seeds `text_row_stride=40` to mirror the live START→ITEM
entry; add `DEBUG_BAGMENU_EMPTY=1` for the empty-inventory worst case),
`DEBUG_PARTYMENU`, `DEBUG_G1` (pokédex CONTENTS), `DEBUG_TEXTBOXID=<id>`;
and the audio-engine gate `DEBUG_AUDIO` (starts Pallet Town BGM via the real
gateway at boot, ticks the engine 120 frames, dumps audio RAM + virtual APU
windows to DUMP.BIN — expected values are commented on its `windows:` table
in `src/debug/debug_dump.asm`).
This is how the 2026-06-15 viewport diagnosis, the 2026-06-16 out-of-map clamp
fix, and the 2026-07-06 OW-A.13 menu-corruption A/Bs were made. Prefer this to
screenshots for ground truth.

**Fully headless recipe (agent-runnable, verified 2026-07-06):**

1. **Stale objects.** `-D` define changes are handled: every `.o` depends on
   the `NASMFLAGS` stamp (`.nasmflags.stamp`), so changing `DEBUG_*`/`TRACK=`
   flags triggers a full rebuild automatically. What is NOT tracked is
   `%include`d file content: after `make assets` regenerates an `.inc`, the
   `.o`s that include it are stale — `touch` the consumers (grep the
   `%include`) or `make clean`. A stale build silently ships old data.
2. Build the image: `make -C dos_port image DEBUG_BAGMENU=1` (etc. — the
   harness flags set `SKIP_TITLE` themselves). `make image` packages
   `PKMN.EXE` into the **isolated `PKMN.IMG`** (its own C:) — files the game
   writes land inside the image, not on the host.
3. Scratch conf: copy `dos_port/dosbox-x.conf` and append `exit` after
   `PKMN.EXE` in `[autoexec]` (`sed 's/^PKMN.EXE$/PKMN.EXE\nexit/'`). The
   harness exits the program → DOSBox-X exits and flushes the image. (`-c
   "exit"` on the CLI runs too early — don't use it.)
4. Run: `SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy timeout -s KILL 150
   dosbox-x -defaultdir "$PWD" -defaultconf -conf <scratch.conf>` from
   `dos_port/`. Boot-to-dump ≈ 30–60 s at cycles=23880.
5. Extract: `mdel -i PKMN.IMG@@1048576 ::FRAME.BIN` **first** (the image
   persists files across rebuilds — stale FRAME.BINs lie), then after the run
   `mcopy -n -i PKMN.IMG@@1048576 ::FRAME.BIN .` (1048576 = partition byte
   offset). Render: `python3 tools/render_frame.py FRAME.BIN out.png`.
6. **⚠ Image contention:** if a live `dos_port/run` session is open (the user
   test-driving), it holds `PKMN.IMG` mounted read-write — a concurrent
   headless run on the same image **silently loses its FRAME.BIN** (the live
   session's cached FAT flushes clobber it; the run "succeeds" with exit 0 and
   no file, mimicking a crash). Verified 2026-07-06: this burned an hour on a
   phantom-crash hunt. Run headless against a **copy**: `cp PKMN.IMG
   $SCRATCH/pkmn_test.img`, point the scratch conf's `imgmount c` at the
   copy's absolute path, and mcopy-extract from the copy.

(The dosbox-mcp launcher below instead mounts the HOST `dos_port/` as C:, so
there FRAME.BIN lands directly on disk — no mcopy.)

### Visual capture

`./test_render.sh [out.png]` does a clean `SKIP_TITLE=1` build, launches
DOSBox-X, waits, screenshots (spectacle → import fallback), and force-kills.
Good for confirming a final render once the data is known-correct. Note: under a
Wayland session the compositor screenshot may grab the wrong window — the
`FRAME.BIN` route above is more reliable.

### Other dump decoders and static audits

Same family as `render_frame.py` above — decode a captured `.BIN` on the host
instead of staring at DOSBox-X, or check a static invariant without booting
anything:

```sh
# Per-stage frame timing (src/debug/perf.asm DEBUG_PERF build)
tools/read_perf.py PERF.BIN                       # ms/stage table
tools/read_perf.py PERF.BIN --baseline OTHER.BIN   # before/after delta

# DEBUG_SEAM harness trace (map-connection walk): view-pointer lockstep +
# other invariants, one 12-byte record per rendered frame
tools/read_seamlog.py SEAMLOG.BIN

# Blast-radius audit of the emulated GB address space: every `equ` region in
# include/gb_memmap.inc + assets/rom_window.inc, checked for overlaps/strays.
# Also wired into `make assets` (it's the last step) — run standalone after
# touching gb_memmap.inc/rom_window.inc without a full asset rebuild.
tools/audit_memmap.py

# Find symbols pkmn.sym couldn't name (helps spot a missing `global`)
tools/unnamed.py pkmn.sym
tools/unnamed.py -r src pkmn.sym    # only symbols under src/
```

## Asset-authoring tools (palettes, overworld maps, UI layout)

Interactive pygame editors that write hand-authored **sidecar JSON**, which a
`generators/gen_*.py` script then turns into the actual `assets/*.inc` — never
edit the generated `.inc` directly (see "Never hand-edit generated
`assets/*.inc` files" above); edit the sidecar and regenerate.

**Palettes** (colorization pipeline, complete as of 2026-07-13 —
`docs/plans/colorization.md`):

```sh
tools/colorize.py --gen                    # sidecar (assets/colors/palettes.json)
                                            # + pret data -> assets/colors/palettes.inc
tools/colorize.py --verify                 # sidecar valid + palettes.inc not stale
tools/colorize.py --edit                   # launch the pygame shade editor
tools/colorize.py --export-png SPECIES     # e.g. CHARIZARD -> indexed repaint PNG
tools/colorize.py --import-png PATH.png    # re-import a repainted PNG (<=4 colors/
                                            # tile, <=4 palettes/asset), then --gen
```

`--edit` controls (`colors/editor.py`, live battle-scene mock preview): `[`/`]`
cycle the `PAL_*` family, `,`/`.` cycle preview species, `1`-`4` pick a shade,
arrow keys adjust R/G, `PgUp`/`PgDn` adjust B, `S` saves sidecar deltas (prints
a reminder to run `--gen`), `Esc` quits. There is no `--edit <path>` flag on
`colorize.py` itself — for a non-default sidecar run `tools/colors/editor.py
<path> --zoom N` directly.

**Overworld maps:** `tools/map_editor/editor.py` — viewer/painter for the
border-ring authoring + block painting that feed `generators/gen_map_borders.py`
and `assets/map_overrides/<Pascal>.json`. See its own `--help`/docstring for
current controls (actively developed alongside `docs/current_plan_map_tool.md`).

**UI layout** (menu/battle element placement, complete —
`docs/plans/battle_ui.md`): `tools/ui_layout/editor.py
assets/ui_layout_<subsystem>_sidecar.json` hand-positions elements with a live
canvas preview; `generators/gen_ui_layout.py <subsystem>` projects the sidecar
into `assets/ui_layout_<subsystem>.inc`. `ui_layout/seed_from_battle.py` /
`seed_from_pret.py` are one-shot scripts that bootstrap a new sidecar from an
existing battle layout / from pret's `TextBoxCoordTable` — run once when adding
a new subsystem's sidecar, not part of the normal edit loop.

**Save converter:** `tools/saveconv.py` is a **stub** — `.sav`↔`.dsv`
conversion is not implemented yet (Phase 5). The `.dsv` format it will target
is already real and documented in its own header (`src/save/dsv_io.asm` writes/
reads version-1 files).

## Auditioning music (listen to a track — do NOT tailspin into rebuilds)

Two paths, fastest first. The arranger skills (`audio-enhance-opl3` /
`audio-enhance-mt32`) own *what* to write; this section owns *how to hear it*.

**1. Host-side (seconds, no DOS boot)** — `tools/audio/audition.py` plays the
generated `assets/midi/<target>/<Song>.mid` straight to an ALSA synth:

```sh
mt32emu-qt &                                        # MUNT, for --target mt32
tools/audio/audition.py Music_Celadon               # MT-32 (setup SysEx prepended)
tools/audio/audition.py --target gm Music_Celadon   # fluidsynth / any GM synth
```

Edit `tools/audio/mt32/timbres.yaml` / `overrides/*.yaml` / enhancement YAMLs →
`make assets` → re-run audition.py → listen. That's the whole loop.

**2. In-DOS (end-to-end, real drivers)** — only when verifying the actual
driver path (OPL shim, MPU-401, Tandy/speaker). The track is a make variable —
**never edit the Makefile or debug_dump.asm to swap songs**:

```sh
dos_port/run DEBUG_AUDIO=1 TRACK=MUSIC_CELADON /LOOP   # OPL3, loops forever
dos_port/run-mt32 DEBUG_AUDIO=1 TRACK=MUSIC_CELADON /LOOP  # MT-32 via MUNT
```

`TRACK=` takes any `MUSIC_*` constant from `assets/audio_constants.inc`
(default `MUSIC_GAME_CORNER`); the bank resolves via the generated
`<name>_BANK` constant. Without `/LOOP` the harness plays the Phase-A demo
sequence (music + SFX + cry + PCM) then dumps audio state to `DUMP.BIN` and
exits — that's the byte-verification mode, not the listening mode.

**Enhancements on/off (A/B) — the two targets differ (verified 2026-07-07):**
- **OPL3**: the tier-1 layer is a *runtime* overlay (`opl_enh.asm` streams) —
  the `/NOENH` exe flag disables it live: `dos_port/run DEBUG_AUDIO=1
  TRACK=... /LOOP /NOENH`. No rebuild of assets needed.
- **MT-32/GM**: enhancements are **baked into the MIDI stream at asset-gen
  time** (`gb_to_midi.py` folds `enhancements/<Song>.yaml` in; `mpu401.asm`
  never checks `/NOENH` — passing it is harmless but does nothing). The plain
  side of an A/B needs a stream regen:
  ```sh
  python3 tools/audio/gb_to_midi.py --target mt32 --songs GameCorner --no-enhance
  python3 tools/audio/midi_to_stream.py --target mt32
  dos_port/run-mt32 DEBUG_AUDIO=1 TRACK=MUSIC_GAME_CORNER /LOOP
  make -C dos_port assets   # afterwards: restore the enhanced streams
  ```
  (`mpu401.o` depends on `music_streams.inc` in the Makefile, so the rebuild
  picks the regen up automatically.)
- A song with no `enhancements/<Song>.yaml` (most of them, currently — only
  GameCorner and PalletTown have tier-1 layers) sounds identical with or
  without any of this: enhanced == plain until a YAML exists.

Anti-patterns (both caused a real lost session, 2026-07-07):
- Rebuilding PKMN.EXE / booting DOSBox-X repeatedly to hear a YAML tweak —
  use audition.py; the DOS build is for driver verification only.
- **Root-level `make clean` / `make tidy` in this tree.** It deletes
  pret-built intermediates (gfx `.2bpp`, etc.) that `make -C dos_port assets`
  needs — and this branch's pret tree is contaminated and can NOT rebuild
  them end-to-end (`make yellow` fails; see the golden-worktree note in the
  fidelity section). `make -C dos_port clean` is safe: it removes only `.o`s,
  `PKMN.EXE`, and the flags stamp — never assets. If root intermediates are
  already gone, rebuild them via the pristine golden worktree.

## Key Reference URLs

All key reference documents are also mirrored locally in `docs/references/pandocs/`.

- **Pan Docs** (GB hardware): https://gbdev.io/pandocs/
- **Ralf Brown's Interrupt List**: https://www.delorie.com/djgpp/doc/rbinter/
- **DPMI 0.9 Spec**: https://www.phatcode.net/res/262/files/dpmi09.html
- **DJGPP docs**: https://www.delorie.com/djgpp/doc/
- **DJGPP FAQ (hardware/interrupts)**: https://www.delorie.com/djgpp/v2faq/faq18.html
- **PC Game Programmer's Encyclopedia**: http://qzx.com/pc-gpe/
- **Abrash Black Book**: https://www.phatcode.net/res/224/files/html/
- **Awesome DOS**: https://github.com/balintkissdev/awesome-dos
