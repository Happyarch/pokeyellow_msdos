#!/bin/sh
# goldencheck.sh <scenario> — build the matching DEBUG_* image, run it headless
# in DOSBox-X, extract GBSTATE.BIN, and diff it against the committed mGBA
# golden (fidelity plan Stage 1.4). Exits nonzero on any unmasked divergence.
#
# Run from dos_port/ (make goldencheck SCENARIO=<name> does). The headless run
# uses a COPY of PKMN.IMG in a scratch dir so a live `dos_port/run` session
# can't clobber the extraction (verified failure mode — see build-and-debug).
set -eu

SCENARIO="${1:?usage: goldencheck.sh <scenario>}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"   # dos_port/
cd "$HERE"

FLAGS="$(python3 tools/golden_diff.py "$SCENARIO" --flags)"

SCRATCH="${TMPDIR:-/tmp}/goldencheck.$$"
mkdir -p "$SCRATCH"
trap 'rm -rf "$SCRATCH"' EXIT

echo "== goldencheck $SCENARIO: make image $FLAGS"
# shellcheck disable=SC2086  # FLAGS is intentionally word-split into make vars
make image $FLAGS >"$SCRATCH/build.log" 2>&1 || {
    tail -20 "$SCRATCH/build.log"; echo "goldencheck: build failed"; exit 2; }

cp PKMN.IMG "$SCRATCH/pkmn.img"
# F-11: a stale GBSTATE.BIN baked into PKMN.IMG from an earlier build would be mcopy'd
# out by a run that crashed before dumping, and the scenario would diff the OLD state —
# reporting a pass (or a bogus failure) for a run that produced nothing. Delete first.
for f in GBSTATE.BIN DUMP.BIN FRAME.BIN; do
    mdel -i "$SCRATCH/pkmn.img@@1048576" "::$f" 2>/dev/null || true
done
sed "s|^imgmount c PKMN.IMG|imgmount c $SCRATCH/pkmn.img|; s|^PKMN.EXE\$|PKMN.EXE\nexit|" \
    dosbox-x.conf >"$SCRATCH/run.conf"

echo "== goldencheck $SCENARIO: headless DOSBox-X run"
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy timeout -s KILL 150 \
    dosbox-x -defaultdir "$HERE" -defaultconf -conf "$SCRATCH/run.conf" \
    >"$SCRATCH/dosbox.log" 2>&1 || true

mcopy -n -i "$SCRATCH/pkmn.img@@1048576" ::GBSTATE.BIN "$SCRATCH/" || {
    echo "goldencheck: no GBSTATE.BIN in image — run crashed before the dump?";
    tail -20 "$SCRATCH/dosbox.log"; exit 2; }

echo "== goldencheck $SCENARIO: diff vs golden"
python3 tools/golden_diff.py "$SCENARIO" --gbstate "$SCRATCH/GBSTATE.BIN"
