#!/usr/bin/env bash
# Launch the ground-truth side of the mgba-mcp bridge (fidelity plan 1.5):
# mgba-lua-runner + mcp_agent.lua serving TCP 127.0.0.1:$MGBA_MCP_PORT for
# tools/mgba_mcp/server.py (model: run_with_mcp.sh for dosbox-mcp).
#
# The ROM is the sha1-verified golden build from the pinned pret worktree —
# ground truth only ever comes from a verified ROM (same gate as
# make_goldens.sh).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PRET_GOLDEN_DIR="${PRET_GOLDEN_DIR:-$(dirname "$REPO_ROOT")/pokeyellow_msdos-pret-golden}"

ROM="$PRET_GOLDEN_DIR/pokeyellow.gbc"
SYM="$PRET_GOLDEN_DIR/pokeyellow.sym"
RUNNER="$SCRIPT_DIR/mgba_build/mgba-lua-runner"
AGENT="$SCRIPT_DIR/mgba_harness/mcp_agent.lua"
PORT="${MGBA_MCP_PORT:-8765}"

for f in "$ROM" "$SYM"; do
    [ -f "$f" ] || { echo "ERROR: $f missing — build the golden ROM (see make_goldens.sh)" >&2; exit 1; }
done
[ -x "$RUNNER" ] || { echo "ERROR: $RUNNER missing — run tools/build_mgba.sh" >&2; exit 1; }

want_sha1=$(awk '/pokeyellow.gbc/ { print $1 }' "$REPO_ROOT/roms.sha1")
have_sha1=$(sha1sum "$ROM" | awk '{ print $1 }')
[ "$want_sha1" = "$have_sha1" ] || {
    echo "ERROR: $ROM sha1 $have_sha1 != roms.sha1 $want_sha1 — refusing to serve ground truth" >&2
    exit 1; }

echo "mgba-mcp: serving $ROM on 127.0.0.1:$PORT (agent: $AGENT)"
exec env PKMN_SYM="$SYM" MGBA_MCP_PORT="$PORT" \
    "$RUNNER" -s "$AGENT" -F 1000000000 "$ROM"
