#!/usr/bin/env python3
"""
mGBA MCP bridge for the Pokemon Yellow fidelity harness (plan Stage 1.5).

Structural twin of tools/dosbox_mcp/server.py, but for GROUND TRUTH: it
drives the sha1-verified pokeyellow ROM inside tools/mgba_build/
mgba-lua-runner via the resident agent script tools/mgba_harness/
mcp_agent.lua (newline-delimited JSON over TCP 127.0.0.1:$MGBA_MCP_PORT).

Execution model: the agent blocks the emulator between commands (debugger
semantics). run_frames / press_buttons advance emulated time; everything
else inspects the paused core. Together with dosbox-mcp on the port this
gives label-addressed differential debugging: same pret symbol, one read on
each side.

Start the emulator side first:  tools/run_mgba_mcp.sh
Then this server (MCP stdio):   python3 tools/mgba_mcp/server.py

Environment:
  MGBA_MCP_PORT   agent TCP port           (default 8765)
  MGBA_MCP_HOST   agent host               (default 127.0.0.1)
"""

import json
import os
import socket
from typing import Optional

from mcp.server.fastmcp import FastMCP

HOST = os.environ.get("MGBA_MCP_HOST", "127.0.0.1")
PORT = int(os.environ.get("MGBA_MCP_PORT", "8765"))

mcp = FastMCP("mgba-groundtruth")

_sock: Optional[socket.socket] = None
_file = None


def _connect():
    global _sock, _file
    if _sock is not None:
        return
    _sock = socket.create_connection((HOST, PORT), timeout=300)
    _file = _sock.makefile("rw")


def _cmd(obj: dict) -> dict:
    """Send one command, wait for its reply. Reconnects once on failure."""
    global _sock, _file
    for attempt in (1, 2):
        try:
            _connect()
            _file.write(json.dumps(obj) + "\n")
            _file.flush()
            line = _file.readline()
            if not line:
                raise ConnectionError("agent closed the connection")
            return json.loads(line)
        except (OSError, ConnectionError, json.JSONDecodeError) as e:
            _sock = None
            _file = None
            if attempt == 2:
                return {"ok": False, "error": f"agent unreachable: {e} "
                        f"(is tools/run_mgba_mcp.sh running on port {PORT}?)"}
    return {"ok": False, "error": "unreachable"}


@mcp.tool()
def gb_read(offset_or_name: str, length: int = 1) -> str:
    """Read GB memory from the ground-truth ROM by pret label or address.

    offset_or_name: a pret symbol (e.g. 'wTileMap', 'wPartyMon1') resolved via
    the golden pokeyellow.sym, or a hex/decimal address ('0xC3A0').
    Returns a hex dump of `length` bytes.
    """
    addr: object = offset_or_name
    try:
        addr = int(offset_or_name, 0)
    except ValueError:
        pass
    r = _cmd({"cmd": "read", "addr": addr, "len": length})
    if not r.get("ok"):
        return f"ERROR: {r.get('error')}"
    data = bytes.fromhex(r["hex"])
    lines = []
    base = r.get("addr", 0)
    for i in range(0, len(data), 16):
        chunk = data[i:i + 16]
        lines.append(f"{base + i:04X}: {' '.join(f'{b:02X}' for b in chunk)}")
    return "\n".join(lines)


@mcp.tool()
def run_frames(n: int = 1) -> str:
    """Advance the emulator by n frames, then pause again."""
    r = _cmd({"cmd": "run_frames", "n": n})
    return f"at frame {r.get('frame')}" if r.get("ok") else f"ERROR: {r.get('error')}"


@mcp.tool()
def press_buttons(buttons: str, hold_frames: int = 2, gap_frames: int = 10) -> str:
    """Press GB buttons (comma-separated: A,B,START,SELECT,UP,DOWN,LEFT,RIGHT),
    hold them hold_frames, release, then run gap_frames more so the game
    consumes the edge. Pauses afterwards."""
    keys = [k.strip().upper() for k in buttons.split(",") if k.strip()]
    r = _cmd({"cmd": "press", "keys": keys, "hold": hold_frames, "gap": gap_frames})
    return f"pressed {'+'.join(keys)}, at frame {r.get('frame')}" if r.get("ok") \
        else f"ERROR: {r.get('error')}"


@mcp.tool()
def dump_state(path: str = "/tmp/mgba_mcp.ss0") -> str:
    """Save an emulator savestate to `path` (local speed cache; goldens never
    depend on savestates)."""
    r = _cmd({"cmd": "save_state", "path": path})
    return f"saved {path}" if r.get("ok") else f"ERROR: {r.get('error') or 'save failed'}"


@mcp.tool()
def load_state(path: str = "/tmp/mgba_mcp.ss0") -> str:
    """Load an emulator savestate from `path`."""
    r = _cmd({"cmd": "load_state", "path": path})
    return f"loaded {path}" if r.get("ok") else f"ERROR: {r.get('error') or 'load failed'}"


@mcp.tool()
def screenshot(path: str = "/tmp/mgba_frame.png") -> str:
    """Write a PNG screenshot of the current frame to `path`."""
    r = _cmd({"cmd": "screenshot", "path": path})
    return f"wrote {path}" if r.get("ok") else f"ERROR: {r.get('error')}"


@mcp.tool()
def current_frame() -> str:
    """Report the current emulated frame number (ping)."""
    r = _cmd({"cmd": "ping"})
    return f"frame {r.get('frame')}" if r.get("ok") else f"ERROR: {r.get('error')}"


@mcp.tool()
def quit() -> str:
    """Shut the ground-truth emulator down cleanly."""
    r = _cmd({"cmd": "quit"})
    return "emulator exited" if r.get("ok") else f"ERROR: {r.get('error')}"


if __name__ == "__main__":
    mcp.run()
