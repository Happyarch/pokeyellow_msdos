# Current plan — text engine: flat stream pointers, TX_FAR, kill the staging model

Status: **COMPLETE** — Stages 0–4 all DONE. Opened and closed 2026-07-13.

## Closing summary

`TextCommandProcessor` walked its command stream **EBP-relative**, so it could only
read a stream living inside the 64 KB emulated GB address space — but every text
stream in the port is **flat program-image `.data`**. The port bridged that with a
**staging copy**: `PrintText` blind-copied 256 bytes of the caller's stream into a
WRAM buffer and ran TCP on the copy, and seven other call sites open-coded the same
thing. Making TCP's stream pointer flat (Stage 1) removed the *need* for staging and
made `TX_FAR` expressible (Stage 2); Stages 3–4 then deleted the staging model.

What it bought, beyond the cleanup:

* **`TX_FAR` ($17) was outright broken** — it read a 3-byte GB offset while the
  `text_far` macro emits a 4-byte flat `dd`: wrong pointer *and* a one-byte stream
  desync. Latent only because its producers are unlinked (T-1). Now works (Stage 2).
* **Four real dialogs rendered garbage** (T-8) — the blind 256-byte copy truncated
  any longer stream mid-command, and TCP then walked off into WRAM. Blue in the
  champion's room (347 B), ERIKA (308 B), OAK's hall-of-fame speech (302 B) and
  MR.FUJI (280 B) were all over the line. Observed and fixed; see T-8.
* **The in-battle nickname prompt printed garbage** (T-9) — `AskName`'s battle branch
  passed its stream in EAX while `PrintText` has always read ESI. Fixed.

`PrintTextStaged` survives, but only for its real purpose: streams **composed in WRAM
at run time** (`DisplayUsedMoveText`, `ComposeStatIntro` splice a nickname / a TX_RAM
operand). That is not a workaround — it is a second entry for a second kind of stream.

Verified: the 14-case text oracle (12 pre-existing captures **byte-identical**, plus
the two new >256-byte probes rendering their tails), `make check`, `lint_pret_labels`
0 violations, `make fidelity` 6/6.

---

## The defect (what this plan is fixing)

`TextCommandProcessor` (TCP) walked its command stream **EBP-relative**
(`movzx eax, byte [ebp + esi]`), i.e. it could only read a stream living inside the
64 KB emulated GB address space. On the GB that is free — text *is* in addressable
ROM. In the port, every text stream is **flat program-image `.data`** (the generated
`assets/*_text.inc`). The two models don't meet, so the port bridged them by
**staging**: `PrintText` `rep movsb`-copied `NPC_DIALOG_LEN` (256) bytes of the
caller's flat stream into `NPC_DIALOG_BUF` (0xCB00) and ran TCP on the copy. Seven
other call sites open-coded the same copy.

Three consequences:

1. **Staging is fragile.** The copy length is a *guess* — it must exceed the stream
   but not run off the end of `.data`. `PrintText` copies a blind 256 bytes and
   relies on the generators padding their `.inc` tails; `PrintBattleText` once
   guessed 80 and page-faulted on the 118-byte `TryingToLearnText`. A stream longer
   than 256 bytes is silently truncated and TCP walks off into WRAM.
2. **`TX_FAR` ($17) was broken.** The `text_far` macro (`include/gb_text.inc:141`)
   emits `db TX_FAR` + `dd <flat 32-bit label>` — **4** operand bytes — while
   `.cmd_far` read **3** (addr_lo, addr_hi, bank) and combined them into a *GB
   offset*. Wrong pointer **and** a one-byte stream desync.
3. **No oracle.** The 6 golden scenarios render no streamed text at all. A previous
   attempt at this fix (reverted; post-mortem `4a5f366a`) assembled, linted, and
   passed `make fidelity` 6/6 while rendering `REDRED` in a live dialog.

