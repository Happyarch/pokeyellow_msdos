; get_current_move.asm — GetCurrentMove backend (battle engine plan).
;
; Faithful translation of engine/battle/core.asm:GetCurrentMove (the move-record
; load). Loads the selected move's 6-byte record (anim, effect, power, type,
; accuracy, pp) from the flat `Moves` table into the wPlayerMove* / wEnemyMove*
; WRAM fields, picked by hWhoseTurn. This is the load the damage pipeline, the
; move-hit test, and the trainer-AI move scoring all read from.
;
; Flat-source note: pret finishes with `AddNTimes` + `FarCopyData`, but in the
; port FarCopyData/CopyData bias the source by EBP (for GB WRAM), whereas `Moves`
; is a flat program-image table. So we index it flat (esi = Moves + (id-1)*MOVE_LENGTH)
; and copy flat→WRAM with an inline loop — exactly as LoadWildData does for the
; flat wild-data table.
;
; The move-name fetch tail (`GetMoveName` via wNameListIndex) is the deferred UI;
; wNameListIndex is still set here (the non-UI half) so the consumer can fetch it.
;
; Register map: a=AL, de=EDX (dest), hl=ESI (flat source), ecx scratch.
;
; Build: nasm -f coff -I include/ -I . -o get_current_move.o get_current_move.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

extern Moves

section .text

global GetCurrentMove

GetCurrentMove:
    mov al, [ebp + hWhoseTurn]
    test al, al
    jz .player
    mov edx, wEnemyMoveNum
    mov al, [ebp + wEnemySelectedMove]
    jmp .selected
.player:
    mov edx, wPlayerMoveNum
    ; TestBattle (debug) forces a specific player move
    mov al, [ebp + wStatusFlags7]
    test al, (1 << BIT_TEST_BATTLE)
    mov al, [ebp + wTestBattlePlayerSelectedMove]
    jnz .selected
    mov al, [ebp + wPlayerSelectedMove]
.selected:
    mov [ebp + wNameListIndex], al       ; ld [wNameListIndex], a (name fetch input)
    ; esi = &Moves[(id - 1) * MOVE_LENGTH]  (flat)
    dec al
    movzx ecx, al
    imul ecx, ecx, MOVE_LENGTH
    mov esi, Moves
    add esi, ecx
    ; copy MOVE_LENGTH bytes flat [esi] → WRAM [ebp + edx]
    mov ecx, MOVE_LENGTH
.copy:
    mov al, [esi]
    inc esi
    mov [ebp + edx], al
    inc edx
    dec ecx
    jnz .copy
    ret
