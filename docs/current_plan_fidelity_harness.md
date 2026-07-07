# Fidelity Harness — mGBA golden differential testing + anti-divergence static tooling

Worktree: `/mnt/sdb1/Code/Active Code/pokeyellow_msdos-fidelity_harness` (branch `fidelity_harness`).

Status: **in progress — Sessions A–G done (2026-07-07); next: Session H.**

**Sequencing vs `current_plan_overworld_port.md` (decided with user 2026-07-06):**
the harness spine — Sessions A–E + H — runs as one focused block **before** the
overworld plan's high-divergence-risk items (VRAM tile-slot / tile-management rewrite,
clamp retirement via map-data extension, `render_bg`/sprite plumbing). Low-risk,
loosely-coupled overworld items may interleave anytime; remaining harness sessions
(F, G, I, J) slot in as filler once the spine is up.

**Execution is chunked into Sessions A–J (see "Session plan" below) — each sized for
one autonomous Claude session with its own checklist and exit gate.** Do not start a
session's work mid-way through another; if a session's exit gate can't be reached,
stop, write findings into this file under the session's heading, and report.
The Stage sections further down are the technical spec the sessions reference;
mark both the session checklist and the stage `[ ]` boxes as work lands.

## Context

The last four status-screen bugs (sprite bleed-in, HUD tile-slot clobber, missing
PTile, spurious ▼) all shared one root cause: agents generalized from the port's own
code instead of reading pret's specific routine. All four were mechanically detectable
by comparing against pret — no judgment required. This plan builds the three tiers
that make that class of divergence fail a test instead of surviving to the user, plus
one quality-of-life fix for unattended agent sessions (dosbox-x quit confirmation).

Decisions already made with the user:
- mGBA's **built-in Lua scripting** is the backbone (no emulator patching — it ships a socket API natively).
- mGBA is **vendored as a git submodule at `dos_port/tools/mgba`** pinned to a 0.10.x release tag (MPL-2.0 compliance via source-alongside; version-pinned goldens).
- Golden scenarios reached via **Lua WRAM seeding** mirroring the port's `PrepareNewGameDebug`, with savestates only as a local speed cache.
- **Goldens are committed to git** (~7 KB/scenario).
- Part 2 ships **both** Python CLIs (label linter + call-graph faithdiff) plus a review-gate skill.
- Part 2 also ships a **per-label translation DB** (SQLite, extending `translation.db`
  additively): status of every pret label (translated/stub/missing/relocated),
  **always derived by rescanning the tree** (never agent-written directly, so it can't
  drift), queried via `label_status --callees <Label>` from the translation workflow so
  agents know what to extern vs stub before writing a line.
- An **MCP bridge drives the Lua harness** (twin of dosbox-mcp) so interactive differential debugging needs no manual emulator driving.

## Key facts from exploration (2026-07-06)

- ~~Root pret tree builds `pokeyellow.gbc` + `pokeyellow.sym` from source~~ **Correction
  (Session A):** only a *pristine upstream* checkout builds — the branch tree fails at
  link (see Session A result; build from `../pokeyellow_msdos-pret-golden/` @ `7caf2e09`).
  rgbds pin is `1.0.1` (`.rgbds-version`) and the system has exactly 1.0.1. `roms.sha1`
  verifies the ROM bit-for-bit. No baserom needed. `.sym` gives label→address for Lua.
- Port headless pipeline exists (`make -C dos_port image DEBUG_X=1` →
  `SDL_VIDEODRIVER=dummy dosbox-x` → `mcopy -i PKMN.IMG@@1048576`), ~30 `DEBUG_*`
  scenario gates in `dos_port/src/debug/debug_dump.asm`. **But no dump captures full
  tilemap/VRAM/OAM**: `DUMP.BIN` = 9×64-byte windows; `FRAME.BIN` = 320×200 rendered
  pixels only.
- **Shape mismatch (the one design wrinkle):** port `W_TILEMAP` at `0xC3A0` is a
  **40×25 flat canvas** (1000 B, stride 40); real GB `wTileMap` at the same address is
  **20×18** (360 B, stride 20). The differ must extract the port's 20×18 subwindow at a
  per-scenario offset. VRAM (`0x8000–0x97FF`) and OAM (`0xFE00`, 160 B, live-populated
  each frame from `W_SHADOW_OAM`) map 1:1 at `[EBP+addr]`.
- No existing label-linting or pret-comparison tooling; `dos_port/tools/build_index`
  (walks pret `home/`/`engine/`/`scripts/` into `translation.db`) is the model to copy.
- dosbox-x-mcp quit prompt: `CheckQuit()`
  (`dos_port/tools/dosbox-x-mcp/src/gui/sdlmain.cpp:1341`) reads `[dosbox]`
  `quit warning` (default `auto` → still prompts while a guest program runs).
  `quit warning = false` → returns true, no dialog. **Config-only fix**; the generated
  conf lives in `dos_port/tools/run_with_mcp.sh`.
- Stale-object gotcha applies to all new `DEBUG_*` consumers: `-D` flag changes are
  guarded by the `.nasmflags.stamp` (Makefile:1146–1159), but `%include` edits still
  need `make clean`.

