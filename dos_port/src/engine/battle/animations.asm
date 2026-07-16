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
global AdjustOAMBlockXPos
global AdjustOAMBlockXPos2
global AdjustOAMBlockYPos
global AdjustOAMBlockYPos2

extern DelayFrames               ; src/video/frame.asm — BL = frame count

%ifndef wCoordAdjustmentAmount
wCoordAdjustmentAmount   equ 0xD089 ; golden 00:d089
%endif
%ifndef OBJ_SIZE
OBJ_SIZE                 equ 4     ; constants/hardware.inc — bytes per OAM entry
%endif
%ifndef SCREEN_HEIGHT_PX
SCREEN_HEIGHT_PX         equ 144   ; constants/hardware.inc
%endif

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

; ---------------------------------------------------------------------------
; AdjustOAMBlock{X,Y}Pos / ...2 — pret engine/battle/animations.asm:1381-1426.
;
; Step a run of OAM entries along one axis by wCoordAdjustmentAmount, putting an
; entry off-screen once it leaves the visible area. Shared by the CUT animation
; (cut2.asm:AnimCut) and the Strength boulder-dust animation
; (dust_smoke.asm:AnimateBoulderDust) — which is why these live here, in their pret
; home file, rather than in either consumer.
;
; pret gives each axis two entry points, and both are kept:
;   AdjustOAMBlockXPos  — In: EDX (de) = OAM entry ptr; copies it to ESI (ld l,e/ld h,d)
;   AdjustOAMBlockXPos2 — In: ESI (hl) = OAM entry ptr (callers that already hold it)
; In both: BL (pret c) = entry count; wCoordAdjustmentAmount = signed delta.
; ESI/EDX are GB offsets into wShadowOAM — read/write as [ebp + esi].
;
; REGISTER CONTRACT (BL, not CL): pret's count is `c`, which the project register
; map (BC→BX) puts in BL. cut2.asm already documents and passes BL. dust_smoke.asm
; passed CL — a latent bug in a file that had never linked; fixed there, not
; accommodated here, so there is ONE contract.
;
; PORT DEVIATION (strictly less clobber): pret's `ld de, OBJ_SIZE` at the ...2 entry
; destroys DE to use it as the stride addend for `add hl, de`. The port adds the
; OBJ_SIZE literal to ESI directly and leaves EDX intact. No caller depends on DE
; being clobbered.
; Clobbers: AL, BH, ESI. Out: BL = 0.
; ---------------------------------------------------------------------------
AdjustOAMBlockXPos:
    mov esi, edx                     ; ld l, e / ld h, d
AdjustOAMBlockXPos2:
.loop:
    mov bh, [ebp + wCoordAdjustmentAmount]   ; ld a, [wCoordAdjustmentAmount] / ld b, a
    mov al, [ebp + esi]                      ; ld a, [hl] — this entry's X
    add al, bh                               ; add b
    cmp al, 168
    jb .skipPuttingEntryOffScreen            ; jr c — still on screen
; put off-screen if X >= 168. hl points at the X byte, so `dec hl` reaches THIS
; entry's Y byte: writing 160 there hides the entry. (Contrast the Y routine below,
; where the same idiom is a bug.)
    dec esi
    mov al, SCREEN_HEIGHT_PX + OAM_Y_OFS     ; 160 — below the visible area
    mov [ebp + esi], al                      ; ld [hli], a
    inc esi
.skipPuttingEntryOffScreen:
    mov [ebp + esi], al                      ; ld [hl], a
    add esi, OBJ_SIZE                        ; add hl, de (de = OBJ_SIZE in pret)
    dec bl                                   ; dec c — sets the ZF the branch reads
    jnz .loop
    ret

AdjustOAMBlockYPos:
    mov esi, edx                     ; ld l, e / ld h, d
AdjustOAMBlockYPos2:
.loop:
    mov bh, [ebp + wCoordAdjustmentAmount]
    mov al, [ebp + esi]                      ; ld a, [hl] — this entry's Y
    add al, bh
    cmp al, 112
    jb .skipSettingPreviousEntrysAttribute   ; jr c — still on screen
; BUG{class=data-model; pret=engine/battle/animations.asm:AdjustOAMBlockYPos; behavior=the off-screen path writes 160 to the PREVIOUS OAM entry's attribute byte as well as hiding this entry, flipping that sprite's palette/priority/flip bits; evidence=pret animations.asm:1419 carries the comment "bug, sets previous OAM entry's attribute" — hl already points at Y (offset 0) here, unlike the X routine where it points at X (offset 1), so dec hl lands one byte BEFORE this entry; lifetime=permanent Gen-1 behavior, fixed only at BUG_FIX_LEVEL >= 2}
;
; The intended effect still happens: AL is 160 when `ld [hl],a` writes this entry's
; Y below, hiding it. The stray write to the previous attribute is pure collateral.
%if BUG_FIX_LEVEL >= 2
    mov al, SCREEN_HEIGHT_PX + OAM_Y_OFS     ; fix: hide this entry (the write lands
                                             ; at .skip below) without the stray
                                             ; write to the previous entry
%else
    dec esi                                  ; THE BUG: → previous entry's attribute
    mov al, SCREEN_HEIGHT_PX + OAM_Y_OFS     ; ld a, 160
    mov [ebp + esi], al                      ; ld [hli], a — clobbers prev attribute
    inc esi
%endif
.skipSettingPreviousEntrysAttribute:
    mov [ebp + esi], al                      ; ld [hl], a
    add esi, OBJ_SIZE                        ; add hl, de
    dec bl                                   ; dec c
    jnz .loop
    ret
