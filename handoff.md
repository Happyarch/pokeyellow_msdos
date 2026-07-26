# Handoff

**This is the ONE handoff file. Overwrite it; do not create `handoff_s16.md`.**

Sessions 10, 13 and 14 each left their own `handoff_s*.md` behind and nothing ever
deleted them, so by s15 the repo root held three handoffs — one untracked and
three sessions stale — with no way to tell from the filenames which was current.
All three were purged. Rewrite *this* file at the end of your session. Anything
that outlives one session belongs in **stigmergy**, not here; this is a pointer
sheet, not a record.

**Written:** 2026-07-26 (session 15) · **Branch:** `master`

Everything below is measured. **Re-measure anything you rely on**, including these
numbers.

---

## 1. Nothing is owed. The tree is green and unblocked.

The maintainer blessed the 52-row allowlist mid-session, so:

```
git config --get pokeyellow.pretAllowlistApprovedSha256
sha256sum dos_port/tools/pret_label_allowlist.json
```

were **equal** at end of session → `registry_approval` 0, `static_gate` passes,
`dos_port/` commits unblocked, no restamp pending. Run both anyway; this line goes
stale the moment anyone retires a row. Live state lives in **one** memory now:
`registry-approval-state`.

**You should never type that hash again.** `.githooks/pre-commit` now computes and
prints it (plus the row count and the exact bless command) whenever the allowlist
is staged, and the new `.githooks/prepare-commit-msg` appends the same measured
facts to the commit message. Regression test:
`.githooks/test_prepare_commit_msg.sh`, 13 assertions — re-run it if you touch
either hook, because both of its failure modes are silent.

---

## 2. What s15 landed

| commit | what |
|---|---|
| `ca0da4b7` | chunk 11 — names / names2 / item mirror repair, 6 rows, NEW mirror, `item_predicates.asm` deleted |
| `67aac60c` | restamp `translation.db` |
| `707dc237` | docs staleness sweep, handoff purge, one misleading skill claim |
| `a561c72c` | registry retirement, 6 rows, **58 → 52** |
| `3ac9b60a` | hooks compute the registry SHA-256 (+ checked-in test) |
| `e58dadf1`, `a5c01595`, `d7d4cdaf` | handoff fixups |

Debt **58 → 52**. Linked sources **249** (unchanged — the deleted file's
`GAME_SRCS` slot went to the new mirror). Fallthrough **142**. `--strict-claims`
at its standing **24** (21 `local_shadow` + 3 `hand_encoded_text`).
`make fidelity-full`: `MAKE_EXIT=0`, census exactly **33 PASS**, read from the full
log not a pipe.

**Coverage 4/6.** `bag_menu` reaches `GetName`, `NamePointers`, `IsKeyItem`,
`IsItemHM`. `IsMoveHM`/`HMMoves` are **not** executed — `RunTMHMTest`'s seed
deliberately frees three move slots so `TryingToLearn` is never entered. For those
two, green is a regression result only.

---

## 3. Do this first

Read memory **`relocated-labels-grind`** (chunking order, recipes, landmines), then
**`static-gate-and-ci-wiring`** (the two gates, the `DECL_RE` rules that decide how
you may cut a file), then **`shared-worktree-git-safety`** before deleting anything.

**Chunk 12 is scoped and is the cheapest work left** — three files whose *entire*
contents are the relocated pair, so two are pure renames and one is a merge:

| rows | move |
|---|---|
| 2 | `src/video/lcd_control.asm` → **`src/home/lcd.asm`** (`DisableLCD`, `EnableLCD`) |
| 2 | `src/home/sprites.asm` → **`src/home/clear_sprites.asm`** (`ClearSprites`, `HideSprites`) |
| 2 | `src/home/map_text_pointer.asm` → merge into the **existing** `src/home/predef_text.asm` |

Sweep measured: `home/sprites.asm` has 12 provider comments + 2 bare ones, and
**CLAUDE.md and AGENTS.md both cite `src/home/sprites.asm` by name** — live pointers
that must move in the same commit. `lcd_control` ~17 mentions, `map_text_pointer` 4.

Re-measure the clusters rather than trusting any list:

```sql
select pret_file, count(*) from labels where status='relocated'
group by pret_file order by 2 desc;
```

Biggest remaining after that: **`engine/overworld/sprite_collisions.asm`, 4 rows**,
all inside a 1734-line `movement.asm` interleaved with pret labels. Still the first
genuinely entangled unit. Budget a whole session; don't use it as a warm-up.

---

## 4. Traps s15 paid for

- **`--gates` is COMMA-separated.** A space-separated list is parsed as one name,
  so you get `not gates in the Makefile: <everything you typed>` — reads like your
  names are wrong when the separator is. `DEBUG_BATTLE_GOLDEN` is silently dropped
  by design; its absence from the OK list is not a skip.
- **`align 4` and plain `%if` are NOT declarations** to the move battery
  (`DECL_RE` has `%ifdef`/`%ifndef`, not `%if`), so they must move verbatim.
  `section .data` *is* one, so pinning it to the source and emitting a fresh one at
  the destination is legal and costs +1.
- **A file's NAME can lie about which mirror it is — every chunk since s14 has hit
  this.** `src/home/names.asm` held pret `home/names2.asm`'s two labels as well as
  its own, turning a "3-row cluster" into a 6-row three-way repair.
- **An annotation's `pret=` can be wrong and the linter cannot tell** — it parses
  the form, never the truth of the path. Re-check `pret=` whenever an annotation
  travels with a moved routine.
- **A scenario seed can deliberately defeat the branch you want to claim.** Read
  the harness routine, not just the call graph.
