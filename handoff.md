# Handoff

**This is the ONE handoff file. Overwrite it; do not create `handoff_s20.md`.**

Sessions 10, 13 and 14 each left their own `handoff_s*.md` behind and nothing ever
deleted them, so by s15 the repo root held three handoffs with no way to tell from
the filenames which was current. All three were purged. Rewrite *this* file at the
end of your session. Anything that outlives one session belongs in **stigmergy**,
not here; this is a pointer sheet, not a record.

**Written:** 2026-07-27 (session 19) · **Branch:** `master`

Everything below is measured. **Re-measure anything you rely on** — including the
claim in §1, which the last two sessions both found stale.

---

## 1. ⚠ A BLESS IS OWED — and this is the LAST relocation bless

s19 ended with the final retirement, so the registry hash no longer matches:

```
sha256sum dos_port/tools/pret_label_allowlist.json
# 604994cfaf8c03534df58db858a302dd901e48b051ce9b9ef67b9dd10f4685ef   (2 rows)
git config --get pokeyellow.pretAllowlistApprovedSha256
# 80bc335d…  ← the OLD 11-row hash
```

Maintainer action (**agents must never run this**):

```
git config pokeyellow.pretAllowlistApprovedSha256 \
  604994cfaf8c03534df58db858a302dd901e48b051ce9b9ef67b9dd10f4685ef
```

Until then `.githooks/pre-commit` blocks every commit staging anything under
`dos_port/`. Docs-only commits still land. **Never reach for `--no-verify`.**

**Do not trust the paragraph above — re-measure.** Live state is memory
**`registry-approval-state`**. s17 opened with a handoff declaring a bless owed
that had already been paid; **s19 opened exactly the same way and found the same
thing — the bless was paid and commits were open the whole time.** Run the two
commands.

Otherwise the tree is clean: `git status` shows only the two untracked maintainer
files in §7.

---

## 2. 🏁 THE ORDINARY RELOCATION GRIND IS FINISHED

**348 → 2.** Both survivors are the **BLOCKED** `home/predef_text.asm` pair
(`SetMapTextPointer`, `RestoreMapTextPointer`). They are not work anyone can pick
up: `PrintPredefTextID` needs the unported 69-entry `TextPredefs` table, and 68 of
its 69 text targets exist nowhere in the port. That is a text-porting dependency,
not a relocation. **Do not re-scope it.**

There is no chunk 19. Do not go looking for one.

| commit | what |
|---|---|
| `38395ce3` | **chunk 18** — 8 mechanical singletons, 4 new mirrors, 21 files. Coverage **4/8** |
| `33fc5137` | **joypad repair** — `engine/joypad.asm` made live, `DiscardButtonPresses` moved home |
| `14d8ccd4` | restamp `translation.db` |
| `86b3d3ca` | retirement, 9 rows, 11 → 2, **plus the `dup_def` suppression** |

Both units: `make fidelity-full` → **MAKE_EXIT=0 / exactly 33 PASS**. static_gate
PASS on every commit. lint 0 violations. Linked sources **252 → 258**.
`fallthrough` 142, unmoved since s8.

**Registry suppressions are now 4, not the 5 quoted across older notes.**

Full detail, recipes and landmines: memory **`relocated-labels-grind`** — still the
best reference for any future move, mirror, or file split. The grind ended; the
traps did not. The joypad decision and its measurements:
**`discardbuttonpresses-mirror-blocked`**.

---

## 3. ⚠ THREE INHERITED CLAIMS s19 FOUND WRONG — the pattern is the point

1. **The previous handoff said the tree was clean. It was not.** Chunk 18 was
   sitting fully done and uncommitted in the shared worktree — s18 did the work
   *after* writing its handoff. **Run `git status` and read the diff before
   believing any inherited description of the tree.**
2. **It said a bless was owed. It had been paid.** (Same as s17. See §1.)
3. **`src/engine/joypad.asm` "does not assemble (wrong %include path)" was true and
   incomplete.** Fixing the path exposed a second wall of errors — pret-lowercase
   HRAM operands the port's memmap never defined — and a third, `jp Joypad` with no
   target. Nobody had ever run nasm on it.
   *** "It does not assemble because X" is a claim about ONE error message.
   Assemble it and read them all. ***

