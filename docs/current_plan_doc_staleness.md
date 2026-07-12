# Current Plan: Documentation Staleness Sweep (interactive seed)

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
| `TODO.md` | Wholesale — user-confirmed "stale as fuck"; still frames Phase-2 items as open that are live (wild encounters, battle engine) and misses the real gaps | user statement 2026-07-12; mtime Jul 10 but content predates the battle/overworld landings | confirmed |
| `CLAUDE.md` "Current Phase" | Open-items list ("scripted NPC movement, trainer battle engine, random encounter trigger, battle engine") — scripted NPC movement is DONE, wild encounters + wild battle are LIVE; trainer battles are coded-but-gated | 2026-07-12 surveys; `TRAINER_BATTLE_LIVE` never defined in Makefile | confirmed |
| `.claude/skills/project-conventions/SKILL.md` "Currently active plans" | Lists `current_plan_overworld_port.md` ("Not started") and `current_plan_macros.md` — neither exists; both archived (`docs/plans/overworld_port.md`, `docs/plans/macros.md`). Says battle work is tracked in `docs/battle_audit_findings.md` — that file is now `docs/archive/…` and CLOSED. Omits the newer compositor-perf and bug-tagging plans | `ls docs/current_plan_*.md` vs skill text | confirmed |
| `docs/current_plan_audio.md` | Own checkbox still `[ ]` Phase A (line ~332) and skill says "Phase A not started" — audio phases A–E merged to master 2026-07-07; engine is live in the build | grep + session memory | confirmed (verify merge commit in the session) |
| `docs/current_plan_map_tool.md` | "MAP_BORDER is already 6" — it is 7 since the E/W-seam fix; border-derived reasoning in the plan may need re-checking | CLAUDE.md (`MAP_BORDER` 7 note) | confirmed |
| `docs/archive/battle_audit_findings.md` | CLOSED, but Tier-4 claims now wrong: trainer-AI move selection is linked/live (not dead code); `ReadTrainer` prize money is real (`AddBCD` award in `faint_sendout.asm`) | 2026-07-12 battle survey | confirmed |
| `dos_port/src/engine/battle/battle_exp_stubs.asm` header prose | Names `ApplyBadgeStatBoosts` / `ApplyBurnAndParalysisPenaltiesToPlayer` / `LearnMoveFromLevelUp` as stubs; all three have real linked bodies. Comment-only fix (3 labels in the file ARE still stubs) | battle survey | confirmed |
| `docs/current_plan_script_engine.md` | Being superseded/absorbed by `current_plan_overworld_events.md` (written in parallel this session); needs a header pointer or archival | this session | confirmed |
| `docs/translation_progress.md` | Snapshot last generated 2026-06-25 22:28 UTC — 2.5 weeks and several subsystem landings old | file header | confirmed |
| `translation.db` `stubs` table | 2 rows total (both `PalletTownOakText`); the real stub inventory lives in inline `; STUB(...)` comments — DB does not reflect reality | sqlite query, overworld survey §6 | confirmed |
| `docs/current_plan_bug_tagging.md` | Phase A complete per commit trail (`ac88338f` "Phase A complete", follow-ups through `d0b95c09`); plan may be archivable depending on the optional Phase-B save-draft decision | git log on `chore/bug-tagging` | high |
| ~~`docs/current_plan_battle_ui.md`~~ | **RESOLVED 2026-07-12** — archived to `docs/plans/battle_ui.md` at the user's direction; B6 (human-in-the-loop widescreen redesign) moved to the back burner and tracked in TODO.md | checkbox grep | done |
| `dos_port/tools/pret_label_allowlist.json` | Standing header: "DRAFT (Session H 2026-07-07)… flagged for user review" — review never happened (bug-tagging pass re-verified entries resolve but didn't clear the flag) | file header; `bug_categorization.md` note | confirmed |

Out of scope: agent memory files (private, self-maintained). One convention
reminder for the rewrite: TODO.md = big-picture scope only; work-item detail
belongs in `current_plan_*.md` files (don't duplicate the three new plans into
it).

## Questions for the user (the interactive session asks these)

- **TODO.md:** rewrite wholesale from the three 2026-07-12 plans + survey
  findings, or prune in place keeping the phase structure? Keep the "Known
  Regressions" log section, move it elsewhere, or drop resolved entries?
- **CLAUDE.md "Current Phase":** rewrite now to match reality, and should it
  keep enumerating open items at all (vs pointing at `current_plan_*.md` and a
  slimmed TODO)?
- **project-conventions skill active-plans list:** update in place, or stop
  maintaining a duplicate list in the skill entirely (scan
  `docs/current_plan_*.md` being the convention already)?
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
- **translation_progress.md:** regenerate now, and should regeneration be
  a habit (e.g. part of plan-archival checklists) or on-demand only?
- **pret_label_allowlist.json:** do the deferred review of the 7 `suppress`
  entries + DRAFT header now, or explicitly re-defer with a dated note?
- **Sweep mechanics:** one commit per doc or one sweep commit? Which branch?
