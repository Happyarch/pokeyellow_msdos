# Current Plan: Orphaned Backlog (the tracker TODO.md used to be)

> **Gate — the linter is MANDATORY. Rewritten 2026-08-02 against the tooling
> that actually exists; the version this replaces predated `static_gate` and
> told you "nothing runs it for you", which stopped being true on 2026-07-26.**
>
> **What runs automatically.** `dos_port/tools/static_gate` runs BOTH linter
> modes plus `test_label_db.py` and `validate_scenarios.py`, and it is invoked
> by `.githooks/pre-commit` (installed here: `core.hooksPath=.githooks`). It
> fires whenever anything under `dos_port/` is staged. It is a per-class
> RATCHET against a checked-in baseline: it fails a class that GREW.
>
> **What that does NOT mean.** A class sitting at baseline is not sanctioned —
> it is unfixed debt that merely has not gotten worse. `dos_port/tools/lint_pret_labels`
> **must exit 0**; it does not today — a small number of known, unsanctioned
> findings remain (`aux_misplaced` under plain `lint_pret_labels`;
> `--strict-claims` can add `hand_encoded_text` / `local_shadow` on top). None
> of those was ever approved by the maintainer, and the counts move as agents
> clear debt — **run `dos_port/tools/lint_pret_labels --no-scan` and
> `--no-scan --strict-claims` yourself** rather than trusting a number written
> here. Do not cite "at baseline" as permission to leave a class non-zero, and
> do not rewrite the rule to match the breakage.
>
> **For every commit made under this plan:**
> 1. Record the per-class counts from BOTH `lint_pret_labels` and
>    `lint_pret_labels --strict-claims` **before** you start.
> 2. Run both again before committing and compare per class. A class that grew
>    is your regression to fix now, not the next agent's to discover. Moving a
>    routine between files silently invalidates `extern` provider comments
>    elsewhere in the tree — collateral visible **only** under `--strict-claims`.
> 3. A green static gate proves **no structural or bookkeeping drift and nothing
>    about behaviour.** If the change can move a pixel or a WRAM byte, run
>    `make -C dos_port fidelity` (core) or `fidelity-full`, and add a must-hit
>    scenario when no existing one can witness the change.
>
> **The allowlist is not yours to grow.** `dos_port/tools/pret_label_allowlist.json`
> is hash-locked legacy debt, not precedent. New relocations are FORBIDDEN. An
> agent may not add, expand or reinterpret it — including `structural_findings`
> and `suppress` — to make its own work pass. **Any ADDITION requires explicit
> maintainer sign-off and cannot be committed without it**; the pre-commit hook
> refuses added keys outright and names them. If the linter says `mirror`, move
> the complete routine to `dos_port/src/<pret path>` instead.
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
- **Battle fidelity findings → `docs/archive/battle_audit_findings.md`.** Not here.
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

### 4. CI wiring for the fidelity harness — **STATIC TIER DONE 2026-07-26**
From `docs/plans/fidelity_harness.md`. The static half is wired; the runtime
half is deliberately still manual.

**Landed.** `dos_port/tools/static_gate` runs the checks that were rotting because
nothing ran them: both `lint_pret_labels` modes against a checked-in per-class
baseline (`tools/static_gate_baseline.json`), the `test_label_db.py` suite, and
`validate_scenarios.py`. Each class is a **ratchet in both directions** — a
class that grows is a regression, and a class that shrinks fails too until the
baseline is lowered deliberately with `--update-baseline`, so an improvement
cannot silently reverse later. Surfaces:
- `make -C dos_port static_gate` (the target is `static_gate`; there is no
  `gate` target — corrected 2026-08-02, verified against `dos_port/Makefile:2615`
  and the `.PHONY` line at `:1721`)
- `.githooks/pre-commit` + `make -C dos_port install-hooks` (opt-in, sets
  `core.hooksPath`; no-ops when nothing under `dos_port/` is staged; bypass with
  `git commit --no-verify`). **Install it only after the registry is blessed**,
  or `registry_approval` blocks every commit.
- `.github/workflows/dos-port.yml` — submodules, rgbds, root build, assets,
  `make check`, then the gate.

