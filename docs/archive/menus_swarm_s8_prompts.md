# Menus Swarm — Session 8 (wave 3) launch prompts

Session 8 of `docs/current_plan_menus.md`: the last two leaf-screen packages,
each **%include-split** into two workers —

- **G — pokedex** → **G1** (2D scroller + side menu) / **G2** (entry page;
  front-pic reuse spike first)
- **I — link_menu** → **I1** (menus + dispatch; serial → TODO-HW stubs with
  pret timeout semantics) / **I2** (cup validation, fully real)

plus **root-first** Tier-1 generators `tools/gen_dex_order.py` +
`tools/gen_dex_entries.py` that G1/G2 **and** I2 build on.

Requires: S7 landed (`5c35b2a3` on `menus-port`; packages C/E/H in, `dsv_io.asm`
live). Root = the coordinating session that writes the generators, adds the
`UI_*` elements, seeds the worktrees, integrates, and gates.

Two things make S8 different from S6/S7 and set the launch order:

1. **The splits are `%include`-based, not two independent files.** G1 owns
   `src/engine/menus/pokedex.asm` and `%include`s G2's
   `src/engine/menus/pokedex_entry.asm` at the pret INCLUDE point; I1 owns
   `src/engine/menus/link_menu.asm` and `%include`s I2's
   `src/engine/menus/link_cups.asm` at the `PointerTable_f5488` boundary. The two
   halves compile as **one translation unit**, so labels cross-reference by name
   (no `extern` between the halves) — exactly as pret has one file. Root defines
   the seam (which labels live in which file, and the single `%include` line) in
   the briefs so the two workers don't collide on it.
2. **Cross-package data dep: I2 needs the dex data too.** PetitCup reads
   `PokedexEntryPointers` (height/weight gate), so `gen_dex_entries.py` must land
   before BOTH the G worktrees and the I worktree seed. Root-first order matters.

Read the "Root checklist" top-to-bottom before launching anyone.

---

## Root checklist (do these yourself, not in a brief)

1. **Root-first generators, BEFORE seeding.** Both are Tier-1
   (`assets/*.inc`, `DO NOT EDIT BY HAND` header, deterministic function of the
   read-only pret source + constant enums — CLAUDE.md two-tier rule):
   - `tools/gen_dex_order.py` ← pret `data/pokemon/dex_order.asm`
     (`PokedexOrder`, `table_width 1`, 190 `db DEX_*` bytes) → `assets/dex_order.inc`:
     emit `PokedexOrder:` as a NASM `db` blob of the resolved internal-index bytes
     (resolve `DEX_*` against the same dex-number enum the port already uses; the
     value stored is the **internal index**, per
     memory `gen1-internal-index-vs-dex`). Publish the symbol name `PokedexOrder`.
   - `tools/gen_dex_entries.py` ← pret `data/pokemon/dex_entries.asm`
     (`PokedexEntryPointers` `table_width 2` + each `<Mon>DexEntry` = species
     string + feet/inches + weight word + flavor-text pointer). PORT: the flavor
     text is `text_far _<Mon>PokedexEntry` into bank data the port can't address
     flat — so **inline the flavor string bytes** into the emitted entry
     (`; DEVIATION: text_far → inline`, the naming_screen.asm S7 precedent) and
     have the pointer word point at the inlined bytes. Emit `PokedexEntryPointers`
     (dw table, one per internal index, MissingNo entries kept) + each entry
     blob. Read the flavor text from pret `text/pokedex/*.asm`. Publish the two
     symbol names and the exact per-entry byte layout (species-string offset,
     feet at +N, inches, weight word, flavor-pointer/inline-string offset) so G2
     and I2 code the field math against it. **This layout IS a contract** — write
     it in the `.inc` header comment.
   - Add both to the Makefile `assets` rule; `make -C dos_port assets`; build +
     `make check` green on the primary BEFORE seeding.
