# Handoff

**This is the ONE handoff file. Overwrite it; do not create `handoff_s17.md`.**

Sessions 10, 13 and 14 each left their own `handoff_s*.md` behind and nothing ever
deleted them, so by s15 the repo root held three handoffs with no way to tell from
the filenames which was current. All three were purged. Rewrite *this* file at the
end of your session. Anything that outlives one session belongs in **stigmergy**,
not here; this is a pointer sheet, not a record.

**Written:** 2026-07-26 (session 16) · **Branch:** `master`

Everything below is measured. **Re-measure anything you rely on**, including these
numbers.

---

## 0. ⚠ READ FIRST — THERE IS FINISHED, VERIFIED WORK SITTING UNCOMMITTED

**Chunk 14 is complete and fully verified but COULD NOT BE COMMITTED**, because the
registry bless (§1) is outstanding and `.githooks/pre-commit` blocks every commit
that stages anything under `dos_port/`. It is in the working tree right now:

```
git status --short          # ~15 tracked entries: 1 delete, 2 renames, the rest edits
```

It is **9 relocated rows** across four units, with `make fidelity-full` green
(MAKE_EXIT=0, 33 PASS) and the move battery reconciled (+11 residual, decomposition
== measurement). **The commit message is already written** at
`/tmp/claude-1000/-mnt-sdb1-Code-Active-Code-pokeyellow-msdos/147a50f9-4abc-4da0-aa95-2699a3a7c397/scratchpad/c14.msg`
— that is a session-scratch path and **will not survive**, so if you are picking
this up later and it is gone, §3 has everything needed to rewrite it.

**To land it:** get the bless (§1), then

```
git add dos_port/src dos_port/Makefile
git commit -F <c14.msg> -- dos_port/src dos_port/Makefile \
    dos_port/src/engine/overworld/pikachu.asm \
    dos_port/src/engine/overworld/warp_check.asm
```

(the last two paths are the removed sides of the rename/delete — `git commit`
resolves them against HEAD, and omitting them silently leaves the removals staged;
see memory `shared-worktree-git-safety`). Then `dos_port/tools/update_label_db` and
a restamp commit, then retire the 9 rows (41 → 32).

**This is a shared worktree.** Do not `git reset`, `git stash` or `git checkout` to
"clean up" — that destroys the work. If it must be set aside, commit it once the
bless lands, or ask the maintainer.

---

## 1. The one thing owed: the registry bless

s16 ended chunk 13 with a registry retirement, so the allowlist hash no longer
matches the maintainer's approval.

```
git config --get pokeyellow.pretAllowlistApprovedSha256   # a3d2da9e… (old, 52 rows)
sha256sum dos_port/tools/pret_label_allowlist.json        # 39015d46… (current, 41 rows)
```

**MAINTAINER ACTION — agents must never run this:**

```
git config pokeyellow.pretAllowlistApprovedSha256 \
  39015d46c97f1fc8cc6427fb424178d12ca28c6147f692f5858ef8aa94db9ad3
```

That hash was measured twice and the two agreed: `.githooks/prepare-commit-msg`
computed it into retirement commit `8282a245`, and `sha256sum` was then run
independently. Verify it yourself before running. Live state:
memory **`registry-approval-state`**. Docs-only commits still land meanwhile —
that is how this file and the docs fix got committed. Never reach for
`--no-verify`.

---

## 2. What s16 landed

| commit | what |
|---|---|
| `67a0bf81` | chunk 12 — `lcd_control.asm` → `home/lcd.asm`, `home/sprites.asm` → `home/clear_sprites.asm`, 4 rows |
| `13379388` | restamp |
| `1d3ab899` | chunk 13 — `copy` / `move_mon` / `movie/evolution` / `bills_pc`, 7 rows |
| `de0fd511` | restamp |
| `8282a245` | registry retirement, 11 rows, **52 → 41** |
| `9dd74130` | handoff |
| `0120f0b7` | docs — HiddenEventMaps pointer after the chunk-14 split |
| *(uncommitted)* | **chunk 14 — 9 rows, verified, see §0** |

Debt **52 → 41 committed**, 32 once chunk 14 lands. Linked sources **249**
throughout. Fallthrough **142**. `--strict-claims` at its standing **24**
(21 `local_shadow` + 3 `hand_encoded_text`), `stale_provider` 0. Three
`make fidelity-full` runs, all **MAKE_EXIT=0 / exactly 33 PASS** from the full log.

Coverage: c12 **4/4**, c13 **4/7**, c14 **1/9** (and that one early-out only).
The c14 tally is weak and honest — that region is genuinely unexercised.

---

## 3. Chunk 14, in enough detail to rewrite its commit message

Four units, all with the destination's pret ordering **measured** first
(player_state.asm 0 inversions of 9 pairs, player_animations.asm 0 of 22), so every
arrival went to its true pret position:

