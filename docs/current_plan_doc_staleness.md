# Current Plan: Documentation Staleness Sweep (interactive seed)

> **Gate — re-run the STRICT linter, every time (rule change 2026-07-25).**
> `dos_port/tools/lint_pret_labels` on its own is NOT sufficient and never was.
> It does not gate on `legacy_annotation`, `stale_provider`, `local_shadow` or
> `hand_encoded_text` — only `dos_port/tools/lint_pret_labels --strict-claims`
> reports those, and nothing runs it for you.
>
> For every commit made under this plan:
> 1. Record the strict finding counts **before** you start, per class.
> 2. Run **both** `lint_pret_labels` and `lint_pret_labels --strict-claims`
>    before committing.
> 3. Compare per class. A class that grew is your regression to fix now, not
>    the next agent's to discover. Moving a routine between files silently
>    invalidates `extern` provider comments elsewhere in the tree, and that
>    collateral is visible **only** under `--strict-claims`.
>
> Do not quote a finding count from this file, CLAUDE.md, AGENTS.md, a skill, or
> a stigmergy memory as evidence that a class is clean — every one of those has
> been wrong before. Re-measure it.

Status: **seed only — do not execute autonomously.** This file is the input to
a FUTURE INTERACTIVE session: an agent walks this list with the user, asks the
questions below, and only then edits/archives docs per the answers. Nothing
here is a fix; it is an inventory. Archive to `docs/plans/doc_staleness.md`
when the sweep is done.

Origin: 2026-07-12 engine-gap survey session (three code surveys of battle /
items / overworld-events, ground truth = linked code, not docs). The survey
findings themselves live in `current_plan_overworld_events.md`,
`current_plan_battle_completion.md`, `current_plan_items.md` (written the same
session) — treat those as the ground-truth replacements when rewriting
anything below.

## Stale-item inventory

