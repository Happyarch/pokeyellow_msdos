# Handoff — session 13 (relocated-labels grind, chunks 2/3/4)

Written 2026-07-26 at the end of the batch. HEAD is `0d5085af` on `master`.
Everything below is measured against that HEAD, not recalled.

---

## 1. FIRST: the bless, and why nothing else can be committed until it happens

The batch retired 19 more relocation rows, which by construction invalidates the
maintainer's allowlist approval. **`registry_approval` is 1 right now,
`tools/static_gate` FAILS, and `.githooks/pre-commit` therefore blocks every
commit that stages anything under `dos_port/`.**

Maintainer command (agents must never run this — it is the one thing that lives
outside the worktree so no commit can forge it):

```
git config pokeyellow.pretAllowlistApprovedSha256 \
  6916f93ac83b77564ebc168fad3f9f5eb133d34fa2519f33fba7dacedca61e1b
```

Verify it took:

```
cd "/mnt/sdb1/Code/Active Code/pokeyellow_msdos"
git config --get pokeyellow.pretAllowlistApprovedSha256
sha256sum dos_port/tools/pret_label_allowlist.json      # must match
dos_port/tools/lint_pret_labels                          # expect 0 violations / 5 suppressed
dos_port/tools/static_gate                               # expect PASS — 5 static checks
```

96 rows in the registry; the label DB agrees at 96.

### The one job owed immediately after the bless

The customary `translation.db` restamp could not be committed — that commit stages
a `dos_port/` path, so the hook blocks it. The DB was deliberately restored to its
committed state rather than left staged in the shared index (another agent's bare
commit would sweep it). After blessing:

```
cd "/mnt/sdb1/Code/Active Code/pokeyellow_msdos"
dos_port/tools/update_label_db          # expect: relocated=96, build: 248 linked + 8 check-only
git add -- dos_port/tools/translation.db
git commit -- dos_port/tools/translation.db     # message: "tools: restamp translation.db at HEAD"
```

Note: a **docs-only** commit still lands while unapproved — the hook exits 0 when
nothing under `dos_port/` is staged (lines 24-26). That is by design, not a hole,
and is how commit `0d5085af` went in. Do not reach for `--no-verify`.

---

## 2. What landed

| commit | what |
|---|---|
| `0e709e81` | chunk 2 — 15 `home/map_objects.asm` rows into a NEW mirror; deleted `src/home/simulate_joypad.asm` |
| `51ba99e1` | chunk 2 registry retirement (130 → 115) |
| `aa121793` | chunk 2 restamp (the maintainer blessed `8972c75b` mid-session, so this one landed) |
| `00c7d0a9` | chunk 3 — 8 `home/palettes.asm` rows into the existing mirror + a 58-comment provider sweep |
| `fec6e9a3` | chunk 4 — 11 `engine/battle/core.asm` rows; **deleted 9 port files** |
| `16e1a9ac` | chunks 3+4 registry retirement (115 → 96) — **awaiting bless** |
| `0d5085af` | doc-staleness patrol: 39 dangling live-doc pointers measured, 19 fixed |

Debt: **130 → 96 rows.** Linked sources 257 → 248. Tree-wide fallthrough
unchanged at 142. `--strict-claims` back at its 24 baseline (21 `local_shadow` +
3 `hand_encoded_text`), `stale_provider` 0. `make fidelity-full` ran clean after
each of the three move units: `MAKE_EXIT=0`, token census exactly `33 PASS`.

Per-row coverage verdicts are in each commit message, settled by reading call
sites at that HEAD. Tally: chunk 2 **1 of 15** rows executed, chunk 3 **7 of 8**,
chunk 4 **6 of 11**. For the rest a green suite is a regression result, not
feature evidence.

---

## 3. Next chunk

`engine/pokemon/evos_moves.asm`, 8 rows, **new mirror**, own session. 425
instructions, dominated by `EvolutionAfterBattle` at **247** — bigger than chunks
1 and 3 put together. No structural landmine; it is pure review surface.

After that, the tail: ~37 pret files, ~88 rows, batched by pret directory. Biggest
remaining clusters: `home/vcopy.asm` 7, `engine/overworld/pathfinding.asm` 5,
`engine/battle/scale_sprites.asm` 5, `engine/items/item_effects.asm` 5. Re-measure
rather than trusting this list:

```sql
select pret_file, count(*) from labels where status='relocated'
group by pret_file order by 2 desc;
```

Read memory `relocated-labels-grind` (v28) before planning — it now carries the
chunking order, the extraction recipe, and everything this batch learned. Read
`static-gate-and-ci-wiring` (v7) for the two gates and their traps.

---

## 4. Findings surfaced and deliberately NOT fixed

Each is stated in the commit that surfaced it. None is a regression; all are
pre-existing or out of a relocation's scope.

1. **`RestoreScreenTilesAndReloadTilePatterns` still drops its `call
   RunDefaultPaletteCommand`.** After chunk 3 the target is defined ~60 lines
   below it *in the same file*, so what is missing is the audit, not a symbol.
   Wiring it is a behaviour change and needs golden evidence.
2. **`GBPalNormal` drops pret's three `UpdateCGBPal_*` calls** ("deferred to Phase
   5") while `GBPalWhiteOut` — now its immediate neighbour — makes all three. The
   move made the inconsistency visible; it did not introduce it.
