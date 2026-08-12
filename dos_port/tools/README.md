# `dos_port/tools/` — map

This directory mixes three different kinds of thing. Know which kind a file
is before touching it:

1. **Data generators** (`generators/`) — never run these to get information;
   run them to regenerate an `assets/*.inc` file. `make assets` (or a normal
   `make`, via per-`.inc` prerequisites) invokes them for you. Never hand-edit
   their output — fix the generator and regenerate.
2. **Shared libraries** — imported by other tools, no CLI of their own.
3. **Human-facing tools** — you run these directly. Full usage lives in the
   skill named next to each one below, not here; this file is only a map.

## `generators/` — Tier-1 data pipeline (build-only)

Every `gen_*.py` script that turns pret source (or a hand-authored sidecar)
into a generated `assets/*.inc`, plus `gen_all_assets.py` (the orchestrator
`make assets` calls) and `gb_text.py` (the charmap-encode helper the string
generators share — see the project's two-tier rule in
`.claude/skills/project-conventions/SKILL.md` for why text strings are
generated data, never hand-encoded).

Don't run these standalone unless you're iterating on one asset (e.g.
`python3 tools/generators/gen_palettes.py` while debugging that one
generator) — `make -C dos_port assets` regenerates everything consistently
and is what CI/the build actually depends on. Run from the repo root or
`dos_port/`; each script's own docstring says which.

