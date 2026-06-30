#!/bin/bash
# Quick launcher for DOSBox-X with MCP server support
#
# Usage: ./start_dosbox_mcp.sh [make flags]
#
# This requires the MCP-patched DOSBox-X binary to be built first:
#   dos_port/tools/build_dosbox_mcp.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOSPORT="$SCRIPT_DIR/dos_port"

echo "Starting DOSBox-X with MCP support..."
echo "Make sure you've built the MCP-patched binary:"
echo "  $DOSPORT/tools/build_dosbox_mcp.sh"
echo ""

# Run the official launch script with any passed arguments
exec "$DOSPORT/tools/run_with_mcp.sh" "$@"
