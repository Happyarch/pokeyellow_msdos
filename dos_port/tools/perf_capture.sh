#!/bin/sh
# perf_capture.sh — headless DEBUG_PERF baseline capture (compositor-perf plan).
#
# Builds one of the plan's baseline scenarios with -D DEBUG_PERF, runs it under
# DOSBox-X with no display/audio, and decodes the PERF.BIN it writes after
# DEBUG_PERF_FRAMES measured frames. Every stage of the plan re-runs these and
# diffs against the stored baseline:
#
#   tools/perf_capture.sh ow_idle                        # capture
#   tools/perf_capture.sh ow_idle -o perf/ow_idle.bin    # capture + keep
#   tools/read_perf.py perf/ow_idle.bin --baseline perf/ow_idle.base.bin
#
# Scenarios (see the case block): ow_idle, ow_walk, start_menu, party_menu, battle.
#
# Runs against a COPY of PKMN.IMG in a scratch dir, so it is immune to the
# image-contention trap (a live `dos_port/run` session holding PKMN.IMG mounted
# silently eats a concurrent headless run's output file).
set -eu

cd "$(dirname "$0")/.."
DOS_PORT="$PWD"

SCENARIO="${1:-ow_idle}"
shift 2>/dev/null || true
OUT=""
FRAMES=""
while [ $# -gt 0 ]; do
    case "$1" in
        -o) OUT="$2"; shift 2 ;;
        -f|--frames) FRAMES="$2"; shift 2 ;;
        *) echo "unknown arg: $1" >&2; exit 2 ;;
    esac
done

# AUTOKEY_DUMP_FRAME is normally 200 (dump FRAME.BIN + exit). The perf runs must
# outlive it, so scripted scenarios push it out of reach — DEBUG_PERF_FRAMES ends
# the run instead.
NEVER=999999

case "$SCENARIO" in
    ow_idle)     FLAGS="SKIP_TITLE=1 DEBUG_SEED_PARTY=1";                       DEF_FRAMES=300 ;;
    ow_walk)     FLAGS="DEBUG_AUTOKEY=1 AUTOKEY_SEAM=1 AUTOKEY_PAD=PAD_UP AUTOKEY_DUMP_FRAME=$NEVER"; DEF_FRAMES=400 ;;
    start_menu)  FLAGS="DEBUG_AUTOKEY=1 AUTOKEY_DOWNS=0 AUTOKEY_DUMP_FRAME=$NEVER"; DEF_FRAMES=300 ;;
    party_menu)  FLAGS="DEBUG_AUTOKEY=1 AUTOKEY_DOWNS=1 AUTOKEY_DUMP_FRAME=$NEVER"; DEF_FRAMES=400 ;;
    battle)      FLAGS="DEBUG_BATTLE_LIVE=1 DEBUG_SEED_PARTY=1";                DEF_FRAMES=300 ;;
    *) echo "unknown scenario: $SCENARIO" >&2; exit 2 ;;
esac
FRAMES="${FRAMES:-$DEF_FRAMES}"

SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

echo "=== $SCENARIO: make image DEBUG_PERF=1 DEBUG_PERF_FRAMES=$FRAMES $FLAGS"
# shellcheck disable=SC2086
make -C "$DOS_PORT" image DEBUG_PERF=1 DEBUG_PERF_FRAMES="$FRAMES" $FLAGS >/dev/null

cp "$DOS_PORT/PKMN.IMG" "$SCRATCH/pkmn.img"
sed -e "s#^imgmount c .*#imgmount c \"$SCRATCH/pkmn.img\" -t hdd -fs fat#" \
    -e 's/^PKMN.EXE$/PKMN.EXE\nexit/' \
    "$DOS_PORT/dosbox-x.conf" > "$SCRATCH/dosbox-x.conf"

echo "=== running $FRAMES frames headless (this takes a minute)"
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy \
    timeout -s KILL 300 dosbox-x -defaultdir "$SCRATCH" -defaultconf \
    -conf "$SCRATCH/dosbox-x.conf" >/dev/null 2>&1 || true

mcopy -n -i "$SCRATCH/pkmn.img@@1048576" ::PERF.BIN "$SCRATCH/PERF.BIN" 2>/dev/null || {
    echo "no PERF.BIN produced — the run crashed or never reached $FRAMES frames" >&2
    exit 1
}

if [ -n "$OUT" ]; then
    mkdir -p "$(dirname "$OUT")"
    cp "$SCRATCH/PERF.BIN" "$OUT"
    echo "=== saved $OUT"
fi
echo
python3 "$DOS_PORT/tools/read_perf.py" "$SCRATCH/PERF.BIN"
