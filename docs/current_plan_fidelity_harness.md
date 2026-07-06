# Fidelity Harness — mGBA golden differential testing + anti-divergence static tooling

Worktree: `/mnt/sdb1/Code/Active Code/pokeyellow_msdos-fidelity_harness` (branch `fidelity_harness`).

Status: **planned 2026-07-06, not started.** Branch TBD (likely cut from `master` after
the status-screen fixes land).

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
- [ ] `symbols.lua`, `input.lua`, `dump.lua`, `scenario.lua` skeleton.
- [ ] Smoke scenario: boot ROM → skip intro via `input.lua` → dump
      tilemap/VRAM/OAM of the title or first playable frame.
- **Exit gate:** a `GOLDEN.BIN` + JSON sidecar for the smoke scenario exists and a
  quick Python read-back shows plausible tile IDs (nonzero, charmap-decodable text).

### Session C — WRAM seeding + first real goldens  *(rest of 1.1 + 1.2 items 1–2)*
- [ ] `seed.lua` mirroring `PrepareNewGameDebug` (open the **port's** seed routine AND
      pret's struct layout; fields are big-endian).
- [ ] Scenarios `status_p1`, `status_p2`, `start_menu`; commit goldens +
      `make goldens` target.
- **Exit gate:** `make goldens` regenerates byte-identical goldens twice in a row
  (determinism check); status_p1 golden's tilemap decodes to the expected screen text.

### Session D — port-side `GBSTATE.BIN`  *(Stage 1.3)*
- [ ] `DumpGBState` in `debug_dump.asm`; wire alongside every `DumpBackbuffer` hook.
- **Exit gate:** headless `DEBUG_STATUS=1` run yields a `GBSTATE.BIN` (extracted via
  mcopy) whose tilemap region shows the status screen's text tiles.

### Session E — differ + end-to-end proof  *(Stage 1.4)*
- [ ] `golden_diff.py` + `make goldencheck` / `make fidelity`.
- [ ] Proof: goldencheck green on fixed tree; revert `LoadStatusScreenHudTilePatterns`
      locally → goldencheck red pointing at the exact VRAM slots/cells; restore.
- **Exit gate:** the revert-proof (green → red → green) reproduced and pasted into the
  session note.

### Session F — remaining scenarios  *(1.2 items 3–4)*
- [ ] `overworld_pallet`, `party_menu`, `bag_menu`, `battle_menu` goldens + port-side
      diff runs; per-scenario masks only with a written justification each.
- **Exit gate:** `make fidelity` green across all scenarios (or red entries filed as
  findings in the session note — a true divergence found here is a WIN, not a blocker;
  file it, mask it with justification, move on).

### Session G — mgba-mcp bridge  *(Stage 1.5)*
- [ ] `mcp_agent.lua` + `mgba_mcp/server.py` + `run_mgba_mcp.sh` (copy dosbox_mcp
      structure).
- **Exit gate:** from an MCP client: boot, `run_frames`, `press_buttons` to open START
  menu, `gb_read wTileMap` shows the menu tiles, `quit` exits clean.

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
- [ ] `symbols.lua` — parse `pokeyellow.sym` so all addresses are by pret label
      (`wTileMap`, `wPartyMons`, …), never hardcoded.
- [ ] `dump.lua` — dump named regions to a `GOLDEN.BIN` (fixed layout + JSON sidecar
      naming regions/sizes/scenario): `wTileMap` 20×18 (360 B), VRAM `0x8000–0x97FF`
      (6144 B), OAM `0xFE00` (160 B), plus scenario-specific WRAM windows.
- [ ] `input.lua` — frame-stepped press/hold/release helpers.
- [ ] `seed.lua` — WRAM seeding mirroring the port's `PrepareNewGameDebug` (same party
      structs — big-endian fields — flags, dex, names), addresses via `symbols.lua`.
- [ ] `scenario.lua` — runner: boot ROM → settle frames → seed → navigate via input →
      settle → dump → exit(0). Savestate caching as local speed-up only.

### Stage 1.2 — Scenario scripts + committed goldens
`dos_port/tools/mgba_harness/scenarios/<name>.lua`, goldens committed at
`dos_port/tests/goldens/<name>.bin` + `.json`. Initial set (mirrors existing port
`DEBUG_*` gates; motivating bugs first):
- [ ] `status_p1`, `status_p2` (↔ `DEBUG_STATUS[_PAGE2]`)
- [ ] `start_menu` (↔ `DEBUG_STARTMENU`)
- [ ] `overworld_pallet` baseline (↔ `DEBUG_TRANSITION`/`DEBUG_BASELINE`)
- [ ] then: `party_menu`, `bag_menu`, `battle_menu` (↔ their `DEBUG_*` twins)
- [ ] `make goldens` target regenerates all (requires built mGBA + sha1-verified ROM).

### Stage 1.3 — Port-side GB-state dump (`GBSTATE.BIN`)
- [ ] New routine `DumpGBState` in `dos_port/src/debug/debug_dump.asm` (parallel to
      `DumpBackbuffer`): full `W_TILEMAP` (1000 B, 40×25), VRAM `0x8000–0x97FF`, OAM
      `0xFE00` (160 B), small header with scenario id — all `[EBP+addr]` reads like
      existing windows.
- [ ] Call it alongside every existing `DumpBackbuffer` hook so each `DEBUG_*` scenario
      emits `FRAME.BIN` + `GBSTATE.BIN`. Extract via the existing `mcopy …@@1048576`
      recipe.

### Stage 1.4 — Differ + make target
- [ ] `dos_port/tools/golden_diff.py`: extract port 20×18 subwindow from the 40×25
      canvas at a **per-scenario (col,row) offset** from the golden's JSON sidecar;
      cell-by-cell tile-ID diff vs golden `wTileMap`, decoding text tiles via
      `assets/gb_charmap.txt` in the report (row/col, expected vs got, glyph). OAM diff
      with optional coordinate normalization (port pins camera differently); VRAM diff
      per 16-byte tile with slot numbers (would have caught the `$73/$74` clobber
      directly). Per-scenario mask list for legitimately-divergent cells (e.g.
      widescreen-only columns are excluded by construction of the subwindow).
- [ ] `make -C dos_port goldencheck SCENARIO=status_p1`: build image with the matching
      `DEBUG_*` flag → headless dosbox-x run → extract `GBSTATE.BIN` → diff → nonzero
      exit + cell report on mismatch. `make fidelity` = all scenarios. (GitHub CI
      wiring deferred — needs dosbox-x + mGBA builds in CI.)

### Stage 1.5 — MCP bridge (the laziness layer)
- [ ] `mcp_agent.lua`: resident script using mGBA's Lua socket API; command loop over a
      Unix socket (read memory by label, press buttons, run N frames, dump state,
      save/load state, screenshot). Reuses `lib/` modules.
- [ ] `dos_port/tools/mgba_mcp/server.py`: thin Python MCP server, structural twin of
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
