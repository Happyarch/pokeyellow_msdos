#!/bin/sh
# kbdnamecheck.sh — SINGLE-instance KBD_NAMING scancode-injection harness
# (link cable plan Stage 5 step 5, Deliverable 3 — `kbd_naming_entry` in
# tools/scenario_manifest.json). Same single-instance skeleton as
# linkbookcheck.sh (no nullmodem, no peer, one scratch image, one headless
# run), simplified further: no persistence to prove, so there is only one run.
#
# RunKbdNameCheckTest (src/engine/menus/naming_screen.asm) seeds the
# deterministic RED/id-0 identity, then calls the REAL, blocking
# DisplayNamingScreen for the PLAYER screen (dest wPlayerName) -- unlike the
# DEBUG_NAMINGSCREEN golden's RunNamingScreenTest, which deliberately never
# enters that loop (see its own header). AutoKeyDrive's AUTOKEY_KBDSCRIPT
# table (src/debug/debug_dump.asm, AUTOKEY_KBDNAMECHECK selector) types "Ab"
# (shift A, unshifted b), Tab opens the KBD_NAMING special-character picker
# (kbd_scancode_map.inc's KbdPickerChars), Enter picks its index-0 entry
# (deterministic), a second Enter submits the whole name.
#
# Asserts the committed wPlayerName bytes (GBSTATE region "wPlayerName",
# already dumped unconditionally by every scenario -- see debug_dump.asm)
# against "Ab" + KbdPickerChars[0], both computed rather than hard-coded:
# "Ab" via tools/generators/gb_text.py's encode() (never hand-coded charmap
# hex), the picker char by parsing the GENERATED
# dos_port/assets/kbd_scancode_map.inc (gen_kbd_naming.py's output) for its
# own KbdPickerChars table, never a literal byte value in this script.
#
#   tools/kbdnamecheck.sh [outdir]
#
# Env overrides: KBDNAMECHECK_DUMP_FRAME (default 600, the Makefile gate's
# own default), RUN_TIMEOUT (default 150s).
set -eu

HERE="$(cd "$(dirname "$0")/.." && pwd)"   # dos_port/
cd "$HERE"

OUT="${1:-${TMPDIR:-/tmp}/kbdnamecheck.$$}"
mkdir -p "$OUT"

DUMP_FRAME="${KBDNAMECHECK_DUMP_FRAME:-600}"
RUN_TIMEOUT="${RUN_TIMEOUT:-150}"

SCRATCH="${TMPDIR:-/tmp}/kbdnamecheck.scratch.$$"
mkdir -p "$SCRATCH"
trap 'rm -rf "$SCRATCH"' EXIT

echo "== kbdnamecheck: make image KBD_NAMING=1 DEBUG_KBDNAMECHECK=1 AUTOKEY_DUMP_FRAME=$DUMP_FRAME" >&2
make image KBD_NAMING=1 DEBUG_KBDNAMECHECK=1 AUTOKEY_DUMP_FRAME="$DUMP_FRAME" \
    >"$SCRATCH/build.log" 2>&1 || {
    tail -20 "$SCRATCH/build.log"; echo "kbdnamecheck: build failed" >&2; exit 2; }

cp PKMN.IMG "$SCRATCH/pkmn.img"
for f in GBSTATE.BIN DUMP.BIN FRAME.BIN PAL.BIN; do
    mdel -i "$SCRATCH/pkmn.img@@1048576" "::$f" 2>/dev/null || true
done

sed "s|^imgmount c PKMN.IMG|imgmount c $SCRATCH/pkmn.img|; s|^PKMN.EXE\$|PKMN.EXE\nexit|" \
    dosbox-x.conf >"$SCRATCH/run.conf"

echo "== kbdnamecheck: headless DOSBox-X (timeout ${RUN_TIMEOUT}s)" >&2
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy timeout -s KILL "$RUN_TIMEOUT" \
    dosbox-x -defaultdir "$HERE" -defaultconf -conf "$SCRATCH/run.conf" \
    >"$SCRATCH/dosbox.log" 2>&1 || true

got=0
for f in GBSTATE.BIN FRAME.BIN; do
    if mcopy -n -i "$SCRATCH/pkmn.img@@1048576" "::$f" "$OUT/" 2>/dev/null; then
        got=$((got + 1))
    fi
done
if [ ! -f "$OUT/GBSTATE.BIN" ]; then
    echo "kbdnamecheck: missing GBSTATE.BIN -- died before its dump" >&2
    tail -20 "$SCRATCH/dosbox.log" >&2
    exit 2
fi
echo "== kbdnamecheck: extracted $got files" >&2

rc=0
python3 - "$OUT" "$HERE" <<'PYEOF' || rc=$?
import re, struct, sys
from pathlib import Path

out, here = sys.argv[1], sys.argv[2]
sys.path.insert(0, str(Path(here) / "tools" / "generators"))
import gb_text  # noqa: E402 -- charmap encode(), never hand-coded hex (CLAUDE.md rule)

fails = []

def gbstate(path):
    data = Path(path).read_bytes()
    magic, ver, flags, count, dirsize, total = struct.unpack_from('<4sBBHII', data, 0)
    assert magic == b'GBST' and ver == 2, f'{path}: bad GBSTATE header'
    regions = {}
    for i in range(count):
        off = 16 + i * 32
        name = data[off:off + 20].split(b'\0')[0].decode()
        gb_addr, size, foff = struct.unpack_from('<III', data, off + 20)
        regions[name] = data[foff:foff + size]
    return regions

def first_picker_char():
    """Parse the GENERATED assets/kbd_scancode_map.inc for KbdPickerChars'
    first byte -- never a hard-coded literal (CLAUDE.md rule: generated data
    is read, not duplicated by hand)."""
    inc_path = Path(here) / "assets" / "kbd_scancode_map.inc"
    text = inc_path.read_text()
    m = re.search(r'KbdPickerChars:.*?\n\s*db\s+([^\n]+)', text, re.S)
    assert m, f'{inc_path}: KbdPickerChars table not found'
    values = [int(x.strip(), 16) for x in m.group(1).split(',')]
    assert values and values[0] != 0xFF, f'{inc_path}: KbdPickerChars is empty'
    return values[0]

r = gbstate(f'{out}/GBSTATE.BIN')

knMarks = r['knMarks']
print(f"  knMarks: {knMarks[0]}")
if knMarks[0] != 1:
    fails.append('knMarks not set -- DisplayNamingScreen never reached .submitNickname')

picker_char = first_picker_char()
print(f"  KbdPickerChars[0] = 0x{picker_char:02X}")

expected = bytes(gb_text.encode('Ab')) + bytes([picker_char]) + bytes([0x50])
got = r['wPlayerName'][:len(expected)]
print(f"  wPlayerName (first {len(expected)} bytes): {got.hex()}  expected: {expected.hex()}")
if got != expected:
    fails.append(f'wPlayerName prefix {got.hex()} != expected {expected.hex()} '
                 f'("Ab" + KbdPickerChars[0]=0x{picker_char:02X} + terminator)')

if fails:
    print('kbdnamecheck: FAIL')
    for f in fails:
        print(f'  - {f}')
    sys.exit(1)
print('kbdnamecheck: PASS')
PYEOF
echo "$OUT"
exit $rc
