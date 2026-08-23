#!/bin/sh
# tradecheck.sh — two-instance null-modem link-TRADE harness (link-cable plan,
# Stage 3 step 5). Fork of linkcheck.sh: builds one DEBUG_TRADECHECK image,
# boots it in TWO DOSBox-X instances joined by an emulated null-modem cable,
# drives a REAL two-round link trade session (round 1: both sides offer party
# slot 0 and confirm; round 2: both sides navigate to CANCEL and confirm), and
# asserts the .dsv/GBSTATE postconditions:
#
#   1. establishment: hSerialConnectionStatus is $02 (USING_INTERNAL_CLOCK,
#      the master) on exactly one side and $01 on the other; netState is
#      NS_ESTABLISHED (3) and netDesyncs is 0 on both.
#   2. both harness marks (tcMarks: round1_traded, round2_cancelled) are set
#      on BOTH sides — the trade actually completed and the mutual-CANCEL
#      handshake actually returned to the club room.
#   3. THE SWAP: after the trade, RemovePokemon shifts the traded-away slot 0
#      up and AddEnemyMonToPlayerParty APPENDS the received mon at the new
#      LAST slot (src/engine/pokemon/remove_mon.asm's shift-up removal +
#      src/engine/pokemon/add_mon.asm:_AddEnemyMonToPlayerParty) — NOT back
#      into slot 0, and NOT still present anywhere in the SENDER's own final
#      party either (its own slot 0 left FOR GOOD; the shift-up means the
#      sender's own post-trade dump has nothing at slot 0 to compare against).
#      So the reference for "what was sent" is a SEPARATE, EARLIER dump:
#      DumpGBStateSeed (debug_dump.asm, AUTOKEY_TRADECHECK gate) fires once
#      per side into GBSEED.BIN the first frame each side is parked at its
#      table (wCurMap==TRADE_CENTER && wLinkState==LINK_STATE_IN_CABLE_CLUB),
#      before either side's slot-0 mon has been touched. Assert: A's FINAL
#      party[5] (last slot) == B's SEED party[0] struct byte-for-byte, all 44
#      bytes including offset 7 (MON_CATCH_RATE / the Gen-2 held-item carry
#      byte), and vice versa for B's final party[5] vs A's seed party[0].
#      Party counts stay 6/6. OT name of the received mon must equal the
#      peer's player name ("RED" / "BLUE"); nickname must equal the peer's
#      SEED nickname for that mon (pret copies wEnemyMonNicks verbatim in
#      _AddEnemyMonToPlayerParty — it does NOT reset to the species default,
#      and the nickname array shifts out of the sender's OWN final party the
#      same way the struct does, so its reference is the seed dump too).
#   4. .dsv: extract sPartyData (flat 0x22F2C, size 0x194 — dsv_io.asm's
#      GB_SRAM_BANK1-relative offset within the "banks 1-3" payload region)
#      from both POKEMON.DSV and assert it matches the corresponding GBSTATE
#      wPartyData region byte-for-byte (the SramStoreImage commit landed).
#   5. LINKLOG cross-check both directions (linkcheck.sh's parser, reused
#      verbatim — /LINKLOG is armed on both sides for this).
#
# The in-game driver is RunTradeCheck (src/engine/link/cable_club_npc.asm): it
# loops the REAL CableClubNPC exactly like RunLinkCheck until the two
# instances' establishment races overlap, then — UNLIKE linkcheck — lets
# AUTOKEY_TRADECHECK's A train press through LinkMenu's default TRADE CENTER
# selection instead of stopping there, drives the one-tile walk to the role's
# table gameboy, and drives both trade rounds via live-WRAM-gated key
# injection (debug_dump.asm AutoKeyDrive's AUTOKEY_TRADECHECK block).
#
# REQUIRES the nullmodem-capable DOSBox-X fork binary, same as linkcheck.sh:
# tools/dosbox-x-mcp/dosbox-x-mcp (tools/build_dosbox_mcp.sh).
#
#   tools/tradecheck.sh [outdir]
#
# Env overrides: TRADECHECK_PORT (default 23457 — DIFFERENT from linkcheck's
# 23456 so both harnesses can coexist), TRADECHECK_DUMP_FRAME (default 14000 —
# the Makefile gate's default; the trade animation plus two full menu rounds
# is long), RUN_TIMEOUT (default 300 s per instance — generous: the rendezvous
# retry loop, the walk, the trade animation, and two rounds all fit inside
# it), TRADECHECK_STAGGER (default 3 s between instance launches).
set -eu