**Registry approval in CI.** The approval lives in the repo-local git config,
outside the worktree so no commit can forge it, which means a fresh CI clone
cannot have it. The workflow restores it from the repository variable
`PRET_ALLOWLIST_APPROVED_SHA256` (maintainer-settable, not writable by a pull
request). **UPDATE 2026-08-02: that variable WAS set on 2026-07-28** and the
approval branch is enforced, not INFO — see memories `registry-approval-state`
("git config MATCHES and the GitHub repo variable now MATCHES too — BLESSED
both sides") and `ci-dos-port-workflow-first-green` (run 30315835274 shows the
approval branch executing and the class passing). The workflow still carries the
`--allow-unapproved-registry` fallback at `.github/workflows/dos-port.yml:137-141`
for the unset case. That is a GitHub-side fact this note cannot verify from the
worktree — re-check it there rather than trusting this paragraph. **The hash now
lives in two places; a re-bless must update both.**

**Still manual, on purpose.** `make fidelity` / `fidelity-full` /
`goldens-verify` need DOSBox-X, mGBA and a golden ROM. Putting a multi-minute
runtime tier in a pre-commit hook is how hooks get reflexively bypassed. **A
green gate is a regression result about structure and bookkeeping only — it is
never evidence that behaviour is unchanged.** The open question for whoever
picks this up: whether a self-hosted runner should carry the runtime tier, or
whether it stays a local pre-push discipline.

### 5. pret-tree contamination decision — **PREMISE CONTRADICTED, RE-CHECK**
From `docs/plans/fidelity_harness.md`. This item asserted that "this branch's
pret tree cannot rebuild `pokeyellow.gbc` end-to-end", which is why goldens come
from the pinned pristine worktree `../pokeyellow_msdos-pret-golden`.

**Measured 2026-07-26 and that is not true today.** In a fresh
`git worktree add --detach HEAD` (with submodules initialised), `make -j` at the
repo root exits 0 and produces `pokeyellow.gbc` at sha1
`cc7d03262ebfaf2f06772c1a480c7d9d5f4a38e1`, which **matches `roms.sha1`
exactly**. The build was run as part of wiring item 4 and is reproduced by
`.github/workflows/dos-port.yml`.

That does not by itself decide the item — the golden worktree may still be worth
keeping as an independent source, and this measurement says nothing about
whether the in-tree pret sources have diverged in ways the ROM hash cannot see.
But the stated *reason* for the split no longer holds, so the decision should be
re-taken on current evidence rather than inherited. Whoever takes it: start by
re-running the measurement above, do not quote this paragraph.

### 6. `project_state --plans` blind spots — **FIXED 2026-08-02**
Memory: `project-state-plans-glob-and-checkbox-blindspots` (supersedes the note
in `strict-claims-gate-and-tooling-baselines`). There were **two** bugs, not the
one this item recorded:
- **Glob.** `glob('current_plan_*.md')` required the trailing underscore, so
  `docs/current_plans_remaster_Music_Cities1.md` (plural) was invisible. This is
  the one this item knew about.
- **Checkbox regex.** `r'^\s*- \[x\]'` missed the backticked ``- `[x]` `` form.
  `docs/current_plan_audio.md` is written entirely that way and reported **0/0**
  while really being 30 done / 4 open. Nobody had noticed.
Both widened in `dos_port/tools/project_state:54-63`. Measured after: 11 plans
listed (was 10), audio reads 30/4.

**Why it mattered more than a one-line fix.** The glob drove commit `880bbf94`,
the sweep that rewrote every plan's obsolete gate header — so the music spec was
skipped and kept a header whose central claim ("nothing runs it for you") had
been false since 2026-07-26. Standing lesson: when a hand-maintained inventory is
deleted in favour of a generator, that generator's COVERAGE becomes a correctness
property of the docs. `ls docs/current_plan*.md | wc -l` against its row count is
the five-second check that catches this.

### 7. Two stale tests in `tools/test_label_db.py` — **FIXED 2026-07-26**
Both were rewritten to the current structure rather than deleted, because both
encoded a real invariant. `tools/test_label_db.py` is now **81 passed, 0
failed** on a clean tree.
- `Probe::test_check_only_sources_are_not_linked` asserted `trainer_engine.asm`
  is check-only; the trainer-engine promotion deleted that file. It now asserts
  the SET RELATIONSHIP instead of a filename — check is non-empty, disjoint from
  link, and a subset of all — so it cannot rot the same way when the next file
  moves.
- `LiveTree::test_boot_chain_fallthrough_edges_exist` asserted an
  `EnterMapBoot -> EnterMap` fallthrough; the 2026-07-23 R-002 retirement moved
  `EnterMap` to the `src/home/overworld.asm` mirror, so no such edge can exist
  between two files. It now asserts CONNECTIVITY (the edge, not the edge kind),
  which survives a relocation that changes `jmp` to fallthrough or back. The two
  genuine fallthrough edges are still asserted as fallthrough.
