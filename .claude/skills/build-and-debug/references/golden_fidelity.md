# Golden Fidelity Harness & Parallel Runner (`pgate.sh`)

Detailed reference for the golden fidelity harness, state comparison specifications, and the parallel runner architecture.

---

## Overview & Architecture

The golden fidelity harness provides byte-for-byte ground truth verification of the DOS port against the original game:
1. **Reference Engine (mGBA)**: Built with Lua scripting support (`tools/build_mgba.sh`). It runs the sha1-verified golden ROM built by root `make yellow` (`pokeyellow.gbc: OK` against `roms.sha1`, `cc7d0326...`).
2. **Deterministic Scenarios**: Lua scripts (`tools/mgba_harness/scenarios/*.lua`) boot the game, navigate through menus, and export committed golden dumps (`tests/goldens/<scenario>.bin` + `<scenario>.json` sidecars).
3. **Port Side Execution**: The DOS port builds the matching `DEBUG_*` flag, runs headless, and `src/debug/debug_dump.asm:DumpGBState` dumps `GBSTATE.BIN`.
4. **State Differ (`tools/golden_diff.py`)**: Resolves port widescreen projections and performs field-aware structural diffing across tilemaps, VRAM, OAM, and WRAM.

---

## `GBSTATE.BIN` v2 Format

`GBSTATE.BIN` is a self-describing binary format:
- **16-byte Header (`"GBST"`)**:
  - Magic: `"GBST"` (4 bytes)
  - Version: `2` (2 bytes)
  - Scenario ID: 2 bytes
  - Region count: 2 bytes
  - Directory size: 2 bytes
  - Total file size: 4 bytes
- **Region Directory**:
  - Array of descriptors: region name (ASCII string), GB address (16-bit), size (16-bit), payload byte offset (32-bit).
- **Payload Data**:
  - Raw memory buffers matching the directory order.

The golden differ matches regions by name and verifies memory-map bounds, ensuring memory layout drift fails loudly.

### Dffing Capabilities & Scenario Classes
- **Tilemaps**: Decoded into Game Boy charmap characters in diff reports.
- **VRAM**: Identifies clobbered 16-byte tile slots (e.g. `$73/$74` HUD-clobber class).
- **OAM**: Sprite positions, attributes, and tile indices.
- **WRAM Data Structures**: Field-aware decoding (`wPartyData mon 3 DVs`, `wBagItems slot 2 quantity`, etc.).
- **`"datastruct"` Class**: Exclusively diffs WRAM data structures, intentionally skipping transient render state (used for battle mechanics, items, captures).

---

## The Parallel Runner: `tools/pgate.sh`

`make fidelity` (core tier) and `make fidelity-full` (full tier) invoke `tools/pgate.sh` by default.

### Key Architecture & Performance Properties
1. **Isolated Scratch Copies**:
   - `pgate.sh` stages runs in isolated directories.
   - Trims base footprint from **1.1 GB to ~97 MB** by excluding emulator submodules (`tools/{dosbox-x,dosbox-x-mcp,mgba,mgba_build}`), object files (`*.o`), and disk binaries (`PKMN.EXE`, `PKMN.IMG`).
2. **Bounded Concurrency**:
   - Concurrency is bounded to `nproc / 6`, clamped between `[4, 24]` (overridable with `PGATE_JOBS`).
   - DOSBox-X emulation is essentially single-threaded; oversubscription leads to false timeouts in `goldencheck.sh`.
3. **Pacing by Emulated Time (Negative Result: `cycles=max`)**:
   - Setting `cycles=max` in DOSBox-X does **not** speed up execution (e.g. 267 s vs 250 s stock).
   - Scenarios are gated by emulated hardware timers (`wait_vblank` + PIT 60 Hz interrupts). DOSBox paces these against wall-clock time regardless of host CPU speed.
4. **Failure on Any Gap**:
   - `pgate.sh` reports a non-zero exit code if any scenario fails to report. Never judge a run solely by PASS counts (a scenario that crashed before reporting emits neither PASS nor FAIL).
5. **Image Cleanup**:
   - `goldencheck.sh` explicitly `mdel`s `GBSTATE.BIN`, `DUMP.BIN`, `FRAME.BIN`, `PAL.BIN`, and `POKEMON.DSV` before each run to eliminate stale artifacts.

---

## Verification & Golden Generation

```sh
# Verify all committed goldens against fresh Lua runs (detects ROM/script drift)
make -C dos_port goldens-verify

# Regenerate committed goldens (sha1-gated against roms.sha1)
make -C dos_port goldens

# Manual inspection of golden sidecars
tools/mgba_harness/inspect_golden.py tests/goldens/status_p1.json
```

---

## Registering a New Scenario

To add a new golden scenario:
1. Create a Lua script in `dos_port/tools/mgba_harness/scenarios/<name>.lua`.
2. Register the scenario in `dos_port/tools/scenario_manifest.json`:
   - `name`, `id`, `tier` (`"core"` or `"full"`).
   - `build_flags` (the `DEBUG_*` make variable).
   - `port_entry_gate` (routine or hook).
   - `dump_type`, `timeout`, and `must_hit` symbol list.
3. Add entry to `dos_port/tools/golden_diff.py`'s `SCENARIOS` table with any required region masks and justification strings.
4. Add the `%ifdef DEBUG_<NAME>` harness in the port code calling `DumpGBState`.
5. Validate configuration with:
   ```sh
   python3 dos_port/tools/validate_scenarios.py
   ```

---

## Live Differential Debugging (`mgba-mcp`)

For live side-by-side bisection:
1. Start the mGBA Lua agent:
   ```sh
   dos_port/tools/run_mgba_mcp.sh
   ```
   (Starts mGBA with resident agent `tools/mgba_harness/mcp_agent.lua` listening on TCP port 8765).
2. Start the MCP server:
   ```sh
   python3 dos_port/tools/mgba_mcp/server.py
   ```
3. With both `dosbox-mcp` (port side) and `mgba-mcp` (ground truth side) active, inspect the identical pret symbol addresses on both sides to locate where state diverged.

---

## Mask Policy & False Witness Discipline

- **Masks require written justifications**: A divergence mask in `golden_diff.py` requires a written `why` string citing an active finding or deviation. See the `faithfulness-review` skill.
- **False Witness Discipline**: Verify that a scenario actually executes the routine under test. If a scenario passes with an unchanged dump between parameter changes, the harness is taking an early return and not testing the target code.