| rows | move |
|---|---|
| 3 | `src/engine/overworld/pikachu.asm` → **new** `src/engine/pikachu/pikachu_follow.asm` (whole-file rename, reordered into pret order) |
| 2 | `src/engine/overworld/warp_check.asm` → merged into `player_state.asm`; **warp_check.asm deleted** |
| 2 | `src/home/hidden_events.asm` → **split**; new `src/engine/overworld/hidden_events.asm` |
| 2 | `src/engine/overworld/ledges.asm` → merged into `player_animations.asm` |

Battery: 253 lines moved verbatim; **15 new / 4 dropped declarations, residual +11,
measured +11**. The 15 new are 9 lines of three `%ifndef` equ blocks *copied* (both
halves of the hidden_events split read them), `%include "gb_macros.inc"`,
`extern CheckForHiddenEvent`, two repointed `Func_15xx` externs, and
`section .text` + `section .data` at player_animations. The 4 dropped are two
duplicate externs (`Delay3`, `IsInArray`) and the two misattributed `Func_15xx`
lines they replace. `port_defs`/`port_calls` +0, `externs` −1 (decomposes as
+1 −1 −1), `fallthrough` 142. relocated 41 → 32.

**Two latent misattributions the moves exposed**, both pre-existing, both fixed:
`player_animations.asm` credited `Func_151d`/`Func_1510` to
`engine/overworld/pikachu.asm` (they are in `src/home/pikachu.asm`), and
`start_sub_menus.asm` credited `CheckIfInOutsideMap` to `warp_check.asm` (it is in
`src/home/overworld.asm`).

---

## 4. ⚠ A REAL BUG s16 FOUND AND DID NOT FIX

**Nothing calls `HandleMidJump`.** pret calls it from `OverworldLoopLessDelay`
(`home/overworld.asm:49`) and `faithdiff OverworldLoopLessDelay` has been reporting
`DROPPED HandleMidJump (call)` all along. `HandleLedges` *is* reachable and sets
`BIT_LEDGE_OR_FISHING`; `_HandleMidJump` is the only routine that clears it on the
ledge path. So after one ledge hop the flag sticks and permanently gates collision,
OBJ and emotion bubbles.

A `BUG{}` annotation is on `HandleMidJump` in `src/home/overworld.asm` (lints
clean, part of the uncommitted chunk 14). Full symptom / repro / fix plan:
memory **`regression-overworld-ledge-hop-never-advanced`**.

Not fixed because restoring a main-loop call is a behaviour change inside a
relocation chunk whose whole claim is that behaviour is unchanged — and it is
unverifiable today, since **no scenario covers ledges**. Scenario first, then the
call.

---

## 5. Do this first

Read memory **`relocated-labels-grind`** (chunking order, recipes, landmines), then
**`registry-approval-state`**, then **`static-gate-and-ci-wiring`** (the two gates,
the `DECL_RE` rules), then **`shared-worktree-git-safety`** — the last one matters
more than usual this session because of §0.

**Chunk 15 is not scoped.** After chunk 14 lands, re-measure:

```sql
select pret_file, count(*) from labels where status='relocated'
group by pret_file order by 2 desc;
```

Biggest remaining: **`engine/overworld/sprite_collisions.asm`, 4 rows**, all inside
a 1734-line `movement.asm` interleaved with pret labels. Still the first genuinely
entangled unit — budget a whole session, don't use it as a warm-up. Then
`home/delay.asm` 3 (NOT the free rename it looks like — `DelayFrames` and
`DelayFrame` are both wired into the frame pipeline in `src/video/frame.asm`),
`home/inventory.asm` 3, `home/pokemon.asm` 3, and a long singleton tail.

**`home/predef_text.asm`'s 2 rows are BLOCKED, not pending — do not re-scope them.**
`src/home/predef_text.asm` is check-only because `PrintPredefTextID` externs
`TextPredefs` (69 `add_tx_pre` entries) and **68 of those 69 text labels exist
nowhere in the port**. Merging would unlink `Set`/`RestoreMapTextPointer`, which the
SAVE flow's `ChangeBox` needs live. Blocked on the predef-text layer.

---

## 6. Traps s16 paid for

- **A MERGE CAN SILENTLY UNLINK THE THING YOU ARE MOVING.** `knows_hm_move.asm`
  existed only so `KnowsHMMove` could link while `bills_pc.asm` was check-only.
  Check which link list the destination is in *before* merging.
- **A stale Makefile comment is a load-bearing claim.** The stated reason
  `bills_pc.asm` was check-only was measurably false (s14 had already fixed it).
  Measuring beat routing around it: `POKEMON_CHECK_SRCS` is now empty.
- **A free edit is not a true edit.** Header rewrites are invisible to the line
  invariant, and s16 twice caught *itself* writing header claims it had not
  measured. Query the `labels` table and paste the answer.
