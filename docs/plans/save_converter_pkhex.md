# Current Plan: Save Converter (Portable C) & PKHeX Plugin

Created: 2026-09-10  
Topic: Interoperability between Pokémon Yellow DOS `.dsv` save format and standard Game Boy `.sav` format (CLI Converter + PKHeX Integration)  
Status: Stage 1 complete 2026-09-10 (`dos_port/tools/dsv2sav.c`, verified end-to-end — see §2); Stage 2 complete 2026-09-10 (plugin toolchain + core + wine GUI verification, both export dialogs proven — see §2)

---

## 1. Overview & Goals

The Pokémon Yellow DOS port persists save data to disk as `POKEMON.DSV` using the **v2 format**: a 7-byte header prepended to the raw 32,768-byte MBC5 SRAM image (`dsv_io.asm`). Because the payload is a bank-identical image of real cartridge SRAM (Banks 0–3), conversion to and from standard Game Boy `.sav` files is mathematically lossless and invertible (a 7-byte header strip or prepend with checksum calculation).

This plan defines two interoperability deliverables:

1. **Stage 1: Portable Standalone CLI Converter (`dsv2sav`)**
   - Written in pure standard C (C89/C99) using **only standard library headers** (`<stdio.h>`, `<stdlib.h>`, `<string.h>`, `<stdint.h>`).
   - **Naturally endian-agnostic**: Must compile and function identically on little-endian (x86, x86-64, ARM) and big-endian (PowerPC, M68k, SPARC) CPU architectures, with zero unaligned pointer casts.
   - **Fully bidirectional**: Losslessly converts both ways — DOS port `.dsv` to standard Game Boy `.sav` (`--to-sav`) and standard Game Boy `.sav` to DOS port `.dsv` (`--to-dsv`).
   - Robust collision detection for Nintendo DS DeSmuME `.dsv` files.
   - Ships as a standalone tool in `dos_port/tools/dsv2sav.c` (while `saveconv.py` remains in the tree for the internal golden test harness).

2. **Stage 2: PKHeX Plugin (`PokemonYellowDOS`)**
   - A C# plugin targeting .NET 10 (`net10.0-windows`) implementing PKHeX's `IPlugin` interface.
   - Loads 32,775-byte `.dsv` files through a custom `ISaveReader` registered in `SaveUtil.CustomSaveReaders`, so PKHeX's normal pipeline opens them ahead of the `SaveHandlerFooterRTC` false-positive trap.
   - Integrates with PKHeX's `SAV1` class for full Pokémon Yellow editing (party, PC boxes, Pokédex, trainer data).
   - Provides "Export as .dsv (DOS Port)" and "Export as .sav (Standard GB)" menu options under PKHeX's Tools menu.

---

## 2. Checklist & Progress

- [x] **Stage 1: Portable C Save Converter (`dsv2sav.c`)** — DONE 2026-09-10
  - [x] Implement endian-agnostic byte read/write helpers (`read_u16_le`, `write_u16_le`, `write_u32_le`).
  - [x] Implement additive 16-bit checksum calculation (`sum(payload) & 0xFFFF`).
  - [x] Implement DeSmuME footer detection (`|-DESMUME SAVE-|` cookie).
  - [x] Implement validation routine matching `dsv_io.asm:SramLoadImage` rules (DeSmuME probe -> size -> magic -> version -> checksum).
  - [x] Implement `--to-sav` mode (strip 7-byte header, write 32 KiB raw SRAM).
  - [x] Implement `--to-dsv` mode (prepend 7-byte header, calculate checksum, write 32,775-byte `.dsv`).
  - [x] Implement `--verify` / `--info` mode with detailed inspection output.
  - [x] Add atomic file write handling (write to temporary buffer/file, flush, close).
  - [x] Verify byte-for-byte output equivalence against Python `saveconv.py` on test fixtures (`yellow_100.sav`).
  - [x] Test on both little-endian and big-endian targets (e.g., via `qemu-ppc` or big-endian toolchain check).

