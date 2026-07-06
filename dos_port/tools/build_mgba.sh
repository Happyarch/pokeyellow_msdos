#!/usr/bin/env bash
# Build mGBA (vendored submodule) with Lua scripting for the fidelity harness.
#
# mGBA is the golden-reference GB emulator: its built-in Lua scripting runs
# the harness scripts in tools/mgba_harness/ against the sha1-verified
# pokeyellow.gbc to produce the committed goldens (see
# docs/current_plan_fidelity_harness.md).
#
# Source: dos_port/tools/mgba (git submodule pinned to a 0.10.x release tag).
# Output: dos_port/tools/mgba_build/mgba  (SDL frontend, not committed)
#         dos_port/tools/mgba_build/     (build tree, gitignored)
#
# Requires: cmake, a C compiler, SDL2, libpng, zlib, Lua 5.4 (all checked
# below — no network access needed once the submodule is cloned).
#
# Run from anywhere; script auto-locates the repo root.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="${SCRIPT_DIR}/mgba"
# Build out-of-tree in /tmp: the repo path contains spaces, which some
# generated build rules still mishandle, and object files don't belong in
# the submodule checkout anyway.
BUILD_DIR="/tmp/mgba-fidelity-build"
DEST_DIR="${SCRIPT_DIR}/mgba_build"

if [ ! -f "$SRC_DIR/CMakeLists.txt" ]; then
    echo "ERROR: mGBA submodule not checked out at $SRC_DIR" >&2
    echo "Run: git submodule update --init dos_port/tools/mgba" >&2
    exit 1
fi

for dep in cmake cc; do
    command -v "$dep" >/dev/null || { echo "ERROR: $dep not found" >&2; exit 1; }
done
pkg-config --exists lua5.4 || { echo "ERROR: Lua 5.4 dev files not found" >&2; exit 1; }

echo "mGBA source: $SRC_DIR ($(git -C "$SRC_DIR" describe --tags 2>/dev/null || echo 'unknown version'))"

# Scripting (ENABLE_SCRIPTING + USE_LUA) is the point of this build; Qt is
# skipped (heavy dep — the harness drives the SDL frontend headlessly under
# SDL_VIDEODRIVER=dummy). FFmpeg/editline/etc. are optional extras mGBA
# auto-detects; leave them to autodetection.
cmake -S "$SRC_DIR" -B "$BUILD_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DBUILD_QT=OFF \
    -DBUILD_SDL=ON \
    -DENABLE_SCRIPTING=ON \
    -DUSE_LUA=ON \
    2>&1 | grep -Ei 'lua|script|sdl|error|warning: ' || true

# Fail loudly if configure disabled scripting silently.
grep -q 'ENABLE_SCRIPTING:BOOL=ON' "$BUILD_DIR/CMakeCache.txt" || {
    echo "ERROR: scripting not enabled in CMake cache" >&2; exit 1; }

cmake --build "$BUILD_DIR" -j"$(nproc)" 2>&1 | tail -5

mkdir -p "$DEST_DIR"
cp "$BUILD_DIR/sdl/mgba" "$DEST_DIR/mgba"
chmod +x "$DEST_DIR/mgba"
cp -P "$BUILD_DIR"/libmgba.so* "$DEST_DIR/"

# Headless Lua runner: mGBA 0.10.x only exposes the Lua engine through the
# Qt GUI, so the harness ships its own tiny frontend (see runner.c).
cc -O2 -Wall -o "$DEST_DIR/mgba-lua-runner" "${SCRIPT_DIR}/mgba_harness/runner.c" \
    -I"$SRC_DIR/include" -I"$BUILD_DIR/include" \
    -L"$DEST_DIR" -lmgba -Wl,-rpath,'$ORIGIN'

echo ""
echo "Done. Binaries:"
echo "  $DEST_DIR/mgba            (SDL frontend, no scripting entry)"
echo "  $DEST_DIR/mgba-lua-runner (headless Lua harness runner)"
"$DEST_DIR/mgba" --version
