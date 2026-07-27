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

## 1. ONE THING IS OWED, AND IT BLOCKS ALL `dos_port/` COMMITS

s16 ended with a registry retirement, so the allowlist hash no longer matches the
maintainer's approval. Until it is re-blessed, `.githooks/pre-commit` **blocks
every commit that stages anything under `dos_port/`**. Docs-only commits still
land (that is how this file got committed).

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
computed it into the retirement commit (`8282a245`), and `sha256sum` was then run
independently. Verify it yourself before blessing. Live state:
memory **`registry-approval-state`** — do not re-derive it from this file.

Do **not** reach for `--no-verify`. If you need to work before the bless, work on
docs, memories, or read-only analysis.

---

## 2. What s16 landed

| commit | what |
|---|---|
| `67a0bf81` | chunk 12 — `lcd_control.asm` → `home/lcd.asm`, `home/sprites.asm` → `home/clear_sprites.asm`, 4 rows, 2 pure renames |
| `13379388` | restamp `translation.db` |
| `1d3ab899` | chunk 13 — `copy` / `move_mon` / `movie/evolution` / `bills_pc`, 7 rows, 1 new mirror, `knows_hm_move.asm` deleted |
| `de0fd511` | restamp `translation.db` |
| `8282a245` | registry retirement, 11 rows, **52 → 41** |

Debt **52 → 41**. Linked sources **249** throughout (chunk 13's deletion and its
`bills_pc.asm` promotion cancel). Check-only sources **8 → 7**. Fallthrough
**142**. `port_defs` 9195, `port_calls` 5217, `externs` 2370 — none moved, because
all 11 labels were already `global`. `--strict-claims` at its standing **24**
(21 `local_shadow` + 3 `hand_encoded_text`). `make fidelity-full` after each
chunk: `MAKE_EXIT=0`, census exactly **33 PASS**, read from the full log.

**Coverage: chunk 12 4/4, chunk 13 4/7.** The 4/4 is the best this grind has had —
`Init` calls `DisableLCD` and `ClearSprites` unconditionally, so they run in every
scenario. Not executed: `CopyDataUntil`, `KnowsHMMove`, `HMMoveArray`; for those
three the green suite is a regression result only.

---

## 3. Do this first

Read memory **`relocated-labels-grind`** (chunking order, recipes, landmines),
then **`registry-approval-state`** (§1 above), then **`static-gate-and-ci-wiring`**
(the two gates, the `DECL_RE` rules that decide how you may cut a file), then
**`shared-worktree-git-safety`** before deleting or renaming anything.

**Chunk 14 is scoped — 9 rows in four units — but it is a step up from 12/13:
two of the four are genuine mixed-file extractions, not renames.**

| rows | move |
|---|---|
| 3 | `src/engine/overworld/pikachu.asm` → **new** `src/engine/pikachu/pikachu_follow.asm` |
| 2 | `src/engine/overworld/warp_check.asm` → merge into existing `src/engine/overworld/player_state.asm` |
| 2 | `src/home/hidden_events.asm` → **split**, new `src/engine/overworld/hidden_events.asm` (two home labels STAY) |
| 2 | `src/engine/overworld/ledges.asm` → merge into existing `player_animations.asm` (`HandleLedges` + 3 port-only tables STAY) |

Per-unit detail, including the `_SpawnPikachu` placement decision, is in the grind
memory. Re-measure the clusters rather than trusting any list:

```sql
select pret_file, count(*) from labels where status='relocated'
group by pret_file order by 2 desc;
```

Biggest remaining after that: **`engine/overworld/sprite_collisions.asm`, 4 rows**,
all inside a 1734-line `movement.asm` interleaved with pret labels. Still the first
genuinely entangled unit. Budget a whole session; don't use it as a warm-up.

**Do not re-scope chunk 12's third unit.** s15 planned
`map_text_pointer.asm` → `predef_text.asm`; s16 measured that it is blocked, not
merely unstarted — see §5.

---

## 4. Traps s16 paid for

- **A MERGE CAN SILENTLY UNLINK THE THING YOU ARE MOVING.** `knows_hm_move.asm`
  existed only so `KnowsHMMove` could link while `bills_pc.asm` sat in
  `POKEMON_CHECK_SRCS`. Merging back would have dropped it out of the binary with
  no gate noticing. **Check which link list the destination is in before merging.**
- **A stale Makefile comment is a load-bearing claim.** The stated reason
  `bills_pc.asm` was check-only ("needs a link-ready `_MoveMon`…") was measurably
  false — s14 chunk 10 had already fixed it. Measuring beat routing around it:
  the file was promoted, `POKEMON_CHECK_SRCS` is now empty, and the merge came out
  binary-neutral.
