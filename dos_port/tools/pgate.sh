#!/bin/zsh
# pgate — run golden scenarios in parallel against tmpfs shadow copies.
#
# Wall clock becomes ~= the SLOWEST SINGLE SCENARIO instead of the sum of all of
# them. Measured on this host (96 threads): the 17-scenario battery drops from
# ~20 min serial to the length of trainer_battle_route alone.
#
# WHY THIS IS SAFE
#   * goldencheck.sh has no external path dependencies — no `../`, no absolute
#     paths, no reference to the pret-golden worktree — and all 57 goldens are
#     committed under dos_port/tests/goldens, so a copy is self-contained.
#   * It invokes plain `dosbox-x` from PATH, NOT the tools/dosbox-x-mcp fork.
#   * DOSBox at `cycles=fixed 23880` emulates time rather than racing wall clock,
#     so a loaded host makes a run take longer in wall-clock but execute
#     IDENTICALLY. Parallelism cannot change results. The one way it could is
#     oversubscription pushing a run into goldencheck's `timeout -s KILL 600`;
#     dosbox-x is effectively single-threaded, so keep concurrency well under
#     nproc and that cannot bite.
#   * Each goldencheck already works on its own scratch copy of PKMN.IMG, so the
#     live-session image-contention trap does not apply.
#
# WHAT IS EXCLUDED FROM THE COPY, AND WHY IT IS SAFE
#   dos_port/tools/dosbox-x       499M  submodule SOURCE for the debugger fork
#   dos_port/tools/dosbox-x-mcp   619M  built fork binary (goldencheck uses PATH)
#   dos_port/tools/mgba{,_build}   76M  golden GENERATION only; goldencheck only
#                                       DIFFS against committed goldens
#   *.o, PKMN.EXE, PKMN.IMG             rebuilt per scenario anyway — every
#                                       scenario has distinct DEBUG_* flags, and
#                                       the .nasmflags stamp forces a full
#                                       rebuild regardless
# That takes the base from 1.1G to ~97M, so 17 copies cost ~1.6G instead of
# ~19G, and the full 57-scenario registry would cost only ~5.5G.
#
# ASSETS: deliberately INCLUDED and NOT regenerated. goldencheck runs `make
# image`, never `make assets`, so the generated assets/*.inc are inherited by
# every copy and `make assets` runs zero times instead of once per scenario.
#
# ⚠ ASSET-DRIFT CAVEAT: because assets are copied rather than regenerated, this
# harness tests whatever assets the SOURCE tree currently holds. If you changed a
# generator under tools/generators/, run `make -C dos_port assets` in the source
# tree BEFORE using this, or the gate silently validates stale data.
#
# CONCURRENCY IS BOUNDED (added 2026-08-12). The original fanned out EVERY
# scenario at once (`for sc in $SCENARIOS; do (...) & done; wait`). That was fine
# for the 17-scenario battery but is not for the full 66-scenario registry: each
# worker runs a complete `make image` (a multi-file nasm build) AND a dosbox-x,
# so 66 at once oversubscribes even a 96-thread host — and this file's own header
# names oversubscription as THE way parallelism can change results, by pushing a
# run into goldencheck's `timeout -s KILL`. Default is nproc/6 clamped to [4,24];
# override with PGATE_JOBS.
#
# Copies are now made INSIDE the worker and removed after, so peak disk is
# JOBS copies (~2.3G at 24) rather than one per scenario (~6.4G at 66).
#
# Usage: tools/pgate.sh <outdir> [scenario ...]
#          outdir MUST be a path (absolute, or containing a '/').
#          no scenarios given -> the full registry from scenario_manifest.json
#        PGATE_JOBS=N tools/pgate.sh <outdir> ...
set -u
SRC="$(cd "$(dirname "$0")/../.." && pwd)"

# GUARD for a trap that has already cost a run: `pgate.sh full` treated "full"
# as the OUTDIR, ran zero scenarios, and still exited 0. An outdir is a path, so
# require it to look like one.
OUT="${1:?need outdir (a path, e.g. /tmp/pg/full) — NOT a scenario name}"; shift
if [[ "$OUT" != /* && "$OUT" != */* ]]; then
  print -u2 "pgate: outdir '$OUT' is not a path. The first argument is the OUTPUT"
  print -u2 "       DIRECTORY, not a scenario or a tier name. Use e.g. /tmp/pg/full."
  exit 2
fi
ROOT=/tmp/pgate2
BASE="$ROOT/base"

