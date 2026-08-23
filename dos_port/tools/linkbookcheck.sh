#!/bin/sh
# linkbookcheck.sh — SINGLE-instance connection-book persistence harness
# (link cable plan Stage 5 step 5, Deliverable 2 — `link_book_roundtrip` in
# tools/scenario_manifest.json). UNLIKE linkcheck.sh/tradecheck.sh/
# battlecheck.sh, there is NO nullmodem cable and no second DOSBox-X instance:
# RunLinkBookCheck (src/engine/link/cable_club_npc.asm) calls the real
# CableClubNPC with no /COM1 flag and no peer, so its LinkTransportSelect call
# opens the port-only transport-select/connection-book UI (src/net/link_ui.asm)
# instead of racing an establishment window — that UI is this harness's whole
# subject. AutoKeyDrive's AUTOKEY_LINKBOOKCHECK[_PHASE2] state machine drives
# the menus; AUTOKEY_KBDSCRIPT (shared with kbdnamecheck.sh) types the NAME?/
# ADDRESS? fields via kbd_ring_push (src/input/joypad.asm). See
# RunLinkBookCheck's header for the full mechanism citation trace.
#
# TWO SEQUENTIAL runs against the SAME scratch disk image (never the tree's
# own dos_port/PKMN.IMG — this script only ever touches a scratch copy, same
# isolation rule run_headless.sh/goldencheck.sh follow):
#   run 1 (fresh — LINKBOOK.DAT purged first): TCP book -> NEW -> "HOME" /
#     "10.0.0.1:5000" -> SAVED; IPX book -> NEW -> "LAN" / hex
#     "FEED:C0FFEE001122" -> SAVED; CANCEL out (no connect attempt — the
#     connect seam fails by design in Stage 5, see link_ui_connect_attempt).
#   run 2 (SAME scratch image, LINKBOOK.DAT NOT purged -- that is the
#     persistence point under test; rebuilt with LBC_PHASE2=1, its PKMN.EXE
#     swapped onto the SAME image via mcopy, exactly as `make image`'s own
#     rule does): TCP record -> EDIT -> "WORK" / "10.0.0.2:5001" -> SAVED;
#     IPX record -> DELETE -> YES confirm -> SAVED.
#
# Asserts, per run, against GBSTATE.BIN's lbcMarks region (game-code-gated
# stores in src/net/link_ui.asm — see RunLinkBookCheck's header: NOT harness
# bookkeeping) and the extracted LINKBOOK.DAT parsed byte-for-byte (name
# bytes computed via tools/generators/gb_text.py's encode(), never
# hard-coded charmap hex; address bytes are raw binary, not charmap text, so
# they are computed directly).
#
# SCOPE (deferred per the plan spec's explicit allowance -- see
# link_book_roundtrip's "verification" field in scenario_manifest.json): the
# FULL-book path (5/5 entries + the FULL! message) is NOT exercised by either
# run here; a future phase 3 would fill the remaining 4 slots per family.
#
#   tools/linkbookcheck.sh [outdir]
#
# Env overrides: LINKBOOKCHECK_DUMP_FRAME (default 3000, the Makefile gate's
# own default), RUN_TIMEOUT (default 150s per run).
set -eu

HERE="$(cd "$(dirname "$0")/.." && pwd)"   # dos_port/
cd "$HERE"

OUT="${1:-${TMPDIR:-/tmp}/linkbookcheck.$$}"
mkdir -p "$OUT/run1" "$OUT/run2"

DUMP_FRAME="${LINKBOOKCHECK_DUMP_FRAME:-3000}"
RUN_TIMEOUT="${RUN_TIMEOUT:-150}"

SCRATCH="${TMPDIR:-/tmp}/linkbookcheck.scratch.$$"
mkdir -p "$SCRATCH"
trap 'rm -rf "$SCRATCH"' EXIT

# ---------------------------------------------------------------------------
# run1: fresh image, both books created.
# ---------------------------------------------------------------------------
echo "== linkbookcheck: run1 -- make image DEBUG_LINKBOOKCHECK=1 AUTOKEY_DUMP_FRAME=$DUMP_FRAME" >&2
make image DEBUG_LINKBOOKCHECK=1 AUTOKEY_DUMP_FRAME="$DUMP_FRAME" \
    >"$SCRATCH/build1.log" 2>&1 || {
    tail -20 "$SCRATCH/build1.log"; echo "linkbookcheck: run1 build failed" >&2; exit 2; }