HERE="$(cd "$(dirname "$0")/.." && pwd)"   # dos_port/
cd "$HERE"

# --kill (link-cable plan Stage 3 step 6): kill instance B mid-session and
# assert that A ESCAPES instead of hanging — the cable_club_link_down hatch
# (src/engine/link/cable_club.asm) routes the dead session through pret's own
# index-$ff path to DisplayTitleScreen. Kill-mode assertions (python, mode
# 'kill'): A's GBSTATE.BIN exists at all (the dump fired at AUTOKEY_DUMP_FRAME
# => the game loop was still alive, not hung in a wait), tcPointerIdx == $ff
# (the hatch fired), netLinkUp == 0 (session down), desyncs == 0. B's
# artifacts are not asserted (it was SIGKILLed).
MODE=full
if [ "${1:-}" = "--kill" ]; then
    MODE=kill
    shift
fi

OUT="${1:-${TMPDIR:-/tmp}/tradecheck.$$}"
mkdir -p "$OUT/a" "$OUT/b"

PORT="${TRADECHECK_PORT:-23457}"
DUMP_FRAME="${TRADECHECK_DUMP_FRAME:-14000}"
RUN_TIMEOUT="${RUN_TIMEOUT:-300}"
STAGGER="${TRADECHECK_STAGGER:-3}"
# --kill only: seconds after B's launch before it is SIGKILLed. Default aims
# mid-first-SelectMon (after establishment + the walk, before round 1
# completes) — UNVALIDATED until the end-of-plan dynamic battery runs; tune
# there alongside DUMP_FRAME.
KILL_AFTER="${TRADECHECK_KILL_AFTER:-60}"

DOSBOX="$HERE/tools/dosbox-x-mcp/dosbox-x-mcp"
if [ ! -x "$DOSBOX" ]; then
    echo "tradecheck: $DOSBOX missing — the system dosbox-x has no C_MODEM" >&2
    echo "tradecheck: build it with tools/build_dosbox_mcp.sh" >&2
    exit 2
fi

SCRATCH="${TMPDIR:-/tmp}/tradecheck.scratch.$$"
mkdir -p "$SCRATCH/a" "$SCRATCH/b"
trap 'rm -rf "$SCRATCH"' EXIT

echo "== tradecheck: make image DEBUG_TRADECHECK=1 AUTOKEY_DUMP_FRAME=$DUMP_FRAME" >&2
make image DEBUG_TRADECHECK=1 AUTOKEY_DUMP_FRAME="$DUMP_FRAME" \
    >"$SCRATCH/build.log" 2>&1 || {
    tail -20 "$SCRATCH/build.log"; echo "tradecheck: build failed" >&2; exit 2; }

# Per-instance image clones + stale-dump purge (run_headless.sh's F-11 rule:
# a file found after the run must be definitionally fresh). POKEMON.DSV too —
# a stale one from a prior run's boot-load would make assertion 4 pass for
# the wrong reason.
for side in a b; do
    cp PKMN.IMG "$SCRATCH/$side/pkmn.img"
    for f in GBSTATE.BIN GBSEED.BIN DUMP.BIN FRAME.BIN PAL.BIN LINKLOG.BIN POKEMON.DSV; do
        mdel -i "$SCRATCH/$side/pkmn.img@@1048576" "::$f" 2>/dev/null || true
    done
done

