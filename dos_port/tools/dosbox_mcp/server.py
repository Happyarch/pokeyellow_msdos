#!/usr/bin/env python3
"""
DOSBox-X MCP Debug Server for the Pokemon Yellow DOS Port.

Exposes tools that let an LLM drive the DOSBox-X heavy debugger via a
Unix domain socket patched into DOSBox-X.  High-level tools know about
the GB address space (EBP + gb_offset) and translate symbol names via
pkmn.map / gb_memmap.inc.

Address model (verified live 2026-07-06):
  PKMN.EXE is a DJGPP/CWSDPMI protected-mode image.  Its CS/DS descriptors
  share a nonzero base (observed 0x00400000), so a pkmn.map VMA is the
  *segment offset* of a routine, NOT its linear address.  Every debugger
  command that takes seg:ofs therefore uses the game's own selectors
  (read from REGJSON while paused inside the game):
    execution breakpoint:  BP "<cs>":"<vma>"
    memory dump:           MEMDUMPBIN "<ds>":"<EBP+gb_offset>"
  Hex arguments are double-quoted because the debugger's expression parser
  resolves bare names like AF/BP/DX as registers/flags first (a DS selector
  of literally "AF" parsed as the adjust flag = 0 — the original silent
  breakage of this harness, along with using BPLM, which is a memory-CHANGE
  watchpoint, not an execution breakpoint).

Pause/resume model: the DOSBox-X patch only processes socket commands while
its emulation thread sits in the (headless) debugger loop.  While the game
free-runs, exactly one thing works: the BREAK request (pause_exec), whose
reply is produced by the next debugger entry.  After a RUN, the reply
arrives when a breakpoint hits — if a tool times out waiting, the response
stays *pending* and wait_break() collects it.

Usage (started by run_with_mcp.sh or Claude Code MCP config):
  python3 tools/dosbox_mcp/server.py

Environment:
  DOSBOX_MCP_SOCKET  path to Unix socket  (default /tmp/dosbox-mcp.sock)
  PKMN_MAP           path to pkmn.map     (default dos_port/pkmn.map)
  GB_MEMMAP_INC      path to gb_memmap.inc
  DOSBOX_MCP_DIR     directory where MEMDUMP.BIN / FRAME.BIN are written
                     (default: same dir as PKMN.EXE, typically dos_port/)
"""

import os
import sys
import json
import shutil
import subprocess
from pathlib import Path
from typing import Optional

# Allow running from repo root or tools/ dir
_HERE = Path(__file__).parent
_REPO = _HERE.parent.parent.parent  # dos_port/tools/dosbox_mcp → dos_port/tools → dos_port → repo root

sys.path.insert(0, str(_HERE))
from symbol_map import SymbolMap
from socket_client import DebugSocketClient, ResponseTimeout, PendingResponse

from mcp.server.fastmcp import FastMCP

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

SOCK_PATH  = os.environ.get('DOSBOX_MCP_SOCKET', '/tmp/dosbox-mcp.sock')
MAP_FILE   = os.environ.get('PKMN_MAP',    str(_REPO / 'dos_port' / 'pkmn.map'))
MEMMAP_INC = os.environ.get('GB_MEMMAP_INC', str(_REPO / 'dos_port' / 'include' / 'gb_memmap.inc'))
DUMP_DIR   = os.environ.get('DOSBOX_MCP_DIR', str(_REPO / 'dos_port'))
RENDER_PY  = str(_REPO / 'dos_port' / 'tools' / 'render_frame.py')

GB_BACKBUF      = 0x12000   # back buffer offset in GB space (gb_memmap.inc)
GB_BACKBUF_SIZE = 64000     # 320 × 200

# ---------------------------------------------------------------------------
# Singletons / state
# ---------------------------------------------------------------------------

_syms = SymbolMap(MAP_FILE, MEMMAP_INC)
_client = DebugSocketClient(SOCK_PATH, timeout=120.0)

# Execution state as best the client can track it:
#   'unknown' — just launched / reconnected; game may be free-running
#   'paused'  — last exchange ended inside the debugger loop
#   'running' — a RUN was issued and its break notification is still pending
_state = 'unknown'

