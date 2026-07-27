# Handoff

**This is the ONE handoff file. Overwrite it; do not create `handoff_s21.md`.**

Sessions 10, 13 and 14 each left their own `handoff_s*.md` behind and nothing ever
deleted them, so by s15 the repo root held three handoffs with no way to tell from
the filenames which was current. All three were purged. Rewrite *this* file at the
end of your session. Anything that outlives one session belongs in **stigmergy**,
not here; this is a pointer sheet, not a record.

**Written:** 2026-07-27 (session 20) · **Branch:** `master`

Everything below is measured. **Re-measure anything you rely on.**

---

## 1. ✅ NO BLESS IS OWED — and stop trusting this section

Measured at the start of s20:

```
sha256sum dos_port/tools/pret_label_allowlist.json
# 604994cfaf8c03534df58db858a302dd901e48b051ce9b9ef67b9dd10f4685ef  (2 rows)
git config --get pokeyellow.pretAllowlistApprovedSha256
# 604994cfaf8c03534df58db858a302dd901e48b051ce9b9ef67b9dd10f4685ef  ← EQUAL
```

`dos_port/` commits are **open**, confirmed end-to-end: s20 landed three of them
through the pre-commit hook, static gate PASS each time.

**The previous handoff said a bless was owed. It had already been paid — the FOURTH
session in a row to open on that false alarm** (s17, s19, s20 all found the same
thing). It is structural, not luck: the handoff is written *before* the maintainer
acts, and the maintainer acts *between* sessions. Live state is memory
**`registry-approval-state`**, which s20 corrected. Run the two commands; do not
plan around a phantom blocker.

---

## 2. What s20 did

Session brief was "read the handoff and clean up everything it missed", then two
mid-session directives from the maintainer.

| commit | what |
|---|---|
| `13a015fb` | **dissolved `include/m8_2_pending_symbols.inc`** into `gb_memmap.inc`/`gb_constants.inc` and deleted it, plus its 11 `%include` sites |
| `72f19bdf` | docs: retired the stale "`src/engine/joypad.asm` is dead" claims (the s19 deferral) |
| `1ceae0aa` | regenerated `docs/translation_progress.md` |
| `3058bca9` | **rewrote `gen_progress_report`** onto derived state instead of the abandoned `work_queue` |
| `95707057` | **dissolved `include/m1_3_pending_symbols.inc`** — the last scaffold — and fixed the colliding placeholder HRAM slot it had left behind |

Gates: `make fidelity-full` **MAKE_EXIT=0, exactly 33 PASS, 0 FAIL**; `static_gate`
PASS on every commit; `lint_pret_labels` 0 violations, 4 suppressed. Label DB
unmoved: 3790 labels, missing 1604 / port_only 429 / relocated 2 / stub 82 /
translated 1673, 258 linked sources.

---

## 3. Both scaffolds are gone — and each was hiding a defect

`m8_2_pending_symbols.inc` (`13a015fb`) and `m1_3_pending_symbols.inc` (`95707057`)
both carried their own exit condition in their headers, and both had rotted in place
for months. **No pending-symbol include remains.** Recipe, landmines and the full
method: memory **`pending-symbols-scaffolds-and-shadowing-equs`**.

**m1_3 was hiding a real latent defect.** It defined
`hSavedMapTextPtr equ 0xFF8E ; PLACEHOLDER (2 bytes)` with a comment asking the root
to allocate a real pair — nobody ever did. As two bytes it ran to `0xFF8F` =
`H_SPRITE_OFFSET2`, which `PrepareOAMData` writes **once per sprite, every frame**,
from the vblank pipeline. So the saved pointer's high byte was overwritten between
any save and its restore, handing `ChangeBox` a corrupt `wCurMapTextPtr` across
`SaveGameData`. Both routines are linked with a live caller; the flow sits behind the
Bill's-PC stubs, so it was latent, never observed. Fixed by taking pret's own address
(`0xFFEC`, golden `00:ffec`), which was free.

*Treat `PLACEHOLDER` / `TODO(root)` / `ROOT must allocate` on an address definition as
a defect report — it means an address nobody has checked.*

Two more things from that memory belong in front of you:

1. **The shadowing-equ trap, found TWICE.** m8_2 defined
   `wMapSpriteExtraData equ 0xD503` — pret's WRAM address — while the port's real
   array is flat `.bss` carrying the same pret name as a label. Any file including the
   scaffold bound the pret name to emulated WRAM **the port never writes**: assembles,
   links, reads plausible zeros. It cost two real bugs (`EngageMapTrainer`, caught by
   the route3_sight golden; `PickUpItem`, same shape). m1_3 held the **sibling array's**
   identical trap, `wMapSpriteData equ 0xD4E3` — no user, so it never bit, but it was
   one `%include` away. Both were **deleted rather than migrated**. *If you ever see a
   pret data name defined both as an address and as a label, that is a bug, not a
   style issue.*

