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

To rebuild `PKMN.EXE` you need **NASM**, a **DJGPP linker** (`ld` targeting
`coff-go32-exe`) and **Python 3**.

A **fresh clone needs more**, because the graphics and most data tables are
generated rather than committed — see [Fresh clone](#fresh-clone-generate-the-assets-first)
below for the full list (rgbds, a C compiler, Pillow, PyYAML).

### Linux

```sh
# Debian / Ubuntu (incl. WSL)
sudo apt install nasm binutils-djgpp python3 make
# a fresh clone additionally needs:
sudo apt install gcc python3-pil python3-yaml
```

**rgbds is not in Ubuntu's repos**, and where a distro does package it the
version is wrong — `.rgbds-version` pins **1.0.2** exactly. Let the setup script
fetch it (statically linked, so it runs on any x86-64 distro):

```sh
python3 dos_port/tools/setup_toolchain.py            # from the repo root
export PATH="$(git rev-parse --show-toplevel)/.toolchain/rgbds:$PATH"
rgbasm --version                                     # expect v1.0.2
```

`.toolchain/` always lives at the **repository root**, so `git rev-parse` above
keeps the export correct whether you run it from the root or from `dos_port/`.
(The script prints the same line with an absolute path when it finishes — copying
that is equally safe.)

On Linux it installs *only* rgbds and tells you what to apt-get; run it with
`--print-only` first to see exactly what it fetches. Arch does package a current
`rgbds`, but check it reports 1.0.2 before relying on it.

**Set that `PATH` before running `make`.** The root build calls `rgbgfx` to render
the graphics; without it, `make` dies partway and leaves only the graphics it had
already reached, which later shows up as a confusing
`No rule to make target '../gfx/font/P.1bpp'` from the port build.

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

It downloads NASM, rgbds 1.0.2 and a Windows-hosted DJGPP cross-linker into a
project-local `.toolchain\` directory, checks each download against a pinned
SHA-256, and writes an activator. Nothing is installed system-wide and no global
environment variable is touched — delete `.toolchain\` to uninstall. Run it with
`--print-only` first if you'd rather see exactly what it fetches and from where,
or `--check` to see what you already have.

**It does not install everything, by design.** It fetches pinned archives into a
local folder; it will not mutate your system. These stay your job, and the
script reports which are missing:

| Needed | For | Get it |
|---|---|---|
| `make` | always | MSYS2 `pacman -S make` |
| `git` | always | [git-scm.com](https://git-scm.com/download/win) |
| `gcc` | fresh clone only | MSYS2 `pacman -S gcc` |
| Pillow, PyYAML | fresh clone only | `pip install pillow pyyaml` |

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
`PKMN` — or use the run scripts below, which do it for you.

#### Run scripts

The bash launchers have PowerShell counterparts, with the same argument
convention (`/...` tokens are `PKMN.EXE` flags, everything else goes to make):

| PowerShell | bash | What |
|---|---|---|
| `.\build.ps1` | `build` | build `PKMN.EXE` |
| `.\run.ps1` | `run` | build + launch in DOSBox-X |
| `.\run-mt32.ps1` | `run-mt32` | MT-32 music via DOSBox-X's built-in MUNT |
| `.\run-spk.ps1` | `run-spk` | Sound Blaster off — PC-speaker PWM cry |
| `.\run-tandy.ps1` | `run-tandy` | Tandy 1000 SN76489 PSG |

```powershell
cd dos_port
.\run.ps1 SKIP_TITLE=1
.\run.ps1 DEBUG_AUDIO=1 /LOOP /NOENH
$env:MT32_ROMDIR = 'C:\roms\mt32'; .\run-mt32.ps1 DEBUG_AUDIO=1 /LOOP
```

They find DOSBox-X on `PATH` or in the usual install directories, put
`.toolchain\` on `PATH` automatically, and supply the `LD=` override for you.

⚠ **They differ from the bash scripts in one way that matters.** The bash
launchers build `PKMN.IMG` and `imgmount` it, so C: is an isolated FAT image and
the game cannot reach the host filesystem at any `BUG_FIX_LEVEL`. Building that
image needs `sfdisk`/`mkfs.fat`/`mcopy`, so on Windows C: is instead a **mounted
directory** (`dos_port\rundir\`) holding only `PKMN.EXE`, `CWSDPMI.EXE` and your
save. That keeps the blast radius small, but it is not the same guarantee — read
[docs/glitch_safety.md](docs/glitch_safety.md) before exploring glitches, and
prefer WSL for that. One upside: dumps (`FRAME.BIN`, `GBSTATE.BIN`, …) land
directly on the host with no `mcopy` step.

MT-32 additionally needs the Roland ROM pair (`MT32_CONTROL.ROM`,
`MT32_PCM.ROM`) in `$env:MT32_ROMDIR` or `dos_port\mt32-roms\`. Those are
copyright Roland — supply your own; nothing here fetches them.

#### Fresh clone? Generate the assets first

A clone straight from git **cannot build** — you'll get `unable to open include
file 'assets/..._gfx.inc'`. Most of the assets are generated, not committed: 585
`.2bpp` tileset graphics (none tracked) and ~693 of the 714
`dos_port/assets/*.inc`. Bootstrap them once:

```sh
cd <repo root>              # these three run from the ROOT, not dos_port/
git submodule update --init --recursive
make                        # renders the .2bpp — needs rgbds + gcc
make -C dos_port assets     # needs Pillow + PyYAML
```

Only the first `make` is root-only — it drives pret's build. Anything with
`-C dos_port` has a direct equivalent from inside `dos_port/` (`make assets`,
`make PKMN.EXE`, …), so work wherever you prefer; just keep `PATH` pointing at
the repo-root `.toolchain/` as above.

The root `make` builds pret's own C tools (`tools/gfx`, `tools/scan_includes`,
`tools/make_patch`), which is why a C compiler is on the list. Its final ROM link
may fail — that's fine, the graphics are produced before it.

> **This chain is the least-tested part of the native Windows route.** Do the
> first bootstrap under **WSL** if you hit trouble; once the assets exist,
> rebuilding `PKMN.EXE` natively works fine and is verified. If `git submodule`
> fails, note that `.gitmodules` uses SSH URLs — either add
> `git config --global url."https://github.com/".insteadOf git@github.com:` or
> use SSH keys.

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
