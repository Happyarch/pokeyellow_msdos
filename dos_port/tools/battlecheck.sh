#!/bin/sh
# battlecheck.sh — two-instance null-modem link-BATTLE harness (link-cable
# plan, Stage 4 step 3). Fork of tradecheck.sh: builds one DEBUG_BATTLECHECK
# image, boots it in TWO DOSBox-X instances joined by an emulated null-modem
# cable, drives a REAL Colosseum link battle to completion, and asserts the
# GBSTATE postconditions:
#
#   1. establishment: hSerialConnectionStatus is $02 (USING_INTERNAL_CLOCK,
#      the master) on exactly one side and $01 on the other; netState is
#      NS_ESTABLISHED (3) and netDesyncs is 0 on both; netLinkUp is 1 on both
#      (the session is still alive at dump time).
#   2. both harness marks (bcMarks: battle_started, battle_over) are set on
#      BOTH sides — the battle actually started (wIsInBattle nonzero with
#      wLinkState==LINK_STATE_BATTLING, latched live by AUTOKEY_BATTLECHECK's
#      .apply block) and actually ended (EndOfBattle's link-battle branch,
#      end_of_battle.asm).
#   3. LOCKSTEP: bcMarks.turn_count (incremented once per
#      LinkBattleExchangeData call, core.asm) is EQUAL on both sides and
#      >= 1 — the two instances agree on how many nybble exchanges the
#      battle took, which is the core proof that the link protocol kept both
#      sides' turn order synchronized start to finish.
#   4. CONSISTENT RESULT: bcMarks.battle_result (wBattleResult at battle_over
#      time: $00 win / $01 lose / $02 draw — core.asm's EndOfBattle
#      cmp/jc/je chain, `cmp al,1 / jc win-branch / je lose-branch /
#      fallthrough draw-branch`) is COMPLEMENTARY across the two instances:
#      each side's "win" means ITS OWN player won, so a real, consistent
#      battle shows exactly one of A-WIN/B-LOSE, A-LOSE/B-WIN, or
#      BOTH-DRAW — never both sides reporting the same non-draw result.
#   5. LINKLOG cross-check both directions (linkcheck.sh's/tradecheck.sh's
#      parser, reused verbatim — /LINKLOG is armed on both sides for this).
#
# The in-game driver is RunBattleCheck (src/engine/link/cable_club_npc.asm):
# it loops the REAL CableClubNPC exactly like RunTradeCheck until the two
# instances' establishment races overlap, then AUTOKEY_BATTLECHECK's A train
# (with one live-WRAM-gated DOWN to select LinkMenu's COLOSSEUM item, and a
# live-WRAM-gated one-tile walk to the role's table gameboy — debug_dump.asm
# AutoKeyDrive's AUTOKEY_BATTLECHECK block) drives the whole link battle on a
# bare A-train (FIGHT + move-1 every turn; ITEM is banned outright in a link
# battle by the core, and the cursor never leaves FIGHT/move-1 anyway since
# no D-pad press ever moves it there — see that block's header for the full
# citation trace).
#
# REQUIRES the nullmodem-capable DOSBox-X fork binary, same as
# linkcheck.sh/tradecheck.sh: tools/dosbox-x-mcp/dosbox-x-mcp
# (tools/build_dosbox_mcp.sh).
#
#   tools/battlecheck.sh [outdir]
#
# Env overrides: BATTLECHECK_PORT (default 23458 — DIFFERENT from linkcheck's
# 23456 and tradecheck's 23457 so all three harnesses can coexist),
# BATTLECHECK_DUMP_FRAME (default 20000 — the Makefile gate's default; a full
# link battle's turn-by-turn menu redraws, HP-bar animation and faint/switch
# handling run longer than a trade's two menu rounds — UNVALIDATED until the
# maintainer's end-of-plan dynamic battery runs this script for real),
# RUN_TIMEOUT (default 420 s per instance — generous: the rendezvous retry
# loop, the walk, and a full battle all fit inside it), BATTLECHECK_STAGGER
# (default 3 s between instance launches).
set -eu

HERE="$(cd "$(dirname "$0")/.." && pwd)"   # dos_port/
cd "$HERE"

