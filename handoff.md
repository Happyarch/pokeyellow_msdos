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

## 1. Nothing is owed — the registry is blessed

s17 ended with a retirement, which normally blocks `dos_port/` commits until the
maintainer re-blesses. **That bless was performed in-session**, so the tree starts
clean and unblocked:

```
git config --get pokeyellow.pretAllowlistApprovedSha256   # 8304337c… (18 rows)
sha256sum dos_port/tools/pret_label_allowlist.json        # 8304337c… — equal
```

Verified three ways after blessing: the two values are byte-equal; the row count
is 18, matching the DB's `relocated` count; and `tools/static_gate` returns PASS
with `registry_approval` **absent** from the findings, which it cannot be while
the hash differs.

Live state: memory **`registry-approval-state`** — **check that key, not this
file.** The previous handoff declared a bless owed that had already been paid; a
handoff is written before the fact, that key is measured. If they ever differ,
`.githooks/pre-commit` blocks every commit staging anything under `dos_port/`
(docs-only commits still land). Never reach for `--no-verify`.

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

## 3. Do this first — chunk 17 is scoped and measured, 7 rows

s17 measured the remaining debt properly and it is smaller work than advertised.
Full per-unit detail in memory **`relocated-labels-grind`**. Re-measure before
cutting, but the shape is settled.

**UNIT A — the `movement.asm` cluster. 5 rows, TWO new mirrors.**

| new mirror | gets |
|---|---|
| `src/engine/overworld/sprite_collisions.asm` | `_UpdateSprites`, `UpdateNonPlayerSprite`, `DetectCollisionBetweenSprites`, `SetSpriteCollisionValues` |
| `src/home/update_sprites.asm` | `UpdateSprites` (a 16-line bank-shuffle wrapper — separate pret file, so a separate mirror even though it sits adjacent) |

All five come out of `src/engine/overworld/movement.asm`. Measured:

- they sit in **two contiguous blocks**, lines 145–254 and 1474–EOF; the 33 labels
  that stay are one contiguous middle run.
- **six cross-cut edges total** — 4 out, 2 back.
- **zero fallthrough straddles the cut** (all 3 pairs are between labels that stay).
- one `section .text`, no `.data`/`.bss` — no private data to carry.
- **the port has two of them inverted vs pret** (`SetSpriteCollisionValues` before
  `DetectCollisionBetweenSprites`). A new mirror has no excuse — reorder on the way
  in; verify `SetSpriteCollisionValues` ends in `ret` first.
- pret's other two labels, `Func_4d0a` and `SpriteCollisionBitTable`, are `missing`
  **by design** — inlined into the port's bespoke `DetectCollisionBetweenSprites`,
  already documented at `movement.asm:1664` and `:1712`. Say so in the header; do
  not try to extract them.

**UNIT B — the `move_effect_helpers.asm` pair. 2 rows, the file EMPTIES and is DELETED.**

`EffectCallBattleCore` → `src/engine/battle/move_effects/reflect_light_screen.asm`
(exists); `Bankswitch` → new `src/home/bankswitch2.asm`. That 54-line file's only
two column-0 labels are these two — same shape as `frame.asm` and
`knows_hm_move.asm`. Grep the Makefile for it before starting.

Read memory **`relocated-labels-grind`**, then **`registry-approval-state`**, then
**`static-gate-and-ci-wiring`**, then **`shared-worktree-git-safety`**.

---

## 4. What's left after chunk 17 — and chunk 18 finishes the grind

**Chunk 18 = the 9 remaining singletons, batched into ONE chunk and ONE suite run.**
Measured sweep surface across all nine is **11 extern lines** — against chunk 16's
~95. They are cheap.

| label | → mirror | callers | externs |
|---|---|---|---|
| `MoveAnimationTiles1` | `engine/battle/animations.asm` | 0 | 1 |
| `DisplayUsedMoveText` | `engine/battle/used_move_text.asm` | 2 | 0 |
| `LoadPokedexTilePatterns` | `engine/gfx/load_pokedex_tiles.asm` | 4 | 0 |
| `DiscardButtonPresses` | `engine/joypad.asm` | 3 | 1 |
| `PrintStatsBox` | `engine/pokemon/status_screen.asm` | 2 | 2 |
| `FadeOutAudio` | `home/fade_audio.asm` | 1 | 1 |
| `EndNPCMovementScript` | `home/npc_movement.asm` | 2 | 0 |
| `FarPrintText` | `home/print_num.asm` | 0 | 0 |
| `PrintLetterDelay` | `home/print_text.asm` | 4 | 2 |

**After chunk 18 the grind is done except for `home/predef_text.asm`'s 2 rows**,
which are **BLOCKED, do not re-scope** — they need the unported 69-entry
`TextPredefs` table; 68 of its 69 targets exist nowhere in the port.

**⚠ A CORRECTION YOU ARE INHERITING.** Every handoff since s16 called
`sprite_collisions.asm` "the one genuinely entangled unit — budget a whole session."
**That was measured false in s17.** It had been inferred from two numbers ("4 rows",
"1734-line file") and restated across five documents until it read as measured.
Disproving it cost two queries. Before you inherit a difficulty rating, map the
labels: a file's *length* says nothing about how entangled *your* labels are in it.

**Keep this in proportion.** Relocation debt was always the cheapest tier — it is
bookkeeping, not implementation. The real remaining work is 82 stubs and 1606
`missing` labels, neither started. Do not read "95% retired" as "95% done".

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
