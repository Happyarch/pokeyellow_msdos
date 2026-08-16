# sm83xlat — one-shot SM83 → x86 transpiler for pret `scripts/`

**STATUS: Stages 0-7 complete. Output emitted, committed, and hand-maintained
from here.** The fine-comb fan-out (Gemini via `agy`) has NOT been started —
another session sequences it.

Plan: `docs/current_plan_script_transpiler.md`.

| module | stage | what it is |
|---|---|---|
| `build_symbols.py` | prework | the shared pret↔port RAM symbol mapping (below) |
| `lexer.py` | 0 | line lexer — every line categorised, operands split |
| `isa.py` | 0 | the SM83 instruction + flag table. The tool's axioms |
| `macros.py` | 0 | classification and declared effects for every rgbasm macro `scripts/` uses |
| `pretsyms.py` | 0 | the pret-side symbol universe (RAM, constants, labels) |
| `parser.py` | 0 | conditional assembly, label scope, item classification |
| `probe.py` | 0 | coverage counter, branch census, callee inventory |
| `stage0.py` | 0 | CLI → `coverage.md`, `tables/probe.json`, `tables/callees.json` |
| `pretsyms.py` / `symfile.py` / `resolve.py` | 1 | the pret name universe, rgblink's `pokeyellow.sym`, and the one answer to "what does the port call this?" |
| `ir.py` | 2 | regions, CFG, flag liveness, pointer-domain propagation |
| `emit.py` | 3 | the lowering table and the structural invariants |
| `transpile.py` | 3-7 | the one shot → `dos_port/src/scripts/*.asm`, `tables/bail_report.json`, `transpile_report.md` |
| `stage4_pallet_town.py` | 4 | the hand-port regression fixture |

```sh
python3 dos_port/tools/sm83xlat/stage0.py             # coverage.md + tables/
python3 dos_port/tools/sm83xlat/transpile.py --assemble   # THE ONE SHOT + nasm gate
python3 dos_port/tools/sm83xlat/stage4_pallet_town.py     # the regression fixture
python3 -m pytest dos_port/tools/sm83xlat/tests/ -q
```

**The root build must run first.** `resolve.py` reads `pokeyellow.sym`, which
`make` in the repository root produces; without it Stage 1 has no addresses.

---

## Stages 1-7 result (2026-08-16)

**1,729 of 2,530 regions lowered (68.3%), and all 224 emitted files assemble
clean** under the Makefile's own flags. Two runs are byte-identical. Full report
in `transpile_report.md`; the bail inventory is `tables/bail_report.json`.

251 pret files merge into **224** port files: 26 maps are split across two or
three pret sources (`BillsHouse.asm` + `BillsHouse_2.asm`), and emitting them one
at a time made the second overwrite the first — which is why constants defined in
one half read as undefined in the other.

### Merge order — READ THIS BEFORE MERGING AFTER WORKSTREAM B

**This output is NOT rename-invariant, and it cannot be made so.** 268 sites
across 61 emitted files name a `SCREAMING_SNAKE` equ (`W_Y_COORD`,
`W_SIMULATED_JOYPAD_STATES_INDEX`, …) that the memmap rename deletes. The plan's
"safe alongside `current_plan_memmap_pret_names`" is true of the symbol
**mapping** — which joins on the normalized name — and was never true of emitted
**output**, which bakes in whichever spelling was current when it ran.

Emitting the pret spelling with an `%ifndef` alias was tried and **does not
work**: `%ifndef` tests preprocessor `%define`s, and `gb_memmap.inc` uses `equ`,
an assembly-time label the preprocessor cannot see. The guard never fires, so the
alias becomes a redefinition the moment the rename lands. NASM has no guard for
an `equ`.

Measured by simulating the whole rename over `gb_memmap.inc` and re-assembling:
**126/224 files survive**, failing as `inconsistently redefined` and
`W_EVENT_FLAGS not defined`. That second one is the point — **`events.inc`
references `W_EVENT_FLAGS` itself**, so the rename already has to sweep its
consumers, and these 61 files are simply more consumers.

**So: include `dos_port/src/scripts/` in Workstream B's rename sweep.** Or merge
C first. Either works; doing neither leaves 98 files failing to assemble.
Re-running `transpile.py` after B lands also fixes it, since the resolver reads
the memmap live.

### Nothing is wired into the build, deliberately

The emitted files are in no `SRCS` list. Most reference callees the port does not
define, which is the designed witness — an `extern` the linker enumerates — but a
witness is only useful when someone is looking at it, not when it breaks
everyone's build. `pallet_town.asm` was **not** overwritten; its tool output went
to `emitted_shadow/` and is the Stage 4 fixture.

