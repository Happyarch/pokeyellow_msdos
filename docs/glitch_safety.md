# Glitch Safety Guide

This document explains the safety implications of running the DOS port with
original game glitches enabled, and what platform to use for each scenario.

---

## Overview

Pokémon Yellow has many documented bugs and glitches, ranging from harmless cosmetic
quirks to arbitrary code execution (ACE) routes that can write to any memory address
the Game Boy can reach. On the original hardware this is bounded to the GB's 64 KB
address space; under DPMI on a DOS machine the implications are different.

The DOS port preserves all original behavior by default. Two flags restrict behavior:

| Flag | Behavior |
|------|----------|
| (none) | All glitches active. Original game behavior. |
| `/FIXCRIT` | Critical bugs fixed: buffer overflows, OOB writes, save corruption, ACE paths. Harmless glitches preserved. |
| `/FIXALL` | All documented bugs fixed. Closest to a "clean" experience. |

---

## Per-Glitch Reference

For a full classified catalogue of all ~50 known Pokémon Yellow glitches (name, category,
engine area, ACE flag, BUG_FIX_LEVEL guidance), see:
[`docs/references/yellow_glitches.md`](references/yellow_glitches.md)

---

## Glitch Categories

### Intentional Glitches (safe to use on any platform)

These glitches work entirely within the emulated GB memory space and cannot escape
the DPMI-allocated block:

- **MissingNo / M' encounter**: Reads garbage tile data; visual corruption only.
- **Item duplication (box trick, Pokémon PC trick)**: Writes to SRAM-equivalent
  file buffer; no risk to disk beyond your save file.
- **Infinite Rare Candy**: Same as above.
- **Walk-through-walls**: Writes to player/map coordinates; bounded.
- **Species stat glitches**: Reads/writes Pokémon data structures in WRAM; bounded.

### Cosmetic Bugs (fixed by `/FIXALL` only)

- Wrong text strings (misspellings, overflow into next string)
- Minor visual glitches (OAM ordering artifacts, palette flicker)
- Incorrect battle stat calculations in edge cases

### Critical Bugs (fixed by `/FIXCRIT` and `/FIXALL`)

These involve unguarded writes that may exceed the intended WRAM region:

- **CopyData without bounds check**: Can write past `WRAM0` if `BC` is large and
  `HL` is near the end of WRAM.
- **Item slot $FF (Glitch Item)**: Reads a pointer from position 255 of the item
  list, which is past the end of `wItems`; the pointer may land in or near HRAM.
  Under DPMI the write lands in `[EBP + 0xFF00..0xFFFF]` (I/O shadow region) —
  harmless in most cases but could corrupt emulated HRAM.
- **Uninitialised inventory / missing list terminator** (port-specific): every
  inventory (bag, PC box, party, mon-box) is laid out as `db count`, then
  `(item, qty)` pairs, then a `$FF` terminator. Several routines scan for that
  `$FF` (`AddItemToInventory_`, `RemoveItemFromInventory_`) or trust the `count`
  byte (`DisplayListMenuID`). If the list is never seeded, those bytes are
  whatever the DPMI allocation happened to contain, so the scans **loop through
  memory** looking for a terminator that may be far away (or read hundreds of
  bytes past a 20-slot bag). This is a port-only exposure: the base game seeds
  the terminators in `InitPlayerData2` (`InitializeEmptyList` on each list),
  which runs as the first action of `OakSpeech` on **new-game creation**. The
  port's title / `SKIP_TITLE` boot jumps straight to `EnterMap`, so that seeding
  was being skipped.
  - **Root fix (always on):** `InitPlayerData2` is ported
    (`src/engine/movie/oak_speech/init_player_data.asm`) and now runs on the boot
    path via the `OakSpeech` prologue (`main_menu_stubs.asm`), so the default
    bag/box/party state always carries a `$FF` terminator.
  - **Defensive fix (`/FIXCRIT`, `BUG_FIX_LEVEL >= 1`):** `SanitizeInventory`
    (`inventory.asm`) clamps a list's `count` to its hardcoded capacity
    (`BAG_ITEM_CAPACITY` = 20 / `PC_ITEM_CAPACITY` = 50) and forces a `$FF`
    terminator at that count before any scan; `DisplayListMenuID` clamps the
    rendered length the same way. So even a corrupt/un-seeded list can only be
    read within its expected range — no runaway walk through memory. On a
    well-formed list both are no-ops.