Each was cheap to check and none had been. Same shape as s18's two false scoping
claims and s17's false difficulty claim. **Verify the cheap inherited claim.**

---

## 4. What the joypad repair actually put in the binary

Maintainer chose **option A**: repair and link the file whole, rather than trim it
to the one live routine. The port now links **five zero-caller pret routines** as
dead bytes — `ReadJoypad_`, `_Joypad`, `TrySoftReset` (`engine/joypad.asm`) and
`Joypad`, `ReadJoypad` (the new `src/home/joypad.asm` mirror, which took two labels
from `missing` to `translated`).

**The live input path is unchanged.** An INT 9h ISR latches `H_JOY_*` and
`joypad_update` runs inside `DelayFrame`, so `DelayFrame` *is* the poll. The
port-input-model DEVIATION at `src/home/start_menu.asm:28` still stands; s19 only
corrected its now-false clause that `Joypad` is `missing`.

`ReadJoypad_` carries a new `DEVIATION{class=HAL}` worth reading before you touch
input: **`IO_JOYP` IS emulated** — `joypad_update` composes that shadow honouring
the select bits. What it does not do is recompute on write, so `ReadJoypad_`'s
select-then-read-in-one-call would return the previous frame's row. "The port does
not emulate `IO_JOYP`" would have been a plausible, checkable, **false** claim.

---

## 5. Coverage — five of the ten labels are regression-only

A green suite proves **no regression** for these, not execution. Settling chains
are in the commit messages.

- **`PrintStatsBox`** — needs a scenario that levels a mon, or a Rare Candy. The
  `battle_faint` harness is SNORLAX L80 vs PIDGEY L13 and *cannot* level.
- **`FadeOutAudio`** — `audio_tick` self-gates on `g_audio_engine_online`, 0 in the
  harness.
- **`EndNPCMovementScript`** — no scenario drives scripted NPC movement.
- **`FarPrintText`** — zero callers, and **not a gap**: pret has none either. An
  unused pret routine, faithfully reproduced.
- **`DiscardButtonPresses`** — needs a boulder-push scenario, or one setting
  `BIT_DISABLE_JOYPAD`.

---

## 6. Where to go next

The maintainer's own priority framing (s18, verbatim): *"Relocations were the
biggest concern. Missing USUALLY just means we haven't gotten around to porting
something yet."* **That tier is now empty**, so the nearest remaining members of the
same family are next:

1. **`_SpawnPikachu` is a FORKED NAME** for pret's `SpawnPikachu_` — the
   Preserve-pret-Labels rule forbids it. Renaming touches its caller in
   `src/home/pikachu.asm`. Small and well-understood.
2. **The 21 `local_shadow` findings** — all one shape (pret label defined in a
   generated `assets/*.inc`, provider picked as the `.asm` that `%include`s it).
   Probably ONE provider-picker bug. s18 hit the pattern by hand and confirmed it
   is real, not a scanner artifact.

Otherwise the open threads are unchanged and listed under "OTHER OPEN THREADS" in
`relocated-labels-grind` — including **the ledge-hop bug**
(`regression-overworld-ledge-hop-never-advanced`, nothing calls `HandleMidJump`), a
live gameplay defect with no scenario covering it.

Two findings s19 surfaced and deliberately did not fix, both stated in their
commits: `include/gb_memmap.inc`'s `wJoyIgnore` alias carries a stale
`"(confident) = 0xCCB7"` comment while resolving to `0xCD6B`; and ~10 files under
`docs/` still describe `src/engine/joypad.asm` as dead. Every in-tree mention was
swept — the docs are for the doc patrol
(`docs/current_plan_doc_staleness.md`) to judge per mention.

---

## 7. Working tree — not mine, untouched

```
?? .opencode/   opencode.json
```

Neither was in scope. Unchanged since s15 flagged them.

---

## 8. Read these first, in this order

1. **`registry-approval-state`** — is a bless owed? (measured, not remembered)
2. **`relocated-labels-grind`** — the recipes and landmines outlive the grind
3. **`static-gate-and-ci-wiring`** — the two gates, the hook, the move battery
4. **`shared-worktree-git-safety`** — ALWAYS commit with an explicit pathspec

And the rule that earned its place three times this session: **claim the files,
read the tree, and re-measure the cheap inherited claim.**