**Root cause of 1 and 2 is the same**: TCP's stream pointer was EBP-relative. Making
it flat removes the need for staging *and* makes TX_FAR trivially correct.

What deliberately does **not** change: TCP's **operands** (TX_RAM / TX_NUM / TX_BCD
source addresses, TX_MOVE / TX_BOX destinations) are genuinely GB-space addresses in
pret and stay EBP-relative. The **cursor** (EBX) stays EBP-relative — it indexes the
tilemap. Only the **stream pointer** went flat.

---

## Stages

### [x] Stage 0 — the oracle (DONE)
No harness exercised a text stream *directly*; every one reached text incidentally
through a whole game path, and none covered TX_FAR / TX_NUM / TX_BCD / `<PARA>` at
all. Added **`DEBUG_TEXT=<1..7>`** (`src/debug/debug_dump.asm:RunTextTest`): seeds
the overworld, runs one probe stream through the real `PrintText` in the real dialog
window, dumps `FRAME.BIN`, exits.

| case | command |
|---|---|
| 1 | plain + `<LINE>` |
| 2 | `<PARA>` (page break) |
| 3 | TX_RAM (splice from WRAM) |
| 4 | TX_NUM |
| 5 | TX_BCD |
| 6 | **TX_FAR** |
| 7 | TX_DOTS |
| 8 | **a 289-byte stream** — past the old 256 B staging window (T-8) |
| 9 | the same, through `ShowTextStream` (the overworld NPC path) |

Cases 8/9 end on a page reading **`TAIL OK`**, which lives past byte 256 and can only
render if the whole stream was walked. The generator *asserts* the probe exceeds the
window (`_long_stream()` raises if it shrinks under 256) — a probe that quietly fell
back under the limit would pass while testing nothing.

Streams are Tier-1 data → generated by `tools/gen_text_oracle.py` →
`assets/text_oracle.inc`. Regression net (already-working screens): `DEBUG_ITEMTM`
(frames 40/70/110), `DEBUG_BATTLE_INTRO` (TX_RAM), `DEBUG_LEARNMOVE`.

Capture scripts live in the session scratchpad (`cap.sh`, `oracle.sh`) — **recreate
them, they are not in the repo**; see "How to re-run the oracle" below.

### [x] Stage 1 — TCP stream pointer → flat (DONE, bit-exact)
ESI is now a flat linear pointer inside TCP. `PrintText` still stages and enters with
`lea esi, [ebp + NPC_DIALOG_BUF]`, so no staged caller changed behaviour. Three direct
TCP callers were converted to pass a flat pointer: `home/window.asm`
(`PrintText_NoCreatingTextBox`), `engine/menus/party_menu.asm`,
`engine/menus/pokedex_entry.asm`.

**Verified bit-exact**: 11 of 12 oracle captures byte-identical to the pre-change
baseline; the 12th is TX_FAR, which is the thing that was broken.

### [x] Stage 2 — TX_FAR reads its `dd` (DONE)
`.cmd_far` now reads the 4-byte flat pointer the macro actually emits, recurses, and
resumes the outer stream at ESI+4. pret's `push/pop af` ROM-bank save/restore is
dropped **with** the bank byte (there is no bank in a flat pointer, and the rROMB
write is already a no-op in `home/bankswitch.asm` — it would save and restore the
same value).

**Verified**: `DEBUG_TEXT=6` went from *crashing* (no `FRAME.BIN` at all) to
rendering `FARSPLICEDEND` — outer stream, recursive splice, and outer-stream resume
all correct.

### [x] Stage 3 — drop staging (DONE)
`PrintText` stopped copying first: it now does `push esi` / `pop esi` around the box
draw, which is exactly pret's own `push hl` / `pop hl`. Then each open-coded stager
was converted, re-running the oracle after each step.

