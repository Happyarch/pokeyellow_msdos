# current_plan_script_transpiler — one-shot SM83→x86 transpiler for pret `scripts/`

**Worktree:** `../pokeyellow_msdos-transpiler`, branch `script-transpiler`, already
created and built clean from prework commit `c1ea70331`. Build order in a worktree
is load-bearing: `make -j$(nproc)` in the **repo root** first, then
`make -C dos_port -j$(nproc)` — see [[agent-fanout-worktree-setup]].

**Owner:** one Opus agent, stages 0–7. All tooling is Opus-owned:
a tooling error is *systematic* (one wrong flag-table row is wrong across all 251
files), while a missed detail in the comb pass is *local to one map*.
**Parallelism:** runs concurrently with `current_plan_data_path_mirror`, and is
safe alongside `current_plan_memmap_pret_names` because the symbol mapping joins
**by address** and is therefore rename-invariant.
**Fine comb (final stage):** Gemini fan-out via `agy`, one map per agent.

---

## Why

`scripts/` is the last code directory in pret without a systematic port — and
unlike `audio/` (10 code files of 469) it is uniformly code, **251 of 251 files**:

| pret dir | .asm | with code | lines | status |
|---|---|---|---|---|
| `home/` | 71 | 69 | 10,364 | ported |
| `engine/` | 214 | 212 | 60,785 | ported |
| **`scripts/`** | **251** | **251** | **29,673** | **this plan** |
| `audio/` | 469 | 10 | 35,849 | engine ported, rest data |
| `data/` / `text/` / `gfx/` | 1,013 | **0** | 48,334 | generator territory |
| `constants/` / `ram/` | 42 | **0** | 8,087 | declarations |

Hand-porting 251 maps is not viable. Collapsing map families into port-side
"drivers" was **rejected** — it invents state machines pret does not have. The
approach is to mirror pret 1:1 and take leverage from **mechanisation instead of
abstraction**.

## Principles

- **Mirror pret behaviour.** Translate what pret does, sequence for sequence. The
  output matches pret including the parts that look surprising, because pret is
  the specification. Behaviour changes belong to the post-completion sweep behind
  `make BUG_FIX_LEVEL=1|2`.
- **One-shot.** Output `.asm` is committed and thereafter hand-maintained —
  Tier 2, seeded once by a tool. Not a build step, not in `make assets`.
- **Bail loudly.** Anything not recognised with certainty emits an in-place marker
  and **no symbol**, never a plausible lowering.

## Corpus shape (measured 2026-08-16)

- 13,306 imperative lines; 6,895 text/pointer boilerplate; 618 `text_asm` markers
- per-file imperative lines: p50 **27**, p90 133, max 721; **114 of 251 files ≤20**
- concentration: top 12 files = 3,791 imperative lines = **28%** of the total
  (OaksLab 721, MtMoonB2F 398, SilphCo11F 376, CinnabarGym 318, GameCorner 298,
  RocketHideoutB4F 278, Route22 258, SilphCo7F 254, ViridianCity 229,
  PokemonTower7F 228, CeruleanCity 226, Daycare 207)
- **22 mnemonics total**; `ld` 5081, `call` 2243, `ret` 874, `jp` 841, `jr` 819 =
  85%. `daa`/`cpl`/`rst`/`halt`/`di`/`ei`/`add sp` **never occur**
- `ld` operand space is **42 shapes; six cover 90%**
- 920 conditional branches: **48.4%** producer immediately before, **20.5%**
  separated by flag-transparent ops, **31.1%** no producer within 12 lines
- **312 synthesized conditionals** (46 `call cc` + 266 `ret cc`)
- 618 `text_asm` bodies: 254 TalkToTrainer-inline, 44 jr-form, 20 trivial
  PrintText, **300 genuine residue**

## The Tier boundary is pret's own

Scripts reference text by **label** (`text_far _CeruleanGymMistyPreBattleText`,
defined in `text/CeruleanGym.asm`) and by **ID** (`ld a, TEXT_PEWTERMART_CLERK`).
Content lives in `text/`, which contains **zero instructions**. So the transpiler
emits pointers and needs **no charmap knowledge**; `gen_npc_dialogs.py` keeps
owning what they point at.

