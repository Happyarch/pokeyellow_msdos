; status_ailments.asm — PrintStatusAilment (menus-port Session 5).
;
; Source: engine/pokemon/status_ailments.asm (pret/pokeyellow). Prints the
; 3-letter non-volatile status (PSN/BRN/FRZ/PAR/SLP) for the status byte at
; [de], or nothing when the mon is healthy. The fainted "FNT" case is handled
; by the caller (home/pokemon.asm:PrintStatusCondition), as in pret.
;
; (This file previously carried an "intentionally skipped — text rendering"
; note from the unwired-skeleton era; the party menu realign made it live.)
;
; Register map (CLAUDE.md): A=AL, DE=EDX, HL=ESI, EBP = GB base.
;
; Build (standalone check):
;   nasm -f coff -I include/ -I . -o /dev/null src/engine/pokemon/status_ailments.asm
; ---------------------------------------------------------------------------
bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

global PrintStatusAilment

; MON_STATUS bit indices / mask (pret constants/battle_constants.asm)
PSN_BIT      equ 3
BRN_BIT      equ 4
FRZ_BIT      equ 5
PAR_BIT      equ 6
SLP_MASK     equ 0x07


section .data
; 3-letter strings in the GB charmap ('A' = $80)
%include "assets/status_ailment_runtime_strings.inc"

section .text

; ---------------------------------------------------------------------------
; PrintStatusAilment — pret ref: engine/pokemon/status_ailments.asm.
; In:  EDX (de) = EBP-rel address of the status byte;
;      ESI (hl) = dest tile cursor (EBP-rel).
; Out: ESI advanced by 3 if a status was printed (pret's ld_hli_a_string),
;      unchanged otherwise. Clobbers EAX.
; ---------------------------------------------------------------------------
PrintStatusAilment:
    mov al, [ebp + edx]                 ; ld a,[de]
    test al, 1 << PSN_BIT               ; bit PSN,a
    jnz .psn
    test al, 1 << BRN_BIT               ; bit BRN,a
    jnz .brn
    test al, 1 << FRZ_BIT               ; bit FRZ,a
    jnz .frz
    test al, 1 << PAR_BIT               ; bit PAR,a
    jnz .par
    and al, SLP_MASK                    ; and SLP_MASK
    jnz .slp
    ret                                 ; ret z — healthy, print nothing
.slp:
    mov eax, sa_slp
    jmp .put
.psn:
    mov eax, sa_psn
    jmp .put
.brn:
    mov eax, sa_brn
    jmp .put
.frz:
    mov eax, sa_frz
    jmp .put
.par:
    mov eax, sa_par
.put:                                   ; ld_hli_a_string — 3 tiles, hl advances
    push ecx
    mov cl, [eax]
    mov [ebp + esi], cl
    mov cl, [eax + 1]
    mov [ebp + esi + 1], cl
    mov cl, [eax + 2]
    mov [ebp + esi + 2], cl
    pop ecx
    add esi, 3
    ret
