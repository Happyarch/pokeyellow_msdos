# Current Plan: Orphaned Backlog (the tracker TODO.md used to be)

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
>    the next agent's to discover.
>
> Do not quote a finding count from this file, CLAUDE.md, AGENTS.md, a skill, or
> a stigmergy memory as evidence that a class is clean — every one of those has
> been wrong before. Re-measure it.

Status: **inventory, not a work order.** Nothing here is scheduled; each entry
is a deferred tail that some other document handed off and then stopped
tracking. Take items from it deliberately, not top-to-bottom.

## Why this file exists

`TODO.md` was deleted 2026-07-25 (commit `3bee670d`) as stale beyond salvage —
the right call: it misreported finished subsystems as open, and agents cited it
as evidence. But it was also the **named tracker of record** for a dozen
deferred tails that memories and archived plans explicitly hand off to it. Those
items briefly lived in no tracker at all. This file is that home, chosen by the
maintainer on 2026-07-26 over splitting them back into subsystem plans, folding
them into `ROADMAP.md`, or rewriting `TODO.md`.

Scope discipline, so this does not rot the way its predecessor did:
- **Big-picture phase scope → `ROADMAP.md`.** Not here.
- **Active multi-step work → its own `docs/current_plan_*.md`.** Not here.
- **Completed work + its deferred tails → `docs/plans/*.md`.** Not here.
- **Battle fidelity findings → `docs/battle_audit_findings.md`.** Not here.
- **Here:** only tails with no other owner. When an item grows into real work,
  it graduates to its own plan file and leaves a one-line pointer behind.

`TODO.md` is recoverable if ever needed: `git show 3bee670d^:TODO.md`.
Full provenance: stigmergy memory `todo-md-deleted-orphaned-trackers`.

**Do not assume an item here is done because the file that tracked it is gone.**
Every entry needs its status re-measured against repository or runtime evidence
before you act on it — this file is an index of leads, not an authority.

---

## Tooling / fidelity infrastructure

### 1. faithdiff has no model of call-site relocation or routine decomposition
Memory: `faithdiff-no-call-relocation-model`. Live example: `RunMapScript`.
When a pret routine is split across port files, or a call site moves, faithdiff
reports added/dropped calls that are not real divergences. Proposed fix was a
`relocated_calls` / `decomposed_routines` allowlist category. **Unstarted.**
Note the registry rule: new allowlist categories are a maintainer decision, and
an agent may not add entries to make its own work pass.

### 2. Label-DB provider selection for inlined/duplicated routines — **PARTLY FIXED**
Memory: `label-db-wrong-provider-on-inlined-routines` (v4).
The dead-file half is **fixed** (2026-07-26, commit `81719078`): the picker now
prefers definitions the build actually assembles, so a dead file can no longer
out-rank a live one. `DiscardButtonPresses` reports its live provider, the
registry/DB off-by-one is closed (148 == 148), and the retirement hazard is gone.
**Still open:** a pret routine inlined into a differently-named host with no
global of its own still reports `missing`, and the picker still does not consult
the allowlist. An `inlined_into` / `absorbed_by` category is unbuilt.

### 3. Reachability analysis: residual `not-proven-reached` blind spots
Memory: `project-state-reachability-false-negative-overworld-menu-subtree`.
`dd Label` dispatch tables and address-taken operands emit no call edge, so every
jump-table handler and both ISRs read `not-proven-reached` while provably
running. This is documented in CLAUDE.md as a permanent caveat; the deferred work
is teaching the extractor to emit edges for dispatch tables so the column stops
producing false negatives. **Unstarted.**

### 4. CI wiring for the fidelity harness
From `docs/plans/fidelity_harness.md`. Nothing runs `make fidelity` /
`goldens-verify` / `lint_pret_labels --strict-claims` automatically; every gate
in this repo is manual and therefore skippable. **Unstarted.**

### 5. pret-tree contamination decision
From `docs/plans/fidelity_harness.md`. This branch's pret tree cannot rebuild
`pokeyellow.gbc` end-to-end, which is why goldens come from the pinned pristine
worktree `../pokeyellow_msdos-pret-golden`. Whether to clean the in-tree pret
sources or formalise the golden worktree as the only ROM source is undecided.

### 6. `project_state --plans` glob misses `current_plans_*`
Memory: `strict-claims-gate-and-tooling-baselines`. The generated plan inventory
silently omits `docs/current_plans_remaster_Music_Cities1.md` (note the plural).
One-line fix; matters because CLAUDE.md points at that tool as the authority.

### 7. Two stale tests in `tools/test_label_db.py`
Found 2026-07-26; both predate that session and both fail on a clean tree:
- `Probe::test_check_only_sources_are_not_linked` asserts `trainer_engine.asm`
  is check-only. That file no longer exists anywhere in the tree.
