; battle_stubs.asm — temporary stubs so core_damage.asm links into the battle
; front end before the full Wave-1 backend is wired.
;
; Both symbols are referenced by core_damage.asm only on code paths the Stage-2b
; damage calc does NOT take yet:
;   * JumpMoveEffect      — reached only via JumpToOHKOMoveEffect (OHKO moves) and
;                           the move-effect dispatch (effects.asm). Stubbed here so
;                           we don't drag in the whole effect-handler closure.
;   * CheckTargetSubstitute — reached only via MoveHitTest (accuracy/substitute),
;                           which the first damage pass skips.
; These will be replaced by the real routines (effects.asm / a CheckTargetSubstitute
; port) when the turn loop needs effects + accuracy.
;
bits 32
section .text

global JumpMoveEffect
global CheckTargetSubstitute

JumpMoveEffect:
    ret

CheckTargetSubstitute:
    ret