`tools/audio/gen_*.py` is the music-pipeline's equivalent set and stays under
`audio/` (it was already isolated from this clutter, so it wasn't moved here).

## Shared libraries (no CLI — imported by generators and/or editors)

- `colors/` — palette sidecar schema + PNG repaint round-trip, backs
  `colorize.py` and `generators/gen_palettes.py`.
- `gfx_core/` — shared GB graphics decode/compositing core (tiles, fonts,
  palettes, pret map metadata). Used by `colors/`, `ui_layout/`,
  `map_editor/`, and a few `generators/` scripts.
- `map_editor/` (minus its `editor.py` entry point) — border/override/view
  helpers for `generators/gen_map_borders.py`.
- `ui_layout/` (minus its `editor.py`/`seed_from_*.py` entry points) —
  layout schema + canvas projection for `generators/gen_ui_layout.py`.
- `unicode_converter/` — vendored git submodule (MPL-2.0), the actual
  GB-charmap converter `gb_text.py` wraps.
- `dosbox_mcp/`, `mgba_mcp/` — MCP server implementations; see
  **`build-and-debug`** for how they're launched.

## Human-facing tools — full usage in a skill

Everything below is meant to be run directly by a developer. Skill = where the
detailed usage lives (invoke it, don't guess flags from `--help` alone).

| Tool | What it's for | Skill |
|---|---|---|
| `colorize.py`, `colors/editor.py` | Palette CLI (`--gen`/`--verify`/`--edit`/`--export-png`/`--import-png`) + the pygame shade editor | `build-and-debug` |
| `map_editor/editor.py` | Overworld map viewer/painter | `build-and-debug` |
| `ui_layout/editor.py`, `seed_from_battle.py`, `seed_from_pret.py` | UI layout editor + one-shot sidecar seeders | `build-and-debug` |
| `render_frame.py` | Render a `FRAME.BIN` back-buffer dump to PNG | `build-and-debug` |
| `read_perf.py` | Decode a `DEBUG_PERF` capture (`PERF.BIN`) | `build-and-debug` |
| `read_seamlog.py` | Decode a `DEBUG_SEAM` trace (`SEAMLOG.BIN`) | `build-and-debug` |
| `audit_memmap.py` | Blast-radius audit of the emulated GB address space | `build-and-debug` |
| `unnamed.py` | Find unnamed symbols in a `.sym` file | `build-and-debug` |
| `golden_diff.py`, `goldencheck.sh` | Fidelity differ / one-scenario check-and-diff | `build-and-debug` |
| `saveconv.py` | `--verify`/`--info FILE` validates a `.dsv` (size/magic/version/checksum); `--to-dos IN.sav OUT.dsv` / `--to-gb IN.dsv OUT.sav` convert (header prepend/strip — the v2 payload IS a raw `.sav`). Run on every `save_real_load` golden. | `build-and-debug` |
| `dosbox_mcp/`, `mgba_mcp/`, `run_with_mcp.sh`, `run_mgba_mcp.sh`, `build_dosbox_mcp.sh`, `build_mgba.sh` | Live symbolic debugging (DOSBox-X port side / mGBA golden side) | `build-and-debug` |
| `audio/audition.py` | Host-side MIDI audition (fastest way to hear a track) | `build-and-debug` |
| `faithdiff`, `label_status`, `lint_pret_labels`, `update_label_db`, `fidelity_gate` | Pret-fidelity gate: label DB, per-routine diff, pre-commit check | `faithfulness-review` |
| `dependency_graph.py` | Interactive, canvas-rendered pret/DOS dependency viewer backed read-only by `translation.db`. Resolves unmodeled-pret-dir provenance — read `display_status`, not `status` | `build-and-debug` |
| `gen_progress_report`, `project_state`, `buildprobe.py` | Derived project state → `docs/translation_progress.md`: per-subsystem pret-label coverage plus the `DEVIATION`/`BUG`/`GLITCH`/`STUB` ledger. Read-only by default (`--scan` refreshes the DB first). Extensionless by convention — a report tool, not one of the `generators/` scripts | not yet owned by a skill; each has a `Usage:`/docstring block — read that first |
| `gen_audio_enhancement_report` | Derived per-song audio status → `docs/audio_enhancement_status.md`: which of the 49 songs have `audio/enhancements/*.yaml` (and which tiers), which have `audio/overrides/*.yaml`, and orphan files that match neither. Standalone, not a Makefile target. The one non-derived column, "Approved", is sign-off the maintainer enters by ear — record it by invoking the tool itself with `MUSIC_<CONST>=1`/`=0` (never by hand-editing `audio/enhancement_approvals.json`, which the tool owns) | not yet owned by a skill; docstring first |
| ~~`build_index`, `work_queue`, `process_placements`~~ | **DELETED 2026-08-02, with their `functions` / `stubs` / `translation_log` tables, at the maintainer's direction.** The hand-maintained translation work queue: its statuses only moved when an agent remembered to run `work_queue complete`/`wired`/`verified`, that bookkeeping was abandoned, and by the end it reported 97 `translated` against the label DB's 1673. `gen_progress_report` was moved off it 2026-07-27, after which nothing read it at all. **Do not resurrect this pattern.** The replacement is not another queue — it is `translation.db`'s label tables, which are *derived by rescanning the tree* and therefore cannot drift from it. Recoverable from git if ever needed | — |

`tests/`, `test_label_db.py`, `validate_scenarios.py` are regression suites,
not tools you run for output — see their own headers.

### Dependency graph viewer

Run `python3 dos_port/tools/dependency_graph.py`. It opens a loopback-only local
page on an automatically selected port; pass `--no-browser` to print the URL
without opening it. `--db PATH` selects a fixture or alternate database.
`--scan` derives a fresh database in a temporary directory and never rewrites
the tracked `translation.db`. `--host` and `--port` override the listener.

The pret and DOS tabs deliberately have different scopes. Pret shows every
modeled pret label and unknown referenced endpoints. DOS shows the complete
modeled pret universe (including unported/isolated routines), port-only labels,
and unknown endpoints.

**Read `display_status`, not `status`.** The label model covers pret `home/` +
`engine/` only, so a faithful pret label from `audio/`, `data/`, `gfx/`, `ram/`
or `scripts/` lands in `status = port_only` *by elimination*. The viewer resolves
that against the names-only `aux_labels` / `script_labels` provenance tables and
shows those nodes as **`pret-unmodeled`** (its own colour, filter and legend
entry), with `aux_pret_file` / `aux_pret_dir` naming the real pret origin.
Measured 2026-07-27: 90 `pret-unmodeled` against 337 genuinely port-only.

> A node is genuinely port-only only when `display_status == "port_only"` **and**
> `aux_pret_file` is null. Treating raw `status == "port_only"` as "bespoke port
> code" overstates the port's divergence by ~90 labels.

Provenance is names-only: `pret-unmodeled` nodes still carry no status and no
call-graph edges, so an absent edge on one of them means nothing.
The DB also cannot infer `dd Label` dispatch-table or address-taken edges, so
an absent edge is never evidence that an ISR or jump-table handler is unexecuted.
