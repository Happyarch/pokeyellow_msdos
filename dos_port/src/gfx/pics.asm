; pics.asm — mon-pic merge + placement pipeline (Wave 2, Stage 1c-ii).
;
; Source: home/pics.asm (pret/pokeyellow): LoadUncompressedSpriteData,
;   AlignSpriteDataCentered, ZeroSpriteBuffer, InterlaceMergeSpriteBuffers.
; Pairs with src/gfx/uncompress.asm (the byte-exact-validated decoder).
;
; Flow (front pic): UncompressSpriteData decodes the stream into the two dense,
; column-major 1bpp chunks in sSpriteBuffer1 / sSpriteBuffer2; this file then
;   1. zeroes buffer0 and copies+centers chunk1 (buffer1) into it,
;   2. zeroes buffer1 and copies+centers chunk2 (buffer2) into it,
;   3. interlaces buffer0(MSB) + buffer1(LSB) into the 7x7 2bpp sprite in
;      buffer1+2, then copies the 49 tiles to VRAM and marks the tile cache dirty.
; PlacePicTilemap then writes the 49 tile IDs into W_TILEMAP in the column-major
; order the merged buffer produces (faithful to CopyUncompressedPicToTilemap).
;
; Render path: the battle BG uses SIGNED tile addressing, so tile ID $00-$7F maps
; to VRAM $9000-$97F0 (vChars2). We place the front pic at VRAM $9000 (tile ID $00),
; clear of the box/HP-bar tiles the HUD loads at $60-$7F.
;
; Register map: A=AL, BC=BX, DE=DX, HL=ESI, EBP=GB base; GB memory = [EBP+addr].
;
%include "gb_memmap.inc"
%include "gb_constants.inc"

bits 32

%define FW         SCREEN_TILES_W       ; 40 — W_TILEMAP stride
%define PIC_SIZE   (7 * 7)              ; 49 tiles in the centered 7x7 sprite buffer
%define PIC_STAGE  0xA4A0               ; GB scratch for the compressed input stream
                                        ; (free SRAM just past sSpriteBuffer2 $A498)

extern UncompressSpriteData
extern g_tilecache_dirty

global LoadMonPicToVRAM
global LoadMonBackPicToVRAM
global PlacePicTilemap
global DrawEnemyFrontPic_Stub
global DrawPlayerBackPic_Stub

section .text

; ---------------------------------------------------------------------------
; LoadMonPicToVRAM — decode a compressed pic and assemble it into VRAM.
; In:  [wSpriteInputPtr] = GB addr of the staged compressed stream
;      [wSpriteFlipped]  = 0 front / 1 back
;      AL  = dimensions byte (hi nybble = height tiles, lo = width tiles)
;      EDX = destination VRAM GB address (e.g. GB_VCHARS2 = $9000)
; Out: 49 merged 2bpp tiles at [EDX]; g_tilecache_dirty set.
; ---------------------------------------------------------------------------
LoadMonPicToVRAM:
    mov [pic_dest], edx
    mov [pic_dims], al
    call UncompressSpriteData          ; -> buffer1 = chunk1, buffer2 = chunk2
    mov al, [pic_dims]
    ; fall through

; ---------------------------------------------------------------------------
; LoadUncompressedSpriteData — center each chunk in a 7x7 buffer, then merge.
; In: AL = dimensions byte.  Reuses [pic_dest] as the merge destination.
; ---------------------------------------------------------------------------
LoadUncompressedSpriteData:
    mov bl, al                         ; save dims byte
    and al, 0x0f                       ; width in tiles
    mov [hSpriteWidth], al
    mov bh, al
    mov al, 7
    sub al, bh                         ; 7-w
    inc al                             ; 8-w
    shr al, 1                          ; (8-w)/2  — horizontal center, tiles
    mov bh, al
    add al, al
    add al, al
    add al, al                         ; *8
    sub al, bh                         ; *7  — skip for horizontal center, in tiles
    mov [hSpriteOffset], al
    mov al, bl
    shr al, 4                          ; height in tiles (hi nybble)
    mov bh, al
    add al, al
    add al, al
    add al, al                         ; *8  — height in bytes
    mov [hSpriteHeight], al
    mov al, 7
    sub al, bh                         ; 7-h  — vertical center, tiles
    mov bh, al
    mov al, [hSpriteOffset]
    add al, bh                         ; 7*((8-w)/2) + (7-h)
    add al, al
    add al, al
    add al, al                         ; *8  — combined overall offset, in bytes
    mov [hSpriteOffset], al

    mov esi, sSpriteBuffer0
    call ZeroSpriteBuffer
    mov edx, sSpriteBuffer1            ; src chunk1
    mov esi, sSpriteBuffer0            ; -> buffer0 (becomes 2bpp MSB)
    call AlignSpriteDataCentered
    mov esi, sSpriteBuffer1
    call ZeroSpriteBuffer
    mov edx, sSpriteBuffer2            ; src chunk2
    mov esi, sSpriteBuffer1            ; -> buffer1 (becomes 2bpp LSB)
    call AlignSpriteDataCentered
    ; fall through to InterlaceMergeSpriteBuffers

