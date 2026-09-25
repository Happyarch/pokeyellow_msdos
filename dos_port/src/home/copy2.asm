; copy2.asm — VRAM tile-data copy family + screen-area helpers.
;
; Source: home/copy2.asm (pret/pokeyellow) — the complete pret file:
;         IsTilePassable, FarCopyDataDouble, CopyVideoData, CopyVideoDataDouble,
;         FillMemory, GetFarByte, ClearScreenArea, CopyScreenTileBufferToVRAM,
;         ClearScreen.
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
; native 40×25 wTileMap surface; see memory `renderer-native-viewport-invariant`).
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
; the next DelayFrame. DIVERGENCE: the per-8-tile frame cadence is dropped. Every
; current caller is a synchronous graphics/VRAM load — CopyVideoDataDouble from
; town_map, ledges and printer2, FarCopyDataDouble from town_map, CopyVideoData
; from the overworld/battle/movie loaders — and none depends on the intermediate
; frames.
;
; Register map: HL→ESI, DE→EDX, BC→BX (B=BH, C=BL), A→AL.
;
; Build: nasm -f coff -I include/ -o copy2.o copy2.asm

bits 32

%include "gb_memmap.inc"

%assign TILE_1BPP_SIZE (TILE_SIZE / 2)      ; 8 bytes per 1bpp 8x8 tile
%define TILE_BLANK 0x7F                      ; charmap " " (TILE_SPC in text.asm)

extern g_tilecache_dirty                     ; src/ppu/ppu.asm — arm tile-cache re-decode
extern DelayFrame                            ; src/home/vblank.asm — one-frame yield
extern Delay3                                ; src/home/palettes.asm
extern _IsTilePassable                       ; src/engine/gfx/sprite_oam.asm — CL=tile → CF

global IsTilePassable
global FarCopyDataDouble
global CopyVideoData
global CopyVideoDataDouble
global FillMemory
global GetFarByte
global ClearScreenArea
global CopyScreenTileBufferToVRAM
global ClearScreen

section .text

; ---------------------------------------------------------------------------
; IsTilePassable — sets carry if tile is NOT passable, clears carry otherwise.
; pret home/copy2.asm:IsTilePassable — `homecall_sf _IsTilePassable / ret`,
; i.e. a bank trampoline around _IsTilePassable (engine/gfx/sprite_oam.asm).
; Flat model: the bank switch is a no-op, so the trampoline is a tail jump.
;
; In:  CL = tile ID.  Out: CF = 0 passable, CF = 1 blocked. Clobbers AL, ESI.
; ---------------------------------------------------------------------------
IsTilePassable:
    jmp _IsTilePassable                      ; pret: homecall_sf _IsTilePassable

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
    lea edi, [ebp + esi]             ; dest = EBP + GB VRAM offset
    mov esi, edx                     ; src = flat pointer
    ; COUNTER WIDTH: pret expands CL (C) 1bpp tiles, 8 source bytes → 16 dest bytes
    ; each. Its c=0 path is NOT a wrap: `cp 8 / jr nc` fails, so the routine arms
    ; hVBlankCopyDoubleSize = 0 and VBlankCopyDouble's own `and a / ret z`
    ; (home/vcopy.asm:232-234) copies nothing — 0 tiles, not 256. Keep CL 8-bit
    ; (`dec cl`) and dispatch c=0 to .done to reproduce that for EVERY input.
    ; `movzx ecx, bl` + `imul ecx,16` + `dec ecx` wrapped 0 → ~4.29e9 and walked
    ; EDI off the DPMI allocation.
    mov cl, bl                       ; ld c, b — tile count (8-bit)
    test cl, cl
    jz .done                         ; pret: c=0 → hVBlankCopyDoubleSize 0 → 0 tiles
.tileLoop:
    mov ch, TILE_1BPP_SIZE           ; 8 source bytes per 1bpp tile