- **An inversion can be load-bearing.** `src/home/copy.asm` is not in pret order,
  but swapping it would turn `FarCopyData`'s `jmp CopyData` into a fallthrough.
- **A pointer can carry a LINE NUMBER** (`lcd_control.asm:38`). Re-derive it.
- **The sweep reaches outside `dos_port/src`** — `include/`, `tools/generators/`,
  `CLAUDE.md`, `AGENTS.md` and `.claude/skills/` all held live pointers.
- **Gate names are not what you'd guess**: `DEBUG_BAGMENU` not `DEBUG_BAG_MENU`,
  and there is no `DEBUG_OVERWORLD` — the plain-boot gate is `DEBUG_BASELINE`.
- **A confident comment is the recurring defect.** Three false in-source claims
  were corrected this session, and one of them (`ledges.asm` asserting
  `HandleMidJump` is called every frame) is exactly what hid §4's bug.

Still true: `--gates` is COMMA-separated; never read a suite result through a pipe;
plain `lint_pret_labels` rescans the tracked DB (use `--no-scan`); don't invent a
provider comment for an extern that had none; `git add` refuses a path already
staged as a deletion; don't edit any source while `make fidelity-full` runs
(~15–20 min).

**And on sequencing:** the retirement blocks `dos_port/` commits, so it is the
natural *end* of code work. s16 did chunk 14 after it and could not land it — §0 is
the cost. Retire last, or get the bless before starting the next chunk.

---

## 7. Docs and memory maintenance (done this session)

**Docs measured clean.** A resolver over all **522** `path.ext` references in
`CLAUDE.md`, `AGENTS.md`, `ROADMAP.md` and every `docs/current_plan_*.md` found 29
unresolved, and **every one is deliberate**: `TODO.md`, `trainer_engine.asm`,
`audio_stubs.asm`, `wild_encounter_check.asm` cited as deleted; `serial_hal.inc`
explicitly "a proposed name, not a path"; `docs/plans/<topic>.md` are archive
destinations; the two `current_plan_battle_ui.md` mentions are struck through and
marked RESOLVED. Only one real fix was needed (`0120f0b7`). s15's patrol holds.
Skills also clean.

**Memories corrected (5):** `registry-approval-state` (41 rows, bless outstanding),
`relocated-labels-grind` (s16 entry + chunk-14 scoping + new lessons),
`pret-relocations-forbidden` (52 → 41), `copydata-dest-is-edx` (the routine is
`src/home/copy.asm` now, and **two files in its caller list no longer exist** —
replaced the list with `label_status --callers`, which returns 86),
`overworld-events-stage3-hidden-events-linked` (the file was split; also replaced
its "no reachable map has hidden events" guess with the measurement — Pallet Town
is absent from `HiddenEventMaps` but **ROUTE_11 is in it and `route11_sight` runs
there**, so start the hidden-event scenario hunt from that).
**Memory added (1):** `regression-overworld-ledge-hop-never-advanced` (§4).
Also stripped a second stale hash out of `allowlist-audit-2026-07-23`.

---

## 8. Still open, not started

- **Phase 2** — the 21 `local_shadow` findings, all one shape (pret label defined
  in a generated `assets/*.inc`, provider picked as the `.asm` that `%include`s
  it), so probably one provider-picker bug.
- **Phase 3** — the 82 stubs. Retiring one means implementing the routine.
- **CI has never run.** `origin/master` is far behind; the action is *push*.
  Known gap: `pre-commit` exits early when nothing under `dos_port/` is staged, so
  an amend touching no `dos_port/` content never re-runs the gate.
- **Fly/warp is entirely ungated**, and now **ledges too** (§4).
- Carried: `RestoreScreenTilesAndReloadTilePatterns` drops
  `call RunDefaultPaletteCommand`; `GBPalNormal` drops three `UpdateCGBPal_*`;
  `src/engine/battle/core.asm` is not in pret order; `GetMonLearnset_Evo` has zero
  callers; the Yellow intro renders in Mew's palette.
- New from s16: `CopyVideoDataAlternate`/`CopyVideoDataDoubleAlternate` are
  unported; `bills_pc.asm` being linked puts three zero-caller port-only routines
  into the binary as dead bytes; `_SpawnPikachu` is a **forked name** for pret's
  `SpawnPikachu_`, which CLAUDE.md's Preserve-pret-Labels rule forbids (noted in
  the new mirror's header, not renamed — it would touch its caller).

---

## 9. Working tree — not mine, untouched

```
?? .opencode/   opencode.json   docs/menu_intro_plan.md
```

`docs/menu_intro_plan.md` is stale (it describes `dos_port/src/movie/title.asm`, a
path that has not existed for some time). None were in scope. Unchanged since s15
flagged them. **Everything else in `git status` is chunk 14 — see §0.**
