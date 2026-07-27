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

## 1. One thing is owed: the registry bless

s16 ended with its third retirement, so the allowlist hash no longer matches the
approval. Until re-blessed, `.githooks/pre-commit` **blocks every commit that
stages anything under `dos_port/`**. Docs-only commits still land.

```
git config --get pokeyellow.pretAllowlistApprovedSha256   # 821ac501… (old, 32 rows)
sha256sum dos_port/tools/pret_label_allowlist.json        # 5beec673… (current, 27 rows)
```

**MAINTAINER ACTION — agents must never run this:**

```
git config pokeyellow.pretAllowlistApprovedSha256 \
  5beec6730267e21142e0553ef164f52f38376f28eb063cb5195e700c4b13ed0b
```

Measured twice and agreed: `.githooks/prepare-commit-msg` computed it into
retirement commit `eab807ca`, and `sha256sum` was run independently after.
Live state: memory **`registry-approval-state`**. Never reach for `--no-verify`.

**Otherwise the tree is clean** — `git status` shows only the three untracked
maintainer files in §7. Nothing is uncommitted, nothing is half-done.

---

## 2. What s16 landed — debt 52 → 27, four chunks, 25 rows

| commit | what |
|---|---|
| `67a0bf81` + `13379388` | **chunk 12** — `home/lcd.asm`, `home/clear_sprites.asm`. 4 rows, two pure renames. Coverage **4/4** |
| `1d3ab899` + `de0fd511` | **chunk 13** — `copy` / `move_mon` / `movie/evolution` / `bills_pc`. 7 rows, `knows_hm_move.asm` deleted. Coverage 4/7 |
| `8282a245` | retirement #1, 11 rows, 52 → 41 |
| `a9f3f8da` + `a31b5859` | **chunk 14** — `pikachu_follow` / `player_state` / `hidden_events` / `player_animations`. 9 rows, `warp_check.asm` deleted. Coverage 1/9 |
| `d8965c17` | retirement #2, 9 rows, 41 → 32 |
| `9ab36e2e` + `edf43bde` | **chunk 15** — the `pics.asm` four-way split. 5 rows. Coverage **5/5** |
| `eab807ca` | retirement #3, 5 rows, 32 → 27 |
| `9dd74130`, `0120f0b7`, `61aad2ea`, `353780df` | handoffs + docs |

**348 → 27 across the campaign: 92% of the relocated-label debt retired.**

Linked sources **249** through all four chunks. Fallthrough **142**. `port_defs`
9195 / `port_calls` 5217 never moved. `--strict-claims` at its standing **24**
(21 `local_shadow` + 3 `hand_encoded_text`), `stale_provider` **0**. Four
`make fidelity-full` runs, each **MAKE_EXIT=0 / exactly 33 PASS** from the full log.

---

## 3. Do this first — chunk 16 is scoped, 8 rows, three NEW mirrors

Maintainer's direction at the end of s16: **do these three units next, and leave
`sprite_collisions` and the singletons for later.** None of the three destinations
exists yet. Full per-unit detail is in memory **`relocated-labels-grind`**.

| rows | unit |
|---|---|
| 3 | `home/delay.asm` → **new** `src/home/delay.asm` — `DelayFrames` from `src/video/frame.asm`, `PlaySoundWaitForCurrent` + `WaitForSoundToFinish` from `src/home/audio.asm`. All three of pret's labels, so the mirror ends up complete |
| 3 | `home/inventory.asm` → **new** `src/home/inventory.asm` — `AddAmountSoldToMoney` from `home/money.asm`, `Add`/`RemoveItemFromInventory` from `engine/items/inventory.asm` |
| 2 | `home/joypad2.asm` → **new** `src/home/joypad2.asm` — `JoypadLowSensitivity` (whole of `joypad_lowsens.asm`) + `WaitForTextScrollButtonPress` (entangled in `battle_menu.asm`) |

Three things to know before cutting:

- **`home/delay.asm` is the unit every session has flagged as *not* the free rename
  it looks like.** `DelayFrames` is in the frame pipeline next to `home/vblank.asm`'s
  `DelayFrame` (a separate remaining row), and those two are `frame.asm`'s only pret
  labels. Decide deliberately whether `DelayFrame` travels too — taking both would
  retire the `vblank.asm` row as well.
- **`home/inventory.asm` is the easy shape**: the `_`-suffixed bodies
  (`AddItemToInventory_`, `RemoveItemFromInventory_`) are `engine/items/inventory.asm`
  labels that STAY, so the split is pret's own — same as chunk 15's `LoadMonData`.
- **`WaitForTextScrollButtonPress` has a known faithdiff quirk**: faithdiff reports
  zero port calls because they attribute to the co-located `WaitForAPress`. Don't
  read that as unreachable; settle its coverage from call sites.

Read memory **`relocated-labels-grind`** (chunking order, recipes, landmines), then
**`registry-approval-state`** (§1), then **`static-gate-and-ci-wiring`** (the two
gates, the `DECL_RE` rules), then **`shared-worktree-git-safety`**.

---

## 4. What's left after chunk 16 — and it gets harder per row

