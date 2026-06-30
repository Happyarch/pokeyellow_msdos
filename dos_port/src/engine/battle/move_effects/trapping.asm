; 1002__TrappingEffect.asm — TrappingEffect (move-effect translation swarm worker output).
;
; Faithful translation of engine/battle/effects.asm:TrappingEffect (pret/pokeyellow).
; Partial-trapping handler shared by Wrap, Bind, Fire Spin, and Clamp: sets the
; USING_TRAPPING_MOVE battle-status bit on the attacker and rolls a 2-5 attack
; counter into wXxxNumAttacksLeft, after clearing any pending Hyper Beam recharge.
;
; Fidelity boundary: docs/move_translation_divergence.md. Shared externs (§4) are
; called, not redefined; only §2 allowlist items (literal subanim, audio, banks)
; diverge. This handler has none of those — it is pure WRAM/RNG bookkeeping, no
; animation or text of its own (the caller's accuracy test + damage pipeline pick
; up animation/text afterward).
;
; Register map: A=AL, B=BH, C=BL (BC=BX), D=DH, E=DL (DE=EDX), HL=ESI, EBP=GB base.
; GB memory at [EBP+addr].
;
; Build: nasm -f coff -I include/ -I . -o /dev/null 1002__TrappingEffect.asm

bits 32

%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"

section .text

global TrappingEffect_

; --- shared scaffold externs (§4: call, never define) ---
extern ClearHyperBeam               ; move_effect_helpers.asm — already shared global
extern BattleRandom                 ; core_damage.asm — battle RNG

; ===========================================================================
; TrappingEffect_ — pret engine/battle/effects.asm:TrappingEffect
;
; Sets USING_TRAPPING_MOVE on the attacker's own battle-status (hWhoseTurn side)
; and seeds wXxxNumAttacksLeft with a 2-5 turn counter (3/8 chance of 2 or 3,
; 1/8 chance of 4 or 5 — matches pret's comment). If the attacker is already
; mid-trap (bit already set, e.g. turn 2 of a Wrap), this is a no-op: ret nz
; leaves the existing counter untouched, so a Wrap chain doesn't re-roll its
; remaining-turns count each turn — faithful to pret.
;
; NOTE (pret comment, preserved verbatim — not a bugs_and_glitches.md-listed bug,
; just the original author's own caveat): this effect runs BEFORE the move's
; accuracy/hit test, so ClearHyperBeam fires — and USING_TRAPPING_MOVE/the attack
; counter get set — even if the trapping move goes on to miss. The practical
; upshot is the attacker won't need to recharge from a prior Hyper Beam even when
; the trapping move whiffs. This is intentional pret behavior (order of operations
; in JumpMoveEffect), not something this handler can or should "fix" — translated
; verbatim.
; ===========================================================================
TrappingEffect_:
    mov esi, wPlayerBattleStatus1       ; hl = wPlayerBattleStatus1
    mov edx, wPlayerNumAttacksLeft      ; de = wPlayerNumAttacksLeft
    mov al, [ebp + hWhoseTurn]
    and al, al
    jz .trappingEffect
    mov esi, wEnemyBattleStatus1
    mov edx, wEnemyNumAttacksLeft
.trappingEffect:
    test byte [ebp + esi], 1 << USING_TRAPPING_MOVE
    jnz .ret                            ; ret nz — already trapping; leave counter alone
    call ClearHyperBeam                 ; see NOTE above: runs before the hit test
    or byte [ebp + esi], 1 << USING_TRAPPING_MOVE   ; mon is now using a trapping move
    call BattleRandom                   ; 3/8 chance for 2 and 3 attacks,
    and al, 3                           ; 1/8 chance for 4 and 5 attacks
    cmp al, 2
    jc .setTrappingCounter
    call BattleRandom
    and al, 3
.setTrappingCounter:
    inc al
    mov [ebp + edx], al
.ret:
    ret