**Two whole classes of region are deliberately NOT emitted, and the static gate
is what found them.** A first run reported 914 `dup_def` violations: the emitted
battle-text streams duplicated `assets/trainer_headers.inc`, which already owns
every one of them. A second reported four more — `Mansion1Script_Switches` and
siblings exist as ret-stubs in `hidden_object_stubs.asm`. Emitting a body for a
stub is a duplicate definition, not a retirement: retiring a stub means DELETING
it and repointing every extern comment, which is a deliberate act and not
something a transpiler gets to do as a side effect. Both classes now bail
(`owned-by-generated-assets`, 268 regions) and the labels are externed.

The gate also caught a subtler one: a bailed region copies its pret source
verbatim as a comment, and one of those comments carried a `; BUG(...)` that
`lint_pret_labels` read — correctly, by its own rules — as a free-form BUG claim
this port was making. Copied annotation keywords are moved out of annotation
position now.

### Stage 1 found a port defect, and the emitter fails closed on it

Cross-checking `gb_memmap.inc` against the linker's own table (684 same-spelled
symbols) decomposes as **684 agree, 25 SRAM flat-bank rebases, 21 documented
relocations, 9 unexplained**. One of the nine is referenced by scripts:
**`wPlayerCoins` is at `0xD5A4` in the port and `0xD5A3` in the linker's table**,
between `wUnusedMapVariable` (0xD5A2, matching) and `wToggleableObjectFlags`
(0xD5A5). Five script sites touch it. The emitter refuses to name any symbol whose
port address contradicts the linker's without a documented reason, so those sites
bail instead of quietly reading the wrong byte. Recorded as
`regression-memmap-wplayercoins-off-by-one`.

### Stage 2 gate: the CFG reproduces the Stage 0 census independently

| bucket | Stage 0 (local walk) | Stage 2 (CFG + liveness) |
|---|---:|---:|
| adjacent | 665 | 667 |
| separated | 98 | 104 |
| callee-flag-contract | 150 | 142 |
| cross-block | 0 | 0 |
| **total** | **913** | **913** |

Same population, same shape, and the small movements are exactly where a CFG
should differ from source order — it follows real predecessors. The two share no
machinery, which is what makes the agreement worth anything.

### Stage 4: zero tool bugs

Eight routines differ from the hand-written `pallet_town.asm`. Three classify
automatically (`hand-port-reorder`, `hand-port-fusion-loses-flags`,
`text-model-divergence`); the other five were inspected by hand and the tool is
1:1 with pret in every one — pret imperative lines vs emitted x86 read 17/17,
26/27, 24/25, 13/13, with the `+1`s being `ret cc` expanding to skip/ret/label.

Two findings point the other way, at the HAND port:
* `PalletTown_Script` — the hand port **reordered** `ld hl, ScriptPointers` and
  `ld a, [wPalletTownCurScript]`; pret has them the other way round.
* `PalletTownPikachuBattleScript` — pret's `xor a` clears the flags, and the hand
  port's fused `mov byte [X], 0` does not. Equivalent for the stored value, not
  for a downstream flag reader. Latent, since nothing reads a flag there today.

## Stage 0 result (2026-08-16)

251/251 files parse, **zero parse errors** — the stage's acceptance. Full report
in `coverage.md`; the headline is **9,361 of 12,500 imperative sites (74.9%)
mechanically lowerable**, with `unknown-callee-abi` the only large bail bucket
(2,997 sites over **233 distinct callees**, 128 of which the port already
defines). Everything else is under 100 sites.

Three measurements in the plan did not survive contact with the corpus, and each
is pinned by a test in `tests/test_stage0.py` so it cannot quietly revert:

* **The projection surface is 18 lines, not 16.** `ld bc, SCREEN_WIDTH * 2`
  (CeladonMartRoof) and `ld bc, SCREEN_WIDTH * 6` (VermilionDock) are row-stride
  advances written as arithmetic instead of through a coord macro, each one line
  after an `hlcoord` in a file already on the bail list. The port's stride is not
  pret's, so they are exactly as unlowerable as the 16 macro sites — counting the
  macro rather than the geometry is what hid them. Same 5 files.
* **Inline glyph runs are 29 sites in 11 files, not the two CeruleanGym lines the
  plan names.** 8 gyms × (city + leader), Route23's 7 badge names, GameCorner's 4
  currency labels, BikeShop's 2.
* **The branch census does not reproduce, and the branch COUNT does.**
  920 = 913 active + 7 inside `IF DEF(_DEBUG)` blocks. The quoted proportions
  (48.4 / 20.5 / 31.1) cannot be reproduced because the definition behind them
  was never recorded; a deliberately cruder re-bucketing lands in the same family
  (47.2 / 26.5 / 26.3) but is not a match, and identifying it is not claimed.
  See `coverage.md` for why this matters to Stage 2's acceptance gate.

The census work also surfaced a fourth bucket the quoted figures have no slot
for: **150 branches read a flag written by a CALLEE** (`call GiveItem` / `jr nc`).
Treating `call` as flag-transparent — which is what makes the crude census
possible — reads straight through those and credits an earlier `cp` with a CF it
never wrote. They are `abi.json` rows, not distances.