- [ ] **Stage 2: PKHeX Plugin (`PokemonYellowDOS.dll`)** — toolchain + core DONE 2026-09-10, GUI verification open
  - [x] Set up Class Library projects referencing `PKHeX.Core` (`dos_port/tools/pkhex_plugin/`: `PokemonYellowDOS.Core` on plain `net10.0`, `PokemonYellowDOS` plugin shell on `net10.0-windows`, `PokemonYellowDOS.Tests` on `net10.0`).
  - [x] Implement `DsvFormat` C# utility class (header build, validate, strip, checksum).
  - [x] Implement `DsvSaveReader : ISaveReader`, registered in `SaveUtil.CustomSaveReaders` at plugin `Initialize`; it validates the `.dsv`, strips the 7-byte header, and delegates the payload to PKHeX's own Gen-1 detection.
  - [x] Implement DeSmuME collision check with user-friendly warning dialog (`DsvPlugin.TryLoadFile` guard; `OpenFromPath` consults plugins first).
  - [x] Implement `IPlugin` (`Name`, `Priority`, `SaveFileEditor`/`PKMEditor` set from `Initialize` args, `NotifySaveLoaded`, `NotifyDisplayLanguageChanged`, `TryLoadFile`).
  - [x] Add Tools-menu actions exporting `.dsv` (`SAV1.Write()` re-wrapped with a recalculated DOS header) and `.sav` (`Menu_Tools` items added from `Initialize` args).
  - [x] Add unit test suite: 18 xUnit tests green on Linux (`DsvFormatTests` hermetic vectors + `DsvSaveReaderTests` against `yellow_100.sav`). Export asserts idempotence + equivalence-with-stock PKHeX behavior, not byte identity (`Write()` normalizes box layout; second write is a fixed point).
  - [x] Write installation documentation (`pkhex_plugin/README.md`: legal/build/install sections).
  - [x] Verify under wine with the real app (26.08.26): plugin `Initialize` runs in-process; the exact `Main.OpenFile` pipeline (`FileUtil.GetSupportedFile` → registered `DsvSaveReader` → `SAV1` YW / OT Player1 / party 6) opens a `.dsv` built from `yellow_100.sav`, using the shipped DLLs against the installed Core 26.8.26 (cross-version binding fine).
  - [x] GUI end-to-end (§6.2) — DONE 2026-09-10: maintainer opened a `.dsv` in PKHeX 26.08.26 under wine (File > Open), edited, exported, and booted CONTINUE in DOSBox-X cleanly — twice. First pass used the raw `.sav` export (converted losslessly with `saveconv.py --to-dos` before staging); second pass used the plugin's Export-as-`.dsv` dialog directly (valid v2 header, staged as-is) and also booted clean. Note for future testers: PKHeX File > Save writes the raw payload without the DOS header — the `.dsv` wrapper only comes from the plugin's Tools-menu export.

---

## 3. Technical Background & Architecture

### 3.1 Binary Format Specifications

#### Pokémon Yellow DOS `.dsv` v2 Layout
```
Offset       Size (Bytes)  Type        Description
--------------------------------------------------------------------------------
0x00..0x03   4             ASCII       Magic bytes: "DOSV" (0x44, 0x4F, 0x53, 0x56)
0x04         1             uint8       Format version (must be 0x02)
0x05..0x06   2             uint16 LE   16-bit additive payload sum (sum(payload) & 0xFFFF)
0x07..0x8006 32768         Bytes       Raw SRAM payload (Banks 0, 1, 2, 3 sequential)
--------------------------------------------------------------------------------
Total Size:  32,775 bytes (0x8007)
```

