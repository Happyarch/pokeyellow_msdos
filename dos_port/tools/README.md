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
| `saveconv.py` | `.sav` ↔ `.dsv` converter — **STUB, not implemented yet** | `build-and-debug` |
| `dosbox_mcp/`, `mgba_mcp/`, `run_with_mcp.sh`, `run_mgba_mcp.sh`, `build_dosbox_mcp.sh`, `build_mgba.sh` | Live symbolic debugging (DOSBox-X port side / mGBA golden side) | `build-and-debug` |
| `audio/audition.py` | Host-side MIDI audition (fastest way to hear a track) | `build-and-debug` |
| `faithdiff`, `label_status`, `lint_pret_labels`, `update_label_db`, `fidelity_gate` | Pret-fidelity gate: label DB, per-routine diff, pre-commit check | `faithfulness-review` |
| `build_index`, `work_queue`, `gen_progress_report`, `process_placements`, `project_state`, `buildprobe.py` | Translation work-queue DB + swarm progress reporting (note: `gen_progress_report` is extensionless by convention — it's a report tool, not one of the `generators/` scripts) | not yet owned by a skill; each has a `Usage:`/docstring block — read that first |

`tests/`, `test_label_db.py`, `validate_scenarios.py` are regression suites,
not tools you run for output — see their own headers.
