; display_effectiveness.asm — DisplayEffectiveness (battle-engine porting swarm worker).
;
; Faithful translation of engine/battle/display_effectiveness.asm:DisplayEffectiveness
; (pret/pokeyellow). Prints "It's super effective!" / "It's not very effective..." /
; nothing, based on the type-effectiveness multiplier left in wDamageMultipliers by
; the damage pipeline.
;
; Register map: A=AL, F.C=CF, HL=ESI (flat text stream ptr), EBP=GB base.
; GB memory at [EBP+addr].
;
; Build: nasm -f coff -I include/ -I . -o display_effectiveness.o display_effectiveness.asm

bits 32

%include "gb_macros.inc"
%include "gb_memmap.inc"
%include "gb_constants.inc"

section .data

; --- hand-authored text streams (Tier-2 code; not in generated battle_text.inc) ---
; TX_START=0x00, <LINE>=0x4F, <PROMPT>=0x58 — bytes as supplied by the swarm
; coordinator, encoded from pret's charmap for these two literal strings.
SuperEffectiveText:
    db 0x00, 0x88,0xB3,0xE0,0xB2,0x7F,0xB2,0xB4,0xAF,0xA4,0xB1, 0x4F, 0xA4,0xA5,0xA5,0xA4,0xA2,0xB3,0xA8,0xB5,0xA4,0xE7, 0x58   ; "It's super"<LINE>"effective!"<PROMPT>
NotVeryEffectiveText:
    db 0x00, 0x88,0xB3,0xE0,0xB2,0x7F,0xAD,0xAE,0xB3,0x7F,0xB5,0xA4,0xB1,0xB8, 0x4F, 0xA4,0xA5,0xA5,0xA4,0xA2,0xB3,0xA8,0xB5,0xA4,0xE8,0xE8,0xE8, 0x58   ; "It's not very"<LINE>"effective..."<PROMPT>

section .text

global DisplayEffectiveness

; --- shared scaffold extern (call, never define) ---
extern PrintText                    ; move_effect_helpers.asm — ESI = flat text stream

; ===========================================================================
; DisplayEffectiveness — pret engine/battle/display_effectiveness.asm.
; Reads wDamageMultipliers, masks off the STAB bit (EFFECTIVENESS_MASK), and
; compares against EFFECTIVE (10, i.e. 1x):
;   == EFFECTIVE  -> print nothing (ret)
;   >  EFFECTIVE  -> "It's super effective!"      (CF clear after cp, not equal)
;   <  EFFECTIVE  -> "It's not very effective..." (CF set after cp)
; Clobbers AL, ESI; tail-jumps into PrintText.
; ===========================================================================
DisplayEffectiveness:
    mov al, [ebp + wDamageMultipliers]  ; ld a, [wDamageMultipliers]
    and al, EFFECTIVENESS_MASK          ; and $7F
    cmp al, EFFECTIVE                   ; cp EFFECTIVE (10)
    jz .ret                             ; ret z — exactly effective, print nothing
    mov esi, SuperEffectiveText         ; ld hl, SuperEffectiveText
    jnc .done                           ; jr nc, .done — multiplier > EFFECTIVE
    mov esi, NotVeryEffectiveText       ; ld hl, NotVeryEffectiveText
.done:
    jmp PrintText                       ; jp PrintText
.ret:
    ret
