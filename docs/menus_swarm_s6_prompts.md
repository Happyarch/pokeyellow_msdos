# Menus Swarm — Session 6 (wave 1) launch prompts

Session 6 of `docs/current_plan_menus.md`: four parallel worker packages —
**A** (oaks_pc + league_pc), **B** (draw_badges), **D** (options),
**F** (players_pc). Workers run as **Opus** subagents (user direction for this
wave), one package per agent, each in its own seeded worktree.

Requires: S5 landed (`f59e9134` on `menus-port`). Root = the coordinating
session that launches these.

---

## Root checklist (do these yourself, not in a brief)

1. **Seed each worktree** after creating it: copy `dos_port/assets/*.inc` and
   all `.2bpp/.pic/.1bpp` from the primary clone (memory: worktree builds fail
   without them). Re-seed + re-`make check` if any generator lands mid-wave.
2. **Root-owned deliverable for package B:** write
   `dos_port/tools/gen_badge_tiles.py` (Tier 1 generator: gym-leader face +
   badge 2bpp tiles from pret `gfx/trainer_card/` → `assets/badge_tiles.inc`),
   plus its Makefile `assets` rule. Do it before or during B's run; B codes
   against the symbol names below.
3. **Integration gates per package, in order** (plan "Worker rules" section):
   (1) branch-by-branch pret control-flow diff; (2) tag audit (`; PROJ` /
   `; TODO-HW:` / `; DEVIATION:` only); (3) PROJ-geometry-cites-UI_* audit;
   (4) `make check` + `make`; (5) TODO-HW return-contract audit. Then Makefile
   entry + `debug_dump.asm` harness wiring + commit — **root only** (workers
   never touch git/Makefile/assets/gb_memmap.inc — they report needed lines).
4. **New WRAM addresses**: workers propose symbol names + pret `wram.asm`
   context; root derives addresses against two verified anchors (S5 pattern,
   see the "Menus S5" block comment in `gb_memmap.inc`) and adds them.
5. **Window row-bands in use** (collision registry — new screens must pick
   free bands or be full takeovers): GB_TILEMAP0: list 0-10, qty 12-14,
   yes/no 16-20, USE/TOSS 21-25, field-move pop-up 0-15 (party context only).
   GB_TILEMAP1: START box + dialog 0-15 / 0-5, party panel + message 0-17.
6. **Layout freeze:** any new `UI_*` element (options screen, players-PC menu
   box, …) is a root edit to the sidecar via the editor + `make assets`,
   between waves only. Seed from the pret GB coords with the standard
   center/top anchor unless the screen is a full takeover.

---

## Shared context block (paste at the top of EVERY brief, verbatim)

