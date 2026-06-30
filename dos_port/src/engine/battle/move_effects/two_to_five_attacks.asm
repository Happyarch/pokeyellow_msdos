; 991__TwoToFiveAttacksEffect.asm — TwoToFiveAttacksEffect (move-effect swarm worker).
;
; Faithful translation of engine/battle/effects.asm:TwoToFiveAttacksEffect (pret/
; pokeyellow). Sets ATTACKING_MULTIPLE_TIMES on the attacker's battle-status byte
; (re-entry guard for the multi-hit loop), then decides the hit count for the turn
; and writes it to both wXxxNumAttacksLeft and wXxxNumHits:
;   - ATTACK_TWICE_EFFECT ($2C, e.g. Double Kick)  -> always 2 hits.
;   - TWINEEDLE_EFFECT ($4D, Twineedle)            -> always 2 hits (see note below),
;                                                      AND rewrites the move's own
;                                                      effect byte to POISON_SIDE_EFFECT1
;                                                      so the second hit chains into the
;                                                      poison side-effect roll.
;   - everything else (TWO_TO_FIVE_ATTACKS_EFFECT $1D, and the unused EFFECT_1E $1E,
;     which pret routes through the same fallthrough since it never special-cases it
;     here) -> BattleRandom 2-bit roll, 3/8 chance of 2 or 3 hits, 1/8 chance of 4 or 5
;     hits (reroll once if the first roll was >= 2, then +2).
;
; This handler does NOT print text or play an animation — pret's TwoToFiveAttacksEffect
; is pure RNG + WRAM bookkeeping; the actual hits/animations happen via the normal
; per-hit attack/effect dispatch that follows.
;
; Fidelity boundary: docs/move_translation_divergence.md. Shared externs (§4) are
; called, not redefined; only §2 allowlist items (literal subanim, audio, banks)
; may diverge — this handler doesn't touch any of them. Pure WRAM control flow (§3)
; is translated verbatim, including the BattleRandom roll/table and the Twineedle
; register-reuse quirk below.
;
; Register map: A=AL, B=BH, C=BL (BC=BX), D=DH, E=DL (DE=EDX), HL=ESI, EBP=GB base.
; GB memory at [EBP+addr].
;
; Build: nasm -f coff -I include/ -I . -o /dev/null 991__TwoToFiveAttacksEffect.asm

bits 32

%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"

section .text

global TwoToFiveAttacksEffect_

; --- shared scaffold externs (§4: call, never define) ---
extern BattleRandom                 ; home/random.asm — battle RNG, AL = result

; ===========================================================================
; TwoToFiveAttacksEffect_ — pick the multi-hit count for the current attacker's
; turn and stash it in wXxxNumAttacksLeft / wXxxNumHits. Guarded by
; ATTACKING_MULTIPLE_TIMES so it only runs once per multi-hit sequence (the
; per-hit dispatch loop that follows calls back into the same move's effect
; jump table on every hit; this routine must not re-roll mid-sequence).
;
; pret: HL = wXxxBattleStatus1 (re-entry-guard byte), DE = wXxxNumAttacksLeft,
; BC = wXxxNumHits, selected by hWhoseTurn. Translated: ESI/EDX/ECX respectively.
; ===========================================================================
TwoToFiveAttacksEffect_:
    mov esi, wPlayerBattleStatus1       ; hl = wPlayerBattleStatus1
    mov edx, wPlayerNumAttacksLeft      ; de = wPlayerNumAttacksLeft
    mov ecx, wPlayerNumHits             ; bc = wPlayerNumHits
    mov al, [ebp + hWhoseTurn]
    and al, al
    jz .twoToFiveAttacksEffect
    mov esi, wEnemyBattleStatus1
    mov edx, wEnemyNumAttacksLeft
    mov ecx, wEnemyNumHits
.twoToFiveAttacksEffect:
    mov al, [ebp + esi]                 ; ld a,[hl] — battle status byte (no hl advance)
    bt ax, ATTACKING_MULTIPLE_TIMES     ; bit ATTACKING_MULTIPLE_TIMES, [hl]
    jc .ret                             ; ret nz — already mid multi-hit sequence
    or byte [ebp + esi], 1 << ATTACKING_MULTIPLE_TIMES   ; set ATTACKING_MULTIPLE_TIMES, [hl]

    mov esi, wPlayerMoveEffect          ; hl = wPlayerMoveEffect
    mov al, [ebp + hWhoseTurn]
    and al, al
    jz .setNumberOfHits
    mov esi, wEnemyMoveEffect
.setNumberOfHits:
    mov al, [ebp + esi]                 ; ld a,[hl] — this move's effect byte
    cmp al, TWINEEDLE_EFFECT
    je .twineedle
    cmp al, ATTACK_TWICE_EFFECT
    mov al, 2                           ; number of hits is always 2 for ATTACK_TWICE_EFFECT
    je .saveNumberOfHits
    ; TWO_TO_FIVE_ATTACKS_EFFECT (and the unused EFFECT_1E, which pret never special-
    ; cases — both fall through to this same generic roll): 3/8 chance for 2 and 3
    ; hits, 1/8 chance for 4 and 5 hits.
    call BattleRandom
    and al, 0x3
    cmp al, 0x2
    jc .gotNumHits
    ; if the number of hits was >= 2 (i.e. the 2-bit roll was 2 or 3), re-roll again
    ; for a lower chance of landing on the high end (4/5 hits)
    call BattleRandom
    and al, 0x3
.gotNumHits:
    inc al
    inc al
.saveNumberOfHits:
    mov [ebp + edx], al                 ; ld [de],a — wXxxNumAttacksLeft
    mov [ebp + ecx], al                 ; ld [bc],a — wXxxNumHits
    ret
.twineedle:
    ; NOTE (not a bug — faithful register-reuse quirk, pret ref:
    ; engine/battle/effects.asm:TwoToFiveAttacksEffect.twineedle): pret rewrites
    ; Twineedle's own move-effect byte to POISON_SIDE_EFFECT1 here (so the second
    ; hit's effect dispatch chains into the poison side-effect roll), then falls
    ; through to .saveNumberOfHits *without recomputing A* — the hit count Twineedle
    ; ends up with is whatever AL holds at that point, which is POISON_SIDE_EFFECT1
    ; itself (0x02). This only produces the correct "2 hits" because
    ; POISON_SIDE_EFFECT1 == 2 by coincidence of the effect-constant numbering.
    ; Preserved verbatim — do not "fix" by loading an explicit 2.
    mov al, POISON_SIDE_EFFECT1
    mov [ebp + esi], al                 ; ld [hl],a — overwrite move effect byte
    jmp .saveNumberOfHits
.ret:
    ret
