#!/bin/sh
# run_headless.sh "<MAKE FLAGS>" [outdir] — build a DEBUG_* image, run it headless
# in DOSBox-X, and extract every dump file it produced (GBSTATE.BIN / DUMP.BIN /
# FRAME.BIN) into outdir (default: a fresh dir under $TMPDIR, printed on stdout).
#
# The scenario-bound twin is goldencheck.sh, which additionally diffs against a
# committed golden. Use this one when there is no golden yet — probing a new gate's
# GBSTATE to measure its window/projection, or eyeballing a datastruct dump.
#
#   tools/run_headless.sh "DEBUG_ITEMTM=1" /tmp/probe
#
# Like goldencheck.sh, the run uses a COPY of PKMN.IMG in a scratch dir, so a live
# `dos_port/run` session can't clobber the extraction (see build-and-debug skill).
set -eu

FLAGS="${1:?usage: run_headless.sh \"<MAKE FLAGS>\" [outdir]}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"   # dos_port/
cd "$HERE"

OUT="${2:-${TMPDIR:-/tmp}/run_headless.$$}"
mkdir -p "$OUT"

SCRATCH="${TMPDIR:-/tmp}/run_headless.scratch.$$"
mkdir -p "$SCRATCH"
trap 'rm -rf "$SCRATCH"' EXIT

echo "== run_headless: make image $FLAGS" >&2
# shellcheck disable=SC2086  # FLAGS is intentionally word-split into make vars
make image $FLAGS >"$SCRATCH/build.log" 2>&1 || {
    tail -20 "$SCRATCH/build.log"; echo "run_headless: build failed" >&2; exit 2; }

cp PKMN.IMG "$SCRATCH/pkmn.img"
# F-11: PKMN.IMG can carry a dump file baked in from an EARLIER build. A run that
# crashes before dumping would leave that stale file in the image, mcopy would pull it
# out, and the capture would read as a clean success — a silently passing test of
# nothing. Delete them first, so any file found below is definitionally fresh.
for f in GBSTATE.BIN DUMP.BIN FRAME.BIN; do
    mdel -i "$SCRATCH/pkmn.img@@1048576" "::$f" 2>/dev/null || true
done
sed "s|^imgmount c PKMN.IMG|imgmount c $SCRATCH/pkmn.img|; s|^PKMN.EXE\$|PKMN.EXE\nexit|" \
    dosbox-x.conf >"$SCRATCH/run.conf"

echo "== run_headless: headless DOSBox-X run" >&2
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy timeout -s KILL 150 \
    dosbox-x -defaultdir "$HERE" -defaultconf -conf "$SCRATCH/run.conf" \
    >"$SCRATCH/dosbox.log" 2>&1 || true

got=0
for f in GBSTATE.BIN DUMP.BIN FRAME.BIN; do
    if mcopy -n -i "$SCRATCH/pkmn.img@@1048576" "::$f" "$OUT/" 2>/dev/null; then
        echo "== run_headless: extracted $f" >&2
        got=$((got + 1))
    fi
done
if [ "$got" -eq 0 ]; then
    echo "run_headless: no dump files in the image — run crashed before the dump?" >&2
    tail -20 "$SCRATCH/dosbox.log" >&2
    exit 2
fi
echo "$OUT"
