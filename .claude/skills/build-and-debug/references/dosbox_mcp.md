# Live Symbolic Debugging via `dosbox-mcp`

Detailed operational guide for live symbolic debugging of the Pokémon Yellow DOS port using the `dosbox-x-mcp` fork and the `dosbox_mcp` MCP server.

---

## Architecture & Components

1. **`dosbox-x-mcp` fork**: Vendored as a git submodule in `dos_port/tools/dosbox-x` (branch `mcp-debug` on `Happyarch/dosbox-x`). It implements an MCP socket bridge thread and the `SYMF` native symbol table inside DOSBox-X. Built into binary `dos_port/tools/dosbox-x-mcp/dosbox-x-mcp` (and `~/.local/bin/dosbox-x-mcp`) so it never collides with the system `dosbox-x`.
2. **Symbol Pipeline (`pkmn.sym` → `SYMF`)**:
   - `dos_port/tools/generators/gen_symfile.py` extracts COFF symbols directly from `dos_port/PKMN.EXE` at every link, producing `dos_port/pkmn.sym` (~21.5k symbols, including NASM local labels like `_AdvancePlayerSprite.scroll`).
   - The MCP server (`dos_port/tools/dosbox_mcp/server.py`) re-reads `pkmn.sym` on mtime change; if `PKMN.EXE` is newer than `pkmn.sym`, it errors loudly.
   - Symbols are automatically loaded into the emulator's internal `SYMF` table upon first debugger pause. In the ncurses debugger UI, names resolve natively (`BP CS:OverworldLoop`, `EV MySym+4`, `SYMNEAR EIP`, `SYMLIST <pattern>`).
3. **Expression Parser Precedence**:
   - Precedence: `register / flag name` → `symbol` → `hex literal`.
   - Identifiers starting with a digit (`7B1C`) are always parsed as hex.
   - Pure hex symbols (e.g. `AddBCD`) resolve as symbols (`EV ADDBCD` yields the address). Double-quote a value (`EV "ADDBCD"`) to force literal hex parsing.

---

## Launcher & Execution Flow

### Launching the Debugger Session
```sh
dos_port/run-mcp [make args] [/EXE flags]
```
- Arguments without `/` are passed to `make` (e.g. `make image` auto-build).
- Tokens starting with `/` are passed to `PKMN.EXE` (e.g. `/LOOP`, `/NOSOUND`).
- Mounts the isolated FAT disk image `PKMN.IMG` as `C:`. Game-written files land inside the image:
  ```sh
  mcopy -n -i PKMN.IMG@@1048576 ::FRAME.BIN .
  ```
- Does **not** pass `-break-start`: runtime selectors exist only after `PKMN.EXE` is loaded into memory by CWSDPMI.

### Canonical MCP Debugging Flow
1. `pause_exec()` — pause free-running emulator via the bridge's BREAK request.
2. `set_breakpoint("OverworldLoop")` — arm breakpoint on any `pkmn.sym` symbol (global or local) or hex offset.
3. `continue_exec()` — resume execution and wait for the break. Break reports are annotated (`EIP=00007B1C (OverworldLoop)`).
4. `wait_break()` — collect a break notification that outlives a RUN timeout without tearing down the socket.
5. `where()` — inspect nearest symbol at or below current `EIP`.
6. Inspect state:
   - `get_registers()`: dump general registers, flags, and segment selectors.
   - `gb_read(addr, len)` / `x86_read(addr, len)`: read emulated memory.
   - `dump_frame()` / `screenshot()`: capture visual state (see distinction below).
   - `disassemble()`: non-destructive disassembly around `EIP` with symbol annotations.

---

## Visual Inspection: `dump_frame` vs `screenshot`

| Attribute | `dump_frame` | `screenshot` |
|---|---|---|
| **Source** | The GAME's software-PPU back buffer (`GB_BACKBUF`, 320×200), read out of emulated GB memory | The emulated DISPLAY: whatever DOSBox-X is currently rendering |
| **Emulator State** | Requires game alive, in pmode, selectors resolvable (`_game_ctx()`) | Works without selectors, symbols, or even a live `PKMN.EXE` |
| **Crash State** | Fails outright if the game has crashed or faulted | Still works — captures console text |
| **Palette** | `render_frame.py` debug palette unless `PAL.BIN` is provided | Live VGA DAC output palette |

