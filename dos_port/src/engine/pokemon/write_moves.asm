; write_moves.asm — LoadMovePPs / AddPartyMon_WriteMovePP.
;
; Source: engine/pokemon/add_mon.asm:LoadMovePPs, AddPartyMon_WriteMovePP
;         (pret/pokeyellow) — still relocated, awaiting their own mirror.
;
; The engine/pokemon/evos_moves.asm labels this file used to carry —
; GetMonLearnset, WriteMonMoves, WriteMonMoves_ShiftMoveData — now live in their
; pret mirror, src/engine/pokemon/evos_moves.asm.
;
; Register map: a=AL, b=BH, c=BL (bc=EBX), d=DH, e=DL (de=EDX), hl=ESI.
;
; Build: nasm -f coff -I include/ -I . -o write_moves.o write_moves.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

global LoadMovePPs
global AddPartyMon_WriteMovePP

extern GetPredefRegisters
extern Moves

section .text

; ---------------------------------------------------------------------------
; LoadMovePPs — write each move's base PP into the 4 PP slots (pret add_mon.asm).
; In (via predef regs): ESI (hl) = move-id source (WRAM), EDX (de) = PP dest − 1
; (WRAM). Empty move slots get PP 0. AddPartyMon_WriteMovePP enters with the
; registers already set (the AddPartyMon path).
;
; DIVERGENCE (faithful to write_moves' existing daycare branch): the base PP is
; read straight from the flat `Moves` table — Moves[(id−1)*MOVE_LENGTH+MOVE_PP] —
; rather than the GB FarCopyData→wMoveData the original uses. Clobbers AL/ECX, BH.
; ---------------------------------------------------------------------------
LoadMovePPs:
    call GetPredefRegisters          ; esi=hl (moves src), edx=de (PP dest − 1)
AddPartyMon_WriteMovePP:
    mov bh, NUM_MOVES
.pploop:
    mov al, [ebp + esi]              ; ld a,[hli] — move id
    inc esi
    test al, al
    jz .empty                        ; empty slot → PP byte 0 (al already 0)
    movzx ecx, al
    dec ecx
    imul ecx, ecx, MOVE_LENGTH
    mov al, [Moves + ecx + MOVE_PP]  ; base PP (flat Moves table)
.empty:
    inc edx                          ; inc de
    mov [ebp + edx], al              ; ld [de],a
    dec bh
    jnz .pploop
    ret