| rows | what | note |
|---|---|---|
| 4 | `engine/overworld/sprite_collisions.asm` | **hard** — all inside a 1734-line `movement.asm` interleaved with pret labels. The one genuinely entangled unit. Budget a whole session |
| 2 | `home/predef_text.asm` | **BLOCKED, do not re-scope** — needs the unported 69-entry `TextPredefs` table; 68 of its 69 targets exist nowhere in the port |
| 13 | singletons | one row each, across battle / overworld / home |

**Cost warning:** chunks 12–15 averaged ~6 rows each because whole files and clean
pairs were still available. After chunk 16 it's 13 singletons, each needing its own
baseline, tree-wide sweep, coverage settle and a 15–20 minute suite run. Consider
batching several singletons into one chunk and one suite run.

---

## 5. ⚠ A REAL BUG s16 FOUND AND DID NOT FIX

**Nothing calls `HandleMidJump`.** pret calls it from `OverworldLoopLessDelay`
(`home/overworld.asm:49`), and `faithdiff OverworldLoopLessDelay` has been reporting
`DROPPED HandleMidJump (call)` all along. `HandleLedges` *is* reachable and sets
`BIT_LEDGE_OR_FISHING`; `_HandleMidJump` is the only routine that clears it on the
ledge path. So after one ledge hop the flag sticks and permanently gates collision,
OBJ and emotion bubbles.

`BUG{}` annotation on `HandleMidJump` in `src/home/overworld.asm`. Symptom / repro /
fix plan: memory **`regression-overworld-ledge-hop-never-advanced`**.

Not fixed: restoring a main-loop call is a behaviour change inside a relocation
chunk claiming none, and **no scenario covers ledges** so it can't be verified.
Scenario first, then the call.

---

## 6. Traps s16 paid for

- **Retiring blocks `dos_port/` commits, so it ends code work.** s16 retired at
  52→41 then started chunk 14 anyway — finished, gated, green, and uncommittable
  until the maintainer blessed mid-session. **Retire LAST, or get the bless before
  starting the next chunk.** This session's final retirement is correctly the last
  action.
- **A merge can silently unlink the thing you're moving.** Check which link list
  the destination is in first. A Makefile comment's stated reason is a claim to
  verify, not a fact — `bills_pc.asm`'s was measurably stale.
- **Measure the destination's pret ordering, and expect different answers for
  different destinations in the same chunk.** Chunk 15: `init_battle.asm` 0
  inversions (insert at true position), `pokemon.asm` 4 of 14 (append under a
  banner, ordered among themselves).
- **Repointing a declaration's comment costs +1/−1, not zero** — correct accounting,
  but say so or the numbers read wrong.
- **A free edit is not a true edit.** Header rewrites are invisible to the line
  invariant, and s16 twice caught itself writing header claims it hadn't measured.
- **A rename turns an already-wrong provider comment into a dangling one** — that's
  how two long-standing misattributions surfaced.
- **Zero callers on a routine pret DOES call is a bug, not a coverage result.**
  That's how §5 surfaced.
- **A `%ifdef` isn't always a gate** — `MON_FRONT_PICS` is added unconditionally at
  Makefile:26.
- **A file's name lies.** Every chunk since s14 hit this; chunk 15's `pics.asm` was
  carrying labels from **three** different pret files at once.
- Gate names: `DEBUG_BAGMENU` not `DEBUG_BAG_MENU`; no `DEBUG_OVERWORLD` — the
  plain-boot gate is `DEBUG_BASELINE`.

Still true: `--gates` is COMMA-separated; never read a suite result through a pipe;
plain `lint_pret_labels` rescans the tracked DB (use `--no-scan`); for a rename or
delete the `git commit --` pathspec must name the REMOVED path; don't edit any
source while `make fidelity-full` runs.

---

## 7. Still open, not started

- **Phase 2** — the 21 `local_shadow` findings, all one shape, probably one
  provider-picker bug.
- **Phase 3** — the 82 stubs; retiring one means implementing the routine.
- **CI has never run.** `origin/master` is far behind; the action is *push*.
- **Fly/warp is entirely ungated**, and so are **ledges** (§5).
- Carried: `RestoreScreenTilesAndReloadTilePatterns` drops
  `call RunDefaultPaletteCommand`; `GBPalNormal` drops three `UpdateCGBPal_*`;
  `engine/battle/core.asm` is not in pret order; `GetMonLearnset_Evo` has zero
  callers; the Yellow intro renders in Mew's palette.
- From s16: `src/home/copy.asm` is not in pret order and the inversion is
  load-bearing; `CopyVideoDataAlternate`/`CopyVideoDataDoubleAlternate` unported;
  `bills_pc.asm` being linked puts three zero-caller routines in the binary as dead
  bytes; **`_SpawnPikachu` is a forked name for pret's `SpawnPikachu_`**, which the
  Preserve-pret-Labels rule forbids (noted in the mirror header, not renamed — it
  would touch its caller).

---

## 8. Working tree — not mine, untouched

```
?? .opencode/   opencode.json   docs/menu_intro_plan.md
```

`docs/menu_intro_plan.md` is stale (it describes `dos_port/src/movie/title.asm`, a
path that has not existed for some time). None were in scope. Unchanged since s15
flagged them.
