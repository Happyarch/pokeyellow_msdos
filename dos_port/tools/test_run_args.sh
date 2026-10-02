#!/usr/bin/env bash
# test_run_args.sh — pin dos_port/run's (and run-mcp's) argument routing.
#
# check_run_parity.sh proves the launchers emit the right DEVICE conf; this
# proves they route every TOKEN to the right consumer. Three namespaces:
#   /FLAG         -> PKMN.EXE inside DOS (conf autoexec line)
#   -FLAG --FLAG  -> DOSBox-X itself (after -conf)
#   NAME=value    -> make
# plus --help / --dry-run / -- and the greedy host-value rule.
#
# Everything runs against stub `make` / `dosbox-x` on PATH plus --dry-run, so
# this never builds, never launches an emulator, and finishes in seconds. The
# run-mcp half is skipped gracefully when the fork binary is absent.
set -euo pipefail

DOSPORT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DOSPORT"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/fakebin" "$TMP/logs" "$TMP/cap"

# --- stubs -------------------------------------------------------------------
cat > "$TMP/fakebin/make" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >> "$TMP/logs/make_argv"
exit 0
EOF
cat > "$TMP/fakebin/dosbox-x" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >> "$TMP/logs/dosbox_argv"
while [ \$# -gt 0 ]; do
  case "\$1" in
    -conf) cp "\$2" "$TMP/logs/conf.bin"; break ;;
  esac
  shift
done
exit 0
EOF
chmod +x "$TMP/fakebin/make" "$TMP/fakebin/dosbox-x"
export PATH="$TMP/fakebin:$PATH"
# Belt and braces: even the non-dry paths below can only ever exec the stub.
# (Without this, the /PAS and run-mcp cases would launch the REAL emulator at
# the LIVE image — observed 2026-10-01: a hung fork held PKMN.IMG open.)
export RUN_EMULATOR="$TMP/fakebin/dosbox-x"
export DOSBOX_MCP_LAUNCH="$TMP/launch" DOSBOX_MCP_CAPTURE_DIR="$TMP/cap"

reset_logs() { rm -f "$TMP/logs/make_argv" "$TMP/logs/dosbox_argv" "$TMP/logs/conf.bin" "$TMP/launch"; }

pass=0; fail=0
ok()   { pass=$((pass + 1)); echo "  ok   $1"; }
bad()  { fail=$((fail + 1)); echo "  FAIL $1"; }

# run_case NAME -- <launcher-args...> == EXPECT_MAKE / EXPECT_DOS / EXPECT_CONF / EXPECT_OUT
# Minimal assertion DSL over the three consumers plus stdout/exit of --dry-run.
have() { # have FILE LITERAL
    grep -qF -- "$2" "$1" 2>/dev/null
}

LAUNCHER=./run
case_run() { # case_run NAME [args...]
    local name="$1"; shift
    reset_logs
    "$LAUNCHER" "$@" >/dev/null 2>&1
}

echo "== dos_port/run routing =="

# 1. base, no args: make gets bare `image`, conf EXE line bare
case_run base
have "$TMP/logs/make_argv" "image" && ! grep -q "SKIP" "$TMP/logs/make_argv" \
    && have "$TMP/logs/dosbox_argv" "-defaultconf" \
    && grep -q '^PKMN\.EXE$' "$TMP/logs/conf.bin" \
    && ok "base: bare make image, bare PKMN.EXE" \
    || bad "base: bare make image, bare PKMN.EXE"

# 2. make var + DOS flag split
case_run split SKIP_TITLE=1 /LOOP
have "$TMP/logs/make_argv" "SKIP_TITLE=1" && ! have "$TMP/logs/make_argv" "/LOOP" \
    && have "$TMP/logs/conf.bin" "PKMN.EXE /LOOP" \
    && ! have "$TMP/logs/dosbox_argv" "/LOOP" \
    && ok "split: SKIP_TITLE=1->make, /LOOP->DOS" \
    || bad "split: SKIP_TITLE=1->make, /LOOP->DOS"

# 3. device rows: snippet line present + device flag on the EXE line
declare -A SNIP=( [MT32]="mididevice  = mt32" [GB]="sbtype  = gb"
  [COVOX]="disney = true" [IMFC]="imfc_base   = 2a20" [INNOVA]="sidbase    = 280"
  [SPK]="sbtype  = none" [TANDY]="tandy = on" [PAS]="sbtype  = pas16" )
for d in MT32 GB COVOX IMFC INNOVA SPK TANDY PAS; do
    case_run "dev-$d" "/$d"
    if have "$TMP/logs/conf.bin" "${SNIP[$d]}" \
       && { [ "$d" = SPK ] && grep -q '^PKMN\.EXE$' "$TMP/logs/conf.bin" \
            || have "$TMP/logs/conf.bin" "PKMN.EXE /$d"; }; then
        ok "device /$d: snippet + EXE line"
    else
        bad "device /$d: snippet + EXE line"
    fi
done
# /PAS must resolve the fork binary (asserted via --dry-run with the test
# override lifted, so the real resolution runs; dry-run never launches).
out="$(RUN_EMULATOR= ./run --dry-run /PAS 2>&1)"
if echo "$out" | grep -q "$(bash tools/fork_binary.sh 2>/dev/null || echo '<fork-not-found>')" \
   || echo "$out" | grep -q "<fork-not-found>"; then
    ok "device /PAS: resolves the fork binary"