All four new assertions were probed for non-vacuity: each was made to fail by
violating exactly its own condition.
~~**Residual, and it is item 4's problem, not this one's: nothing runs this
pytest suite automatically either.**~~ **CORRECTED 2026-08-02 — that residual is
no longer true and has not been for a while.** `dos_port/tools/static_gate` runs
`pytest tools/test_label_db.py` as step **4 of 5** (`static_gate:198-205`), and
`.githooks/pre-commit` invokes the gate, so the suite now runs on every commit
that stages anything under `dos_port/`. Measured this session: 81 passed, 53
subtests. The historical point stands and is worth keeping: it went red for an
unknown number of sessions precisely because, at that time, no gate looked at it.

### 19. `MapHeaderPointers` — the last `aux_misplaced` finding
Filed 2026-08-02. This is the **single remaining `lint_pret_labels` violation**,
and the standing rule is that the linter must exit 0 — so it is real open work,
not accepted state. It is deliberately **not** suppressed and **not** allowlisted.

`MapHeaderPointers` is a pret `data/maps/map_header_pointers.asm` table living in
`dos_port/src/engine/overworld/overworld.asm` (~`:1141`). The 2026-08-02 sweep
(`a3804828`) moved 13 of the 14 sibling tables to the data layer and could not
move this one. The blocker is structural, and the reason is documented in full at
the site (read the comment block above the `global`):
1. `assets/map_headers.inc` also defines `TilesetGfxPtrs`/`GfxSizes`/`BlocksPtrs`/
   `BlocksSizes`/`CollPtrs`, whose rows point at blob labels defined by
   `assets/extra_includes.inc` that are **not** `global`. Splitting the table from
   those blobs breaks the link.
2. Those blobs are welded to the code in that file through assembly-time size
   `equ`s (`OVERWORLD_BLOCKS_SIZE` and friends), and **a NASM `equ` cannot cross an
   object file**. Same constraint already documented for the pokedex tile blob.

So clearing it needs a real refactor, one of: publish the blob sizes as linkable
data words and change the consuming code to load them rather than assemble them
in; or relocate the whole asset region together with its consumers. **Scoped
work, no plan file owns it** — that gap is why this entry exists.

### 20. The `work_queue` pipeline — **RETIRED 2026-08-02, CLOSED**
Maintainer decision: delete. Done in the same commit as this note.

Removed: the `stubs` (2 rows), `functions` (7127) and `translation_log` (200)
tables from `dos_port/tools/translation.db`, **and** the three scripts that were
their only remaining readers — `dos_port/tools/build_index`, `work_queue`,
`process_placements`. Verified before deleting: no invocation from the Makefile,
`.githooks` or `.github`; `update_label_db`'s own docstring confirms it never
touched those tables, so a rescan does not recreate them. Verified after:
`pytest tools/test_label_db.py` 81 passed, `static_gate` PASS.

**Why it died, because the pattern is the point.** Its statuses only advanced when
an agent remembered to run `work_queue complete`/`wired`/`verified`. That
bookkeeping was abandoned, and by the end it reported 97 `translated` against the
label DB's 1673 — a hand-maintained index of a tree that had moved on without it.
`gen_progress_report` was rewired onto the label DB on 2026-07-27, after which
nothing read it at all.

**Do not build another one.** The replacement is not a better queue; it is
`translation.db`'s label tables, which are *derived by rescanning the tree* and so
cannot drift from it. Recoverable from git if ever wanted.

### 21. Native-width BG renderer plan — **CLOSED 2026-08-02, no action**
Maintainer assessment: *"the plan is basically done for its primary goals (many of
which were superseded in future plans that were already finished anyway)."*
Recorded as an assessment, **not a measurement** — nobody re-derived the 12 open
boxes, and the maintainer said "as far as I'm aware." A banner saying so is now on
the plan itself, so the next agent finds the answer instead of re-raising this.

Kept below as the record of *how* it stayed invisible, because that part is
reusable. Original finding:

`docs/plans/Native-width BG renderer (retire the 256px torus)_current.md` has
**13 done / 12 open** checkboxes. Its own title reads "(Stage A Complete), border
+ connections (**Stage B Current**)"; Stage B is "Enlarge `MAP_BORDER` so the
centered viewport never reads past the map (CURRENT)" and Stage C is a live SPEC.

