#!/bin/sh
# printcheck.sh — Headless DOSBox-X print output test harness.
#
# Builds a DEBUG_* image, executes it headless in DOSBox-X with virtual parallel
# printer device (ESC/P 24-pin/9-pin/color) enabled, and extracts the captured
# page artifacts (page*.png, doc*.ps, doc*.pdf, PRINT*.PRN) into outdir.
# See docs/current_plan_printer.md (Stage 4).
#
# Usage:
#   tools/printcheck.sh [OPTIONS] "<MAKE FLAGS>" [outdir]
#
# Options:
#   --ps           Use PostScript output (multipage=true) and convert to PDF via ps2pdf
#   --color        Pass /PRNCOLOR command-line flag (4-pass CMYK ESC r color)
#   --9pin         Pass /PRINT9 command-line flag (60 dpi 9-pin mode)
#   --prnfile      Pass /PRNFILE command-line flag (file output PRINTnnn.PRN)
#   --seed-save <path> Seed .sav save file converted to POKEMON.DSV
#   --timeout <sec> Run timeout in seconds (default: 150)
#   --probe        Perform 2-run determinism probe (verifies bit-for-bit identical outputs)
#
# Examples:
#   tools/printcheck.sh "DEBUG_PRINT_SURF_CANCEL=1 AUTOKEY_APRESS=1" /tmp/surf_print
#   tools/printcheck.sh --color "DEBUG_PRINT_SURF_CANCEL=1 AUTOKEY_APRESS=1" /tmp/surf_color
#   tools/printcheck.sh --ps "DEBUG_PRINT_SURF_CANCEL=1 AUTOKEY_APRESS=1" /tmp/surf_ps
#   tools/printcheck.sh --probe "DEBUG_PRINT_SURF_CANCEL=1 AUTOKEY_APRESS=1"

set -eu

HERE="$(cd "$(dirname "$0")/.." && pwd)"   # dos_port/
cd "$HERE"

DO_PS=0
DO_COLOR=0
DO_9PIN=0
DO_PRNFILE=0
DO_PROBE=0
SEED_SAV=""
RUN_TIMEOUT=150
FLAGS=""
OUT=""

while [ $# -gt 0 ]; do
    case "$1" in
        --ps)
            DO_PS=1
            shift
            ;;
        --color)
            DO_COLOR=1
            shift
            ;;
        --9pin)
            DO_9PIN=1
            shift
            ;;
        --prnfile)
            DO_PRNFILE=1
            shift
            ;;
        --probe)
            DO_PROBE=1
            shift
            ;;
        --seed-save)
            SEED_SAV="$2"
            shift 2
            ;;
        --timeout)
            RUN_TIMEOUT="$2"
            shift 2
            ;;
        *)
            if [ -z "$FLAGS" ]; then
                FLAGS="$1"
            elif [ -z "$OUT" ]; then
                OUT="$1"
            else
                echo "printcheck.sh: unexpected extra argument '$1'" >&2
                exit 2
            fi
            shift
            ;;
    esac
done

if [ -z "$FLAGS" ]; then
    echo "usage: printcheck.sh [OPTIONS] \"<MAKE FLAGS>\" [outdir]" >&2
    exit 2
fi

OUT="${OUT:-${TMPDIR:-/tmp}/printcheck.$$}"
mkdir -p "$OUT"

DOSBOX_BIN="./tools/dosbox-x-mcp/dosbox-x-mcp"
if [ ! -x "$DOSBOX_BIN" ]; then
    DOSBOX_BIN="dosbox-x"
fi

