#!/usr/bin/env bash
# Build the MCP dosbox-x fork for the Pokemon Yellow DOS port debugger.
#
# Source of truth: the submodule dos_port/tools/dosbox-x — the Happyarch/dosbox-x
# fork, branch mcp-debug (MCP unix-socket bridge + REGJSON + SYMF symbol table).
# The old dosbox-x-mcp.patch flow is retired.
#
# The binary is deliberately named dosbox-x-mcp (NOT dosbox-x) so it can never
# conflict with or shadow the system dosbox-x install. It is installed to:
#   ~/.local/bin/dosbox-x-mcp            (on PATH)
#   tools/dosbox-x-mcp/dosbox-x-mcp      (in-repo copy, used by run_with_mcp.sh)
#
# autotools cannot cope with the repo path's space ("Active Code"), so the
# submodule working tree is rsynced to a space-free staging dir in /tmp and
# configured/built there. Uncommitted submodule changes ARE picked up (rsync of
# the working tree) — handy while developing debugger features.
#
# Run from anywhere; script auto-locates the repo root.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$SCRIPT_DIR"
SUBMODULE="$TOOLS_DIR/dosbox-x"

STAGE_SRC="/tmp/dosbox-x-mcp-src"
BUILD_DIR="/tmp/dosbox-x-mcp-build"
BIN_NAME="dosbox-x-mcp"
REPO_BIN="${TOOLS_DIR}/dosbox-x-mcp/${BIN_NAME}"
LOCAL_BIN="${HOME}/.local/bin/${BIN_NAME}"

if [ ! -f "$SUBMODULE/src/debug/debug.cpp" ]; then
    echo "ERROR: submodule not checked out at $SUBMODULE" >&2
    echo "Run: git submodule update --init dos_port/tools/dosbox-x" >&2
    exit 1
fi

if ! git -C "$SUBMODULE" diff --quiet 2>/dev/null; then
    echo "NOTE: submodule has uncommitted changes — building the working tree as-is."
fi

echo "Staging submodule working tree → $STAGE_SRC"
mkdir -p "$STAGE_SRC"
rsync -a --delete --exclude .git "$SUBMODULE/" "$STAGE_SRC/"

if [ ! -f "$STAGE_SRC/configure" ]; then
    echo "Running autogen.sh..."
    (cd "$STAGE_SRC" && ./autogen.sh 2>&1 | tail -3)
fi

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Enable heavy debug + SDL2 + MT-32 + printer.
# SDL2: required on Arch (sdl12-compat's SDL1 lacks some DOSBox-X key constants).
# MT-32 uses system libmt32emu (munt package on Arch).
# Printer uses CUPS (libcups).
"$STAGE_SRC/configure" \
    --enable-debug=heavy \
    --enable-sdl2 \
    --enable-mt32 \
    --enable-printer \
    --prefix="$BUILD_DIR/install" \
    2>&1 | grep -E "debug|mt32|printer|curses|SDL|error:|configure:" | grep -v "^checking " | head -20

make -j"$(nproc)" 2>&1 | tail -10

if [ ! -x src/dosbox-x ]; then
    echo "ERROR: build produced no binary at $BUILD_DIR/src/dosbox-x" >&2
    exit 1
fi

mkdir -p "$(dirname "$REPO_BIN")" "$(dirname "$LOCAL_BIN")"
cp src/dosbox-x "$REPO_BIN"
cp src/dosbox-x "$LOCAL_BIN"
chmod +x "$REPO_BIN" "$LOCAL_BIN"

echo ""
echo "Done."
echo "  In-repo binary: $REPO_BIN"
echo "  On PATH:        $LOCAL_BIN"
echo "Run: dos_port/tools/run_with_mcp.sh"
