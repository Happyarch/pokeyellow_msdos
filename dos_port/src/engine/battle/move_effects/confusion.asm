; confusion.asm — ConfusionSideEffect + ConfusionEffect (move-effect swarm).
;
; Faithful translation of engine/battle/effects.asm:ConfusionSideEffect,
; ConfusionEffect, ConfusionSideEffectSuccess and ConfusionEffectFailed
; (pret/pokeyellow). In pret these four labels are one contiguous block joined by
; fall-through:
;   ConfusionSideEffect  (CONFUSION_SIDE_EFFECT $4C, the damaging move Confusion's
;                         10%-chance side effect) → rolls 10%, then falls through to
;   ConfusionEffect      (CONFUSION_EFFECT $31, Confuse Ray / Supersonic — the main,
;                         accuracy-tested status move) → substitute + hit test, then
;   ConfusionSideEffectSuccess → set CONFUSED + roll the 2-5 turn counter, and
;   ConfusionEffectFailed      → silent for the side effect, "But it failed!" else.
; Because the fall-through IS the control flow, both effect entry points and both
; shared tails live in this one file (folding the separate ConfusionSideEffect
; ticket in); the shared tails are file-local `.` labels.
;
; Fidelity boundary: docs/move_translation_divergence.md. Shared externs (§4) are
; called, not redefined; only §2 allowlist items (literal subanim via
; PlayCurrentMoveAnimation2) diverge. Drives PrintText / ConditionalPrintButItFailed
; / DelayFrames (faithful, §3).
;
; Register map: A=AL, B=BH, C=BL (BC=BX/EBX), D=DH, E=DL (DE=EDX), HL=ESI, EBP=GB
; base. GB memory at [EBP+addr]; battle_text streams are flat program addresses.
;
; Build: nasm -f coff -I include/ -I . -o /dev/null confusion.asm

bits 32

%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"

section .text

global ConfusionEffect_
global ConfusionSideEffect_

; --- shared scaffold externs (§4: call, never define) ---
extern CheckTargetSubstitute        ; move_effect_helpers.asm — ZF=1 if no substitute
extern MoveHitTest                  ; core_damage.asm — accuracy test → wMoveMissed
extern BattleRandom                 ; home/random.asm
extern PrintText                    ; move_effect_helpers.asm — ESI = flat text stream
extern ConditionalPrintButItFailed  ; move_effect_helpers.asm
extern DelayFrames                  ; frame.asm — BL = frame count
; --- allowlist anim stub (§2 item 1: literal subanim, ANIMATION=OFF path) ---
extern PlayCurrentMoveAnimation2
; --- battle_text.inc stream (global in core.o) ---
extern BecameConfusedText

; ===========================================================================
; ConfusionSideEffect_ — pret ConfusionSideEffect. The damaging move Confusion's
; 10% side effect: roll, and on success fall through into the shared success path.
; Silent on a failed roll (ret nc).
; ===========================================================================
ConfusionSideEffect_:
    call BattleRandom
    cmp al, 10 * 0xFF / 100             ; cp 10 percent — chance of confusion
    jae .ret                            ; ret nc — roll failed, stay silent
    jmp ConfusionSideEffectSuccess      ; jr ConfusionSideEffectSuccess
.ret:
    ret

; ===========================================================================
; ConfusionEffect_ — pret ConfusionEffect. Confuse Ray / Supersonic: substitute +
; accuracy test, then the shared success path. Fails (silently, after the checks)
; on substitute / miss; "But it failed!" if the target is already confused.
; ===========================================================================
ConfusionEffect_:
    call CheckTargetSubstitute
    jnz ConfusionEffectFailed           ; jr nz, ConfusionEffectFailed
    call MoveHitTest                    ; → wMoveMissed
    mov al, [ebp + wMoveMissed]
    and al, al
    jnz ConfusionEffectFailed           ; jr nz, ConfusionEffectFailed

; --- ConfusionSideEffectSuccess (shared; ConfusionEffect_ falls straight in, and
; ConfusionSideEffect_ jumps here on a successful roll). Plain file-local labels
; (not dot-locals) so both entry points can reference them. ---
ConfusionSideEffectSuccess:
    mov al, [ebp + hWhoseTurn]
    and al, al                          ; ZF preserved across the movs below
    mov esi, wEnemyBattleStatus1        ; ld hl, wEnemyBattleStatus1
    mov ebx, wEnemyConfusedCounter      ; ld bc, wEnemyConfusedCounter
    mov al, [ebp + wPlayerMoveEffect]   ; ld a, [wPlayerMoveEffect]
    jz .confuseTarget
    mov esi, wPlayerBattleStatus1       ; ld hl, wPlayerBattleStatus1
    mov ebx, wPlayerConfusedCounter     ; ld bc, wPlayerConfusedCounter
    mov al, [ebp + wEnemyMoveEffect]    ; ld a, [wEnemyMoveEffect]
.confuseTarget:
    test byte [ebp + esi], 1 << CONFUSED   ; bit CONFUSED, [hl] — is mon confused?
    jnz ConfusionEffectFailed              ; jr nz, ConfusionEffectFailed (AL = move effect)
    or byte [ebp + esi], 1 << CONFUSED     ; set CONFUSED, [hl] — mon is now confused
    push eax                               ; push af — preserve the move-effect byte
    call BattleRandom                      ; clobbers AL only (ESI/EBX preserved)
    and al, 3
    inc al
    inc al
    mov [ebp + ebx], al                    ; ld [bc], a — confusion lasts 2-5 turns
    pop eax                                ; pop af
    cmp al, CONFUSION_SIDE_EFFECT
    jz .skipAnim                           ; call nz, PlayCurrentMoveAnimation2
    call PlayCurrentMoveAnimation2         ;   (the damaging move already played its own
.skipAnim:                                 ;    subanim, so skip it for the side effect)
    mov esi, BecameConfusedText            ; ld hl, BecameConfusedText
    jmp PrintText                          ; jp PrintText

; --- ConfusionEffectFailed (shared fall-through). Literal translation: AL holds
; whatever the predecessor left — the move-effect byte on the already-confused
; entry (so $4C → silent for the side effect), or a non-$4C value on the
; substitute/miss early-fail entries (→ loud "But it failed!"). ---
ConfusionEffectFailed:
    cmp al, CONFUSION_SIDE_EFFECT
    jz .ret                             ; ret z — side-effect path stays silent
    mov bl, 50                          ; ld c, 50
    call DelayFrames
    jmp ConditionalPrintButItFailed
.ret:
    ret
