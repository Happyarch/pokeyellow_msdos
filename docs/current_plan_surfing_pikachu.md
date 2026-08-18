# Current Plan — Surfing Pikachu Minigame (`engine/minigame/surfing_pikachu.asm`)

Author: planning agent, 2026-08-17 (maintainer-authorised exception to the
"root writes the plan" rule).
Skills used: `project-conventions` (active-plan convention, two-tier data rule,
stub rules, annotation schema), `asm-translation` (register map, flag/counter
rules, VRAM tile-cache rule, `SCREEN_WIDTH` role split, HAL boundaries).

---

## 1. Status and scope

### In scope

Port pret `engine/minigame/surfing_pikachu.asm` (2877 lines, 175 top-level
labels) to `dos_port/src/engine/minigame/surfing_pikachu.asm`, plus the
substrate it needs:

- The `wSurfingMinigame*` WRAM block and the animated-object staging region in
  `dos_port/include/gb_memmap.inc`.
- A Tier-1 generator for the minigame's 5 tilemaps and 3 `.2bpp` graphics blobs
  (`dos_port/tools/generators/gen_surfing_pikachu.py` → `assets/surfing_pikachu.inc`).
- The mirrors for its two `data/sprite_anims/` tables and its `gfx/` blob labels.
- Three compositor/HAL primitives the minigame is unimplementable without:
  `RedrawRowOrColumn`, the generic `VBlankCopy` tile transfer, and a
  per-scanline BG Y-displacement channel (the `wLYOverrides` wave).
- A `DEBUG_SURFING_PIKACHU` entry gate so the minigame is reachable at runtime,
  and a visual `FRAME.BIN` proof that it draws.
- Merge back to `master`.

### Explicitly NOT in scope

- **The printer path.** `PrintSurfingMinigameHighScore` and
  `Printer_PrepareSurfingMinigameHighScoreTileMap` (pret `engine/printer/printer.asm:118,631`)
  stay unresolved. The port has no printer transport
  (`dos_port/src/home/printer.asm:5-12` — `PrinterSerial`/`SerialFunction` are
  deliberately not ported). Their only callers are
  `scripts/SummerBeachHouse.asm:174` / `SummerBeachHouse_2.asm:7`, whose port
  mirror `dos_port/src/scripts/summer_beach_house.asm` is **not in any Makefile
  source list** (verified: `grep -n summer_beach_house dos_port/Makefile` returns
  nothing), so nothing links against them. Do not add stubs for them.
- **Wiring the minigame into the real game flow.** `summer_beach_house.asm`
  already carries `call SurfingPikachuMinigame`
  (`dos_port/src/scripts/summer_beach_house.asm:124`), but that file is
  unlinked and `dos_port/src/scripts/` is owned by another workstream right now.
  Runtime reachability in this plan is via the `DEBUG_*` gate only.
- **An mGBA golden scenario + `scenario_manifest.json` row — DEFERRED**, and
  the reason is design, not laziness: the minigame loop is driven by `Random`
  (`SurfingMinigame_*` wave spawning) and by a 3-frame-buffered joypad
  (`SurfingPikachu_GetJoypad_3FrameBuffer`, pret line 2531). A deterministic
  differential golden needs RNG pinning plus a scripted input tape on both
  sides, which is its own piece of harness design. Chunk 3 delivers the
  `DEBUG_*` gate (the prerequisite for any future scenario) and a `FRAME.BIN`
  visual proof; the manifest row is a follow-up work item for the root.
- **Re-parameterising the minigame to the full 40x25 canvas.** See §2.

### Projection ruling (maintainer, 2026-08-17)

**CENTER. Nothing more.** Coordinates targeting `wTileMap` get +10 columns /
+3 rows, exactly like the battle screen's `BCOORD`. Do not redesign, widen, or
re-parameterise any layout. Coordinates targeting the *GB tilemap*
(`bgcoord`/`hlbgcoord`/`debgcoord`) are **verbatim** — the port models
`GB_TILEMAP0`/`GB_TILEMAP1` 1:1 at stride 32 (`dos_port/include/coords.inc:102-131`).

---

## 2. Findings on the two flagged risks

Both were investigated against the tree. Neither is a blocker, but the first
one's real shape is *not* the one the brief guessed, and the investigation
turned up a **third** gap that is larger than either.

### Risk 1 — `vBGMap1`: NOT a second BG map here. It is the WINDOW map.

`SurfingPikachuMinigame_SetupLoop` sets
`rLCDC = LCDC_ON | LCDC_WIN_9C00 | LCDC_WIN_ON | LCDC_OBJ_ON | LCDC_BG_ON`
(pret `engine/minigame/surfing_pikachu.asm:265`) and parks the window at
`hWY = $7e` (line 246). So every `hlbgcoord …, vBGMap1` /
`debgcoord 1, 1, vBGMap1` site (lines 349, 358, 360, 362, 364 — the HP status
bar in `SurfingPikachuMinigame_DrawStaticTilemapLayout`) is writing the
**window** tilemap, not a second background.

**The port already models this.** A window descriptor carries its own tilemap
base: `set_single_window` / `add_window` take `ESI = tilemap_base` documented as
"EBP-rel: `GB_TILEMAP0`/`GB_TILEMAP1`" (`dos_port/src/ppu/ppu.asm:1809, 1816, 1861`),
and the per-cell window attribute plane deliberately spans
"`GB_TILEMAP0` ($9800) through the end of `GB_TILEMAP1` ($9FFF) — 2 KB, both
maps, because a descriptor may sample either" (`dos_port/src/ppu/ppu.asm:455-457`).
So the status bar is a plain second window descriptor. **No HAL gap.**