That is active work, but it is unfindable three ways over:
- it sits in `docs/plans/`, which is the **archive**, not the queue;
- its filename follows no convention (spaces, parentheses, a `_current` suffix),
  so `project_state --plans` — which globs `docs/current_plan*.md` — cannot see
  it even now that the glob is fixed;
- consequently it was skipped by the `880bbf94` gate-header sweep too.

It also **overlaps item 16** (the two out-of-map clamps + map-data extension) and
is partly overtaken by events: `MAP_BORDER` is already 7, which is some of what
Stage B asks for. So the open count is not trustworthy either — the file needs
re-measuring, not just moving.

~~The decision: promote it, or fold the remainder into item 16.~~ **Answered
2026-08-02: neither — it is done, see the banner above.**

**The reusable lesson, which is why this entry survives its own closure:** a plan
can be invisible to every inventory at once — wrong directory, non-conforming
filename, and therefore skipped by the tooling-driven sweeps too. The filename
convention is not cosmetic; it is what makes a plan findable. `project_state
--plans` globs `docs/current_plan*.md` and nothing else.

### 23. `docs/plans/macros.md` unticked boxes — **CLOSED 2026-08-02**
Reconciled and banner added to the plan. Maintainer's read ("probably wasn't
[finished as bookkeeping] and just fell off") is confirmed by measurement, not
just accepted: **14 of 15** spot-checked macros exist in `dos_port/include/`
(`coord`/`hlcoord`/`dwcoord`/`validate_coords`/`owcoord`, `dbw`/`dn`/`bcd2`,
`CheckAndSetEvent`/`SetEvents`, `RGB`/`lb`, `text_start`/`text_bcd`).

The 15th, **`const_def`, is absent by design and needs no work item.** Its Stage 8
is marked "optional, low priority — port only if/when a hand-written enum/table
actually needs them", and nothing ever did.

`const_def`/`const` (`macros/const.asm`) keep a counter and emit constants from
it. The port has no consumer: its constants arrive from pret already resolved, as
plain `equ`s. A local counter would also be unsafe — species ids index
`MonsterNames`/`CryData`/`EvosMovesPointerTable` and reach save files, so they
must match pret exactly, and a counter renumbers everything after an insertion
silently. Original finding kept below.

The plan is in the archive showing **2 done / 16 open**. The work appears to have
actually landed in `a7822644`: `dos_port/include/` now contains `coords.inc`,
`data_macros.inc`, `events.inc`, `gfx_macros.inc` and `gb_text.inc` — the exact
chunks the open boxes describe. So this looks like *bookkeeping never done*, not
work abandoned; the archived plan's own narrative ("Stage 1 done; coords chunk A1
is next") was still being quoted as current in the `project-conventions` skill
until 2026-08-02.

Reconcile the boxes against what is actually in `include/` and either tick them
or state plainly which chunks were dropped and why. Note the plan's scope was
deliberately "add macros only, do not retrofit call sites" — so "the macros exist
but nothing uses them" is the *expected* end state, not evidence of incompleteness.

### 22. Save round-trip test upgrade (deferred from `bug_tagging`)
Promote `DEBUG_SAVE_ROUNDTRIP` in `RunSaveTest` from a file-exists smoke test to a
full seeded-state round-trip diff: seed party → `SaveGameData` → wipe WRAM →
`TryLoadSaveFile` → `DumpGBState`, then compare `GBSTATE.BIN` host-side. This is
new test-harness code, not a tagging task, and it touches `save.asm`, which has
real live callers — it needs its own reviewed change, not an unattended pass.
Source: `docs/current_plan_bug_tagging.md` (~`:264-272`); update that citation if
that plan is ever archived.

### 24. Two real defects on the fishing path (`LoadAnimSpriteGfx`)
Filed 2026-08-02 by the plan re-measurement. **Code defects, not bookkeeping**, and
they were invisible because two comments lie about the file.