cp PKMN.IMG "$SCRATCH/pkmn.img"
# F-11 (run_headless.sh's rule) PLUS the plan's own explicit requirement:
# LINKBOOK.DAT must be genuinely absent for run1 -- a stale one baked into an
# earlier build of this same tree would silently turn "creates both entries"
# into "already had both entries", which two green marks would not catch.
for f in GBSTATE.BIN DUMP.BIN FRAME.BIN PAL.BIN LINKBOOK.DAT; do
    mdel -i "$SCRATCH/pkmn.img@@1048576" "::$f" 2>/dev/null || true
done

sed "s|^imgmount c PKMN.IMG|imgmount c $SCRATCH/pkmn.img|; s|^PKMN.EXE\$|PKMN.EXE\nexit|" \
    dosbox-x.conf >"$SCRATCH/run.conf"

echo "== linkbookcheck: run1 -- headless DOSBox-X (timeout ${RUN_TIMEOUT}s)" >&2
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy timeout -s KILL "$RUN_TIMEOUT" \
    dosbox-x -defaultdir "$HERE" -defaultconf -conf "$SCRATCH/run.conf" \
    >"$SCRATCH/dosbox1.log" 2>&1 || true

got=0
for f in GBSTATE.BIN LINKBOOK.DAT FRAME.BIN; do
    if mcopy -n -i "$SCRATCH/pkmn.img@@1048576" "::$f" "$OUT/run1/" 2>/dev/null; then
        got=$((got + 1))
    fi
done
if [ ! -f "$OUT/run1/GBSTATE.BIN" ]; then
    echo "linkbookcheck: run1 -- missing GBSTATE.BIN, died before its dump" >&2
    tail -20 "$SCRATCH/dosbox1.log" >&2
    exit 2
fi
echo "== linkbookcheck: run1 -- extracted $got files" >&2

# ---------------------------------------------------------------------------
# run2: SAME scratch image (LINKBOOK.DAT untouched), new EXE swapped in.
# ---------------------------------------------------------------------------
echo "== linkbookcheck: run2 -- make PKMN.EXE DEBUG_LINKBOOKCHECK=1 LBC_PHASE2=1 AUTOKEY_DUMP_FRAME=$DUMP_FRAME" >&2
make PKMN.EXE DEBUG_LINKBOOKCHECK=1 LBC_PHASE2=1 AUTOKEY_DUMP_FRAME="$DUMP_FRAME" \
    >"$SCRATCH/build2.log" 2>&1 || {
    tail -20 "$SCRATCH/build2.log"; echo "linkbookcheck: run2 build failed" >&2; exit 2; }

# Swap the new EXE onto the SAME scratch image -- same `mcopy -D o` idiom the
# Makefile's own `image` rule uses -- so every OTHER file already on the
# image (LINKBOOK.DAT from run1, CWSDPMI.EXE from run1's initial `cp`) is
# left exactly as it was. This is the actual persistence mechanism under
# test: run2 reads the SAME on-disk book run1 wrote.
mt="$(mktemp)"
printf 'drive x: file="%s" offset=1048576\n' "$SCRATCH/pkmn.img" >"$mt"
MTOOLSRC="$mt" mcopy -D o PKMN.EXE x:PKMN.EXE
rm -f "$mt"

for f in GBSTATE.BIN DUMP.BIN FRAME.BIN PAL.BIN; do
    mdel -i "$SCRATCH/pkmn.img@@1048576" "::$f" 2>/dev/null || true
done

echo "== linkbookcheck: run2 -- headless DOSBox-X (timeout ${RUN_TIMEOUT}s)" >&2
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy timeout -s KILL "$RUN_TIMEOUT" \
    dosbox-x -defaultdir "$HERE" -defaultconf -conf "$SCRATCH/run.conf" \
    >"$SCRATCH/dosbox2.log" 2>&1 || true

got=0
for f in GBSTATE.BIN LINKBOOK.DAT FRAME.BIN; do
    if mcopy -n -i "$SCRATCH/pkmn.img@@1048576" "::$f" "$OUT/run2/" 2>/dev/null; then
        got=$((got + 1))
    fi
