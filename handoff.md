# Handoff

**This is the ONE handoff file. Overwrite it; do not create `handoff_s18.md`.**

Sessions 10, 13 and 14 each left their own `handoff_s*.md` behind and nothing ever
deleted them, so by s15 the repo root held three handoffs with no way to tell from
the filenames which was current. All three were purged. Rewrite *this* file at the
end of your session. Anything that outlives one session belongs in **stigmergy**,
not here; this is a pointer sheet, not a record.

**Written:** 2026-07-27 (session 17) · **Branch:** `master`

Everything below is measured. **Re-measure anything you rely on**, including these
numbers. In particular §1: s17 opened with the *previous* handoff declaring a bless
owed that had already been paid.

---

## 1. One thing is owed: the registry bless

s17 ended with a retirement, so the allowlist hash no longer matches the approval.
Until re-blessed, `.githooks/pre-commit` **blocks every commit that stages anything
under `dos_port/`**. Docs-only commits still land (this file was one).

```
git config --get pokeyellow.pretAllowlistApprovedSha256   # 5beec673… (old, 27 rows)
sha256sum dos_port/tools/pret_label_allowlist.json        # 8304337c… (current, 18 rows)
```

**MAINTAINER ACTION — agents must never run this:**

```
git config pokeyellow.pretAllowlistApprovedSha256 \
  8304337cb6fafcfc346c709e4ffb9dd8ec6e818dc0551d55eb3103914e44baee
```

Measured twice and agreed: `.githooks/prepare-commit-msg` computed it into
retirement commit `563cd9f6`, and `sha256sum` was run independently after.
Live state: memory **`registry-approval-state`** — **check that key, not this
file**. Never reach for `--no-verify`.

**Otherwise the tree is clean** — `git status` shows only the three untracked
maintainer files in §7. Nothing is uncommitted, nothing is half-done.

---

## 2. What s17 landed — debt 27 → 18, one chunk, 9 rows

| commit | what |
|---|---|
| `0bddffcb` | **chunk 16** — four new `home/` mirrors, two files deleted. 9 rows. Coverage **8/9** |
| `47ec72b3` | restamp `translation.db` |
| `563cd9f6` | retirement, 9 rows, 27 → 18 |

**348 → 18 across the campaign: 95% of the relocated-label debt retired.**

Chunk 16 in one line each:

- **`src/video/frame.asm` split, then DELETED.** It carried pret labels from *two*
  files under a name matching neither: `DelayFrame` → new `src/home/vblank.asm`,
  `DelayFrames` → new `src/home/delay.asm`. s17 took `DelayFrame` as well as the
  scoped `DelayFrames` — the decision every session since s12 had deferred. The
  argument was the **sweep**, not the diff: ~95 provider lines had to move either
  way, and a later `DelayFrame`-only move would have re-split the same helpers and
  re-run the same sweep.
- `PlaySoundWaitForCurrent` + `WaitForSoundToFinish` out of `src/home/audio.asm`,
  so **`src/home/delay.asm` holds all three** of pret `home/delay.asm`'s labels.
- New **`src/home/inventory.asm`** (`AddAmountSoldToMoney` + the two inventory
  wrappers). `src/home/money.asm` is now complete too.
- `src/home/joypad_lowsens.asm` renamed to new **`src/home/joypad2.asm`**, plus
  `WaitForTextScrollButtonPress` extracted out of `battle_menu.asm`.

Linked sources **249 → 251** (−2 deleted, +4 new). Fallthrough **142**. `port_defs`
9195 / `port_calls` 5217 never moved. `--strict-claims` at its standing **24**
(21 `local_shadow` + 3 `hand_encoded_text`), `stale_provider` **0**.
`make fidelity-full`: **MAKE_EXIT=0 / exactly 33 PASS** from the full log.

---

## 3. Do this first — nothing is pre-scoped, and that is deliberate

s16 handed s17 a scoped chunk. s17 does **not** do the same: the remaining 18 rows
have no clean multi-row unit left, so the right batching depends on your session
budget. Re-measure and choose:

```
select pret_file, count(*) from labels where status='relocated'
group by pret_file order by 2 desc, 1;
```

**The cheapest row on the board is `home/fade_audio.asm` (`FadeOutAudio`).** It
sits in `src/home/audio.asm` — the file chunk 16 already cut — so its extraction
shape is known and its provider sweep is small. s17 deliberately left it because
the maintainer had scoped c16 to three units and deferred singletons; the cost
argument for deferring it no longer holds.

Read memory **`relocated-labels-grind`** (recipes, landmines, the full c16 record),
then **`registry-approval-state`** (§1), then **`static-gate-and-ci-wiring`**, then
**`shared-worktree-git-safety`**.

---

## 4. What's left — 18 rows, and it gets harder per row

| rows | what | note |
|---|---|---|
| 4 | `engine/overworld/sprite_collisions.asm` | **hard** — all inside a 1734-line `movement.asm` interleaved with pret labels. The one genuinely entangled unit. Budget a whole session |
| 2 | `home/predef_text.asm` | **BLOCKED, do not re-scope** — needs the unported 69-entry `TextPredefs` table; 68 of its 69 targets exist nowhere in the port |
| 12 | singletons | one row each, across battle / overworld / home |

**Cost warning:** c12–c16 averaged 6–9 rows each because whole files and clean
pairs were still available. Those are gone. Batch several singletons into **one**
chunk and **one** suite run.

---

## 5. ⚠ TWO REAL BUGS FOUND AND NOT FIXED

