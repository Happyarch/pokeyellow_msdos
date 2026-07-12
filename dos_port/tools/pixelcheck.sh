#!/bin/sh
# pixelcheck.sh — capture one scenario's FRAME.BIN headlessly.
#
# The compositor-perf plan (docs/current_plan_compositor_perf.md) requires every
# stage to be a PIXEL-IDENTICAL transform, so each stage captures these frames
# before and after and byte-compares them:
#
#   tools/pixelcheck.sh pallet -o before/pallet.bin     # on the old tree
#   tools/pixelcheck.sh pallet -o after/pallet.bin      # on the new tree
#   cmp before/pallet.bin after/pallet.bin
#
# Scenarios cover both render_bg paths (overworld surface + flat wTileMap), the
# window compositor (menus, stacked descriptors) and the sprite compositor.
# Runs against a COPY of PKMN.IMG in a scratch dir (image-contention trap).
set -eu

cd "$(dirname "$0")/.."
DOS_PORT="$PWD"

SCENARIO="${1:?usage: pixelcheck.sh <scenario> -o out.bin}"
shift
OUT=""
while [ $# -gt 0 ]; do
    case "$1" in
        -o) OUT="$2"; shift 2 ;;
        *) echo "unknown arg: $1" >&2; exit 2 ;;
    esac
done
: "${OUT:?-o out.bin is required}"

case "$SCENARIO" in
    pallet)     FLAGS="DEBUG_TRANSITION=1 DEBUG_BASELINE=1" ;;  # overworld surface path
    route1)     FLAGS="DEBUG_TRANSITION=1" ;;                   # overworld after a map crossing
    walk)       FLAGS="DEBUG_WALK_NORTH=1" ;;                   # overworld mid-scroll
    startmenu)  FLAGS="DEBUG_STARTMENU=1" ;;                    # window layer over the overworld
    partymenu)  FLAGS="DEBUG_PARTYMENU=1" ;;                    # whiteout + window + icons
    bagmenu)    FLAGS="DEBUG_BAGMENU=1" ;;                      # stacked window descriptors
    pokedex)    FLAGS="DEBUG_G1=1" ;;                           # flat wTileMap path
    battle)     FLAGS="DEBUG_BATTLE=1" ;;                       # flat path + sprites
    status)     FLAGS="DEBUG_STATUS=1" ;;                       # flat path + pics
    *) echo "unknown scenario: $SCENARIO" >&2; exit 2 ;;
esac

SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

# shellcheck disable=SC2086
make -C "$DOS_PORT" image $FLAGS >/dev/null

cp "$DOS_PORT/PKMN.IMG" "$SCRATCH/pkmn.img"
sed -e "s#^imgmount c .*#imgmount c \"$SCRATCH/pkmn.img\" -t hdd -fs fat#" \
    -e 's/^PKMN.EXE$/PKMN.EXE\nexit/' \
    "$DOS_PORT/dosbox-x.conf" > "$SCRATCH/dosbox-x.conf"

SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy \
    timeout -s KILL 200 dosbox-x -defaultdir "$SCRATCH" -defaultconf \
    -conf "$SCRATCH/dosbox-x.conf" >/dev/null 2>&1 || true

mkdir -p "$(dirname "$OUT")"
mcopy -n -i "$SCRATCH/pkmn.img@@1048576" ::FRAME.BIN "$OUT" 2>/dev/null || {
    echo "$SCENARIO: no FRAME.BIN — the harness crashed or never dumped" >&2
    exit 1
}
echo "$SCENARIO -> $OUT ($(stat -c%s "$OUT") bytes)"
