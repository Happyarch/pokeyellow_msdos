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

### 5. RUN-Outstanding Discipline, and the Response-Pending Wedge
- The MCP bridge services **exactly one command at a time**.
- When `continue_exec()` has been called, `wait_break()` is the only call that can proceed. All other tools bounce with `"a previous command's response is still pending"`.
- **Never send a command-bearing tool before `pause_exec()`.** While the guest free-runs only BREAK is answerable; `load_debugger_symbols`, `set_breakpoint`, `gb_read`, `where`, `get_registers`, `x86_read` each issue a command that is serviced only at a debugger entry, so sending one first wedges `_pending` with no entry ever coming. `server.py` since `3c99fe298` (2026-10-01) takes a BREAK first in that state, but the ordering stays mandatory. See memory `regression-tooling-dosbox-mcp-bridge-wedge`.
- **Hung with no hit?** `force_break()` then `wait_break()`. The socket thread's `mcp_wait_for_response` polls the client socket every ~75 ms (`select` + `MSG_PEEK`), consumes a parked `BREAK\n`, and sets `mcp_break_pending`, which `Normal_Loop` turns into a debugger entry. **Live only in a fork built from `174d08bc9`+** (rebuilt 2026-10-01). An older binary reports "BREAK parked" and never fires; then the only recoveries are the pilot's `Alt+Pause` (or the Debug menu) and an emulator restart.
- Never open a second socket connection to the Unix bridge socket — it wedges the C-side bridge thread in `cond_wait`.
- Keep `wait_break()` timeouts under the transport limit (e.g. ≤45 s; transport times out at ~60 s with `-32001`).

### 5b. Verifying the running binary — do NOT trust `strings`/`nm`
Whether a debugger feature is actually compiled in cannot be answered by `strings`/`nm`: `mcp_break_pending` and the `MCPBREAKNOW` literal both exist in binaries that lack the preemption poll, and `git log -S<str>` reports the most-recent change, not the introducing commit. Both misled a 2026-10-01 investigation into the wrong conclusion. Check the **PLT imports of the enclosing function**:
```sh
B=dos_port/tools/dosbox-x-mcp/dosbox-x-mcp
ROW=$(nm -S "$B" | grep -E '_ZL21mcp_wait_for_responseib|_ZL17mcp_server_threadPv' | head -1)
A=$(echo "$ROW" | awk '{print $1}'); S=$(echo "$ROW" | awk '{print $2}')
objdump -d --start-address=0x$A --stop-address=0x$(printf '%x' $((0x$A+0x$S))) "$B" \
  | grep -oE '[a-zA-Z_][a-zA-Z0-9_]*@plt' | sort -u
```
`force_break` is live iff `mcp_wait_for_response` shows `select@plt`, two `recv@plt` (one carrying the `MSG_PEEK|MSG_DONTWAIT` immediate `0x42`) and `pthread_cond_timedwait@plt`. The wait logic is **outlined** into `mcp_wait_for_response` in recent builds, so grepping `mcp_server_thread` alone gives a false negative.

### 6. Process Management: NEVER `pkill -f dosbox`
- `pkill -f dosbox` matches `tools/dosbox_mcp/server.py` and terminates the MCP server, permanently disconnecting the session's tools.
- Always kill the fork binary specifically: `pkill -f dosbox-x-mcp` or kill by PID.

### 7. Server lifecycle (OpenCode V2)
- `dos_port/tools/dosbox_mcp/server.py` is a **long-lived** MCP child of `opencode serve --service`. It does **not** hot-reload `server.py`: an edit needs `opencode service restart` (`opencode reload` may suffice). Restarting the TUI/app does **not** recycle it.
- `opencode mcp list` shows server status; `opencode service status` shows the background server URL.
- The emulator picks up a **rebuilt fork binary** on its next launch — that half needs no server restart.

---

## Rebuilding the Debugger Submodule

If changes are made to the bridge code in `dos_port/tools/dosbox-x`:
```sh
dos_port/tools/build_dosbox_mcp.sh
```
This script rsyncs the working tree to a temporary space-free directory (autotools fails on path spaces), compiles `dosbox-x-mcp`, and installs copies to `tools/dosbox-x-mcp/` and `~/.local/bin/`. Commit the submodule commit SHA to the main repository when done.

### Known build break at mcp-debug HEAD (found 2026-10-01): `pas.cpp` include order
`src/hardware/pas.cpp` (PAS16 stage 4) included `dma.h` **before** `inout.h`. `dma.h`'s `DMAChannel` declares `IO_ReadHandleObject`/`IO_WriteHandleObject`, which only `inout.h` defines, and `dma.h` does not include it — so the build died with `'IO_ReadHandleObject' does not name a type`. **Fix: include `inout.h` before `dma.h`** (every other `dma.h` user already does; `pas.cpp` was the only one that did not).

Two traps around this:
- The script pipes `make` through `tail -10`, so its own log shows only a warning snippet, not the error. Re-run `make -j$(nproc)` in `/tmp/dosbox-x-mcp-build` to see the real failure.
- The script rsyncs the submodule working tree as-is, so an **uncommitted** submodule fix is picked up. If the `pas.cpp` reorder is not committed you can still build by patching `/tmp/dosbox-x-mcp-src/src/hardware/pas.cpp` and re-running `make` in the build dir, then copying `src/dosbox-x` over both installed binaries.
