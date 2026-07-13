; tms.asm — faithful port of engine/items/tms.asm (pret).
;   CanLearnTM — can [wCurPartySpecies] learn TM/HM move [wMoveNum]?
;   TMToMove   — convert TM/HM number [wTempTMHM] into its move number.
; TechnicalMachines (the TM/HM -> move-id list) is generated into assets/items.inc
; by tools/gen_items.py.
;
; Build: nasm -f coff -I include/ -I . -o /dev/null src/engine/items/tms.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"     ; FLAG_TEST

section .text

global CanLearnTM
global TMToMove

extern GetMonHeader
extern FlagAction               ; ESI=array, CL=bit index, BH=action; result in CL
extern TechnicalMachines        ; assets/items.inc


; ---------------------------------------------------------------------------
; CanLearnTM — tests if mon [wCurPartySpecies] can learn move [wMoveNum].
; Out: CL = 0 (can't learn) / non-zero (learnable learnset bit set).
; ---------------------------------------------------------------------------
CanLearnTM:
    mov al, [ebp + wCurPartySpecies]
    mov [ebp + wCurSpecies], al
    call GetMonHeader
    mov esi, wMonHLearnset
    push esi                         ; push hl (learnset array)
    mov al, [ebp + wMoveNum]
    mov bh, al                       ; ld b, a (move to find)
    mov cl, 0                        ; ld c, 0 (running TM index)
    lea esi, [TechnicalMachines]
.findTMloop:
    mov al, [esi]                    ; ld a, [hli]
    inc esi
    cmp al, 0xFF                     ; cp -1 (terminator)
    je .done
    cmp al, bh                       ; cp b
    je .TMfoundLoop
    inc cl                           ; inc c
    jmp .findTMloop
.TMfoundLoop:
    pop esi                          ; pop hl (learnset array)
    mov bh, FLAG_TEST                ; ld b, FLAG_TEST
    ; pret: predef_jump FlagActionPredef. The predef indirection reloads regs via
    ; GetPredefRegisters; since we set ESI/CL/BH directly, collapse to a tail-call
    ; of FlagAction (which tests learnset bit CL, returns result in CL).
    jmp FlagAction
.done:
    pop esi                          ; pop hl (discard)
    mov cl, 0                        ; ld c, 0
    ret

; ---------------------------------------------------------------------------
; TMToMove — converts the TM/HM number in [wTempTMHM] into a move number.
; HMs start at 51.
; ---------------------------------------------------------------------------
TMToMove:
    mov al, [ebp + wTempTMHM]
    dec al
    lea esi, [TechnicalMachines]
    movzx ecx, al                    ; ld b, 0 / ld c, a
    add esi, ecx                     ; add hl, bc
    mov al, [esi]                    ; ld a, [hl]
    mov [ebp + wTempTMHM], al
    ret
