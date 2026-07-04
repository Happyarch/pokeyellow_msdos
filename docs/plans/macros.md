# current_plan_macros — Port pret RGBDS macros to the DOS port

Multi-session, chunked, checkbox-tracked. **"Add macros only"** — define each macro
as a real NASM `%macro`; do **not** retrofit the existing hand-computed call sites
(zero regression risk; new code adopts them going forward). Each chunk = one
new/extended `.inc` under `dos_port/include/`, with an `%ifndef` include guard, plus
a scratch equivalence test (`nasm -f coff -o /dev/null`) proving the macro emits the
same address/bytes a current hand-computed `equ` site uses. Ordered value/low-risk
first.

## Why (context)

pret's 15 macro files at the repo root have no systematic equivalent in `dos_port/`.
Two exploration passes sorted them into four buckets; only bucket 4 is real work:

1. **Redundant by design** — banking/dispatch (`farcall`, `callfar`, `homecall`,
   `predef`, `jpfar`/`farjp`) collapse to plain `call`/`jmp` under the flat DPMI
   model. Nothing to port.
2. **Already owned by the generators** — `object_event`/`warp_event`/`bg_event`/
   `map_header`/`connection`, the `text`/`line`/`para` data streams, and struct
   layouts (`party_struct`/`box_struct`) are pre-expanded to raw `db`/`dw` or `equ`
   offsets. Per the two-tier rule these **stay** in `tools/gen_*.py`.
3. **Blocked on unported engines** — the `audio.asm` family (Phase-3 APU HAL),
   `gfx_anims.asm` (anim engine), and the `script_*` templates in `maps.asm`
   (need their routines). Not low-effort; nothing to target yet.
4. **Genuinely useful as real NASM macros, currently missing** — coords, the
   extended event-macro family, trivial data/gfx helpers, and text-command macros
   for hand-authored dialog. **This plan.**

Currently ported: `CheckEvent`/`SetEvent`/`ResetEvent` (`include/events.inc`) and
`text_far`/`text_end` (`include/gb_text.inc`). Port macro idiom: EBP-relative
`%macro` with `%ifndef` guards (mirror those two files).

> **⚠ Stride is context-dependent — there is no single "screen stride."** The
> global `SCREEN_WIDTH = SCREEN_TILES_W = 40`, `SCREEN_HEIGHT = 25` (the widescreen
> canvas), and `W_TILEMAP` lives at `0xC3A0` as a 40×25 / 1000-byte buffer — **not**
> the GB's 20×18. But the *same* `W_TILEMAP` buffer is addressed at **different
> strides by different callers**:
> - `src/text/text.asm` defines its **own** `SCREEN_W_TILES equ 20` and lays dialog
>   out at **stride 20** (e.g. `W_TILEMAP + 12*SCREEN_W_TILES`).
> - It further keeps a **runtime** `text_row_stride: dd 20` that the battle path
>   flips to **40** — i.e. the dialog stride is chosen at runtime (20 overworld /
>   40 battle), which a compile-time macro **cannot** express.
> - VRAM maps `GB_TILEMAP0`/`GB_TILEMAP1` (`0x9800`/`0x9C00`) use `TILEMAP_WIDTH = 32`.
>
> **Consequences for the coords chunk:** a single ported `coord`/`hlcoord` cannot
> serve every caller. Each coord macro must **pin its stride + origin to one target
> buffer and document which**; the runtime-strided dialog path is likely **not
> macro-able** and should be excluded (keep using `text_row_stride`). Confirm the
> exact symbols/values in `gb_memmap.inc` (`SCREEN_WIDTH`, `TILEMAP_WIDTH`,
> `W_TILEMAP`, `GB_TILEMAP0`) and `src/text/text.asm` (`SCREEN_W_TILES`,
> `text_row_stride`) at build time. Treat this as a real design decision, not a
> copy of pret's stride-20 `coord`.

## Chunks

### Stage 1 — Seed this plan  ✅ (done)
- [x] Create `docs/current_plan_macros.md` (this file).
- [x] Add a bullet to CLAUDE.md's **"Currently active plans"** list pointing here.

### Stage 2 — Chunk A1: screen-tilemap coords → `dos_port/include/coords.inc`
- [ ] `coord <reg>, x, y[, origin]` → `mov <reg>, (y)*<stride> + (x) + origin`.
      **Resolve the stride/origin question first** (see ⚠ above): decide whether
      the ported `coord` targets `W_TILEMAP` (stride 40) or the legacy stride-20
      screen buffer, and make the choice explicit (default origin + stride pinned
      together). Confirm `SCREEN_WIDTH`, `W_TILEMAP`/`GB_TILEMAP0` in `gb_memmap.inc`.
- [ ] `hlcoord`/`bccoord`/`decoord` wrappers. Design note: a port tilemap pointer
      is a 32-bit GB offset used as `[ebp+reg]`, so callers pass `esi`/`edi`;
      document that `bc`/`de` shorthands map to the port's pointer regs, not BX/DX.
