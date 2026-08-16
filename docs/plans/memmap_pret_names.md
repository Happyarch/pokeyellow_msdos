# current_plan_memmap_pret_names — realign `gb_memmap.inc` symbol names with pret

**Owner:** one Opus agent, end to end, on **master** — deliberately no worktree.
**Runs ALONE.** Not because of its file set but because of its oracle: the
verification is `diff pkmn.sym` against a baseline, and any concurrent merge voids
that baseline. Re-baseline after `current_plan_data_path_mirror` lands.

---

## Why

"Preserve pret Labels" (CLAUDE.md) covers data labels, not just routines, so the
port's `W_Y_COORD`-style names are an untagged standing deviation from a hard
rule. Realigning them:

- removes the script transpiler's symbol-mapping table as a source of error
- makes symbol references diffable against pret
- is the same principle as `current_plan_data_path_mirror`, applied to the naming
  axis instead of the path axis

## What is actually there (measured 2026-08-16)

`dos_port/include/gb_memmap.inc` is **hand-maintained** — no generator writes it,
no `DO NOT EDIT` header; every tool that touches it treats it as an *input*
(`audit_memmap.py`, `gen_battle_text.py`, `gen_map_script_tables.py`,
`golden_diff.py`). 2366 lines, **1426 `equ` lines / 1416 unique names**:

| family | count | action |
|---|---|---|
| SCREAMING_SNAKE legacy (`W_Y_COORD`, `H_MONEY`) | 620 | **the rename targets** |
| already lowercase pret-style (`wEnemyMonType1`) | 724 | nothing to do |
| constants (`MAX_WINDOWS`, `BIT_SPINNING`, `WIN_*`) and port-only HAL names (`GB_VRAM0`, `WIN_CLIP_W`) | remainder | **never renamed** |

**Zero of these equs are declared `global` anywhere in the tree.** They are pure
assembly-time constants; the linker never resolves them by name. That is what
makes the oracle below work.

## Stages

- [x] Establish build determinism: build twice unchanged, confirm `pkmn.sym` is
      byte-identical both times. **PASSED** — second build forced by touching
      `gb_memmap.inc` so 290 objects recompiled; `pkmn.sym` byte-identical.
- [x] Capture the baseline: taken at `51a2b22cc` (after A and C merged), 14158
      lines. **TRAP FOUND:** `pixellock`/`goldencheck`/`fidelity` build with
      `-D DEBUG_*`, and the NASMFLAGS stamp guard forces a full rebuild on a flag
      change — so a `pkmn.sym` left on disk after any golden run is a DEBUG
      symfile and diffs against a plain baseline by ~28k lines. Always re-run a
      plain `make -C dos_port` immediately before capturing or comparing.
- [x] **Mapping built (prework, 2026-08-16).**
      `dos_port/tools/sm83xlat/build_symbols.py` → `tables/symbols.json`, the same
      artifact the transpiler consumes. **214 rename candidates, 0 ambiguous, 0
      address conflicts.** Method and its two rejected alternatives are recorded
      in `dos_port/tools/sm83xlat/README.md`
- [x] Review the 214 candidates by hand before renaming anything (the tool
      reports; it does not decide). **This changed the work.** All 76
      `confirmed` already had the pret name DEFINED in `gb_memmap.inc`, so they
      are alias MERGES (delete the legacy definition), not renames; all 138
      `name_only` are true renames. Eleven aliases were defined BY REFERENCE
      (`wPlayerMoney equ W_PLAYER_MONEY`) and had to be inlined to their literal
      before the legacy definition was deleted. Recorded in
      `memmap-rename-confirmed-76-are-alias-merges`.
- [x] Fold the duplicate definitions. **The plan said ten, "all value-identical";
      nine are.** `hAutoBGTransferEnabled` was defined once as the literal
      `0xFFBA` and once BY REFERENCE to `H_AUTO_BG_TRANSFER_EN`, which is itself
      `0xFFBA` — so they agree only transitively. Four of the ten (`W_CUR_MAP`,
      `W_Y_COORD`, `W_X_COORD`, `H_MONEY`) are inside the 214 and were folded by
      the rename itself; the other six were folded in `e7f8730e7`.
- [x] Batch 1 — HRAM block, 65 names (`a7990fba7`)
- [x] Batch 2 — player/map/overworld state, 47 names (`5ebfa994f`)
- [x] Batch 3 — flags/status bits, 21 names
- [x] Batch 4 — party/box/mon structs, 23 names
- [x] Batch 5 — the long tail, 58 names
- [x] Final `diff` against the baseline `pkmn.sym`: **EMPTY** after every batch
      and at the end.
- [x] Archive: `git mv docs/current_plan_memmap_pret_names.md docs/plans/memmap_pret_names.md`

## Outcome (2026-08-16)