2. **How a "pure refactor" gets verified.** `PKMN.EXE`'s md5 *did* change, which is
   exactly where such a claim normally gets explained away. Don't. Prove build
   determinism first, then compare **section bytes**, the **defined** symbol table,
   and the **absolute** symbol table separately. For m8_2 the whole diff was absolute:
   5208 → 5207, the one intended removal, no value changed. For m1_3 `.text` changed
   too — by **exactly 4 bytes**, and they were exactly the 4 predicted HRAM operands
   (`8e→ec`, `8f→ed`, twice). `equ`s live in the COFF symbol table, so a file hash
   cannot tell metadata from behaviour. The decomposition can. *A byte count matching
   your prediction is evidence only if the bytes are also where you predicted.*

3. **An HRAM free-list from `gb_memmap.inc` alone is WRONG.** `trainer_sight.asm`
   defines four HRAM bytes locally at `0xFF82-0xFF85`, so the header-only scan reports
   them free. Scan the whole tree before allocating any HRAM slot — a header-only scan
   is how the placeholder above became a bug in the first place.

Also verified rather than trusted, because a comment asserted it: NASM accepts an
`equ` repeated at the **same** value and hard-errors on a different one.

---

## 4. `docs/translation_progress.md` is now worth reading

It used to render the hand-maintained `work_queue`, whose statuses only moved when
an agent remembered to file one. Abandoned, it read **97 `translated` against the
label DB's 1673**. Regenerating it would only have re-timestamped a dead number, so
the generator was moved onto `project_state` + the structured annotations (parsed by
*importing* `lint_pret_labels.parse_annotation`, not a second regex).

It now carries per-subsystem coverage and the full defect ledger — worth a look
before picking work:

| engine/menus | engine/overworld | engine/items | home/ | engine/battle | engine/minigame · printer |
|---|---|---|---|---|---|
| 96.8% | 95.9% | 92.7% | 71.0% | 56.2% | 0.0% |

Plus 46 `BUG`, 10 `GLITCH`, 136 `DEVIATION` and 22 annotated stubs *with their
retirement conditions*. Read-only by default; `--scan` refreshes the DB first.

**Open call left to the maintainer:** the `work_queue` pipeline (and its `functions`
/ `stubs` / `translation_log` tables) now has **no reader at all**. Retire it, or
deliberately revive it. Recorded in `docs/current_plan_doc_staleness.md`.

---

## 5. Where to go next

Unchanged from s19 — the relocation tier is empty, so the nearest members of the
same family are next:

1. **`_SpawnPikachu` is a FORKED NAME** for pret's `SpawnPikachu_`, which the
   Preserve-pret-Labels rule forbids. Renaming touches its caller in
   `src/home/pikachu.asm`. Small and well-understood.
2. **The 21 `local_shadow` findings** — all one shape (pret label defined in a
   generated `assets/*.inc`, provider picked as the `.asm` that `%include`s it).
   Probably ONE provider-picker bug; s18 confirmed by hand it is real, not a
   scanner artifact.
3. **`m1_3_pending_symbols.inc`** — the last scaffold, recipe proven (§3).

The ledger in `docs/translation_progress.md` is now a better source for the rest
than any prose list. Longer threads live under "OTHER OPEN THREADS" in
`relocated-labels-grind`, including **the ledge-hop bug**
(`regression-overworld-ledge-hop-never-advanced`, nothing calls `HandleMidJump`) —
a live gameplay defect with no scenario covering it.

s19's two deferred findings are both **closed**: the stale `wJoyIgnore` "= 0xCCB7"
comment (it was in `m8_2_pending_symbols.inc`, not `gb_memmap.inc` as the handoff
said — its value went into `gb_memmap.inc` with a golden citation), and the docs
calling `src/engine/joypad.asm` dead.

---

## 6. Working tree — not mine, untouched

```
?? .opencode/   opencode.json
```

Neither was in scope. Unchanged since s15 flagged them.

---

## 7. Read these first, in this order

1. **`registry-approval-state`** — is a bless owed? (measured, not remembered)
2. **`pending-symbols-scaffolds-and-shadowing-equs`** — the scaffold recipe, the
   shadowing-equ trap, and the byte-identity verification method
3. **`relocated-labels-grind`** — the recipes and landmines outlive the grind
4. **`static-gate-and-ci-wiring`** — the two gates, the hook, the move battery
5. **`shared-worktree-git-safety`** — ALWAYS commit with an explicit pathspec

And the rule that has now earned its place four sessions running: **claim the files,
read the tree, and re-measure the cheap inherited claim.** Every single one s20
checked — the bless, the location of the `wJoyIgnore` comment, "~10 docs" (it was 5
files), "five zero-caller routines" (they call each other; the cluster has no live
*entry*) — was slightly-to-completely wrong, and each took under a minute to check.
