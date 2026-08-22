# Current Plan: Text Engine — realign `home/text.asm` with pret

Workstream B of the pret-realignment arc (Workstream A was the data path mirror,
archived at `docs/plans/data_path_mirror.md`).

## The gap, measured 2026-08-22

`dos_port/tools/label_status --subsystem home` reports `home/text.asm` at
**52 missing / 4 translated of 56**. That is **52 of home's 97 remaining gaps —
54% of everything left in `home/`, in one file.**

The four that survive by name: `PlaceNextChar`, `PlaceString`, `TextBoxBorder`,
`TextCommandProcessor`.

**The `missing` flag is true as a symbol claim and false as a functionality
claim.** Every pret `TextCommand_*` handler exists as an inline branch in the
port's `TextCommandProcessor` (`src/home/text.asm:1122-1150` — the full
`TX_START`/`RAM`/`BCD`/`MOVE`/`BOX`/`LOW`/`PROMPT_BUTTON`/`SCROLL`/`START_ASM`/
`NUM`/`PAUSE`/`SOUND`/`DOTS`/`WAIT_BUTTON`/`FAR` set), and every control-char
handler exists as an inline branch in `PlaceNextChar`. The port is 1517 lines
against pret's 647.

So this plan **moves no behaviour**. It restores pret's label granularity, and
annotates the bodies that genuinely cannot match.

### What is a real customization and stays

Three families, all load-bearing, none of which is a reason to drop a *label*:

1. **The DJGPP memory model.** pret's `PlaceString` reads DE in one address
   space, so `print_name` can funnel `wPlayerName` (WRAM) and `PlacePOKeText`
   (ROM) into one `PlaceCommandCharacter` tail. The port has two: `place_flat_str`
   for DS-relative program-image constants, `[ebp+edx]` for WRAM names. The
   handlers still get their pret names and entry points; only the tail forks.
2. **The projection layer.** pret hard-codes `ldcoord_a 18, 16` / `hlcoord 1, 13`
   against a 20×18 screen. The port's canvas is 40×25 and the dialog box is a
   window descriptor, so these go through `text_row_stride`, `text_line2`,
   `text_arrow_pos`, `text_prompt_hook`, `sync_dialog_window`. Existing
   `DEVIATION{class=projection}` territory.
3. **Genuinely port-only machinery** with no pret counterpart: the msgbox
   projection records (`text_msgbox`/`msgbox_dialog`), `manual_text_scroll`'s
   window hijack, `g_dex_flavor_active` + `dex_flavor_full_mirror`,
   `done_sentinel_flat` (see memory `regression-battle-anim-interp-runtime-crash`).
   These keep descriptive port names — they are not pret labels.

---

## The 52, decomposed into three stages

Counted and reconciled: 8 + 18 + 26 = 52.

> **Stage boundary corrected 2026-08-22, mid-execution.** Stage 1 was
> written as 10 and delivered 8. `ContCharText` and `TextIDErrorText` are
> not `db` strings like the other eight — they are `text_far` wrappers whose
> only consumers are pret's `ContText` and `NullChar`, both of which are
> Stage 3. Generating them in Stage 1 would have landed two data labels with
> no caller; they moved to Stage 3 so each arrives with its consumer.

### Stage 1 — data labels (8). Lowest risk, no code motion. **DONE**

`EnemyText`, `PCCharText`, `PlacePKMNText`, `PlacePOKeText`, `RocketCharText`,
`SixDotsCharText`, `TMCharText`, `TrainerCharText`.

These are pret `db` strings. The port had them as port-invented `str_*` labels in
`assets/home_text_runtime_strings.inc`. The generator now emits the pret name as
PRIMARY, **with its own `global`** in the `.inc`.

**The `global` placement is load-bearing and was measured 2026-08-22.** Emitting
`PTile:` in a generated `.inc` while the `global PTile` sat in the carrier `.asm`
produced a `local_shadow` finding under `--strict-claims`: the scanner recorded
`is_global=0` in a file that is not the selected provider. `battle_text.inc` does
not trip it because it emits `global PoofText` *inside the .inc*. Follow
`battle_text.inc`. And `dos_port/assets/%` is explicitly exempt from the `mirror`
rule (`lint_pret_labels:229-247`), so a generated `.inc` is the correct home for
these even though they are `home/` (core-tier) labels — `PoofText` is the
standing precedent.

