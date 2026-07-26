# Antigravity Pokemon Yellow DOS Port

**This file is a DIGEST for the Antigravity harness, not the authority.**
`CLAUDE.md` / `AGENTS.md` at the repo root are the full always-in-force rules
(~500 lines each, kept in sync with each other); this is the short form for a
harness that cannot load them. **Where this file and the root docs disagree, the
root docs win and this file is the bug.** Reconciled against them 2026-07-26.

It deliberately does NOT restate: the stigmergy coordination mandate, the Evidence
and Knowledge Policy, the golden-harness workflow, or the per-area skill routing
gate. Read the root docs for those before doing anything non-trivial.

## General Rules & Disciplines

### Preserve Flags (ZF/CF) — x86 ≠ SM83

**Translating a conditional is not just translating the branch — it's preserving
the flag the branch reads.** SM83 and x86 set flags on *different* instructions,
so a faithful-looking translation can silently break a `jr z`/`jr c` by clobbering
the flag between where it's set and where it's tested. This has bitten real
routines (see the `lea esi,[esi+1]`-instead-of-`inc` fix in `pikachu_status.asm`).

- **Identify the exact instruction that sets the flag pret's branch depends on,
  and make sure nothing between it and the branch disturbs that flag.** Map
  `jr z/nz` → `jz/jnz` (ZF), `jr c/nc` → `jb/jae` (CF, unsigned) — but only after
  confirming the flag still holds at the branch.
- **`inc`/`dec` preserve CF but modify ZF/SF/OF/AF/PF.** So an `inc de`/`dec hl`
  that pret places between a `sub` and an `sbc` (borrow chain) is safe in x86
  too — CF survives. But an `inc`/`dec` between a `cp`/`or`/`and` and a `jr z`
  **destroys ZF** — pret's `inc hl` after a compare was flag-neutral on SM83 in
  that spot only because SM83's `ld`/`inc [hl]` differ; re-check each case.
- **`mov`, `lea`, `movzx`, `push`/`pop` do NOT touch flags** — use `lea
  esi,[esi+1]` instead of `inc esi`, or reorder, when you must advance a pointer
  without disturbing a live ZF/CF.
- **`test`/`cmp`/`and`/`or`/`add`/`sub`/`shl`/`shr` all set flags** — never place
  one of these between a flag producer and its consumer unless it *is* the
  producer.
- SM83 `F: N`/`H` are tracked separately (`[hf_shadow]`, lazy); most routines
  don't touch them, but DAA/CPL paths do. (The full SM83->x86 register table is in
  the `asm-translation` skill — it is NOT in this file, despite what this line used
  to say by pointing "above" at a table that was never copied across.)
- Related: multi-byte GB values are **big-endian** — see "Data Endianness" below.

### Data Endianness (preserve pret byte order)

**GB game data is big-endian; keep it that way.** The SM83 stores multi-byte
game values **high byte first** (big-endian): mon HP, MaxHP, the five stats,
OT ID, EXP, and every other multi-byte field in the party/box/`wLoadedMon`
structs. This is load-bearing for pret cross-reference *and* for the Gen-2
byte-identical-struct rule — **do not** re-store any GB value in x86-native
little-endian order.

- **Reading a multi-byte GB value:** treat `[EBP+addr]` as big-endian
  (`hi = [addr]`, `lo = [addr+1]`), exactly as the pret routine does. Do not
  assume x86 little-endian just because the host is.
- **Home/shared routines must match pret's byte order.** `PrintNumber`
  (`home/print_num.asm`) reads its source **big-endian** — the first byte at
  `DE` is most-significant (pret loads it into the high slot of `hNumToPrint`).
  A prior port revision read it little-endian; that was a latent divergence
  (harmless only because every caller so far passed 1-byte values) and is now
  fixed. When you translate any routine that consumes a multi-byte value,
  verify the endianness against the pret source rather than the x86 default.
- **Flags caveat that often rides along:** SM83 16-bit math builds values
  hi-then-lo; when porting a borrow/carry chain (`sub`/`sbc`) that walks such a
  value, remember `inc`/`dec` on the pointer preserve CF (unlike some other x86
  ops), so the borrow survives the pointer step — but a `cmp`/`add`/`sub`/`test`
  between the halves will clobber it.

### Other Hard Conventions

