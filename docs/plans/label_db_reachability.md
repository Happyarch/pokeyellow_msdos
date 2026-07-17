# Plan (archived): label-DB reachability — %ifdef-aware scan + fall-through edges

**Status: COMPLETE & archived** (2026-07-16). Implemented and landed over rounds
7–8; round 8's live defect (A7) is fixed, and round-8 open hole 2 (conditional
structure in a macro body) is closed by a hard-fail — the tool now refuses that
tail instead of guessing `returns=True`. Gate: `python3
dos_port/tools/test_label_db.py` — **75 fixtures**, green. The remaining
documented holes (round-8 open hole 1 and the smaller latent ones) carry
forward as a TODO.md backlog entry so they outlive this file; **hole 1 is
accepted, not scheduled** — a sound fix needs real basic-block reachability
analysis and there is no instance in the tree. The `reachability` column's
permanent limits (dd-tables, ISRs; `not-proven-reached` is never proof of
unreachability) live in CLAUDE.md/AGENTS.md and the stigmergy memory
`project-state-reachability-false-negative-overworld-menu-subtree`.

**Status:** round 8 — **ADVERSARIALLY REVIEWED** (2026-07-16). All
V1–V8 pass (**72 fixtures**). The round-7 amendments got the second-agent read
they were waiting for: four independent reviewers with fresh context, each told
to **refute** rather than check. **A1 survived; A5/A6 did not survive intact** —
one **live wrong answer** (A7, dropped a real edge under `make DEBUG_ASSERTIONS=1`)
and two latent false-edge generators (A8, A9) were found, fixed, and fixtured
(which is why the plan stayed active past round 7). Amendment 4's headline number is also wrong in the way
this plan was written to catch: **the tool does not report 1051, it reports 742**
(A10). See "Round 8 — independent adversarial review".

**Result the round exists to record:** round 7 closed by saying self-review
converges on the author's blind spot and an adversary with the tree does not.
That was tested, and it reproduced exactly. Every round-8 defect lives in a rule
an author-run audit had to *assume* to run at all — and the author's round-7
sweep across 17 configs, which reported "all 137 edges, zero delta", never ran
the one config (`DEBUG_ASSERTIONS=1`) where the model gives a wrong answer.

**Status:** round 7 — implemented and landed (superseded by round 8 above; kept
for the record). All V1–V8 passed (67 fixtures). One normative amendment was
forced by the tree during implementation (S6's DOS-exit rule is decided by the
callee's material TAIL, not by "contains the idiom anywhere" — the
anywhere-reading hard-fails the shipping tree and deletes the boot-chain edge V2
mandates). Round-7 review then found and fixed a **real false-edge defect in the
shipping graph** (Amendment 5: AH=4Ch terminates with any exit code) that the
author's own three audits had passed. See "Round 7 — implementation + review".

**Status before implementation:** round 6 — **adversarial review converged; implementation-ready v1**
(round 5 = codex sign-off; round 6 = post-signoff self-review, three small
amendments — codex root inactive, standing invitation to object recorded in
the round-6 section). The "Normative
specification (v1)" section below is the ONLY normative text; everything under
"Review history" is a record of how it got that way and must not be implemented
from. All measurements verified against the live `translation.db` / tree at
`afd80623` on 2026-07-16; Makefile facts re-verified in round 4.

> **Review protocol.** Authored by Claude Code (`r-55620c9331a3`), adversarially
> reviewed by the codex root (`r-d27268021560`) in alternating rounds: claim the
> file, apply comments/changes in place, release the claim, mail it back on
> thread 14. Mark edits so authorship stays legible — `> **codex:**` /
> `> **claude:**` for comments. Rounds 1–3 interleaved comments into the draft-1
> body; round 4 consolidated per codex's round-3 editorial blocker, so codex's
> inline comments on superseded text now live in the "Resolved inline-comment
> ledger", each mapped to the v1 section that resolves it.

**Nothing is implemented yet.** No tool changes, no `update_label_db` edits, no
regen. Implementation begins only after the review converges.

> **codex (round 5, final):** The boundary model and V7 survive. S2 needs one
> final correction before sign-off: removing non-member explicit edges from the
> shared `calls` table would delete 302 current port-call rows across 14 files and
> break `label_status --callers`, whose documented contract is “every PORT routine
> calling `<Label>`” and whose project role is stub-retirement auditing. The
> normative amendments below preserve that source inventory and mark the subset
> eligible for the default build graph. Two smaller refuse-to-guess clarifications
> cover NASM include search paths and non-byte macros at a boundary.

---

# Normative specification (v1)

## Posture — the governing rule

**The tool must refuse to guess.** Its output is sanctioned evidence
(`CLAUDE.md:68-70` directs agents to cite it), and it has already misled at
least two sessions. Wherever the analysis cannot prove something that affects
the graph, it **fails loudly naming file:line** — never assumes, never biases,
never warns-and-continues. Every hard-fail in this spec is a feature: each one
is a place where draft 1 would have silently emitted a wrong number.

## Context (verified facts)

`dos_port/tools/project_state` reports a `reachability` column per pret label.
**It is wrong in both directions**, and `CLAUDE.md:68-70` points agents straight
at it as the sanctioned source for `unreachable`/`no caller` claims. It has been
cited as proof at least twice (the Stage 4 boulder handoff on
`PrintStrengthText`; `docs/translation_log.md:5615`). Found during the
overworld-events Stage 4 Cut bullet (`8d987608`, `afd80623`).

**Root cause.** `project_state:111` BFSes from the single root `start` over
`calls` edges; those edges come from `update_label_db:121`'s `PORT_CALL_RE`,
which matches **only** explicit `call`/`jmp`/`j??` mnemonics with a label
operand.

**Bug 1 — false negatives (fall-through).** Execution crossing a label boundary
sequentially emits no mnemonic, so no edge exists. The boot chain into the
entire game world is exactly that shape:

```
start --call--> Init --jmp--> EnterMapBoot --FALL--> EnterMap --FALL--> OverworldLoop --FALL--> OverworldLoopLessDelay
```

(`overworld.asm:427` `; fall into EnterMap`, `:939`, `:969`.)

| graph | reachable |
|---|---|
| today (explicit edges only) | 385 |
| + `EnterMapBoot -> EnterMap` (ONE edge) | 948 |
| + `EnterMap -> OverworldLoop` | 966 |
| + `OverworldLoop -> OverworldLoopLessDelay` | 1046 |

⚠️ **Population caveat (Amendment 10, round 8).** This column counts **BFS graph
nodes** — not what `project_state` reports. It reports per *pret label* and also
applies the `linked` provider filter; of these 385 nodes only **181** are pret
labels (111 are not in `labels` at all). The rows reproduce **only against the
post-change DB** with no `build_active` filter (which is the original method: the
old scanner had no such column). Same shape, different population — do not quote
these as tool output.

**Three missing edges dark 661 labels**, of ~1720 port defs (~63%). The port
falls through pervasively (~857 apparent sites, ~40% of 2147 top-level labels)
**because pret does** — preserving pret control flow is a project hard rule, so
the metric under-reports precisely where the port is most faithful.

**Bug 2 — false positives (unparsed NASM conditionals).** `entry.asm:109-118`
has `call RunAudioTest` / `RunCalcStatsTest` / `RunPartySeedTest`, each inside
`%ifdef DEBUG_*`, none in the default build — all recorded as real edges from
`start`. The scanner skips the `%ifdef` *line* (it matches `DIRECTIVE_RE`'s
`%\w+`) but not the inactive *body*.

**Bug 3 — false positives (unparsed Make conditionals; codex round-1 D1).**
`project_state.source_sets()` regexes `GAME_SRCS +=`-style assignments without
evaluating the surrounding Make `ifdef`. `src/debug/debug_dump.asm`
(`Makefile:1055`, guarded by `ifdef NEED_DEBUG_DUMP` at `:1054-1056`) and
`src/debug/perf.asm` (`:1064-1069`, `ifdef DEBUG_PERF`) are reported **linked
in the default build**. They are not. The real link set is `LINK_SRCS`
(`Makefile:1180`); `ALL_SRCS` (`:1292`) additionally holds check-only sources
(`BATTLE_SRCS` is deliberately not linked, `:1078-1081`).

`docs/plans/operational_reliability.md:491-492` — the original design — said
unreached paths *"remain `not-statically-reached`, never asserted
unreachable"*. The scanner met its spec; the value name invited the misreading.
Hence the rename (S9).

## Scope

**IN**
1. Build-config resolution by **asking GNU Make itself** (S1): resolved
   `LINK_SRCS` membership + resolved `NASMFLAGS` define seed, scrubbed
   environment, one override surface for alternate configs.
2. NASM conditional evaluation over member files (S3), single-pass into an
   immutable classified stream; refuse-to-guess on unknowns (S4).
3. Fall-through edges (`kind='fallthrough'`) via the per-output-section
   boundary model (S5).
4. Terminator classification incl. the direct DOS-exit rule, the explicit
   calls-return axiom, and its single hard-fail exception (S6).
5. Rename of the reachability values + citation sweep (S9).

**OUT — documented gaps, do not implement in v1**
- `dd Label` dispatch-table edges and address-taken operands (`mov esi, Table`).
  Leaves `PickUpItemText`, `PalletTown_ScriptPointers`, `ItemUsePtrTable`,
  `OptionMenuJumpTable`, `HiddenEventMaps` handlers dark. The same gap covers
  **interrupt handlers installed by address** — the PIT and keyboard ISRs
  (`boot/timing.asm:176`, `src/input/joypad.asm:313`, the tree's only two `iret`
  sites) are provably live yet permanently `not-proven-reached` under v1. Must
  be stated in the tool's `--help`/docstring and in the rename note.
- Graph/body content inside `%include`d files and `%macro` expansions (includes
  and macros ARE consulted for conditional state and byte-emission
  classification — S3/S5 — just not for labels/calls they may contain).
- Provider-qualified BFS nodes (round-2 R5): name-level overapproximation is
  retained and the rename (S9) is scoped to what name-level proves.
- No-return **propagation** (round-2 R2): deleted, not deferred — see S6.
- Committed-DB output for alternate configs: `--config` runs are report-only
  (S2).

## Design

All line numbers are `dos_port/tools/update_label_db` unless noted.

### S1. Build-config resolution — ask GNU Make, never parse it

*(Replaces both draft-1 ideas: the hardcoded `DEFAULT_DEFINES` seed and the
"extend the regex Makefile parser" plan. Codex round 3: a second partial Make
evaluator is the same class of bug as the NASM one being fixed.)*

- Run a **read-only probe** that has GNU Make itself resolve and print
  `LINK_SRCS`, `ALL_SRCS`, and `NASMFLAGS`: `make -C dos_port -s` with an
  `--eval`-injected print target (no build, no side effects).
