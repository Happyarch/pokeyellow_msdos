---
name: asm-translation
description: SM83→x86 NASM translation reference for the Pokémon Yellow DOS port. Invoke BEFORE translating any pret/home/engine routine to x86 assembly, or when unsure about the register mapping, ZF/CF flag preservation, big-endian GB data layout, the EBP-relative memory model / DJGPP addressing gotchas, the software-video/timing/hardware-I/O/RST translation boundaries, 386+ instruction choices, or the per-routine translation workflow. Triggers: "translate <routine>", "port this SM83 code", "which x86 register maps to HL/BC/DE", "jr z / jr c", "big-endian", "EBP offset", "TODO-HW", "ds_base / vga_base".
---

# SM83 → x86 Translation Reference

Deep reference for translating pret/pokeyellow SM83 routines into the DOS port's
x86 NASM. The always-loaded hard rules (preserve pret labels, GB data is
big-endian) live in `CLAUDE.md`; this skill holds the detail.

## Register Mapping (SM83 → x86)

| SM83 | x86 | Notes |
|------|-----|-------|
| A | AL | Accumulator |
| F: Z, C | EFLAGS ZF, CF | Direct |
| F: H | `[hf_shadow]` | BSS byte; lazy — only update where DAA/CPL consume H |
| F: N | (implicit) | Tracked via instruction choice, not a flag |
| BC | BX | B = BH, C = BL |
| DE | DX | D = DH, E = DL |
| HL | ESI | Full 32-bit, used for flat addressing |
| SP | ESP | Direct; mind calling convention |
| — | EBP | Fixed base → emulated GB address space |
| — | EDI | Secondary pointer / blit destination |
| — | ECX | Loop counter / scratch |

## Preserve Flags (ZF/CF) — x86 ≠ SM83

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
- SM83 `F: N`/`H` are tracked separately (`[hf_shadow]`, lazy) — see the register
  table above; most routines don't touch them, but DAA/CPL paths do.
- Related: multi-byte GB values are **big-endian** — see "Data Endianness" below.

## Preserve Counter WIDTH — a widened loop counter loses its bound