3. **`dos_port/src/engine/battle/core.asm` is not in pret order and never has
   been.** s8 assembled it by appending whole files under `; --- was <file> ---`
   banners. Measured: for 6 of chunk 4's 11 rows the pret-preceding anchor sits at
   a *higher* port line than the pret-following one, so no insertion point
   satisfies both. Chunk 4 followed the file's own convention and ordered the new
   routines in pret order among themselves. Interleaving 5.5k lines is a separate
   change.
4. **20 dangling path pointers remain** in `docs/current_plan_*.md` prose (mostly
   `tools/gen_*.py` paths from before the move to `tools/generators/`). Owner is
   `docs/current_plan_doc_staleness.md`, which exists for exactly this.
5. **The hand-written "Currently active plans" list in CLAUDE.md / AGENTS.md (and
   the `project-conventions` skill) is materially wrong** — needs a decision, not
   an edit. It lists `docs/current_plan_script_engine.md` and
   `docs/current_plan_overworld_port.md`, **neither of which exists**, and omits
   five plans that do (`battle_completion`, `bug_tagging`, `doc_staleness`,
   `menu_intro`, `overworld_events`). Measured against
   `dos_port/tools/project_state --plans`, the generated inventory CLAUDE.md
   itself tells agents to use — and CLAUDE.md's own Evidence policy says not to
   maintain a second hand-written inventory. Delete it in favour of the generated
   one, or re-sync it. Maintainer's call.

---

## 5. Still open, still not mine

- **The uncommitted foreign work — ASSIGNED TO YOU (maintainer decision,
  2026-07-26).** `dos_port/src/engine/overworld/player_animations.asm` (a
  Fly/Town-Map page-fault fix, **4** well-formed `DEVIATION` annotations —
  measured; an older memory said 3) plus `.codex/config.toml`. Untouched by s11,
  s12 and s13, and deliberately excluded from every commit this session — verified
  by grepping the swept provider string out of its diff and by confirming it is
  absent from each commit's `--stat`.

  **The maintainer has decided: take it with your next set of rows.** So it is no
  longer homeless, and it is no longer optional — commit it as part of the
  `evos_moves` chunk (or whichever chunk you run), not as a separate orphan.
  Things to know before you do:
  - It **is** in the linked build already, so every suite run since it appeared —
    including this session's three clean `33 PASS` runs — included it. That is
    regression evidence for it, and nothing more.
  - **No scenario covers Fly, Teleport, Dig or any warp**, so the fix itself is
    entirely ungated. Do not let the green suite read as evidence that the fix
    works; say so explicitly in the commit message the way the per-row coverage
    verdicts do.
  - Its four `DEVIATION` annotations were already well-formed when measured — check
    them against `lint_pret_labels` anyway, since you will be the one committing
    them and the annotation format is machine-parsed.
  - It carries a stale `extern Delay3 ; video/frame.asm` (the provider moved to
    `src/home/palettes.asm` in `00c7d0a9`). It does NOT trip `stale_provider` (no
    `src/` prefix), which is why s13 left it — fix it while you own the file.
  - `.codex/config.toml` is a different agent's tooling config, not port code.
    Judge it separately; see memory `dosbox-mcp-codex-config-uses-absolute-paths`
    for why it was edited.
- **CI has never run.** `origin/master` is ~267 commits behind (last push
  2026-07-17). The workflow and the `PRET_ALLOWLIST_APPROVED_SHA256` repo variable
  are both inert until someone pushes. See `ci-inert-until-master-is-pushed`.
- **Phase 2 of the debt plan** (21 `local_shadow` findings) and **phase 3** (82
  stubs) are still queued behind relocations. Phase 3 collides with the feature
  freeze — retiring a stub means implementing the routine — and needs its own
  conversation.

---

## 6. Traps this batch paid for, so you don't

- **`git add` refuses a path already staged as a deletion.** After `git rm`, the
  path is in neither the worktree nor the index, so `git add -- <path>` fails with
  "did not match any files". The deletion is *already* staged; just name the path
  in `git commit -- …` (its pathspec resolves against HEAD too). Verify with
  `git show --stat --format="" HEAD` — a deleted file must appear with a
  pure-deletion line.
- **This shell is zsh: unquoted `$VAR` does not word-split.** `git add -- $FILES`
  passes one giant path. Use an array and `"${ARR[@]}"`.
- **Plain `lint_pret_labels` with no flags rescans the tracked `translation.db`
  in place**, silently re-dirtying it. Pass `--no-scan` when you only want
  findings. (`static_gate` got the temp-DB fix in `b0f4ad98`; its sibling did not.)
- **Do not invent a provider comment for an extern that had none.** Chunk 4
  supplied `; src/engine/battle/animations.asm` for
  `PredefShakeScreenHorizontally` from memory; `--strict-claims` went 0 → 1 and
  named it — it is a STUB in `core_stubs.asm`. Look providers up in `port_defs`.
- **`--gates auto` builds nothing** when the unit's own files have no `%ifdef`,
  which is the normal case for a relocation. Name gates by hand from the
  *callers'* subsystems, and get real names from `build_flags` in
  `tools/scenario_manifest.json` — there is no `DEBUG_POKEDEX` (it is `DEBUG_G1` /
  `DEBUG_G2`), and the tool correctly hard-fails an unknown name.
- **A file header can lie about what the file contains.** `simulate_joypad.asm`
  documented two routines defined elsewhere; `wild_encounter_check.asm` advertised
  four and held one. Grep before believing.
- **A port file's pret attribution can be wrong**, and 10 of chunk 4's 11 labels
  are `Label:` (single colon) in pret, so a `::`-only grep finds nothing.
