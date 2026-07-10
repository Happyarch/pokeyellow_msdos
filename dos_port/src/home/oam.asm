; oam.asm — WriteOAMBlock translated from SM83 to x86.
;
; Source: home/oam.asm:WriteOAMBlock (pret/pokeyellow).
; Intended path: dos_port/src/home/oam.asm
;
; WriteOAMBlock writes a 2x2 block of OAM entries (used by Cut/emotion-bubble/
; trade animations). In pret it targets wShadowOAM ($C300), the 40-entry shadow
; buffer that the DMA routine copies to real OAM ($FE00) each VBlank. THIS PORT
; USES THE SAME SHADOW-OAM MODEL: PrepareOAMData (src/gfx/sprite_oam.asm) builds
; wShadowOAM (= W_SHADOW_OAM, $C300) and frame.asm:update_oam DMA-copies it to
; GB_OAM ($FE00) each frame; the software PPU (ppu.asm render_sprites) reads the
; 4-byte-per-entry (Y, X, tile, attr) layout out of $FE00. So writing the same
; (Y, X, tile, attr) layout into wShadowOAM is exactly faithful — this is NOT
; GB-OAM-torus/tilemap geometry, it is the flat 4-bytes-per-sprite array the
; renderer already consumes.
;
; INPUT (pret contract, mapped to the port register map):
;   AL = OAM block index (each block = 4 OAM entries = 16 shadow-OAM bytes)
;        pret: `swap a` (a << 4) gives the low byte of the wShadowOAM slot.
;   BH = Y coordinate of the upper-left corner of the block  (pret b)
;   BL = X coordinate of the upper-left corner of the block  (pret c)
;   EDX = FLAT pointer to the 4 (tile, attribute) pairs        (pret de)
;        i.e. 8 source bytes: tile0,attr0, tile1,attr1, tile2,attr2, tile3,attr3.
;        These blocks are flat image labels (.data), not GB WRAM offsets.
;
; The four entries are emitted in pret's order:
;   upper-left  (Y=b,   X=c)
;   upper-right (Y=b,   X=c+8)
;   lower-left  (Y=b+8, X=c)
;   lower-right (Y=b+8, X=c+8)
; Each entry consumes one (tile, attr) pair from DE in sequence.
;
; All registers preserved (leaf-style: caller state is unchanged on return).
;
; Build: nasm -f coff -I include/ -o oam.o oam.asm

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"

global WriteOAMBlock

section .text

; ---------------------------------------------------------------------------
; WriteOAMBlock — write a 2x2 sprite block into shadow OAM (wShadowOAM).
; ---------------------------------------------------------------------------
WriteOAMBlock:
    push eax
    push ebx
    push esi
    push edi

    ; destination = ebp + W_SHADOW_OAM + (block_index << 4)   (pret: swap a; ld l,a)
    movzx edi, al
    shl   edi, 4
    lea   edi, [ebp + edi + W_SHADOW_OAM]

    ; source = flat pointer in EDX. pret's `de` is the ROM base address of the
    ; tile/attr pairs; in the flat port those OAM-block tables are flat image
    ; labels (.data), NOT GB WRAM offsets — so take EDX as a full flat pointer
    ; rather than biasing a 16-bit offset by ebp. (.writeOneEntry already reads
    ; the source flat via [esi].)  Callers: pass the block label in EDX.
    mov   esi, edx

    ; BH = Y (pret b), BL = X (pret c)
    call .writeOneEntry             ; upper left  (Y=b,   X=c)
    add  bl, 8                      ; c += 8
    call .writeOneEntry             ; upper right (Y=b,   X=c+8)
    sub  bl, 8                      ; restore c   (pret pop bc)
    add  bh, 8                      ; b += 8
    call .writeOneEntry             ; lower left  (Y=b+8, X=c)
    add  bl, 8                      ; c += 8
    call .writeOneEntry             ; lower right (Y=b+8, X=c+8)

    pop edi
    pop esi
    pop ebx
    pop eax
    ret

; ---------------------------------------------------------------------------
; .writeOneEntry — write one 4-byte OAM entry, advance cursors.
;   In:  EDI = dest cursor (flat), ESI = source cursor (flat),
;        BH = Y, BL = X.
;   Out: EDI += 4, ESI += 2. Clobbers AL (restored by the outer push eax).
;   Layout matches the renderer: byte0=Y, byte1=X, byte2=tile, byte3=attr.
; ---------------------------------------------------------------------------
.writeOneEntry:
    mov [edi],   bh                 ; Y coordinate   (pret: ld [hl], b)
    mov [edi+1], bl                 ; X coordinate   (pret: ld [hl], c)
    mov al, [esi]                   ; tile number    (pret: ld a,[de]; ld [hli],a)
    mov [edi+2], al
    mov al, [esi+1]                 ; attribute      (pret: ld a,[de]; ld [hli],a)
    mov [edi+3], al
    add edi, 4
    add esi, 2
    ret
