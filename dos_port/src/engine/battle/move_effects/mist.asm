%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_macros.inc"

extern PlayCurrentMoveAnimation
extern PrintText
extern PrintButItFailedText_
extern ShroudedInMistText

section .text
global MistEffect_


MistEffect_:
    mov esi, wPlayerBattleStatus2
    mov al, byte [ebp + hWhoseTurn]
    and al, al
    jz .mistEffect
    mov esi, wEnemyBattleStatus2
.mistEffect:
    test byte [ebp + esi], (1 << PROTECTED_BY_MIST)
    jnz .mistAlreadyInUse
    or byte [ebp + esi], (1 << PROTECTED_BY_MIST)
    call PlayCurrentMoveAnimation
    mov esi, ShroudedInMistText
    jmp PrintText
.mistAlreadyInUse:
    jmp PrintButItFailedText_

