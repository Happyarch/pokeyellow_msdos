; animations.asm — battle move-animation entry (decision-tree stub).
;
; Faithful skeleton of the `.moveAnimation` decision in pret
; engine/battle/animations.asm:MoveAnimation. The real animation playback
; (ShareMoveAnimations + PlayAnimation: subanimation tile streaming, palette
; cycling, screen shake) is a large graphics subsystem deferred to the battle-
; animation HAL. Only the branch the battle loop strictly needs today is faithful:
; when the player has battle animations turned OFF in the options
; (BIT_BATTLE_ANIMATION set), the original substitutes a fixed 30-frame delay so
; the message pacing still feels right — we replicate exactly that. With
; animations ON, the real animation would play; that path is a `; TODO-HW:` no-op
; until the animation HAL lands.
;
; Build: nasm -f coff -I include/ -I . -o animations.o animations.asm
; ---------------------------------------------------------------------------
bits 32

%include "gb_memmap.inc"

global PlayMoveAnimation

extern DelayFrames               ; src/video/frame.asm — BL = frame count

section .text

; ---------------------------------------------------------------------------
; PlayMoveAnimation — play (or fake) the current move's battle animation.
; In:  EBP = GB memory base. Out: all registers preserved.
; pret ref: engine/battle/animations.asm:MoveAnimation `.moveAnimation`.
; ---------------------------------------------------------------------------
PlayMoveAnimation:
    push eax
    push ebx
    mov al, [ebp + wOptions]
    test al, 1 << BIT_BATTLE_ANIMATION
    jnz .animations_disabled
    ; TODO-HW: battle move animation HAL — ShareMoveAnimations + PlayAnimation
    ; (subanimation tile streaming, palette cycling, PlayApplyingAttackAnimation
    ; screen shake). Deferred; no-op while animations are enabled.
    jmp .done
.animations_disabled:
    ; animations off in options → original substitutes a flat 30-frame delay.
    mov bl, 30
    call DelayFrames
.done:
    pop ebx
    pop eax
    ret
