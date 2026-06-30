; print_num.asm — PrintNumber (mirrors home/print_num.asm:PrintNumber).
;
; Print the c-digit, b-byte little-endian value at DE into the tile buffer at HL.
; Supports 2..7 digits and 1..3 source bytes. Flags LEADING_ZEROES (bit 7) and
; LEFT_ALIGN (bit 6) may be set in the high bits of B. (For a 1-digit number the
; caller adds the value to '0' directly, as in pret.)
;
; The pret original does the decimal conversion by repeatedly subtracting 3-byte
; powers of ten through a hand-rolled borrow chain in HRAM scratch (hNumToPrint /
; hPowerOf10 / hPastLeadingZeros). The value is at most 3 bytes (<= 24 bits), so
; the 386 port computes the same digits with native 32-bit DIV — faithful to the
; *observable* behaviour: identical digits and identical leading-zero / left-align
; / space-padding and pointer-advance rules (see .PrintLeadingZero / .NextDigit in
; the original), per the 386 optimization strategy.
;
; Register map: A=AL, B=BH, C=BL (BC=BX), D=DH, E=DL (DE=DX), HL=ESI, EBP=GB base.
; In:  ESI = dest tile-buffer cursor (HL, EBP-relative)
;      EDX = source value address  (DE, EBP-relative)
;      BH  = flags | byte-count (low nibble = byte count 1..3, bits 5-7 = flags)
;      BL  = digit count (2..7)
; Out: ESI = cursor advanced past the printed field.
; Clobbers: EAX, ECX, EDX. EBX/EDI preserved.
;
; Build: nasm -f coff -I include/ -I . -o print_num.o print_num.asm
%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"

bits 32

CHAR_ZERO  equ 0xF6                  ; '0' glyph (constants/charmap.asm)

section .bss
pn_flags:   resb 1                   ; flags byte (bits 6,7 = LEFT_ALIGN / LEADING_ZEROES)
pn_past:    resb 1                   ; non-zero once a significant digit has been printed

section .text

global PrintNumber

PrintNumber:
    push ebx
    push edi

    ; --- decode flags / counts ---
    movzx eax, bh
    mov   [pn_flags], al             ; stash flags byte (DS-flat)
    and   eax, 0x0F                  ; EAX = source byte count (1..3)
    movzx ecx, bl                    ; ECX = digit count (grab before BL is clobbered)
    push  ecx

    ; --- read the little-endian value at [EBP+EDX] (EAX bytes) into EDI ---
    xor   edi, edi                   ; EDI = accumulated value
    xor   ecx, ecx                   ; ECX (cl) = current shift
.read:
    movzx ebx, byte [ebp + edx]
    shl   ebx, cl
    or    edi, ebx
    inc   edx
    add   cl, 8
    dec   eax
    jnz   .read

    pop   ecx                        ; ECX = digit count

    ; --- divisor (EBX) = 10^(digits-1) ---
    mov   ebx, 1
    mov   edx, ecx
    dec   edx
    jz    .gotdiv
.powl:
    imul  ebx, ebx, 10
    dec   edx
    jnz   .powl
.gotdiv:
    mov   byte [pn_past], 0

    ; EDI = value, EBX = divisor, ECX = remaining digit count, ESI = cursor
.digit:
    mov   eax, edi
    xor   edx, edx
    div   ebx                        ; EAX = digit (0..9), EDX = remainder
    mov   edi, edx                   ; value := remainder
    cmp   ecx, 1
    je    .ones                      ; last (ones) digit: always printed

    test  al, al
    jnz   .nonzero
    cmp   byte [pn_past], 0
    jne   .nonzero
    ; --- leading zero (.PrintLeadingZero) ---
    test  byte [pn_flags], (1 << BIT_LEADING_ZEROES)
    jz    .nz_noprint                ; no leading-zeroes flag: leave the blank tile
    mov   byte [ebp + esi], CHAR_ZERO
.nz_noprint:
    ; --- .NextDigit: advance unless (!LEADING_ZEROES && LEFT_ALIGN && !past) ---
    test  byte [pn_flags], (1 << BIT_LEADING_ZEROES)
    jnz   .adv
    test  byte [pn_flags], (1 << BIT_LEFT_ALIGN)
    jz    .adv
    jmp   .nextplace                 ; left-aligned, still in leading zeros: no advance
.nonzero:
    mov   byte [pn_past], 1
    add   al, CHAR_ZERO
    mov   [ebp + esi], al
.adv:
    inc   esi
.nextplace:
    ; divisor /= 10
    mov   eax, ebx
    xor   edx, edx
    push  ecx
    mov   ecx, 10
    div   ecx
    pop   ecx
    mov   ebx, eax
    dec   ecx
    jmp   .digit

.ones:
    add   al, CHAR_ZERO
    mov   [ebp + esi], al
    inc   esi
    pop   edi
    pop   ebx
    ret