; ---------------------------------------------------------------------------
; InterlaceMergeSpriteBuffers — interlace buffer0(MSB)+buffer1(LSB) into the 2bpp
; sprite spanning buffer1+buffer2 (rows of the two planes alternate), optionally
; nybble-swap for a flipped sprite, then copy the 49 tiles to [pic_dest] VRAM.
; ---------------------------------------------------------------------------
InterlaceMergeSpriteBuffers:
    mov edi, sSpriteBuffer2 + SPRITEBUFFERSIZE - 1   ; dest end (walk down)
    mov edx, sSpriteBuffer1 + SPRITEBUFFERSIZE - 1   ; source 2: buffer1 end
    mov esi, sSpriteBuffer0 + SPRITEBUFFERSIZE - 1   ; source 1: buffer0 end
    mov ecx, SPRITEBUFFERSIZE / 2
.interlace:
    mov al, [ebp + edx]
    dec edx
    mov [ebp + edi], al
    dec edi
    mov al, [ebp + esi]
    dec esi
    mov [ebp + edi], al
    dec edi
    mov al, [ebp + edx]
    dec edx
    mov [ebp + edi], al
    dec edi
    mov al, [ebp + esi]
    dec esi
    mov [ebp + edi], al
    dec edi
    dec ecx
    jnz .interlace

    cmp byte [ebp + wSpriteFlipped], 0
    je .notFlipped
    lea edi, [ebp + sSpriteBuffer1]                  ; flipped: swap nybbles, all bytes
    mov ecx, 2 * SPRITEBUFFERSIZE
.swap:
    mov al, [edi]
    rol al, 4
    mov [edi], al
    inc edi
    dec ecx
    jnz .swap
.notFlipped:
    lea esi, [ebp + sSpriteBuffer1]                  ; copy 49 tiles -> VRAM
    mov edi, [pic_dest]
    lea edi, [ebp + edi]
    mov ecx, PIC_SIZE * 16
    rep movsb
    mov byte [g_tilecache_dirty], 1
    ret

; ---------------------------------------------------------------------------
; AlignSpriteDataCentered — copy hSpriteWidth columns of hSpriteHeight bytes from
; [EDX] (source, read densely) into [ESI]+hSpriteOffset (dest), stepping the dest
; one full 7-tile column (56 bytes) between source columns. Centers the sprite.
; In: EDX = source GB addr, ESI = dest buffer GB addr.
; ---------------------------------------------------------------------------
AlignSpriteDataCentered:
    movzx eax, byte [hSpriteOffset]
    add esi, eax                       ; dest += centering offset
    mov cl, [hSpriteWidth]
.column:
    push esi
    mov ch, [hSpriteHeight]
.inner:
    mov al, [ebp + edx]
    inc edx
    mov [ebp + esi], al
    inc esi
    dec ch
    jnz .inner
    pop esi
    add esi, 7 * TILE_1BPP_SIZE         ; advance one full column (7 tiles)
    dec cl
    jnz .column
    ret

; ---------------------------------------------------------------------------
; ZeroSpriteBuffer — zero SPRITEBUFFERSIZE bytes at [ESI]. Preserves ESI.
; ---------------------------------------------------------------------------
ZeroSpriteBuffer:
    push esi
    lea edi, [ebp + esi]
    xor al, al
    mov ecx, SPRITEBUFFERSIZE
    rep stosb
    pop esi
    ret