**One exception:** a few scripts carry glyph bytes directly (CeruleanGym's
`.CityName: db "CERULEAN CITY@"`, `.LeaderName: db "MISTY@"` fed to
`LoadGymLeaderAndCityName`) — pret violating its own split. The tool must
**classify `db`** (810 uses) and route string runs to a generator. Hand-encoded
charmap bytes in a `.asm` are the port's most-repeated Tier-1 violation.

## Where the tool lives

`dos_port/tools/sm83xlat/`, with a `README.md` recording the run's git SHA and
one-shot status. **Deliberately not under `tools/generators/`** — everything there
is re-run by `make assets` with gitignored outputs, so filing it there invites
someone to regenerate over hand edits. No Makefile wiring at all.

## Stages

- [x] **Stage 0 — parse & probe.** Lexer, parser, macro classifier, coverage
      counter. *Acceptance:* all 29,673 lines parse with **zero** parse errors (a
      parse failure is a tool bug, never a bail); `coverage.md` reports the
      reason-code histogram. **This is the work queue and the go/no-go.**
      **DONE 2026-08-16.** 251/251 files, 0 parse errors, 0 unclassified items.
      **9,361 of 12,500 imperative sites (74.9%) mechanically lowerable.** The
      only large bail bucket is `unknown-callee-abi` — 2,997 sites over **233
      distinct callees** (128 already defined in the port), exactly as budgeted;
      every other bucket is under 100 sites. Report: `tools/sm83xlat/coverage.md`.
      **GO.** Three of this plan's own figures were corrected in the process —
      see "Stage 0 corrections" below.
- [x] **Stage 1 — symbols & constants.** DONE: 99.96% of referenced symbols resolve (acceptance >=95%). `resolve.py` + `pretsyms.py` + `symfile.py`; the address problem was retired by reading rgblink's own `pokeyellow.sym` rather than reproducing rgbasm's section allocator. Found a port defect — `wPlayerCoins` off by one — see the Stage 1 note below. ORIGINAL TEXT: The RAM-symbol half is **built as
      prework**: `build_symbols.py` → `tables/symbols.json`, 214 pret↔port pairs,
      0 ambiguous, 0 address conflicts, with `tests/test_rename_invariance.py`
      pinning that it works before *or* after Workstream B. Remaining for this
      stage: `constants.json` (the `EVENT_*`/`TEXT_*`/`PAD_*`/`MUSIC_*`/`SPRITE_*`
      resolution, which comes from `constants/*.asm`, not `ram/*.asm` — note the
      398 `unmatched` names in the prework report are largely this category).
      *Acceptance:* ≥95% of symbols **referenced by scripts** resolve
- [x] **Stage 2 — IR, CFG, dataflow.** DONE: `ir.py` reproduces the Stage 0 census independently (adjacent 667 vs 665, separated 104 vs 98, callee 142 vs 150, cross-block 0 vs 0, total 913 vs 913). ORIGINAL TEXT: *Acceptance gate:* the tool independently
      reproduces the Stage 0 branch census in `tools/sm83xlat/coverage.md`, whose
      bucket definitions are written down, over a branch population independently
      confirmed at **913 active / 920 total**.
      **The old gate — "reproduces 48.4 / 20.5 / 31.1" — is RETIRED and must not
      be reinstated.** Those proportions cannot be reproduced because the
      definition behind them was never recorded, and a gate against an
      unreproducible number gates nothing. The branch COUNT does reproduce
      exactly (920 = 913 + 7 inside `IF DEF(_DEBUG)` blocks), so nothing is
      missing from the corpus; only the bucketing is undefined. See the Stage 0
      corrections below
- [x] Decide and record the predef strategy: direct call under `DEVIATION{class=banking}`, the plan's sanctioned alternative, plus a dataflow guard — if A is live after the site the region BAILS, because pret's predef leaves the id in A and a direct call does not (31 sites bail on exactly that)
- [x] **Stage 3 — lowering + emitter**, head of the distribution; target the 114
      files with ≤20 imperative lines first
