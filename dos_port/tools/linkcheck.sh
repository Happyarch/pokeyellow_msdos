#!/bin/sh
# linkcheck.sh — two-instance null-modem link harness (link-cable plan, Stage 2
# step 5). Builds one DEBUG_LINKCHECK image, boots it in TWO DOSBox-X instances
# joined by an emulated null-modem cable (nullmodem serial over local TCP), and
# asserts that the port's link stack carried both sides into the Cable Club:
#
#   1. establishment: hSerialConnectionStatus is $02 (USING_INTERNAL_CLOCK) on
#      exactly one side and $01 on the other, matching the net session's
#      elected role (netRole);
#   2. both sides reached LinkMenu (lcMarks in_menu byte) with a live session
#      (netLinkUp=1, netState=NS_ESTABLISHED, zero desyncs);
#   3. the /LINKLOG exchange rings cross-check: every byte one side logged as
#      TX appears in the peer's RX log with the same exch_id, both directions.
#
# The in-game driver is RunLinkCheck (src/engine/link/cable_club_npc.asm):
# it loops the REAL CableClubNPC (the faithful 90-frame race) until the two
# instances' races overlap, AUTOKEY_LINKCHECK's A train answers the prompts,
# and both sides park in LinkMenu for the AUTOKEY_DUMP_FRAME photograph.
#
# REQUIRES the nullmodem-capable DOSBox-X fork binary (the system dosbox-x is
# built without C_MODEM): tools/dosbox-x-mcp/dosbox-x-mcp, built by
# tools/build_dosbox_mcp.sh. Verified 2026-08-22: it logs "Nullmodem server
# waiting for connection on TCP port <port>".
#
#   tools/linkcheck.sh [outdir]
#
# Env overrides: LINKCHECK_PORT (default 23456), LINKCHECK_DUMP_FRAME (default
# 3600 — the Makefile gate's default), RUN_TIMEOUT (default 150 s per instance),
# LINKCHECK_STAGGER (default 3 s between instance launches).
set -eu

HERE="$(cd "$(dirname "$0")/.." && pwd)"   # dos_port/
cd "$HERE"

OUT="${1:-${TMPDIR:-/tmp}/linkcheck.$$}"
mkdir -p "$OUT/a" "$OUT/b"

PORT="${LINKCHECK_PORT:-23456}"
DUMP_FRAME="${LINKCHECK_DUMP_FRAME:-3600}"
RUN_TIMEOUT="${RUN_TIMEOUT:-150}"
STAGGER="${LINKCHECK_STAGGER:-3}"

DOSBOX="$HERE/tools/dosbox-x-mcp/dosbox-x-mcp"
if [ ! -x "$DOSBOX" ]; then
    echo "linkcheck: $DOSBOX missing — the system dosbox-x has no C_MODEM" >&2
    echo "linkcheck: build it with tools/build_dosbox_mcp.sh" >&2
    exit 2
fi

SCRATCH="${TMPDIR:-/tmp}/linkcheck.scratch.$$"
mkdir -p "$SCRATCH/a" "$SCRATCH/b"
trap 'rm -rf "$SCRATCH"' EXIT

echo "== linkcheck: make image DEBUG_LINKCHECK=1 AUTOKEY_DUMP_FRAME=$DUMP_FRAME" >&2
make image DEBUG_LINKCHECK=1 AUTOKEY_DUMP_FRAME="$DUMP_FRAME" \
    >"$SCRATCH/build.log" 2>&1 || {
    tail -20 "$SCRATCH/build.log"; echo "linkcheck: build failed" >&2; exit 2; }

# Per-instance image clones + stale-dump purge (run_headless.sh's F-11 rule:
# a file found after the run must be definitionally fresh).
for side in a b; do
    cp PKMN.IMG "$SCRATCH/$side/pkmn.img"
    for f in GBSTATE.BIN DUMP.BIN FRAME.BIN PAL.BIN LINKLOG.BIN; do
        mdel -i "$SCRATCH/$side/pkmn.img@@1048576" "::$f" 2>/dev/null || true
    done