#### Standard Game Boy `.sav` Layout
```
Bank         Offset Range  Size        Contents
--------------------------------------------------------------------------------
Bank 0       0x0000..0x1FFF 8192 bytes  Sprite buffers (3 × 0x190), Hall of Fame
Bank 1       0x2000..0x3FFF 8192 bytes  Player name (0x2598), main data, party data,
                                       current box, sMainDataCheckSum (0x3523)
Bank 2       0x4000..0x5FFF 8192 bytes  PC Boxes 1–6 + checksums
Bank 3       0x6000..0x7FFF 8192 bytes  PC Boxes 7–12 + checksums
--------------------------------------------------------------------------------
Total Size:  32,768 bytes (0x8000)
```

### 3.2 The DeSmuME Extension Collision
DeSmuME (the Nintendo DS emulator) also uses the `.dsv` extension. However, their internal structure is completely different:
- **DeSmuME**: Uses a **122-byte footer** appended after DS save data. The last 16 bytes of the file are always `|-DESMUME SAVE-|` (ASCII).
- **DOS Port**: Uses a **7-byte header** prepended before Game Boy save data, beginning with `DOSV`.

**Safety Rule:** The converter and plugin must always probe for the DeSmuME footer cookie before running size or magic checks, emitting an explanatory message guiding the user to DeSmuME's native "Export Backup Memory" option.

### 3.3 The PKHeX `SaveHandlerFooterRTC` Trap
PKHeX contains a handler designed to strip trailing RTC metadata from emulator saves:
```csharp
if ((size & 0x3F) == 7) // Designed for FlashGBX >v2.0 7-byte RTC footer
```
Because our `.dsv` file size is `32768 + 7 = 32775`, `32775 & 0x3F == 7` evaluates to `true`!
Without our plugin, PKHeX mistakes `POKEMON.DSV` for a FlashGBX save and strips the **last** 7 bytes instead of the **first** 7 bytes. The resulting payload is offset by +7 bytes, corrupting all pointers and failing Gen 1 list validation (`IsListValidG12`).

A dedicated PKHeX plugin intercepts the file inside `IPlugin.TryLoadFile` before PKHeX's default handlers run, correctly stripping the 7-byte header from offset `0x00`.

---

## 4. Stage 1 Specification: Portable C Converter (`dsv2sav`)

### 4.1 Endian-Agnostic & Portability Design Rules
To guarantee flawless compilation and operation on any CPU architecture (including big-endian systems like PowerPC or SPARC):
1. **Zero Architecture-Specific Headers**: Do not include `<endian.h>`, `<sys/endian.h>`, `<byteswap.h>`, `<intrin.h>`, or compiler-specific builtins.
2. **Explicit Byte Serialization (Shift/Mask)**:
   - Reading 16-bit little-endian:
     ```c
     static uint16_t read_u16_le(const uint8_t *p) {
         return (uint16_t)p[0] | ((uint16_t)p[1] << 8);
     }
     ```
   - Writing 16-bit little-endian:
     ```c
     static void write_u16_le(uint8_t *p, uint16_t v) {
         p[0] = (uint8_t)(v & 0xFF);
         p[1] = (uint8_t)((v >> 8) & 0xFF);
     }
     ```
   - Writing 32-bit little-endian:
     ```c
     static void write_u32_le(uint8_t *p, uint32_t v) {
         p[0] = (uint8_t)(v & 0xFF);
         p[1] = (uint8_t)((v >> 8) & 0xFF);
         p[2] = (uint8_t)((v >> 16) & 0xFF);
         p[3] = (uint8_t)((v >> 24) & 0xFF);
     }
     ```
3. **No Pointer Casting for Multi-Byte Types**:
   - **Never** do `*(uint32_t *)ptr == 0x56534F44`. On big-endian CPUs (PowerPC), this reads as `0x444F5356`. On architectures with strict alignment requirements (SPARC, older ARM/MIPS), this causes a hardware bus error / alignment fault if `ptr` is not 4-byte aligned.
   - Always compare magic bytes with `memcmp(data, "DOSV", 4) == 0`.
4. **Byte-Iterative Additive Checksum**:
   - `sum(payload) & 0xFFFF` accumulates byte-by-byte into a `uint16_t`, which naturally wraps at 16 bits regardless of machine word size or endianness.

