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
# Usage: tools/pgate.sh <outdir> [scenario ...]      (default: the 17-scenario battery)
set -u
SRC="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${1:?need outdir}"; shift
ROOT=/tmp/pgate2
BASE="$ROOT/base"

SCENARIOS=("$@")
if (( ${#SCENARIOS} == 0 )); then
  SCENARIOS=(
    battle_intro battle_menu move_selection battle_damage battle_faint battle_blackout
    trainer_battle_init trainer_battle_win trainer_battle_loss trainer_battle_route
    ball_catch item_potion_use fish_old_rod
    party_menu pokedex_list overworld_pallet ledge_hop
  )
fi

mkdir -p "$OUT"; rm -f "$OUT"/*.log "$OUT"/results.txt 2>/dev/null; : > "$OUT/results.txt"
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

T1=$SECONDS
for sc in $SCENARIOS; do ( cp -a "$BASE" "$ROOT/$sc" ) & done
wait
echo "[pgate] ${#SCENARIOS} copies fanned out in $((SECONDS-T1))s"

T2=$SECONDS
for sc in $SCENARIOS; do
  (
    cd "$ROOT/$sc/dos_port" || exit 99
    PATH="/usr/bin:$PATH" make goldencheck SCENARIO=$sc > "$OUT/gc_$sc.log" 2>&1
    echo "$sc EXIT=$?" >> "$OUT/results.txt"
  ) &
done
wait
echo "scenarios=${#SCENARIOS} run_s=$((SECONDS-T2)) total_s=$((SECONDS-T0))" >> "$OUT/results.txt"
echo "ALL DONE" >> "$OUT/results.txt"
echo "[pgate] scenarios finished in $((SECONDS-T2))s (total $((SECONDS-T0))s)"
