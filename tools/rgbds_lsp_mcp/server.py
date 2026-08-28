#!/usr/bin/env python3
"""
rgbds-lsp MCP Server for the Pokémon Yellow pret disassembly.

Exposes Game Boy SM83 / RGBDS Language Server capabilities (hover documentation,
instruction cycles/flags, symbol outline, definitions, and autocompletion) to
Antigravity, Claude Code, and other LLM agents via Model Context Protocol (MCP).
"""

import os
import sys
import json
import argparse
import threading
import subprocess
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Optional, List, Dict, Any

from mcp.server.fastmcp import FastMCP

# Paths
_HERE = Path(__file__).parent.resolve()
_REPO = _HERE.parent.parent  # tools/rgbds_lsp_mcp -> tools -> repo root

mcp = FastMCP("rgbds-lsp", instructions="Game Boy SM83 / RGBDS Assembly Language Server for Pokémon Yellow disassembly")


class RgbdsLspClient:
    """Manages an rgbds-lsp process and translates LSP calls."""

    def __init__(self, root_dir: Path):
        self.root_dir = root_dir.resolve()
        self.proc: Optional[subprocess.Popen] = None
        self._req_id = 0
        self._lock = threading.Lock()
        self._open_files: set[Path] = set()
        self._start_server()

    def _start_server(self):
        if self.proc and self.proc.poll() is None:
            return

        self.proc = subprocess.Popen(
            ["rgbds-lsp"],
            cwd=str(self.root_dir),
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        root_uri = urllib.parse.urljoin("file:", urllib.request.pathname2url(str(self.root_dir)))
        self._send_request("initialize", {
            "processId": None,
            "rootUri": root_uri,
            "capabilities": {
                "textDocument": {
                    "hover": {"contentFormat": ["markdown", "plaintext"]},
                    "completion": {"completionItem": {"snippetSupport": True}},
                    "documentSymbol": {"hierarchicalDocumentSymbolSupport": True},
                }
            }
        })
        self._send_notification("initialized", {})

    def _send_request(self, method: str, params: dict) -> Any:
        with self._lock:
            if self.proc is None or self.proc.poll() is not None:
                self._open_files.clear()
                self._start_server()

            self._req_id += 1
            req_id = self._req_id
            payload = {
                "jsonrpc": "2.0",
                "id": req_id,
                "method": method,
                "params": params
            }
            body = json.dumps(payload).encode("utf-8")
            msg = f"Content-Length: {len(body)}\r\n\r\n".encode("utf-8") + body
            try:
                self.proc.stdin.write(msg)
                self.proc.stdin.flush()
            except (BrokenPipeError, OSError):
                self._open_files.clear()
                self._start_server()
                return None

            while True:
                resp = self._read_message()
                if resp is None:
                    return None
                if resp.get("id") == req_id:
                    return resp.get("result")

    def _send_notification(self, method: str, params: dict):
        with self._lock:
            if self.proc is None or self.proc.poll() is not None:
                return
            payload = {
                "jsonrpc": "2.0",
                "method": method,
                "params": params
            }
            body = json.dumps(payload).encode("utf-8")
            msg = f"Content-Length: {len(body)}\r\n\r\n".encode("utf-8") + body
            try:
                self.proc.stdin.write(msg)
                self.proc.stdin.flush()
            except (BrokenPipeError, OSError):
                pass

    def _read_message(self) -> Optional[dict]:
        length = 0
        while True:
            line = self.proc.stdout.readline().decode("utf-8", errors="replace")
            if not line:
                return None
            if line.startswith("Content-Length:"):
                length = int(line.split(":")[1].strip())
            elif line == "\r\n":
                break
        raw = self.proc.stdout.read(length).decode("utf-8", errors="replace")
        return json.loads(raw)

    def _resolve_path(self, path_str: str) -> Path:
        p = Path(path_str)
        if not p.is_absolute():
            p = _REPO / p
        return p.resolve()

    def _ensure_file_open(self, file_path: Path) -> str:
        abs_path = file_path.resolve()
        file_uri = urllib.parse.urljoin("file:", urllib.request.pathname2url(str(abs_path)))
        if abs_path not in self._open_files:
            if abs_path.exists():
                with open(abs_path, "r", encoding="utf-8", errors="replace") as f:
                    text = f.read()
                self._send_notification("textDocument/didOpen", {
                    "textDocument": {
                        "uri": file_uri,
                        "languageId": "rgbds",
                        "version": 1,
                        "text": text
                    }
                })
                self._open_files.add(abs_path)
        return file_uri

    def hover(self, file_path_str: str, line: int, column: int) -> Optional[str]:
        p = self._resolve_path(file_path_str)
        uri = self._ensure_file_open(p)
        res = self._send_request("textDocument/hover", {
            "textDocument": {"uri": uri},
            "position": {"line": max(0, line - 1), "character": max(0, column - 1)}
        })
        if not res or "contents" not in res:
            return None
        contents = res["contents"]
        if isinstance(contents, dict):
            return contents.get("value", "")
        elif isinstance(contents, list):
            parts = []
            for item in contents:
                if isinstance(item, dict):
                    parts.append(item.get("value", ""))
                elif isinstance(item, str):
                    parts.append(item)
            return "\n\n".join(parts)
        elif isinstance(contents, str):
            return contents
        return str(contents)

    def document_symbols(self, file_path_str: str) -> List[Dict[str, Any]]:
        p = self._resolve_path(file_path_str)
        uri = self._ensure_file_open(p)
        res = self._send_request("textDocument/documentSymbol", {
            "textDocument": {"uri": uri}
        })
        return res or []

    def definition(self, file_path_str: str, line: int, column: int) -> Any:
        p = self._resolve_path(file_path_str)
        uri = self._ensure_file_open(p)
        return self._send_request("textDocument/definition", {
            "textDocument": {"uri": uri},
            "position": {"line": max(0, line - 1), "character": max(0, column - 1)}
        })

    def completion(self, file_path_str: str, line: int, column: int) -> List[Dict[str, Any]]:
        p = self._resolve_path(file_path_str)
        uri = self._ensure_file_open(p)
        res = self._send_request("textDocument/completion", {
            "textDocument": {"uri": uri},
            "position": {"line": max(0, line - 1), "character": max(0, column - 1)}
        })
        if not res:
            return []
        if isinstance(res, dict):
            return res.get("items", [])
        return res


_client: Optional[RgbdsLspClient] = None

def get_client() -> RgbdsLspClient:
    global _client
    if _client is None:
        _client = RgbdsLspClient(_REPO)
    return _client


# ---------------------------------------------------------------------------
# MCP Tool Registrations
# ---------------------------------------------------------------------------

@mcp.tool()
def rgbds_lsp_hover(file_path: str, line: int, column: int) -> str:
    """
    Get Game Boy SM83 / RGBDS hover documentation (instructions, cycles, bytes, flags, registers, symbols, doc comments).

    Args:
        file_path: Path to the GB assembly file (e.g. home/init.asm, engine/battle/core.asm).
        line: 1-indexed line number.
        column: 1-indexed column number.
    """
    client = get_client()
    res = client.hover(file_path, line, column)
    if res is None:
        return "No hover documentation available at this position."
    return res


@mcp.tool()
def rgbds_lsp_document_symbols(file_path: str) -> str:
    """
    List all functions, routines, labels, and constants declared in a Game Boy RGBDS assembly file.

    Args:
        file_path: Path to the GB assembly file (e.g. home/init.asm, engine/battle/core.asm).
    """
    client = get_client()
    symbols = client.document_symbols(file_path)
    if not symbols:
        return "No symbols found."
    lines = []
    for s in symbols:
        name = s.get("name", "<unnamed>")
        loc = s.get("location", {}).get("range", {}).get("start", {})
        l = loc.get("line", 0) + 1
        c = loc.get("character", 0) + 1
        lines.append(f"- {name} (line {l}, col {c})")
    return "\n".join(lines)


@mcp.tool()
def rgbds_lsp_definition(file_path: str, line: int, column: int) -> str:
    """
    Go to definition for a symbol in a Game Boy RGBDS assembly file.

    Args:
        file_path: Path to the GB assembly file.
        line: 1-indexed line number.
        column: 1-indexed column number.
    """
    client = get_client()
    res = client.definition(file_path, line, column)
    if not res:
        return "Definition not found."
    return json.dumps(res, indent=2)


@mcp.tool()
def rgbds_lsp_completion(file_path: str, line: int, column: int) -> str:
    """
    Get autocompletion suggestions (SM83 instructions, registers, RGBDS keywords, symbols) at a given position.

    Args:
        file_path: Path to the GB assembly file.
        line: 1-indexed line number.
        column: 1-indexed column number.
    """
    client = get_client()
    items = client.completion(file_path, line, column)
    if not items:
        return "No completions available."
    sample = items[:25]
    res_list = [f"- {item.get('label')}: {item.get('detail', '')}" for item in sample]
    out = "\n".join(res_list)
    if len(items) > 25:
        out += f"\n... ({len(items) - 25} more items)"
    return out


# ---------------------------------------------------------------------------
# CLI / Main entry point
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="rgbds-lsp MCP Server & CLI for pret/pokeyellow SM83 assembly")
    parser.add_argument("--hover", nargs=3, metavar=("FILE", "LINE", "COL"), help="Query hover doc")
    parser.add_argument("--symbols", metavar="FILE", help="List symbols in file")
    parser.add_argument("--def", dest="definition", nargs=3, metavar=("FILE", "LINE", "COL"), help="Go to definition")
    parser.add_argument("--complete", nargs=3, metavar=("FILE", "LINE", "COL"), help="Completions")

    args = parser.parse_args()

    if args.hover:
        f, l, c = args.hover
        print(rgbds_lsp_hover(f, int(l), int(c)))
        return
    elif args.symbols:
        print(rgbds_lsp_document_symbols(args.symbols))
        return
    elif args.definition:
        f, l, c = args.definition
        print(rgbds_lsp_definition(f, int(l), int(c)))
        return
    elif args.complete:
        f, l, c = args.complete
        print(rgbds_lsp_completion(f, int(l), int(c)))
        return

    # Run as stdio MCP server
    mcp.run()


if __name__ == "__main__":
    main()
