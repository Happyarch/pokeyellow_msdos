# Current Plan: WRAM Expansion by Prefix-Sum Relocation

Replacing the port's ad-hoc "grow in place, displace into free-looking echo gaps"
memory scheme with a systematic one: **the port is a Game Boy that has more WRAM.**

Seeded 2026-08-19 from a maintainer design session. All numbers below are measured
against `pokeyellow.sym` and the tree at `script-linking@18b612b18`; re-measure
rather than quoting them.

## The model

> **`port_addr = pret_addr + Σ(growths strictly below it)`**

A buffer that must grow keeps its address. Everything below it is unmoved.
Everything above it shifts up by the growth, and successive growths compose in
address order — each grown buffer's successor begins exactly where it ends. It is
an append, not a repack.

This is the same *operation* the port already performs (displace whatever a growth
overruns); the only change is that the destination is **computed** rather than
hand-picked from whatever gap looked free.

## What we do today, and why it fails

1. A buffer that outgrows its pret slot grows in place at its pret address.
2. Whatever pret symbols that growth overruns are relocated **individually**, to an
   address hand-picked from the echo window by whoever hit the problem. Every such
   comment in `gb_memmap.inc` independently calls its target "free echo RAM"
   without mentioning the others — there was no allocator, just successive authors
   finding gaps.
3. A few go above the GB window entirely when nothing fits (`wTempPic` → `0x21A00`).
4. `gen_pret_ram.py` emits every other pret symbol at its `pokeyellow.sym` address;
   `gb_memmap.inc`'s hand-written defines win where they exist ("it only fills the
   gaps").
5. `ram_address_baseline.json` records the 41 divergences; `check_ram_addresses.py`
   (`static_gate` check 6) fails on a *new* divergence or a baselined symbol *moving*.

**The gate ratchets drift, not correctness.** It has nothing to say about whether a
hand-picked address was sane, which is why `wShadowOAMBackup` and `wLYOverrides`
both sit at `0xF500` with the gate green: both are in the baseline, at that address,
recorded as deliberate.

### "Free echo RAM" is a misnomer that caused the damage

There is no free echo RAM. On hardware `$E000-$FDFF` mirrors `$C000-$DDFF`, so
`0xF500` *is* `0xD500` — which pret populates with `wToggleableObjectFlags` and the
whole `wOaksLabCurScript`…`wRoute6CurScript` run. The port gets away with it only
because it does not implement the mirror (measured: no mirroring code in `src/`;
the arena is flat with `GB_BACKBUF` at `0x12000`). The region is a **port-only
scratch arena that happens to start at 0xE000**, and describing it as a hardware
property is what let two authors each believe they owned `0xF500`.

Under this plan the mirror concept is discarded explicitly: `0xE000+` is WRAM.

### Maintainer ruling 2026-08-19 — echo deferred, with one constraint

Real software never writes echo, so a write there is *always* a bug; making echo a
genuine mirror is deferred to port completion. Two things follow, and the second is
the reason this is written down rather than just deferred:

- The useful implementation is probably a **trap, not a mirror** — the value is in
  flagging a write to echo as the bug it is, which a mirror does not do.
- **Prefix-sum expansion puts real pret WRAM into the echo range.** pret's WRAM top
  `0xDFFF` shifts to `0xEDCB`, so ~3.5 KB of pret symbols land above `0xE000`, and
  a later echo-as-mirror (or echo-as-trap) can no longer tell a bug write from a
  legitimate one. Restoring echo then requires shifting `GB_OAM`/`GB_IO`/HRAM up by
  the expansion — mechanically fine (all symbolic, all generated) but it spends the
  "HRAM never moves" property this layout currently gets for free. The decision
  stays deferrable; the cost is just no longer free at that point.

## Measured growth table

pret `ds` sizes (union lanes → largest lane), **not** address-gap inference —
pret's `NEXTU` blocks make sequential inference wrong, which is the exact bug
`gen_pret_ram.py` was written to avoid.

