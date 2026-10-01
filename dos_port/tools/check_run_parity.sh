#!/usr/bin/env bash
# check_run_parity.sh — fail if the bash `run` and the PowerShell run.ps1 drift.
#
# The two launchers must generate the SAME device conf (modulo the C: mount
# line and the intentional platform difference in the MT-32 romdir default),
# and all three shell completers must offer the same DOS flags as
# boot/entry.asm. This is the guard against the exact class of drift that made
# the old per-device wrappers diverge (run-gb/run-pas dropping /EXE flags,
# run-spk/run-tandy missing the guard).
#
# Needs pwsh for the ps1 half; that half is skipped gracefully if pwsh is
# absent. Never launches an emulator (everything is --dry-run).
set -euo pipefail

DOSPORT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DOSPORT"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- device conf parity ------------------------------------------------------
DEVICES=("" "/MT32" "/GB" "/COVOX" "/IMFC" "/INNOVA" "/SPK" "/TANDY" "/PAS")
NAMES=(base mt32 gb covox imfc innova spk tandy pas)

norm() {
    # C: is the image in bash and a mounted dir in ps1; the MT-32 romdir default
    # is platform-specific on purpose; Set-Content -Encoding ASCII mangles the
    # non-ASCII comment characters in the tracked conf.
    sed -E 's/^(imgmount|mount) c .*$/MOUNT/; s/^mt32\.romdir = .*$/mt32.romdir = ROMDIR/' "$1" \
        | LC_ALL=C sed -E 's/[\x80-\xFF]+/?/g' | sed -E 's/\r$//'
}

fails=0

for i in "${!DEVICES[@]}"; do
    flag="${DEVICES[$i]}"; name="${NAMES[$i]}"
    if [ -n "$flag" ]; then
        ./run --dry-run "$flag" 2>/dev/null | sed -n '/^run: conf:/,$p' | tail -n +2 | sed 's/^    //' > "$TMP/b_$name"
    else
        ./run --dry-run 2>/dev/null | sed -n '/^run: conf:/,$p' | tail -n +2 | sed 's/^    //' > "$TMP/b_$name"
    fi
    norm "$TMP/b_$name" > "$TMP/bn_$name"
done

if command -v pwsh >/dev/null 2>&1; then
    for i in "${!DEVICES[@]}"; do
        flag="${DEVICES[$i]}"; name="${NAMES[$i]}"
        helper="$TMP/gen_$name.ps1"
        {
            printf '$ErrorActionPreference = "Stop"\n'
            printf '. "%s/run.ps1"\n' "$DOSPORT"
            if [ -n "$flag" ]; then
                printf "Invoke-Run -Arguments @('--dry-run', '%s') | Out-Null\n" "$flag"
            else
                printf "Invoke-Run -Arguments @('--dry-run') | Out-Null\n"
            fi
        } > "$helper"
        pwsh -NoProfile -File "$helper" 2>/dev/null \
            | sed -n '/^run: conf:/,$p' | tail -n +2 | sed 's/^    //' > "$TMP/p_$name"
        if [ ! -s "$TMP/p_$name" ]; then
            echo "check_run_parity: ps1 produced no conf for $name" >&2
            fails=$((fails + 1)); continue
        fi
        norm "$TMP/p_$name" > "$TMP/pn_$name"
        if diff -u "$TMP/bn_$name" "$TMP/pn_$name" > "$TMP/d_$name"; then
            echo "  conf parity OK   $name"
        else
            echo "  conf parity FAIL $name"; sed 's/^/    /' "$TMP/d_$name"
            fails=$((fails + 1))
        fi
    done
else
    echo "check_run_parity: pwsh not found — skipping the run.ps1 half"
fi

# --- completion flag coverage ------------------------------------------------
# Every PKMN.EXE flag the parser knows (entry.asm arg_* table) must be offered
# by each completer.
mapfile -t FLAGS < <(
    grep -oE "db +'/[A-Za-z0-9=]+'" boot/entry.asm \
        | sed -E "s/.*'(\/[^']+)'.*/\1/" | sort -u
)
echo "  entry.asm declares ${#FLAGS[@]} /flags"

for f in tools/completion/pkmn-run.zsh tools/completion/pkmn-run.bash tools/completion/pkmn-run.ps1; do
    missing=()
    for fl in "${FLAGS[@]}"; do
        grep -qF "'$fl'" "$f" || missing+=("$fl")
    done
    if [ ${#missing[@]} -eq 0 ]; then
        echo "  completion OK    $f"
    else
        echo "  completion FAIL  $f missing: ${missing[*]}"
        fails=$((fails + 1))
    fi
done

echo
if [ "$fails" -eq 0 ]; then
    echo "check_run_parity: PASS"
else
    echo "check_run_parity: FAIL ($fails)"
    exit 1
fi
