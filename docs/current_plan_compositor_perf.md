# Current Plan — Compositor Performance (get back toward 386/66)

Status: **in progress** — tick stages as they land. Archive to
`docs/plans/compositor_perf.md` when complete.

- [x] Stage 0 — DEBUG_PERF instrumentation + baselines
- [ ] Stage 1 — render_bg dirty-skip / nested loops / flat-path trim
- [ ] Stage 2 — render_window row-decode amortization
- [ ] Stage 3 — present dirty-row diff
- [ ] Stage 4 — LUT decode + sprites from tile_cache
- [ ] Stage 5 — (optional, ask user before enabling) overrun pacing
- [ ] Stage 6 — targeted loop unrolling (measured polish)
- [ ] Ride-along: party_menu icon-bob missing `g_tilecache_dirty`

## Measured baselines (Stage 0, 2026-07-12)

DOSBox-X `cycles=fixed 23880` (386SX ~20 MHz), TIMING=SGB → **16.348 ms/frame
budget**. Captured with `tools/perf_capture.sh <scenario>`; ms/frame, work =
everything except the pacing spin.

| scenario | render_bg | present_windows | present | sprites | audio | WORK | verdict |
|---|---|---|---|---|---|---|---|
| ow_idle    | **14.97** | 0.01 | 1.69 | 1.28 | 0.20 | 18.26 (112%) | overrun |
| ow_walk    | **15.00** | 0.01 | 1.69 | 0.84 | 0.39 | 18.04 (110%) | overrun |
| party_menu | 5.83 | **15.24** | 1.69 | 0.40 | 0.20 | 23.42 (143%) | overrun |
| battle     | **15.94** | 0.01 | 1.69 | 1.01 | 0.60 | 19.29 (118%) | overrun |

This ratifies the plan's ranking with no ambiguity:

