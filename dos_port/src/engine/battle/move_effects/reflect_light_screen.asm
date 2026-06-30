; 1192__ReflectLightScreenEffect.asm — ReflectLightScreenEffect (move-effect swarm).
;
; Faithful translation of engine/battle/move_effects/reflect_light_screen.asm:
; ReflectLightScreenEffect_ (pret/pokeyellow). Sets HAS_LIGHT_SCREEN_UP (Light
; Screen) or HAS_REFLECT_UP (Reflect) on the move's USER (the side select is by
; hWhoseTurn, same side as the mover — unlike most effects this targets the
; user, not the opponent), failing with "But it failed!" if that screen is
; already up.
;
; RE-TRANSLATION: the prior draft at
; dos_port/src/engine/battle/move_effects/reflect_light_screen.asm was missing
; the entire ReflectLightScreenEffect_ body and wrongly REDEFINED the shared
; global EffectCallBattleCore (which already lives in move_effect_helpers.asm,
; tail-jumping ESI in the flat DPMI model — divergence §2 item 4: no banks).
; This draft externs EffectCallBattleCore instead of redefining it, and
; supplies the full effect body.
;
; Fidelity boundary: docs/move_translation_divergence.md. Shared externs (§4)
; are called, not redefined; only §2 allowlist items (subanim, banks) diverge.
;
; Register map: A=AL, B=BH, C=BL (BC=BX), D=DH, E=DL (DE=EDX), HL=ESI, EBP=GB base.
; GB memory at [EBP+addr]; battle_text streams are flat program addresses.
;
; Build: nasm -f coff -I include/ -I . -o /dev/null 1192__ReflectLightScreenEffect.asm

bits 32

%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"

section .text

global ReflectLightScreenEffect_

; --- shared scaffold externs (§4: call, never define) ---
extern PlayCurrentMoveAnimation      ; move_effect_helpers.asm — allowlist subanim stub (§2.1)
extern PrintText                     ; move_effect_helpers.asm — ESI = flat text stream
extern PrintButItFailedText_         ; move_effect_helpers.asm — "But it failed!"
extern DelayFrames                   ; move_effect_helpers.asm — BL = frame count
extern EffectCallBattleCore          ; move_effect_helpers.asm — tail into ESI (no banks, §2.4)

; --- battle_text.inc streams (global in core.o; flat addresses) ---
extern LightScreenProtectedText
extern ReflectGainedArmorText

; ===========================================================================
; ReflectLightScreenEffect_ — pret move_effects/reflect_light_screen.asm.
; Sets HAS_LIGHT_SCREEN_UP or HAS_REFLECT_UP (selected by the move's effect
; byte, LIGHT_SCREEN_EFFECT vs. anything else i.e. REFLECT_EFFECT) on the
; CURRENT MOVER's wXxxBattleStatus3 (hWhoseTurn selects player vs. enemy —
; both hl and de track the SAME side here, unlike the usual user/target
; split, since this move always affects its own user). Fails ("But it
; failed!", 50-frame delay) if that screen is already up.
; ===========================================================================
ReflectLightScreenEffect_:
    mov esi, wPlayerBattleStatus3       ; ld hl, wPlayerBattleStatus3
    mov edx, wPlayerMoveEffect          ; ld de, wPlayerMoveEffect
    mov al, [ebp + hWhoseTurn]          ; ldh a, [hWhoseTurn]
    and al, al
    jz .reflectLightScreenEffect        ; jr z, .reflectLightScreenEffect
    mov esi, wEnemyBattleStatus3        ; ld hl, wEnemyBattleStatus3
    mov edx, wEnemyMoveEffect           ; ld de, wEnemyMoveEffect
.reflectLightScreenEffect:
    mov al, [ebp + edx]                 ; ld a, [de]
    cmp al, LIGHT_SCREEN_EFFECT
    jne .reflect                        ; jr nz, .reflect
    test byte [ebp + esi], 1 << HAS_LIGHT_SCREEN_UP   ; bit HAS_LIGHT_SCREEN_UP, [hl]
    jnz .moveFailed                     ; jr nz, .moveFailed — already up
    or byte [ebp + esi], 1 << HAS_LIGHT_SCREEN_UP     ; set HAS_LIGHT_SCREEN_UP, [hl]
    mov esi, LightScreenProtectedText   ; ld hl, LightScreenProtectedText
    jmp .playAnim
.reflect:
    test byte [ebp + esi], 1 << HAS_REFLECT_UP        ; bit HAS_REFLECT_UP, [hl]
    jnz .moveFailed                     ; jr nz, .moveFailed — already up
    or byte [ebp + esi], 1 << HAS_REFLECT_UP          ; set HAS_REFLECT_UP, [hl]
    mov esi, ReflectGainedArmorText     ; ld hl, ReflectGainedArmorText
.playAnim:
    push esi                            ; push hl
    mov esi, PlayCurrentMoveAnimation   ; ld hl, PlayCurrentMoveAnimation
    call EffectCallBattleCore           ; call EffectCallBattleCore (flat: jmp esi; call so we return)
    pop esi                             ; pop hl
    jmp PrintText                       ; jp PrintText
.moveFailed:
    mov bl, 50                          ; ld c, 50
    call DelayFrames
    mov esi, PrintButItFailedText_      ; ld hl, PrintButItFailedText_
    jmp EffectCallBattleCore            ; jp EffectCallBattleCore (flat: tail-jmp esi)
