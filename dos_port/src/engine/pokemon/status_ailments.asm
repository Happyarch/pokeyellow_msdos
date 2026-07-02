; status_ailments.asm — PrintStatusAilment (pret engine/pokemon/status_ailments.asm).
;
; Prints a 3-letter status abbreviation (PSN/BRN/FRZ/PAR/SLP) into the tilemap,
; selected by priority bit-tests over a mon's MON_STATUS byte. A healthy mon
; (no non-volatile status) prints nothing and returns with ZF set.
;
; Faithful to pret: the priority order is PSN > BRN > FRZ > PAR > SLP, and the
; sleep test is the SLP_MASK counter (bits 0-2), not a single bit. The 3-letter
; string is written GB-font-charmap ('A'=$80 … 'Z'=$99), matching the tiles the
; text/font engine loads.
;
; Register map: A=AL, DE=EDX (input: GB offset of the status byte), HL=ESI
; (input/output: GB tilemap destination offset). Like pret's ld_hli_a_string,
; ESI is advanced by 2 (to the last written tile) and AL = the last tile written.
;
; INPUT:
;   EDX = GB offset of the status condition byte (e.g. wLoadedMonStatus)
;   ESI = GB tilemap destination offset
; OUTPUT:
;   3 status tiles written at [EBP+ESI..+2]; ESI += 2; ZF set iff no status.

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

section .text

global PrintStatusAilment

; write a 3-tile string to [EBP+ESI], mirroring pret's `ld_hli_a_string`:
; the first two tiles advance ESI (ld [hli]); the last is written without a
; further increment (ld [hl]), leaving ESI at the last tile and AL = last tile.
%macro put_str3 3
    mov al, %1
    mov [ebp + esi], al
    inc esi
    mov al, %2
    mov [ebp + esi], al
    inc esi
    mov al, %3
    mov [ebp + esi], al
%endmacro

; GB font charmap: uppercase letter L → tile $80 + (L - 'A').
%define CHR(c) ((c) - 'A' + 0x80)

PrintStatusAilment:
    mov al, [ebp + edx]         ; ld a, [de]
    test al, 1 << PSN           ; bit PSN, a
    jnz .psn
    test al, 1 << BRN           ; bit BRN, a
    jnz .brn
    test al, 1 << FRZ           ; bit FRZ, a
    jnz .frz
    test al, 1 << PAR           ; bit PAR, a
    jnz .par
    and al, SLP_MASK            ; and SLP_MASK
    jz .healthy                 ; ret z
    put_str3 CHR('S'), CHR('L'), CHR('P')
    ret
.healthy:
    ret
.psn:
    put_str3 CHR('P'), CHR('S'), CHR('N')
    ret
.brn:
    put_str3 CHR('B'), CHR('R'), CHR('N')
    ret
.frz:
    put_str3 CHR('F'), CHR('R'), CHR('Z')
    ret
.par:
    put_str3 CHR('P'), CHR('A'), CHR('R')
    ret
