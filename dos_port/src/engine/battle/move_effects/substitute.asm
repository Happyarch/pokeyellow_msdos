; 1196__SubstituteEffect.asm — SubstituteEffect_ (move-effect translation swarm).
;
; Faithful translation of engine/battle/move_effects/substitute.asm:SubstituteEffect_
; (pret/pokeyellow). Put up a Substitute doll at a cost of maxHP/4 of the user's own
; HP: refuses if HAS_SUBSTITUTE_UP is already set on the user, refuses if the user's
; remaining HP would underflow, otherwise debits the HP, sets HAS_SUBSTITUTE_UP, plays
; the substitute pop-up "animation" (selected per wOptions/BIT_BATTLE_ANIMATION), prints
; the message, and redraws the HUDs/HP bars.
;
; Fidelity boundary: docs/move_translation_divergence.md. Shared externs (§4) are
; called, not redefined; only §2 allowlist items (literal subanim, banks) diverge.
;
; Register map: A=AL, B=BH, C=BL (BC=EBX, used as a 32-bit GB address when it holds a
; pointer), D=DH, E=DL (DE=EDX, ditto), HL=ESI (full 32-bit), EBP=GB base. GB memory at
; [EBP+addr]; battle_text streams are flat program addresses (ESI = stream).
;
; Build: nasm -f coff -I include/ -I . -o /dev/null 1196__SubstituteEffect.asm

bits 32

%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"

section .text

global SubstituteEffect_

; --- shared scaffold externs (§4: call, never define) ---
extern PrintText                    ; move_effect_helpers.asm — ESI = flat text stream
extern DelayFrames                  ; move_effect_helpers.asm — BL = frame count
extern DrawHUDsAndHPBars            ; battle_menu.asm — jpfar target in pret; flat tail-call here
; --- allowlist anim stub (§2 item 1: literal subanim, ANIMATION=OFF path) ---
extern PlayCurrentMoveAnimation
; AnimationSubstitute (engine/battle/animations.asm:2020) is the literal hard-coded
; substitute pop-up subanim pret reaches when wOptions/BIT_BATTLE_ANIMATION is SET
; (animations off — see comment at .selectAnim below). It is NOT yet defined anywhere
; in the dos_port scaffold (move_effect_helpers.asm only stubs PlayCurrentMoveAnimation/
; PlayBattleAnimation, not this one). Externed here per allowlist §2 item 1 (literal
; subanimation engine, not ported) so this file assembles standalone; resolving the
; undefined symbol at link time is the master's job — add a `ret`-stub global
; AnimationSubstitute alongside the others in move_effect_helpers.asm.
; FLAG FOR MASTER: AnimationSubstitute has no stub yet — add one (ret) to
; move_effect_helpers.asm's allowlist-stub block before this handler can link.
extern AnimationSubstitute
; --- battle_text.inc streams (global in core.o) ---
extern SubstituteText
extern HasSubstituteText
extern TooWeakSubstituteText

; ===========================================================================
; SubstituteEffect_ — pret engine/battle/move_effects/substitute.asm.
; Puts up a Substitute for the side whose turn it is (hWhoseTurn: 0=player,
; 1=enemy), costing maxHP/4 of the user's own current HP.
; ===========================================================================
SubstituteEffect_:
    mov bl, 50                          ; ld c, 50
    call DelayFrames

    mov esi, wBattleMonMaxHP            ; ld hl, wBattleMonMaxHP
    mov edx, wPlayerSubstituteHP        ; ld de, wPlayerSubstituteHP
    mov ebx, wPlayerBattleStatus2       ; ld bc, wPlayerBattleStatus2
    mov al, [ebp + hWhoseTurn]          ; ldh a, [hWhoseTurn]
    and al, al
    jz .notEnemy
    mov esi, wEnemyMonMaxHP
    mov edx, wEnemySubstituteHP
    mov ebx, wEnemyBattleStatus2
.notEnemy:
    mov al, [ebp + ebx]                 ; ld a, [bc]
    test al, 1 << HAS_SUBSTITUTE_UP     ; bit HAS_SUBSTITUTE_UP, a
    jnz .alreadyHasSubstitute

