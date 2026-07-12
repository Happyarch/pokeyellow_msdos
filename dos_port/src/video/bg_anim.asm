; bg_anim.asm — VBlank BG animation / queued-map-copy helpers (Wave 2, M2.2)
;
; Intended repo path: dos_port/src/video/bg_anim.asm
;
; Faithful translations of two pret VBlank steps that the original runs every
; frame from the VBlank ISR (home/vblank.asm) but which do real work only when a
; gate byte is armed:
;
;   UpdateMovingBgTiles  — pret home/vcopy.asm:UpdateMovingBgTiles
;                          (water tile $14 + flower tile $03 overworld animation)
;   VBlankCopyBgMap      — pret home/vcopy.asm:VBlankCopyBgMap
;                          (queued row copy: hVBlankCopyBGSource/Dest/NumRows)
;
; Both are GLOBALS and BOTH SELF-GATE at their top on their arming byte, so the
; sibling M2.1 change may add an *unconditional* `call UpdateMovingBgTiles` /
; `call VBlankCopyBgMap` into the DelayFrame pipeline and it is always correct:
; when the gate is unarmed (its arming byte == 0) the routine is a no-op `ret`.
; In the current build NOTHING arms either gate (all HRAM boots to 0), so both
; are inert.
;
; ── Renderer-integrity notes (this port diverges hard from GB geometry) ──────
; The DOS port's native renderer (src/ppu/ppu.asm:render_bg) does NOT scan the
; GB's 32×32 BG tilemap at $9800; it decodes the 44×32 `wSurroundingTiles`
; surface / the 40×25 W_TILEMAP via `tile_cache`. Consequences honoured here:
;
;  * UpdateMovingBgTiles mutates tile PATTERN bytes in vChars/vTileset ($9000
;    region). That path DOES feed the renderer through `tile_cache`, so after
;    mutating pattern bytes we set `g_tilecache_dirty` (per CLAUDE.md) to force a
;    re-decode. Addresses are the *pattern* addresses (vTileset tile $14/$03),
;    never the 44×32 surface, and stride never assumes 32-wide geometry.
;
;  * VBlankCopyBgMap copies into the GB BG-map region addressed by
;    hVBlankCopyBGDest (a $9800-style pointer the caller supplies), exactly like
;    the existing do_bg_transfer (frame.asm) writes the physical GB tilemap.
;    In this port that region is vestigial/unread by render_bg, so a faithful
;    copy there is harmless. The per-row width is the GB-faithful 20 tiles with a
;    32-wide stride — hardcoded below, NOT the port's redefined SCREEN_WIDTH
;    (which is 40 for the extended viewport). It therefore never writes into
;    wSurroundingTiles / tile_cache / the 40×25 W_TILEMAP with GB-32-wide-stride
;    assumptions. Wiring this queue to the native surface, if ever wanted, is a
;    follow-up (see SUMMARY) — do not point the dest at a native buffer on a guess.
;
; Build check:
;   nasm -f coff -I dos_port/include -I dos_port -o /dev/null bg_anim.asm

bits 32

%include "gb_memmap.inc"

; ── ROOT-INTEGRATION: relocate these to dos_port/include/gb_memmap.inc ───────
; These HRAM/WRAM symbols are not yet in gb_memmap.inc. Addresses verified from
; pret ram/hram.asm + ram/wram.asm sequential layout (chain lands exactly on the
; already-present hTileAnimations=0xFFD7). Once root adds them to gb_memmap.inc,
; DELETE this whole block (nasm `equ` cannot be %ifndef-guarded, so leaving both
; a memmap def and this local def would be a redefinition error).
hVBlankCopyBGSource      equ 0xFFC1   ; dw — low byte doubles as the enable byte
hVBlankCopyBGDest        equ 0xFFC3   ; dw
hVBlankCopyBGNumRows     equ 0xFFC5   ; db
hMovingBGTilesCounter1   equ 0xFFD8   ; db  (byte after hTileAnimations $FFD7)
wMovingBGTilesCounter2   equ 0xD084   ; db  (pret wram.asm; after wFBTileCounter)
; ── end ROOT-INTEGRATION block ──────────────────────────────────────────────