# --kill (link-cable plan Stage 4 step 3, mirroring tradecheck.sh's Stage 3
# step 6): kill instance B mid-battle and assert that A ESCAPES instead of
# hanging — LinkBattleExchangeData's .linkDown hatch (src/engine/battle/
# core.asm, step 2's DEVIATION) synthesizes a LINKBATTLE_RUN nybble the
# instant NetHAL_LinkAlive reports the session dead inside .syncLoop1, which
# drives EnemyRan and ends the battle for good instead of spinning forever.
# Kill-mode assertions (python, mode 'kill'): A's GBSTATE.BIN exists at all
# (the dump fired at AUTOKEY_DUMP_FRAME => the game loop was still alive, not
# hung in .syncLoop1 — THE point), bcMarks.link_down_hatch == 1 (the hatch
# fired), bcMarks.battle_over == 1 (the synthesized peer-ran ended the battle
# through the normal EndOfBattle link-battle branch), netLinkUp == 0 (session
# down), desyncs == 0. B's artifacts are not asserted (it was SIGKILLed).
MODE=full
if [ "${1:-}" = "--kill" ]; then
    MODE=kill
    shift
fi

OUT="${1:-${TMPDIR:-/tmp}/battlecheck.$$}"
mkdir -p "$OUT/a" "$OUT/b"

PORT="${BATTLECHECK_PORT:-23458}"
DUMP_FRAME="${BATTLECHECK_DUMP_FRAME:-20000}"
RUN_TIMEOUT="${RUN_TIMEOUT:-420}"
STAGGER="${BATTLECHECK_STAGGER:-3}"
# --kill only: seconds after B's launch before it is SIGKILLed. Default aims
# mid-battle (after establishment + the walk + at least one full turn, well
# before the battle would naturally end) — UNVALIDATED until the end-of-plan
# dynamic battery runs; tune there alongside DUMP_FRAME. 90, not tradecheck's
# 60: the walk into a battle table plus the battle's own turn-1 setup
# (versus text, HUD draw) takes longer than trade's walk-plus-first-menu.
KILL_AFTER="${BATTLECHECK_KILL_AFTER:-90}"

DOSBOX="$HERE/tools/dosbox-x-mcp/dosbox-x-mcp"
if [ ! -x "$DOSBOX" ]; then
    echo "battlecheck: $DOSBOX missing — the system dosbox-x has no C_MODEM" >&2
    echo "battlecheck: build it with tools/build_dosbox_mcp.sh" >&2
    exit 2
fi

SCRATCH="${TMPDIR:-/tmp}/battlecheck.scratch.$$"
mkdir -p "$SCRATCH/a" "$SCRATCH/b"
trap 'rm -rf "$SCRATCH"' EXIT

echo "== battlecheck: make image DEBUG_BATTLECHECK=1 AUTOKEY_DUMP_FRAME=$DUMP_FRAME" >&2
make image DEBUG_BATTLECHECK=1 AUTOKEY_DUMP_FRAME="$DUMP_FRAME" \
    >"$SCRATCH/build.log" 2>&1 || {
    tail -20 "$SCRATCH/build.log"; echo "battlecheck: build failed" >&2; exit 2; }

# Per-instance image clones + stale-dump purge (run_headless.sh's F-11 rule:
# a file found after the run must be definitionally fresh). POKEMON.DSV too —
# a stale one from a prior run's boot-load would seed a different party than
# this run's debug seed, which could change turn count / battle outcome for
# the wrong reason.
for side in a b; do
    cp PKMN.IMG "$SCRATCH/$side/pkmn.img"
    for f in GBSTATE.BIN DUMP.BIN FRAME.BIN PAL.BIN LINKLOG.BIN POKEMON.DSV; do
        mdel -i "$SCRATCH/$side/pkmn.img@@1048576" "::$f" 2>/dev/null || true
    done
done

# Derive the two confs from the tracked one: per-instance image, /COM1
# /LINKLOG on both (assertion 5), /PARTYB on B ONLY (boot/entry.asm; selects
# DebugNewGamePartyB + the BLUE/otid-66 identity in debug_party.asm — not
# load-bearing for this harness's assertions the way it is for tradecheck's
# swap check, but kept for parity with linkcheck/tradecheck's instance shape
# and so a future assertion can distinguish the sides' parties if needed).
# Exit after the game, and a [serial] section the tracked conf deliberately
# does not carry. Instance A is the nullmodem TCP server (no server:
# parameter — it listens); B connects to it. transparent:1 is required for
# raw bytes (without it the link speaks telnet escaping).
sed "s|^imgmount c PKMN.IMG|imgmount c $SCRATCH/a/pkmn.img|; s|^PKMN.EXE\$|PKMN.EXE /COM1 /LINKLOG\nexit|" \
    dosbox-x.conf >"$SCRATCH/a/run.conf"
printf '\n[serial]\nserial1=nullmodem port:%s transparent:1\n' "$PORT" >>"$SCRATCH/a/run.conf"

