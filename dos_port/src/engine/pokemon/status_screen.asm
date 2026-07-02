bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

SECTION .text

global CalcExpToLevelUp

extern CalcExperience

CalcExpToLevelUp:
    ; ld a, [wLoadedMonLevel]
    mov al, [ebp + wLoadedMonLevel]

    ; cp MAX_LEVEL
    cmp al, MAX_LEVEL
    
    ; jr z, .atMaxLevel
    jz .atMaxLevel

    ; inc a
    inc al

    ; ld d, a
    mov dh, al

    ; callfar CalcExperience
    call CalcExperience

    ; ld hl, wLoadedMonExp + 2
    mov esi, wLoadedMonExp + 2

    ; ldh a, [hExperience + 2]
    mov al, [ebp + hExperience + 2]

    ; sub [hl]
    sub al, [ebp + esi]

    ; ld [hld], a
    mov [ebp + esi], al
    dec esi

    ; ldh a, [hExperience + 1]
    mov al, [ebp + hExperience + 1]

    ; sbb [hl]
    sbb al, [ebp + esi]

    ; ld [hld], a
    mov [ebp + esi], al
    dec esi

    ; ldh a, [hExperience]
    mov al, [ebp + hExperience]

    ; sbb [hl]
    sbb al, [ebp + esi]

    ; ld [hld], a
    mov [ebp + esi], al
    dec esi

    ret

.atMaxLevel:
    ; ld hl, wLoadedMonExp
    mov esi, wLoadedMonExp

    ; xor a
    xor al, al

    ; ld [hli], a
    mov [ebp + esi], al
    inc esi

    ; ld [hli], a
    mov [ebp + esi], al
    inc esi

    ; ld [hl], a
    mov [ebp + esi], al

    ret
