#!/usr/bin/env bash
# pick_save.sh — list, stage, back up and extract the save inside PKMN.IMG.
#
# WHY THIS EXISTS
#   `make image` deliberately never touches POKEMON.DSV inside the disk image
#   (see the save contract on the `image` target in dos_port/Makefile), so a
#   save a test session wrote survives everyday rebuilds. The flip side is that
#   there is no automatic way to GET a save in there either, and the old
#   auto-recreate path could drop it. This is that manual door, in one command.
#
#   Related hazard, do not "fix" it here: run_headless.sh copies PKMN.IMG and
#   purges GBSTATE/DUMP/FRAME/PAL but NOT POKEMON.DSV (see the stigmergy memory
#   regression-tooling-stale-dsv-goldencheck), so an unseeded headless probe
#   boots WITH whatever save the base image carries.
#
# USAGE
#   tools/pick_save.sh                     list candidates + the current save
#   tools/pick_save.sh --list              same as above
#   tools/pick_save.sh <n|name-substr>     stage that candidate into PKMN.IMG
#   tools/pick_save.sh --file PATH         stage an arbitrary .dsv/.sav
#   tools/pick_save.sh --current           show/verify the save now in the image
#   tools/pick_save.sh --extract DEST      copy the in-image save out to DEST
#   tools/pick_save.sh --backup            back up the in-image save to save/dos/
#
# Staging always backs the current in-image save up to
#   save/dos/backup-<UTC>.dsv
# first (when one exists and verifies), so switching presets never silently
# destroys a working test save. Pass --no-backup to skip that.
#
# Candidates: save/dos/*.dsv, save/gb/*.sav and tests/fixtures/*.sav. A .sav is
# converted with tools/saveconv.py on the way in, exactly like goldencheck.sh
# does for a seed save. Invalid files are listed but refused.

set -euo pipefail

DOSPORT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DOSPORT"

IMG="PKMN.IMG"
IMG_PART_OFF=1048576          # partition byte offset (matches Makefile IMG_PART_OFF)
IMG_SPEC="${IMG}@@${IMG_PART_OFF}"
DSV_NAME="POKEMON.DSV"
SAVE_DOS="save/dos"
SAVE_GB="save/gb"
FIXTURES="tests/fixtures"
SAVECONV="tools/saveconv.py"

die()  { echo "pick_save: $*" >&2; exit 1; }
note() { echo "pick_save: $*" >&2; }

# --- tool availability -------------------------------------------------------
for t in mcopy mdir mdel; do
    command -v "$t" >/dev/null 2>&1 || die "missing host tool '$t' (install mtools)"
done
command -v python3 >/dev/null 2>&1 || die "missing python3 (needed for saveconv.py)"
[ -f "$SAVECONV" ] || die "missing $SAVECONV"

require_image() {
    [ -f "$IMG" ] || die "no $IMG — build it first: make -C dos_port image"
    # A live DOSBox-X session holds the image mounted rw; staging under it
    # corrupts the run (same guard as the run scripts).
    if command -v fuser >/dev/null 2>&1 && fuser -s "$IMG" 2>/dev/null; then
        die "$IMG is held open by a running DOSBox-X session — close it first"
    fi
}

# --- validation --------------------------------------------------------------
# A .dsv is validated directly; a .sav is converted to a temp .dsv and that is
# validated (which also proves the raw image is the 32 KiB SRAM layout).
TMPDIR_PICK="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_PICK"' EXIT

# verify_sav PATH — 0 if PATH converts to a valid .dsv
verify_sav() {
    local src="$1" out="$TMPDIR_PICK/verify.dsv"
    python3 "$SAVECONV" --to-dos "$src" "$out" >/dev/null 2>&1 || return 1
    python3 "$SAVECONV" --verify "$out" >/dev/null 2>&1
}
verify_dsv() { python3 "$SAVECONV" --verify "$1" >/dev/null 2>&1; }

# as_dsv PATH OUT — materialize PATH (dsv or sav) as a .dsv at OUT.
as_dsv() {
    local src="$1" out="$2"
    case "$src" in
        *.sav) python3 "$SAVECONV" --to-dos "$src" "$out" >/dev/null 2>&1 \
                   || die "could not convert $src to .dsv" ;;
        *.dsv) cp -f "$src" "$out" ;;
        *)     die "unrecognized save type: $src (want .dsv or .sav)" ;;
    esac
}

# --- the in-image save -------------------------------------------------------
# Extract the in-image save to OUT (a .dsv) if one exists and validates.
# Returns 1 when absent or invalid, 0 with OUT populated.
extract_current() {
    local out="$1"
    mcopy -n -i "$IMG_SPEC" "::$DSV_NAME" "$out" 2>/dev/null || return 1
    verify_dsv "$out" || return 1
    return 0
}

