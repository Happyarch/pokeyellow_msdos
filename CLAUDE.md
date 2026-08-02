# CLAUDE.md — Pokemon Yellow DOS Port


Project context for Claude Code sessions. Read this at the start of every session.
## ⚠ THIS PROJECT USES STIGMERGY — coordination is MANDATORY

You are ALREADY registered as a root (stigmergy did it from your host session —
do NOT call context_open or root_register). Do the part that ISN'T automatic:

1. **memory_search BEFORE you plan or edit.** Other agents left notes here; you
   are not starting from a blank slate.
2. **claim_acquire every file you'll edit, BEFORE editing it.** An edit to a file
   another agent claimed is BLOCKED OUTRIGHT and names the owner.
3. **Stay warm.** Every stigmergy call refreshes your liveness. Go quiet ~15 min
   and your root is considered dead and your claims drop (claim TTL 30 min, root
   liveness 15). Use claim_renew on long-held claims.

Subagents: 1–3 for exploration only. NO planning agents — the ROOT writes the
plan. Subagents may be Sonnet, rarely Opus. NEVER a Fable subagent.
---

## What This Project Is

A from-scratch port of **Pokémon Yellow (Game Boy Color)** to **MS-DOS**, written
entirely in **x86 NASM assembly**, targeting 386+ in 32-bit protected mode via CWSDPMI.

The SM83 source at the **repository root** is the pret/pokeyellow disassembly — a
complete, labeled reverse-engineering of the original ROM. Treat it as **read-only
specification**. The actual port lives in `dos_port/`. All translated routines keep
the names used in pret (e.g. `CopyData`, `FillMemory`, `LoadSpriteOAM`) so the port
stays cross-referenceable against pret as documentation.

---

## Skills — mandatory routing gate

The deep reference lives in **project skills** (`.claude/skills/`) so it only
loads into context when needed. Loading the matching skill via the `Skill` tool
is required before planning, editing, reviewing, or verifying work in that area.

Before planning or editing, run a skill-routing check. If the task matches any
skill trigger below, load the skill before deciding on an approach, not after.
Do not rely on memory, CLAUDE.md, TODOs, or plan files as substitutes for the
skill.

At the start of any non-trivial task, state one of:
- `Skills used: <skill names>` and why they apply.
- `Skills not used: no listed skill matches this task`.

Skipping an applicable skill is a process failure. If work touches an area
covered by a skill, stop and load the skill before continuing.

Common mandatory routes:
- Translating or editing pret-labeled x86 routines: `asm-translation`, then
  `faithfulness-review`.
- Touching stubs, generated data, annotations, active plans, or BUG/GLITCH tags:
  `project-conventions`.
- Building, running, debugging, fidelity harnesses, DOSBox-X, dumps, assets,
  auditioning, or inspecting pret/DOS dependency and caller/callee graphs:
  `build-and-debug`.
- Reviewing pret fidelity or changed pret labels: `faithfulness-review`.
- Music analysis or arrangement: `score-analysis`, then `music-theory`, then the
  relevant enhancement skill.

Full index, by task:

**Porting code** (the main loop — usually all four, in this order):
- **`asm-translation`** — translating any SM83/pret routine to x86: register map,
  ZF/CF flag preservation, big-endian GB data, EBP memory model / DJGPP addressing,
  video/timing/hardware-I/O/RST boundaries, 386+ instruction choices, the 7-step
  translation workflow.
- **`project-conventions`** — stub conventions (`*_stubs.asm`), the data/code
  two-tier rule (incl. text-string generation), `BUG_FIX_LEVEL`/`GLITCH` tags, the
  active-plan file convention + current plans, save-file format notes.
- **`build-and-debug`** — building/running the port, asset regen, DOSBox-X config,
  memory-dump (`DUMP.BIN`) / back-buffer (`FRAME.BIN`) / GB-state (`GBSTATE.BIN`)
  debugging recipes, the golden fidelity harness (mGBA vs DOSBox-X, `goldencheck`
  / `make fidelity`), music auditioning (audition.py / `DEBUG_AUDIO TRACK=`),
  the interactive dependency graph + agent-facing JSON caller/callee API, the
  repo layout map, reference URLs.
