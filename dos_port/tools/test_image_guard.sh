#!/usr/bin/env bash
# test_image_guard.sh — prove `make image` never destroys the save.
#
# The save contract (see the `image` target in dos_port/Makefile):
#   - missing image  -> create a bare one (EXE + DPMI host only);
#   - present image  -> refresh EXE/host in place, save untouched;
#   - image too small for the build -> FAIL with restore instructions;
#   - free space short of the growth -> FAIL before writing (no torn EXE).
#
# This exercises all four against a SCRATCH image under dos_port/ (the recipe
# resolves the image through $(CURDIR), so the playground must live there; it
# is removed on exit). It never touches the real PKMN.IMG: every make call
# overrides IMG/TARGET, and TARGET points at fake binaries so nothing compiles.
#
# Needs the same host tools as `make image` itself (sfdisk, mkfs.fat, mtools);
# skips gracefully without them.
set -euo pipefail

DOSPORT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DOSPORT"

for t in sfdisk mkfs.fat mcopy mdir mdel; do
    command -v "$t" >/dev/null 2>&1 || {
        echo "test_image_guard: SKIP (missing host tool '$t')"
        exit 0
    }
done

PLAY=".tmp-image-guard"
rm -rf "$PLAY"
mkdir -p "$PLAY"
trap 'rm -rf "$PLAY"' EXIT

IMG="$PLAY/T.IMG"
SPEC="$PLAY/T.IMG@@1048576"
SMALL="$PLAY/small.exe"
BIG="$PLAY/big.exe"
DPMI="$PLAY/dpmi.exe"

# FAT16 refuses tiny filesystems, so the stand-ins must size a realistic
# image (>= ~16 MB total, like the real one).
head -c 10485760 /dev/zero > "$SMALL"   # 10 MiB stand-in EXE
head -c 18874368 /dev/zero > "$BIG"     # SMALL + 8 MiB: outgrows its image
pass=0; fail=0
ok()  { pass=$((pass + 1)); echo "  ok   $1"; }
bad() { fail=$((fail + 1)); echo "  FAIL $1"; }
die() { echo "  SETUP-FAILED: $1" >&2; exit 2; }

# NOTE: only IMG/TARGET are overridden. DPMI_HOST stays the default
# CWSDPMI.EXE because the recipe copies it to x:$(DPMI_HOST), and an mtools
# target with slashes in it is read as subdirectories.
mkimage() { # mkimage EXE — make image with IMG/TARGET overridden, quiet
    make -s image IMG="$IMG" TARGET="$2" >/dev/null 2>&1 \
        || die "make image failed for $2"
}

put_save() { # put a valid save in the scratch image
    mcopy -o -i "$SPEC" save/dos/generic_early_game_testbed_save.dsv ::POKEMON.DSV
}
save_sha() { # save_sha -> sha1 of the in-image save, or MISSING/INVALID
    local tmp="$PLAY/out.dsv"
    mcopy -n -i "$SPEC" ::POKEMON.DSV "$tmp" 2>/dev/null || { echo MISSING; return 0; }
    python3 tools/saveconv.py --verify "$tmp" >/dev/null 2>&1 || { echo INVALID; return 0; }
    sha1sum "$tmp" | awk '{print $1}'
}
exe_size_in_image() {
    mdir -i "$SPEC" :: 2>/dev/null | awk '$1=="PKMN" && $2=="EXE" {print $3}'
}

echo "== image-guard contract =="

# 1. missing image -> bare create (EXE + DPMI host only, no save)
mkimage x "$SMALL"
if mdir -i "$SPEC" :: 2>/dev/null | grep -q "PKMN.*EXE" \
   && ! mcopy -n -i "$SPEC" ::POKEMON.DSV "$PLAY/nope" 2>/dev/null; then
    ok "create: bare image, no save smuggled in"
else
    bad "create: bare image, no save smuggled in"
fi

# 2. refresh preserves the save byte-for-byte (the everyday rebuild path)
put_save
before="$(save_sha)"
mkimage x "$SMALL"
after="$(save_sha)"
[ "$before" != MISSING ] && [ "$before" != INVALID ] && [ "$before" = "$after" ] \
    && ok "refresh: save byte-identical across rebuild" \
    || bad "refresh: save byte-identical across rebuild (was $before, now $after)"

# 3. image too small -> FAIL, save and EXE untouched
put_save
before="$(save_sha)"; exe_before="$(exe_size_in_image)"
if make -s image IMG="$IMG" TARGET="$BIG" >"$PLAY/make3.log" 2>&1; then
    bad "too-small image must fail the build"
elif ! grep -q "POKEMON.DSV" "$PLAY/make3.log"; then
    bad "too-small: failed, but without the restore instructions"; sed 's/^/    /' "$PLAY/make3.log"
else
    after="$(save_sha)"; exe_after="$(exe_size_in_image)"
    if [ "$before" = "$after" ] && [ "$exe_before" = "$exe_after" ]; then
        ok "too-small: refused with instructions, save + EXE untouched"
    else
        bad "too-small: refused but image changed (save $before->$after, exe $exe_before->$exe_after)"
    fi
fi

# 4. free space short -> FAIL before writing, save and EXE untouched.
#    NOTE: with the slack formula ANY growth >= 512 bytes trips branch 3
#    first (the file size tracks img_sz exactly), so this branch is reachable
#    only when the FILE is bigger than the filesystem thinks: pad the file
#    (simulating headroom from an earlier larger build) and eat the filesystem
#    free space with junk. Growth is then total-fitting but filesystem-short.
MED="$PLAY/med.exe"
head -c 10551296 /dev/zero > "$MED"    # SMALL + 64 KiB
mkimage x "$SMALL"
put_save
truncate -s +1048576 "$IMG"           # file headroom; filesystem unchanged
free_now="$(mdir -i "$SPEC" :: | grep 'bytes free' | tr -cd '0-9')"
head -c $((free_now - 200)) /dev/zero > "$PLAY/junk"
mcopy -o -i "$SPEC" "$PLAY/junk" ::JUNK.BIN >/dev/null
before="$(save_sha)"; exe_before="$(exe_size_in_image)"
if make -s image IMG="$IMG" TARGET="$MED" >"$PLAY/make4.log" 2>&1; then
    bad "short free space must fail the build"
elif ! grep -q "not enough free space" "$PLAY/make4.log"; then
    bad "short-free: failed, but via the wrong branch:"; sed 's/^/    /' "$PLAY/make4.log"
else
    after="$(save_sha)"; exe_after="$(exe_size_in_image)"
    if [ "$before" = "$after" ] && [ "$exe_before" = "$exe_after" ]; then
        ok "short-free: refused, save + EXE untouched (no torn write)"
    else
        bad "short-free: refused but image changed (save $before->$after, exe $exe_before->$exe_after)"
    fi
fi

echo
if [ "$fail" -eq 0 ]; then
    echo "test_image_guard: PASS ($pass)"
else
    echo "test_image_guard: FAIL ($fail of $((pass + fail)))"
    exit 1
fi
