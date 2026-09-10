#!/usr/bin/env bash
# build_gb_apu.sh — Builds Shay Green's Basic_Gb_Apu (Gb_Snd_Emu) as libgbapu.so
#
# Clones Gb_Snd_Emu into gitignored .gb_snd_emu/ if missing,
# and compiles libgbapu.so using clang++ with -O3 -shared -fPIC.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EMU_DIR="$SCRIPT_DIR/.gb_snd_emu"
AUDITION_DIR="$SCRIPT_DIR/audition"
DEST_LIB="$SCRIPT_DIR/libgbapu.so"

CXX="${CXX:-clang++}"
if ! command -v "$CXX" >/dev/null 2>&1; then
    if command -v g++ >/dev/null 2>&1; then
        CXX="g++"
    else
        echo "ERROR: Neither clang++ nor g++ found on system PATH." >&2
        exit 1
    fi
fi

if [ ! -d "$EMU_DIR" ]; then
    echo "Cloning Gb_Snd_Emu into $EMU_DIR..."
    git clone --depth 1 https://github.com/blarggs-audio-libraries/Gb_Snd_Emu.git "$EMU_DIR"
fi

echo "Building libgbapu.so with $CXX..."
"$CXX" -O3 -shared -fPIC \
    -Wno-unused-value -Wno-constant-conversion \
    -I "$EMU_DIR" \
    "$AUDITION_DIR/gb_synth.cpp" \
    "$EMU_DIR/Basic_Gb_Apu.cpp" \
    "$EMU_DIR/gb_apu/Gb_Apu.cpp" \
    "$EMU_DIR/gb_apu/Gb_Oscs.cpp" \
    "$EMU_DIR/gb_apu/Blip_Buffer.cpp" \
    "$EMU_DIR/gb_apu/Multi_Buffer.cpp" \
    -o "$DEST_LIB"

echo "libgbapu.so built successfully at $DEST_LIB"