---

## This tool is ONE-SHOT, and that is a structural claim

When the transpiler lands it will run **once**, over pret's 251 `scripts/*.asm`,
and its output will be committed to `dos_port/src/scripts/` and **hand-maintained
from then on**. It is migration scaffolding, not a generator.

Concretely, and deliberately:

- It lives in `dos_port/tools/sm83xlat/`, **not** `dos_port/tools/generators/`.
  Everything under `generators/` is re-run by `make assets` and writes gitignored
  outputs; filing this there would invite someone to regenerate over hand edits
  and silently discard them.
- It has **no Makefile wiring at all**, by design.
- Its output carries **no `DO NOT EDIT` header**. Hand-editing those files is the
  normal, expected way they change.

This is the third tier described in the `project-conventions` skill: *Tier 2,
seeded once by a tool*. Tier 1 (`assets/*.inc`) is machine-owned and regenerated;
Tier 2 is human-owned; a tool-seeded file is Tier 2 that a tool happened to type
the first draft of.

When the one shot is taken, record its git SHA here.

---

## `build_symbols.py` — the shared symbol mapping

Maps the port's `gb_memmap.inc` names to pret's RAM label names, writing
`tables/symbols.json`. Read in both directions by two workstreams:

| consumer | direction |
|---|---|
| `docs/current_plan_memmap_pret_names.md` (the rename) | port name → pret name |
| `docs/current_plan_script_transpiler.md` (this tool) | pret name → port name |

```sh
python3 dos_port/tools/sm83xlat/build_symbols.py            # write tables/symbols.json
python3 dos_port/tools/sm83xlat/build_symbols.py --report   # summary, writes nothing
python3 -m pytest dos_port/tools/sm83xlat/tests/ -q
```

### Method: normalized NAME match, ADDRESS as cross-check

Three sources were measured before settling on this (2026-08-16):

| source | result |
|---|---|
| trailing comments in `gb_memmap.inc` | **dead** — only 312 of 1426 equ lines carry a pret label (21.9%), and the oldest block (lines 80-86: `W_CUR_MAP`, `W_Y_COORD`, `W_X_COORD`) has none |
| address join against the port's own pret-style equs | **weak and unsafe alone** — 67 of 619, with wrong pairs |
| normalized name match against pret `ram/*.asm` | **strong** — 214 matches, 0 ambiguous, 0 conflicts |

The address join failed in two distinct ways worth remembering:

1. **Non-addresses join on value.** `MAX_WINDOWS` (= 6, a window count) matched a
   pret `*_SIZE` constant that also equals 6.
2. **pret RAM is full of unions.** `ram/hram.asm` has 45 `UNION`/`NEXTU`/`ENDU`
   directives and `ram/wram.asm` has 130, so 3-4 names legitimately share one
   address. Every HRAM scratch address matched a pile of names at once.

Name matching also sidesteps the real blocker: pret's 11 WRAM `SECTION`
directives carry **no explicit addresses**, so deriving them from source means
reproducing rgbasm's section allocator — fragile, and wrong quietly.

So the tool matches on the normalized name and uses the address, where both sides
have one, purely to **confirm or contradict**. The `addr_conflict` bucket is the
most valuable output: a name match whose addresses disagree means the port symbol
and the pret symbol it resembles are **not the same storage**.

### Current output (2026-08-16)

```
port gb_memmap.inc : 1426 equ lines, 612 SCREAMING_SNAKE
pret ram/*.asm     : 1286 RAM labels

  confirmed        76   name matches AND address agrees
  name_only       138   name matches, no address on both sides to check
  addr_conflict     0   name matches but addresses differ — review each
  ambiguous         0   several pret names normalize the same
  unmatched       398   no pret RAM label (constants, port-only HAL)
  duplicate names  10   fold these during the rename
```

**214 rename candidates ready, 0 needing review.** The 398 unmatched are
overwhelmingly hardware/audio constants (`AUD3WAVE_SIZE`, `ANIM_FLOWER_TILE_ID`)
that come from `constants/*.asm` rather than `ram/*.asm` — a different category,
largely out of scope for the rename.

Ambiguity resolves on the **storage-class prefix**: the normalizer drops it, so
`hSpriteIndex` and `wSpriteIndex` collide, but the port's `H_SPRITE_INDEX` keeps
the class and picks `hSpriteIndex`. That took ambiguous 5 → 0.

### Rename invariance

Matching keys on the normalized name, so the pairing is identical before and
after the rename workstream lands. `tests/test_rename_invariance.py` pins this:
it synthesizes the post-rename memmap, re-runs the builder, and asserts the work
queue is empty (214 → 0) with no new conflicts or ambiguity.

That property is what makes the rename and the transpiler **safe to run in
parallel**, and the empty queue doubles as the rename's acceptance test.