done

# Derive the two confs from the tracked one: per-instance image, /COM1 /LINKLOG
# on the game's command line, exit after the game, and a [serial] section the
# tracked conf deliberately does not carry. Instance A is the nullmodem TCP
# server (no server: parameter — it listens); B connects to it. transparent:1
# is required for raw bytes (without it the link speaks telnet escaping).
sed "s|^imgmount c PKMN.IMG|imgmount c $SCRATCH/a/pkmn.img|; s|^PKMN.EXE\$|PKMN.EXE /COM1 /LINKLOG\nexit|" \
    dosbox-x.conf >"$SCRATCH/a/run.conf"
printf '\n[serial]\nserial1=nullmodem port:%s transparent:1\n' "$PORT" >>"$SCRATCH/a/run.conf"

sed "s|^imgmount c PKMN.IMG|imgmount c $SCRATCH/b/pkmn.img|; s|^PKMN.EXE\$|PKMN.EXE /COM1 /LINKLOG\nexit|" \
    dosbox-x.conf >"$SCRATCH/b/run.conf"
printf '\n[serial]\nserial1=nullmodem server:localhost port:%s transparent:1\n' "$PORT" >>"$SCRATCH/b/run.conf"

echo "== linkcheck: instance A (server) up, B follows after ${STAGGER}s (timeout ${RUN_TIMEOUT}s each)" >&2
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy timeout -s KILL "$RUN_TIMEOUT" \
    "$DOSBOX" -defaultdir "$HERE" -defaultconf -conf "$SCRATCH/a/run.conf" \
    >"$SCRATCH/a/dosbox.log" 2>&1 &
PID_A=$!
sleep "$STAGGER"
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy timeout -s KILL "$RUN_TIMEOUT" \
    "$DOSBOX" -defaultdir "$HERE" -defaultconf -conf "$SCRATCH/b/run.conf" \
    >"$SCRATCH/b/dosbox.log" 2>&1 &
PID_B=$!
wait "$PID_A" || true
wait "$PID_B" || true

got=0
for side in a b; do
    for f in GBSTATE.BIN FRAME.BIN PAL.BIN LINKLOG.BIN DUMP.BIN; do
        if mcopy -n -i "$SCRATCH/$side/pkmn.img@@1048576" "::$f" "$OUT/$side/" 2>/dev/null; then
            got=$((got + 1))
        fi
    done
    cp "$SCRATCH/$side/dosbox.log" "$OUT/$side/dosbox.log"
done
if [ ! -f "$OUT/a/GBSTATE.BIN" ] || [ ! -f "$OUT/b/GBSTATE.BIN" ]; then
    echo "linkcheck: missing GBSTATE.BIN — a run died before its dump" >&2
    for side in a b; do
        echo "--- $side dosbox.log tail ---" >&2
        tail -10 "$OUT/$side/dosbox.log" >&2
    done
    exit 2
fi
echo "== linkcheck: extracted $got files -> $OUT" >&2

rc=0
python3 - "$OUT" <<'PYEOF' || rc=$?
import struct, sys

out = sys.argv[1]
fails = []

def gbstate(path):
    data = open(path, 'rb').read()
    magic, ver, flags, count, dirsize, total = struct.unpack_from('<4sBBHII', data, 0)
    assert magic == b'GBST' and ver == 2, f'{path}: bad GBSTATE header'
    regions = {}
    for i in range(count):
        off = 16 + i * 32
        name = data[off:off + 20].split(b'\0')[0].decode()
        gb_addr, size, foff = struct.unpack_from('<III', data, off + 20)
        regions[name] = data[foff:foff + size]
    return regions