; GB-faithful BG-map geometry for VBlankCopyBgMap. Hardcoded on purpose: the
; port's SCREEN_WIDTH is redefined to 40 (extended viewport), but pret's
; VBlankCopyBgMap copies GB SCREEN_WIDTH(=20) tiles per row into a GB
; TILEMAP_WIDTH(=32)-wide map. Using the port's SCREEN_WIDTH here would copy 40
; bytes/row and overflow the 32-wide row.
GB_BG_ROW_TILES          equ 20        ; pret SCREEN_WIDTH  — tiles copied per row
GB_BG_STRIDE             equ 32        ; pret TILEMAP_WIDTH — dest bytes per row

; vTileset ($9000) animated pattern-tile addresses (GB_VCHARS2 = vTileset).
; The tile IDs are shared (gb_memmap.inc) so screens that load their own graphics
; into vTileset can assert they don't overlap what this routine rewrites.
WATER_TILE_ADDR          equ GB_VCHARS2 + ANIM_WATER_TILE_ID * TILE_SIZE   ; $9140 (tile $14)
FLOWER_TILE_ADDR         equ GB_VCHARS2 + ANIM_FLOWER_TILE_ID * TILE_SIZE  ; $9030 (tile $03)

extern g_tilecache_dirty        ; src/ppu/ppu.asm — arm cache re-decode after vChars write

global UpdateMovingBgTiles
global VBlankCopyBgMap

section .text

; ═══════════════════════════════════════════════════════════════════════════
; UpdateMovingBgTiles — animate overworld water (tile $14) + flower (tile $03).
; pret ref: home/vcopy.asm:UpdateMovingBgTiles
;
; Gate: hTileAnimations == 0 → ret (0 breaks Surf; 1 = water only; 2 = water+flower).
; In:  EBP = GB memory base. Out: all registers preserved.
; Sets g_tilecache_dirty whenever it mutates vChars pattern bytes.
; ═══════════════════════════════════════════════════════════════════════════
UpdateMovingBgTiles:
    pushad

    ; ── self-gate ────────────────────────────────────────────────────────────
    mov al, [ebp + hTileAnimations]
    test al, al
    jz .done                        ; ret z — animations disabled

    ; pret: ldh a,[rLY]; cp $90; ret c   ("skip if not in vblank")
    ; TODO-HW: rLY is the GB scanline counter; the software PPU does not expose a
    ; live per-scanline rLY here and DelayFrame IS the port's vblank-equivalent,
    ; so we always proceed. (Faithful I/O-boundary handling.)

    ; ── frame cadence: hMovingBGTilesCounter1 ────────────────────────────────
    mov al, [ebp + hMovingBGTilesCounter1]
    inc al
    mov [ebp + hMovingBGTilesCounter1], al
    cmp al, 20
    jb .done                        ; ret c — not this frame
    cmp al, 21
    je .flower                      ; jr z .flower

    ; ── water: rotate the 16 pattern bytes of tile $14 left or right ─────────
    lea esi, [ebp + WATER_TILE_ADDR]
    mov ecx, TILE_SIZE              ; 16 bytes

    mov al, [ebp + wMovingBGTilesCounter2]
    inc al
    and al, 7
    mov [ebp + wMovingBGTilesCounter2], al

    test al, 4
    jnz .water_left
.water_right:
    mov al, [esi]
    ror al, 1                      ; rrca — bit0 → bit7 (scroll right)
    mov [esi], al
    inc esi
    dec ecx
    jnz .water_right
    jmp .water_commit
.water_left:
    mov al, [esi]
    rol al, 1                      ; rlca — bit7 → bit0 (scroll left)
    mov [esi], al
    inc esi
    dec ecx
    jnz .water_left

.water_commit:
    mov byte [g_tilecache_dirty], 1     ; vChars mutated → re-decode tile_cache

    ; pret: ldh a,[hTileAnimations]; rrca; ret nc; then reset counter1
    ;   anim==1 (bit0 set)  → CF=1 → reset counter1 to 0 (loop stays on water)
    ;   anim==2 (bit0 clear)→ CF=0 → leave counter1 at 20 → next frame → .flower
    mov al, [ebp + hTileAnimations]
    ror al, 1
    jnc .done                      ; ret nc — leave counter armed for flower
    mov byte [ebp + hMovingBGTilesCounter1], 0
.done:
    popad
    ret

    ; ── flower: copy one of three 16-byte pattern frames into tile $03 ───────