# Derive the two confs from the tracked one: per-instance image, /COM1
# /LINKLOG on both (assertion 5), /PARTYB on B ONLY (boot/entry.asm; selects
# DebugNewGamePartyB + the BLUE/otid-66 identity in debug_party.asm, so every
# asserted byte differs between the sides and a swap is unambiguous). Exit
# after the game, and a [serial] section the tracked conf deliberately does
# not carry. Instance A is the nullmodem TCP server (no server: parameter —
# it listens); B connects to it. transparent:1 is required for raw bytes
# (without it the link speaks telnet escaping).
sed "s|^imgmount c PKMN.IMG|imgmount c $SCRATCH/a/pkmn.img|; s|^PKMN.EXE\$|PKMN.EXE /COM1 /LINKLOG\nexit|" \
    dosbox-x.conf >"$SCRATCH/a/run.conf"
printf '\n[serial]\nserial1=nullmodem port:%s transparent:1\n' "$PORT" >>"$SCRATCH/a/run.conf"

sed "s|^imgmount c PKMN.IMG|imgmount c $SCRATCH/b/pkmn.img|; s|^PKMN.EXE\$|PKMN.EXE /COM1 /LINKLOG /PARTYB\nexit|" \
    dosbox-x.conf >"$SCRATCH/b/run.conf"
printf '\n[serial]\nserial1=nullmodem server:localhost port:%s transparent:1\n' "$PORT" >>"$SCRATCH/b/run.conf"

echo "== tradecheck: instance A (server) up, B follows after ${STAGGER}s (timeout ${RUN_TIMEOUT}s each)" >&2
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
    echo "== tradecheck --kill: SIGKILL instance B ${KILL_AFTER}s after its launch" >&2
    sleep "$KILL_AFTER"
    kill -9 "$PID_B" 2>/dev/null || true
fi
wait "$PID_A" || true
wait "$PID_B" || true

got=0
for side in a b; do
    for f in GBSTATE.BIN GBSEED.BIN FRAME.BIN PAL.BIN LINKLOG.BIN DUMP.BIN POKEMON.DSV; do
        if mcopy -n -i "$SCRATCH/$side/pkmn.img@@1048576" "::$f" "$OUT/$side/" 2>/dev/null; then
            got=$((got + 1))
        fi
    done
    cp "$SCRATCH/$side/dosbox.log" "$OUT/$side/dosbox.log"
done
if [ ! -f "$OUT/a/GBSTATE.BIN" ]; then
    # In BOTH modes A's dump is the non-negotiable artifact: in --kill mode a
    # missing dump IS the hang the hatch exists to prevent.
    echo "tradecheck: missing A GBSTATE.BIN — the run died (or, in --kill mode, HUNG) before its dump" >&2
    for side in a b; do
        echo "--- $side dosbox.log tail ---" >&2
        tail -10 "$OUT/$side/dosbox.log" >&2
    done
    exit 2
fi
if [ "$MODE" = full ] && [ ! -f "$OUT/b/GBSTATE.BIN" ]; then
    echo "tradecheck: missing B GBSTATE.BIN — the run died before its dump" >&2
    tail -10 "$OUT/b/dosbox.log" >&2
    exit 2
fi
if [ "$MODE" = full ]; then
    if [ ! -f "$OUT/a/GBSEED.BIN" ] || [ ! -f "$OUT/b/GBSEED.BIN" ]; then
        echo "tradecheck: missing GBSEED.BIN — a side never reached its table (DumpGBStateSeed never fired), assertion 3 cannot run" >&2
    fi
    if [ ! -f "$OUT/a/POKEMON.DSV" ] || [ ! -f "$OUT/b/POKEMON.DSV" ]; then
        echo "tradecheck: missing POKEMON.DSV — SramStoreImage never committed (or the trade never completed)" >&2
    fi
fi
echo "== tradecheck: extracted $got files -> $OUT" >&2

rc=0
python3 - "$OUT" "$MODE" <<'PYEOF' || rc=$?
import struct, sys

out = sys.argv[1]
mode = sys.argv[2] if len(sys.argv) > 2 else 'full'
fails = []

