; 987__SwitchAndTeleportEffect.asm — SwitchAndTeleportEffect (move-effect
; translation swarm worker ticket). Teleport (player-only escape), Roar/
; Whirlwind (force a wild mon to flee / would force-switch a trainer's mon —
; in Gen 1 these moves only succeed at all in a wild battle, where they end
; the battle the same as a player escape; trainer battles never actually
; switch the opponent's mon despite the move name).
;
; Faithful translation of engine/battle/effects.asm:SwitchAndTeleportEffect,
; copying the structure of dos_port/src/engine/battle/move_effects/poison.asm
; (the swarm template).
;
; Fidelity boundary: docs/move_translation_divergence.md. Shared externs (§4)
; are called, not redefined; only §2 allowlist items (literal subanim) diverge.
; Drives PrintText/PrintButItFailedText_/PrintDidntAffectText/
; ConditionalPrintButItFailed/BattleRandom/DelayFrames/ReadPlayerMonCurHPAndStatus
; (all faithful, §3) and sets wEscapedFromBattle/wAnimationType directly (§3:
; every WRAM read/write translated verbatim).
;
; Register map: A=AL, B=BH, C=BL (BC=BX), D=DH, E=DL (DE=EDX), HL=ESI, EBP=GB
; base. GB memory at [EBP+addr]; battle_text streams are flat program addresses.
;
; Build: nasm -f coff -I include/ -I . -o /dev/null 987__SwitchAndTeleportEffect.asm

bits 32

%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"

section .text

global SwitchAndTeleportEffect_

; --- shared scaffold externs (§4: call, never define) ---
extern BattleRandom                 ; home/random.asm — returns AL = random byte
extern DelayFrames                  ; video/frame.asm — BL = frame count
extern PrintText                    ; move_effect_helpers.asm — ESI = flat text stream
extern PrintButItFailedText_        ; move_effect_helpers.asm
extern PrintDidntAffectText         ; move_effect_helpers.asm
extern ConditionalPrintButItFailed  ; move_effect_helpers.asm
extern ReadPlayerMonCurHPAndStatus  ; engine/battle/core.asm — already live + linked
; --- allowlist anim stub (§2 item 1: literal subanim, ANIMATION=OFF path) ---
extern PlayBattleAnimation          ; move_effect_helpers.asm allowlist stub
; --- battle_text.inc streams (global in core.o; flat addresses) ---
extern IsUnaffectedText
extern RanFromBattleText
extern RanAwayScaredText
extern WasBlownAwayText

; FLAG FOR MASTER: ROAR is not in gb_constants.inc's "move ids referenced by
; battle logic" block (only NO_MOVE/KARATE_CHOP/COUNTER/RAZOR_LEAF/QUICK_ATTACK/
; CRABHAMMER/SLASH/STRUGGLE + the field-move ids are listed there). Derived from
; constants/move_constants.asm (`const_def` order: NO_MOVE=$00 ... ROAR is the
; 47th `const`, i.e. index $2E) — pret source comment confirms "; 2e". TELEPORT
; ($64) is already defined in gb_constants.inc and used as-is.