| pret base | buffer (lane) | pret | port | growth |
|---|---|---|---|---|
| `0xC3A0` | `wTileMap` 40×25 | 360 | 1000 | +640 |
| `0xC508` | union, `wSurroundingTiles` 48×36 lane | 480 | 1728 | +1248 |
| `0xC6E8` | union, `wOverworldMap` `MAP_BORDER=7` lane | 1300 | 2304 | +1004 |
| `0xCD81` | `wTileMapBackup2` 40×25 | 360 | 1000 | +640 |
| | **in-place growth** | | | **+3532** |
| appended | `W_INTRO_ANIM_DATA` 672 + `W_SURF_ANIM_DATA` 704 | — | 1376 | +1376 |
| | **total new WRAM demand** | | | **4908** |

The two staging regions have no pret counterpart (pret addresses that data in ROM;
the port stages it into GB space to keep 16-bit pointer arithmetic faithful), so
they append above the shifted pret WRAM.

### Append property — verified, all four compose exactly

```
0xC3A0 -> 0xC3A0 +1000 = 0xC788 | successor pret 0xC508 -> 0xC788   OK
0xC508 -> 0xC788 +1728 = 0xCE48 | successor pret 0xC6E8 -> 0xCE48   OK
0xC6E8 -> 0xCE48 +2304 = 0xD748 | successor pret 0xCBFC -> 0xD748   OK
0xCD81 -> 0xD8CD +1000 = 0xDCB5 | successor pret 0xCEE9 -> 0xDCB5   OK
```

No gaps, no overlaps. The current scheme by contrast strands ~570 bytes in six
unusable slivers between hand-placed buffers, with the echo window 93% full.

### Top of memory — OAM, I/O and HRAM DO NOT MOVE

```
pret WRAM end 0xDFFF -> 0xEDCB  (uniform shift +3532)
+ staging 1376 B               -> expanded WRAM ends 0xF32B
need 13100 B ; space below OAM (0xC000-0xFDFF) = 15872 B ; headroom 2772 B
```

The whole expansion fits below `GB_OAM`. **`0xFE00`, `GB_IO 0xFF00` and HRAM
`0xFF80` keep their pret addresses**, so no HRAM symbol relocates — the single
largest cost feared for this change does not materialise.

## What this retires

- **The `0xF500` collision, with no hand intervention.** `wShadowOAMBackup` →
  `0xC788` (shift +640), `wLYOverrides` → `0xD24C` (shift +2892). They only ever
  collided because both were hand-placed.
- **The relocation baseline**, mostly: divergences become derived, so only
  deliberate exceptions remain as entries.
- **Echo-region fragmentation** and the "free echo RAM" framing.
- **The `wLYOverridesBufferEnd - wLYOverrides` bug class** (fixed once in
  `b5b4efbae` after wiping 928 bytes for months). Symbol differences are preserved
  by a uniform shift; they break only under *non-uniform* relocation, which is
  exactly today's scheme.

## Invariants this plan must not violate

1. **No growth point above `wMainDataStart`.** `save.asm` copies
   `wMainDataEnd - wMainDataStart` into SRAM; a growth inside that span changes the
   `.dsv` payload layout. All four current growth points are below it, so the save
   format is untouched *today*. This is convertible if ever needed (`saveconv.py`
   already does `.sav`↔`.dsv`), but it must be a decision, not a discovery — the
   generator must **report** when a growth crosses the line.
2. **Total growth stays a multiple of `0x100`.** `wCurrentAnimatedObjectOAMBufferOffset`
   holds a low-byte cursor added directly to `wShadowOAM`, which requires
   `wShadowOAM` to stay page-aligned. (`0xC300` is below every growth point, so it
   does not move — but a future growth below it would need this.)
3. **Headroom is 2772 B and it is the budget for all future growth.** When it is
   exhausted the question reopens as "shift OAM up" or "bank it via `rWBK`". Record
   that trigger; do not rediscover it.
