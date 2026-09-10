# PokemonYellowDOS — PKHeX plugin for the DOS port `.dsv` save format

Lets the real PKHeX editor open the port's `POKEMON.DSV` files directly and
export back to `.dsv` (DOS port) or `.sav` (standard Game Boy). Stage 2 of
`docs/current_plan_save_converter_pkhex.md`.

Layout:

| Project | TFM | Runs on Linux? | Contents |
|---|---|---|---|
| `PokemonYellowDOS.Core` | `net10.0` | yes (build + test) | `DsvFormat` (header build/validate/strip/checksum, no PKHeX dependency) + `DsvSaveReader : ISaveReader` (load path) |
| `PokemonYellowDOS` | `net10.0-windows` | builds only | `DsvPlugin : IPlugin` (registers the reader, Tools-menu exports, DeSmuME guard) |
| `PokemonYellowDOS.Tests` | `net10.0` | yes (`dotnet test`) | xUnit suite for the Core paths |

## Legal / licensing — what may and may not be in the repo

- **PKHeX.Core is GPL-3.0-or-later.** That is the license field on its NuGet
  page, and it ships from the `kwsch/PKHeX` monorepo whose root license is
  GPLv3. There is no MIT-licensed PKHeX.Core; treat any such claim as wrong.
- **This directory contains no PKHeX code and no PKHeX binaries** — only a
  `PackageReference` plus original source written for this port. Nothing GPL
  is *in* the repo, so nothing in the repo triggers GPL obligations: at build
  time NuGet fetches PKHeX.Core from its publisher to *your* machine (same
  posture as `dos_port/tools/savegen`, same as the root `README.md`
  "Legal note": download third-party bits at build time, never commit them).
- **Linking is not distributing.** Our sources carry no GPL notice and need
  none — they are our code. GPL obligations attach only to the *combined
  binary*: building the DLLs for yourself is unrestricted; handing a built
  `PokemonYellowDOS.dll` to someone else means the combined work
  (our plugin + PKHeX.Core) is distributed under GPL-3.0-or-later terms
  (license text + corresponding source, which is this directory plus PKHeX
  itself). If the maintainer ever wants frictionless binary distribution,
  keep these sources under a GPL-compatible license — but that is a choice
  about distributing builds, not a requirement on the sources as they sit.
- **Do NOT commit:** `bin/`, `obj/`, `TestResults/` (gitignored per project),
  any built `PokemonYellowDOS*.dll`, any `.nupkg`, `PKHeX.exe`, or PKHeX source.
- Test fixtures under `dos_port/tests/fixtures/` are save *data* (user bytes,
  32 KiB SRAM images), already committed precedent — unaffected by the above.
- Note the repo root currently carries no `LICENSE` file at all; that is a
  separate maintainer decision, not something this plugin forces.

## Build

Needs the .NET 10 SDK (the plugin must run on PKHeX's framework; PKHeX itself
requires .NET 10, and PKHeX.Core 26.7.7 targets `net10.0`).

```sh
cd dos_port/tools/pkhex_plugin
dotnet build PokemonYellowDOS/PokemonYellowDOS.csproj -c Release
dotnet test PokemonYellowDOS.Tests/PokemonYellowDOS.Tests.csproj
```

Linux builds the `-windows` project compile-only (`EnableWindowsTargeting`;
the WindowsDesktop *runtime* does not exist on Linux, so only the
platform-neutral paths are executed here). The WinForms export dialogs are
Windows-only and stay untested until a Windows run.

Two host quirks, both measured 2026-09-10 on this machine:

1. **NuGet hangs (broken IPv6 route).** DNS returns IPv6 addresses for
   `api.nuget.org` but v6 traffic is blackholed (`curl -6` times out; a
   241-byte fetch took 30 s over v6 vs 0.2 s over v4), and .NET's HTTP stack
   waits on the dead route far longer than curl's happy-eyeballs fallback, so
   `dotnet restore` hangs forever at "Restoring packages...". Process-local
   fix, no system change:
   ```sh
   export DOTNET_SYSTEM_NET_DISABLEIPV6=1
   ```
   With it, restore takes ~1 s. The real fix is at the OS/network layer
   (remove the dead v6 default route); until then this export is required for
   every `dotnet` invocation on this host.