; ===========================================================================
; SwitchAndTeleportEffect_ — pret engine/battle/effects.asm:SwitchAndTeleportEffect.
; Teleport/Roar/Whirlwind. In a wild battle, rolls an escape chance from the
; user's and target's levels (auto-success if the escaping side's relevant level
; is >= the other's) via BattleRandom; on success sets wEscapedFromBattle and
; ends the battle with a flee/blow-away message. In a trainer battle the move
; always "doesn't affect" / "fails" (no trainer mon ever flees or switches via
; this effect) after the standard 50-frame delay.
; ===========================================================================
SwitchAndTeleportEffect_:
    mov al, [ebp + hWhoseTurn]
    and al, al
    jnz .handleEnemy

; --- player is attacking (player trying to flee/Roar) ---
    mov al, [ebp + wIsInBattle]
    dec al
    jnz .notWildBattle1                 ; wIsInBattle != 1 → trainer battle

    mov al, [ebp + wCurEnemyLevel]
    mov bh, al                          ; b = enemyLevel
    mov al, [ebp + wBattleMonLevel]
    cmp al, bh                          ; is the player's level >= the enemy's level?
    jae .playerMoveWasSuccessful        ; jr nc — if so, teleport always succeeds
    add al, bh                          ; a = playerLevel + enemyLevel (8-bit wrap, faithful)
    mov bl, al
    inc bl                              ; c = playerLevel + enemyLevel + 1
.rejectionSampleLoop1:
    call BattleRandom                   ; al = random byte in [0,255]
    cmp al, bl
    jae .rejectionSampleLoop1           ; jr nc — reroll until al < c
    shr bh, 1
    shr bh, 1                           ; b = enemyLevel / 4
    cmp al, bh                          ; is rand[0, playerLevel+enemyLevel] >= enemyLevel/4?
    jae .playerMoveWasSuccessful        ; jr nc — if so, allow teleporting
    mov bl, 50
    call DelayFrames
    mov al, [ebp + wPlayerMoveNum]
    cmp al, TELEPORT
    jnz PrintDidntAffectText            ; jp nz, PrintDidntAffectText
    jmp PrintButItFailedText_           ; jp PrintButItFailedText_
.playerMoveWasSuccessful:
    call ReadPlayerMonCurHPAndStatus
    xor al, al
    mov byte [ebp + wAnimationType], al
    inc al
    mov byte [ebp + wEscapedFromBattle], al
    mov al, [ebp + wPlayerMoveNum]
    jmp .playAnimAndPrintText
.notWildBattle1:
    mov bl, 50
    call DelayFrames
    mov esi, IsUnaffectedText
    mov al, [ebp + wPlayerMoveNum]
    cmp al, TELEPORT
    jnz PrintText                       ; jp nz, PrintText
    jmp PrintButItFailedText_           ; jp PrintButItFailedText_

; --- enemy is attacking (wild/trainer mon trying to flee/Roar the player away) ---
.handleEnemy:
    mov al, [ebp + wIsInBattle]
    dec al
    jnz .notWildBattle2

    mov al, [ebp + wBattleMonLevel]
    mov bh, al                          ; b = playerLevel
    mov al, [ebp + wCurEnemyLevel]
    cmp al, bh                          ; is the enemy's level >= the player's level?
    jae .enemyMoveWasSuccessful
    add al, bh                          ; a = enemyLevel + playerLevel (8-bit wrap, faithful)
    mov bl, al
    inc bl
.rejectionSampleLoop2:
    call BattleRandom
    cmp al, bl
    jae .rejectionSampleLoop2
    shr bh, 1
    shr bh, 1                           ; b = playerLevel / 4
    cmp al, bh
    jae .enemyMoveWasSuccessful
    mov bl, 50
    call DelayFrames
    mov al, [ebp + wEnemyMoveNum]
    cmp al, TELEPORT
    jnz PrintDidntAffectText
    jmp PrintButItFailedText_
.enemyMoveWasSuccessful:
    call ReadPlayerMonCurHPAndStatus
    xor al, al
    mov byte [ebp + wAnimationType], al
    inc al
    mov byte [ebp + wEscapedFromBattle], al
    mov al, [ebp + wEnemyMoveNum]
    jmp .playAnimAndPrintText
; NOTE (faithful, not a bug per docs/bugs_and_glitches.md — no entry there for
; this routine, so not BUG-tagged, but flagged for the auditor): pret's
; .notWildBattle2 ends in `jp ConditionalPrintButItFailed` while the player's
; mirror-image .notWildBattle1 above ends in an unconditional
; `jp PrintButItFailedText_`. This asymmetry is exactly what pret does — the
; enemy path additionally respects wMoveDidntMiss (stays silent if the
; attack itself missed) where the player path always prints "But it failed!".
; Preserved verbatim; this is the genuine pret control-flow split, not a
; transcription error.
.notWildBattle2:
    mov bl, 50
    call DelayFrames
    mov esi, IsUnaffectedText
    mov al, [ebp + wEnemyMoveNum]
    cmp al, TELEPORT
    jnz PrintText
    jmp ConditionalPrintButItFailed

; --- shared tail: the escaping side's move succeeded — animate + report ---
.playAnimAndPrintText:
    push eax                            ; push af (only AL is load-bearing past here)
    call PlayBattleAnimation            ; al = move num in/out; stub is a no-op (§2 item 1)
    mov bl, 20
    call DelayFrames
    pop eax
    mov esi, RanFromBattleText
    cmp al, TELEPORT
    je .printText
    mov esi, RanAwayScaredText
    cmp al, ROAR
    je .printText
    mov esi, WasBlownAwayText           ; WHIRLWIND (or any other move routed here)
.printText:
    jmp PrintText
