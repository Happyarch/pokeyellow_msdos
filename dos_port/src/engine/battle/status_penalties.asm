; status_penalties.asm — burn/paralysis stat penalties (battle engine, Stage 7).
;
; Faithful translation of engine/battle/core.asm:
;   ApplyBurnAndParalysisPenaltiesToPlayer / ...ToEnemy / ApplyBurnAndParalysisPenalties
;   QuarterSpeedDueToParalysis  (paralysed mon's Speed /= 4, min 1)
;   HalveAttackDueToBurn        (burned mon's Attack /= 2, min 1)
;
; The penalty is applied to the side whose turn it is NOT (hWhoseTurn selects).
; Register map: a=AL, b/c via BL scratch, hl=ESI. GB memory at [EBP+addr].
;
; Build: nasm -f coff -I include/ -I . -o status_penalties.o status_penalties.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

section .text

global ApplyBurnAndParalysisPenaltiesToPlayer
global ApplyBurnAndParalysisPenaltiesToEnemy
global ApplyBurnAndParalysisPenalties
global QuarterSpeedDueToParalysis
global HalveAttackDueToBurn

ApplyBurnAndParalysisPenaltiesToPlayer:
    mov al, 1
    jmp ApplyBurnAndParalysisPenalties

ApplyBurnAndParalysisPenaltiesToEnemy:
    xor al, al
ApplyBurnAndParalysisPenalties:
    mov [ebp + hWhoseTurn], al
    call QuarterSpeedDueToParalysis
    jmp HalveAttackDueToBurn

; --- Speed /= 4 if the off-turn mon is paralysed (min 1) ---
QuarterSpeedDueToParalysis:
    mov al, [ebp + hWhoseTurn]
    test al, al
    jz .playerTurn
; enemy's turn -> quarter the player's speed
    mov al, [ebp + wBattleMonStatus]
    and al, 1 << PAR
    jz .ret
    mov esi, wBattleMonSpeed + 1
    mov al, [ebp + esi]              ; low ([hld])
    dec esi
    mov bl, al
    mov al, [ebp + esi]              ; high
    shr al, 1
    rcr bl, 1
    shr al, 1
    rcr bl, 1                        ; (a:bl) = speed >> 2
    mov [ebp + esi], al              ; store high ([hli])
    inc esi
    or al, bl
    jnz .storePlayerSpeed
    mov bl, 1                        ; minimum 1
.storePlayerSpeed:
    mov [ebp + esi], bl
.ret:
    ret
.playerTurn:
; quarter the enemy's speed
    mov al, [ebp + wEnemyMonStatus]
    and al, 1 << PAR
    jz .ret
    mov esi, wEnemyMonSpeed + 1
    mov al, [ebp + esi]
    dec esi
    mov bl, al
    mov al, [ebp + esi]
    shr al, 1
    rcr bl, 1
    shr al, 1
    rcr bl, 1
    mov [ebp + esi], al
    inc esi
    or al, bl
    jnz .storeEnemySpeed
    mov bl, 1
.storeEnemySpeed:
    mov [ebp + esi], bl
    ret

; --- Attack /= 2 if the off-turn mon is burned (min 1) ---
HalveAttackDueToBurn:
    mov al, [ebp + hWhoseTurn]
    test al, al
    jz .playerTurn
; enemy's turn -> halve the player's attack
    mov al, [ebp + wBattleMonStatus]
    and al, 1 << BRN
    jz .ret
    mov esi, wBattleMonAttack + 1
    mov al, [ebp + esi]
    dec esi
    mov bl, al
    mov al, [ebp + esi]
    shr al, 1
    rcr bl, 1                        ; (a:bl) = attack >> 1
    mov [ebp + esi], al
    inc esi
    or al, bl
    jnz .storePlayerAttack
    mov bl, 1
.storePlayerAttack:
    mov [ebp + esi], bl
.ret:
    ret
.playerTurn:
; halve the enemy's attack
    mov al, [ebp + wEnemyMonStatus]
    and al, 1 << BRN
    jz .ret
    mov esi, wEnemyMonAttack + 1
    mov al, [ebp + esi]
    dec esi
    mov bl, al
    mov al, [ebp + esi]
    shr al, 1
    rcr bl, 1
    mov [ebp + esi], al
    inc esi
    or al, bl
    jnz .storeEnemyAttack
    mov bl, 1
.storeEnemyAttack:
    mov [ebp + esi], bl
    ret
