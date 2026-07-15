# Operational Reliability Rollout

This plan turns fidelity evidence policy into generated interfaces and gates.
It complements, and does not modify, the separately owned fidelity-expansion
runtime harness.

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

**Measured migration debt (strict lint, 2026-07-14):**

- 49 weak/boilerplate file-level relocation entries.
- 39–40 stale explicit extern provider trails (the count can move as concurrent
  fidelity work lands).
- 6 local pret-label shadows.
- 56 likely hand-encoded rendered charmap blobs; confirm each detector hit before
  migration because the detector is intentionally conservative.
- Legacy free-form `DEVIATION`, `STUB`, `BUG`, and `GLITCH` annotations remain
  accepted temporarily and require manual evidence-backed conversion.

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
- [ ] Migrate the strict-lint inventory of likely hand-encoded rendered strings
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
- [ ] Add debug-only projection, scratch-owner, compositor-lifecycle, and
  re-entrancy assertions subsystem by subsystem.
- [x] Reconcile M-69 and the MAP_BORDER=6 row-wrap stigmergy entries using repository/runtime
  evidence, retaining resolved historical lessons without stale active status.

Acceptance for this initial slice: project state is generated from the scanner
and Makefile; check-only differs from linked; weak file-level authority fails;
and static success never claims runtime fidelity.