2. **Layout freeze — pre-add the new `UI_*` elements before seeding** (root edit
   to the sidecar via the editor + `make assets`, S6/S7 pattern). Derive rects
   from the pret source yourself:
   - `UI_POKEDEX_MAIN` (G1): the pokedex is a full bespoke 20×18 layout
     (CONTENTS list left, SEEN/OWN top-right, side menu bottom-right) — a full
     takeover, center/top like `UI_OPTIONS`/`UI_NAMING_SCREEN`.
   - `UI_POKEDEX_SIDE_MENU` (G1): the DATA/CRY/AREA/PRNT/QUIT menu —
     HandlePokedexSideMenu's `hlcoord 15, 8` cursor region (top-right sub-rect;
     may be carried inside `UI_POKEDEX_MAIN` if the whole screen is one window —
     G1 reports which it needs).
   - `UI_POKEDEX_ENTRY` (G2): the full dex-data page (front pic + №/HT/WT +
     divider + flavor) — DrawDexEntryOnScreen's full-screen border. Full
     takeover, center/top.
   - `UI_LINK_MENU` (I1): LinkMenu's TRADE CENTER/COLOSSEUM select box —
     `hlcoord 5, 3` / `lb bc, 8, 13`.
   - `UI_LINK_CUP_MENU` (I1): Func_f531b's cup-select screen — three boxes:
     View/Rules `hlcoord 0,0 lb 4,5`, cup list `hlcoord 8,0 lb 8,10`, rules
     panel `hlcoord 0,10 lb 6,18`. Root derives one full-takeover rect (or three
     sub-rects); I1 cites and reports the exact rects it drew into.
   Let the workers CITE these; they report the exact rect they need and root
   fixes any mismatch between waves (S6/S7 precedent).
3. **Seed each worktree** after prework: hardlink-copy `dos_port/assets/*.inc`
   (now including `dex_order.inc` + `dex_entries.inc`) + all `.2bpp/.pic/.1bpp`
   from the primary into each. Re-seed + re-`make check` if a generator lands
   mid-wave. Verify each seed built green (`make -C <wt>/dos_port check`) before
   the worker starts. **G1+G2 share `pokedex.asm`'s translation unit and I1+I2
   share `link_menu.asm`'s** — give each pair either separate worktrees with a
   clear file-ownership seam (G1 owns the parent + `%include` line; G2 owns only
   the included file) OR run each pair sequentially in one worktree. Separate
   worktrees + a strict "only touch YOUR file" rule is cleaner; root writes the
   one `%include` line into the parent itself if a race is possible.
4. **Integration gates per package, in order** (plan "Worker rules"):
   (1) branch-by-branch pret control-flow diff (count/polarity/fallthrough,
   flag-sense per docs/register_map.md — **watch ZF-clobber**: x86 `and`/`cp`
   set flags where the GB path relied on a stale Z; the pokedex bit-scan and the
   cup level compares are dense with `cp`/`jr z`); (2) tag audit (`; PROJ` /
   `; TODO-HW:` / `; DEVIATION:` only); (3) PROJ-geometry-cites-UI_* audit;
   (4) `make check` + `make`; (5) TODO-HW return-contract audit (I1's serial
   stubs MUST return the no-partner timeout path, never a bare ret). Then
   Makefile entry + `debug_dump.asm`/overworld harness wiring + commit — **root
   only**.
5. **New WRAM: derive against `origin/symbols:pokeyellow.sym`, do NOT trust the
   worker's proposed address.** (`git show origin/symbols:pokeyellow.sym`.) S6/S7
   caught several wrong worker addresses this way. Likely new: `wDexMaxSeenMon`,
   `hDexWeight` (HRAM), `wPrinterPokedexEntryTextPointer` (printer path =
   TODO-HW), and the link cluster (`wLinkMenuSelectionSendBuffer` /
   `…ReceiveBuffer`, `wSerialExchangeNybbleSendData` / `…ReceiveData`,
   `wUnknownSerialCounter`, `wBuffer`, `wMenuJoypadPollCount`, `wEnteringCableClub`,
   `wUnusedLinkMenuByte`, `wDefaultMap`, `wDestinationMap`, `wWalkBikeSurfState`,
   `wStatusFlags4`/`wStatusFlags6`). Many already exist in gb_memmap.inc — check
   before adding; the 0xCC../0xCD.. scratch unions alias, that's expected.