- `LiveTree::test_boot_chain_fallthrough_edges_exist` asserts an
  `EnterMapBoot -> EnterMap` fallthrough. `EnterMap` moved to the
  `src/home/overworld.asm` mirror in the 2026-07-23 R-002 retirement, so the two
  labels are in different files and no such edge can exist.
Both need rewriting to the current structure, not deleting.

---

## Battle

### 8. Faint/EXP coverage — **LARGELY CLOSED**, tail remains
Session 8 measured that only 13 of 62 relocated pret `core.asm` labels were
executed by the suite. The `battle_faint` scenario (2026-07-26) added the first
resolved turn and KO, executing the damage pipeline and the
`FaintEnemyPokemon -> GainExperience` chain. **Still not executed by any
scenario:** the player-mon faint path (`RemoveFaintedPlayerMon`,
`HandlePlayerBlackOut`, `ChooseNextMon`), trainer-battle victory
(`TrainerBattleVictory`, `ReplaceFaintedEnemyMon`), residual damage, mirror
move, metronome, counter, `SelectEnemyMove`, and every link-battle branch.
The player-faint/black-out half is now **CLOSED**: `battle_blackout` (id 34,
tier `full`) is registered and passing, so `RemoveFaintedPlayerMon`,
`ReadPlayerMonCurHPAndStatus`, `AnyPartyAlive` and `HandlePlayerBlackOut` are
executed by the suite. Building it found a real port defect — the hang was NOT
the low-health alarm (that call is not even translated): the no-op
`ReadPlayerMonCurHPAndStatus` never wrote the fainted mon's 0 HP back to its
party slot, so `AnyPartyAlive` never failed and the battle looped
faint -> re-send forever. Detail: memory `regression-battle-blackout-gate-hangs`.
**Still not executed by any scenario:** `ChooseNextMon`, trainer-battle victory
(`TrainerBattleVictory`, `ReplaceFaintedEnemyMon`), residual damage, mirror
move, metronome, counter, `SelectEnemyMove`, and every link-battle branch.
One narrower tail this gate left open: `battle_blackout` stops inside
`RemoveFaintedPlayerMon` (at the `wBattleResult = 1` landmark), so pret's
`HandlePlayerBlackOut` side effect — `res BIT_ALWAYS_ON_BIKE` in
`wStatusFlags6`, core.asm:1200, which the port omits — is executed but not
compared. Covering it needs a landmark between the black-out and `EndOfBattle`.

### 9. battle_menu golden convergence spec
From `docs/plans/battle_ui.md` / `fidelity_harness.md`. The remaining
convergence notes for the battle menu screens.

### 10. Battle-UI session B6 — widescreen redesign
From `docs/plans/battle_ui.md`. The battle scene is still GB-centred on the
40×25 canvas rather than redesigned for it.

---

## Menus / screens

### 11. Bill's PC full UI
From `docs/plans/pokemon_behavior.md`. `BillsPCDepositLogic` /
`BillsPCWithdrawLogic` / `BillsPCReleaseLogic` exist in
`src/engine/pokemon/bills_pc.asm`, which is **check-only — assembled but not
linked**. The logic is written; the UI that would reach it is not.

### 12. Status screen: front pic, cry, and the STATS wire-up
From `docs/plans/pokemon_behavior.md`.

### 13. `LoadPokedexTilePatterns` tileset
From `docs/plans/menus.md`.

### 14. Window-compositor gap
From `docs/plans/menus.md`. Related to the documented Z-order inversion (the
port composites the window layer over OBJ; see CLAUDE.md).

### 15. Interactive navigation sweeps
From `docs/plans/menus.md`. Manual walk-throughs that no golden scenario covers.

---

## Overworld

### 16. The two out-of-map clamps + the map-data extension
From CLAUDE.md, "Temporary scaffold". The block-ID clamp in `DrawTileBlock` and
the block-map address clamp in `LoadCurrentMapView` are both **stopgaps**. The
real fix is extending the map data so the extended viewport reads real blocks;
both clamps then become dead code and should be deleted. CLAUDE.md is the record
of this work because no other file tracks it — keep it that way until it lands.

### 17. Cable-club warp seam
From `docs/plans/menus.md`.

### 18. Hidden-event / overworld-events Stage 3 lint tail
Memory: `overworld-events-stage3-hidden-events-linked`.

---

## Relocation debt (has a live owner — pointer only)

The legacy relocation inventory in `dos_port/tools/pret_label_allowlist.json`
stands at **148 rows**. It is tracked in stigmergy memory
`relocated-labels-grind`, not here; this pointer exists so the item is findable
from the same index as everything else. 18 rows of the pret `core.asm` cluster
remain from session 8, including `LoadHudTilePatterns`, which is blocked on
splitting `gen_battle_hud_inc.py` into separate battle_hud and ptile blobs
(you cannot do assembly-time arithmetic on an extern).
