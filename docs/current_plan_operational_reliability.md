# Operational Reliability Rollout

This plan turns fidelity evidence policy into generated interfaces and gates.
It complements, and does not modify, the separately owned fidelity-expansion
runtime harness.

## Restart handoff (2026-07-15, fourth annotation slice complete)

The fourth bounded legacy-annotation slice is complete after `2ea42200`:

- Audited exactly the first 29 entries of the regenerated 88-entry strict
  remainder, from `menus/main_menu.asm:216` through
  `menus/pokedex.asm:437`. The next entry, the pokédex side-menu spacing note
  (now line 518), was not touched.
- Converted 25 live projection, HAL, data-model, timing, or temporary-stub
  claims to structured annotations while retaining their detailed prose.
  Evidence was checked against matching pret flow and generated
  `project_state`; `OakSpeech`, `DisplayPCMainMenu`, and `BillsPC_` are confirmed
  linked stubs and now use structured `STUB` records.
- Corrected four stale markers rather than preserving them: two already-fixed
  naming-screen port defects are historical `FIXED` notes, the SAVE info screen
  now has its generated `UI_SAVE_INFO` projection, and OaksPC's call-site marker
  merely duplicated the file-level structured projection claim.
- Strict claim lint now reports exactly **59** remaining `legacy_annotation`
  entries and no other strict category. Default lint is clean with five
  existing suppressions.

Verification for this comment/metadata-only slice:

- **26** operational tool tests pass.
- Default `lint_pret_labels`: 0 violations / 5 suppressions.
- Strict lint: the measured 59-entry legacy remainder only.
- `validate_scenarios.py`: 19 scenarios consistent.
- Relevant `project_state` checks confirm linked implementations and the three
  linked stubs named above; direct pret inspection validates the retained
  menu/input/projection claims.
- `faithdiff` was run for every affected pret label. Clean routines remained
  clean; reported differences are pre-existing executable divergences now
  described by the retained prose/structured metadata. No executable byte,
  call graph, or WRAM store changed here.
- `project_state --plans` and `git diff --check` pass. Runtime goldens were not
  rerun because only comments and this handoff changed.

If directed to continue, regenerate the strict inventory and take a fresh
bounded slice beginning at `menus/pokedex.asm:518`.

## Restart handoff (2026-07-15, third annotation slice complete)

The next bounded slice after `2765e48a` is complete:

- Audited exactly the first 29 entries of the regenerated 117-entry strict
  remainder, from `items/item_effects.asm:1949` through
  `menus/main_menu.asm:12`. The next entry, the canvas-stride deviation in
  `main_menu.asm` (now line 216), was not touched.
- Converted 27 live original-game bugs, hardware/data-model boundaries,
  projection adaptations, or temporary missing-dependency seams to structured
  annotations while retaining their detailed prose. Evidence was checked
  against matching pret control/data flow and generated `project_state`.
- Removed two stale exception markers rather than preserving them: the
  `ItemUseCardKey` header's uppercase `BUG note` merely pointed to the real bug
  annotation below, and `main_menu.asm`'s uppercase `DEVIATION` legend merely
  described comment vocabulary. Neither was itself an exception claim.
- Strict claim lint now reports exactly **88** remaining `legacy_annotation`
  entries and no other strict category. Default lint is clean with five
  existing suppressions.

Verification for this comment/metadata-only slice:

- **26** operational tool tests pass.
- Default `lint_pret_labels`: 0 violations / 5 suppressions.
- Strict lint: the measured 88-entry legacy remainder only.
- `validate_scenarios.py`: 19 scenarios consistent.
- Relevant `project_state` checks distinguish linked providers and the missing
  `Func_3b10f` dependency; direct pret inspection validates the retained
  control/data-flow claims.
- `faithdiff` was run for every affected pret label. `DrawBadges` remained
  clean; reported differences elsewhere are pre-existing executable
  divergences now described by the retained prose/structured metadata. No
  executable byte, call graph, or WRAM store changed here.
- `project_state --plans` and `git diff --check` pass. Runtime goldens were not
  rerun because only comments and this handoff changed.

If directed to continue, regenerate the strict inventory and take a fresh
bounded slice beginning at `menus/main_menu.asm:216`.

