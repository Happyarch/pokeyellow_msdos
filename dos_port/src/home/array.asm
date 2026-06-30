; dos_port/home/array.asm
bits 32
%include "gb_constants.inc"     ; NAME_LENGTH

global SkipFixedLengthTextEntries
global AddNTimes
global IsInArray

section .text

; ---------------------------------------------------------------------------
; IsInArray — pret home/array2.asm:IsInArray (shared home global).
; Search a $FF(-1)-terminated array at ESI (HL) for the value in AL (A).
; Entry size is EDX (DE) bytes. Returns CF=1 and BH (B) = 0-based index of the
; match if found; CF=0 if the terminator is reached first.
; Reads the array with FLAT addressing ([ESI]) — the effect-category arrays and
; HM/move tables that use this live in program .data (flat), not GB WRAM.
; In:  AL = value, ESI = array base (flat), EDX = entry stride (bytes).
; Out: CF = found, BH = count/index. Clobbers ESI (advances), BH, CL. AL/EDX kept.
; ---------------------------------------------------------------------------
IsInArray:
    xor bh, bh                  ; ld b, 0  (running count → match index)
.loop:
    mov cl, [esi]               ; ld a, [hl] — flat read
    cmp cl, 0xFF                ; cp -1 → terminator?
    je .notfound
    cmp cl, al                  ; cp c
    je .found
    inc bh                      ; inc b
    add esi, edx                ; add hl, de (advance by stride)
    jmp .loop
.notfound:
    clc
    ret
.found:
    stc
    ret

; skips AL (A) text entries, each of size NAME_LENGTH
; ESI (HL): base pointer, will be incremented by NAME_LENGTH * AL
SkipFixedLengthTextEntries:
    test al, al
    jz .done
    movzx eax, al
    mov ecx, NAME_LENGTH
    imul ecx, eax
    add esi, ecx
    xor al, al
    mov bx, NAME_LENGTH
.done:
    ret

; add BX (BC) to ESI (HL) AL (A) times
AddNTimes:
    test al, al
    jz .done2
    movzx eax, al
    movzx ecx, bx
    imul ecx, eax
    add esi, ecx
    xor al, al
.done2:
    ret