- [x] **Stage 4 — `pallet_town.asm` regression.** DONE, zero tool bugs: 8 routines differ, 3 auto-classified and 5 hand-inspected 1:1 against pret. Two findings point at the HAND port instead — a reorder, and a fused store that loses the flags pret's `xor a` clears. ORIGINAL TEXT: Classify every difference as
      `{hand-port-fusion, tool-is-more-literal, tool-bug}`; require **zero**
      `tool-bug`
- [x] **Stage 5 — assemble-all gate.** DONE: **224/224 emitted files assemble clean**. ORIGINAL TEXT: Every emitted file through
      `nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0`, `%include`s by bare
      filename
- [x] **Stage 6 — the tail, reason-code ordered.** Stopped at 1,739/2,530 (68.7%);
      a later tool-strengthening pass took it to **1,861/2,530 (73.6%)** — see
      "Tool-strengthening pass" below for what moved and what is deliberately
      left. The largest remaining bucket is still a CASCADE
      (`target-region-bailed`, 245) rather than 245 independent problems.
      ORIGINAL TEXT: Stop when the marginal reason
      code has <5 sites and hand-port those. A transpiler chasing the last 2% grows
      an unreviewable special case per site
- [ ] Resolve the **18** screen-coord bail sites by hand (16 coord macros + 2 SCREEN_WIDTH stride expressions — see the Stage 0 corrections)
- [x] **Stage 7 — the one shot.** DONE: emitted across 251 pret files into **224** port files (26 maps are split across 2-3 pret sources), with `tables/bail_report.json`, `transpile_report.md` and `tables/abi.json`. Two runs byte-identical. NOT wired into any SRCS list and `pallet_town.asm` NOT overwritten — see the README. ORIGINAL TEXT: Emit across 251 files; commit output +
      `bail_report.json` + `coverage.md` + manifests; freeze the README at that SHA
- [ ] Emit the three registry mappings (see below)
- [ ] Teach `faithdiff` to model map scripts, fed by the emitted correspondence
- [ ] Retire `TrainerTalkHook` and the `TRAINER_TALK` sentinel
- [ ] Retire `TrainerMapScript` + `MapScriptParams` and the `SCRIPT` sentinel
- [ ] Realign the port's text commands so `TX_ASM` does what pret does
- [ ] Fine-comb fan-out: Gemini agents via `agy`, one map each, driven by
      `bail_report.json`
- [ ] Integrate comb findings centrally; regenerate the shared dispatch and tables
- [ ] `lint_pret_labels` 0 in both modes; `make fidelity-full`; `make pixellock`
- [ ] Archive: `git mv docs/current_plan_script_transpiler.md docs/plans/script_transpiler.md`

---

## Tool-strengthening pass (2026-08-17) — 68.7% → 73.6%

Done BEFORE the fine-comb fan-out, deliberately: while the emitted files are
still machine-generated and un-hand-edited, regeneration is free, so a class-level
fix re-lowers every one of its sites and deletes its own bail banners. That stops
being true the moment the comb starts hand-editing, so the leverage was spent
first. **Method: fix the tool, retranspile, measure — never hand-edit the output.**
(Learned by breaking it: `cde1a4642` collapsed 255 banners by editing the emitted
files and the next re-run erased all of it; the collapse now lives in
`transpile.py`.)

`git log --oneline b7a0aba2d..a8c6a0350` is the pass. Regions lowered
1,739 → 1,861; bails 791 → 669. Every step: transpiled TWICE (the tool's own
second-run rule), byte-identical, 224/224 assembling, build green, `pkmn.sym`
unchanged, core fidelity 16/16.

