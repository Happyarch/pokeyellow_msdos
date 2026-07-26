# Handoff

**This is the ONE handoff file. Overwrite it; do not create `handoff_s16.md`.**

Sessions 10, 13 and 14 each left their own `handoff_s*.md` behind and nothing
ever deleted them, so by s15 the repo root held three handoffs — one untracked
and three sessions stale — with no way to tell from the filenames which was
current. All three were purged in s15. Rewrite *this* file at the end of your
session. Anything that outlives one session belongs in **stigmergy**, not here;
this file is a pointer sheet, not a record.

**Written:** 2026-07-26 (session 15) · **Branch:** `master`

Everything below is measured, not recalled. **Re-measure anything you intend to
rely on** — including the numbers here.

---

## 1. Nothing is owed. One thing awaits the maintainer.

The 58-row allowlist bless landed before s15 started, and s15 then retired six
more rows, so a **new** bless is outstanding:

```
git config --get pokeyellow.pretAllowlistApprovedSha256
sha256sum dos_port/tools/pret_label_allowlist.json
```

Run both. While they differ, `registry_approval` is 1, `static_gate` fails, and
**every commit staging anything under `dos_port/` is blocked**. Docs-only commits
still land (the hook exits 0 when nothing under `dos_port/` is staged).
**Do not `--no-verify`. Agents must never run the bless themselves.**

**MAINTAINER ACTION — the one thing owed** (52-row allowlist, retired in
`3026f32a`):

```
git config pokeyellow.pretAllowlistApprovedSha256 \
  a3d2da9e869101202413a47e2d08a090572a8b865218d502d8b24c96e1ed3cee
```

**Verify that against a real `sha256sum` run before using it.** s15 fabricated
this hash in the retirement commit message on the first attempt and had to amend
it — a hash written into prose is not evidence, wherever you read it.

No `translation.db` restamp is stuck behind the block: s15 restamped in
`67aac60c`, after its chunk and before its retirement.

---

## 2. What s15 landed

| commit | what |
|---|---|
| `ca0da4b7` | chunk 11 — names / names2 / item mirror repair, 6 rows, NEW mirror, `item_predicates.asm` deleted |
| `67aac60c` | restamp `translation.db` at that HEAD |
| `707dc237` | docs staleness sweep + handoff purge + a misleading skill claim |
| `3026f32a` | **the registry retirement, 6 rows, 58 → 52** (amended to fix a fabricated hash) |

Debt **58 → 52** by DB count. Linked sources unchanged at **249**. Tree-wide
fallthrough unchanged at **142**. `--strict-claims` at its standing baseline
(24 = 21 `local_shadow` + 3 `hand_encoded_text`). `make fidelity-full` after the
chunk: `MAKE_EXIT=0`, token census exactly **33 PASS** and no other token, read
from the full log rather than through a pipe.

**Coverage: 4 of 6 rows executed** (`GetName`, `NamePointers`, `IsKeyItem`,
`IsItemHM` via `bag_menu`). `IsMoveHM`/`HMMoves` are **not** executed — see the
commit message; for those two a green suite is a regression result only.

---

## 3. Do this first

**Read memory `relocated-labels-grind`.** It is the load-bearing one: chunking
order, the extraction recipe, and every landmine s12–s15 hit. Then
`static-gate-and-ci-wiring` for the two gates and the `DECL_RE` rules that decide
how you may cut a file, and `shared-worktree-git-safety` before you delete
anything.

**Chunk 12 is already scoped and it is the cheapest one left** — three files
whose *entire* contents are the relocated pair, so two are pure renames and one
is a merge:

| rows | move |
|---|---|
| 2 | `src/video/lcd_control.asm` → **`src/home/lcd.asm`** (`DisableLCD`, `EnableLCD`) |
| 2 | `src/home/sprites.asm` → **`src/home/clear_sprites.asm`** (`ClearSprites`, `HideSprites`) |
| 2 | `src/home/map_text_pointer.asm` → merge into the **existing** `src/home/predef_text.asm` (`RestoreMapTextPointer`, `SetMapTextPointer`) |

Sweep size measured: `home/sprites.asm` has 12 provider comments + 2 bare
`sprites.asm` ones, and **CLAUDE.md and AGENTS.md both cite
`src/home/sprites.asm` by name** — those two are live pointers you must update in
the same commit. `lcd_control` ~17 mentions, `map_text_pointer` 4.

Re-measure the clusters rather than trusting any list:

```sql
select pret_file, count(*) from labels where status='relocated'
group by pret_file order by 2 desc;
```

At the end of s15 the biggest remaining is **`engine/overworld/sprite_collisions.asm`,
4 rows**, all inside `src/engine/overworld/movement.asm`. It is still the first
genuinely entangled unit and still deserves a whole session — `_UpdateSprites`
and `UpdateNonPlayerSprite` sit at the top of a 1734-line file interleaved with
pret `movement.asm` labels. Do not start it as a warm-up.

---

## 4. Traps s15 paid for

- **`--gates` is COMMA-separated and a space-separated list fails misleadingly.**
  The whole string is parsed as one gate name, so you get
  `not gates in the Makefile: <everything you typed>` — which reads like your
  gate names are wrong when the separator is. Also: `DEBUG_BATTLE_GOLDEN` is
  silently subtracted from the build list by design, so its absence from the OK
  list is not a skip.
- **`align 4` and plain `%if` are NOT declarations** to the move battery
  (`DECL_RE` lists `%ifdef`/`%ifndef` but not `%if`). They must move verbatim
  with their data/code. `section .data` *is* a declaration, so pinning it to the
  source and emitting a fresh one at the destination is legal and costs +1.