**The actual `vBGMap0` gap is the opposite one, and it is real.** The minigame
drives the *background* by writing `vBGMap0` directly — `ld hl, vBGMap0 / ld bc,
2 * TILEMAP_AREA / FillMemory` and `hlbgcoord 0, 6 / ld bc, 12 * TILEMAP_WIDTH`
water fill (pret lines 225-232), then scrolls it with `hSCX`. But the port's
`render_bg` **never reads `GB_TILEMAP0`**: its surface is decoded either from
`wSurroundingTiles` (overworld) or from the flat 40-wide `wTileMap`
(`decode_surface_flat`, `dos_port/src/ppu/ppu.asm:1141-1153` — "the read is
direct from `wTileMap` at its native 40-wide stride"). A minigame BG written into
`vBGMap0` would render as nothing.

**Resolution — use the established cinematic-surface precedent, in reverse.**
The movie projection already presents a GB-stride-32 tilemap through the window
layer: `MovieBeginSurface` / `MovieMirrorSurface` mirror `wTileMap` (stride 40)
into `GB_TILEMAP0` (stride 32) and show it through a window
(`dos_port/src/ppu/ppu.asm:255-265`; `dos_port/src/debug/debug_dump.asm:7257,7279`).
For the minigame the mirror step is unnecessary — the game already puts the
right bytes in `GB_TILEMAP0`. So the presentation is:

- **BG plane** = one window descriptor, `wx = 80+7`, `wy = 24`, `clip_w = 160`,
  `max_y = 168`, `tilemap = GB_TILEMAP0`, `start_row = 0`, with
  `WIN_SRC_X = hSCX` and `WIN_SRC_Y = hSCY` (the "fine" wrap path,
  `dos_port/src/ppu/ppu.asm:1673-1712`, which does the mod-256 / mod-32 GB torus
  wrap correctly and is exactly what an endlessly-scrolling water field needs).
- **Status bar** = a second descriptor, `tilemap = GB_TILEMAP1`, `wy = 24 + $7e`.
- `g_bg_whiteout = 1` so `render_bg` paints a clean matte instead of the
  overworld, `g_obj_clip = (80, 24, 240, 168)` so OBJ clip at the projected GB
  boundary, and `g_obj_over_window = 1` so Pikachu draws **over** the water —
  the GB hardware order, which this screen needs
  (`dos_port/src/ppu/ppu.asm:268-275`).

This is why the projection ruling is CENTER and nothing more: the GB tilemap is
32 tiles wide, `render_window` caps a row decode at `TILEMAP_W` = 32
(`dos_port/src/ppu/ppu.asm:1616-1624`), and 320 px needs 40. A 20-tile-wide
centred window is inside the cap; a full-width one is not.

**Severity: LOW.** No new compositor code; correct use of existing primitives.

### Risk 2 — Music tempo: SUPPORTED. Literal translation works.

`SurfingMinigame_UpdateMusicTempo` (pret line 117) and
`SurfingMinigame_ResetMusicTempo` (line 160) do exactly two things: gate on
`wChannelNoteDelayCounters[0..2] == 1`, then store a 16-bit value into
`wMusicTempo`. Both symbols exist and are live in the port:

- `wChannelNoteDelayCounters equ 0xC0B6` (`dos_port/include/gb_memmap.inc:1040`)
- `wMusicTempo equ 0xC0E8 ; dw, stored hi-then-lo (big-endian!)` (`:1048`)

and the translated engine reads `wMusicTempo` big-endian in its note-delay
computation (`dos_port/src/audio/engine_1.asm:639-640`,
`mov dh, [ebp + wMusicTempo] / mov dl, [ebp + wMusicTempo + 1]`) and writes it
from the `tempo_cmd` handler (`:432-441`). The APU is a virtual APU and not a
TODO-HW boundary. **No HAL gap, no deviation owed.**

One trap to carry into the translation: pret writes the **low** byte to
`wMusicTempo + 1` first and the **high** byte to `wMusicTempo` second (lines
147-151), because its `.Tempos` table is RGBDS `dw` (little-endian) while
`wMusicTempo` is big-endian. Reproduce the byte *destinations*, not the source
layout. See Chunk 2's constraint list.

**Severity: NONE.**

### Risk 3 (found during this investigation) — the per-scanline wave. THIS is the hard part.

The minigame's defining visual is a per-scanline `rSCY` displacement driven by a
STAT-mode-0 (H-blank) interrupt:

```
ld a, STAT_MODE_0                 ; pret line 33-34
ldh [rSTAT], a
...
ld a, rSCY - $ff00                ; line 249-250
ldh [hLCDCPointer], a
call SurfingMinigame_InitScanlineOverrides   ; line 242 → fills wLYOverrides
```

`asm-translation` is explicit that **`rLY`/`rSTAT` are INERT in the port** and a
literal per-scanline effect hangs or does nothing. The port's existing record of
this exact gap:

> `DEVIATION{class=HAL; pret=engine/movie/intro_yellow.asm:YellowIntroScene6;
> behavior=the per-scanline LY scroll override is not emulated … the surfing
> scene's water renders flat instead of waving …}`
> — `dos_port/src/engine/movie/intro_yellow.asm:335`

The compositor has a per-row **X** channel (`g_row_xoff` / `g_row_xoff_on`,
`dos_port/src/ppu/ppu.asm:327, 403-407, 705-707`) built for
`AnimationWavyScreen`, but no Y analogue. Because the minigame's BG is presented
through a **window** descriptor (Risk 1's resolution), the hook is small and
local: `render_window`'s fine path already computes
`src_y = (WIN_SRC_Y + WLY) & 255` at `.fine_row`
(`dos_port/src/ppu/ppu.asm:1673-1677`). A per-screen-row Y table adds one term.

**Severity: MODERATE, and it is chunk 1's centre of gravity.** The cost is that
the fine path's `win_last_row` cache (`:1682-1690`) stops hitting once per 8
scanlines and starts missing per scanline. That is a real per-frame cost, must be
behind an off-by-default flag, and must be measured.

### Risk 4 (found) — `RedrawRowOrColumn` does not exist in the port.

`SurfingMinigame_UpdateWaveColumn` (pret lines 1916-1941) pushes a two-tile
column into `vBGMap0` each frame via `wRedrawRowOrColumnSrcTiles` /
`hRedrawRowOrColumnDest` / `hRedrawRowOrColumnMode`. The port's `home/vcopy.asm`
header lists `RedrawRowOrColumn` among the routines **not** ported
(`dos_port/src/home/vcopy.asm:15`), and CLAUDE.md records the ring as retired
with the VRAM torus.

**This one is cheap.** In the port there is no VRAM/CPU contention: pret's
routine is pure GB-memory manipulation (copy N tiles from
`wRedrawRowOrColumnSrcTiles` to `hRedrawRowOrColumnDest`, wrapping inside the
32x32 map). Translate it faithfully into its mirror
`dos_port/src/home/vcopy.asm` and drive it from the `DelayFrame` pipeline.
**Severity: LOW.**

### Risk 5 (found) — the generic `VBlankCopy` does not exist, and it is gameplay-load-bearing.

`SurfingMinigame_ReadBGMapBuffer` (pret line 1324) samples one tile out of
`vBGMap0` nine tiles into the viewport, via `hVBlankCopySource` /
`hVBlankCopyDest` / `hVBlankCopySize`, into `wSurfingMinigameBGMapReadBuffer`.
That buffer is then **read seven times** (pret lines 918, 1091, 1113, 1215,
1379) to decide wave collision and trick state — it is not cosmetic.

The port has only `VBlankCopyBgMap` (the `hVBlankCopyBG*` row transfer,
`dos_port/src/home/vcopy.asm:81-150`); the generic byte transfer is recorded
absent:

> `DEVIATION{class=HAL; pret=engine/movie/intro_yellow.asm:Request7TileTransferFromC810ToC710;
> behavior=the hVBlankCopySource/Dest/Size request is written but never acted on
> because the port has no generic VBlank tile copy …}`
> — `dos_port/src/engine/movie/intro_yellow.asm:418` (a second at `:527`)

**Severity: LOW to implement, MODERATE in blast radius.** Implementing it
*activates* those two intro_yellow sites (cloud tiles and the LY-wave tile
animation begin transferring), which can move intro goldens. That is a feature,
not a regression, but it must be measured and reported rather than silently
absorbed — see chunk 1's review gate.

### What could not be determined

- **Exact per-frame cost of the per-scanline window path.** No measurement was
  taken; chunk 1 is required to take one with `DEBUG_PERF` /
  `tools/perf_capture.sh` and report it.
- **Whether implementing `VBlankCopy` shifts any existing golden.** Predicted to
  touch only the two `intro_yellow` scenes. Chunk 1 must run `fidelity-full` and
  report the actual diff rather than assume.
- **The exact `wSurfingMinigame*` addresses.** They are not in
  `dos_port/include/gb_memmap.inc` today (only three strays:
  `wSurfingMinigamePikachuHP equ 0xC5D6`, `wSurfingMinigameTotalScore equ 0xC5DC`,
  `wSurfingMinigameTrickFlags equ 0xC62F` at `:91-95`, and a note at `:1271-1273`
  saying the block is "not modelled here"). They must be **read from
  `pokeyellow.sym`**, never inferred — the same discipline
  `dos_port/src/scripts/summer_beach_house.asm:56-59` used for
  `wPikachuMapScriptFlags equ 0xD492`.

---

## 3. Stages

Chunks are dispatched **strictly sequentially**. Chunk N+1 is dispatched only
after chunk N has returned *and* the root has verified it against §5 and ticked
its box. A failed review holds the line.

- [ ] **Stage 0 — Worktree standup (root session, not an execution agent).**
- [ ] **Stage 1 — Chunk 1: substrate.** WRAM/staging symbols, Tier-1 generator +
      asset mirrors, and the three HAL primitives (`RedrawRowOrColumn`,
      `VBlankCopy`, per-scanline window Y override).
- [ ] **Stage 2 — Root review of chunk 1** (§5.1). Tick only on evidence.
- [ ] **Stage 3 — Chunk 2: the translation.** All 175 labels into
      `dos_port/src/engine/minigame/surfing_pikachu.asm`, check-only.
- [ ] **Stage 4 — Root review of chunk 2** (§5.2).
- [ ] **Stage 5 — Chunk 3: presentation, link, runtime gate.** The two missing
      externals, the window/projection glue, link the file,
      `DEBUG_SURFING_PIKACHU`, `FRAME.BIN` proof.
- [ ] **Stage 6 — Root review of chunk 3** (§5.3).
- [ ] **Stage 7 — Merge `surfing-pikachu` back to `master`** (root), after a
      clean `fidelity-full` on the merge result.
- [ ] **Stage 8 — Follow-up (deferred, not part of this plan's chunks): design a
      deterministic golden scenario** (RNG pin + input tape) and add its
      `scenario_manifest.json` row.

---

## 4. Execution specs

Each of the three specs below is **self-contained**. Hand one verbatim to a
`gemini-3.7-flash-high` agent. Do not hand more than one at a time.

Launch form (from CLAUDE.md, plus the fan-out lessons in stigmergy memory
`agent-fanout-worktree-setup`):

```sh
agy --model gemini-3.7-flash-high --effort high \
    --dangerously-skip-permissions --print-timeout 15m \
    --output-format json \
    -p "<THE CHUNK SPEC, VERBATIM>" > /tmp/surf-chunk-N.json 2>&1
```

`--output-format json` is mandatory (it is the only way `usage.input_tokens` is
recorded). If a chunk needs a follow-up, resume with
`--conversation <conversation_id>` from that JSON — never `--continue`.

---

### Stage 0 — Worktree standup (root does this before dispatching chunk 1)

```sh
git worktree add ../pokeyellow_msdos-surf -b surfing-pikachu
cd ../pokeyellow_msdos-surf
git submodule update --init --recursive        # REQUIRED — see below
python3 tools/setup_toolchain.py               # or copy CWSDPMI.EXE in
make -j$(nproc)                                # ROOT FIRST
make -C dos_port -j$(nproc)                    # THEN dos_port
```

Load-bearing, all measured (memory `agent-fanout-worktree-setup`):

- **A worktree is not ready after `git worktree add`.** Submodules are not
  populated. Without `dos_port/tools/unicode_converter` the build dies at
  `assets/bills_pc_text.inc` with `ModuleNotFoundError: data_manipulation_logic`
  — an error that names a *tracked* file and reads as a missing file when it is
  a missing checkout.
- **`CWSDPMI.EXE` is deliberately uncommitted** (licensing) and gitignored.
- **Build order is load-bearing.** Running `make -C dos_port` first in a fresh
  worktree fails twice and neither failure names its cause: `Error 127` on
  `gfx/**/*.pic` (pret's gitignored C tools race under `-j`), then
  `FileNotFoundError: gfx/town_map/town_map.2bpp` (a fresh worktree carries 382
  of the 583 `.2bpp` the asset generators read). A root `make` builds the C
  tools, all 583 `.2bpp`, the `.pic` set, and `pokeyellow.gbc` + `pokeyellow.sym`.
- **Pin the DOSBox MCP socket per worktree:**
  `export DOSBOX_MCP_SOCKET=/tmp/dosbox-mcp-surf.sock`. `run_with_mcp.sh` must
  be launched from the **repo root**, not `dos_port/`.
- **agy specifics:** its MCP config is `~/.gemini/config/mcp_config.json` (not
  the repo `.mcp.json`); `root_register` `agent_kind` **must** be `"antigravity"`
  (`gemini`/`agy` are silently rejected); `context_open` must use the **main**
  repo path `/mnt/sdb1/Code/Active Code/pokeyellow_msdos` even when working in
  the worktree, or the project memory space silently forks.
- Check quota before sizing anything: `agy -p "/usage"`.

---

### 4.1 CHUNK 1 SPEC — Substrate: symbols, Tier-1 data, and three HAL primitives

> Hand everything from here to the end of §4.1 to the agent, verbatim.

---

**You are implementing chunk 1 of 3 of a port task. Read this whole spec before
touching anything. Do exactly what it says and nothing more.**

#### Environment

You are working in the git worktree `/mnt/sdb1/Code/Active Code/pokeyellow_msdos-surf`,
branch `surfing-pikachu`. It is already built. All paths below are relative to
that worktree root unless absolute.

Register with stigmergy using `agent_kind: "antigravity"` and
`context_open` on the **main** repo path
`/mnt/sdb1/Code/Active Code/pokeyellow_msdos` (not the worktree path — using the
worktree path silently forks the project memory space).

Export `DOSBOX_MCP_SOCKET=/tmp/dosbox-mcp-surf.sock` before any DOSBox work.

#### Project context you must honour

This is a from-scratch port of Pokémon Yellow (Game Boy) to MS-DOS in 32-bit x86
NASM (386+, protected mode, DJGPP/COFF). The pret disassembly at the repository
root is **read-only specification** — never edit anything outside `dos_port/`.
The port lives under `dos_port/`.

Read `CLAUDE.md` at the repo root before you start. The rules that bind you here:

- **Preserve pret label names verbatim.** Every routine, jump target and data
  label keeps the exact name pret uses. Never rename, never invent a "port"
  variant of a pret name. If you need a local alias, add it *alongside*.
- **A pret-labeled routine lives in its MIRROR path**: pret `home/vcopy.asm` →
  `dos_port/src/home/vcopy.asm`. Never relocate a pret label to a "more
  convenient" file.
- **Text and graphics are Tier-1 DATA.** Any glyph run or graphics blob is
  produced by a Python generator under `dos_port/tools/generators/` emitting
  `dos_port/assets/*.inc` with a `DO NOT EDIT BY HAND` header, `%include`d by a
  `.asm` and wired into the Makefile `assets` target. **Never** hand-write
  `db 0x…` graphics or charmap bytes in a `.asm`.
- **Link-time stand-ins go in `src/<area>/<area>_stubs.asm`** under the exact
  pret label, never as a `ret`-only body in a mirror file.
- **Do not add zero-guards pret lacks, and do not widen its counters.** pret's
  `dec c / jr nz` entered with C=0 runs 256 times; `movzx ecx, cl / dec ecx /
  jnz` runs 4 billion and page-faults. Keep 8-bit counters 8-bit (`dec cl`).
  Adding `test cl,cl / jz` is a *behavioural divergence*, not a safety fix.
- **Preserve the exact ZF/CF a `jr z`/`jr c` reads.** `mov`/`lea`/`movzx` do not
  touch flags; `inc`/`dec` preserve CF but clobber ZF.
- Register map: A→AL, BC→BX, DE→DX, HL→ESI, EBP = base of emulated GB memory.
  GB memory is `[ebp + SYMBOL]` with symbols from `dos_port/include/gb_memmap.inc`.
- **GB data is big-endian** — multi-byte game values are stored high byte first.
- **Any new linker section name must be added to `dos_port/link.ld` first**, or
  its bytes never load and its symbols read back as zero at runtime with no
  fault. Prefer `.data` / `.text`. Related measured trap: NASM's COFF backend
  emits a `global` label as an *undefined external* if it is defined in the
  implicit default section — always write an explicit `section` directive before
  a `global`'d data block (see `dos_port/src/home/player_gfx.asm:60-64`).
- **VRAM tile writes must invalidate the tile cache.** The compositor never
  reads VRAM tile patterns; it decodes them once into `tile_cache`. Route tile
  writes through `CopyVideoData`, or set `mov byte [g_tilecache_dirty], 1`
  explicitly. A raw `rep movs` into vChars that does neither renders the
  *previous* occupants of those slots.
- **A stated gap beats a wrong lowering.** If something cannot be done
  faithfully, stop, leave the code correct-as-far-as-it-goes, and say so
  precisely in your report. Do not invent behaviour to fill a hole.
- **Sanctioned divergences carry a machine-parsed annotation**, one line, no `;`
  or `}` inside a value:
  `; DEVIATION{class=<HAL|banking|projection|data-model|timing|stub|temporary>; pret=<file>:<Label>; behavior=<what differs>; evidence=<why that is the truth>; lifetime=<what retires it>}`
  Kinds are exactly `DEVIATION`, `BUG`, `GLITCH`, `STUB` — no others parse.
- The interactive shell is **zsh**, not bash: quote globs (an unmatched glob is
  an error and the command does not run), `$pipestatus` is 1-indexed, and never
  put anything between a gate and the status you read (redirect to a file,
  record `$?` to a file, read that file).

#### HARD CONSTRAINTS for this chunk

1. **Do not edit `docs/current_plan_surfing_pikachu.md` or any other plan or doc
   file.** Report your results; the root session records them and ticks boxes.
2. **Do not touch any of these files** — other agents own them right now:
   `dos_port/src/engine/events/diploma.asm`,
   `dos_port/src/engine/events/diploma2.asm`,
   `dos_port/tools/generators/gen_diploma.py`,
   `dos_port/src/engine/events/try_pikachu_movement.asm`,
   anything under `dos_port/src/engine/pikachu/`,
   anything under `dos_port/src/scripts/`.
3. **Do not commit and do not push.** Leave the work in the worktree.
4. **Do not translate `engine/minigame/surfing_pikachu.asm` in this chunk.** That
   is chunk 2. Creating `dos_port/src/engine/minigame/surfing_pikachu.asm` is
   out of scope here.
5. You **may and must** run `dos_port/tools/lint_pret_labels` (both modes) and
   `dos_port/tools/static_gate` — you are in your own worktree, so the
   `translation.db` you rescan is this tree's own file and there is no race.
   Report their counts.

#### Tasks

**T1.1 — WRAM symbols.** Add the `wSurfingMinigame*` block to
`dos_port/include/gb_memmap.inc`. Source of truth for the layout is pret
`ram/wram.asm:222-264` (`wSurfingMinigameData` … `wSurfingMinigameDataEnd`) plus
`ram/wram.asm:301-304` (`wLYOverrides`, `wLYOverridesEnd`, `wLYOverridesBuffer`,
`wLYOverridesBufferEnd`).

- **Addresses must be READ FROM `pokeyellow.sym`** in the worktree root (built by
  the root `make`), never inferred or computed. The precedent for this discipline
  is `dos_port/src/scripts/summer_beach_house.asm:56-59` ("Addresses are
  rgblink's, read from pokeyellow.sym — not inferred").
- Three of these symbols already exist in `gb_memmap.inc` (`:91-95`):
  `wSurfingMinigamePikachuHP`, `wSurfingMinigameTotalScore`,
  `wSurfingMinigameTrickFlags`. **Verify each against `pokeyellow.sym`.** If one
  disagrees, that is a finding — report it, correct it, and say so. Do not
  create a duplicate definition.
- `wLYOverridesEnd` is missing (`wLYOverrides` and `wLYOverridesBuffer` exist at
  `:1302-1307`). Add it.
- Update the stale comment at `gb_memmap.inc:1271-1273` which says the block is
  "not modelled here, the port has no surfing minigame yet".
- `wPikachuMapScriptFlags` (0xD492) is currently defined locally inside
  `dos_port/src/scripts/summer_beach_house.asm`. **Do not touch that file.** Add
  the symbol to `gb_memmap.inc` only if it does not already exist there; if
  adding it would shadow the script-local `equ`, report the collision and leave
  `gb_memmap.inc` without it, noting it for the root.

**T1.2 — Animated-object staging region.** The minigame's animated-object engine
reads its tables through *GB* pointers: `wAnimatedObjectSpawnStateDataPointer`,
`wAnimatedObjectOAMDataPointer`, `wAnimatedObjectFramesDataPointer` are 16-bit GB
addresses (`dos_port/src/engine/gfx/animated_objects.asm:125`), while
`wAnimatedObjectJumptablePointer` holds a 32-bit host pointer.

Follow the **exact** existing precedent, which is the Yellow intro:
`W_INTRO_ANIM_DATA` / `W_INTRO_FRAMES_DATA` / `W_INTRO_OAM_DATA` /
`W_INTRO_SPAWN_DATA` in `dos_port/include/gb_memmap.inc:1293-1298`, with the
tables assembled at `dos_port/src/data/sprite_anims/intro_frames.asm` and
`intro_oam.asm` (read both — they show the `GBPTR(l)` pre-bias macro and the
`times`-based size assertion pattern) and copied flat→GB at init by
`CopyYellowIntroAnimatedObjectData` (`dos_port/src/engine/movie/intro_yellow.asm:841`).

Do the same for the minigame:

- Reserve `W_SURF_ANIM_DATA` and derive `W_SURF_FRAMES_DATA` /
  `W_SURF_OAM_DATA` in `gb_memmap.inc`, in a region that does not overlap
  anything else. **Prove non-overlap** — run `dos_port/tools/audit_memmap.py`
  and report its output. Do not guess at free space.
- Create `dos_port/src/data/sprite_anims/surfing_pikachu_frames.asm` and
  `dos_port/src/data/sprite_anims/surfing_pikachu_oam.asm`, mirroring pret
  `data/sprite_anims/surfing_pikachu_frames.asm` and
  `data/sprite_anims/surfing_pikachu_oam.asm`, with internal `dw` pointers
  pre-biased through a `GBPTR(l)` macro exactly as `intro_oam.asm` does.
  Keep the pret label names `SurfingPikachuFrames` and `SurfingPikachuOAMData`.
- **Do not** write the flat→GB copy routine here. That belongs to the minigame
  file in chunk 2.

**T1.3 — Tier-1 generator for the minigame's graphics and tilemaps.**

Create `dos_port/tools/generators/gen_surfing_pikachu.py` emitting
`dos_port/assets/surfing_pikachu.inc`, and wire it into the Makefile `assets`
target and the consuming object's prerequisites. Model it on the existing
generators (`dos_port/tools/generators/gen_all_assets.py` handles
`gfx/sprites/surfing_pikachu.2bpp` at line 417 — read it for the file format and
header conventions).

It must emit these eight blobs, byte-for-byte from the read-only pret sources:

| pret label | source file | size (bytes) |
|---|---|---|
| `SurfingPikachu1Graphics1` | `gfx/surfing_pikachu/surfing_pikachu_1a.2bpp` | 1040 |
| `SurfingPikachu1Graphics2` | `gfx/surfing_pikachu/surfing_pikachu_1b.2bpp` | 4096 |
| `SurfingPikachu1Graphics3` | `gfx/surfing_pikachu/surfing_pikachu_1c.2bpp` | 2224 |
| `SurfingMinigame_BeachIntroTilemap` | `gfx/surfing_pikachu/beach_intro.tilemap` | 240 |
| `SurfingMinigame_UseControlPadTilemap` | `gfx/surfing_pikachu/use_control_pad.tilemap` | 15 |
| `SurfingMinigame_ToSurfRadTilemap` | `gfx/surfing_pikachu/to_surf_rad.tilemap` | 13 |
| `SurfingMinigame_TitleTilemap` | `gfx/surfing_pikachu/title.tilemap` | 72 |
| `SurfingMinigame_DrawResultsScreen.BeachOutroTilemap` | `gfx/surfing_pikachu/beach_outro.tilemap` | 200 |

Emit an `…End` label after each, matching pret. **Assert the sizes in the
generator** (pret asserts `beach_intro == 12 * SCREEN_WIDTH` = 240 and
`title == 6 * 12` = 72; reproduce those assertions in Python so a source change
fails loudly). The beach-outro blob is a local label inside a routine in pret —
emit it under a plain, pret-derived name such as `SurfingMinigame_BeachOutroTilemap`
and note the rename in your report; chunk 2 will reference it.

The two `gfx/surfing_pikachu/high_score_*.tilemap` files belong to the printer
path and are **out of scope** — do not emit them.

**Carrier files.** `SurfingPikachu1Graphics1..3` are pret `gfx/surfing_pikachu.asm`
labels, so their carrier is the mirror path
`dos_port/src/gfx/surfing_pikachu.asm` — create it, with an explicit
`section .data`, `global`s for the three labels, and `%include "assets/surfing_pikachu.inc"`.
(There is no `dos_port/src/gfx/` directory yet; create it. Add the new `.o` to
the Makefile's check-only tier for now — chunk 3 links it.) The four tilemap
labels belong to `engine/minigame/surfing_pikachu.asm`, which does not exist
yet; leave them in the same generated `.inc` and note in your report that
chunk 2 must `%include` it.

**T1.4 — `RedrawRowOrColumn`.** Translate pret `home/vcopy.asm:RedrawRowOrColumn`
(and any pret label it needs) into its mirror `dos_port/src/home/vcopy.asm`.
Read that file's header comment first — it currently lists `RedrawRowOrColumn`
among routines *not* ported; update that comment as part of the change.

This is a pure GB-memory operation in the port (there is no VRAM/CPU
contention), so translate it **literally**: copy tiles from
`wRedrawRowOrColumnSrcTiles` to the GB address in
`hRedrawRowOrColumnDest`/`+1`, mode from `hRedrawRowOrColumnMode`
(`H_REDRAW_ROW_COL_MODE equ 0xFFD0`, `H_REDRAW_ROW_COL_DEST equ 0xFFD1` already
exist in `gb_memmap.inc:964-965`; the mode constants are at `:1734`). Preserve
pret's mod-32 row/column wrap arithmetic exactly. Drive it from the `DelayFrame`
pipeline in `dos_port/src/home/vblank.asm` at the point pret's VBlank handler
calls it, gated exactly as pret gates it (`hRedrawRowOrColumnMode` nonzero).

**T1.5 — generic `VBlankCopy`.** Translate pret `home/vcopy.asm:VBlankCopy` (the
`hVBlankCopySource` / `hVBlankCopyDest` / `hVBlankCopySize` transfer) into
`dos_port/src/home/vcopy.asm` and drive it from `DelayFrame` the same way. The
existing `VBlankCopyBgMap` (`dos_port/src/home/vcopy.asm:81-150`) is the model
for the port's driving pattern — read it, including its "low byte doubles as the
enable byte" gate note.

**This retires two recorded deviations.** After it works, **delete** the
`DEVIATION{}` annotations at `dos_port/src/engine/movie/intro_yellow.asm:418`
and `:527` and their explanatory text, since the claim they make ("the port has
no generic VBlank tile copy") becomes false. Do not delete the surrounding
faithful code.

⚠ **This is the one task in this chunk that changes existing behaviour**: those
two intro sites begin transferring, so the Yellow intro's cloud tiles and
LY-wave tiles start animating. **Run the full golden suite and report exactly
which scenarios move, with names.** Do not re-bless, re-record, or "fix" any
golden. If scenarios move, report and stop — the root decides.

**T1.6 — per-scanline BG Y-displacement channel.** Add to
`dos_port/src/ppu/ppu.asm`, modelled *precisely* on the existing per-row X
channel (`g_row_xoff` / `g_row_xoff_on`, declared at `:327` and `:403-407`,
consumed at `:705-707`):

```nasm
global g_row_yoff_on
g_row_yoff_on: dd 0             ; 0 = off (identity fast path)
global g_row_yoff
g_row_yoff:    resb RENDER_H    ; signed per-screen-row window source-Y displacement
```

Consume it in **`render_window`'s fine path only**, at `.fine_row`
(`dos_port/src/ppu/ppu.asm:1673-1712`), where the source line is currently:

```nasm
    mov edx, [win_line_ctr]
    add edx, [win_src_y]
    and edx, 255                        ; src_y
```

Add, when `g_row_yoff_on` is nonzero, the signed byte `g_row_yoff[ECX]` — where
ECX is the *screen* scanline counter, not WLY — before the `and edx, 255`. Use
`movsx` (this is a signed displacement) and keep the mask at 255 so the GB's
mod-256 wrap is preserved.

Requirements, all hard:

- **Default is the exact semantic identity.** With `g_row_yoff_on == 0` the code
  path, the pixels, and the instruction count of every existing screen must be
  unchanged. Take the branch *outside* the hot inner work, as the X channel does.
- **Ownership follows the `g_row_xoff` / `g_obj_clip` model**: only code that
  needs non-default behaviour sets, owns and restores it. Document that in a
  comment at the declaration.
- **The `win_last_row` decode cache** (`:1682-1690`) is keyed on the tile row;
  a per-scanline displacement makes it miss more often. That is correct, not a
  bug — but **measure the cost**. Build with `DEBUG_PERF`, run
  `dos_port/tools/perf_capture.sh`, and report `render_window` ms/frame with the
  channel off (must be unchanged) and with it armed to a synthetic sine over a
  full-screen `GB_TILEMAP0` window. State the numbers; do not estimate them.
- Do **not** wire it to `hLCDCPointer` or `wLYOverrides` in this chunk. That is
  chunk 3's job. This chunk delivers the channel and proves it inert by default.

#### Verification you must run, and the evidence you owe

Run each, redirect to a file, record `$?` to a file, and read that file — never
pipe a gate into `tail`.

```sh
cd /mnt/sdb1/Code/Active Code/pokeyellow_msdos-surf

# per-file assembly (the -I flags and -D are required; a bare nasm fails)
cd dos_port && nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 -o /dev/null src/home/vcopy.asm
cd dos_port && nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 -o /dev/null src/ppu/ppu.asm
cd dos_port && nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 -o /dev/null src/gfx/surfing_pikachu.asm
cd dos_port && nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 -o /dev/null src/data/sprite_anims/surfing_pikachu_frames.asm
cd dos_port && nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 -o /dev/null src/data/sprite_anims/surfing_pikachu_oam.asm

make -C dos_port assets
make -C dos_port -j24
objdump -t dos_port/src/ppu/ppu.o | grep -E 'g_row_yoff'
objdump -t dos_port/src/home/vcopy.o | grep -E 'RedrawRowOrColumn|VBlankCopy'
objdump -t dos_port/src/gfx/surfing_pikachu.o | grep -E 'SurfingPikachu1Graphics'
dos_port/tools/audit_memmap.py
dos_port/tools/lint_pret_labels                     # must exit 0
dos_port/tools/lint_pret_labels --no-scan --strict-claims
dos_port/tools/static_gate
dos_port/tools/faithdiff RedrawRowOrColumn
dos_port/tools/faithdiff VBlankCopy
make -C dos_port fidelity                           # core tier
make -C dos_port fidelity-full                      # full tier — REQUIRED for T1.5
```

Notes on the gates: `make -C dos_port fidelity` (core, ~16 scenarios, ~30 s) and
`fidelity-full` (~85 scenarios, ~370 s) both run **in parallel**. Do **not** use
`fidelity-serial` / `fidelity-full-serial`. `pgate.sh` exits non-zero on any gap
and names every scenario that never reported — judge the run by its **exit
status**, not by PASS/FAIL counts, because a scenario that never ran emits
neither. Do not edit sources while a suite is running.

**Report, explicitly:**

1. Every file you created or modified, with a one-line reason each.
2. The `pokeyellow.sym` addresses you used for the `wSurfingMinigame*` block, and
   whether the three pre-existing definitions agreed.
3. `audit_memmap.py` output proving `W_SURF_*` overlaps nothing.
4. Byte sizes of all eight generated blobs, and confirmation each matches the
   table above.
5. `lint_pret_labels` exit code and violation count; `--strict-claims` counts by
   class; `static_gate` exit code.
6. `faithdiff` output for `RedrawRowOrColumn` and `VBlankCopy`, with a
   justification for **every** unsuppressed added or dropped call.
7. `fidelity` and `fidelity-full` **exit statuses**, and — for `fidelity-full` —
   the **names** of any scenario that changed state, with your reading of why.
8. `DEBUG_PERF` `render_window` ms/frame, channel off vs armed.
9. Anything you could not do faithfully, stated as a gap.

Do not commit. Do not push. Do not edit the plan file.

---

### 4.2 CHUNK 2 SPEC — Translate `engine/minigame/surfing_pikachu.asm` (check-only)

> Hand everything from here to the end of §4.2 to the agent, verbatim.

---

**You are implementing chunk 2 of 3 of a port task. Read this whole spec before
touching anything. Do exactly what it says and nothing more.**

#### Preconditions (verify before you start; if any fails, stop and report)

Chunk 1 has landed in this worktree. Confirm:

```sh
cd /mnt/sdb1/Code/Active Code/pokeyellow_msdos-surf
grep -c wSurfingMinigame dos_port/include/gb_memmap.inc      # must be >= 30
grep -n 'W_SURF_' dos_port/include/gb_memmap.inc             # must exist
ls dos_port/assets/surfing_pikachu.inc                       # must exist
ls dos_port/src/data/sprite_anims/surfing_pikachu_oam.asm    # must exist
objdump -t dos_port/src/home/vcopy.o | grep -E 'RedrawRowOrColumn|VBlankCopy'
objdump -t dos_port/src/ppu/ppu.o | grep g_row_yoff
```

#### Environment

Worktree `/mnt/sdb1/Code/Active Code/pokeyellow_msdos-surf`, branch
`surfing-pikachu`. Register with stigmergy using `agent_kind: "antigravity"` and
`context_open` on the **main** repo path
`/mnt/sdb1/Code/Active Code/pokeyellow_msdos` (not the worktree path).
`DOSBOX_MCP_SOCKET=/tmp/dosbox-mcp-surf.sock`.

#### Project context you must honour

This is a from-scratch port of Pokémon Yellow (Game Boy) to MS-DOS in 32-bit x86
NASM (386+, protected mode, DJGPP/COFF). The pret disassembly at the repository
root is **read-only specification**. Read `CLAUDE.md` before you start. Binding
rules:

- **Preserve pret label names verbatim** — every routine, jump target, local
  label (`.loop`, `.copyRow`) and data label keeps pret's exact name.
- **pret behaviour is the specification.** Translate instruction for
  instruction. A sequence that reads like an oversight is usually load-bearing;
  "tidying" it changes the game.
- **A pret-labeled routine lives in its MIRROR path.** All 175 labels of pret
  `engine/minigame/surfing_pikachu.asm` go in exactly one file:
  `dos_port/src/engine/minigame/surfing_pikachu.asm`. Do not split them out.
- **Text and graphics are Tier-1 DATA** produced by a Python generator into
  `dos_port/assets/*.inc`. Chunk 1 already generated
  `dos_port/assets/surfing_pikachu.inc` — `%include` it. Never hand-write graphic
  or charmap bytes.
- **Link-time stand-ins go in `src/<area>/<area>_stubs.asm`** under the exact
  pret label. (You should not need any in this chunk — see the externs task.)
- **Do not add zero-guards pret lacks, and do not widen its counters.** pret's
  `dec c / jr nz` entered with C=0 runs 256 times and stops; `movzx ecx, cl /
  dec ecx / jnz` runs ~4 billion and page-faults. Translate an 8-bit pret
  counter as an 8-bit x86 counter (`dec cl`). Adding `test cl,cl / jz` writes 0
  items where the GB writes 256 — that is a behavioural divergence, not a safety
  fix, and it would need a `DEVIATION`.
- **Preserve the exact ZF/CF a `jr z`/`jr c` reads.** `mov`/`lea`/`movzx` do not
  touch flags; `inc`/`dec` preserve CF but clobber ZF; `cmp`/`test`/`and`/`or`/
  `add`/`sub` set flags. `jr z/nz` → `jz/jnz`; `jr c/nc` → `jb/jae` (SM83 `cp`
  is unsigned).
- **`movzx` vs `movsx` is looked up, not inferred.** GB values are unsigned
  (`movzx`) unless the quantity is itself signed — `jr` displacements, sprite and
  screen deltas, signed distances. Width and compare signedness are one decision.
- **GB data is big-endian.**
- Register map: A→AL, BC→BX, DE→DX, HL→ESI, EBP = emulated-GB-memory base;
  GB memory is `[ebp + SYMBOL]` from `dos_port/include/gb_memmap.inc`.
- `%include` by **bare filename** (`%include "gb_memmap.inc"`) — the Makefile
  assembles with `-I include/ -I .` from `dos_port/`.
- **Any new linker section name must be in `dos_port/link.ld` first.** Prefer
  `.data`/`.text`. Always write an explicit `section` directive before a
  `global`'d data block (NASM COFF emits a `global` in the implicit section as an
  undefined external).
- **VRAM tile writes must invalidate the tile cache** — route through
  `CopyVideoData` or set `mov byte [g_tilecache_dirty], 1`. **OBJ/sprite tiles
  are not exempt.** `FarCopyData` into `vChars0`/`vChars2` counts.
- **A stated gap beats a wrong lowering.** If you cannot do something faithfully,
  leave it correct-as-far-as-it-goes, annotate it, and say so precisely.
- Annotation format, one line, no `;` or `}` inside a value:
  `; DEVIATION{class=<HAL|banking|projection|data-model|timing|stub|temporary>; pret=<file>:<Label>; behavior=…; evidence=…; lifetime=…}`
  Kinds are exactly `DEVIATION`, `BUG`, `GLITCH`, `STUB`.
- Shell is **zsh**: quote globs, `$pipestatus` is 1-indexed, never pipe a gate
  into `tail` — redirect, record `$?` to a file, read the file.

#### HARD CONSTRAINTS for this chunk

1. **Do not edit `docs/current_plan_surfing_pikachu.md` or any other plan or doc
   file.** Report your results; the root records them and ticks boxes.
2. **Do not touch:** `dos_port/src/engine/events/diploma.asm`,
   `dos_port/src/engine/events/diploma2.asm`,
   `dos_port/tools/generators/gen_diploma.py`,
   `dos_port/src/engine/events/try_pikachu_movement.asm`,
   anything under `dos_port/src/engine/pikachu/`,
   anything under `dos_port/src/scripts/`.
3. **Do not commit and do not push.**
4. **The new file is CHECK-ONLY.** Add it to a new `MINIGAME_CHECK_SRCS` list in
   `dos_port/Makefile` and fold that into `ALL_SRCS` (see line 2777 —
   `ALL_SRCS := $(LINK_SRCS) $(BATTLE_SRCS) $(POKEMON_CHECK_SRCS) …`). **Do not
   add it to `LINK_SRCS`.** Two of its externals do not exist yet; linking it
   would break the build. Chunk 3 links it.
5. You **may and must** run `dos_port/tools/lint_pret_labels` (both modes) and
   `dos_port/tools/static_gate` — you are in your own worktree.

#### The task

Translate **all 175 top-level labels** of pret
`engine/minigame/surfing_pikachu.asm` (2877 lines) into
`dos_port/src/engine/minigame/surfing_pikachu.asm`.

##### Dependency situation (already measured — do not re-derive)

89 distinct callees; 61 are internal to the file. Of the 28 external symbols,
**26 already exist in the port** and you simply `extern` them (each `extern`'s
trailing comment must name the file that currently provides it):

`ClearObjectAnimationBuffers`, `ClearSprites`, `CopyData`, `DelayFrame`,
`DisableLCD`, `FarCopyData`, `FillMemory`, `GBPalNormal`, `Joypad`,
`MaskCurrentAnimatedObjectStruct`, `PlayDefaultMusic`, `PlayMusic`,
`PlayPikachuSoundClip`, `PlaySound`, `Random`, `RunDefaultPaletteCommand`,
`RunObjectAnimations`, `RunPaletteCommand`,
`SetCurrentAnimatedObjectCallbackAndResetFrameStateRegisters`,
`SpawnAnimatedObject`, `UpdateCGBPal_BGP`, `UpdateCGBPal_OBP0`,
`UpdateCGBPal_OBP1`, `WaitForSoundToFinish`, plus chunk 1's
`RedrawRowOrColumn` and `VBlankCopy`.

Confirm each with `dos_port/tools/label_status <Label>` before use.

**Two are missing and you must NOT create them in this chunk:**
`IsSurfingStarterPikachuInParty` (pret `engine/pikachu/pikachu_status.asm:183` —
its mirror is under `dos_port/src/engine/pikachu/`, which you are forbidden to
touch) and `ReloadMapAfterSurfingMinigame` (pret `home/overworld.asm:1991`).
`extern` both, with a trailing comment saying `; NOT YET DEFINED — chunk 3`.
The file is check-only, so the unresolved externs are harmless.

**Two are out of scope permanently:** `PrintSurfingMinigameHighScore` and
`Printer_PrepareSurfingMinigameHighScoreTileMap` are printer-path. They are not
called from this pret file — do not add externs or stubs for them.

##### Data

`%include "assets/surfing_pikachu.inc"` for the graphics and tilemap blobs
generated in chunk 1. Do not re-derive or hand-write any of those bytes. The
label pret writes as the routine-local `.BeachOutroTilemap` is emitted by the
generator under a top-level name — check the `.inc` for its exact spelling and
reference that, with a comment noting pret's local-label form.

`SurfingPikachuObjectSpawnData` and `SurfingPikachuObjectCallbacks` are defined
*inside* this pret file — translate them here, in this file.

`SurfingPikachuFrames` and `SurfingPikachuOAMData` were mirrored in chunk 1 at
`dos_port/src/data/sprite_anims/surfing_pikachu_{frames,oam}.asm` — `extern`
them.

##### Animated-object pointer model (get this right or nothing animates)

The engine reads three of the four pointers as **GB addresses**, one as a host
pointer. Copy the intro's model exactly
(`dos_port/src/engine/movie/intro_yellow.asm:116-119` and its flat→GB staging
copy at `:841`):

```nasm
    mov word  [ebp + wAnimatedObjectSpawnStateDataPointer], W_SURF_SPAWN_DATA   ; GB ptr
    mov word  [ebp + wAnimatedObjectOAMDataPointer],        W_SURF_OAM_DATA     ; GB ptr
    mov word  [ebp + wAnimatedObjectFramesDataPointer],     W_SURF_FRAMES_DATA  ; GB ptr
    mov dword [ebp + wAnimatedObjectJumptablePointer],      SurfingPikachuObjectCallbacks  ; HOST ptr
```

Write the flat→GB staging copy for the frames/OAM tables into this file, at the
point pret's `SurfingPikachuLoop` sets those pointers, modelled on
`CopyYellowIntroAnimatedObjectData`. Give it a descriptive port-only name (it has
no pret counterpart) and say so in a comment.

##### THE `SCREEN_WIDTH` ROLE-SPLIT AUDIT — do this site by site, do not judge case by case

`SCREEN_WIDTH` means **20** in pret and **40** in the port
(`dos_port/include/gb_memmap.inc:1680`). The same identifier is a row **stride**
in some places (must become the port's 40) and an **extent** in others (must stay
pret's 20-derived value). Getting this wrong walks a draw loop diagonally off
canvas instead of failing loudly.

**The rule:** a quantity that indexes `wTileMap` is a port quantity (stride 40,
`SCREEN_AREA` 1000, coordinates via `BCOORD`). A quantity that is a GB pixel
coordinate, a GB LY index, or the length of a GB-sized array is a **pret literal**
and stays.

Here is the complete audit, already worked. Reproduce it exactly; if you find a
site not listed, stop and report it rather than guessing.

| pret line | expression | role | port |
|---|---|---|---|
| 2 | `SCREEN_WIDTH_PX / 2 + OAM_X_OFS` | GB **OAM X** coordinate | keep pret (160/2+8) — OAM is published in GB space and projected by the compositor |
| 53, 2369 | `ld a, SCREEN_HEIGHT_PX` → `hWY` | park window below screen | port canvas: `RENDER_H` (200), or call `hide_window` |
| 260 | `ld bc, SCREEN_WIDTH` (fill `wSurfingMinigameWaveHeight`) | **array length** (`ds SCREEN_WIDTH` = 20 in pret wram) | keep **20** |
| 1453, 2404, 2545 | `ld bc, SCREEN_AREA` (fill `wTileMap`) | canvas extent | port `SCREEN_AREA` (**1000**) |
| 1458 | `decoord 0, 6` + `CopyData` of 200-byte beach-outro | **STRIDE TRAP** — pret copies 10 rows × 20 as one linear run | copy **row by row**: 20 bytes per row, destination advancing by port `SCREEN_WIDTH` (40), starting at `BCOORD(0,6)` |
| 1516 | `ld c, SCREEN_WIDTH - 4` box interior width | **extent** | keep **16**; keep the counter 8-bit (`dec cl`) |
| 1904 | `ld c, SCREEN_WIDTH - 2` (shift `wSurfingMinigameWaveHeight`) | **array length - 2** | keep **18**; 8-bit counter |
| 2410 | `ld bc, 12 * SCREEN_WIDTH` + `decoord 0, 6` (beach-intro) | **STRIDE TRAP** — 12 rows × 20 | copy **row by row**, 20 bytes/row, dest stride 40, from `BCOORD(0,6)` |
| 2417 | `lb bc, 3, SCREEN_WIDTH - 5` | rows=3, **extent** width=15 | keep **15** |
| 2439 | `ld bc, SCREEN_WIDTH` in `.CopyBox` row advance | **STRIDE** | port **40** |
| 2457 | `ld bc, SCREEN_WIDTH` in `.FillBoxWithFF` row advance | **STRIDE** | port **40** |
| 2466 | `ASSERT … == 12 * SCREEN_WIDTH` | asset size assertion | already enforced in chunk 1's generator (240 bytes); drop the `ASSERT`, note it |
| 2478 | `ld c, SCREEN_HEIGHT_PX - 2 * TILE_HEIGHT` (`SurfingMinigame_UpdateLYOverrides`) | **GB LY count** (the override buffer is GB-scanline-indexed) | keep **128**; 8-bit counter |
| 2630 | `cp SCREEN_HEIGHT_PX` | GB pixel-Y comparison | keep **144** |

##### The coordinate macros

- **`hlcoord` / `decoord` / `bccoord`** target `wTileMap` at stride 40. There are
  **16** `hlcoord` sites (pret lines 1475, 1479, 1483, 1487, 1491, 1495, 1499,
  1503, 1507, 1573, 1637, 1640, 1668, 1671, 2413, 2416) and **8** `decoord`
  sites (1458, 1526, 1537, 1591, 1684, 2409, 2420, 2424). Every one of these
  is **PROJECTED: +10 columns, +3 rows**, using the existing `BCOORD(X, Y)`
  macro from `dos_port/include/coords.inc:155`
  (`wTileMap + ((Y)+3) * SCREEN_WIDTH + ((X)+10)`). Do not re-derive the
  transform and do not widen any layout. Only the coordinate *values* move; every
  write through them is pret's.
- **`hlbgcoord` / `debgcoord`** target the GB tilemap at stride 32 and are
  **VERBATIM — no projection.** The port models `GB_TILEMAP0` ($9800) and
  `GB_TILEMAP1` ($9C00) 1:1 (`dos_port/include/coords.inc:102-131`,
  `dos_port/include/gb_memmap.inc:46-47`). The 5 `hlbgcoord` sites (pret lines
  230, 358, 360, 362, 364) and 1 `debgcoord` site (349) translate straight
  across, including their `vBGMap1` third argument.

##### Hardware boundaries — what to translate literally and what not

- **`rBGP` / `rOBP0` / `rOBP1` are LIVE.** `ldh [rBGP], a` is a literal
  `mov [ebp + IO_BGP], al` — `commit_palette` picks it up from `DelayFrame`. No
  `TODO-HW`, no deviation. `UpdateCGBPal_*` calls stay as calls.
- **`rSCX` / `rSCY` are live via their SHADOWS.** pret already writes `hSCX` /
  `hSCY` here — translate those literally to `[ebp + hSCX]` / `[ebp + hSCY]`.
  Never write `IO_SCX`/`IO_SCY` directly; `commit_shadow_regs` overwrites them
  each `DelayFrame`.
- **The APU is a virtual APU**, not a hardware boundary. Translate every audio
  register and `wMusicTempo` write literally.
- **`wMusicTempo` byte order:** pret's `.Tempos` table is RGBDS `dw`
  (little-endian) but `wMusicTempo` is big-endian, which is why pret stores
  `[hli]` into `wMusicTempo + 1` and `[hl]` into `wMusicTempo`
  (pret lines 147-151). Reproduce the byte **destinations**, not the source
  layout. `wMusicTempo equ 0xC0E8 ; dw, stored hi-then-lo` and the engine reads
  it big-endian (`dos_port/src/audio/engine_1.asm:639-640`).
- **`rLY` / `rSTAT` are INERT** — nothing in the port writes them and nothing
  spins on them. Translate `ldh [rSTAT], a` as a plain store to the emulated
  register and carry a `DEVIATION{class=HAL; …}` on the site saying the STAT
  H-blank interrupt is not emulated and the per-scanline effect is delivered by
  the compositor instead. **Do not write a spin loop on `rLY` or `rSTAT`** — it
  would hang.
- **`hLCDCPointer` and `wLYOverrides`:** translate every write **faithfully**
  (the bytes are the input to chunk 3's compositor channel). Carry one
  `DEVIATION{class=HAL; …}` in this file stating that nothing consumes them yet
  and naming chunk 3 in `lifetime=`. Model the wording on the existing example at
  `dos_port/src/engine/movie/intro_yellow.asm:335`.
- **`rIE` / `rIF` / `hTileAnimations` / `wUpdateSpritesEnabled`
  save-modify-restore** in `SurfingPikachuMinigame` (pret lines 22-32, 62-72):
  translate literally. `hTileAnimations` and `wUpdateSpritesEnabled` are live in
  the port.
- **`FarCopyData` into `vChars0` / `vChars2`** (pret lines 193-204, 2341-2344)
  writes VRAM tile patterns. `FarCopyData` is **not** `CopyVideoData` — verify
  whether the port's `FarCopyData` arms `g_tilecache_dirty`. If it does not,
  set `mov byte [g_tilecache_dirty], 1` explicitly at each such site (extern it
  from `src/ppu/ppu.asm`) and say so in your report. Getting this wrong renders
  the *previous* occupants of those tile slots.

##### Presentation is NOT your job

This chunk translates the pret code. It does **not** set up window descriptors,
`g_bg_whiteout`, `g_obj_clip`, `g_obj_over_window`, or `g_row_yoff`. Chunk 3
does that in a separate port-only glue routine. Translate `rLCDC` /
`hWY` / `hSCX` writes faithfully as GB-register stores and leave it there.

#### Verification you must run, and the evidence you owe

Redirect each to a file, record `$?` to a file, read that file. Never pipe a gate
into `tail`.

```sh
cd /mnt/sdb1/Code/Active Code/pokeyellow_msdos-surf/dos_port
nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 -o /dev/null src/engine/minigame/surfing_pikachu.asm
cd /mnt/sdb1/Code/Active Code/pokeyellow_msdos-surf
make -C dos_port -j24
objdump -t dos_port/src/engine/minigame/surfing_pikachu.o > /tmp/surf_syms.txt
dos_port/tools/lint_pret_labels                     # must exit 0
dos_port/tools/lint_pret_labels --no-scan --strict-claims
dos_port/tools/static_gate
dos_port/tools/faithdiff SurfingPikachuMinigame
dos_port/tools/faithdiff SurfingPikachuLoop
dos_port/tools/faithdiff SurfingPikachuMinigame_LoadGFXAndLayout
dos_port/tools/faithdiff SurfingMinigame_UpdateMusicTempo
dos_port/tools/faithdiff SurfingMinigame_ReadBGMapBuffer
dos_port/tools/faithdiff RunSurfingMinigameRoutine
make -C dos_port fidelity                           # must be unchanged: nothing is linked yet
```

`fidelity` runs in parallel via `pgate.sh`; judge it by **exit status**, not by
PASS/FAIL counts. Do not use `fidelity-serial`.

**Report, explicitly:**

1. **Symbol accounting: a count of top-level pret labels defined in your `.o`,
   against the 175 in the pret file, and an explicit list of any not defined.**
   "All present" without the decomposition is not evidence.
2. The `SCREEN_WIDTH` audit table above, filled in with what you actually did at
   each site, plus any site you found that is not in the table.
3. Every `hlcoord`/`decoord` site with its `BCOORD` result, and confirmation that
   all `hlbgcoord`/`debgcoord` sites went across verbatim.
4. Every `DEVIATION`/`BUG`/`GLITCH`/`STUB` annotation you wrote, verbatim.
5. Whether `FarCopyData` arms `g_tilecache_dirty`, with file:line evidence, and
   what you did about it.
6. Every 8-bit pret counter you translated, and confirmation you kept it 8-bit.
   Name any site where you judged a count can be zero on entry.
7. `lint_pret_labels` exit code and violation count; `--strict-claims` counts by
   class; `static_gate` exit code.
8. All six `faithdiff` outputs, with a justification for **every** unsuppressed
   added or dropped call.
9. `make -C dos_port fidelity` exit status.
10. Anything you could not do faithfully, stated as a gap. A stated gap beats a
    wrong lowering.

Do not commit. Do not push. Do not edit the plan file.

---

### 4.3 CHUNK 3 SPEC — Presentation, the two missing externals, link, and runtime gate

> Hand everything from here to the end of §4.3 to the agent, verbatim.

---

**You are implementing chunk 3 of 3 of a port task. Read this whole spec before
touching anything. Do exactly what it says and nothing more.**

#### Preconditions (verify before you start; if any fails, stop and report)

```sh
cd /mnt/sdb1/Code/Active Code/pokeyellow_msdos-surf
ls dos_port/src/engine/minigame/surfing_pikachu.asm          # chunk 2 landed
objdump -t dos_port/src/ppu/ppu.o | grep g_row_yoff          # chunk 1 landed
objdump -t dos_port/src/home/vcopy.o | grep -E 'RedrawRowOrColumn|VBlankCopy'
grep -n MINIGAME_CHECK_SRCS dos_port/Makefile                # still check-only
```

**Ask the dispatching session to confirm that `dos_port/src/engine/pikachu/` has
been released by the other workstream before you begin.** If it has not, do
tasks T3.1 and T3.3–T3.6 and report T3.2 as blocked — do not edit a file another
agent owns.

#### Environment

Worktree `/mnt/sdb1/Code/Active Code/pokeyellow_msdos-surf`, branch
`surfing-pikachu`. Register with stigmergy using `agent_kind: "antigravity"` and
`context_open` on the **main** repo path
`/mnt/sdb1/Code/Active Code/pokeyellow_msdos` (not the worktree path).
`export DOSBOX_MCP_SOCKET=/tmp/dosbox-mcp-surf.sock`; `run_with_mcp.sh` launches
from the **repo root**, not `dos_port/`.

#### Project context you must honour

Same as the previous chunks — read `CLAUDE.md` at the repo root. Binding rules:
preserve pret label names verbatim; a pret-labeled routine lives in its mirror
path; text and graphics are Tier-1 generated data, never hand-written bytes;
link-time stand-ins go in `src/<area>/<area>_stubs.asm` under the exact pret
name; do not add zero-guards pret lacks and do not widen its counters (an 8-bit
pret counter stays 8-bit — a zero-guard writes 0 where the GB writes 256, which
is a divergence, not a fix); preserve the exact ZF/CF a `jr z`/`jr c` reads;
register map A→AL, BC→BX, DE→DX, HL→ESI, EBP = GB memory base; GB data is
big-endian; a new linker section must be in `dos_port/link.ld` first and a
`global`'d data block needs an explicit `section` directive; VRAM tile writes
must arm `g_tilecache_dirty`; **a stated gap beats a wrong lowering.**
Annotations are one line, no `;` or `}` in a value, kinds exactly
`DEVIATION`/`BUG`/`GLITCH`/`STUB`, `class` one of
`HAL|banking|projection|data-model|timing|stub|temporary`. Shell is **zsh**:
quote globs, never pipe a gate into `tail` — redirect, record `$?` to a file,
read the file.

#### HARD CONSTRAINTS for this chunk

1. **Do not edit `docs/current_plan_surfing_pikachu.md` or any other plan or doc
   file.** Report your results; the root records them and ticks boxes.
2. **Do not touch:** `dos_port/src/engine/events/diploma.asm`,
   `dos_port/src/engine/events/diploma2.asm`,
   `dos_port/tools/generators/gen_diploma.py`,
   `dos_port/src/engine/events/try_pikachu_movement.asm`,
   anything under `dos_port/src/scripts/`. (`dos_port/src/engine/pikachu/` is
   conditionally released — see the preconditions.)
3. **Do not commit and do not push.**
4. You **may and must** run `dos_port/tools/lint_pret_labels` (both modes) and
   `dos_port/tools/static_gate` — you are in your own worktree.

#### Tasks

**T3.1 — `ReloadMapAfterSurfingMinigame`.** Translate pret
`home/overworld.asm:1991` into its mirror `dos_port/src/home/overworld.asm`.
That file is large and shared — insert the routine at the position matching its
pret neighbourhood, change nothing else in it, and add the `extern` comment
trail. Run `dos_port/tools/label_status --callees ReloadMapAfterSurfingMinigame`
first and report anything it needs that is missing.

**T3.2 — `IsSurfingStarterPikachuInParty`** (only if the preconditions cleared
`dos_port/src/engine/pikachu/`). Translate pret
`engine/pikachu/pikachu_status.asm:183` into its mirror
`dos_port/src/engine/pikachu/pikachu_status.asm`. Note the flag trap recorded for
that file: an `inc`/`dec` between a compare and its `jr z` destroys ZF — use
`lea esi,[esi+1]` where a live flag must survive. If the directory is still
owned by another agent, add a `STUB{}`-annotated `ret`-only stand-in under the
exact pret name in the pikachu subsystem's `*_stubs.asm` **only if** that stub
file is outside the forbidden directory; otherwise report T3.2 as blocked and
leave the extern unresolved (which means T3.4 cannot link — say so).

**T3.3 — presentation glue (port-only).** Write two port-only routines in
`dos_port/src/engine/minigame/surfing_pikachu.asm`, with descriptive port-only
names (they have no pret counterpart — say so in a comment), called from the
translated `SurfingPikachuMinigame` entry and exit.

The setup routine must:

- `mov dword [g_bg_whiteout], 1` — `render_bg` then paints a clean matte instead
  of the overworld. (`dos_port/src/ppu/ppu.asm:252-253`.)
- Publish **two window descriptors** in painter's order via `hide_window` then
  `add_window` (`dos_port/src/ppu/ppu.asm:1840-1885`; signature
  `EAX=wx, EBX=wy, ECX=clip_w, EDX=max_y, ESI=tilemap_base, EDI=start_row`):
  1. **BG plane** — `wx = 80 + 7`, `wy = 24`, `clip_w = 160`, `max_y = 168`,
     `tilemap = GB_TILEMAP0`, `start_row = 0`. This is the CENTER projection:
     the GB's 160x144 viewport centred in the port's 320x200 canvas
     (+80 px = +10 tiles, +24 px = +3 rows).
  2. **Status bar** — same `wx`, `wy = 24 + $7e`, `tilemap = GB_TILEMAP1`,
     `start_row = 0`, `clip_w = 160`, `max_y = 168`. (`$7e` is the `hWY` the
     translated code writes at pret line 246.)
- Each frame, before `render_window` runs, refresh the BG descriptor's
  `WIN_SRC_X` from `[ebp + hSCX]` and `WIN_SRC_Y` from `[ebp + hSCY]`. This
  selects `render_window`'s **fine** path, which performs the GB's mod-256 /
  mod-32 torus wrap (`dos_port/src/ppu/ppu.asm:1673-1712`) — exactly the
  behaviour an endlessly-scrolling water field needs. `add_window` zeroes the
  fine fields, so write them after appending.
- `mov dword [g_obj_over_window], 1` — the GB's hardware order (BG → window →
  OBJ), so Pikachu draws **over** the water. The port's default is the inverse.
  (`dos_port/src/ppu/ppu.asm:268-275`.)
- Set `g_obj_clip` to `(80, 24, 240, 168)` — upper bounds exclusive — so a GB
  OBJ that hardware would hide or edge-clip at the 160x144 boundary is hidden or
  clipped at the **projected** boundary instead of leaking into the widescreen
  matte. This is the same rectangle the cinematics use
  (`dos_port/src/ppu/ppu.asm:283-298`).
- Arm the per-scanline channel from chunk 1: set `g_row_yoff_on` **only when
  `[ebp + hLCDCPointer]` is nonzero** (that is pret's own enable), and each frame
  copy `wLYOverrides` into `g_row_yoff` with the projection applied — GB scanline
  `L` maps to screen row `L + 24`, and screen rows outside `[24, 168)` get 0.
  pret stores an absolute `rSCY` value per scanline; `g_row_yoff` is a *signed
  displacement*, so store `wLYOverrides[L] - hSCY` (wrapped to a signed byte).
  If that subtraction cannot be made to reproduce pret's wave faithfully, **stop
  and report it as a gap** rather than inventing a mapping.

The teardown routine must restore every one of the above to its default:
`g_bg_whiteout = 0`, `g_obj_over_window = 0`, `g_row_yoff_on = 0`,
`g_obj_clip` back to the whole canvas, `hide_window`. Note that `ClearSprites`
clears `g_obj_over_window` but deliberately does **not** reset `g_obj_clip` — a
leaked narrow clip rectangle visibly clips the next overworld frame's sprites and
fails the overworld goldens, so restore it explicitly.

Also call `SurfingMinigame_UpdateLYOverrides` at the point pret's frame loop
does, so the wave table actually advances.

**T3.4 — link the file.** Move
`dos_port/src/engine/minigame/surfing_pikachu.asm`,
`dos_port/src/gfx/surfing_pikachu.asm` and the two
`dos_port/src/data/sprite_anims/surfing_pikachu_*.asm` out of the check-only
tier and into the linked lists in `dos_port/Makefile` (`LINK_SRCS` is assembled
at line 2647 from `BOOT_SRCS`, `HOME_SRCS`, `HAL_SRCS`, `SAVE_SRCS`,
`AUDIO_SRCS`, `GAME_SRCS`, `POKEMON_SRCS`, `ITEMS_SRCS`, `FRONTEND_SRCS`,
`BATTLE_SUPPORT_SRCS`). Add the generated `assets/surfing_pikachu.inc` as a
prerequisite of the consuming `.o`s.

**T3.5 — runtime gate.** Add a `DEBUG_SURFING_PIKACHU` build gate that boots
straight into `SurfingPikachuMinigame`, following the existing `DEBUG_*` pattern
in `dos_port/Makefile` and `dos_port/src/debug/debug_dump.asm` (there are ~40
such gates already — read two or three, e.g. `DEBUG_BATTLE_INTRO`, and copy the
structure). It must set up whatever party/flag state the minigame reads
(`IsSurfingStarterPikachuInParty`, `wPikachuMapScriptFlags`) so the entry path is
actually taken.

**T3.6 — prove it draws.** Build with the gate, run under DOSBox-X, and capture
`FRAME.BIN` at (at minimum) the title screen, one in-game frame with the water
scrolling, and the results screen. Render them with
`dos_port/tools/render_frame.py`. Report what you see, honestly — including
anything wrong. A screenshot that shows a defect is a better result than a claim
that it works.

#### Verification you must run, and the evidence you owe

Redirect each to a file, record `$?` to a file, read that file.

```sh
cd /mnt/sdb1/Code/Active Code/pokeyellow_msdos-surf
make -C dos_port -j24
make -C dos_port DEBUG_SURFING_PIKACHU=1 -j24
objdump -t dos_port/pkmn.exe | grep -iE 'Surfing|ReloadMapAfterSurfingMinigame'
dos_port/tools/label_status --callers SurfingPikachuMinigame
dos_port/tools/lint_pret_labels                     # must exit 0
dos_port/tools/lint_pret_labels --no-scan --strict-claims
dos_port/tools/static_gate
dos_port/tools/faithdiff ReloadMapAfterSurfingMinigame
dos_port/tools/faithdiff IsSurfingStarterPikachuInParty
make -C dos_port fidelity
make -C dos_port fidelity-full
```

`fidelity` and `fidelity-full` run in **parallel** via `pgate.sh` — judge each by
its **exit status**, not by PASS/FAIL counts (a scenario that never ran emits
neither, which is how a run once read "61 PASS / 0 FAIL" while failing). Do not
use `fidelity-serial` / `fidelity-full-serial`. Do not edit sources while a suite
is running.

**Report, explicitly:**

1. Every file created or modified, with a one-line reason.
2. Whether T3.2 was done or blocked, and if blocked, exactly what is unresolved.
3. The two window descriptors as actually published (all six fields each), and
   the `g_obj_clip` rectangle.
4. The `wLYOverrides` → `g_row_yoff` mapping you implemented, including the sign
   convention, and whether it reproduces pret's wave. If it does not, say so
   plainly.
5. `lint_pret_labels` exit code and violation count; `--strict-claims` counts by
   class; `static_gate` exit code.
6. `faithdiff` output for both new routines, with a justification for every
   unsuppressed added or dropped call.
7. `fidelity` and `fidelity-full` **exit statuses**, and the **names** of any
   scenario that changed state.
8. Rendered `FRAME.BIN` descriptions for the three capture points, with defects
   named.
9. Anything you could not do faithfully, stated as a gap.

Do not commit. Do not push. Do not edit the plan file.

---

## 5. Root-side review gates (this is the box-ticking procedure)

Execution agents never tick a box. For each chunk the root re-runs the checks
itself in the worktree, and ticks only on the evidence below. A missing item is
a hold, not a rounding error.

### 5.1 Before ticking Stage 1 (chunk 1)

| Check | Pass looks like |
|---|---|
| `make -C dos_port -j24` | exit 0, zero `***` lines |
| `objdump -t dos_port/src/ppu/ppu.o \| grep g_row_yoff` | both `g_row_yoff` and `g_row_yoff_on` present |
| `objdump -t dos_port/src/home/vcopy.o \| grep -E 'RedrawRowOrColumn\|VBlankCopy'` | both defined |
| `dos_port/tools/audit_memmap.py` | `W_SURF_*` region overlaps nothing |
| Generated blob sizes | all eight match §4.1's table exactly, byte for byte |
| `wSurfingMinigame*` addresses | each traced to a `pokeyellow.sym` line; the three pre-existing definitions confirmed or corrected |
| `dos_port/tools/lint_pret_labels` | exit 0, **0** violations |
| `--no-scan --strict-claims` | **0** in every class |
| `dos_port/tools/static_gate` | exit 0 |
| `faithdiff RedrawRowOrColumn`, `faithdiff VBlankCopy` | every unsuppressed added/dropped call justified in the report |
| `make -C dos_port fidelity` | **exit 0** |
| `make -C dos_port fidelity-full` | **exit 0**, or a diff confined to the two named `intro_yellow` scenes with the root's explicit acceptance |
| `DEBUG_PERF` numbers | `render_window` ms/frame with the channel off is unchanged from baseline; armed cost is stated as a measured number |

**Reject if:** any golden was re-blessed or re-recorded; the identity default was
not proven; a blob size was reported as "correct" without its byte count; the
per-scanline hook was wired to `hLCDCPointer` (that is chunk 3).

### 5.2 Before ticking Stage 3 (chunk 2)

| Check | Pass looks like |
|---|---|
| `nasm … -o /dev/null src/engine/minigame/surfing_pikachu.asm` | exit 0 |
| `make -C dos_port -j24` | exit 0 |
| **Symbol accounting** | a *count* of top-level pret labels defined in the `.o` against the 175 in the pret file, plus an explicit list of any absent. **"All present" without the decomposition is not evidence** — reject it |
| `SCREEN_WIDTH` audit | every row of §4.2's table answered with what was actually written; any unlisted site reported rather than guessed |
| Coordinate audit | 16 `hlcoord` + 8 `decoord` sites projected through `BCOORD`; 5 `hlbgcoord` + 1 `debgcoord` sites verbatim |
| Counter audit | every 8-bit pret counter listed and confirmed 8-bit; **no** added zero-guard |
| `FarCopyData` / tile cache | the `g_tilecache_dirty` question answered with file:line evidence |
| Annotations | every one quoted verbatim; parses under `lint_pret_labels` |
| `dos_port/tools/lint_pret_labels` | exit 0, **0** violations |
| `--no-scan --strict-claims` | **0** in every class |
| `dos_port/tools/static_gate` | exit 0 |
| Six `faithdiff` runs | every unsuppressed added/dropped call justified |
| `make -C dos_port fidelity` | **exit 0** and unchanged — nothing new is linked yet, so any movement is a real finding |
| Makefile | the file is in `MINIGAME_CHECK_SRCS` and reachable from `ALL_SRCS`; **not** in `LINK_SRCS` |

**Reject if:** any pret label was renamed; any label was placed outside
`dos_port/src/engine/minigame/surfing_pikachu.asm`; graphics or tilemap bytes
were hand-written instead of `%include`d; a zero-guard was added; a counter was
widened; a `SCREEN_WIDTH` site was decided ad hoc rather than by the table.

### 5.3 Before ticking Stage 5 (chunk 3)

| Check | Pass looks like |
|---|---|
| `make -C dos_port -j24` and `DEBUG_SURFING_PIKACHU=1` build | both exit 0 |
| `objdump -t dos_port/pkmn.exe` | `SurfingPikachuMinigame` and `ReloadMapAfterSurfingMinigame` defined in the linked image |
| `label_status --callers SurfingPikachuMinigame` | the debug gate appears as a caller |
| Descriptors | both windows reported with all six fields; BG at `GB_TILEMAP0`, status bar at `GB_TILEMAP1`; `g_obj_clip == (80,24,240,168)` |
| Teardown | every one of `g_bg_whiteout`, `g_obj_over_window`, `g_row_yoff_on`, `g_obj_clip`, window list restored |
| `lint_pret_labels` / `--strict-claims` / `static_gate` | exit 0, 0 violations, 0 in every class |
| `faithdiff` on both new routines | every unsuppressed added/dropped call justified |
| `make -C dos_port fidelity` and `fidelity-full` | **exit 0** on both, with any scenario state change named and explained |
| `FRAME.BIN` renders | three capture points described; defects named rather than glossed |
| T3.2 | either done with `faithdiff`, or reported blocked with the exact unresolved symbol |

**Reject if:** `g_obj_clip` is left armed on exit (it visibly clips the next
overworld frame's sprites and fails the overworld goldens); the `wLYOverrides`
mapping is described as "should work" rather than observed; a golden was
re-blessed; the report claims the minigame "works" without a rendered frame.

### 5.4 Before ticking Stage 7 (merge)

Full `fidelity-full` on the merge result, exit 0. `lint_pret_labels` and
`static_gate` clean on `master` after the merge. Then sweep, in the same commit
range: the two retired `intro_yellow` `DEVIATION{}` blocks, the stale
`gb_memmap.inc:1271-1273` "not modelled here" note, the `vcopy.asm:15`
not-ported list, and any `regression-*` memory this work touches.

---

## 6. Open items carried forward

- **Deterministic golden scenario** for the minigame (Stage 8): needs RNG pinning
  and a scripted input tape on both the mGBA and DOSBox-X sides, because
  `Random` and `SurfingPikachu_GetJoypad_3FrameBuffer` drive the loop.
- **Printer high-score path** (`PrintSurfingMinigameHighScore`,
  `Printer_PrepareSurfingMinigameHighScoreTileMap`, and the two
  `gfx/surfing_pikachu/high_score_*.tilemap` blobs): permanently out of scope
  until the port has a printer transport.
- **Wiring `SurfingPikachuMinigame` into the real game flow** via
  `dos_port/src/scripts/summer_beach_house.asm` — blocked on that file being
  linked, which is another workstream's decision.