.expandLoop:
    lodsb                            ; ld a, [de] / inc de
    mov ah, al
    mov [edi], al                    ; low bitplane
    mov [edi + 1], ah                ; high bitplane (duplicate)
    add edi, 2
    dec ch
    jnz .expandLoop
    dec cl                           ; dec c — 8-bit tile counter (pret's bound)
    jnz .tileLoop
.done:
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
;      BX  = source byte count (output = 2 * BX bytes; BC is a 16-bit count)
;      AL  = source bank (NO-OP)
; Out: g_tilecache_dirty armed. Caller registers preserved.
; ---------------------------------------------------------------------------
FarCopyDataDouble:
    push eax
    push ecx
    push esi
    push edi
    mov byte [g_tilecache_dirty], 1
    lea edi, [ebp + edx]             ; dest = EBP + GB VRAM offset
    ; esi already = source flat pointer
    ; COUNTER WIDTH: pret's loop is TWO 8-bit counters (`dec c` inner, `dec b`
    ; outer) with a normalization pass that makes BX a true 16-bit byte count:
    ;   b==0            → inc b        (so b=0,c=0 copies 256 — pret's own answer)
    ;   b!=0 and c==0   → do NOT inc b (the first `dec c` underflows to 256)
    ;   otherwise       → inc b
    ; `movzx ecx, bx` + `dec ecx` wrapped BX=0 to ~4.29e9 and walked EDI off the
    ; DPMI allocation. Reproduced exactly, including the c-underflow re-entry.
    mov cl, bl                       ; ld c, b   (low byte  = inner count)
    mov ch, bh                       ; ld b, b   (high byte = outer count)
    test ch, ch
    jnz .bNonzero
    inc ch                           ; pret: b==0 → inc b
    jmp .expandLoop
.bNonzero:
    test cl, cl
    jnz .incB                        ; b!=0, c!=0 → pret falls into .eightbitcopyamount
    jmp .expandLoop                  ; b!=0, c==0 → skip inc b (do not underflow early)
.incB:
    inc ch
.expandLoop:
    lodsb                            ; pret: ld a, [de] / inc de  (pret swaps hl/de)
    mov ah, al
    mov [edi], al                    ; ld [hli], a
    mov [edi + 1], ah                ; ld [hli], a
    add edi, 2
    dec cl                           ; dec c — 8-bit inner
    jnz .expandLoop
    dec ch                           ; dec b — 8-bit outer
    jnz .expandLoop                  ; pret: jr nz, .expandloop (c underflowed to 256)
    pop edi
    pop esi
    pop ecx
    pop eax
    ret

; ---------------------------------------------------------------------------
; FillMemory — fill BX bytes at [EBP+ESI] with AL.
; pret home/copy2.asm:FillMemory ("fill bc bytes at hl with a"). The SM83
; double-loop (inc b when c!=0, nested 8-bit loops) collapses to movzx+rep stosb;
; semantics match pret for all counts 1..65535.
;
; In:  ESI = destination offset (GB address, EBP-relative)
;      BX  = byte count (16-bit)
;      AL  = fill value
; Out: ESI/EBX/EAX unchanged (EDI/ECX scratch, saved). DF must be 0 (always is
;      under DJGPP). CF not touched.
; ---------------------------------------------------------------------------
FillMemory:
    push ecx
    push edi
    movzx   ecx, bx              ; zero-extend 16-bit BC count to full 32 bits
                                 ; count=0 → ECX=0 → rep stosb no-op.
                                 ; DIVERGENCE: pret FillMemory(BC=0) writes 256
                                 ; bytes (B=0→inc b→1, then C=0 underflows the
                                 ; inner loop 256×). The port writes 0. Safe: no
                                 ; caller passes BC=0 expecting 256 (callers that
                                 ; want 256 pass $100). Intentionally NOT emulated.
    lea     edi, [ebp + esi]     ; flat destination: EBP base + GB-space offset
    rep stosb                    ; fill ECX bytes at ES:EDI with AL
                                 ; ES = DS = flat selector under DJGPP
    pop edi
    pop ecx
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
; ClearScreenArea — clear a BL×BH (width×height) tile region of wTileMap.
; pret home/copy2.asm:ClearScreenArea ("clear tilemap area cxb at hl").
;
; NATIVE GEOMETRY: the row-advance stride is SCREEN_WIDTH, which the port
; redefines to SCREEN_TILES_W = 40 (NOT the GB 20). The software PPU scans
; wTileMap at stride 40 for the menu/battle path, so 40 is the correct stride
; and matches town_map.asm's TM_COORD addressing. pret's literal `ld de,
; SCREEN_WIDTH` therefore translates faithfully — the constant carries the
; port's 40. (Blank tile = 0x7F, charmap " ".)
;
; In:  ESI = top-left destination GB offset into wTileMap (EBP-relative)
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
    ; COUNTER WIDTH: pret is `dec b / jr nz` — 8-BIT, so a row count of 0 clears
    ; 256 rows and stops. `dec edx` on the movzx'd value runs ~4 billion times
    ; and walks EDI off the allocation. `dec dl` IS pret's bound, reproduced
    ; exactly, so nothing diverges and no annotation is owed.
    ; (The WIDTH counter is a separate, still-open divergence: `rep stosb` with
    ; ECX=0 writes NOTHING where pret's inner `dec c` writes 256. It needs pret's
    ; inner-loop shape, not a register narrowing. Every observed ClearScreenArea
    ; call site in the tree passes a literal nonzero width, so the c=0 case is
    ; latent rather than currently reached.)
    dec dl
    jnz .rowLoop
    pop edi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

; ---------------------------------------------------------------------------
; CopyScreenTileBufferToVRAM — make wTileMap visible.
; pret home/copy2.asm:CopyScreenTileBufferToVRAM ("copy wTileMap to the BG Map
; ... in thirds of 6 rows ... 3 frames").
;
; PORT MODEL: the software PPU renders wTileMap DIRECTLY every frame (render_bg,
; view-pointer = 0 path). There is no separate physical $9800 tilemap that the
; renderer scans in the menu/battle path — do_bg_transfer (vblank.asm) is inert
; whenever hAutoBGTransferEnabled is 0, which is the case here. So the buffer is
; ALREADY on screen; there is nothing to copy. The routine's only observable
; contract is its 3-frame cost, which callers use for pacing — reproduced with
; three DelayFrame calls. Copies tilemap INDICES, not pattern data → does NOT
; arm g_tilecache_dirty.
;
; In:  BH (b) = target BG map high byte — IGNORED (native renderer owns wTileMap).
; Out: waits 3 frames. Caller registers preserved.
; ---------------------------------------------------------------------------
CopyScreenTileBufferToVRAM:
    call DelayFrame
    call DelayFrame
    call DelayFrame
    ret

; ---------------------------------------------------------------------------
; ClearScreen — fill wTileMap with $7F (space), enable auto-BG-transfer,
; wait 3 frames.
; Source: home/copy2.asm:ClearScreen
; ---------------------------------------------------------------------------
ClearScreen:
    push esi
    push ebx
    push eax
    mov esi, wTileMap
    mov bx,  SCREEN_AREA & 0xFFFF
    mov al,  0x7F
    call FillMemory
    mov byte [ebp + hAutoBGTransferEnabled], 1
    pop eax
    pop ebx
    pop esi
    jmp Delay3    ; tail call
