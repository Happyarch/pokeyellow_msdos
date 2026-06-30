; 986__ThrashPetalDanceEffect.asm — ThrashPetalDanceEffect (move-effect translation swarm).
;
; Faithful translation of engine/battle/effects.asm:ThrashPetalDanceEffect (pret/pokeyellow).
; Thrash / Petal Dance: sets the THRASHING_ABOUT bit on the attacker's
; wXxxBattleStatus1 byte and rolls a random 2-3 turn lock-in counter into the
; attacker's wXxxNumAttacksLeft, then plays the (allowlist-stubbed) per-side
; "shrinking square" battle animation.
;
; Fidelity boundary: docs/move_translation_divergence.md. Shared externs (§4) are
; called, not redefined; only §2 allowlist items (literal subanim, audio, banks)
; diverge. This handler is pure WRAM bit-set + RNG-counter logic with a tail
; jump into the (stubbed) subanim player — a 1:1 translation, nothing else to
; diverge.
;
; Register map: A=AL, B=BH, C=BL (BC=BX), D=DH, E=DL (DE=EDX), HL=ESI, EBP=GB base.
; GB memory at [EBP+addr].
;
; Build: nasm -f coff -I include/ -I . -o /dev/null 986__ThrashPetalDanceEffect.asm

bits 32

%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"

section .text

global ThrashPetalDanceEffect_

; --- shared scaffold externs (§4: call, never define) ---
extern BattleRandom                 ; home/random.asm — battle RNG, result in AL
; --- allowlist anim stub (§2 item 1: literal subanim, ANIMATION=OFF path) ---
extern PlayBattleAnimation2

; SHRINKING_SQUARE_ANIM ($B0) is provided by gb_constants.inc (folded in by the master).

; ===========================================================================
; ThrashPetalDanceEffect_ — pret engine/battle/effects.asm:ThrashPetalDanceEffect.
;   ld hl, wPlayerBattleStatus1
;   ld de, wPlayerNumAttacksLeft
;   ldh a, [hWhoseTurn]
;   and a
;   jr z, .thrashPetalDanceEffect
;   ld hl, wEnemyBattleStatus1
;   ld de, wEnemyNumAttacksLeft
; .thrashPetalDanceEffect
;   set THRASHING_ABOUT, [hl] ; mon is now using thrash/petal dance
;   call BattleRandom
;   and $1
;   inc a
;   inc a
;   ld [de], a ; set thrash/petal dance counter to 2 or 3 at random
;   ldh a, [hWhoseTurn]
;   add SHRINKING_SQUARE_ANIM
;   jp PlayBattleAnimation2
;
; In: hWhoseTurn (0 = player's turn, nonzero = enemy's turn) selects the ATTACKING
; side's wXxxBattleStatus1 / wXxxNumAttacksLeft pair — the literal pret hl/de
; selection (same side that is about to thrash/petal-dance).
; Out: THRASHING_ABOUT set on that side's battle-status-1 byte; that side's
; NumAttacksLeft set to a random 2 or 3 (BattleRandom & 1, + 2). Tail-jumps into
; PlayBattleAnimation2 with AL = SHRINKING_SQUARE_ANIM + hWhoseTurn (the per-side
; anim id pret selects via the literal `add`), matching pret's `jp` (this routine's
; caller is returned to by PlayBattleAnimation2's own ret, exactly as in pret).
; Clobbers: AL, ESI, EDX.
; ===========================================================================
ThrashPetalDanceEffect_:
    mov esi, wPlayerBattleStatus1       ; ld hl, wPlayerBattleStatus1
    mov edx, wPlayerNumAttacksLeft      ; ld de, wPlayerNumAttacksLeft
    mov al, [ebp + hWhoseTurn]          ; ldh a, [hWhoseTurn]
    and al, al
    jz .thrashPetalDanceEffect          ; jr z, .thrashPetalDanceEffect
    mov esi, wEnemyBattleStatus1        ; ld hl, wEnemyBattleStatus1
    mov edx, wEnemyNumAttacksLeft       ; ld de, wEnemyNumAttacksLeft
.thrashPetalDanceEffect:
    or byte [ebp + esi], 1 << THRASHING_ABOUT   ; set THRASHING_ABOUT, [hl]
    call BattleRandom                   ; call BattleRandom -> AL
    and al, 1                           ; and $1
    inc al                              ; inc a
    inc al                              ; inc a  -> al = 2 or 3
    mov [ebp + edx], al                 ; ld [de], a
    mov al, [ebp + hWhoseTurn]          ; ldh a, [hWhoseTurn]
    add al, SHRINKING_SQUARE_ANIM       ; add SHRINKING_SQUARE_ANIM
    jmp PlayBattleAnimation2            ; jp PlayBattleAnimation2 (tail call)
