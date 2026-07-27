# Handoff

**This is the ONE handoff file. Overwrite it; do not create `handoff_s19.md`.**

Sessions 10, 13 and 14 each left their own `handoff_s*.md` behind and nothing ever
deleted them, so by s15 the repo root held three handoffs with no way to tell from
the filenames which was current. All three were purged. Rewrite *this* file at the
end of your session. Anything that outlives one session belongs in **stigmergy**,
not here; this is a pointer sheet, not a record.

**Written:** 2026-07-27 (session 18) · **Branch:** `master`

Everything below is measured. **Re-measure anything you rely on**, including these
numbers — and note that s18 found TWO inherited scoping claims to be false (§4).

---

## 1. ⚠ A BLESS IS OWED — `dos_port/` commits are BLOCKED

s18 ended with a retirement, so the registry hash no longer matches the approval:

```
sha256sum dos_port/tools/pret_label_allowlist.json
# 80bc335dc93a97db3f37da59829f79c9e7d6cfa1702c227714b4a3b5bd9dac81   (11 rows)
git config --get pokeyellow.pretAllowlistApprovedSha256
# 8304337c…  ← the OLD 18-row hash
```

Maintainer action (**agents must never run this**):

```
git config pokeyellow.pretAllowlistApprovedSha256 \
  80bc335dc93a97db3f37da59829f79c9e7d6cfa1702c227714b4a3b5bd9dac81
```

Until then `.githooks/pre-commit` blocks every commit staging anything under
`dos_port/`. Docs-only commits still land. **Never reach for `--no-verify`.**

**But do not trust the paragraph above — re-measure.** Live state is memory
**`registry-approval-state`**, and even that is measured at *write* time. s17
opened with the previous handoff declaring a bless owed that had already been
paid. Run the two commands.

Otherwise the tree is clean: `git status` shows only the two untracked maintainer
files in §7.

---

## 2. What s18 landed — debt 18 → 11, one chunk, 7 rows

| commit | what |
|---|---|
| `b3b34dd4` | **chunk 17** — 2 new mirrors, 1 file deleted, 39 files. Coverage **5/7** |
| `901c4fb8` | restamp `translation.db` |
| `10d82e9d` | retirement, 7 rows, 18 → 11 |

**348 → 11 across the campaign: 97% of the relocated-label debt retired.**

- **`src/engine/overworld/sprite_collisions.asm` (NEW)** — `_UpdateSprites`,
  `UpdateNonPlayerSprite`, `DetectCollisionBetweenSprites`,
  `SetSpriteCollisionValues`, cut out of `movement.asm` and put **in pret order**
  (the port had the last two inverted; the reorder is inert because
  `SetSpriteCollisionValues` ends in `ret` on both arms). `Func_4d0a` and
  `SpriteCollisionBitTable` stated `missing` by design in the header — both are
  inlined into the bespoke `DetectCollisionBetweenSprites`, not pending.
- **`src/home/update_sprites.asm` (NEW)** — `UpdateSprites`, 44 lines for an
  8-instruction routine. Its own mirror because pret `home/update_sprites.asm` is
  a separate home-bank file whose only label it is. Adjacency is not an argument.
- **`move_effect_helpers.asm` DELETED** — `EffectCallBattleCore` →
  `move_effects/reflect_light_screen.asm`, `Bankswitch` → `home/bankswitch2.asm`,
  `StatModTextStrings` → `src/data/battle_data.asm`.

Measured: 248 code lines moved verbatim; residual +9 derived, +9 measured.
Linked sources **251 → 252**. `port_defs` 9195 / `port_calls` 5217 / fallthrough
142 all unmoved; externs 2376 → 2380. `--strict-claims` at its standing **24**
(21 `local_shadow` + 3 `hand_encoded_text`), `stale_provider` **0**.
`make fidelity-full`: **MAKE_EXIT=0 / exactly 33 PASS**.

Full detail, recipes and landmines: memory **`relocated-labels-grind`**.

---

## 3. Do this first — chunk 18 finishes the grind, and it is CHEAP

**The 9 remaining singletons, batched into ONE chunk with ONE baseline and ONE
suite run.** s17 measured the sweep surface at **11 extern lines across all nine**
— against chunk 16's ~95 and chunk 17's 42. Re-measure it, but expect small.

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