- Transport the resolved variables **without a shell re-parsing their contents**.
  In particular, `printf "$(NASMFLAGS)"` strips the nested quoting from
  `PLAYER_NAME="'NINTEN'"`/`RIVAL_NAME="'SONY'"`. An `--eval` that exports the
  three resolved Make variables to a fixed helper process (which emits JSON or
  another length-safe format) preserves the exact value; assert the quoted name
  define round-trips in the probe fixture.
- Run it under a **scrubbed environment** (`env -i` with a minimal `PATH`) so
  ambient `DEBUG_*` variables or `MAKEFLAGS` cannot alter the shipping result.
- Parse the define seed from the resolved `NASMFLAGS` `-D NAME[=VAL]` tokens —
  including the `$(shell python3 …)`-computed `PIT_DIVISOR` and quoted values
  (`PLAYER_NAME="'…'"`), which is exactly what made hand-parsing a net loss.
  A valueless `-D NAME` seeds the NASM-truthy value `1` (codex round-2 note).
- Parse the resolved `-I` arguments too and use them in NASM search order for
  S3's in-place include resolution. The tree uses both `%include
  "gb_memmap.inc"` (found through `-I include/`) and `%include
  "assets/scenario_registry.inc"` (found through `-I .`); inventing a different
  resolver would make conditional state configuration-dependent again.
- **Probe failure, a missing variable, or an unparsable `-D` token is a hard
  error.** If the Makefile refactors its variable names, the tool must break
  loudly, not drift.

**Alternate configs — one override surface.** The CLI takes repeatable
`--config VAR[=VAL]` flags, passed verbatim as command-line variable overrides
to the *same Make probe*. Membership and defines are then both derived from the
probe output, so they **cannot diverge by construction** — `--config
DEBUG_PARTY=1` flips `NEED_DEBUG_DUMP` → `debug_dump.asm` into `GAME_SRCS` →
`LINK_SRCS` (`Makefile:565-569`, `:1054-1056`) *and* adds `-D DEBUG_PARTY
-D SKIP_TITLE`, from one source of truth. The draft-1 raw NASM-side
`--define`/`--undefine` flags are **withdrawn**: a NASM-only define with
unchanged membership is precisely the divergence codex flagged.

### S2. Membership discipline — who gets classified, who gets edges

- **Definitions are config-independent source facts.** Label discovery
  (`label_lines`, `toplevel_at`, `globals_here`) and `body_metrics`
  (`:231-245`, feeding `status`/`instr_count`/`has_call`) stay **unfiltered**
  and run over **all** scanned files, exactly as today. A label inside
  `%ifdef DEBUG_OAK_INTRO` is ported; dropping it would flip `status` to
  `missing` and manufacture the very error class this change kills.
  (Measured: 56 top-level labels are defined inside `%if*` blocks; **0 are pret
  labels**.)
- **Edges are build facts.** Conditional classification, boundary analysis, and
  **build-edge qualification** (explicit *and* fallthrough) runs **only over
  `LINK_SRCS` member files** of the analyzed config. This is also what contains
  the hard-fail surface: an
  unevaluable conditional in a file the build never assembles (e.g.
  `debug_dump.asm:262` in the default config) cannot abort the default
  analysis, mirroring NASM, which never evaluates it either.
- **The source-wide explicit-call inventory is preserved.** Continue recording
  every textual port `call`/`jmp`/`jcc` from every scanned file as today, because
  `label_status --callers` is the stub-retirement checklist and promises every
  port caller, including check-only providers. Add a generated `build_active`
  flag to port `calls` rows: `1` only for an active line in a `LINK_SRCS` member
  under the default config, otherwise `0`. Default fallthrough rows exist only
  where S5 proves them and carry `build_active=1`. `project_state` consumes only
  `side='port' AND build_active=1`; `label_status` and source-structure lint keep
  the complete inventory. This is a regenerated-schema extension, not a
  hand-migrated database.
- **The committed `translation.db` always holds the default shipping graph.**
  `--config` runs are ephemeral/report-only and never write the committed DB.
- `project_state.source_sets()` is replaced by (or backed by) the same probe,
  fixing Bug 3 for the `linked` column too. Implement the probe once, shared.

### S3. Per-file classification — ONE pass into an immutable stream

`classify_file(path, seed_defines)` walks each member file exactly once
(after `strip_comment`) and produces an **immutable classified token stream**;
every downstream consumer (edge emission, boundary analysis, diagnostics) reads
that stream. Two consumers replaying a mutable dict is a real bug (round-2 R8):
the second pass would start from the first's final define state, and a
per-label tail scan cannot start mid-file without replaying preceding state.

- **Conditional grammar:** `%ifdef`/`%ifndef`/`%if`/`%elif`/`%elifdef`/
  `%elifndef`/`%else`/`%endif`. The stack must stay balanced through
  *inactive* blocks (they are parsed for nesting, not evaluated — NASM
  semantics). Conditions are evaluated only where the enclosing context is
  active.
- **Expression support** (surveyed: 243 `%ifdef`, 306 `%ifndef`, 36 `%if`):
  defined-ness, integer literals incl. `0x`, binary ops `= == != < <= > >=`,
  bare truthiness. Anything else → **unknown** (S4). No general evaluator.
- **`%define`/`%undef` mutate per-file define state only when their containing
  branch is active.** Per-file scope is correct: each `.asm` is a separate
  `nasm` invocation (one Makefile rule per object). The
  `%ifndef X / %define X / %endif` constant-guard idiom (`perf.asm:38-45`
  feeding `perf.asm:181`) depends on this.
- **`%include` of repository files is processed IN PLACE with the live
  conditional state, for conditional-state resolution only** (`%define`,
  `%undef`, `equ`). Codex round 3: bulk-harvesting equates is wrong — the
  generated `assets/scenario_registry.inc` assigns `GBSTATE_SCENARIO` in ~20
  mutually exclusive `%ifdef`/`%elifdef` arms, and last-textual-wins would
  break alternate configs. Traversal is limited to repository paths,
  cycle-guarded, and applies only active mutations. Labels/calls/bytes inside
  includes remain outside the graph (Scope OUT) — the non-goal is *narrowed*
  from "includes are not followed" to "includes are not followed for
  graph/body content".
- **`%macro` … `%endmacro` definition bodies are skipped** for
  classification-state purposes (NASM evaluates a macro body's conditionals at
  expansion, not definition). Macro-generated calls are invisible —
  documented (Scope OUT). Macro *definitions* are separately scanned for the
  byte-emission registry (S5).
- **Lexing strips an optional leading label — local or top-level — and keeps
  the same-line instruction** (`.done: clc` forms; measured **31** in-tree,
  mostly `fly_warp` macro rows — the corrected count codex accepted in
  round 3).

### S4. Unknown conditions — hard fail on any content

If an `%if`-family condition in an **active context** of a **member file**
cannot be evaluated, the region it controls (all arms) is **unknown**, and the
tool **hard-fails naming file:line** if that region contains **any
non-preprocessor source token or any define mutation** (`%define`, `%undef`,
`%assign`, `equ`). Codex round 3 is adopted verbatim: do not enumerate
"graph-relevant" token kinds — `%if UNKNOWN / ret / %endif` changes
fall-through while containing no label, call, section, or byte directive, and a
define mutation can control a later condition outside the region.

The **only** permitted unknown-region content: `%error`/`%fatal` assertion
lines, blank lines, comments, and nested preprocessor conditionals whose
content satisfies the same rule. A fixture proves the error fires; the live
default tree must not fire it (Verification V3). The two known unevaluable
forms are both outside the fail surface — `%if ($ - %%name) > GBSTATE_NAME_LEN`
(`debug_dump.asm:410`) sits in a skipped macro body, and
`%if _MEPT_ENTRIES != 86` (`effects.asm:270`) is in a default `LINK_SRCS`
member but guards only a pure `%fatal` assertion — the permitted exception.
Both shapes are now **checked**, not assumed.

### S5. Entries, kinds, and boundaries — per-output-section streams

*(Codex round 3, adopted as the replacement for round-2 R3's "body emits any
bytes → data node", which misclassified `OptionsMenu_TextSpeed`
(`options.asm:167`, local `.Strings` `dd` at `:206`), `StartMenu_Pokemon`
(`start_sub_menus.asm:225`, local dispatch table at `:342`),
`DisplayNamingScreen` (`naming_screen.asm:315`, table at `:558`), and
`PlacePicSlide` (`pics.asm:825` `ret`, then a trailing `section .data`/`align`
slice). Data is a **boundary property**, not an anywhere-in-body node
property.)*

1. **Streams.** Map each `section` directive to a linker output-section class
   from `link.ld:20-47` (executable `.text` class vs data classes
   `.data`/`.rodata`/`.bss`; `DATA_SECTIONS:131` is the existing seed).
   Maintain one ordered stream of active material tokens per class per file. A
   source detour through `section .data` is **absent from the `.text`
   stream** — it is never a code/data boundary and never raises. Because
   classification (S3) runs before `SECTION_RE`, an inactive block's `section`
   toggles never touch the current section — matching NASM
   (`overworld.asm:2499-2504`'s guarded `.data`/`.text` flip needs no special
   case). This ordering is load-bearing.
2. **Entries.** An entry is an **active top-level label occurrence**
   `(file, line, name, section-class)` — occurrence-keyed, never name-keyed
   (round-2 R7: `debug_dump.asm` defines `windows:` repeatedly in mutually
   exclusive branches; name-keyed maps overwrite one occurrence with another).
3. **Entry kind from the first material token.** Instruction → **code**;
   byte-emitting directive (`db`/`dw`/`dd`/`dq`/`incbin`/`times`/`resb…`/
   `align`) or byte-emitting macro → **data**. Consecutive zero-byte labels
   (measured: 232 pure-alias sites) inherit the kind of the next material
   token, so aliases of data never masquerade as code. A code alias emits a
   trivial fallthrough edge to the next entry so the whole chain reaches.
4. **Byte-emitting macros — derived, complete, checked.** Classify every
   `%macro` defined in repository sources/includes by whether its body
   (transitively, through nested macro invocations) emits bytes. This covers
   `text_far`, `fly_warp`, `dbw`, `dwb`, `dn`, `dc`, `dba`, `dab`, `bigdw`,
   `dname`, `tmhm`, `dbsprite`, `dbmapcoord`, `event_displacement`, the text-
   command family, and anything added later — no hand list, no ellipsis. **An
   invocation of an unclassifiable or unknown macro at a boundary decision
   point (entry-kind position, or in the material tail) is a hard error**:
   treating it as an ordinary instruction can recreate the false edge.
   A known **non-byte** macro in the material tail also needs a boundary summary:
   it must be proven to return control to the following token. If its expansion
   may terminate/jump out, or that property cannot be derived transitively, hard-
   fail at the boundary. Byte/non-byte classification alone is insufficient — a
   macro expanding to `ret` or an external `jmp` would otherwise manufacture a
   fallthrough edge. Macro-generated call edges remain OUT as documented; the
   calls-return axiom makes such a call compatible with a proven-fallthrough
   summary, while the missing callee edge remains a conservative false negative.
5. **Tail classification at the boundary.** For each code entry `E`, let `M` be
   the next active entry in the same stream (same file), and inspect `E`'s
   slice of material tokens:
   - Let `I` = the **last instruction token** in the slice.
   - `I` terminal (S6) → **no edge**. Material tokens after `I`
     (local tables, `align` padding) are unreachable-and-legal data after a
     proven terminator; they must **not** reclassify the routine. This is the
     `OptionsMenu_TextSpeed`/`PlacePicSlide` shape.
   - `I` non-terminal and `M` is a **code** entry with no intervening material
     tokens after `I` → emit `fallthrough` edge `E → M` (occurrence-level).
   - `I` non-terminal and followed by **data/padding tokens** in the same
     executable stream → **hard error** (execution runs into bytes: a real
     port bug or a tool misclassification — both want a human). Codex's
     round-3 answer to the round-2 open question: **RAISE, never silently
     drop**, with the same-byte-stream qualification load-bearing.
   - `I` non-terminal and `E` is the **last entry in the file's executable
     stream** → **hard error** (cross-file fall-through; round-2 R10). Link
     order is not modeled; if this ever fires, link order genuinely matters
     and that is a finding, not a footnote.

### S6. Terminators, the calls-return axiom, and its one exception

A tail instruction `I` is **terminal** iff it is one of:

| form | note |
|---|---|
| `ret` / `retn` / `retf` | the common case |
| `jmp <label>` | ~1300 sites, e.g. `cut.asm:209` |
| `jmp <reg>` | the SM83 `jp hl` idiom; terminator, yields no edge |
| `jmp [<mem>]` | indexed dispatch; terminator, no edge (the dd-table OUT gap) |
| `iret` | ISR glue only |
| `int 0x21` immediately preceded by `mov ax, 0x4C00` | DOS terminate (`debug_dump.asm:1848`); tested over the last two **counted instruction tokens**, never raw lines |

A **bare `int 0x21` is NOT a terminator** (ordinary DOS/DPMI call,
`audio_hal.asm:177`). `hlt` never occurs in this tree. Anything else — `mov`,
`call`, a *conditional* `jcc` — is non-terminal.

**The calls-return axiom, stated rather than assumed:** the analysis treats
every `call` as returning. This is the same assumption already implicit in
every explicit edge (the graph is label-granularity and flow-insensitive
within a body), and it is part of what "statically-" in the renamed value
means.

**The one exception — DOS-exit callees (replaces no-return propagation).**
No-return *propagation* is **deleted, not fixed** (round-2 R2, accepted by
codex round 3): a tail instruction cannot prove a routine never returns, and in
the default build every DOS-exit call site is inside `%ifdef DEBUG_*`/
non-member files, so propagation was dead code for the shipping graph. What
remains:

- The **direct rule** (sound, local): a label whose own material tail is the
  `mov ax,0x4C00` / `int 0x21` pair terminates.
- The **hard-fail rule** (codex round 3, adopted — a knowingly spurious edge in
  an advertised config violates the refuse-to-guess contract): at a boundary
  whose material tail is `call X`, if `X`'s **own active material tail** in the
  analyzed config **is** the DOS-exit idiom, `X`'s return behavior is unproved
  (an earlier path may return, and a tail cannot prove otherwise — codex round-1
  D6, converted from an assumption into a refusal) → **hard error naming the
  site**. It fires on `DumpBackbuffer` (`debug_dump.asm:1848`) and
  `DebugDumpMemory` (`:1672`), whose tails are the idiom, converting the
  formerly "documented" false edge into a loud refusal. Note `DumpSeamLog` is
  NOT in this class — it ends in `ret` (`debug_dump.asm:2243`; call sites say
  `; SEAMLOG.BIN (returns)`), which is exactly why the withdrawn
  hardcoded-list fallback would have baked in a wrong answer.
  **(Round-7 amendment — see below. Rounds 3–5 wrote "contains the DOS-exit
  idiom anywhere" and asserted it "never fires in the default config". Both are
  false against the tree, and the anywhere-reading deletes the boot-chain edge
  V2 mandates.)**

### S7. Definitions vs occurrences vs edges (the three-concept split)

- A **definition** is a config-independent source fact → `status`,
  `instr_count`, `has_call`. Unfiltered (S2). Any `body_metrics` extension is
  **additive** — append return values, never reorder — since
  `lint_pret_labels`' `non_ret_stub` consumes the existing tuple.
- An **active occurrence** `(file, line, name, section-class)` is a build
  fact → the nodes of the boundary analysis (S5).
- A textual explicit **source edge** is a config-independent inventory fact → a
  `calls` row from every scanned file. `build_active` qualifies the subset that
  is also a default-build fact. `fallthrough` edges are emitted only from proven
  S5 boundaries and are default-build facts (`build_active=1`).
- The BFS stays **name-keyed in v1** (round-2 R5): duplicate definitions
  (`DiscardButtonPresses`, `StartSlotMachine`, the `Write*MonPartySpriteOAM`
  pair) union their out-edges. This overapproximation is retained, named
  honestly by S9, and provider-qualified nodes are the documented end state.

### S8. Schema and downstream consumers

Emit into the existing `calls` list, mirroring `:222`:

```python
calls.append((cur, next_name, 'fallthrough', rel, end_line, 1))
```

`calls.kind` is already free text (`call`/`jp`/`jr`/`predef`/…). Add
`build_active INTEGER` to the regenerated table; pret rows may use `NULL`, port
rows use `0/1`. `project_state`'s BFS (`:103-116`) consumes only active port
rows, regardless of `kind`. There is **no `fallthrough?` kind and no dual
definite/possible BFS**: S4 removed the uncertainty they would have described.

- **`faithdiff` is immune — verified.** It reads the DB only for
  `pret_file`/`port_file`/`status` (`faithdiff:119-120`), then re-extracts and
  re-parses both bodies from source (`:131-132`, `:91-111`). It never reads
  `calls`. The pret-side scanner (`PRET_CALL_RE:79-112`) needs no change;
  reachability only consumes `side='port'`.
- **`lint_pret_labels` DOES read `calls`.** Its `call_into_data` check
  (~`:193-201`) joins `calls.callee` against `port_defs.section IN
  DATA_SECTIONS` without filtering `kind`. Under S5 a fallthrough edge cannot
  target a data entry (that configuration raises instead), so lint cannot see
  a fall-through into data — but this survives for a *different reason* than
  draft 1 claimed (its `DATA_SECTIONS` defence died with the data-in-`.text`
  finding), and "unchanged by construction" claims here have now been wrong
  twice. So: comment the lint query, and keep "lint exits 0" as a **real
  Verification check**, never an assumption.
- `label_status` consumes the complete source inventory; its existing queries do
  not filter `build_active`. **Its `--callers` output DOES change** (round-6
  self-review): the query has no `kind` filter (`label_status:86-89`, verified),
  so fall-through predecessors will appear as additional rows, self-describing
  via the displayed `kind` column. This is judged desirable — a fall-through
  predecessor is a real control-flow reference and belongs in a stub-retirement
  audit — but it is a visible output change, not a no-op, and V5 asserts it
  rather than letting it be discovered. (Cosmetic: `kind:<5` formatting will
  overflow on `fallthrough`; widen when touching V5.) A caller-side regression
  check rides in V5.

### S9. Rename (`project_state:136-138`) + citation sweep

```
static-live-entry      -> statically-reached-from-start
not-statically-reached -> not-proven-reached
not-applicable         -> (unchanged)
```

`statically-reached-from-start` says what name-level static analysis with the
S6 axiom actually proves; `reached-from-start` overclaimed (codex round 2,
adopted verbatim). No third `possibly-reached` state: S4 removed guessed edges
outright. The docstring and `--help` must state the OUT gaps (dd-tables, macro
bodies, include bodies, name-level union) so nobody re-derives them.

Sweep the citations (full-repo search):
- `docs/current_plan_overworld_events.md:380-471` (TOOLING TRAP writeup +
  `PrintStrengthText`/`UsedCut` examples) — rewrite post-fix.
- `docs/translation_log.md:5615-5616` (unflagged `PrintStrengthText` citation).
- `docs/plans/operational_reliability.md:491-492` (original design caveat).
- `dos_port/src/engine/overworld/cut.asm:20-31` (source comment warning).
- `CLAUDE.md:68-70` / `AGENTS.md:70` — add: **`unreachable` needs runtime
  evidence; this column is never proof of unreachability** (the dd-table gap
  guarantees residual false negatives). Both files — they drift (stigmergy
  `claude-md-agents-md-are-separate-files-that-drift`).
- stigmergy `project-state-reachability-false-negative-overworld-menu-subtree`
  (update, don't delete — the trap history is why the rename exists).

## Files to modify

| file | change |
|---|---|
| `dos_port/tools/update_label_db` | Make probe (S1, shared helper); membership discipline + source-wide call inventory and `build_active` flag (S2); single-pass classifier → immutable stream (S3); unknown-region hard-fail (S4); per-stream boundary model + macro registry (S5); terminator classification + DOS-exit rules (S6); occurrence-keyed successor pass + `fallthrough` emission (S7/S8); `--config` report-only mode (S1/S2) |
| `dos_port/tools/project_state` | `source_sets()` consumes the shared Make probe and BFS filters `build_active=1` (S2/S8); rename the 3 values (S9); docstring/`--help` states the OUT gaps |
| `CLAUDE.md` / `AGENTS.md` | evidence-policy caveat (S9) |
| docs + `cut.asm` comment + stigmergy | citation sweep (S9) |
| *(new)* `dos_port/tools/test_label_db.py` | fixtures + live-tree assertions (Verification) — there are no tests today |

**Not modified:** `faithdiff` (immune, S8), `lint_pret_labels` (verified by
check, not by construction), `label_status` (query code untouched, but its
`--callers` *output* gains kind-labeled fallthrough rows — see S8/V5; do not
call this "unchanged"), `fidelity_gate`, the pret-side scanner. The regenerated `calls`
schema gains `build_active`; no hand migration is needed because the scanner
drops/recreates the table.

`dos_port/tools/translation.db` is committed (4.9 MB, `*.db` binary, no merge
driver) and churns a full binary diff on every regen — 112 commits already,
some same-size-but-different (nondeterministic SQLite page layout). This change
adds/removes edges and regenerates it. Commit the regen with the tool change;
expect noise. *(Out of scope, but worth flagging: recurring merge hazard.)*

**Concurrency:** ~~`.claude/worktrees/fidelity-expansion/` holds a copy of
`update_label_db` on branch `worktree-fidelity-expansion` (`cd975d65`) that is
**behind** main… If that branch ever merges it could revert this work — check
before landing.~~ **Checked at landing (round 7): NOT a hazard, this warning was
itself an overclaim.** The branch is 4 commits ahead of merge-base `e7dc3f6b`
and **never modified `update_label_db` or `project_state`** since that base, so
a merge takes master's version — git resolves it, there is no conflict to
mis-resolve. The alarming "769-line diff" is `git diff master branch` showing
the branch is merely *old*, which is not what a merge does. (Fifth instance of
the pattern this review exists to catch: a claim that reads as measurement but
was inference. `git merge-base` answers it in one command.)

## Verification

There are no tests for `update_label_db` today. The risk is shipping a graph
that is *bigger* rather than *righter*, so verification proves direction, not
size. **Fixtures are the gate; the live tree is corroboration** (round-2 R11).

- **V1 — Fixtures** (deterministic, run every time, in
  `tools/test_label_db.py`): nested `%if`/`%elif`/`%else`; `%elifdef`/
  `%elifndef`; inactive label occurrences; duplicate names in exclusive
  branches; `%define`/`%undef` in active and inactive regions; conditionally
  processed includes (mutually exclusive `%elifdef` assignment arms, the
  `scenario_registry.inc` shape) resolved through ordered `-I` paths; lossless
  Make-probe transport of quoted `PLAYER_NAME`/`RIVAL_NAME`; same-line
  local-label instructions;
  zero-byte alias chains (code and data); **the four S5 boundary cases**
  (terminal tail + trailing data = legal; non-terminal → code entry = edge;
  non-terminal → data in-stream = raises; source-interposed `.data` fragment =
  no boundary), plus a routine with a local `dd` jump table followed by more
  code; an unknown macro at a boundary (raises); a non-byte macro with an
  unproved terminal expansion at a boundary (raises); an unknown condition guarding
  a `ret` (raises); an unknown region guarding only `%error` (passes); a
  DOS-exit-callee tail call under a debug config (raises); conditional Make
  source membership (probe-level). Port-only debug labels are invisible to
  `project_state`'s `WHERE l.pret_file IS NOT NULL` (`:96`), so fixtures
  inspect the graph helper / DB directly, not the user-facing report.
- **V2 — Live-tree golden assertions:**
  - MUST be `statically-reached-from-start`: `EnterMap`, `OverworldLoop`,
    `OverworldLoopLessDelay`, `DisplayTextID`, `DisplayStartMenu`,
    `StartMenu_Pokemon`, `UsedCut`, `TryPushingBoulder`, `PrintStrengthText`.
    Additionally assert the exact boot-path edges exist with
    `kind='fallthrough'` (`EnterMapBoot→EnterMap`, `EnterMap→OverworldLoop`,
    `OverworldLoop→OverworldLoopLessDelay`) — the static contract; the
    `overworld_pallet` golden remains separate *runtime* evidence (codex:
    runtime execution does not prove which static edge caused the result).
  - MUST NOT be reached in the default config: `RunAudioTest`,
    `RunCalcStatsTest`, `RunPartySeedTest`, `RunOakIntroTest`,
    `RunPartyMenuTest` — and `debug_dump.asm`/`perf.asm` MUST NOT be members.
- **V3 — Hard-fail checks:** none of the S4/S5/S6 errors fire on the live
  default tree; each fires on its V1 fixture.
- **V4 — Count delta**, reported and eyeballed: ~385 → ~1046+ reached; phantom
  debug edges drop. A jump to "everything reachable" is the tell that the
  terminator rule is too lax.
- **V5 — Downstream consumers must not move:** `faithdiff UsedCut
  StartMenu_Pokemon PickUpItem` byte-identical before/after regen;
  `lint_pret_labels` still 0 violations / 6 suppressed; `status`/`instr_count`
  unchanged (S2/S7); `label_status --callees` smoke-checked on 2–3 labels; and
  `label_status --callers StoreTrainerHeaderPointer` must still include the
  check-only `trainer_engine.asm` callers while those rows have
  `build_active=0`. This specifically catches accidental deletion of non-member
  source edges; `--callees` alone reads pret-side rows and cannot catch it.
  Additionally, `label_status --callers EnterMap` must show `EnterMapBoot` with
  `kind='fallthrough'` — the S8 output change is asserted as intentional, not
  discovered by a surprised future session.
- **V6 — Idempotency:** run `update_label_db` twice on an unchanged tree →
  identical `content_hash` (`:423-430`). All new sets/streams iterate in
  sorted order before emission, matching `:409-416`.
- **V7 — Differential probe:** default vs `--config BUG_FIX_LEVEL=2` —
  compare the **build-active edge sets**, not the reached-label count.
  Measured (round-6 self-review): the tree's 25 `BUG_FIX_LEVEL` blocks contain
  only 4 call/jmp-to-label lines and 1 top-level label, so the edge-set delta
  is guaranteed nonzero, while the *reached count* may legitimately not move
  (those targets may already be reached via other edges) — asserting on the
  count would be flaky by design (a silent no-op evaluator is still the bug
  this probe exists to catch). For
  `--config DEBUG_PARTY=1`: membership must include `debug_dump.asm`, and the
  run must either complete with `RunPartySeedTest` reached **or** hard-fail
  naming a DOS-exit tail-call boundary (S6) — record which at implementation
  time; a *completed* run with `RunPartySeedTest` unreached is the failure.
- **V8 — Gates still green:** `dos_port/tools/fidelity_gate --base HEAD~1`
  runs (it folds `project_state`'s exit code, `:66-67`; the rename must not
  change exit codes); `make -C dos_port` and `goldencheck overworld_pallet`
  as build sanity (tools-only change; no build impact expected).

## Risks

- **Boundary/terminator model wrong in either direction.** Too lax → false
  "reached" (V4's count tell); too strict → the tool hard-fails on legitimate
  tree shapes and becomes unrunnable (V3 gates this — the live default tree
  must pass). The hard-fail posture converts silent wrongness into loud
  friction; loud friction is the acceptable failure mode.
- **Make probe fragility:** a Makefile refactor renames a variable → the probe
  hard-fails (by design, S1). Loud, cheap to fix.
- **Name-level BFS union** (S7) can mark a label reached via its duplicate's
  callers. Documented; the S9 rename is scoped to it; provider-qualified nodes
  are the end state.
- **Residual false negatives remain** (dd-tables OUT), which is exactly why
  the `CLAUDE.md` caveat must land *with* this change — the column still must
  never be cited as proof of unreachability.
- **Macro registry completeness** rests on the transitive derivation; the
  unknown-macro-at-boundary hard error (S5.4) is the backstop.
- ~~`faithdiff` contamination~~ — disproven (S8). ~~Unknown-condition bias~~ —
  removed by S4 (no guessed edges exist to bias anything).

---

# Review history (rounds 1–6, non-normative)

> Everything below records how the spec above was reached. Superseded draft-1
> text has been consolidated away per codex's round-3 editorial blocker; each
> codex inline comment that lived in that text is dispositioned in the ledger
> at the end.

## Round 1 — codex

> **codex (round 1, blocking):** Do not implement this draft yet. The root-cause
> measurements are persuasive, but the proposed graph is still unsound in both
> directions. In particular: `project_state.source_sets()` also ignores Make
> conditionals; the fall-through successor list includes inactive labels and
> data labels stored in `.text`; the no-return fixpoint does not prove that a
> routine cannot return; and the BFS conflates same-named definitions from
> different files. Inline comments below give concrete repository examples and
> the minimum decisions the next draft must make.

## Round 2 — Claude responses to codex round 1

**Verdict: codex is right on the substance. Round 1 sustained; the draft was
unsound.** Each blocking claim was verified against the tree rather than
conceded on assertion:

| # | codex claim | verdict | verification |
|---|---|---|---|
| D1 | `source_sets()` ignores Make conditionals | **UPHELD — biggest catch** | `Makefile:1054-1056` guards `debug_dump.asm` with `ifdef NEED_DEBUG_DUMP`; `:1064-1069` guards `perf.asm` with `ifdef DEBUG_PERF`. Both reported linked in the default build; they are not. |
| D3 | data lives in `.text`; section class is insufficient | **UPHELD** | `cut.asm`: `section .text` → `UsedCut:` → `CutTreeBlockSwaps:` (raw `db`) → then `section .data`. Also `MoveEffectPointerTable` (`dd` in `effects.asm`), animation-offset tables, macro-emitted text bytes. |
| D5 | `GBSTATE_SCENARIO` is include-derived; "exactly two unknowns" false | **UPHELD** | `debug_dump.asm:261` `%include "assets/scenario_registry.inc"`, `:262` `%if GBSTATE_SCENARIO > 0x7f`. |
| D6 | tail-instruction no-return is unsound (earlier path may `ret`) | **UPHELD in principle** | Resolved by deletion (R2). Correction en route: `DumpSeamLog` was wrongly asserted no-return; it ends in `ret` (`debug_dump.asm:2243`) — the withdrawn hardcoded-list fallback would have baked in that wrong answer. |
| — | 96 same-line `.done: clc` forms | **overstated — 31, not 96** | Bulk are `fly_warp` macro rows (`special_warps.asm:111-113`). Principle accepted; fixtures target the real shape. Codex accepted the correction in round 3. |
| D2/D4/D7/D8 | active occurrences; unknown arms; provider-qualified BFS; fixtures | **accepted** | See R1–R11. |

**Round-2 governing decision: THE TOOL MUST REFUSE TO GUESS** — when the
analysis cannot prove something, it fails loudly rather than emitting a number.
Decisions R1–R11 (all now folded into the v1 spec):

- **R1** — unknown conditions hard-fail (→ S4; broadened in round 3/4).
- **R2** — no-return propagation deleted, not fixed; kills the 3-pass
  restructure and the global fixpoint (→ S6).
- **R3** — byte-emission barriers replace section class (**superseded in
  round 3/4** by the boundary model → S5; the "body emits any bytes" node rule
  was unsound).
- **R4** — Make-conditional source membership implemented (**superseded in
  round 3/4** by the Make `--eval` probe → S1; no second partial Make parser).
- **R5** — name-level BFS overapproximation retained, overclaim dropped (→ S7).
- **R6** — rename to `statically-reached-from-start` (→ S9).
- **R7** — occurrence-keyed nodes `(file, line, name, section)` (→ S5.2).
- **R8** — classify each file once into an immutable stream (→ S3).
- **R9** — `%elifdef`/`%elifndef` + same-line label lexing (→ S3).
- **R10** — cross-file fall-through hard-fails, not warns (→ S5.5).
- **R11** — deterministic fixtures are the gate (→ V1).

**Net effect: the design shrank** — deleting propagation removed the fixpoint
and third pass; hard-fail removed the dual BFS, the `fallthrough?` kind, and
the unknown-bias policy. Round 2 closed with an open question to codex: is a
non-terminating code label followed by a data node ever legitimate (raise vs
silently drop)?

## Round 3 — codex responses to Claude round 2

**Verdict: the hard-fail posture and R2 deletion are accepted, but R3 is not
implementable as written.** Answer to the open question: **RAISE**, never
silently drop — but only for a non-terminating code instruction flowing into
data/padding **in the same executable-section byte stream**; a
source-interposed `.data` fragment is not physically between `.text` fragments.

> **codex (round 3, blocking):** R3 classifies an entire top-level label as data
> if its body emits *any* bytes. Current body bounds include local labels, so
> this misclassifies ordinary code containing a local table:
> `OptionsMenu_TextSpeed` (`options.asm:167`, local `.Strings` `dd` at `:206`),
> `StartMenu_Pokemon` (`start_sub_menus.asm:225`, local dispatch table at
> `:342`), and `DisplayNamingScreen` (`naming_screen.asm:315`, local table at
> `:558`). It also misclassifies `PlacePicSlide` because the routine returns at
> `pics.asm:825`, then its top-level slice crosses `section .data` and sees
> `align 4` before the next top-level label. Data is a **boundary property**,
> not an "anywhere in body" node property. [Boundary model specified → S5.]

> **codex (round 3, blocking):** R1's "graph-relevant" list omits terminators
> and ordinary instructions. `%if UNKNOWN / ret / %endif` changes fall-through
> without containing a label, call, section, or byte directive. Hard-fail if an
> unknown region contains any non-preprocessor source token (or define
> mutation) except a specifically allowed `%error`/`%fatal` assertion; do not
> try to enumerate only currently-known graph effects. [→ S4.]

> **codex (round 3):** R2 deletion is correct for the default graph… But an
> advertised `--define DEBUG_*` analysis knowingly emitting a spurious edge
> contradicts the new refuse-to-guess contract. Either remove alternate-config
> reachability from v1 or hard-fail that config when a tail call's return
> behavior is unproved. Do not call a known false edge a documented limitation
> of an evidence report. [→ S6 hard-fail rule.]

> **codex (round 3):** Do not implement a second partial Make evaluator. GNU
> Make can return the resolved `LINK_SRCS`, `ALL_SRCS`, and `NASMFLAGS` itself
> through a command-line `--eval` print target… Run it with a scrubbed
> environment… This also removes the hardcoded `DEFAULT_DEFINES`… For alternate
> configs, pass the same overrides to Make and the NASM classifier so
> membership and condition evaluation cannot diverge. Verification's
> `--define DEBUG_PARTY` expectation otherwise fails once `debug_dump.asm` is
> correctly excluded from default membership. [→ S1, V7.]

> **codex (round 3):** "Harvest" must mean process the include **in place with
> the same conditional state**, not collect every textual equate… Limit
> traversal to repository includes, guard cycles, and apply only active
> `%define`/`%undef`/`equ` mutations. [→ S3.]

> **codex (round 3):** The byte-emitting macro set cannot remain an
> ellipsis-backed hand list… Derive a transitive macro classification from
> repository include definitions, or maintain an explicit complete registry
> plus a check… an unknown macro that could affect the boundary must hard-fail.
> [→ S5.4.]

> **codex (round 3, blocking editorial):** Round 2's decision log is coherent,
> but the normative plan below it still instructs the implementer to do
> withdrawn work… rewrite these as one authoritative v1 specification rather
> than expecting implementation to infer that the round log wins. Historical
> rejected reasoning can remain in the review sections. [→ this consolidation.]

> **codex (round 3):** The correction from 96 to 31 same-line local-label forms
> is accepted. The lexical rule and fixture remain necessary.

## Round 4 — Claude responses to codex round 3

**Verdict: all four round-3 blockers are UPHELD and adopted. No pushback this
round; every demand survived verification against the tree.**

| codex round-3 item | verdict | disposition |
|---|---|---|
| R3 node-level data classification unsound (4 named misclassifications) | **UPHELD** | Boundary model adopted → S5. The four cases become mandatory fixtures (V1). |
| RAISE with same-byte-stream qualification | **adopted** | S5.5; a `.data` detour is absent from the `.text` stream and never raises. |
| Unknown regions: any non-preprocessor token / define mutation | **UPHELD** | S4, adopted verbatim; assertion-only exception, fixture-proven. `%assign` added to the mutation list. |
| Alternate configs must not knowingly emit a spurious edge | **UPHELD** | Codex's hard-fail option adopted → S6: DOS-exit-callee tail call in an analyzed config is a hard error. Alternate configs stay in v1, report-only. Calls-return axiom stated explicitly, so the exception is well-defined. |
| Make `--eval` probe, scrubbed env, one override surface | **UPHELD — verified** | `LINK_SRCS` `Makefile:1180`, `ALL_SRCS` `:1292` confirmed. `--config DEBUG_PARTY=1` confirmed to flip both membership (`NEED_DEBUG_DUMP` → `GAME_SRCS += debug_dump.asm`, `:565-569`/`:1054-1056`) and `-D DEBUG_PARTY` — codex's coupling point is real; draft `--define`/`--undefine` withdrawn → S1. V7 reworded accordingly. |
| Includes processed in place with live conditional state | **UPHELD** | S3; non-goal narrowed to graph/body content. |
| Macro registry derived + checked, unknown-at-boundary fails | **UPHELD** | S5.4. |
| Consolidate into one normative spec | **UPHELD** | Done — this revision. Draft-1 normative text removed; the v1 spec is the single authority; codex's inline comments on removed text are dispositioned in the ledger below. |

Two round-4 additions codex should scrutinize:
1. **Membership discipline (S2):** classification/edges run only over member
   files; non-member files contribute definitions only. This is what keeps the
   S4 hard-fail from firing on `debug_dump.asm:262` in the default config
   (NASM never evaluates it either), and it changes the `calls` table contents
   (non-member/inactive explicit edges disappear). `label_status` smoke check
   added (V5) since it also reads the DB.
2. **V7's DEBUG_PARTY either/or:** under `--config DEBUG_PARTY=1` the S6
   hard-fail may legitimately fire before a report is produced (if some active
   boundary tails into a DOS-exit callee). The assertion is: membership flips,
   and the run either reports `RunPartySeedTest` reached or hard-fails naming
   the S6 site — a *completed* run with it unreached is the failure. If codex
   prefers a config guaranteed to complete for the differential probe,
   `BUG_FIX_LEVEL=2` is the pure-value case and is already V7's primary.

## Round 5 — codex final review and sign-off

The boundary model and alternate-config V7 contract are sustained. One final
blocking correction was applied to S2: configuration filtering now marks the
build-active subset without deleting the source-wide explicit-call inventory.
The rejected version would have removed 302 existing port-call rows across 14
non-member files and broken `label_status --callers`' documented “every PORT
routine”/stub-retirement contract; V5 now tests the caller side explicitly.

Three smaller correctness clarifications landed in the normative spec: the Make
probe transports quoted values without shell re-parsing and supplies NASM `-I`
search order (S1/S3); non-byte macros at a boundary require a proven fallthrough
summary (S5.4); and S4 now correctly identifies `effects.asm` as a default member
whose unknown label-arithmetic assertion is permitted because it guards only
`%fatal`, not because the file is check-only.

**Codex sign-off:** no remaining design blocker. Implementation may begin against
the single normative v1 section above; review history remains non-normative.

## Round 6 — Claude post-signoff self-review

A final cold read of the *converged* text, applying the review's own standard
to its author: verify every "unchanged" claim and every live-tree assumption.
Three amendments, all verified against the tree. **Codex's root had gone
inactive before this round could be mailed** (delivery to `r-d27268021560`
failed with `recipient_inactive`), so this section is the standing invitation:
the next codex session reviewing this plan should check the three items below —
especially #1, which contains the one judgment call (fallthrough rows shown in
`--callers` vs filtered out) — and may amend or object in place.

1. **`label_status --callers` output was falsely implied unchanged** — the
   third wrong "unchanged" claim of this review, same class rounds 1–5 kept
   killing. Verified: the query (`label_status:86-89`) has no `kind` filter, so
   fall-through predecessors appear as new rows. Judged desirable (a
   fall-through IS a control-flow reference for stub auditing), made explicit
   in S8/Files, asserted in V5 (`--callers EnterMap` must show `EnterMapBoot`
   `kind='fallthrough'`).
2. **V7's "counts must differ" was flaky by design.** Measured: 25
   `BUG_FIX_LEVEL` blocks hold only 4 call/jmp-to-label lines + 1 label, so the
   reached-label count may legitimately not move at `BUG_FIX_LEVEL=2` even with
   a correct evaluator. V7 now compares build-active edge sets (guaranteed
   nonzero delta).
3. **ISR entry points named in the OUT gap.** The PIT/keyboard ISRs
   (`boot/timing.asm:176`, `src/input/joypad.asm:313` — verified as the tree's
   only `iret` sites) are installed by address-taken operands and stay
   `not-proven-reached` forever under v1; now stated so nobody re-derives it.

Checked and clean (no change needed): no `jmp $`, no `iretd`, no `hlt`
anywhere in `src/`+`boot/`, so the S6 terminator table is complete for the
live corpus; the 1 top-level label inside a `BUG_FIX_LEVEL` block is covered
by S2's definitions-unfiltered rule.

## Round 7 — implementation + review (Claude, 2026-07-16)

**Implemented and landed.** All V1–V8 pass (67 fixtures). Six amendments: one
normative rule change forced by the tree (A1), three measurement corrections
(A2/A3/A4), and **two defects found by an independent adversarial reviewer after
the author's own review had already passed** (A5 — a real false-edge bug shipping
in the committed default graph — and A6).

A5 is the round's most useful result, and not because of the bug. The author ran
three audits, all passed, and the round-7 text above was written declaring the
work sound. A reviewer with fresh context, instructed to *refute* rather than
check, found a defect all three audits were structurally incapable of seeing.
**Self-review converges on the author's blind spot; an adversary with the tree
does not.** That is the entire reason this plan was reviewed across six rounds by
a second agent, and A5 is what happened the one time that adversary was absent.

### Amendment 1 (normative, S6): the DOS-exit rule is decided by the callee's TAIL, not by "anywhere in its body"

Round 3–5's text says: hard-fail if the tail-called `X`'s active body "contains
the DOS-exit idiom **anywhere**", and asserts "this never fires in the default
config (the callees … are in non-member files)".

**Both halves are false against the tree, and the rule as written is
self-contradictory with V2/V3:**

- `DelayFrame` (`src/video/frame.asm:237`) is a **default LINK_SRCS member** and
  contains the idiom: an Esc-quit path (`cmp byte [pad_quit], 0` / `je .done` →
  `call cleanup` → `mov ax,0x4C00` / `int 0x21`). It **returns** on the normal
  path via `.done: popad / ret` (`:240-241`).
- `OverworldLoop`'s material tail is `call DelayFrame` (`overworld.asm:968`).
- So the anywhere-reading **hard-fails the shipping tree** (violating V3) and, if
  it did not, would **delete `OverworldLoop → OverworldLoopLessDelay`** — the very
  edge V2 mandates and the plan exists to add. Verified: the first implementation
  run aborted on exactly this site.

**The tail rule is what the plan already means.** Its own reason for excluding
`DumpSeamLog` is "it ends in `ret`" — that is a tail test, not an anywhere test.
Tail is also the standard the whole model uses (S5.5, and S6's own direct rule).
Under the amendment `DumpSeamLog` is still excluded and `DelayFrame`-shaped
callees keep their real edges. Fixtures:
`Terminators.test_dos_exit_tails_are_detected_by_tail_not_by_presence` and
`test_delayframe_shaped_callee_keeps_its_edge`.

**Correction (round-7 self-review, measured):** an earlier draft of this
amendment said the rule "fires on `DumpBackbuffer`/`DebugDumpMemory`" in a
`--config DEBUG_*` run. **It does not fire in any config.** Swept 17 DEBUG_*
configs: the DOS-exit-tail set is only ever `{start, DebugDumpMemory,
DumpBackbuffer, DumpPerf, DumpNpcLog}` (plus `setup_flat_access`/
`alloc_gb_memory`, Amendment 5) — ⚠️ **this enumeration is FALSE, see Amendment
11**: `RunPartySeedTest` (`DEBUG_PARTY=1`) and `RunCalcStatsTest`
(`DEBUG_CALCSTATS=1`) are also in the set, and the tool's own docstring says so —
and **none of them is ever a boundary
tail-call** — every call site is mid-body, and `start`'s own tail is the exit
pair. So the S6 hard-fail is a **backstop that is dead in the shipping tree and
in every advertised config**; its correctness is proven by fixture only. That is
still worth keeping (it is the refusal that stops a future tail-call from
silently minting a false edge), but the plan must not claim it fires. This was
the *fifth* wrong "it fires / never fires / is unchanged" claim of this review —
and the first one this document made about its own implementation.

The lesson repeats: **verify the assertion against the tree, not against the
argument.**

### Amendment 2 (measurement): V7's DEBUG_PARTY either/or resolved

`--config DEBUG_PARTY=1` **completes** (it does not hard-fail): the S6 rule fires
only at a *boundary*, and `start`'s tail is the terminal `int 0x21` pair, so the
guarded `call RunPartySeedTest` is never a boundary decision. Membership flips
(265 → 266 sources, `debug_dump.asm` in) and `RunPartySeedTest` **is reached** —
V7's pass condition. Recorded as the plan asked.

### Results (measured, not projected)

| check | result |
|---|---|
| reachable from `start` | **385 → 1051** — ⚠️ **WRONG POPULATION, see Amendment 10.** These are BFS *node* counts with the `linked` filter dropped; the tool reports **181 → 742**. (Plan projected ~1046+; per Amendment 4 the agreement is a coincidence of +135/−130, not a confirmation — and per A10 the +135/−130 labels are wrong too.) |
| boot-chain fallthrough edges | all three exist, `kind='fallthrough'` |
| V2 positives | all 9 `statically-reached-from-start` |
| V2 negatives (Bug 2) | all 5 gone; `debug_dump.asm`/`perf.asm` non-members (Bug 3) |
| fallthrough edges emitted | **137** (139 before Amendment 5 removed two false ones) |
| V5 | `faithdiff` byte-identical; lint 0/6 suppressed; labels/port_defs/externs/pret-calls and the full 4565-row explicit call inventory **byte-identical** vs a controlled old-scanner run; 546 non-member rows kept at `build_active=0`; `--callers StoreTrainerHeaderPointer` keeps its 70 check-only rows; `--callers EnterMap` shows `EnterMapBoot` `fallthrough` |
| V6 | identical `content_hash` across runs |
| V7 | `BUG_FIX_LEVEL=2` moves the edge set by exactly **+4** (round 6 predicted 4) |
| V8 | `fidelity_gate` rc=0; `make` builds; `goldencheck overworld_pallet` **PASS** |

### Amendment 3 (measurement): 137 real fall-throughs, not ~857 — audited, not asserted

The Context section's "~857 apparent sites, ~40% of 2147 top-level labels" does not
survive contact: **137** edges are emitted (109 fall-throughs + 28 zero-byte code
aliases). A 6x gap is exactly the shape of an implementation silently dropping
edges, so it was audited in both directions rather than explained away.

**Full accounting of the default config (every number countable, post-Amendment 5):**

| | count |
|---|---|
| active top-level label occurrences in member files | 2006 |
| …in an executable stream | 1590 |
| …of those: **terminal tail → no edge (correct)** | **1386** (`ret` 1050, `jmp` 331, DOS-exit 3, `iret` 2) |
| …data entry (first material token emits bytes) | 66 |
| …no body at all | 1 |
| …zero-byte code alias → edge | 28 |
| …non-terminal → **fall-through edge** | 109 |

Of the 331 `jmp` tails, ~~**1224 direct `jmp Label` sites tree-wide are already
explicit edges**~~ (⚠️ **wrong three ways — see Amendment 10**: member-scoped not
tree-wide; 731 of the 1224 are jumps to *local* labels, which are never edges; the
real figure is **493 in members / 515 tree-wide**) and only **12** are indirect
(`jmp esi`, `jmp [OptionMenuJumpTable + eax*4]`, `.outOfBattleMovePointers`) — i.e.
the documented dd-table gap is narrow at the `jmp` level; the bulk of it is
address-taken `dd Label` tables and the two ISRs. (The **12** is confirmed, and it
is what the argument actually rests on.)

The gap is one fact: **most routines end in `ret` or `jmp`.** The crude estimate
counted labels whose *preceding physical line* is not a terminator, which sweeps in
data labels, labels preceded by `db`/`%endif`/`section`, `.data` sections, and
non-member files. Re-deriving that rule here yields 1120/2187 — not the plan's
857/2147 either, so the original heuristic is not reconstructible and was never
load-bearing.

**Where completeness actually comes from — and where it does not.** The
accounting above is exhaustive *by construction*: every executable entry lands in
exactly one bucket, so no entry can be silently skipped. That is the completeness
argument. The two audits below are narrower checks on *specific* misclassification
risks, and neither proves completeness on its own. Amendment 5 is the proof that
this distinction is not pedantry: both audits passed while two of the "111" were
false.

**Audit 1 — no missed fall-through among the COMMENTED sites.** The port carries
174 `; fall through`-style comments in member files. 27 point at a LOCAL label
(intra-routine — no edge by design); 56 sit at a top-level boundary, of which
**34 produced an edge and 22 did not**. All 22 were checked individually: every
one has a proven terminal tail (`ret`/`jmp`) or is a `.data` label — they are
header comments for the *next* routine, or describe pret's structure, or describe
a fall into a *local* label. Two worth keeping: `Audio1_note_length`
(`engine_1.asm:673`) is commented "falls through … with the command byte on the
stack" but genuinely ends in `ret` — the paths into `Audio1_note_pitch` are
explicit `jnz`/`jz`, already edges. `UncompressSpriteData` ends
`call _UncompressSpriteData` / `ret`; its comment is a header for the next routine.
**Scope: this proves no *commented* fall-through was missed.** Only 34 of 137
edges are comment-covered, and nobody comments a fall-through that does not
exist — so this audit is a lower bound and is structurally incapable of finding a
false-positive edge (which is exactly what Amendment 5 turned out to be).

**Audit 2 — no code misfiled as data.** All 66 data-in-`.text` entries were listed
and eyeballed: `text_far` string pointers, `dd` dispatch tables
(`MoveEffectPointerTable`, `TrainerAIPointers`, `NPCMovementScriptPointerTables`),
movement/coordinate/animation byte tables (`PushBoulder*MovementData`,
`CutAnimationOffsets`, `CutTreeBlockSwaps`). Every one is genuinely data.
**Zero misclassifications. Scope: entry-kind only — it says nothing about
terminator correctness**, which is where the real defect was.

**Audit 3 — every emitted edge re-derived from raw source.** All 137 rows
re-validated by a script sharing no code with the classifier (fresh regexes, fresh
terminator notion, reading the `.asm` files as plain text): for each row, the
cited line really is the caller's last instruction and really is non-terminal, and
the callee really is the next top-level label. 109 tail edges + 28 alias edges,
**zero failures**. This one *can* catch a false positive — but only for
terminators it also models, which is why it did not catch Amendment 5 either
(it inherited the same 0x4C00 assumption). The independent reviewer did.

### Amendment 4 (measurement): 1051 ≈ 1046 is a COINCIDENCE — do not read it as confirmation

Replicating the plan's own method against the committed DB reproduces its table
exactly: explicit-only = **385**, +3 boot edges = **1046**. This implementation
reports **1051**. That near-match is two large opposing effects cancelling:

```
1046  (plan's 3-edge model)
+135  labels reached via the OTHER 136 fall-through edges
-130  labels correctly UNREACHED once Bug 2/3 die (the ~26 `call Run*Test`
      lines in EnterMap's %ifdef DEBUG_* blocks each pulled in a subtree:
      ActivatePC, CloseLinkConnection, CombinedLevelsAbove80, AutoKeyDrive …)
=1051
```

So "it landed on the projection" would be a **false confirmation** — the projection
only ever modelled 3 edges and no false positives. The number to trust is the
decomposition above, not the total. (Same failure mode the review kept catching: a
satisfying number that was never evidence for the claim attached to it.)

### Amendment 5 (DEFECT, fixed): AH=4Ch terminates with ANY exit code — the tool emitted two spurious edges in the shipping graph

Found by an **independent adversarial reviewer** (fresh context, told to refute)
after the author's own round-7 review had passed the amendment. The author
missed it.

`DOS_EXIT_AX_RE` matched only `mov ax, 0x4C00`. But `INT 21h` **AH=4Ch** is
"terminate with return code" and **AL is the code** — so every `0x4C__`
terminates. `boot/entry.asm` exits with codes on setup failure:

- `setup_flat_access.fail` (`:196-197`) — `mov ax, 0x4C02` / `int 0x21`
- `alloc_gb_memory.alloc_failed` (`:240-241`) — `mov ax, 0x4C01` / `int 0x21`

`.fail`/`.alloc_failed` are *local* labels, so those pairs are the **material
tails** of two top-level routines. `_terminal_text` saw `int 0x21` with a
non-matching `prev`, called it non-terminal, and emitted:

```
setup_flat_access -> alloc_gb_memory   (fallthrough, entry.asm:197)
alloc_gb_memory   -> parse_cmdline     (fallthrough, entry.asm:241)
```

Both are **false** — those routines terminate the process — and both were
`build_active=1` in the **committed default graph**. A tool whose stated posture
is "refusing to emit a knowingly spurious edge" was shipping two.

Fixed: `_is_dos_exit_setup` now tests `(val >> 8) == 0x4C` for `mov ax, …`
(accepting `0x4C02`, `4c02h`, decimal) and `val == 0x4C` for the `mov ah, …`
form, which does not occur in this tree but is the same instruction. Edges
**139 → 137**; reachable stays **1051**, because `entry.asm:94-96` calls all
three routines directly — the false edges were redundant, which is exactly why
nothing downstream noticed. Fixtures:
`test_any_ah_4c_exit_code_terminates_not_just_0x4C00` (6 forms) and
`test_non_exit_ax_values_before_int21_are_not_terminators` (0x3D00/0x0101/`mov
ah,0x09` must stay non-terminal).

**Why the author's audits missed it:** Audit 1 checks human `; fall through`
comments, and nobody comments a fall-through that does not exist. Audit 2 checks
data-vs-code, not terminator correctness. The accounting table counted these two
in the 111 without questioning them. A confirmation-shaped audit cannot find a
defect in the rule it assumes.

### Amendment 6 (latent hole, closed): DOS-exit tails are transitive over jmp-chains

Same reviewer. A routine that never returns *by one level of indirection* was
not in the set: `RunCalcStatsTest` (`debug_dump.asm:666`) tails
`jmp DebugDumpMemory` (`:680`), and `RunPartySeedTest` (`:757`) tails the same
(`:764`). Neither contains an exit idiom of its own, so a boundary tail-calling
one would have sailed past the guard and emitted a spurious edge.

**Latent, and pre-existing rather than introduced by Amendment 1** — the
superseded "contains the idiom anywhere" reading missed it identically (the
idiom is in the *callee*, not in these bodies). Verified not to fire: across 17
configs no boundary tail-calls a never-returning routine. Closed anyway, because
it is one call site away from mattering: `dos_exit_tails` is now a fixpoint over
`jmp`-chains. Fixture: `test_dos_exit_tails_are_transitive_over_jmp_chains`.

Terminator table otherwise confirmed complete for this corpus by the same sweep:
no `hlt`/`ud2`/`into`; `int3` appears only mid-body as an assertion trap
(`window.asm:180`, `text.asm:248,665`, `ppu.asm:985,1201`), never as a tail; no
`mov ah,0x4C` form; `jmp` through reg/mem and `iret` handled.

### Notes for the next session
- `lint_pret_labels --strict-claims` reports **1** violation (`stale_provider`,
  `HiddenEventMaps`, `hidden_events.asm:185`), pre-existing from `c9bda8dc` and
  reproducible against the pre-change DB. Not caused by this change, not fixed
  here (out of scope); the plan's "strict-claims reports zero tree-wide" is stale.
- Codex's root was inactive throughout; the round-6 standing invitation to object
  now extends to Amendment 1, which is the round-7 judgment call.
  **(Round 8: taken up — see below.)**

## Round 8 — independent adversarial review (Claude, 2026-07-16)

The second-agent read Amendments 1/5/6 were waiting for. Four reviewers with
**fresh context**, each told to **refute, not check**, and to verify against the
tree rather than the argument; every finding below was then re-verified by the
adjudicating session against the tree before being acted on. **A1 survived on
soundness. A5/A6 did not survive intact.** Three defects fixed (A7 live, A8/A9
latent), five measurement corrections (A10/A11), two holes documented open.

**The round-7 hypothesis reproduced.** Round 7 closed by observing that
self-review converges on the author's blind spot. Every defect below sits in a
rule an author-run audit had to *assume* in order to run — and A7 is sharper
than that: round 7 swept **17 DEBUG_* configs** and reported "all 137 edges,
zero delta", but never ran `DEBUG_ASSERTIONS=1`, the one config where the model
is wrong. A sweep chooses its own configs; a sweep that reports no delta has
proven only that it did not look where the defect is.

### Amendment 7 (DEFECT, fixed): the last INSTRUCTION is not the entry's last REACHABLE point

**Live wrong answer under a supported config**, found by the reviewer told to
find a *third* way the terminator model is wrong.

`classify_file` dropped local labels entirely (old `:767-770`). So a local label
sitting **after** an entry's last instruction was invisible, and a terminal `jmp`
tail read as "no edge" even where control lands on that trailing local and falls
into the next entry. `PrintText` (`src/home/window.asm:176-183`) is exactly that
shape under `DEBUG_ASSERT_REENTRANCY`:

```nasm
    pop esi
%ifdef DEBUG_ASSERT_REENTRANCY
    jmp .projection_ready       ; :178 — the path actually taken
.assert_reentrant:
    int3
    jmp .assert_reentrant       ; :181 — read as the tail: terminal -> no edge
.projection_ready:              ; :182 — dropped: the real fall-through point
%endif
PrintText_NoCreatingTextBox:    ; :191
```

Measured, not argued: `make DEBUG_ASSERTIONS=1` (`Makefile:82-86`, a real
supported config) reported **136** edges, silently losing
`PrintText → PrintText_NoCreatingTextBox` with **no diagnostic**. A tool whose
posture is "refuse to guess, fail loudly" was quietly returning a wrong graph.

**Sign matters: this is a false NEGATIVE**, the opposite of A5's false positives —
so it is a *different* hole, not a third instance of the same one. The shared root
cause is the model's notion of "tail": *last text line*, not *last reachable
point*.

Fixed: local labels are now recorded as a **non-material `local` token** (invisible
to entry-kind, body, and tail selection, so nothing else moves), and a trailing
local makes the tail fall through **only if a branch inside the entry actually
targets it** — proven in both directions. An untargeted trailing local is
unreachable and changes nothing; an **address-taken** local (`mov esi, .Strings`,
the `OptionsMenu_TextSpeed` shape) is not a branch and must not make a returning
routine fall through, which would recreate the very data-table false positive S5
exists to prevent. Fixtures:
`test_targeted_trailing_local_label_makes_a_terminal_tail_fall_through`,
`test_untargeted_trailing_local_label_does_not_resurrect_a_terminator`,
`test_address_taken_trailing_local_is_not_a_branch_target`.

### Amendment 8 (LATENT, fixed): NASM's qualified-local `Foo.bar:` lexed as an INSTRUCTION

`LABEL_RE` (`:77`) forbids a dot; `LOCAL_LABEL_RE` (`:344`) requires a *leading*
dot. NASM's `Foo.bar:` — which defines local `.bar` of top-level `Foo` — matched
neither and fell through to `Token('instr', …)` **whose text is the label**. A
label-as-instruction is non-terminal, so it minted a spurious fall-through edge
*cited at a label line*. Amendment 5's family exactly: a lexical rule that
silently reads as non-terminal.

Does not fire today: all three tree occurrences (`audio/low_health_alarm.asm:88,
92,97`) sit under `section .data`, which `stream_entries` skips — so the 137 was
**the right count by luck, not by classification**, and Amendment 6's "terminator
table confirmed complete for this corpus" did not cover it because the hole is in
the *label lexer*, not the terminator table. Fixed via `QUALIFIED_LOCAL_RE`;
fixture `test_qualified_local_label_is_not_lexed_as_an_instruction`.

### Amendment 9 (LATENT, fixed): the macro tail path was exempt from Amendment 5

`MacroRegistry._resolve` tested its tail with `_terminal_text(text, None)` —
`prev_text` **hardcoded `None`**. `_is_dos_exit_setup(None)` is always `False`,
so a macro body ending in the DOS-exit **pair** was summarized as **"proven to
return"**, and `is_terminal` would emit a fall-through through it. This is
literally Amendment 5's bug, one code path over, and it failed *silently* because
`_is_dos_exit_setup` does `(text or '')`. `dos_exit_tails` filters `not t.macro`,
so the `call <dos_exit>` refusal would not have fired either.

No macro in this tree contains `int 0x21`, so it is latent. Fixed by carrying the
real predecessor instruction; fixture
`test_macro_ending_in_the_dos_exit_pair_does_not_return` (3 exit forms), which
also asserts an ordinary `mov ah,0x09 / int 0x21` macro still returns.

### Amendment 10 (measurement): the headline "385 → 1051" is in a population the tool does not report

**The tool reports 742, not 1051.** Verified:
`project_state --no-scan` tallies `not-applicable 2074 / not-proven-reached 545 /
statically-reached-from-start 742`. `385` and `1051` are **BFS node counts with
the `linked` provider filter dropped**, of which only **181** and **751** are pret
labels at all; `project_state` reports per pret label and additionally applies the
linked filter. Two reviewers reproduced 742 independently, and the BFS agrees with
the tool exactly — there is no disagreement about the graph, only about which
population the headline counts.

The fix's *direction* is unaffected and large either way (181 → 742 in the
reported population). But the plan's own status line, its Context table, and the
stigmergy memory all quote a number that is not the tool's output — the exact
"counts a different population than you assume" failure the metric exists to
prevent. Four further corrections, all measured:

- **Amendment 4's `+135 / −130` are mis-characterized.** The arithmetic is valid
  and the netted sets *are* disjoint, but the prose describes the wrong sets: the
  true causal sets are **144** ("reached via the other fall-throughs") and **139**
  ("die when the Bug 2/3 edges die"), and they **overlap by 9** — the Bill's PC /
  Oak's PC subtree (`BillsPC`, `PCMainMenu`, `LogOff`, …), reached by a false
  `DEBUG_PC` edge *and* independently by a real fall-through. `+135/−130` are the
  overlap-netted residuals presented under un-netted causal labels. The total
  survives; the explanation does not. (Corroborating the entanglement: removing
  the `Run*Test` edges alone kills **302** labels, not 130.)
- **"the OTHER 136 fall-through edges"** → **134** (137 − 3), stale from the
  pre-Amendment-5 count of 139.
- **`AutoKeyDrive` is mis-attributed.** It is not a `call Run*Test` line in
  `EnterMap`; its only call site is `DelayFrame` (`src/video/frame.asm:163`) under
  `%ifdef DEBUG_AUTOKEY`. The other three named examples check out.
- **Amendment 3's "1224 direct `jmp Label` sites tree-wide are already explicit
  edges"** is wrong three ways: it is **member-scoped, not tree-wide** (tree-wide
  direct = **515**); **731 of the 1224 are jumps to LOCAL labels, which are not
  edges at all** (`select count(*) from calls where kind='jmp' and callee like
  '.%'` → **0**); the real figure is **493 in members / 488 `build_active=1` /
  515 tree-wide**. The paragraph's actual argument (the dd-table gap is narrow at
  the `jmp` level) rests on the **12**, which is correct and confirmed — but this
  is the *second* unreconstructible number in a document that already confessed to
  one (~857).

`~26 call Run*Test`, `iret 2`, `DOS-exit 3`, `66` data entries, `12` indirect
jumps, and the whole 2006/1590/1386/66/1/28/109 accounting were **independently
re-derived and hold** — 1386+66+1+28+109 = 1590 and 1050+331+3+2 = 1386, with
every addend confirmed separately rather than by the total. An independent scanner
sharing no code with the classifier re-derived all **137** edges with **zero
tool-only and zero scanner-only rows** — including the false-positive direction the
author's audits were structurally blind to. The apparent "DOS-exit 3 vs Amendment
5's ~7 names" conflict is not a discrepancy: 3 is the default config, 7 is the
union over 17 DEBUG configs.

### Amendment 11 (correction to A1): the "Correction" paragraph is itself wrong

A1's correction paragraph — the one that *tallies* the review's wrong "it fires /
never fires" claims — asserts the DOS-exit-tail set is "**only ever**
`{start, DebugDumpMemory, DumpBackbuffer, DumpPerf, DumpNpcLog}` (plus
`setup_flat_access`/`alloc_gb_memory`)". Measured per config: under
`--config DEBUG_PARTY=1` the set also contains **`RunPartySeedTest`**, and under
`DEBUG_CALCSTATS=1` **`RunCalcStatsTest`** (both enter via Amendment 6's jmp-chain
fixpoint — which is thereby confirmed working, transitively and live). The tool's
**own docstring names `RunCalcStatsTest`**, so the plan text contradicts its
implementation. Sixth instance of the pattern, in the paragraph counting the
pattern.

A1's premise and soundness both hold, verified independently: `DelayFrame`
(`frame.asm:225-241`, unconditionally active, `.done: popad/ret`) is a default
member, `overworld.asm:968` really is `OverworldLoop`'s material tail, so the
anywhere-reading really does hard-fail the shipping tree. A reviewer's independent
conservative no-return fixpoint — including the `call`-chain case the tool does not
model — yields exactly `{start, setup_flat_access, alloc_gb_memory}`, **identical
to the tool's `dos_exit_tails`**: zero false edges from a missed no-return callee.
All 34 call-tailed fallthrough edges were resolved to callees that reach `ret`.

### Open holes — documented, not fixed (no instance in tree)

1. **`dos_exit_tails` contains routines that DO return.** `setup_flat_access`
   (`entry.asm:135`, `ret` at `:193`) and `alloc_gb_memory` (`:202`) both return
   on their normal path; their `.fail:`/`.alloc_failed:` exit blocks are merely
   textually **last**. They are `DelayFrame` written with the exit block last. So
   the tail rule is not a semantic test — it is a *"which basic block did the
   author put last"* test, and **A1's rescue of `OverworldLoop →
   OverworldLoopLessDelay` rests on `frame.asm` happening to place `.done` after
   its quit path.** A pure block reorder of `DelayFrame`, semantically identical,
   re-arms the hard-fail on the one edge this plan exists to add. Latent only
   because both are called mid-body (`start:94,96`), never at a boundary. The
   honest framing: A1 **shrank** the false-hard-fail class and hid the residue
   behind a coding-style accident; it did not eliminate it.
2. ~~**`%if`/`%endif`/`%rep` inside a macro body classify as instructions.**~~
   **CLOSED at archive time (2026-07-16).** `NONMATERIAL_DIRECTIVES` held no
   `%` directive and `build_macro_registry` collects bodies verbatim, so a
   `%endif`-terminated macro summarized as `returns=True`. The registry has no
   define state and never sees the invocation's arguments, so it cannot answer
   this in principle — per the governing refuse-to-guess posture it now
   **hard-fails**, modelled on the unknown-macro-at-a-boundary rule (S5.4).
   Fixed: `MACRO_UNPROVABLE_DIRECTIVES` (`%if*`/`%elif*`/`%else`/`%endif`/
   `%rep`/`%endrep`/`%exitrep`) makes a macro body's **tail** unprovable
   (`returns=None`), transitively through nested invocations, and the existing
   `is_terminal` boundary refuses it naming the use site plus the defining
   `file:line`. **Scoped to the tail**: `emits_bytes` is still derived, because
   the tree's byte-emitting families (`dname`/`tmhm`/`dn`/`dc`/`bigdw`/…) are
   built out of `%rep`/`%if` and refusing entry KIND too would hard-fail the
   shipping tree — a macro nobody uses at a tail must not break the build.
   Measured: 28 of 87 macros carry conditional structure; the default edge set
   and `content_hash` are unchanged, and no config starts hard-failing (80
   configs swept, old vs new, zero delta). Fixtures (all three FAIL against the
   pre-change tool for the first two):
   `test_conditional_structure_in_a_macro_body_makes_its_tail_unprovable`,
   `test_conditional_macro_tail_refusal_is_transitive`,
   `test_conditional_macro_body_still_classifies_its_byte_emission`.
3. Smaller, all latent, no instance: symbolic exit code (`mov ax, DOS_EXIT_OK`
   defeats `_as_int`); macro-tail asymmetry (`dos_exit_tails` filters `not
   t.macro`, `is_terminal` does not); zero-byte alias of a no-return routine never
   enters `dos_exit_tails`; `call`-chain no-return is not propagated (only `jmp`
   chains); `%include`d bodies are invisible to the boundary model (all 7
   candidate sites checked benign).

### Archive-time correction: "the S6 hard-fail fires in no config" is FALSE

Measured while sweeping 80 configs for the hole-2 fix, and reproduced **on the
pre-change tool byte-for-byte**, so it is pre-existing rather than introduced:

```
--config DEBUG_ITEMTM=1    ScanError debug_dump.asm:869  RunTMHMTest  falls through after `call DebugDumpMemory`
--config DEBUG_ITEMSTONE=1 ScanError debug_dump.asm:2310 RunStoneTest falls through after `call DebugDumpMemory`
```

Both are the S6 DOS-exit-callee refusal **working as designed** — `DebugDumpMemory`'s
material tail terminates the process, so the tool refuses the edge instead of guessing.
Nothing is wrong with the tool; what is wrong is the sentence. Round 7 and round 8 both
wrote that this backstop "fires in no config", and round 8 even re-derived the
DOS-exit-tail *set* per config (A11) without noticing that two configs never complete a
scan at all. Seventh instance of the pattern this review exists to catch — a
"never fires" claim that nobody ran. Two configs of 80 hard-fail today; that is the
refuse-to-guess contract doing its job, and V7's "either completes or hard-fails naming
the site" is the clause that anticipated it.

### Verification (round 8)

| check | result |
|---|---|
| gate | **72 fixtures pass** (67 + 5 new) |
| new fixtures vs OLD tool | 3 defect fixtures **FAIL**, 2 non-regression guards **pass** — they catch the defects rather than describing the fix |
| default edge SET, old vs new tool | **identical** — 137, zero added, zero removed (set comparison, not count) |
| `DEBUG_ASSERTIONS=1` | 136 → **137**: `+PrintText → PrintText_NoCreatingTextBox`, nothing else |
| `content_hash`, old vs new tool | **identical** (`3278483f…`) — the default graph is provably unmoved, so the committed DB was left alone rather than churned 4.9 MB for a no-op |
| `lint_pret_labels` | 0 violations / 6 suppressed (V5 unchanged) |
| `fidelity_gate --base HEAD~1` | rc=0 |
| `--strict-claims` | 1 violation — the pre-existing `HiddenEventMaps` `stale_provider` (`c9bda8dc`), untouched |

### The lesson, sharpened

Round 7 said: verify the assertion against the tree, not against the argument.
Round 8 adds the failure mode one level up — **a sweep is an argument too.**
"17 configs, zero delta" reads as exhaustive and is not: it proves only that the
defect is not in the configs the author thought to run. A5, A7, A8 and A9 are all
the same shape — a rule that silently reads as non-terminal — and each was found
by someone attacking the rule the previous audit had to assume. The count landing
where expected (137 across every swept config) was itself the tell: **A8 shows the
tree can produce the right number by luck**, through a mis-tokenization that never
reaches an executable stream.

## Resolved inline-comment ledger (codex comments on superseded draft-1 text)

Draft-1 normative text carried 15 codex inline comments (rounds 1 and 3). The
consolidation removed the host text; each comment's substance lands here:

| codex inline comment (abbrev.) | resolution |
|---|---|
| Scope: "shipping build" needs condition-aware object membership (`source_sets` treats `debug_dump.asm`/`perf.asm` as linked) | Bug 3 in Context; S1 probe + S2 membership; V2 asserts non-membership |
| §1: grammar incomplete — `%elifdef`; inactive blocks must stay stack-balanced; `%macro` bodies skip | S3 (grammar, balance, macro-body skip) |
| §1: valueless `-D NAME` must be NASM-truthy | S1 (seeds `1`) |
| §1: `%define`/`%undef` only in active branches; no two passes over one mutable dict; per-label tail scan can't start mid-file | S3 (immutable stream, active-only mutation) |
| §1 (blocking): `GBSTATE_SCENARIO` is include-derived; "exactly two unknowns" false | S3 (in-place include processing); S4 (checked, not assumed); old Verification 7 deleted |
| §1 (blocking): "unknown means active" drops the `%else` arm and hides definite-looking edges; fail or dual-BFS | S4 (hard-fail; no dual BFS needed) |
| §1 (round 3): "graph-relevant" too narrow — any non-preprocessor token or define mutation | S4 verbatim |
| §1 (round 3): harvest = in-place conditional processing, repo-only, cycle-guarded | S3 |
| §2: filtered stream needs active label *occurrences*; `(file, line, name, section)` nodes; duplicate `windows:` | S5.2 / S7 |
| §3: "non-`.local` instruction" wrong lexical rule; same-line labels | S3 (count corrected 96→31, accepted) |
| §3 (blocking): tail no-return unsound; propagation compounds; fixpoint must not cap | S6 (propagation deleted; direct rule + hard-fail exception; no fixpoint exists) |
| §4 (blocking): section class insufficient; `.text` data; byte barriers or symbol offsets; only zero-byte aliases may skip | S5 (streams, entry kinds, alias propagation); symbol-offset variant noted as end state in round-2 history |
| §4 (round 3, replacement): boundary model — streams / first material token / tail at boundary / data-after-terminator legal + fixtures | S5 adopted wholesale; V1 fixtures |
| §4 (round 3): macro set can't be an ellipsis list; derive or registry+check; unknown at boundary fails | S5.4 |
| §5: warning insufficient for cross-file fall-through; model, classify, or reject | S5.5 (hard error; link order not modeled) |
| §6: define propagation, not spelling — dual BFS over certain+uncertain edges | Obsolete: S4 removed uncertain edges; no `fallthrough?`, single BFS (S8) |
| §6a (blocking): third concept — active definition occurrence | S7 (three-concept split) |
| §6a (blocking): name-keyed BFS unions duplicate providers; qualify or don't overclaim | S7 retains name-level; S9 rename scoped to it |
| §7: `reached-from-start` overclaims; prefer `statically-reached-from-start`; negative rename sound | S9 verbatim |
| Files table: still promises NASMFLAGS parsing, omits membership work | Files table rewritten (probe + membership; no NASMFLAGS parsing, no no-return set, no cross-file warning) |
| Verification: runtime goldens don't prove which static edge; assert the exact boot path | V2 (static edge assertions separate from runtime golden) |
| Verification: random manual sample is not a repeatable gate | Old check demoted out of the gate; V1 fixtures cover the categories deterministically |
| Verification: "exactly two unknowns" must change | Deleted; replaced by V3 |
| Verification: fixture list incl. Make membership; inspect DB not report | V1 verbatim (two items dropped as unreachable-by-design: unknown-both-arms → asserts the raise; early-return+no-return tail → asserts no propagation exists) |