| class | before | after | how |
|---|---:|---:|---|
| `owned-by-generated-assets` banner | 255 | 255 (collapsed) | one line naming the owning asset instead of the verbatim pret dump: −5,975 lines across 67 files |
| `event-range-macro` | 7 | 0 | the port's `events.inc` already had the macros; the table's "hand-work by design" note was false |
| `event-byte-assembly-state` | 34 | 0 | mirrored pret's `*ReuseHL` family in NASM so the ASSEMBLER carries `event_byte` |
| `predef-leaves-id-in-a` | 24 | 1 | direct call + banking DEVIATION; bail now fires on a DIRECT read of A, not on liveness |
| `bank-expression` | 13 | 0 | `BANK(x)` resolved from `pokeyellow.sym` / `pokeyellow.map` |
| `bit-clobbers-live-carry` | 13 | 0 | `setc ah` / `test` / `bt eax,8` — flags MEASURED on the host CPU |
| `host-pointer-in-16bit-reg` | 37 | 29 | `DecodeRLEList`, `WriteOAMBlock` promoted out of `_deliberately_absent` |
| `pointer-domain-unknown` | 22 | 15 | modelled the STACK so `pop hl` recovers a domain |

### Maintainer decisions recorded in this pass

* **The bank left in A after a `predef` is irrelevant to the port** — pret's
  `Predef` restores the parent ROM bank into A, and a flat model has no
  counterpart. Direct call, banking DEVIATION. (The bail's old claim that pret
  "leaves the predef id in A" was simply wrong.)
* **That ruling does NOT extend to `BANK(x)`.** The port's audio engine models the
  audio ROM bank as a VALUE: `PlayMusic` stores C into `wAudioROMBank` and the
  fade path branches on it. So `BANK(x)` is resolved to rgblink's real bank, not
  a placeholder.

### Correctly refusing — do not "fix" these

* `inline-text-db` (11) — the emitter refusing to hand-encode charmap bytes. That
  is the project's Tier-1 rule working; the fix is a generator, not a lowering.
* `pikachu-table-index` (3) — non-linear assembly-time arithmetic across object
  files, which a NASM `equ` genuinely cannot express.
* `hl-half-register-access` (9) — H/L are halves of ESI with no flag-safe 8-bit
  x86 form in 32-bit mode.
* `local-label-scope-collision` (12) — an artifact of other bails; shrinks as
  roots clear, and "fixing" it means deviating from pret label naming.
* `predef-leaves-parent-bank-in-a` (1) — `CeruleanTrashedHouse.asm:14` does
  `predef GetQuantityOfItemInBag` / `and b`, a genuine read of the bank number.

### Two hazards found, both fixed — read before touching this area

* **`AfterBranch`/`Force` event macros must NOT elide the pointer reload.** pret's
  versions assert that earlier code left HL pointing at the flag byte. That
  assertion is about PRET's emitted code; in the port the region that establishes
  the pointer may have BAILED and never been emitted (measured on `SilphCo2F`).
  Honouring it wrote through whatever ESI happened to hold.
* **A `%define` SHADOWS a `%macro` of the same name.** `events.inc` had aliased
  the whole `*ReuseHL` family onto the plain forms; those aliases silently
  disabled the mirrors, clobbered AL where pret preserves it, and — being 1-arg —
  could never have assembled for the 2-arg `AfterBranch` forms at all.

### Four analysis defects fixed along the way

Each had been quietly widening every analysis in the tool, not just its own class:

1. the pointer-domain dataflow was seeded with `(BOT, ())`, and `()` is a REAL
   lattice value (the provably-empty stack), so the first join destroyed the stack
   at every region's first push — the stack needed its own bottom;
2. `_successors` gave a fall-through edge to control-transfer MACROS
   (`predef_jump`/`farjp`/`jpfar`/`tx_pre_jump`), so analyses propagated into the
   next routine;
3. `pop af` did not count as writing A, so A looked live across the
   `push af` … `pop af` bracket scripts use to save it around a predef;
4. the self-test invariant's regex was end-anchored and could not match a line
   with a trailing comment, while the `swap` lowering always emits one — it
   undercounted by exactly the number of swaps.

### What the remaining bails need (none is a lowering rule)

* `text-sound-command-unported` 49 / `text-script-command-unported` 16 — ENGINE
  work. 44 of the 49 are two commands: `sound_get_item_1` (27) and
  `sound_get_key_item` (17). **The maintainer is handling the sound commands.**