---

## Session plan (one autonomous session each)

**Every session, before touching code:**
- Read CLAUDE.md + this plan file top to bottom; find your session's heading.
- Invoke the `build-and-debug` skill (headless recipe, mcopy extraction, stale-object
      gotchas); invoke `asm-translation` if the session touches `.asm`,
      `project-conventions` if it adds tools/stubs/strings.
-     `git status` — confirm you're on the right branch and note unrelated changes
      (don't sweep them into your commits).

**Every session, before ending:**
-     Exit gate verified **by running it**, not by reading code.
-     Work committed (one commit per session unless noted), plan checkboxes marked
      `[x]`, and a 2–4 line "Session X result:" note added under the session heading
      (what landed, what surprised you, what the next session must know).
-     If the gate was NOT reached: commit nothing half-broken; write the blocker into
      this file and stop.

### Session A — quit fix + mGBA vendor/build + golden ROM  *(Stage 1.0 + scope add)*
- [x] Apply the dosbox-x quit fix (both conf sites + `quit_emulator` MCP tool) and
      verify per the Verification section.
- [x] Add the `dos_port/tools/mgba` submodule @ 0.10.x tag; write `build_mgba.sh`;
      build with scripting enabled (Lua dep may need a **user-approved** package
      install — ask, per CLAUDE.md policy, or build vendored).
- [x] Verify the headless scripting entry point (hello-world Lua under
      `SDL_VIDEODRIVER=dummy`, confirm memory/input/socket/file APIs exist). **If this
      fails, stop and report — the fallback choice (qt offscreen vs libmgba runner) is
      the user's.**
- [x] `make yellow` at root; sha1-verify vs `roms.sha1`; confirm `pokeyellow.sym` exists.
- **Exit gate:** headless mGBA runs a Lua script that reads a known WRAM address from
  the verified ROM and prints it; DOSBox-X closes promptless via `quit_emulator`.

**Session A result (2026-07-06): all gates passed.** What the next sessions must know:
- **The branch's root pret tree does NOT build the ROM** — port commit `101c5a9c`
  (2026-06-16) edited pret sources (`MAP_BORDER` 3→6, `wOverworldMap` 1300→2048,
  loop rewrites in `home/overworld.asm` + `engine/overworld/update_map.asm`),
  overflowing WRAM0 at link. Golden ROM builds from the **pristine upstream commit
  `7caf2e09`** in the pinned worktree `../pokeyellow_msdos-pret-golden/` (sha1 matches
  `roms.sha1`; `pokeyellow.sym` there, 24 453 symbols). `make goldens` (Session C)
  must use that worktree; the "root pret tree builds" key fact below was wrong for
  this branch. The pret-tree contamination itself is a **decision-for-user** (it also
  violates the read-only-spec hard rule).
- **mGBA 0.10.5 has no headless scripting entry point** (SDL frontend: none; Qt:
  GUI-menu only). Per user decision, the harness ships a custom runner
  `tools/mgba_harness/runner.c` → built as `tools/mgba_build/mgba-lua-runner` by
  `build_mgba.sh` (no SDL/Qt/display needed at all). Gotchas baked into it:
  `mScriptContextLoadFile` only compiles — `engine->run()` must follow; the "frame"
  callback is triggered manually per `runFrame` (mirrors `thread.c ADD_CALLBACK`).
  Lua env: full `luaL_openlibs` (io/os available), socket + console verified.
  Exit-gate run: `mgba-lua-runner -s tools/mgba_harness/hello_wram.lua <golden>.gbc`
  → API asserts pass, `wTileMap` bytes print, `HELLO_WRAM_OK`. GB-core "MBC5 unknown
  address" log spam is normal — filter it.
- `build_mgba.sh` needs `-DCMAKE_POLICY_VERSION_MINIMUM=3.5` (system CMake 4 vs
  mGBA's 3.1 minimum). Lua 5.4 + cmake were already installed — no package installs.
- Fresh-worktree bootstrap traps hit this session: `git submodule update --init
  dos_port/tools/unicode_converter` is required before `make assets`; `CWSDPMI.EXE`
  and the `dosbox-x-mcp/` binary are untracked — copy/symlink from the main checkout.
- `quit_emulator` (tools/dosbox_mcp/server.py) verified live twice: BREAK →
  QUIT over the socket, no prompt (`quit warning=false` in both confs), SIGTERM
  fallback in place. `send_raw()` added to socket_client.py for the reply-less
  shutdown path.

### Session B — Lua core library, no seeding yet  *(Stage 1.1 minus `seed.lua`)*
- [x] `symbols.lua`, `input.lua`, `dump.lua`, `scenario.lua` skeleton (+ unplanned
      `gbtext.lua`: encode tilemap assertions via pret's charmap.asm, no hand bytes).
- [x] Smoke scenario: boot ROM → skip intro via `input.lua` → dump
      tilemap/VRAM/OAM of the title or first playable frame.
- **Exit gate:** a `GOLDEN.BIN` + JSON sidecar for the smoke scenario exists and a
  quick Python read-back shows plausible tile IDs (nonzero, charmap-decodable text).

**Session B result (2026-07-06): gate passed.** `smoke_title` boots the golden ROM,
skips the intro, and dumps the main menu; `inspect_golden.py` decodes `▶NEW GAME` /
`OPTION` from the tilemap (360/360 nonzero); golden byte-identical across two runs.
What the next sessions must know:
- **mGBA context rule (bit us immediately):** every mGBA binding — `emu:*`,
  `console:*`, even *indexing `C.GB_KEY`* — errors "Function called from invalid
  context" when called from a coroutine thread (`lua.c _luaGetContext` requires the
  main `lua_State`). `scenario.lua`'s driver therefore executes yielded **thunks** on
  the main state; bodies use `scenario.exec(fn)` / `scenario.read_range(addr, n)` and
  the input helpers, never `emu` directly. `seed.lua` (Session C) must do all WRAM
  writes inside one `scenario.exec` thunk.
- **The main menu acts on START** (selects NEW GAME → Oak speech) — a blind fixed-tap
  mash overshoots. Scenarios navigate state-aware: poll the tilemap via
  `scenario.read_range` for expected text (`gbtext.lua` encodes it from
  `constants/charmap.asm`; first-wins parse — the later Japanese block reuses the
  same byte range) and stop tapping when seen. Inputs stay a pure function of
  emulated state → still deterministic.
- Env contract: `PKMN_SYM` (sym path, default `../pokeyellow_msdos-pret-golden/…`),
  `PKMN_CHARMAP` (default `constants/charmap.asm` relative to cwd), `GOLDEN_DIR`
  (output dir). Scenario scripts self-locate `lib/` via `debug.getinfo` (mGBA chunk
  name = `@<path as invoked>`; its require shim roots at the script's own dir only).
- OAM dumps all-zero on menu screens (no sprites on the main menu) — expected.

### Session C — WRAM seeding + first real goldens  *(rest of 1.1 + 1.2 items 1–2)*
- [x] `seed.lua` mirroring `PrepareNewGameDebug` (open the **port's** seed routine AND
      pret's struct layout; fields are big-endian).
- [x] Scenarios `status_p1`, `status_p2`, `start_menu`; commit goldens +
      `make goldens` target.
- **Exit gate:** `make goldens` regenerates byte-identical goldens twice in a row
  (determinism check); status_p1 golden's tilemap decodes to the expected screen text.

**Session C result (2026-07-06): gate passed.** `make -C dos_port goldens` regenerates
all four goldens (smoke_title, start_menu, status_p1, status_p2) byte-identical across
two consecutive runs (sha1-compared); status_p1 decodes to the full expected screen
(PIKACHU, <LV>5, HP 19/19, №025, STATUS/OK, ATTACK 11 / DEFENSE 8 / SPEED 14 /
SPECIAL 10, TYPE1/ELECTRIC, OT/RED, ID 00000 — hand-checked against pret's CalcStat
formula); status_p2 shows EXP 125 + "LEVEL UP 91→L6" (game-computed from the seeded
EXP) and moves THUNDERSHOCK 30/30, GROWL 40/40, **SURF 0/15** (the port's
poke-after-PP quirk, reproduced by construction). What the next sessions must know:
- **The seed spec is `lib/seed.lua` — the port must converge to it (Session D/E).**
  The port's `PrepareNewGameDebug` gets DVs from `Random_` (add_party_mon.asm:185),
  so its party bytes are irreproducible; seed.lua instead writes explicit structs:
  spec DVs `$98 $76` (Atk9/Def8/Spd7/Spc6 → HP DV 10), OT name "RED", OT/player
  id `$0000`, stats via pret CalcStat (stat exp 0) from ROM BaseStats, EXP via the
  growth-rate polynomials, moves = species base moves with the port's pokes applied
  AFTER PP is written (SURF slot keeps PP 0). **Session D/E port-side TODO:** make the
  port harness deterministic to match — seed `wPlayerName`="RED@", `wPlayerID`=0, and
  overwrite each party mon's DVs with `$98 $76` + recompute stats (or equivalent) in
  the `DEBUG_*` path, so GBSTATE.BIN equals the golden.
- **`DrawStartMenu` always lists POKéMON** (only POKéDEX is event-gated —
  engine/menus/draw_start_menu.asm:36) — the start_menu golden with an empty party
  correctly shows POKéMON/ITEM/RED/SAVE/OPTION/EXIT, box at (10,0), cursor on item 0.
  Golden player stands at Pallet Town **(8,8) facing down** = the port boot spawn
  (overworld.asm:1174).
- **Differ (Session E) mask candidates found now:** Pallet's flower/water tiles
  animate by VRAM tile-DATA swap (tilemap IDs stay put; the pattern bytes cycle with
  frame phase) → VRAM diff needs those slots masked or phase-matched. Status screens
  have a blinking ▼ whose phase depends on dump frame.
- Nav gotchas baked into `lib/navigate.lua` (don't rediscover): door mats warp only
  on a DOWN press (walking across does nothing); held directions latch one extra step
  after release → `walk()` re-measures after an 18-frame stationary window; the party
  menu's ▶ sits one row below the nickname row (`choose(needle, nil, 1)`); dialog
  mashing must tap A only while ▼ is visible; the end of the Oak intro is detected by
  probing START until the menu actually opens (wCurMap is already 38 mid-speech).
- Bedroom route (Yellow layout): spawn (3,6); TV blocks UP at x=3, console blocks
  x=6 on the spawn row → RIGHT 1, UP 5, RIGHT into the (7,1) stairs; 1F: DOWN 6,
  LEFT 4 onto the (3,7) mat, DOWN to exit. House exit lands at Pallet (7,3)-ish.
- `make -C dos_port goldens` = `tools/mgba_harness/make_goldens.sh`: sha1-gates the
  ROM against `roms.sha1` before running; scenarios must run with cwd = repo root
  (gbtext resolves `constants/charmap.asm` relative to cwd).

### Session D — port-side `GBSTATE.BIN`  *(Stage 1.3)*
- [x] `DumpGBState` in `debug_dump.asm`; wire alongside every `DumpBackbuffer` hook.
- **Exit gate:** headless `DEBUG_STATUS=1` run yields a `GBSTATE.BIN` (extracted via
  mcopy) whose tilemap region shows the status screen's text tiles.

**Session D result (2026-07-07): gate passed.** `DumpGBState` writes `GBSTATE.BIN`
(16-B header `GBST`+version+scenario-id, then `W_TILEMAP` 1000 B (40×25), VRAM
`0x8000–0x97FF`, OAM `0xFE00` — 7320 B total) and **returns**; it's called from the
top of `DumpBackbuffer`, so all ~25 existing FRAME.BIN hooks emit it with zero
call-site edits. Headless `DEBUG_STATUS=1`: tilemap decodes the full status screen,
byte-identical GBSTATE.BIN across two runs. What the next sessions must know:
- **The Session C port-side determinism TODO is done** (was half-started uncommitted
  work; finished here): `PrepareNewGameDebug` seeds `wPlayerName`="RED@…",
  `wPlayerID`=0 **before** the party build, then post-build overwrites every mon's
  DVs with spec `$98 $76`, zeroes stat exp, recomputes stats via
  GetMonHeader+CalcStats (stat exp ignored) and sets HP=MaxHP. Verified live: OT/RED,
  ID 00000, PIKACHU L5 HP 19/19, Atk 11/Def 8/Spd 14/Spc 10 — the golden's values.
- **status screens' 20×18 subwindow offset is (col 10, row 3)** in the 40×25 canvas —
  the per-scenario offset golden_diff.py needs. Non-text divergences the differ must
  expect: mon-pic tile IDs and HP-bar tiles differ from golden tile numbering only
  where VRAM layout differs — compare via VRAM region, not assumption.
- Possible seed-spec residue for party-WRAM diffs (NOT tilemap-visible): pret
  `_AddPartyMon` may write the box-level byte (struct offset 3) = level where
  seed.lua writes 0 — check before diffing party WRAM windows in Session F.
- Extraction recipe gains `::GBSTATE.BIN` next to `::FRAME.BIN` (mdel stale copies
  first, as ever).

### Session E — differ + end-to-end proof  *(Stage 1.4)*
- [x] `golden_diff.py` + `make goldencheck` / `make fidelity`.
- [x] Proof: goldencheck green on fixed tree; revert `LoadStatusScreenHudTilePatterns`
      locally → goldencheck red pointing at the exact VRAM slots/cells; restore.
- **Exit gate:** the revert-proof (green → red → green) reproduced and pasted into the
  session note.

**Session E result (2026-07-07): gate passed.** `make fidelity` (status_p1, status_p2,
start_menu) green; revert-proof: widening the BattleHudTiles1 load 3→8 tiles turned
goldencheck red with exactly `vChars2 tile $70/$71/$73/$74` named ($73=<ID>, $74=№ —
the motivating clobber class), restore → green. Design deltas + findings the next
sessions must know:
- **Scenario config lives in `golden_diff.py` `SCENARIOS`** (offset/masks/projections/
  make-flags), NOT the golden sidecar as the stage text guessed — the offset is
  port-side knowledge the mGBA scenario can't know. `goldencheck.sh` reads the make
  flags from it (`--flags`), so one table drives build+run+diff.
- **FINDING (filed): starter-Pikachu status runs Yellow's PikaPic cartoon** (drawn via
  direct BG-map writes that never touch wTileMap; cel gfx streamed over vChars0).
  Unported → the whole 7×7 pic area + vChars0 + stale vChars2 $20-$5F are masked with
  justifications on status_p1/p2. The static 5×5 pic pattern data at $9000-$918F IS
  compared and matches. If PikaPic ever ports, drop `_STATUS_MASKS`.
- **Menus over the overworld need projections**: the widescreen port re-anchors the
  START menu at X+20 (docs/ui_projection.md registry) — differ config supports
  per-rect `projections`. The overworld backdrop's W_TILEMAP window is the
  **block-aligned mirror**, offset (16,10) at the (8,8) spawn (measured; NOT the
  (10,3) flat-canvas offset status screens use), and golden rows 15-17 fall off the
  25-row canvas (justified via `offcanvas`).
- **OAM normalization**: entries hidden on both sides (Y==0 or Y>=160) compare equal
  (golden parks stale tiles at Y=160; port zeroes its slots).
- Flower ($03)/water ($14) vChars2 tile-data animation masked on start_menu by phase
  (as Session C predicted). If a later scenario dumps at a luckier frame these may
  match — masks only fire on mismatch.
- Port fix that fell out: `DEBUG_STARTMENU` never seeded the player name → menu row
  showed the build define "NINTEN"; now `SeedDeterministicPlayerIdentity` (extracted
  from `PrepareNewGameDebug`, exported) runs in the gate. debug_party.o linked into
  the DEBUG_STARTMENU build in the Makefile.

### Session F — remaining scenarios  *(1.2 items 3–4)*
- [x] `overworld_pallet`, `party_menu`, `bag_menu` goldens + port-side
      diff runs; per-scenario masks only with a written justification each.
- [ ] `battle_menu` — **deferred, filed as a finding (below)**.
- **Exit gate:** `make fidelity` green across all scenarios (or red entries filed as
  findings in the session note — a true divergence found here is a WIN, not a blocker;
  file it, mask it with justification, move on).

**Session F result (2026-07-07): gate passed** — `make fidelity` green across all six
scenarios (status_p1/p2, start_menu, overworld_pallet, party_menu, bag_menu). New
goldens byte-identical across two `make goldens` runs; the four committed goldens
regenerated bit-identical. What the next sessions must know:
- **battle_menu DEFERRED (finding):** the port's `DEBUG_BATTLE` harness hand-seeds a
  synthetic enemy (`PIDGEY` with temp HP 200, custom PP for the PP-depletion test —
  values marked REVERT in debug_dump.asm) that no real encounter produces, and a
  golden would need a deterministic *real* wild encounter (RNG-dependent species/
  DVs) or an agreed seed spec like seed.lua's party. Needs its own convergence spec
  (post-plan or a later session); not a differ limitation.
- **Widescreen UI re-layouts are handled by per-rect `projections`** (measured and
  byte-verified): party = name rows 2i→row i left panel, HP rows→right panel (+20),
  6-row message box → 3 rows × 2 panels; bag = 2-rows-per-item → names left/qty
  right. The overworld backdrop window is (16,10) at the (8,8) spawn everywhere.
- **Real fixes that fell out:** DEBUG_PARTYMENU dumped before the ▶ cursor existed —
  hook now runs PlaceMenuCursor + PartyMenuMirror pre-dump (golden dumps inside
  HandleMenuInput where the cursor is placed).
- **Divergence classes masked with justification** (see `SCENARIOS` in
  golden_diff.py): stale-history VRAM (SKIP_TITLE boot leaves vChars1 tail zeroed
  where GB has font-digit residue; stale vChars2 $00-$5F under full-redraw menus);
  RNG NPC wander (OAM); GB hides the player sprite under centered menus while the
  widescreen port's re-anchored boxes leave it visible; flower/water tile-data
  animation phase; GB animated OAM party icons vs port static BG icon tiles; GB
  keeps the START-menu box visible beside the ITEM list, port panel-redraws.
- seed.lua gained `seed.items` (DEBUG_ITEMS = the port's DebugNewGameItemsList
  verbatim). Badges/dex flags still unseeded (no scenario renders them yet).

### Session G — mgba-mcp bridge  *(Stage 1.5)*
- [x] `mcp_agent.lua` + `mgba_mcp/server.py` + `run_mgba_mcp.sh` (copy dosbox_mcp
      structure).
- **Exit gate:** from an MCP client: boot, `run_frames`, `press_buttons` to open START
  menu, `gb_read wTileMap` shows the menu tiles, `quit` exits clean.

**Session G result (2026-07-07): gate passed.** A real MCP stdio client drove
server.py end-to-end: boot → main menu → NEW GAME → preset naming → in-game START
menu (wCurMap $26 = REDS_HOUSE_2F), EXIT/OPTION/SAVE verified via `gb_read wTileMap`,
screenshot PNG confirmed visually, `quit` exited clean. What the next sessions must
know:
- **The agent gives the free-running runner debugger semantics by BLOCKING inside
  the "frame" callback** while no time-advancing command is pending (polling its TCP
  socket at 50 ms); `run_frames`/`press` release it for exactly N frames, reply on
  re-pause. TCP (127.0.0.1:$MGBA_MCP_PORT, default 8765), newline-delimited JSON —
  mGBA's Lua socket API is TCP-only (no Unix sockets).
- **mGBA Lua socket gotchas:** `socket.bind` returns a WRAPPER (lua.c
  `_socketLuaSource`) exposing `receive/hasdata/accept/send`; `listen()` returns
  `(ok, err)` — err nil on success (a bare status check reads success 1 as failure);
  timed waits must go through the raw handle `sock._s:select(ms)`; `socket.ERRORS`
  is effectively empty — error strings are 'disconnected'/'error#N'.
- Tools: gb_read (pret label via golden .sym, resolved agent-side), run_frames,
  press_buttons, dump_state/load_state, screenshot, current_frame, quit.
- run_mgba_mcp.sh sha1-gates the ROM like make_goldens.sh. Start it first, then
  server.py (MCP stdio).
- ⚠ shell gotcha: `pkill -f mgba-lua-runner` matches your own compound command —
  use `pkill -x mgba-lua-runner`.

### Session H — label DB + linter  *(Stage 2.1)*
- [ ] Scanner `update_label_db` + `labels`/`calls`/`externs` tables in `translation.db`
      (additive; don't break `work_queue`); `lint_pret_labels` as queries over it;
      allowlist sidecar.
- [ ] Run over the whole tree; triage output into: real violations (fix trivial ones),
      allowlist/`relocated` candidates, and **decisions-for-user** (do NOT auto-resolve
      judgment calls — list them).
- **Exit gate:** linter exits 0 on the tree with the draft allowlist; rescan is
  idempotent (two runs, identical DB); session note contains the categorized findings
  list for user review.

### Session I — faithdiff + label_status  *(Stages 2.2 + 2.4 CLI)*
- [ ] `faithdiff <PretLabel>` CLI + suppression list.
- [ ] `label_status <Label> --callees` reusing faithdiff's call-target extractor over
      the Session H DB; `--callers` over the `calls`/`externs` tables.
- **Exit gate:** `faithdiff StatusScreen` and `faithdiff PrepareOAMData` outputs
  manually spot-checked against the pret sources and pasted into the session note;
  `label_status --callees StatusScreen` correctly classifies every callee
  (translated/stub/missing) against a manual grep of two of them;
  `label_status --callers` on one currently-stubbed label matches a manual grep of
  its externs.

### Session J — review-gate skill + wrap-up  *(Stages 2.3 + 2.4 skill wiring)*
- [ ] `.claude/skills/faithfulness-review/` skill; one-line reference from CLAUDE.md
      hard rules.
- [ ] Wire `label_status --callees` + post-change `update_label_db` steps into the
      `asm-translation` and `project-conventions` skills (Stage 2.4).
- [ ] Archive this plan per convention (`git mv` to `docs/plans/fidelity_harness.md`)
      **only if** all sessions' gates passed; else leave active with a status summary.
- **Exit gate:** skill invocable; CLAUDE.md line present; plan archived or status noted.

---

## Part 1 — mGBA golden harness (Lua)

### Stage 1.0 — Vendor + build + golden ROM
- [x] Add submodule `dos_port/tools/mgba` @ latest 0.10.x tag (**0.10.5**); build script
      `dos_port/tools/build_mgba.sh` (model: `build_dosbox_mcp.sh`) — CMake with
      scripting/Lua enabled (`-DENABLE_SCRIPTING=ON`, Lua dep).
- [x] **Verify the headless scripting entry point before anything else**: the unknown
      resolved negative — no stock frontend takes scripts headlessly in 0.10.5.
      **User chose the libmgba-runner fallback**: `tools/mgba_harness/runner.c` →
      `tools/mgba_build/mgba-lua-runner`; Lua env verified (memory, key injection via
      core methods, frame callbacks, `socket`, file I/O).
- [x] Build the golden ROM ~~at repo root~~ in the pinned pristine worktree
      `../pokeyellow_msdos-pret-golden/` (`make yellow`), checked against `roms.sha1`.
      Goldens are only ever generated from a sha1-verified ROM.

### Stage 1.1 — Core Lua library (`dos_port/tools/mgba_harness/lib/`)
Shared by batch scenarios and the MCP bridge:
- [x] `symbols.lua` — parse `pokeyellow.sym` so all addresses are by pret label
      (`wTileMap`, `wPartyMons`, …), never hardcoded.
- [x] `dump.lua` — dump named regions to a `GOLDEN.BIN` (fixed layout + JSON sidecar
      naming regions/sizes/scenario): `wTileMap` 20×18 (360 B), VRAM `0x8000–0x97FF`
      (6144 B), OAM `0xFE00` (160 B), plus scenario-specific WRAM windows.
- [x] `input.lua` — frame-stepped press/hold/release helpers.
- [x] `seed.lua` — WRAM seeding mirroring the port's `PrepareNewGameDebug` (same party
      structs — big-endian fields — flags, dex, names), addresses via `symbols.lua`.
      (Party + player identity only so far; badges/items/dex-flag seeding lands with
      the Session F scenarios that render them. seed.lua is the byte-level SPEC the
      port harness must match — see Session C result.)
- [x] `scenario.lua` — runner: boot ROM → settle frames → seed → navigate via input →
      settle → dump → exit(0). Savestate caching as local speed-up only.
      (+ `gbtext.lua` — charmap-encoded text assertions, parsed from pret's
      `constants/charmap.asm`; Session B addition.)

### Stage 1.2 — Scenario scripts + committed goldens
`dos_port/tools/mgba_harness/scenarios/<name>.lua`, goldens committed at
`dos_port/tests/goldens/<name>.bin` + `.json`. Initial set (mirrors existing port
`DEBUG_*` gates; motivating bugs first):
- [x] `status_p1`, `status_p2` (↔ `DEBUG_STATUS[_PAGE2]`)
- [x] `start_menu` (↔ `DEBUG_STARTMENU`)
- [x] `overworld_pallet` baseline (↔ `DEBUG_TRANSITION`/`DEBUG_BASELINE`)
- [x] `party_menu`, `bag_menu` (↔ their `DEBUG_*` twins); `battle_menu` deferred
      (Session F finding: port battle harness is synthetic-seeded, needs a spec)
- [x] `make goldens` target regenerates all (requires built mGBA + sha1-verified ROM).

### Stage 1.3 — Port-side GB-state dump (`GBSTATE.BIN`)
- [x] New routine `DumpGBState` in `dos_port/src/debug/debug_dump.asm` (parallel to
      `DumpBackbuffer`): full `W_TILEMAP` (1000 B, 40×25), VRAM `0x8000–0x97FF`, OAM
      `0xFE00` (160 B), small header with scenario id — all `[EBP+addr]` reads like
      existing windows.
- [x] Call it alongside every existing `DumpBackbuffer` hook so each `DEBUG_*` scenario
      emits `FRAME.BIN` + `GBSTATE.BIN`. Extract via the existing `mcopy …@@1048576`
      recipe. (Done structurally: `DumpGBState` returns, and `DumpBackbuffer` calls it
      first — every present and future hook is covered with no call-site edits.)

### Stage 1.4 — Differ + make target
- [x] `dos_port/tools/golden_diff.py`: extract port 20×18 subwindow from the 40×25
      canvas at a **per-scenario (col,row) offset** (kept in the differ's `SCENARIOS`
      table, not the sidecar — port-side knowledge; see Session E note);
      cell-by-cell tile-ID diff vs golden `wTileMap`, decoding text tiles via
      `assets/gb_charmap.txt` in the report (row/col, expected vs got, glyph). OAM diff
      with hidden-entry normalization (Y==0/Y>=160 equal both sides); VRAM diff
      per 16-byte tile with slot numbers (caught the `$73/$74` clobber in the
      revert-proof directly). Per-scenario mask list + per-rect UI `projections`
      + `offcanvas` justification for legitimately-divergent cells.
- [x] `make -C dos_port goldencheck SCENARIO=status_p1`: build image with the matching
      `DEBUG_*` flag → headless dosbox-x run → extract `GBSTATE.BIN` → diff → nonzero
      exit + cell report on mismatch. `make fidelity` = all scenarios. (GitHub CI
      wiring deferred — needs dosbox-x + mGBA builds in CI.)

### Stage 1.5 — MCP bridge (the laziness layer)
- [x] `mcp_agent.lua`: resident script using mGBA's Lua socket API; command loop over a
      TCP socket (mGBA Lua sockets are TCP-only — see Session G note; read memory by
      label, press buttons, run N frames, save/load state, screenshot). Reuses `lib/`.
- [x] `dos_port/tools/mgba_mcp/server.py`: thin Python MCP server, structural twin of
      `tools/dosbox_mcp/server.py` (tools: `gb_read`, `press_buttons`, `run_frames`,
      `dump_state`, `load_state`, `screenshot`, `quit`). Launcher `run_mgba_mcp.sh`
      (model: `run_with_mcp.sh`).
- Result: differential debugging with an MCP session on each side — dosbox-mcp on the
  port, mgba-mcp on ground truth, same label-addressed reads.

## Part 2 — Static anti-divergence tooling

### Stage 2.1 — per-label translation DB + `lint_pret_labels` (model: `build_index`)
The label index IS the database: one scanner populates a per-label SQLite table, the
linter is queries over it, and the label-status skill (Stage 2.4) reads it. **The DB
is always derived by rescanning the tree — never hand-edited and never written
directly by agents** — so a missed update self-heals on the next scan instead of
lying. Extend the existing `dos_port/tools/translation.db` **additively** (new
`labels` table + views; `build_index`/`work_queue`'s file-level tables untouched —
they may be superseded later, not in this plan).
- [ ] Scanner (`tools/update_label_db`, callable standalone and by the linter): index
      pret routine labels from root `home/` + `engine/` (top-level labels; skip
      `data/` — that's generator-owned), and every `global` in `dos_port/src/**/*.asm`
      with defining file + whether it's a `*_stubs.asm`.
- [ ] `labels` table: label, pret source file, port file (NULL = untranslated), status
      (`translated` / `stub` / `missing` / `relocated`), stub file if any, scan
      timestamp + git hash. Committed like `translation.db` is today.
- [ ] `calls` edge table (caller label → callee label, side = pret|port) and `externs`
      table (port file, symbol, trailing comment text). Both fall out of the same
      parse pass. This gives dependency-tree queries — "who calls X" — used by stub
      retirement (below) and makes the stale-extern-comment lint a plain query.
      Note callers need **no code change** when a stub is retired (they `extern` the
      label; the linker re-resolves) — the callers query exists for the two things
      linking can't fix: repointing extern trailing comments (stub convention rule 3),
      and auditing callers translated against stub-era behavior (register/flag
      contracts, side effects the stub never produced, bespoke workarounds).
- [ ] `lint_pret_labels`: violations as DB queries (nonzero exit): pret-named global
      defined neither in its path-mirrored file nor a `*_stubs.asm`; stub whose body
      isn't ret-only (the "silently patched instead of stubbed" GetName class);
      duplicate definitions (silent-shadow trap); `extern` comments pointing at a stub
      file that no longer defines the symbol.
- [ ] Sidecar allowlist for deliberate relocations (e.g. `home/pikachu.asm` →
      `src/engine/overworld/pikachu.asm`) → `relocated` status, not a violation.

### Stage 2.2 — `dos_port/tools/faithdiff <PretLabel>` (Python CLI)
- [ ] Extract pret's routine body (label → next exported label) and its **call/store
      graph**: `call/jp/jr/rst` targets, `predef`/`farcall`/`callfar` macro targets,
      stores to named wram/hram symbols.
- [ ] Extract the port mirror's body the same way (`call/jmp` targets,
      `[ebp + W_*/H_*]` stores).
- [ ] Report: calls/stores the port **added**, **dropped**, or **substituted** vs
      pret — with a suppression list for known translation boundaries (`TODO-HW`,
      `DelayFrame` plumbing, `ds_base` biasing helpers). Not a semantic prover; a
      forcing function that makes "port calls LoadHudTilePatterns; pret doesn't" fall
      out automatically.

### Stage 2.3 — Review-gate skill
- [ ] New project skill `.claude/skills/faithfulness-review/`: any change touching a
      pret-labeled routine must run `faithdiff` on each touched label and justify every
      added/dropped call in the commit message; run `lint_pret_labels` before
      committing. Reference it from CLAUDE.md's hard rules (one line) and from the
      code-review flow.

### Stage 2.4 — `label_status` CLI + translation-workflow skill wiring
The "check before you call" layer: when translating a routine, every `call`/`jp`/
`predef` target in the pret source either already exists in the port (extern it),
is stubbed (extern it, comment names the stub file), or is missing (add a stub per
convention). Today agents resolve this by grepping — or don't, which is how
`GetName` got silently patched.
- [ ] `tools/label_status <Label> [...]`: query the Stage 2.1 DB — status, defining
      file, stub file. With `--callees <Label>`: extract the pret routine's call
      targets (reuse faithdiff's extractor from 2.2) and report each target's status —
      one command answers "what do I extern vs stub for this translation?".
- [ ] `label_status --callers <Label>`: every port routine calling `<Label>` (from the
      `calls` table) + every file `extern`ing it with its comment. This is the **stub
      retirement checklist**: repoint each extern comment, then eyeball each caller
      for stub-era assumptions (was it translated/verified while `<Label>` was a
      `ret`-stub? does it depend on registers/flags the real body clobbers?).
- [ ] Add the `--callers` retirement step to the stub-retirement rules in the
      `project-conventions` skill (rule 5 gains: "run `label_status --callers` and
      work the list").
- [ ] Wire into the `asm-translation` skill's 7-step workflow: new step after "pick a
      routine" — run `label_status --callees <Label>`; and a final step — run
      `tools/update_label_db` after the translation/stub lands so the DB reflects it
      (rescan-derived, so skipping this is self-healing, not corrupting).
- [ ] Same post-change rescan step added to the stub instructions in the
      `project-conventions` skill.

## Scope add — dosbox-x-mcp unattended quit fix

- [x] Add `quit warning = false` to the `[dosbox]` section of the conf generated in
      `dos_port/tools/run_with_mcp.sh` (and mirror in `dos_port/dosbox-x.conf` for the
      plain `run` pipeline). `CheckQuit()` then returns true with no dialog — no C++
      patch change.
- [x] Add a `quit_emulator` MCP tool to `tools/dosbox_mcp/server.py` (clean shutdown
      via the debugger socket — BREAK then the debugger's existing `QUIT` command —
      with SIGTERM fallback) so agents never rely on window-close. Verified live.

## Verification

- **Stage 1.0**: built ROM sha1 matches `roms.sha1`; a hello-world Lua script prints
  from headless mGBA and exits.
- **End-to-end proof (after 1.4)**: `make goldencheck SCENARIO=status_p1` passes on the
  current (fixed) tree; then locally revert one status-screen fix (e.g. the
  `LoadStatusScreenHudTilePatterns` tile layout) and confirm the differ fires with the
  exact VRAM slots / tilemap cells — proving the harness would have caught the original
  bugs. Restore.
- **2.1**: linter run over the tree; triage every finding as real (fix or allowlist
  with justification) — expected to rediscover any remaining silently-patched labels.
- **2.2**: smoke `faithdiff StatusScreen` and `faithdiff PrepareOAMData`; confirm the
  reports match pret manually.
- **Quit fix**: launch `run_with_mcp.sh` headless, call the new `quit_emulator` tool
  (and separately window-close) — DOSBox-X exits with no confirmation prompt.