4. Gen-1/Gen-2 byte-identical mon structs are unaffected — nothing here touches
   struct layout, only base addresses.

## Sequencing note

`gen_pret_ram.py`, `check_ram_addresses.py` and `ram_address_baseline.json` exist
**only on branch `script-linking`** (21 commits, unpushed; `static_gate` 6 checks
there vs 5 on master). This plan presupposes that branch merging first.

## Status: COMPLETE

fidelity-full **86/86** (nonzero=0), static_gate **PASS — 8 checks**, and the CI
chain (`make assets`, `make check`, `static_gate`) verified from a clean asset
tree. Landed 2026-08-19 across `3b4a7ed48`, `e4d4892bd`, `44e388643`.

Two rules make the model correct, and both were learned the hard way: a growth
applies at or above the END of its region (`p + pret_size <= addr`, or grown
regions tear apart), and **a widening is a growth** (the `dw`→`dd` jumptable
pointer needs its 4 bytes modelled, not inherited from pret's 2).

## Stages

- [x] **S1 — Land the collision detector as a gate.** Group port symbols by port
      address; for each group compare the names' *pret* addresses. Same → pret
      union, authorised. Different → port-introduced collision. Prototype run:
      3404 symbols, 467 shared addresses, **443 authorised, 7 unauthorised**. No
      curated size table needed. Ship as `static_gate` check 7.
- [x] **S2 — Triage the 7 unauthorised collisions** before any layout change, so
      known-broken aliases are not carried into the new map:
      `0xCFAE` `wLoadedMonSpeedExp`/`wPlayerLastStopDirection`;
      `0xD093` `wEndBattleTextRomBank`/`wSubAnimAddrPtr`;
      `0xD499` `wUnknownSerialFlag_d499`/`wPrinterConnectionOpen`;
      `0xF500` `wShadowOAMBackup`/`wLYOverrides`;
      `0xFFA9`/`0xFFAA` `hSwapItemID`/`hSwapItemQuantity` on live serial HRAM;
      `0xFFC1` `hVBlankCopyBGSource`/`hSpriteAnimFrameCounter`.
      Note the three serial/printer ones go live the moment the Game Boy Printer
      tier lands — which `current_plan_script_linking.md` group C is waiting on.
- [x] **S3 — Land the straddle detector as a gate.** For every symbol-difference
      expression in `src/`, flag any that spans a growth point. Current state:
      **120 both-pret differences, 0 straddle** — decomposed (50 of the 120 start
      inside the growth zone, so it is not vacuous) and false-witness tested
      (probes at `0xD400`/`0xD800`/`0xDA00` fire 8/6/6, first hit always
      `wMainDataEnd - wMainDataStart`). 3 differences are unevaluable because a
      name is port-only — close that gap or record it.
- [x] **S4 — Teach `gen_pret_ram.py` the growth table** and emit prefix-summed
      addresses, with the save-span report from invariant 1.
- [x] **S5 — Shrink `gb_memmap.inc` to deliberate exceptions**, deleting the
      hand-placed echo addresses the generator now derives, and rename the region
      so nothing calls it "free echo RAM" again.
- [x] **S6 — Rebase the above-window arena** (`GB_VRAM1`, `GB_BACKBUF`, SRAM
      banks, `wTempPic`). NOT DONE and NOT NEEDED for the expansion: the whole
      shift fits below `GB_OAM`, so nothing above `0x10000` had to move.
      `wTempPic` stays exiled at `0x21A00` — pret unions it with `wOverworldMap`
      at `0xC6E8`, so bringing it home is possible but is a behavioural change
      that wants its own scenario. Left deliberately.
- [x] **S7 — Verify.** `static_gate`, `make fidelity-full` (85 scenarios), plus a
      deliberate false-witness pass on both new gates. Note no golden currently
      covers the surf/Town-Map aliasing pair, and none structurally can — a
      scenario that runs the minigame then opens the Town Map would be the first.

- [x] **S8 — De-literalise the generators.** Measured 2026-08-19: five generators
      bake GB addresses as Python literals, so a move does not reach them and they
      emit wrong data silently. `gen_map_headers.py:1004 wOverworldMap = 0xE800`
      (moves to `0xCE48`), `gen_trainer_headers.py:59 WEVENTFLAGS = 0xD746`
      (→ `0xE512`), `gen_map_script_tables.py:72 WGAMEPROGRESSFLAGS = 0xD5EF`,
      `gen_battle_transition_arcs.py:34 wTileMap = 0xC3A0` (safe — it is a growth
      base and does not move, but it is the same anti-pattern). Give them one
      shared address source and gate against GB-address literals in
      `tools/generators/`.
- [x] **S9 — Update the `asm-translation` skill.** It carries the EBP memory model
      and is what teaches an agent how to place a variable, so it is where the
      "free" anti-pattern below came from and where the fix has to land: the
      prefix-sum model, "echo is not free space", and the hard rule that a free
      address is **derived from `pokeyellow.sym`, never asserted**. Without this,
      the next porter needing a byte recreates collision number eight.

## Remediating the seven collisions

**Five of the seven share one root cause: "free" was asserted, not measured.**
Verbatim from `gb_memmap.inc` — *"root-allocated free bytes after
hDivideBCDBuffer"*, *"Port-assigned to free hram"*, *"free echo RAM"*. The same
mistake in three different address ranges.

| collision | remediation | cost |
|---|---|---|
| `0xF500` `wShadowOAMBackup`/`wLYOverrides` | none — prefix-sum separates them to `0xC788` / `0xD24C` | free |
| `0xCFAE` `wPlayerLastStopDirection` | use pret's `0xD528`, measured **unused anywhere in the port** | trivial |
| `0xFFC1` `hSpriteAnimFrameCounter` | use pret's `0xFFEA`, measured free in `gb_memmap.inc`. Its squatting partner `hVBlankCopyBGSource` is **live** (VBlankCopy is wired into `DelayFrame`), so this is an active alias, not a latent one | trivial |
| `0xD499` `wUnknownSerialFlag_d499` | `pokeyellow.sym` says `0xD498`; the port used the address embedded in the *name*. Name-vs-symbol-table drift — use `0xD498` | trivial |
| `0xFFA9`/`0xFFAA` `hSwapItemID`/`hSwapItemQuantity` | pret puts them at `0xFF95`/`0xFF96`, unioned with `hDividend`/`hMultiplicand`. Restore that iff the swap path never calls Divide/Multiply while they are live; otherwise allocate from measured-free HRAM | needs one analysis |
| `0xD093` `wEndBattleTextRomBank` | the flat-adapted `dw`→`dd` widening shifts it `+2` into a "golden gap". **Its comment asserts "no overlap" citing the two neighbours the author considered and misses `wSubAnimAddrPtr` at pret `0xD093`, inside the very gap it claims.** A 4-byte widening needs port-only space, not a pret gap | real work |

## Open questions

- **Does any glitch worth preserving overrun `wTileMap` into neighbouring WRAM?**
  This is the only input that would justify the more expensive alternative
  considered and set aside: a real packed 360-byte `wTileMap` at `0xC3A0` with the
  wide-only ring held separately, dual-sourced by the compositor. That buys overrun
  fidelity and nothing else, at the cost of stride translation inside the hot loop
  `docs/plans/compositor_perf.md` fences. Unanswered; nobody has established which
  Gen-1 glitches, if any, depend on tilemap contiguity.
- **`tools/audit_memmap.py` has a detector gap** — it reports "clean: no overlaps"
  on a tree containing all 7 collisions, because a symbol with no `_SIZE` equ and no
  `CURATED_SIZES` entry is an extentless point, and the tool only checks
  extent-vs-extent or point-inside-extent. pret extents are derivable from
  `pokeyellow.sym` ordering, which would retire most of `CURATED_SIZES`.
