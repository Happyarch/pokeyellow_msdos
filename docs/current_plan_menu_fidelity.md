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
| 1 | `src/home/window.asm` | `home/window.asm` | DONE | (this commit) | M-1 (`HandleMenuInput_` split + blink + AB SFX), M-2 (list ▼ coord), M-3 (`PrintText` substitution), M-4 (stale `SFX_PRESS_AB`) |
| 2 | `src/home/textbox.asm` | `home/textbox.asm` | TODO | | |
| 3 | `src/engine/menus/text_box.asm` | `engine/menus/text_box.asm` + `data/text_boxes.asm` | TODO | | 4× DEVIATION incl. `PlaceMenuCursor` hardcoded-row model |
| 4 | `src/home/list_menu.asm` | `home/list_menu.asm` | TODO | | DEVIATION(stride); "bespoke bag list" A/B remnants |
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
| 23 | **`PrintText` / `PrintText_NoCreatingTextBox`** | `home/window.asm` | **NEXT** | | opened by row 1 — see **M-3**. The pret home routine is unported; a battle-scope wrapper squats on the label and 9 non-battle files print through the battle box. **User-directed priority (2026-07-13): fix, do not defer.** Cross-cutting (~120 call sites), so it takes its own iteration rather than riding row 1. |

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

### M-2. The list-menu ▼ is drawn at box-relative (14,9), so the new blink can't reach it **[OPEN]**
**File:** `dos_port/src/home/list_menu.asm:761,783` (row 4's scope — filed, not touched)
**pret:** `home/list_menu.asm:517` — the ▼ lands at `hlcoord 18, 11`, the exact tile
`HandleMenuInput_` blinks.
**What's wrong:** the port's list menu renders into a **box-relative scratch** (`LIST_STRIDE 20`,
arrow at `LIST_DOWN_ROW 9`, `LIST_DOWN_COL 14`), not at pret's screen coordinate. So M-1's
now-faithful blink call (which targets row 11 / col 18 of the current stride, as pret does)
lands on a different cell and is inert for the bag/PC lists — the arrow stays steady. This is
harmless today (the blink is guarded: it only acts on a tile that already *is* a ▼, so it
neither draws nor erases anything elsewhere), but it means the `bag_menu` golden's
"MORE-list arrow" mask stays live until row 4 reconciles the list's coordinate model.
**Fix:** row 4 — make the list menu's ▼ land at the pret-projected (18,11), then re-check the
mask in `tools/golden_diff.py`.
**Severity:** low (cosmetic)

### M-3. `PrintText` is a battle-scope substitution; pret's `PrintText` is unported **[OPEN — row 23]**
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

### M-4. `naming_screen.asm` hardcodes a stale `SFX_PRESS_AB` **[OPEN]**
**File:** `dos_port/src/engine/menus/naming_screen.asm:110-114` (row 15's scope — filed, not touched)
**What's wrong:** it defines `SFX_PRESS_AB equ 0x3E` locally under a `; TODO-HW(audio)` comment
claiming the real id is unavailable. The audio engine is live and the generated
`assets/audio_constants.inc` gives `SFX_PRESS_AB equ 0x90`. The local equ is both wrong and
stale — 0x3E is some other sound.
**Fix:** row 15 — delete the local equ + TODO-HW, `%include "assets/audio_constants.inc"`, and
add the `.inc` to `naming_screen.o`'s Makefile prerequisites (as row 1 did for `window.o`).
**Severity:** medium (wrong SFX id played on every naming-screen keypress)

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
- **`PrintText`** (`relocated_labels`) — challenged. Deleted it; the linter fired exactly one
  mirror violation, which is **correct**: this is not a relocation at all (see M-3). Re-added
  with a hand-written `why` that states what it really is (a substitution held only to keep the
  link together) and names M-3 + the condition for its deletion. The boilerplate
  *"pret home/window.asm split across port files (draft Session H)"* is gone.
- **`EnableAutoTextBoxDrawing` / `DisableAutoTextBoxDrawing` / `AutoTextBoxDrawingCommon`** —
  also `home/window.asm` labels, but their port file is `src/home/auto_textbox.asm`, which is
  **row 6's** scope and whose ledger line already reads *"allowlisted relocation ×3 —
  challenge"*. Deliberately left for that row rather than challenged twice.
