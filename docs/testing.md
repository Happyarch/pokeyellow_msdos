# Testing the DOS Port

Short orientation doc: what the test tiers are, and which command belongs to
each. **Operational detail is deliberately not duplicated here** — the deep
recipes (DOSBox-X config, dump-file forensics, scenario authoring, the
dependency-graph API, music auditioning) live in the `build-and-debug` project
skill, and the fidelity-review workflow lives in `faithfulness-review`. Load the
skill; do not treat this file as a substitute for it.

Everything below is `make -C dos_port …` unless noted. Paths are relative to the
repository root.

---

## Read this first: never pipe a gate and read its status

```sh
make -C dos_port fidelity | tail -40        # WRONG
make -C dos_port fidelity > log; echo $?    # WRONG
```

The shell is **zsh**, and both forms report the exit status of the *last*
element of the pipeline/list — `tail` and `echo` both succeed, so **a failing
gate reads as a pass.** Do it this way instead:

```sh
make -C dos_port fidelity > /tmp/fidelity.log 2>&1
echo $? > /tmp/fidelity.status
cat /tmp/fidelity.status        # this is the gate's verdict
```

Redirect to a file, record `$?` to a file, read that file. (If you must inspect a
pipeline's stages, zsh's array is `$pipestatus` and it is **1-indexed** —
`$pipestatus[1]`, not bash's `$PIPESTATUS[0]`.)

The same discipline applies to reasoning about results: a green static gate
proves **no structural or bookkeeping drift and nothing about behaviour**. See
CLAUDE.md's Evidence and Knowledge Policy for why `defined` / `linked` /
`reachable` / `executed` / `golden-matched` / `visually-observed` are not
interchangeable.

---

## The tiers, at a glance

| Tier | Command | Needs | Proves |
|------|---------|-------|--------|
| Syntax | `make -C dos_port check` | nasm | every `.asm` assembles |
| Build | `make -C dos_port` | nasm, ld, mtools, dosfstools, sfdisk | `PKMN.EXE` links, `PKMN.IMG` packages |
| Static | `dos_port/tools/static_gate` | python3, pytest | no structural/bookkeeping drift |
| Runtime | `make -C dos_port fidelity` / `fidelity-full` | DOSBox-X, built goldens | port GB state matches the mGBA golden |
| Golden provenance | `make -C dos_port goldens-verify` | mGBA runner + pinned pret ROM | committed goldens are reproducible |

---

## Build

```sh
make -C dos_port            # default goal: PKMN.EXE + the PKMN.IMG disk image
make -C dos_port check      # assemble-only syntax check of every source (no link)
make -C dos_port image      # (re)package PKMN.EXE + CWSDPMI.EXE into PKMN.IMG
make -C dos_port clean      # objects + PKMN.EXE
make -C dos_port clean-image # delete PKMN.IMG (also wipes any save inside it)
```

`make` builds `dos_port/PKMN.EXE` (a DJGPP `coff-go32` executable) and then
`image` bundles it with `CWSDPMI.EXE` into a partitioned FAT16 hard-disk image
`dos_port/PKMN.IMG` with ~5 MB free for the in-game `.dsv` save. Rebuilds refresh
`PKMN.EXE` in place and **preserve** a save already inside the image — that
preservation is convenient for play and a hazard for testing (see "stale
artifacts" below).

Reference ROM (the read-only pret spec at the repository root):

```sh
make compare                # SHA1-verify the reference ROM build
```

Requires **rgbds 1.0.2** — the version is pinned in `.rgbds-version`; the
installed toolchain reports `rgbasm v1.0.2+hotfix`.

### Assets

Generated data (`dos_port/assets/*.inc`) is committed and regenerated from
generators under `dos_port/tools/generators/`:

```sh
make -C dos_port assets     # regenerate what is out of date; ends with audit_memmap.py
make -C dos_port regen      # force-regenerate everything (assets rules are timestamp-gated)
make -C dos_port audit_memmap  # standalone overlap/containment audit of gb_memmap.inc regions
```

Run `audit_memmap` after any edit that moves or grows a GB-space buffer.

---

## Running it

```sh
dos_port/run                       # build image + launch DOSBox-X against it
dos_port/run SKIP_TITLE=1          # bypass the (known-imperfect) title screen
dos_port/run DEBUG_AUDIO=1 /LOOP   # make vars vs EXE flags, split by the leading '/'
```

`dos_port/run` mounts **only** `PKMN.IMG` as `C:` — the host filesystem is never
exposed, so an OOB disk write from the game (at any `BUG_FIX_LEVEL`) can only
corrupt the image. Arguments starting with `/` are passed to `PKMN.EXE`
(`/NOSOUND /MT32 /GM /TANDY /SPK /NOENH /LOOP /FIXALL /FIXCRIT`, parsed in
`dos_port/boot/entry.asm`); everything else is passed to `make`.

`SKIP_TITLE=1` is the normal way in: the title screen is a known-imperfect
bespoke implementation, and `SKIP_TITLE` boots straight to the overworld.

The Makefile defines **112 `DEBUG_*` build gates** (count from
`grep -c '^ifdef DEBUG_' dos_port/Makefile`) — one per debuggable screen or
scenario, e.g. `DEBUG_DUMP`, `DEBUG_TRANSITION`, `DEBUG_WALK_NORTH`,
`DEBUG_SEAM`, `DEBUG_STARTMENU`, `DEBUG_PARTY`, `DEBUG_BAGMENU`,
`DEBUG_BATTLE_FAINT`, `DEBUG_AUDIO TRACK=…`, plus the `DEBUG_ASSERT*` family and
navigation seeds (`DEBUG_START_MAP/X/Y`, `DEBUG_NOCLIP`, `DEBUG_NO_WILD`). Read
`dos_port/Makefile` for the authoritative list and each gate's sub-flags; the
`build-and-debug` skill explains how to use them.

### Do not hand-roll a headless run

There are two supported headless drivers, and both exist because a hand-rolled
one produces a **false pass**:

```sh
dos_port/tools/run_headless.sh "DEBUG_ITEMTM=1" /tmp/probe   # no golden yet
dos_port/tools/goldencheck.sh <scenario>                     # golden-bound
```

`make image` preserves files already inside `PKMN.IMG`. So a freshly built image
can still carry a **stale `FRAME.BIN` / `DUMP.BIN` / `GBSTATE.BIN`** (and, worse,
a stale `POKEMON.DSV`) from an earlier build. A harness that copies those out
without deleting them first will happily extract the *previous* run's screen and
report it as this run's result — it renders like a genuine result. Both scripts
`mdel` those files from their scratch copy of the image before running, so any
file found afterwards is definitionally fresh. Both also operate on a **copy** of
`PKMN.IMG`, so a live `dos_port/run` session cannot clobber the extraction.

The old Xvfb + ImageMagick screenshot recipe this document used to carry is
retired for exactly this reason. Do not reintroduce it.

---

## Static tier — runs whether you remember it or not

```sh
dos_port/tools/static_gate                  # the whole-tree ratchet
make -C dos_port static_gate                # same, via make (GATEFLAGS=... passes through)
make -C dos_port install-hooks              # git config core.hooksPath .githooks
```

`static_gate` is fast (no emulator, no ROM, no golden) and runs, in order:

1. `update_label_db` — one shared rescan, into a **temporary** DB by default so
   the tracked `dos_port/tools/translation.db` is not left dirty (`--write-db`
   opts into in-place);
2. `lint_pret_labels` — per-class counts vs `tools/static_gate_baseline.json`;
3. `lint_pret_labels --strict-claims` — the four classes only that mode reports;
4. `pytest dos_port/tools/test_label_db.py`;
5. `dos_port/tools/validate_scenarios.py` — scenario manifest vs the generated
   registry.

Every class is a **ratchet**: a class that grows fails, and a class that shrinks
also fails (an unexplained improvement is the "good news nobody adversarially
reviews"). Lowering the baseline is deliberate (`--update-baseline`) and lands in
a commit.

`.githooks/pre-commit` invokes it automatically once you have run
`make -C dos_port install-hooks`; it exits 0 immediately when nothing under
`dos_port/` is staged. Bypass one commit with `git commit --no-verify`; undo the
hook with `git config --unset core.hooksPath`.

**A class sitting at baseline is not sanctioned** — it is unfixed debt that has
merely not gotten worse. `dos_port/tools/lint_pret_labels` must ultimately exit
0. Measure it yourself (`lint_pret_labels --no-scan`, and again with
`--strict-claims`) rather than quoting a count from any document, this one
included.

The per-change counterpart is `dos_port/tools/fidelity_gate` — the per-label
evidence chain for a specific diff, including the relocation move battery
(`--move-baseline` before editing, `--move-verify` after). See
`faithfulness-review`.

---

## Runtime tier — the golden fidelity harness

This is the project's actual regression mechanism. Each scenario builds a
`DEBUG_*` image, runs it headless in DOSBox-X, extracts `GBSTATE.BIN`, and diffs
the port's GB state (tilemap / VRAM / OAM / WRAM regions, with per-scenario
masks) against a golden captured from **mGBA running the sha1-verified reference
ROM**.

```sh
make -C dos_port fidelity        # core tier
make -C dos_port fidelity-full   # every scenario
make -C dos_port goldencheck SCENARIO=<name>   # one scenario
dos_port/tools/goldencheck.sh <name>           # same, directly
```

Scenario inventory lives in `dos_port/tools/scenario_manifest.json`. Measured
from that file (re-measure; do not copy this number):

- **37 scenarios total**
- **16** in the `core` tier (`make fidelity`), **37** in `full`
  (`make fidelity-full`)
- `disabled_scenarios` is **empty** — nothing is switched off

Each entry declares its `build_flags`, `port_entry_gate`, mGBA
`navigation_script`, dump type/artifact/timeout, `must_hit` labels, and the
comparison regions/masks. Two scenarios declare a `seed_save`; `goldencheck.sh`
converts that GB `.sav` fixture through `dos_port/tools/saveconv.py --to-dos` on
every run, which keeps the converter on the tested path.

Regenerating and drift-checking the goldens themselves (needs the pinned
pristine pret worktree and the built mGBA Lua runner):

```sh
make -C dos_port goldens          # regenerate tests/goldens/ from the pinned ROM
make -C dos_port goldens-verify   # regenerate into scratch and diff vs committed
```

`goldens-verify` re-checks the ROM's SHA1 against `roms.sha1` first, so a wrong
ROM fails loudly instead of silently producing wrong goldens.

**A regression with a runtime repro should become a golden scenario.** Once it
has one, the suite is the currency mechanism — a re-break fails the suite instead
of waiting to be re-noticed.

---

## Other diagnostics

- `dos_port/tools/render_frame.py` — turn a `FRAME.BIN` back-buffer dump into a
  viewable image.
- `dos_port/tools/pixelcheck.sh` — pixel-level frame comparison.
- `dos_port/tools/perf_capture.sh` + `read_perf.py` — the `DEBUG_PERF` profiler
  (`PERF.BIN`).
- `dos_port/tools/read_seamlog.py` — `SEAMLOG.BIN`, for map-seam work.
- `dos_port/tools/saveconv.py --verify FILE` — inspect/validate a `.sav`/`.dsv`.
- `dos_port/tools/project_state --plans`, `dos_port/tools/label_status --callers`,
  `dos_port/tools/faithdiff <Label>` — generated project state; read-only.

All of these are documented properly in the `build-and-debug` skill.

---

## Concurrency warning

The build writes objects next to their sources in a single shared tree. **Two
concurrent `make` invocations corrupt each other's objects** (the classic symptom
is `file is not recognized: file truncated`), and a concurrent `update_label_db`
races on `tools/translation.db`. A live `dos_port/run` session also holds
`PKMN.IMG` open — `run` refuses to start a second one. Serialize builds, gates
and emulator runs.