- **`faithfulness-review`** — the pre-commit fidelity gate for any change touching
  a pret-labeled routine: faithdiff / lint_pret_labels / label_status / golden
  scenarios, and the justification rules.

**Music work** (arrangement pipeline — read in this order):
- **`score-analysis`** — per-track musicological analysis; read the target
  track's entry BEFORE any arrangement work on it.
- **`music-theory`** — chord ID, voice leading, voicing; foundation for both
  enhance skills, also standalone for analysis/review.
- **`audio-enhance-opl3`** — tier-1 conservative FM channels (must sound good on
  OPL3; cascades up to MT-32/GM). Do this tier first.
- **`audio-enhance-mt32`** — tier 2–3 MT-32/GM channels on top of existing
  tier 1 (never duplicating it).
- To *listen* to any result, that's not an arranger question — it's
  `build-and-debug` → "Auditioning music" (host-side `audition.py` for fast
  iteration; `dos_port/run DEBUG_AUDIO=1 TRACK=<MUSIC_*> /LOOP` in-DOS).

Rule of thumb: writing/reviewing x86 from pret source → `asm-translation` +
`faithfulness-review`; touching stubs/generators/tags → `project-conventions`;
running, hearing, inspecting runtime state, or querying dependency/caller/callee
graphs → `build-and-debug`; notes and chords → the music set.

The always-apply hard rules below stay here so they're in force every session; the
skills hold the "look it up while doing X" detail.

## Evidence and Knowledge Policy

Repository and runtime evidence outrank prose. Use this order: pret source and
the current linked build; deterministic mGBA/DOSBox-X state; generated static
analysis; then comments, plans, skills, commits, and memory. Unsupported negative
claims are prohibited: `missing`, `stub`, `unported`, `check-only`, `unreachable`,
and `no caller` must cite generated state (`dos_port/tools/project_state`) or
runtime evidence.

**`port-only` is a positive claim that needs the same discipline, and the raw
`status` column does NOT support it.** `update_label_db` models pret `home/` +
`engine/` only, so a faithful pret label from `audio/`, `data/`, `gfx/`, `ram/`
or `scripts/` is recorded `port_only` *by elimination* — nobody determined it was
bespoke. Measured 2026-07-28 (after the upstream pret merge 46b8e169): 91 of 428
`port_only` rows were real pret labels (data 41, audio 22, scripts 16, gfx 10,
ram 2) — audio gained `PlayPikachuSoundClip`, which upstream moved out of
`engine/pikachu/` into `audio/`. Cite the `aux_labels` /
`script_labels` provenance tables, or the dependency graph's `display_status`
(`pret-unmodeled`) and `aux_pret_file`. A label is genuinely port-only only when
`display_status == "port_only"` AND `aux_pret_file` is null. Calling a pret
routine "port-only" invites exactly the forked-name duplication the "Preserve
pret Labels" rule exists to prevent.

**`unreachable` needs runtime evidence; the `reachability` column is never proof
of unreachability.** It supports the positive direction only
(`statically-reached-from-start` = a path exists from `start`, assuming calls
return — still not proof of execution). `not-proven-reached` means the analysis
found no path, and it has permanent blind spots: `dd Label` dispatch tables and
address-taken operands emit no edge, so every jump-table handler and both ISRs
(PIT, keyboard) read `not-proven-reached` while provably running. Cite
`--callers` or runtime evidence instead.

**Unsupported CONFIRMATIONS are prohibited too — the rule is symmetric.** A
result that matches an expectation is not evidence until you state what it is
made of: a matching aggregate (count, total, hash, "no diff") counts only with
its decomposition, because two opposing errors cancel to a plausible total and
nobody adversarially reviews good news. `1051 ≈ the projected 1046` was really
`1046 +135 −130`. Treat a number landing where you expected as a prompt to
decompose it, not as a result.

Corollary: **"unchanged by construction" is not a verification — run the check.**
Any sentence that *explains away* a discrepancy instead of measuring it (`just`,
`merely`, `crude estimate`, `coincidence`, `by construction`) marks the spot
where a measurement was cheap and skipped. In the review that produced this rule,
every such claim was false.