else
    bad "device /PAS: resolves the fork binary"
fi
# SPK_ONLY knob
SPK_ONLY=1 ./run /SPK >/dev/null 2>&1
have "$TMP/logs/conf.bin" "oplmode = none" \
    && ok "SPK_ONLY=1 -> oplmode none" \
    || bad "SPK_ONLY=1 -> oplmode none"

# 4. regression: old run-gb dropped user /EXE flags (double CONF block)
case_run gb-keeps-flags /GB /LOOP
have "$TMP/logs/conf.bin" "PKMN.EXE /GB /LOOP" \
    && ok "/GB /LOOP both reach the EXE line" \
    || bad "/GB /LOOP both reach the EXE line"

# 5. two devices is an error, and nothing launches
reset_logs
if ./run /GB /MT32 >/dev/null 2>&1; then
    bad "two devices must fail"
else
    [ ! -e "$TMP/logs/dosbox_argv" ] \
        && ok "two devices fail before launch" \
        || bad "two devices launched anyway"
fi

# 6. host flags go to dosbox-x, after -conf
case_run host -fullscreen /LOOP
if have "$TMP/logs/dosbox_argv" "-fullscreen" \
   && awk '/-conf/{found=1} /-fullscreen/{if(found) ok=1} END{exit !ok}' "$TMP/logs/dosbox_argv" \
   && have "$TMP/logs/conf.bin" "PKMN.EXE /LOOP" \
   && ! have "$TMP/logs/make_argv" "-fullscreen"; then
    ok "-fullscreen->host after -conf; /LOOP->DOS"
else
    bad "-fullscreen->host after -conf; /LOOP->DOS"
fi

# 7. host value consumption: `-c "mount c ."` keeps its value off make
case_run hostval -c "mount c ." SKIP_TITLE=1
have "$TMP/logs/dosbox_argv" "mount c ." \
    && have "$TMP/logs/make_argv" "SKIP_TITLE=1" \
    && ! have "$TMP/logs/make_argv" "mount" \
    && ok "-c value stays on the host side" \
    || bad "-c value stays on the host side"

# 8. `--` sends everything after it to make verbatim
case_run sep SKIP_TITLE=1 -- /LOOP -x
have "$TMP/logs/make_argv" "/LOOP" && have "$TMP/logs/make_argv" "-x" \
    && grep -q '^PKMN\.EXE$' "$TMP/logs/conf.bin" \
    && ! have "$TMP/logs/dosbox_argv" "-x" \
    && ok "-- forces make-verbatim" \
    || bad "-- forces make-verbatim"

# 9. -h is the emulator's (forwarded); --help is ours
case_run dash-h -h
have "$TMP/logs/dosbox_argv" "-h" \
    && ok "-h forwarded to dosbox-x" \
    || bad "-h forwarded to dosbox-x"
./run --help 2>/dev/null | grep -q "/MT32" \
    && ok "--help lists devices" \
    || bad "--help lists devices"

# 10. --dry-run prints and launches nothing
reset_logs
out="$(./run --dry-run /GB /LOOP 2>&1)"
echo "$out" | grep -q "PKMN.EXE /GB /LOOP" \
    && [ ! -e "$TMP/logs/make_argv" ] && [ ! -e "$TMP/logs/dosbox_argv" ] \
    && ok "--dry-run prints, launches nothing" \
    || bad "--dry-run prints, launches nothing"

# 11. MT32 without ROMs fails before launch
reset_logs
if MT32_ROMDIR="$TMP/empty-roms" ./run /MT32 >/dev/null 2>&1; then
    bad "missing MT32 ROMs must fail"
else
    [ ! -e "$TMP/logs/dosbox_argv" ] \
        && ok "missing MT32 ROMs fail before launch" \
        || bad "missing MT32 ROMs launched anyway"
fi

echo "== dos_port/run-mcp routing =="
if bash tools/fork_binary.sh >/dev/null 2>&1; then
    LAUNCHER=./run-mcp
    # base: MCP socket + captures in conf, handshake records this checkout.
    # (The emulator here is the stub via RUN_EMULATOR; fork resolution itself
    # is covered by the /PAS case above.)
    case_run mcp-base /GB /LOOP
    have "$TMP/logs/conf.bin" "mcp_socket=" \
        && have "$TMP/logs/conf.bin" "PKMN.EXE /GB /LOOP" \
        && [ -f "$TMP/launch" ] && have "$TMP/launch" "DOSPORT=$DOSPORT" \
        && ok "run-mcp: socket+captures+handshake" \
        || bad "run-mcp: socket+captures+handshake"
    # --dry-run writes no handshake
    reset_logs
    ./run-mcp --dry-run /GB >/dev/null 2>&1
    [ ! -e "$TMP/launch" ] \
        && ok "run-mcp --dry-run writes no handshake" \
        || bad "run-mcp --dry-run writes no handshake"
else
    echo "  skip run-mcp half (no fork binary built)"
fi

echo
if [ "$fail" -eq 0 ]; then
    echo "test_run_args: PASS ($pass)"
else
    echo "test_run_args: FAIL ($fail of $((pass + fail)))"
    exit 1
fi
