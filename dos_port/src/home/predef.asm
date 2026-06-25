; predef.asm — GetPredefRegisters (Pokémon data/stats plan, Stage 5 tail).
;
; Source: home/predef.asm:GetPredefRegisters (pret/pokeyellow).
;
; Restores the HL/DE/BC register pairs a predef routine was invoked with. The
; predef dispatcher stashes the caller's HL/DE/BC into wPredefHL/DE/BC (big-
; endian: [addr]=high byte, [addr+1]=low byte) before jumping to the routine;
; the routine calls GetPredefRegisters to read them back. Only this leaf is
; ported so far — SetPartyMonTypes (set_types.asm) needs it; the full predef
; dispatch table is deferred (no predef caller exists in the port yet, so the
; predef WRAM slots are populated directly by callers / test harnesses).
;
; Register map: a=AL, hl=ESI, de=EDX, bc=EBX. Clobbers AL (faithful: pret
; clobbers A). The big-endian byte order is reconstructed via AH/AL of a GP
; register (ESI/EDX/EBX have no addressable high-of-low-word sub-register).
;
; Build: nasm -f coff -I include/ -I . -o predef.o predef.asm

bits 32

%include "gb_memmap.inc"

global GetPredefRegisters

section .text

GetPredefRegisters:
    mov ah, [ebp + wPredefHL]        ; H (high byte)
    mov al, [ebp + wPredefHL + 1]    ; L (low byte)
    movzx esi, ax                    ; hl
    mov ah, [ebp + wPredefDE]        ; D
    mov al, [ebp + wPredefDE + 1]    ; E
    movzx edx, ax                    ; de
    mov ah, [ebp + wPredefBC]        ; B
    mov al, [ebp + wPredefBC + 1]    ; C
    movzx ebx, ax                    ; bc
    ret
