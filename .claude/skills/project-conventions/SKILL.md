---
name: project-conventions
description: >
  Detailed project conventions for the Pokémon Yellow DOS port. Invoke when
  adding a link-time stub, deciding whether something is generated data vs.
  hand-written code (the two-tier rule, incl. the "text strings are DATA, never
  hand-encode charmap bytes" rule), writing a BUG_FIX_LEVEL / GLITCH guard, or
  creating/archiving an active-plan file; also holds the save-file format notes.
  Triggers: "add a stub / *_stubs.asm", "BUG_FIX_LEVEL", "GLITCH tag",
  "should this be a generator or code", "gen_*.py / assets/*.inc",
  "hand-encode a string / charmap db", "current_plan_*.md", "archive a plan",
  ".sav / .dsv save format".
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
only, `2` = all; the Makefile passes `-D BUG_FIX_LEVEL=$(BUG_FIX_LEVEL)` (default 0).
Note: `BUG_FIX_LEVEL` is a compile-time Makefile flag; the old runtime `/FIXCRIT|/FIXALL`
flags were removed on 2026-08-16. Bare `nasm` runs without `-D BUG_FIX_LEVEL=` will fail
on the `%if`.

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

Re-measured: `--strict-claims` reports **zero** `legacy_annotation`
(also zero `hand_encoded_text` / `local_shadow` / `stale_provider`).
All 14 `*_stubs.asm` files are retired (`STUB{}` annotation count is 0).

**A live worked example of why `--strict-claims` matters, from 2026-08-08.** A
comment reading `; DEVIATION on AnimationWavyScreen in engine/battle/...` — a
plain PROSE CROSS-REFERENCE with no `{}` — was flagged as `legacy_annotation`,
correctly. A line that merely *mentions* an annotation kind in the annotation
position parses as a malformed one. If you want to point at an annotation from
elsewhere, write e.g. `see DEVIATION{} block above` or `the AnimationWavyScreen
deviation`, never the bare name in the comment position.

---

## Stub Conventions (all stubs live in a subsystem `*_stubs.asm`)

All 14 legacy `*_stubs.asm` files have been deleted/retired (`STUB{}` count is 0).
If temporary stubs are ever needed during future subsystem work, follow these rules:

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
2. **`.asm` is never *regenerated*.** Every move/item-specific decision,
   `BUG`/`GLITCH` guard, and quirk lives there, and nothing in `make assets` may
   overwrite it.

   **There is a third category, and it is `.asm` that a tool authored once.** A
   one-shot migration tool (e.g. the SM83→x86 script transpiler,
   `dos_port/tools/sm83xlat/`) may *seed* `.asm` files, which are then committed
   and become **human-owned exactly like any other Tier 2 file**. The
   distinguishing property is not who typed the first draft — it is who owns it
   afterwards:

   | tier | example | ownership |
   |---|---|---|
   | 1, machine-owned | `assets/*.inc` | regenerated by `make assets`; holds zero hand-authored information |
   | 2, human-owned | most `.asm` | hand-written, hand-maintained |
   | 2, tool-seeded once | `src/scripts/*.asm` | tool ran once at a recorded SHA; hand-maintained ever after |

   Rules for a tool-seeded file: the tool stays **out of `make assets`** and out of
   `tools/generators/` (everything there is re-run with gitignored outputs, so
   filing it there invites someone to regenerate over hand edits); it records its
   run SHA in its own `README.md`; and **hand-editing the output is the normal way
   it changes**. Do not add a `DO NOT EDIT` header — that would be exactly wrong.
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
   `aux_misplaced` rule wants a pret `data/` label at exactly that mirrored path
   (or inside a generated `assets/*.inc`, whose placement is its carrier's). A
   hand-written table at the mirrored data-layer path satisfies both — being
   hand-written says nothing about where it lives. It moved into the data layer
   in `a3804828` and to its mirrored path in the 2026-08-16 pass
   (`docs/plans/data_path_mirror.md`); the older wording here, that the rule
   "asks only that the label live under `dos_port/src/data/`", is retired;
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

**Active Plans & Backlog — Get the live list from the generator:**

```
dos_port/tools/project_state --plans
```

That is the authority on which plans exist and how many stages each has open; it cannot drift because it reads the tree. Do not maintain a hand-written inventory in documentation or skills.

- **Generator caveat:** The tool counts only checkbox lines (`- [ ]` and the backtick form `` - `[ ]` ``), so a plan written as prose or numbered headings reports `0 completed / 0 open` regardless of its real state. **"0/0" means "unparsed", not "empty"** — inspect the file directly.
- **Backlog:** Deferred tails are tracked in `docs/current_plan_backlog.md`. Grep that file before assuming a deferred item or tail is untracked.
- **Archived plans:** Completed and historical plans reside in `docs/plans/` (read-only reference; do not edit files in `docs/plans/`).

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