# --- candidate enumeration ---------------------------------------------------
# Prints "path\tsav" or "path\tdsv" for every existing candidate, one per line.
list_candidates() {
    local f
    for f in "$SAVE_DOS"/*.dsv; do [ -e "$f" ] && printf '%s\tdsv\n' "$f"; done
    for f in "$SAVE_GB"/*.sav;  do [ -e "$f" ] && printf '%s\tsav\n' "$f"; done
    for f in "$FIXTURES"/*.sav; do [ -e "$f" ] && printf '%s\tsav\n' "$f"; done
}

validity() { # validity PATH TYPE -> "ok" | "INVALID"
    case "$2" in
        dsv) verify_dsv "$1" && echo ok || echo INVALID ;;
        sav) verify_sav "$1" && echo ok || echo INVALID ;;
    esac
}

cmd_list() {
    local i=0 cur_hash="" tmp="$TMPDIR_PICK/current.dsv"
    if extract_current "$tmp"; then
        cur_hash="$(sha1sum "$tmp" | awk '{print $1}')"
    fi

    printf '%-3s %-40s %-5s %-7s %s\n' "#" "candidate" "kind" "valid" "matches image"
    while IFS=$'\t' read -r path kind; do
        i=$((i + 1))
        local dsv="$TMPDIR_PICK/cand.dsv" match=""
        as_dsv "$path" "$dsv" 2>/dev/null || true
        if [ -f "$dsv" ] && [ -n "$cur_hash" ] \
           && [ "$(sha1sum "$dsv" | awk '{print $1}')" = "$cur_hash" ]; then
            match="<-- current"
        fi
        printf '%-3s %-40s %-5s %-7s %s\n' "$i" "$path" "$kind" "$(validity "$path" "$kind")" "$match"
        rm -f "$dsv"
    done < <(list_candidates)

    if [ -n "$cur_hash" ]; then
        echo
        note "image currently holds a save (matches sha1 ${cur_hash:0:12}...)"
    else
        echo
        note "image currently holds NO valid save"
    fi
}

# --- selecting --------------------------------------------------------------
resolve_selector() { # resolve_selector N|substr -> prints one path
    local sel="$1" n=0 hit="" matches=0
    while IFS=$'\t' read -r path kind; do
        n=$((n + 1))
        if [ "$sel" = "$n" ] || [[ "$(basename "$path")" == *"$sel"* ]]; then
            hit="$path"; matches=$((matches + 1))
        fi
    done < <(list_candidates)
    [ "$matches" -gt 0 ] || die "no candidate matches '$sel' (run with --list)"
    if [ "$matches" -gt 1 ] && ! [ "$sel" = "$n" ]; then
        note "warning: '$sel' matched $matches candidates; using the first ($hit)"
    fi
    printf '%s\n' "$hit"
}

backup_current() {
    local tmp="$TMPDIR_PICK/backup.dsv"
    extract_current "$tmp" || return 1
    mkdir -p "$SAVE_DOS"
    local dest="$SAVE_DOS/backup-$(date -u +%Y%m%dT%H%M%SZ).dsv"
    cp -f "$tmp" "$dest"
    note "backed up the previous in-image save -> $dest"
}

stage_file() {
    local src="$1" tmp="$TMPDIR_PICK/stage.dsv"
    [ -f "$src" ] || die "no such file: $src"
    # Validate BEFORE backing up / overwriting anything.
    case "$src" in
        *.sav) verify_sav "$src" || die "$src is not a valid 32 KiB SRAM save" ;;
        *.dsv) verify_dsv "$src" || die "$src is not a valid .dsv" ;;
        *)     die "unrecognized save type: $src (want .dsv or .sav)" ;;
    esac
    if [ "$DO_BACKUP" = 1 ]; then backup_current || true; fi
    as_dsv "$src" "$tmp"

    mcopy -o -i "$IMG_SPEC" "$tmp" "::$DSV_NAME"

    # Verify by extracting back and comparing.
    local back="$TMPDIR_PICK/back.dsv"
    mcopy -n -i "$IMG_SPEC" "::$DSV_NAME" "$back"
    cmp -s "$tmp" "$back" || die "verification failed: staged save does not match source"
    note "staged $src -> ::$DSV_NAME ($(stat -c%s "$tmp") bytes, verified)"
}

cmd_current() {
    local tmp="$TMPDIR_PICK/current.dsv"
    if extract_current "$tmp"; then
        python3 "$SAVECONV" --info "$tmp"
    else
        note "no valid save in $IMG"
        return 1
    fi
}

cmd_extract() {
    local dest="$1" tmp="$TMPDIR_PICK/current.dsv"
    extract_current "$tmp" || die "no valid save in $IMG to extract"
    mkdir -p "$(dirname "$dest")"
    cp -f "$tmp" "$dest"
    note "wrote in-image save -> $dest"
}

# --- CLI ---------------------------------------------------------------------
DO_BACKUP=1
case "${1:-}" in
    ""|--list|-l)     require_image; cmd_list ;;
    --current)        require_image; cmd_current ;;
    --help|-h)
        sed -n '2,40p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
        ;;
    --backup)
        require_image
        backup_current || die "no valid save in $IMG to back up"
        ;;
    --extract)
        [ $# -ge 2 ] || die "--extract needs a destination path"
        require_image; cmd_extract "$2"
        ;;
    --file)
        [ $# -ge 2 ] || die "--file needs a path"
        require_image; stage_file "$2"
        ;;
    --no-backup)
        DO_BACKUP=0
        shift
        [ $# -ge 1 ] || die "--no-backup needs a selector"
        require_image
        stage_file "$(resolve_selector "$1")"
        ;;
    -*)
        die "unknown option: $1 (try --help)"
        ;;
    *)
        require_image
        stage_file "$(resolve_selector "$1")"
        ;;
esac