**This is the same family as the flag rule above, and it is the single most
repeated translation defect in this project** (maintainer-observed, 2026-08-04:
"counter and loop bugs going from 8 bit to 16 bit or 32 bit has happened in this
project more than I'd like to admit"). Read it before translating any `dec c` /
`dec b` loop.

pret writes `dec c / jr nz`. Entered with **C = 0** that runs **256** times and
stops — a bounded, survivable glitch. The bound comes from the **register
width**, not from any instruction. Translate it to `movzx ecx, bl` + `dec ecx /
jnz` and the same input runs **~4 billion** times, walks the write pointer off
the end of the DPMI allocation, and **page-faults**. Same opcodes, same
semantics, catastrophically different blast radius.

**Why this keeps getting through review — the guard is not in the source.** The
original author never wrote a zero-check because the hardware *was* the check, so
there is nothing textual to carry across. `movzx ecx, bl` + `dec ecx / jnz` is a
correct-looking translation and is genuinely correct for every input except the
boundary one. Unlike a flag bug, there is no misplaced `inc` to spot in the diff.
The failure is also **displaced**: it surfaces as a page fault whose faulting
routine is the loop, while the actual defect is a *caller* passing a zero count.

**The rule — keep the counter 8 bits wide.** When translating a pret loop whose
counter comes from an 8-bit register, ask explicitly: *can this count be 0 on
entry?*
- If yes — or if you cannot prove no — **use the 8-bit register**: `dec cl` /
  `dec dl`, not `dec ecx` / `dec edx`. That IS pret's bound, reproduced exactly,
  and it needs no `DEVIATION` annotation because nothing diverges.
- Record the answer in a comment when it is non-obvious, so the next reader does
  not have to re-derive it.

**⚠ A ZERO-GUARD IS NOT EQUIVALENT — this page said it was, and it was wrong.**
`test ecx,ecx / jz .done` writes **0** items where the GB writes **256**. That is
a real behavioural divergence, and one you would then owe a `DEVIATION` for. The
earlier advice here ("a guard that reproduces the 8-bit wrap's boundedness is
faithful") conflated *bounded* with *faithful*: a guard is bounded but it is a
different program. MEASURED on `TextBoxBorder` 2026-08-05 — pret's `.PlaceChars`
is `ld d, c / dec d / jr nz`, so width 0 places 256 chars and stops. The fix that
landed (`dd68f32d`) is `dec cl`, not a guard.
Use a guard only where you have decided the GB's degenerate behaviour is itself
undesirable — and then say so in a `DEVIATION`, because it is one.

**The masking trap — do not skip this.** Adding a zero-guard to a loop whose
caller passes a bad count converts a loud page fault into a *silently mis-drawn
screen*, which is strictly harder to find. Guard the loop **and** fix the caller;
never let the guard close the investigation.

**Second worked instance, and it is the OTHER shape: `DelayFrames` (`d5a24c52`,
2026-08-08).** `TextBoxBorder` was a *widened* counter fixed by narrowing to
`dec cl`. `DelayFrames` was the opposite — an 8-bit loop that was already correct,
with a zero-guard *added* on top:

```nasm
DelayFrames:            ; pret: call DelayFrame / dec c / jr nz / ret
    test bl, bl         ; <-- ADDED. 0 frames where the GB waits 256 (~4.3 s)
    jz .done
```

Unannotated, so `lint_pret_labels` and `faithdiff` both reported it faithful. The
fix was to delete the guard, not document it.

**The diagnostic that settles these — look at the CALLERS, not the loop.** pret
can afford a bare do-while because its callers maintain the nonzero invariant.
Measured across all 105 `DelayFrames` call sites: 102 pass a literal non-zero,
none passes a literal zero, and all 3 computed sites are provably non-zero — the
clearest being `PlayerSpinInPlace`'s escape-warp variant, which counts 16 down to
end value 0 and whose own `cp c / ret z` returns EXACTLY when the delay would
reach zero. **So before adding a guard, go read the callers; the invariant is
usually already there, and if it is, the guard is not defence — it is divergence.**

Worked instance and the exposure audit: memory
`bug-class-gb-counter-widened-to-32-bit`. First fully root-caused case was
`TextBoxBorder.fill_chars` (`src/home/text.asm`), which page-faulted on a zero
interior box width. Find candidate sites with (**quote the glob — zsh errors on
an unmatched one and the command does not run at all**):

```sh
grep -rn --include='*.asm' -E "movzx (ecx|ebx|edx), (bl|bh|cl|ch|dl|dh|al|ah)\b" src/
grep -rn --include='*.asm' -A1 -E "^\s*dec ecx\s*$" src/ | grep jnz
```

Those greps report **exposure, not defects** — most counts are provably non-zero
by construction. Each hit needs the can-it-be-zero question answered on its own;
do not report the raw counts as a bug tally.

## Memory Model

`EBP` = base of a ~96 KB DPMI allocation (64 KB GB space + 8 KB CGB VRAM bank 1
+ 160×144 back buffer). Access emulated GB memory as `[EBP + constant]` where
constants come from `dos_port/include/gb_memmap.inc`. All offsets derived from
`constants/hardware.inc`.

**DJGPP addressing (critical, verified in testing):** the DS/CS selector base
is the program image, NOT linear 0. `setup_flat_access` (boot/entry.asm) raises
the DS limit to 4 GB (DPMI fn 0008h — the "nearptr" model) and stores the DS
base in `[ds_base]`. Every raw linear address must be biased by `-[ds_base]`
before use as a DS-relative offset:
- VGA framebuffer: use `[vga_base]` (= 0xA0000 − ds_base), never raw 0xA0000
- DPMI fn 0501h results: linear − ds_base (done in `alloc_gb_memory`; EBP is
  already biased)
- PSP/real-mode addresses: segment×16 − ds_base

Other verified DPMI gotchas:
- DPMI fn 0501h takes the size in **BX:CX as 16-bit halves**, not ECX
- A hardware ISR must load DS via `mov ds, [cs:isr_ds]` (CS base = DS base
  under DJGPP); don't assume SS holds the flat selector on ISR entry
- Restore the PIT divisor and original IRQ0 vector before exit (`pit_restore`)
- **`[EBP + disp]` addressing defaults to the SS segment**, and the go32
  loader (verified under HDPMI32) gives us an SS whose base does NOT match
  DS — so every EBP-relative GB memory access silently read/wrote the wrong
  linear memory until `setup_flat_access` was taught to normalize SS to the
  DS selector (with an ESP rebase of `ss_base - ds_base` in the same
  instruction pair). Symptom when broken: renderer reads all zeros, no crash.

## Data Endianness (preserve pret byte order)

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

## Video
- VGA Mode 13h (320×200, 256 colors)
- Back buffer: **320×200 native** (64,000 B) at `[EBP + GB_BACKBUF]` — the software
  PPU composites at the port's extended viewport size, not the GB's 160×144, and
  `present` is a straight 1:1 `rep movsd` to `[vga_base]` (no scaling blit).
- Palette: 256-entry VGA (6-bit RGB via ports 0x3C8/0x3C9). **The GBC colors are
  live — the old global 4-shade DMG-green ramp is gone.** `commit_palette`
  (`boot/video.asm`) maps the 8 BG + 8 OBJ CGB-style slot palettes through
  `IO_BGP`/`IO_OBP0`/`IO_OBP1` into the DAC, reading `bg_slot_pal` /
  `obj_slot_pal` / `pal_rgb_table` (published by `src/home/palettes.asm`, data
  generated into `assets/colors/palettes.inc` by
  `tools/generators/gen_palettes.py`). It early-outs unless `g_pal_dirty` or one
  of the three DMG palette registers changed, so **a routine that rewrites slot
  palettes must arm `g_pal_dirty`**.
  There is no `dmg_palette` symbol; `boot/video.asm` still carries a
  `test_palette` used only by `video_init`'s DAC self-test. The colorization plan
  is complete and archived at `docs/plans/colorization.md` (2026-07-13, stages
  R1-R3 done). Residual `; TODO-HW: palette/fade (Phase 5)` comments in
  `src/home/overworld.asm` and `src/engine/overworld/overworld.asm` refer to the
  **fade** routines (`GBFadeOutToBlack` &c.), which are still deferred — not to
  the palette data.

### Writing VRAM tile data: `CopyVideoData`, or arm `g_tilecache_dirty` yourself

**A raw `rep movs` into vChars that does neither is a visible-corruption bug.**
This is the single most repeated compositor mistake — it has shipped twice.

The port does not read VRAM tile patterns while compositing. It decodes all 384
tiles (2bpp→8bpp) once into `tile_cache`, and **`render_bg`, `render_window` *and*
`render_sprites` all composite from that cache** (`docs/plans/compositor_perf.md`).
So a routine that mutates vChars bytes without invalidating the cache draws
whatever those cache slots held *before* — stale font glyphs, the previous mon's
icon, another screen's tiles.

When you translate a pret routine that writes tile data (`CopyVideoData`,
`LoadMonPartySpriteGfx`, move-anim tilesets, emote bubbles, HUD/pic loads):

- **Prefer `CopyVideoData` (`home/copy2.asm`)** — it arms `g_tilecache_dirty`
  itself, so anything routed through it is correct by construction. Most pret VRAM
  writes are already `CopyVideoData`/`CopyData` calls; keep them that way.
- **A hand-rolled copy must arm it explicitly**, as its first statement:
  ```nasm
  extern g_tilecache_dirty            ; src/ppu/ppu.asm
      mov byte [g_tilecache_dirty], 1 ; VRAM tile data changes → rebuild decode cache
  ```
- **OBJ/sprite tiles are NOT exempt.** They were, once — `render_sprites` used to
  bit-decode raw OBJ VRAM. It no longer does. Any comment claiming "sprites read
  raw VRAM, no cache involvement" is stale; `LoadPokeballGfx` carried exactly that
  comment and was silently drawing stale ball tiles (`33e21fd2`).
- **Parking graphics in vTileset?** Tiles `$03` (flower) and `$14` (water) are
  RESERVED — `UpdateMovingBgTiles` (`src/home/vcopy.asm`) rewrites them in place
  whenever `hTileAnimations` is nonzero, and will scribble over anything you
  leave there (`ANIM_FLOWER_TILE_ID` / `ANIM_WATER_TILE_ID` in `gb_memmap.inc`;
  the addresses are vChars2 `$9030` and `$9140`). This ate the party-menu mon
  icons (`be6500bc`).

Note the pixel harness will **not** catch a missing flag on its own: a scenario
passes if some *other* load happens to arm the cache in the same frame. Reason
about the write, don't rely on `pixelcheck.sh` alone.

## Timing
- PIT channel 0, mode 3; divisor chosen by the Makefile `TIMING` mode (the GB is
  not exactly 60 Hz). Default **SGB** = 61.1685 Hz (divisor 19506, the Super Game
  Boy's ~+2.4% SNES-clock speed-up); `TIMING=DMG` = 59.7275 Hz (19977, real
  handheld); `TIMING=PC` = 60 Hz (19886); or `TIMING_HZ=`/`TIMING_DIVISOR=` custom.
  `timing.asm` reads `-D PIT_DIVISOR=`.
- Frame loop: `wait_vblank → wait_pit_tick → update → render → present`, driven
  from `DelayFrame` in **`src/home/vblank.asm`** (with `src/home/delay.asm`).
  The old `src/video/frame.asm` was split into those two and the directory
  deleted (`0bddffcb`) — there is no `dos_port/src/video/`.
- VBlank detection: port 0x3DA bit 3 (VSync active high)
- No cycle-counted delay loops

## Hardware I/O Boundary
**Do not translate GB I/O register accesses directly.** These are translation
boundaries. Emit a `; TODO-HW:` comment describing what the original code does:

- `$FF40–$FF4B` (LCDC, STAT, SCX/SCY, palettes, OAM DMA) → software renderer.
  **But several of these are NOT boundaries any more — do not reflexively emit
  `; TODO-HW` for the whole range** (measured 2026-08-08, battle_animations
  Stage 3):
  * **`rBGP`/`rOBP0`/`rOBP1` (`$FF47-49`) are LIVE.** A write to
    `[ebp + IO_BGP]` IS the whole effect: `commit_palette` (boot/video.asm)
    early-outs unless `g_pal_dirty` or one of the three DMG palette registers
    changed, and it runs from `DelayFrame` via `src/home/vblank.asm`. So pret's
    `ldh [rBGP], a` is a literal `mov [ebp + IO_BGP], al` with no HAL and no
    TODO-HW owed — that is exactly how the whole flash/palette family
    (`AnimationFlashScreen`, `SetAnimationBGPalette`, …) is translated.
    `UpdateCGBPal_BGP/OBP0/OBP1` all collapse to `mov byte [g_pal_dirty], 1`.
  * **`rSCX`/`rSCY` are live via their SHADOWS.** Write `H_SCX`/`H_SCY`, not
    `IO_SCX`/`IO_SCY` — `commit_shadow_regs` copies shadow → register every
    `DelayFrame`, so a direct register write is erased next frame. `render_bg`
    takes its blit offset from them, which is how the whole-canvas screen shake
    works.
  * **`rLY`/`rSTAT` are INERT** — nothing in the port ever writes them. Code
    that spins on `rSTAT & 3` for H-blank falls straight through, and a
    `cp rLY` frame-end poll never terminates. A literal translation HANGS. Any
    per-scanline effect needs a HAL instead (see `AnimationWavyScreen`'s per-row
    displacement table, `g_row_xoff` in `src/ppu/ppu.asm`).
- `$FF01/$FF02` (serial SB/SC) → still `; TODO-HW: network HAL` (Phase 4);
  `IO_SB`/`IO_SC` in `gb_memmap.inc` carry that tag, and the stand-ins live in
  `src/home/serial_stubs.asm`
- `$FF04–$FF07` (timer) → PIT-based main loop, not translated
- `$FF10–$FF26` + `$FF30–$FF3F` (APU / wave RAM) — **NOT a TODO-HW boundary any
  more.** These are a **virtual APU**: the registers live in emulated GB memory
  under their pret names (`rAUD1SWEEP` … `rAUDENA`, `_AUD3WAVERAM`, see
  `gb_memmap.inc`), the translated engine (`src/audio/engine_1..4.asm`) writes
  them exactly as the SM83 did, and the per-device shim (`src/audio/audio_hal.asm`
  → `opl_shim` / `tandy_shim` / `spk_shim` / `mpu401`) reads them once per
  `audio_tick`. Translate APU writes **literally**; do not emit `; TODO-HW`.
  (The shim consumes the NRx4 bit-7 "restart" and clears it — the engine never
  reads it back.) Only `IO_APU_BASE` still carries a legacy TODO-HW comment in
  `gb_memmap.inc`; it is stale, not guidance.

## RST Vectors
`RST $00`–`$38` become regular labeled `CALL` targets, not interrupt-style dispatch.

## 386+ Instructions
Prefer: `movzx`/`movsx` for zero/sign extension, `imul reg, reg, imm` for
tile/map index math, `lea` for flags-preserving address computation, `rep stos/movs`
for block fills/copies.

## Translation Workflow

1. Pick a routine from `home/` or `engine/` with no `$FF__` I/O accesses.
2. Run `dos_port/tools/label_status --callees <Label>` — it classifies every
   call target of the pret routine (translated / relocated / stub / missing),
   so you know up front what to `extern` (and from where) vs what needs a stub
   per the `project-conventions` stub rules. (DB stale? `tools/update_label_db`.)
3. Create `dos_port/src/<mirrored path>/<filename>.asm`.
4. Translate following the register map. Include by **bare filename** —
   `%include "gb_memmap.inc"` — because the Makefile assembles with
   `-I include/ -I .` from `dos_port/`. A path-qualified
   `%include "dos_port/include/gb_memmap.inc"` does not resolve.
5. Emit `; TODO-HW:` for any I/O boundary hit.
6. For any known bug (check `docs/bugs_and_glitches.md`), emit the **structured**
   annotation — `; BUG{class=…; pret=…; behavior=…; evidence=…; lifetime=…}` —
   paired with its `%if BUG_FIX_LEVEL >= N` block. **The free-form
   `; BUG(level):` form is DEAD**: `lint_pret_labels --strict-claims` reports it
   as `legacy_annotation`, and the tree-wide count is currently zero. Writing one
   is a regression. Schema → skill `project-conventions`.
7. Add an entry to `docs/translation_log.md` (narrative log; not gated by any
   tool, and commits do drift from it — write the entry, don't read it as
   authority).
8. Verify assembly from `dos_port/`:
   `nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 -o /dev/null <file>`.
   Both the `-I` flags and `-D BUG_FIX_LEVEL=` are required — the Makefile
   supplies them, and a bare `nasm` fails on any `%if BUG_FIX_LEVEL` block.
9. Run the fidelity gate (skill `faithfulness-review`): `tools/faithdiff <Label>`
   + `tools/lint_pret_labels`; then `tools/update_label_db` so the label DB
   reflects the new translation/stubs (rescan-derived — skipping is
   self-healing, not corrupting).
   Two automated gates sit behind those: `tools/fidelity_gate` runs the
   per-change/per-label chain for you (and carries the relocation move battery,
   `--move-baseline` / `--move-verify`), and `tools/static_gate` is the whole-tree
   ratchet that **`.githooks/pre-commit` runs on every commit staging anything
   under `dos_port/`**. Neither says anything about behaviour — the golden suite is
   separate. See skill `faithfulness-review`.
   CAUTION: a bare `tools/lint_pret_labels` **rescans the tracked
   `translation.db` in place**; pass `--no-scan` when you only want findings.