**⚠ `DiscardButtonPresses` is the one that is NOT mechanical.** Its mirror path
`engine/joypad.asm` is currently occupied by a DEAD reference file — in no SRCS
list at all — while the live body is `src/input/joypad.asm`. There is a live
`dup_def` suppression in the registry explaining this. Read it before moving.

**After chunk 18 the grind is done except for `home/predef_text.asm`'s 2 rows**,
which are **BLOCKED, do not re-scope** — `PrintPredefTextID` needs the unported
69-entry `TextPredefs` table and 68 of its 69 targets exist nowhere in the port.

Read memory **`relocated-labels-grind`**, then **`registry-approval-state`**, then
**`static-gate-and-ci-wiring`**, then **`shared-worktree-git-safety`**.

---

## 4. ⚠ TWO SCOPING CLAIMS s18 INHERITED WERE FALSE — check the table above

Both were in the previous handoff and in the grind memory, both were cheap to
verify, and neither had been:

1. **"`Bankswitch` → NEW `src/home/bankswitch2.asm`."** It was **not new** — that
   mirror has existed since the 2026-07-23 menu-intro review holding
   `BankswitchCommon` + `JumpToAddress`. One `ls` would have said so.
2. **"That 54-line file's only two column-0 labels are these two."** There was a
   **third**, `StatModTextStrings` — invisible to a column-0 scan because it is
   *defined inside its generated `%include`*, leaving only a `global`, a
   `section .data` and the include line in the `.asm`.

**The generalisation, because it will recur:** *"this file's only labels are X and
Y" is a claim about a scan, and a column-0 scan cannot see a label that lives in
an `assets/*.inc`.* Before declaring a file empty enough to delete, read its
`global` lines and its `%include`s too. This is the same shape as the 21
`local_shadow` findings — which s18 has now confirmed is a real pattern, not a
scanner artifact.

This is the third consecutive session to inherit a confidently-stated, unmeasured
claim (s17 retracted "sprite_collisions is genuinely entangled — budget a whole
session", which s18 confirmed was indeed false: it took one ordinary unit).
**Map the labels before you inherit a characterisation.**

---

## 5. ⚠ THE MAINTAINER'S PRIORITY FRAMING (2026-07-27) — read before choosing work

Verbatim: *"Relocations were the biggest concern. Missing usually just means we
haven't gotten around to porting something yet. New labels may or may not be
problematic on a case-by-case basis, and stubs, well, those are straightforward."*

So chunk 18 does not merely finish a metric — it closes the tier that actually
mattered. **Do not treat the 1606 `missing` as equivalent debt.** The nearest
remaining members of the same family (forked / invented names) are:

- **`_SpawnPikachu` is a forked name for pret's `SpawnPikachu_`** — a plain
  Preserve-pret-Labels violation. Same name with the underscore moved, so it
  *reads* as a pret label and is not one. Not renamed because it touches its
  caller in `src/home/pikachu.asm`.
- **The 21 `local_shadow` findings** — all one shape, plausibly one
  provider-picker bug rather than 21 problems. No verdict has ever been recorded.

Both are cheap and unblocked. Prefer them over opening the stub tier.

---

## 6. ⚠ TWO REAL BUGS FOUND AND NOT FIXED

**(a) Nothing calls `HandleMidJump`** (found s16, still open). pret calls it from
`OverworldLoopLessDelay`. After one ledge hop `BIT_LEDGE_OR_FISHING` sticks and
permanently gates collision, OBJ and emotion bubbles. `BUG{}` on `HandleMidJump`
in `src/home/overworld.asm`; memory
**`regression-overworld-ledge-hop-never-advanced`**. No scenario covers ledges.

**(b) `AddAmountSoldToMoney` drops pret's `SFX_PURCHASE` tail** (found s17) —
`call PlaySoundWaitForCurrent` + `jp WaitForSoundToFinish`. The comment that
justified it ("audio HAL, Phase 3, elided") was **measurably stale**.
`BUG{class=temporary}` at the site in `src/home/inventory.asm`. Not fixed — zero
port callers (the shop layer is unported), so nothing could verify it.

Both need a scenario first, then the call. **General lesson from (b): a `TODO-HW`
/ "deferred to Phase N" comment is a claim with an expiry date. When your chunk
touches one, re-measure whether the dependency is still missing.**

---

## 7. Traps, carried forward and added to

- **A KILLED `fidelity-full` LOOKS LIKE A PASS TALLY, NOT A FAILURE.** Write
  `MAKE_EXIT` into the log file itself and require it. A tally with no
  `MAKE_EXIT=0` is an unfinished run, not a result.
- **Write every sweep as an explicit `old → new` table with an exact-count
  assertion per entry.** s18's 42 entries all matched first run. A blanket regex
  would have mis-repointed comments silently. **The pret label the comment is
  ABOUT decides the target, not the file the line sits in.**
- **⚠ NEW (s18): `.claude/worktrees/fidelity-expansion` holds a whole second copy
  of `dos_port/`** and pollutes every tree-wide grep with plausible-looking hits
  from a dead branch. Exclude it explicitly, or you will "fix" a file nothing
  builds.
- **A delete exposes provider comments that were ALREADY wrong** — this has hit
  every chunk since s16. s18 found three: `PlayBattleAnimation` and `PrintText`
  were never defined in `move_effect_helpers.asm`. **Repoint at the measured
  provider, never at the new path.** And split dangling mentions three ways: live
  pointers, relocated prose, and genuine provenance (which keeps the old name with
  "deleted in chunk 17" appended — silently erasing it erases the provenance).
- **`home/` files are split across `HOME_SRCS` and `GAME_SRCS`.** Group a new
  mirror by subsystem, not by directory; s18's first insertion split the
  `vblank`/`delay` pair.
- **Do not casually re-indent an untouched declaration** — trimming two alignment
  spaces turns a no-op into a +1/−1 in the decomposition.
- **Read the assembled file, not just the tool's verdict.** Comment-only damage is
  invisible to the line invariant; s18 caught a moved comment reading "(Same as
  Bankswitch below)" when `Bankswitch` was no longer below.
