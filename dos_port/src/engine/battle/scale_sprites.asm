; dos_port/src/engine/battle/scale_sprites.asm
; ============================================================
; Mirror of pret engine/battle/scale_sprites.asm. Holds every label of that file,
; in pret order: ScaleSpriteByTwo, ScaleFirstThreeSpriteColumnsByTwo,
; ScaleLastSpriteColumnByTwo, ScalePixelsByTwo, DuplicateBitsTable.
;
; They arrived from src/home/pics.asm, which calls ScaleSpriteByTwo out of
; LoadMonBackPicToVRAM and keeps the rest of the pic-loading family.
;
; DEVIATION{class=banking; pret=engine/battle/scale_sprites.asm:ScaleSpriteByTwo; behavior=no OpenSRAM/CloseSRAM wrapper around the scaling body, so pret ScaleSpriteByTwo and its .ScaleSpriteByTwo inner label collapse into one routine; evidence=port flat DPMI address space with SRAM mapped unconditionally at $A000 per gb_memmap.inc sSpriteBuffer0, and pret ScaleSpriteByTwo whose outer body is only the bank open plus close; lifetime=permanent under the flat memory model}
;
; Register map: a=AL, b=BH, c=BL (bc=EBX), d=DH, e=DL (de=EDX), hl=ESI,
; EBP = GB memory base. The sprite buffers are GB SRAM ($A000+), so they are
; addressed [EBP+...]; DuplicateBitsTable is flat program-image data.
;
; Build: nasm -f coff -I include/ -I . -o scale_sprites.o scale_sprites.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

global ScaleSpriteByTwo

section .text

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
section .data


; repeats each input bit twice, e.g. DuplicateBitsTable[%0101] = %00110011
DuplicateBitsTable:
    db 0x00, 0x03, 0x0C, 0x0F, 0x30, 0x33, 0x3C, 0x3F
    db 0xC0, 0xC3, 0xCC, 0xCF, 0xF0, 0xF3, 0xFC, 0xFF


section .bss
hSpriteScaleCtr: resb 1                ; ScaleLastSpriteColumnByTwo inner counter