6. **Cross-package coordination unique to S8 — handle at integration:**
   - **The `%include` seam is root-owned.** Root writes the single
     `%include "engine/menus/pokedex_entry.asm"` (at pret's INCLUDE point, after
     `DrawTileLine`, before `PokedexToIndex` — or wherever the seam lands) and
     `%include "engine/menus/link_cups.asm"` (at the `PointerTable_f5488`
     boundary) into the parent file at integration if the workers can't both edit
     it safely. Confirm no duplicate label / no double-`global`.
   - **I1's serial routines are stubs; I2 is real.** The seam: I1 owns every
     `Serial_*` / `hSerialConnectionStatus` / `rSC` / `CloseLinkConnection`
     boundary → `; TODO-HW: network HAL` stubs that return pret's **no-partner
     timeout** path (the menu falls through to `.choseCancel`/CloseLinkConnection
     gracefully — NEVER a bare ret that skips the cancel flow). I2 owns the cup
     validators (`PokeCup`/`PikaCup`/`PetitCup` + the 15 result routines), which
     are pure party/dex logic with real GB behavior — no serial, no stub.
   - **`SpecialEnterMap` / `PrepareForSpecialWarp` are root-wired** (same as S7's
     E hand-off). LinkMenu's `jpfar SpecialEnterMap` / `callfar
     PrepareForSpecialWarp` reach the seam root provides; I1 just keeps the pret
     jp/call targets. This is integration-spine work (Session 9), not a worker
     deliverable — I1 stubs the warp with a tagged note.
   - **`LoadTownMap_Nest` (AREA) and `PrintPokedexEntry` (PRNT) are out of
     scope.** HandlePokedexSideMenu's `.choseArea` (`predef LoadTownMap_Nest`)
     and `.chosePrint` (`callfar PrintPokedexEntry` + printer) → tagged STUBs
     returning the correct `b` exit code (area shown = b=0; print, GB-only, = the
     `_YELLOW_VC` forbid-print path is fine to mirror as a no-op → b=3). G1 keeps
     the dispatch shape; the leaf targets are later work.
7. **Update `docs/ui_projection.md`** with the new `UI_*` pokedex/link equates at
   integration (S10 does the full index pass, but log the rects now).
8. **Window row-bands / full-takeover registry** (collision registry): the
   pokedex (G1/G2) and the link cup screen (I1) are **full GB_TILEMAP takeovers**
   like options/naming — they draw the whole bespoke layout into the stride-20
   scratch and blit one full window (options.asm / naming_screen.asm are the
   working references). LinkMenu's smaller TRADE CENTER box can be a windowed
   sub-rect. No new shared row-bands.

---

## Shared context block (paste at the top of EVERY brief, verbatim)

```
CONTEXT — Pokémon Yellow DOS port, menus swarm S8. Read these first, in order:
  CLAUDE.md (root) — register map, memory model, conventions. Binding.
  docs/current_plan_menus.md — the plan; your package is Session 8.
  docs/translation_log.md — "menus-port Session 2..7" entries: the canvas model,
    generic drivers, the S7 full-takeover screens (naming_screen, main_menu,
    options) and the drawn-whole dialog + window-mirror pattern. Your screen
    reuses these.
  docs/ui_projection.md — GB→port UI coordinate registry.

PORT MODEL ESSENTIALS (hard-won; violating these = invisible or garbled UI):
- SM83→x86: A=AL, BC=BX, DE=DX, HL=ESI, SP=ESP, EBP = GB memory base;
  GB memory is [EBP + symbol] with symbols from dos_port/include/gb_memmap.inc.
- FLAGS ARE NOT THE GB'S. x86 and/or/cp/inc/dec set ZF/CF where the GB code
  leaned on a stale flag. Every `jr z`/`jr c` you port must branch on a flag set
  by the SAME logical op pret used — re-derive it, don't assume the previous x86
  instruction left the right ZF/CF. The pokedex max-seen bit scan (sla a; jr c),
  IsPokemonBitSet's `and a` return, and every cup `cp NN / jr nc/jr c` level gate
  are dense with this; a clobbered ZF here silently mis-validates a team or
  mis-counts the dex. This is the #1 defect class for S8 — audit it per branch.
- W_TILEMAP triple duty: 40×25 stride-40 canvas (DisplayTextBoxID draws here
  at UI_* coords), stride-20 scratch (pret hlcoord X,Y = W_TILEMAP + Y*20 + X,
  bytes 0-359), AND the overworld collision mirror. Menus that run
  UpdateSprites must scrub with RefreshCollisionTileMap on close.
- Full-screen takeovers (pokedex, link cup screen) draw the whole bespoke layout
  into the stride-20 scratch, then blit one full window and drive their own
  input loop with a per-frame mirror callback — study options.asm and
  naming_screen.asm (S7), which are the closest working references.
- PlaceString takes EAX = FLAT source pointer (lea eax,[ebp+addr] for GB
  memory; bare label for .data), ESI = EBP-relative dest. NOT pret's DE.
- PrintNumber: EDX = EBP-rel source addr, BH = flags|byte-count (BIG-endian
  multi-byte, fixed in S5), BL = digit count, ESI = dest. LEADING_ZEROES is a BH
  flag bit — keep it.
- The generic driver: HandleMenuInput (home/window.asm) + wTopMenuItemY/X,
  wMaxMenuItem, wMenuWatchedKeys, wMenuWrappingEnabled,
  wMenuWatchMovingOutOfBounds, and the port-side text_row_stride (20 or 40)
  + menu_item_step + menu_redraw_cb.
- TRAPS: title.asm ClearScreen is canvas-scoped AND re-arms the canvas
  auto-transfer mid-draw — blank stride-20 rows with FillMemory (360 bytes at
  W_TILEMAP) instead. frame.asm do_bg_transfer is canvas-scoped (stride 40) —
  use an explicit *_mirror.