**(a) Nothing calls `HandleMidJump`** (found s16, still open). pret calls it from
`OverworldLoopLessDelay`. After one ledge hop `BIT_LEDGE_OR_FISHING` sticks and
permanently gates collision, OBJ and emotion bubbles. `BUG{}` on `HandleMidJump`
in `src/home/overworld.asm`; memory
**`regression-overworld-ledge-hop-never-advanced`**. No scenario covers ledges.

**(b) `AddAmountSoldToMoney` drops pret's `SFX_PURCHASE` tail** (found s17) —
`call PlaySoundWaitForCurrent` + `jp WaitForSoundToFinish`. The comment that
justified it ("audio HAL, Phase 3, elided") was **measurably stale**: both routines
have real linked bodies and `PlaySound` is live. `BUG{class=temporary}` at the site
in `src/home/inventory.asm`. Not fixed — zero port callers (the shop layer is
unported), so nothing could verify it.

Both need a scenario first, then the call. **General lesson from (b): a `TODO-HW` /
"deferred to Phase N" comment is a claim with an expiry date. When your chunk
touches one, re-measure whether the dependency is still missing.**

---

## 6. Traps s17 paid for

- **A KILLED `fidelity-full` LOOKS LIKE A PASS TALLY, NOT A FAILURE.** s17's first
  run was terminated mid-suite; the log read `25 PASS` with **no FAIL token** —
  exactly what green looks like, only shorter. **Write `MAKE_EXIT` into the log
  file itself and require it.** A tally with no `MAKE_EXIT=0` is an unfinished run.
  s17 re-ran from scratch rather than reason about the missing 8.
- **Write a sweep as an explicit `old → new` table with an exact-count assertion
  per entry.** A blanket regex would have silently repointed `DelayFrames` comments
  at `vblank.asm`. The assertions caught two legitimate 2-match lines.
  **The pret label the comment is ABOUT decides the target, not the file it sits in.**
- **Merging two externs onto one line breaks the provider comment.** s17's own
  sweep wrote `extern GetMonName, PlaySound ; a.asm, b.asm` and lint read one
  provider for both → `stale_provider` 0 → 1. One symbol per commented extern line.
- **A script that splits a file must keep each banner with its own block.** The
  `joypad2.asm` builder stranded a 5-line comment above the wrong routine —
  comment-only, so the line invariant could never catch it. **Read the assembled
  file, not just the tool's verdict.**
- **An extern can't be used in assembly-time arithmetic**, so recipe rule 3 ("don't
  drag the `%include`") inverts when the symbol is an `equ` in an address
  expression — `ARROW_OFF` forced the layout include into `joypad2.asm`.
- **Don't sweep pre-existing cruft inside a relocation commit** — but say in the
  header that you found it and why you left it (`T_DOWNARROW` /
  `ARROW_BLINK_FRAMES` were already dead before the move).
- **Coverage settling is now one command:** parse `must_hit` out of
  `scenario_manifest.json`, parse `label_status --callers`, intersect. That settled
  6 of 9 rows with zero guessing; only the 3 misses needed a guard read.
- **Zero callers can CLEAR a row, not only condemn it.** `AddAmountSoldToMoney` has
  zero callers *and* pret calls it — from the unported shop layer. That's "linked,
  not reached", not the s16 bug shape. The question is whether the pret caller
  exists in the port at all.

Still true: `--gates` is COMMA-separated; never read a suite result through a pipe;
plain `lint_pret_labels` rescans the tracked DB (use `--no-scan`); for a rename or
delete the `git commit --` pathspec must name the REMOVED path; don't edit any
source while `make fidelity-full` runs. Gate names: `DEBUG_BAGMENU` not
`DEBUG_BAG_MENU`; no `DEBUG_OVERWORLD` — the plain-boot gate is `DEBUG_BASELINE`.

---

## 7. Still open, not started

- **Phase 2** — the 21 `local_shadow` findings, all one shape, probably one
  provider-picker bug.
- **Phase 3** — the 82 stubs; retiring one means implementing the routine.
- **CI has never run.** `origin/master` is far behind; the action is *push*.
- **Fly/warp is entirely ungated**, and so are **ledges** (§5a) and **shops** (§5b).
- Carried: `RestoreScreenTilesAndReloadTilePatterns` drops
  `call RunDefaultPaletteCommand`; `GBPalNormal` drops three `UpdateCGBPal_*`;
  `engine/battle/core.asm` is not in pret order; `GetMonLearnset_Evo` has zero
  callers; the Yellow intro renders in Mew's palette; `src/home/copy.asm` is not in
  pret order and the inversion is load-bearing; `CopyVideoDataAlternate` /
  `CopyVideoDataDoubleAlternate` unported; `bills_pc.asm` being linked puts three
  zero-caller routines in the binary as dead bytes; **`_SpawnPikachu` is a forked
  name for pret's `SpawnPikachu_`**, which the Preserve-pret-Labels rule forbids.
- From s17: `src/video/` no longer exists as a source directory (only stale `.o`
  artifacts). ~14 files under `docs/` still cite `src/video/frame.asm`; those were
  deliberately left as history for the next doc patrol to judge.

---

## 8. Working tree — not mine, untouched

```
?? .opencode/   opencode.json   docs/menu_intro_plan.md
```

`docs/menu_intro_plan.md` is stale (it describes `dos_port/src/movie/title.asm`, a
path that has not existed for some time). None were in scope. Unchanged since s15
flagged them.