- `[x]` 1.1 `gen_runtime_strings.py` emits the pret names as PRIMARY, with
  their `global` in the `.inc`; the port-invented `str_*` names are gone
  (all 8 consumers were in `src/home/text.asm` alone) except `str_dot`,
  which has no pret counterpart. Emitted bytes are unchanged.
- `[x]` 1.2 `update_label_db`: exactly 8 rows `missing -> translated`
- `[x]` 1.3 gates: lint 0, `--strict-claims` 0, `static_gate`, `fidelity-full`

### Stage 2 — `TextCommand_*` (18). Mechanical, one routine.

`NextTextCommand`, `TextCommandJumpTable`, `TextCommandSounds`, and
`TextCommand_{BOX,START,RAM,BCD,MOVE,LOW,PROMPT_BUTTON,SCROLL,START_ASM,NUM,PAUSE,SOUND,DOTS,WAIT_BUTTON,FAR}`.

Every one is already a `.cmd_*` local under `TextCommandProcessor`. Promote each
to its pret name.

**`TextCommandJumpTable` is the one open design decision — see "Decision" below.**

- `[ ]` 2.1 promote the 15 `.cmd_*` bodies + `.next_cmd` + `.TextCommandSounds`
- `[ ]` 2.2 rebind every `.local` that the promotions re-scope (see Hazard 1)
- `[ ]` 2.3 `TextCommandJumpTable` per the decision
- `[ ]` 2.4 `faithdiff TextCommandProcessor` + each promoted label
- `[ ]` 2.5 gates incl. `fidelity-full`; `DEBUG_PERF` before/after if 2.3 lands

### Stage 3 — `PlaceNextChar`'s char handlers (26). Highest risk.

`NextChar`, `NullChar`, `PlaceCommandCharacter`, `PrintPlayerName`,
`PrintRivalName`, `TrainerChar`, `TMChar`, `PCChar`, `RocketChar`, `PlacePOKe`,
`SixDotsChar`, `PlacePKMN`, `PlaceMoveTargetsName`, `PlaceMoveUsersName`,
`PlaceDexEnd`, `ContText`, `PromptText`, `DoneText`, `Paragraph`, `PageChar`,
`_ContText`, `_ContTextNoPause`, `ScrollTextUpOneLine`, `ProtectedDelay3`,
plus the two `text_far` wrappers moved down from Stage 1: `ContCharText`
(consumed by `ContText`) and `TextIDErrorText` (consumed by `NullChar`).

