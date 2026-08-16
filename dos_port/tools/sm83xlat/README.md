# sm83xlat — one-shot SM83 → x86 transpiler for pret `scripts/`

**STATUS: prework only. The transpiler itself is NOT built yet.**
What exists today is `build_symbols.py`, the shared symbol mapping, staged ahead
of the fork so both consuming workstreams read one artifact.

Plan: `docs/current_plan_script_transpiler.md`.

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