## Restart handoff (2026-07-15, second annotation slice complete)

The user authorized exactly 29 additional annotations after `8af72220`; that
bounded slice is complete:

- Audited exactly the first 29 entries of the regenerated 146-entry strict
  remainder, from `battle/residual_damage.asm:15` through
  `items/item_effects.asm:1889`. The next entry, the critical post-capture BUG
  in `item_effects.asm` (now line 1949), was not touched.
- Converted 28 live original-game bugs/glitches, safety boundaries, or
  intentional DOS deviations to structured annotations while retaining their
  detailed prose. Evidence was checked against the matching pret control/data
  flow, generated `project_state`, and local bug/glitch references where
  available.
- Deleted one stale exception marker rather than preserving it:
  `item_effects.asm`'s `DEVIATION 3 (file header)` referenced a header entry
  that does not exist. The adjacent palette-HAL explanation remains as ordinary
  prose.
- Strict claim lint now reports exactly **117** remaining
  `legacy_annotation` entries and no other strict category. Default lint is
  clean with five existing suppressions.

Verification for this comment/metadata-only slice:

- **26** operational tool tests pass.
- Default `lint_pret_labels --no-scan`: 0 violations / 5 suppressions.
- Strict lint: the measured 117-entry legacy remainder only.
- `validate_scenarios.py`: 19 scenarios consistent.
- Relevant `project_state` checks distinguish linked outer routines, linked
  extracted `_` move-effect bodies, the intentionally stubbed ItemUsePPRestore
  wrapper, and port-only helper code.
- `faithdiff` was run for all affected linked pret labels. Clean routines
  remained clean; reported differences are pre-existing executable
  divergences. No executable byte, call graph, or WRAM store changed here.
- `project_state --plans` and `git diff --check` pass. Runtime goldens were not
  rerun because only comments and this handoff changed.

Stop here: the user's authorization was exactly 29 more. If directed to
continue, regenerate the strict inventory and use the newly requested bound.
The current first 29 of the remainder run from `item_effects.asm:1949` through
`menus/main_menu.asm:12`.

## Restart handoff (2026-07-15, first annotation slice complete)

The first bounded legacy-annotation review is complete on top of `152cbf36`:

- Audited exactly the first 30 strict-inventory entries, from
  `dos_port/src/audio/engine_1.asm:1038` through both deviations at the top of
  `dos_port/src/engine/battle/print_type.asm`. Entry 31,
  `battle/residual_damage.asm:15`, was not touched.
- Converted 26 live original-game bugs/glitches or intentional DOS deviations
  to structured annotations while retaining their detailed prose. Evidence was
  checked against the matching pret routine and, where applicable, the local
  bug/glitch catalog or the generated `project_state` provider report.
- Four stale exception markers were corrected instead of preserved:
  `experience.asm`'s `BUG-FREE` explanation is a note, while the already-fixed
  integration defects in `faint_leaves.asm`, `faint_sendout.asm`, and
  `faint_switch.asm` are historical `FIXED` notes rather than live BUG claims.
- Strict claim lint now reports exactly **146** remaining
  `legacy_annotation` entries and no other strict category. Default lint is
  clean with five existing suppressions.

Verification for this comment/metadata-only slice:

- **26** operational tool tests pass.
- Default `lint_pret_labels --no-scan`: 0 violations / 5 suppressions.
- Strict lint: the measured 146-entry legacy remainder only.
- `validate_scenarios.py`: 19 scenarios consistent.
- Relevant `project_state` checks confirm linked providers for the reviewed
  battle labels; direct pret inspection confirms the file-local audio label.
- `faithdiff` was run for every affected pret routine. Clean routines remained
  clean; reported differences are pre-existing executable divergences now
  described by the retained prose/structured metadata. No executable byte,
  call graph, or WRAM store changed in this slice.
- `project_state --plans` and `git diff --check` pass. Runtime goldens were not
  rerun because only comments and this handoff changed.

Do not start the next slice without user direction. If directed to continue,
regenerate the strict inventory and audit exactly its first 30 entries (the
current expected range is `battle/residual_damage.asm:15` through
`items/item_effects.asm:1945`), then leave another bounded handoff and commit.

## Restart handoff (2026-07-15, after `6c0ea79c`)