### 4.2 Implementation Layout (`dos_port/tools/dsv2sav.c`)

```c
/* dsv2sav.c — Portable Pokémon Yellow DOS port .dsv <-> .sav converter.
 *
 * Compiles cleanly with any ISO C99 / C89 compiler:
 *   gcc -O2 -std=c99 -Wall -Wextra -pedantic -o dsv2sav dsv2sav.c
 *   clang -O2 -std=c99 -Wall -Wextra -pedantic -o dsv2sav dsv2sav.c
 *   cl /O2 /W4 dsv2sav.c                                (MSVC)
 *   gcc -O2 -o dsv2sav.exe dsv2sav.c                    (MinGW / DJGPP)
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#define DSV_MAGIC_STR   "DOSV"
#define DSV_VERSION     2
#define HDR_SIZE        7
#define SAV_SIZE        32768u
#define DSV_SIZE        (HDR_SIZE + SAV_SIZE)

static const char DESMUME_COOKIE[16] = "|-DESMUME SAVE-|";

/* Endian-neutral integer encoding */
static uint16_t read_u16_le(const uint8_t *p) {
    return (uint16_t)p[0] | ((uint16_t)p[1] << 8);
}

static void write_u16_le(uint8_t *p, uint16_t v) {
    p[0] = (uint8_t)(v & 0xFF);
    p[1] = (uint8_t)((v >> 8) & 0xFF);
}

static void write_u32_le(uint8_t *p, uint32_t v) {
    p[0] = (uint8_t)(v & 0xFF);
    p[1] = (uint8_t)((v >> 8) & 0xFF);
    p[2] = (uint8_t)((v >> 16) & 0xFF);
    p[3] = (uint8_t)((v >> 24) & 0xFF);
}

/* 16-bit additive sum mod 2^16 */
static uint16_t payload_checksum(const uint8_t *payload, size_t len) {
    uint16_t sum = 0;
    for (size_t i = 0; i < len; i++) {
        sum = (uint16_t)(sum + payload[i]);
    }
    return sum;
}

static int is_desmume(const uint8_t *data, size_t len) {
    if (len < 16) return 0;
    return (memcmp(data + len - 16, DESMUME_COOKIE, 16) == 0);
}

/* Validation logic matching dsv_io.asm */
static int validate_dsv(const char *path, const uint8_t *data, size_t len) {
    if (is_desmume(data, len)) {
        fprintf(stderr,
            "dsv2sav: error: '%s' is a Nintendo DS (DeSmuME) save file.\n"
            "  DeSmuME and this DOS port both use the .dsv extension, but the formats differ.\n"
            "  To use a DeSmuME save, export a raw .sav in DeSmuME via File -> Export Backup Memory.\n",
            path);
        return 0;
    }

    if (len != DSV_SIZE) {
        if (len == SAV_SIZE) {
            fprintf(stderr,
                "dsv2sav: error: '%s' is a raw Game Boy .sav (%u bytes), not a .dsv.\n"
                "  Did you mean: dsv2sav --to-dsv \"%s\" output.dsv ?\n",
                path, (unsigned)SAV_SIZE, path);
        } else {
            fprintf(stderr, "dsv2sav: error: '%s' has invalid size %u bytes (expected %u bytes).\n",
                path, (unsigned)len, (unsigned)DSV_SIZE);
        }
        return 0;
    }

    if (memcmp(data, DSV_MAGIC_STR, 4) != 0) {
        fprintf(stderr, "dsv2sav: error: '%s' has invalid header magic (expected 'DOSV').\n", path);
        return 0;
    }

    if (data[4] != DSV_VERSION) {
        fprintf(stderr, "dsv2sav: error: '%s' has unsupported version %u (supported: version %u).\n",
            path, (unsigned)data[4], (unsigned)DSV_VERSION);
        return 0;
    }

    uint16_t stored = read_u16_le(data + 5);
    uint16_t computed = payload_checksum(data + HDR_SIZE, SAV_SIZE);
    if (stored != computed) {
        fprintf(stderr, "dsv2sav: error: '%s' payload checksum mismatch (stored 0x%04X, computed 0x%04X).\n",
            path, (unsigned)stored, (unsigned)computed);
        return 0;
    }

    return 1;
}
```

