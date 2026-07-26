# Handoff — session 14 (relocated-labels grind, chunks 5–10)

Written 2026-07-26 at the end of the batch. Everything below is measured, not
recalled. **Verify anything you intend to rely on against the tree, not against
this file** — including the numbers here.

---

## 1. ONE THING IS OWED, AND IT IS THE MAINTAINER'S

The registry retirement landed, so `registry_approval` is 1 **by construction**
and the tree is blocked for any commit that stages something under `dos_port/`.

```
git config --get pokeyellow.pretAllowlistApprovedSha256
  6916f93ac83b77564ebc168fad3f9f5eb133d34fa2519f33fba7dacedca61e1b   (the OLD, 96-row one)
sha256sum dos_port/tools/pret_label_allowlist.json
  15982836a0e996717dc01d3fe3e79fb9a8dafa552b4480e955b8d3d487251566   (the new, 58-row one)
```

**Bless command — MAINTAINER ONLY. Agents must never run it:**

```
git config pokeyellow.pretAllowlistApprovedSha256 \
  15982836a0e996717dc01d3fe3e79fb9a8dafa552b4480e955b8d3d487251566
```

**Nothing else is owed.** Unlike session 13, no `translation.db` restamp is stuck
behind the block: s14 restamped after every chunk, and the last one (`50dc35e6`)
carries the label data for the final code state. The only commits after it are
docs-only. (Re-running `update_label_db` *will* show a byte diff in the DB — that
is the per-row `scanned_at` bookkeeping being rewritten, not a content change.
`git checkout -- dos_port/tools/translation.db` after you look.)

Until the bless: docs-only commits still land (the hook exits 0 when nothing under
`dos_port/` is staged). Do **not** `--no-verify`.

---

## 2. What landed

Debt **96 → 58** by DB count, in six chunks. Linked sources 248 → 249. Tree-wide
fallthrough unchanged at 142. `--strict-claims` back at its 24 baseline
(21 `local_shadow` + 3 `hand_encoded_text`) apart from the expected
`registry_approval`. `make fidelity-full` was run in full after **every** chunk:
`MAKE_EXIT=0`, token census exactly `33 PASS`, never through a pipe.

| commit | what |
|---|---|
| `64400890` | adopted the foreign Fly/Town-Map page-fault fix + `.codex/config.toml` (maintainer assignment) |
| `ede92ef8` | chunk 5 — `engine/pokemon/evos_moves.asm`, 8 rows, NEW mirror |
| `05ecbf13` | chunk 6 — `home/vcopy.asm` + `home/array2.asm` + `home/copy_string.asm`, 12 rows, 2 new mirrors; deleted `src/video/bg_anim.asm` |
| `f746c024` | chunk 7 — `engine/battle/scale_sprites.asm`, 5 rows, NEW mirror |
| `00c5cd58` | chunk 8 — `engine/overworld/pathfinding.asm`, 5 rows, NEW mirror |
| `af15ef77` | chunk 9 — `engine/items/item_effects.asm`, 5 rows; deleted `src/engine/items/get_max_pp.asm` |
| `e352bdf2` | chunk 10 — `engine/pokemon/add_mon.asm`, 3 rows; deleted `write_moves.asm` **and** `add_party_mon.asm` |
| `c549ba94` | **the single registry retirement, 38 rows, 96 → 58** |
| `052df8f3` | docs: two live pointers repointed at files this batch deleted |

Six port files deleted; four new mirrors created. Per-row coverage verdicts are in
each commit message, settled by reading call sites at that HEAD. Tally: **c5 6/8,
c6 5/12, c7 5/5, c8 0/5, c9 5/5, c10 3/3.** For the rest a green suite is a
regression result, not feature evidence — the commits say so per row.

---

## 3. Do this first

**Read memory `relocated-labels-grind` (v30).** It is the load-bearing one: the
chunking order, the extraction recipe, and every landmine s12/s13/s14 hit. Then
`static-gate-and-ci-wiring` (v10) for the two gates, and
`shared-worktree-git-safety` (v4) before you delete anything.

Then pick the next chunk. Re-measure the clusters rather than trusting this list:

```sql
select pret_file, count(*) from labels where status='relocated'
group by pret_file order by 2 desc;
```

At end of s14 the biggest were:

- **`engine/overworld/sprite_collisions.asm`, 4 rows** — all inside
  `src/engine/overworld/movement.asm`. **This is the first genuinely entangled
  unit left**, and s14 deliberately did not start it: `_UpdateSprites` and
  `UpdateNonPlayerSprite` sit at the top of a 1734-line file interleaved with
  pret `engine/overworld/movement.asm` labels, and `DetectCollisionBetweenSprites`
  / `SetSpriteCollisionValues` are elsewhere in it. Budget a whole session.
