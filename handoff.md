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

s16 ended with its second retirement, so the allowlist hash no longer matches the
approval. Until it is re-blessed, `.githooks/pre-commit` **blocks every commit that
stages anything under `dos_port/`**. Docs-only commits still land.

```
git config --get pokeyellow.pretAllowlistApprovedSha256   # 39015d46… (old, 41 rows)
sha256sum dos_port/tools/pret_label_allowlist.json        # 821ac501… (current, 32 rows)
```

**MAINTAINER ACTION — agents must never run this:**

```
git config pokeyellow.pretAllowlistApprovedSha256 \
  821ac5017b020a4d3f1b49fccb209b85fbb72da4b98cdb077e42b534294fb9ec
```

Measured twice and agreed: `.githooks/prepare-commit-msg` computed it into
retirement commit `d8965c17`, and `sha256sum` was run independently after. Verify
before running. Live state: memory **`registry-approval-state`**. Never reach for
`--no-verify`.

**Nothing else is owed. The tree is clean** — `git status` shows only the three
untracked maintainer files in §7.

---

## 2. What s16 landed — debt 52 → 32, three chunks, 20 rows

| commit | what |
|---|---|
| `67a0bf81` + `13379388` | **chunk 12** — `lcd_control.asm` → `home/lcd.asm`, `home/sprites.asm` → `home/clear_sprites.asm`. 4 rows, two pure renames |
| `1d3ab899` + `de0fd511` | **chunk 13** — `copy` / `move_mon` / `movie/evolution` / `bills_pc`. 7 rows, 1 new mirror, `knows_hm_move.asm` deleted |
| `8282a245` | retirement #1, 11 rows, 52 → 41 |
| `9dd74130`, `0120f0b7` | handoff + docs |
| `a9f3f8da` + `a31b5859` | **chunk 14** — `pikachu_follow` / `player_state` / `hidden_events` / `player_animations`. 9 rows, 1 new mirror, `warp_check.asm` deleted |
| `d8965c17` | retirement #2, 9 rows, 41 → 32 |

Linked sources **249** throughout all three chunks. Fallthrough **142**.
`port_defs` 9195 / `port_calls` 5217 unmoved. `--strict-claims` at its standing
**24** (21 `local_shadow` + 3 `hand_encoded_text`), `stale_provider` **0**.
Three `make fidelity-full` runs, each **MAKE_EXIT=0 / exactly 33 PASS** read from
the full log.

Per-chunk coverage: c12 **4/4** (the best this grind has had), c13 **4/7**,
c14 **1/9** and that one early-out only. The c14 tally is weak and honest — that
region is genuinely unexercised.

---

## 3. ⚠ A REAL BUG s16 FOUND AND DID NOT FIX

**Nothing calls `HandleMidJump`.** pret calls it from `OverworldLoopLessDelay`
(`home/overworld.asm:49`), and `faithdiff OverworldLoopLessDelay` has been
reporting `DROPPED HandleMidJump (call)` all along. `HandleLedges` *is* reachable
and sets `BIT_LEDGE_OR_FISHING`; `_HandleMidJump` is the only routine that clears
it on the ledge path. So after one ledge hop the flag sticks and permanently gates
collision, OBJ and emotion bubbles.

`BUG{}` annotation on `HandleMidJump` in `src/home/overworld.asm` (lints clean).
Symptom / repro / fix plan: memory
**`regression-overworld-ledge-hop-never-advanced`**.

Not fixed because restoring a main-loop call is a behaviour change inside a
relocation chunk claiming none, and **no scenario covers ledges** so it cannot be
verified. Scenario first, then the call.

---

## 4. Do this first

Read memory **`relocated-labels-grind`** (chunking order, recipes, landmines), then
**`registry-approval-state`** (§1), then **`static-gate-and-ci-wiring`** (the two
gates, the `DECL_RE` rules), then **`shared-worktree-git-safety`**.

**Chunk 15 is NOT scoped — re-measure before choosing:**

```sql
select pret_file, count(*) from labels where status='relocated'
group by pret_file order by 2 desc;
```

The 32 remaining, measured at end of s16:

- **`engine/overworld/sprite_collisions.asm` 4** — all inside a 1734-line
  `movement.asm` interleaved with pret labels. Still the first genuinely entangled
  unit. Budget a whole session; don't use it as a warm-up.
- **`home/pokemon.asm` 3 + `engine/battle/init_battle.asm` 2** — four of these five
  are in `src/home/pics.asm`, a 797-line mixed file, and **both destinations
  already exist**. Doing them together is one cut of one file, not two. Probably
  the best-value next chunk.
- **`home/inventory.asm` 3**, **`home/delay.asm` 3**, **`home/joypad2.asm` 2** —
  destinations don't exist yet. `home/delay.asm` is **not** the free rename it
  looks like: `DelayFrames` and `home/vblank.asm`'s `DelayFrame` are both wired
  into the frame pipeline in `src/video/frame.asm`.
- **`home/predef_text.asm` 2 — BLOCKED, do not re-scope.** `predef_text.asm` is
  check-only because `PrintPredefTextID` externs `TextPredefs` (69 `add_tx_pre`
  entries) and **68 of those 69 text labels exist nowhere in the port**. Merging
  would unlink `Set`/`RestoreMapTextPointer`, which the SAVE flow's `ChangeBox`
  needs live. Blocked on the predef-text layer, not on grind effort.
- plus thirteen singletons.

---

## 5. Traps s16 paid for