---

## 5. Stage 2 Specification: PKHeX Plugin (`PokemonYellowDOS`)

### 5.1 Project Configuration
Directory: `dos_port/tools/pkhex_plugin/`, three projects:

- `PokemonYellowDOS.Core/` (plain `net10.0`, no WinForms): `DsvFormat.cs` + `DsvSaveReader.cs`. Builds and runs on Linux.
- `PokemonYellowDOS/` (`net10.0-windows` + `UseWindowsForms`): `DsvPlugin.cs`. Linux builds compile-only (`EnableWindowsTargeting`); runs inside PKHeX on Windows/wine.
- `PokemonYellowDOS.Tests/` (plain `net10.0` + xUnit): the suite. Plain `net10.0` because the WindowsDesktop *runtime* does not exist on Linux, so a `-windows` testhost cannot execute there (and a cross-TFM `ProjectReference` is a hard NU1201 error, which is why the tested core is split out instead of living in the plugin shell).

`PokemonYellowDOS.csproj` (the shell; `PokemonYellowDOS.Core.csproj` is the same minus `TargetFramework`/`UseWindowsForms`/`EnableWindowsTargeting`/`AssemblyTitle`):
```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net10.0-windows</TargetFramework>
    <UseWindowsForms>true</UseWindowsForms>
    <EnableWindowsTargeting>true</EnableWindowsTargeting>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <AssemblyTitle>Pokémon Yellow DOS Port PKHeX Plugin</AssemblyTitle>
    <Version>1.0.0</Version>
    <Authors>Pokémon Yellow DOS Port Contributors</Authors>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="PKHeX.Core" Version="26.7.7" />
    <ProjectReference Include="..\PokemonYellowDOS.Core\PokemonYellowDOS.Core.csproj" />
  </ItemGroup>
</Project>
```
`PKHeX.Core` is pinned at `26.7.7` (matches `dos_port/tools/savegen`; a floating version is non-reproducible). The plugin must run on PKHeX's own framework, so this tracks the app (PKHeX requires .NET 10).

### 5.2 Core Format Handling (`DsvFormat.cs`)
```csharp
namespace PokemonYellowDOS;

public static class DsvFormat
{
    public const int HeaderSize = 7;
    public const int PayloadSize = 32768;
    public const int TotalSize = HeaderSize + PayloadSize;
    public const byte Version = 2;
    private static readonly byte[] MagicBytes = "DOSV"u8.ToArray();
    private static readonly byte[] DeSmuMECookie = "|-DESMUME SAVE-|"u8.ToArray();

    public static bool IsDeSmuME(ReadOnlySpan<byte> data)
    {
        return data.Length >= 16 && data[^16..].SequenceEqual(DeSmuMECookie);
    }

    public static bool IsDsv(ReadOnlySpan<byte> data)
    {
        if (data.Length != TotalSize)
            return false;
        if (!data[..4].SequenceEqual(MagicBytes))
            return false;
        if (data[4] != Version)
            return false;

        ushort stored = (ushort)(data[5] | (data[6] << 8));
        ushort computed = ComputeChecksum(data[HeaderSize..]);
        return stored == computed;
    }

    public static ushort ComputeChecksum(ReadOnlySpan<byte> payload)
    {
        int sum = 0;
        foreach (byte b in payload)
            sum += b;
        return (ushort)(sum & 0xFFFF);
    }

    public static byte[] BuildDsv(ReadOnlySpan<byte> payload)
    {
        var dsv = new byte[TotalSize];
        MagicBytes.CopyTo(dsv, 0);
        dsv[4] = Version;
        ushort checksum = ComputeChecksum(payload);
        dsv[5] = (byte)(checksum & 0xFF);
        dsv[6] = (byte)((checksum >> 8) & 0xFF);
        payload.CopyTo(dsv.AsSpan(HeaderSize));
        return dsv;
    }

    public static byte[] ExtractPayload(ReadOnlySpan<byte> dsv)
    {
        return dsv[HeaderSize..].ToArray();
    }
}
```

