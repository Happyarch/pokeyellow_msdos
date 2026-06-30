; battle_stubs.asm — (now empty) battle front-end link stubs.
;
; CheckTargetSubstitute was stubbed here; it is now the faithful shared helper in
; move_effect_helpers.asm (the move-effect scaffold), so MoveHitTest's substitute
; check is real. JumpMoveEffect is live in effects.asm. Nothing remains to stub.
;
bits 32
section .text