Verification terms are not interchangeable: `defined`, `linked`, `reachable`,
`executed`, `golden-matched`, and `visually-observed` describe distinct evidence.
A regression-only run must not be reported as feature execution. A clean static
gate means only “no detected structural divergence”; run
`dos_port/tools/fidelity_gate` for changed pret labels and add a must-hit runtime
scenario when behavior is changed.

When a capability becomes live, sweep related `TODO-HW`, `STUB`, extern,
allowlist, plan, skill, `regression-*` memories, and stigmergy claims in the same
workstream. Stigmergy is
an evidence index, not authority: durable entries need evidence and state;
volatile status needs expiry; contradictory repository evidence updates the
existing key. Run `dos_port/tools/project_state --plans` for the generated active
plan inventory; do not maintain a second hand-written inventory.

Use stigmergy memories before making decisions that depend on project history,
prior agent work, local conventions, or non-obvious constraints. Search with
`memory_search` early, before choosing an approach, and again before recording a
durable decision; treat hits as leads to verify against repository/runtime
evidence, not as final authority.

---

## Current Phase

**Phase 2: Game Loop** — big-picture scope lives in `ROADMAP.md`; per-work-item
detail lives in the active `docs/current_plan_*.md` set (generated inventory:
`dos_port/tools/project_state --plans`). The old root `TODO.md` was removed
2026-07-25 as stale beyond salvage — do not cite it. The deferred tails it used
to track now live in `docs/current_plan_backlog.md` (memory
`todo-md-deleted-orphaned-trackers` records what moved and why).
Phase 1 delivered the BG tile decoder + tilemap renderer with SCX/SCY scrolling
(`src/ppu/ppu.asm`) and the keyboard → joypad ISR (`src/input/joypad.asm`);
window layer and OAM sprites remain open there. The save system is now real: the
port emulates all four **SRAM banks resident** (bank 0 at `$A000`, banks 1-3 at
`$22000-$27FFF`, `class=banking` deviation, same flat model as ROM), pret's
save/load/box routines read and write the real `s*` addresses, and
`src/save/dsv_io.asm` persists the whole 32 KiB image as `.dsv` **v2**
(`SramLoadImage` at boot, `SramStoreImage` at each save commit). The Bill's PC
box UI is the faithful pret mirror (`src/engine/pokemon/bills_pc.asm`), and the
whole tier is golden-gated: `bills_pc_ops` (deposit/withdraw/release through
the real UI on both sides) and `box_change_roundtrip` (the change-box round
trip — the only runtime path into SRAM banks 2/3). The sram plan is archived
at `docs/plans/sram_pc_storage.md`; its one open flag is the torn-write-guard
acceptance awaiting maintainer sign-off (stage 7).