* `host-pointer-in-16bit-reg` 29 — needs a per-SITE callee table with per-site
  evidence. 17 of them report `callee <none in range>`, and widening the lookahead
  is UNSAFE: `BillsHouse.asm:63` has an intervening `call
  CheckPikachuFollowingPlayer`, so "first call in the window" binds the load to
  the wrong routine.
* `pointer-domain-unknown` 15 — loop headers whose back-edges join at a different
  stack depth, plus one (`OaksLab.asm:518`) where HL is returned by a callee.
* `target-region-bailed` 245 — cascade. Not work; it falls with its roots.

## Stage 0 corrections to this plan's own figures (measured 2026-08-16)

Each is pinned by a test in `tools/sm83xlat/tests/test_stage0.py`, so a later
change that silently restores the old number fails there rather than being
rediscovered by hand.

1. **The projection surface is 18 lines, not 16** — same 5 files. The two extra
   are `ld bc, SCREEN_WIDTH * 2` (`CeladonMartRoof.asm:204`) and
   `ld bc, SCREEN_WIDTH * 6` (`VermilionDock.asm:55`): row-stride advances
   written as arithmetic rather than through a coord macro, each one line after
   an `hlcoord` in a file already on the bail list. The port's stride is not
   pret's, so they are exactly as unlowerable by rule as the 16 macro sites —
   **counting the macro rather than the geometry is what hid them**, which is
   the same mistake in miniature that rule 7 warns about.
2. **Inline glyph runs are 29 sites in 11 files**, not the two `CeruleanGym`
   lines named above: 8 gyms × (city name + leader name), `Route23`'s 7 badge
   names, `GameCorner`'s 4 currency labels, `BikeShop`'s 2. All must be routed
   into a generator.
3. **The branch census does not reproduce; the branch COUNT does.** See the
   Stage 2 entry. A fourth bucket exists that the quoted three have no slot for:
   **150 branches read a flag written by a CALLEE** (`call GiveItem` / `jr nc`).
   Those are `abi.json` rows, not distances — and treating `call` as
   flag-transparent, which is what makes the cruder census possible at all, reads
   straight through them and credits an earlier `cp` with a CF it never wrote.

Two smaller findings, both now their own reason codes rather than silent `ok`s:

* **`bank-expression`, 22 sites.** `BANK(x)` needs a port-side bank constant per
  target (the hand port renders `ld a, BANK(x)` / `ld c, a` as `mov bl, X_BANK`),
  and `SSAnneCaptainsRoom.asm:49` does `cp BANK("Audio Engine 3")` — the bank of
  a SECTION NAME, compared. Banking being a no-op in the flat model does not make
  either mechanical.
* **`event-byte-assembly-state`, 90 sites.** The `*ReuseHL` / `*ReuseA` event
  macros emit their `ld` only `IF event_byte != ((\1) / 8)`, where `event_byte`
  is a DEF carried in source order across the whole file. One line's expansion
  depends on a line above it, so the IR stage must resolve that state rather than
  assume a fixed expansion.

## Correctness rules the tool must encode

1. **Flag exactness.** Worked failure — `CeruleanGym_Script`:
   `ld hl, wCurrentMapScriptFlags` / `bit BIT_CUR_MAP_LOADED_2,[hl]` /
   `res BIT_CUR_MAP_LOADED_2,[hl]` / `call nz, .LoadNames`. On SM83 `bit` sets ZF
   and `res` sets **no flags**, so `call nz` reads ZF from two instructions back;
   the natural `and byte [ebp+esi], ~MASK` writes ZF and breaks it. Needs
   per-instruction flag tables, backward liveness, and preservation strategies.
2. **No conditional call/ret in x86.** `call cc, X` → `j<¬cc> .skip / call X /
   .skip:`; `ret cc` needs a local epilogue. 312 sites, all polarity traps.