; ---------------------------------------------------------------------------
; LoadMonBackPicToVRAM — decode a back pic, scale it 2x (4x4 -> 7x7), merge to VRAM.
; In:  [wSpriteInputPtr] = staged stream, [wSpriteFlipped] = flag, EDX = dest VRAM.
; ---------------------------------------------------------------------------
LoadMonBackPicToVRAM:
    mov [pic_dest], edx
    call UncompressSpriteData           ; buffer1 = chunk1, buffer2 = chunk2 (4x4 dense)
    call ScaleSpriteByTwo               ; buffer0 = scaled chunk1, buffer1 = scaled chunk2
    call InterlaceMergeSpriteBuffers
    ret

; ---------------------------------------------------------------------------
; ScaleSpriteByTwo — scale both 4x4-tile chunks 2x into 7x7 chunks (2x2 output
; pixels per input pixel; rightmost/bottommost 4 px ignored). Source: pret
; engine/battle/scale_sprites.asm. chunk1(buffer1)->buffer0, chunk2(buffer2)->buffer1.
; ---------------------------------------------------------------------------
ScaleSpriteByTwo:
    mov edx, sSpriteBuffer1 + (4*4*8) - 5    ; last input byte (last 4 rows pre-skipped)
    mov esi, sSpriteBuffer0 + SPRITEBUFFERSIZE - 1
    call ScaleLastSpriteColumnByTwo          ; last tile column is a special case
    call ScaleFirstThreeSpriteColumnsByTwo
    mov edx, sSpriteBuffer2 + (4*4*8) - 5
    mov esi, sSpriteBuffer1 + SPRITEBUFFERSIZE - 1
    call ScaleLastSpriteColumnByTwo
    call ScaleFirstThreeSpriteColumnsByTwo
    ret

; In: EDX = source (read backward), ESI = dest (written backward).
ScaleFirstThreeSpriteColumnsByTwo:
    mov bh, 3                          ; 3 tile columns
.column:
    mov bl, 4*8 - 4                    ; 0x1c — 4 tiles minus 4 unused rows
.inner:
    push ebx
    mov al, [ebp + edx]
    mov bx, -(7*8) + 1                 ; scale low nybble, seek to previous output column
    call ScalePixelsByTwo
    mov al, [ebp + edx]
    dec dx
    rol al, 4                          ; swap a
    mov bx, 7*8 + 1 - 2                ; scale high nybble, seek back + to next 2 rows
    call ScalePixelsByTwo
    pop ebx
    dec bl
    jnz .inner
    sub dx, 4                          ; skip 4 unused rows of the input column
    mov al, bh
    mov bx, -7*8                       ; skip the already-written output column
    add si, bx
    mov bh, al
    dec bh
    jnz .column
    ret

; In: EDX = source, ESI = dest. Only the high nybble of each input byte is used.
ScaleLastSpriteColumnByTwo:
    mov byte [hSpriteScaleCtr], 4*8 - 4
.inner:
    mov al, [ebp + edx]
    dec dx
    rol al, 4                          ; swap a — high nybble holds the info
    mov bx, -1
    call ScalePixelsByTwo
    dec byte [hSpriteScaleCtr]
    jnz .inner
    sub dx, 4
    ret

; ScalePixelsByTwo — scale the low 4 bits of AL (4x1 px) to 2 output bytes (8x2 px):
; write DuplicateBitsTable[AL&0xf] to [ESI] and [ESI-1], then ESI += BX (signed).
; In: AL = byte, ESI = dest (hl), BX = signed offset (bc). Clobbers EAX, ECX.
ScalePixelsByTwo:
    push esi
    and al, 0x0f
    movzx ecx, al
    mov al, [DuplicateBitsTable + ecx]
    pop esi
    mov [ebp + esi], al                ; write byte twice (2 px tall)
    dec si
    mov [ebp + esi], al
    add si, bx                         ; advance dest by offset
    ret

; ---------------------------------------------------------------------------
; PlacePicTilemap — write a 7x7 block of tile IDs into W_TILEMAP, column-major
; (ID = base + col*7 + row), matching the merged buffer's tile order.
; In: EDI = [ebp + W_TILEMAP + topleft] dest, AL = base tile ID.
; ---------------------------------------------------------------------------
PlacePicTilemap:
    mov bl, al                         ; running tile ID
    mov ecx, 7                         ; columns
