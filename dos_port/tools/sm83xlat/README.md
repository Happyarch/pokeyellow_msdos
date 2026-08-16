# sm83xlat — one-shot SM83 → x86 transpiler for pret `scripts/`

**STATUS: Stage 0 (parse & probe) complete. No IR, no lowering, no emitted x86.**

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

```sh
python3 dos_port/tools/sm83xlat/stage0.py            # write coverage.md + tables/
python3 dos_port/tools/sm83xlat/stage0.py --report   # print, write nothing
python3 -m pytest dos_port/tools/sm83xlat/tests/ -q
```

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