| file | what changed |
|---|---|
| `src/home/window.asm` | `PrintText` no longer copies. `PrintTextStaged` became a one-line `lea esi, [ebp + NPC_DIALOG_BUF]` prologue that falls through into it. |
| `src/engine/overworld/map_sprites.asm` | `ShowTextStream` prints the flat stream in place (its ECX length param is gone); `TrainerEncounterFlow` likewise. **Both 256-byte bounds deleted** — see T-8. |
| `src/home/overworld_text.asm` | the sign dispatch carried the same bound; deleted. |
| `src/scripts/pallet_town.asm` | dropped the now-dead length loads. |
| `src/engine/items/item_effects.asm` | `iu_print_text` takes ESI alone; **15 dead `mov ecx, [X_ref + 4]` length loads removed**, so the sites now read exactly like pret's `ld hl, X / call PrintText`. |
| `src/engine/menus/party_menu.asm` | passes the flat stream straight to TCP. |
| `src/engine/menus/naming_screen.asm` | both branches collapse into one `PrintText`; **fixes T-9**. |
| `src/home/text_script.asm` | its 5 `PrintTextStaged` calls loaded a *flat* label into ESI, which `PrintTextStaged` then threw away — dead-broken. (Unlinked, so nothing observed it; see T-1.) Now `PrintText`. |

**`battle/core.asm` was NOT converted, and that is correct.** *Both* of its sites —
`DisplayUsedMoveText` (~854) and `ComposeStatIntro` (~929); the earlier plan wrongly
said only the latter — **compose** their stream in WRAM byte-by-byte at run time
(splicing a nickname, or a `TX_RAM` operand). Those streams genuinely live in GB
space, so they keep `PrintTextStaged`. That is the entry point's real purpose and why
it survives; a comment there now says so. Do not "fix" them.

### [x] Stage 4 — retire the scaffolding (DONE)
`NPC_DIALOG_BUF` / `NPC_DIALOG_LEN` **survive** — the WRAM composers above need them —
but `include/gb_memmap.inc` now documents them as composed-stream scratch, with an
explicit "don't route a flat stream through here". The `gen_battle_text.py` 256-byte
tail pad, which existed *only* to keep the blind copy in bounds, is deleted. Every
comment asserting the staging model was corrected (`window.asm`, `map_sprites.asm`,
`item_effects.asm`, `naming_screen.asm`, `pallet_town.asm`, `battle/core.asm`).

**Debt deliberately left, not swept in:** `naming_screen.asm:DoYouWantToNicknameText`
is still a hand-encoded charmap string (a pre-existing Tier-1 violation). Its comment
used to justify the inline by claiming TX_FAR could not reach flat `.data` — now
false, and corrected in place. It should become a real `text_far` once
`data/text/text_3.asm` has a generator. `pokedex_entry.asm`'s staging comments are
*not* liars: `dex_stage_flavor` really does compose its flavour text in WRAM.

---

## How to re-run the oracle (not in the repo — recreate in scratchpad)

`cap.sh <out.bin> <make flags…>`: `make -C dos_port image <flags>` → copy `PKMN.IMG`
to a scratch dir → **`mdel -i "$SCRATCH/pkmn.img@@1048576" ::FRAME.BIN`** → patch
`dosbox-x.conf` (imgmount the scratch copy; append `exit` after `PKMN.EXE`) →
`SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy timeout -s KILL 200 dosbox-x -defaultdir
"$SCRATCH" -defaultconf -conf "$SCRATCH/dosbox-x.conf"` → `mcopy -n -i
"$SCRATCH/pkmn.img@@1048576" ::FRAME.BIN "$OUT"`. Render with
`dos_port/tools/render_frame.py`.

Cases: `DEBUG_TEXT=1..7`; plus `SKIP_TITLE=1 DEBUG_ITEMTM=1 AUTOKEY_DUMP_FRAME=40|70|110`,
`SKIP_TITLE=1 DEBUG_BATTLE_INTRO=1`, `SKIP_TITLE=1 DEBUG_LEARNMOVE=1`.