This is the authoritative next-session handoff; the older assertion checkpoint
below is retained as history and its commands are superseded.

Completed in `6c0ea79c`:

- All four debug-only assertion families have focused static negative-boundary
  tests. The tool suite is now **26 passing tests**.
- `status_p1`, `item_tm_teach`, and `ball_catch` golden-match with
  `DEBUG_ASSERTIONS=1`; the full **12-scenario core fidelity tier passes** with
  all four families enabled.
- Two harness regressions exposed during verification were fixed without
  weakening production behavior: deterministic party seeding bypasses the live
  nickname prompt while still copying default species nicknames, and the shared
  autokey train uses B only for `DEBUG_ITEMBALL` (A for affirmative item flows).
- The assertion checkbox below is complete. Default label lint is clean with
  five existing suppressions, and `validate_scenarios.py` reports 19 consistent
  scenarios.

The remaining work is deliberately multi-session. Budget at least **six review
sessions** for the **176** legacy annotations; context quality is more important
than clearing the inventory quickly. Each session must retain the detailed prose
and validate truth against pret plus `project_state`, bug/glitch references, or a
matching golden before adding structured metadata. Delete or fix stale claims.

### Exact next-session contract: first 30 annotations

1. Register/search memory, read this plan in full, and regenerate the stable
   inventory with `lint_pret_labels --no-scan --strict-claims`.
2. Audit **exactly the first 30 `legacy_annotation` entries in that output**
   (current ordered slice: `audio/engine_1.asm:1038` through the two
   `battle/print_type.asm` deviations). Do not spill into entry 31. This keeps
   the review bounded and leaves an expected **146** entries if none are deleted
   or expanded by a truth fix.
3. Run the tool tests, default lint, strict lint, relevant `project_state` /
   pret checks, and `git diff --check`. Strict lint may remain red only for the
   measured remainder; compare its categorized count rather than calling it a
   regression.
4. Update this handoff with the exact reviewed range, evidence, remaining count,
   and verification results. Commit the 30-annotation slice independently.
5. After committing, ask the user whether to continue with the next bounded
   slice or stop and leave a fresh handoff. Do not begin annotation 31 without
   that direction.

## Restart handoff (2026-07-15, assertion-infrastructure checkpoint)

Assertion continuation completed later on 2026-07-15:

- `status_p1` initially failed even without assertions. The cause was harness
  drift after `0828a941`: `PrepareNewGameDebug` reached the newly live AskName
  prompt with no input. The deterministic party builder now uses AddPartyMon's
  nonzero player-path marker while seeding, copies default species nicknames,
  and restores `wMonDataLocation = 0` before returning.
- The shared `AUTOKEY_APRESS` script had also been changed globally to B for
  `ball_catch`, breaking the affirmative TM flow. B is now scoped to
  `DEBUG_ITEMBALL`; all other users retain A.
- Focused static negative-boundary tests cover all four assertion families.
  `status_p1`, `item_tm_teach`, and `ball_catch` golden-match with assertions;
  the full 12-scenario core tier passes with `DEBUG_ASSERTIONS=1`.

Worktree checkpoint for the next session:

- Strict claim lint now enumerates the previously silent backlog as
  `legacy_annotation`: **176** free-form claims. A parser regression test was
  added; the tool suite is now **21 passing tests**. Strict lint is intentionally
  red until the evidence-reviewed migration reaches zero.
- `DEBUG_ASSERTIONS=1` now expands to four independently selectable NASM flags:
  `DEBUG_ASSERT_PROJECTION`, `DEBUG_ASSERT_SCRATCH`,
  `DEBUG_ASSERT_LIFECYCLE`, and `DEBUG_ASSERT_REENTRANCY`.
- Current debug-only contracts compile and link across the full DOS build:
  window-list capacity at `add_window`; text scratch stride 20/40 at
  `TextBoxBorder` and `PlaceString`; compositor count/boolean lifecycle at
  `render_window`; and non-reentrant ownership of PrintText's global projection
  state. Production objects contain none of this code.