; quarter health to remove from user
; assumes max HP is 1023 or lower (pret comment — the discarded quarter-HP high byte
; below relies on this; see note at the shr)
    push ebx                            ; push bc — save the status2 pointer; bh/bl get
                                         ; reused below as GB 'b'/'c' scratch, matching
                                         ; pret's reuse of B as the maxHP/4 low byte.
    mov al, [ebp + esi]                 ; ld a, [hli] — maxHP high byte
    inc esi
    mov bh, [ebp + esi]                 ; ld b, [hl] — maxHP low byte
    ; srl a / rr b / srl a / rr b — 16-bit (a:b) >>= 2. Assembled into AX (AH=high,
    ; AL=low) for a single shr; bit-identical to the two SM83 srl/rr passes. The
    ; resulting high byte (AH) is never used again below — pret overwrites GB 'a'
    ; before it's read, per the "max HP <=1023" assumption (quarter-HP high byte
    ; is always 0 for any realistic HP).
    mov ah, al
    mov al, bh
    shr ax, 2                           ; ax = maxHP / 4
    mov bh, al                          ; b = quarter-HP low byte

    push edx                            ; push de
    add esi, (wBattleMonHP - wBattleMonMaxHP) ; add hl, de — hl -> current-HP low byte
                                         ; (same delta for the player and enemy mon
                                         ; structs — pret relies on matching layout)
    pop edx                             ; pop de
    mov al, bh                          ; ld a, b
    mov [ebp + edx], al                 ; ld [de], a — stash quarter-HP into
                                         ; wPlayerSubstituteHP/wEnemySubstituteHP
    mov al, [ebp + esi]                 ; ld a, [hld] — current HP low byte
    dec esi
; subtract [max hp / 4] to current HP
    sub al, bh                          ; sub b
    mov dh, al                          ; ld d, a — stash low-byte subtraction result
    mov al, [ebp + esi]                 ; ld a, [hl] — current HP high byte
    sbb al, 0                           ; sbc 0 — propagate the borrow only (quarter-HP
                                         ; high byte assumed 0, per the comment above)
    pop ebx                             ; pop bc — restore the status2 pointer

; BUG{class=data-model; pret=engine/battle/move_effects/substitute.asm:SubstituteEffect_; behavior=current HP exactly equal to one quarter max HP permits Substitute and leaves the user at zero HP; evidence=pret subtraction carry-only branch and source comment; lifetime=permanent Gen-1 behavior at compatibility level below 2}
; Pret only branches on the borrow (carry) from the maxHP/4
; subtraction. A user whose current HP exactly equals maxHP/4 subtracts to exactly
; 0 with NO carry, so it falls through to the "user has 0 or more HP" path below:
; HAS_SUBSTITUTE_UP gets set and the substitute goes up while the user is left at
; 0 HP without a proper faint check firing here — Substitute can self-KO the user.
; pret ref: engine/battle/move_effects/substitute.asm (comment at the
; `jr c, .notEnoughHP` site, "bug: ... will possibly leave user with 0 HP").
%if BUG_FIX_LEVEL >= 2
    jc .notEnoughHP
    ; fix: also reject when the subtraction left exactly 0 HP, matching the
    ; in-game intent of "not enough HP to put up a Substitute".
    or al, al
    jnz .haveHP
    or dh, dh
    jnz .haveHP
    jmp .notEnoughHP
.haveHP:
%else
    jc .notEnoughHP                     ; original (buggy) carry-only branch
%endif

; user has 0 or more HP
    mov [ebp + esi], al                 ; ld [hli], a — store HP high byte
    inc esi
    mov [ebp + esi], dh                 ; ld [hl], d — store HP low byte
    mov esi, ebx                        ; ld h, b / ld l, c — hl = bc (status2 ptr)
    or byte [ebp + esi], 1 << HAS_SUBSTITUTE_UP ; set HAS_SUBSTITUTE_UP, [hl]

    mov al, [ebp + wOptions]            ; ld a, [wOptions]
    test al, 1 << BIT_BATTLE_ANIMATION  ; bit BIT_BATTLE_ANIMATION, a
    jnz .useAnimationSubstitute         ; jr nz — bit set: animations off, use the
                                         ; literal hard-coded substitute pop-up
    call PlayCurrentMoveAnimation       ; bit clear: animations on, generic move-anim path
    jmp .animDone
.useAnimationSubstitute:
    call AnimationSubstitute            ; allowlist §2 item 1 — see extern note above
.animDone:
                                         ; (Bankswitch dropped per allowlist §2 item 4 —
                                         ; flat DPMI model has no banks)
    mov esi, SubstituteText             ; ld hl, SubstituteText
    call PrintText
    jmp DrawHUDsAndHPBars               ; jpfar DrawHUDsAndHPBars — tail call

.alreadyHasSubstitute:
    mov esi, HasSubstituteText          ; ld hl, HasSubstituteText
    jmp .printTextTail                  ; jr .printText
.notEnoughHP:
    mov esi, TooWeakSubstituteText      ; ld hl, TooWeakSubstituteText
.printTextTail:
    jmp PrintText                       ; jp PrintText
