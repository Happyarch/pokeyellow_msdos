; poison.asm — PoisonEffect (the move-effect translation swarm's REFERENCE handler).
;
; Faithful translation of engine/battle/effects.asm:PoisonEffect (pret/pokeyellow).
; This is the gold-standard template the swarm copies (docs/current_plan_move_swarm.md
; S4): a status-only handler exercising the substitute check, the already-statused /
; type-immunity guards, the side-effect vs. main-effect accuracy split, the status-byte
; write, Toxic's badly-poisoned branch, and the faithful text + a Gen-1 bug tag.
;
; Fidelity boundary: docs/move_translation_divergence.md. Shared externs (§4) are
; called, not redefined; only §2 allowlist items (literal subanim, audio, banks)
; diverge. Drives PrintText (faithful, §3).
;
; Register map: A=AL, B=BH, C=BL (BC=BX), D=DH, E=DL (DE=EDX), HL=ESI, EBP=GB base.
; GB memory at [EBP+addr]; battle_text streams are flat program addresses.
;
; Build: nasm -f coff -I include/ -I . -o poison.o poison.asm

bits 32

%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"

section .text

global PoisonEffect_

; --- shared scaffold externs (§4: call, never define) ---
extern CheckTargetSubstitute        ; move_effect_helpers.asm — ZF=1 if no substitute
extern MoveHitTest                  ; core_damage.asm — accuracy test → wMoveMissed
extern BattleRandom                 ; home/random.asm
extern PrintText                    ; move_effect_helpers.asm — ESI = flat text stream
extern PrintDidntAffectText         ; move_effect_helpers.asm
extern DelayFrames                  ; move_effect_helpers.asm — BL = frame count
; --- allowlist anim stubs (§2 item 1: literal subanim, ANIMATION=OFF path) ---
extern PlayBattleAnimation2
extern PlayCurrentMoveAnimation2
; --- battle_text.inc streams (global in core.o) ---
extern PoisonedText
extern BadlyPoisonedText

; ===========================================================================
; PoisonEffect_ — inflict POISON (or, for Toxic, BADLY_POISONED) on the target.
; Handles POISON_SIDE_EFFECT1/2 (20% / 40% chance, no accuracy test) and the
; main POISON_EFFECT (accuracy-tested). Misses if the target has a substitute,
; is already statused, or is a Poison-type.
; ===========================================================================
PoisonEffect_:
    mov esi, wEnemyMonStatus            ; hl = target status (player's turn → enemy)
    mov edx, wPlayerMoveEffect          ; de = move effect
    mov al, [ebp + hWhoseTurn]
    and al, al
    jz .poisonEffect
    mov esi, wBattleMonStatus
    mov edx, wEnemyMoveEffect
.poisonEffect:
    call CheckTargetSubstitute
    jnz .noEffect                       ; substitute up → can't poison a doll
    mov al, [ebp + esi]                 ; ld a,[hli] — status byte
    inc esi
    mov bh, al                          ; ld b, a (unused after, faithful)
    and al, al
    jnz .noEffect                       ; already statused → miss
    mov al, [ebp + esi]                 ; ld a,[hli] — type 1
    inc esi
    cmp al, POISON
    je .noEffect                        ; can't poison a Poison-type
    mov al, [ebp + esi]                 ; ld a,[hld] — type 2
    dec esi
    cmp al, POISON
    je .noEffect
    mov al, [ebp + edx]                 ; ld a,[de] — move effect
    cmp al, POISON_SIDE_EFFECT1
    mov bh, (20 * 0xFF / 100) + 1       ; 20 percent + 1 chance of poisoning
    je .sideEffectTest
    cmp al, POISON_SIDE_EFFECT2
    mov bh, (40 * 0xFF / 100) + 1       ; 40 percent + 1
    je .sideEffectTest
    ; main POISON_EFFECT (PoisonPowder etc.): apply the accuracy test.
    push esi
    push edx
    ; BUG(cosmetic): Gen-1 1/256 miss — MoveHitTest can roll a miss on a 100%-accuracy
    ; move (the inherited <256/256 hit-chance bug). Preserved here; the fix, if any,
    ; lives in MoveHitTest under BUG_FIX_LEVEL, not in this handler.
    ; pret ref: engine/battle/core.asm:MoveHitTest, bugs_and_glitches (1/256 miss).
    call MoveHitTest                    ; → wMoveMissed
    pop edx
    pop esi
    mov al, [ebp + wMoveMissed]
    and al, al
    jnz .didntAffect
    jmp .inflictPoison
.sideEffectTest:
    call BattleRandom
    cmp al, bh                          ; was the side effect successful?
    jae .ret                            ; ret nc — failed, stay silent
.inflictPoison:
    dec esi                             ; dec hl → back to the status byte
    or byte [ebp + esi], 1 << PSN       ; set PSN
    push edx                            ; push de (move-effect ptr)
    dec edx                             ; dec de → move NUM ptr (effect-1)
    mov al, [ebp + hWhoseTurn]
    and al, al                          ; ZF preserved across the movs below
    mov bh, SHAKE_SCREEN_ANIM           ; ld b, SHAKE_SCREEN_ANIM
    mov esi, wPlayerBattleStatus3       ; ld hl, wPlayerBattleStatus3
    mov cl, [ebp + edx]                 ; ld a,[de] — move num (stash; de is reused next)
    mov edx, wPlayerToxicCounter        ; ld de, wPlayerToxicCounter
    jnz .ok
    mov bh, ENEMY_HUD_SHAKE_ANIM
    mov esi, wEnemyBattleStatus3
    mov edx, wEnemyToxicCounter
.ok:
    mov al, cl                          ; a = move num
    cmp al, TOXIC
    jne .normalPoison                   ; not Toxic → regular poison
    or byte [ebp + esi], 1 << BADLY_POISONED   ; set Toxic battstatus
    xor al, al
    mov [ebp + edx], al                 ; clear the toxic counter
    mov esi, BadlyPoisonedText
    jmp .continue
.normalPoison:
    mov esi, PoisonedText
.continue:
    pop edx                             ; pop de (move-effect ptr)
    mov al, [ebp + edx]                 ; ld a,[de] — move effect
    cmp al, POISON_EFFECT
    je .regularPoisonEffect
    mov al, bh                          ; a = anim id (subanim is the ANIMATION=OFF stub)
    call PlayBattleAnimation2
    jmp PrintText                       ; ESI = the poison text stream
.regularPoisonEffect:
    call PlayCurrentMoveAnimation2
    jmp PrintText
.noEffect:
    mov al, [ebp + edx]
    cmp al, POISON_EFFECT
    jne .ret                            ; ret nz — side effects stay quiet on no-effect
.didntAffect:
    mov bl, 50                          ; ld c, 50
    call DelayFrames
    jmp PrintDidntAffectText
.ret:
    ret
