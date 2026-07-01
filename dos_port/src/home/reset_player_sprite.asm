; reset_player_sprite.asm — ResetPlayerSpriteData translated from SM83 to x86.
;
; Source: home/reset_player_sprite.asm:ResetPlayerSpriteData /
;         ResetPlayerSpriteData_ClearSpriteData (pret/pokeyellow).
; Intended path: dos_port/src/home/reset_player_sprite.asm
;
; Faithful FULL version. The audit noted the port previously inlined only the
; value-set (picture id / image-base offset / Y,X screen pos) and omitted the
; two-block FillMemory zero-clear of slot 0 of wSpriteStateData1/2. This
; restores the complete pret behaviour:
;   1. zero-clear slot 0 (16 bytes) of wSpriteStateData1 via FillMemory,
;   2. zero-clear slot 0 (16 bytes) of wSpriteStateData2 via FillMemory,
;   3. picture id = 1  (wSpritePlayerStateData1PictureID, $C100),
;   4. image-base offset = 1 (wSpritePlayerStateData2ImageBaseOffset, $C20E),
;   5. Y screen pos = $3c (wSpritePlayerStateData1YPixels, $C104),
;   6. X screen pos = $40 (wSpritePlayerStateData1XPixels, $C106).
;
; pret asserts SPRITESTATEDATA2_LENGTH == SPRITESTATEDATA1_LENGTH; both equal
; the $10-byte slot stride. The port carries that stride as
; SPRITESTATEDATA_STRUCT_SIZE (gb_memmap.inc = 0x10), used here as the clear
; count so no pending-symbol dependency is introduced.
;
; Build: nasm -f coff -I include/ -o reset_player_sprite.o reset_player_sprite.asm

bits 32

%include "gb_memmap.inc"
%include "gb_macros.inc"

global ResetPlayerSpriteData
global ResetPlayerSpriteData_ClearSpriteData

extern FillMemory                   ; src/home/fill_memory.asm

section .text

; ---------------------------------------------------------------------------
; ResetPlayerSpriteData — clear + initialize the player sprite (slot 0).
;   No inputs. Preserves EAX/EBX/ESI (the regs it touches); ECX clobbered via
;   FillMemory (matches pret, which clobbers freely).
; ---------------------------------------------------------------------------
ResetPlayerSpriteData:
    push eax
    push ebx
    push esi

    mov esi, W_SPRITE_STATE_DATA_1              ; ld hl, wSpriteStateData1
    call ResetPlayerSpriteData_ClearSpriteData
    mov esi, W_SPRITE_STATE_DATA_2              ; ld hl, wSpriteStateData2
    call ResetPlayerSpriteData_ClearSpriteData

    mov byte [ebp + W_SPRITE_PLAYER_PICTURE_ID], 1        ; ld a,1; ld [..PictureID],a
    mov byte [ebp + W_SPRITE_PLAYER_IMAGE_BASE_OFFSET], 1 ; ld [..ImageBaseOffset],a
    mov byte [ebp + W_SPRITE_PLAYER_Y_PIXELS], 0x3c       ; ld [hl],$3c (Y screen pos)
    mov byte [ebp + W_SPRITE_PLAYER_X_PIXELS], 0x40       ; inc hl; inc hl; ld [hl],$40

    pop esi
    pop ebx
    pop eax
    ret

; ---------------------------------------------------------------------------
; ResetPlayerSpriteData_ClearSpriteData — zero one sprite-data slot.
;   In:  ESI = GB offset of the slot to clear (data1 or data2 base).
;   Fills SPRITESTATEDATA_STRUCT_SIZE (0x10) bytes with 0 via FillMemory.
;   FillMemory takes ESI=dest, BX=count, AL=fill; preserves ESI/EAX/EBX.
; ---------------------------------------------------------------------------
ResetPlayerSpriteData_ClearSpriteData:
    push eax
    push ebx
    mov bx, SPRITESTATEDATA_STRUCT_SIZE         ; ld bc, SPRITESTATEDATA1_LENGTH (0x10)
    xor al, al                                  ; xor a  (fill value 0)
    call FillMemory                             ; call FillMemory
    pop ebx
    pop eax
    ret
