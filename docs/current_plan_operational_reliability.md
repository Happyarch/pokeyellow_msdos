# Operational Reliability Rollout

This plan turns fidelity evidence policy into generated interfaces and gates.
It complements, and does not modify, the separately owned fidelity-expansion
runtime harness.

- [x] Add evidence hierarchy, precise verification terms, subsystem-retirement
  sweep, and knowledge lifecycle rules to AGENTS.md.
- [x] Add a repository-derived per-label `tools/project_state` report that
  distinguishes linked, check-only, unlisted, stub, and missing providers.
- [x] Add changed-label `tools/fidelity_gate` with conservative evidence wording
  and an explicit static-blind-spot report.
- [x] Reject local pret-label shadows and boilerplate file-level relocations in
  `lint_pret_labels --strict-claims`; default lint remains usable during migration.
- [ ] Migrate legacy weak relocations to enumerated, evidenced label entries.
- [ ] Manually migrate legacy free-form `DEVIATION`, `STUB`, `BUG`, and `GLITCH`
  comments to the structured form, verifying each claim rather than bulk-rewriting.
- [x] Add strict structured source-annotation parsing; legacy free-form comments
  remain accepted until touched. Format:
  `; DEVIATION{class=projection; pret=file:Label; behavior=...; evidence=...; lifetime=...}`.
  `STUB`, `BUG`, and `GLITCH` use the same fields; glitches also require `safety`.
- [x] Extend strict claim linting to explicit `src/...asm` extern-provider trails;
  structured `STUB` annotations must name a label and fail if generated state
  reports a real implementation.
- [ ] Migrate the stale provider-comment backlog reported by `--strict-claims`.
- [ ] After fidelity Stage 1c releases its files, consolidate scenario metadata,
  IDs, flags, Lua registration, must-hit markers, and artifact identity checks.
- [ ] Add deterministic generator regeneration, parser-coverage, pret-byte, and
  longest-match charmap gates.
- [ ] Add debug-only projection, scratch-owner, compositor-lifecycle, and
  re-entrancy assertions subsystem by subsystem.
- [ ] Reconcile M-69 and MAP_BORDER-era stigmergy entries using repository/runtime
  evidence, retaining resolved historical lessons without stale active status.

Acceptance for this initial slice: project state is generated from the scanner
and Makefile; check-only differs from linked; weak file-level authority fails;
and static success never claims runtime fidelity.
