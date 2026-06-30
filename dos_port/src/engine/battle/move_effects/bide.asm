; 985__BideEffect.asm — BideEffect (move-effect translation swarm worker output).
;
; Faithful translation of engine/battle/effects.asm:BideEffect (pret/pokeyellow).
; Bide is SETUP-only here: it sets the STORING_ENERGY battle-status bit on the
; user's side, zeroes the (word) accumulated-damage counter, clears BOTH move-effect
; bytes (literal pret behavior — see note below), rolls a random 2-3 turn counter
; into the overloaded wXxxNumAttacksLeft byte, and tails into the literal subanim
; (allowlist stub). The damage accumulation (when the user is hit while storing
; energy) and the release-on-counter-expiry (double accumulated damage back at the
; foe) live elsewhere in the battle core — out of scope for this ticket.
;
; Fidelity boundary: docs/move_translation_divergence.md. Shared externs (§4) are
; called, not redefined; only §2 allowlist item 1 (literal subanim via
; PlayBattleAnimation2, ANIMATION=OFF path) diverges.
;
; Register map: A=AL, B=BH, C=BL (BC=BX/EBX as an address pointer, matching the
; confusion.asm/poison.asm convention), D=DH, E=DL (DE=EDX as an address pointer),
; HL=ESI, EBP=GB base. GB memory at [EBP+addr].
;
; Build: nasm -f coff -I include/ -I . -o /dev/null 985__BideEffect.asm

bits 32

%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"

section .text

global BideEffect_

; --- shared scaffold externs (§4: call, never define) ---
extern BattleRandom                 ; home/random.asm
; --- allowlist anim stub (§2 item 1: literal subanim, ANIMATION=OFF path) ---
extern PlayBattleAnimation2

; XSTATITEM_ANIM ($AE) is provided by gb_constants.inc (folded in by the master).

; ===========================================================================
; BideEffect_ — pret BideEffect. Sets STORING_ENERGY on the user's side, clears
; the 2-byte accumulated-damage counter, clears wPlayerMoveEffect/wEnemyMoveEffect
; (both, unconditionally — literal pret behavior, not gated by hWhoseTurn; harmless
; here since EffectCallBattleCore's caller re-fetches/uses the move-effect byte
; before this handler runs, matching pret's own assumption), rolls a 2-3 turn
; Bide counter into the (overloaded) wXxxNumAttacksLeft byte, and plays the
; XSTATITEM_ANIM-family subanim (literal subanim → allowlist stub, §2 item 1).
;
; pret:
;   BideEffect:
;       ld hl, wPlayerBattleStatus1
;       ld de, wPlayerBideAccumulatedDamage
;       ld bc, wPlayerNumAttacksLeft
;       ldh a, [hWhoseTurn]
;       and a
;       jr z, .bideEffect
;       ld hl, wEnemyBattleStatus1
;       ld de, wEnemyBideAccumulatedDamage
;       ld bc, wEnemyNumAttacksLeft
;   .bideEffect
;       set STORING_ENERGY, [hl] ; mon is now using bide
;       xor a
;       ld [de], a
;       inc de
;       ld [de], a
;       ld [wPlayerMoveEffect], a
;       ld [wEnemyMoveEffect], a
;       call BattleRandom
;       and $1
;       inc a
;       inc a
;       ld [bc], a ; set Bide counter to 2 or 3 at random
;       ldh a, [hWhoseTurn]
;       add XSTATITEM_ANIM
;       jp PlayBattleAnimation2
; ===========================================================================
BideEffect_:
    mov esi, wPlayerBattleStatus1       ; ld hl, wPlayerBattleStatus1
    mov edx, wPlayerBideAccumulatedDamage ; ld de, wPlayerBideAccumulatedDamage
    mov ebx, wPlayerNumAttacksLeft      ; ld bc, wPlayerNumAttacksLeft
    mov al, [ebp + hWhoseTurn]          ; ldh a, [hWhoseTurn]
    and al, al
    jz .bideEffect                      ; jr z, .bideEffect
    mov esi, wEnemyBattleStatus1        ; ld hl, wEnemyBattleStatus1
    mov edx, wEnemyBideAccumulatedDamage ; ld de, wEnemyBideAccumulatedDamage
    mov ebx, wEnemyNumAttacksLeft       ; ld bc, wEnemyNumAttacksLeft
.bideEffect:
    or byte [ebp + esi], 1 << STORING_ENERGY  ; set STORING_ENERGY, [hl] — mon is now using bide
    xor al, al                          ; xor a
    mov [ebp + edx], al                 ; ld [de], a — low byte of accumulated damage
    inc edx                             ; inc de
    mov [ebp + edx], al                 ; ld [de], a — high byte of accumulated damage
    mov [ebp + wPlayerMoveEffect], al   ; ld [wPlayerMoveEffect], a
    mov [ebp + wEnemyMoveEffect], al    ; ld [wEnemyMoveEffect], a
    call BattleRandom
    and al, 1                           ; and $1
    inc al
    inc al                              ; a = 2 or 3
    mov [ebp + ebx], al                 ; ld [bc], a — set Bide counter to 2 or 3 at random
    mov al, [ebp + hWhoseTurn]          ; ldh a, [hWhoseTurn]
    add al, XSTATITEM_ANIM              ; add XSTATITEM_ANIM
    jmp PlayBattleAnimation2            ; jp PlayBattleAnimation2
