; dos_port/engine/math/multiply_divide.asm
;
; _Multiply / _Divide — emulate the Game Boy 24-bit×8-bit multiply and the
; multi-byte ÷ 8-bit divide, preserving the exact HRAM scratch side-effects so
; callers (CalcStat, CalcExperience, damage calc, …) see identical results.
;
; Source: engine/math/multiply_divide.asm (pret/pokeyellow).
;
; HRAM map (gb_memmap.inc): hProduct=FF95(4) ; hMultiplicand=FF96(3) ;
; hMultiplier=FF99 ; hDividend=FF95(4) ; hDivisor=FF99 ; hQuotient=FF95(4) ;
; hRemainder=FF99. (Quotient overlaps dividend; remainder overlaps divisor.)

%include "gb_macros.inc"
%include "gb_memmap.inc"

section .text

global _Multiply
global _Divide

; -----------------------------------------------------------------------------
; _Multiply — 24-bit multiplicand (hMultiplicand, big-endian) × 8-bit multiplier
; (hMultiplier) -> 32-bit product (hProduct, big-endian). Zeros hMultiplier,
; matching the GB loop's end state. Caller (wrapper) preserves esi/edx/bx.
; -----------------------------------------------------------------------------
_Multiply:
    movzx ecx, byte [ebp + hMultiplier]

    movzx eax, byte [ebp + hMultiplicand + 0]
    shl eax, 8
    mov al, byte [ebp + hMultiplicand + 1]
    shl eax, 8
    mov al, byte [ebp + hMultiplicand + 2]

    mul ecx                                  ; EDX:EAX = eax * ecx (fits in EAX)

    mov byte [ebp + hProduct + 3], al
    shr eax, 8
    mov byte [ebp + hProduct + 2], al
    shr eax, 8
    mov byte [ebp + hProduct + 1], al
    shr eax, 8
    mov byte [ebp + hProduct + 0], al

    mov byte [ebp + hMultiplier], 0
    ret

; -----------------------------------------------------------------------------
; _Divide — divide the BH-byte big-endian dividend at hDividend by the 8-bit
; divisor at hDivisor. Writes the 32-bit quotient big-endian to hQuotient and
; the remainder to hRemainder. BH = dividend length in bytes (1..4).
;
; Rewritten from the original (broken) draft, which used the SM83 mnemonic `sbc`
; (invalid x86; the file never assembled) and an unverified byte-level emulation.
; This uses a single hardware divide with the same memory contract.
; -----------------------------------------------------------------------------
_Divide:
    push ebx
    push edx
    push edi

    movzx ecx, byte [ebp + hDivisor]        ; divisor
    test ecx, ecx
    jz .done                                 ; guard divide-by-zero (GB would loop forever)

    movzx ebx, bh                            ; ebx = dividend length in bytes
    test ebx, ebx
    jz .done

    ; Assemble the big-endian dividend (first BH bytes of hDividend) into EAX
    ; before any quotient store, since hQuotient overlaps hDividend.
    xor eax, eax
    xor edi, edi
.assemble:
    shl eax, 8
    mov al, byte [ebp + hDividend + edi]
    inc edi
    cmp edi, ebx
    jb .assemble

    xor edx, edx
    div ecx                                  ; EAX = quotient, EDX = remainder

    mov byte [ebp + hQuotient + 3], al
    shr eax, 8
    mov byte [ebp + hQuotient + 2], al
    shr eax, 8
    mov byte [ebp + hQuotient + 1], al
    shr eax, 8
    mov byte [ebp + hQuotient + 0], al

    mov byte [ebp + hRemainder], dl
.done:
    pop edi
    pop edx
    pop ebx
    ret
