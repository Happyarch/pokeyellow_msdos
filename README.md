# Pokemon Yellow — DOS Port

A from-scratch port of Pokémon Yellow (Game Boy Color) to MS-DOS, written in
x86 assembly (NASM), targeting 386+ in 32-bit protected mode via CWSDPMI.

The SM83 source in the repository root is the **read-only translation reference**
(pret/pokeyellow disassembly). The DOS port lives in `dos_port/`. All translated
routines keep the names used in pret so the port stays cross-referenceable against
the original disassembly.

---

## Reference ROM SHA1s

| ROM | SHA1 |
|-----|------|
| Pokemon Yellow (UE) [C][!].gbc | `cc7d03262ebfaf2f06772c1a480c7d9d5f4a38e1` |
| YELLMONS.GB (debug build) | `d44e96eddfbdad633cbe4e6e64915e9e198974b0` |
| Dmgapse0.h08.patch | `f3346a5559d52c296b8feab0cdbbfb0e250ac161` |

---

## Building the Reference ROM

Requires [rgbds 1.0.2](https://github.com/gbdev/rgbds/releases/tag/v1.0.2).

```sh
make compare
```

This builds the ROM and verifies the SHA1 checksums. Success confirms the
reference baseline before any translation work.

See [INSTALL.md](INSTALL.md) for full setup instructions.

---

## Building the DOS Port

You need three things: **NASM** (assembler), a **DJGPP linker** (`ld` targeting
`coff-go32-exe`), and **Python 3** (the asset generators are Python).

### Linux

```sh
# Debian / Ubuntu
sudo apt install nasm binutils-djgpp python3
```

On distros without a packaged DJGPP binutils (Arch, Fedora, …), build the
cross-toolchain with [andrewwutw/build-djgpp](https://github.com/andrewwutw/build-djgpp).

```sh
make -C dos_port
# produces: dos_port/PKMN.EXE, plus PKMN.IMG (a bootable disk image)
```

The Makefile calls the linker `i386-pc-msdosdjgpp-ld` and the objdump
`i586-pc-msdosdjgpp-objdump`. Toolchain builds commonly produce only the `i586-`
names, so either symlink `i386-pc-msdosdjgpp-ld → i586-pc-msdosdjgpp-ld` or
override on the command line: `make -C dos_port LD=i586-pc-msdosdjgpp-ld`.

### Windows

**Install [Python 3](https://www.python.org/downloads/) and `make`** (MSYS2:
`pacman -S make`; or [GnuWin32 make](https://gnuwin32.sourceforge.net/packages/make.htm)),
then let the setup script fetch the rest:

```sh
python dos_port\tools\setup_toolchain.py
```

It downloads NASM and a Windows-hosted DJGPP cross-linker into a project-local
`.toolchain\` directory, checks each download against a pinned SHA-256, and
writes an activator. Nothing is installed system-wide and no global environment
variable is touched — delete `.toolchain\` to uninstall. Run it with
`--print-only` first if you'd rather see exactly what it fetches and from where,
or `--check` to see what you already have.

Then, per shell:

```bat
.toolchain\activate.bat                                REM cmd.exe
make -C dos_port PKMN.EXE LD=i586-pc-msdosdjgpp-ld
```

```powershell
. .toolchain\activate.ps1                              # PowerShell
make -C dos_port PKMN.EXE LD=i586-pc-msdosdjgpp-ld
```

Copy the resulting `PKMN.EXE` and `CWSDPMI.EXE` into your DOSBox-X mount and run
`PKMN`.

Two Windows-specific limits:

- **Build `PKMN.EXE`, not the default target.** `make` with no target also builds
  `PKMN.IMG`, which needs `sfdisk`, `mkfs.fat` and `mcopy` — Linux-only. Same for
  the fidelity/golden targets, which need mGBA and DOSBox-X.
- **`LD=` is required.** The Makefile's default is `i386-pc-msdosdjgpp-ld`;
  prebuilt toolchains ship only the `i586-` name. (`OBJDUMP`'s default is already
  `i586-`, so it needs no override.)

If you'd rather not use the native toolchain at all, **WSL** works and gets you
the full target set: install [WSL](https://learn.microsoft.com/windows/wsl/install),
open the Ubuntu shell, and follow the Linux instructions above verbatim.

> Verified 2026-08-09 by building through the exact toolchain the script
> installs: it links a **byte-identical** `PKMN.EXE` (same SHA-256, 10,348,318
> bytes) to the Linux build, and its NASM emits object files differing only in
> the 4-byte COFF timestamp field.

#### Legal note

The script **downloads** from each project's own distribution server when you
run it; it does not redistribute anything, and this repository ships no
third-party binaries. You receive NASM (BSD-2-Clause) and binutils (GPLv3)
directly from their publishers under their own licenses. Keep it that way —
committing the archives into the repo would make this project a distributor and
pull in GPLv3's obligation to convey corresponding source.

### Running the port

**Run in DOSBox / DOSBox-X:**
```dosbox
[cpu]
cputype=386
core=normal
cycles=50000
```
A DPMI host must be available — the DJGPP stub accepts any DPMI 0.9 host:
- **CWSDPMI** (`CWSDPMI.EXE` in the same directory or on PATH) — the standard
  DJGPP host, from [delorie.com](http://www.delorie.com/pub/djgpp/current/v2misc/csdpmi7b.zip)
- **HDPMI32** (`HDPMI32.EXE -r` before launching) — from the
  [HX project](https://github.com/Baron-von-Riedesel/HX/releases); verified
  working with this port under DOSBox-X 2024.03.01

**Run in 86Box:** Configure a 386 or 486 machine; no special settings needed.

**Controls:**

| Key | GB button |
|-----|-----------|
| Arrow keys | D-pad |
| X | A |
| Z | B |
| Enter | Start |
| Right Shift / Tab | Select |
| Esc | Quit to DOS |

---

## Hard Conventions

### Register Mapping (SM83 → x86)

| SM83 | x86 | Notes |
|------|-----|-------|
| A | AL | Accumulator |
| F: Z, C | EFLAGS ZF, CF | Direct |
| F: H | `[hf_shadow]` | BSS byte, updated lazily — only where DAA/CPL/etc. consume H |
| F: N | (implicit) | Tracked via instruction choice, not a flag |
| BC | BX | B = BH, C = BL |
| DE | DX | D = DH, E = DL |
| HL | ESI | Full 32-bit, used for flat addressing |
| SP | ESP | Direct, mind calling convention |
| — | EBP | Fixed base pointer to emulated GB address space |
| — | EDI | Secondary pointer / blit destination |
| — | ECX | Loop counter / scratch |

### Memory Model
`EBP` holds the base of a 72 KB flat allocation that mirrors the GB address space.
All emulated memory accesses use `[EBP + GB_addr]` offsets defined in
`dos_port/include/gb_memmap.inc`. Offsets derived from `constants/hardware.inc`.

### Timing
- PIT channel 0 reprogrammed to ~60 Hz (divisor 19886, mode 3 square wave)
- Frame loop: `wait_vblank → wait_pit_tick → update → render → present`
- No cycle-counted delay loops

### Hardware I/O boundary
Any access to `$FF00–$FFFF` I/O registers (LCDC, APU, serial, timer) is a
translation boundary — not a 1:1 instruction mapping. These are emitted as
`; TODO-HW:` comments until the relevant subsystem is implemented.

### Bug Fix Flags
| Flag | Effect |
|------|--------|
| `/FIXALL` | Fix all documented bugs (cosmetic, behavioral, critical) |
| `/FIXCRIT` | Fix only critical bugs: buffer overflows, OOB writes, save corruption |
| (none) | Original game behavior including all known glitches |

See [docs/glitch_safety.md](docs/glitch_safety.md) before running with glitches
enabled on bare hardware.

---

## Docs

- [ROADMAP.md](ROADMAP.md) — Development phases and acceptance criteria
- [docs/current_plan_backlog.md](docs/current_plan_backlog.md) — Deferred tails
  with no other owner (the tracker TODO.md used to be)
- [docs/register_map.md](docs/register_map.md) — SM83→x86 register mapping (living doc)
- [docs/translation_log.md](docs/translation_log.md) — Per-routine translation notes
- [docs/glitch_safety.md](docs/glitch_safety.md) — Glitch sandbox guidance
- [docs/references/README.md](docs/references/README.md) — GB hardware and DOS programming references

---

## Network Multiplayer

The Game Boy link cable I/O (`$FF01`/`$FF02`, serial SB/SC registers) is
isolated and flagged with `; TODO-HW: network HAL` comments throughout. Transport
protocol (IPX, raw serial/null-modem, or packet-driver TCP/IP) is undecided.
This is a Phase 4 item — see [ROADMAP.md](ROADMAP.md).

---

## Glitch Safety

Dangerous glitches (arbitrary code execution via item slot overflow, etc.) can
theoretically write outside the DPMI-allocated memory on bare real hardware.
**Use 86Box or DOSBox for glitch exploration.** See
[docs/glitch_safety.md](docs/glitch_safety.md) for details.

---

For the original pret/pokeyellow documentation, see the
[pret/pokeyellow wiki](https://github.com/pret/pokeyellow/wiki) and
[INSTALL.md](INSTALL.md).