> [!IMPORTANT]
> `screenshot(output_png=...)` is the **only** mechanism that captures **DOS console text**, including the **DPMI page-fault register dump** (`Page Fault cr2=... at eip=...`), BIOS boot messages, or crash text. Use `screenshot` whenever a fault or crash occurs.

### Capture Image vs Raw Screenshot
- `screenshot` calls `CAPTURE_IMAGE` (render source + render palette).
- DOSBox-X's `CAPTURE_RAWIMAGE` (native VGA geometry, true DAC palette, `rPAL` chunk) requires a vertical retrace that never occurs while paused in the debugger. Do not invoke raw screenshot through the bridge while paused.

---

## Critical Traps & Protocol Gotchas

### 1. Breakpoint (BP) vs Memory Watchpoint (BPLM)
- `set_breakpoint` sets an execution breakpoint (`BP <cs>:<offset>`, `BKPNT_PHYSICAL`).
- `set_watchpoint` sets a memory-change watchpoint (`BPLM`). Setting `BPLM` on *code* bytes will never trigger because code bytes do not change during execution.

### 2. CWSDPMI Runtime Selectors vs Raw Linear VMAs
- The CWSDPMI executable runs with base `0x00400000`. Raw VMAs from `pkmn.sym` cannot be accessed linearly without adding the segment base.
- MCP tools handle selector translation automatically via `REGJSON`/`SELINFO`. If issuing raw commands with `dbg_command`, resolve the segment base first.

### 3. Hex Arguments Quoting
- Bare hex numbers matching register or flag names are parsed as registers:
  - Selector `AF` parsed unquoted is interpreted as the Adjust Flag (0).
  - Always double-quote hex literals in raw commands: `EV "AF"`, `BP "00007B1C"`.

### 4. Build Mismatches & Handshake File
- `dos_port/run-mcp` writes `/tmp/dosbox-mcp.launch` atomically upon launch.
- `server.py` re-reads this handshake file on change to re-bind to the active worktree build.
- Verify symbol alignment:
  ```sh
  awk '$3=="PrintText"{print $1}' dos_port/pkmn.sym
  ```
  Compare with the address reported by `lookup_symbol("PrintText")`. If mismatched, re-launch via `dos_port/run-mcp`. Do not kill `server.py`.

### 5. RUN-Outstanding Discipline
- The MCP bridge services **exactly one command at a time**.
- When `continue_exec()` has been called, `wait_break()` is the **only** call that can proceed. All other tools bounce with `"a previous command's response is still pending"`.
- Never open a second socket connection to the Unix bridge socket — it wedges the C-side bridge thread in `cond_wait`.
- If the game hangs and no breakpoint is reached, the agent cannot break in via socket. The human pilot must press `Alt+Pause` (or use the Debug menu in DOSBox-X) to trigger the debugger.
- Keep `wait_break()` timeouts under the transport limit (e.g. ≤45 s; transport times out at ~60 s with `-32001`).

### 6. Process Management: NEVER `pkill -f dosbox`
- `pkill -f dosbox` matches `tools/dosbox_mcp/server.py` and terminates the MCP server, permanently disconnecting the session's tools.
- Always kill the fork binary specifically: `pkill -f dosbox-x-mcp` or kill by PID.

---

## Rebuilding the Debugger Submodule

If changes are made to the bridge code in `dos_port/tools/dosbox-x`:
```sh
dos_port/tools/build_dosbox_mcp.sh
```
This script rsyncs the working tree to a temporary space-free directory (autotools fails on path spaces), compiles `dosbox-x-mcp`, and installs copies to `tools/dosbox-x-mcp/` and `~/.local/bin/`. Commit the submodule commit SHA to the main repository when done.
