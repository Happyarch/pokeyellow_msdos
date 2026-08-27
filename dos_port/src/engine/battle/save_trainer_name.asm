; save_trainer_name.asm — SaveTrainerName.
;
; Source (faithful translation): engine/battle/save_trainer_name.asm.
;
; Copies the engaged trainer class's display name into wNameBuffer, which
; _TrainerNameText (a TX_RAM wNameBuffer stream, generated into
; assets/trainer_text.inc) then prints as the "<TRAINER>: " prefix of the
; end-battle text. Sole caller: PrintEndBattleText (src/home/trainers.asm).
;
; DEVIATION{class=data-model; pret=data/trainers/name_pointers.asm:TrainerNamePointers; behavior=flat dd rows with 0xFFFFFFFF marker for wTrainerName (WRAM/ROM split); evidence=GB single address space vs port flat model; lifetime=permanent}
;
; Register map (CLAUDE.md): A=AL, HL=ESI, EBP=GB base, [ebp+addr].
; Stride widening: pret table is dw (2-byte) indexed by (wTrainerClass-1)*2;
; port table is dd (4-byte) indexed by (wTrainerClass-1)*4 — note widening.
;
; Build: nasm -f coff -I include/ -I . -o save_trainer_name.o save_trainer_name.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

extern TrainerNamePointers

global SaveTrainerName

section .text

SaveTrainerName:
    ; pret: ld hl, TrainerNamePointers / ld a,[wTrainerClass] / dec a / ld c,a / ld b,0 / add hl,bc / add hl,bc / ld a,[hli] / ld h,[hl] / ld l,a / ld de,wNameBuffer / .CopyCharacter: ld a,[hli] / ld [de],a / inc de / cp '@' / jr nz,.CopyCharacter / ret
    mov esi, TrainerNamePointers
    movzx ecx, byte [ebp + wTrainerClass]
    dec ecx
    mov esi, [esi + ecx*4]         ; stride 4 vs pret dw*2 — note widening
    cmp esi, 0xFFFFFFFF
    je .runtime
    ; fixed string: ESI already flat pointer to "@"-terminated bytes
    jmp .copy
.runtime:
    lea esi, [ebp + wTrainerName]  ; marker -> runtime buffer
.copy:
    lea edi, [ebp + wNameBuffer]
.CopyCharacter:
    mov al, [esi]
    mov [edi], al
    inc esi
    inc edi
    cmp al, 0x50
    jne .CopyCharacter
    ret