# --- .dsv v2 layout (src/save/dsv_io.asm) ---
DSV_HEADER = 7                       # "DOSV" + version(1) + checksum(2 LE)
DSV_BANK0_SIZE = 0x2000              # GB_SRAM_BANK_SIZE — bank 0 goes first
SPARTY_GB_ADDR = 0x22F2C             # sPartyData (include/gb_memmap.inc)
SPARTY_BANK1_BASE = 0x22000          # GB_SRAM_BANK1 — banks 1-3 follow bank 0
SPARTY_SIZE = 0x194                  # 404 bytes: count+species+6 structs+6 OT+6 nicks
DSV_PARTY_OFFSET = DSV_HEADER + DSV_BANK0_SIZE + (SPARTY_GB_ADDR - SPARTY_BANK1_BASE)

# --- wPartyData region sub-layout (matches sPartyData's, same 404 bytes) ---
PARTY_LENGTH = 6
NAME_LENGTH = 11
PARTYMON_STRUCT_LENGTH = 0x2C        # 44
OFF_COUNT = 0
OFF_SPECIES = 1                      # 7 bytes: 6 species + $FF sentinel
OFF_MONS = OFF_SPECIES + (PARTY_LENGTH + 1)               # 8
OFF_OT = OFF_MONS + PARTY_LENGTH * PARTYMON_STRUCT_LENGTH  # 272
OFF_NICK = OFF_OT + PARTY_LENGTH * NAME_LENGTH             # 338
PARTY_TOTAL = OFF_NICK + PARTY_LENGTH * NAME_LENGTH        # 404
assert PARTY_TOTAL == SPARTY_SIZE, (PARTY_TOTAL, SPARTY_SIZE)


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


def dsv_party(path):
    data = open(path, 'rb').read()
    assert data[0:4] == b'DOSV', f'{path}: bad .dsv magic'
    return data[DSV_PARTY_OFFSET:DSV_PARTY_OFFSET + SPARTY_SIZE]


def parse_party(blob):
    assert len(blob) == PARTY_TOTAL, len(blob)
    count = blob[OFF_COUNT]
    mons = [blob[OFF_MONS + i * PARTYMON_STRUCT_LENGTH:OFF_MONS + (i + 1) * PARTYMON_STRUCT_LENGTH]
            for i in range(PARTY_LENGTH)]
    ots = [blob[OFF_OT + i * NAME_LENGTH:OFF_OT + (i + 1) * NAME_LENGTH] for i in range(PARTY_LENGTH)]
    nicks = [blob[OFF_NICK + i * NAME_LENGTH:OFF_NICK + (i + 1) * NAME_LENGTH] for i in range(PARTY_LENGTH)]
    return dict(count=count, mons=mons, ots=ots, nicks=nicks, raw=blob)


# --- --kill mode (Stage 3 step 6): only A's dump is asserted. The dump's
# existence alone already proves the main claim (the game loop reached
# AUTOKEY_DUMP_FRAME instead of hanging in a dead-link wait); the bytes prove
# it escaped through the intended path.
if mode == 'kill':
    r = gbstate(f'{out}/a/GBSTATE.BIN')
    idx = r['tcPointerIdx'][0]
    hatch = r['tcMarks'][6]              # tradecheck_link_down_hatch — sticky
    up = r['netLinkUp'][0]
    desyncs = struct.unpack('<H', r['netDesyncs'])[0]
    # tcPointerIdx is informational only: the hatch sets it to $ff, but A's
    # A-mash can start a NEW GAME after the title reset and its WRAM init may
    # legitimately rewrite it before the dump frame. The sticky flat-.bss
    # hatch mark is the assertion.
    print(f"  a: link_down_hatch={hatch} tcPointerIdx=${idx:02x} netLinkUp={up} desyncs={desyncs}")
    if hatch != 1:
        fails.append(f"a: link_down_hatch={hatch} (want 1 — "
                     "cable_club_link_down never routed the dead session to the title reset)")
    if up != 0:
        fails.append(f"a: netLinkUp={up} (want 0 — the session should be dead after the peer kill)")
    if desyncs != 0:
        fails.append(f"a: {desyncs} exch_id desyncs recorded on the way down (want a clean death)")
    if fails:
        print('tradecheck --kill: FAIL')
        for f in fails:
            print(f'  - {f}')
        sys.exit(1)
    print('tradecheck --kill: PASS (A escaped to the title reset, no hang, no desyncs)')
    sys.exit(0)

