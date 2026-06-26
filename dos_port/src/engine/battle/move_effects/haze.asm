%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_macros.inc"

extern PlayCurrentMoveAnimation
extern CallBankF
extern PrintText
extern _StatusChangesEliminatedText




section .text
global HazeEffect_
global CureVolatileStatuses
global ResetStatMods

HazeEffect_:
    mov al, 7
    ; store 7 on every stat mod
    mov esi, wPlayerMonAttackMod
    call ResetStatMods
    mov esi, wEnemyMonAttackMod
    call ResetStatMods
    ; copy unmodified stats to battle stats
    mov esi, wPlayerMonUnmodifiedAttack
    mov edx, wBattleMonAttack
    call ResetStats
    mov esi, wEnemyMonUnmodifiedAttack
    mov edx, wEnemyMonAttack
    call ResetStats
    ; cure non-volatile status, but only for the target
    mov esi, wEnemyMonStatus
    mov edx, wEnemySelectedMove
    mov al, [ebp + hWhoseTurn]
    test al, al
    jz .cureStatuses
    mov esi, wBattleMonStatus
    dec edx ; wPlayerSelectedMove

.cureStatuses:
    mov al, [ebp + esi]
    mov byte [ebp + esi], 0
    and al, (1 << FRZ) | SLP_MASK
    jz .cureVolatileStatuses
    ; prevent the Pokemon from executing a move if it was asleep or frozen
    mov byte [ebp + edx], 0xff

.cureVolatileStatuses:
    xor al, al
    mov [ebp + wPlayerDisabledMove], al
    mov [ebp + wEnemyDisabledMove], al
    mov esi, wPlayerDisabledMoveNumber
    mov [ebp + esi], al
    inc esi
    mov [ebp + esi], al
    mov esi, wPlayerBattleStatus1
    call CureVolatileStatuses
    mov esi, wEnemyBattleStatus1
    call CureVolatileStatuses
    mov esi, PlayCurrentMoveAnimation
    call CallBankF
    mov esi, StatusChangesEliminatedText
    jmp PrintText

CureVolatileStatuses:
    and byte [ebp + esi], ~(1 << CONFUSED)
    inc esi ; BATTSTATUS2
    mov al, [ebp + esi]
    ; clear USING_X_ACCURACY, PROTECTED_BY_MIST, GETTING_PUMPED, and SEEDED statuses
    and al, ~((1 << USING_X_ACCURACY) | (1 << PROTECTED_BY_MIST) | (1 << GETTING_PUMPED) | (1 << SEEDED))
    mov [ebp + esi], al ; BATTSTATUS3
    inc esi
    mov al, [ebp + esi]
    and al, 11110000b | (1 << TRANSFORMED) ; clear Bad Poison, Reflect and Light Screen statuses
    mov [ebp + esi], al
    ret

ResetStatMods:
    mov bh, NUM_STAT_MODS
.loop:
    mov [ebp + esi], al
    inc esi
    dec bh
    jnz .loop
    ret

ResetStats:
    mov bh, (NUM_STATS - 1) * 2 ; doesn't reset STAT_HEALTH
.loop:
    mov al, [ebp + esi]
    inc esi
    mov [ebp + edx], al
    inc edx
    dec bh
    jnz .loop
    ret

StatusChangesEliminatedText:
    db 0x0A ; TX_PAUSE
    db 0x17 ; TX_FAR
    dd _StatusChangesEliminatedText
    db 0x50 ; TX_END