- **`home/names.asm`, 3 rows** — `HMMoves` / `IsItemHM` / `IsMoveHM`, all in
  `src/home/item_predicates.asm`. Attractive: after chunk 9 that file holds only
  those three plus `IsKeyItem`, so moving them may empty it. Check what pret file
  `IsKeyItem` belongs to first.
- `home/pokemon.asm` 3, `home/inventory.asm` 3, `home/delay.asm` 3,
  `engine/pikachu/pikachu_follow.asm` 3.

---

## 4. Traps this batch paid for

The full set is in the memory. The five worth knowing before you touch anything:

- **`fidelity_gate --move-baseline` takes REPO-ROOT-relative paths and fails
  silently otherwise.** Run from inside `dos_port/` with `src/foo.asm` and it
  matches nothing: "pret labels 0 / code lines 0", no error, and the dirty check
  passes vacuously. Always read the counts it prints back.
- **A FILE'S NAME CAN LIE ABOUT WHICH MIRROR IT IS.** `src/home/vcopy.asm` was not
  the mirror of `home/vcopy.asm` — it was a "home util bucket" holding two labels
  from two other pret files, while the real vcopy routines lived under
  `src/video/`. Check what a file *holds* before assuming its name; expect to
  evict squatters first. Every one of s14's six chunks had a lying header.
- **When you split a file by line range, `tail` BOTH sides.** Chunk 8 cut one line
  short and left the `$ff` terminator of a jump-mask table behind in the source.
  No gate would have caught it: the table is read by address-taken indexing (no
  call edge) and no scenario executes it.
- **Zero callers is not always evidence of "not executed".** If the caller is
  reached through a `dd` jump table (map scripts, NPC movement tables) there is no
  static edge. Settle from the GUARD instead.
- **The ratchet will catch your sweep miss, and it did.** Chunk 8's first commit
  was BLOCKED because two externs in `src/scripts/pallet_town.asm` still named the
  old provider — lines that had been on screen in the `label_status` output
  minutes earlier. Re-grep after you think the sweep is done.

Still true from s13: never read a suite result through a pipe; plain
`lint_pret_labels` rescans the tracked DB in place (use `--no-scan`); don't invent
a provider comment for an extern that had none; `git add` refuses a path already
staged as a deletion (name it in `git commit --` only).

New: **do not edit any source while `make fidelity-full` is running** — it
rebuilds the image per scenario and would pick your edit up half-way through.
Budget 15–20 minutes per run.

---

## 5. Findings surfaced and deliberately NOT fixed

Each is stated in the commit that surfaced it. None is a regression.

1. **`GetMonLearnset_Evo` has zero callers tree-wide** — a port-only "corrected"
   learnset lookup now sitting in the evos_moves mirror. Dead before the move and
   dead after; deleting it is a separate change.
2. **`ScaleSpriteByTwo` drops pret's `OpenSRAM`/`CloseSRAM`** under the flat
   memory model. It now carries a `DEVIATION{class=banking}` instead of being an
   unexplained faithdiff delta.
3. **The adopted Fly/Town-Map fix is entirely ungated.** It is in the linked
   build, so every `33 PASS` since it appeared includes it — but **no scenario
   covers Fly, Teleport, Dig or any warp**. The suite says it broke nothing and
   says nothing about whether it works. It has never been observed running.
4. Carried over and still open: `RestoreScreenTilesAndReloadTilePatterns` still
   drops its `call RunDefaultPaletteCommand`; `GBPalNormal` drops three
   `UpdateCGBPal_*` calls its neighbour makes; `src/engine/battle/core.asm` is not
   in pret order; ~20 dangling path pointers remain in `docs/current_plan_*.md`
   prose (owner: `docs/current_plan_doc_staleness.md`).

---

## 6. Still open, not started

- **Phase 2** — the 21 `local_shadow` findings. All one shape (pret label defined
  in a generated `assets/*.inc`, provider picked as the `.asm` that `%include`s
  it), so probably one provider-picker bug. Queued behind relocations.
- **Phase 3** — the 82 stubs. Retiring a stub means implementing the routine
  (32 of the 82 are `hidden_object_stubs.asm`), so it collides with the feature
  freeze and needs its own conversation with the maintainer.
- **CI has never run.** `origin/master` is far behind and the
  `PRET_ALLOWLIST_APPROVED_SHA256` repo variable is unset, so both are inert until
  someone pushes. See memory `ci-inert-until-master-is-pushed`.

---

## 7. Working tree — NOT mine

Left untouched and out of every commit, as instructed:

```
?? .opencode/  docs/menu_intro_plan.md  handoff.md  opencode.json
```

`handoff.md` at the repo root is **session 10's** and is now three sessions stale;
it is untracked and was not mine to delete. `handoff_s13.md` (tracked) describes
the batch before this one.
