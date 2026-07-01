; copy2.asm — VRAM tile-data copy family + screen-area helpers.
;
; Source: home/copy2.asm (pret/pokeyellow) — FarCopyDataDouble, CopyVideoData,
;         CopyVideoDataDouble, GetFarByte, ClearScreenArea,
;         CopyScreenTileBufferToVRAM.
;         (FillMemory lives in src/home/fill_memory.asm; ClearScreen/IsTilePassable
;          are not ported here — see SUMMARY.md.)
;
; ---------------------------------------------------------------------------
; PORT MODEL — READ THIS BEFORE CHANGING SIGNATURES
;
; The CopyVideoData* routines write tile PATTERN data into the vChars VRAM
; sub-regions ($8000 vChars0 / $8800 vChars1/vFont / $9000 vChars2). That data
; is consumed by the software PPU's `tile_cache` (2bpp→8bpp decode). Any write
; to VRAM tile data MUST arm `g_tilecache_dirty` so render_bg re-decodes — every
; routine here that touches vChars does so (matches src/gfx/load_font.asm and
; src/engine/overworld/player_gfx.asm, the two established VRAM loaders).
;
; NATIVE-RENDERER SAFETY: these copies are LINEAR tile-byte streams. They make
; NO assumption about the GB 32×32 background-tilemap geometry (that path is the
; native 40×25 W_TILEMAP surface; see memory `renderer-native-viewport-invariant`).
; They only touch the vChars pattern area, never a $9800 tilemap.
;
; POINTER CONVENTION (matches load_font/player_gfx + town_map.asm call sites):
;   * a graphics SOURCE is a FLAT linear pointer (a `.data` label loaded with
;     `lea`), NOT EBP-relative — the graphics blobs live in the program image.
;   * a VRAM DESTINATION is an EBP-relative GB offset (e.g. GB_VCHARS0 + n*16).
;   This differs from the existing GB↔GB CopyData/FarCopyData (both operands
;   EBP-relative); the *Double / Video routines here are graphics loaders whose
;   source is always ROM/.data, so flat-src is the correct and consistent model.
;
; VBLANK STAGING: pret stages these through hVBlankCopy* HRAM + DelayFrame
; (c/8 frames). The port performs the copy IMMEDIATELY to VRAM (as load_font /
; player_gfx do) and arms g_tilecache_dirty; the render pipeline picks it up on
; the next DelayFrame. DIVERGENCE: the per-8-tile frame cadence is dropped. All
; current callers (town_map graphics setup) are static loads, so this is safe.
;
; Register map: HL→ESI, DE→EDX, BC→BX (B=BH, C=BL), A→AL.
;
; Build: nasm -f coff -I include/ -o copy2.o copy2.asm

bits 32

%include "gb_memmap.inc"

%assign TILE_1BPP_SIZE (TILE_SIZE / 2)      ; 8 bytes per 1bpp 8x8 tile
%define TILE_BLANK 0x7F                      ; charmap " " (TILE_SPC in text.asm)

extern g_tilecache_dirty                     ; src/ppu/ppu.asm — arm tile-cache re-decode
extern DelayFrame                            ; src/video/frame.asm — one-frame yield

global FarCopyDataDouble
global CopyVideoData
global CopyVideoDataDouble
global GetFarByte
global ClearScreenArea
global CopyScreenTileBufferToVRAM

section .text

; ---------------------------------------------------------------------------
; CopyVideoData — copy BL (C) 2bpp tiles from a flat source to VRAM.
; pret home/copy2.asm:CopyVideoData ("copy c 2bpp tiles from b:de to hl").
;
; In:  ESI = destination GB VRAM offset (EBP-relative, e.g. GB_VCHARS0 + n*16)
;      EDX = source FLAT pointer (2bpp tile data in .data / ROM)
;      BH  = source bank (NO-OP under the flat model)
;      BL  = tile count (each tile = TILE_SIZE = 16 bytes)
; Out: g_tilecache_dirty armed. EAX/ECX/ESI/EDI clobbered-then-restored; all
;      caller registers preserved (ESI/EDX are NOT advanced, unlike pret which
;      leaves updated pointers in the HRAM staging vars).
; ---------------------------------------------------------------------------
CopyVideoData:
    push eax
    push ecx
    push esi
    push edi
    mov byte [g_tilecache_dirty], 1
    movzx ecx, bl                    ; tile count
    imul ecx, ecx, TILE_SIZE         ; bytes = tiles * 16
    lea edi, [ebp + esi]             ; dest = EBP + GB VRAM offset
    mov esi, edx                     ; src = flat pointer
    rep movsb
    pop edi
    pop esi
    pop ecx
    pop eax
    ret

; ---------------------------------------------------------------------------
; CopyVideoDataDouble — expand BL (C) 1bpp tiles to 2bpp in VRAM.
; pret home/copy2.asm:CopyVideoDataDouble ("copy c 1bpp tiles from b:de to hl",
; each byte written twice → colors 0 or 3).
;
; In:  ESI = destination GB VRAM offset (EBP-relative)
;      EDX = source FLAT pointer (1bpp tile data)
;      BH  = source bank (NO-OP)
;      BL  = tile count (each 1bpp tile = TILE_1BPP_SIZE = 8 bytes → 16 out)
; Out: g_tilecache_dirty armed. Caller registers preserved.
; ---------------------------------------------------------------------------
CopyVideoDataDouble:
    push eax
    push ecx
    push esi
    push edi
    mov byte [g_tilecache_dirty], 1
    movzx ecx, bl                    ; tile count
    imul ecx, ecx, TILE_1BPP_SIZE    ; source bytes = tiles * 8
    lea edi, [ebp + esi]             ; dest = EBP + GB VRAM offset
    mov esi, edx                     ; src = flat pointer
