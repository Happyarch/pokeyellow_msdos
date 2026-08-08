---
name: project-conventions
description: Detailed project conventions for the Pokémon Yellow DOS port. Invoke when adding a link-time stub, deciding whether something is generated data vs. hand-written code (the two-tier rule, incl. the "text strings are DATA, never hand-encode charmap bytes" rule), writing a BUG_FIX_LEVEL / GLITCH guard, or creating/archiving an active-plan file; also holds the save-file format notes. Triggers: "add a stub / *_stubs.asm", "BUG_FIX_LEVEL", "GLITCH tag", "should this be a generator or code", "gen_*.py / assets/*.inc", "hand-encode a string / charmap db", "current_plan_*.md", "archive a plan", ".sav / .dsv save format".
---

# Project Conventions (detailed)

Deep reference for the port's conventions. The one-line hard rules (stubs live in
`*_stubs.asm`; text strings are generated, never hand-encoded; bug/glitch tagging)
are summarized in `CLAUDE.md`; the full conventions are here.

## Structured annotations (BUG / GLITCH / DEVIATION / STUB)

**These are machine-parsed, not prose.** `tools/lint_pret_labels` strictly parses
them (`ANNOTATION_RE`); a malformed annotation, an unknown `class`, or a missing
field is a **violation that fails the gate**. This is the mechanism that makes a
divergence's "why" queryable by tooling instead of stranded in a commit message.

```nasm
; DEVIATION{class=<class>; pret=<file>:<Label>; behavior=<what differs>; evidence=<why that is the truth>; lifetime=<what retires it>}
```

**Kinds — exactly four: `DEVIATION`, `BUG`, `GLITCH`, `STUB`.**
Do **not** invent a kind. An unrecognized one (`RELOCATION{…}`, `NOTE{…}`) does not
parse, so the linter treats it as an ordinary comment: it looks rigorous and proves
nothing. **New relocations are not allowed.** A pret counterpart's complete body
and every pret entry point belong in `dos_port/src/<pret path>`. Existing entries
in `tools/pret_label_allowlist.json` are a legacy-debt inventory, not permission or
precedent; move them back to their mirrors when touched. An agent whose change
trips the mirror rule must repair the file placement, not edit the registry or add
a `structural_findings` entry. Registry edits may only retire or reclassify audited
debt and are content-hash locked outside the worktree.

**Required fields — all four kinds:** `class`, `pret`, `behavior`, `evidence`,
`lifetime`. Plus:
- `GLITCH` also requires `safety` (e.g. `safety=safe under DPMI (bounded)` /
  `unsafe on bare HW if ACE reachable`).
- `STUB` also requires `label`, and its `class` must be `stub` or `temporary`.

**`class` must be one of:** `HAL`, `banking`, `projection`, `data-model`, `timing`,
`stub`, `temporary`. Nothing else parses.

**Syntax trap:** the parser splits the body on `;`, so **no `;` or `}` inside any
field value** — use commas. Keep the annotation on one line.

### Bugs: annotation + fix block

A known bug pairs the annotation with a conditional block. Levels: `1` = critical
only (`/FIXCRIT`), `2` = all (`/FIXALL`); the Makefile passes `-D BUG_FIX_LEVEL=$(BUG_FIX_LEVEL)`
(default 0), so bare `nasm` runs without `-D BUG_FIX_LEVEL=` will fail on the `%if`.

```nasm
; BUG{class=data-model; pret=home/names.asm:GetName; behavior=HM01 threshold redirects every name type, not only items, to machine-name formatting; evidence=pret GetName unconditional cp HM01 before type dispatch; lifetime=permanent latent Gen-1 behavior}
%if BUG_FIX_LEVEL >= 2
    ; fixed implementation
%else
    ; original (buggy) behavior
%endif
```

### The legacy free-form format is dead — do not resurrect it