- **`render_bg` alone is 92–98% of the entire frame budget** on every non-menu
  screen — the full-surface re-decode (cost #1) is the whole problem. Stage 1.
- **`present_windows` is 93% of budget in the party menu** (15.24 ms, worst
  frame 31.8 ms) and ~0 elsewhere — precisely the per-scanline row re-decode
  (cost #2) scaling with menu depth. Stage 2.
- `audio_tick` averages 0.2–0.6 ms — **exonerated**, as the investigation said.
  (Its ~10 ms worst frame is a one-off song load, not per-frame cost.)
- `present` is a flat 1.69 ms — real, but 10% of budget; Stage 3 is worth it
  only after 1 and 2 (and matters far more on real ISA VGA than in DOSBox-X).
- Frames cost ~31–34 ms total, i.e. **the game runs at roughly half speed** here,
  and `wait` still burns 13 ms on top: cost #7 (`wait_vblank` spinning for a
  fresh 70 Hz edge on an already-late frame) is confirmed real → Stage 5.

Instruction-level style rules (LEA/scaled indexing, MOVZX, 32-bit moves, cycle
table) live in `docs/386_optimization_strategy.md` — apply them throughout;
this plan is the structural work. All paths below are relative to `dos_port/`.

## Context

The port originally targeted a 66 MHz 386; it now needs a ~166 MHz 486 for full
speed. Music is driven once per `DelayFrame`, so frame overruns audibly slow it —
worst with the START menu open, worse per submenu, and in battles. The GB has no
compositor (the PPU does it in hardware), so this is all port-side HAL code
(`src/ppu/ppu.asm`, `boot/video.asm`, `src/video/frame.asm`) — no pret-fidelity
constraints beyond "pixels must not change."

Investigation (2026-07-11 session: direct reads + an agent sweep of audio/menus)
settled the "is the compositor even the right place?" question: **yes, decisively.**

**Exonerated:** `audio_tick` is flat per-frame cost (OPL writes are change-gated;
worst case ~1–3 envelope TL rewrites/frame ≈ 0.1 ms of dummy-IN delay) and cannot
explain menu-depth scaling. Menu `menu_redraw_cb` mirrors copy only 140–360
bytes/frame. Water/flower animation rebuilds the tile cache every ~20 frames, not
every frame. Battle installs no big mirrors at all.

**The real costs:**

| # | Cost (per frame) | When | Where |
|---|---|---|---|
| 1 | Full surface re-decode: all 1728 tiles (48×36) → 110,592 B written + ~110 KB read from tile_cache, plus 1728 `div`s (3456 on flat path), even when nothing changed | always, unconditional | `src/ppu/ppu.asm:185-263` |
| 2 | `render_window`: full 32-tile row decoded with per-pixel `shl/rcl` for **every scanline** of **every open descriptor** (~3–5 K cycles/scanline; START menu ≈ 80 scanlines, options/party ≈ 160–200, bag stacks descriptors) | scales with menus/submenus | `src/ppu/ppu.asm:663-756`, `decode_win_row :837-875` |
| 3 | `present`: unconditional 64,000-B `rep movsd` to VGA — on ISA-bus VGA this is the slowest memory on the machine (~ms/frame) | always | `boot/video.asm:280-293` |
| 4 | Surface→backbuf blit, 64,000 B | always | `src/ppu/ppu.asm:376-405` |
| 5 | `rebuild_tile_cache`: 384 tiles per-pixel decode (~24.5 K `stosb` iterations) | every ~20 frames (water/flower), on font/pic loads | `src/ppu/ppu.asm:421-446` |
| 6 | `render_sprites`: per-pixel 2bpp bit extraction per sprite | always | `src/ppu/ppu.asm:464-594` |
| 7 | `wait_vblank` blocks for a fresh 70 Hz vsync edge before the PIT check → up to ~14 ms extra spin on already-late frames | overrun frames | `boot/timing.asm:183-199` |

Decisions made with the user: yardstick is **real 386/486 hardware (ISA/VLB VGA)**;
staging is **instrument first, then fix in ranked order**. The PIT tick is the
authoritative game-speed clock (SGB/DMG/PC divisor modes) and must not change.

## Stage 0 — DEBUG_PERF instrumentation

New `src/debug/perf.asm` + `%ifdef DEBUG_PERF` hooks in `DelayFrame`
(`src/video/frame.asm`): latch PIT ch0 (command port 0x43, read 0x40) around each
stage — commit/oam/audio/render_bg/render_sprites/present_windows/present —
accumulate 32-bit totals + frame count per stage (handle count wrap at the
divisor), dump `PERF.BIN` on quit in the existing `DebugDumpMemory` style.
Makefile: `DEBUG_PERF=1` (NASMFLAGS stamp already handles flag rebuilds).

Baseline scenarios: overworld idle, walking, START menu, options/party submenu,
wild battle — under DOSBox-X fixed cycles (386-class and 486-class settings),
plus user spot-check on real hardware. Every later stage re-runs these.

### Debugger support (dosbox-x-mcp, symbolic since 2026-07-12)

PERF.BIN stays the *measurement* tool (real-hardware comparable); the MCP
debug harness is the *inspection* tool while implementing each stage. What
the 2026-07-12 upgrade gives this plan specifically:

- **Symbolic breakpoints incl. NASM local labels** — `pkmn.sym` is generated
  from PKMN.EXE's COFF symtab at every link and carries all ~8–9 k local
  labels, so the exact hot spots in this plan are breakable by name:
  `set_breakpoint("render_bg")`, `render_bg.row_copy`, `render_sprites`
  (`.colLoop`), `decode_win_row`, `rebuild_tile_cache`, `present`. No hex
  hunting; `where()` / annotated `disassemble` confirm which rewritten path
  actually executes.
- **No stale-symbol class** — `symbol_map.py` mtime-reloads `pkmn.sym` per
  call (errors loudly if PKMN.EXE is newer), so the tight
  rebuild→re-break iteration loop these stages need works mid-session
  without restarting the MCP server. Breakpoints re-resolve on the new build.
- **Watchpoints for the dirty-flag work** — `set_watchpoint` (BPLM,
  memory-change) on `g_tilecache_dirty`, the Stage 1b tile-ID shadow, or the
  Stage 3 prev-frame shadow catches "who armed/failed to arm the flag"
  directly — this is the debugging shape for both the dirty-skip stages and
  the party_menu ride-along bug.
- Workflow reminders: build the game first (`run_with_mcp.sh` does **not**
  build), launch via `dos_port/tools/run_with_mcp.sh`; the binary is the
  fork-submodule build `dosbox-x-mcp` (rebuild with
  `tools/build_dosbox_mcp.sh` if the fork moves); never `pkill -f dosbox`
  (use `pkill -f dosbox-x-mcp`).

## Stage 1 — render_bg: stop re-decoding the world every frame (biggest win)

- **1a. Nested loops:** replace the linear-index `div`-per-tile loop with
  row 0..35 / col 0..47 nested loops and a running dest pointer. Deletes all
  per-tile `div`s (~38–40 cycles each) and the `imul`; also hoist the per-tile
  `W_CURRENT_TILE_BLOCK_MAP_VIEW_PTR` load/branch (loop-invariant).
- **1b. Dirty-skip:** keep a 1728-byte shadow of last frame's tile IDs + a
  force-redecode flag. Per tile: decode only if ID ≠ shadow or force set.
  `rebuild_tile_cache` arms the force flag (patterns changed under same IDs).
  Use `rep cmpsb/cmpsd` runs for fast skip. Idle frame → ~2 KB compares instead
  of ~220 KB traffic; walking → only the fresh row/column.
- **1c. Flat path:** decode only the live 40×25 cells; fill the 48×36 padding
  ($7F) once on the view-ptr 0↔nonzero transition, not per frame; drops the
  second per-tile `div` and 728 dead-cell tests.

## Stage 2 — render_window: amortize the row decode (fixes menu scaling)

- **2a.** Decode a window tile row once per 8 scanlines into an 8-row (2 KB)
  buffer instead of re-decoding per scanline; the 8 covered scanlines just copy.
- **2b.** Decode only `ceil(clip_w/8)+1` tiles (≤ 21 for the 160-px dialog), not
  all 32.
- **2c.** Source rows from the already-decoded `tile_cache` (window tiles are in
  its $8000–$97FF range) — 8-byte gather-copies, zero bit extraction. Same
  signed/unsigned `tiledata_mode` math as `render_bg .got_tile`.

Combined: a 200-scanline submenu goes from ~200 full-row bit-decodes to ~25
tile-row gathers — >10× less window work; descriptor stacking becomes cheap.

## Stage 3 — present: dirty-row diff (top win on real ISA VGA)

Keep a 64,000-B prev-frame shadow in system RAM. Per row (or 4-row band):
`rep cmpsd` vs shadow; `rep movsd` to VGA + shadow update only for changed rows.
Idle menu frames drop from 64,000 VGA writes to ~0–2,000 (cursor blink). RAM
compares are cheap next to ISA VGA writes. Optional fast path: when the frame is
known fully-changed (walk scroll active), skip the diff and blast the full copy.

## Stage 4 — cheaper decodes + sprites from tile_cache

- **4a. 2bpp→8bpp LUT:** two 256×8-B tables (lo-plane spread, hi-plane spread≪1);
  a tile row = 2 dword loads + or per 4 px, replacing 8×(2 `shl` + 2 `rcl` +
  `stosb`). Use in `rebuild_tile_cache` (and any remaining direct decode). 4 KB
  `.data` (respect the link.ld section rule).
- **4b. render_sprites:** fetch pre-decoded rows from `tile_cache` instead of
  per-pixel `shr` on the 2bpp planes; X-flip = reversed-order read; keep the
  per-pixel transparency/priority tests. Roughly halves sprite cost.

## Stage 5 (optional — ASK THE USER before enabling anything) — overrun pacing

**Hard constraint (user):** the PIT is load-bearing — music and other
subroutines pace off it, so nothing here may alter the PIT ISR, divisor
(SGB/DMG/PC modes), `tick_flag` semantics, or how many ticks a frame consumes.
The only change: skip the *additional* `wait_vblank` spin when `tick_flag` is
already set (frame is late) — the tick wait itself is untouched, so game/music
speed is bit-identical; the trade is possible tearing on catch-up frames only.
Behind a Makefile flag; default off unless the user wants it.

## Stage 6 — targeted loop unrolling (polish pass, after Stages 1–4)

386/486 have no branch prediction; a taken `jnz` is ~7+ cycles on 386 (~3 on 486)
plus a prefetch-queue flush, so short fixed-count loops carry 15–30% pure loop
overhead. Unroll only these (all have compile-time trip counts):

- `render_bg .row_copy` (`src/ppu/ppu.asm:250-259`): fully unroll the 8-row ×
  8-byte tile copy into 16 `mov` pairs with fixed displacements — deletes the
  two pointer `add`s and `dec/jnz` per row (~100 cycles/tile saved wherever a
  tile still gets decoded after Stage 1's dirty-skip).
- Stage 4a LUT row decode in `rebuild_tile_cache`: unroll the per-row loop
  (2 table lookups + 2 stores per row, 8 rows).
- `render_sprites .colLoop` (`src/ppu/ppu.asm:538-580`): unroll the 8 columns
  (fixed count); the per-pixel transparency/priority tests stay, but
  `inc/cmp/jb` per pixel goes away. Combine with Stage 4b.
- Stage 2c window row gather: each tile row is 2 `mov` dword pairs — inline
  them, no inner loop at all.

Do **NOT** unroll: any `rep movsd`/`rep stosd` block transfer (`present`, the
surface→backbuf blit, whiteout fill, window row copies). String ops are already
optimal on 386/486, the VGA copy is ISA-bus-bound regardless, and unrolled
copies bloat code into the 486's small 8 KB unified cache. Keep unrolls modest
for the same cache reason — this stage is measured polish (Stage 0 numbers
before/after), not a rewrite.

## Rides along

- `src/engine/menus/party_menu.asm:518-547` icon-bob `LoadPartyMonIconFrame`
  writes VRAM patterns without arming `g_tilecache_dirty` — latent staleness
  bug found in the audit; 1-line fix (cheap once Stage 1/4 land).

## Faithfulness notes

- Every stage is a pixel-identical transform — no behavior change permitted.
- Existing documented divergences stay as-is: window-over-sprites order (needed
  for the extended viewport), reverse-OAM order, no 10-sprite/scanline limit,
  no 8×16 OBJ. Optional glitch-parity items (10-sprite dropout, smaller-X
  priority) are *not* included — they cost cycles against the goal.
- Audio left alone (evidence says it's not the problem); optional later:
  OPL3-detected shorter data-write delay.

## Files

- `src/ppu/ppu.asm` — Stages 1, 2, 4
- `boot/video.asm` — Stage 3 (`present`)
- `src/video/frame.asm` — Stage 0 hooks, Stage 5
- `src/debug/perf.asm` (new), `Makefile` (`DEBUG_PERF`)
- `src/engine/menus/party_menu.asm` — 1-line dirty-flag fix

## Verification

1. **Perf:** `PERF.BIN` before/after each stage across the 5 baseline scenarios
   (DOSBox-X fixed cycles; user validates on real hardware).
2. **Pixels:** `FRAME.BIN` byte-identical vs pre-change baseline per scenario
   (headless harness), plus `make fidelity` / `goldencheck` golden scenarios.
3. **Symptom:** music tempo steady with START menu + submenus open
   (`DEBUG_AUDIO TRACK=` loop while navigating menus).
4. `tools/lint_pret_labels` exit 0 before each commit (HAL files, but run anyway).