SCENARIOS=("$@")
if (( ${#SCENARIOS} == 0 )); then
  # The registry is the single source of truth (same generator the Makefile's
  # FIDELITY_SCENARIOS_FULL uses), so this can no longer drift from the suite
  # the way a hardcoded battery did.
  SCENARIOS=(${(f)"$(cd "$SRC/dos_port" && python3 tools/generators/gen_scenario_registry.py --names full)"})
  SCENARIOS=(${=SCENARIOS})
  if (( ${#SCENARIOS} == 0 )); then
    print -u2 "pgate: registry returned no scenarios — refusing to 'pass' vacuously."
    exit 2
  fi
fi

JOBS="${PGATE_JOBS:-0}"
if (( JOBS == 0 )); then
  JOBS=$(( $(nproc) / 6 ))
  (( JOBS < 4 ))  && JOBS=4
  (( JOBS > 24 )) && JOBS=24
fi

# `rm -f "$OUT"/*.log` is NOT safe in zsh: an unmatched glob is an ERROR, so on a
# fresh outdir this printed `no matches found` before doing anything. (N) is the
# NULL_GLOB qualifier — expand to nothing instead of erroring.
mkdir -p "$OUT"; rm -f "$OUT"/*.log(N) "$OUT"/results.txt(N); : > "$OUT/results.txt"
T0=$SECONDS

rm -rf "$ROOT"; mkdir -p "$BASE"
rsync -a \
  --exclude='.git' \
  --exclude='dos_port/tools/dosbox-x' \
  --exclude='dos_port/tools/dosbox-x-mcp' \
  --exclude='dos_port/tools/mgba' \
  --exclude='dos_port/tools/mgba_build' \
  --exclude='*.o' \
  --exclude='PKMN.IMG' \
  --exclude='PKMN.EXE' \
  "$SRC"/ "$BASE"/ 2>/dev/null
echo "[pgate] base $(du -sh "$BASE" | cut -f1) staged in $((SECONDS-T0))s"
echo "[pgate] ${#SCENARIOS} scenarios, ${JOBS} at a time (nproc $(nproc))"

T2=$SECONDS
export ROOT BASE OUT
# One worker per scenario, at most $JOBS live. Each copies, runs, records, and
# removes its own tree. `xargs -P` is the pool; a worker that dies still gets an
# EXIT= line, so the reconciliation below can never silently lose a scenario.
print -rl -- $SCENARIOS | xargs -P "$JOBS" -I{} zsh -c '
  sc="$1"
  d="$ROOT/$sc"
  cp -a "$BASE" "$d" 2>/dev/null || { echo "$sc EXIT=98" >> "$OUT/results.txt"; exit 0; }
  cd "$d/dos_port" || { echo "$sc EXIT=99" >> "$OUT/results.txt"; rm -rf "$d"; exit 0; }
  PATH="/usr/bin:$PATH" make goldencheck SCENARIO="$sc" > "$OUT/gc_$sc.log" 2>&1
  echo "$sc EXIT=$?" >> "$OUT/results.txt"
  rm -rf "$d"
' _ {}

echo "scenarios=${#SCENARIOS} run_s=$((SECONDS-T2)) total_s=$((SECONDS-T0))" >> "$OUT/results.txt"
echo "ALL DONE" >> "$OUT/results.txt"
echo "[pgate] scenarios finished in $((SECONDS-T2))s (total $((SECONDS-T0))s)"

# RECONCILE, AND EXIT NON-ZERO ON ANY GAP. The old script always exited 0 —
# results.txt had to be read by hand, and a scenario that never ran looked
# exactly like one that passed. Attempted-vs-reported is the check that catches
# a worker dying, which a PASS/FAIL count structurally cannot.
ran=$(grep -c ' EXIT=' "$OUT/results.txt")
bad=$(grep ' EXIT=' "$OUT/results.txt" | grep -vc ' EXIT=0$')
echo "[pgate] reported=$ran/${#SCENARIOS} nonzero=$bad"
if (( ran != ${#SCENARIOS} )); then
  print -u2 "pgate: FAIL — ${#SCENARIOS} scenarios dispatched but only $ran reported."
  for sc in $SCENARIOS; do
    grep -q "^$sc EXIT=" "$OUT/results.txt" || print -u2 "  never reported: $sc"
  done
  exit 1
fi
if (( bad != 0 )); then
  print -u2 "pgate: FAIL — $bad scenario(s) exited non-zero:"
  grep ' EXIT=' "$OUT/results.txt" | grep -v ' EXIT=0$' | sed 's/^/  /' >&2
  exit 1
fi
echo "[pgate] PASS — all ${#SCENARIOS} scenarios exited 0"