.flower:
    mov byte [ebp + hMovingBGTilesCounter1], 0

    mov al, [ebp + wMovingBGTilesCounter2]
    and al, 3
    ;  a<2 → FlowerTile1 ; a==2 → FlowerTile2 ; else (a==3) → FlowerTile3
    lea esi, [FlowerTile1]
    cmp al, 2
    jb .flower_copy
    lea esi, [FlowerTile2]
    je .flower_copy
    lea esi, [FlowerTile3]
.flower_copy:
    lea edi, [ebp + FLOWER_TILE_ADDR]
    mov ecx, TILE_SIZE             ; 16 bytes = one 2bpp tile
    rep movsb
    mov byte [g_tilecache_dirty], 1     ; vChars mutated → re-decode tile_cache
    popad
    ret

; ═══════════════════════════════════════════════════════════════════════════
; VBlankCopyBgMap — flush a queued BG-map row copy.
; pret ref: home/vcopy.asm:VBlankCopyBgMap (+ TransferBgRows)
;
; Copies [hVBlankCopyBGNumRows] rows of GB_BG_ROW_TILES(20) tiles from
; hVBlankCopyBGSource to hVBlankCopyBGDest, dest advancing GB_BG_STRIDE(32) per
; row (12-byte pad), then disables the queue by zeroing the source low byte.
;
; Gate: hVBlankCopyBGSource low byte == 0 → ret (pret: the low byte doubles as
; the enable byte; XX00 is an invalid/disabled source). Also short-circuits on
; NumRows == 0. Nothing arms either in the current build → inert.
;
; Port note: dest is the caller-supplied GB BG-map pointer ($9800 region),
; addressed [ebp + ptr] exactly like do_bg_transfer. render_bg does not scan
; that region, so the copy is harmless/unread here (see header). NEVER uses the
; port's 40-wide SCREEN_WIDTH — GB_BG_ROW_TILES/GB_BG_STRIDE are hardcoded.
;
; In:  EBP = GB memory base. Out: all registers preserved.
; ═══════════════════════════════════════════════════════════════════════════
VBlankCopyBgMap:
    pushad

    ; ── self-gate ────────────────────────────────────────────────────────────
    mov al, [ebp + hVBlankCopyBGSource]     ; low byte = enable byte (pret)
    test al, al
    jz .done                                ; ret z — queue disabled
    movzx ebx, byte [ebp + hVBlankCopyBGNumRows]
    test ebx, ebx
    jz .done                                ; nothing queued

    ; ESI = flat source, EDI = flat dest (16-bit GB pointers from HRAM)
    movzx esi, word [ebp + hVBlankCopyBGSource]
    add esi, ebp
    movzx edi, word [ebp + hVBlankCopyBGDest]
    add edi, ebp

    ; pret zeroes the source so the transfer does not continue next V-blank
    mov byte [ebp + hVBlankCopyBGSource], 0

.row:
    mov ecx, GB_BG_ROW_TILES               ; 20 contiguous source bytes
    rep movsb                              ; src +20 (contiguous), dest +20
    add edi, GB_BG_STRIDE - GB_BG_ROW_TILES ; +12 → dest advances 32 (one 32-wide row)
    dec ebx
    jnz .row
.done:
    popad
    ret

; ═══════════════════════════════════════════════════════════════════════════
; Flower animation pattern frames (pret INCBIN gfx/tilesets/flower/flowerN.2bpp).
; Embedded as bytes so this file links standalone; each is exactly one 2bpp tile
; (TILE_SIZE = 16 bytes). Bytes verified against gfx/tilesets/flower/*.2bpp.
; ═══════════════════════════════════════════════════════════════════════════
section .data

FlowerTile1:
    db 0x81,0x00,0x00,0x18,0x00,0x24,0x85,0x5a,0x1c,0x42,0x18,0xa5,0x00,0x7e,0x81,0x18
FlowerTile2:
    db 0x81,0x00,0x00,0x0c,0x00,0x12,0x82,0x2d,0x0e,0xe1,0x0c,0x73,0x00,0x3e,0x81,0x18
FlowerTile3:
    db 0x81,0x18,0x00,0x24,0x04,0x5a,0x9d,0x42,0x18,0x24,0x00,0xdb,0x00,0x7e,0x81,0x18