- **A file's NAME can lie about which mirror it is — again.** `src/home/names.asm`
  was not purely the mirror of `home/names.asm`; it held pret `home/names2.asm`'s
  two labels as well. Every chunk since s14 has hit this. Check what a file
  *holds* before believing its name, and expect to evict squatters.
- **An annotation's `pret=` field can be wrong and the linter cannot tell.** The
  `GetName` `BUG{}`/`GLITCH{}` pair claimed `pret=home/names.asm:GetName`; GetName
  is a `home/names2.asm` label. The linter parses the FORM, never the truth of the
  path.
- **A scenario's seed can deliberately defeat the branch you are trying to claim
  coverage for.** `RunTMHMTest` frees three move slots specifically so
  `TryingToLearn` is never entered. Read the harness routine, not just the call
  graph — the seed decides the verdict.

Still true from earlier sessions: never read a suite result through a pipe; plain
`lint_pret_labels` rescans the tracked DB in place (use `--no-scan`); don't invent
a provider comment for an extern that had none; `git add` refuses a path already
staged as a deletion (name it in `git commit --` only); do not edit any source
while `make fidelity-full` is running (15–20 min, it rebuilds per scenario).

---

## 5. Docs and memory patrol (s15)

A read-only patrol extracted 815 path references from `CLAUDE.md`, `AGENTS.md`,
`ROADMAP.md` and every `docs/current_plan_*.md`, and resolved each against the
tree. **CLAUDE.md and AGENTS.md came back clean.** Fixed this session:

- 8 `tools/gen_*.py` → `tools/generators/gen_*.py` across 4 plans.
- `src/movie/title.asm` → `src/engine/movie/title.asm` (2 sites).
- `docs/battle_audit_findings.md` → `docs/archive/…`; `current_plan_{overworld_port,macros}.md`
  → `docs/plans/…`; `docs/llm_arranger_design_notes.md` → `docs/plans/…`;
  `dos_port/tools/gate` → `tools/static_gate`; `src/init/init.asm` → `src/home/init.asm`.
- `ROADMAP.md` claimed the audio HAL was unbuilt because it looked for
  `audio_hal.inc`; it landed as `src/audio/audio_hal.asm`. `serial_hal.inc` is a
  proposed name, not a path, and now says so.
- `current_plan_audio.md`: `src/audio/audio_stubs.asm` is deleted (the file
  contradicted itself on this); `src/audio/engine.asm` split into `engine_1..4`.
- `current_plan_overworld_events.md`: the `oak_intro.lua.disabled` scaffold is
  **enabled, committed and PASSING** — two bullets described a state that had not
  held for some time.
- Ambiguous bare basenames qualified (`palettes.asm`, `special_warps.asm`).
- **The `project-conventions` skill was actively misleading**: it said the
  script-engine plan was "never archived, so do not go looking in `docs/plans/`".
  It IS there — `docs/plans/current_plan_script_engine.md`, which kept its
  `current_plan_` prefix against the archive convention, which is why searching
  for `docs/plans/script_engine.md` finds nothing.

Memories corrected: `static-gate-and-ci-wiring` and `relocated-labels-grind` (both
still said the bless was outstanding), `menu-intro-devloop-review-findings` (the
"foreign work" was adopted by s14 in `64400890`, not still pending), and
`ci-inert-until-master-is-pushed` (the commit gap is a moving number — 292 at s15,
not the 253 recorded).

**Left unfixed, deliberately** — each needs a decision, not a sweep:
`faint_sendout.asm`, `intro_anim_data.asm` and `bg_anim.asm` are cited by plans
but exist only as stale `.o` build artifacts with no surviving source, so there is
no correct replacement to write. Six bare `overworld.asm` citations remain
genuinely two-way ambiguous inside `dos_port/src/`.

---

## 6. Still open, not started

- **Phase 2** — the 21 `local_shadow` findings, all one shape (pret label defined
  in a generated `assets/*.inc`, provider picked as the `.asm` that `%include`s
  it), so probably one provider-picker bug. Queued behind relocations.
- **Phase 3** — the 82 stubs. Retiring one means implementing the routine (32 of
  the 82 are `hidden_object_stubs.asm`), so it collides with the feature freeze
  and needs its own conversation with the maintainer.
- **CI has never run.** `origin/master` is 292 commits behind (last push
  2026-07-17) and the `PRET_ALLOWLIST_APPROVED_SHA256` repo variable is unset, so
  both are inert. The action is *push*, not "set the variable" — memory
  `ci-inert-until-master-is-pushed` ranks what CI would actually buy.
- **The Fly/Town-Map fix is in the linked build and covered by NOTHING.** No
  scenario exercises Fly, Teleport, Dig or any warp. Every `33 PASS` since it
  appeared includes it; that is evidence it breaks nothing and no evidence that it
  works. A warp golden is the retirement.
- Carried and still open: `RestoreScreenTilesAndReloadTilePatterns` drops its
  `call RunDefaultPaletteCommand`; `GBPalNormal` drops three `UpdateCGBPal_*`
  calls its neighbour makes; `src/engine/battle/core.asm` is not in pret order;
  `GetMonLearnset_Evo` has zero callers tree-wide.

---

## 7. Working tree — not mine, untouched

```
?? .opencode/   opencode.json   docs/menu_intro_plan.md
```

`docs/menu_intro_plan.md` is stale (it describes `dos_port/src/movie/title.asm`,
a path that has not existed for some time). None of these were in scope; they are
left for the maintainer to judge.
