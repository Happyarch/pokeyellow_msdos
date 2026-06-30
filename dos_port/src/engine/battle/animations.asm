; animations.asm — battle move-animation entry (faithful ANIMATION=OFF path).
;
; Port of pret engine/battle/animations.asm:MoveAnimation + PlayApplyingAttackAnimation,
; restricted to the behaviour the original game takes when the ANIMATION option is set
; to OFF (wOptions bit BIT_BATTLE_ANIMATION = 1). We have no subanimation engine yet, so
; we ALWAYS implement exactly that branch — this is the sanctioned placeholder, NOT a
; bespoke HP-bar drain. (We can't gate on the wOptions bit the way pret does: its DEFAULT
; is animations ON, which would take the unported PlayAnimation path and play nothing,
; skipping even the delay. We have no engine, so the OFF behaviour is what we render.)
; The HP-bar update is a SEPARATE faithful step (DrawHUDsAndHPBars), done by the caller
; after the move resolves — not here.
;
; pret MoveAnimation (animations.asm:418):
;   WaitForSoundToFinish / SetAnimationPalette       (audio + palette setup)
;   wAnimationID == 0          → finish (no-op)
;   .moveAnimation:
;     wOptions BIT_BATTLE_ANIMATION set (OFF) → .animationsDisabled: DelayFrames(30)
;     (else: ShareMoveAnimations + PlayAnimation — the full subanim engine, NOT ported)
;   .next: PlayApplyingAttackAnimation  (generic "show damage" shake/blink, BOTH cases)
;   .animationFinished: WaitForSoundToFinish + reset anim scratch
;
; Build: nasm -f coff -I include/ -I . -o animations.o animations.asm
; Register map: A=AL, EBP = GB base; GB memory = [EBP+addr].
bits 32

%include "gb_memmap.inc"

%define ANIM_OFF_DELAY 30        ; pret .animationsDisabled: ld c,30 / call DelayFrames

global PlayMoveAnimation
global PlayApplyingAttackAnimation

extern DelayFrames               ; src/video/frame.asm — BL = frame count

section .text

; ---------------------------------------------------------------------------
; PlayMoveAnimation — pret core.asm:PlayMoveAnimation → predef MoveAnimation, the
; ANIMATION=OFF realization. In: AL = animation id (the move number, as core.asm
; passes wPlayerMoveNum/wEnemyMoveNum). All registers preserved.
; ---------------------------------------------------------------------------
PlayMoveAnimation:
    push eax
    push ebx
    mov [ebp + wAnimationID], al
    ; TODO-HW: audio HAL — WaitForSoundToFinish (no-op until the APU HAL, Phase 3).
    ; TODO-HW: SetAnimationPalette — our VGA palette is fixed (Phase 5), so no-op.
    mov al, [ebp + wAnimationID]
    and al, al
    jz .done                            ; wAnimationID 0 → nothing to play
    ; .moveAnimation → .animationsDisabled: a fixed 30-frame delay where the move
    ; animation would play. TODO-HW: full subanimation engine (ShareMoveAnimations +
    ; PlayAnimation) when the battle-animation tile/OAM stream interpreter is ported.
    mov bl, ANIM_OFF_DELAY
    call DelayFrames
    ; .next: the generic applying-attack animation runs in BOTH the on and off cases.
    call PlayApplyingAttackAnimation
.done:
    mov byte [ebp + wAnimationID], 0    ; .animationFinished: clear the anim id scratch
    pop ebx
    pop eax
    ret

; ---------------------------------------------------------------------------
; PlayApplyingAttackAnimation — pret animations.asm:488. The generic post-move effect
; that shakes the screen / blinks the enemy pic "to show damage", dispatched by
; wAnimationType (0 = none → return). The shake/blink themselves drive rWX / the OBJ
; palette, which our software-PPU battle renderer doesn't expose yet, so the dispatch
; is faithfully gated on wAnimationType but the visible shake is a marked TODO-HW.
; Our backend does not set wAnimationType yet, so this is a faithful no-op for now.
; In: EBP = GB base. All registers preserved.
; ---------------------------------------------------------------------------
PlayApplyingAttackAnimation:
    push eax
    mov al, [ebp + wAnimationType]
    and al, al
    jz .done                            ; wAnimationType 0 → no applying animation (pret ret z)
    ; TODO-HW: AnimationTypePointerTable dispatch (ShakeScreenVertically /
    ; ShakeScreenHorizontally* / BlinkEnemyMonSprite). These manipulate rWX (window
    ; scroll) and the OBJ palette to flash the pic — both need software-PPU hooks the
    ; battle renderer doesn't have yet. Faithful structure preserved; visible shake
    ; deferred. (pret animations.asm:506 AnimationTypePointerTable.)
.done:
    pop eax
    ret