A/B a change by capturing a tagged baseline, `git stash push -- <the engine files>`,
capturing again, and `cmp`-ing. **Everything except the thing you meant to change must
be byte-identical.**

---

## Findings

### T-1 — `text_script.asm` is unlinked, and its TX_FAR streams are dead
`home/text_script.asm` is in a **check-only** Makefile list, not the link list
(Makefile:1052 records its closure as 15 symbols deep, `Joypad` undefined). Its
`db 0x17 / dd <label>` streams therefore never executed, which is the only reason the
broken TX_FAR never crashed anything. Recorded so nobody concludes TX_FAR "works
because nothing broke". The other producer is `trainer_engine.asm:808`
(`TrainerEndBattleText`); `gen_battle_text.py` *inlines* far text instead of emitting
the command.

### T-2 — the 256-byte staging copy has no bound check [RESOLVED in Stage 3]
`PrintText` copied exactly `NPC_DIALOG_LEN` bytes from the caller's flat pointer with
no regard for the stream's length or where `.data` ends. This was assumed harmless
("the longest real stream is 118 bytes"). **That assumption was wrong** — see T-8.
Stage 3 removed the copy entirely.

### T-3 — **`FRAME.BIN` captures can silently return a STALE frame** [FIXED in the harness; affects every FRAME.BIN user in this repo]
`PKMN.IMG` ships a **stale `FRAME.BIN` baked in** (mine was dated 2026-07-10). A
headless run that crashes *before* dumping leaves that old frame in the image, `mcopy`
pulls it out, and **the capture looks like a clean success**. This bit this session:
`DEBUG_TEXT=6` (broken TX_FAR) crashed and returned a plausible-looking overworld
frame that I nearly accepted as "TX_FAR renders nothing". Any tool that pulls
`FRAME.BIN` out of the image must `mdel` it first, so a frame that is found is
definitionally this run's. Worth pushing into `tools/pixelcheck.sh` / `goldencheck.sh`
if they have the same hole — **not yet checked**.

### T-4 — pret's `wTextDest` is write-only; the port drops it [WONTFIX, justified]
pret's TCP stores the cursor to `wTextDest` on entry (`home/text.asm:331/333`, also
428/431). `wTextDest` is **never read anywhere in the pret tree** — grep it. The port
does not implement it. `faithdiff TextCommandProcessor` reports it as a DROPPED store;
that is expected and correct. Do not add dead writes to silence the tool.

### T-5 — faithdiff's TCP call list is structurally noisy [expected, not a defect]
pret's TCP dispatches through `TextCommandJumpTable` (`jp hl`) to separate
`TextCommand_*` labels, so pret's TCP body contains **zero** calls. The port inlines
every handler as a local `.cmd_*` label, so faithdiff reports 7 ADDED calls
(`PlaceString`, `PrintNumber`, `PrintBCDNumber`, `TextBoxBorder`,
`TextCommandProcessor` (the TX_FAR recursion), `manual_text_scroll`,
`scroll_text_up`). All are pret's own handler bodies, inlined. Likewise DROPPED
`[wLetterPrintingDelayFlags]` vs ADDED `[W_LETTER_PRINTING_DELAY]` is one store under
the port's memmap name, not a divergence.