- Runtime evidence with all four flags: `start_menu` and `overworld_pallet`
  golden-matched. `status_p1` trapped before its dump. Binary isolation showed
  the first projection checks also trapped; WX/WY non-negativity was invalid
  because slide transitions use signed origins. Those origin/descriptor checks
  were removed, leaving the indisputable capacity contract. The relaxed build
  compiles, but `status_p1` has **not yet been rerun** after the relaxation.
  The core fidelity run was interrupted during `party_menu` to make this handoff.

Exact next commands and sequence:

1. Run `make -C dos_port goldencheck SCENARIO=status_p1 DEBUG_ASSERTIONS=1`.
   If it still traps, isolate with scratch+reentrancy versus lifecycle; do not
   reintroduce unsigned WX/WY bounds.
2. Once status passes, run `make -C dos_port fidelity DEBUG_ASSERTIONS=1`, then
   add focused negative/static tests for each assertion family before checking
   off the assertion item.
3. Commit the assertion slice independently. Then use the new
   `legacy_annotation (176)` strict inventory to migrate claims subsystem by
   subsystem; retain the existing detailed prose, but validate truth against
   pret/project_state/goldens before adding structured metadata.
4. Only after strict lint is fully clean, run the full verification block and
   `fidelity-full`, update counts, and archive the plan.

## Restart handoff (2026-07-15, after `0828a941`)

Completed in this continuation:

- `92886cd6` audited all 56 strict-lint text candidates as rendered strings and
  moved them into deterministic generated includes. Strict lint is now clean,
  all 20 tool tests pass, and the full DOS build links.
- `0828a941` audited every legacy `STUB` claim. `GetCryData` is the one genuine
  linked stub and now has a generated-state-backed structured annotation;
  missing/check-only Pallet/CUT/FLY paths are structured temporary deviations.
  The last claim was stale: `AskName` is linked, so `_AddPartyMon` now restores
  pret's call. The `ball_catch` golden passes with the port gate declining the
  live nickname prompt, matching mGBA.

Exact next sequence:

1. Audit the remaining free-form `DEVIATION` claims, grouped by subsystem.
   Validate each against pret plus `project_state` or a matching golden before
   structuring it; delete or fix stale claims instead of preserving them.
2. Audit `BUG` and `GLITCH` claims against pret and the bug/glitch references.
   Keep Gen-1 behavior distinct from already-fixed port defects; glitches need
   explicit safety evidence.
3. Add the four debug-only assertion families from actual writer/reader
   ownership: projection bounds, scratch owner, compositor lifecycle, then
   re-entrancy. Add focused negative tests for every assertion family.
4. Run the full verification block and fidelity tiers, update measured counts,
   then archive this plan only when the two remaining checkboxes close.

## Restart handoff (2026-07-15, after `9dc5b771`)

Completed in this continuation:

- `e5aa8f96` reconciled all 19 final fidelity scenarios and made the differ
  reject a mismatched runtime scenario ID.
- `4ea3fcbd` made CORE/FULL Make lists and NASM scenario dispatch derive from
  the manifest; GBSTATE v2 now carries a required terminal marker in scenario
  tag bit 7. `goldencheck SCENARIO=status_p1` passed end to end.
- `5800f4c0` added temporary-tree deterministic regeneration, source-row/parser
  coverage, unique-label identity, and an independent pret byte-stream check.
  The tool suite now has 20 passing tests.
- `39c6b3ee` migrated all 40 stale extern-provider trails using
  `project_state`-selected providers.
- `87b8750d` removed all six local pret-label shadows by retaining private
  projected variants under port-only names. A full `make -C dos_port` linked.
- `9dc5b771` replaced 49 weak file-level relocation claims with 147 explicit
  scanner-evidenced per-label entries; one obsolete `home/audio.asm` claim was
  deleted because no selected label still used its old provider.

Current measured gate state: default lint is clean (5 suppressions); strict
lint has no `stale_provider`, `local_shadow`, or `weak_relocation` category. Its
remaining reported inventory is 56 conservative `hand_encoded_text` candidates.

Exact next sequence:

1. Audit the 56 rendered-text candidates one label at a time. Confirm that each
   byte run is human-rendered text rather than control/layout data, then move
   confirmed strings into subsystem generators and generated `assets/*.inc`.
   Preserve pret labels in the generated include and add regeneration tests.