sed "s|^imgmount c PKMN.IMG|imgmount c $SCRATCH/b/pkmn.img|; s|^PKMN.EXE\$|PKMN.EXE /COM1 /LINKLOG /PARTYB\nexit|" \
    dosbox-x.conf >"$SCRATCH/b/run.conf"
printf '\n[serial]\nserial1=nullmodem server:localhost port:%s transparent:1\n' "$PORT" >>"$SCRATCH/b/run.conf"

echo "== battlecheck: instance A (server) up, B follows after ${STAGGER}s (timeout ${RUN_TIMEOUT}s each)" >&2
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy timeout -s KILL "$RUN_TIMEOUT" \
    "$DOSBOX" -defaultdir "$HERE" -defaultconf -conf "$SCRATCH/a/run.conf" \
    >"$SCRATCH/a/dosbox.log" 2>&1 &
PID_A=$!
sleep "$STAGGER"
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy timeout -s KILL "$RUN_TIMEOUT" \
    "$DOSBOX" -defaultdir "$HERE" -defaultconf -conf "$SCRATCH/b/run.conf" \
    >"$SCRATCH/b/dosbox.log" 2>&1 &
PID_B=$!
if [ "$MODE" = kill ]; then
    echo "== battlecheck --kill: SIGKILL instance B ${KILL_AFTER}s after its launch" >&2
    sleep "$KILL_AFTER"
    kill -9 "$PID_B" 2>/dev/null || true
fi
wait "$PID_A" || true
wait "$PID_B" || true

got=0
for side in a b; do
    for f in GBSTATE.BIN FRAME.BIN PAL.BIN LINKLOG.BIN DUMP.BIN POKEMON.DSV; do
        if mcopy -n -i "$SCRATCH/$side/pkmn.img@@1048576" "::$f" "$OUT/$side/" 2>/dev/null; then
            got=$((got + 1))
        fi
    done
    cp "$SCRATCH/$side/dosbox.log" "$OUT/$side/dosbox.log"
done
if [ ! -f "$OUT/a/GBSTATE.BIN" ]; then
    # In BOTH modes A's dump is the non-negotiable artifact: in --kill mode a
    # missing dump IS the hang the hatch exists to prevent.
    echo "battlecheck: missing A GBSTATE.BIN — the run died (or, in --kill mode, HUNG) before its dump" >&2
    for side in a b; do
        echo "--- $side dosbox.log tail ---" >&2
        tail -10 "$OUT/$side/dosbox.log" >&2
    done
    exit 2
fi
if [ "$MODE" = full ] && [ ! -f "$OUT/b/GBSTATE.BIN" ]; then
    echo "battlecheck: missing B GBSTATE.BIN — the run died before its dump" >&2
    tail -10 "$OUT/b/dosbox.log" >&2
    exit 2
fi
echo "== battlecheck: extracted $got files -> $OUT" >&2

rc=0
python3 - "$OUT" "$MODE" <<'PYEOF' || rc=$?
import struct, sys

out = sys.argv[1]
mode = sys.argv[2] if len(sys.argv) > 2 else 'full'
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


# --- --kill mode (Stage 4 step 3, mirroring tradecheck.sh's Stage 3 step 6):
# only A's dump is asserted. The dump's existence alone already proves the
# main claim (the game loop reached AUTOKEY_DUMP_FRAME instead of hanging in
# .syncLoop1); the bytes prove it escaped through the intended path.
if mode == 'kill':
    r = gbstate(f'{out}/a/GBSTATE.BIN')
    marks = r['bcMarks']
    battle_over = marks[1]
    hatch = marks[4]              # battlecheck_link_down_hatch — sticky
    up = r['netLinkUp'][0]
    desyncs = struct.unpack('<H', r['netDesyncs'])[0]
    print(f"  a: link_down_hatch={hatch} battle_over={battle_over} netLinkUp={up} desyncs={desyncs}")
    if hatch != 1:
        fails.append(f"a: link_down_hatch={hatch} (want 1 — "
                     "LinkBattleExchangeData's .linkDown hatch never fired)")
    if battle_over != 1:
        fails.append(f"a: battle_over={battle_over} (want 1 — the synthesized "
                     "peer-ran nybble never reached EndOfBattle's link-battle branch)")
    if up != 0:
        fails.append(f"a: netLinkUp={up} (want 0 — the session should be dead after the peer kill)")
    if desyncs != 0:
        fails.append(f"a: {desyncs} exch_id desyncs recorded on the way down (want a clean death)")
    if fails:
        print('battlecheck --kill: FAIL')
        for f in fails:
            print(f'  - {f}')
        sys.exit(1)
    print('battlecheck --kill: PASS (A escaped .syncLoop1 via the .linkDown hatch, no hang, no desyncs)')
    sys.exit(0)