214 of 214 renamed. `build_symbols.py --report`, re-derived against the realigned
file, now reports **0 rename candidates and 0 duplicate names** (from 214 and 10).
`gb_memmap.inc` went 1426 → 1340 `equ` lines. The 398 SCREAMING_SNAKE names that
remain are the `unmatched` set this plan scoped out: constants and port-only HAL
names with no pret RAM counterpart.

### Five oracles, not two

The plan's two were necessary and not sufficient:

1. **`make check`** — exit 0 after every batch. **Blind to
   `dos_port/src/scripts/`**: those 223 transpiler-emitted files are in no
   `_SRCS` list and `check:` iterates `ALL_SRCS`, yet 266 of the swept sites live
   there. Closed by assembling all 225 explicitly after every batch (0 failures).
2. **`pkmn.sym` diff** — empty after every batch. **Blind to `equ` VALUES**,
   because `gen_symfile.py` filters absolutes out. An alias merge that kept a
   pret definition with a DIFFERENT value would have silently moved every use
   site and this oracle would still read empty.
3. **Resolved-address equivalence** — added to cover exactly that gap. Both
   versions of `gb_memmap.inc` parsed and every symbol resolved through its
   expression chain: **all 214 resolve to the identical address, 0 skipped,
   0 changed.**
4. **Section bytes** — `objdump -s -j .text -j .data` on a rebuild of the pre-B
   commit vs the post-B build: **byte-identical**. The rename provably changed
   nothing executable, which is why no behavioural tier was needed to justify it
   (core `fidelity` was run anyway: 16/16, no gaps).
5. **Independent regeneration** — re-running `transpile.py`, which reads
   `gb_memmap.inc` live, reproduced all 223 emitted script files **byte-identically
   to the mechanical sweep**. Two mechanisms, arrived at differently, agreeing.

### Deliberately left out of scope

Ten legacy `equ`s outside the 214 share an address with an already-defined
pret-style name, because name-normalization cannot match a TRUNCATED legacy
spelling (`H_AUTO_BG_TRANSFER_EN` vs `hAutoBGTransferEnabled`) or a pret label
that rgbasm generates from a struct macro rather than writing literally
(`W_PARTY_MON1_MOVES` vs `wPartyMon1Moves`). **Do not merge these mechanically on
the address join** — at least two are union collisions, not aliases:
`H_SERIAL_CONN_STATUS` and `hSwapItemQuantity` merely share `0xFFAA`, and
`W_SPRITE_PLAYER_PICTURE_ID` shares `0xC100` with the block marker
`wSpriteDataStart`. That is the same false-pair trap that killed the pure address
join during the prework. Each needs its own reading.

`regression-memmap-wplayercoins-off-by-one` is NOT fixed here and must not ride
inside a rename batch: it changes an `equ` VALUE, which oracle 2 cannot see at
all, so a batch carrying it would go green on a false pass. It needs its own
commit and a registered slots scenario.

## The mapping (built as prework — do not re-derive it)

`dos_port/tools/sm83xlat/build_symbols.py --report` regenerates the summary;
`tables/symbols.json` is the table. Measured 2026-08-16:

```
  confirmed        76   name matches AND address agrees
  name_only       138   name matches, no address on both sides to check
  addr_conflict     0   name matches but addresses differ
  ambiguous         0   several pret names normalize the same
  unmatched       398   no pret RAM label (constants, port-only HAL) — out of scope
  duplicate names  10   fold these during the rename
```

**Match on the normalized NAME against pret `ram/*.asm`; use the address only to
cross-check.** Two alternatives were measured and rejected, and both failure
modes are worth knowing before anyone "improves" this:

- **Trailing comments** — dead. 312 of 1426 lines (21.9%), and the oldest block
  (`:80-86`, holding `W_CUR_MAP`/`W_Y_COORD`/`W_X_COORD`) has none.
- **Pure address join** — weak *and unsafe*. It matched only 67 of 619 and
  produced wrong pairs two ways: non-addresses join on bare value (`MAX_WINDOWS`
  = 6, a window count, matched a pret `*_SIZE` that also equals 6), and pret RAM
  is full of **unions** (45 `UNION`/`NEXTU`/`ENDU` in `ram/hram.asm`, 130 in
  `ram/wram.asm`), so every HRAM scratch address legitimately carries 3-4 names.

Name matching also avoids the real blocker: pret's 11 WRAM `SECTION` directives
carry no explicit addresses, so deriving them from source means reproducing
rgbasm's section allocator.

Ambiguity resolves on the **storage-class prefix** — the normalizer drops it, so
`hSpriteIndex`/`wSpriteIndex` collide, but the port's `H_SPRITE_INDEX` keeps the
class. That took ambiguous 5 → 0.

`addr_conflict` is the bucket to watch on any re-run: a name match whose
addresses disagree means the port symbol and the pret symbol it resembles are
**not the same storage**. It is 0 today; if it ever isn't, read every entry.

## Method — two oracles, no parser