### T-6 — the other worktree's F-9 is a misdiagnosis [handoff left in place]
`worktree-fidelity-expansion` stopped on **F-9** ("the port's overworld dialog box has
the wrong geometry AND the wrong line spacing"), and assigned the fix to this
subsystem. **The line-spacing half is wrong.** Measured from rendered pixels
(`DEBUG_LEARNMOVE`, ink per 8-px band), the dialog occupies pixel-rows 15–20: top
border, blank, **text line 1 (17)**, **blank (18)**, **text line 2 (19)**, bottom
border — i.e. the GB's 2-row spacing, faithfully. The confusion is that the overworld
dialog scratch is **stride 20, not 40** (`msgbox_dialog`: `dd 20 ; MB_STRIDE —
GB-shaped scratch`; `MB_LINE1` = flat 281, `MB_LINE2` = flat 321, which are 2 rows
apart *at stride 20*). Read as a 40-wide canvas they look like adjacent rows 7/8 —
exactly F-9's table. That branch also **predates `2c33f7a6`** (row 23, "one PrintText
— the message box is a projection record"), so it was measuring `PrintText_Overworld`,
a forked name that no longer exists. A full handoff + merging guidance is written into
that worktree's `docs/current_plan_fidelity_expansion.md` under F-9 (**uncommitted**
there). Nothing in `text.asm` needs to change for their `sign_pallet` golden.

### T-7 — TX_START_ASM ($08) is a silent no-op in the port [OPEN, not scoped here]
pret's `TextCommand_START_ASM` genuinely *runs code* (`ld de, NextTextCommand / push
de / jp hl`). The port skips the byte silently. `trainer_engine.asm:808`'s
`TrainerEndBattleText` depends on it (`db 0x17 … db 0x08`). Blocks the script engine
along with T-1; not fixed here because nothing linked reaches it yet.

### T-8 — **four real dialogs rendered garbage**: streams over 256 bytes were truncated [FIXED in Stage 3]
The staging copy was a blind `NPC_DIALOG_LEN` (256) bytes, so any longer stream was cut
**mid-command** and TCP then walked off the end of the buffer into WRAM. T-2 dismissed
this as theoretical on the grounds that "the longest real stream is 118 bytes". Nobody
had measured. Measuring `assets/npc_dialogs/*.inc` (940 streams) finds **four over the
line**, and they are not obscure:

| stream | bytes |
|---|---|
| `champions_room_rival_0_text` (Blue, champion's room) | 347 |
| `celadon_gym_erika_0_text` (ERIKA) | 308 |
| `hall_of_fame_oak_0_text` (OAK's hall-of-fame speech) | 302 |
| `pokemon_tower_7f_mr_fuji_2_text` (MR.FUJI) | 280 |

Observed directly, not inferred. Oracle case 8 is a 289-byte stream ending in
`TAIL OK`; captured against the old engine it renders **`9PIKACHU$● / NINTEN`** —
truncated at 256, TCP walking into the WRAM that follows (the harness's seeded
`wStringBuffer`). Against the flat engine it renders `IF YOU CAN READ / TAIL OK`.

Two independent bounds *silently skipped* the dialog rather than truncating it
(`map_sprites.asm:CheckNPCInteraction` and `overworld_text.asm`'s sign dispatch both
did `cmp <len>, 256 / jge .done`), so on those paths the four dialogs displayed
**nothing at all**. Both bounds are deleted: nothing needs a length any more.

**No golden covers streamed text**, which is why this survived so long. Cases 8/9 are
the standing regression net for it.

### T-9 — `AskName`'s in-battle nickname prompt printed whatever was in ESI [FIXED in Stage 3]
`naming_screen.asm:AskName` did `mov eax, DoYouWantToNicknameText / call PrintText` on
the battle branch, with the comment "battle PrintText copies EAX itself". **There is
one `PrintText` and it has always read ESI** (`grep -rn '^PrintText:' src/` — a single
definition, `home/window.asm`). So in battle it printed whatever `GetMonName` happened
to leave in ESI. The overworld branch, which set ESI, worked — which is presumably why
this was never noticed.

A port defect, not a Gen-1 bug, so it is simply fixed (no `BUG_FIX_LEVEL` guard). Both
branches now collapse into a single `PrintText` that differs only in which msgbox
projection it selects.

This is the third stale comment in this subsystem to assert something the code did not
do (cf. the TX_FAR header, the `naming_screen` TX_FAR justification). Treat comments in
this area as unverified hypotheses.
