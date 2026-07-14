# Menu fidelity — de-bespoking the menu system against pret

> **STATUS — 2026-07-14. Rows 1–14 + 23 are DONE: 15 of 24. The shared drivers are finished;
> everything left is a leaf screen.**
> Next row is **15** (`naming_screen.asm`). Nine rows remain: **15–22 and 24.**
>
> **The row table below is the only authoritative status.** This header is prose and has
> already gone stale once (it claimed "1–8 done (9 of 24)" and "1-9 done (10 of 24)" in the
> same breath while row 10 was already committed). If the two ever disagree again, believe
> the table — every DONE row carries its commit hash.
>
> **Resume by re-running the `/loop`** (one file per iteration: audit → fix → gate →
> commit). It picks the first row that is `TODO`/`IN-PROGRESS` and works it. Update the row
> + append findings each iteration.
>
> **Sequencing notes.** Row 13 is the last SHARED DRIVER; the rest are leaf screens. Rows 19
> (`save`, 1080 ln) and 20 (`link_menu`, 1148 ln) are mostly TODO-HW SRAM/serial boundaries:
> low bug yield per line, and they MUST be split across iterations. **Row 22 is the
> highest-value row on the board and is sequenced last** — the battle move-menu family is
> missing entirely; it clears blocker B8 and unblocks Mimic + PP items. Consider promoting it.
>
> The text-subsystem detour this audit was paused for is **complete and archived**
> (`docs/plans/text_engine.md`): the staging model is gone, `TX_FAR` works, and there is now a
> `DEBUG_TEXT=1..9` oracle for streamed text — which the golden harness still structurally
> does not render.
>
> **What the audit found in 11 rows** — worth knowing before trusting any menu file's header:
> two game-breaking bugs (M-7: the ×NN quantity selector HUNG the game and drew its box
> invisibly; M-10: every YES/NO drew its ▶ next to the option the player was NOT selecting),
> two wrong allowlist entries, a wrong finding of my own (M-2), and several false "faithful" /
> "no live caller" / wrong-pret-file header claims. Row 6 is the first row whose *code* was
> already faithful — the lie was the file's **placement**, blessed by 3 rubber-stamped
> allowlist entries. Row 7 dropped **three** pret calls, each one hidden behind a comment
> asserting it couldn't be made (a stale `TODO-HW`, a false `STUB`, and a "not needed" that
> generalized one real deviation into two). Row 8's *x86* was faithful end to end — the first
> such row — but its **generated data** wasn't (M-16: the generator encoded the rendered string,
> so pret's `#MON` text command became 7 literal glyphs) and neither was the **label DB** the
> audit runs on (M-18: it couldn't see `equ` aliases, reporting 7 present labels as `missing`).
> Audit the generators and the tooling, not just the assembly. Row 9 part 1 found the same shape
> a third time: a `DEVIATION(icons)` comment that was true when written and **silently went false**
> when the party icons moved from BG tiles to OBJ (M-19), so swapping two mons left both icons
> painted over the blanked rows. Rows 10–11 sharpened the dominant failure mode into a named
> class: **the false stub / false TODO** — a comment asserting a dependency is unported when it
> is sitting in the link. Four instances so far (M-21, M-25, M-38, M-41, M-43), plus row 10's
> mirror image, where the ○ tile pret loads by *walking off the end of another asset's copy*
> was reimplemented as a load pret never makes. Do not believe a `STUB(...)`/`TODO-HW` comment;
> grep `pkmn.sym` for the symbol it names. (Row 11's M-46 is the one such claim that held up —
> and it took a symbol-table check to establish that.) Row 12 is the class's mirror image, and the
> sharpest argument for the rule: its *code* is faithful line-for-line, but its header declared the
> file **CHECK-only with "no live caller"** while `nm` shows it in the binary and `list_menu.asm`
> jumps to it — and the `GLITCH` tag's **`Safety:` note derived its "dormant, not reachable" verdict
> from that header**, so an item-underflow **ACE** gateway stood documented as unreachable while
> being live (M-48). A stale comment is not always cosmetic; here it inverted a safety assessment.
> The hit rate on "audited file turns out to hold a real defect" is still 100%. The remaining rows
> are not a formality.

## Why this exists

The menu system was built screen-by-screen and drifted from pret. The drift is
*self-reported but never audited*:

- **21 of 24 menu files self-declare divergence** (`DEVIATION`, `bespoke`, `placeholder`,
  `stand-in`, `scaffold`) — but nobody has checked whether each is forced, stale, or a bug
  hiding behind a comment.
- **All 30 menu-related allowlist relocations are auto-blessed boilerplate.** 7/7
  `relocated_files` + 23/23 `relocated_labels` carry `"pre-existing relocation … (draft
  Session H)"`; zero hand-written justifications. The allowlist's own header says *"Flagged
  for user review."* The mirror rule is currently enforced against a rubber-stamped baseline.
- **The battle move-menu family is missing entirely** — `SelectMenuItem`, `SwapMovesInMenu`,
  `PrintMenuItem`, `HandleMenuInput_` all report `missing`, and `MoveSelectionMenu` drops
  pret's `wMoveMenuType` dispatch. That is blocker **B8**, and why Mimic is dead code.

## Ground rules

1. **Distrust every comment.** Headers, TODOs, docs, commit messages and allowlist
   justifications here are frequently stale or wrong (a header said "DANGLING" on a live
   file; a stub comment claimed a routine was unported while its real body existed and was
   merely *unlinked* — that shadow was the whole of blocker B1). Evidence = pret source, the
   actual instruction stream, `label_status`/`translation.db`/`nm`, runtime dumps. When a
   comment proves wrong, fix the comment in the same commit and note it here.
2. **Port-only primitives are OFF-LIMITS but must be documented.** The window-list
   compositor (`set_single_window`/`add_window`/`hide_window`, `g_bg_whiteout`,
   `g_obj_over_window`), the menu-loop scratch (`menu_redraw_cb`, `menu_item_step`,
   `text_row_stride`, `place_flat_str`, `PartyMenuMirror`), the 40×25 canvas / `; PROJ`
   coordinates, and the TODO-HW boundaries (audio, palettes, SRAM, serial) are deliberate
   architecture. Do not reshape them. Where they force a divergence, tag the site and record
   it as **SANCTIONED** below with a real justification. *"The port's other screens do it
   this way"* is not a justification — the gate exists to reject exactly that.
3. **Conventions still bind:** pret label names exactly; rendered strings are Tier-1 DATA
   (generated, never hand-encoded charmap `db`); stubs only in `*_stubs.asm`; Gen-1 bugs are
   PRESERVED behind `BUG(level)` / `BUG_FIX_LEVEL`, never "fixed".

## Coverage

Shared drivers first — screens inherit their bugs, so fixing a screen against a broken
driver only relocates the divergence.

| # | port file | pret counterpart | status | commit | findings |
|---|---|---|---|---|---|
| 1 | `src/home/window.asm` | `home/window.asm` | DONE | `da875f9a` | M-1 (`HandleMenuInput_` split + blink + AB SFX), M-2 (list ▼ coord), M-3 (`PrintText` substitution), M-4 (stale `SFX_PRESS_AB`) |
| 2 | `src/home/textbox.asm` | `home/textbox.asm` | DONE | `d84ac907` | faithful (1 label, `DisplayTextBoxID`). No allowlist entry (already mirrored). One SANCTIONED TODO-HW(banking) deviation; header comment corrected. |
| 3 | `src/engine/menus/text_box.asm` | `engine/menus/text_box.asm` + `data/text_boxes.asm` | DONE | `df0c652f` | M-5 (`TwoOptionMenu_{Save,Restore}ScreenTiles` missing → row 5), M-6 (stride save slot was re-entrancy-unsafe — FIXED), 8 hand-encoded strings migrated to a generator |
| 4 | `src/home/list_menu.asm` | `home/list_menu.asm` | DONE | `3c2b6097` | **M-7 (qty menu HUNG the game — FIXED)**, M-8 (priced qty window clipped — needs mart anchor), M-9 (▷ swap counter never seeded — FIXED), M-2 **corrected** (my earlier finding was wrong; port's ▼ is faithful → new row 24). Priced price/qty coords swapped → FIXED; non-item tail duplicated the item tail → collapsed to pret's shared tail; 3 hand-encoded strings migrated to a generator; "no live caller" header claim was FALSE. |
| 5 | `src/home/yes_no.asm` | `home/yes_no.asm` + `engine/menus/text_box.asm` | DONE | `6d74aed2` | **M-10 (single-spaced + cursor on the WRONG option — FIXED)**, **M-11 (`wMenuWatchMovingOutOfBounds` never cleared — FIXED)**, M-5 RESOLVED (Save/RestoreScreenTiles absent by design → SANCTIONED). Allowlist: the boilerplate *file-level* entry was FALSE (it keyed all of `engine/menus/text_box.asm` to yes_no.asm) — deleted, re-added as a hand-justified *label-level* entry for `DisplayTwoOptionMenu` only. 9 hand-encoded strings migrated to a generator. New `DEBUG_YESNO` harness. |
| 6 | ~~`src/home/auto_textbox.asm`~~ → merged into `src/home/window.asm` | `home/window.asm` | DONE | `9b509fda` | **Allowlist ×3 DELETED, not re-added** — the "split" had no reason; the 3 routines now live in the file that mirrors pret (relocated → translated). Bodies were already faithful. Header named the wrong pret file. M-12 (the button-press flag is write-only in the linked build). |
| 7 | `src/home/start_menu.asm` | `home/start_menu.asm` | DONE | `3c409873` | **3 dropped calls restored, all 3 hidden behind a false comment**: M-13 `PlaySound SFX_START_MENU` (stale `TODO-HW`; audio is live), M-14 `PrintSafariZoneSteps` (false `STUB(safari)`; the body is real, linked, self-guarding), M-15 `SaveScreenTilesToBuffer2` (header claimed "not needed"; it's a pure WRAM copy — only the *restore* half is window-model). 2 SANCTIONED: `Joypad` + `CloseTextDisplay`, both genuinely unlinkable. No allowlist entries (file is at its mirrored path). |
| 8 | `src/engine/menus/draw_start_menu.asm` | same | DONE | `634dcbe6` | **First row whose x86 was faithful end to end** (both labels; flag preservation correct at all 3 CheckEvent/test → branch pairs). The defects were in the *data* and the *tooling*: M-16 (the generator encoded the RENDERED string, so pret's `#MON` — the $54 POKé text command — became 7 literal glyphs, silently bypassing the handler the port implements; **generator patched**, data now byte-identical to pret), M-17 (`StartMenuShowWindow`'s `global` + "re-arms it after sub-menus" comment — no such caller has ever existed), M-18 (`update_label_db` couldn't see `equ` aliases, so 7 present pret labels reported `missing`; **tool patched**). 1 SANCTIONED: the canvas→window bridge. No allowlist entries. |
| 9 | `src/engine/menus/start_sub_menus.asm` | same (861 ln) | **DONE** | `6ce2e8b6` (p1), `1b66f55a` (p2), `6e9cc7c2` (p3) | **Part 1 = the party half** (`StartMenu_Pokemon`, `ErasePartyMenuCursors`, `SwitchPartyMon{,_ClearGfx,_InitVarOrSwapData}`). M-19 (the swap **left both mons' icons on screen** — the `DEVIATION(icons)` excusing the missing OAM park went stale when icons became OBJ; FIXED, incl. the `RENDER_H` projection pret's 144px park constant needs), M-20 (`SFX_SWAP` + `WaitForSoundToFinish` missing behind another stale `TODO-HW`; FIXED — and wiring it is *what makes M-19 visible*), M-21 (the field-move stub's stated reason is FALSE — the effects ARE ported, they're in check-only files; comment corrected, dispatch scoped as **part 3**). Header advertised 4 STUBs that Session 9 had already wired. **Part 2 = the bag half + the 4 seams — DONE**: M-22 (a private `ret`-only `RunDefaultPaletteCommand` **shadowing the real global body** — the stub class the conventions exist to catch; a 3rd copy sits in `pokedex.asm`, filed), M-23 (`.exitMenu` dropped `LoadTextBoxTilePatterns`+`UpdateSprites` under a window-model excuse that covers neither — the START box could render out of HP-bar tiles), M-24 (`ItemMenuLoop` dropped the `hAutoBGTransferEnabled=0` store — the OW-A.13 leak class), M-25 (both refusal messages were `STUB(text)` blaming unported *features*, while the guard branches ran and showed **nothing**; nothing blocked them — generator patched, both now print), M-26 (`StartMenu_SaveReset` dropped pret's RESET branch *while row 8's `DrawStartMenu` already draws the RESET label*, and returned to the START menu instead of the map). Only `TrainerInfo_FarCopyData` still `missing` → **row 10**. **Part 3 = the field-move dispatch — DONE**: M-27. pret's real dispatch (GetPartyMonName + pointer table + badge gates + 6 generated refusal streams). STRENGTH / DIG / SOFTBOILED / FLASH / TELEPORT **work**; SURF+CUT+FLY gate correctly and stub at the leaf (`ItemUseSurfboard` ret-stub / `cut.asm` unlinked on `WriteOAMBlock` / `ChooseFlyDestination` genuinely missing). **`field_move_messages.asm` linked** — its sole blocker was `PlayCry`, now a documented ret-stub: one symbol was gating two field moves. |
| 10 | `src/engine/menus/trainer_card.asm` | `engine/menus/start_sub_menus.asm` (`DrawTrainerInfo` section) | **DONE** | `3df412e0` | M-33 (**the ○ tile was an *invented* load**: pret never loads `CircleTile` — its `$17`-tile `BlankLeaderNames` copy is one tile LONGER than the asset and runs off the end into it, which is the only reason the ○ exists in VRAM at all. The port copied 22 and then wrote the circle to `$76` itself. FIXED: the generator now emits the two blobs contiguously **and asserts the 23-tile total**, and the port makes pret's single copy), M-34 (`TrainerInfo_FarCopyData` was `missing` and the 5 VRAM loads were **hand-rolled `rep movsd`** with one trailing `g_tilecache_dirty` — armed, so not a live bug, but correct-by-accident in exactly the shape that has shipped visible corruption twice; the label is **restored** and every load goes through `CopyVideoData`, which arms the cache itself), M-35 (the two PlaceString labels were **hand-encoded charmap `db` bytes** — the Tier-1 violation; migrated into `tools/gen_menu_strings.py` → `assets/trainer_card_strings.inc`, generated bytes verified byte-identical), M-36 (a **defensive `BIT_SINGLE_SPACED_LINES` clear** with no pret counterpart — every setter in pret *and* the port re-clears it, so it cannot be set on entry; dropped. Two more copies live in `pokedex.asm`/`players_pc.asm`, filed). **Allowlist CHALLENGED**: deleted → 6 mirror violations → re-added with a hand-written why (the card is one self-contained SCREEN; pret bundles it with the six `StartMenu_*` dispatchers only for ROM-bank locality; no label forked, trail runs both ways). SANCTIONED + tagged: the missing `DisplayPicCenteredOrUpperRight` predef, the `LoadBadgeTiles` split, the `CopyVideoData` tail. VERIFIED live (`DEBUG_TRAINERCARD` → `FRAME.BIN`): card renders, **both ○ render from the rider copy alone**. |
| 11 | `src/engine/menus/party_menu.asm` + `src/home/pokemon.asm` | `engine/menus/party_menu.asm`, `home/pokemon.asm` | **DONE** | `3d5ce1e3` (p1), `1e14cecf` (p2) | **Part 1 = `party_menu.asm` — DONE.** Four excuses, all four false, all four checked against the linked build rather than believed: M-38 (`RunPaletteCommand` ×2 dropped behind *"TODO-HW: SGB/CGB palette command (Phase 5)"* — the palette is Phase 5, the CALL is not; it is a linked global and six other screens call it. Restored), M-39 (**the six party messages were hand-encoded charmap `db` bytes** drawn whole by a bespoke routine, behind *"engine far-text streams aren't GB-space assets yet"* — `gen_item_text.py` **already scans `engine/menus/party_menu.asm`** and has been emitting all five streams as linked globals since it was written. The hand copy also re-made M-16's mistake: literal `POKéMON` glyphs where pret writes the `$54` POKé command. Now `PartyMenuMessagePointers` → pret's `PrintText`), M-40 (**M-29 CLOSED for this screen**: authored `msgbox_party`, the projection M-29 said had to exist. Root cause pinned: `manual_text_scroll` (text.asm:386) copies the scratch's dialog rows into `GB_TILEMAP1` rows 0-5 — the party PANEL's rows — on every `<PROMPT>`/`<PARA>`, and *unlike* `sync_dialog_window` it is **not** gated on `g_bg_whiteout`. `msgbox_party` has no window (so the party window list survives) and its own `MB_PROMPT` hook, which is the mechanism that keeps `<PROMPT>` away from that copy), M-41 (**both learnability columns were STUBs** — `.teachMoveMenu` / `.evolutionStoneMenu` — blaming *"reachable only from item USE"*. Reachability is not a blocker and nothing was blocking: `CanLearnTM` and `EvosMovesPointerTable` are both translated **and linked**. The stubs cost the TMHM and EVO_STONE menus their entire right-hand column — the one thing those menus exist to show. Implemented; the evo scan walks the flat blob in place instead of pret's two `FarCopyData` stagings), M-42 (`.printItemUseMessage`'s hand-rolled printer was excused by *"every one of these nine texts terminates with `<DONE>` (never `<PROMPT>`)"* — **`RareCandyText` is `sound_get_item_1` + `text_promptbutton`**; the generated stream ends `$0B $06 $50`. Open-coding the printer meant that prompt was never dispatched. Routed through `PrintText`). Also restored the 2 `hAutoBGTransferEnabled` stores (M-24's precedent; the flag is **write-only** in the port — `do_bg_transfer` is deleted — but a screen that quietly stops writing it is how state drifts from pret's). 2 strings migrated to a generator (`assets/party_menu_strings.inc`). SANCTIONED + tagged: `ClearScreen`→`FillMemory` (canvas-scoped), `SetMonPartySpriteOrigin` + `ShowPartyMenuWindows` + `PartyMenuMirror` (window model), the pikachu-follower STUB ×2, `InitPartyMenuBlkPacket` (genuinely `missing`, SGB), `PartyMenuPrintText` (the projection wrapper around pret's `PrintText`). **Gate: golden `party_menu` PASSes with all 360 tilemap cells matching mGBA** — the message box and its text are byte-identical to the real ROM. **Part 2 = `home/pokemon.asm` — DONE.** M-43 (the `STUB(pikachu-follow)` comment, in **both** this file and `party_menu.asm`, claimed the follower system was unported — `IsThisPartyMonStarterPikachu`, `CheckPikachuFollowingPlayer` **and** `WriteMonPartySpriteOAMByPartyIndex`'s `$ff` branch were all already linked; the fourth instance of this excuse class. Both sites destubbed — UNVERIFIED at runtime, no golden has Pikachu following), M-44 (`PrintStatusCondition`'s hand-encoded "FNT" was **also an off-by-one**: `ld_hli_a_string` advances HL by len-1 and leaves A = the *second-to-last* char, which pret's `and a` tests; the port advanced 3 and left 'T'. Migrated to `assets/home_pokemon_strings.inc` and fixed), M-45 (`GetMonHeader`'s dropped `IndexToPokedex` predef — SANCTIONED, argued from pret's own `wPokedexNum` save/restore, tagged `DEVIATION(flat-data)`), M-46 (its fossil/ghost `TODO-HW` — **verified TRUE**, the three pics exist nowhere in the port). **Two generators patched**: `gen_battle_text.collect_wrappers`' regex silently skipped pret's address-suffixed `PartyMenuText_12cc` (only `*Text`/`*Text<n>` matched), and `gen_menu_strings.py` gained the `HOME_POKEMON` glyph-run group. SANCTIONED + tagged: `PartyMenuPrintText` (window model — pret's bare `PrintText` lands in the GB dialog rows, which the port draws behind windows), the `Bankswitch*` collapses, `DisplayPartyMenu`'s `DEBUG_PARTYMENU` harness calls. Gate: `make fidelity` 6/6 PASS. |
| 12 | `src/engine/menus/swap_items.asm` | same | **DONE** | `ad7dab3e` | **The x86 is faithful — the only label (`HandleItemListSwapping`) translates pret line-for-line, and faithdiff is clean (2/2 calls, 7/7 stores).** The lies were all in the comments: M-48 (the header declared the file **CHECK-only with "No live caller"** and its WRAM symbols "LOCAL PLACEHOLDERS below — ROOT migrates + deletes"; there are no placeholders, the file is in **GAME_SRCS**, `nm` shows `T HandleItemListSwapping`, and `list_menu.asm:435` jumps to it on SELECT — **and the `GLITCH` block's `Safety:` note inherited that false premise**, declaring the item-underflow gateway "dormant, not reachable in the current build" when it is live), M-49 (two gratuitous register-contract divergences: a pointless `mov dl,al` / `pop esi` / `mov al,dl` detour clobbering **DL**, which pret preserves, and a `push dx`/`pop dx` pair saving only the **low half** of an EDX the routine then uses as a full 32-bit flat pointer — plus leaving ESP 2-mod-4). No allowlist entry exists (file is at its mirrored path); nothing to challenge. Gate: `make fidelity` 6/6 PASS. **The swap path itself is UNVERIFIED at runtime** — no golden and no `DEBUG_*` harness presses SELECT on a list (same gap row 4 recorded for M-9); the goldens only prove no regression. |
| 13 | `src/engine/menus/field_moves.asm`, `display_text_id_init.asm` | `engine/menus/text_box.asm`, `display_text_id_init.asm` | **DONE** | `4c97321f` | The row with "no self-declared divergence" turned out to be **two files of dead code**, both advertising themselves as live. M-50 (`field_moves.asm`'s `IsFieldMove` — a port-only second scan of pret's field-move table, with **zero callers anywhere in the tree**; commit `c0b225ac` moved the party menu onto pret's `GetMonFieldMoves` and left it orphaned, while the header went on asserting *"party_menu.asm calls IsFieldMove"*. Deleted — the port now has exactly one field-move scan and it is pret's. The generated tables stay: `GetMonFieldMoves`/`DisplayFieldMoveMonMenu` are their real consumers), M-51 (**`DisplayTextIDInit` has never run**: it is linked, but its only caller is `DisplayTextID` in `src/home/text_script.asm`, which is **HOME_CHECK_SRCS** — the `DisplayTextID` in the binary is the `home_stubs.asm` ret-stub. So a faithful translation of a routine whose rendering is UNVERIFIABLE until `text_script.asm` links. Header now says so), M-52 (the dropped `hWY` store was tagged **`TODO-HW`** — wrong twice: `H_WY` exists and is written elsewhere, and no hardware work will ever make this store correct. It is a permanent window-compositor deviation; retagged `DEVIATION(window-compositor)` with the real argument). **M-12 CONFIRMED, still OPEN** — `text_script.asm` really is unlinked, so `wDoNotWaitForButtonPressAfterDisplayingText` really is write-only; same root cause, same fix (link `text_script.asm`), and it is not this row's file. **Epistemics cut both ways here:** `home_stubs.asm`'s claim that *"the only linked caller is TryDoWildEncounter"* looked wrong (three callers grep) and **checked out** — the other two are themselves check-only. `GetMonFieldMoves`/`DisplayFieldMoveMonMenu` faithdiff clean/blind-spot-only; no allowlist entries for either file. Gate: 6/6 PASS. |
| 14 | `src/engine/menus/options.asm` | same | **DONE** | `f2c83ad7` | All 17 labels `translated`, and the **x86 really is faithful** — faithdiff clean on every handler (the flag-juggling `sla a`/`rl c` → `shl`/`rcl` translations, the `swap a` → `rol al,4`, the cursor-skip arithmetic, all correct). The defects were around it: M-53 (**the `rAUDTERM` store was dropped behind a false `TODO-HW: audio HAL — no APU register in the port`** — `rAUDTERM` is a live GB-memory byte, `$FF25`, written by `engine_1.asm`/`engine_2.asm` and **read every frame by the OPL/Tandy/PC-speaker shims** to route channel output. Nothing was blocking it. Restored — pret silences the channels while the speaker setting changes, and the port simply wasn't), M-54 (**18 hand-encoded charmap `db` strings**, the Tier-1 violation — and the file header didn't merely omit the excuse, it *asserted* one: it called them *"Tier-2 code data"*. A string the player reads is Tier-1 DATA. Migrated into `tools/gen_menu_strings.py` → `assets/options_strings.inc`; generated bytes **byte-compared against the old literals: identical, all 18**), M-55 (`InitOptionsMenu` dropped pret's `hAutoBGTransferEnabled` store — the M-24 leak class, restored; and the `BUG(cosmetic)` joypad-state tag carried **no `%if BUG_FIX_LEVEL` block**, so the convention's "preserve the bug, offer the guarded fix" contract was half-implemented. Added at level 2, using pret's own one-line fix). SANCTIONED + tagged: `options_mirror` ×2 + `OptionsShowWindow` (the window compositor stands in for pret's VBlank BGMap transfer), `text_row_stride = 20`. No allowlist entries — nothing to challenge. **VERIFIED live** (`DEBUG_OPTIONS` → `FRAME.BIN`): the screen renders **byte-identical** before/after the string migration, and the rendered PNG shows all five rows, their values, CANCEL and the ▶ cursor drawing correctly. `make fidelity` 6/6 PASS. |
| 15 | `src/engine/menus/naming_screen.asm` | same | **DONE** | `848b6593` | Five findings, one of them the worst bug this audit has hit. **M-63: `PrintNamingText` clobbered the screen-type in AL** (`mov al,[wNamingScreenType]` immediately followed by `mov eax, YourTextString`, destroying it with the low byte of an address) — so PLAYER and RIVAL both fell into the MON path and the **player-name screen printed a garbage species name and asked "NICKNAME?" instead of "YOUR NAME?"**. faithdiff was **clean** on that routine throughout: it is a register defect, the one class the tools cannot see. Caught only by rendering the screen. M-57 (**wrong SFX id, `0x3E` vs the real `0x90`** — played on every letter press, kept alive by a `TODO-HW` claiming `PlaySound` is a stub when it is a real body in `home/audio.asm`; closes **M-4**), M-58 (**5 hand-encoded strings**, one carrying a false "no generator exists" excuse — `collect_far` already flattened `text_3.asm`; all five generated, **bytes identical**, and `DoYouWantToNicknameText` restored to pret's real `text_far`+`text_end` shape), M-59 (**`gb_text.encode` has no longest-match pass** — `"RIVAL's "` is the first apostrophe in any generator input and would have encoded `'s` as two glyphs instead of the `$BD` ligature; worked around, encoder gap still open), M-60 (**`AskName` called `YesNoChoice`, which pret's `AskName` must not** — `YesNoChoice` wraps the box in a buffer-1 save/restore and **buffer 1 belongs to `AskName`**; it was harmless only because the port's `YesNoChoice` *drops* that wrapper, i.e. this file's fidelity rested on another file's infidelity and would break the day `yes_no.asm` is fixed. Now calls `DisplayTextBoxID` as pret does: **10/10 calls, 4/4 stores**). SANCTIONED + tagged: `InitYesNoTextBoxParameters` (pret's own routine, the only supported way to pass the box geometry the port's two-option path reads from `.bss`), `naming_mirror`/`naming_show_window`/`SetMonPartySpriteOrigin` (window compositor + PROJ), the JP-only dakuten branch (verified unreachable: the EN grid in `data/text/alphabets.asm` emits no `ﾞ`/`ﾟ`). Filed elsewhere: **M-61/M-62** (`RunDefaultPaletteCommand` defined twice, and both copies pass the palette id in **BL where pret uses B/BH** — a live hazard for the in-flight palette body; handed to that session). **VERIFIED live** (`DEBUG_NAMINGSCREEN` → `FRAME.BIN` → PNG): before the fix the screen rendered `F STONE`/`NICKNAME?`; after, **"YOUR NAME?"** with the grid, box, cursor and underscore row correct. `make fidelity` 6/6 PASS. |
| 16 | `src/engine/menus/pokedex.asm`, then `pokedex_entry.asm` | `engine/menus/pokedex.asm` | **DONE** | `cb247fdc` (p1), `e68b8c7f` (p2) | **p1 `pokedex.asm`: the AREA option was DEAD — `LoadTownMap_Nest` was a complete, linked, never-called body (M-64).** Also: printer path dropped 2 calls/3 stores behind a fake STUB (M-65); `GetCryData` ret-stub in a mirror file (M-66); duplicate `RunDefaultPaletteCommand` (M-67); 3 extern comments claiming stubs that are real bodies (M-68); hand-encoded strings (M-70). **Tooling: a fresh `PKMN.IMG` ships a STALE `FRAME.BIN`, so a non-dumping harness reads as a pass (M-69).** **Part 2 = the DATA (entry) page — DONE.** The whole file `pokedex_entry.asm` was a **parallel-worker artifact** (its header said so) and is **deleted**: both halves now live in `pokedex.asm` as in pret, which retires all 10 allowlist entries (M-78; the 10th, `GetCryData`, was already dead after M-66). Four dropped-behind-a-false-comment fixes: M-73 (`rAUDVOL` halving for the cry, hidden behind a fake `TODO-HW: no APU` — the shims read $FF24 every frame; same false claim still in `status_screen.asm`, filed), M-74 (`RunDefaultPaletteCommand` "not defined in the port" — it is a global this same file already calls), M-75 (`PlayCry` call dropped), M-76 (`hDexWeight` save/restore dropped although **$FF8B is a live HRAM union** holding the overworld's `hPreviousTileset`). M-77: 3 more hand-encoded strings → generator, bytes identical. RHYDON DATA page rendered and looked at. |
| 17 | `src/engine/menus/pc.asm`, `players_pc.asm`, `oaks_pc.asm`, `league_pc.asm` | same | **IN-PROGRESS (part 1 of 4 DONE)** | `3b495afb` (p1: pc.asm) | **p1 `pc.asm`: the file's header made three claims and all three were false.** M-79: all six `PlaySound`/`WaitForSoundToFinish` calls dropped behind a fake `TODO-HW: audio HAL` — audio is ported and live (the row-9 M-20 shape). M-80: `Save/LoadScreenTilesFromBuffer2` "replaced" by a shim that saved **`g_window_count`**, i.e. nothing; the real bodies were in `movie/title.asm` all along and the *load* half was merely never `global`. M-81: the four dialogs were a private message engine over **nine hand-encoded charmap strings** (Tier-1 violation) that could not render text COMMANDS, so `<PLAYER>`/POKé were open-coded as glyph runs — now generated (`assets/pc_text.inc`) and printed by `PrintText` with pret's four restored wrapper labels. **M-82 (filed): `ActivatePC` is UNREACHABLE** — `home/overworld_text.asm`'s PC text scripts are still `%ifdef`-guarded out under a stale "targets are NI" comment, so the whole PC subsystem is dead code in the shipped binary. New `DEBUG_PC` harness; dialog rendered and looked at. `pc_stubs.asm` (DisplayPCMainMenu / BillsPC_) verified: ret-only-plus-menu-vars, in a `*_stubs.asm`, shadowing nothing. **p2-p4: `players_pc.asm`, `oaks_pc.asm`, `league_pc.asm` REMAIN** (all three carry the same drawn-whole + hand-encoded-charmap debt). |
| 18 | `src/engine/menus/main_menu.asm` | same | TODO | | DEVIATION ×8; `OakSpeech` stub |
| 19 | `src/engine/menus/save.asm` (1080 ln) | same | TODO | | expect mostly TODO-HW/SRAM sanctioned; split |
| 20 | `src/engine/menus/link_menu.asm` (1148 ln), `link_cups.asm` | `engine/menus/link_menu.asm` | TODO | | expect mostly TODO-HW/serial; allowlisted split (18 labels); split |
| 21 | `src/engine/menus/draw_badges.asm` | same | TODO | | "Port stand-in" |
| 22 | **`MoveSelectionMenu` / `SelectMenuItem` / `SwapMovesInMenu` / `PrintMenuItem`** | `engine/battle/core.asm` | TODO | | **clears blocker B8**; unblocks Mimic + PP items. Needs row 1 settled first. |
| 23 | **`PrintText` / `PrintText_NoCreatingTextBox`** | `home/window.asm` | DONE | `2c33f7a6` | opened by row 1 — see **M-3** (now FIXED: one printer, placement is a data record; `PrintText_Overworld`/`PrintText_NoBox` forks deleted). Verified by byte-identical `DEBUG_ITEMTM` + `DEBUG_LEARNMOVE` frames. Was: a battle-scope wrapper squatted on the label, so 9 non-battle files printed through the battle box. |
| 24 | **`HandleMenuInput_.downArrowTile`** (▼ blink coord space) | `home/window.asm` | TODO | | opened by row 4 — see the **corrected M-2**. The blink targets pret's ABSOLUTE (18,11); every list draws box-relative into the stride-20 scratch, so the blink is inert. Row 1's file, found after row 1 closed. |

Also: pret's `engine/menus/unused_input.asm` has **no port counterpart**. Confirm it is
genuinely unreachable, then record it as intentionally-absent rather than unexplained.

## Known — do NOT re-file these as new findings

- The **window-compositor full-takeover gap** (naming / main_menu / pokédex-entry don't
  composite through the menu window; `options.asm` is the working reference).
- **"Menu boxes corrupt live but fine in harness"** — this is *not* a menu bug. It's the
  overworld VRAM tile-slot defect, owned by `docs/current_plan_overworld_port.md`.
- **Interactive nav sweeps** the golden harness structurally cannot drive (pokédex list
  scroll + side menu, dex `<PAGE>` flavor scroll, link cup-select nav, naming grid nav).

`docs/plans/menus.md` has a per-package ledger of known divergences — **verify its claims
rather than trusting them**; at least one (`LoadPokedexTilePatterns`) is already stale.

## Findings

Format (from `docs/archive/battle_audit_findings.md`, which worked):

```
### M-1. <one-line summary> **[OPEN | FIXED <hash> | SANCTIONED | BLOCKED]**
**File:** <port path:line>
**pret:** <pret file:line/label>
**What's wrong:** …
**Fix:** …
**Severity:** high (wrong gameplay/state) | medium (wrong text/edge) | low (cosmetic)
```

### M-1. `HandleMenuInput_` was missing: no flag clear, no ▼ blink, no A/B blip **[FIXED — row 1 commit]**
**File:** `dos_port/src/home/window.asm:126` (+ `src/home/pokemon.asm:264`)
**pret:** `home/window.asm:1` (`HandleMenuInput` / `HandleMenuInput_`)
**What's wrong:** the port collapsed pret's two entry points into one `HandleMenuInput` and
dropped four behaviors along the way:
1. pret's `HandleMenuInput` is *only* `xor a / ld [wPartyMenuAnimMonEnabled], a` falling into
   `HandleMenuInput_`. The port had no such clear, so the party-mon icon-bob flag was never
   reset by the driver — it only worked because `HandlePartyMenuInput` happens to clear it by
   hand afterwards. Any path that leaves the flag set (an early exit, a future caller) would
   have made the *next* menu animate a party icon. `HandleMenuInput_` reported **missing** in
   `translation.db`; `HandlePartyMenuInput` called the wrong (clearing) entry.
2. The blinking ▼ was never blinked: pret's wait loop calls `HandleDownArrowBlinkTiming` at
   `hlcoord 18, 11` every poll. The port's loop just didn't. (The `bag_menu` golden mask
   already recorded the symptom — *"MORE-list arrow: blinking … the port draws it steady"* —
   and was masked rather than fixed.)
3. The A/B press SFX (`SFX_PRESS_AB`, gated on `wMiscFlags` `BIT_NO_MENU_BUTTON_SOUND`) was
   dropped. The header comment claimed this was deliberate — it dates from before the audio
   engine was live, and was stale. `pc.asm`/`players_pc.asm` were already setting and clearing
   `BIT_NO_MENU_BUTTON_SOUND` to suppress a sound that nothing played.
4. `hDownArrowBlinkCount1/2` were not saved/restored around the loop (pret pushes both).
**Fix:** split `HandleMenuInput` / `HandleMenuInput_` per pret and repoint `HandlePartyMenuInput`
at the underscore entry; add the blink call, the counter save/restore, and the gated
`PlaySound SFX_PRESS_AB`. The header comment that claimed the shake and the sound were
"dropped" is corrected in the same commit (the shake was never dropped — it was there).
**Severity:** medium (dead cosmetic + latent state leak; no wrong gameplay observed)

### M-2. The ▼ blink in `window.asm` uses ABSOLUTE GB coords against a box-relative scratch **[OPEN → needs row 24]**
> **CORRECTED at row 4 (2026-07-13). The original text of this finding was WRONG** — it claimed
> the port's list drew its ▼ in the wrong cell and told row 4 to move it. It does not, and row 4
> did not move it. Recording the error because the whole point of this audit is that confident
> prose is not evidence.

**The arithmetic I failed to do the first time:** the list box's origin is GB(4,2). pret's ▼ at
`hlcoord 18, 11` is therefore box-relative **(col 14, row 9)** — which is *exactly*
`LIST_DOWN_COL 14` / `LIST_DOWN_ROW 9`, the cell the port already writes. **The port's ▼
placement is FAITHFUL** (and row 4 re-derived it a second way: pret's `ld bc,-8 / add hl,bc`
from the post-loop `hl`, which on a stride-20 line lands on the same cell).

**The actual defect** is on the *other* side, in the blink: `src/home/window.asm`
`.downArrowTile` computes its target as `[text_row_stride] * MENU_ARROW_ROW(11) + W_TILEMAP +
MENU_ARROW_COL(18)` — pret's **absolute screen** coordinate. But every list renders
**box-relative** into the stride-20 scratch, where (row 11, col 18) is not the arrow cell; it is
outside the 16×11 box altogether. So the blink is inert for the bag/PC lists — the arrow just
sits there. Harmless today (the blink only acts on a tile that already *is* a ▼, so it draws and
erases nothing), but the mechanism is dead.

**Fix:** belongs in `src/home/window.asm`, which is **row 1's** file (already DONE) — not row 4's,
so row 4 correctly did not cross into it. Needs its own row: see **row 24**. The blink target must
be expressed in the same coordinate space as the box that owns the arrow (box-relative when a
menu scratch is active), after which the `bag_menu` golden's "MORE-list arrow" mask can be
re-examined.
**Severity:** low (cosmetic — a non-blinking arrow)

### M-3. `PrintText` is a battle-scope substitution; pret's `PrintText` is unported **[FIXED — row 23]**
**File:** `dos_port/src/engine/battle/move_effect_helpers.asm:53` (the `PrintText` global);
the real body lives in `dos_port/src/home/text.asm:1332` under the **forked name**
`PrintText_Overworld`, with `PrintText_NoCreatingTextBox` forked to `PrintText_NoBox`.
**pret:** `home/window.asm:281` (`PrintText` / `PrintText_NoCreatingTextBox`)
**What's wrong:** the port's only `PrintText` global is `mov eax, esi / jmp PrintBattleText`,
whose tail (`RunBattleTextStream`, `core.asm:562`) hardcodes the **battle** dialog geometry
(`text_row_stride = FW`, `BTXT_LINE2`, `BTXT_ARROW`, `BattlePromptWait`). Meanwhile pret's
actual `PrintText` body — MESSAGE_BOX border, the `set_single_window` dialog projection,
`TextCommandProcessor` at (1,14) — sits in `text.asm` under a forked name, which is a direct
violation of the "preserve pret labels / never fork a name" hard rule.
The consequence is a **live bug, not just a naming problem**: 9 non-battle files
(`cut.asm`, `field_move_messages.asm`, `trainer_engine.asm`, `player_animations.asm`,
`evolution.asm`, `learn_move.asm`, `item_effects.asm`, `save.asm`, `naming_screen.asm`) call
`PrintText` and therefore print **overworld** messages through the **battle** box. Their own
extern comments prove they did not intend this — `cut.asm:79` and `field_move_messages.asm:54`
both say `extern PrintText ; src/text/text.asm`, i.e. they believe they are calling the text
engine. The linker binds them to the battle wrapper instead. (Some later callers — `save.asm`,
`link_menu.asm` — then *documented* the battle printer as a deliberate choice, because
`PrintText_Overworld` calls `set_single_window` and collapses their window list. So the two
ABIs have since been built on: flat stream pointer + battle box vs. staged `NPC_DIALOG_BUF`
pointer + dialog window.)
**Fix:** row 23. Restore the pret names (`PrintText` / `PrintText_NoCreatingTextBox`) on the
real body, give `PrintText` the staging prologue so one label serves both pointer ABIs, and
select the box geometry from the live canvas rather than from which symbol the caller picked.
Neither `text_row_stride` nor `g_bg_whiteout` is usable as that discriminator (checked: both
are multiplexed across screens), so this needs an explicit canvas selector — which is why it
is its own row and not a rider on row 1.
**Severity:** high (wrong text box on every overworld field-move / Cut / trainer message)

**Resolution (row 23).** The two printers are now **one** `PrintText`; the box placement is
**data**. A *projection record* (`include/msgbox.inc`) holds the stride, box origin/size, the
two text-line cursors, the ▼ position, the prompt hook, and the window geometry; `text_msgbox`
points at the active one. Two records exist — `msgbox_dialog` (`src/home/text.asm`: the
hand-tuned overworld dialog window, stride 20, `set_single_window` at wx=87/wy=152) and
`msgbox_centered` (`src/engine/battle/core.asm`: the center-projected box on the 40-wide flat
canvas, no window, so a full-screen menu's window list survives). `PrintText` stages the flat
stream into `NPC_DIALOG_BUF` and falls through to `PrintTextStaged`, which republishes the
record and draws. `PrintBattleText`/`RunBattleTextStream` are now two-line shims that select
`msgbox_centered` and jump into the one printer; the forked `PrintText_Overworld` /
`PrintText_NoBox` bodies are deleted, and `PrintText` / `PrintText_NoCreatingTextBox` live at
the mirrored path `src/home/window.asm` under their pret names.

Every call site now *declares* its projection (`mov dword [text_msgbox], msgbox_…`) immediately
before the call, which also closes a **latent leak found on the way**: only `core.asm` ever wrote
`text_line2` / `text_arrow_pos` / `text_prompt_hook` and nothing restored them, so after any
battle the overworld dialog's `<LINE>` and `<PROMPT>` still pointed at battle geometry.
`PrintTextStaged` republishes all four fields on every call, so the leak cannot recur.

**Verified by observation** (the golden suite covers no dialog text — 6/6 still pass, which only
proves the covered screens are untouched): headless `DEBUG_ITEMTM` (dialog projection, via
`iu_print_text`) and `DEBUG_LEARNMOVE` (centered projection) both render **byte-for-byte
identical** `FRAME.BIN` to the pre-refactor build. The first capture was *not* identical, and that
is how a real bug was caught: `TextBoxBorder` walks `EDI` over the box rows and does not restore
it, so holding the record pointer in `EDI` across the call made `MB_WIN_TILEMAP` read back zero
and every dialog silently took the no-window branch — the box vanished. Reloading `EDI` from
`text_msgbox` after `TextBoxBorder` fixed it. No golden could have caught this.

### M-4. `naming_screen.asm` hardcodes a stale `SFX_PRESS_AB` **[OPEN]**
**File:** `dos_port/src/engine/menus/naming_screen.asm:110-114` (row 15's scope — filed, not touched)
**What's wrong:** it defines `SFX_PRESS_AB equ 0x3E` locally under a `; TODO-HW(audio)` comment
claiming the real id is unavailable. The audio engine is live and the generated
`assets/audio_constants.inc` gives `SFX_PRESS_AB equ 0x90`. The local equ is both wrong and
stale — 0x3E is some other sound.
**Fix:** row 15 — delete the local equ + TODO-HW, `%include "assets/audio_constants.inc"`, and
add the `.inc` to `naming_screen.o`'s Makefile prerequisites (as row 1 did for `window.o`).
**Severity:** medium (wrong SFX id played on every naming-screen keypress)

### M-5. `TwoOptionMenu_SaveScreenTiles` / `_RestoreScreenTiles` do not exist in the port **[OPEN — row 5]**
**File:** none — `sqlite3 translation.db` reports both `missing`, and neither name appears anywhere
under `dos_port/src/` (checked, not assumed).
**pret:** `engine/menus/text_box.asm:316` / `:334` (called by `DisplayTwoOptionMenu`, `:238`/`:297`/`:308`)
**What's wrong:** pret's two-option menu **saves the 6×5 tile block it is about to cover into
`wBuffer`, then restores it** after the choice (that is what makes a yes/no box disappear without a
full redraw; pret even documents that wider menus don't fully restore). The port's
`DisplayTwoOptionMenu` (relocated to `src/home/yes_no.asm` — row 5) calls neither, so nothing
save/restores those tiles.
**Likely benign, but UNVERIFIED:** the port draws two-option menus through the **window compositor**,
and hiding the window should reveal the untouched canvas beneath, making the save/restore pair
structurally unnecessary rather than merely forgotten. That is a hypothesis; nobody has confirmed it,
and the pret-labelled routines are silently absent instead of being recorded as intentionally so.
**Fix (row 5):** confirm the window model really does restore the covered tiles (observe a yes/no box
opening and closing over a drawn screen), then either record the pair as intentionally-absent with a
written why, or implement them.
**Severity:** medium (leftover box tiles if the hypothesis is wrong)

### M-6. `DisplayTextBoxID_` saved the caller's stride in a static — and it re-enters itself **[FIXED — row 3]**
**File:** `dos_port/src/engine/menus/text_box.asm:199` (was: `tb_saved_stride: resd 1` in `.bss`)
**pret:** n/a — the stride save is a port-only artifact of the 40-wide canvas (`text_row_stride`).
**What's wrong:** `DisplayTextBoxID_` forced `text_row_stride = 40` for the dispatch and restored it
from a **single static slot**. But the routine **re-enters itself**: both function-table handlers
(`DisplayMoneyBox`, `DoBuySellQuitMenu`) call `DisplayTextBoxID`, so a nested dispatch runs inside
the outer one. The inner call overwrote the static with the already-forced 40, and the outer restore
then handed the caller **40 instead of its own stride** — i.e. entering the mart from the overworld
(stride 20) left the overworld at stride 40 on the way out.
Mostly *masked* today, which is why it survived: row 23 made `PrintText` republish `text_row_stride`
from its projection record on every call, so overworld dialog self-heals on the next message. Any
other stride consumer that ran first would not.
**Fix:** the save slot is now the **stack** (`push dword [text_row_stride]` / `pop dword
[text_row_stride]`), which is re-entrancy-safe by construction. `pop <mem>` touches neither EFLAGS
nor AL, so the handlers' CF/AL return contract still passes through — matching pret's plain `ret`.
The `TWO_OPTION_MENU` jump happens before the push, so it cannot unbalance the stack.
**Severity:** medium (wrong text stride after a mart/money box, masked by the row-23 republish)

### Row 3 — `src/engine/menus/text_box.asm` (audited)

Nine labels, all `translated`, plus the two `missing` ones filed as **M-5**. One real bug (**M-6**,
fixed) and one convention violation, fixed:

- **Tier-1 violation fixed: 8 hand-encoded charmap strings migrated to a generator.**
  `BuySellQuitText`, `UseTossText`, `MoneyText`, `BattleMenuText`, `SafariZoneBattleMenuText`,
  `SwitchStatsCancelText`, `PokemonMenuEntries`, `CurrencyString` were raw `db 0x81,0x94,…` blocks.
  They are now **generated** by `tools/gen_textbox_strings.py` → `assets/textbox_strings.inc`
  (`%include`d, wired into `make assets` + the `text_box.o` prerequisites). `<NEXT>` ($4E) and
  `<PK>`/`<MN>` ($E1/$E2) are control/glyph bytes `gb_text.encode` cannot map, so the generator emits
  them as named raw bytes between encoded runs — the documented pattern. `×` and `¥` *are* encoded.
  The generated bytes were byte-compared against the hand-written block: **identical, all 8**.
- **SANCTIONED — DEVIATION(en-only):** the JP-only table rows (`JP_MOCHIMONO`, `JP_SAVE_MESSAGE`,
  `JP_SPEED_OPTIONS`, `JP_AH`, `JP_POKEDEX`) and their strings are omitted from
  `TextBoxTextAndCoordTable`. Those template IDs are unreachable in the EN game, and
  `SearchTextBoxTable` simply never matches them. Justification is the shipped locale, not
  convenience.
- **SANCTIONED — PROJ menus:** table geometry is the generated `UI_*` equates (canvas-projected),
  `GetAddressOfScreenCoords` uses the 40-wide canvas stride and an O(1) `imul` for pret's row loop
  (same result, `D`=0 on exit as pret leaves it), and `GetTextBoxIDText` returns the text pointer in
  **EAX** rather than DE — a 16-bit DX cannot hold a flat pointer, and EAX is `PlaceString`'s source
  register.
- **`DoBuySellQuitMenu`'s 2-row `menu_item_step` is CORRECT, not a bug** — I checked it because it
  looked wrong. pret's `PlaceMenuCursor` steps **`bc = 40` (two GB rows) by default**, dropping to
  one row only when `BIT_DOUBLE_SPACED_MENU` is set (the constant's name reads backwards); and pret's
  `<NEXT>` likewise advances **2 rows** unless `BIT_SINGLE_SPACED_LINES` is set. So BUY/SELL/QUIT
  really is double-spaced on hardware, and the port's `<NEXT>` implements the same default. The
  existing `DEVIATION(framework)` tag (spacing carried in `menu_item_step` instead of
  `hUILayoutFlags`) is accurate.
- **Allowlist:** nothing to challenge. The only relocation out of this pret file is
  `DisplayTwoOptionMenu` → `src/home/yes_no.asm`, which is **row 5's** scope and whose ledger line
  already says "allowlisted relocation — challenge". Not challenged twice.
- **faithdiff** — every line is one of the two documented blind spots or the indirect dispatch:
  `DisplayTextBoxID_` drops `DisplayTwoOptionMenu (jp)` because the port's is a **conditional** `je`
  (faithdiff's port matcher only accepts `call`/`jmp`); it drops `hl (jp)` and adds `eax (call)`
  because pret's function-table dispatch is `push .done / jp hl` and the port's is `call eax / jmp
  .done` (same control flow, and CF survives both). `DisplayMoneyBox` adds `[W_STATUS_FLAGS_5]` and
  `DisplayFieldMoveMonMenu` adds `[wFieldMoves]` / `[wFieldMovesLeftmostXCoord]` because pret writes
  those with `set/res n,[hl]` and `ld [hli],a`, which faithdiff's pret store-matcher does not see.
- **Verified:** `DEBUG_TEXTBOXID=0x06` (USE/TOSS) and `=0x0C` (SWITCH/STATS/CANCEL) render
  **byte-identical** `FRAME.BIN` to the pre-change build, and the rendered PNG shows the generated
  strings drawing correctly. `make fidelity` 6/6 PASS.

### Row 2 — `src/home/textbox.asm` (audited, faithful)

One label (`DisplayTextBoxID`), 7 lines of pret, and it holds up. Verified rather than trusted:
`DisplayTextBoxID_` is a **real linked body** at `src/engine/menus/text_box.asm` (`nm`:
`T DisplayTextBoxID_`, and both files are in the linked `HOME_SRCS`/menus lists — not a stub, not
a check-only shadow), and the header's claim that the interim copy in `src/home/text_script.asm`
was retired is **true** (it is an `extern` there now). No allowlist entry exists for this label —
correctly, since it already sits at its mirrored path.

- **SANCTIONED — TODO-HW(banking).** pret is `homecall_sf DisplayTextBoxID_`; the port is a plain
  `call`. The `_sf` suffix is load-bearing and the old header misread it: `homecall_sf` pops the
  saved bank into **BC** rather than **AF** specifically so the *callee's* flags survive the bank
  restore (`BankswitchCommon` is two stores + `ret`, flag-neutral). Flags — the contract callers
  actually read (`DoBuySellQuitMenu`'s CF) — therefore pass through on both sides. But the shuffle
  also **destroys A and BC** on exit, where the port preserves AL and BX. That divergence is
  strictly permissive (nothing can depend on a register being clobbered) and there is no bank byte
  to restore under flat memory. Tagged at the call site.
- **Comment fixed (epistemics).** The header asserted *"Register/flag pass-through is total"* — true
  of the port, but stated as if it matched pret, which it does not. Rewritten to spell out the
  macro's actual expansion and name the A/BC divergence.
- **faithdiff `DisplayTextBoxID`: `+ ADDED DisplayTextBoxID_ (call)`** — a **faithdiff blind spot**,
  not a divergence: pret's call lives inside the `homecall_sf` macro body, which faithdiff's pret
  parser does not expand, so it sees zero calls on the pret side. The port's single call is exactly
  the call the macro makes. Left unsuppressed (a global suppression would hide real macro-hidden
  drops elsewhere) and justified in the commit message instead.

### Row 1 — SANCTIONED deviations (tagged in `src/home/window.asm`)
- **DEVIATION(timing)** — pret's `.loop2` free-runs (`JoypadLowSensitivity` polls the hardware;
  `.loop1` ends in `Delay3`). The port has no busy-poll: the joypad is an ISR and
  `H_JOY_PRESSED` is edge-triggered per frame, so the loop is paced by one `DelayFrame` per
  iteration and `Delay3` is dropped — adding it would put 3 dead frames on every cursor move
  *on top of* the frame the port already spends, reintroducing the menu lethargy fixed in
  `JoypadLowSensitivity` (2026-07-04). `wMenuJoypadPollCount` is consequently counted in frames.
  *Justification is the input HAL, not "other screens do it this way".*
- **DEVIATION(timing)** — the blink counters are seeded `COUNT1 = ARROW_ON_FRAMES / COUNT2 = 1`
  (frame-paced) instead of pret's `0 / 6` (kHz-paced), **and only when the tile really is a ▼**.
  pret can seed `COUNT1 = 0` unconditionally because 0 doubles as
  `HandleDownArrowBlinkTiming`'s "no blink active" guard; in the port's frame-paced version a
  nonzero `COUNT1` on an arrow-less menu would eventually *draw* a spurious ▼. Guarding the arm
  reproduces pret's net behavior (blink where an arrow exists, inert where it doesn't) in frames.
- **DEVIATION(stride)** — `.downArrowTile` scales pret's `hlcoord 18, 11` by the runtime
  `text_row_stride` instead of the GB's fixed `SCREEN_WIDTH`, because the port's menu scratch
  tilemap has a runtime row stride (menu-loop scratch primitive; off-limits by the plan).
- **`menu_redraw_cb` / `menu_item_step`** (the `call eax` and the cursor step in
  `PlaceMenuCursor`) — pre-existing menu-loop scratch primitives, off-limits by the plan;
  `menu_item_step` stands in for pret's `hUILayoutFlags` `BIT_DOUBLE_SPACED_MENU` spacing toggle.

### Row 1 — allowlist challenge
- **`PrintText`** (`relocated_labels`) — challenged, and now **deleted outright**. It was never a
  relocation (see M-3); row 23 moved the real body to its mirrored path `src/home/window.asm`,
  so the entry has nothing left to excuse and the linter passes with it gone. The boilerplate
  *"pret home/window.asm split across port files (draft Session H)"* is gone with it.
- **`EnableAutoTextBoxDrawing` / `DisableAutoTextBoxDrawing` / `AutoTextBoxDrawingCommon`** —
  also `home/window.asm` labels, but their port file is `src/home/auto_textbox.asm`, which is
  **row 6's** scope and whose ledger line already reads *"allowlisted relocation ×3 —
  challenge"*. Deliberately left for that row rather than challenged twice.

### M-7. `DisplayChooseQuantityMenu` hung the game and never drew its own box **[FIXED — row 4]**
**File:** `dos_port/src/home/list_menu.asm` `.waitForKeyPressLoop`
**pret:** `home/list_menu.asm:.waitForKeyPressLoop` — `call JoypadLowSensitivity`, no `DelayFrame`.
**What was wrong:** pret's spin loop is correct *on the GB* for two hardware reasons: its
`JoypadLowSensitivity` opens with `call Joypad`, which reads the pad **hardware** directly, and
the LCD scans the tilemap **continuously**, so the box it just wrote is on screen without anyone
asking. In the port BOTH of those are frame-driven — `joypad_update` (which computes the
`hJoyHeld`/`hJoyPressed` edge that `JoypadLowSensitivity` reads) and the compositor's
render+present run **inside `DelayFrame` and nowhere else**. The port translated the loop
literally, so it span forever on a joypad state that could never change, never presenting the
box it had just mirrored: **the ×NN quantity selector froze the game with its own window
invisible.** Reachable live: `START → ITEM → TOSS` (`start_sub_menus.asm:529`) and all three
`players_pc.asm` deposit/withdraw/toss paths.
**Fix:** `call DelayFrame` in the wait loop — the same pump pret's own `HandleMenuInput_` loop
has and that the port mirrors in `home/window.asm`. This one input loop was the outlier that
leaned on the hardware. Tagged `DEVIATION(port-frame-pump)`.
**Observed:** the `DEBUG_LISTMENU=2 DEBUG_LISTMENU_QTY=1` headless run hung (killed at the 200 s
timeout, no `FRAME.BIN`) before the fix and exits cleanly with the box rendered after it. That
harness is new in this row, and it is what turned a code-reading hunch into evidence.
**Severity:** HIGH (game-freezing, on a live path)

### M-8. The priced quantity box is drawn 11 wide but its window only exposes 5 **[OPEN]**
**File:** `dos_port/src/home/list_menu.asm` `list_add_qty_window` / `DisplayChooseQuantityMenu`
**What's wrong:** `PRICEDITEMLISTMENU` widens the qty box to an 11-column interior (pret's mart
layout, box origin GB(7,9)), but `list_add_qty_window` registers the **quantity-only** projection
(`wx=287 clip=40` — 5 tiles wide, anchored for the GB(15,9) box). So the price at box-relative
(5,1) lands outside the window clip and cannot be seen. This is the already-known missing **mart
anchor** (`TODO(proj)` at the routine), surfacing as a concrete symptom.
**Consequence for row 4:** the priced coordinate fix below is verified only *in part* — the
`×01` cell at box-rel (1,1) renders correctly and is observed in `FRAME.BIN`; the price cell at
box-rel (5,1) is **UNVERIFIED IN PIXELS**, because no window currently exposes it. It is correct
by derivation from pret (see the commit message), not by observation. Stating that plainly rather
than claiming the fix works.
**Not fixable in row 4's scope alone:** it needs the mart projection decision, and the only
`PRICEDITEMLISTMENU` setter (`home/text_script.asm:DisplayPokemartDialogue`) still dead-ends in a
`home_stubs.asm` ret-stub, so nothing renders it live yet either.
**Severity:** low today (unreachable), blocking whenever the Pokémart lands.

### M-9. The ▷ swap-position counter was never seeded **[FIXED — row 4]**
**File:** `dos_port/src/home/list_menu.asm` `PrintListMenuEntries`
**pret:** `home/list_menu.asm:340-362` — `ld a,[wListScrollOffset] / ld c,a`, then `sla c` for item
lists; `c` stays in BC and the entry loop walks it as the 1-based ▷ swap-position counter.
**What was wrong:** pret uses **one** register for two jobs — the scroll term of the entry-address
math *and* the swap counter. The port did the address math in `ECX` and kept the counter in `BL`,
and **never seeded `BL` from it**. So the `cp c` swap compare ran against whatever happened to be
in BL, and the SELECT-swap ▷ marker landed on the wrong entry (or none) — always, not just when
scrolled.
**Fix:** `mov bl, cl` before the loop, with a comment naming the pret aliasing that made it easy
to drop.
**Not observable in the goldens:** the ▷ only draws when `wMenuItemToSwap != 0`, which no golden
scenario and no `DEBUG_*` harness sets, so all list renders are byte-identical before and after.
The fix is derived, not observed — flagged here rather than dressed up.
**Severity:** medium (visible mis-marking during a bag item swap)

### M-10. The two-option (YES/NO) menu was single-spaced, and the cursor pointed at the wrong option **[FIXED — row 5]**
**File:** `dos_port/src/home/yes_no.asm` `DisplayTwoOptionMenu`
**pret:** `engine/menus/text_box.asm:DisplayTwoOptionMenu` + `data/yes_no_menu_strings.asm`
**What was wrong — two bugs, compounding:**
1. **Spacing.** pret stores each menu's pair as ONE string joined by `next` ($4E), and
   `PlaceString`'s `<NEXT>` handler (`home/text.asm:63`) advances **`2 * SCREEN_WIDTH`** unless
   `hUILayoutFlags`' `BIT_SINGLE_SPACED_LINES` is set — and *nothing in the two-option path sets
   it* (the only setters are `save.asm`, `learn_move.asm`, `printer2.asm`, battle `core.asm`).
   Likewise `PlaceMenuCursor` steps `ld bc, 40` (two rows) unless `BIT_DOUBLE_SPACED_MENU` is
   SET — a constant whose name reads backwards. So the menu is **double-spaced**. The port put
   option B at `frow+1` and set `menu_item_step = 20`. The descriptor heights are the tell, and
   are otherwise inexplicable: a 2-item menu gets `int_h 3` (rows 1 and 3), or `int_h 4` with
   `blank` for HEAL_CANCEL (rows 2 and 4) — single-spaced, every box carries a stray empty row.
2. **Cursor row.** The routine juggled the first-option row through `push`/`pop` around both
   `place_flat_str` calls, and the final `pop` retrieved the value pushed *last* — the SECOND
   option's row — into `wTopMenuItemY`. Its comment said `; ECX = frow (first option row)`. It
   was not. **The ▶ was drawn one row below the first option**, i.e. next to NO while
   `wCurrentMenuItem` still said YES: the arrow pointed at the option A would *not* pick.
**Fix:** option B at `frow + 2`; `menu_item_step = 2 * 20`; and the row is now held in a named
slot (`yn_frow`) read three times instead of juggled on the stack, so it cannot drift again.
**Observed:** new `DEBUG_YESNO` harness (no golden covers this box). Before: `YES`/`NO` on
adjacent rows, ▶ next to `NO`, blank row at the bottom. After: `▶YES` / blank / `NO`, and the
HEAL_CANCEL variant renders blank / `▶HEAL` / blank / `CANCEL`. Both match pret's geometry.
**Severity:** HIGH (the cursor contradicted the selection on every YES/NO in the game)

### M-11. `wMenuWatchMovingOutOfBounds` was never cleared **[FIXED — row 5]**
**File:** `dos_port/src/home/yes_no.asm` `DisplayTwoOptionMenu`
**pret:** `engine/menus/text_box.asm` — `xor a / ld [wLastMenuItem], a / ld [wMenuWatchMovingOutOfBounds], a`
**What was wrong:** the port cleared `wLastMenuItem` but silently dropped the second store, so
the two-option menu ran with whatever the *previous* menu left in
`wMenuWatchMovingOutOfBounds` — and `DisplayListMenuID` sets it to 1. Bag TOSS goes
list → quantity → YES/NO, so the YES/NO inherited out-of-bounds movement watching.
**Fix:** store the 0, as pret does.
**Severity:** medium (latent; depends on the preceding menu)

### M-12. The post-text button-press flag is **write-only in the linked build** [OPEN — row 13/17]
**File:** flag `wDoNotWaitForButtonPressAfterDisplayingText` (set by `AutoTextBoxDrawingCommon`,
`src/home/window.asm`; also set by `pc.asm:202` and `players_pc.asm:260`)
**pret:** `DisplayTextID` reads it to decide whether to `HoldTextDisplayOpen` — i.e. whether the
text closes immediately or waits for A/B.
**What is wrong:** in the port the flag's **only reader is `src/home/text_script.asm:227`, and that
file is not linked** (it sits in a check-only Makefile list — same finding as T-1 in
`docs/plans/text_engine.md`, where its dead `TX_FAR` streams turned up). So every store to this
flag is inert: the two PC screens set it precisely to *skip* the post-text wait, and nothing acts
on it. The port's dialog wait is `npc_dialog_wait_impl` (bespoke), which never consults it.
**Not fixed here:** out of row 6's scope — the defect is in the consumer, not the setter. The
setter is faithful. Belongs to row 13 (`display_text_id_init.asm`) or whichever row links
`text_script.asm` / de-bespokes the dialog wait.
**Severity:** low-medium (a missing optimisation, not a corruption: text waits when it should
not have to). Worth confirming against pret whether any screen *depends* on not waiting.

**Row 6's own verdict:** the three routines were already instruction-for-instruction faithful.
The whole row was a **file-placement lie**, not a code bug: `auto_textbox.asm` existed only
because someone split 13 lines out of pret's `home/window.asm`, and 3 boilerplate allowlist
entries then blessed the split. There was no forcing reason — the port already mirrors
`home/window.asm`. The file is deleted, the routines moved to `src/home/window.asm` (pret's own
position for them, right after `HandleDownArrowBlinkTiming`), and all 3 allowlist entries are
**deleted, not re-justified**. `relocated` 390 → 387, `translated` 824 → 827.
Its header also claimed the pret source was `home/text.asm`. It is `home/window.asm`. Corrected.

### M-5 resolution (row 5): `TwoOptionMenu_SaveScreenTiles` / `_RestoreScreenTiles`
Filed at row 3 as "missing entirely". Verified at row 5: they are **absent by design, and now
documented at `yn_teardown`** rather than merely unnoticed. pret must snapshot the tilemap cells
its box overwrites and paste them back, because on the GB the box IS the tilemap; the port's box
is a window descriptor composited over an untouched background, so "restore" is dropping the
descriptor. Recorded as **SANCTIONED(window-compositor)**.
One consequence worth stating: pret's own comment under `DisplayTwoOptionMenu` admits the
save/restore is undersized ("the bottom and right edges of the menu may remain after the
function returns"). The port cannot reproduce that residue. This is **not** a silent fix of a
Gen-1 bug we were meant to preserve under `BUG_FIX_LEVEL` — the bug is a property of the
save/restore mechanism, and there is no save/restore to be buggy.

### M-13. START-menu SFX was silent behind a stale `TODO-HW` [FIXED — row 7]
`DisplayStartMenu` carried `; TODO-HW: PlaySound SFX_START_MENU — audio HAL (Phase 3)`.
Phase 3 landed: `PlaySound` is translated and linked (`src/home/audio.asm`, sound id in AL,
self-gated on `g_audio_engine_online`), `SFX_START_MENU equ 0x8F` exists in the generated
`assets/audio_constants.inc`, and `home/window.asm` already calls `PlaySound` the same way.
Nothing was blocking it — the comment simply outlived its own premise, and the START menu has
been opening in silence ever since. Wired (`mov al, SFX_START_MENU` / `call PlaySound`) and the
comment deleted. A sibling stale comment survives at `src/engine/menus/pokedex.asm:307`
("audio HAL stub (no-op)") — **not fixed here, out of scope; row 16 owns it.**

### M-14. `PrintSafariZoneSteps` was called nowhere, behind a false `STUB(safari)` [FIXED — row 7]
`RedisplayStartMenu_DoNotDrawStartMenu` said `; STUB(safari): farcall PrintSafariZoneSteps —
Safari Zone not yet ported`. Every clause of that is wrong. The routine has a **full, faithful,
linked body** (`src/engine/overworld/player_state.asm:348`; `player_state.asm` is in `GAME_SRCS`),
and it **self-guards on `wCurMap`** (`cmp al, SAFARI_ZONE_EAST / jb .ret`; `cmp al,
CERULEAN_CAVE_2F / jae .ret`) exactly as pret's does — so calling it outside the Safari Zone is
inert, which is precisely why pret can call it unconditionally on every START-menu redraw. It
was not a stub and needed no guard; the call was just missing. Wired.
This is the *third* instance of the class the loop's EPISTEMICS rule exists for: a comment
asserting a routine is unported while its real body sits linked in the build.

### M-15. `SaveScreenTilesToBuffer2`: the header generalized one deviation into two [FIXED — row 7]
The file header claimed pret's "SaveScreenTilesToBuffer2 screen save/restore is not needed: the
box is a non-destructive window overlay", and the call site was commented out on that basis.
The *restore* half is genuinely window-model — the port's sub-menus drop the START window and let
`RedisplayStartMenu` redraw instead of pasting back a tilemap snapshot (`start_sub_menus.asm`
comments this out in 6 places; SANCTIONED, and row 9's to own). But the **save** half is a pure
`wTileMap → wTileMapBackup2` WRAM copy (`movie/title.asm`, `pushad` / `rep movsb` / `popad`,
`SCREEN_AREA` = the port's full 40×25 canvas, into a correctly-sized 1000 B buffer) with no
compositor coupling whatsoever, and it is *already used in paired form* by `cut.asm` and
`title.asm`. Nothing forced it out. Restored.
Two things this exposed:
* It was **not exported.** `SaveScreenTilesToBuffer2` is defined file-locally in `title.asm`
  with no `global`; the only other callers are behind `%ifdef M72_OVERWORLD_TEXTSCRIPTS`
  (undefined) or in unlinked `cut.asm`, so nothing had ever link-referenced it and the missing
  export was invisible. Row 7 is its first linked caller — hence a one-line `global` added to
  `title.asm` (visibility only, zero behavior change; the only out-of-file edit in this commit).
* The save is currently **write-only** in the port, since no sub-menu restores from Buffer2. It
  is kept anyway: it is what pret does, it costs one 1000-byte copy per menu open, and removing
  it would silently break the first sub-menu that ever wants the buffer back.
* The routines themselves are **relocated** (pret `home/tilemap.asm` → port `movie/title.asm`).
  That relocation is out of scope here and is **not** in the menu ledger — filing it: it deserves
  the same allowlist challenge rows 1–6 got.

### Row 7 verification note (what the green suite does and does not prove)
`make fidelity` passes 6/6. That is real evidence for M-13 and M-14 — the `DEBUG_STARTMENU`
harness dumps *after* `RedisplayStartMenu_DoNotDrawStartMenu`, so both new calls execute in the
scenario and the tilemap/VRAM/OAM still come out byte-identical to the mGBA golden (i.e.
`PrintSafariZoneSteps` really is inert off-map, and `PlaySound` disturbs no rendered state).
It proves nothing about M-15: `SaveScreenTilesToBuffer2` sits in `.buttonPressed`, past the dump,
so the harness never reaches it — its safety rests on inspection (a register-preserving copy into
a dedicated buffer nothing else reads). And the SFX itself is **audible-only: UNVERIFIED** by any
harness; no golden or dump captures audio.

### M-16. The string generator encoded the *rendered* text, not pret's string [FIXED — row 8]
pret's `StartMenuPokemonText` is `db "#MON@"`. `#` is **charmap $54 — a text COMMAND**, expanded
to "POKé" at print time by `PlaceNextChar` (`home/text.asm`: `dict '#', PlacePOKe`), not four
literal glyphs. `tools/gen_menu_strings.py` had `("sm_str_pokemon", "POKéMON")` — it encoded what
the label *looks like* rather than what pret *writes*, emitting 7 literal tiles
(`8F 8E 8A BA 8C 8E 8D`) where pret emits 4 bytes (`54 8C 8E 8D`).
The screen output is identical, which is exactly why nobody caught it. What it actually did was
**silently route around the $54 handler the port already implements** (`src/home/text.asm:926
.handle_poke` → `str_poke` = `8F 8E 8A BA`), leaving that path untested by the one screen that
should exercise it. It also broke the Tier-1 premise that a generated `.inc` is a deterministic
function of the pret source — a generator that paraphrases its input is not regenerable from it.
Fixed at the generator (per the user's standing instruction: *patch the applicable generator*).
`LABELS` now carries **pret's `db` string verbatim** plus the pret label name for cross-reference;
`gb_text.encode('#MON')` → `54 8C 8E 8D`, so all 7 labels are now byte-identical to pret's data.
Verified: `goldencheck SCENARIO=start_menu` compares the menu-box tilemap cells against mGBA
(the only tilemap mask is rows 15–17, pure backdrop) and passes — the $54 expansion renders the
same 7 tiles the literal did.
**Worth a sweep beyond this row:** every other string generator is suspect for the same class of
paraphrase. `#` ($54), `<PKMN>` ($4A), `<PLAYER>` ($52), `<RIVAL>` ($53), `<TARGET>`/`<USER>` are
all text commands that a generator can "helpfully" pre-expand. Filed for rows 11/14/16 and for
the dialog generator.

### M-17. `StartMenuShowWindow`: exported to nobody, with a comment naming a caller that never existed [FIXED — row 8]
`global StartMenuShowWindow ; home/start_menu.asm re-arms it after sub-menus`. There is no such
caller — not in `home/start_menu.asm` (read in full for row 7), not anywhere in `src/`. The
routine's only entry is `DrawStartMenu`'s tail `jmp`, and it is correct that way: a sub-menu
returns via `RedisplayStartMenu` → `DrawStartMenu`, which re-arms the window on its way out. The
`global` is dead and the comment describes a design that was never built. Both removed; the
mechanism is now stated as it actually works. (`sm_canvas_mirror`'s export IS real — but it is the
`%ifdef DEBUG_STARTMENU` harness that uses it, not the live menu, which reaches it through
`menu_redraw_cb`. Comment corrected to say so.)
Also rewrote the file's garbled `UI_LAYOUT_EQUATES_ONLY` header note, which argued itself into a
"which would collide … we therefore re-derive nothing" knot. The guard is real, generated by
`gen_ui_layout.py`, and used by 8 other files; it exists to avoid a duplicate *table*, not a
collision.

### M-18. `update_label_db` was blind to `equ` aliases → 7 present labels reported `missing` [FIXED — row 8]
The 7 `StartMenu*Text` labels all reported `missing` in `translation.db`. They are not missing:
`draw_start_menu.asm` keeps the pret names as `equ` aliases onto the generated `sm_str_*` labels
(`StartMenuPokemonText equ sm_str_pokemon`) — which is precisely what CLAUDE.md's "preserve pret
labels" rule asks for when a generator owns the bytes. But the scanner's port-definition regex is
`^Name:`, so an alias was invisible and the label fell through to `missing`.
This matters beyond cosmetics: **the label DB is the evidence this audit runs on** (loop step 2 —
"a label pret has that the port simply lacks is a finding"). A blind spot that reports present
labels as absent manufactures false findings, and worse, would hide a genuinely absent string
label in the noise of the 7 false ones.
Patched `tools/update_label_db`: `EQU_ALIAS_RE` registers `Name equ Symbol` as a port definition
(symbol aliases only — `FOO equ 12` is a constant, not a definition), with null body metrics like
the include-defined-global path, and without touching the `cur` routine cursor (an `equ` is
standalone; the lines after it belong to whatever routine preceded it). Blast radius measured
first and it is exactly these 7: they are the only pret-named `equ` aliases in the tree.
`missing` 2123 → 2116, `translated` 827 → 834; `lint_pret_labels` still exits 0.

### M-19. Swapping party mons left BOTH mons' icons on screen [FIXED — row 9 part 1]
`SwitchPartyMon_ClearGfx` blanked the mon's two BG rows and stopped there. pret also parks that
mon's **4 OAM icon entries** offscreen. The port skipped it under a `DEVIATION(icons)` comment:
*"the port's BG icons live in the rows just cleared and RedrawPartyMenu_ re-places them."*
That was true once. It stopped being true when the party icons became **OBJ**
(`engine/gfx/mon_icons.asm`, `docs/plans/party_icons_oam.md`): blanking BG rows no longer touches
them, so both swapped mons' icons stayed painted over two blank rows. A stale comment outlived
the architecture it described — and nobody re-read it when the architecture changed.
Two things had to be got right to fix it, neither of which is a verbatim translation:
* **The park constant is a projection.** pret parks at `SCREEN_HEIGHT_PX + OAM_Y_OFS` — "one
  screen-height down", offscreen on a **144px** GB screen. The port's screen is `RENDER_H` = 200
  and the party panel's origin is canvas y=0 (`UI_PARTY_PANEL_WY`), so pret's constant would put
  the icon at canvas y=144 — **visibly relocated, not hidden**. The port needs the same idea at
  its own screen height: `OBJ_PARK_Y = RENDER_H + OAM_Y_OFS` → `spr_dos_sy` = 200, and
  `render_sprites` culls at `cmp sy, RENDER_H / jge` (ppu.asm:847). Exactly on the boundary.
* **A park that is never published does nothing.** The compositor does not read shadow OAM's Y —
  `render_sprites` draws at `spr_dos_sx/sy`, which only `CommitMonPartySpriteOAM` publishes (the
  standing invariant from `flatcanvas-sprite-suppression`). Same for the blanked BG rows, which
  reach the panel window only via `PartyMenuMirror`. Both are now called, so the cleared state is
  actually on screen during the sound spin below — the frame window pret shows it in.

### M-20. The swap SFX was missing behind another stale `TODO-HW` [FIXED — row 9 part 1]
`; call WaitForSoundToFinish / ld a,SFX_SWAP / jp PlaySound — TODO-HW: audio HAL (Phase 3)`.
Phase 3 landed: `WaitForSoundToFinish` is live in `home/audio.asm` (and it *pumps DelayFrame*, so
it really does spin visible frames), `PlaySound` is live, `SFX_SWAP equ 0xAE` is in the generated
audio constants. This is the **third** stale `TODO-HW: audio` found in three rows (M-13, and the
pokédex one filed at row 16) — the audio destub swept the engine in but never revisited the call
sites that had been commented out while waiting for it. **Worth a tree-wide sweep**: grep
`TODO-HW.*audio` and check each against `label_status PlaySound`.
The two findings are coupled, which is why they land together: with no `WaitForSoundToFinish`
there was no frame in which the cleared state was ever displayed, so the missing OAM park (M-19)
had nothing to be visible *during*. Wiring the sound is what exposes the ghost icons.

### M-21. "None of the field effects are ported yet" — false, and never checked [comment FIXED, dispatch scoped — row 9 part 1]
The field-move branch of `StartMenu_Pokemon` is stubbed (`jmp .loop`), which is fine as a
deferral — pret's own refusal paths do exactly that, so nothing misbehaves; the move just does
nothing. What is not fine is the stated reason: *"None of the field effects (UsedCut,
ChooseFlyDestination, UseItem, PrintStrengthText, …) are ported yet."* `UseItem` is called by this
very file, twenty lines away. Actual status (`tools/label_status`):
* `UsedCut`, `IsSurfingAllowed`, `PrintStrengthText` — **translated**, but in **check-only** files
  (`cut.asm`, `field_move_messages.asm`; Makefile `HOME_CHECK_SRCS`). They exist and do not link.
* `CloseTextDisplay` — translated, also check-only (`text_script.asm`, established at row 7).
  Every `.goBackToMap` path needs it, so it gates cut/surf/strength/flash/dig/teleport/fly alike.
* `ChooseFlyDestination` — genuinely `missing`. FLY's happy path only.
* `UseItem`, `Divide`, `AddNTimes`, `PrintText`, `GetPartyMonName`, `DelayFrames`, `Func_1510`,
  `CheckIfInOutsideMap` — linked and callable **today**.
So the real blocker is **linkage, not translation** — and **SOFTBOILED** (Divide + `UseItem` POTION
+ PrintText) plus the `.newBadgeRequired` / `.notHealthyEnough` refusals need nothing that is
missing at all; they are blocked only by their text streams. Comment corrected to say all of this.
The dispatch is now scoped as **row 9 part 3** (badge gate + jump table + 5 generated text streams
+ a decision on linking `cut.asm` / `field_move_messages.asm` / `text_script.asm` and paying their
closure). It is deferred because it is a real implementation task, not because "it isn't ported".

### Row 9 part 1 verification note
**VERIFIED LIVE 2026-07-13** (user-driven swap under DOSBox-X, `SKIP_TITLE=1 DEBUG_SEED_PARTY=1`:
START → #MON → SELECT ×2 — icons park, rows blank, SFX plays; "lgtm"). Recorded because what
follows was written *before* that run and is the reason the fix was trusted enough to commit —
keep it, it is the analytic basis, not a substitute for the observation.
`make fidelity` 6/6 — but that is a **regression check only**: no golden navigates a party swap,
so `SwitchPartyMon_ClearGfx` is **not executed by any scenario**, and it was **unverified by the
suite** at commit time. Its basis was a read of the primitives it depends on, each confirmed in
source rather than assumed: the cull is `cmp spr_sy, RENDER_H / jge .nextSprite` (`ppu.asm:847`); the park lands
at exactly `spr_dos_sy = RENDER_H` given `mps_org_y = UI_PARTY_PANEL_WY = 0`; `sprite_shift_y` is
zeroed on every flat-canvas screen (`ppu.asm:421`, the `.not_overworld` path the party menu takes),
so nothing shifts it back on screen; and `CommitMonPartySpriteOAM` is what turns shadow OAM into
the `spr_dos_*` the compositor reads. The live run confirmed all of it, but by hand — the path is still **not covered by any
automated harness**, so a future regression here would be silent. The `DEBUG_PARTYSWAP` harness
(seed party → `RedrawPartyMenu_` → `SwitchPartyMon_ClearGfx` → `DumpGBState`) is still worth
building when **row 11** opens `party_menu.asm`, which is where the hook has to live.
The SFX was **heard** in the live run; it remains uncovered by any automated check (no harness
captures audio).

### M-22. A private `ret`-only `RunDefaultPaletteCommand` SHADOWED the real body [FIXED — row 9 part 2]
`start_sub_menus.asm` defined its own file-local `RunDefaultPaletteCommand: ret`, commented
*"kept file-local … so StartMenu_TrainerInfo/StartMenu_Pokedex control flow links."* It links
fine without it: the **real body is `global` in `naming_screen.asm`** and does what pret does
(`ld b, SET_PAL_DEFAULT` → fall into `RunPaletteCommand`). The private copy silently ate the
`SET_PAL_DEFAULT` argument for every caller in this file.
This is the **stub-shadowing-a-real-body class the conventions exist to catch**, and it is
invisible today only because `RunPaletteCommand` is itself a Phase-5 `ret`-stub — so the bug is
*latent*: the day the palette engine lands, the trainer card and the bag would be the two screens
that don't restore the default palette, for no discoverable reason. Nobody would look here.
Now externed. **`pokedex.asm` carries a THIRD private copy** — same bug, another row's file, filed
here. The right end state is one definition; a `ret`-only stand-in belongs in a `*_stubs.asm`, not
copy-pasted per screen. Worth a tree-wide sweep for other pret labels defined file-locally more
than once (`grep -rn '^<PretLabel>:' src/` for anything the DB calls `relocated`).

### M-23. `StartMenu_Item.exitMenu` dropped two calls the window model does not excuse [FIXED — row 9 part 2]
pret's exit is `LoadScreenTilesFromBuffer2` / `LoadTextBoxTilePatterns` / `UpdateSprites`. The port
dropped **all three** under one comment: *"the START menu redraw rebuilds the window list and box;
no separate restore needed in the window model."* That sentence is true of the first call and of
nothing else — the same over-generalisation as row 7's (one real deviation stretched to cover its
innocent neighbours).
`LoadTextBoxTilePatterns` reloads **VRAM tile patterns**, not a tilemap. A USE that opens the party
menu overwrites the box tiles with the HP-bar set (`$62-$7F`) — *this file's own*
`StartMenu_Pokemon.exitMenu` comment says exactly that, eighty lines up — so leaving the bag
afterwards drew the START box out of HP-bar patterns, and the compositor **caches** decoded tiles,
so it sticks until something else arms `g_tilecache_dirty`. `RedisplayStartMenu` does not reload
them. And `StartMenu_Option`, in this same file, kept both calls — the drop was not a decision,
it was an oversight wearing a decision's comment.

### M-24. `ItemMenuLoop` dropped `hAutoBGTransferEnabled = 0` with the buffer restore [FIXED — row 9 part 2]
`LoadScreenTilesFromBuffer2DisableBGTransfer` (`missing` in the port) does two things: it zeroes
`hAutoBGTransferEnabled`, and it copies `wTileMapBackup2 → wTileMap`. Only the second is
window-model. The port dropped both and said "subsumed by DisplayListMenuID's full redraw".
`DisplayListMenuID` does happen to clear the byte itself (`list_menu.asm:194`) — but that is the
callee's business, not a licence for the caller to skip pret's write, and **the leak of exactly
this byte is a known regression class here** (OW-A.13, which `DEBUG_STARTMENU` still exists to
repro). The store is back, inline, with the buffer half tagged as the deviation it actually is.

### M-25. The two refusal messages were tagged `STUB(text)` — nothing was blocking them [FIXED — row 9 part 2]
`CannotUseItemsHereText` (bag inside a Cable Club) and `CannotGetOffHereText` (BICYCLE while
`BIT_ALWAYS_ON_BIKE`) were both `missing`, each behind a comment blaming an unported *feature*:
*"link play not ported"*, *"bike riding not ported"*. But the **guard branches were kept** — so the
port took the refusal path and displayed nothing, which is not a stub, it is a silently wrong
screen. And nothing about the message was blocked: the text engine takes a flat stream, `PrintText`
links, and `gen_battle_text.collect_far` flattens both bodies straight out of pret's
`data/text/text_8.asm`.
Fixed as **Tier-1 data + Tier-2 wrapper**, per the two-tier rule: `tools/gen_menu_strings.py` grew
a FAR-stream group emitting `assets/menu_text.inc` (the generator patch the standing instruction
calls for — it previously handled only bare glyph runs, which is why nobody could add a *message*
to it), and the `text_far` / `text_end` wrappers live in the `.asm` under pret's own label names,
as pret writes them. Both labels are now `translated`; `TrainerInfo_FarCopyData` is the file's only
remaining `missing` label and it belongs to **row 10** (`trainer_card.asm`).

### M-26. `StartMenu_SaveReset` dropped the RESET branch, and returned to the wrong screen [FIXED — row 9 part 2]
Two bugs in five lines.
* pret gates on `BIT_LINK_CONNECTED` and **soft-resets** (`jp Init`) instead of saving. The port
  omitted it as *"link-play (S8) … the guard would never take"* — but **`DrawStartMenu` reads that
  same bit to label the item RESET instead of SAVE** (row 8's file). So the port would draw
  "RESET" and then save the game: one feature, implemented in one half and denied in the other.
  `Init` is translated and linked; the branch is three instructions. Restored.
* pret's tail is `jp HoldTextDisplayOpen` → falls into `CloseTextDisplay`, which **closes the menu
  and returns to the map** — saving puts you back in the overworld. The port did
  `jmp RedisplayStartMenu` and left the START menu open. That is simply the wrong screen, and it
  was not tagged as a deviation at all. Both pret routines are translated but sit in **check-only**
  `text_script.asm` (the row-9 part-3 linkage item); `CloseStartMenu` is the port's already-
  sanctioned fold of exactly that pair (release-spin → folded `CloseTextDisplay`) and is what the
  bag's own `.useItem_closeMenu` already tail-jumps. Now used here too, and tagged.

### Row 9 part 2 — audited-and-faithful (recorded so the next reader need not redo it)
* `.choseItem`'s cursor blanks. pret `ldcoord_a 5,4 / 5,6 / 5,8 / 5,10`; the port writes
  `W_TILEMAP + {2,4,6,8}*20 + 1`. **Correct**: the port's list menu draws box-relative into the
  stride-20 scratch, and `home/list_menu.asm` independently derives the same origin
  (`LIST_CURSOR_COL = 1`, `LIST_NAME_ROW0 = 2`, `LIST_ROW_STEP = 2`, with the comments
  `pret hlcoord 5,4 → box-rel (1,2)`). The two projections agree.
* `StartMenu_Pokedex` / `StartMenu_Option` / `StartMenu_TrainerInfo`: faithful. Each drops only
  `LoadScreenTilesFromBuffer2` (window model) — `StartMenu_TrainerInfo` adds the
  `trainer_card_present`/`_teardown` window bridge, which is the same deviation in mirror form.

### Row 9 part 2 verification note
`make fidelity` 6/6 (regression only). What each fix is actually backed by:
* **M-23 / M-24 / M-26** are restorations of calls/stores pret makes — the argument is pret's
  source plus the port's own linkage, and the golden suite confirms nothing regressed. The
  *symptom* M-23 describes (START box drawn from HP-bar tiles after a party-menu item USE) is
  **not covered by any golden** — no scenario uses an item — so the fix is reasoned, not observed.
* **M-25's two messages are UNREACHABLE in the port today**, which is why no harness can show them:
  one needs a Cable Club (link play is not ported at all), the other needs `BIT_ALWAYS_ON_BIKE`
  (forced-bike, Cycling Road). What *is* verified is that the streams are byte-identical to pret's
  `data/text/text_8.asm` (same `collect_far` that produces the battle text), and that the
  `text_far` wrapper + `PrintText` + `msgbox_dialog` shape is the one the **linked** battle text
  uses on screen every level-up — `TX_FAR` is handled in `home/text.asm`'s TextCommandProcessor.
* **faithdiff blind spot, worth knowing:** it reports `- DROPPED Init (jp)` for `StartMenu_SaveReset`
  even though the branch is there — its port matcher only accepts `call`/`jmp`, never `jnz`/`jz`.
  Confirmed present by disassembling `PKMN.EXE`: `test $0x40,%al / jne <Init>`. Do not "fix" it.

### M-27. The field-move dispatch: implemented. The blocker was LINKAGE, and it was one symbol [FIXED — row 9 part 3]
Row 9 part 1 established that "none of the field effects are ported yet" was false (M-21). Part 3
acts on it. `.choseOutOfBattleMove` is now pret's real dispatch — `GetPartyMonName`, the
`wFieldMoves[wCurrentMenuItem]` index, the pointer table, `wObtainedBadges` in AL, and all nine
leaves with their badge gates and refusal messages. What each leaf does *today*:

| leaf | state | why |
|---|---|---|
| **STRENGTH** | **works** | needed `field_move_messages.asm` linked (below) |
| **SURF** | badge gate + `IsSurfingAllowed` run; the surfboard itself is inert | `ItemUseSurfboard` is a `ret`-stub (`item_use_stubs.asm`), so `UseItem` returns 0 and control takes **pret's own refusal path** (`.reloadNormalSprite`). Correct shape, no surfing. |
| **DIG** | **works** | `ItemUseEscapeRope` is translated and linked |
| **SOFTBOILED** | **works** | `Divide` + the maxHP/5 borrow-chain compare + `ItemUseMedicine` (POTION) |
| **FLASH** | **works** | `wMapPalOffset = 0`, message, `.goBackToMap` |
| **TELEPORT** | **works** | both messages, `BIT_FLY_WARP`/`BIT_ESCAPE_WARP`, `Func_1510`, `DelayFrames` |
| **FLY** | badge gate + the indoor "can't fly here" refusal work; the destination does not | `ChooseFlyDestination` is the ONE genuinely `missing` routine in the whole dispatch (the Town Map fly-target UI). Tagged `STUB(fly-destination)`. |
| **CUT** | badge gate works; the cut does not | `UsedCut` is **translated** — `cut.asm` just doesn't link (`WriteOAMBlock` in check-only `home/oam.asm`, plus `AnimCut`→`cut2.asm`→the unported `AdjustOAMBlock*Pos` battle-anim primitives). A linkage/OAM-primitive gap, not an unported effect. Tagged `STUB(cut-animation)`. |
| **all badge-gated leaves** | **refuse correctly** | `.newBadgeRequired` prints the real message |

**`field_move_messages.asm` is now LINKED.** The Makefile said its blocker was `PlayCry`, "unported
cry synth" — and that was *true*, but it was one symbol gating two field moves. `PlayCry` is now a
documented `ret`-stub in `home_stubs.asm` (its only live caller is the `text_asm` hook inside
`UsedStrengthText`, which does `call PlayCry / call Delay3 / jmp TextScriptEnd` — so the stub costs
the cry and nothing else: the STRENGTH message still prints and still holds). That is the whole
price of STRENGTH + SURF. **The lesson generalises**: the check-only list is not a list of unported
files, it is a list of files with an unresolved symbol, and the symbol is sometimes this cheap.
Re-read those Makefile notes — several predate the audio destub, as M-20 already showed.
Six more FAR streams generated (`gen_menu_strings.py` MENU_FAR → `assets/menu_text.inc`).

**Still deferred, and now precisely:** `CloseTextDisplay` / `HoldTextDisplayOpen` (check-only
`text_script.asm`, a 15-symbol closure incl. `Joypad` and eight `DisplayTextID` special cases —
owned by the script-engine session, correctly out of scope here). `.goBackToMap` uses
`CloseStartMenu`, the port's already-sanctioned fold of `CloseTextDisplay`, as M-26 does.

### Row 9 part 3 verification note
`make fidelity` 6/6 (regression only — no golden opens the field-move menu). `faithdiff
StartMenu_Pokemon`: 24 of 31 pret calls matched, up from 17. The seven unmatched are each
accounted for: `ChooseFlyDestination` + `LoadFontTilePatterns` (the FLY tail — `STUB`), `UsedCut`
(`STUB`), `Save`/`LoadScreenTilesFromBuffer1` (window model → `fm_show_window`/`fm_drop_window`),
`CloseTextDisplay` (→ `CloseStartMenu`), and **`hl (jp)`, a false positive**: that is pret's
`jp hl` indirect dispatch, which the port does as `jmp [.outOfBattleMovePointers + ecx*4]` —
faithdiff cannot see through an indirect jump, exactly as it cannot see `jnz Init` (M-26).
**LIVE-TESTABLE, unlike parts 1 and 2's fixes.** `DEBUG_SEED_PARTY` seeds a Snorlax that knows
FLY/CUT/SURF/STRENGTH *and* seeds `wObtainedBadges` = all badges but EARTH (`debug_party.asm:90`),
so every badge gate passes. **STRENGTH is reachable in four keypresses** and exercises the whole
new path end to end: dispatch → badge gate → `PrintStrengthText` (the newly-linked file) →
`GBPalWhiteOutWithDelay3` → `.goBackToMap` → back to the overworld.

**RUN 2026-07-13 (user).** The *menu* half passed on the first try — dispatch, badge gate and
leaf selection are correct ("looks good on the menu end"). The *exit* half did not, twice, and
the two failures are recorded as M-28 (fixed) and M-29 (open, deferred out of this row). The
dispatch itself has not needed a change since it was written.

### M-28. `.goBackToMap` never tore down the party menu's compositor state — the map came back BLANK [FIXED — row 9 part 3 follow-up, `04c8c96f`]
**Found live, not by the gate** (no golden opens the field-move menu; 6/6 passed throughout).

`DisplayPartyMenu` raises **`g_bg_whiteout`** (`party_menu.asm:417`), the port-only compositor
flag meaning "this screen is a full takeover — do not draw the BG at all", and installs its own
window list. `.goBackToMap` cleared none of it, so STRENGTH/FLASH/DIG/TELEPORT/successful-SURF
all returned to the overworld with the **BG layer suppressed**: a blank screen. Its sibling exit
`.exitMenu` — the CANCEL path ten lines above — has always done this teardown
(`g_window_count`/`g_bg_whiteout`/`g_obj_over_window` = 0 + `LoadTilesetTilePatternData`, the
party menu's HP-bar patterns occupying the BG tileset slots). Both are party-menu exits; only one
knew it. `.goBackToMap` now does the same, then `LoadGBPal`.

pret needs none of this: its party screen is just tiles, and `CloseTextDisplay`'s
`LoadCurrentMapView` paints the map back over them. Tagged `DEVIATION(port-window-model)`.

**A wrong first diagnosis, recorded because the failure mode is instructive.** The first fix was
`LoadGBPal` alone — reasoning that `GBPalWhiteOutWithDelay3` zeroes BGP/OBP0/OBP1 and pret
un-whites inside `CloseTextDisplay`, which the `CloseStartMenu` fold omits. That is *true*, and
the `LoadGBPal` is genuinely required — but it is not sufficient, and it did nothing visible,
because **no palette value can fix a layer that is never composited**. "White screen" has (at
least) two mechanisms in this port; matching the first one that fits and shipping it cost a live
round-trip. Check `g_bg_whiteout` before the palette next time.

### M-29. `GB_TILEMAP1` rows 0-5 are a SHARED staging buffer — the party panel and the dialog box collide there [OPEN — not this row's file]
**Superseded my first write-up, which was wrong** (kept below, struck, because the way it was
wrong is the point). Corrected by the user's observation: *"The party panel is being moved about.
The textbox itself seems to be in the right place."*

The dialog window is **correctly placed**. `msgbox_dialog` sources its box from `GB_TILEMAP1`
**rows 0-5**, and `PartyMenuMirror` (`party_menu.asm:443`) mirrors the party panel into
`GB_TILEMAP1` **rows 0-17** — the same rows. Two different screens stage into one region. So when
`PrintText` opens the dialog window over the party menu, that window faithfully shows whatever is
in its source rows: **the party panel**, re-framed at the dialog's position. Names, levels and HP
bars travel together because they are literally those tilemap rows; the mon icons stay put because
OBJ are OAM entries positioned from `spr_dos_sx/sy`, a different layer the window cannot move.
That asymmetry is the tell, and it is only explicable as a staging collision.

It is a **buffer-ownership bug, not a placement bug** — the fix is to stop the two screens sharing
rows 0-5 (a dedicated staging region for the dialog, or a party-screen projection that stages
elsewhere), NOT to retune coordinates. `set_single_window` also collapses `g_window_count` 2 → 1
(measured), which is a second, separable defect on the same path.

~~*Original (wrong) diagnosis: "the box lands at the overworld's placement (wx=87, wy=152) and the
two pages overlay in an uncleared box." The box placement is fine, and the page overlay was not an
uncleared box at all — it was M-31.*~~

### M-31. `TX_START_ASM` was skipped, not dispatched — the hook's terminator went with it [FIXED — `92c2e726`]
`TextCommandProcessor` sent `TX_START_ASM` ($08) to `.cmd_skip0` under the comment *"can't
translate inline ASM; skip silently"*. Both halves false. pret's handler is four instructions
(`pop hl / ld de, NextTextCommand / push de / jp hl`), and the flat port makes it **easier**: the
stream and the code share one address space, so `jp hl` is `jmp esi`. The landing pad already
existed and was faithful — `TextScriptEnd` is `mov esi, TextScriptEndingText / ret`, returning onto
a lone `$50`. Only the dispatch was missing.

Skipping was not harmless. `text_asm` splices **real x86 instructions into the stream**, and the
hook ends with `jmp TextScriptEnd` — *that* `jmp` is what **terminates the message**. Skipping the
command byte does not skip the hook: it feeds the hook's opcode bytes to the renderer as glyphs
**and swallows the terminator**, so the processor runs off the end of the message into the bytes
that follow. STRENGTH's *"SNORLAX used / move boulders."* was never two pages overlaid — it was
**one page that never ended**, running into the next message in the file.

**Latent because it had no caller.** `field_move_messages.asm:79` is the **only live `text_asm`
invocation in the entire port** (every other occurrence is a comment). Linking that file in row 9
part 3 walked the port's first-ever inline-ASM hook into an engine that had never dispatched one.

**Method note, and the reason this row cost three live round-trips.** Two diagnoses were made by
reading and both were wrong (M-28's palette-only fix; M-29's "uncleared box"). The one that was
right came from **measurement**: dosbox-mcp read `g_bg_whiteout = 1` at `PrintStrengthText` —
proving the box-mirror path being blamed was gated *off* and could not have drawn the text — and a
breakpoint on `PlayCry`, the hook's first instruction, **never fired**. Prefer the debugger to a
plausible story.

### M-32. `PlayCry`/`GetCryData`: a ret-stub whose stale reason hides a real, blocking contract [OPEN — audio subsystem]
pret's `PlayCry` (`home/pokemon.asm`) ends in **`WaitForSoundToFinish`** — it **blocks** for the
duration of the cry, and that block is what holds *"<MON> used STRENGTH."* on screen. The port's
ret-only stub (`home/home_stubs.asm`) keeps the label but drops the caller's real contract, which
is its *duration*: message 1 now flashes past in `Delay3`'s 3 frames and message 2 paints over it.
A stub that is "ret-only" per the convention can still be wrong when the contract callers rely on
is **how long it takes**.

**Cries are TWO ret-stubs away, not an audio project.** I got this wrong twice in opposite
directions in one turn — first claiming the primitives were all present (from a symbol-name grep,
without reading the body: `GetCryData` is a `ret`), then accepting "it's an audio-driver design
question" without checking. Then I checked. The engine side is **done**:

| piece | status |
|---|---|
| `CryData` (3B/species: cry id, pitch mod, tempo mod) | **exists**, generated + exported (`assets/cry_data.inc`, `global CryData`) |
| cry support in the engine | **exists** — `engine_1.asm` has `Audio1_IsCry`, `CRY_SFX_START/END`, and consumes `wFrequencyModifier` (:881) / `wTempoModifier` (:857) |
| `PlaySound` | **real** (gated on `g_audio_engine_online`, which `audio_init` sets — music plays) |
| `WaitForSoundToFinish` | **real** — spins on `wChannelSoundIDs` CHAN5/6/8 |
| `GetCryData` | **ret-stub** — pret `home/pokemon.asm:157`, ~15 instructions |
| `PlayCry` | **ret-stub** — pret `home/pokemon.asm:140`, 14 instructions |

Two direct translations, no design work. Genuinely unknown (and worth saying so): whether the
OPL/MT-32 shims render a cry acceptably once handed one — tuning, not a blocker.

**Both stubs lie about why they exist**, and both comments are now fixed:
- `GetCryData` claimed *"No audio HAL in this port (Phase 3)"* — false since the audio phases
  merged (2026-07-07), and it also cited the wrong pret file (`home/audio.asm`), which is what made
  it read as an audio-subsystem deferral instead of the plain home-routine translation it is.
- `PlayCry` claimed a bare `ret` *"costs the cry and nothing else"* — false, see the contract above.

**Convention violation to fix while destubbing:** `GetCryData`'s ret-stub sits in
`engine/menus/pokedex.asm`, a source-mirror file, not a `*_stubs.asm`.

### M-29 (superseded heading — original text follows for the record)
STRENGTH's two messages render wrong, and the cause is one layer below this file. `PrintText`
places its box through the projection record in **`text_msgbox`**, and `PrintStrengthText`
(`engine/overworld/field_move_messages.asm`) points it at **`msgbox_dialog`** — which, per its own
definition (`home/text.asm:1373`), is the *overworld* dialog and **collapses the window list**. So
the party panel is torn down mid-message and replaced by a box at the overworld's placement
(wx=87, wy=152). Live symptoms, all one root: the mon names half-slide off screen, the OBJ icons
stay, and the two pages **overlay** in an uncleared box — page 1 (`" used" / <LINE> "STRENGTH."`,
ending `text_end`, no prompt) is still on line 1 while page 2 (`" can" / <LINE> "move boulders."`,
`prompt`) types over line 2: *"SNORLAX used / move boulders."* with `AX` left from the longer name.

The existing escape hatch does not fit: **`msgbox_centered`** (`engine/battle/core.asm:610`) is the
*battle* dialog — battle coordinates and `BattlePromptWait`. It is merely the only projection that
happens not to collapse the window list, which is why `learn_move`/`evolution` borrow it.

**There is no projection for "a message box over a full-screen menu."** One must be authored
(`msgbox_party`: the party screen's box coords + a `; PROJ` entry in `docs/ui_projection.md`,
window fields zeroed so the caller's list survives), and the box-not-cleared behaviour re-checked
against it — the uncleared interior may be a second bug hiding behind the first, and should be
confirmed under dosbox-mcp rather than assumed. Owner: the party-menu/text row, not row 9.
**Until then STRENGTH's message is cosmetically wrong; its dispatch, gating and map-exit are correct.**

### M-30. `RestoreScreenTilesAndReloadTilePatterns`'s header comment is false
`home/fade.asm:176` claims it "reasserts the default palette". It does not — its
`RunDefaultPaletteCommand` call is commented out with a TODO claiming the routine is "not yet a
linkable global", which is the same false claim M-22 already disproved (it *is* global, in
`naming_screen.asm`). Trusting this comment is part of what sent M-28's first diagnosis wrong.
Out-of-file (`home/fade.asm`); fix the comment and the dead TODO when that file is touched.

### M-33. The ○ tile was an INVENTED load — pret gets it by running off the end of `BlankLeaderNames` [FIXED — row 10]
`DrawTrainerInfo` copies `ld bc, $17 tiles` (23) from `BlankLeaderNames` to vChars2 `$60`. The asset
`gfx/trainer_card/blank_leader_names.2bpp` is **352 bytes = 22 tiles**. The 23rd tile pret reads is
whatever follows the label — and `gfx/trainer_card.asm` puts **`CircleTile`** there, one tile,
immediately after. So the ○ lands at vChars2 `$60 + 22 = $76`: exactly the tile id
`TrainerInfo_BadgesText` (`db $76,"BADGES",$76,"@"`) prints. `CircleTile` has **no load of its own and
no referencer anywhere in the pret tree** — grep it. The adjacency *is* the load.

The port didn't see this. It copied 22 tiles and then wrote `tc_circle_tile` to `$76` in a load of its
own — same pixels on screen, but a VRAM write with no pret counterpart, and (worse) `gen_trainer_card_
tiles.py`'s docstring **asserted** the invented structure as fact: `CircleTile → vChars2 tile $76`
listed as one of pret's loads. The comment I first wrote on it was wrong in a third way, hypothesising
the ○ was "already resident from the text-box tile patterns". Nobody had read pret's byte counts.

FIXED: the generator emits `tc_blank_name_tiles` and `tc_circle_tile` **contiguously** (with a comment
forbidding anything between), exports `TC_BLANK_NAME_COPY_COUNT = 23`, and **fails loudly** if the two
assets ever stop summing to pret's `$17`. `DrawTrainerInfo` now makes pret's single copy and the extra
write is gone. Verified live: `$76` is written *only* by the rider copy, and both ○ still render.

### M-34. `TrainerInfo_FarCopyData` was `missing`; its five loads were hand-rolled `rep movsd` [FIXED — row 10]
The label was `missing` in the DB while the port open-coded each of pret's copies as a raw `rep movsd`
into vChars, with a single `mov byte [g_tilecache_dirty], 1` after the run. That flag *was* armed, so
this was not a live bug — but it is precisely the raw-VRAM-write shape CLAUDE.md calls out as having
shipped visible corruption twice, and it was correct only by accident: nothing tied the arming to the
writes. Restored `TrainerInfo_FarCopyData` under its pret name; every load now goes through it.

`; DEVIATION(port-primitive)`: its tail is `CopyVideoData`, not `FarCopyData`. pret's entire payload
here is `ld a, BANK(...)` — a **no-op** under the flat model — so only the tail survives; and
`CopyVideoData` is the port's VRAM-tile primitive, which arms the cache **itself**. Routing VRAM tile
loads through the generic GB-space `FarCopyData` (which does not) would reintroduce the hazard by
construction. Count is therefore in TILES, not bytes.

### M-35. The trainer card's two PlaceString labels were hand-encoded charmap bytes [FIXED — row 10]
`TrainerInfo_NameMoneyTimeText` / `TrainerInfo_BadgesText` were `db 0x8D, 0x80, …` in the `.asm` — the
Tier-1 violation. Migrated into `tools/gen_menu_strings.py` (which gained the mixed str-or-int part
list from `gen_status_strings.py`, so raw tiles like `<NEXT>` `$4E` and the ○ `$76` sit between encoded
runs exactly as pret's `db`/`next` do) → `assets/trainer_card_strings.inc`, wired into the Makefile.
Generated bytes diffed byte-identical against the literals they replace.

### M-36. A defensive `BIT_SINGLE_SPACED_LINES` clear with no pret counterpart [FIXED — row 10]
`DrawTrainerInfo` cleared `BIT_SINGLE_SPACED_LINES` in `H_UI_LAYOUT_FLAGS` before its `PlaceString`, so
the `<NEXT>`s would double-space onto rows 2/4/6. pret does no such thing: it *assumes* the bit is
clear. And the assumption is sound in both trees — every setter (`save.asm`, `learn_move.asm`,
`battle/core.asm`, `printer2.asm`, and their port counterparts) re-clears the bit a few instructions
later, so no path can reach a screen with it set. The clear was an ADDED store defending against a leak
that cannot happen — and, if one ever *did* appear, papering over it in one screen would hide it.
Dropped. **Two more copies of the same defensive clear live in `pokedex.asm:415` and
`players_pc.asm:194`**, both tagged `DEVIATION` — out of this row's file; delete them when those rows
come up (and check the `<NEXT>` rows still land right).

### M-37. `StartMenu_TrainerInfo`'s stride comment is backwards [OPEN — not this row's file]
`start_sub_menus.asm:666` restores `text_row_stride` to 20 with the comment "DrawTrainerInfo set stride
40 → restore". `DrawTrainerInfo` sets it to **20** (`TCSCR_W`), not 40, so the line restores the value
that is already there — harmless today, but the comment states the opposite of what the code does and
would mislead anyone changing either side. Row 9's file; fix the comment when it's next touched.

### M-38. `RunPaletteCommand` ×2 dropped behind a TODO-HW that confuses the palette with the call [FIXED — row 11 part 1]
`RedrawPartyMenu_.afterDrawingMonEntries` and `SetPartyMenuHPBarColor` both dropped their
`RunPaletteCommand` call, commented *"TODO-HW: SGB/CGB palette command (Phase 5)"*. The PALETTE is
Phase 5. The CALL is not: `RunPaletteCommand` is a linked global (a `ret`-only palette-HAL stub in
`faint_switch.asm`), and six other screens — status, naming, pokédex, league PC, battle send-out, and
the trainer card — call it today. Only the party menu skipped it, so on the day the HAL lands it would
have been the one screen with no palette. Both restored.

(Filed while here: that stub lives in `engine/battle/faint_switch.asm`, a **source-mirror file, not a
`*_stubs.asm`** — the same convention violation M-22 caught. Not this row's file.)

### M-39. The party messages were a hand-encoded copy of data the build already had [FIXED — row 11 part 1]
`party_menu.asm` carried its own charmap `db` transcription of all six `PartyMenuMessagePointers`
messages (`pm_msg_normal1` …) and drew them whole through a bespoke `DrawPartyMenuMessage`, under
`DEVIATION(text): engine far-text streams aren't GB-space assets yet`.

They were, and had been all along. `tools/gen_item_text.py` **already lists `engine/menus/party_menu.asm`
in its wrapper sources** and has been emitting `PartyMenuNormalText`, `PartyMenuItemUseText`,
`PartyMenuBattleText`, `PartyMenuUseTMText` and `PartyMenuSwapMonText` into `assets/item_text.inc` as
linked `global`s — while this file ignored them and printed its own copy. Nobody checked.

And the copy was wrong in the way M-16 already taught us: it spelled `POKéMON` as seven literal glyphs
where pret writes `#MON` — `$54`, the POKé text COMMAND — silently bypassing the handler this port
implements. Deleted; `PartyMenuMessagePointers` is now a `dd` table (a pointer table is Tier-2 code) of
pret's own streams, printed with pret's `PrintText`.

### M-40. M-29's missing projection, authored — and its writer identified [FIXED — row 11 part 1]
M-29 said the party panel and the dialog box collide in `GB_TILEMAP1` rows 0-5, and that a projection
for "a message box over a full-screen menu" had to be authored. Both halves are now settled.

**The writer is `manual_text_scroll` (`home/text.asm:386).** It copies the stride-20 scratch's dialog
rows (12-17) into `GB_TILEMAP1` rows **0-5** and forces the overworld dialog's WX/WY — and unlike
`sync_dialog_window`, which was explicitly gated on `g_bg_whiteout` for exactly this reason, it is not
gated at all. It runs on every `<PROMPT>`/`<PARA>`/`<CONT>`. Those rows are the party menu's mon-list
panel. That is the whole bug.

**The projection is `msgbox_party`** (`party_menu.asm`, `global`): stride-20, box in the screen's own
scratch, `MB_WIN_TILEMAP = 0` (**no window** — so `PrintText`'s `set_single_window` never collapses the
party window list), and `MB_PROMPT = PartyMenuPromptWait`, its own ▼-blink/A-B wait. That hook is the
sanctioned mechanism (`text_prompt_hook != 0`, exactly as battle's `BattlePromptWait` does it) and it
is what keeps `<PROMPT>` out of `manual_text_scroll` entirely. Neither existing record could serve:
`msgbox_dialog` owns rows 0-5 and collapses the list; `msgbox_centered` is stride-40 and draws into the
canvas, which `g_bg_whiteout` means we never composite (invisible).

**Still open, and now unblocked:** the STRENGTH/field-move messages are printed by
`engine/overworld/field_move_messages.asm` through the *default* `msgbox_dialog` while the party screen
is still up — that caller must select `msgbox_party`. The record it needs now exists and is global.
Owner: the field-move row (13), not this file.

### M-41. Both learnability columns were stubbed on a reachability argument [FIXED — row 11 part 1]
`.teachMoveMenu` and `.evolutionStoneMenu` were `STUB(items-plan)`, excused as *"reachable only from
TM/HM item USE / evolution-stone USE, which current_plan_items.md owns"*. Reachability is not a blocker,
and nothing was blocking: `CanLearnTM` (`engine/items/tms.asm`) and `EvosMovesPointerTable`
(`assets/evos_moves.inc`) are both translated **and linked in the current build** — checked in
`pkmn.sym`, not assumed. The stubs cost every TMHM and EVO_STONE party menu its entire right-hand
column ("ABLE" / "NOT ABLE"), which is the one thing those two menus exist to show.

Implemented. The evolution scan walks the mon's `EvosMoves` blob **in place** — pret needs two
`FarCopyData` stagings into `wEvoDataBuffer` only because the table is in another bank; flat memory has
no such problem. Same terminator, same 3-byte / 4-byte (`EVOLVE_ITEM`) entry stride. The two strings are
generated (`assets/party_menu_strings.inc`); pret's four labels are RGBDS locals with no global name to
preserve, so they map to `pm_str_{able,not_able}` with the mapping recorded at the use site.

### M-42. "Never `<PROMPT>`" — `RareCandyText` is a prompt [FIXED — row 11 part 1]
`.printItemUseMessage` open-coded the printer (`TextBoxBorder` + `TextCommandProcessor` at the box
cursor) rather than calling `PrintText`, justified by: *"every one of these nine texts terminates with
`<DONE>`/`text_end` (never `<PROMPT>`), so nothing blocks before the mirror."*

`RareCandyText` (pret `engine/menus/party_menu.asm:297`) is `text_far / sound_get_item_1 /
text_promptbutton / text_end`, and its generated stream ends `$0B $06 $50` — a sound command and a
PROMPT. So the level-up message's prompt was never dispatched, and the sound command rode a printer
that had never been asked whether it handled one. Routed through `PrintText`, like every other message
in the game; `msgbox_party`'s `MB_PROMPT` hook now serves it.

### M-43. "The follower system is not ported" — both routines were linked all along [FIXED — row 11 part 2]
The same `STUB(pikachu-follow)` comment sat in **two** places — `HandlePartyMenuInput`
(`home/pokemon.asm`, pret's `.asm_128f` sleeping-Pikachu refusal) and `RedrawPartyMenu_`
(`party_menu.asm`, the `hPartyMonIndex = $ff` follower-icon select) — and said the same thing: *"the
follower system is not ported; every mon takes the regular path."*

Both routines it names are **translated and linked**: `IsThisPartyMonStarterPikachu` (`0001477d T`,
`engine/pikachu/pikachu_status.asm`) and `CheckPikachuFollowingPlayer` (`0001177e T`,
`engine/overworld/pikachu.asm`). Worse, the *consumer* was ported too:
`WriteMonPartySpriteOAMByPartyIndex` (`mon_icons.asm:.saveOAM`) already implements the `$ff` branch —
dead code, because nothing could ever set `$ff`. Fourth instance of this excuse class (M-21, M-25,
M-38, M-41): a stub comment asserting an unported dependency that is sitting in the link.

Both sites destubbed. What this restores: with Pikachu walking behind you, its party row shows the
follower icon, and selecting it from the party menu is refused with "There isn't any response..."
(`PartyMenuText_12cc` → `_SleepingPikachuText1`) instead of silently opening its submenu.

**UNVERIFIED at runtime:** no golden scenario has Pikachu following the player
(`wPikachuOverworldStateFlags` bit 1 clear in every seeded party), so this path is proved by the
instruction stream and the flag contracts, not by a dump. A scenario that walks Pikachu out and opens
the party menu would close that gap.

### M-44. `PrintStatusCondition` advanced HL by 3 where pret advances it by 2 [FIXED — row 11 part 2]
The fainted path hand-encoded "FNT" as three `mov byte [ebp+esi], 0x85/0x8D/0x93` and then `add esi, 3`
— a Tier-1 violation (hand-written charmap bytes) that was **also a real divergence**, found only by
reading the macro it was replacing. `ld_hli_a_string` (`macros/code.asm:13`) emits `ld [hli], a` for
every character *but the last*, then a plain `ld [hl], <last>` — so HL ends up advanced by **len-1**,
pointing AT the final glyph, and A is left holding the *second-to-last* character ('N'), which pret's
following `and a` then tests. The port advanced by 3 and left A = 'T'.

No caller reads either today (the status/party callers reload HL), which is exactly why it survived —
but it is the sort of off-by-one that a future caller inherits silently. Now: 2 advances + a
non-advancing store, `and al, al`, and the three bytes come from `assets/home_pokemon_strings.inc`
(`hp_str_fnt`, generated). **Generator patched twice** for this row: `gen_menu_strings.py` gained the
`HOME_POKEMON` group, and `gen_battle_text.collect_wrappers`' label regex only accepted names *ending*
in `Text`/`Text<digits>` — it silently skipped pret's address-suffixed `PartyMenuText_12cc`, which is
why M-43's text stream "didn't exist". It exists now (`assets/item_text.inc`, via `home/pokemon.asm`
added to `gen_item_text.py`'s scan list).

### M-45. `GetMonHeader`'s dropped `IndexToPokedex` predef — SANCTIONED, now argued [row 11 part 2]
faithdiff reports `GetMonHeader` dropping `AddNTimes` / `CopyData` / `BankswitchCommon` / the
`IndexToPokedex` **predef**, and dropping the `[wPokedexNum]` store. Untagged until now. The first
three are the flat-data model (the tables are program-image labels, not EBP-relative GB memory). The
predef needed an actual argument, not a shrug: its whole contract is `wPokedexNum := dex(wPokedexNum)`,
and pret **saves `wPokedexNum` on entry and restores it at `.done`** — so the routine's only net effect
on GB memory is the `wMonHeader` copy plus `wMonHIndex`, which is exactly what the port produces by
reading the flat `IndexToPokedex` table in place. Tagged `DEVIATION(flat-data)` with that reasoning.

### M-46. `GetMonHeader`'s fossil/ghost `TODO-HW` — VERIFIED TRUE [row 11 part 2]
The one claim in this file that held up. `FossilKabutopsPic` / `GhostPic` / `FossilAerodactylPic` are
in no port symbol table (`pkmn.sym`), no data blob, and no generator emits them — there is genuinely
nothing to point `wMonHFrontSprite` at, so the guard writing 0 is correct and the `TODO-HW` stays.
Comment updated to say it was checked, and when.

### M-47. `RunPaletteCommand`'s ret-stub is in a source-mirror file, not a `*_stubs.asm` [OPEN — out of scope, not row 11's file]
Found while restoring M-38's two dropped calls. The stub is at
`dos_port/src/engine/battle/faint_switch.asm:59` — a bare `RunPaletteCommand: ret` sitting in the
middle of a *translated* battle file. CLAUDE.md's stub convention is explicit that a link-time
stand-in goes in the subsystem's `*_stubs.asm` and never in the file that will eventually hold the
real routine, precisely so retiring it is a bounded search instead of a tree-wide hunt.

**This is now live, not theoretical:** the palette/colorization work is in progress in a parallel
session, and `RunPaletteCommand` is the routine that work has to fill in. Whoever lands the palette
layer will grep for a stub file, not find one, and either duplicate the symbol (link error, cheap) or
translate the real body somewhere else and leave this `ret` **shadowing** it (silent, and the exact
class that has shipped twice — see the stub-shadow note in `project-conventions`).

Fix: move it to `src/engine/battle/battle_stubs.asm` (or a `gfx_stubs.asm`, since the routine is
`engine/gfx/palettes.asm` in pret — its mirror file does not exist in the port yet), repoint the
extern comments in the seven callers via `tools/label_status --callers RunPaletteCommand`, and delete
it outright the moment the palette body lands. Not row 11's file, so not touched here.

### M-48. `swap_items.asm` declared itself CHECK-only and unreachable — it is in the linked binary, and so is its ACE glitch **[FIXED — row 12]**
**File:** `dos_port/src/engine/menus/swap_items.asm` (header, and the `GLITCH:` block's `Safety:` note)
**What was wrong:** the header made three claims, all false:
1. *"LINK status: assembles CHECK-only now. … No live caller invokes the list menu yet."* —
   `src/engine/menus/swap_items.asm` is in **`GAME_SRCS`** (`Makefile:309`), `pkmn.sym` carries
   `T HandleItemListSwapping`, and its caller is linked: `src/home/list_menu.asm:435`
   (`DisplayListMenuIDLoop.checkOtherKeys`) does `jmp HandleItemListSwapping` on SELECT. The SELECT
   swap runs whenever the bag list menu is open. (This is the same false *"no live caller"* header
   claim row 4 already caught in `list_menu.asm` — the two files were lying about each other.)
2. *"Symbols still missing from gb_memmap.inc / gb_constants.inc are LOCAL PLACEHOLDERS below —
   ROOT migrates + deletes."* — there are **no placeholders in the file**. Every symbol it uses
   (`hSwapItemID` $FFA9, `hSwapItemQuantity` $FFAA, `wListCount`, `wMaxMenuItem`, `ITEMLISTMENU`)
   is a canonical `equ` in `gb_memmap.inc`/`gb_constants.inc`. A comment 10 lines further down
   already said so — the header contradicted its own file.
3. **The dangerous one.** The `Safety:` half of the `GLITCH:` tag on `.swapSameItemType` *derived
   itself from claim 1*: "this file is CHECK-only per its header … so this path is dormant, not
   reachable, in the current build. Once linked: unsafe — ACE can escape EBP allocation via the
   downstream ws# #m# chain." It is linked. The item-underflow gateway (the unclamped 8-bit
   quantity `add`, whose 256-sum wrap writes a ×0 stack) is **live right now**, and the file's own
   safety note was telling the next reader the opposite. The `GLITCH:` description is accurate and
   the behavior is correctly preserved verbatim per pret — only the reachability assessment was
   wrong, which is precisely the half a `Safety:` note exists to get right.
**Fix:** header rewritten to state the real link status (with the `nm`/Makefile/caller evidence);
`Safety:` rewritten to say LIVE, and to name the actual guard rail — the multi-step quantity
manipulation needed to *set up* the 256-sum, not the absence of a link.
**Severity:** medium (no wrong instruction shipped, but a `Safety:` note that inverts an ACE
glitch's reachability is exactly the comment the convention exists to make trustworthy)

### M-49. Two gratuitous register-contract divergences in an otherwise faithful translation **[FIXED — row 12]**
**File:** `dos_port/src/engine/menus/swap_items.asm` `HandleItemListSwapping`
**pret:** `engine/menus/swap_items.asm:19-20` (`ld a,[hl]` / `pop hl`) and `:50-51` (`push hl` / `push de`)
**What was wrong:**
1. **DL clobbered where pret preserves DE.** pret reads the selected entry's ID and restores HL with
   a plain `ld a,[hl]` / `pop hl` — `pop` cannot disturb A. The port routed the byte through **DL**
   (`mov dl,al` / `pop esi` / `mov al,dl`) for no reason, destroying the low half of DE on *every*
   path including the two early `jmp DisplayListMenuIDLoop` exits, which pret leaves DE untouched
   on. Latent, not live (the caller re-enters its loop and does not read DE across the jump), but
   it is a silent narrowing of the register contract in the one routine whose whole job is to
   shuffle registers around a list.
2. **`push dx` / `pop dx` saved half of a 32-bit pointer.** The swap block mirrors pret's
   `push hl` / `push de`, but the port immediately does `mov edx, esi` and uses **EDX as a flat
   32-bit pointer** into the list. Pushing only `dx` restores the low 16 bits and leaves the high
   half as whatever the routine last wrote — the save was decorative. (Harmless today only because
   every value EDX takes is a GB address < $10000, so the high half happens to be zero; it is
   correct-by-accident.) It also left ESP 2-mod-4 through the body.
**Fix:** the DL detour is deleted (`mov al,[ebp+esi]` / `pop esi` / `inc al` — `pop` touches neither
AL nor EFLAGS, so the `jz` still reads the flags `inc al` sets), and the pair is now `push edx` /
`pop edx`. No behavioral change intended or observed; `make fidelity` 6/6 PASS.
**Severity:** low (latent register clobber; correct-by-accident stack save)

### M-50. `IsFieldMove`: a port-only duplicate of pret's field-move scan, with no callers **[FIXED — row 13]**
**File:** `dos_port/src/engine/menus/field_moves.asm` (deleted)
**pret:** `engine/menus/text_box.asm:GetMonFieldMoves` (`.fieldMoveLoop`) — the scan pret actually ships
**What was wrong:** `field_moves.asm` exported a port-only helper, `IsFieldMove`, that walked the same
`$FF`-terminated `FieldMoveDisplayData` table as pret's `GetMonFieldMoves` and returned a name pointer
in `EAX`/CF. It was written when the port's party menu labelled field moves itself. Commit `c0b225ac`
("party menu realigned onto the faithful pret split") replaced that call with pret's `GetMonFieldMoves`
and **left `IsFieldMove` with zero callers** — verified, not assumed: it appears nowhere in `dos_port/src`
outside its own definition (and one comment in `text_box.asm`), and `nm` shows it linked and called by
nobody. The file's header meanwhile asserted, for the whole intervening time, *"This data must live in a
LINKED source (party_menu.asm calls IsFieldMove)"*. It does not.
Two scans of one table is exactly how the two drift apart, and the dead one is the one nobody re-checks.
**Fix:** `IsFieldMove` deleted; `field_moves.asm` is now data-only. The generated `FieldMoveDisplayData` /
`FieldMoveNames` tables stay exactly as they are — their real consumers are `GetMonFieldMoves` and
`DisplayFieldMoveMonMenu`, both in `text_box.asm`, both faithdiff-clean. Header rewritten to name them.
**Severity:** low (dead code — but a divergent second implementation of a pret routine)

### M-51. `DisplayTextIDInit` is linked, faithful, and has never run **[FIXED (documented) — row 13]**
**File:** `dos_port/src/engine/menus/display_text_id_init.asm`
**pret:** `engine/menus/display_text_id_init.asm:DisplayTextIDInit`
**What's wrong:** the translation is faithful (all 4 calls matched; the `set`/`res [hl]` stores are
faithdiff's known pret-side blind spot; the `bit`-then-`res`-then-`jr nz` flag order is correctly
reproduced with an `AH` copy, since SM83 `res` does not touch flags). But the routine **is not reachable
in the linked build**, and its header described its caller as though it were:
- `nm`: `T DisplayTextIDInit` — it is in the binary.
- Its **only** caller is `DisplayTextID` in `src/home/text_script.asm`, and that file is in
  **`HOME_CHECK_SRCS`** — it assembles, it does not link.
- The `DisplayTextID` that *is* in the binary is the ret-stub in `src/home/home_stubs.asm`, which calls
  nothing. The port's live NPC dialog does not route through `DisplayTextID` at all (`CheckNPCInteraction`
  calls `PrintText` directly).
So the box-drawing behavior this file's careful SCREEN MODEL notes describe — the dialog border at (0,12),
the start-menu border at (10,0) — **has never been observed**, and cannot be until `text_script.asm` links.
**Epistemics, in the other direction:** `home_stubs.asm`'s stub comment claims *"the only linked caller is
TryDoWildEncounter's `.lastRepelStep`"*, and a grep finds **three** `call DisplayTextID` sites, which looks
like the false-claim class this audit keeps finding. It is not: `predef_text.asm` and `trainer_engine.asm`
are themselves `HOME_CHECK_SRCS`. The stub's account is **correct**. Checked rather than assumed, and
recorded because "the comment was right" is evidence too.
**Fix:** no code change to the body — it is faithful. The header now states the reachability plainly
(dead code; unverified at runtime; becomes live when `text_script.asm` links, which is also what retires
the `home_stubs` ret-stub) instead of implying a live caller.
**Severity:** low as shipped (nothing runs), medium as documentation (a "faithful, working" reading of
this file was unearned, and its screen-model reasoning is untested)

### M-52. The dropped `hWY` store was tagged `TODO-HW`; it is a permanent deviation **[FIXED — row 13]**
**File:** `dos_port/src/engine/menus/display_text_id_init.asm` (the `xor a / ldh [hWY],a` site)
**pret:** `engine/menus/display_text_id_init.asm:73`
**What was wrong:** the port drops pret's `hWY = 0` store — correctly — but tagged it `; TODO-HW: rWY
write`, which is wrong on both halves. There is nothing hardware-deferred about it: `H_WY` exists in the
port and is written elsewhere (`set_single_window` mirrors `wy → H_WY`), and no future hardware work will
ever make this particular store correct. On the GB, `rWY = 0` reveals a window whose *content is already
in the tilemap*; in the port the dialog is a window **descriptor**, and `H_WY` doubles as the "a dialog
window is open" gate — so writing 0 here would open that gate with no descriptor behind it. The store is
permanently and deliberately not made, and `PrintText` does the equivalent when it registers the real
window. That is a **SANCTIONED(window-compositor)** deviation, not a to-do.
**Fix:** retagged `; DEVIATION(window-compositor):` with the argument above written out. A `TODO-HW` that
will never be done is a comment that lies to whoever eventually greps for the remaining hardware work.
**Severity:** low (documentation; the code was already right)

### M-53. The `rAUDTERM` silence store was dropped behind a false `TODO-HW` **[FIXED — row 14]**
**File:** `dos_port/src/engine/menus/options.asm` `OptionsMenu_SpeakerSettings.save`
**pret:** `engine/menus/options.asm:240-241` — `xor a / ldh [rAUDTERM], a`
**What was wrong:** pret zeroes `rAUDTERM` (NR51, the stereo/channel routing register) at the
instant the speaker setting changes, silencing all channel output across the switch. The port
dropped the store under:
> `; TODO-HW: audio HAL (Phase 3) — pret zeroes rAUDTERM ... no APU register in the port, so the`
> `; register write is skipped.`
Every clause is false, and the file it is false about is one `grep` away:
- `rAUDTERM` **exists**: `gb_memmap.inc:905`, `equ 0xFF25`.
- It is **written** by the audio engine — `src/audio/engine_1.asm:79,254,256,696,698`,
  `src/audio/engine_2.asm:99,153` (the latter commented "no sound output").
- It is **read every frame by the output shims** — `opl_shim.asm:313`, `tandy_shim.asm:166`,
  `spk_shim.asm:96` — which is exactly how the port decides which channels reach the speaker.
So the byte is not a phantom hardware register: it is live port state with live readers, and the
one screen whose *purpose* is to change speaker routing was the one screen not writing it.
"Phase 3" landed long ago (this is the same stale-`TODO-HW`-outliving-its-premise class as M-13
and M-20 — now the third instance in audio alone).
**Fix:** `xor al, al / mov [ebp + rAUDTERM], al`, at pret's position. AL is reloaded from
`wOptions` on the next instruction, so the clobber is pret's own.
**faithdiff note:** this now shows as `+ ADDED [rAUDTERM]`, which is the pret-side blind spot —
pret writes it with `ldh`, and the store-matcher only sees `ld [sym], a`.
**Severity:** medium (wrong audio behavior on a live screen; the shims keep routing on the stale
byte across the change)

### M-54. 18 hand-encoded charmap strings — excused by the header as "Tier-2 code data" **[FIXED — row 14]**
**File:** `dos_port/src/engine/menus/options.asm` (`.data`) → `dos_port/assets/options_strings.inc`
**pret:** `engine/menus/options.asm:AllOptionsText`, `OptionMenuCancelText`, and the six handlers'
local `.Strings` entries (`.Fast`/`.Mid`/`.Slow`, `.On`/`.Off`, `.Shift`/`.Set`,
`.Mono`/`.Earphone1-3`, `.Lightest`..`.Darkest`)
**What was wrong:** every rendered string on the OPTION screen was a raw `db 0x93, 0x84, …` block —
the Tier-1 violation CLAUDE.md calls "the most-repeated violation". What makes this instance worth
its own finding is that the header did not merely *fail* to flag it; it **asserted the opposite**:
> `; Jump table + strings (Tier-2 code data — hand-authored charmap bytes ...)`
A string the player reads is Tier-1 DATA by definition. The comment invented an exemption that does
not exist, which is why nobody re-examined it for eight rows of this audit.
**Fix:** migrated into `tools/gen_menu_strings.py` (new `OPTIONS` group) → `assets/options_strings.inc`,
`%include`d, wired into `make assets` and the `options.o` prerequisites. `AllOptionsText` and
`OptionMenuCancelText` keep their pret GLOBAL names; the `opt_*` labels stand in for pret's RGBDS
locals (the `PARTY_MENU` precedent) and the `.Strings` tables map them back. **`OptionMenuJumpTable`
stays hand-written and is now the only thing in that section** — it holds flat CODE addresses, which
no data generator can emit; the header says so instead of lumping it in with the strings.
The generated bytes were **byte-compared against the old literals: identical, all 18** (and the
trailing padding — `"MID "`, `"SET  "`, `"MONO     "` — is load-bearing, since a shorter value must
fully overwrite the longer one it replaces in the same cells; noted in the generator so nobody
"tidies" it).
**Severity:** low as shipped (the bytes were right), high as precedent (an invented exemption in a
header is how a convention dies)

### M-55. `InitOptionsMenu`'s dropped `hAutoBGTransferEnabled`, and a `BUG` tag with no guard **[FIXED — row 14]**
**File:** `dos_port/src/engine/menus/options.asm` `InitOptionsMenu` / `DisplayOptionMenu_`
**pret:** `engine/menus/options.asm:470-471` (`ld a,$01 / ldh [hAutoBGTransferEnabled],a`) and
`DisplayOptionMenu_` (`docs/bugs_and_glitches.md#options-menu-code-fails-to-clear-joypad-state-on-initialization`)
**What was wrong — two small things, both convention-shaped:**
1. `InitOptionsMenu` dropped pret's `hAutoBGTransferEnabled = 1` store, replacing it with the port's
   explicit mirror. The mirror is right (SANCTIONED — there is no VBlank BGMap transfer to enable),
   but the store is **write-only, not meaningless**: rows 9 and 11 already established that a screen
   which quietly stops writing a flag pret writes is how port state drifts out of step (M-24).
   Restored, with the mirror kept and tagged.
2. The `BUG(cosmetic)` tag for the joypad-state bug was **comment-only** — it described pret's fix in
   prose and then didn't implement it. The convention is `; BUG(level):` **plus** a
   `%if BUG_FIX_LEVEL >= N` block: the bug is preserved at level 0 *and* the fix is available. Half
   the contract was missing. Added at `BUG_FIX_LEVEL >= 2` (cosmetic — `docs/bug_categorization.md:36`
   already classifies it so), using pret's own one-line fix (`call JoypadLowSensitivity` before
   `InitOptionsMenu`) verbatim. The bug itself is untouched at level 0, as required.
**Severity:** low (latent state drift; a missing fix-level block)

### M-56. `docs/bug_categorization.md` still calls the item-swap driver "dormant" **[OPEN — not this row's file]**
`docs/bug_categorization.md:111` (Expanded Item Pack) says it *"Shares `swap_items.asm`'s **dormant**
list-menu driver"* and defers the Item Underflow entry until *"`HandleItemListSwapping` is linked"*.
It **is** linked — row 12 established that (`T HandleItemListSwapping` in `pkmn.sym`, reached from
`list_menu.asm`'s SELECT branch), and fixed the same false claim in `swap_items.asm`'s own header and
`GLITCH`/`Safety` note. The doc is the last copy of that stale belief, and it is the copy a
glitch-safety reader would consult. Not row 14's file; filed rather than swept in.
**Severity:** low (documentation), but it is a *safety* doc making a reachability claim that is wrong.

### M-47 — resolved by another session (noted, not claimed)
The `RunPaletteCommand` ret-stub in `src/engine/battle/faint_switch.asm` is **gone**. The parallel
colorization session (stigmergy root `r-0e1a76275e71`) deleted it and landed a real `RunPaletteCommand`
body while row 13 was in flight, after this ledger's finding was passed to them over the mailbox. The
shadow hazard M-47 described is closed. Recorded here because the finding was filed here; the fix is
theirs, not this audit's.

---

## Row 15 findings — `src/engine/menus/naming_screen.asm`

### M-57. A stale `SFX_PRESS_AB` placeholder, kept alive by a false stub claim **[FIXED — row 15]**
The file carried its own `SFX_PRESS_AB equ 0x3E`, under this comment: *"TODO-HW(audio): PlaySound is a
stub in this port (engine/battle/move_effect_helpers.asm); value not yet load-bearing."* Every clause
of that is false, and each one was checkable in one command:
* **`PlaySound` is a real body**, at `src/home/audio.asm:217` — not a stub, and not in
  `move_effect_helpers.asm`. The audio engine has been live since 2026-07-07.
* **The value is load-bearing**, precisely because of the above.
* **`0x3E` is the wrong id.** The real `SFX_PRESS_AB` is **`0x90`** (`assets/audio_constants.inc`,
  generated from `constants/music_constants.asm`).
So the naming screen has been playing **sound `0x3E` — a different SFX entirely — on every letter
press.** This is the same defect class as M-53 (row 14): a `TODO-HW` asserting a dependency is absent
while it sits in the link, and the assertion outliving the thing it described.
**Fix:** deleted the local `equ`, `%include`d the generated `assets/audio_constants.inc`, and added
that `.inc` to `naming_screen.o`'s Makefile prerequisites. This closes the long-open **M-4**.

### M-58. Hand-encoded charmap strings — including one that already had a generator **[FIXED — row 15]**
Five rendered strings were hand-written charmap `db` bytes (the Tier-1 violation): the four
`PlaceString` labels (`YourTextString`, `RivalsTextString`, `NameTextString`, `NicknameTextString`)
and the 12-line inlined `DoYouWantToNicknameText` stream. The inline stream carried an excuse:
*"the inline stays only because `data/text/text_3.asm` has no generator yet"*. **It has one.**
`tools/gen_battle_text.collect_far` already flattens every stream in `text_3.asm` — 483 labels,
`_DoYouWantToNicknameText` among them. Nobody had pointed it at this label. The comment's other
premise (that `TX_FAR` couldn't address flat `.data`) it had already retracted itself, correctly:
`TX_FAR` takes a flat 32-bit operand and `home/text.asm:1141` splices it recursively.
**Fix:** all five generated into `assets/naming_strings.inc` via `tools/gen_menu_strings.py`, and
`DoYouWantToNicknameText` restored to pret's actual two-label shape — `text_far _DoYouWantToNicknameText`
+ `text_end`. Generated bytes **byte-compared against the hand-written literals: identical, all five**
(including the far stream's `dw wNameBuffer` → `6D CD`).

### M-59. `gb_text.encode` has no longest-match pass — apostrophe ligatures encode wrong **[FIXED (worked around) — row 15; the encoder gap is OPEN]**
Found while migrating M-58. RGBDS charmaps match **longest-first**, and `constants/charmap.asm` defines
`"'d" $BB`, `"'l" $BC`, `"'s" $BD`, `"'t" $BE`, `"'v" $BF`, `"'r" $E4`, `"'m" $E5` as **single glyphs**
(a bare `'` is `$E0`). So pret's `db "RIVAL's @"` assembles to **8 bytes, one glyph for `'s`**.
`gb_text.encode` (the `unicode_converter` submodule) matches one character at a time and returns
`$E0,$B2` — a **nine**-byte string that renders as two glyphs and shifts every cell after it.
`RivalsTextString` is the **first generator input in the tree to contain an apostrophe**, so this has
never bitten before — it was waiting for whoever wrote the next one.
**Fix (this row):** emit the ligature as a raw byte (`APOS_S = 0xBD`), the same mechanism the generators
already use for `<NEXT>`/`@`/`○`, with the trap documented at the constant.
**Still open:** the encoder itself. Any future string with `'d/'l/'s/'t/'v/'r/'m` fed to `gb_text.encode`
will be silently wrong. The real fix is a longest-match pass in the submodule.

### M-60. `AskName` called `YesNoChoice` — which pret's `AskName` must *not* call **[FIXED — row 15]**
The port had a single `call YesNoChoice`, commented *"this is exactly the standard YES/NO box"*. It is
not. pret's `AskName` inlines the box itself (`hlcoord 14,7` / `lb bc,8,15` / `wTextBoxID =
TWO_OPTION_MENU` / `call DisplayTextBoxID`) and **deliberately does not go through `YesNoChoice`**,
because pret's `YesNoChoice` wraps the box in `SaveScreenTilesToBuffer1` … `jp
LoadScreenTilesFromBuffer1` — and **buffer 1 belongs to `AskName`**, which snapshots the pre-prompt
screen into it at entry and restores it after the naming screen closes. A yes/no box that re-saved
buffer 1 would capture the screen *with the nickname prompt on it*, and `AskName`'s restore would paint
the prompt box back onto the field.

The reason it was not already a visible bug is the interesting part: **the port's `YesNoChoice` drops
pret's save/restore wrapper** (a documented window-model deviation in `home/yes_no.asm`). So this
file's fidelity rested on *another file's infidelity* — silently, with no tripwire, and it would have
broken the day `yes_no.asm` was made faithful (which is exactly what that file is waiting to do).
**Fix:** call what pret calls. `faithdiff AskName` went from a dropped `DisplayTextBoxID` + a dropped
`[wTextBoxID]` store to **10/10 calls, 4/4 stores**.
**SANCTIONED (tagged at the site):** the one remaining added call, `InitYesNoTextBoxParameters`, stands
in for pret's `hlcoord 14,7 / lb bc,8,15`. It is *pret's own routine* and sets exactly those coords; the
port needs the call because `DisplayTextBoxID_`'s two-option path reads the box geometry from
`yes_no.asm`'s private `yn_box_col`/`yn_box_row` (`.bss`) rather than a register triple, so there is no
other supported way to express pret's `hlcoord`/`lb bc` here. It also writes `wTwoOptionMenuID =
YES_NO_MENU`, which pret's `AskName` does **not** — pret inherits whatever the last two-option box left
behind (only the `yes_no` entry points, `clear_save`, `slots` and `cable_club` ever write it; it is 0 in
practice by the time `AskName` runs). The port is therefore *deterministic* where pret is
stale-state-dependent; the box is the same either way.

### M-63. `PrintNamingText` clobbered the screen-type in AL — the player-name screen said "NICKNAME?" **[FIXED — row 15]**
The worst bug in the file, and **invisible to faithdiff** (the call/store lists were already clean —
it is a register defect, which is exactly what faithdiff cannot see). The port had:
```asm
mov al, [ebp + wNamingScreenType]
mov eax, YourTextString      ; <-- overwrites AL with the low byte of an ADDRESS
test al, al                  ; tests the address, not the screen type
jz .notNickname
```
pret keeps the screen type in `A` and the string pointer in `DE` — **two different registers**,
deliberately. The port hoisted the pointer into `EAX` (because its `PlaceString` takes the source
there) and destroyed the type in the same instruction. The low byte of a link-time address is never 0,
so `PLAYER` and `RIVAL` both fell through into the **MON** path: the player-name screen printed a
**garbage species name** (from an unset `wNameBuffer`) and asked **"NICKNAME?"** instead of
**"YOUR NAME?"**, and it called `WriteMonPartySpriteOAMBySpecies` on a garbage species id.
**OBSERVED, not deduced** — the `DEBUG_NAMINGSCREEN` frame rendered `F STONE` / `NICKNAME?`.
**Fix:** keep the pointer in `EDX` (pret's `DE`) and move it to `EAX` only at the `PlaceString` call
site. Re-rendered: the screen now reads **"YOUR NAME?"** and the garbage name row is gone.
This is the CLAUDE.md register-map rule failing in the one way the fidelity tools cannot catch, and it
argues for rendering every screen an audit touches rather than trusting a clean faithdiff.

### M-61. `RunDefaultPaletteCommand` is defined TWICE **[OPEN — not this row's file]**
The global definition is `engine/menus/naming_screen.asm:548`. There is a **second, file-local copy** at
`engine/menus/pokedex.asm:638`. It links only because the pokedex copy is not `global` — so pokedex
silently calls its own private clone of a pret label instead of the shared one. Row 16 is
`pokedex.asm`; filed rather than reached into. Also passed to the colorization session, since the fix
belongs with their palette body.

### M-62. The palette command was passed in the wrong register half **[FIXED — `c84c76e8`]**
Both bodies do `mov bl, SET_PAL_DEFAULT`, and `naming_screen.asm:300`'s `SET_PAL_GENERIC` call site does
the same. pret sets **`b`** (= **BH** in the port's register map), and `RunPaletteCommand` reads `b`.
This is harmless *only* while `RunPaletteCommand` is a ret-stub that never reads its argument — the
existing comment says as much. But the colorization session is landing a **real** `RunPaletteCommand`
body right now, and on the day it starts reading BH, every `RunDefaultPaletteCommand` caller hands it
whatever is in the wrong half and picks the wrong palette. Not fixed here: changing a register contract
underneath another session's in-flight body, without their body to test against, is how you ship the
next silent bug. Messaged to `r-60a3083156c6` with the fix.

**RESOLVED `c84c76e8`.** That session ended without taking it, so this row closed it. Reading their
landed body changed the picture completely: `RunPaletteCommand` was not merely *reading the wrong
half*, it was reading **either** half —

    RunPaletteCommand:
        mov al, bl
        test al, al
        jnz .have_command
        mov al, bh          ; only when BL == 0

— i.e. a "normalizing shim" that made the **wrong half authoritative**. Two consequences, neither of
them theoretical:

1. The sites that were **already correct** (`town_map`'s `SET_PAL_TOWN_MAP`, `pokedex_entry`'s
   `SET_PAL_POKEDEX`, both writing BH) were **silently mis-dispatched whenever BL happened to be
   nonzero**. The bug was live, and it punished the callers that had done the right thing.
2. It made the path **un-fixable one site at a time**: the faithful edit (BL → BH) is precisely the
   edit the shim breaks. This is why row 16 part 1 deliberately did *not* convert `pokedex.asm` —
   that call was right, on the evidence available then, but the real answer was that the migration
   must land **atomically**, which is what `c84c76e8` does: all 9 call sites → BH, then the shim
   reads BH only. `_RunPaletteCommand` never reads BL, so pret's `c` carries nothing here.

The lesson generalizes past palettes: **a compatibility shim that accepts both of two contracts does
not remove the bug, it removes your ability to fix it** — and it hides which callers are wrong.

### M-72. Two battle call sites passed NO palette command at all **[FIXED — `c84c76e8`]**
Found while doing M-62. `faint_switch.asm:205` and `faint_sendout.asm:127` both `call
RunPaletteCommand` where pret does `ld b, SET_PAL_BATTLE / call RunPaletteCommand` — they set `b`
**not at all** and dispatched on whatever junk `BX` happened to hold. Harmless only while
`RunPaletteCommand` ignored its argument; that stopped being true the moment the palette engine
landed, and nothing would have flagged it (faithdiff sees the *call*, and the call was there).
`SET_PAL_BATTLE` did not exist anywhere in the port — added to `gb_constants.inc`.

---

## Row 16 findings (part 1) — `src/engine/menus/pokedex.asm`

Eight findings on the list/menu half. The headline is a **whole feature that was written,
linked, and then simply never called** — and the row also produced a *methodology* finding
(M-69) that invalidates how earlier rows may have "verified" screens.

### M-64. The POKéDEX **AREA** option was dead — `LoadTownMap_Nest` was never called **[FIXED]**
`.choseArea` was a no-op whose comment read *"STUB: pret `predef LoadTownMap_Nest` — OUT OF
SCOPE for the menus swarm (town-map subsystem)"*. Every clause of that is false:
`LoadTownMap_Nest` is a **complete 74-instruction body** at `engine/items/town_map.asm:252`,
it is `global`, and it is **linked** (`ITEMS_SRCS` ⊂ `LINK_SRCS`). Nothing was out of scope
and nothing was missing — the *one instruction that calls it* was missing. Pressing AREA
silently returned to the list.

The Makefile carried the matching lie: *"town_map is intentionally kept dangling (not in the
main loop)"*, sitting directly above a `CHECK_SRCS` list that does **not** contain it. Both
the code comment and the Makefile comment are corrected in this commit.

Fixed with `call LoadTownMap_Nest` (pret's `predef`; predefs carry no bank in a flat address
space and this one takes no register args). **Verified by rendering it** — the new
`DEBUG_G1=1 PDEX_AREA=1` harness photographs the screen, and it draws **"PIDGEY's NEST"** over
the Kanto map with nest markers. The species reaches `GetMonName` through the
`wPokedexNum`/`wNamedObjectIndex` union (both `0xD11D`, as in pret's `wd11e`), so
`PokedexToIndex`'s internal index lands where the name lookup reads it.

### M-65. `.chosePrint` dropped 2 calls and 3 stores behind a "STUB" comment **[FIXED]**
Same anti-pattern, smaller blast radius: the whole printer path was replaced by `mov bh,3 / jmp`,
dropping `ClearScreen`, `PrintPokedexEntry`, and the `hTileAnimations` save/zero/restore +
`wCurPartySpecies` stores. A stub is a **label with a `ret`, in a `*_stubs.asm`** — never a
deleted code path in a source-mirror file. pret's body is now ported in full, and the one thing
that genuinely cannot work (the GB Printer is a **serial-link peripheral** → TODO-HW) is a real
ret-only stub: new file `src/engine/printer/printer_stubs.asm`. Behaviour with a ret stub is
what hardware does with no printer attached: clear + redraw.

### M-66. `GetCryData` — a ret-stub parked in a source-mirror file **[FIXED]**
It sat in `pokedex.asm` under a comment that *itself listed this as violation #1* and had been
ignored. Moved to `home_stubs.asm` (it is `home/pokemon.asm`), beside `PlayCry` — its only other
caller, with which it must be destubbed. Still a stub: the CRY option is silent. That remains
**M-32** and is *not* an audio-HAL blocker — the engine is live, `PlaySound` is a real body, and
`CryData` is generated and exported. Nobody has written the ~15 instructions.

### M-67. `RunDefaultPaletteCommand` defined twice — the duplicate is deleted **[FIXED; closes the pokedex half of M-61]**
The file-local clone in `pokedex.asm` is gone; the file now externs the `global` in
`naming_screen.asm`. One pret label, one body.

### M-68. Three extern comments asserted stubs that are REAL, LINKED BODIES **[FIXED — comments]**
- `RunPaletteCommand` — *"palette HAL (no-op stub)"*. It is a **real body** (`home/palettes.asm`)
  dispatching to `_RunPaletteCommand`. Its shim reads GB `b` from **BL first, BH only if BL is
  zero**. This *inverts* M-62's fix for this file: switching to pret's literal `ld b` → BH would
  let a stale nonzero BL win the test and select the **wrong palette**. So this file deliberately
  keeps `mov bl`, with the reason written at the site. Unifying on BH stays M-62 (palette session).
- `PlaySound` — *"audio HAL stub"*. Real body (`home/audio.asm`). Same false claim row 15 killed.
- `LoadPokedexTilePatterns` — *"shared no-op stub"*. Its real body is **20 lines below the comment.**

### M-69. **A freshly built `PKMN.IMG` ships a STALE `FRAME.BIN`** — a harness that fails to dump reads as a pass **[OPEN — tooling]**
While verifying M-64 I pulled `FRAME.BIN` from the image and got a **battle screen with a magenta
palette** — another session's frame, dated hours earlier. `make image` packages the previous run's
`FRAME.BIN`/`GBSTATE.BIN`/`PAL.BIN` artifacts into the image, so when a harness crashes, hangs, or
never reaches its dump, `mcopy` happily returns the **previous screen** and it renders like a result.
I nearly reported a false pass off it, and the two golden-scenario "phantom FAILs" from earlier
sessions smell like the same trap.

Workaround used here: `mdel -i img ::FRAME.BIN` **before** the run, so a missing dump is a hard
"no output" instead of a stale picture. The real fix is for `make image` to exclude the dump
artifacts (or for `goldencheck.sh` to delete them from its scratch copy). Not this row's file.

### M-70. The four PlaceString labels + `.dashedLine` were hand-encoded charmap bytes **[FIXED]**
Under a header calling them *"Tier-2 hand-authored charmap bytes"* — **there is no such exemption**;
a rendered string is Tier-1 DATA (CLAUDE.md). Same false-exemption shape as row 14's M-54. All five
now generate via `gen_menu_strings.py` → `assets/pokedex_strings.inc`, byte-compared against the
literals they replace: **identical**. `.dashedLine` is routine-*local* in pret, and the generated
`.inc` keeps that exact name using NASM's `Global.local` form
(`Pokedex_PlacePokemonList.dashedLine`) rather than inventing a global alias.

### M-71. `IndexToPokedex` — pret's ROUTINE name is squatted by a port DATA TABLE **[OPEN — cross-file]**
pret has **two** symbols: the table `PokedexOrder` and the routine `IndexToPokedex` that walks it.
The port has **no `PokedexOrder`** and gives the name `IndexToPokedex` to the *table*. Semantics are
equivalent (`PokedexToIndex` walks the same bytes), so nothing is broken — but a pret ROUTINE label
naming a DATA object is exactly the confusion the label rule exists to prevent, and it is what the
`relocated` allowlist entry has been quietly blessing. The correct shape is table→`PokedexOrder`,
routine→`IndexToPokedex`. Not fixed here: the table name is load-bearing in
`src/data/pokemon_data.asm`, `home/pics.asm` (×2), and `tools/gen_base_stats.py` — all outside this
row's file.

**Allowlist challenge — deferred to part 2, on the evidence.** All 10 pokedex entries in
`pret_label_allowlist.json` sit under `relocated_labels`, and **not one of them names a label
defined in `pokedex.asm`**: nine relocate to `pokedex_entry.asm` (G2's file) and the tenth is
`IndexToPokedex` → `pokemon_data.asm` (M-71). Deleting them while auditing *this* file would test
nothing. They are challenged in part 2, where the labels actually live.

### Verification
`make check` clean; `lint_pret_labels` **0 violations**; `make fidelity` **all 6 golden scenarios
PASS** (no new masks). `faithdiff HandlePokedexSideMenu` went from **8/11 calls + 7/10 stores** to
**11/11 calls + 10/10 stores** — every dropped call and store restored. Both screens **rendered and
looked at**: the CONTENTS list (SEEN/OWN counts, pokéballs on the owned mons, and the `.dashedLine`
placeholder — the harness seed now deliberately leaves mon 4 unseen so that path is actually
exercised) and "PIDGEY's NEST".

---

## Row 16 findings (part 2) — the DATA-page half (ex-`pokedex_entry.asm`, now merged)

**The file is gone.** `src/engine/menus/pokedex_entry.asm` held the second half of pret's
`engine/menus/pokedex.asm` (`ShowPokedexData` … `PokedexDataDividerLine`). Its own header admitted
why it existed: *"package G2 … a separate worker/worktree … Root finalizes the link at
integration."* That is a **parallel-worker artifact, not a port-model decision** — and it is what all
nine `relocated_labels` allowlist entries were quietly blessing. Both halves now live in
`src/engine/menus/pokedex.asm`, mirroring pret one-to-one, and **all ten allowlist entries are
deleted** (lint: 0 violations). See M-78.

### M-73. `rAUDVOL` save/restore dropped behind a **false** `TODO-HW` **[FIXED]**
`ShowPokedexDataInternal` writes `$33` to `rAUDVOL` on entry and `$77` on exit (pret halves the
volume for the cry, then restores it). The port dropped both stores under
*"TODO-HW: audio HAL (Phase 3). No APU."* — **wrong**: `rAUDVOL` ($FF24) is a live GB byte that the
OPL/Tandy/MPU-401 shims read every frame, exactly like row 14's `rAUDTERM` (M-53). Both stores
restored; the comment deleted. **Same false claim still sits at
`src/engine/pokemon/status_screen.asm:147` and `:696` — cross-file, filed not fixed.**

### M-74. `RunDefaultPaletteCommand` dropped, "not defined in the port" **[FIXED]**
The teardown's call was commented out with *"not defined in the port."* It is a `global` in
`src/engine/menus/naming_screen.asm` — and **this very file already calls it** from
`.exitPokedex` (part 1's M-67 externed it). The comment was stale before it was written. Call
restored.

### M-75. `PlayCry` call dropped from `DrawDexEntryOnScreen` **[FIXED]**
pret loads `wCurPartySpecies` and calls `PlayCry` before the flavor text. The port dropped it
silently. `PlayCry` is a documented ret-stub in `home_stubs.asm` (M-32), so the call is currently a
no-op — but **the call site is the fidelity contract**, and it is the sole reason the `rAUDVOL`
halving above exists. Restored.

### M-76. `hDexWeight` save/restore dropped — and $FF8B is a **live union** **[FIXED]**
pret saves the 2 bytes at `hDexWeight` and restores them before returning. The port dropped this
because "nothing else uses hDexWeight" — false: **`$FF8B` is an HRAM union** (`hDexWeight` /
`hMapStride` / `hPreviousTileset` / `hWarpDestinationMap` / `hItemPrice`, all aliased onto
`hBaseTileID` in pret). The dex is entered *from the overworld*, which parks `hPreviousTileset`
there. Save/restore restored, hoisted above the port-only feet/inches staging and replayed before the
`stc` so the carry contract survives.

### M-77. Three more hand-encoded charmap blobs **[FIXED]**
`HeightWeightText`, `PokeText` and `PokedexDataDividerLine` were raw `db` bytes. Migrated into
`tools/gen_menu_strings.py` → `assets/pokedex_strings.inc` (now 8 labels); `gb_text.encode`
reproduces the literals **byte-for-byte**. Note `PokeText` is `"#"` — the **$54 POKé text COMMAND**,
one byte, not four glyphs (M-16).

### M-78. The allowlist split, challenged and **deleted** **[FIXED]**
Deleted all nine `relocated_labels` entries pointing at `pokedex_entry.asm` and re-ran the lint: nine
mirror violations, as expected. Rather than re-write nine justifications for a split with no reason
to exist, the two files were **merged into the pret-mirrored path**, which makes every entry
unnecessary — none re-added. The tenth entry (`GetCryData` → `pokedex.asm`) was **already dead**:
part 1's M-66 moved that stub to `home_stubs.asm` and nobody removed the entry. Deleting it fired
nothing. Allowlist for this file: **empty**. Lint: **0 violations, 5 suppressed, exit 0.**

### SANCTIONED (tagged at the site)
- `dex_show_window` / `dex_mirror` / `dex_stage_flavor` — the window compositor and the
  stride-20 → GB_TILEMAP1 mirror standing in for `hAutoBGTransferEnabled`; the flavor stager copies
  the flat entry text into GB space because `TextCommandProcessor` reads GB pointers.
- `g_dex_flavor_active` — the port's full-page flavor mode (the 40×25 canvas has no 20×18 clip).
- `DelayFrame` in `.waitForButtonPress` — `DEVIATION(input)`; the port has no per-scanline joypad.
- `DROPPED IndexToPokedex` in `DrawDexEntryOnScreen` — the M-71 table-name squat; documented at the
  site, still cross-file.

### Verification
`make check` clean; `update_label_db && lint_pret_labels` **0 violations, exit 0**;
`make fidelity` **6/6 PASS** (no new masks). faithdiff: `ShowPokedexData` 4/4;
`ShowPokedexDataInternal` **9/9 calls** (was 7/9 — `RunDefaultPaletteCommand` + `PlayCry` restored);
`DrawDexEntryOnScreen` 11/12 (the one DROPPED is M-71); `Pokedex_PrepareDexEntryForPrinting` 2/2.
Remaining ADDED stores are the two documented faithdiff blind spots (`set/res n,[hl]`,
`ldh [rAUDVOL],a`, `ldcoord_a`) plus the tagged compositor calls.
**Rendered and looked at** (headless `DEBUG_G2` → `FRAME.BIN`, with the M-69 stale-image guard): the
RHYDON DATA page draws its border, front pic, name, `No.112`, `HT 6'03"`, `WT 265.0lb`, the divider
line and the flavor text.

---

## Row 17 findings (part 1) — `src/engine/menus/pc.asm`

The file's header made three claims. All three were false, and each one had cost the file
working code. Nothing about the PC needed to be special: it is an ordinary screen whose parts
were all already ported, and merely disbelieved.

### M-79. Every `PlaySound` / `WaitForSoundToFinish` dropped behind a **false** `TODO-HW` **[FIXED]**
Six calls — `SFX_TURN_ON_PC` (ActivatePC), `SFX_ENTER_PC` (×4: player's / OAK's / league / BILL's)
and `SFX_TURN_OFF_PC` (LogOff) — were commented out under *"TODO-HW: audio HAL (Phase 3)"*. Both
routines are ported and live in `src/home/audio.asm`, the SFX ids are in
`assets/audio_constants.inc`, and the engine plays sound. The same stale excuse cost row 9 its
`SFX_SWAP` (M-20). All six restored; the PC is audible again.

### M-80. `SaveScreenTilesToBuffer2` / `LoadScreenTilesFromBuffer2` "→ window-model save/restore" **[FIXED]**
Both were replaced by a shim that saved and restored **`g_window_count`** — i.e. saved *nothing*
(the screen it is supposed to preserve is `wTileMap`). Both routines are ported (`movie/title.asm`),
are pure `wTileMap` ↔ `wTileMapBackup2` WRAM copies with no compositor coupling, and are **already
called faithfully** from `home/start_menu.asm` and `overworld/cut.asm`. The only thing missing was a
one-line `global` on the *load* half — the body has been sitting there, unexported, the whole time,
which is why three separate files (`pc.asm`, `oaks_pc.asm`, `players_pc.asm`) each "discovered" they
had to invent a substitute. Export added; both calls restored. A `hide_window` rides with the restore
(SANCTIONED below), because a WRAM copy cannot drop a window layer.

### M-81. The four dialogs were HAND-DRAWN pages of HAND-ENCODED charmap bytes **[FIXED]**
`pc.asm` carried its own message engine — `pc_msg_open/close/border/show/page`, `pc_prompt` — and
**nine hand-encoded charmap strings** (the Tier-1 DATA violation, again). The justification was that
"the dialog projection collapses the window list (would hide any menu)". But nothing here needs a
window to survive the message: `PCMainMenu` redraws its box through `DisplayPCMainMenu` on every
pass. And the drawn-whole placer **cannot render text COMMANDS**, so the strings open-coded
`<PLAYER>` ($52) and `#`/POKé ($54) as literal glyph runs and placed the name buffer by hand.
All four streams (`_TurnedOnPC1Text`, `_AccessedBillsPCText`, `_AccessedSomeonesPCText`,
`_AccessedMyPCText`) now generate from pret's `data/text/text_3.asm` into `assets/pc_text.inc`
(`gen_menu_strings.py`), pret's four wrapper labels are restored (they were `missing`), and
`PrintText` prints them. ~130 lines of port-only plumbing deleted.

### M-82. `ActivatePC` is **unreachable** from the game **[OPEN — cross-file]**
`home/overworld_text.asm`'s `TextScript_PokemonCenterPC` (and `TextScript_ItemStoragePC` /
`TextScript_BillsPC`) sit behind `%ifdef M72_OVERWORLD_TEXTSCRIPTS`, under a comment saying *"All
target routines are NI"* — which is stale: `ActivatePC`, `PlayerPC` and `BillsPC_` all exist and link
today. So the entire PC subsystem is dead code in the shipped binary: **no player action can reach
it.** Out of this row's scope (the guard is in `home/`), filed. This is also why row 17 needs its own
harness to observe anything.

### SANCTIONED (tagged at the site)
- `mov dword [text_msgbox], msgbox_dialog` before each `PrintText` — the port's single printer takes
  its box geometry from a projection record (`msgbox.inc`); on the GB the box is a fixed literal
  inside `TextCommandProcessor`, so there is nothing to translate. Same as every other menu.
- `call hide_window` after `LoadScreenTilesFromBuffer2` — DEVIATION(window-compositor). The WRAM
  restore puts the map tiles back but the dialog is shown through the **window layer**, which no WRAM
  copy touches; without the drop the empty box stays on screen.

### Allowlist
**Nothing to challenge**: `pret_label_allowlist.json` has no entry naming any label in
`engine/menus/pc.asm` (verified by scanning every entry, not by trusting the row note). The four text
labels were simply `missing`; they are now `translated`.

### Verification
`make check` clean; build+link clean; `update_label_db && lint_pret_labels` **0 violations, 5
suppressed, exit 0**; `make fidelity` **6/6 PASS** (no new masks). faithdiff, all 8 labels: every pret
call now matched — `ActivatePC` 6/6, `PCMainMenu` 8/8, `BillsPC`/`OaksPC`/`PKMNLeague` 4/4 each,
`LogOff` 2/2, `ReloadMainMenu` 3/3, `RemoveItemByID` 1/1 (was 22 dropped calls in total). The residue
is the two documented blind spots: `DROPPED BillsPC/OaksPC/PKMNLeague (jp)` (the port reaches them by
`jz`, which the port matcher does not accept) and `ADDED [wMiscFlags]` (pret writes it with
`set/res n,[hl]`, invisible to the pret store matcher).
**Rendered and looked at** — new `DEBUG_PC` harness (`RunPCTest`, AutoKeyDrive photographs the open
dialog since the stream blocks on its `prompt`): the map is up, the box is drawn, and it reads
**"NINTEN turned on / the PC."** — i.e. the `<PLAYER>` command is expanded by the text engine, which
is precisely what the hand-encoded path could not do.
