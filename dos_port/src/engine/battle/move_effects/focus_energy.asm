%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_macros.inc"

extern PlayCurrentMoveAnimation
extern PrintText
extern DelayFrames
extern PrintButItFailedText_
extern GettingPumpedText


section .text
global FocusEnergyEffect_

FocusEnergyEffect_:
    mov esi, wPlayerBattleStatus2
    mov al, [ebp + hWhoseTurn]
    test al, al
    jz .notEnemy
    mov esi, wEnemyBattleStatus2
.notEnemy:
    test byte [ebp + esi], 1 << GETTING_PUMPED
    jnz .alreadyUsing
    or byte [ebp + esi], 1 << GETTING_PUMPED
    
    call PlayCurrentMoveAnimation
    mov esi, GettingPumpedText
    jmp PrintText

.alreadyUsing:
    mov bl, 50                          ; DelayFrames reads BL (frame.asm:213)
    call DelayFrames
    jmp PrintButItFailedText_