Phase 2 so far: `Init`/`ClearVram`/`StopAllSounds` (`src/home/init.asm`),
supporting home routines (`src/home/copy.asm`, `src/home/lcd.asm`,
`src/video/frame.asm`, `src/home/clear_sprites.asm`), and a text/font engine
(`src/home/load_font.asm` 1bpp→2bpp expansion from `gfx/font/font.png`,
`src/home/text.asm` PlaceString/TextBoxBorder). The overworld map loader/renderer
(pret mirror `src/home/overworld.asm`; `src/engine/overworld/overworld.asm` keeps
the port-only glue and the embedded asset blobs) renders correctly in DOSBox-X: `SKIP_TITLE=1`
boots straight into a fully drawn Pallet Town (Oak's Lab, tree border, sign) in the
DMG-green palette. The title screen (`src/engine/movie/title.asm`) is a **bespoke early
implementation that does NOT render fully correctly** — it boots and reaches the
menu ("works enough") but the graphics are wrong; a known low-priority defect, its
faithful reimpl deferred (likely rides with the overworld tile-management rewrite).
Use `SKIP_TITLE=1` to bypass it.
Player movement now works: `OverworldLoop` reads the joypad and walks the
player in all four directions, scrolling the map smoothly via
`AdvancePlayerSprite` (the home-bank wrapper in `src/home/overworld.asm`; its engine
body `_AdvancePlayerSprite` and the `MoveTileBlockMapPointer{East,West,South,North}`
family live in the pret mirror `src/engine/overworld/advance_player_sprite.asm`, and it
now relies purely on `LoadCurrentMapView` without VRAM sliding) with land collision
against the embedded `Overworld_Coll` passable-tile list.
The OAM sprite renderer (`src/ppu/ppu.asm:render_sprites`) is in: 8×8 DMG OBJ
emulation (X/Y flip, OBP0/OBP1, color-0 transparency, BG-priority bit). It draws
`spr_oam_valid` entries **positioned from `spr_dos_sx/sy`** (canvas coords), taking
only tile/attr from `$FE00` — so whoever owns the canvas owns OAM: publish through
`PrepareOAMData` / `PrepareStaticOAM` / the mon-icon writers, or nothing is drawn
(`ClearSprites`/`HideSprites` zero the count). Z-order: the port composites the
**window layer last, over OBJ** — inverse of the GB, so the overworld dialog box can
occlude NPCs the widescreen camera exposes under it. A screen whose window *is* the
screen and whose OBJ belong on top of it (party menu, naming screen) sets
`g_obj_over_window` to get the hardware order back; `ClearSprites` clears it again.

The `UpdatePlayerOAM` scaffold has been replaced by the **faithful sprite
engine**: `PrepareOAMData` (`src/engine/gfx/sprite_oam.asm`) builds shadow OAM from the
16-slot `wSpriteStateData1/2` arrays (facing/animation table, under-grass
priority, OBP→CGB palette mapping, `$80+` tile path), and `UpdateSprites`
(`src/engine/overworld/movement.asm`, with `UpdatePlayerSprite`/`Func_4e32`/`Func_5274`)
advances the player's facing and walk-frame leg animation each `OverworldLoop`
iteration. `frame.asm:update_oam` runs `PrepareOAMData` and DMA-copies shadow OAM
→ `$FE00` in the `DelayFrame` pipeline (gated on `wUpdateSpritesEnabled`).
`LoadPlayerSpriteGraphics` loads Red's standing tiles to `$8000` and walking
tiles to `$8800` (the VRAM layout the engine indexes; walking tiles time-share
vChars1 with the font, as on the GB). NPC implementation is complete: `InitSprites`
(`src/home/overworld.asm`, from `LoadMapHeader`) populates slots 1–15 from the map
object binary, and the sprite-set TILE loading is the separate
`InitMapSprites` (the pret home/palettes.asm wrapper, `src/home/palettes.asm`) ->
`_InitMapSprites` (`src/engine/overworld/map_sprites.asm`) path; WALK/STAY movement and leg animation run via `UpdateNonPlayerSprite`;
`CheckNPCInteraction` does the MAPY/MAPX block scan, calls `MakeNPCFacePlayer`,
and runs `PrintText` with per-character reveal and multi-page scroll; player-NPC
collision is enforced by `IsNPCAtTargetBlock` in `CollisionCheckOnLand`; NPC
wall-blocking uses MAPY/MAPX-based tile lookup in `GetTileSpriteStandsOn`.
**Open Phase 2 items are NOT enumerated here — query them** (rule adopted
2026-08-02). This paragraph used to list "scripted NPC movement, trainer battle
engine, random encounter trigger, battle engine"; by 2026-08-02 scripted NPC
movement was done, wild encounters and the wild battle were live, and trainer
battles were coded-but-gated — so every item on it was wrong in a different
direction. A hand-kept open-items list in the always-loaded file is exactly the
failure mode that killed `TODO.md`. Run `dos_port/tools/project_state --plans`
for the plan inventory and read the owning `docs/current_plan_*.md`; use
`dos_port/tools/label_status --callers` and the dependency graph for what is
actually linked and reached. Battle fidelity has an archived audit at
`docs/archive/battle_audit_findings.md` — historical, and its Tier-4 claims are
known stale (it calls trainer-AI move selection dead code when it is linked and
live, and `ReadTrainer` prize money missing when `AddBCD` awards it in
`faint_sendout.asm`).

`render_bg` (`src/ppu/ppu.asm`) is a **native-width surface renderer**: it decodes
tile IDs into a 48×36-tile (384×288 px) surface using the existing `tile_cache`
(2bpp→8bpp decoded tiles), re-decoding only the cells whose tile id changed since
last frame. It then blits a 320×200 window at a signed pixel offset `(Xoff, Yoff)`
derived from the coarse block alignment and the fine `H_SCX`/`H_SCY` values,
providing smooth per-pixel scrolling without wrap artifacts. The old 256×256 VRAM
torus emulation and related `RedrawRowOrColumn` rings are gone. The compositor is
at full speed as of 2026-07-12 — see `docs/plans/compositor_perf.md` (archived)
before changing any of these hot loops; it also ships the `DEBUG_PERF` profiler
(`tools/perf_capture.sh`) and `tools/pixelcheck.sh`.

**Temporary scaffold — two out-of-map clamps (`src/home/overworld.asm`):**
the extended 40×25-tile viewport draws a larger area than the original 20×18 and
the player is pinned at screen-center, so a player-centered camera near a map
edge reaches past the populated `wOverworldMap` data. Two complementary stopgaps
keep that from painting garbage:
1. **Block-ID clamp** in `DrawTileBlock`: a block ID past the embedded blockset
   is clamped to block 0.
2. **Block-map address clamp** in `LoadCurrentMapView`: `wOverworldMap` ($E800,
   $900 = 2304 bytes at `MAP_BORDER` 7, ending $F100) is separated from
   `wSurroundingTiles` ($E000, 1728 bytes) by a $140-byte gap. Any read outside
   `[wOverworldMap, wOverworldMapEnd)` yields the map's border block
   (`wMapBackgroundTile`) instead of garbage, so the out-of-map area renders as
   clean dummy tiles matching the in-bounds border.

`MAP_BORDER` (`include/gb_memmap.inc`) is 7, not pret's 3: the port's viewport is
12×9 blocks, and `MoveTileBlockMapPointer{West,East,…}` advances the flat view
pointer *before* the coords wrap, so the border must exceed `SCREEN_BLOCK_WIDTH/2`.
At border 6 it did not, and a west step at `x=0` wrapped the pointer into the
previous block-row. Every border-derived quantity must be written in terms of
`MAP_BORDER` / `SCREEN_BLOCK_*`, never as the literal that happens to equal it —
pret's own source is full of such collisions (`MAP_BORDER*2 == SCREEN_BLOCK_WIDTH`).

Both are stopgaps: the real fix is to **extend the map data** so those regions
hold real blocks (no blank area), after which both clamps are dead code and
should be deleted. The address clamp removes the garbage *now* (verified via
`FRAME.BIN` for baseline / north-transition / walk-to-edge); it does **not** yet
give editable map cells for that extended area — that still needs the map-data
extension (enlarged border / bigger block grid). Until that lands, both clamps
stay — this section is the record of that work, which no other file tracks.

---

## Hard Rules (always in force)

These stay in-context every session. Deeper detail is in the skill named at the
end of each rule — invoke it when the rule needs its full context.

Before any edit, confirm:
- Which skill applies, or why none applies.
- Which stigmergy memories were checked.
- **Which regression memories cover the area** (`memory_search regression <area>`
  — see "Known regressions" below).
- Which files are claimed if coordination is needed.

### The interactive shell is zsh, NOT bash

**Write zsh-compatible commands.** This is a repeated agent error, not a hypothetical
— the differences are silent, so a bash-ism usually produces a wrong answer rather
than an error:

- **Unquoted `$var` is NOT word-split.** `set -- $pair` leaves it as ONE word; use
  `${=var}` to split, or pass arguments explicitly.
- **`$pipestatus`, not `$PIPESTATUS`** — and zsh arrays are **1-indexed**, so the
  first element is `$pipestatus[1]`.
- **Splitting on newlines** is `${(f)var}`, not bash's `IFS=$'\n'` idioms.
- **`**` globs recursively by default**, and an unmatched glob is an ERROR (the
  command does not run) rather than passing through literally.
- Long `while read` / `for` loops that `cd` or invoke `git -C` have been observed to
  lose `PATH` mid-iteration in this environment. If a loop's second iteration reports
  `command not found: awk`, that is the failure — rewrite it as straight-line
  commands rather than debugging the loop.

Related shell rule, not zsh-specific but the same family: **put nothing between a
gate and the status you read.** Both `make fidelity | tail -40` and
`make fidelity > log; echo "EXIT=$?"` report the status of the LAST element, so a
failing gate reads as a pass. Redirect to a file, record `$?` to a file, read that
file. Full detail → skill **`build-and-debug`**.

### Preserve pret Labels

**Keep the pret label names — do not rename or invent.** Every translated
routine, jump target, and data label keeps the exact name pret uses (`StatusScreen`,
`DrawHPBar`, `EvolutionAfterBattle`, `.nonzeroHP`, `TypesIDNoOTText`, …) so the
port stays line-for-line cross-referenceable against the disassembly. This is a
hard rule, not a style preference:

- If the port needs a lowercase/local alias (e.g. a file-local helper the pret
  routine inlined), keep the pret name as the primary symbol and add the alias
  **alongside** it — never in place of it. Prefer adding aliases in the `.inc`,
  not renaming the routine.
- Where pret's structure splits differently in the port (e.g. a pret `predef`
  that the port calls directly, or one pret routine realized as two because a
  bespoke variant already exists), keep pret's names on both halves and add a
  comment explaining the split. Don't collapse two pret labels into one new name.
