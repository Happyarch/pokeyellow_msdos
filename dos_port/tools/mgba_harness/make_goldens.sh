#!/usr/bin/env bash
# Regenerate all committed goldens (dos_port/tests/goldens/) from the
# sha1-verified golden ROM. Invoked as `make -C dos_port goldens`.
#
# Ground-truth inputs come from the pinned pristine pret worktree (the branch
# tree does NOT build the ROM — see the fidelity plan, Session A note):
#   $PRET_GOLDEN_DIR (default: ../pokeyellow_msdos-pret-golden next to the
#   repo root) must hold pokeyellow.gbc + pokeyellow.sym from `make yellow`.
# The ROM is sha1-checked against roms.sha1 before every run — goldens are
# only ever generated from a verified ROM.
#
# Scenarios are deterministic (state-aware navigation, fixed seeds), so two
# consecutive runs must produce byte-identical .bin files.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PRET_GOLDEN_DIR="${PRET_GOLDEN_DIR:-$(dirname "$REPO_ROOT")/pokeyellow_msdos-pret-golden}"

ROM="$PRET_GOLDEN_DIR/pokeyellow.gbc"
SYM="$PRET_GOLDEN_DIR/pokeyellow.sym"
RUNNER="$REPO_ROOT/dos_port/tools/mgba_build/mgba-lua-runner"
OUT_DIR="$REPO_ROOT/dos_port/tests/goldens"

for f in "$ROM" "$SYM"; do
    [ -f "$f" ] || { echo "ERROR: $f missing — build the golden ROM:" >&2
        echo "  git worktree add --detach '$PRET_GOLDEN_DIR' 7caf2e09 && make -C '$PRET_GOLDEN_DIR' yellow" >&2
        exit 1; }
done
[ -x "$RUNNER" ] || { echo "ERROR: $RUNNER missing — run dos_port/tools/build_mgba.sh" >&2; exit 1; }

# sha1 gate: the golden ROM must match the pret-pinned checksum
want_sha1=$(awk '/pokeyellow.gbc/ { print $1 }' "$REPO_ROOT/roms.sha1")
have_sha1=$(sha1sum "$ROM" | awk '{ print $1 }')
if [ "$want_sha1" != "$have_sha1" ]; then
    echo "ERROR: $ROM sha1 $have_sha1 != roms.sha1 $want_sha1 — refusing to generate goldens" >&2
    exit 1
fi

mkdir -p "$OUT_DIR"
cd "$REPO_ROOT" # scenarios resolve constants/charmap.asm relative to cwd

status=0
for scenario in "$SCRIPT_DIR"/scenarios/*.lua; do
    name=$(basename "$scenario" .lua)
    echo "=== golden: $name"
    if GOLDEN_DIR="$OUT_DIR" PKMN_SYM="$SYM" \
        "$RUNNER" -s "$scenario" "$ROM" 2>&1 | grep -v 'MBC5 unknown address'; then
        :
    else
        echo "ERROR: scenario $name failed" >&2
        status=1
    fi
done

echo
sha1sum "$OUT_DIR"/*.bin
exit $status
