# Menus Swarm — Session 7 (wave 2) launch prompts

Session 7 of `docs/current_plan_menus.md`: three parallel worker packages —
**E** (main_menu), **H** (save.asm UI + structure), **C** (naming_screen) —
plus a **root-first** save-I/O layer (`src/save/dsv_io.asm`) that E and H build
on. Workers run as **Opus** subagents (S6 precedent; C is logic-only and should
be Sonnet to save plan budget — user's call), one package per agent,
each in its own seeded worktree.

Requires: S6 landed (`a5302a80` on `menus-port`, all four wave-1 packages in).
Root = the coordinating session that writes the save layer, seeds the worktrees,
integrates, and gates.

This is the FIRST session with real file I/O and the FIRST cross-package data
dependency (E + H both need `dsv_io.asm`), so the root-first order matters more
than in S6. Read the "Root checklist" top-to-bottom before launching anyone.

---

## Root checklist (do these yourself, not in a brief)

1. **Root-first: write `src/save/dsv_io.asm` BEFORE seeding.** This is the save
   HAL both E and H extern; it must exist + link green before the workers seed,
   exactly like S6's gen_badge_tiles/UI-elements prework.
   - Reuse `debug_dump.asm`'s DPMI "Simulate Real Mode Interrupt" (INT 31h/0300h)
     file path — `int 21h` pointer args are NOT auto-translated under CWSDPMI, so
     copy the conventional-DOS-buffer + AH=3Ch/3Dh/3Fh/40h/3Eh (create/open/read/
     write/close) dance from there. Grep `dos_port/src/debug/debug_dump.asm` for
     the buffer + INT 31h setup and factor the shared bits out (don't duplicate).
   - `.dsv` format (CLAUDE.md "Save File Notes"): `DOSV` magic (4) + version byte
     (1) + 2-byte checksum (LE) + payload. **Decide the payload NOW (root):**
     "minimal real" = a fixed-layout blob of the WRAM the save needs (player name,
     party, current box, item bag, badges, Pokédex owned/seen, play time, money) —
     NOT a faithful 32 KB SRAM bank image yet. Document the byte layout in a
     header comment; keep it version-gated so a future faithful-SRAM format can
     bump the version. saveconv.py (below) must be able to describe it.
   - Export at least: `DsvFileExists` (CF/AL = a valid `DOSV` file is present),
     `DsvWriteSave` (serialize the WRAM payload + header + checksum → `POKEMON.DSV`
     on C:), `DsvReadSave` (load it back). Give each a documented return contract
     (E and H code against these names — publish the signatures in the briefs).
   - Add `src/save/dsv_io.asm` → the Makefile SRCS, build + `make check` green,
     THEN seed. Add any new WRAM (`wSaveFileStatus`, save scratch) to
     `gb_memmap.inc` yourself, sym-verified.
2. **Root-owned generator for package C:** write `dos_port/tools/gen_alphabets.py`
   (Tier-1: pret `data/text/alphabets.asm` `UpperCaseAlphabet`/`LowerCaseAlphabet`
   grid strings + `gfx/font/ED.1bpp` → `assets/alphabets.inc`: the charmap-encoded
   grid rows + the ED tile bytes + counts). Add its `assets` rule; run
   `make -C dos_port assets`. C codes against the emitted symbol names (publish
   them in C's brief). Do it before seeding.
3. **Layout freeze — pre-add the new `UI_*` elements before seeding** (root edit
   to the sidecar via the editor + `make assets`, S6 pattern; seed from the pret
   GB rects at the standard center/top anchor unless full-takeover). Derive rects
   from the pret source yourself, as in S6:
   - `UI_MAIN_MENU` (E): the CONTINUE/NEW GAME/OPTION textbox — pret main_menu.asm
     `TextBoxBorder` at its hlcoord/`lb bc`. Small, right/top or center/top.
   - `UI_CONTINUE_INFO` (E): the "continue game" info panel (PLAYER/BADGES/
     POKéDEX/TIME) — DisplayContinueGameInfo's box. Likely full-ish, center/top.
   - `UI_NAMING_SCREEN` (C): the full letter-grid screen — full 20×18 takeover,
     center/top (like UI_OPTIONS).
   - `UI_CHANGE_BOX` (H): the box-select list for ChangeBox — a list box; check
     ChangeBox's hlcoord.
   Let the workers CITE these; they report the exact rect they need and root
   fixes any mismatch between waves (S6 precedent).
4. **Seed each worktree** after prework: copy `dos_port/assets/*.inc` + all
   `.2bpp/.pic/.1bpp` from the primary (hardlink is fine — workers can't modify
   assets; S6 used `ln -f` off `git ls-files --others --ignored`). Re-seed +
   re-`make check` if a generator lands mid-wave. Verify the seed built green
   (`make -C <wt>/dos_port check`) before the worker starts.
5. **Integration gates per package, in order** (plan "Worker rules"):
   (1) branch-by-branch pret control-flow diff; (2) tag audit (`; PROJ` /
   `; TODO-HW:` / `; DEVIATION:` only); (3) PROJ-geometry-cites-UI_* audit;
   (4) `make check` + `make`; (5) TODO-HW return-contract audit. Then Makefile
   entry + `debug_dump.asm`/overworld harness wiring + commit — **root only**.
6. **New WRAM: derive against `origin/symbols:pokeyellow.sym`, do NOT trust the
   worker's proposed address.** S6 caught TWO wrong worker addresses this way
   (D's `wOptionsCursorLocation` 0xD029→**0xCD3D**, A's whole HoF cluster). The
   sym is `git show origin/symbols:pokeyellow.sym` — many save/naming vars live
   in the same 0xCC../0xCD.. scratch unions, so aliasing is expected and fine.
7. **Cross-package coordination unique to S7 — handle these at integration:**
   - **H provides the real `LoadHallOfFameTeams`** (pret save.asm:645). When H
     lands, **delete the `LoadHallOfFameTeams` `ret`-stub from
     `src/engine/menus/league_pc_stubs.asm`** (keep the `Func_7033f` stub until
     the HoF movie). `wNumHoFTeams` still stays 0 until the HoF-movie writer
     lands, so package A's league PC keeps showing the no-teams path — that's
     correct; don't "fix" it.
   - **E owns `InitOptions`** (the `wOptionsInitialized` byte D deferred to this
     package). E writes the default `wOptions` (verify the bit layout matches D's
     gb_memmap equates: text speed bits 3-0, BIT_BATTLE_SHIFT 6, BIT_BATTLE_ANIMATION
     7, SOUND_MASK 0x30) + `wOptionsInitialized`. Add `wOptionsInitialized` to
     gb_memmap (sym-verified) at integration.
   - **`SpecialEnterMap` is root-wired.** The port already boots into the
     overworld via `SKIP_TITLE`; E's main menu should hand off to the overworld
     boot the way SKIP_TITLE does. Wire the actual map-entry seam yourself; E just
     exports `MainMenu` and reaches a `SpecialEnterMap` seam you provide (stub or
     real). This is integration-spine work, not a worker deliverable.
   - **SRAM banking regs → the .dsv file.** pret's `rRAMG`/`rBMODE`/`rRAMB` +
     `sPlayerName`/`sBox*` SRAM symbols have no port hardware; every such access
     is `; TODO-HW:` collapsing to a `dsv_io` call or a WRAM read. Audit these in
     H (SaveGameData/ChangeBox) and E (CheckForPlayerNameInSRAM).
8. **Update `dos_port/tools/saveconv.py`'s stub header** to describe the now-real
   `.dsv` layout dsv_io.asm writes (it stays a stub for the GB `.sav` ↔ DOS `.dsv`
   conversion until Phase 5, but the header should stop saying "format TBD").
9. **Window row-bands in use** (collision registry — new screens pick free bands
   or are full takeovers): GB_TILEMAP0: list 0-10, qty 12-14, yes/no 16-20,
   USE/TOSS 21-25. GB_TILEMAP1: START box + dialog 0-15 / 0-5, party/options/
   main-menu panel 0-17, message 12-17. Naming screen (C) is a full GB_TILEMAP1
   takeover (like options).

---

## Shared context block (paste at the top of EVERY brief, verbatim)

```
CONTEXT — Pokémon Yellow DOS port, menus swarm S7. Read these first, in order:
  CLAUDE.md (root) — register map, memory model, conventions. Binding.
  docs/current_plan_menus.md — the plan; your package is Session 7.
  docs/translation_log.md — "menus-port Session 2/3/4/5/6" entries: the canvas
    model, generic drivers, party realign, and the wave-1 leaf screens. Your
    screen reuses these (esp. the S6 drawn-whole dialog + window-mirror pattern).
  docs/ui_projection.md — GB→port UI coordinate registry.

PORT MODEL ESSENTIALS (hard-won; violating these = invisible or garbled UI):
- SM83→x86: A=AL, BC=BX, DE=DX, HL=ESI, SP=ESP, EBP = GB memory base;
  GB memory is [EBP + symbol] with symbols from dos_port/include/gb_memmap.inc.
- W_TILEMAP triple duty: 40×25 stride-40 canvas (DisplayTextBoxID draws here
  at UI_* coords), stride-20 scratch (pret hlcoord X,Y = W_TILEMAP + Y*20 + X,
  bytes 0-359), AND the overworld collision mirror. Menus that run
  UpdateSprites must scrub with RefreshCollisionTileMap on close (see
  RedisplayStartMenu).
- Screens become visible ONLY via window descriptors: draw into scratch or
  canvas, blit the rect to a GB_TILEMAP0/1 row band (stride 32), then
  set_single_window/add_window with UI_* geometry. Live cursors reach the
  window via menu_redraw_cb (a *_mirror callback re-blitting each frame) —
  see list_mirror (home/list_menu.asm), PartyMenuMirror (party_menu.asm), and
  the S6 pc_menu_mirror / options_mirror.
- PlaceString takes EAX = FLAT source pointer (lea eax,[ebp+addr] for GB
  memory; bare label for .data), ESI = EBP-relative dest. NOT pret's DE.
- PrintNumber: EDX = EBP-rel source addr, BH = flags|byte-count (BIG-endian
  multi-byte, fixed in S5), BL = digit count, ESI = dest.
- The generic driver: HandleMenuInput (home/window.asm) + wTopMenuItemY/X,
  wMaxMenuItem, wMenuWatchedKeys, wMenuWrappingEnabled,
  wMenuWatchMovingOutOfBounds, and the port-side text_row_stride (20 or 40)
  + menu_item_step (row step in bytes) + menu_redraw_cb.
- TRAPS: title.asm ClearScreen is canvas-scoped AND re-arms the canvas
  auto-transfer mid-draw (3 frames) — blank stride-20 rows with FillMemory
  (360 bytes at W_TILEMAP) instead. frame.asm do_bg_transfer is canvas-scoped
  (stride 40; its 20×18 comments are stale) — use an explicit *_mirror.
- Text: PrintText is the BATTLE printer; overworld dialog = PrintText_Overworld,
  which collapses the window list to the dialog alone. If your screen must
  keep a menu visible under a message, draw the message whole into scratch
  rows 12-17 + UI_MESSAGE_BOX window (DEVIATION(text), S4/S5/S6 precedent) —
  copy the pret wording exactly (GB charmap: 'A'=$80,'a'=$A0,é=$BA,' '=$7F,
  '.'=$E8,'?'=$E6,'@'=$50 terminator). The S6 files (oaks_pc/players_pc) are
  the cleanest drawn-whole examples to copy.
- Emit `; TODO-HW:` at every GB I/O boundary (APU/serial/palette/printer/SRAM);
  a TODO-HW stub must still return pret's failure/no-op path contract, never
  a bare ret that changes flow. SRAM banking (rRAMG/rBMODE/rRAMB, sPlayerName/
  sBox*) has no port hardware — it collapses to a dsv_io call or a WRAM read;
  tag every such site.

WORKER RULES (binding, from docs/current_plan_menus.md):
1. Every routine keeps its pret name; `; pret ref: <file>:<label>` per logical
   block. Label parity is checked mechanically.
2. Deviations only behind exactly three tags: `; PROJ` (geometry — must cite a
   `UI_*` equate from ui_layout_menus.inc, never a bare literal),
   `; TODO-HW:`, `; DEVIATION: <one-line why>`. Untagged control-flow change
   = defect, package bounces.
3. Never reinvent something pret names — `extern` it or port it under its name.
4. Never touch git, assets/*.inc, the sidecar JSON, gb_memmap.inc, or the
   Makefile (report needed symbols/SRCS lines instead). Propose new WRAM as a
   symbol name + pret ram/wram.asm line context; ROOT derives the address
   against origin/symbols:pokeyellow.sym (do NOT ship a guessed address as fact).
5. Run `make -C dos_port check` in the seeded worktree before reporting.
6. Completion report MUST end `FAITHFUL EXCEPT: <list|none>` + routine map +
   tag inventory + externs needed.

DELIVERABLE SHAPE (all packages): new .asm file(s) under dos_port/src/ at the
pret-mirrored path; a `%ifdef DEBUG_<PKG>` harness routine Run<Pkg>Test
exported FROM YOUR OWN FILE (seed state, open the screen, DelayFrame,
call DumpBackbuffer — extern it; root wires the Makefile flag + the
overworld/debug_dump.asm call site); a report listing: needed gb_memmap.inc
symbols (with pret wram.asm line context), needed Makefile SRCS lines, needed
UI_* elements (pret GB rect + suggested anchor), and the FAITHFUL EXCEPT block.
```

---

## Package E — main_menu

```
TASK: Port pret engine/menus/main_menu.asm (301 lines) to
dos_port/src/engine/menus/main_menu.asm.

[paste the shared context block here]

SCOPE
- MainMenu + InitOptions + CheckForPlayerNameInSRAM + StartNewGame(Debug) +
  DisplayContinueGameInfo + PrintSaveScreenText + PrintNumBadges /
  PrintNumOwnedMons / PrintPlayTime + DisplayOptionMenu (the START-screen entry
  into package D's OPTION menu — extern DisplayOptionMenu_).
- InitOptions: writes the DEFAULT wOptions + wOptionsInitialized (package D
  DEFERRED wOptionsInitialized to you). Use the wOptions bit layout already in
  gb_memmap.inc (text speed bits 3-0, BIT_BATTLE_SHIFT 6, BIT_BATTLE_ANIMATION 7,
  SOUND_MASK 0x30). Propose wOptionsInitialized to root (pret wram.asm:1580).
- CheckForPlayerNameInSRAM: pret enables SRAM (rRAMG/rBMODE/rRAMB) and scans
  sPlayerName for '@'. PORT: these are `; TODO-HW: SRAM banking` → collapse to a
  single `call DsvFileExists` (root-supplied, src/save/dsv_io.asm). Contract:
  DsvFileExists returns CF=1 / AL≠0 when a valid DOSV save is present (mirrors
  pret's `scf` "found" path); preserve pret's CF polarity into the caller.
- The CONTINUE vs NEW GAME menu: draw the 2- or 3-entry box (CONTINUE only if a
  save exists) on the generic HandleMenuInput; cite UI_MAIN_MENU (root-supplied).
  DisplayContinueGameInfo draws the PLAYER/BADGES/#DEX/TIME panel — cite
  UI_CONTINUE_INFO; PrintNumBadges/PrintNumOwnedMons/PrintPlayTime read the
  loaded save's WRAM (after DsvReadSave) via PrintNumber. Texts drawn-whole
  (DEVIATION(text), S6 precedent) with exact data/text wording.
- StartNewGame → the naming screen is package C (extern its entry, e.g.
  AskName/DisplayNamingScreen); if C isn't linked yet, STUB the call (tagged)
  and note it — root serializes C↔E at integration.
- SpecialEnterMap (::) is the hand-off to the overworld boot — ROOT WIRES IT.
  Just `jp SpecialEnterMap` / export MainMenu; keep the three pret jp targets
  (the continue/new/debug branches) reaching that one seam.
- Harness: RunMainMenuTest — seed with and without a save present (call the
  root DsvWriteSave once to make CONTINUE appear, OR force DsvFileExists), open
  MainMenu, DelayFrame, DumpBackbuffer at the CONTINUE/NEW GAME menu.

WATCH FOR: the wSaveFileStatus values (1=no save, 2=save present) drive which
menu shows — read them faithfully. LoadSAV / the SRAM checksum verify is package
H's SaveGameData mirror; extern any load routine H exports (report the seam).
```

## Package H — save.asm (UI + structure)

```
TASK: Port pret engine/menus/save.asm (694 lines) to
dos_port/src/engine/menus/save.asm — the SAVE flow + box structure. This is the
package that turns the START→SAVE stub (S4) and the .dsv layer real.

[paste the shared context block here]

SCOPE
- SaveGameData:: (SaveMainData / SaveCurrentBoxData / SavePartyAndDexData) +
  CalcCheckSum + the SAVE-menu UI (the "SAVE" yes/no + "SAVING... DON'T TURN OFF"
  message + "<PLAYER> saved the game!" result). PORT: the actual byte writes to
  SRAM (sPlayerName/sMainData/sBox*) are `; TODO-HW: SRAM` → collapse the whole
  serialize into ONE `call DsvWriteSave` (root-supplied, src/save/dsv_io.asm),
  which owns the payload layout + DOSV header + checksum. Keep pret's UI/flow
  shape (wSaveFileStatus=2, the confirm yes/no via the S3 yes_no driver, the
  drawn-whole messages) around that single call. Port CalcCheckSum for label
  parity even though dsv_io does the file-level checksum — tag if unused.
- ChangeBox:: — the deposit-box switch UI (box-select list + "the <box> box").
  Faithful list + confirm; cite UI_CHANGE_BOX. Box data is the Gen-1-shaped
  in-memory box (wNumBoxItems is items; the MON boxes are wBoxData-family —
  propose the WRAM to root). Keep the current-box save/reload structure.
- LoadHallOfFameTeams: (pret save.asm:645) — port it REAL (reads the HoF team
  from the save). This REPLACES the ret-stub package A left in
  league_pc_stubs.asm — note that to root (root deletes the stub at integration).
  Reads via DsvReadSave / the in-memory HoF region; wNumHoFTeams stays 0 until
  the HoF-movie writer, so league PC still shows the no-teams path (correct).
- SGB/SRAM enable/disable, bank switches, the sav-checksum banking: all
  `; TODO-HW: SRAM` no-ops or dsv_io calls. Keep pret's control flow (the
  checksum verify branch, the corrupt-save path) — behind DsvReadSave's return.
- Harness: RunSaveTest — seed a party+bag+badges, run SaveGameData through the
  confirm (auto-YES), DumpBackbuffer at the "saved the game!" message; a second
  mode dumps DUMP.BIN of the written POKEMON.DSV bytes for a round-trip check
  (reuse debug_dump's file-read, or just verify DsvFileExists after).

WATCH FOR: SaveMainData/SaveCurrentBoxData/SavePartyAndDexData enumerate exactly
which WRAM regions the save covers — that list IS the dsv_io payload layout, so
coordinate the field set with root's dsv_io.asm (report the WRAM ranges you'd
serialize). wSaveFileStatus + the "would you like to SAVE?" reuse the S3 yes_no.
```

## Package C — naming_screen

```
TASK: Port pret engine/menus/naming_screen.asm (510 lines) to
dos_port/src/engine/menus/naming_screen.asm.

[paste the shared context block here]

SCOPE
- AskName / DisplayNameRaterScreen:: / DisplayNamingScreen + PrintAlphabet +
  PrintNicknameAndUnderscores + the letter-grid input loop (case toggle, DEL,
  END, cursor move, submit) + LoadEDTile. Full-screen takeover: draw the grid
  into the stride-20 scratch, one full-screen window at UI_NAMING_SCREEN
  (root-supplied, full 20×18 center/top like UI_OPTIONS). This screen does its
  own input loop (like options.asm) — study options.asm for the JoypadLowSensitivity
  cadence + per-frame mirror, and party_menu/pc_menu for the cursor mirror.
- ALPHABET DATA is root-generated: code against assets/alphabets.inc (root writes
  tools/gen_alphabets.py from pret data/text/alphabets.asm + gfx/font/ED.1bpp).
  Symbols: `UpperCaseAlphabet` / `LowerCaseAlphabet` (charmap grid rows) +
  `alphabet_ed_tile` (ED.1bpp bytes) + counts. Do NOT create the .inc; extern/
  %include the generated symbols (root publishes exact names before you start).
- LoadEDTile: pret copies ED_Tile to VRAM during HBlank (rSTAT %10 poll) because
  GameFreak didn't set the bank. PORT: `; DEVIATION: rSTAT HBlank bank hack →
  plain copy` — just copy alphabet_ed_tile to its vChars slot (set
  g_tilecache_dirty), no HBlank wait (the port has no bank/timing constraint).
- wNamingScreenType selects PLAYER / RIVAL / MON / BOX name; wNamingScreenNameLength,
  wNamingScreenSubmitName, wNamingScreenLetter, wAlphabetCase drive the loop.
  Propose all wNamingScreen* WRAM to root (pret wram.asm) — do NOT guess addresses.
- The submitted name lands in the destination buffer (wcd6d/wStringBuffer family)
  exactly as pret; PLAYER name → W_PLAYER_NAME (package E reads it after this
  returns). Texts drawn-whole (DEVIATION(text)).
- Harness: RunNamingScreenTest — seed wNamingScreenType=PLAYER, open
  DisplayNamingScreen, DelayFrame, DumpBackbuffer at the letter grid (uppercase
  page). Static open; the full grid navigation is the S10 interactive sweep.

WATCH FOR: the DAKUTEN/JP pages are JP-only — omit with a DEVIATION(JP) note
(S1 precedent). The '▶'/underscore cursor + the name-length underscores use
specific tiles; PrintNicknameAndUnderscores builds them — keep its exact tile math.
```

---

## Launch template (root fills per package)

> subagent_type: general-purpose (or a named worker), model **opus**
> (C may be sonnet if saving budget), isolation: NONE — use a manually-created,
> pre-seeded `git worktree` and forbid git in the prompt (memory:
> swarm-workers-must-not-touch-git). Prompt = the package block above with the
> shared context block pasted in, plus: "Your worktree is at <abs path>, already
> seeded with assets + src/save/dsv_io.asm + assets/alphabets.inc. Work only
> under dos_port/src/. NEVER run git. Report back in the deliverable shape."

Seed order recap (root-first): write dsv_io.asm + gen_alphabets.py + the 4 UI_*
elements → make assets → build/check green on the primary → THEN `git worktree
add --detach` + hardlink-seed each worktree → verify each `make check` → launch.

Integrate one package at a time through the five gates; commit each alone
(explicit paths). Ledger rows to fill in docs/current_plan_menus.md on
integration: C, E, H — status + FAITHFUL EXCEPT. Do NOT start Session 8; if a
package bounces its gates twice, integrate the ones that pass, leave the ledger
row honest, and stop for the user.
```

---

## Root kickoff prompt (paste this to start the Session 7 root agent)

```
Run menus-port Session 7 (swarm wave 2). You are the ROOT/integrator session.

Read in order before doing anything:
1. docs/current_plan_menus.md — Session 7 scope; S6 is done (HEAD should be
   a5302a80 or later on branch menus-port; all four wave-1 packages A/B/D/F in).
2. docs/menus_swarm_s7_prompts.md — the prepared launch prompts. Follow it
   exactly: the "Root checklist" section is YOUR job list; the package blocks
   E/H/C are the worker briefs (paste the shared context block into each one
   verbatim, as the file instructs).
3. docs/translation_log.md "menus-port Session 6 package A/B/D/F" entries — the
   current port model your workers build on (esp. the drawn-whole dialog +
   window-mirror pattern in oaks_pc/players_pc, and options.asm's own input loop).

Execution order (root-first, because E + H both depend on the save layer):
- First do root-owned prework, IN THIS ORDER, and get make + make check green
  on the primary before seeding anything:
    (a) write src/save/dsv_io.asm (DOSV magic + version + 2-byte checksum +
        minimal-real WRAM payload; DsvFileExists / DsvWriteSave / DsvReadSave),
        reusing debug_dump.asm's DPMI INT 31h/0300h file I/O; add it to the
        Makefile SRCS + its new WRAM (wSaveFileStatus, …) to gb_memmap.inc
        (sym-verified). Publish the three routine signatures for the E/H briefs.
    (b) write tools/gen_alphabets.py (pret data/text/alphabets.asm + gfx/font/
        ED.1bpp -> assets/alphabets.inc) + its assets rule; run make assets.
        Publish the emitted symbol names for the C brief.
    (c) add the four UI_* elements (UI_MAIN_MENU, UI_CONTINUE_INFO,
        UI_NAMING_SCREEN, UI_CHANGE_BOX) to the sidecar (pret GB rects, standard
        anchors) + make assets.
    (d) update saveconv.py's stub header to describe the now-real .dsv layout.
- Then seed 3 worktrees (E, H, C) — hardlink-copy dos_port/assets/*.inc + all
  .2bpp/.pic/.1bpp + the new src/save/dsv_io.asm from the primary into each,
  verify each make check is green, THEN launch E/H/C as Opus subagents (C may be
  Sonnet). Workers never touch git, the Makefile, assets/*.inc, the sidecar, or
  gb_memmap.inc — they report needed lines.
- Integrate one package at a time through the five gates listed in the prompts
  file (pret control-flow diff -> tag audit -> PROJ-cites-UI_* -> make check +
  make -> TODO-HW return-contract audit), then wire its Makefile SRCS +
  DEBUG_<PKG> harness into overworld.asm/debug_dump.asm, derive any new WRAM
  yourself against origin/symbols:pokeyellow.sym (S6 caught two wrong worker
  addresses this way — do NOT trust proposed addresses), capture the FRAME.BIN
  gate headlessly (scratch conf + `-c exit` + SDL_VIDEODRIVER=dummy; recipe in
  the S6 log), and commit that package alone (stage explicit paths only).
- Cross-package coordination (see the prompts "Root checklist" item 7): H's real
  LoadHallOfFameTeams replaces package A's ret-stub in league_pc_stubs.asm
  (delete that one stub, keep Func_7033f); E owns InitOptions/wOptionsInitialized
  (D deferred it); SpecialEnterMap is root-wired; all SRAM banking -> dsv_io /
  TODO-HW.
- Fill the package-status ledger rows in docs/current_plan_menus.md and mark
  Session 7 [x] only when all three packages are integrated, gated, and make +
  make check are green. Update translation_log.md per package. Archive the S7
  prompts (git mv docs/menus_swarm_s7_prompts.md docs/archive/) at closeout.

Do not start Session 8. If a package bounces its gates twice, integrate the ones
that pass, leave the ledger row honest, and stop for me.
```

---

## How these swarm prompts are constructed (reusable recipe)

This file (and its S6 sibling / the S8 successor) all follow one template. Keep
the shape when building the next wave's prompts — it's what makes a swarm
integrate cleanly instead of bouncing.

1. **Pick the wave's packages from the plan.** `docs/current_plan_menus.md`
   already names them (e.g. S7 = E/H/C, S8 = G1/G2/I1/I2). One package = one pret
   source file (or one faithful `%include`-split half of one). One worker per
   package, one seeded worktree per worker.

2. **Read the pret source(s) end-to-end first.** The brief's SCOPE list is the
   pret label inventory of that file — every top-level routine gets named so
   label parity is checkable mechanically. Note the flag-sensitive branches
   (`cp`/`and` + `jr z/nz/c/nc`), the I/O boundaries (serial/APU/palette/printer/
   SRAM), and the `text_far`/bank reads — those become the WATCH-FOR / TODO-HW /
   DEVIATION lines.

3. **Split root-vs-worker work.** Anything a worker cannot safely own goes in the
   **Root checklist** (do-it-yourself list), never in a brief:
   - Tier-1 **generators** + the `assets/*.inc` they emit (deterministic, pret-
     derived; publish the emitted symbol names + byte layout as a contract).
   - New **`UI_*` layout elements** (root edits the sidecar + `make assets`;
     workers only *cite* `UI_*`, never bare literals).
   - **New WRAM** addresses (derive against `origin/symbols:pokeyellow.sym` —
     never trust a worker's guessed address; this has caught real bugs every wave).
   - **Worktree seeding** (hardlink assets + `.2bpp/.pic/.1bpp`), **Makefile**
     edits, **git**, and **cross-package seams** (`%include` lines, spine
     hand-offs like SpecialEnterMap).

4. **Write the shared context block once, paste it verbatim into every brief.**
   It carries the hard-won port-model invariants (register map, W_TILEMAP triple
   duty, PlaceString EAX-flat, PrintNumber big-endian, the ClearScreen/
   do_bg_transfer traps, PrintText-vs-Overworld, the charmap) + the six binding
   worker rules + the deliverable shape (pret-mirrored `.asm` + a `DEBUG_<PKG>`
   `Run<Pkg>Test` harness + a report). Refresh only the "read these first" refs
   and the one or two invariants that bit the previous wave (S8 promoted
   ZF/CF-clobber to the top because its bit-scans + cup gates are compare-dense).

5. **Per-package brief = TASK + [context block] + SCOPE + WATCH FOR.** SCOPE is
   pret labels + which calls become extern/stub/TODO-HW/DEVIATION. WATCH FOR is
   the two or three things most likely to silently break (flag polarity, a
   contract byte, a return code the dispatcher reads).

6. **State the five integration gates + the ledger.** Every wave integrates one
   package at a time through: (1) branch-by-branch pret control-flow diff;
   (2) tag audit (`; PROJ`/`; TODO-HW:`/`; DEVIATION:` only); (3) PROJ-cites-`UI_*`;
   (4) `make check` + `make`; (5) TODO-HW return-contract audit. Then Makefile +
   harness wiring + a single-package commit (explicit paths), and a filled ledger
   row (`status` + `FAITHFUL EXCEPT`). Coupled halves (`%include` pairs) integrate
   together.

7. **End with a launch template + a root kickoff prompt.** The launch template
   fixes model choice (Opus for rendering/flow reasoning; Sonnet for logic-only
   packages — memory `sonnet-parallel-logic-only`) and the no-git worktree rule
   (memory `swarm-workers-must-not-touch-git`). The root kickoff prompt is the
   single message that boots the coordinating session: root-first prework order,
   seed, launch, gate, ledger, "do not start the next session."

Non-negotiables that keep the swarm safe (all learned the hard way): workers
never touch git / `assets/*.inc` / the sidecar / `gb_memmap.inc` / the Makefile;
worktrees must be asset-seeded or the build fails (memory `worktree-asset-seeding`);
every pret deviation is flagged behind one of the three tags (memory
`feedback-no-silent-bespoke`); root re-derives every proposed WRAM address.