- New port-only routines (HAL boundaries, debug harnesses) get descriptive names,
  but anything that *has* a pret counterpart uses the pret counterpart's name.

### Data is big-endian

**GB game data is big-endian — preserve pret byte order.** Multi-byte values (mon
HP/MaxHP/stats, OT ID, EXP, every party/box/`wLoadedMon` field) are stored high
byte first. Never re-store a GB value in x86-native little-endian order — it's
load-bearing for pret cross-reference and the Gen-2 byte-identical rule. Full
detail + the `PrintNumber`/borrow-chain caveats → skill **`asm-translation`**.

### Register map & flag preservation

Translate SM83 → x86 by the fixed register map (A→AL, BC→BX, DE→DX, HL→ESI, EBP =
GB memory base), and **preserve the exact ZF/CF a `jr z`/`jr c` reads** — x86 sets
flags on different instructions than SM83, so an `inc`/`cmp` in the wrong spot
silently breaks a branch. Full table, flag rules, EBP/DJGPP memory model, and
video/timing/hardware-I/O boundaries → skill **`asm-translation`**.

### Linker sections

Put embedded data in `.data` (as font/title assets do); **any new section name
must be added to `link.ld` first**, or its bytes never load and its symbols read
back as zero at runtime with no fault (the `.rodata` all-white bug). Full
explanation → skill **`build-and-debug`**.