| Doc / artifact | What's stale | Evidence | Confidence |
|---|---|---|---|
| ~~`TODO.md`~~ | **RESOLVED 2026-07-25/26 — DELETED, not rewritten** (commit `3bee670d`). The maintainer chose deletion over the wholesale rewrite this row proposed. Its orphaned deferred tails now live in `docs/current_plan_backlog.md` (created 2026-07-26); dangling references repointed there. Recoverable: `git show 3bee670d^:TODO.md` | user statement 2026-07-12; deletion commit 3bee670d | done |
| `CLAUDE.md` "Current Phase" | Open-items list ("scripted NPC movement, trainer battle engine, random encounter trigger, battle engine") — scripted NPC movement is DONE, wild encounters + wild battle are LIVE; trainer battles are coded-but-gated | 2026-07-12 surveys; `TRAINER_BATTLE_LIVE` never defined in Makefile | confirmed |
| `.claude/skills/project-conventions/SKILL.md` "Currently active plans" | Lists `docs/plans/overworld_port.md` ("Not started") and `docs/plans/macros.md` — neither exists; both archived (`docs/plans/overworld_port.md`, `docs/plans/macros.md`). Says battle work is tracked in `docs/archive/battle_audit_findings.md` — that file is now `docs/archive/…` and CLOSED. Omits the newer compositor-perf and bug-tagging plans | `ls docs/current_plan_*.md` vs skill text | confirmed |
| `docs/current_plan_audio.md` | Own checkbox still `[ ]` Phase A (line ~332) and skill says "Phase A not started" — audio phases A–E merged to master 2026-07-07; engine is live in the build | grep + session memory | confirmed (verify merge commit in the session) |
| `docs/current_plan_map_tool.md` | "MAP_BORDER is already 6" — it is 7 since the E/W-seam fix; border-derived reasoning in the plan may need re-checking | CLAUDE.md (`MAP_BORDER` 7 note) | confirmed |
| `docs/archive/battle_audit_findings.md` | CLOSED, but Tier-4 claims now wrong: trainer-AI move selection is linked/live (not dead code); `ReadTrainer` prize money is real (`AddBCD` award in `faint_sendout.asm`) | 2026-07-12 battle survey | confirmed |
| `dos_port/src/engine/battle/battle_exp_stubs.asm` header prose | Names `ApplyBadgeStatBoosts` / `ApplyBurnAndParalysisPenaltiesToPlayer` / `LearnMoveFromLevelUp` as stubs; all three have real linked bodies. Comment-only fix (3 labels in the file ARE still stubs) | battle survey | confirmed |
| `docs/plans/current_plan_script_engine.md` | Being superseded/absorbed by `current_plan_overworld_events.md` (written in parallel this session); needs a header pointer or archival | this session | confirmed |
| `docs/translation_progress.md` | Snapshot last generated 2026-06-25 22:28 UTC — 2.5 weeks and several subsystem landings old | file header | confirmed |
| `translation.db` `stubs` table | 2 rows total (both `PalletTownOakText`); the real stub inventory lives in inline `; STUB(...)` comments — DB does not reflect reality | sqlite query, overworld survey §6 | confirmed |
| `docs/current_plan_bug_tagging.md` | Phase A complete per commit trail (`ac88338f` "Phase A complete", follow-ups through `d0b95c09`); plan may be archivable depending on the optional Phase-B save-draft decision | git log on `chore/bug-tagging` | high |
| ~~`docs/current_plan_battle_ui.md`~~ | **RESOLVED 2026-07-12** — archived to `docs/plans/battle_ui.md` at the user's direction; B6 (human-in-the-loop widescreen redesign) moved to the back burner and tracked in TODO.md until its deletion; now `docs/current_plan_backlog.md` item 10 | checkbox grep | done |
| `dos_port/tools/pret_label_allowlist.json` | Standing header: "DRAFT (Session H 2026-07-07)… flagged for user review" — review never happened (bug-tagging pass re-verified entries resolve but didn't clear the flag) | file header; `bug_categorization.md` note | confirmed |

Out of scope: agent memory files (private, self-maintained).

The convention reminder that used to sit here was written for a TODO.md rewrite
that never happened — the file was deleted instead. The convention it encoded
still holds, and now reads: big-picture scope is `ROADMAP.md`, work-item detail
is `current_plan_*.md`, and deferred tails with no other owner are
`docs/current_plan_backlog.md`. Do not duplicate a plan's contents into the
backlog file.

## Questions for the user (the interactive session asks these)

- ~~**TODO.md:** rewrite wholesale, or prune in place?~~ **ANSWERED
  2026-07-25/26: neither — deleted (`3bee670d`), with the orphaned tails moved
  to `docs/current_plan_backlog.md`.** The "Known Regressions" log section went
  with it; nothing has re-homed it, so if a regression log is still wanted that
  is a live open question.
- ~~**CLAUDE.md "Current Phase":** rewrite now to match reality, and should it
  keep enumerating open items at all?~~ **ANSWERED 2026-08-02: stop
  enumerating.** The open-items sentence is replaced (in both CLAUDE.md and
  AGENTS.md) by a pointer at `project_state --plans` + `label_status
  --callers`, with a note recording that all four items on the old list were
  wrong in different directions. The technical prose around it — MAP_BORDER,
  the two out-of-map clamps, the OBJ/window Z-order inversion — **stays**: it
  is context no generator produces.
- ~~**project-conventions skill active-plans list:** update in place, or stop
  maintaining a duplicate?~~ **ANSWERED 2026-08-02: stop.** The "plans with no
  entry below" list is deleted; the section keeps only per-plan narrative and
  defers existence questions to the generator. It had already lost
  `current_plan_predef_text.md`, which appeared in neither the list nor the
  entries — measured 2026-08-02.

**Governing rule adopted 2026-08-02 (applies beyond the rows above):** where
the tooling can generate an inventory, agent-facing docs point at the generator
instead of duplicating it. Every confirmed row in the table above is an
instance of the same failure — a hand-maintained duplicate of something
derivable. When fixing a row, prefer deleting the duplicate over correcting it.
- **Archived docs** (`battle_audit_findings.md` Tier-4 claims): add a
  "superseded — see X" banner at the top, annotate the specific rows, or leave
  archives frozen as historical record?
- **Plans to archive now?** `current_plan_bug_tagging.md` (is Phase B save
  draft still wanted?), ~~`current_plan_battle_ui.md`~~ (**answered 2026-07-12:
  archived with B6 as a TODO tail**), `current_plan_script_engine.md` (absorb into
  the new overworld-events plan or keep as the milestone-1 record?).
- **Audio plan:** tick A–E and reconcile its stage list with what actually
  merged, or replace its status block with a pointer to the arrangement
  backlog (~45 songs)?
- **translation.db stubs table:** backfill from the inline `; STUB` comments
  and maintain it, or bless inline comments as the canonical record and note
  that in the plan/skill docs?
- ~~**translation_progress.md:** regenerate now, and should regeneration be
  a habit (e.g. part of plan-archival checklists) or on-demand only?~~
  **ANSWERED 2026-07-27 (s20, at the maintainer's direction): regenerated, then the
  generator was rewritten onto derived data.** Two steps, because the first exposed
  the real problem. The file used to render the **hand-maintained `work_queue`
  pipeline**, whose statuses only move when an agent runs
  `work_queue complete`/`wired`/`verified` — bookkeeping that was abandoned.
  Refreshed as-was, it reported 97 `translated` while the label DB measured 1673. It
  was never going to become accurate by being regenerated more often.
  `gen_progress_report` now reads `project_state` (the scanned label DB) and the
  structured `DEVIATION`/`BUG`/`GLITCH`/`STUB` annotations, parsed by importing
  `lint_pret_labels.parse_annotation` rather than a second regex. So the report is
  now derived from the tree and cannot rot the old way, and it gained the two things
  the queue never had: per-pret-subsystem coverage, and the full known-defect and
  stub ledger with lifetimes.
  On **"should regeneration be a habit?"** — the premise changed with the rewrite.
  It is now a cheap, meaningful refresh rather than a re-timestamping of an unfed
  table, and the report prints the DB scan's commit so a stale run is visible on its
  face. Still deliberately NOT wired into a Make target or a hook: it is a narrative
  document, and a report that regenerates itself in every commit becomes diff noise
  nobody reads. On-demand, and at plan-archival time.
  **Open follow-up for the maintainer:** the `work_queue` pipeline (and its
  `functions` / `stubs` / `translation_log` tables) now has no reader. Retire it, or
  deliberately revive it — but it is currently dead weight that duplicates the label
  DB, which is derived from the tree and cannot rot this way.
- **pret_label_allowlist.json:** do the deferred review of the 7 `suppress`
  entries + DRAFT header now, or explicitly re-defer with a dated note?
- **Sweep mechanics:** one commit per doc or one sweep commit? Which branch?
