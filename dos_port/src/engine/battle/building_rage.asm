; building_rage.asm — HandleBuildingRage (battle engine plan, Stage 7).
;
; Faithful translation of engine/battle/core.asm:HandleBuildingRage. When the mon
; being attacked is under the effect of Rage, its Attack stat-mod is raised one
; stage: the routine flips hWhoseTurn, temporarily rewrites the target's move to a
; null move with ATTACK_UP1_EFFECT, runs StatModifierUpEffect, then restores the
; Rage move and the turn flag.
;
; Depends on StatModifierUpEffect (Stage 5, stat_mod_effects.asm). PrintText +
; BuildingRageText are the deferred battle front end (extern), so this assembles
; (make check) but does not yet link; the stat-mod outcome is native-validated end
; to end through the real StatModifierUpEffect.
;
; Register map: a=AL, b=BH, c=BL (bc=BX), d=DH, e=DL (de=DX), hl=ESI.
;
; Build: nasm -f coff -I include/ -I . -o building_rage.o building_rage.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"

extern StatModifierUpEffect
extern PrintText
extern BuildingRageText

section .text

global HandleBuildingRage

HandleBuildingRage:
    ; values for the player's turn (target = enemy mon)
    mov esi, wEnemyBattleStatus2
    mov edx, wEnemyMonStatMods
    mov ebx, wEnemyMoveNum
    mov al, [ebp + hWhoseTurn]
    test al, al
    jz .next
    ; values for the enemy's turn (target = player mon)
    mov esi, wPlayerBattleStatus2
    mov edx, wPlayerMonStatMods
    mov ebx, wPlayerMoveNum
.next:
    test byte [ebp + esi], (1 << USING_RAGE)
    jz .ret                          ; ret z — target not raging
    mov al, [ebp + edx]
    cmp al, 0x0D                     ; attack mod already maxed (+6)?
    je .ret                          ; ret z
    mov al, [ebp + hWhoseTurn]
    xor al, 0x01                     ; flip turn for the stat-raise
    mov [ebp + hWhoseTurn], al
    ; temporarily set the target's move to $00 / effect to ATTACK_UP1_EFFECT
    mov esi, ebx                     ; hl = bc (move-number address)
    mov byte [ebp + esi], 0x00       ; null move number
    inc esi
    mov byte [ebp + esi], ATTACK_UP1_EFFECT
    push esi
    mov esi, BuildingRageText
    call PrintText
    call StatModifierUpEffect
    pop esi                          ; esi = move-effect address
    xor al, al
    mov [ebp + esi], al              ; ld [hld], a — null move effect
    dec esi
    mov al, RAGE
    mov [ebp + esi], al              ; restore the target's move to Rage
    mov al, [ebp + hWhoseTurn]
    xor al, 0x01                     ; flip turn back
    mov [ebp + hWhoseTurn], al
.ret:
    ret