The already-linked `FishingAnim` calls `LoadAnimSpriteGfx`
(`src/engine/gfx/mon_icons.asm`) with:
1. a **header-layout mismatch** — the callee reads the 12-byte party-icon header
   shape (`MON_ICON_HDR_SIZE`, documented at `mon_icons.asm:70-74` as a deliberate
   port divergence from pret's 6-byte header); the fishing caller supplies an
   8-byte layout;
2. the **count passed in `AL` where the callee reads `EAX`**.

Concealed by a stale `; UNPORTED` comment and a stale "Check-only
(HOME_CHECK_SRCS)" file header — the file is in `GAME_SRCS`.

**Owner is genuinely ambiguous** and that is why it is here rather than in a plan:
`LoadAnimSpriteGfx` has 3 callers and its 12-byte shape is the *party-icon* shape,
so a fix for fishing must not break the icon path (archived context:
`docs/plans/party_icons_oam.md`). Whoever takes it owns both paths, and it wants a
scenario covering each.

### 25. Promote `wRodResponse` to `include/gb_memmap.inc` (0xCD3D)
Filed 2026-08-02. Currently a `%ifndef` **local shadow** at
`src/engine/overworld/player_animations.asm:116-118`. The fishing-rod handlers
(`docs/current_plan_items.md`) are the second consumer, so porting them without
this promotion either adds a second shadow or forces the promotion mid-change —
and `3fad3249` drove the `local_shadow` class from 21 to **0**, so it would be a
fresh strict-claims regression on a class cleared the same day.

`wRodResponse` unions with `wPPRestoreItem` (`gb_memmap.inc:205`) and the
`wFlyAnimUsingCoordList` / `wPlayerSpin*` scratch, all at 0xCD3D — the promotion
must carry that union comment forward or it silently aliases.

### 26. `project_state` and `label_status` disagree on caller counts
Filed 2026-08-02. Measured for `DisplayTextID`: `project_state --no-scan` reports
**5** callers; `label_status --callers` lists **7 call sites / 6 unique**
(`PalletTownAfterPikachuBattleScript` calls it twice). So the two disagree even
after collapsing duplicates — one undercounts by one.

`ModifyPikachuHappiness` *does* decompose cleanly (8 unique vs 9 sites), so the
rule "`project_state` counts unique callers" holds there and fails here. That is
the bad shape: a discrepancy that looks like a known rounding rule until you check.

This matters because the Evidence Policy **requires** plans to cite these columns.
Reconcile them, or document precisely what each counts.

### 27. No `gen_trainer_headers.py` — blocks the `TrainerFlagAction` cleanup
Filed 2026-08-02 (from battle-completion X4; boundary between that plan and
overworld-events, placed here so neither drops it).
`src/home/trainers.asm:53-58` files a "ROOT FOLLOW-UP": once trainer-header DATA
exists, delete `npc_beaten_flags` and route `map_sprites.asm`'s
`CheckTrainerSight` / `TrainerEncounterFlow` beaten-gate through
`TrainerFlagAction`. It is gated on a generator that **does not exist** —
`ls dos_port/tools/generators/` shows no trainer-header generator. Tier-1 data
work touching map scripts.

### 28. Stale in-code prose found during the 2026-08-02 re-measurement
All found by reading files in full rather than grep windows — which is the point:
none of these is visible in a match window.

**FIXED 2026-08-02** (same commit as the re-measurement):
- `src/home/overworld.asm` — two orphaned doc headers sit ~1000 lines from the
  routines they document, and their internal directions had become **inverted**
  ("the head **above**", "falls through into the sprite scan **below**" — both
  pointed the wrong way after the relocation). Direction words removed; the
  content is correct and load-bearing (it is where the Surf `DH` contract is
  recorded), so it was fixed in place rather than moved.
- `src/home/map_objects.asm:118-121` — called `BillsPC_` a menu stub; it has had
  a real body since `0c9afce5` (2026-07-31) with two goldens.
- `src/home/run_map_script.asm:1-37` — a 37-line header documenting `RunMapScript`
  in a file that now holds only `DefaultMapScript` (the routine moved to
  `src/home/overworld.asm`). Header re-pointed; the prose kept, since it is
  accurate about the routine, just filed under the wrong roof.
- `docs/items_blockers.md:17` cited `tools/gen_hidden_item_coords.py`; the real
  path is `tools/generators/gen_hidden_item_coords.py`.

**STILL OPEN** — fold into whichever change next touches the file:
- `end_of_battle.asm` — Pay Day `TODO-HW` comment is stale in two ways.
- `battle_exp_stubs.asm` — the LATENT-COLLISION header paragraph (l.13-18) is
  contradicted by its own l.47-50.
- `src/engine/gfx/mon_icons.asm` — the `; UNPORTED` comment and the "Check-only
  (HOME_CHECK_SRCS)" header; the file is in `GAME_SRCS`. These two are what hid
  the defects in #24, so fix them with that work, not before.

### 29. Overworld-events tails with no good home in that plan
Filed 2026-08-02 from the overworld re-measurement, to keep its Stage bullets honest:
- **`CableClubNPC`** — its own `STUB{}` says `lifetime=until Phase 4 cable/link
  behavior lands`. It sits inside a Phase-2 bullet that therefore cannot close.
- **`CeladonPrizeMenu` / prize service** — the only one of that five-way bullet
  whose consumer is a Game Corner map Stage 5 will not reach for many batches, and
  the only one measuring 0 callers. Low value staying coupled to
  vending/Safari/Pikachu.
- **`ShowTextStream` auto-advance mismatch** — a real behavioural divergence from
  pret with a named symptom (Oak's "Hey! Wait!"), currently narrative inside a
  handoff with no bullet anywhere.
- **`LoadHoppingShadowOAM`** (`overworld_stubs.asm:93-107`, stub/linked/1 caller/
  reached) — the cosmetic half of the ledge work; its TODO needs `PrepareOAMData`
  to grow shadow-OAM slots, a compositor change. Pair with the ledge-hop bullet.

### 30. Build-gate trap: `DEBUG_OAKINTRO` vs `DEBUG_OAK_INTRO`
Filed 2026-08-02. **Two different build gates one underscore apart, in the same
Makefile**, driving two different scenarios:
- `DEBUG_OAKINTRO` (`Makefile:1168`) → `RunOakSpeechCheckpoint` — Prof. Oak's
  *opening speech*. This is golden scenario id 29, named `oak_intro`, owned by
  `docs/current_plan_menu_intro.md`.
- `DEBUG_OAK_INTRO` (`Makefile:649`) → `RunOakIntroTest`
  (`src/home/overworld.asm:385`, `src/debug/debug_dump.asm:207`) — the **Pallet
  overworld** Oak cutscene, owned by `docs/current_plan_overworld_events.md`.
  **It appears in no manifest row**, so it has no golden coverage.

The overworld plan recorded its scenario as "ENABLED and PASSING" on the strength
of the *name* `oak_intro` existing in the manifest. It was reading the other
plan's scenario. The `.disabled` scaffold was deleted, not re-enabled (`7338860c`,
whose own message says so).

Rename one of the gates, or at minimum never reuse a scenario name across plans —
any new Pallet cutscene golden needs a distinct name (`pallet_oak_cutscene`).
**A false coverage claim is worse than a missing one:** it retires the very
scenario that would have caught the regression.

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

### 11. Bill's PC full UI — DONE 2026-07-31 (sram plan C1-C5, a2ea6550..c0b34720)
From `docs/plans/pokemon_behavior.md`. Closed: the whole Bill's PC UI is the
faithful pret mirror in `src/engine/pokemon/bills_pc.asm`, LINKED, and driven
end-to-end by two goldens (`bills_pc_ops` id 37, `box_change_roundtrip` id 38).
The port-only `BillsPC*Logic` fork names this item used to cite are DELETED —
the pret-labeled `BillsPCDeposit`/`BillsPCWithdraw`/`BillsPCRelease` bodies
replaced them. See `docs/plans/sram_pc_storage.md` stage 6.

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
stands at **2 rows** — measured 2026-08-02, and the grind that got it there is
done. ~~148 rows … 18 rows of the pret `core.asm` cluster remain from session 8,
including `LoadHudTilePatterns`, blocked on splitting `gen_battle_hud_inc.py`~~ —
**all of that is discharged**; the `core.asm` cluster and `LoadHudTilePatterns`
were retired during the grind. This paragraph read "148 rows" until 2026-08-02,
which is a 74× overstatement of the remaining debt and exactly the kind of stale
headline that makes a backlog untrustworthy.

Current registry, measured (`python3 -c "import json; …"` over the file):
`relocated_labels` **2**, `suppress` **4**, `structural_findings` **0**,
`relocated_files` **0**; sha256 prefix `604994cf`, matching git config
`pokeyellow.pretallowlistapprovedsha256` — i.e. maintainer-blessed.

Tracked in stigmergy memories `relocated-labels-grind` and
`registry-approval-state`, not here; this pointer exists so the item is findable
from the same index as everything else. The last 2 rows are blocked on the predef
text work — see `docs/current_plan_predef_text.md`. **New relocations are
forbidden and registry ADDITIONS are refused outright by `.githooks/pre-commit`
since `3f1b12be`.**
