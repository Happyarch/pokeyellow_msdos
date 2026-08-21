; oaks_lab_email.asm — Oak's Lab email hidden-event handler.
;
; Faithful translation of pret `engine/events/hidden_events/oaks_lab_email.asm`.
; OakLabEmailText is a plain text_far wrapper generated as Tier-1 data in assets/predef_text.inc.
;
; Register map: A=AL; GB memory at [EBP + addr].
;
; Build: nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 -o /dev/null \
;            src/engine/events/hidden_events/oaks_lab_email.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "predef.inc"
%include "assets/predef_text_ids.inc"

global DisplayOakLabEmailText

extern EnableAutoTextBoxDrawing         ; src/home/window.asm
extern PrintPredefTextID                ; src/home/predef_text.asm

section .text

; ─────────────────────────────────────────────────────────────────────────────
; DisplayOakLabEmailText — pret engine/events/hidden_events/oaks_lab_email.asm:DisplayOakLabEmailText
; ─────────────────────────────────────────────────────────────────────────────
DisplayOakLabEmailText:
    mov al, [ebp + wSpritePlayerStateData1FacingDirection]
    cmp al, SPRITE_FACING_UP
    jne .ret
    call EnableAutoTextBoxDrawing
    tx_pre OakLabEmailText
.ret:
    ret
