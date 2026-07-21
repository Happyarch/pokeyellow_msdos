#!/bin/sh
# pixelcheck.sh — capture one scenario's FRAME.BIN headlessly.
#
# The compositor-perf plan (docs/plans/compositor_perf.md) requires every
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
    # Cinematic projection/clipping/wrap markers (menu-intro A1.6). Offsets come
    # from the MARKER_SX/MARKER_SY environment variables so one scenario drives
    # the whole sweep: 0..7 proves sub-tile motion, 252..255 proves GB wrap.
    markers)    FLAGS="DEBUG_CINEMATIC_MARKERS=1 MARKER_SX=${MARKER_SX:-0} MARKER_SY=${MARKER_SY:-0}" ;;
    # The real title, booted through the full bounce to its stable checkpoint
    # (menu-intro A2.3/A2.6). No SKIP_TITLE — that would defeat the scenario.
    # The real main menu, reached by booting the real title and latching START at
    # its idle loop (menu-intro A3). No SKIP_TITLE: the routing is the evidence.
    mainmenu)   FLAGS="DEBUG_MAINMENU_LIVE=1" ;;
    title_reentry) FLAGS="DEBUG_TITLE_REENTRY=1" ;;
    oakpic)     FLAGS="DEBUG_OAKPIC=1" ;;
    oakintro)   FLAGS="DEBUG_OAKINTRO=1 AUTOKEY_DUMP_FRAME=${AUTOKEY_DUMP_FRAME:-360}" ;;
    namemenu)   FLAGS="DEBUG_NAMEMENU=1 AUTOKEY_DUMP_FRAME=${AUTOKEY_DUMP_FRAME:-120}" ;;
    oakslide)   FLAGS="DEBUG_OAKSLIDE=1 AUTOKEY_DUMP_FRAME=${AUTOKEY_DUMP_FRAME:-120}" ;;
    choosename) FLAGS="DEBUG_CHOOSENAME=1 AUTOKEY_DUMP_FRAME=${AUTOKEY_DUMP_FRAME:-260}" ;;
    choosename_custom) FLAGS="DEBUG_CHOOSENAME=1 CHOOSENAME_CUSTOM=1 AUTOKEY_DUMP_FRAME=${AUTOKEY_DUMP_FRAME:-320}" ;;
    splash)     FLAGS="DEBUG_CINEMATIC_SPLASH=1 AUTOKEY_DUMP_FRAME=${AUTOKEY_DUMP_FRAME:-20}" ;;
    animobj)    FLAGS="DEBUG_CINEMATIC_ANIMOBJ=1 AUTOKEY_DUMP_FRAME=${AUTOKEY_DUMP_FRAME:-30}" ;;
    yellow)     FLAGS="DEBUG_CINEMATIC_YELLOW=1 AUTOKEY_DUMP_FRAME=${AUTOKEY_DUMP_FRAME:-40}" ;;
    title)      FLAGS="DEBUG_TITLE=1 TITLE_DUMP_FRAME=${TITLE_DUMP_FRAME:-0} TITLE_DUMP_SCENE=${TITLE_DUMP_SCENE:-0} TITLE_DUMP_LOOP=${TITLE_DUMP_LOOP:-0}" ;;
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