# Cached while paused inside the game — stable across a session
_cached_ebp: Optional[int] = None
_cached_cs: Optional[str] = None   # hex selector strings as REGJSON prints them
_cached_ds: Optional[str] = None
_cached_ds_base: Optional[int] = None

mcp = FastMCP("dosbox-debugger")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _q(val) -> str:
    """Quote a hex value for the DOSBox-X expression parser.  Bare hex like
    AF/BP/DX otherwise parses as a register or flag name."""
    if isinstance(val, int):
        return f'"{val:X}"'
    return f'"{val}"'


def _cmd(raw: str, timeout: float = 60.0) -> str:
    """Send a raw debugger command, return captured output (or error text)."""
    try:
        _client.connect()
    except OSError as e:
        return f"ERROR: cannot connect to {SOCK_PATH}: {e}"
    return _client.command(raw, timeout=timeout)


def _parse_regjson(out: str) -> dict:
    for line in out.splitlines():
        line = line.strip()
        if line.startswith('{'):
            try:
                return json.loads(line)
            except json.JSONDecodeError:
                break
    return {'error': out}


def _regs() -> dict:
    """Return current x86 registers as a dict, caching EBP/CS/DS."""
    global _cached_ebp, _cached_cs, _cached_ds, _state
    out = _cmd('REGJSON', timeout=15.0)
    regs = _parse_regjson(out)
    if 'error' not in regs:
        _state = 'paused'
        _cached_ebp = int(regs['EBP'], 16)
        _cached_cs = regs['CS']
        _cached_ds = regs['DS']
    return regs


def _sel_base(sel: str) -> Optional[int]:
    """Return the base linear address of a selector via SELINFO, or None."""
    import re
    out = _cmd(f'SELINFO {_q(sel)}', timeout=15.0)
    m = re.search(r'\bb:([0-9A-Fa-f]{8})', out)
    return int(m.group(1), 16) if m else None


def _game_ctx() -> Optional[str]:
    """Ensure we are paused inside the game (pmode, selectors known).
    Returns None when ready, or an error string."""
    global _cached_ds_base
    if _state == 'running':
        return ("ERROR: game is running — a RUN is waiting for a breakpoint. "
                "Use wait_break() to wait for it (or restart with breakpoints "
                "set before continuing).")
    if _client.has_pending():
        return ("ERROR: a previous command's response is still pending — "
                "call wait_break() to collect it.")
    regs = _regs()
    if 'error' in regs:
        return f"ERROR: cannot read registers: {regs['error']}"
    if _cached_ds_base is None:
        _cached_ds_base = _sel_base(_cached_ds)
    if _cached_ds_base is None:
        return (f"ERROR: DS selector {_cached_ds} has no descriptor — the CPU "
                "is not in the game's protected-mode context yet (still "
                "booting DOS?). Let the game reach the overworld, then "
                "pause_exec() and retry.")
    return None


def _resolve_gb_offset(offset_or_name: str) -> Optional[int]:
    if offset_or_name.startswith('0x') or all(
            c in '0123456789abcdefABCDEF' for c in offset_or_name):
        return int(offset_or_name, 16)
    return _syms.gb_offset(offset_or_name)


def _memdump(seg_offset: int, length: int) -> bytes | str:
    """MEMDUMPBIN via the game DS selector; returns bytes or error string."""
    out = _cmd(f'MEMDUMPBIN {_q(_cached_ds)}:{_q(seg_offset)} {_q(length)}',
               timeout=60.0)
    dump_path = Path(DUMP_DIR) / 'MEMDUMP.BIN'
    if not dump_path.exists():
        return f"ERROR: MEMDUMP.BIN not found in {DUMP_DIR}. Debugger output:\n{out}"
    data = dump_path.read_bytes()[:length]
    dump_path.unlink()  # clean up for next call
    return data


