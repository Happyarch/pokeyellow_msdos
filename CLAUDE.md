# CLAUDE.md — Pokemon Yellow DOS Port

Project context for Claude Code sessions. Read this at the start of every session.

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

## Skills — load detailed reference on demand

The deep reference lives in **project skills** (`.claude/skills/`) so it only
loads into context when needed. Invoke the matching skill (via the `Skill`
tool) BEFORE doing that kind of work. Full index, by task:

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
  the repo layout map, reference URLs.
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
running, hearing, or inspecting anything → `build-and-debug`; notes and chords
→ the music set.

The always-apply hard rules below stay here so they're in force every session; the
skills hold the "look it up while doing X" detail.

---

## Current Phase

**Phase 2: Game Loop** — See [TODO.md](TODO.md) for open items.
Phase 1 delivered the BG tile decoder + tilemap renderer with SCX/SCY scrolling
(`src/ppu/ppu.asm`) and the keyboard → joypad ISR (`src/input/joypad.asm`);
window layer, OAM sprites, and the save system remain open there.

Phase 2 so far: `Init`/`ClearVram`/`StopAllSounds` (`src/init/init.asm`),
supporting home routines (`src/util/copy_data.asm`, `src/video/lcd_control.asm`,
`src/video/frame.asm`, `src/gfx/sprites.asm`), and a text/font engine
(`src/gfx/load_font.asm` 1bpp→2bpp expansion from `gfx/font/font.png`,
`src/text/text.asm` PlaceString/TextBoxBorder). The overworld map loader/renderer
(`src/engine/overworld/overworld.asm`) renders correctly in DOSBox-X: `SKIP_TITLE=1`
boots straight into a fully drawn Pallet Town (Oak's Lab, tree border, sign) in the
DMG-green palette. The title screen (`src/movie/title.asm`) is a **bespoke early
implementation that does NOT render fully correctly** — it boots and reaches the
menu ("works enough") but the graphics are wrong; a known low-priority defect, its
faithful reimpl deferred (likely rides with the overworld tile-management rewrite).
Use `SKIP_TITLE=1` to bypass it.
Player movement now works: `OverworldLoop` reads the joypad and walks the
player in all four directions, scrolling the map smoothly via
`AdvancePlayerSprite` (which now relies purely on `LoadCurrentMapView` without
VRAM sliding) with land collision against the embedded `Overworld_Coll` passable-tile list.
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
engine**: `PrepareOAMData` (`src/gfx/sprite_oam.asm`) builds shadow OAM from the
16-slot `wSpriteStateData1/2` arrays (facing/animation table, under-grass
priority, OBP→CGB palette mapping, `$80+` tile path), and `UpdateSprites`
(`src/engine/overworld/movement.asm`, with `UpdatePlayerSprite`/`Func_4e32`/`Func_5274`)
advances the player's facing and walk-frame leg animation each `OverworldLoop`
iteration. `frame.asm:update_oam` runs `PrepareOAMData` and DMA-copies shadow OAM
→ `$FE00` in the `DelayFrame` pipeline (gated on `wUpdateSpritesEnabled`).
`LoadPlayerSpriteGraphics` loads Red's standing tiles to `$8000` and walking
tiles to `$8800` (the VRAM layout the engine indexes; walking tiles time-share
vChars1 with the font, as on the GB). NPC implementation is complete: `InitMapSprites`
(`src/engine/overworld/map_sprites.asm`) populates slots 1–15 from the map object
binary; WALK/STAY movement and leg animation run via `UpdateNonPlayerSprite`;
`CheckNPCInteraction` does the MAPY/MAPX block scan, calls `MakeNPCFacePlayer`,
and runs `PrintText` with per-character reveal and multi-page scroll; player-NPC
collision is enforced by `IsNPCAtTargetBlock` in `CollisionCheckOnLand`; NPC
wall-blocking uses MAPY/MAPX-based tile lookup in `GetTileSpriteStandsOn`.
Open Phase 2 items: scripted NPC movement, trainer battle engine, random encounter
trigger, battle engine. See TODO.md.

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

**Temporary scaffold — two out-of-map clamps (`src/engine/overworld/overworld.asm`):**
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
extension (enlarged border / bigger block grid). See TODO.md (Phase 2).

---

## Hard Rules (always in force)

These stay in-context every session. Deeper detail is in the skill named at the
end of each rule — invoke it when the rule needs its full context.

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

### Bug / glitch tags

Known bugs get a `; BUG(level):` + `%if BUG_FIX_LEVEL >= N` block; intentional
exploitable glitches get a `; GLITCH:` + `; Safety:` comment. Templates and levels
→ skill **`project-conventions`**.

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

<!-- stigmergy:begin — managed block, do not edit; `stigmergy init` regenerates it -->
## stigmergy

This project uses **stigmergy** for memory and coordination shared across every agent working here (Claude Code and Codex alike).

- **Memory lives in stigmergy, not in your own memory files.** Use `memory_search` before starting work, and record durable facts with `memory_write`. Do not keep a private memory directory for this project.
- **Register at the start of every session**: `context_open`, then `root_register` with your host session id as `session_label`.
- **Claim before you edit** anything another agent might touch: `claim_acquire`. Edits to a file claimed by another agent are blocked outright.
- **When a claim blocks you**, the owner is named. Negotiate with `mailbox_send`, or work elsewhere. Never edit around a claim.
- **Write to the agent that is actually there.** The conflict names the root holding the path and says whether it is still live; `root_list_active` shows who else is working here. Do not address a root id you remember from earlier — it may belong to an agent that has since died, while the one blocking you goes unasked.
- **Your mail is handed to you at the end of your turn**, and you cannot finish while a message is undelivered. Answer it: someone is usually blocked on you. Agreeing to hand over a file is not enough — `claim_release` is what frees it.
- **Only the root session** may claim, write memory, or send mail. Subagents read and report back.
<!-- stigmergy:end -->