3. **Counter width.** `dec c / jr nz` entered with C=0 runs 256 times; a widened
   `movzx ecx,bl / dec ecx / jnz` runs ~4 billion and page-faults. Emit `dec bl`
   (C→BL). A zero-guard is **not** equivalent and would be a `DEVIATION`.
4. **Widening follows the quantity's signedness, looked up rather than inferred.**
   GB values are unsigned; the signed set is small and enumerable (see the
   sharpened `asm-translation` rule). The tool never infers sign from surrounding
   code, and never widens at all in practice — see the structural invariant below.
5. **Big-endian GB data** — multi-byte values stay high-byte-first.
6. **Preserve pret labels**; never collapse two into one.
7. **Projection bails.** `dbmapcoord x,y` → `db y,x` is a map coord, identical on
   both sides — 201 uses (with `map_coord_movement`) need **no** projection. The
   only screen-coord sites are **16 lines in 5 files** (GameCorner `hlcoord` ×8,
   BikeShop ×3, CeladonMartRoof ×2, VermilionDock
   `hlcoord`/`hlbgcoord`/`hlowcoord` ×3). The port's stride is context-dependent
   (`SCREEN_WIDTH`=40 vs `text.asm` stride-20 vs runtime `text_row_stride`), so a
   rule here would be a guess. Bail on all 16.

## Design facts that shrink the problem

- **`hf_shadow` is dead code for this corpus** — no H/N consumer occurs, so the
  flag lattice is two bits (Z, C) and any H/N consumer is an immediate bail.
- The lowering table is small enough to **enumerate exhaustively and hand-review**,
  which is the only acceptable posture given rule 1.
- The condition-inversion table is a **single 4-row data table** shared by emitter
  and oracle, property-tested over all 8 (cc × {call, ret}) combinations. One
  place to get polarity wrong, and it has a test.
- **`translation.db:script_labels` (3,766 rows) is the output-path oracle.** Read
  `expect_port_file` rather than inventing a snake_case rule, so the output and
  `lint_pret_labels`' `script_misplaced` cannot disagree by construction.
- **Fall-through across pret labels is first-class.**
  `CeruleanGymMistyPostBattleScript` falls straight into
  `CeruleanGymReceiveTM11` with no branch, so a "routine" is a maximal
  fall-through-connected region carrying multiple pret entry labels — all emitted
  verbatim.

## Two hazards with no textual tell — budget for them

Both are the same shape as the counter-width defect: *the guard is not in the
source*, so a reviewer diffing pret against output sees nothing wrong either way.

- **Pointer domain.** `ld hl, wCurrentMapScriptFlags` puts a **GB** address in ESI
  (`[ebp+esi]`); `ld hl, .SomeText` puts a **host** address in ESI (`[esi]`). The
  hand port shows both. Domain must be a propagated type
  (`⊥ ⊑ {GB,HOST} ⊑ ⊤`); `⊤` at a dereference or call site bails.
- **Callee ABI.** Does `farcall X` also need HL loaded? Does the callee return CF
  (`call GiveItem / jr nc`)? `abi.json` must be **fail-closed from day one** — an
  unlisted callee with a live pointer or flag question bails. Expect
  `unknown-callee-abi` to be the largest reason code in the first probe, and
  populating it (a few hundred mostly trivial entries) to be the single biggest
  chunk of real work. Budget it rather than discovering it at Stage 5.

## Structural invariants that make bug classes inexpressible

- **No widening instruction appears in emitted output at all** — a hard
  post-emission grep assertion. The register map already gives 8-bit names for
  every GB register (AL, BH, BL, DH, DL), so a site that appears to need widening
  is a site the tool misunderstood. Rule 4 becomes unfalsifiable: the tool has no
  way to express the bug.
- **No zero-guard is synthesizable** — no code path emits `test r,r / jz` around a
  loop. The `DelayFrames` regression (`d5a24c52`) was a guard that was *added*; a
  tool that cannot add one cannot regress that way.
- **`BAIL{}` is deliberately not a sanctioned annotation kind.** Bailed routines
  emit verbatim pret source as a comment and **no symbol at all**, so the failure
  mode is a loud link error rather than silent wrong behaviour. The tool must also
  **never auto-emit `STUB{}`** — a stub is a behavioural claim requiring human
  sign-off, and manufacturing those at scale is exactly wrong.

