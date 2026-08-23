; print_num.asm — PrintNumber (mirrors home/print_num.asm:PrintNumber).
;
; Print the c-digit, b-byte BIG-endian value at DE into the tile buffer at HL.
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
global FarPrintText

extern BankswitchCommon              ; src/home/bankswitch2.asm
extern PrintText                     ; src/home/window.asm

; ─────────────────────────────────────────────────────────────────────────────
; FarPrintText — pret home/print_num.asm:1. Print far text b:hl at (1,14).
; In: ESI = text stream (HL). B (BH) = source ROM bank (ignored — flat memory).
;   pret: push bank; a=b; BankswitchCommon; PrintText; pop; BankswitchCommon; ret
; ─────────────────────────────────────────────────────────────────────────────
FarPrintText:
    ; TODO-HW: bank switch is a no-op under flat EBP memory; the far bank in BH is
    ; ignored (all ROM is flat-addressable). Faithful call structure preserved.
    movzx eax, byte [ebp + hLoadedROMBank]
    push eax
    mov al, bh                           ; a = b (target bank)
    call BankswitchCommon
    call PrintText             ; pret PrintText (general printer)
    pop eax
    call BankswitchCommon
    ret

PrintNumber:
    push ebx
    push edi

    ; --- decode flags / counts ---
    movzx eax, bh
    mov   [pn_flags], al             ; stash flags byte (DS-flat)
    and   eax, 0x0F                  ; EAX = source byte count nibble (0..15)
    ; pret does NOT loop on this count — it DISPATCHES: `cp 1 / jr z,.byte`,
    ; `cp 2 / jr z,.word`, and everything else falls through to `.long`, which
    ; reads exactly 3 bytes. The port replaced that with a counted read loop, so
    ; it diverged for every nibble outside {1,2,3}: 0 ran `dec eax` from zero for
    ; ~4 billion reads, and 4..15 read that many bytes where the GB reads 3.
    ; This restores pret's mapping for all 16 values. Not a guard — a guard
    ; would read 0 bytes where the GB reads 3.
    ; REACHABLE, not theoretical: TextCommand_NUM (home/text.asm) takes this
    ; nibble from the TEXT STREAM's format byte, and a corrupted stream is a
    ; failure mode this project has already had (the <DONE> sentinel incident,
    ; regression-battle-anim-interp-runtime-crash).
    cmp   eax, 1
    je    .haveCount
    cmp   eax, 2
    je    .haveCount
    mov   eax, 3                     ; pret .long
.haveCount:
    movzx ecx, bl                    ; ECX = digit count (grab before BL is clobbered)
    push  ecx

    ; --- read the BIG-endian value at [EBP+EDX] (EAX bytes) into EDI ---
    ; pret PrintNumber stages hNumToPrint MSB-first: every multi-byte source
    ; (wLoadedMonHP, text_decimal words, …) is big-endian. (Fixed in menus S5 —
    ; this read was little-endian, which byte-swapped 2/3-byte values; all
    ; pre-S5 linked callers were 1-byte, so nothing observable changed before.)
    xor   edi, edi                   ; EDI = accumulated value
.read:
    shl   edi, 8
    movzx ebx, byte [ebp + edx]
    or    edi, ebx
    inc   edx
    dec   eax
    jnz   .read

    pop   ecx                        ; ECX = digit count

    ; --- pret DISPATCHES the digit count; it does not compute a power of ten ---
    ; pret's `.start` is `cp 2 / jr z,.tens`, `cp 3 / jr z,.hundreds`, … `cp 6 /
    ; jr z,.hundred_thousands`, and EVERY other value — 0, 1, 7, or anything
    ; larger — falls through into the `print_digit 1000000` entry, i.e. exactly
    ; SEVEN digits. That fallthrough is the whole bound.
    ;
    ; The port built the divisor as 10^(digits-1) with an unbounded `imul` loop
    ; instead, which has no bound at all: at 33 iterations EBX is 10^32, and
    ; 10^32 = 2^32 * 5^32, so it is 0 modulo 2^32 — the `div ebx` below then
    ; raises a DIVIDE ERROR and the program dies with no message.
    ;
    ; NOT THEORETICAL. pret reaches PrintLevelCommon with `c` INHERITED from
    ; whatever PlaceString last left in it (engine/movie/hall_of_fame.asm's
    ; HoFDisplayMonInfo is one such call site, and pret's own PlaceString returns
    ; bc = the end cursor), so the count is routinely a tilemap address byte —
    ; 252 on the GB, 84 here. Measured 2026-08-23: the Hall of Fame ceremony died
    ; on exactly this, between frames 185 and 200 of the DEBUG_HOF harness.
    ; TextCommand_NUM takes this count from the TEXT STREAM as well, the same
    ; reachability argument the byte-count fix above already makes.
    ;
    ; This is the SAME defect class as that fix, one field over: a pret dispatch
    ; rewritten as arithmetic, correct on the values anyone tested and unbounded
    ; everywhere else.
    cmp   ecx, 2
    jb    .sevenDigits               ; 0 and 1 fall through in pret too
    cmp   ecx, 6
    ja    .sevenDigits               ; 7 and up: pret's millions entry
    ; --- divisor (EBX) = 10^(digits-1), digits now known to be 2..6 ---
    mov   ebx, 1
    mov   edx, ecx
    dec   edx
    jz    .gotdiv
.powl:
    imul  ebx, ebx, 10
    dec   edx
    jnz   .powl
    jmp   .gotdiv
.sevenDigits:
    mov   ecx, 7                     ; pret: enter the chain at `print_digit 1000000`
    mov   ebx, 1000000
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
