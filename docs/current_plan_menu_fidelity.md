# Menu fidelity — de-bespoking the menu system against pret

> **STATUS — RESUMED 2026-07-13.** Rows 1–8 + 23 are DONE (9 of 24). The text-subsystem
> detour this audit was paused for is **complete and archived** (`docs/plans/text_engine.md`):
> the staging model is gone, `TX_FAR` works, and there is now a `DEBUG_TEXT=1..9` oracle for
> streamed text — which the golden harness still structurally does not render.
>
> **Resume by re-running the `/loop`** (one file per iteration: audit → fix → gate →
> commit). It picks the first row below that is `TODO`/`IN-PROGRESS` and works it. Update
> the row + append findings each iteration.
>
> **Where it stands.** Rows 1-9 + 23 are DONE (10 of 24). Row 9 took three parts (party half /
> bag half + seams / field-move dispatch) and turned up **nine** findings, M-19 through M-27.
> Next row is **10** (`trainer_card.asm` — it owns the 7 relocated `TrainerInfo_*` labels, the one
> `missing` label row 9 left behind (`TrainerInfo_FarCopyData`), and an allowlisted relocation to
> challenge). Row 13 is the last SHARED DRIVER; the rest are leaf screens. Rows 19 (`save`, 1080 ln) and 20 (`link_menu`, 1148 ln) are
> mostly TODO-HW SRAM/serial boundaries: low bug yield per line, and they MUST be split across
> iterations. **Row 22 is the highest-value row on the board and is sequenced last** — the
> battle move-menu family is missing entirely; it clears blocker B8 and unblocks Mimic + PP
> items. Consider promoting it.
>
> **What the audit found in 8 rows** — worth knowing before trusting any menu file's header:
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
> painted over the blanked rows. The hit rate on "audited file turns out to hold a real defect"
> is still 100%. The remaining rows are not a formality.

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
| 10 | `src/engine/menus/trainer_card.asm` | `engine/menus/start_sub_menus.asm` | TODO | | allowlisted relocation (7 labels) — challenge |
| 11 | `src/engine/menus/party_menu.asm` + `src/home/pokemon.asm` | `engine/menus/party_menu.asm`, `home/pokemon.asm` | TODO | | DEVIATION(text) ×3; legacy hand-encoded strings (debt) |
| 12 | `src/engine/menus/swap_items.asm` | same | TODO | | "PLACEHOLDERS below … ROOT migrates + deletes" |
| 13 | `src/engine/menus/field_moves.asm`, `display_text_id_init.asm` | `engine/menus/text_box.asm`, `display_text_id_init.asm` | TODO | | no self-declared divergence — verify by hand |
| 14 | `src/engine/menus/options.asm` | same | TODO | | the working reference for the window model |
| 15 | `src/engine/menus/naming_screen.asm` | same | TODO | | DEVIATION ×6 |
| 16 | `src/engine/menus/pokedex.asm`, then `pokedex_entry.asm` | `engine/menus/pokedex.asm` | TODO | | allowlisted split (9 labels) — challenge |
| 17 | `src/engine/menus/pc.asm`, `players_pc.asm`, `oaks_pc.asm`, `league_pc.asm` | same | TODO | | `pc_stubs.asm`: DisplayPCMainMenu / BillsPC_ |
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

### M-29. A message printed OVER the party screen has no correct projection [OPEN — not this row's file]
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
