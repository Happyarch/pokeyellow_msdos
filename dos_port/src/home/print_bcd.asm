; print_bcd.asm — PrintBCDNumber (mirrors home/print_bcd.asm).
;
; Print a binary-coded-decimal number (two decimal digits per source byte) into
; the tile buffer. Used for money (`text_bcd`).
;
;   DE = address of the BCD number   (EBP-relative)
;   HL = destination tile cursor      (EBP-relative)
;   C  = flags | length:
;        bit 7 (LEADING_ZEROES): if SET, suppress leading zeroes
;                                if clear, print leading zeroes
;        bit 6 (LEFT_ALIGN):     if set, left-align (don't pad with spaces)
;        bit 5 (MONEY_SIGN):     if set, print '¥' before the number
;        bits 0-4: length of the BCD number in bytes
;   (bits 5 and 7 are modified during execution.)
;
; Faithful instruction-for-instruction transliteration of the original. Note the
; sense of bit 7 here is INVERTED vs PrintNumber: here SET means *suppress* leading
; zeroes (pret keeps this quirk).
;
; Register map: A=AL, B=BH, C=BL (BC=BX), D=DH, E=DL (DE=DX), HL=ESI, EBP=GB base.
; In:  ESI = dest cursor (HL), EDX = BCD source addr (DE), BL = flags|length (C).
; Out: ESI = cursor past the number.
; Clobbers: EAX, EBX, ECX, EDX.
;
; Build: nasm -f coff -I include/ -I . -o print_bcd.o print_bcd.asm
%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"

bits 32

CHAR_ZERO  equ 0xF6                  ; '0'
CHAR_YEN   equ 0xF0                  ; '¥' (constants/charmap.asm)

section .text

global PrintBCDNumber
global PrintBCDDigit
extern PrintLetterDelay

PrintBCDNumber:
    ; ld b, c  — save flags in B; C := length (clear flag bits)
    mov   bh, bl                     ; BH = saved flags
    and   bl, ~((1 << BIT_LEADING_ZEROES) | (1 << BIT_LEFT_ALIGN) | (1 << BIT_MONEY_SIGN)) & 0xFF  ; BL = length
    ; if MONEY_SIGN set and NOT suppressing leading zeroes, print '¥' up front
    test  bh, (1 << BIT_MONEY_SIGN)
    jz    .loop
    test  bh, (1 << BIT_LEADING_ZEROES)
    jnz   .loop
    mov   byte [ebp + esi], CHAR_YEN
    inc   esi
.loop:
    movzx eax, byte [ebp + edx]
    shr   al, 4                      ; swap a / upper nibble first
    call  PrintBCDDigit              ; upper digit
    movzx eax, byte [ebp + edx]
    call  PrintBCDDigit              ; lower digit
    inc   edx
    dec   bl
    jnz   .loop
    ; were any non-zero digits printed?  (bit 7 cleared by PrintBCDDigit on first nonzero)
    test  bh, (1 << BIT_LEADING_ZEROES)
    jz    .done                      ; printed something → done
    ; every digit was zero: print the final 0
    test  bh, (1 << BIT_LEFT_ALIGN)
    jnz   .skipRightAlign
    dec   esi                        ; right-aligned: step back one space
.skipRightAlign:
    test  bh, (1 << BIT_MONEY_SIGN)
    jz    .skipCurrency
    mov   byte [ebp + esi], CHAR_YEN
    inc   esi
.skipCurrency:
    mov   byte [ebp + esi], CHAR_ZERO
    call  PrintLetterDelay
    inc   esi
.done:
    ret

; PrintBCDDigit — AL = digit in low nibble. BH = live flags (bit7 suppress-leading,
; bit5 money). Prints the digit (or a leading space) at [EBP+ESI].
PrintBCDDigit:
    and   al, 0x0F
    test  al, al
    jz    .zeroDigit
.nonzeroDigit:
    test  bh, (1 << BIT_LEADING_ZEROES)
    jz    .outputDigit               ; not suppressing → just print
    ; first significant digit: emit pending '¥' then stop suppressing
    test  bh, (1 << BIT_MONEY_SIGN)
    jz    .skipCurrency
    mov   byte [ebp + esi], CHAR_YEN
    inc   esi
    and   bh, ~(1 << BIT_MONEY_SIGN) & 0xFF
.skipCurrency:
    and   bh, ~(1 << BIT_LEADING_ZEROES) & 0xFF
.outputDigit:
    add   al, CHAR_ZERO
    mov   [ebp + esi], al
    inc   esi
    jmp   PrintLetterDelay           ; tail call (returns to caller)
.zeroDigit:
    test  bh, (1 << BIT_LEADING_ZEROES)
    jz    .outputDigit               ; printing leading zeroes → print '0'
    test  bh, (1 << BIT_LEFT_ALIGN)
    jnz   .retNoAdv                  ; left-aligned: print nothing, don't advance
    inc   esi                        ; right-aligned: "print" a space by advancing
.retNoAdv:
    ret