def _hexdump(data: bytes, base: int, base_fmt: str = '{:08X}') -> str:
    lines = []
    for i in range(0, len(data), 16):
        chunk = data[i:i+16]
        hex_part = ' '.join(f'{b:02X}' for b in chunk)
        asc_part = ''.join(chr(b) if 32 <= b < 127 else '.' for b in chunk)
        lines.append(f"{base_fmt.format(base+i)}  {hex_part:<48}  {asc_part}")
    return '\n'.join(lines)


# ---------------------------------------------------------------------------
# MCP Tools
# ---------------------------------------------------------------------------

@mcp.tool()
def dbg_command(cmd: str) -> str:
    """
    Send any raw DOSBox-X debugger command and return its text output.
    Examples: 'BPLIST', 'REGJSON', 'SELINFO "A7"', 'BP "A7":"4996"'
    Only works while the game is paused in the debugger. CAUTION: bare hex
    arguments that spell a register/flag name (AF, BP, DX, CF, ...) are
    parsed as that register — double-quote hex values ("AF") to force
    numeric interpretation.
    """
    try:
        return _cmd(cmd)
    except (ResponseTimeout, PendingResponse) as e:
        return f"ERROR: {e}"


@mcp.tool()
def pause_exec() -> str:
    """
    Pause a free-running game (like hitting the debugger hotkey): breaks into
    the debugger at the current instruction. Use this right after launching
    DOSBox-X, before setting breakpoints. No-op if already paused.
    """
    global _state
    if _state == 'paused':
        return "Already paused."
    try:
        _client.connect()
    except OSError as e:
        return f"ERROR: cannot connect to {SOCK_PATH}: {e}"
    try:
        out = _client.command('BREAK', timeout=20.0)
    except ResponseTimeout:
        _state = 'unknown'
        return ("ERROR: BREAK sent but no debugger entry occurred within 20 s. "
                "If the game was already paused this request is queued and "
                "harmless; wait_break() collects it after the next resume. "
                "Otherwise the emulator may be wedged — press the debugger "
                "hotkey in the DOSBox-X window or restart it.")
    except PendingResponse as e:
        return f"ERROR: {e}"
    _state = 'paused'
    return out


@mcp.tool()
def wait_break(timeout: float = 300.0) -> str:
    """
    Wait for the pending break notification (after continue_exec timed out or
    was called with wait_for_break=False). Returns the BREAK message with
    EIP/EBP when a breakpoint hits.
    """
    global _state
    if not _client.has_pending():
        return "No response pending — the game is already paused (or nothing was run)."
    try:
        out = _client.wait_response(timeout=timeout)
    except ResponseTimeout:
        return (f"Still running after {timeout:.0f}s — no breakpoint hit yet. "
                "Call wait_break() again to keep waiting.")
    _state = 'paused'
    return out


@mcp.tool()
def get_registers() -> str:
    """
    Return all x86 registers as JSON (EAX, EBX, ECX, EDX, ESI, EDI, EBP,
    ESP, EIP, EFLAGS, CS, DS, ES, SS).  EBP is the base of the emulated GB
    address space; HL maps to ESI; BC→BX; DE→DX; A→AL.
    Only valid while paused (pause_exec / breakpoint hit).
    """
    try:
        regs = _regs()
    except (ResponseTimeout, PendingResponse) as e:
        return f"ERROR: {e}"
    return json.dumps(regs, indent=2)


@mcp.tool()
def lookup_symbol(name: str) -> str:
    """
    Resolve a symbol name using pkmn.map. Code/data symbols return the
    program (VMA) address — the value set_breakpoint/x86_read expect.
    Prefix 'gb:' looks up GB memory constants from gb_memmap.inc instead.
    Example: lookup_symbol("OverworldLoop") or lookup_symbol("gb:W_CUR_MAP")
    """
    if name.startswith('gb:'):
        gb_name = name[3:]
        off = _syms.gb_offset(gb_name)
        if off is None:
            return f"Not found in gb_memmap.inc: {gb_name}"
        extra = ''
        if _cached_ebp is not None:
            extra = f", DS offset=0x{_cached_ebp + off:08X}"
            if _cached_ds_base is not None:
                extra += f", linear=0x{_cached_ds_base + _cached_ebp + off:08X}"
        return f"{gb_name}: GB offset=0x{off:04X}{extra}"
    addr = _syms.resolve(name)
    if addr is None:
        matches = _syms.search(name)
        if matches:
            lines = [f"{n}: 0x{a:08X}" for n, a in matches[:10]]
            return "Partial matches:\n" + "\n".join(lines)
        return f"Symbol not found: {name}"
    return f"{name}: 0x{addr:08X} (program/VMA address)"