`lint_pret_labels` still *accepts* free-form `; BUG(critical): …` / `; GLITCH:` +
`; Safety:` comments (legacy acceptance carried over from the migration), and
`--strict-claims` flags each one as `legacy_annotation` ("requires evidence-backed
migration").

**Do not quote a count from this file — measure it.** The structured-annotation
population moves every session:

```
# structured annotations, by kind
for k in DEVIATION BUG GLITCH STUB; do
    printf '%s: %s\n' "$k" "$(grep -rohE "; ?${k}\{" dos_port/src | wc -l)"
done
# the legacy-format gate (never bare — a bare run rewrites translation.db)
dos_port/tools/lint_pret_labels --no-scan --strict-claims
```

Re-measured 2026-08-08: `--strict-claims` reports **zero** `legacy_annotation`
(also zero `hand_encoded_text` / `local_shadow` / `stale_provider`), with
221 `DEVIATION{}`, 46 `BUG{}`, 10 `GLITCH{}`, 72 `STUB{}` under `dos_port/src`,
across 14 `*_stubs.asm` files. The 2026-08-02 line said 192/46/10/**21**, and the
2026-07-25 one said 132/44/13/22 — note `STUB{}` reads 21 → 72 in six days, which
is not a real jump so much as proof that a prose count is worthless: measure it.

**A live worked example of why `--strict-claims` matters, from 2026-08-08.** A
comment reading `; DEVIATION on AnimationWavyScreen in engine/battle/...` — a
plain PROSE CROSS-REFERENCE with no `{}` — was flagged as `legacy_annotation`,
correctly. A line that merely *mentions* an annotation kind in the annotation
position parses as a malformed one. If you want to point at an annotation from
elsewhere, do not start the line with the keyword.

Treat any figure here as a measurement with a date on it, not an invariant: the
zero had silently drifted to 2 before this line was first corrected, because
plain `lint_pret_labels` does not gate on this class — only `--strict-claims`
does. `static_gate` (and therefore `.githooks/pre-commit`) now runs BOTH modes,
so the class is automatically ratcheted; it is still not gated to zero by
anything but this rule. **Re-run the check; do not quote this paragraph as
evidence.** Three `BUG(critical)`/`BUG(cosmetic)`-looking strings survive and are
*prose references inside comment text* (`src/home/names2.asm:49`,
`src/engine/pokemon/experience.asm:136`,
`src/engine/battle/move_effects/transform.asm:14`) — not annotations, and not a
precedent. Writing a free-form one now is a regression that `--strict-claims`
will report.

## Stub Conventions (all stubs live in a subsystem `*_stubs.asm`)

When a routine must exist at link time but its real body is deferred, the stub
does **not** go in the `.asm` that mirrors its pret source file — it goes in the
**subsystem stub file**, `src/<area>/<area>_stubs.asm` (e.g.
`src/engine/overworld/overworld_stubs.asm`, `src/engine/battle/core_stubs.asm`,
`src/engine/menus/main_menu_stubs.asm`, `src/home/home_stubs.asm`). This keeps
every stand-in greppable in one place per subsystem, so retiring stubs later is
a bounded search, not a tree-wide hunt.

Get the live set with `find dos_port/src -name '*_stubs.asm'` rather than
trusting a list here — the set shrinks as stubs retire (`pc_stubs.asm`, which
this paragraph named for months, was deleted in `0c9afce5`).

**Rules:**
1. **Keep the pret label.** The stub carries the exact pret routine name (see
   "Preserve pret Labels"); it is a `global` in the stub file and just `ret`s (or
   returns the minimal flag/CF contract its callers read). Never fork a new name
   for a stub.
2. **Stub file, not the source-mirror file.** Do not leave a `ret`-only body in
   the file that will eventually hold the real routine. Put it in the
   `*_stubs.asm`; create that file if the subsystem has none yet.
3. **Callers point at the stub file, not the pret origin.** An `extern`'s trailing
   comment names **`<area>_stubs.asm`** as the current provider — not the pret
   source the routine will eventually be translated from. That comment is the
   discovery trail: it says "this symbol is a stub right now, and here's the file
   to delete it from." (Optionally note the pret origin second, e.g.
   `; core_stubs.asm — pret: home/…`.)
4. **Each stub documents its own retirement.** Head each stub with the pret ref
   and a `TODO(<wave/plan>):` line stating what replaces it, plus whether it is
   ever reached in the live build (many are dead branches kept only to resolve the
   link). Model on `overworld_stubs.asm`.
5. **Retire, don't shadow.** When the real routine lands (moved into a *linked*
   Makefile list, not a check-only one), **delete the stub** and repoint the
   `extern` comments — do not leave the stub `global` shadowing the real body.
   Two linked `global`s of one name is a link error; a stub linked while the real
   body sits in a check-only list is the silent-shadow trap this convention exists
   to make findable. **Run `dos_port/tools/label_status --callers <Label>` and
   work the list**: it prints every port caller + every file `extern`ing the
   label with its comment — repoint each extern comment, and eyeball each caller
   for stub-era assumptions (translated/verified while `<Label>` was a ret-stub?
   depends on registers/flags the real body clobbers?).
6. **After adding or retiring a stub, run `dos_port/tools/update_label_db`** so
   the label DB reflects it, and `dos_port/tools/lint_pret_labels` to catch a
   non-ret-only stub, a duplicate def, or a stale extern comment immediately
   (the DB is rescan-derived, so a skipped rescan self-heals — but the linter
   run is what catches the violation *before* it's committed).
   Both of those WRITE the tracked `translation.db`, so they are a serialized
   resource: never run them while another agent is building or rescanning. To
   read findings without touching the DB, use `lint_pret_labels --no-scan`.

## Data vs. code: the two-tier rule (regen must never clobber anything)

Many subsystems (moves, items, base stats, maps, …) can't be *fully* generated —
some entries need bespoke, hand-authored logic. Keep that logic safe from
`make assets` by holding a hard split between two tiers:

- **Tier 1 — data, machine-owned: `assets/*.inc`.** Static tables only (move
  power/acc/PP/type, names, field-move display rows, effect-category membership,
  base stats, map blobs). Every such file carries a `DO NOT EDIT BY HAND —
  generated by tools/generators/gen_*.py` header. Each generator is a *deterministic function
  of the read-only pret source + the constant enums*, so the output holds **zero
  hand-authored information** — rerunning is idempotent and cannot lose anything.
- **Tier 2 — code, human-owned: `.asm`.** All per-entry *behavior*: move-effect
  handlers (`src/engine/battle/move_effects/*.asm`), predicates/dispatchers
  (`src/engine/battle/move_category.asm`, `src/home/names.asm`), item effects
  (`src/engine/items/item_effects.asm`), etc.

  **The test is behavior, not subject matter.** `field_moves.asm` used to be
  cited here as Tier 2 and it was wrong: it holds only the generated
  `FieldMoveDisplayData` / `FieldMoveNames` tables, so commit `a3804828` moved it
  to `dos_port/src/data/field_moves.asm` as the Tier-1 data it always was. A file
  that is "about" moves is not thereby code. Ask whether it *decides* anything.

**Hard rules:**
1. **Generators write only `assets/*.inc`. They never emit `.asm`.** So
   `make assets` physically cannot touch Tier 2.
2. **`.asm` is never machine-generated.** Every move/item-specific decision,
   `BUG`/`GLITCH` guard, and quirk lives there.
3. The two tiers link **by id/index, never by inlining** — the worked example is
   `MoveEffectPointerTable`, which exists today at
   `dos_port/src/data/move_effect_pointers.asm`: a hand-written 86-entry `dd`
   table keyed by the effect byte that comes from the generated data table.
   Adding bespoke logic = write/point a handler in code; it does not touch the
   data.

   **It is hand-written *and* lives in the data layer, and that is not a
   contradiction.** No generator can derive it, because its rows are PORT
   function names (unported handlers point at the `UnportedMoveEffect` ret-stub
   beside the dispatcher in `src/engine/battle/effects.asm`) — but pret files the
   same table under `data/moves/effects_pointers.asm`, and the linter's
   `aux_misplaced` rule asks only that a pret `data/` label live under
   `dos_port/src/data/` **or** a generated `assets/*.inc`. A hand-written
   dispatch table in the data layer satisfies both. It moved there in `a3804828`;
   pret's `dw` (bank-relative) becomes `dd` (flat DPMI linear), and it sits in
   `section .data` since it is only ever `lea`'d, never executed.
4. **If a data value must deviate from the pret source** (a fix, or a value pret
   doesn't carry), do **not** hand-patch the `.inc`. Either (a) teach the
   generator the override — ideally reading an explicit sidecar list so it's
   visible and survives regen — or (b) keep the override in code: load the
   generated value, then adjust in the routine under a `BUG_FIX_LEVEL` block.

### Text strings are DATA — generate them; never hand-encode charmap bytes

**This is the single most repeated Tier-1 violation. Read it before you type a
`db 0x…` with a charmap glyph in it.** Any human-readable string the game renders
(menu labels, screen labels, item/move/mon names, dialog, button captions — even a
short one like `"OK"` or `"TYPE1/"`) is **Tier-1 data** and MUST be produced by a
Python generator that charmap-encodes it via `tools/generators/gb_text.py` (`gb_text.encode`,
the `unicode_converter` submodule) into an `assets/*.inc` with the `DO NOT EDIT`
header, `%include`d by the `.asm` and wired into the Makefile `assets` target.

- **DON'T** write `TypesIDNoOTText: db 0x93,0x98,0x8F,0x84,…  ; "TYPE1/"` in a
  `.asm`. Hand-transcribed charmap hex is unreviewable, silently drifts if the
  charmap changes, and is exactly the Tier-1 data the two-tier rule forbids in code.
- **DO** add the label (as readable text) to a generator and `%include` the result.
  Follow the existing pattern: `tools/generators/gen_menu_strings.py` (START-menu labels) and
  `tools/generators/gen_status_strings.py` (status-screen labels) → `assets/menu_strings.inc` /
  `assets/status_strings.inc`. Add your screen's strings to the matching generator
  (or a new `gen_<screen>_strings.py` modeled on those), then add the `.inc` to the
  `assets` target + the consuming `.o`'s prerequisites.
- **Control/format tiles inside a string** that `gb_text.encode` can't map
  (`<NEXT>` $4E, `<LINE>` $4F, `<ID>` $73, …) are inserted by the generator as
  named raw bytes between encoded text runs — mirroring pret's `db "…"` / `next`.
  A **single control tile written by code** (e.g. `mov byte [ebp+esi], LB_VLINE`)
  is not a string and stays in the `.asm`.
- **Pointer/address tables are NOT strings** — a `dw`/`dd` table of WRAM offsets or
  routine addresses (e.g. `OTPointers`, a jump table) is code (Tier 2), hand-written
  in the `.asm`. The rule is about *encoded glyph runs*, not every `db`/`dw`.
- **The legacy hand-encoded backlog is CLEARED — there is no precedent left to
  point at.** This bullet used to name `party_menu.asm`, `bag_menu.asm`,
  `home/names.asm` and "older battle labels" as accepted debt; measured
  2026-08-02, `party_menu.asm` and `home/names.asm` carry no charmap byte runs
  and there is no `bag_menu.asm` in the tree at all. `3fad3249` took
  `hand_encoded_text` **3 → 0** (the last holdout was `CopyrightTextString` in
  `src/engine/movie/title.asm`, now derived by `gen_static_tables.py` into
  `assets/copyright_text.inc`). Anything you add now is the *first* violation,
  not the next one. Re-measure with
  `dos_port/tools/lint_pret_labels --no-scan --strict-claims`, and note the
  detector is deliberately conservative — it needs a `db` run with a `>= $7F`
  byte **plus** either a quoted string in the trailing comment or a `*Text*`-ish
  label, so a hand-encoded run with no comment can still slip past it. The rule
  binds you, not just the linter.
- Worktree caveat for the generator: it needs the
  `unicode_converter` submodule (seed it from the primary clone); the generated
  `.inc` is gitignored and regenerated by `make assets`.

## Active Plan Convention

Active multi-step implementation plans live as a **family** of files named
**`docs/current_plan_<topic>.md`** — one per work item, suffixed by what it's
about. **Multiple may be active at once** (e.g. one engine in progress while
another is paused). They sit between `ROADMAP.md` (big-picture scope for the
entire port) and individual task lists: use one for anything too large for a
single commit but too specific to belong in `ROADMAP.md`.

> The root `TODO.md` was **removed 2026-07-25** (commit `3bee670d`) as stale
> beyond salvage. Several deferred tails below named it as their tracker; they
> now live in **`docs/current_plan_backlog.md`** — still open, not done, but no
> longer homeless. Read that file rather than assuming they are untracked.
> Inventory of what moved: stigmergy memory `todo-md-deleted-orphaned-trackers`.

**Workflow:**
- At the start of each session, scan `docs/current_plan_*.md` to see every open
  work item and pick up where we left off.
- Mark stages `[x]` as they complete (edit the file in-repo).
- When a plan is fully done, archive it: `git mv docs/current_plan_<topic>.md
  docs/plans/<topic>.md` (drop the `current_plan_` prefix). The `docs/plans/`
  subdirectory holds completed plans for reference.
- Start a new work item by creating a new `docs/current_plan_<topic>.md`.

**Plan notes — NOT an inventory. Get the live list from the generator:**

```
dos_port/tools/project_state --plans
```

That is the authority on which plans exist and how many stages each has open, and
it cannot drift because it reads the tree. CLAUDE.md's Evidence policy says not to
maintain a second hand-written inventory next to it — so the list below is
deliberately **not** one. It holds only the durable per-plan *narrative* the
generator cannot produce: what a plan is for, what its lessons were, and which of
its tails were deferred and to where.

Read it for that narrative, never for "what is active". It was last reconciled
against the generator on **2026-08-02**; entries marked *COMPLETE & archived*
are history kept for their lessons. When this section and the generator disagree
about existence, the generator wins and this section is the bug.

One generator caveat worth knowing before you trust its output: it counts only
checkbox lines (`- [ ]` and the backtick form `` - `[ ]` ``), so a plan written
as prose or numbered headings reports `0 completed / 0 open` regardless of its
real state. `current_plan_backlog.md` reads 0/0 while holding 18 numbered items
(several already marked DONE/FIXED in place) plus a relocation-debt pointer;
`_bug_tagging` and `_doc_staleness` read 0/0 too. **"0/0" means
"unparsed", not "empty"** — open the file. (The glob is `current_plan*.md`, not
`current_plan_*.md`, deliberately, so the plural
`docs/current_plans_remaster_Music_Cities1.md` is included.)

**A deferred tail is probably NOT untracked.** Several entries below used to end
"currently untracked"; most of those now live as numbered items in
`docs/current_plan_backlog.md` — CI wiring, the `battle_menu` golden spec,
battle-UI session B6, the status-screen front-pic/cry/STATS wire, the
`LoadPokedexTilePatterns` tileset, the window-compositor gap, interactive
navigation sweeps, the cable-club warp seam, the faithdiff relocation blind
spot, and the pret-tree contamination decision. Grep that file before repeating
the claim.

**A plan with no entry below is normal — go to the file itself.** There is
deliberately no list of those here: one used to sit at this spot and it drifted
within days (it named five plans and had already lost
`docs/current_plan_predef_text.md` entirely by 2026-08-02). Deleted under the
generated-is-authoritative rule adopted 2026-08-02. To find a plan that has no
narrative entry, diff the generator's output against the headings below:

```
dos_port/tools/project_state --plans
```
- **Fidelity-harness expansion — COMPLETE & archived** at
  `docs/plans/fidelity_expansion.md` (2026-07-15). It expanded the golden harness from the
  original rendered-screen tier into GBSTATE v2 WRAM datastruct comparison, streamed text,
  item datastruct flows, battle scenarios, full-screen menu scenarios, core/full fidelity
  tiers, `goldens-verify`, and mask-policy docs. Remaining open findings from that work
  stay with the normal bug/finding backlog, notably **F-13** (stride-20 dialog scratch /
  map mirror overlap), **F-14** (▼ after `done` text), and **F-19** (battle enemy-gauge
  clone masks).
- **Menu fidelity — COMPLETE & archived** at `docs/plans/menu_fidelity.md` (2026-07-14). All 24
  rows de-bespoked against pret. Its lesson, worth carrying: **the recurring defect was not bad
  assembly, it was a confident comment** — false `STUB`/`TODO-HW` claims hiding calls that were
  droppable only in the comment's imagination. It left ~20 `M-` findings OPEN as a backlog; the
  harness-facing ones are imported by the fidelity-expansion plan above.
- **Fidelity harness — COMPLETE & archived** at `docs/plans/fidelity_harness.md`
  (2026-07-07, branch `fidelity_harness`): mGBA golden differential testing
  (`make fidelity` / `goldencheck`, 6 scenarios *at the time* — the suite is 37
  today, see `SCENARIOS` in `tools/golden_diff.py`; mgba-mcp bridge) + static
  tooling (`update_label_db` / `lint_pret_labels` / `faithdiff` / `label_status`,
  the `faithfulness-review` skill), plus the dosbox-x unattended-quit fix.
  Its deferred tails are now **tracked in `docs/current_plan_backlog.md`**:
  battle_menu golden spec (#9), CI wiring (#4, static tier DONE 2026-07-26 —
  `static_gate` + `.githooks/pre-commit` + a GitHub workflow), the relocation
  debt including `FormatMovesString` (the "Relocation debt" pointer section) and
  the pret-tree contamination decision (#5, premise contradicted, re-check).
- **Compositor performance — COMPLETE & archived** at
  `docs/plans/compositor_perf.md` (2026-07-12). The port was running at ~half
  speed (31–34 ms/frame against a 16.348 ms budget); it now lands every frame
  inside one PIT tick (work = 30–45% of budget). `render_bg` dirty-skips against
  a tile-id shadow, `render_window` gathers rows from `tile_cache` once per 8
  lines, tiles decode through an assembly-time 2bpp→8bpp LUT, and sprites
  composite from `tile_cache`. Tooling it left behind: `DEBUG_PERF` +
  `tools/perf_capture.sh` / `read_perf.py` (per-stage PIT profiler) and
  `tools/pixelcheck.sh` (headless FRAME.BIN pixel-identity check).
  **Standing invariant:** BG *and* window now read only `tile_cache`, so any
  VRAM tile-pattern write that fails to arm `g_tilecache_dirty` is **visible
  corruption**, not just a stale decode. Two negative results are recorded there
  so they aren't re-attempted blind: the `present` dirty-row diff measured
  *slower* (rejected), and `wait_vblank` overrun pacing was dropped (no overruns
  left to pace). Also: **`FRAME.BIN` cannot validate `present`** — it dumps the
  back buffer, which is `present`'s input.
- `docs/current_plan_audio.md` — **audio subsystem (Phase 3)**, architecture settled
  2026-07-05: faithful pret engine translation driving a virtual APU + per-device
  shims (OPL3/SB Pro floor, Tandy, PC speaker), MT-32-flagship MIDI path via
  precompiled streams, Pikachu PCM via DSP direct mode / speaker PWM. Phases A–E.
  **The engine is LIVE and linked** — do not repeat the old "Phase A not started"
  line from this entry, which was false: `AUDIO_SRCS` in `dos_port/Makefile`
  links `audio_hal`, `opl_shim`, `opl_enh`, `tandy_shim`, `spk_shim`, `mpu401`,
  `sb_pcm`, `spk_pcm`, `pikachu_pcm`, `engine_1..4` and friends. Status as of
  2026-08-02, from the plan's own boxes: **C (Pikachu PCM) and D (Tandy +
  speaker SFX + polish) are `[x]`, DONE 2026-07-07**; **B (MIDI/MT-32) is `[~]`,
  infrastructure complete**; **A is `[ ]` at the top level but every substantive
  sub-item under it is `[x]`** (OPL3 reference, `pret_audio.py`, `gen_audio_data.py`
  + ROM byte-compare, the `home/audio.asm` gateway and engine translation, the
  `DelayFrame` tick hook, `opl_shim` + `gen_opl_patches.py`, `BLASTER` detection)
  — only the stub-retirement tail is `[~]`. Read the boxes, not the parent.
  Phase E is the LLM music arranger (the `score-analysis` / `music-theory` /
  `audio-enhance-*` skill set).
- **script engine — not active, but the plan file EXISTS. Read it.** There is no
  `docs/current_plan_script_engine.md` — `eb17e64d` (2026-07-12) recorded it as a
  RENAME (`R098`) into `docs/plans/`, which is why a delete-log search comes up
  empty. **This entry used to add "and never archived, so do not go
  looking in `docs/plans/` either"; that was MEASURED FALSE (2026-07-26) and is
  the exact opposite of the truth.** The plan is archived at
  **`docs/plans/current_plan_script_engine.md`** — note it kept its
  `current_plan_` prefix, against the archive convention two paragraphs above,
  which is why a `docs/plans/script_engine.md` search finds nothing. The gen-1
  script system (event-gated dialog, per-map `_Script`/`text_asm`, `DisplayTextID`
  special cases) is owned by **`docs/current_plan_overworld_events.md`**, which is
  active. Its deferred tails — Oak walk-up cutscene, `_Script` state machines —
  live there.
- **Overworld port — COMPLETE & archived** at `docs/plans/overworld_port.md`
  (there is no `docs/current_plan_overworld_port.md`) — **full faithful port of pret
  `engine/overworld/`** (staged swarm+solo; branch `overworld-port` cut after the
  battle-swarm merge). **It also owns the menu live-render defect** — see its
  "Cross-cutting defect" section (heading now: *menu box-draw geometry + window
  compositor*) and the Stage 8 verification item.
  **The VRAM tile-slot explanation for that defect is DISPROVEN, and this entry
  used to repeat it.** Per the 2026-07-05 correction in the plan: the `$79–$7F`
  box/border tiles are byte-identical between `font_extra.2bpp` and
  `font_battle_extra.2bpp`, so `LoadHpBarAndStatusTilePatterns` rewrites them
  with the same bytes and corrupts nothing; the corruption fires on the *first*
  menu, with no battle needed. The real defect is menu-engine box-draw geometry
  plus the canvas↔window compositor, refiled as ticket **OW-A.13**; the
  compositor half is `docs/current_plan_backlog.md` #14. There is **no stigmergy
  memory `menu-corruption-vram-tileslots`** — that citation was dead; the live
  memory for the neighbouring invariant is `compositor-perf-invariants`.
  (The Pokémon **data/stats** layer — party structs, base stats, `CalcStats`,
  experience/leveling, `AddPartyMon`, learnset/moves, names — is **complete**; its
  plan `docs/plans/pokemon_engine.md` is archived DEAD. The **behavior/UI** layer —
  evolution/`EvolveMon`, `learn_move`, status-screen pages 1&2, post-battle wire —
  is **complete and archived** at `docs/plans/pokemon_behavior.md` (2026-07-04);
  its deferred tails are in `docs/current_plan_backlog.md`: status-screen
  front-pic/cry/STATS-wire is **#12, still open**; Bill's PC full UI is **#11,
  DONE 2026-07-31** — the whole UI is the faithful pret mirror
  `src/engine/pokemon/bills_pc.asm`, linked and driven by the `bills_pc_ops` and
  `box_change_roundtrip` goldens, and the port-only `BillsPC*Logic` fork names
  are deleted.)
- **Party mon icons — COMPLETE & archived** at `docs/plans/party_icons_oam.md`
  (2026-07-12, `f8863164` + `12dfdbe2`). The BG-tile icon hack is gone: icons are OBJ
  through pret's `engine/gfx/mon_icons.asm`, in the party menu and the naming screen.
  Two invariants it left behind, both enforced at the primitive
  (`dos_port/src/home/clear_sprites.asm`, the mirror of pret `home/clear_sprites.asm`
  — it was `dos_port/src/home/sprites.asm` until the s16 relocation repair, a name
  that resolved to nothing on the pret side):
  **`ClearSprites`/`HideSprites` publish `spr_oam_valid = 0`** (the port gates the OAM
  DMA on `wUpdateSpritesEnabled`, so a cleared shadow OAM never reached the compositor
  — that is what would ghost overworld sprites onto a whiteout screen), **and they
  clear `g_obj_over_window`** — the new opt-in flag that gives a screen the GB's
  OBJ-over-window z-order (the port otherwise composites the window layer last, so the
  overworld dialog box occludes NPCs). A screen whose window IS the screen and whose
  OBJ sit on top of it raises it with its window; anything else leaves it alone.
- **Items/bag layer — COMPLETE & archived** at `docs/plans/items.md`
  (2026-08-03). `UseItem_`, `ItemUsePtrTable`, and every item-handler family are
  translated in `src/engine/items/item_effects.asm`; fishing rods were the last
  family (`fe91b329`) and their retirement deleted `item_use_stubs.asm`. Runtime
  tails owned by other systems remain in their plans or backlog, notably the
  in-battle ITEM menu and the Surfboard dismount's simulated-input consumer.
- **Battle-UI layout pipeline — PIPELINE COMPLETE & archived** at
  `docs/plans/battle_ui.md` (2026-07-12, branch `menus-port`). Sessions A1-B5 done:
  `tools/gfx_core/` extracted, every hardcoded battle coordinate migrated into the
  `ui_layout_battle_sidecar.json` -> `assets/ui_layout_battle.inc` pipeline, editor
  hardened. **Session B6 (the human-in-the-loop widescreen redesign) is on the back
  burner at the user's direction** -- it needs a scheduling decision, not
  engineering. Tracked as **#10 in `docs/current_plan_backlog.md`**.
- `docs/current_plan_battle_animations.md` — **in-battle move/item animations**,
  the dedicated detail owner under `battle_completion` Stage 6. **Stages 0-3 are
  DONE** (21 completed / 15 open at 2026-08-08); Stage 4 (mon-pic families) is
  next, then 5 (OAM particle families) and 6 (polish + F-19 evaluation).
  Its durable lessons, all measured:
  * **Geometry INVERTS the transitions precedent.** Battle transitions
    re-parameterized to the full 40x25 canvas and say "do NOT use BCOORD"; here
    BCOORD (+10 col / +3 row) **is** the rule. Watch the `SCREEN_WIDTH` role
    split: as a row-STRIDE it is correct verbatim on both sides (each means "my
    tilemap's stride", 20 there / 40 here), but as a COORDINATE
    (`5 * SCREEN_WIDTH + 1` = tile (1,5)) it must be re-derived through `BCOORD`,
    never textually reused.
  * **On GB the battle screen IS the window layer** (`core.asm` sets `rWY = 0` on
    entry). That is why pret shakes via `rWX`/`rWY` and why `AnimationWavyScreen`
    turns the window off before wobbling `rSCX`. The port draws battle on the BG
    layer, so the equivalent whole-screen displacement is `H_SCX`/`H_SCY` — the
    SHADOWS, because `commit_shadow_regs` overwrites the registers each
    `DelayFrame`.
  * **`rLY`/`rSTAT` are inert in the port**, so a literal per-scanline effect
    HANGS. `AnimationWavyScreen` is realized as a per-row displacement HAL
    (`g_row_xoff` / `g_row_xoff_on`, `src/ppu/ppu.asm`) following the
    `g_obj_clip` ownership model: default is the identity, the animation arms and
    clears it.
  * **A BGP write needs no HAL** — `commit_palette` picks it up from
    `DelayFrame`, so the whole flash/palette family is a literal translation.
- `docs/current_plan_map_tool.md` — **overworld map tool** (viewer → border-ring
  authoring → clamp retirement → block painting), built on `gfx_core`. Needed only
  battle-UI Session A2 (landed 2026-07-02) — **not** blocked by that plan's
  deferral. Sequenced after battle.
- **engine/menus port + UI layout tool** — **COMPLETE & archived** at
  `docs/plans/menus.md` (2026-07-04, branch `menus-port`). All 10 sessions landed
  (layout pipeline/editor, faithful `DisplayTextBoxID_`, generic drivers wired,
  start/bag/party realigned, leaf-screen swarm: PCs/pokédex/naming/options/save/
  link). The "menu boxes corrupt live but fine in harness" issue is filed on the
  archived `docs/plans/overworld_port.md` as ticket **OW-A.13** — but note it is
  **NOT** a VRAM tile-slot defect (that hypothesis was disproven 2026-07-05; see
  the overworld-port entry above). It is menu box-draw geometry plus the
  canvas↔window compositor, which is partly a menu-side bug after all.
  Menu-input lethargy fixed in `JoypadLowSensitivity` (2026-07-04). Other
  tails are tracked in `docs/current_plan_backlog.md`: `LoadPokedexTilePatterns`
  tileset (#13), window-compositor gap (#14), interactive navigation sweeps
  (#15), cable-club warp seam (#17).
- **RGBDS macro port — COMPLETE & archived** at `docs/plans/macros.md`
  (there is no `docs/current_plan_macros.md`; it landed in `a7822644`) — **port
  pret's portable RGBDS macros** to real
  NASM `%macro`s in `dos_port/include/` (coords, event-macro family, data/gfx
  helpers, text-command macros), "add macros only" (no call-site retrofit),
  checkbox-tracked across chunked stages. Excludes redundant-by-design banking
  macros, generator-owned data macros, and engine-blocked audio/gfx-anim/script
  templates. **The coords chunk shipped** — `a7822644` ("Translate RGBDS macros:
  coords, data, events, gfx, text") landed `include/coords.inc`,
  `data_macros.inc`, `events.inc`, `gfx_macros.inc`, `gb_text.inc`; the old
  "Stage 1 done, coords chunk A1 is next" line here was stale. The archived plan
  still carries 16 unchecked boxes against 2 checked, so treat "archived" as
  "stopped", not "every box ticked" — the remaining chunks were dropped, not
  done. Its live caveat: the tilemap stride is context-dependent (global
  `SCREEN_WIDTH=40` vs text.asm's stride-20 / runtime `text_row_stride`), so a
  coords macro is only correct against the stride its call site uses.
- **Battle engine** — the backend plan (`battle_engine`) is **complete** and the
  front-end alignment plan (`battle_pret_alignment`) was **superseded by the battle
  swarm** (Masters A/B/C, archived at `docs/archive/battle_swarm_*`, merged to
  `master`); both plans are archived under `docs/plans/`. A live wild battle plays
  end-to-end (menu, move select, speed-ordered turns, damage, faint, EXP/level-up,
  RUN). **Remaining battle work HAS an active plan again:**
  `docs/current_plan_battle_completion.md` (4 done / 32 open at 2026-08-02) —
  this entry previously asserted "not in a `current_plan_*` file", which is
  false. The older ledger `docs/archive/battle_audit_findings.md` is still there
  for open fidelity findings, but it is **archived and partly stale — verify
  before acting on it.** Two of its Tier-4 claims are measurably wrong:
  trainer-AI move selection is not dead code (`label_status --callers
  AIEnemyTrainerChooseMoves` shows `SelectEnemyMove` calling it from
  `src/engine/battle/core.asm`), and `ReadTrainer` does compute prize money
  (`src/engine/battle/read_trainer_party.asm` calls `AddBCD` directly in place of
  pret's `predef AddBCDPredef`). Prefer the active plan.

(NPC implementation is complete and archived at `docs/plans/npc_implementation.md`.
The move data layer is complete and archived at `docs/plans/moves.md`.)

## Save File Notes (`.dsv` v2 is live; `saveconv.py` is complete)

- GB `.sav`: raw 32 KB SRAM dump (MBC5+RAM+BATTERY)
- DOS `.dsv`: **version 2 is real and shipping** — `src/save/dsv_io.asm` writes
  and reads it. 7-byte header (`DOSV` magic, version byte, 16-bit LE **additive**
  checksum — `sum(payload) & 0xFFFF`, *not* a CRC) + a **32768-byte payload that
  IS the raw SRAM image**, bank 0 first, in the same bank order as a real `.sav`;
  32775 bytes total. The port emulates all four SRAM banks resident in memory
  (bank 0 at `$A000`, banks 1-3 at `$22000`), so the two entry points are
  `SramLoadImage` (POKEMON.DSV → banks, once at boot) and `SramStoreImage`
  (banks → POKEMON.DSV, at each save-commit point). A corrupt or absent file
  leaves the banks untouched, which reads as a fresh cartridge.
- **v1 is retired with no migration path** (five WRAM blocks, 3985 bytes). It
  predates SRAM emulation; a v1 file fails the version check and reads as "no
  save". Do not write a reader for it.
- Converter: `dos_port/tools/saveconv.py` — complete. `--verify`/`--info FILE`
  validates a `.dsv` header + checksum (the same checks `SramLoadImage` makes);
  `--to-dos IN.sav OUT.dsv` and `--to-gb IN.dsv OUT.sav` convert, which under v2
  is a header prepend/strip plus a checksum recompute rather than a WRAM-layout
  translation. The round trip is byte-identical, and `goldencheck.sh` runs
  `--to-dos` on every `save_real_load` run, so a regression fails a golden.