2. **No .NET 8 SDK here** (6.0/9.0/10.0 only) — one reason the plan's first
   draft (`net8.0-windows`, floating `Version="*"`) was changed: pinned
   `PKHeX.Core 26.7.7` (matches `savegen`, restorable offline from the local
   cache) on `net10.0-windows`, tracking the PKHeX app's own framework.

## Install (wine, for end users)

PKHeX runs under wine via the system `pkhex` wrapper (own prefix, .NET 10
desktop runtime inside). No Windows host needed.

1. Install the PKHeX version matching PKHeX.Core 26.7.7 (see its release notes;
   mixing a plugin built against one Core with a much newer/older PKHeX can
   break on API drift — the same caveat the PKHeX-Plugins project documents).
   Verified working: plugin built vs 26.7.7 loads and runs in app 26.08.26
   (Core API surface identical; cross-version binding fine).
2. `dotnet build -c Release`, then copy `PokemonYellowDOS.dll` **and**
   `PokemonYellowDOS.Core.dll` from
   `PokemonYellowDOS/bin/Release/net10.0-windows/` into the `plugins/` folder
   next to `PKHeX.exe`. (Two DLLs: the format core ships beside the plugin
   shell. `PKHeX.Core.dll` itself comes with PKHeX — never copy ours over it.)
3. Start PKHeX and open `POKEMON.DSV` via **File > Open (or drag-drop)**.
   Do NOT pass the `.dsv` on the command line: PKHeX parses startup files
   (`Program.Main`: `StartupUtil.GetStartup`) *before* plugins attach, so a
   plugin format can never CLI-open — that limitation hits every
   file-format plugin equally, not just this one. Post-startup opens go
   through `OpenFromPath` → the registered reader and work.

## Architecture (measured against PKHeX.Core 26.7.7, not assumed)

- **Load = `ISaveReader`, not `TryLoadFile` interception.** The first draft
  had the plugin strip the header inside `TryLoadFile`, but
  `ISaveFileProvider.SAV` is get-only (a plugin cannot hand a parsed save to
  the app) and `IPlugin` has no menu API. The sanctioned hook is
  `SaveUtil.CustomSaveReaders` (a public static registry): `DsvPlugin`
  registers `DsvSaveReader` at `Initialize`, and PKHeX's normal
  `FileUtil.GetSupportedFile` pipeline opens `.dsv` natively — backups,
  title, editors, everything stock. The reader only claims 32775-byte files
  with valid `DOSV` magic + version + checksum, so the
  `SaveHandlerFooterRTC` trap never sees them.
- **`TryLoadFile` keeps one job:** the DeSmuME collision guard
  (`OpenFromPath` consults plugins before its own checks, so a DS `.dsv`
  gets a guidance dialog instead of a cryptic failure).
- **Export = `SAV1.Write()`** (there is no `SetChecksums()` API; `Write()`
  recomputes). Two measured PKHeX behaviors the code and tests account for:
  - `SaveFile` **aliases its input buffer** (`Buffer = data`) and `Write()`
    **mutates it in place** (checksums + box merge). The reader therefore
    always hands PKHeX a fresh payload copy, and callers must treat any buffer
    given to `GetSaveFile` as consumed.
  - `Write()` **normalizes box layout** (repacks boxes through the unpacked
    scratch): honest `Write()` of `yellow_100.sav` differs in 7514 bytes, and
    a second `Write()` is a fixed point. Export behaves exactly like PKHeX's
    own File→Export on a raw `.sav` — no more, no less. The test suite asserts
    idempotence + equivalence-with-stock, not byte identity.

## Status

Toolchain + format core + reader + plugin shell + 18 green tests (Linux).
Verified under wine with the real app (26.08.26): plugin loads
(`Initialize` runs), and the exact `Main.OpenFile` pipeline
(`FileUtil.GetSupportedFile` → registered reader → `SAV1` YW / OT Player1 /
party 6) opens a `.dsv` built from `yellow_100.sav`.
Still open (Stage 2 remainder): interactive GUI pass — File > Open a real
`POKEMON.DSV`, verify party/boxes/dex on screen, export `.dsv`, boot it in
DOSBox-X via CONTINUE (plan §6.2). CLI-open cannot work (see above); the
export dialogs are Windows/wine-only and untested.