def linklog(path):
    data = open(path, 'rb').read()
    magic, role, state, desyncs, count, _res = struct.unpack_from('<4sBBHII', data, 0)
    assert magic == b'NLG1', f'{path}: bad LINKLOG magic'
    recs = []
    for i in range(count):
        d, b, xid = struct.unpack_from('<BBH', data, 16 + i * 4)
        recs.append((d, xid, b))
    tx = [(xid, b) for d, xid, b in recs if d == 0]
    rx = [(xid, b) for d, xid, b in recs if d == 1]
    return dict(role=role, state=state, desyncs=desyncs, tx=tx, rx=rx)

sides = {}
for s in ('a', 'b'):
    r = gbstate(f'{out}/{s}/GBSTATE.BIN')
    sides[s] = dict(
        status=r['linkStatus'][0], link_state=r['wLinkState'][0],
        up=r['netLinkUp'][0], role=r['netRole'][0], nstate=r['netState'][0],
        desyncs=struct.unpack('<H', r['netDesyncs'])[0],
        attempts=r['lcMarks'][0], in_menu=r['lcMarks'][1])
    try:
        sides[s]['log'] = linklog(f'{out}/{s}/LINKLOG.BIN')
    except FileNotFoundError:
        sides[s]['log'] = None
        fails.append(f'{s}: LINKLOG.BIN missing')

a, b = sides['a'], sides['b']
for s, d in sides.items():
    print(f"  {s}: hSerialConnectionStatus=${d['status']:02x} wLinkState=${d['link_state']:02x} "
          f"netLinkUp={d['up']} netRole={d['role']} netState={d['nstate']} "
          f"desyncs={d['desyncs']} attempts={d['attempts']} in_menu={d['in_menu']}")
    if d['log']:
        print(f"     linklog: role={d['log']['role']} state={d['log']['state']} "
              f"desyncs={d['log']['desyncs']} tx={len(d['log']['tx'])} rx={len(d['log']['rx'])}")

# 1. role split: one USING_INTERNAL_CLOCK ($02, the elected master), one $01
if sorted((a['status'], b['status'])) != [1, 2]:
    fails.append(f"role split wrong: statuses ${a['status']:02x}/${b['status']:02x} (want $01+$02)")
if a['role'] + b['role'] != 1:
    fails.append(f"election inconsistent: netRole {a['role']}/{b['role']} (want exactly one master)")
for s, d in sides.items():
    want = 2 if d['role'] else 1
    if d['status'] != want:
        fails.append(f"{s}: status ${d['status']:02x} does not match elected role {d['role']}")
    if d['up'] != 1:
        fails.append(f"{s}: netLinkUp={d['up']} (session not alive at dump)")
    if d['nstate'] != 3:                       # NS_ESTABLISHED
        fails.append(f"{s}: netState={d['nstate']} (want 3 = NS_ESTABLISHED)")
    if d['desyncs'] != 0:
        fails.append(f"{s}: {d['desyncs']} exch_id desyncs")
    if d['in_menu'] != 1:
        fails.append(f"{s}: never reached LinkMenu (attempts={d['attempts']})")

# 2. exchange-log cross-check: what one side sent is what the other received,
# in order, with matching exch_ids. The two photographs are not simultaneous,
# so compare over the shorter sequence (the tail difference is in-flight).
def cross(tag, tx, rx):
    n = min(len(tx), len(rx))
    if n == 0:
        fails.append(f'{tag}: no exchanges to compare (tx={len(tx)} rx={len(rx)})')
        return
    for i in range(n):
        if tx[i] != rx[i]:
            fails.append(f'{tag}: record {i}: tx (id={tx[i][0]}, ${tx[i][1]:02x}) '
                         f'!= rx (id={rx[i][0]}, ${rx[i][1]:02x})')
            return
    print(f'  {tag}: {n} records match (tx={len(tx)} rx={len(rx)})')

if a['log'] and b['log']:
    cross('A.tx == B.rx', a['log']['tx'], b['log']['rx'])
    cross('B.tx == A.rx', b['log']['tx'], a['log']['rx'])

if fails:
    print('linkcheck: FAIL')
    for f in fails:
        print(f'  - {f}')
    sys.exit(1)
print('linkcheck: PASS')
PYEOF
echo "$OUT"
exit $rc