- Text: PrintText is the BATTLE printer; overworld dialog = PrintText_Overworld,
  which collapses the window list to the dialog alone. If your screen must keep a
  menu visible under a message, draw the message whole into scratch + a message
  window (DEVIATION(text), S4/S5/S6/S7 precedent) — copy the pret wording exactly
  (GB charmap: 'A'=$80,'a'=$A0,é=$BA,' '=$7F,'.'=$E8,'?'=$E6,'@'=$50 terminator).
- Emit `; TODO-HW:` at every GB I/O boundary (APU/serial/palette/printer);
  a TODO-HW stub must still return pret's failure/no-op path contract, never a
  bare ret that changes flow. Serial (Serial_*, hSerialConnectionStatus, rSC) has
  no port hardware → stub to the no-partner TIMEOUT path so the flow reaches the
  cancel/close branch; tag every such site.

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
pret-mirrored path; a `%ifdef DEBUG_<PKG>` harness routine Run<Pkg>Test exported
FROM YOUR OWN FILE (seed state, open the screen, DelayFrame, call DumpBackbuffer
— extern it; root wires the Makefile flag + the overworld/debug_dump.asm call
site); a report listing: needed gb_memmap.inc symbols (with pret wram.asm line
context), needed Makefile SRCS lines, needed UI_* elements (pret GB rect +
suggested anchor), and the FAITHFUL EXCEPT block.
```

---

## Package G1 — pokedex (2D scroller + side menu)

```
TASK: Port the MENU/LIST half of pret engine/menus/pokedex.asm (lines ~1-436 +
694-751) to dos_port/src/engine/menus/pokedex.asm. This is the PARENT of the
%include split — you own the file and the single %include line for G2's entry
page (root confirms the exact seam line at integration; put it at pret's INCLUDE
"data/pokemon/dex_entries.asm" point i.e. after DrawTileLine).

[paste the shared context block here]

SCOPE (your labels):
- ShowPokedexMenu + HandlePokedexSideMenu + HandlePokedexListMenu +
  Pokedex_DrawInterface + DrawPokedexVerticalLine + Pokedex_PlacePokemonList +
  IsPokemonBitSet + DrawTileLine + PokedexToIndex + IndexToPokedex, and the text
  tables PokedexSeenText/OwnText/ContentsText/MenuItemsText.
- Full-screen takeover: draw the CONTENTS list (left), SEEN/OWN counts +
  divider lines (top-right), and the DATA/CRY/AREA/PRNT/QUIT side menu into the
  stride-20 scratch; blit one full window at UI_POKEDEX_MAIN (root-supplied,
  full 20×18 center/top). The side-menu cursor rides the generic HandleMenuInput
  at UI_POKEDEX_SIDE_MENU (cite it; report if it's a sub-rect of the main window
  or its own). options.asm/naming_screen.asm are the input-loop + per-frame
  mirror references.
- Pokedex_PlacePokemonList: the 7-row scrolling list — pokéball tile ($72) for
  owned, "----------" for unseen, PrintNumber(LEADING_ZEROES) for the dex number,
  GetMonName via PokedexToIndex for seen. Keep the exact wListScrollOffset scroll
  math (up/down 1 row, left/right 7 rows, the wDexMaxSeenMon clamps).
- CountSetBits (seen/owned totals) + the max-seen bit-scan (.maxSeenPokemonLoop:
  sla a; jr c) — extern CountSetBits if the port already has it; port the bit
  scan carefully (ZF/CF: it counts down b until the first set bit rotates into
  CF). IsPokemonBitSet uses FlagActionPredef (FLAG_TEST) — extern the port's
  FlagAction/predef equivalent; report the exact symbol.
- SIDE-MENU dispatch: .choseData → call ShowPokedexDataInternal (G2's label —
  same translation unit, no extern; b=0). .choseCry → GetCryData + PlaySound
  (; TODO-HW: audio HAL — stub PlaySound to a no-op that preserves flow; keep
  GetCryData if the port has it, else stub). .choseArea → predef LoadTownMap_Nest
  is OUT OF SCOPE → tagged STUB returning b=0 (area-shown path). .chosePrint →
  PrintPokedexEntry + printer OUT OF SCOPE → tagged STUB (mirror the _YELLOW_VC
  forbid-print branch as a no-op, or return b=3); keep the dispatch shape.
- RunPaletteCommand / GBPalNormal / SET_PAL_* → ; TODO-HW: palette (no-op stubs
  that preserve flow) unless the port already links them (extern if so).
