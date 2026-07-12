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
- Palette: 256-entry VGA (6-bit RGB via ports 0x3C8/0x3C9); layout TBD Phase 5.
  The current 4-shade DMG-green ramp (`dmg_palette` in `boot/video.asm`) is a
  **debug placeholder** — do not treat it as final. Phase 5 will translate the
  original **GBC** colors into the VGA palette (Yellow is CGB-enhanced; pull
  from the CGB palette data, not an expanded DMG ramp).

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
  RESERVED — `UpdateMovingBgTiles` rewrites them in place whenever
  `hTileAnimations` is nonzero, and will scribble over anything you leave there
  (`ANIM_FLOWER_TILE_ID` / `ANIM_WATER_TILE_ID` in `gb_memmap.inc`). This ate the
  party-menu mon icons.

Note the pixel harness will **not** catch a missing flag on its own: a scenario
passes if some *other* load happens to arm the cache in the same frame. Reason
about the write, don't rely on `pixelcheck.sh` alone.

## Timing
- PIT channel 0, mode 3; divisor chosen by the Makefile `TIMING` mode (the GB is
  not exactly 60 Hz). Default **SGB** = 61.1685 Hz (divisor 19506, the Super Game
  Boy's ~+2.4% SNES-clock speed-up); `TIMING=DMG` = 59.7275 Hz (19977, real
  handheld); `TIMING=PC` = 60 Hz (19886); or `TIMING_HZ=`/`TIMING_DIVISOR=` custom.
  `timing.asm` reads `-D PIT_DIVISOR=`.
- Frame loop: `wait_vblank → wait_pit_tick → update → render → present`
- VBlank detection: port 0x3DA bit 3 (VSync active high)
- No cycle-counted delay loops

## Hardware I/O Boundary
**Do not translate GB I/O register accesses directly.** These are translation
boundaries. Emit a `; TODO-HW:` comment describing what the original code does:

- `$FF40–$FF4B` (LCDC, STAT, SCX/SCY, palettes, OAM DMA) → software renderer
- `$FF01/$FF02` (serial SB/SC) → `; TODO-HW: network HAL` (Phase 4)
- `$FF04–$FF07` (timer) → PIT-based main loop, not translated
- `$FF10–$FF26` (APU) → `; TODO-HW: audio HAL` (Phase 3)

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
4. Translate following the register map. Use `%include "dos_port/include/gb_memmap.inc"`.
5. Emit `; TODO-HW:` for any I/O boundary hit.
6. Emit `; BUG(level):` for any known bug (check `docs/bugs_and_glitches.md`).
7. Add an entry to `docs/translation_log.md`.
8. Verify assembly: `nasm -f coff -o /dev/null <file>`.
9. Run the fidelity gate (skill `faithfulness-review`): `tools/faithdiff <Label>`
   + `tools/lint_pret_labels`; then `tools/update_label_db` so the label DB
   reflects the new translation/stubs (rescan-derived — skipping is
   self-healing, not corrupting).
