# Current Plan: Bug/Glitch Tagging + translation.db Maintenance (+ optional unwired save draft)

**Autonomous goal doc.** A Sonnet agent executes this end-to-end in a fresh
session with **no user available** — see the hard "do not ask questions" rule
below. Everything needed to make every decision is in this file + `CLAUDE.md` +
the two skills named per phase. Read this file in full before starting.

---

## Hard rules (non-negotiable)

1. **DO NOT ask questions.** The user is away. When you hit a choice this doc
   doesn't cover, make the most conservative reasonable call, **write a one-line
   note of what you decided and why in the phase's ledger doc**, and keep going.
   Never block waiting for input.
2. **Everything you add stays UNWIRED / behavior-neutral.** Bug/glitch tags are
   **comments only** — zero change to emitted code at the default `BUG_FIX_LEVEL=0`.
   The save draft is new routines + a headless test harness only; it must not
   replace or alter any live save-menu / boot-load path.
3. **Never touch audio arrangement files** — anything under
   `dos_port/tools/audio/overrides/*.yaml` or `docs/sound/`. They hold the user's
   uncommitted hand-tuning. Leave them exactly as-is; never stage them.
4. **Preserve pret label names.** Never rename/invent (see CLAUDE.md).
5. **Never hand-edit `translation.db`** — it is rescan-derived. The *only*
   sanctioned way to update it is running `dos_port/tools/update_label_db`.
6. **Never edit `dos_port/tools/pret_label_allowlist.json`.** Allowlist curation
   is a human review task — you only *report* suspected discrepancies in the
   ledger.
7. **Work on a dedicated branch** `chore/bug-tagging` (cut from `master`). Commit
   in small, in-scope batches. Do not commit on `master`; do not
   rebase/amend/reset any commit you did not create this session.
8. **Commit message trailer** (every commit):
   `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`
9. Each commit must pass the gate for the files it touches (see Verification).

---

## Phase A — Bug/Glitch tagging + translation.db maintenance (PRIMARY)

**Load first:** Skill `project-conventions` (BUG/GLITCH tag templates + two-tier
rule) and Skill `faithfulness-review` (faithdiff / lint_pret_labels /
update_label_db / label_status). You do **not** need `asm-translation` or
`build-and-debug` for this phase.

### Scope decision (settled — do NOT deviate)

Tagging is **comment-only**. For each original-game bug/glitch that has a
*ported* routine, add the identifying comment **but not** any
`%if BUG_FIX_LEVEL >= N` fix block. Implementing fixes is a separate, later task
(`/FIXCRIT` wiring) and is explicitly **out of scope** here. Rationale: comment
tags leave `BUG_FIX_LEVEL=0` byte-identical → zero regression risk for an
unattended run.

### Tag formats (from `project-conventions`)

- Bug: `; BUG(critical|cosmetic): <desc> — pret ref: <file>:<label>, bugs_and_glitches.md#L<N>`
  placed at the exact site in the ported routine, above the buggy instruction(s).
- Glitch (intentional/exploitable): `; GLITCH: <name> — <desc>` + a following
  `; Safety: safe under DPMI (bounded) | unsafe on bare HW if ACE reachable`.

### Severity rubric (settled — apply consistently, note reasoning in the ledger)

- **critical** — the bug can corrupt saved/party/box data, crash/hang, desync
  battle state, or otherwise change gameplay outcome (e.g. stat/exp/HP math,
  wrong branch, OOB). Tag `BUG(critical)`.
- **cosmetic** — visual/text/audio-only artifact with no gameplay-state effect
  (misdrawn tile, wrong string, off-by-one cursor). Tag `BUG(cosmetic)`.
- If genuinely ambiguous, default to **critical** (safer to over-flag) and note
  why in the ledger.

### Procedure

1. Enumerate every entry in `docs/bugs_and_glitches.md` (the pret bug list) and
   any intentional glitches referenced by `docs/glitch_safety.md`.
2. For each, find the corresponding **ported** routine (grep `dos_port/src` for
   the pret label; `dos_port/tools/label_status --callees/--callers <Label>`
   helps). Note that ~19 BUG tags / ~7 GLITCH tags already exist — **do not
   duplicate**; verify and extend, don't re-tag.
3. If the routine is ported → add the comment tag at the precise site.
   If the routine is **not yet ported** → do NOT tag anything; record it in the
   ledger as "pending port."
4. After each batch, keep the label DB honest: run
   `dos_port/tools/update_label_db`, then `dos_port/tools/lint_pret_labels`
   (must exit 0). If `translation.db` is git-tracked and changed, commit it with
   the batch.