### VRAM tile writes: `CopyVideoData`, or arm `g_tilecache_dirty`

The compositor never reads VRAM tile patterns — it decodes them once into
`tile_cache`, and **`render_bg`, `render_window` and `render_sprites` all draw from
that cache**. So a routine that mutates vChars bytes without invalidating it renders
the *previous* occupants of those slots. Route tile writes through `CopyVideoData`
(which arms the flag itself), or set `mov byte [g_tilecache_dirty], 1` explicitly —
a raw `rep movs` into vChars that does neither is a visible-corruption bug, and
**OBJ/sprite tiles are not exempt** (that assumption shipped a bug twice). Also:
vTileset tiles `$03`/`$14` are reserved for the BG animator — don't park graphics
there. Full detail + the traps → skill **`asm-translation`** ("Writing VRAM tile
data").

### Stubs live in `*_stubs.asm`

A link-time stand-in goes in the subsystem stub file `src/<area>/<area>_stubs.asm`
under its exact pret label — never a `ret`-only body in the source-mirror file,
never a forked name. Full rules (extern comments, retirement, no-shadow) → skill
**`project-conventions`**.

### Text strings are DATA — never hand-encode charmap bytes

Any human-rendered string (menu/screen labels, item/move/mon names, dialog — even
`"OK"`) is **Tier-1 data**: produce it with a Python generator (`gb_text.encode` →
`assets/*.inc`, `%include`d, wired into `make assets`). Never write `db 0x…`
charmap hex in a `.asm`. This is the most-repeated violation. Two-tier rule + the
generator pattern → skill **`project-conventions`**.

### Faithfulness review gate

Any change touching a pret-labeled routine must pass the fidelity gate before
commit: `dos_port/tools/faithdiff <Label>` (justify every unsuppressed
added/dropped call in the commit message) and `dos_port/tools/lint_pret_labels`
(must exit 0). Workflow + tools → skill **`faithfulness-review`**.

**The tree does not currently satisfy that rule, and that is a DEFECT, not a
new normal.** Measured 2026-08-02: `lint_pret_labels` exits 1 with 14
`aux_misplaced` findings, and `--strict-claims` adds 3 `hand_encoded_text` + 21
`local_shadow`. These are unsanctioned leftovers — none was ever approved by
the maintainer — and the standing instruction is to drive them to zero, not to
accept them. `static_gate`'s per-class baseline stops them GROWING; it does not
sanction them, and an agent must not cite "at baseline" as permission to leave
a class non-zero. Re-measure rather than quoting these counts.

**Two automated gates back this up, and one of them runs whether you remember it
or not.** `dos_port/tools/static_gate` is a whole-tree ratchet over a checked-in
per-class baseline and is **invoked by `.githooks/pre-commit`** (install:
`make -C dos_port install-hooks`); it exits 0 only when nothing under `dos_port/`
is staged. `dos_port/tools/fidelity_gate` is the per-change, per-label chain and
also carries the relocation move battery (`--move-baseline` before editing,
`--move-verify` after). A green gate proves no structural or bookkeeping drift and
**nothing about behaviour** — the golden suite is separate.

**A failed fidelity check means repair the implementation.** New relocations are
not allowed. If a routine has a pret counterpart, put its complete body and every
pret entry point in `dos_port/src/<pret path>`. “Related code belongs together,”
“next to its caller/callee,” private-helper convenience, or a port-specific notion
of cohesion never overrides the mirror. Port-only helpers with no pret counterpart
may live where their subsystem requires, but they do not absorb pret labels.

An agent must not add, expand, or reinterpret
`dos_port/tools/pret_label_allowlist.json` to make its own work pass. Its relocation
entries are a legacy-debt inventory, not permission or precedent. Registry edits
may only retire or reclassify audited debt and require explicit user/maintainer
approval for the exact contents, recorded outside the worktree. Agents may not add
`structural_findings` to self-waive new work either. If the linter reports
`mirror`, move the complete routine to the indicated mirrored file.

### Structured annotations — `DEVIATION` / `BUG` / `GLITCH` / `STUB`

Every sanctioned divergence, known bug, exploitable glitch, and link-time stand-in
carries a **machine-parsed** annotation. `tools/lint_pret_labels` parses these
strictly: a malformed one, an unknown `class`, or a missing field is a **violation**,
not a style nit. This is how the "why" becomes queryable instead of living only in a
commit message nobody greps.

```nasm
; DEVIATION{class=<class>; pret=<file>:<Label>; behavior=<what differs>; evidence=<why that is the truth>; lifetime=<what retires it>}
```

- **Kinds — `DEVIATION`, `BUG`, `GLITCH`, `STUB`. There are no others.** Do not invent
  one: an unrecognized kind is invisible to the linter, so it reads as an ordinary
  comment and silently proves nothing. Legacy relocation entries describe debt,
  not faithful structure; do not add another one.
- **Required fields (all kinds):** `class`, `pret`, `behavior`, `evidence`, `lifetime`.
  `GLITCH` also requires `safety`. `STUB` also requires `label`, and its `class` must be
  `stub` or `temporary`.
- **`class` ∈ {`HAL`, `banking`, `projection`, `data-model`, `timing`, `stub`,
  `temporary`}** — nothing else parses.
- **No `;` or `}` inside a value** — the parser splits fields on `;`. Use commas.
- Bugs still pair the annotation with a `%if BUG_FIX_LEVEL >= N` block (`1` = critical,
  `2` = all).
- **The legacy free-form format is dead — do not resurrect it.** `; BUG(critical): …` /
  `; GLITCH:` + `; Safety:` still parse (migration-era acceptance), and
  `lint_pret_labels --strict-claims` flags each as `legacy_annotation`. The migration is
  effectively complete — strict-claims reports **zero** tree-wide as of 2026-07-25 — but
  that is a measured number, not an invariant: re-run the check rather than quoting this
  line. Writing a free-form annotation now is a regression.

Templates → skill **`project-conventions`**; the gate that enforces them → skill
**`faithfulness-review`**.

### Known regressions — QUERY them, never maintain a log

**There is no regressions log file, and one must not be created.** A hand-kept
log gets long, goes stale, and then gets cited as evidence — exactly how
`TODO.md` died. Regressions live at two tiers, both of which are already
load-bearing, and you QUERY them:

1. **The site carries the machine-parsed annotation.** A regression in
   pret-labeled code gets a `BUG{...}` (or `GLITCH{...}` / `DEVIATION{...}`)
   annotation at the code that is wrong, in the format above. That is the
   authority on *what* is broken, it travels with the code, and
   `lint_pret_labels` parses it.
2. **Stigmergy is the searchable index**, for regressions with no single site
   (cross-subsystem, tooling, harness) and for the "why/when/how to reproduce"
   behind an in-code tag. Key convention: **`regression-<area>-<slug>`**
   (`regression-battle-exp-overflow`, `regression-tooling-strict-lint-gap`).

**Query before you work an area — this is part of the pre-edit checklist:**

```
memory_search regression <area>          # e.g. "regression battle", "regression overworld"
```

A regression memory MUST carry, or it is not a regression memory:
- **symptom** — what is observably wrong;
- **repro** — a command, scenario name, or gate that shows it. "It looked wrong"
  is not a repro;
- **evidence** — per the Evidence and Knowledge Policy above, including for the
  claim that it is still open;
- **status + date in the DESCRIPTION**, because `memory_list` shows only
  descriptions. Lead with `OPEN:` or `FIXED <date> (<commit>):`.

**Currency is enforced by three rules, not by good intentions:**
- **Whoever fixes a regression closes its memory in the SAME commit** that fixes
  it, citing the commit — the same discipline the annotation and allowlist
  sweeps already require. A fix that leaves the memory reading `OPEN:` is an
  incomplete fix.
- **A regression with a runtime repro should become a golden scenario.** Once it
  has one, the fidelity suite — not prose — is the currency mechanism: the
  memory shrinks to a pointer at the scenario, and a re-break fails the suite
  instead of waiting to be re-noticed. This is the preferred end state.
- **Contradictory repository or runtime evidence updates the existing key**
  (never a new one). If you find a regression memory that the tree disproves,
  fixing the memory is part of your task, not a favour to the next agent.

Never delete a regression memory to "close" it — mark it `FIXED` with the
commit. The record of what broke, and how it was caught, is the point.


---

## Package / System Install Policy

**All local package installs require explicit user permission before running**, even in
auto mode, for security reasons. This includes `apt`, `pacman`, `pip`, `npm -g`, and
any other package manager that modifies the system or user environment.

Exception: if Claude is running inside a self-contained web container / VM where it owns
the environment, installs may proceed without prompting.

---

## Commit Policy (stay within your task's scope)

**Commit the work for the task you're doing — not unrelated changes.** Use git
normally (stage, `git add -A`, `git commit -a`, amend your own commits). The one
rule: don't fold changes that fall *outside your current task / subsystem* into
your commits without checking with the user first.

- **In-scope changes: just handle them** — changes belonging to the same task/
  subsystem can be committed together.
- **Out-of-scope changes: notify or ask** — if the tree holds unrelated changes,
  don't sweep them into your commit; mention them, and only commit them if the
  user says so or you flag a clear reason in the message.
- **Don't rewrite work that isn't yours.** Amending/rebasing your own recent
  commits is fine; don't `rebase`/`amend`/`reset` a commit from another session or
  one you can't account for — report it and let the user decide.
- When unsure whether something is in scope, `git status`/`git diff` first and ask.

---

## Gen 2 Forward-Compatibility (a Gen 2 port is planned)

Keep the Pokémon party/box data structures **byte-identical to Gen 1** — same
field offsets, same lengths (party = 44 bytes, box = 33 bytes), same "blank"/
reserved bytes. Do **not** shrink, realign, or repurpose any byte to save space.

Why it matters: Gen 2's Time Capsule stores a traded mon's **held item** in the
Gen-1 **catch-rate byte** (`MON_CATCH_RATE`, struct offset 7). Preserving that
slot is how held items survive a Gen 1 ↔ Gen 2 trade, and some species ship
already holding an item via it (e.g. Kadabra → `TWISTEDSPOON_GSC` $60, written by
`_AddPartyMon`). Any new code that builds/copies/converts a mon (party↔box
deposit/withdraw, trades, save format) must carry offset 7 through verbatim.
See `dos_port/include/gb_constants.inc` (struct members) for the load-bearing note.
