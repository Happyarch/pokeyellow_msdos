# Menu fidelity — de-bespoking the menu system against pret

> **STATUS — OPEN, started 2026-07-13.** Driven by a `/loop` (one file per iteration:
> audit → fix → gate → commit). This file is the loop's on-disk state: it picks the first
> row below that is `TODO`/`IN-PROGRESS` and works it. Update the row + append findings
> each iteration.

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
| 5 | `src/home/yes_no.asm` | `home/yes_no.asm` + `engine/menus/text_box.asm` | TODO | | allowlisted relocation — challenge |
| 6 | `src/home/auto_textbox.asm` | `home/window.asm` (split) | TODO | | allowlisted relocation ×3 — challenge |
| 7 | `src/home/start_menu.asm` | `home/start_menu.asm` | TODO | | |
| 8 | `src/engine/menus/draw_start_menu.asm` | same | TODO | | |
| 9 | `src/engine/menus/start_sub_menus.asm` | same (861 ln) | TODO | | expect 2 parts; DEVIATION(icons) |
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