sides = {}
for s in ('a', 'b'):
    r = gbstate(f'{out}/{s}/GBSTATE.BIN')
    d = dict(
        status=r['linkStatus'][0], link_state=r['wLinkState'][0],
        net_up=r['netLinkUp'][0], net_state=r['netState'][0],
        desyncs=struct.unpack('<H', r['netDesyncs'])[0],
        exch_ctr=struct.unpack('<H', r['netExchCtr'])[0],
        round1_traded=r['tcMarks'][0], round2_cancelled=r['tcMarks'][1],
        steps_taken=struct.unpack('<I', r['tcMarks'][2:6])[0],
        player_name=r['wPlayerName'], player_id=r['wPlayerID'],
        party=parse_party(r['wPartyData']),
    )
    try:
        d['log'] = linklog(f'{out}/{s}/LINKLOG.BIN')
    except FileNotFoundError:
        d['log'] = None
        fails.append(f'{s}: LINKLOG.BIN missing')
    try:
        d['dsv_party'] = dsv_party(f'{out}/{s}/POKEMON.DSV')
    except FileNotFoundError:
        d['dsv_party'] = None
        fails.append(f'{s}: POKEMON.DSV missing')
    try:
        seed = gbstate(f'{out}/{s}/GBSEED.BIN')
        d['seed_party'] = parse_party(seed['wPartyData'])
        d['seed_player_name'] = seed['wPlayerName']
    except FileNotFoundError:
        d['seed_party'] = None
        d['seed_player_name'] = None
        fails.append(f'{s}: GBSEED.BIN missing')
    sides[s] = d

a, b = sides['a'], sides['b']
for s, d in sides.items():
    print(f"  {s}: hSerialConnectionStatus=${d['status']:02x} wLinkState=${d['link_state']:02x} "
          f"netLinkUp={d['net_up']} netState={d['net_state']} desyncs={d['desyncs']} "
          f"exchCtr={d['exch_ctr']} round1_traded={d['round1_traded']} "
          f"round2_cancelled={d['round2_cancelled']} steps_taken={d['steps_taken']} "
          f"partyCount={d['party']['count']} player={bytes(d['player_name']).hex()}")

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
    if d['round1_traded'] != 1:
        fails.append(f"{s}: round1_traded={d['round1_traded']} (round 1 trade never completed)")
    if d['round2_cancelled'] != 1:
        fails.append(f"{s}: round2_cancelled={d['round2_cancelled']} (round 2 mutual cancel never returned)")

# 3. THE SWAP. RemovePokemon shifts the traded-away slot 0 up and
# _AddEnemyMonToPlayerParty appends the received mon at the NEW LAST slot
# (remove_mon.asm's shift-up removal + add_mon.asm:413-464) — not back into
# slot 0. Both sides still show count 6 (one out, one in); the received mon
# is each side's party[5].
def name_str(raw):
    # cosmetic only (assertion messages) — not a charmap decode.
    return bytes(raw).hex()


for s, d in sides.items():
    if d['party']['count'] != PARTY_LENGTH:
        fails.append(f"{s}: final wPartyCount={d['party']['count']} (want {PARTY_LENGTH})")

RECV_SLOT = PARTY_LENGTH - 1  # 5 — the appended slot, per remove_mon.asm + add_mon.asm above

recv_a = a['party']['mons'][RECV_SLOT]
recv_b = b['party']['mons'][RECV_SLOT]
# "Sent" comes from each side's OWN pre-walk GBSEED.BIN slot 0, NOT the other
# side's post-trade party — a sender's own slot-0 mon leaves its own party for
# good (remove_mon.asm's shift-up), so the post-trade dump has nothing left
# there to compare against. See DumpGBStateSeed's header (debug_dump.asm) and
# the file header comment above.
sent_b = b['seed_party']['mons'][0] if b['seed_party'] is not None else None
sent_a = a['seed_party']['mons'][0] if a['seed_party'] is not None else None

if sent_b is not None and recv_a != sent_b:
    fails.append(f"A.party[{RECV_SLOT}] (received) != B.seed_party[0] (sent) — 44-byte verbatim swap failed "
                 f"(incl. offset 7 catch-rate/held-item): "
                 f"A={recv_a.hex()} B={sent_b.hex()}")