`ScrollTextUpOneLine` and `ProtectedDelay3` are already standalone port routines
(`scroll_text_up`; and the port's `Delay3` already preserves EBX itself, so
`ProtectedDelay3`'s `push ebx / call Delay3 / pop ebx` body is faithful and free).
The other 22 are `.handle_*` locals.

- `[ ]` 3.1 promote the 22 `.handle_*` bodies to their pret names
- `[ ]` 3.2 rename `scroll_text_up` -> `ScrollTextUpOneLine`, add `ProtectedDelay3`
- `[ ]` 3.3 rebind the shared tails (Hazard 1) — the bulk of the work
- `[ ]` 3.4 preserve pret's fallthrough order exactly (Hazard 2)
- `[ ]` 3.5 `DEVIATION{class=data-model}` on the `print_name` fork,
  `DEVIATION{class=projection}` on the coordinate-bearing handlers
- `[ ]` 3.6 generate `_ContCharText` / `_TextIDErrorText` + their wrappers
- `[ ]` 3.7 `faithdiff` each; gates incl. `fidelity-full`

---

## Hazards, ranked

**Hazard 1 — NASM local-label rebinding is the dominant risk, and it is
structural, not incidental.** A NASM `.local` binds to the last non-local label
above it. `PlaceNextChar` currently owns ~40 locals, and the handlers share tails:
`.advance`, `.glyph`, `.not_term`, `.next_push`. Promoting *one* handler to a
global re-scopes every `.local` below it, so every later reference to `.advance`
silently retargets or fails to assemble.

This is not avoidable by ordering — it must be handled head-on:
- shared tails that HAVE a pret name become that name (`.advance` is pret's
  `NextChar`; `.not_term` is pret's `PlaceNextChar.NotTerminator`, referenced by
  pret's own `PageChar`);
- shared tails with NO pret counterpart become file-scope port-only labels
  (`text_place_glyph`, …), not `.local`s.

Do Stage 3 as one atomic rewrite of that routine's label space. A partial
promotion is the worst of both worlds.

**Hazard 2 — fallthrough.** pret has at least three load-bearing ones here:
`PromptText` -> `DoneText`, `PlaceMoveUsersName.place`'s enemy branch ->
`PlaceCommandCharacter`, `_ContText` -> `_ContTextNoPause`. Restoring names must
preserve pret's ORDER. **Measured the hard way this same session** (commit
`8141ae0b8`): inserting a body between `TryEvolvingMon` and `EvolutionAfterBattle`
severed their fallthrough and no mon evolved — with lint 0, `--strict-claims` 0,
`static_gate` 8/8 and `faithdiff` CLEAN. Only the golden suite saw it. See
memory `regression-pokemon-evolution-fallthrough-severed`.

**Hazard 3 — no golden gates the text engine as such.** Text fidelity is
incidental to the menu/dialog scenarios. The suite will catch a gross break, but
a subtle one (a `<PARA>` landing one row off, a `<PROMPT>` arrow at the wrong
cell) may pass. Mitigation: `tools/pixelcheck.sh` on a dialog-heavy scenario
before and after each stage, and consider a dedicated text-engine scenario as
Stage 4.

**Hazard 4 — hot path.** `PlaceNextChar` runs per rendered character. Take a
`DEBUG_PERF` baseline before Stage 2/3 and compare after.

---

## Decision needed: `TextCommandJumpTable`

pret dispatches text commands through a `dd` jump table. The port uses a 15-deep
`cmp`/`je` ladder.

- **For restoring it:** it is the pret structure, it closes the label, and it is
  *faster* than a 15-deep ladder on the hottest text path.
- **Against:** CLAUDE.md's Evidence policy records that `dd Label` dispatch tables
  emit no call-graph edge, so every handler drops to `not-proven-reached` and
  `faithdiff`'s call comparison over `TextCommandProcessor` goes blind. The ladder
  is currently fully modelled.

The same trade already exists tree-wide for `ItemUsePtrTable` /
`MoveEffectPointerTable`, so it is a known, accepted cost rather than a new one.

**RULED 2026-08-22 (maintainer): RESTORE THE TABLE.** Stage 2 builds pret's `dd`
dispatch table and the ladder goes. The reachability blind spot is accepted, not
worked around: after Stage 2 the 15 `TextCommand_*` handlers read
`not-proven-reached` and `faithdiff TextCommandProcessor`'s call comparison is
blind on this routine. **Do not later cite either as evidence that a handler is
dead** — that is exactly the misreading CLAUDE.md's Evidence policy warns about
for `dd Label` tables, and this is now a deliberate instance of it. Cite
`--callers`, the table row itself, or runtime evidence.

A tooling fix (teaching the dependency graph to read `dd <Label>` rows inside a
recognised dispatch table as edges) would retire the blind spot for every such
table in the tree. It was offered and NOT chosen; it stays available as separate
tooling work and is deliberately out of this plan's scope.

---

## Definition of done

- `label_status --subsystem home` reports `home/text.asm` **56/56 translated**,
  taking home's missing count from 97 to 45.
  (Stage 1 took it to 89.)
- Every remaining structural difference carries a machine-parsed `DEVIATION{}`.
- `lint_pret_labels` 0, `--strict-claims` 0, `static_gate` PASS.
- `make fidelity-full` reported = registered, non-zero = 0, at each stage.
- No behaviour change: this is a naming and structure pass, and any observed
  behaviour delta is a defect in the pass, not an improvement.