- Harness: RunPokedexTest — seed wPokedexSeen/wPokedexOwned with a handful of
  set bits + wDexMaxSeenMon, open ShowPokedexMenu (or jump straight to the list
  draw to avoid the input loop), DelayFrame, DumpBackbuffer at the CONTENTS list.

DEX DATA is root-generated: assets/dex_order.inc (PokedexOrder) +
assets/dex_entries.inc (PokedexEntryPointers + entry blobs). PokedexToIndex /
IndexToPokedex walk PokedexOrder — code against that symbol (%include/extern per
root's published names). Do NOT create the .inc.

WATCH FOR: PokedexToIndex/IndexToPokedex both live in YOUR file but G2's dex
entry page calls them — keep their pret names + exact contract (in/out via
wPokedexNum). The side-menu exit codes in `b` (0 shown / 1 quit / 2 unseen-or-B)
drive ShowPokedexMenu's .goToSideMenu dec-b dispatch — get the polarity exact.
```

## Package G2 — pokedex (entry page)

```
TASK: Port the ENTRY-PAGE half of pret engine/menus/pokedex.asm (lines ~438-693)
to dos_port/src/engine/menus/pokedex_entry.asm. This file is %include'd BY G1's
pokedex.asm (root wires the one %include line) — SAME translation unit, so you
reference G1's labels (PokedexToIndex, IndexToPokedex, IsPokemonBitSet,
DrawTileLine) by name with NO extern. Touch ONLY pokedex_entry.asm.

[paste the shared context block here]

SPIKE FIRST (de-risk before the rest): the front-pic reuse. league_pc.asm (S6)
already calls GetMonHeader + LoadFrontSpriteByMonIndex successfully; DrawDexEntry
uses LoadFlippedFrontSpriteByMonIndex (also global in gfx/pics.asm) + PlayCry.
Wire JUST the "GetMonHeader → LoadFlippedFrontSpriteByMonIndex at hlcoord 1,1"
path into a throwaway harness FIRST, DumpBackbuffer, confirm a mon picture
renders, THEN build the full page around it. Report if the flipped variant needs
anything league_pc's unflipped path didn't.

SCOPE (your labels):
- ShowPokedexData + ShowPokedexDataInternal + DrawDexEntryOnScreen +
  Pokedex_PrintFlavorTextAtRow11 / …AtBC + Pokedex_PrepareDexEntryForPrinting,
  and HeightWeightText / PokedexDataDividerLine (PokeText is unreferenced — port
  it for label parity, tag if unused).
- Full-screen takeover at UI_POKEDEX_ENTRY (root-supplied): the bordered data
  page — top/bottom/left/right borders + corners (DrawTileLine with the $63-$6f
  tile set), the divider line, HT/WT (HeightWeightText), species № + name, the
  front pic at (1,1), and the flavor text at row 11.
- Height/weight print math: feet/inches (′ ″ tiles) + the big-endian hDexWeight
  dance (the tenths-of-pounds decimal-point insertion). Keep the EXACT byte math
  from pret — read fields at the offsets root published for dex_entries.inc's
  entry layout (species string, feet, inches, weight word, flavor pointer). The
  "owned?" gate (ld a,c; and a; ret z) skips HT/WT/flavor for unseen mons —
  preserve that ZF branch faithfully.