- **Count it, don't feel it.** s18 caught itself writing "five other files extern
  it" when the measured number was two — in a comment-only edit, which is exactly
  where the invariant cannot help.
- Still true: `--gates` is COMMA-separated; never read a suite result through a
  pipe; plain `lint_pret_labels` rescans the tracked DB (use `--no-scan`); for a
  rename or delete the `git commit --` pathspec must name the REMOVED path; don't
  edit any source while `make fidelity-full` runs. Gate names: `DEBUG_BAGMENU` not
  `DEBUG_BAG_MENU`; no `DEBUG_OVERWORLD` — the plain-boot gate is `DEBUG_BASELINE`.

---

## 8. Still open, not started

- **The 82 stubs** — retiring one means implementing the routine. The last tier.
- **CI has never run.** `origin/master` is far behind; the action is *push*.
- **Fly/warp is entirely ungated**, and so are **ledges** (§6a) and **shops** (§6b).
- Carried: `RestoreScreenTilesAndReloadTilePatterns` drops
  `call RunDefaultPaletteCommand`; `GBPalNormal` drops three `UpdateCGBPal_*`;
  `engine/battle/core.asm` is not in pret order; `GetMonLearnset_Evo` has zero
  callers; the Yellow intro renders in Mew's palette; `src/home/copy.asm` is not in
  pret order and the inversion is load-bearing; `CopyVideoDataAlternate` /
  `CopyVideoDataDoubleAlternate` unported; `bills_pc.asm` being linked puts three
  zero-caller routines in the binary as dead bytes.
- **New from s18:** `move_effects/reflect_light_screen.asm`'s header still opens
  with the filename `1192__ReflectLightScreenEffect.asm` and a matching Build line,
  both stale from the move-effect swarm. Pre-existing, left alone deliberately
  rather than swept inside a relocation commit.
- **Doc staleness:** s17 deleted `src/video/frame.asm` (~14 docs cite it); s18
  deleted `src/engine/battle/move_effect_helpers.asm` (~10 more). All *in-tree*
  mentions were swept; the `docs/` ones were left as history for the next doc
  patrol to judge. Owner: `docs/current_plan_doc_staleness.md`.

---

## 9. Working tree — not mine, untouched

```
?? .opencode/   opencode.json
```

Neither was in scope. Unchanged since s15 flagged them. (s17's third entry,
`docs/menu_intro_plan.md`, is gone — s17 deleted it as a superseded draft.)