2. Search legacy free-form `DEVIATION`, `STUB`, `BUG`, and `GLITCH` comments
   separately; strict lint intentionally accepts them during migration and
   therefore does not enumerate the backlog. Validate every claim against
   `project_state`, pret, and runtime evidence before converting it.
3. Add debug-only projection, scratch-owner, compositor-lifecycle, and
   re-entrancy assertions subsystem by subsystem. Do not infer ownership from
   comments; start from actual buffer writers/readers and debug entry paths.
4. Run the full verification block, update counts below, archive this plan only
   when every checkbox is closed, and commit each independently reviewable
   migration slice.

## Restart handoff (2026-07-14)

**Superseded 2026-07-15:** fidelity expansion is complete and archived at
`docs/plans/fidelity_expansion.md` (`cb5e8e60`). No fidelity-agent ownership or
sequencing restriction below remains active.

The final 19-scenario registry has now been reconciled into
`scenario_manifest.json`: CORE/FULL membership and order, flags, classes, IDs,
Lua scripts, committed artifacts, sidecar identity, and defined must-hit labels
are validated. `golden_diff.py` also rejects a runtime `GBSTATE.BIN` whose
scenario ID does not match the requested scenario, so a dump from the wrong gate
cannot pass as completion evidence. Verification after that reconciliation: 14
tool tests pass and `validate_scenarios.py` reports 19 consistent scenarios.

Scenario consolidation closed in the next tooling slice: Make derives CORE/FULL
names from the manifest, NASM consumes generated `assets/scenario_registry.inc`,
and GBSTATE v2 uses bit 7 of the scenario tag as a terminal-dump marker. The
differ requires both that marker and the expected low-seven-bit scenario ID.
`goldencheck SCENARIO=status_p1` passed end to end with those checks active.

**Status:** independent operational-control work is committed through
`39692a36`. The fidelity-expansion agent (`r-c7cad7187f77`) owns and is actively
editing the harness through its Stages 2–4. Do not request or take its claimed
files until it archives `docs/current_plan_fidelity_expansion.md` and releases
the claims. It expects multiple hours of work.

That agent's final Stage 4 shape is authoritative for scenario tiers: it will add
CORE/FULL suites and `goldens-verify`. The initial manifest committed here at
`e5b2495e` describes the ten Stage-1c scenarios only and will intentionally report
drift while battle/menu scenarios are landing. After the Stage 4 handoff, update
the manifest to the final registry first, then generate registries from it. Do
not restructure its live files mid-stage.

**Exact next steps for a fresh session:**

1. Register with stigmergy, search memory, run `root_list_active`, and read this
   plan plus the fidelity-expansion plan/archive.
2. Confirm the fidelity agent released `dos_port/Makefile`,
   `dos_port/tools/golden_diff.py`, `dos_port/tools/mgba_harness/**`,
   `dos_port/src/debug/debug_dump.asm`, and its plan file.
3. Run the verification commands below. Expect `validate_scenarios.py` to fail
   only if new Stage 2–4 scenarios have landed without the manifest update.
4. Reconcile `scenario_manifest.json` with the final CORE/FULL scenario set,
   masks, IDs, flags, Lua scripts, dump schemas, timeouts, and scenario classes.
5. Generate Makefile lists, differ registration, and NASM scenario-ID dispatch
   from the manifest; remove conditional-order identity. Add runtime must-hit and
   terminal-marker validation before checking off scenario consolidation.
6. Continue the remaining generator and debug-runtime assertion work. Treat the
   legacy migrations as evidence-review work, never as bulk rewrites.

**Completed commits in this rollout:**

- `ae7357d2` — evidence policy, generated project state, initial fidelity gate.
- `b277194e` — strict structured exception annotations and tests.
- `f33e91bd` — structured stub/provider claim validation.
- `32677d34` — boot scanning and conservative `start` reachability.
- `b2cfba0c` — generated active-plan inventory.
- `c435e588` — conservative hand-encoded rendered-text inventory.
- `e0958c5c` — M-69 and MAP_BORDER=6 memory reconciliation recorded complete.
- `e5b2495e` — initial ten-scenario manifest and cross-registry drift validator.
- `39692a36` — greedy charmap/unknown-character generator contracts.

**Measured migration debt (updated 2026-07-15):**