### 5.3 Load Path (`DsvSaveReader.cs`)

Loading goes through a custom `ISaveReader` registered in PKHeX's public
`SaveUtil.CustomSaveReaders` registry, so `FileUtil.GetSupportedFile` opens
`.dsv` through the normal pipeline (backups, title, editors — everything stock
PKHeX does), ahead of the `SaveHandlerFooterRTC` trap. The reader only claims
32775-byte files with valid `DOSV` magic + version + checksum, and delegates the
stripped payload to PKHeX's own Gen-1 detection, so language/version handling
matches opening a raw `.sav` exactly.

```csharp
using System.Diagnostics.CodeAnalysis;
using PKHeX.Core;

namespace PokemonYellowDOS;

public sealed class DsvSaveReader : ISaveReader
{
    public bool IsRecognized(long dataLength) => dataLength == DsvFormat.TotalSize;

    public bool TryRead(Memory<byte> data, [NotNullWhen(true)] out SaveFile? result, string? path = null)
    {
        result = null;
        if (data.Length != DsvFormat.TotalSize)
            return false;
        if (!DsvFormat.IsDsv(data.Span))
            return false;

        var payload = DsvFormat.ExtractPayload(data.Span);
        SaveFile? sav;
        try
        {
            // Fresh copy per call: SaveFile aliases its input buffer and
            // Write() mutates it in place, so never hand over shared state.
            sav = SaveUtil.GetSaveFile(new Memory<byte>(payload), path);
        }
        catch
        {
            return false;
        }
        if (sav is not SAV1)
            return false;
        result = sav;
        return true;
    }
}
```

### 5.4 Plugin Entry Point (`DsvPlugin.cs`)

`DsvPlugin : IPlugin` registers the reader, contributes the Tools-menu export
items, and keeps the DeSmuME collision guard. `Initialize` receives
`(ISaveFileProvider, IPKMView, ToolStrip menuStrip, Version)`; menus attach
under the `Menu_Tools` item. `TryLoadFile` handles only the DeSmuME case
(`OpenFromPath` consults plugins before its own checks) and returns false for
valid DOS-port files, which the registered reader loads through the pipeline.

