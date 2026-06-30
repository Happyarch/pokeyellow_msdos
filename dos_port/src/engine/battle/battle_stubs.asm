; battle_stubs.asm — temporary stub so core_damage.asm links into the battle front end.
;
; JumpMoveEffect is stubbed in core_stubs.asm (the effects.asm closure isn't link-ready
; yet — see that file). CheckTargetSubstitute remains stubbed here — it is reached only
; via MoveHitTest (accuracy/substitute), and the Substitute effect isn't ported yet.
; Replace it with a faithful port when Substitute lands.
;
bits 32
section .text

global CheckTargetSubstitute

CheckTargetSubstitute:
    ret
