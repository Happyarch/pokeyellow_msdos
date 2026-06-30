; 1013__HyperBeamEffect.asm — HyperBeamEffect (move-effect translation swarm).
;
; Faithful translation of engine/battle/effects.asm:HyperBeamEffect (pret/pokeyellow).
; Sets the NEEDS_TO_RECHARGE bit on the ATTACKER's wXxxBattleStatus2 (player on the
; player's turn, enemy on the enemy's turn) after a Hyper Beam (or Frenzy Plant /
; Hydro Cannon / Blast Burn, if those were defined — gen-1 only has Hyper Beam) hit.
; The matching "must recharge" check/skip is handled elsewhere in core.asm; this
; handler only sets the flag. ClearHyperBeam (the inverse) already lives in
; move_effect_helpers.asm and is not redefined here.
;
; Fidelity boundary: docs/move_translation_divergence.md. Shared externs (§4) are
; called, not redefined; only §2 allowlist items (literal subanim, audio, banks)
; diverge. This handler is pure WRAM bit-set logic — no text, no animation, no
; accuracy test — so there is nothing to diverge: it's a 1:1 translation.
;
; Register map: A=AL, B=BH, C=BL (BC=BX), D=DH, E=DL (DE=EDX), HL=ESI, EBP=GB base.
; GB memory at [EBP+addr].
;
; Build: nasm -f coff -I include/ -I . -o /dev/null 1013__HyperBeamEffect.asm

bits 32

%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"

section .text

global HyperBeamEffect_

; --- shared scaffold externs (§4: call, never define) ---
; (HyperBeamEffect itself has no shared-helper calls — it is a bare WRAM bit-set,
; matching pret exactly. Listed here for completeness / future-proofing only if
; the dispatcher ever needs to fall through into a shared tail.)

; ===========================================================================
; HyperBeamEffect_ — pret engine/battle/effects.asm:HyperBeamEffect.
;   ld hl, wPlayerBattleStatus2
;   ldh a, [hWhoseTurn]
;   and a
;   jr z, .hyperBeamEffect
;   ld hl, wEnemyBattleStatus2
; .hyperBeamEffect
;   set NEEDS_TO_RECHARGE, [hl]   ; mon now needs to recharge
;   ret
;
; In: hWhoseTurn (0 = player's turn, nonzero = enemy's turn) selects which side's
; wXxxBattleStatus2 byte gets NEEDS_TO_RECHARGE set — the ATTACKING side (the side
; whose hWhoseTurn value it is), matching pret's literal hl selection.
; Out: NEEDS_TO_RECHARGE bit set on that side's battle-status-2 byte.
; Clobbers: AL, ESI.
; ===========================================================================
HyperBeamEffect_:
    mov esi, wPlayerBattleStatus2       ; ld hl, wPlayerBattleStatus2
    mov al, [ebp + hWhoseTurn]          ; ldh a, [hWhoseTurn]
    and al, al
    jz .hyperBeamEffect                 ; jr z, .hyperBeamEffect
    mov esi, wEnemyBattleStatus2        ; ld hl, wEnemyBattleStatus2
.hyperBeamEffect:
    or byte [ebp + esi], 1 << NEEDS_TO_RECHARGE   ; set NEEDS_TO_RECHARGE, [hl]
    ret