- [ ] `dwcoord x, y[, origin]`, `dbmapcoord x, y`, `ldcoord_a`, `lda_coord`.
- [ ] `validate_coords` as an assemble-time bounds check via `%if`/`%error`.
- [ ] Verify: scratch test that a macro invocation == an existing hand-site offset
      byte-for-byte.

### Stage 3 — Chunk A2: bg + overworld coords (port-semantics) → `coords.inc`
- [ ] `bgcoord`/`hlbgcoord`/… (stride `TILEMAP_WIDTH` = 32) and `owcoord` family +
      `event_displacement`. **Risk:** the port renders a native-width surface
      (44×32), not the GB 32×32 torus / `vBGMap0` — reconcile with the
      renderer-native-viewport invariant; where port semantics diverge, document
      the divergence rather than copy pret's addressing.

### Stage 4 — Chunk B: data helpers → `dos_port/include/data_macros.inc`
- [ ] `dbw`, `dwb`, `dn` (nybbles), `dc` (2-bit crumbs), `bcd2`, `bcd3`, `dba`,
      `dab`, `bigdw`, `dname`, `tmhm` as `%macro` wrappers over `db`/`dw`.
- [ ] Reconcile the name clash with the file-local `dc` in `src/home/fade.asm`.

### Stage 5 — Chunk C: event-macro family → extend `dos_port/include/events.inc`
- [ ] `CheckAndSetEvent`, `CheckAndResetEvent`, variadic `SetEvents`/`ResetEvents`
      (`%macro … 1-*`), `SetEventRange`/`ResetEventRange`, `CheckBothEventsSet`,
      `CheckEitherEventSet`.
- [ ] GB register-reuse variants (`*ReuseHL`, `*ForceReuseHL`, `*AfterBranch*`,
      `*ReuseA`) as `%define` **aliases** of the base macros — no-ops in the flat
      model, but they let pret-named call sites port verbatim.

### Stage 6 — Chunk D: gfx + code sugar → `dos_port/include/gfx_macros.inc`
- [ ] `RGB r,g,b` (pack RGB555 — directly useful for the Phase-5 palette work) and
      `dbsprite` (OAM entry).
- [ ] Evaluate `code.asm`: `lb`, `ldpal`, `dict`, `ld_hli_a_string` — port the ones
      that map cleanly (`lb` → load two halves of a port reg); mark the rest N/A.

### Stage 7 — Chunk E: text-command macros → extend `dos_port/include/gb_text.inc`
- [ ] Control-flow: `text`, `text_start`, `line`, `next`, `para`, `cont`, `done`,
      `prompt`, `page`, `dex`.
- [ ] Format cmds: `text_ram`, `text_bcd`, `text_decimal`, `text_dots`, `text_pause`,
      `text_waitbutton`, `text_promptbutton`, `text_scroll`, `text_low`, `text_move`,
      `text_box`, `text_asm` — each → its control byte (cross-check pret
      `macros/scripts/text.asm` + the port charmap).
- [ ] Verify one hand-written string assembles to the same bytes a generator emits.

### Stage 8 — Chunk F (optional, low priority): const/asserts plumbing
- [ ] `const_def`/`const`/`const_export`/`shift_const`/`const_skip`/`const_next`/
      `dw_const`, and typed-table builders (`list_start`/`li`, `nybble_array`,
      `bit_array`, `def_grass_wildmons`/`def_water_wildmons`). Port only if/when a
      hand-written enum/table actually needs them.

## Documented but NOT scheduled (do not build)
- **Blocked:** `audio.asm` (Phase-3 APU HAL), `gfx_anims.asm` (anim engine),
  `maps.asm` `script_*` templates (need routines).
- **N/A by design:** `farcall.asm`/`predef.asm` (flat model), `maps.asm` data macros
  (generator-owned, two-tier rule), `ram.asm` struct macros (already `equ` in
  `gb_constants.inc`), `vc.asm` (Virtual Console only).

## Critical files
- New: `dos_port/include/coords.inc`, `dos_port/include/data_macros.inc`,
  `dos_port/include/gfx_macros.inc`.
- Extend: `dos_port/include/events.inc`, `dos_port/include/gb_text.inc`.
- Reference (read-only): `macros/coords.asm`, `macros/scripts/events.asm`,
  `macros/scripts/text.asm`, `macros/data.asm`, `macros/gfx.asm`.
- Ground offsets/style in: `dos_port/include/gb_memmap.inc`,
  `dos_port/include/gb_constants.inc`.

## Verification (per chunk — "add macros only", no retrofit)
1. `nasm -f coff -o /dev/null <scratch test>` that `%include`s the new header and
   asserts (via `%if … %error`) that each macro's emitted offset/bytes equal the
   value a current hand-computed site uses. Fail-closed if they diverge.
2. `make -C dos_port` still builds byte-identically (headers are inert until a call
   site opts in).
3. Tick this chunk's boxes; when all non-deferred chunks are done, archive to
   `docs/plans/macros.md`.