- **A MERGE CAN SILENTLY UNLINK THE THING YOU ARE MOVING.** `knows_hm_move.asm`
  existed only so `KnowsHMMove` could link while `bills_pc.asm` was check-only.
  Check which link list the destination is in *before* merging.
- **A stale Makefile comment is a load-bearing claim.** The stated reason
  `bills_pc.asm` was check-only was measurably false. `POKEMON_CHECK_SRCS` is now
  empty.
- **Retiring blocks `dos_port/` commits, so it ends code work.** s16 retired at
  52→41 and then did chunk 14 anyway — finished, gated, green, and uncommittable
  until the maintainer blessed mid-session. Retire LAST, or get the bless before
  starting the next chunk.
- **A free edit is not a true edit.** Header rewrites are invisible to the line
  invariant, and s16 twice caught *itself* writing header claims it had not
  measured. Query the `labels` table and paste the answer.
- **An inversion can be load-bearing.** `src/home/copy.asm` is not in pret order,
  but swapping would turn `FarCopyData`'s `jmp CopyData` into a fallthrough.
- **A pointer can carry a LINE NUMBER** (`lcd_control.asm:38`). Re-derive it.
- **The sweep reaches outside `dos_port/src`** — `include/`, `tools/generators/`,
  `CLAUDE.md`, `AGENTS.md`, `.claude/skills/` all held live pointers.
- **A rename turns an already-wrong provider comment into a dangling one** — which
  is how you find it. Chunk 14 exposed two long-standing misattributions.
- **Gate names are not what you'd guess**: `DEBUG_BAGMENU` not `DEBUG_BAG_MENU`;
  no `DEBUG_OVERWORLD` — the plain-boot gate is `DEBUG_BASELINE`.
- **Zero callers on a routine pret DOES call is a bug, not a coverage result.**
  That is how §3 surfaced. Check `faithdiff <its caller>` before writing
  "not executed".
- **A confident comment is the recurring defect.** Four false in-source claims were
  corrected this session, one of which hid §3's bug for a long time.

Still true: `--gates` is COMMA-separated; never read a suite result through a pipe;
plain `lint_pret_labels` rescans the tracked DB (use `--no-scan`); don't invent a
provider comment for an extern that had none; for a rename or delete the
`git commit --` pathspec must name the REMOVED path; don't edit any source while
`make fidelity-full` runs (~15–20 min).

---

## 6. Docs and memory maintenance (done)

**Docs measured clean.** A resolver over all **522** `path.ext` references in
`CLAUDE.md`, `AGENTS.md`, `ROADMAP.md` and every `docs/current_plan_*.md` found 29
unresolved, and **every one is deliberate**: `TODO.md`, `trainer_engine.asm`,
`audio_stubs.asm`, `wild_encounter_check.asm` cited as deleted; `serial_hal.inc`
explicitly "a proposed name, not a path"; `docs/plans/<topic>.md` are archive
destinations; the two `current_plan_battle_ui.md` mentions are struck through and
marked RESOLVED. One real fix (`0120f0b7`). Skills clean.

**Memories corrected (6):** `registry-approval-state`, `relocated-labels-grind`
(s16 entry, chunk-14 lessons, re-scoped tail), `pret-relocations-forbidden`
(52 → 32), `copydata-dest-is-edx` (routine is `src/home/copy.asm` now; **two files
in its caller list no longer exist** — replaced with `label_status --callers`,
which returns 86), `overworld-events-stage3-hidden-events-linked` (file split; its
"no reachable map has hidden events" guess replaced by the measurement — Pallet
Town is absent from `HiddenEventMaps` but **ROUTE_11 is in it and `route11_sight`
runs there**, the cheapest lead for a hidden-event scenario),
`allowlist-audit-2026-07-23` (stripped a second stale hash).
**Memory added (1):** `regression-overworld-ledge-hop-never-advanced` (§3).

---

## 7. Still open, not started

- **Phase 2** — the 21 `local_shadow` findings, all one shape (pret label defined
  in a generated `assets/*.inc`, provider picked as the `.asm` that `%include`s
  it), so probably one provider-picker bug.
- **Phase 3** — the 82 stubs. Retiring one means implementing the routine.
- **CI has never run.** `origin/master` is far behind; the action is *push*. Known
  gap: `pre-commit` exits early when nothing under `dos_port/` is staged, so an
  amend touching no `dos_port/` content never re-runs the gate.
- **Fly/warp is entirely ungated**, and now **ledges too** (§3).
- Carried: `RestoreScreenTilesAndReloadTilePatterns` drops
  `call RunDefaultPaletteCommand`; `GBPalNormal` drops three `UpdateCGBPal_*`;
  `src/engine/battle/core.asm` is not in pret order; `GetMonLearnset_Evo` has zero
  callers; the Yellow intro renders in Mew's palette.
- New from s16: `CopyVideoDataAlternate`/`CopyVideoDataDoubleAlternate` unported;
  `bills_pc.asm` being linked puts three zero-caller port-only routines into the
  binary as dead bytes; **`_SpawnPikachu` is a forked name for pret's
  `SpawnPikachu_`**, which the Preserve-pret-Labels rule forbids — noted in the new
  mirror's header, not renamed (it would touch its caller).

---

## 8. Working tree — not mine, untouched

```
?? .opencode/   opencode.json   docs/menu_intro_plan.md
```

`docs/menu_intro_plan.md` is stale (it describes `dos_port/src/movie/title.asm`, a
path that has not existed for some time). None were in scope. Unchanged since s15
flagged them.