.col:
    push edi
    push ecx
    mov ecx, 7                         ; rows
    mov al, bl
.row:
    mov [edi], al
    add edi, FW
    inc al
    dec ecx
    jnz .row
    mov bl, al                         ; next column continues the ID sequence
    pop ecx
    pop edi
    inc edi                            ; next column to the right
    dec ecx
    jnz .col
    ret

; ---------------------------------------------------------------------------
; DrawEnemyFrontPic_Stub — STAGE-1c TEST STOPGAP. Stages an embedded pic, decodes
; + merges it to VRAM $9000, and places it top-right on the battle canvas.
; The real path (Stage 2/3) reads the enemy species -> a pic-pointer table and
; loads the matching pic; this hard-codes one mon so the decode/merge/placement
; can be visually gated now. Called from the DEBUG_BATTLE harness, not InitBattle.
; ---------------------------------------------------------------------------
DrawEnemyFrontPic_Stub:
    mov esi, embedded_pic              ; stage compressed stream into GB space
    lea edi, [ebp + PIC_STAGE]
    mov ecx, embedded_pic_len
    rep movsb
    mov word [ebp + wSpriteInputPtr], PIC_STAGE
    mov byte [ebp + wSpriteFlipped], 0
    mov al, [embedded_pic]             ; dims byte
    mov edx, GB_VCHARS2                ; VRAM $9000 -> signed tile ID $00
    call LoadMonPicToVRAM
    ; place 7x7 at canvas (22,3): enemy pic top-right (GB (12,0) + center +10col/+3row)
    ; PROJ battle-ui: GB(12,0) 7x7 enemy front pic --(center +10/+3)--> canvas(22,3)
    lea edi, [ebp + W_TILEMAP + 3 * FW + 22]
    mov al, 0x00                       ; base tile ID (VRAM $9000)
    call PlacePicTilemap
    ret

; ---------------------------------------------------------------------------
; DrawPlayerBackPic_Stub — STAGE-1c TEST STOPGAP (see DrawEnemyFrontPic_Stub).
; Stages an embedded back pic, decodes + scales + merges it to VRAM $9310, and
; places it bottom-left. Real path (Stage 2/3): from the player's party species.
; ---------------------------------------------------------------------------
DrawPlayerBackPic_Stub:
    mov esi, embedded_backpic
    lea edi, [ebp + PIC_STAGE]
    mov ecx, embedded_backpic_len
    rep movsb
    mov word [ebp + wSpriteInputPtr], PIC_STAGE
    mov byte [ebp + wSpriteFlipped], 0     ; player back pic is not mirrored
    mov edx, GB_VCHARS2 + 0x31 * 16        ; VRAM $9310 -> signed tile ID $31
    call LoadMonBackPicToVRAM
    ; place 7x7 at canvas (11,8): player pic bottom-left (GB (1,5) + center +10col/+3row)
    ; PROJ battle-ui: GB(1,5) 7x7 player back pic --(center +10/+3)--> canvas(11,8)
    lea edi, [ebp + W_TILEMAP + 8 * FW + 11]
    mov al, 0x31                       ; base tile ID (VRAM $9310)
    call PlacePicTilemap
    ret

; ---------------------------------------------------------------------------
section .data
align 4
embedded_pic:
    incbin "../gfx/pokemon/front/pidgey.pic"
embedded_pic_len equ $ - embedded_pic
embedded_backpic:
    incbin "../gfx/pokemon/back/pikachub.pic"
embedded_backpic_len equ $ - embedded_backpic

; repeats each input bit twice, e.g. DuplicateBitsTable[%0101] = %00110011
DuplicateBitsTable:
    db 0x00, 0x03, 0x0C, 0x0F, 0x30, 0x33, 0x3C, 0x3F
    db 0xC0, 0xC3, 0xCC, 0xCF, 0xF0, 0xF3, 0xFC, 0xFF

; ---------------------------------------------------------------------------
section .bss
align 4
pic_dest:       resd 1                 ; merge destination VRAM GB addr
hSpriteWidth:   resb 1                 ; tiles
hSpriteHeight:  resb 1                 ; bytes (tiles*8)
hSpriteOffset:  resb 1                 ; centering offset, bytes
hSpriteScaleCtr: resb 1                ; ScaleLastSpriteColumnByTwo inner counter
pic_dims:       resb 1