done
if [ ! -f "$OUT/run2/GBSTATE.BIN" ]; then
    echo "linkbookcheck: run2 -- missing GBSTATE.BIN, died before its dump" >&2
    tail -20 "$SCRATCH/dosbox2.log" >&2
    exit 2
fi
echo "== linkbookcheck: run2 -- extracted $got files" >&2

# ---------------------------------------------------------------------------
# Assertions.
# ---------------------------------------------------------------------------
rc=0
python3 - "$OUT" "$HERE" <<'PYEOF' || rc=$?
import struct, sys
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

# LINKBOOK.DAT layout (src/net/link_book.asm): magic "LNKB" LE (4) + version (1)
# + checksum LE (2) = 7-byte header, then 10 fixed 32-byte LBREC records (TCP
# family 0, slots 0-4; IPX family 1, slots 0-4): in_use(1) name(16) addr(10)
# pad(5).
LB_MAGIC = b'LNKB'
LB_HDR = 7
REC_SIZE = 32
SLOTS = 5

def linkbook(path):
    data = Path(path).read_bytes()
    assert len(data) == LB_HDR + REC_SIZE * SLOTS * 2, f'{path}: wrong size {len(data)}'
    magic = data[0:4]
    version = data[4]
    checksum = struct.unpack_from('<H', data, 5)[0]
    payload = data[LB_HDR:]
    computed = sum(payload) & 0xFFFF
    assert magic == LB_MAGIC, f'{path}: bad magic {magic!r}'
    assert version == 1, f'{path}: bad version {version}'
    assert checksum == computed, f'{path}: checksum {checksum:#06x} != computed {computed:#06x}'
    recs = {}
    for fam, fam_name in ((0, 'tcp'), (1, 'ipx')):
        for slot in range(SLOTS):
            off = LB_HDR + (fam * SLOTS + slot) * REC_SIZE
            rec = payload[off - LB_HDR:off - LB_HDR + REC_SIZE]
            recs[(fam_name, slot)] = dict(
                in_use=rec[0], name=rec[1:17], addr=rec[17:27], pad=rec[27:32])
    return recs

def name_prefix_ok(raw16, text, tag):
    """Assert raw16[:len(encoded)+1] == encoded charmap bytes + '@' ($50)
    terminator. Only the prefix through the terminator is well-defined by
    the write path (lu_new_edit_common copies all 16 bytes of lu_name_scratch,
    itself a straight copy of wStringBuffer -- kbd_text_edit never clears
    bytes PAST the terminator, so the trailing pad bytes are whatever
    wStringBuffer held before this call, not a fixed value this script can
    predict from source alone). This is the byte-exact, well-defined part of
    "the name field", computed via gb_text.encode() -- never hard-coded hex."""
    encoded = bytes(gb_text.encode(text)) + bytes([0x50])
    got = raw16[:len(encoded)]
    if got != encoded:
        fails.append(f'{tag}: name prefix {got.hex()} != expected {encoded.hex()} ({text!r})')

def addr_ok(raw10, expected, tag):
    if bytes(raw10) != bytes(expected):
        fails.append(f'{tag}: addr {bytes(raw10).hex()} != expected {bytes(expected).hex()}')

# --- run1: both NEW commits, cancelled out, no connect ---
r1 = gbstate(f'{out}/run1/GBSTATE.BIN')
marks1 = r1['lbcMarks']
print(f"  run1 lbcMarks: tcp_new={marks1[0]} ipx_new={marks1[1]} tcp_edited={marks1[2]} "
      f"ipx_deleted={marks1[3]} menu_opened={marks1[4]} cancelled={marks1[5]}")
if marks1[0] != 1:
    fails.append('run1: LBC_TCP_NEW not set -- TCP entry was never committed')
if marks1[1] != 1:
    fails.append('run1: LBC_IPX_NEW not set -- IPX entry was never committed')
if marks1[2] != 0:
    fails.append('run1: LBC_TCP_EDITED set -- unexpected on a fresh run')
if marks1[3] != 0:
    fails.append('run1: LBC_IPX_DELETED set -- unexpected on a fresh run')
if marks1[4] != 1:
    fails.append('run1: LBC_MENU_OPENED not set -- LinkTransportSelect UI never opened')
if marks1[5] != 1:
    fails.append('run1: LBC_CANCELLED not set -- the scenario never reached .cancel_all')