- **A free edit is not a true edit.** Header rewrites are invisible to the line
  invariant, and s16 twice caught *itself* writing confident header claims it had
  not measured (wrong label names for `home/copy.asm`'s other two pret labels;
  "three" above a list of four). Query the `labels` table and paste the answer.
- **An inversion can be load-bearing.** `src/home/copy.asm` is not in pret order,
  but swapping it would turn `FarCopyData`'s `jmp CopyData` into a fallthrough —
  a shape change. Left alone, with the reason in the file header.
- **A pointer can carry a LINE NUMBER.** `init_battle.asm` cited
  `lcd_control.asm:38`; the header rewrite pushed that body line to 40, so fixing
  only the path would have left it silently wrong. Re-derive the line.
- **The sweep reaches outside `dos_port/src`** — `include/`, `tools/generators/`,
  `CLAUDE.md`, `AGENTS.md` and `.claude/skills/` all held live pointers this time.
- **Gate names are not what you'd guess.** It is `DEBUG_BAGMENU`, not
  `DEBUG_BAG_MENU`, and there is no `DEBUG_OVERWORLD` — the plain-boot gate is
  `DEBUG_BASELINE`. Read them out of `tools/scenario_manifest.json`.

Still true: `--gates` is COMMA-separated and a space-separated list fails
misleadingly; never read a suite result through a pipe; plain `lint_pret_labels`
rescans the tracked DB (use `--no-scan`); don't invent a provider comment for an
extern that had none; `git add` refuses a path already staged as a deletion, so
name it in `git commit --` only; don't edit any source while `make fidelity-full`
runs (~15–20 min, rebuilds per scenario — docs and memories are safe).

**And one about sequencing:** the retirement blocks `dos_port/` commits, so it is
the natural *end* of code work for a session. Don't scope another chunk expecting
to land it afterwards.

---

## 5. Findings s16 surfaced and did NOT fix

- **`home/predef_text.asm`'s 2 rows are blocked, not pending.**
  `src/home/predef_text.asm` is in `HOME_CHECK_SRCS` because `PrintPredefTextID`
  externs `TextPredefs` (pret `data/text_predef_pointers.asm`, 69 `add_tx_pre`
  entries) — and **68 of those 69 text labels exist nowhere in `dos_port/src` or
  `dos_port/assets`**. Merging `map_text_pointer.asm` in would either unlink
  `Set`/`RestoreMapTextPointer` (the SAVE flow's `ChangeBox` needs them live) or
  require porting the predef-text table, which is script-engine work.
- `CopyVideoDataAlternate` and `CopyVideoDataDoubleAlternate` (pret
  `home/copy.asm`) are `missing` — unported, no callers.
- `bills_pc.asm` being linked puts three port-only routines
  (`BillsPCDepositLogic` / `WithdrawLogic` / `ReleaseLogic`) with zero callers
  into the binary as dead bytes. Harmless, stated in the chunk 13 commit.

---

## 6. Still open, not started

- **Phase 2** — the 21 `local_shadow` findings, all one shape (pret label defined
  in a generated `assets/*.inc`, provider picked as the `.asm` that `%include`s
  it), so probably one provider-picker bug.
- **Phase 3** — the 82 stubs. Retiring one means implementing the routine (32 are
  `hidden_object_stubs.asm`), so it collides with the feature freeze and needs its
  own conversation.
- **CI has never run.** `origin/master` is far behind (last push 2026-07-17); the
  action is *push*, not "set the variable" — `ci-inert-until-master-is-pushed`
  ranks what it would actually buy. Known pre-existing gap: `pre-commit` exits
  early when nothing under `dos_port/` is staged, so an amend that changes no
  `dos_port/` content never re-runs the gate.
- **Fly/warp is entirely ungated.** No scenario covers Fly, Teleport, Dig or any
  warp. A warp golden is the retirement.
- Carried: `RestoreScreenTilesAndReloadTilePatterns` drops its
  `call RunDefaultPaletteCommand`; `GBPalNormal` drops three `UpdateCGBPal_*` calls
  its neighbour makes; `src/engine/battle/core.asm` is not in pret order;
  `GetMonLearnset_Evo` has zero callers tree-wide; the Yellow intro still renders
  in Mew's palette (Phase-5 CGB gap).
- Docs staleness, remaining because each needs a decision not a sweep:
  `faint_sendout.asm`, `intro_anim_data.asm` and `bg_anim.asm` are cited by plans
  but survive only as stale `.o` artifacts with no source; six bare
  `overworld.asm` citations are genuinely two-way ambiguous inside `dos_port/src/`.

---

## 7. Working tree — not mine, untouched

```
?? .opencode/   opencode.json   docs/menu_intro_plan.md
```

`docs/menu_intro_plan.md` is stale (it describes `dos_port/src/movie/title.asm`, a
path that has not existed for some time). None were in scope; left for the
maintainer. Unchanged since s15 flagged them.
