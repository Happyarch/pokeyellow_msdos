#!/usr/bin/env bash
# fork_binary.sh — print the path to the DOSBox-X fork binary, or fail.
#
# One place that knows where the fork build lives. The fork
# (tools/dosbox-x, branch mcp-debug, built by tools/build_dosbox_mcp.sh) is what
# carries the MCP debug bridge and — since the 2026-10-01 resync — upstream's
# PAS driver. The system `dosbox-x` has neither, so any launcher that needs them
# (run-mcp always; `run /PAS`) resolves the binary HERE instead of hardcoding
# the path and letting the two copies drift.
#
#   path=$(tools/fork_binary.sh)   # fails loudly if it was never built
#
# Prints the path on stdout on success; on failure prints why to stderr and
# exits 1.
set -euo pipefail

DOSPORT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$DOSPORT/tools/dosbox-x-mcp/dosbox-x-mcp"

if [ ! -x "$BIN" ]; then
    echo "fork_binary: fork binary missing or not executable:" >&2
    echo "             $BIN" >&2
    echo "             build it with dos_port/tools/build_dosbox_mcp.sh" >&2
    exit 1
fi

printf '%s\n' "$BIN"
