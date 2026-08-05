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
#
# POKEMON.DSV is the same hazard on the INPUT side, and it is the more dangerous
# one: `make image` deliberately PRESERVES a save already inside PKMN.IMG (so a
# real play session survives a rebuild), so a .dsv written by an earlier run —
# a different scenario's, or an older build's — silently rides into this run and
# any save-reading scenario loads it. That is a pass on data the run never
# produced. Always delete it; scenarios that need one declare it below, and get
# a freshly converted copy.
for f in GBSTATE.BIN DUMP.BIN FRAME.BIN POKEMON.DSV; do
    mdel -i "$SCRATCH/pkmn.img@@1048576" "::$f" 2>/dev/null || true
done

# A scenario may declare a seed save (a raw GB .sav fixture). Convert it to the
# port's .dsv container and stage it as POKEMON.DSV, which SramLoadImage reads at
# boot. Converting per run rather than committing the .dsv keeps saveconv.py on
# the tested path and stops the two artifacts drifting apart.
SEED_SAV="$(python3 tools/golden_diff.py "$SCENARIO" --seed-save)"
if [ -n "$SEED_SAV" ]; then
    [ -f "$SEED_SAV" ] || { echo "goldencheck: seed save not found: $SEED_SAV"; exit 2; }
    python3 tools/saveconv.py --to-dos "$SEED_SAV" "$SCRATCH/POKEMON.DSV" \
        >"$SCRATCH/saveconv.log" 2>&1 || {
        cat "$SCRATCH/saveconv.log"; echo "goldencheck: seed save conversion failed"; exit 2; }
    mcopy -o -i "$SCRATCH/pkmn.img@@1048576" "$SCRATCH/POKEMON.DSV" ::POKEMON.DSV || {
        echo "goldencheck: could not stage POKEMON.DSV into the image"; exit 2; }
    echo "== goldencheck $SCENARIO: seeded POKEMON.DSV from $SEED_SAV"
fi
sed "s|^imgmount c PKMN.IMG|imgmount c $SCRATCH/pkmn.img|; s|^PKMN.EXE\$|PKMN.EXE\nexit|" \
    dosbox-x.conf >"$SCRATCH/run.conf"

# Per-scenario headless-run budget. Every manifest entry declares
# dump.timeout_seconds and nothing read it — this was hardcoded 150, so a scenario
# needing longer died as "no GBSTATE.BIN in image — run crashed before the dump?",
# which reads like a crash and is not one. Default stays 150, so no existing
# scenario changes behaviour.
RUN_TIMEOUT="$(python3 tools/golden_diff.py "$SCENARIO" --timeout)"

echo "== goldencheck $SCENARIO: headless DOSBox-X run (timeout ${RUN_TIMEOUT}s)"
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy timeout -s KILL "$RUN_TIMEOUT" \
    dosbox-x -defaultdir "$HERE" -defaultconf -conf "$SCRATCH/run.conf" \
    >"$SCRATCH/dosbox.log" 2>&1 || true

mcopy -n -i "$SCRATCH/pkmn.img@@1048576" ::GBSTATE.BIN "$SCRATCH/" || {
    echo "goldencheck: no GBSTATE.BIN in image — run crashed before the dump?";
    tail -20 "$SCRATCH/dosbox.log"; exit 2; }

echo "== goldencheck $SCENARIO: diff vs golden"
python3 tools/golden_diff.py "$SCENARIO" --gbstate "$SCRATCH/GBSTATE.BIN"