```csharp
using System.Windows.Forms;
using PKHeX.Core;

namespace PokemonYellowDOS;

public sealed class DsvPlugin : IPlugin
{
    public string Name => "Pokémon Yellow DOS Save (.dsv)";
    public int Priority => 1;

    public ISaveFileProvider SaveFileEditor { get; private set; } = null!;
    public IPKMView PKMEditor { get; private set; } = null!;

    public void Initialize(params object[] args)
    {
        SaveFileEditor = (ISaveFileProvider)Array.Find(args, static z => z is ISaveFileProvider)!;
        PKMEditor = (IPKMView)Array.Find(args, static z => z is IPKMView)!;

        if (!SaveUtil.CustomSaveReaders.OfType<DsvSaveReader>().Any())
            SaveUtil.CustomSaveReaders.Add(new DsvSaveReader());

        if (Array.Find(args, static z => z is ToolStrip) is not ToolStrip menuStrip)
            return;
        if (menuStrip.Items.Find("Menu_Tools", false) is not [ToolStripDropDownItem tools])
            return;
        const string menuName = "Menu_PokemonYellowDOS";
        if (tools.DropDownItems.Find(menuName, false).Length != 0)
            return; // already added (re-initialize guard)
        var ourMenu = new ToolStripMenuItem("Pokémon Yellow DOS") { Name = menuName };
        ourMenu.DropDownItems.Add(new ToolStripMenuItem("Export as .dsv (DOS Port)...", null, ExportDsv));
        ourMenu.DropDownItems.Add(new ToolStripMenuItem("Export as .sav (Standard GB)...", null, ExportSav));
        tools.DropDownItems.Add(ourMenu);
    }

    public void NotifySaveLoaded() { }

    public void NotifyDisplayLanguageChanged(string language) { }

    public bool TryLoadFile(string filePath)
    {
        byte[] data;
        try { data = File.ReadAllBytes(filePath); }
        catch { return false; }

        if (!DsvFormat.IsDeSmuME(data))
            return false;

        MessageBox.Show(
            "This file appears to be a Nintendo DS (DeSmuME) save file.\n\n" +
            "DeSmuME and the Pokémon Yellow DOS port both use the .dsv extension, but their formats differ.\n" +
            "Please export a raw save in DeSmuME via File -> Export Backup Memory.",
            "DeSmuME Save Detected",
            MessageBoxButtons.OK,
            MessageBoxIcon.Information);
        return true; // handled (rejected with guidance)
    }

    private void ExportDsv(object? sender, EventArgs e)
    {
        if (SaveFileEditor.SAV is not SAV1 sav)
        {
            MessageBox.Show("Current save is not a Generation 1 save file.", "Export Error", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return;
        }

        // Write() recomputes checksums (there is no SetChecksums API) and
        // inherits stock-PKHeX export semantics exactly.
        byte[] payload = sav.Write().ToArray();
        if (payload.Length != DsvFormat.PayloadSize)
        {
            MessageBox.Show($"Unexpected save size {payload.Length} bytes (expected {DsvFormat.PayloadSize}).", "Export Error", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return;
        }
        byte[] dsvData = DsvFormat.BuildDsv(payload);

        using var sfd = new SaveFileDialog
        {
            Filter = "Pokémon Yellow DOS Save (*.dsv)|*.dsv",
            FileName = "POKEMON.DSV",
            Title = "Export DOS Port Save File"
        };

        if (sfd.ShowDialog() == DialogResult.OK)
        {
            File.WriteAllBytes(sfd.FileName, dsvData);
            MessageBox.Show($"Successfully exported {dsvData.Length} bytes to {Path.GetFileName(sfd.FileName)}", "Export Complete", MessageBoxButtons.OK, MessageBoxIcon.Information);
        }
    }

    private void ExportSav(object? sender, EventArgs e)
    {
        if (SaveFileEditor.SAV is not SAV1 sav)
        {
            MessageBox.Show("Current save is not a Generation 1 save file.", "Export Error", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return;
        }

        byte[] payload = sav.Write().ToArray();

        using var sfd = new SaveFileDialog
        {
            Filter = "Game Boy Save (*.sav)|*.sav",
            FileName = "POKEMON.SAV",
            Title = "Export Standard Game Boy Save File"
        };

        if (sfd.ShowDialog() == DialogResult.OK)
        {
            File.WriteAllBytes(sfd.FileName, payload);
            MessageBox.Show($"Successfully exported {payload.Length} bytes to {Path.GetFileName(sfd.FileName)}", "Export Complete", MessageBoxButtons.OK, MessageBoxIcon.Information);
        }
    }
}
```

---

### 6.3 Stage 1 verification record (2026-09-10)