- Flavor text: Pokedex_PrintFlavorTextAtBC runs TextCommandProcessor on the
  inlined flavor bytes (root's gen_dex_entries inlines text_far → literal bytes;
  ; DEVIATION: text_far → inline). hClearLetterPrintingDelayFlags /
  hUILayoutFlags BIT_PAGE_CHAR_IS_NEXT → keep the flag set/reset around the call
  (extern the port's TextCommandProcessor).
- ShowPokedexDataInternal: the audio-fade + rAUDVOL writes → ; TODO-HW: audio
  (no-op, preserve flow); the SET_PAL_POKEDEX RunPaletteCommand → ; TODO-HW:
  palette. The JoypadLowSensitivity A/B wait loop is real (extern it, options.asm
  uses it). GBPalWhiteOut/ClearScreen/LoadTextBoxTilePatterns → extern the port's.
- Pokedex_PrepareDexEntryForPrinting (printer layout) → keep for label parity;
  its only caller is the printer path (OUT OF SCOPE) → tag it (may be unused).
- Harness: RunPokedexEntryTest — seed wPokedexNum to a seen+owned mon, call
  ShowPokedexDataInternal (skip the palette/audio stubs' side effects),
  DelayFrame, DumpBackbuffer at the data page (pic + HT/WT + flavor).

WATCH FOR: DrawDexEntryOnScreen returns CF = "print the flavor text" (set only
for owned mons) — ShowPokedexDataInternal does `call c, Pokedex_PrintFlavorText…`.
That CF is the last thing set before ret; do not let an intervening x86 op clobber
it. PlayCry / GetCryData → ; TODO-HW: audio (no-op preserving flow).
```

## Package I1 — link_menu (menus + dispatch; serial → timeout stubs)

```
TASK: Port the MENU/DISPATCH half of pret engine/menus/link_menu.asm to
dos_port/src/engine/menus/link_menu.asm. This is the PARENT of the %include
split — you own the file and the single %include line for I2's cup validators
(root confirms the exact seam at the PointerTable_f5488 boundary). The port
already has src/engine/link/cable_club.asm (S3: CableClub_TextBoxBorder +
DrawHorizontalLine) — extern from there; do NOT duplicate.

[paste the shared context block here]

SCOPE (your labels):
- Func_f531b (the colosseum cup-select screen: View/Rules + cup list + rules
  panel) + Func_f56bd (rules-panel redraw) + PointerTable_f56ee + the rules text
  tables (Text_f56f4/5728/575b) + the menu text tables (Text_f5791/579c) +
  Func_f59ec (cursor blit) + LinkMenu (TRADE CENTER/COLOSSEUM select) +
  TradeCenterText + all the Colosseum*Text `text_far` wrappers (inline the far
  content; ; DEVIATION: text_far → inline, naming_screen S7 precedent) +
  Func_f5476 / asm_f547c / asm_f547f.
- PointerTable_f5488 (dw PokeCup/PikaCup/PetitCup) is the seam: those three
  labels + their result routines live in I2's link_cups.asm (same translation
  unit — reference by name, no extern). Root wires the %include after your text
  tables.
- SERIAL IS ALL STUBS (this is the crux). Every Serial_ExchangeByte /
  Serial_ExchangeNybble / Serial_SyncAndExchangeNybble /
  Serial_ExchangeLinkMenuSelection / Serial_SendZeroByte / CloseLinkConnection /
  hSerialConnectionStatus / rSC / SC_START|SC_INTERNAL → ; TODO-HW: network HAL.
  The CONTRACT: with no partner, the stubs must drive the menu to pret's
  NO-PARTNER TIMEOUT / cancel path — i.e. the exchange loops terminate and flow
  reaches .choseCancel (LinkMenu) / the b-timeout branch (Func_f531b's
  .asm_f59b2). Design the stubs so the receive buffers read "no response"
  (e.g. hSerialConnectionStatus ≠ USING_INTERNAL_CLOCK, receive-nybble = $ff /
  timeout counter expires) and the DelayFrame loops fall through naturally. NEVER
  a bare ret that skips CloseLinkConnection / the cancel dialog. Report exactly
  which stub returns what so root can audit the return contract (gate 5).
- Dispatch tails: LinkMenu's `callfar PrepareForSpecialWarp` + `jpfar
  SpecialEnterMap` (the enter-cable-club hand-off) are ROOT-WIRED (Session 9
  spine, like S7's E). Stub them tagged (; TODO-HW / ; DEVIATION: warp seam =
  Session 9) reaching a root-provided seam; keep the pret jp/call targets +
  wLinkState/wEnteringCableClub/wCableClubDestinationMap writes intact.
- The menu boxes: LinkMenu's box at UI_LINK_MENU; Func_f531b's three boxes at
  UI_LINK_CUP_MENU (cite root's rects; report the exact rects you drew). Cursor
  arrows (▷) via Func_f59ec / the ldcoord_a writes. Generic HandleMenuInput for
  both menus (wTopMenuItemY/X etc. per pret).
- Harness: RunLinkMenuTest — open LinkMenu (or Func_f531b), DelayFrame,
  DumpBackbuffer at the select box. Since serial is stubbed to timeout, a live
  run should reach .choseCancel cleanly — a second mode can assert that (drive
  past the stub and DumpBackbuffer the ColosseumCanceled/timeout state).

WATCH FOR: the send/receive buffer nybble math (add a; add a; add $c0/$d0;
and $3 / and $c / and $f0) is bit-exact and flag-sensitive — port each `and`/`cp`
+ `jr z/nz` on the flag that op sets, not a stale one. LinkMenu's "who clocks the
connection wins" (hSerialConnectionStatus cp USING_INTERNAL_CLOCK) collapses to
the stub's fixed connection-status value — pick it so the single-player path is
deterministic and document it.
```

## Package I2 — link_menu (cup validation, fully real)

```
TASK: Port the CUP-VALIDATION half of pret engine/menus/link_menu.asm (lines
~197-511: PokeCup / PikaCup / PetitCup + every result routine) to
dos_port/src/engine/menus/link_cups.asm. This file is %include'd BY I1's
link_menu.asm (root wires the %include) — SAME translation unit, so I1's
PointerTable_f5488 references your PokeCup/PikaCup/PetitCup by name (no extern),
and you reference nothing of I1's. Touch ONLY link_cups.asm. This is PURE LOGIC —
no serial, no rendering, fully real GB behavior.

[paste the shared context block here]

SCOPE (your labels):
- PokeCup + PikaCup + PetitCup (the three cup eligibility validators) and ALL
  result routines: NotThreeMonsInParty, MewInParty, DuplicateSpecies,
  LevelAbove55, LevelUnder50, CombinedLevelsGreaterThan155, LevelAbove30,
  LevelUnder25, CombinedLevelsAbove80, LevelAbove20, LevelUnder15,
  CombinedLevelsAbove50, asm_f5689, asm_f569b, asm_f56ad. Each result routine
  PrintText's its Colosseum*Text (extern the text labels from I1 — same
  translation unit, reference by name) and returns its error code in a (1..$f);
  a valid team returns a=0. Keep every code exact — I1's dispatch reads it.
- The shared team-shape checks (party count == 3, no MEW, no duplicate species)
  repeat in all three cups — port each faithfully (the dec hl / cp [hl] duplicate
  scan is flag-dense; re-derive each ZF). MEW = the MEW species constant (extern
  the port's constant).
- Level gates: PokeCup 50-55 each + sum ≤155; PikaCup 15-20 each + sum ≤50;
  PetitCup 25-30 each + sum ≤80. Read wPartyMon1Level/2Level/3Level (extern the
  port's party-struct level symbols). The `cp NN / jr nc / jr c` bounds are the
  ZF/CF-sensitive core — port each compare on the flag it sets.
- PetitCup's "basic + size" check: it reads PokedexEntryPointers (root's
  dex_entries.inc — extern PokedexEntryPointers) to pull each mon's dex-entry,
  scans past the species-string '@' terminator to the height/weight fields, and
  gates on height < 6'8" (feet<7, and if ==6 inches gate) and weight ≤ 44 lb
  (the `sub $b9 / sbc $1` two-byte compare). It also calls Func_3b10f
  (evolution-stage check: "is this mon a basic/unevolved form?") per party mon →
  ; TODO/EXTERN: if the port has an evolution-stage predicate use it; else STUB
  it to the "basic" (CF clear) path and tag (; DEVIATION: evo-stage predicate not
  yet ported → basic path) — report the seam. FarCopyData (bank read of the dex
  entry) → the port is flat: replace with a plain copy from PokedexEntryPointers
  (; DEVIATION: FarCopyData bank read → flat copy). Keep the '@'-scan + field
  math EXACT against root's published dex_entries.inc entry layout.
- Harness: RunLinkCupsTest — seed a 3-mon party (levels + species) that PASSES
  one cup and one that FAILS a specific gate; call PokeCup/PetitCup, and since
  the result is a return code + a PrintText message, DumpBackbuffer at the
  message (or assert the return code via a scratch byte the harness reads). Show
  at least one pass (a=0) and one gated fail.

WATCH FOR: the result routines fall through / are shared jump targets — get the
`jp z, <Routine>` polarity exact (e.g. jp z, MewInParty on cp MEW). The height
gate math (add a;add a;ld b,a;add a;add b — ×20 for feet-to-something, then the
$51 compare) is bit-exact; mirror it, don't "simplify". The two-byte weight
compare (sub $b9 / sbc $1 → jr nc) sets CF across two bytes — port it as a real
16-bit compare preserving that CF.
```

---

## Launch template (root fills per package)

> subagent_type: general-purpose (or a named worker), model **opus** for G1 / G2
> / I1 (rendering + serial-flow reasoning). **I2 may be sonnet** — it is
> logic-only (memory: sonnet-parallel-logic-only). isolation: NONE — use a
> manually-created, pre-seeded `git worktree` and forbid git in the prompt
> (memory: swarm-workers-must-not-touch-git). Prompt = the package block above
> with the shared context block pasted in, plus: "Your worktree is at <abs path>,
> already seeded with assets (incl. dex_order.inc + dex_entries.inc) + the S1-S7
> menus src. You own ONLY <your file>; the %include seam is root's. Work only
> under dos_port/src/. NEVER run git. Report back in the deliverable shape."

Seed order recap (root-first): write gen_dex_order.py + gen_dex_entries.py + the
5 UI_* elements → make assets → build/check green on the primary → THEN `git
worktree add --detach` + hardlink-seed each worktree → verify each `make check` →
launch. Because G1/G2 share a translation unit and I1/I2 share one, give each
pair a clean file-ownership seam (parent owns the `%include`; child owns only its
included file) and let ROOT write the single `%include` line at integration.

Integrate one package at a time through the five gates; commit each alone
(explicit paths). Because of the %include coupling, integrate each PAIR together:
G1 then G2 (build the parent with the child's `%include`), then I1 then I2. Fill
the ledger rows in docs/current_plan_menus.md on integration: G1/G2, I1/I2 —
status + FAITHFUL EXCEPT. Do NOT start Session 9; if a package bounces its gates
twice, integrate the ones that pass, leave the ledger row honest, and stop for
the user.

---

## Root kickoff prompt (paste this to start the Session 8 root agent)

```
Run menus-port Session 8 (swarm wave 3). You are the ROOT/integrator session.

Read in order before doing anything:
1. docs/current_plan_menus.md — Session 8 scope; S7 is done (HEAD should be
   5c35b2a3 or later on branch menus-port; packages C/E/H + dsv_io.asm in).
2. docs/menus_swarm_s8_prompts.md — the prepared launch prompts. Follow it
   exactly: the "Root checklist" section is YOUR job list; the package blocks
   G1/G2/I1/I2 are the worker briefs (paste the shared context block into each
   one verbatim).
3. docs/archive/menus_swarm_s7_prompts.md — the S7 prompts + the "How these
   swarm prompts are constructed" methodology note at its end (the reusable
   recipe: root-first prework, shared context block, per-package briefs, five
   gates, ledger). docs/translation_log.md "menus-port Session 6/7" entries — the
   current port model your workers build on (full-takeover screens: options,
   naming_screen).

Execution order (root-first, because G1/G2 AND I2 depend on the dex data):
- First do root-owned prework, IN THIS ORDER, make + make check green on the
  primary before seeding:
    (a) write tools/gen_dex_order.py (pret data/pokemon/dex_order.asm ->
        assets/dex_order.inc, PokedexOrder internal-index byte blob) +
        tools/gen_dex_entries.py (pret data/pokemon/dex_entries.asm +
        text/pokedex/*.asm -> assets/dex_entries.inc, PokedexEntryPointers + entry
        blobs with text_far flavor INLINED). Add both to the Makefile assets rule;
        make assets. Publish the exact entry byte layout for G2/I2.
    (b) add the five UI_* elements (UI_POKEDEX_MAIN, UI_POKEDEX_SIDE_MENU,
        UI_POKEDEX_ENTRY, UI_LINK_MENU, UI_LINK_CUP_MENU) to the sidecar (pret GB
        rects, standard anchors) + make assets.
- Then seed 4 worktrees (G1, G2, I1, I2) — hardlink-copy dos_port/assets/*.inc
  (incl. the two new dex .inc) + all .2bpp/.pic/.1bpp from the primary into each,
  verify each make check is green, THEN launch G1/G2/I1 as Opus subagents and I2
  as Sonnet (logic-only). Workers never touch git, the Makefile, assets/*.inc,
  the sidecar, or gb_memmap.inc — they report needed lines. Give each pair a
  clean file-ownership seam; ROOT writes the single %include line into the parent
  at integration.
- Integrate one package at a time through the five gates (pret control-flow diff
  -> tag audit -> PROJ-cites-UI_* -> make check + make -> TODO-HW return-contract
  audit), then wire its Makefile SRCS + DEBUG_<PKG> harness into
  overworld.asm/debug_dump.asm, derive any new WRAM yourself against
  origin/symbols:pokeyellow.sym (do NOT trust proposed addresses), capture the
  FRAME.BIN gate headlessly (scratch conf + `-c exit` + SDL_VIDEODRIVER=dummy),
  and commit that package alone (stage explicit paths only). Integrate the coupled
  pairs together (G1+G2, then I1+I2) because of the %include.
- Cross-package coordination (Root checklist item 6): the %include seams are
  root-owned; I1's serial stubs must return the no-partner timeout path (audit at
  gate 5); SpecialEnterMap/PrepareForSpecialWarp/LoadTownMap_Nest/PrintPokedexEntry
  are root-wired stubs (Session 9 / out of scope), keep the dispatch shape;
  ZF/CF-clobber is the #1 S8 defect class (dense cp/jr in the bit-scan + cup
  gates) — diff every branch's flag-sense.
- Fill the package-status ledger rows in docs/current_plan_menus.md and mark
  Session 8 [x] only when all four packages are integrated, gated, and make +
  make check are green. Update translation_log.md per package. Archive the S8
  prompts (git mv docs/menus_swarm_s8_prompts.md docs/archive/) at closeout.

Do not start Session 9. If a package bounces its gates twice, integrate the ones
that pass, leave the ledger row honest, and stop for me.
```