if r1['netTransport'][0] != 0:
    fails.append(f"run1: netTransport={r1['netTransport'][0]} -- a transport bound (should stay NONE=0)")

lb1 = linkbook(f'{out}/run1/LINKBOOK.DAT')
tcp1 = lb1[('tcp', 0)]
if tcp1['in_use'] != 1:
    fails.append('run1: TCP slot 0 in_use=0 -- NEW did not persist')
name_prefix_ok(tcp1['name'], 'HOME', 'run1 TCP name')
addr_ok(tcp1['addr'], [10, 0, 0, 1, 0x13, 0x88, 0, 0, 0, 0], 'run1 TCP addr (10.0.0.1:5000)')

ipx1 = lb1[('ipx', 0)]
if ipx1['in_use'] != 1:
    fails.append('run1: IPX slot 0 in_use=0 -- NEW did not persist')
name_prefix_ok(ipx1['name'], 'LAN', 'run1 IPX name')
# net=$0000FEED (4B BE), node=$C0FFEE001122 (top16 $C0FF + low32 $EE001122, both BE)
addr_ok(ipx1['addr'], [0x00, 0x00, 0xFE, 0xED, 0xC0, 0xFF, 0xEE, 0x00, 0x11, 0x22],
        'run1 IPX addr (FEED:C0FFEE001122)')

for slot in range(1, SLOTS):
    if lb1[('tcp', slot)]['in_use'] != 0:
        fails.append(f'run1: TCP slot {slot} unexpectedly in_use')
    if lb1[('ipx', slot)]['in_use'] != 0:
        fails.append(f'run1: IPX slot {slot} unexpectedly in_use')

# --- run2: TCP EDITed, IPX DELETEd, persistence proven ---
r2 = gbstate(f'{out}/run2/GBSTATE.BIN')
marks2 = r2['lbcMarks']
print(f"  run2 lbcMarks: tcp_new={marks2[0]} ipx_new={marks2[1]} tcp_edited={marks2[2]} "
      f"ipx_deleted={marks2[3]} menu_opened={marks2[4]} cancelled={marks2[5]}")
if marks2[2] != 1:
    fails.append('run2: LBC_TCP_EDITED not set -- EDIT was never committed')
if marks2[3] != 1:
    fails.append('run2: LBC_IPX_DELETED not set -- DELETE was never committed')

lb2 = linkbook(f'{out}/run2/LINKBOOK.DAT')
tcp2 = lb2[('tcp', 0)]
if tcp2['in_use'] != 1:
    fails.append('run2: TCP slot 0 in_use=0 -- record vanished across EDIT')
name_prefix_ok(tcp2['name'], 'WORK', 'run2 TCP name (post-EDIT)')
addr_ok(tcp2['addr'], [10, 0, 0, 2, 0x13, 0x89, 0, 0, 0, 0],
        'run2 TCP addr (post-EDIT, 10.0.0.2:5001)')
if tcp2['name'] == tcp1['name'] and tcp2['addr'] == tcp1['addr']:
    fails.append('run2: TCP record identical to run1 -- EDIT had no effect (persistence not proven)')

ipx2 = lb2[('ipx', 0)]
if ipx2['in_use'] != 0:
    fails.append('run2: IPX slot 0 still in_use=1 -- DELETE did not persist')
if any(b != 0 for b in ipx2['name'] + ipx2['addr'] + ipx2['pad']):
    fails.append('run2: IPX slot 0 not fully zeroed after DELETE')

# persistence proof proper: run1's committed TCP name/addr must have been
# VISIBLE to run2 before the EDIT overwrote them -- i.e. run2's build never
# saw a fresh/empty book. The strongest static evidence available here is
# that run2's marks show EDIT (not a fresh NEW under a coincidentally-empty
# slot 0) and the on-disk file's slot 0 was already in_use per run1's own
# dump. Cross-check that explicitly:
if tcp1['in_use'] != 1:
    fails.append('run1: TCP slot 0 was not in_use at run1 -- run2 EDIT precondition unmet')

if fails:
    print('linkbookcheck: FAIL')
    for f in fails:
        print(f'  - {f}')
    sys.exit(1)
print('linkbookcheck: PASS')
PYEOF
echo "$OUT"
exit $rc