5. **translation.db maintenance side-task:** while sweeping, if
   `lint_pret_labels` or `label_status` surfaces a stale extern comment, a
   mis-filed stub, or a suspect `relocated_labels` allowlist entry, **fix the
   extern comment / stub filing** (those are code-comment hygiene, in scope) but
   only **report** allowlist-entry doubts in the ledger (rule 6).

### Deliverables

- Comment tags across the ported routines.
- Ledger `docs/bug_categorization.md` — a table: pret bug → `bugs_and_glitches.md`
  line → severity + reasoning → ported? → routine `file:label` → tagged? (or
  "pending port"). This is also the categorization deliverable from TODO Phase 6.
- Glitch safety ratings folded into `docs/glitch_safety.md` where missing.
- `translation.db` in sync; `lint_pret_labels` exits 0.

### Verification (per touched file, before committing)

- `nasm -f coff -I include/ -I . -o /dev/null <file>` assembles clean.
- `dos_port/tools/lint_pret_labels` exits 0.
- `dos_port/tools/faithdiff <Label>` for each touched pret-labeled routine shows
  **no** added/dropped calls (tags are comments — any call-graph delta means you
  accidentally changed code; fix it).

### Phase A stopping criterion

Every `bugs_and_glitches.md` entry is categorized in the ledger, every one with a
ported routine is tagged, glitches carry `Safety` ratings, and lint is green.
Then proceed to Phase B (if run budget remains) or stop.

---

## Phase B — Unwired save-system draft (OPTIONAL / SECONDARY)

Only start after Phase A's stopping criterion is met. **Load additionally:**
Skill `asm-translation` (translating `SaveSAV`/`LoadSAV` etc.) and Skill
`build-and-debug` (headless `GBSTATE`/`DUMP` verification, `.dsv` file I/O via
DPMI, nasm). Keep `project-conventions` + `faithfulness-review` loaded.

### Scope (settled)

Faithful, **unwired** draft of the SRAM save/load core:

- Translate pret's save routines (`SaveSAVtoSRAM` / `LoadSAV` family — find the
  pret sources via `label_status`; the menu wrapper is `engine/menus/save.asm`,
  the SRAM logic is in the `home/`/`engine/` save files). Keep the pret label
  names. The port emulates the 32 KB SRAM region in GB memory and writes the
  player/party/box/flags into it exactly as pret lays it out (byte-identical
  struct rule from CLAUDE.md still applies).
- Wrap the 32 KB SRAM image in the **`.dsv`** container from CLAUDE.md: `"DOSV"`
  magic + 1 version byte + 2-byte checksum + 32 KB SRAM data. Add `WriteDSV` /
  `ReadDSV` port-only routines that do the DOS file I/O via the DPMI
  "Simulate Real Mode Interrupt" INT 21h pattern already used by
  `src/debug/debug_dump.asm` (copy that mechanism; do not invent a new one).

### UNWIRED requirement

Do **not** hook these into the live save menu or boot-load. Add the routines +
a `DEBUG_SAVE` headless harness (modeled on the existing `DEBUG_*` gates) that:
seed a known party/state → `SaveSAVtoSRAM` → `WriteDSV` → clear → `ReadDSV` →
`LoadSAV` → dump via `DumpGBState`, so a host-side diff proves round-trip
fidelity. The normal game must build and behave exactly as before.

### Verification

- Native ELF32 + `gcc -m32` unit test of the SRAM-layout + checksum logic where
  practical (mirror the items plan's native-validation pattern).
- Headless `DEBUG_SAVE` round-trip: seeded state == reloaded state (`GBSTATE`
  diff).
- `nasm` assembles; `lint_pret_labels` exits 0; `faithdiff` on the translated
  save labels justified in the commit (this phase *does* add calls — justify per
  the faithfulness gate).

### Phase B stopping criterion

`SaveSAVtoSRAM`/`LoadSAV` + `WriteDSV`/`ReadDSV` drafted, round-trip harness
passes, and a ledger note (`docs/current_plan_bug_tagging.md` "Save draft
status" section, appended by you) lists exactly what remains to *wire* it live
(menu hook, boot-load, `saveconv.py`). Then stop.

---

## What NOT to do (recap)

No `%if BUG_FIX_LEVEL` fix code; no live wiring of anything; no audio `.yaml`
edits; no `translation.db` hand-edits; no allowlist edits; no commits on
`master`; no questions.