sides = {}
for s in ('a', 'b'):
    r = gbstate(f'{out}/{s}/GBSTATE.BIN')
    marks = r['bcMarks']
    d = dict(
        status=r['linkStatus'][0], link_state=r['wLinkState'][0],
        net_up=r['netLinkUp'][0], net_state=r['netState'][0],
        desyncs=struct.unpack('<H', r['netDesyncs'])[0],
        exch_ctr=struct.unpack('<H', r['netExchCtr'])[0],
        battle_started=marks[0], battle_over=marks[1],
        turn_count=struct.unpack('<H', marks[2:4])[0],
        link_down_hatch=marks[4], battle_result=marks[5],
    )
    try:
        d['log'] = linklog(f'{out}/{s}/LINKLOG.BIN')
    except FileNotFoundError:
        d['log'] = None
        fails.append(f'{s}: LINKLOG.BIN missing')
    sides[s] = d

a, b = sides['a'], sides['b']
for s, d in sides.items():
    print(f"  {s}: hSerialConnectionStatus=${d['status']:02x} wLinkState=${d['link_state']:02x} "
          f"netLinkUp={d['net_up']} netState={d['net_state']} desyncs={d['desyncs']} "
          f"exchCtr={d['exch_ctr']} battle_started={d['battle_started']} "
          f"battle_over={d['battle_over']} turn_count={d['turn_count']} "
          f"battle_result={d['battle_result']} link_down_hatch={d['link_down_hatch']}")

# 1. role split + session health
if sorted((a['status'], b['status'])) != [1, 2]:
    fails.append(f"role split wrong: statuses ${a['status']:02x}/${b['status']:02x} (want $01+$02)")
for s, d in sides.items():
    if d['net_up'] != 1:
        fails.append(f"{s}: netLinkUp={d['net_up']} (session not alive at dump)")
    if d['net_state'] != 3:                     # NS_ESTABLISHED
        fails.append(f"{s}: netState={d['net_state']} (want 3 = NS_ESTABLISHED)")
    if d['desyncs'] != 0:
        fails.append(f"{s}: {d['desyncs']} exch_id desyncs")

# 2. both harness marks set on both sides
for s, d in sides.items():
    if d['battle_started'] != 1:
        fails.append(f"{s}: battle_started={d['battle_started']} (the link battle never started)")
    if d['battle_over'] != 1:
        fails.append(f"{s}: battle_over={d['battle_over']} (the link battle never reached EndOfBattle)")

# 3. LOCKSTEP: turn_count equal on both sides and >= 1 — the core assertion.
if a['turn_count'] < 1:
    fails.append(f"a: turn_count={a['turn_count']} (want >= 1 — no turn was ever exchanged)")
if b['turn_count'] < 1:
    fails.append(f"b: turn_count={b['turn_count']} (want >= 1 — no turn was ever exchanged)")
if a['turn_count'] != b['turn_count']:
    fails.append(f"turn_count mismatch: a={a['turn_count']} b={b['turn_count']} "
                 "(the two sides disagree on how many turns the battle took)")
elif a['turn_count'] >= 1:
    print(f"  lockstep: turn_count={a['turn_count']} on both sides")

# 4. CONSISTENT RESULT: battle_result complementary across the two instances.
# core.asm's EndOfBattle: 0=win, 1=lose, 2=draw, each from the acting side's
# own point of view.
RESULT_NAME = {0: 'WIN', 1: 'LOSE', 2: 'DRAW'}
ra, rb = a['battle_result'], b['battle_result']
ra_name = RESULT_NAME.get(ra, f'?{ra}')
rb_name = RESULT_NAME.get(rb, f'?{rb}')
consistent = (
    (ra == 0 and rb == 1) or (ra == 1 and rb == 0) or  # one WIN, one LOSE
    (ra == 2 and rb == 2)                              # both DRAW
)
if not consistent:
    fails.append(f"battle_result not complementary: a={ra_name}({ra}) b={rb_name}({rb}) "
                 "(want A-WIN/B-LOSE, A-LOSE/B-WIN, or both DRAW)")
else:
    print(f"  battle_result consistent: a={ra_name} b={rb_name}")

# 5. LINKLOG cross-check both directions (linkcheck.sh's/tradecheck.sh's
# parser, reused verbatim).
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
    print('battlecheck: FAIL')
    for f in fails:
        print(f'  - {f}')
    sys.exit(1)
print('battlecheck: PASS')
PYEOF
echo "$OUT"
exit $rc