elif sent_b is not None:
    print(f"  A.party[{RECV_SLOT}] == B.seed_party[0]: 44 bytes verbatim (offset 7 incl.)")
if sent_a is not None and recv_b != sent_a:
    fails.append(f"B.party[{RECV_SLOT}] (received) != A.seed_party[0] (sent) — 44-byte verbatim swap failed "
                 f"(incl. offset 7 catch-rate/held-item): "
                 f"B={recv_b.hex()} A={sent_a.hex()}")
elif sent_a is not None:
    print(f"  B.party[{RECV_SLOT}] == A.seed_party[0]: 44 bytes verbatim (offset 7 incl.)")

# OT name of the received mon == peer's player name (padded to NAME_LENGTH,
# same '@'-terminated field both places); OTID is INSIDE the 44-byte struct
# (MON_OTID, already covered by the verbatim check above) — asserted again
# here directly against wPlayerID for a second, independent read.
if bytes(a['party']['ots'][RECV_SLOT]) != bytes(b['player_name']):
    fails.append(f"A's received mon OT name != B's wPlayerName: "
                 f"{name_str(a['party']['ots'][RECV_SLOT])} != {name_str(b['player_name'])}")
if bytes(b['party']['ots'][RECV_SLOT]) != bytes(a['player_name']):
    fails.append(f"B's received mon OT name != A's wPlayerName: "
                 f"{name_str(b['party']['ots'][RECV_SLOT])} != {name_str(a['player_name'])}")

MON_OTID_OFF = 0x0C
a_recv_otid = recv_a[MON_OTID_OFF:MON_OTID_OFF + 2]
b_player_id = bytes(b['player_id'])
if a_recv_otid != b_player_id:
    fails.append(f"A's received mon OTID != B's wPlayerID: {a_recv_otid.hex()} != {b_player_id.hex()}")
b_recv_otid = recv_b[MON_OTID_OFF:MON_OTID_OFF + 2]
a_player_id = bytes(a['player_id'])
if b_recv_otid != a_player_id:
    fails.append(f"B's received mon OTID != A's wPlayerID: {b_recv_otid.hex()} != {a_player_id.hex()}")

# Nickname carried through verbatim (_AddEnemyMonToPlayerParty copies
# wEnemyMonNicks, NOT the species default — add_mon.asm:454-464). Reference is
# the SEED dump's nickname, same reasoning as the struct swap above (the
# sender's own nickname array also shifts out from under slot 0 post-trade).
if b['seed_party'] is not None and bytes(a['party']['nicks'][RECV_SLOT]) != bytes(b['seed_party']['nicks'][0]):
    fails.append(f"A's received mon nickname != B's seed nickname for that slot: "
                 f"{name_str(a['party']['nicks'][RECV_SLOT])} != {name_str(b['seed_party']['nicks'][0])}")
if a['seed_party'] is not None and bytes(b['party']['nicks'][RECV_SLOT]) != bytes(a['seed_party']['nicks'][0]):
    fails.append(f"B's received mon nickname != A's seed nickname for that slot: "
                 f"{name_str(b['party']['nicks'][RECV_SLOT])} != {name_str(a['seed_party']['nicks'][0])}")

# 4. .dsv: sPartyData == the final GBSTATE wPartyData region (the
# SramStoreImage-after-SavePartyAndDexData commit landed on the trade path).
for s, d in sides.items():
    if d['dsv_party'] is None:
        continue
    if bytes(d['dsv_party']) != bytes(d['party']['raw']):
        fails.append(f"{s}: POKEMON.DSV sPartyData != final GBSTATE wPartyData")
    else:
        print(f"  {s}: POKEMON.DSV sPartyData == final GBSTATE wPartyData ({SPARTY_SIZE} bytes)")

# 5. LINKLOG cross-check both directions (linkcheck.sh's parser, reused).
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
    print('tradecheck: FAIL')
    for f in fails:
        print(f'  - {f}')
    sys.exit(1)
print('tradecheck: PASS')
PYEOF
echo "$OUT"
exit $rc