- **Never leave a hash-shaped hole in prose.** s15 fabricated a well-formed
  SHA-256 into a commit message; a hash has no semantic content so a wrong one
  looks exactly right. Fixed structurally (§1). Corollary: **record a commit id
  only after the commit is final** — the amend that fixed the hash orphaned the id
  already written into memory.

Still true: never read a suite result through a pipe; plain `lint_pret_labels`
rescans the tracked DB (use `--no-scan`); don't invent a provider comment for an
extern that had none; `git add` refuses a path already staged as a deletion; don't
edit any source while `make fidelity-full` runs (15–20 min, rebuilds per scenario).

---

## 5. Staleness patrols (s15)

**Docs.** 815 path references resolved across `CLAUDE.md`, `AGENTS.md`,
`ROADMAP.md` and every `docs/current_plan_*.md`. **CLAUDE.md and AGENTS.md came
back clean.** Fixed: 8 `tools/gen_*.py` → `tools/generators/`, `src/movie/` →
`src/engine/movie/`, five archived-doc paths, `tools/gate` → `tools/static_gate`,
`src/init/init.asm` → `src/home/init.asm`, plus three materially-wrong claims
(ROADMAP calling the audio HAL unbuilt because it looked for a `.inc`;
`current_plan_audio.md` citing a deleted `audio_stubs.asm` it contradicted itself
about 300 lines later; `oak_intro` described twice as a disabled scaffold when it
is enabled and passing). The `project-conventions` skill said the script-engine
plan was "never archived, so do not go looking in `docs/plans/`" — it is at
`docs/plans/current_plan_script_engine.md`.

**Memories.** All ~84 project memories verified against the tree by three
read-only agents; **12 corrected**. The ones that would have cost someone real
time:

- `port-predefs-as-inline-tables` said `IndexToPokedex` is a data table you must
  never `call`. It is a **real routine with 12 correct call sites** — acting on the
  old wording would have deleted them all.
- `map-connection-border6-clamp-bug` was still filed as an open bug; fixed in
  `397766ae`, and both constants it keyed on (`BORDER=6`, `_tgt < 2`) are gone.
- `trainer-engine-m83-headers` pointed at `src/scripts/route_3.asm`, deleted the
  same day it was written.
- `pret-relocations-forbidden` named four structural findings; all retired,
  `structural_findings` is `{}`.
- `overworld-events-stage1-oak-intro-handoff` said the oak_intro golden is
  disabled; it is active and passing.
- `overworld-events-stage4-fly-arrival-open` said its work was uncommitted pending
  verification; it was committed anyway, so **the Fly fix is in the linked build
  and no scenario covers Fly, Teleport, Dig or any warp**.

Also corrected: `battle-text-composed-in-code-audit` (its OPEN A was fixed two days
earlier), `compositor-perf-invariants` (all four "unaudited VRAM writers" settled),
`coord-macros-logic-audit` + `debug-walk-north-oob-path` (`MAP_BORDER` is 7; the
harness moved), `project-mcp-debugger` (generator path + symbol count),
`colorization-c0-c1-pipeline`, `yellow-intro-palette-mewmon-bug` (line refs, and it
was stored with literal `\n` escapes), `pret-relocation-enforcement-escalation`,
`ci-inert-until-master-is-pushed`, `menu-intro-devloop-review-findings`.

**Structural fix, not just edits:** the registry approval state was embedded in two
~600-line memories, so every bless invalidated a headline and forced a full
rewrite — it went stale twice inside this one session. It now lives in its own
small key, `registry-approval-state`, and both long memories delegate to it.

**Recurring shapes worth knowing** (they will recur): a per-stage handoff memory
nobody closed when the next stage landed; a "still OPEN" item fixed days later by
someone who never looked for the memory; a canonical example that inverted; and
generator paths left behind by the `tools/` → `tools/generators/` move. **When you
fix something, grep the memory list and close the entry in the same commit.**

**Left unfixed deliberately:** `faint_sendout.asm`, `intro_anim_data.asm` and
`bg_anim.asm` are cited by plans but survive only as stale `.o` artifacts with no
source — no correct replacement exists to write. Six bare `overworld.asm` citations
are genuinely two-way ambiguous inside `dos_port/src/`.

---

## 6. Still open, not started

- **Phase 2** — the 21 `local_shadow` findings, all one shape (pret label defined
  in a generated `assets/*.inc`, provider picked as the `.asm` that `%include`s it),
  so probably one provider-picker bug.
- **Phase 3** — the 82 stubs. Retiring one means implementing the routine (32 are
  `hidden_object_stubs.asm`), so it collides with the feature freeze and needs its
  own conversation.
- **CI has never run.** `origin/master` is 292 commits behind (last push
  2026-07-17); the action is *push*, not "set the variable" —
  `ci-inert-until-master-is-pushed` ranks what it would actually buy. A known
  pre-existing gap: `pre-commit` exits early when nothing under `dos_port/` is
  staged, so an amend that changes no `dos_port/` content never re-runs the gate.
- **Fly/warp is entirely ungated** (see §5). A warp golden is the retirement.
- Carried: `RestoreScreenTilesAndReloadTilePatterns` drops its
  `call RunDefaultPaletteCommand`; `GBPalNormal` drops three `UpdateCGBPal_*` calls
  its neighbour makes; `src/engine/battle/core.asm` is not in pret order;
  `GetMonLearnset_Evo` has zero callers tree-wide; the Yellow intro still renders
  in Mew's palette (Phase-5 CGB gap).

---

## 7. Working tree — not mine, untouched

```
?? .opencode/   opencode.json   docs/menu_intro_plan.md
```

`docs/menu_intro_plan.md` is stale (it describes `dos_port/src/movie/title.asm`, a
path that has not existed for some time). None were in scope; left for the
maintainer.