```
CONTEXT — Pokémon Yellow DOS port, menus swarm S6. Read these first, in order:
  CLAUDE.md (root) — register map, memory model, conventions. Binding.
  docs/current_plan_menus.md — the plan; your package is Session 6.
  docs/translation_log.md — "menus-port Session 2/3/4/5" entries: the canvas
    model, generic drivers, and party realign. Your screen reuses these.
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
  see list_mirror (home/list_menu.asm) and PartyMenuMirror (party_menu.asm).
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
  rows 12-17 + UI_MESSAGE_BOX window (DEVIATION(text), S4/S5 precedent) —
  copy the pret wording exactly (GB charmap: 'A'=$80,'a'=$A0,é=$BA,' '=$7F,
  '.'=$E8,'?'=$E6,'@'=$50 terminator).
- Emit `; TODO-HW:` at every GB I/O boundary (APU/serial/palette/printer);
  a TODO-HW stub must still return pret's failure/no-op path contract, never
  a bare ret that changes flow.

WORKER RULES (binding, from docs/current_plan_menus.md):
1. Every routine keeps its pret name; `; pret ref: <file>:<label>` per logical
   block. Label parity is checked mechanically.
2. Deviations only behind exactly three tags: `; PROJ` (geometry — must cite a
   `UI_*` equate from `ui_layout_menus.inc`, never a bare literal),
   `; TODO-HW:`, `; DEVIATION: <one-line why>`. Untagged control-flow change
   = defect, package bounces.
3. Never reinvent something pret names — `extern` it or port it under its name.
4. Never touch git, `assets/*.inc`, the sidecar JSON, `gb_memmap.inc`, or the
   Makefile (report needed symbols/SRCS lines instead).
5. Run `make -C dos_port check` in the seeded worktree before reporting.
6. Completion report MUST end `FAITHFUL EXCEPT: <list|none>` + routine map +
   tag inventory + externs needed.

DELIVERABLE SHAPE (all packages): new .asm file(s) under dos_port/src/ at the
pret-mirrored path; a `%ifdef DEBUG_<PKG>` harness routine Run<Pkg>Test
exported FROM YOUR OWN FILE (seed state, open the screen, DelayFrame,
call DumpBackbuffer — extern it; root wires the Makefile flag + the
debug_dump.asm call site); a report listing: needed gb_memmap.inc symbols
(with pret wram.asm line context), needed Makefile SRCS lines, needed UI_*
elements (pret GB rect + suggested anchor), and the FAITHFUL EXCEPT block.
```

---

## Package A — oaks_pc + league_pc

```
TASK: Port pret engine/menus/oaks_pc.asm and engine/menus/league_pc.asm to
dos_port/src/engine/menus/oaks_pc.asm and league_pc.asm.

[paste the shared context block here]

SCOPE
- OpenOaksPC (28 lines): SaveScreenTilesToBuffer2/LoadScreenTilesFromBuffer2
  are the GB screen-stash idiom — in the window model they collapse to
  window-list save/restore around the dialog (see S5 StartMenu_Pokemon
  .exitMenu note); document as `; DEVIATION` if you replace rather than call
  (check what exists first: grep dos_port/src for SaveScreenTilesToBuffer2).
  The three texts (_AccessedOaksPCText etc., data/text/) are drawn-whole
  message-box texts (DEVIATION(text) precedent). YesNoChoice exists (S3
  yes_no.asm). `predef DisplayDexRating` is a STUB(S8: pokedex package) —
  keep the branch, no-op the call, tag it.
- PKMNLeaguePC (119 lines): the Hall-of-Fame reader. LoadHallOfFameTeams
  reads HoF SRAM — save layer is S7: STUB it to behave as wNumHoFTeams=0
  (the "no teams" path shows AccessedHoFPCText and exits — verify that IS
  the pret flow when wNumHoFTeams=0 and preserve it exactly). Port the full
  loop + LeaguePCShowTeam/LeaguePCShowMon structure anyway (label parity),
  gated so it's reachable once S7 lands. hTileAnimations push/pop and
  BIT_NO_TEXT_DELAY set/res are live state — keep them (S5 did the same
  dance in DisplayPartyMenu).
- Callers (ActivatePC / pc.asm) are S9 spine scope — just export OpenOaksPC
  and PKMNLeaguePC.
- Harness: RunOaksPCTest — seed nothing special, open OpenOaksPC, drive the
  yes/no to the "no" default path is fine for a static dump.

WATCH FOR: WaitForTextScrollButtonPress / TextScroll helpers — check
dos_port/src/text/ for existing ports before writing anything.
```

## Package B — draw_badges (trainer-card gfx)

```
TASK: Port pret engine/menus/draw_badges.asm (119 lines) to
dos_port/src/engine/menus/draw_badges.asm.

[paste the shared context block here]

SCOPE
- DrawBadges: the 4×2 gym-leader-face/badge grid for the player status
  screen (StartMenu_TrainerInfo, wired in S9). Faithful logic: build
  wBadgeOrFaceTiles from .FaceBadgeTiles, wTempObtainedBadgesBooleans from
  wObtainedBadges (srl/carry walk), +4 tile offset for owned badges, then
  the two-row draw with the adjacent-badge tile pairing quirk — keep pret's
  exact loop shape.
- GFX: code against these generated symbols (root supplies
  assets/badge_tiles.inc via tools/gen_badge_tiles.py — do NOT create the
  .inc): badge_face_tiles (label), BADGE_FACE_TILE_COUNT, BADGE_TILE_BYTES.
  Write the VRAM loader that copies them to a vChars slot the way
  load_font.asm does (any VRAM tile-data write MUST set g_tilecache_dirty).
  Report the tile-id base you chose and why it's free in the trainer-card
  context.
- The Japanese-names erasure note in pret is historical — EN behavior only.
- No live caller this session: the harness IS the consumer. RunDrawBadgesTest:
  seed wObtainedBadges = %10100101 (mixed), draw into the scratch at pret
  coords, blit + window (PROJ: cite a UI_* element — report the rect you
  need; root adds UI_TRAINER_CARD_BADGES to the layout between waves),
  DelayFrame, DumpBackbuffer.

WATCH FOR: wBadgeOrFaceTiles/wTempObtainedBadgesBooleans WRAM — propose
addresses from ram/wram.asm context for root (rule 4).
```

## Package D — options

```
TASK: Port pret engine/menus/options.asm (483 lines) to
dos_port/src/engine/menus/options.asm.

[paste the shared context block here]

SCOPE
- DisplayOptionMenu_ + InitOptionsMenu + OptionsControl + GetOptionPointer
  jump table + the per-row handlers (OPT_TEXT_SPEED / OPT_BATTLE_ANIMS /
  OPT_BATTLE_STYLE / OPT_SOUND / OPT_PRINTER / OPT_CANCEL) + cursor-position
  update. This menu does NOT use HandleMenuInput — it has its own
  JoypadLowSensitivity loop (3×DelayFrame cadence). JoypadLowSensitivity is
  already ported (src/input/joypad_lowsens.asm) — extern it; keep the loop
  shape exactly (hJoy5 reads).
- The screen is a full takeover: draw at pret GB coords in the stride-20
  scratch, one full-screen window (like the party panel: GB_TILEMAP1 via an
  explicit mirror; PROJ cite — report the UI_OPTIONS element you need, pret
  rect = full 20×18 at the standard center/top anchor).
- wOptions / wPrinterSettings persistence: wOptions exists in gb_memmap.inc
  (verify); the wOptionsInitialized byte is $D09A-adjacent — propose from
  wram context. Option changes must land in wOptions with pret's exact bit
  layout (battle code already reads it).
- OPT_SOUND writes rAUDTERM (earphone/speaker) — `; TODO-HW: audio HAL
  (Phase 3)`: keep the row, keep the wOptions bits, skip only the register
  write. OPT_PRINTER — `; TODO-HW: printer (no serial)`: row renders, value
  stored, nothing else.
- Harness: RunOptionsTest — open the menu, DelayFrame, DumpBackbuffer
  (static open state; nav is the S10 interactive sweep).

WATCH FOR: this menu redraws row VALUES in place on left/right press — that
needs the mirror re-blit each loop iteration (call your *_mirror right
before the DelayFrames, same slot pret uses for its BGMap update).
```

## Package F — players_pc

```
TASK: Port pret engine/menus/players_pc.asm (302 lines) to
dos_port/src/engine/menus/players_pc.asm.

[paste the shared context block here]

SCOPE
- PlayerPC / PlayerPCMenu (WITHDRAW ITEM / DEPOSIT ITEM / TOSS ITEM /
  LOG OFF) + the three item flows. This is the flagship SECOND caller of
  DisplayListMenuID (home/list_menu.asm) after the bag — the point of the
  package is proving the generic list driver generalizes. Study
  start_sub_menus.asm StartMenu_Item first: the bag is your template for
  wListPointer/wListMenuID setup, ut_-style sub-boxes, and the
  DisplayChooseQuantityMenu chain.
- The parent 4-entry menu: TextBoxBorder at pret (0,0) 8x14 interior +
  PlaceString of PlayersPCMenuEntries + HandleMenuInput (watched A|B) —
  stride-20 scratch + your own mirror + window (report the UI element; pret
  rect GB(0,0) 15×10-ish — check exact box dims from the lb bc, 8, 14).
- Box storage: wNumBoxItems/wBoxItems, Gen-1-shaped in-memory stand-in
  (50 entries + terminator) — the WRAM symbols may already exist in
  gb_memmap.inc (verify; else propose). DEPOSIT moves bag→box via the
  existing inventory routines (home/item.asm, engine/items/inventory.asm —
  grep for AddItemToInventory/RemoveItemFromInventory); WITHDRAW is the
  mirror; TOSS reuses the S4 TossItem chain VERBATIM (extern TossItem,
  IsKeyItem, DisplayChooseQuantityMenu).
- Texts (TurnedOnPC2Text, WhatDoYouWantText, deposit/withdraw prompts and
  results): drawn-whole DEVIATION(text) with exact pret wording from
  data/text/. SFX_TURN_ON_PC etc. = `; TODO-HW: audio HAL`.
- BIT_USING_GENERIC_PC / BIT_NO_MENU_BUTTON_SOUND wMiscFlags bits: wMiscFlags
  is 0xCD60 in gb_memmap.inc; keep the bit ops faithful.
- Callers: overworld PC script objects + pc.asm are S9 — export PlayerPC.
- Harness: RunPlayersPCTest — seed a bag (PrepareNewGameDebug pattern —
  extern it, it's linked in debug builds) + 2-3 box items, open PlayerPC,
  DelayFrame, DumpBackbuffer at the parent menu.

WATCH FOR: wListScrollOffset save/restore around the sub-lists (the bag does
this); losing it desyncs the bag's saved scroll when the player next opens
START→ITEM.
```

---

## Launch template (root fills per package)

> subagent_type: general-purpose (or named worker), model **opus**,
> isolation: worktree. Prompt = the package block above with the shared
> context block pasted in, plus: "Your worktree is at <path>, already seeded
> with assets. Work only under dos_port/src/. Do not run git commands.
> Report back in the deliverable shape."

Ledger rows to fill in docs/current_plan_menus.md on integration:
A, B, D, F — status + FAITHFUL EXCEPT.