@mcp.tool()
def search_symbols(pattern: str) -> str:
    """
    Search pkmn.map symbol names by regex pattern (case-insensitive).
    Returns up to 20 matches with their program (VMA) addresses.
    Example: search_symbols("Overworld") or search_symbols("^Load")
    """
    matches = _syms.search(pattern)[:20]
    if not matches:
        return f"No symbols match: {pattern}"
    return "\n".join(f"0x{a:08X}  {n}" for n, a in sorted(matches, key=lambda x: x[1]))


@mcp.tool()
def set_breakpoint(symbol_or_addr: str) -> str:
    """
    Set an execution breakpoint at a pkmn.map symbol or program (VMA) hex
    address. The game must be paused inside the debugger first (pause_exec
    or an earlier breakpoint). Example: set_breakpoint("OverworldLoop")
    """
    err = _game_ctx()
    if err:
        return err
    addr = _syms.resolve(symbol_or_addr)
    if addr is None:
        return f"Cannot resolve: {symbol_or_addr}"
    try:
        out = _cmd(f'BP {_q(_cached_cs)}:{_q(addr)}')
    except (ResponseTimeout, PendingResponse) as e:
        return f"ERROR: {e}"
    return f"{out}\n({symbol_or_addr} = VMA 0x{addr:08X}, CS={_cached_cs})"


@mcp.tool()
def set_watchpoint(gb_offset_or_name: str) -> str:
    """
    Set a memory-CHANGE watchpoint on one byte of the emulated GB address
    space: execution breaks when the byte's value changes. Argument is a hex
    GB offset (e.g. "D35E") or a gb_memmap.inc constant (e.g. "W_CUR_MAP").
    The game must be paused first.
    """
    err = _game_ctx()
    if err:
        return err
    off = _resolve_gb_offset(gb_offset_or_name)
    if off is None:
        return f"Unknown GB symbol: {gb_offset_or_name}"
    linear = _cached_ds_base + _cached_ebp + off
    try:
        out = _cmd(f'BPLM {_q(linear)}')
    except (ResponseTimeout, PendingResponse) as e:
        return f"ERROR: {e}"
    return f"{out}\n(GB+0x{off:04X} → linear 0x{linear:08X})"


@mcp.tool()
def list_breakpoints() -> str:
    """List all currently set breakpoints (indices for delete_breakpoint)."""
    try:
        return _cmd("BPLIST")
    except (ResponseTimeout, PendingResponse) as e:
        return f"ERROR: {e}"


@mcp.tool()
def delete_breakpoint(number: int) -> str:
    """Delete breakpoint by its list index (from list_breakpoints).
    Pass -1 to delete ALL breakpoints."""
    try:
        if number < 0:
            return _cmd("BPDEL *")
        return _cmd(f"BPDEL {number:X}")  # debugger parses the index as hex
    except (ResponseTimeout, PendingResponse) as e:
        return f"ERROR: {e}"


@mcp.tool()
def continue_exec(wait_for_break: bool = True, timeout: float = 300.0) -> str:
    """
    Resume execution (RUN).  With wait_for_break=True (default) blocks until
    a breakpoint is hit and returns the break location; if the timeout
    expires the game keeps running and wait_break() collects the hit later.
    With wait_for_break=False returns immediately ('RUNNING'); use
    wait_break() to collect the breakpoint hit. NOTE: set breakpoints BEFORE
    continuing — while the game runs, only wait_break() works.
    """
    global _state
    if _state == 'running' or _client.has_pending():
        return "ERROR: already running — use wait_break()."
    try:
        _client.connect()
    except OSError as e:
        return f"ERROR: cannot connect to {SOCK_PATH}: {e}"
    if not wait_for_break:
        try:
            _client.send_only('RUN')
        except PendingResponse as e:
            return f"ERROR: {e}"
        _state = 'running'
        return "RUNNING — call wait_break() to collect the next breakpoint hit."
    try:
        out = _client.command('RUN', timeout=timeout)
    except ResponseTimeout:
        _state = 'running'
        return (f"Still running after {timeout:.0f}s — no breakpoint hit yet. "
                "wait_break() keeps waiting for it.")
    except PendingResponse as e:
        return f"ERROR: {e}"
    _state = 'paused'
    return out