### Arbitrary Code Execution (ACE) Glitches

ACE routes execute attacker-controlled bytes as code. On the original Game Boy this
is bounded to GB ROM/RAM. In the DOS port:

- **Under DPMI**: The DPMI host (CWSDPMI) provides segmented protection. Writes
  through the EBP-relative emulated space are bounded to the 72 KB allocation.
  However, if ACE manages to forge a far pointer and execute outside the game's
  `.text` segment, it can reach arbitrary DOS memory including disk buffers,
  TSR-resident code, and BIOS data.
- **On bare real hardware**: ACE can modify any writable real-mode or protected-mode
  address. Risk of disk corruption or system hang is real.

---

## Platform Recommendations by Scenario

| Use Case | Recommended Platform |
|----------|---------------------|
| Normal play (no glitches) | Any — real hardware, DOSBox, 86Box |
| Harmless intentional glitches | Any |
| Critical bug testing (`/FIXCRIT` off) | DOSBox or 86Box preferred |
| ACE glitch exploration | **86Box** (isolated VM) or **DOSBox** (OS-sandboxed process) |
| ACE on bare real hardware | **Not supported / at your own risk** |

---

## DPMI Protection Details

Under CWSDPMI, the game runs as a DPMI protected-mode client. The `coff-go32-exe`
format provides:

- **Flat data selector**: Covers 0x00000000–0xFFFFFFFF. Writes to `[EBP + offset]`
  with valid `EBP` stay within the game's allocation as long as `offset` is
  reasonable.
- **IOPL3**: I/O ports are directly accessible (required for VGA, PIT).
- **No ring 0 access**: The game cannot touch CPU control registers or install
  real-mode interrupt handlers without going through DPMI.

The protection boundary: if ACE-generated code writes to a linear address outside
the game's DPMI allocation AND outside DPMI's own memory, a **GPF (General
Protection Fault)** triggers, killing the process. This is safe on DOSBox/86Box
(the process dies, the emulator continues). On bare DOS the GPF behavior depends
on what's handling INT 0Dh.

---

## Startup Warning

When the game launches with `BUG_FIX_LEVEL == 0` (default, all glitches active),
it detects the DPMI host using INT 31h function 0400h:

- If the DPMI host ID string contains `CWSDPMI` or `DPMI/V` (CWSDPMI variants),
  check further whether we are running under DOSBox or 86Box (detectable via the
  `INT 21h AX=3000h` version string or `CWSDPMI`'s host name field).
- If running on what appears to be bare DOS with a non-emulated DPMI host and
  ACE-capable glitches could be triggered, display:

```
WARNING: Running with all glitches enabled on a non-emulated platform.
Arbitrary code execution glitches (ACE) may cause system instability.
Use 86Box or DOSBox for glitch exploration.
Press any key to continue, or Ctrl+C to exit.
```

This warning is implemented in Phase 6. For now, the warning is a stub.

---

## 86Box and DOSBox Configuration for Glitch Play

**DOSBox** (easiest):
- Any version of DOSBox; the process runs inside the DOSBox SDL window
- If the game crashes via ACE, DOSBox catches the fault and you can `Ctrl+F9` to close
- Configure: `cputype=386`, `core=normal`, `cycles=50000`

**86Box** (highest fidelity):
- Configure a 386/486 VM with CWSDPMI on the virtual C: drive
- Snapshot your VM state before ACE exploration — you can restore if anything goes wrong
- Better than DOSBox for testing real-hardware behavior of timing-sensitive glitches

---

## Future: Container Launcher (Phase 6 stretch goal)

A launcher script (`tools/launch_glitch_sandbox.sh` / `.bat`) that:
1. Detects whether 86Box or DOSBox is available
2. If found, launches the game inside the emulator automatically
3. If neither found, displays the warning and prompts to continue
4. On Linux: could use Docker/Podman to isolate a DOSBox process

This is deferred to Phase 6.
