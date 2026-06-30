; 954__SleepEffect.asm — SleepEffect (move-effect translation swarm worker ticket).
;
; Faithful translation of engine/battle/effects.asm:SleepEffect (pret/pokeyellow).
; Inflicts SLEEP on the target: bypasses ALL hit-tests (already-asleep,
; already-statused, accuracy) if the target needed to recharge (Hyper Beam);
; otherwise checks already-asleep / already-statused, applies the accuracy test
; (MoveHitTest), then rolls a 1-7 turn sleep counter, with a Stadium-link-related
; reroll-restriction tail.
;
; Fidelity boundary: docs/move_translation_divergence.md. Shared externs (§4) are
; called, not redefined; only §2 allowlist items (literal subanim) diverge.
; Drives PrintText (faithful, §3).
;
; Register map: A=AL, B=BH, C=BL (BC=BX), D=DH, E=DL (DE=EDX), HL=ESI, EBP=GB base.
; GB memory at [EBP+addr]; battle_text streams are flat program addresses.
; Per the established swarm idiom (poison.asm, paralyze.asm), pret BC/DE register
; pairs holding a GB *address* are carried in the full 32-bit EBX/EDX (not BX/DX)
; so `[ebp + ebx]` / `[ebp + edx]` addressing works directly.
;
; Build: nasm -f coff -I include/ -I . -o 954__SleepEffect.o 954__SleepEffect.asm

bits 32

%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"

; --- shared scaffold externs (§4: call, never define) ---
extern MoveHitTest                  ; core_damage.asm — accuracy/substitute/mist test → wMoveMissed
extern BattleRandom                 ; home/random.asm
extern PrintText                    ; move_effect_helpers.asm — ESI = flat text stream
extern PrintDidntAffectText         ; move_effect_helpers.asm
; --- allowlist anim stub (§2 item 1: literal subanim, ANIMATION=OFF path) ---
extern PlayCurrentMoveAnimation2
; --- battle_text.inc streams (global in core.o) ---
extern FellAsleepText
extern AlreadyAsleepText

; wUnknownSerialFlag_d499 ($D499) is provided by gb_memmap.inc (folded in by the
; integration master; also used by FreezeBurnParalyzeEffect's reroll restriction).

section .text

global SleepEffect_

; ===========================================================================
; SleepEffect_ — inflict SLEEP (1-7 turn counter) on the target.
; ===========================================================================
SleepEffect_:
    mov edx, wEnemyMonStatus            ; de = target status (player's turn → enemy)
    mov ebx, wEnemyBattleStatus2        ; bc = target battle status 2 (recharge flag lives here)
    mov al, [ebp + hWhoseTurn]
    and al, al
    jz .sleepEffect
    mov edx, wBattleMonStatus
    mov ebx, wPlayerBattleStatus2
.sleepEffect:
    mov al, [ebp + ebx]                 ; ld a,[bc]
    mov cl, al
    and cl, 1 << NEEDS_TO_RECHARGE      ; bit NEEDS_TO_RECHARGE,a — does the target need to recharge?
    and al, ~(1 << NEEDS_TO_RECHARGE) & 0xFF   ; res NEEDS_TO_RECHARGE,a — target no longer needs to recharge
    mov [ebp + ebx], al                 ; ld [bc],a (write back unconditionally)
    ; BUG(cosmetic): Hyper Beam recharge bypasses ALL hit-tests for status moves —
    ; a target that needed to recharge this turn is unconditionally put to sleep,
    ; skipping the already-asleep/already-statused check AND the accuracy test
    ; (MoveHitTest). pret's own comment flags this ("if the target had to recharge,
    ; all hit tests will be skipped including the event where the target already
    ; has another status"). Preserved verbatim below; the fix re-runs the normal
    ; checks instead of short-circuiting straight to the counter roll.
    ; pret ref: engine/battle/effects.asm:SleepEffect.
%if BUG_FIX_LEVEL >= 2
    ; fixed: fall through into the normal already-asleep/-statused + accuracy path
    ; even when the target needed to recharge (no early jump to .setSleepCounter).
%else
    test cl, cl
    jnz .setSleepCounter                 ; jr nz, .setSleepCounter (original bug)
%endif
    mov al, [ebp + edx]                  ; ld a,[de] — status byte
    mov bh, al                           ; ld b,a (stash full status byte)
    and al, SLP_MASK
    jz .notAlreadySleeping               ; jr z — not already asleep
    mov esi, AlreadyAsleepText           ; ld hl, AlreadyAsleepText
    jmp PrintText                        ; jp PrintText
.notAlreadySleeping:
    mov al, bh
    and al, al
    jnz .didntAffect                     ; jr nz — already has another status
    push edx                             ; push de
    call MoveHitTest                     ; apply accuracy tests (clobbers esi/edx/ebx/eax)
    pop edx                              ; pop de
    mov al, [ebp + wMoveMissed]
    and al, al
    jnz .didntAffect                     ; jr nz
.setSleepCounter:
; set target's sleep counter to a random number between 1 and 7
    call BattleRandom
    and al, SLP_MASK
    jz .setSleepCounter                  ; jr z — reroll on 0
    mov bh, al                           ; ld b,a
    mov al, [ebp + wUnknownSerialFlag_d499]
    and al, al
    jz .continueSetCounter               ; jr z — XXX stadium stuff? (always taken
                                          ; on real DMG/CGB hardware and in this port;
                                          ; only set during a GB Stadium link session)
    mov al, bh
    and al, 0x3
    jz .setSleepCounter                  ; jr z
    mov bh, al
.continueSetCounter:
    mov al, bh                           ; ld a,b
    mov [ebp + edx], al                  ; ld [de],a
    call PlayCurrentMoveAnimation2       ; literal subanim — ANIMATION=OFF stub (§2.1)
    mov esi, FellAsleepText              ; ld hl, FellAsleepText
    jmp PrintText                        ; jp PrintText
.didntAffect:
    jmp PrintDidntAffectText             ; jp PrintDidntAffectText
