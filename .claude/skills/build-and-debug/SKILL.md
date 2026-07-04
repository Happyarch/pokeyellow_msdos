---
name: build-and-debug
description: Build, run, and debug reference for the Pokémon Yellow DOS port. Invoke when building or running the port, regenerating assets, configuring/launching DOSBox-X, or debugging emulated GB memory (DUMP.BIN / FRAME.BIN dumps instead of screenshots). Also holds the repo layout map and the key reference URLs. Triggers: "build the port", "make -C dos_port", "SKIP_TITLE", "make assets", "regenerate assets", "DEBUG_DUMP / DEBUG_TRANSITION / DEBUG_WALK_NORTH", "FRAME.BIN", "render_frame.py", "DOSBox-X config", "linker section / .rodata / orphan section", "where is <file> in the repo", "Pan Docs / DPMI spec / RBIL".
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
    gen_all_assets.py      ← tileset/blockset/map .inc generator
    gen_map_headers.py     ← map header blob + pointer table generator
    render_frame.py        ← render FRAME.BIN back-buffer dump to PNG
    colorize.py            ← palette tool (stub, Phase 5)
    saveconv.py            ← GB .sav ↔ DOS .dsv converter (stub, Phase 5)
    dosbox_mcp/            ← MCP server for live LLM-driven DOSBox-X debugging
    dosbox-x-mcp/          ← MCP-patched DOSBox-X build (gitignored, built locally)
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

### DOSBox-X interactive debugger (secondary)

DOSBox-X (2026.06.02, SDL1) can also be built/run with the heavy debugger
(`Alt+Pause`; `MEMDUMPBIN <lin> <len>` writes a file). Linear address of a GB
offset = `[ds_base] + EBP + offset`; both are runtime values, so the file-dump
route above is usually faster than chasing them in the debugger.

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
movement primitives north `DEBUG_WALK_STEPS` steps, dumping at the crossing).
Typical loop: `make clean && make SKIP_TITLE=1 DEBUG_TRANSITION=1` →
`dosbox-x -defaultdir "$PWD" -c 'mount c "'"$PWD"'"' -c c: -c PKMN.EXE -c exit` →
`python3 tools/render_frame.py FRAME.BIN /tmp/f.png`. This is how the
2026-06-15 viewport diagnosis and the 2026-06-16 out-of-map clamp fix were made
(see docs/loadmapheader_handoff.md). Prefer this to screenshots for ground truth.

### Visual capture

`./test_render.sh [out.png]` does a clean `SKIP_TITLE=1` build, launches
DOSBox-X, waits, screenshots (spectacle → import fallback), and force-kills.
Good for confirming a final render once the data is known-correct. Note: under a
Wayland session the compositor screenshot may grab the wrong window — the
`FRAME.BIN` route above is more reliable.

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