All §6.1 steps executed against `dos_port/tests/fixtures/yellow_100.sav` (+ `yellow_boxes_full.sav`):
- Compiles clean under `gcc -std=c99/c89` and `clang -std=c99`, all with `-Wall -Wextra -Werror -pedantic`.
- Round-trip `--to-dsv` → `--to-sav` reproduces the fixture byte-for-byte (`cmp` clean); `--verify` accepts the product.
- Cross-tool parity: C `--to-dsv` output is byte-identical to `saveconv.py --to-dos` output (both report checksum `0x2DC5` on `yellow_100.sav`); `saveconv.py --to-gb` accepts the C-built `.dsv`.
- DeSmuME probe file rejected by `--verify` and `--to-dsv` with exit 1 and the Export-Backup-Memory guidance.
- Negative battery (bad magic / version / checksum / truncated / swapped extensions / no args) all exit 1 with naming-the-problem messages; no `.tmp` residue (atomic rename confirmed).
- Big-endian: no BE cross-gcc on this host, so no `qemu-ppc` execution run. Substituted with BE-target codegen inspection — the real source compiled with `clang --target=ppc32 -S`: checksum loops lower to `lbz`/`lbzu` byte loads, the u16 header store lowers to `sthbrx` (byte-reversed = explicit LE), the u16 read to `lbz`+shift/or, and no `lhz`/`lwz`/`sth` touches file bytes. Endian-agnostic by construction + LE-executed.
- Deliberate additions beyond §4.2: `--to-dos`/`--to-gb` aliases (match `saveconv.py` names), `--help`, stdout `prog` basename, DeSmuME probe on `--to-dsv` input too. `write_u32_le` is exercised via a `--verify` self-check (round-trips `SAV_SIZE` through it) so it stays compiled and covered despite having no on-disk 32-bit field.

## 6. Verification & Test Plan

### 6.1 Automated Testing Matrix

```bash
# 1. Compile dsv2sav with strict standard compliance
gcc -O2 -std=c99 -Wall -Wextra -Werror -pedantic dos_port/tools/dsv2sav.c -o dos_port/tools/dsv2sav

# 2. Invertibility & Round-Trip Check (Byte-for-Byte Identity)
./dos_port/tools/dsv2sav --to-dsv tests/fixtures/yellow_100.sav /tmp/test.dsv
./dos_port/tools/dsv2sav --to-sav /tmp/test.dsv /tmp/test.sav
cmp tests/fixtures/yellow_100.sav /tmp/test.sav

# 3. Cross-Tool Parity (C dsv2sav vs Python saveconv.py)
python3 dos_port/tools/saveconv.py --to-dos tests/fixtures/yellow_100.sav /tmp/py.dsv
cmp /tmp/test.dsv /tmp/py.dsv

# 4. DeSmuME Rejection Test
printf '%32784s|-DESMUME SAVE-|' '' > /tmp/fake_desmume.dsv
./dos_port/tools/dsv2sav --verify /tmp/fake_desmume.dsv  # Must exit non-zero with DeSmuME message

# 5. Big-Endian Simulation Test
# If qemu-user and powerpc-linux-gnu-gcc are available:
powerpc-linux-gnu-gcc -O2 -std=c99 dos_port/tools/dsv2sav.c -o /tmp/dsv2sav_ppc
qemu-ppc /tmp/dsv2sav_ppc --verify /tmp/test.dsv
qemu-ppc /tmp/dsv2sav_ppc --to-sav /tmp/test.dsv /tmp/test_ppc.sav
cmp /tmp/test.sav /tmp/test_ppc.sav
```

### 6.2 Manual End-to-End Verification
1. Boot the DOS port in DOSBox-X, save the game (`POKEMON.DSV`).
2. Copy `POKEMON.DSV` somewhere the wine prefix can see it and open it with the system `pkhex` wrapper (`pkhex` loads `PokemonYellowDOS.dll` + `PokemonYellowDOS.Core.dll` from the `plugins/` folder next to `PKHeX.exe`) via **File > Open or drag-drop** — not via command-line argument (startup files are parsed before plugins attach, so CLI-open cannot work for plugin formats).
3. Open `POKEMON.DSV` directly in PKHeX. Verify OT name, ID, party Pokémon stats/moves, Pokédex count, and current PC box load cleanly.
4. Modify a Pokémon (e.g. adjust IVs or level), use "Export as .dsv", and save back to `POKEMON.DSV`.
5. Copy back to DOSBox-X drive C: and boot the game. Confirm "CONTINUE" loads with modified stats and no save corruption error.