@mcp.tool()
def gb_read(offset_or_name: str, length: int) -> str:
    """
    Read bytes from the emulated GB address space (only while paused).
    offset_or_name: hex GB offset (e.g. "C000") or gb_memmap.inc constant
                    name (e.g. "W_CUR_MAP").
    length: number of bytes to read (max 4096).
    Returns a hex dump of the memory contents.
    """
    err = _game_ctx()
    if err:
        return err
    gb_off = _resolve_gb_offset(offset_or_name)
    if gb_off is None:
        return f"Unknown GB symbol: {offset_or_name}"
    length = min(length, 4096)
    data = _memdump(_cached_ebp + gb_off, length)
    if isinstance(data, str):
        return data
    return _hexdump(data, gb_off, 'GB+{:04X}')


@mcp.tool()
def x86_read(addr: str, length: int) -> str:
    """
    Read raw program memory (only while paused). addr is a program (VMA) hex
    address as found in pkmn.map — e.g. "1000" for the start of .text — NOT
    a GB offset. Useful for reading code or embedded data sections.
    """
    err = _game_ctx()
    if err:
        return err
    vma = int(addr, 16)
    length = min(length, 4096)
    data = _memdump(vma, length)
    if isinstance(data, str):
        return data
    return _hexdump(data, vma)


@mcp.tool()
def dump_frame(output_png: str = '/tmp/dosbox_frame.png') -> str:
    """
    Dump the current software-PPU back buffer (320×200) to a PNG and return
    its path. Requires the game to be paused. The PNG uses the DMG-green
    palette (values 0-3) plus sprite overlay colors.
    """
    err = _game_ctx()
    if err:
        return err
    data = _memdump(_cached_ebp + GB_BACKBUF, GB_BACKBUF_SIZE)
    if isinstance(data, str):
        return data
    frame_dst = Path(DUMP_DIR) / 'FRAME.BIN'
    frame_dst.write_bytes(data)
    result = subprocess.run(
        [sys.executable, RENDER_PY, str(frame_dst), output_png],
        capture_output=True, text=True
    )
    frame_dst.unlink(missing_ok=True)
    if result.returncode != 0:
        return f"render_frame.py failed:\n{result.stderr}"
    return f"Frame rendered to {output_png}"


@mcp.tool()
def disassemble(symbol_or_addr: str, count: int = 10) -> str:
    """
    Disassemble 'count' instructions starting at a pkmn.map symbol or program
    (VMA) hex address, using ndisasm on bytes read from emulated memory.
    Does not disturb CPU state. Only while paused.
    """
    err = _game_ctx()
    if err:
        return err
    addr = _syms.resolve(symbol_or_addr)
    if addr is None:
        return f"Cannot resolve: {symbol_or_addr}"
    if shutil.which('ndisasm') is None:
        return "ERROR: ndisasm not found on host (install nasm)."
    nbytes = min(16 * count + 16, 4096)
    data = _memdump(addr, nbytes)
    if isinstance(data, str):
        return data
    result = subprocess.run(
        ['ndisasm', '-b', '32', '-o', f'0x{addr:X}', '/dev/stdin'],
        input=data, capture_output=True
    )
    if result.returncode != 0:
        return f"ndisasm failed:\n{result.stderr.decode(errors='replace')}"
    lines = result.stdout.decode(errors='replace').splitlines()
    return '\n'.join(lines[:count])


if __name__ == '__main__':
    mcp.run()