NASM exposes no reusable parser (no `libnasm`, and `nasm -e` only gives
preprocessed output, which flattens the `%include` structure). These equs vanish
into immediates, so nothing is recoverable from the binary either. Use the
assembler itself, twice:

### Oracle 1 — NASM enumerates every use site

Rename the definition and **delete the old name**. Every unrenamed use becomes an
undefined symbol, reported by NASM's own parser with file and line. Rewrite only
the sites the assembler named; iterate until it assembles.

```sh
make -C dos_port check    # Makefile:3821 — assembles every ALL_SRCS file to /dev/null
```

### Oracle 2 — `pkmn.sym` proves nothing moved

> ⚠ **Do NOT compare raw `.o` or `PKMN.EXE` bytes.** `nasm -f coff` writes every
> `equ` as a COFF **absolute** symbol and `ld` carries them into the EXE (485,613
> absolute entries of 501,299 total), so a rename genuinely *does* change the EXE.
> `.o` files additionally carry a COFF timestamp at byte offset 4 and differ
> build-to-build regardless.

Compare **`pkmn.sym`** instead. `dos_port/tools/generators/gen_symfile.py:17-18`
explicitly drops absolute symbols ("every .o re-embeds all `equ` constants — ~300k
junk entries"), keeping only `.text/.data/.bss` symbols at their final linked
VMAs. A pure `equ` rename cannot move a single one.

```sh
make -C dos_port && cp dos_port/pkmn.sym /tmp/sym.before
# ... rename one batch, iterate `make check` until it assembles ...
make -C dos_port && diff /tmp/sym.before dos_port/pkmn.sym   # must be EMPTY
```

Optional belt-and-braces: compare section contents with
`i586-pc-msdosdjgpp-objdump -s -j .text -j .data`. `PKMN.EXE`'s own header
timestamp is 0, so section bytes are reproducible.

## Traps

**Comment-scraping is not a viable mapping source.** Only 312 of 1426 equ lines
(21.9%) carry a pret label in a trailing comment, and the oldest block —
`:80-86`, containing `W_CUR_MAP`, `W_Y_COORD`, `W_X_COORD` — has **no comments at
all**. Its duplicates further down do. Use the address join, not the comments.

**Word-boundary anchoring is required.** `W_CUR_MAP` is a strict prefix of
`W_CUR_MAP_HEADER`, `W_CUR_MAP_TILESET`, `W_CUR_MAP_HEIGHT`,
`W_CUR_MAP_CONNECTIONS`, `W_CUR_MAP_DATA_PTR`, `W_CUR_MAP_SCRIPT_PTR`,
`W_CUR_MAP_TEXT_PTR`, `W_CUR_MAP_HEADER_END`; likewise `H_DIVIDEND`/`H_DIVIDEND2`,
`H_DIVISOR`/`H_DIVISOR2`, `H_QUOTIENT`/`H_QUOTIENT2`. A plain replace corrupts
them. `\bW_CUR_MAP\b` does **not** match inside `W_CUR_MAP_HEADER` because `_` is a
word character, which resolves the entire hazard class.

**`static_gate` cannot see this work at all.** These names are not `global`, never
enter `port_defs`/`labels`/`externs`, and are not pret labels, so none of the
linter classes fire. The only automated guards are:

1. NASM's unresolved-symbol error (Oracle 1)
2. two generators that parse the file and hard-fail on a missing symbol —
   `gen_battle_text.py:133` (`KeyError: text addr symbol … not in gb_memmap.inc`)
   and `gen_map_script_tables.py:326-330` (`check_against_gb_memmap`)

Run `make -C dos_port assets` at least once per batch to exercise (2). It is not
run by the commit hook.

**Include-path variety.** 240 files use `%include "gb_memmap.inc"` (via
`-I include/`) and 10 use `%include "include/gb_memmap.inc"` (via `-I .`). Both
resolve; the rename touches names inside, not the include lines.

**Generated assets reference memmap names.** Six `assets/*.inc` files use `GB_*`
symbols (`audio_constants.inc`, `bg_map_attributes.inc`, `player_sprite.inc`,
`red_bike_sprite.inc`, `seel_sprite.inc`, `surfing_pikachu_sprite.inc`). Those are
port-only HAL names and are **out of scope**, but confirm rather than assume if a
batch touches anything `GB_`-prefixed.

## Evidence

- `dos_port/include/gb_memmap.inc` — 2366 lines, hand-maintained, `%ifndef` guarded `:6-7`
- Zero `global` intersection: all 1416 equ names × all 1874 `global` declarations
  across `dos_port/src` + `dos_port/include` → empty
- `dos_port/tools/generators/gen_symfile.py:17-18` — absolute-symbol filter
- `dos_port/Makefile:12-18` (NASMFLAGS, no `-g`), `:3698-3701` (link + symfile), `:3821` (check)
- Hard-failing generators: `gen_battle_text.py:133`, `gen_map_script_tables.py:326-330`