- 0 weak/boilerplate file-level relocation entries (147 per-label records now).
- 0 stale explicit extern provider trails.
- 0 local pret-label shadows.
- 0 likely hand-encoded rendered charmap blobs.
- 0 unaudited `STUB` claims. Legacy free-form `DEVIATION`, `BUG`, and `GLITCH`
  annotations remain accepted temporarily and require manual evidence-backed
  conversion.

**Verification commands:**

```sh
python3 -m unittest discover -s dos_port/tools/tests -p 'test_*.py'
dos_port/tools/lint_pret_labels --no-scan
dos_port/tools/lint_pret_labels --no-scan --strict-claims
dos_port/tools/validate_scenarios.py
dos_port/tools/project_state --no-scan Init GetTrainerName
dos_port/tools/project_state --plans
git diff --check
```

Last clean independent-work result: 14 tests passed; default label lint reported
0 violations / 5 suppressions; ten Stage-1c scenarios were consistent; `Init`
was `static-live-entry`; `GetTrainerName` was `check-only`. Strict lint is
expected to fail on the measured migration debt. Do not call that failure a
regression without comparing its categorized inventory.

- [x] Add evidence hierarchy, precise verification terms, subsystem-retirement
  sweep, and knowledge lifecycle rules to AGENTS.md.
- [x] Add a repository-derived per-label `tools/project_state` report that
  distinguishes linked, check-only, unlisted, stub, and missing providers.
- [x] Extend the scanner through `boot/` and derive conservative shipping
  reachability from the `start` call graph; indirect/table-driven paths remain
  `not-statically-reached`, never asserted unreachable.
- [x] Generate the active-plan inventory with `tools/project_state --plans`.
- [x] Add changed-label `tools/fidelity_gate` with conservative evidence wording
  and an explicit static-blind-spot report.
- [x] Reject local pret-label shadows and boilerplate file-level relocations in
  `lint_pret_labels --strict-claims`; default lint remains usable during migration.
- [x] Migrate legacy weak relocations to enumerated, evidenced label entries.
- [ ] Manually migrate legacy free-form `DEVIATION`, `STUB`, `BUG`, and `GLITCH`
  comments to the structured form, verifying each claim rather than bulk-rewriting.
- [x] Migrate the strict-lint inventory of likely hand-encoded rendered strings
  into deterministic generators; the detector is conservative and each hit must
  be confirmed before conversion.
- [x] Add strict structured source-annotation parsing; legacy free-form comments
  remain accepted until touched. Format:
  `; DEVIATION{class=projection; pret=file:Label; behavior=...; evidence=...; lifetime=...}`.
  `STUB`, `BUG`, and `GLITCH` use the same fields; glitches also require `safety`.
- [x] Extend strict claim linting to explicit `src/...asm` extern-provider trails;
  structured `STUB` annotations must name a label and fail if generated state
  reports a real implementation.
- [x] Migrate the stale provider-comment backlog reported by `--strict-claims`.
- [x] After fidelity Stage 1c releases its files, consolidate scenario metadata,
  IDs, flags, Lua registration, must-hit markers, and artifact identity checks.
  - [x] Add the initial unified manifest and a drift validator covering unique
    names/IDs, build flags/classes, Makefile order, port gate IDs, Lua scripts,
    committed artifacts, and golden sidecar identity.
  - [x] Generate the registries from the manifest and add runtime must-hit and
    terminal-marker validation (manifest declarations alone are not execution proof).
- [x] Add deterministic generator regeneration, parser-coverage, pret-byte, and
  longest-match charmap gates.
  - [x] Add cross-generator longest-match and unknown-character regression tests
    for the pret-derived item, move, field-move, battle-text, and alphabet encoders.
  - [x] Add temporary-tree regeneration, parser coverage, label identity, and
    eligible byte-for-byte pret stream validation.
- [x] Add debug-only projection, scratch-owner, compositor-lifecycle, and
  re-entrancy assertions subsystem by subsystem.
- [x] Reconcile M-69 and the MAP_BORDER=6 row-wrap stigmergy entries using repository/runtime
  evidence, retaining resolved historical lessons without stale active status.

Acceptance for this initial slice: project state is generated from the scanner
and Makefile; check-only differs from linked; weak file-level authority fails;
and static success never claims runtime fidelity.
