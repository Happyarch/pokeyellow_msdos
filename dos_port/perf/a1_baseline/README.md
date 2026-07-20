# A1 pre-change performance baseline

Baseline for the A1 decomposed performance contract of
`docs/current_plan_menu_intro.md`. Captured **before** any compositor or sprite
renderer change, on the tree at the A1.0 commit.

## Fixed capture parameters (must be identical on the after side)

| Parameter | Value |
|---|---|
| Build | `tools/perf_capture.sh <scenario>` (`make image DEBUG_PERF=1`) |
| DOSBox-X config | tracked `dos_port/dosbox-x.conf`, `cycles = fixed 23880`, `machine = vgaonly` |
| PIT divisor | 19506 (61.1700 Hz → **16.348 ms** frame budget) |
| Frames | party_menu 400, ow_idle 300 |
| Runs | 5 per scenario; compare the **median run** |
| PERF.BIN | v2 (per-frame WORK series) |

## Scenarios and why each is here

- **`party_menu`** — the unchanged projected menu. Exercises the window
  descriptor path (`present_windows` 3.184 ms/frame), so it is the scenario that
  would show a `WIN_SRC_X`/`WIN_SRC_Y` regression.
- **`ow_idle`** — sprite-heavy overworld. Exercises the default `g_obj_clip`
  rectangle and the hottest OBJ loop (`render_sprites` 0.548 ms/frame).

## Steady-state intervals (evidence-based, not chosen for convenience)

- **party_menu: frames 150+.** The full run has **6 deadline misses, at frames
  62, 82, 83, 87, 103, 104** — identical in all 5 runs. These are the scenario's
  own START→party-menu navigation transient, not boot warmup and not steady
  state. Frames 150+ are miss-free.
- **ow_idle: frames 0+.** The full run has **zero** misses; no interval needed.

Report the interval alongside any zero-miss claim, use the same interval on both
sides of a comparison, and also report the **full-run** miss count so a newly
introduced transient miss cannot hide inside the excluded prefix.

## Baseline numbers (steady-state interval; all 5 runs)

### party_menu — frames 150..399

| run | median | p95 | max | misses | render_bg | render_sprites | present_windows |
|---|---|---|---|---|---|---|---|
| r1 | 9.132 | 9.812 | 11.368 | 0 | 2.130 | 1.205 | 3.184 |
| r2 | 9.132 | 9.807 | 11.334 | 0 | 2.130 | 1.205 | 3.184 |
| r3 | 9.132 | 9.807 | 11.358 | 0 | 2.130 | 1.205 | 3.184 |
| r4 | 9.132 | 9.812 | 11.323 | 0 | 2.130 | 1.205 | 3.184 |
| r5 | 9.132 | 9.812 | 11.346 | 0 | 2.130 | 1.205 | 3.184 |

**Median run: median 9.132 ms, p95 9.812 ms.**

### ow_idle — frames 0..299

| run | median | p95 | max | misses | render_bg | render_sprites | present_windows |
|---|---|---|---|---|---|---|---|
| r1 | 4.581 | 14.952 | 15.438 | 0 | 3.162 | 0.548 | 0.009 |
| r2 | 4.581 | 14.950 | 15.438 | 0 | 3.162 | 0.548 | 0.009 |
| r3 | 4.581 | 14.953 | 15.438 | 0 | 3.162 | 0.548 | 0.009 |
| r4 | 4.581 | 14.953 | 15.438 | 0 | 3.162 | 0.548 | 0.009 |
| r5 | 4.581 | 14.950 | 15.438 | 0 | 3.162 | 0.548 | 0.009 |

**Median run: median 4.581 ms, p95 14.952 ms.**

## Determinism

The harness is effectively deterministic (fixed cycles + scripted input):
medians are identical to 3 decimals, p95 spread is ≤0.005 ms, stage means are
identical across all 5 runs, and the party_menu miss frames are the same six in
every run. Run-to-run host scheduling noise is therefore not a material term in
this comparison — a change larger than ~0.05 ms is signal, not noise.

## ⚠ Headroom warning for A1.3

`ow_idle` p95 is **14.95 ms against a 16.348 ms budget — only ~8.5% headroom**.
The median is far lower (4.58 ms) because `render_bg` dirty-skips most frames;
the p95 reflects periodic full-redraw frames. A per-pixel `g_obj_clip` test that
costs even a few percent on those spike frames can convert them into deadline
misses, while the *mean* and *median* barely move. Judge A1.3 on **p95 and miss
count in this scenario**, not on the mean.

## Reproduce

```sh
tools/perf_capture.sh party_menu -o perf/a1_after/party_menu.rN.bin
tools/read_perf.py perf/a1_after/party_menu.rN.bin \
    --baseline perf/a1_baseline/party_menu.rN.bin --from 150

tools/perf_capture.sh ow_idle -o perf/a1_after/ow_idle.rN.bin
tools/read_perf.py perf/a1_after/ow_idle.rN.bin \
    --baseline perf/a1_baseline/ow_idle.rN.bin --from 0
```

## Pass criteria (from the plan)

- Zero deadline misses in the steady-state interval, both sides.
- No new miss in any run (check the full-run count too).
- Median and p95 within 5% of baseline, unless the absolute increase is below
  measurement resolution.
- Window and sprite costs reported separately — an aggregate total is not
  sufficient.