.loop:
    lodsb                            ; al = [esi], esi++
    mov ah, al
    mov [edi], al                    ; low bitplane
    mov [edi + 1], ah                ; high bitplane (duplicate)
    add edi, 2
    dec ecx
    jnz .loop
    pop edi
    pop esi
    pop ecx
    pop eax
    ret

; ---------------------------------------------------------------------------
; FarCopyDataDouble — expand BX (BC) bytes of 1bpp data to 2bpp in VRAM.
; pret home/copy2.asm:FarCopyDataDouble ("expand bc bytes of 1bpp image data
; from a:hl to 2bpp data at de"). Note pret HL=source, DE=dest (opposite of the
; Video routines above) — faithfully preserved.
;
; In:  ESI = source FLAT pointer (1bpp data)
;      EDX = destination GB VRAM offset (EBP-relative)
;      BX  = source byte count (output = 2 * BX bytes)
;      AL  = source bank (NO-OP)
; Out: g_tilecache_dirty armed. Caller registers preserved.
; ---------------------------------------------------------------------------
FarCopyDataDouble:
    push eax
    push ecx
    push esi
    push edi
    mov byte [g_tilecache_dirty], 1
    movzx ecx, bx                    ; source byte count
    lea edi, [ebp + edx]             ; dest = EBP + GB VRAM offset
    ; esi already = source flat pointer
.loop:
    lodsb                            ; al = [esi], esi++
    mov ah, al
    mov [edi], al
    mov [edi + 1], ah
    add edi, 2
    dec ecx
    jnz .loop
    pop edi
    pop esi
    pop ecx
    pop eax
    ret

; ---------------------------------------------------------------------------
; GetFarByte — flat-model far byte read.
; pret home/copy2.asm:GetFarByte ("get a byte from a:hl and return it in a").
; Under the flat model banked ROM data lives at flat `.data` labels, so the
; bank (AL in) is a NO-OP and the pointer is a flat linear address.
;
; In:  ESI = FLAT pointer to the byte (a:hl → flat label)
;      AL  = source bank (NO-OP)
; Out: AL = [ESI]. ESI and all other registers preserved.
; ---------------------------------------------------------------------------
GetFarByte:
    mov al, [esi]
    ret

; ---------------------------------------------------------------------------
; ClearScreenArea — clear a BL×BH (width×height) tile region of W_TILEMAP.
; pret home/copy2.asm:ClearScreenArea ("clear tilemap area cxb at hl").
;
; NATIVE GEOMETRY: the row-advance stride is SCREEN_WIDTH, which the port
; redefines to SCREEN_TILES_W = 40 (NOT the GB 20). The software PPU scans
; W_TILEMAP at stride 40 for the menu/battle path, so 40 is the correct stride
; and matches town_map.asm's TM_COORD addressing. pret's literal `ld de,
; SCREEN_WIDTH` therefore translates faithfully — the constant carries the
; port's 40. (Blank tile = 0x7F, charmap " ".)
;
; In:  ESI = top-left destination GB offset into W_TILEMAP (EBP-relative)
;      BH  = height in rows (B)
;      BL  = width in cols (C)
; Out: region filled with 0x7F. ESI preserved; caller registers preserved.
; ---------------------------------------------------------------------------
ClearScreenArea:
    push eax
    push ebx
    push ecx
    push edx
    push edi
    mov al, TILE_BLANK
    movzx edx, bh                    ; row count
    movzx ebx, bl                    ; width (retained across rows)
    lea edi, [ebp + esi]             ; flat dest ptr
.rowLoop:
    mov ecx, ebx                     ; width
    rep stosb                        ; write `width` blanks; edi += width
    add edi, SCREEN_WIDTH            ; advance to same column on next row...
    sub edi, ebx                     ; ...= rowStart + SCREEN_WIDTH
    dec edx
    jnz .rowLoop
    pop edi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

; ---------------------------------------------------------------------------
; CopyScreenTileBufferToVRAM — make W_TILEMAP visible.
; pret home/copy2.asm:CopyScreenTileBufferToVRAM ("copy wTileMap to the BG Map
; ... in thirds of 6 rows ... 3 frames").
;
; PORT MODEL: the software PPU renders W_TILEMAP DIRECTLY every frame (render_bg,
; view-pointer = 0 path). There is no separate physical $9800 tilemap that the
; renderer scans in the menu/battle path — do_bg_transfer (frame.asm) is inert
; whenever H_AUTO_BG_TRANSFER_EN is 0, which is the case here. So the buffer is
; ALREADY on screen; there is nothing to copy. The routine's only observable
; contract is its 3-frame cost, which callers use for pacing — reproduced with
; three DelayFrame calls. Copies tilemap INDICES, not pattern data → does NOT
; arm g_tilecache_dirty.
;
; In:  BH (b) = target BG map high byte — IGNORED (native renderer owns W_TILEMAP).
; Out: waits 3 frames. Caller registers preserved.
; ---------------------------------------------------------------------------
CopyScreenTileBufferToVRAM:
    call DelayFrame
    call DelayFrame
    call DelayFrame
    ret