## Flag preservation: prefer the obvious fallback

1. **Flag-neutral re-encoding** — `lea esi,[esi+1]` for `inc hl`, covering ~43
   hazard sites at zero instruction cost.
2. **`pushfd`/`popfd` sandwich** — always correct, two instructions, reviewable
   line-for-line against pret. The `CeruleanGym_Script` case emits as
   `test` / `pushfd` / `and` / `popfd` / `jz` / `call`.
3. Targeted repairs for the asymmetric cases (`bit` preserves C on SM83 but x86
   `test` clears it; `swap a` sets Z on SM83 but `rol` does not).
4. **Reordering only as a last resort** — it costs the 1:1 review property, which
   is the whole point.

## Testing the tool

- Unit test per row of the flag table (these are the tool's axioms)
- **Re-run the same dataflow engine over the emitted x86 IR** and assert every
  branch reads a flag written by the lowering of the SM83 instruction that wrote
  it upstream; violation bails, never emits
- **Differential execution oracle** — two small interpreters (SM83's 22 mnemonics,
  x86's ~30 emitted forms) run each translated block from ~1000 randomized states
  **over-weighted to {0, 1, 0xFF}**, asserting identical final registers, touched
  memory, Z, C and successor. Catches polarity inversions, spurious flag writes,
  counter width and endianness — and needs neither nasm nor DOSBox
- Structural assertions over emitted text (no widening instruction; pret→output label
  map injective; synthetic labels collide with no pret label; no `db` byte ≥0x7F
  outside a manifest-routed include; every `%include` a bare filename)
- Determinism: two runs byte-identical

## Predef

**18 distinct targets / 180 call sites**, **14 already defined** in the port
(`HideObject` 57, `ShowObject` 36, `ReplaceTileBlock` 33, `EmotionBubble` 11);
missing `DoInGameTradeDialogue`, `DisplayElevatorFloorMenu`, `OaksAideScript`, +1.
`dos_port/src/engine/predefs.asm` is **excluded from every SRCS list** —
`GetPredefPointer` is a faithful skeleton but `PredefPointers` (pret
`data/predef_pointers.asm`) was never ported. Either port it and revive the
dispatcher (**preferred**), or lower `predef X` to a direct call under
`DEVIATION{class=banking; ...}` since banking is a no-op in the flat DPMI model.
Note pret's `predef` also leaves the predef id in A — assert A is dead after the
call, or bail.

## Port-side abstractions this retires

**`TrainerTalkHook`** (`dos_port/src/scripts/trainer_map_script.asm:117`) is
behaviourally faithful (`call TalkToTrainer / jmp TextScriptEnd`) but **collapses
298 pret labels** (254 inline + 44 `jr`-form) into one port-only name. The
per-trainer labels (`CeruleanGymCooltrainerFText`) and per-header labels
(`CeruleanGymTrainerHeader0`) exist **nowhere** under `dos_port/src` — verified by
grep 2026-08-16; only the table label `<Map>TrainerHeaders` survives. The linter
cannot see this: its rules fire on a *borrowed* pret name in the wrong file, never
on an **absent** one, and no `DEVIATION{}` covers it.

It has already cost a live bug: matching only the inline spelling silently
degraded every trainer on MtMoonB2F / RockTunnel1F / Route9 / Route15 /
ViridianForest to literal text entries — talking never entered `TalkToTrainer`,
the engine walked a non-stream, junk on screen, then a call through garbage. Found
in play 2026-08-15; no gate caught it; Route9/Route15 carried it from the day they
were wired.

Same species: **`TrainerMapScript` + `MapScriptParams`**, and **both text-table
sentinels** (`0xFFFFFFFF` SCRIPT, `0xFFFFFFFE` TRAINER_TALK). Once real routines
exist under pret labels, the port implements pret's actual text-command set with
`TX_ASM` doing what pret does, and all of these disappear.

## Registries the tool must feed

Three, with a mutual-exclusion invariant (`gen_map_scripts.py:50-56` exits on clash):

| registry | file | today |
|---|---|---|
| `SCRIPT_OVERRIDES` (map → `_Script`) | `gen_map_scripts.py` | 1 entry |
| `SCRIPT_OVERRIDES` (text label → routine) | `gen_npc_dialogs.py` | 1 entry |
| `WIRED_MAPS` (driver + scenario) | `gen_map_script_tables.py` | 13 maps |

Hand-curating 300 residue bodies through a 1-entry dict does not scale — the tool
must **emit** these mappings.

## The witness: teach faithdiff to cover scripts

faithdiff skips map scripts today (macro-heavy, would need per-map suppressions) —
a consequence of hand-translation drifting structurally. A 1:1 transpile creates
exact call-graph correspondence, which is faithdiff's precondition, and the tool
can emit the pret-label → port-label correspondence as a byproduct.

This matters because scenarios do not scale: the manifest holds **85 scenarios**,
each with a Lua navigation script, a `DEBUG_*` build flag, a manifest entry and a
golden. Per-map scenarios for 251 maps is not viable. With faithdiff carrying the
structural load, goldens stay behavioural spot-checks.

## Fine-comb fan-out (Gemini via `agy`)

Once Stage 7 has emitted output and `bail_report.json`, inspection and correction
is breadth work over many small independent files, each with an exact reference to
diff against. `script_misplaced` forces one file per map at
`dos_port/src/scripts/<snake_case>.asm`, so agents touch disjoint files.

Per-agent brief: one map; diff emitted NASM against its pret source line by line;
work that map's `bail_report.json` entries first; check flag fidelity at branches,
symbol mapping, and pointer domain at every deref and call site; **mirror pret
behaviour** — translate what pret does, sequence for sequence; cite `file:line` on
every finding.

```sh
agy --model gemini-3.7-flash-high --effort high \
    --dangerously-skip-permissions --print-timeout 15m \
    -p "PROMPT TEXT" > /path/to/log 2>&1
```

Traps, each of which has produced a silent-looking failure:
- `-p` is required (no TTY in a background shell) and **the prompt is its VALUE** —
  a trailing positional is silently ignored and the model answers an empty prompt
  with exit code 0
- `--dangerously-skip-permissions` is required or headless auto-denies `read_file`;
  do **not** add `--sandbox` (breaks MCP)
- agy's MCP config is `~/.gemini/config/mcp_config.json`, not the repo `.mcp.json`
- `root_register` `agent_kind` must be **`antigravity`** — `gemini`/`agy` are
  rejected, quietly, leaving claims non-existent and liveness untracked
- `context_open` must use the **MAIN** repo path even from a worktree, or the
  memory space silently forks
- judge results by **reasoning scope**, not just the presence of citations

Direct reviewers at branches, bail markers, and the 16 projection sites — not at
line count. `OaksLab.asm`, the worst file at 1,151 lines, holds 69 labels and only
**40 conditional branches**; `ld` (339) and `call` (118) dominate and lower
mechanically.

## Reuse rather than rebuild

- `dos_port/include/events.inc` — `CheckEvent`/`SetEvent`/`ResetEvent`/
  `SetEventReuseHL` already exist as NASM macros; ~300 lines pass through ~1:1.
  They **clobber AL** and `CheckEvent` **sets ZF**, so they enter the IR as
  pseudo-instructions with declared clobbers or the dataflow is wrong around them
- `dos_port/src/scripts/pallet_town.asm` — reference output shape and Stage-4
  fixture (274 lines vs pret's 316). Known intentional deltas: the hand-port fused
  `ld a,[wYCoord]`+`cp 0` into one `cmp`; the tool emits the literal
  two-instruction form, with fusion an optional peephole
- `dos_port/include/coords.inc`, `predef.inc`, `gb_macros.inc`, `data_macros.inc`
- `dos_port/tools/generators/gen_npc_dialogs.py` — the `SCRIPT_OVERRIDES` /
  sentinel seam that consumes the text and trainer manifests