- **Preserve pret Labels.** Keep pret label names exactly as they are in the SM83 disassembly. Add aliases alongside if necessary, but never replace.
- **Data vs. Code (Two-tier rule).** Generators write only `assets/*.inc` (Tier 1 data). Human-owned behavior goes in `.asm` (Tier 2 code). Never hand-encode charmap strings in `.asm`—always use Python generators.
- **Stub Conventions.** Put stubs in subsystem `*_stubs.asm` files, never in the source-mirror file. When a real routine lands, delete the stub.
- **Structured annotations — MACHINE-PARSED, and the old free-form style is now a
  regression.** Exactly four kinds: `DEVIATION` / `BUG` / `GLITCH` / `STUB`, each
  written as
  `; KIND{class=…; pret=<file>:<Label>; behavior=…; evidence=…; lifetime=…}`
  (`GLITCH` also needs `safety=`; `STUB` also needs `label=` and `class` must be
  `stub` or `temporary`). `class` must be one of HAL / banking / projection /
  data-model / timing / stub / temporary, and **no `;` or `}` may appear inside a
  value** — the parser splits on `;`. `tools/lint_pret_labels` fails the gate on a
  malformed one. Bugs still pair the annotation with a
  `%if BUG_FIX_LEVEL >= N` block preserving the original behavior in `%else`.
  This line previously said "document glitches with `GLITCH:` safety comments" —
  that free-form style is the dead legacy format; writing one now is a regression
  that `lint_pret_labels --strict-claims` reports.
- **Mirror rule: NEW RELOCATIONS ARE NOT ALLOWED.** A routine with a pret
  counterpart puts its complete body and every pret entry point in
  `dos_port/src/<pret path>`. Cohesion arguments never override it. Never add or
  expand `tools/pret_label_allowlist.json` to make your own work pass — it is a
  legacy-debt inventory, hash-locked outside the worktree.
- **VRAM tile writes must invalidate the decode cache.** The compositor draws from
  `tile_cache`, never from VRAM. Route tile writes through `CopyVideoData` (which
  arms the flag) or set `mov byte [g_tilecache_dirty], 1` yourself. A raw `rep movs`
  into vChars that does neither is visible corruption — and OBJ/sprite tiles are
  NOT exempt.
- **Known regressions are QUERIED, never logged.** There is no regressions log and
  one must not be created: the site carries the machine-parsed annotation, and
  stigmergy holds `regression-<area>-<slug>` memories. Search before working an area.
- **Two automated gates.** `tools/static_gate` is a whole-tree ratchet run by
  `.githooks/pre-commit` on every commit that stages anything under `dos_port/`;
  `tools/fidelity_gate` is the per-change/per-label chain and carries the
  relocation move battery (`--move-baseline` / `--move-verify`). Neither says
  anything about behaviour — the golden suite is separate.
- **Hardware I/O Boundary.** Do not translate GB I/O register accesses (`$FF__`) directly. Emit `; TODO-HW:` comments instead. Escalation may be required.
- **Gen 2 Compatibility.** Keep Pokémon party/box data structures byte-identical to Gen 1. Never shrink or repurpose bytes (especially offset 7, the catch rate byte).
- **Commit Policy.** Stage only files changed by the current work unit (`git add <exact files>`). No `git add -A` for unrelated changes. Never skip pre-commit hooks (`--no-verify`).
- **Debugging.** Do not debug by staring at the screen. Use memory dumps (`DUMP.BIN`) or back-buffer dumps (`FRAME.BIN`) for ground truth.

## Current Plans Workflow

Active multi-step implementation plans live as `docs/current_plan_<topic>.md`.
- Always scan `docs/current_plan_*.md` at the start of a session or task to see open work items.
- Check off stages `[x]` as they complete.
- When a plan is fully complete, archive it to `docs/plans/<topic>.md`.

**Do not keep a plan list here.** This file used to carry one, and four of its six
entries named files that do not exist (`script_engine` deleted outright;
`overworld_port`, `party_icons_oam` and `macros` archived to `docs/plans/`), while
omitting seven plans that do exist. Get the live inventory from the generator,
which reads the tree and cannot drift:

```
dos_port/tools/project_state --plans
```

Per-plan narrative (purpose, lessons, deferred tails) is in the
`project-conventions` skill; completed plans are under `docs/plans/`.

## Swarm Workflow

If you need to perform bulk translation of `simple`-category functions, please activate the swarm skill:
`agy skill pokeyellow-swarm`
This skill will load the full swarm coordinator role, agent definitions, and swarm-specific guidelines.