run_once() {
    target_out="$1"
    scratch_dir="$2"
    mkdir -p "$target_out" "$scratch_dir/doc"

    echo "== printcheck: make image $FLAGS" >&2
    # shellcheck disable=SC2086
    make image $FLAGS >"$scratch_dir/build.log" 2>&1 || {
        tail -20 "$scratch_dir/build.log" >&2
        echo "printcheck: build failed" >&2
        exit 2
    }

    cp PKMN.IMG "$scratch_dir/pkmn.img"
    for f in GBSTATE.BIN DUMP.BIN FRAME.BIN PAL.BIN POKEMON.DSV PRINT001.PRN; do
        mdel -i "$scratch_dir/pkmn.img@@1048576" "::$f" 2>/dev/null || true
    done

    if [ -n "$SEED_SAV" ]; then
        if [ ! -f "$SEED_SAV" ]; then
            echo "printcheck: seed save not found: $SEED_SAV" >&2
            exit 2
        fi
        python3 tools/saveconv.py --to-dos "$SEED_SAV" "$scratch_dir/POKEMON.DSV" \
            >"$scratch_dir/saveconv.log" 2>&1 || {
            cat "$scratch_dir/saveconv.log" >&2
            echo "printcheck: seed save conversion failed" >&2
            exit 2
        }
        mcopy -o -i "$scratch_dir/pkmn.img@@1048576" "$scratch_dir/POKEMON.DSV" ::POKEMON.DSV
    fi

    # Build CLI argument string for PKMN.EXE
    EXE_ARGS="PKMN.EXE"
    if [ "$DO_COLOR" -eq 1 ]; then
        EXE_ARGS="$EXE_ARGS /PRNCOLOR"
    fi
    if [ "$DO_9PIN" -eq 1 ]; then
        EXE_ARGS="$EXE_ARGS /PRINT9"
    fi
    if [ "$DO_PRNFILE" -eq 1 ]; then
        EXE_ARGS="$EXE_ARGS /PRNFILE"
    fi

    PRN_OUTPUT="png"
    PRN_MULTI="false"
    if [ "$DO_PS" -eq 1 ]; then
        PRN_OUTPUT="ps"
        PRN_MULTI="true"
    fi

    cat << EOF_INNER > "$scratch_dir/run.conf"
[dosbox]
machine                   = vgaonly
quit warning              = false

[dos]
automount                 = false

[video]
memory io optimization 1  = false

[cpu]
cputype                   = 386_prefetch
cycles                    = fixed 23880
cycleup                   = 500
cycledown                 = 500

[speaker]
disney                    = false

[parallel]
parallel1                 = printer

[printer]
printer                   = true
printoutput               = $PRN_OUTPUT
multipage                 = $PRN_MULTI
dpi                       = 180
docpath                   = $scratch_dir/doc
timeout                   = 1000

[autoexec]
imgmount c $scratch_dir/pkmn.img -t hdd -fs fat
c:
$EXE_ARGS
exit
EOF_INNER

    echo "== printcheck: headless DOSBox-X run (timeout ${RUN_TIMEOUT}s)" >&2
    SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy timeout -s KILL "$RUN_TIMEOUT" \
        "$DOSBOX_BIN" -defaultdir "$HERE" -defaultconf -conf "$scratch_dir/run.conf" \
        >"$scratch_dir/dosbox.log" 2>&1 || true

    # Extract emulated printer documents from docpath
    got=0
    for doc in "$scratch_dir/doc"/*; do
        if [ -f "$doc" ]; then
            cp "$doc" "$target_out/"
            got=$((got + 1))
            echo "== printcheck: captured $(basename "$doc")" >&2
        fi
    done

    # If PostScript output and ps2pdf is available, convert .ps to .pdf
    if [ "$DO_PS" -eq 1 ] && command -v ps2pdf >/dev/null 2>&1; then
        for psfile in "$target_out"/*.ps; do
            if [ -f "$psfile" ]; then
                pdffile="${psfile%.ps}.pdf"
                ps2pdf "$psfile" "$pdffile" 2>/dev/null || true
                if [ -f "$pdffile" ]; then
                    echo "== printcheck: generated $(basename "$pdffile")" >&2
                fi
            fi
        done
    fi

    # Also extract any disk dump / PRINTnnn.PRN files from the FAT image
    for f in GBSTATE.BIN DUMP.BIN FRAME.BIN PAL.BIN PRINT001.PRN; do
        if mcopy -n -i "$scratch_dir/pkmn.img@@1048576" "::$f" "$target_out/" 2>/dev/null; then
            echo "== printcheck: extracted $f" >&2
            got=$((got + 1))
        fi
    done

    if [ "$got" -eq 0 ]; then
        echo "printcheck: no print output or dump files generated" >&2
        tail -20 "$scratch_dir/dosbox.log" >&2
        exit 2
    fi
}

if [ "$DO_PROBE" -eq 1 ]; then
    PROBE1="${TMPDIR:-/tmp}/printcheck_probe1.$$"
    PROBE2="${TMPDIR:-/tmp}/printcheck_probe2.$$"
    SCRATCH1="${TMPDIR:-/tmp}/printcheck_scratch1.$$"
    SCRATCH2="${TMPDIR:-/tmp}/printcheck_scratch2.$$"
    trap 'rm -rf "$PROBE1" "$PROBE2" "$SCRATCH1" "$SCRATCH2"' EXIT

    echo "== printcheck: running determinism probe pass 1" >&2
    run_once "$PROBE1" "$SCRATCH1"
    echo "== printcheck: running determinism probe pass 2" >&2
    run_once "$PROBE2" "$SCRATCH2"

    diff_found=0
    for f1 in "$PROBE1"/*; do
        fname="$(basename "$f1")"
        f2="$PROBE2/$fname"
        if [ ! -f "$f2" ]; then
            echo "printcheck: determinism failure — $fname missing in run 2" >&2
            diff_found=1
            continue
        fi
        if ! cmp -s "$f1" "$f2"; then
            echo "printcheck: determinism failure — $fname differs between run 1 and run 2" >&2
            diff_found=1
        fi
    done

    if [ "$diff_found" -ne 0 ]; then
        echo "printcheck: determinism probe FAILED" >&2
        exit 2
    fi
    echo "== printcheck: determinism probe PASSED (all outputs bit-for-bit identical)" >&2

    # Copy verified artifacts to OUT
    cp -r "$PROBE1"/* "$OUT/"
    echo "$OUT"
else
    SCRATCH="${TMPDIR:-/tmp}/printcheck_scratch.$$"
    mkdir -p "$SCRATCH"
    trap 'rm -rf "$SCRATCH"' EXIT
    run_once "$OUT" "$SCRATCH"
    echo "$OUT"
fi
