; indigo_plateau_hq.asm — Indigo Plateau HQ hidden-event handler.
;
; Faithful translation of pret `engine/events/hidden_events/indigo_plateau_hq.asm`.
; Only PrintIndigoPlateauHQText is ported here:
;   * IndigoPlateauHQText is a plain `text_far` wrapper, so it is Tier-1 DATA and is
;     generated into assets/predef_text.inc (via tools/generators/gen_predef_text.py),
;     dispatched through TextPredefs (src/data/text_predef_pointers.asm, id $29).
;
; Register map: A=AL; GB memory at [EBP + addr].
;
; Build: nasm -f coff -I include/ -I . -o indigo_plateau_hq.o \
;            src/engine/events/hidden_events/indigo_plateau_hq.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "predef.inc"                   ; tx_pre_id
%include "assets/predef_text_ids.inc"    ; IndigoPlateauHQText_id

global PrintIndigoPlateauHQText

extern EnableAutoTextBoxDrawing         ; src/home/window.asm
extern PrintPredefTextID                ; src/home/predef_text.asm

section .text

; ─────────────────────────────────────────────────────────────────────────────
; PrintIndigoPlateauHQText — pret engine/events/hidden_events/indigo_plateau_hq.asm:PrintIndigoPlateauHQText
; ─────────────────────────────────────────────────────────────────────────────
PrintIndigoPlateauHQText:
    mov al, [ebp + wSpritePlayerStateData1FacingDirection]
    cmp al, SPRITE_FACING_UP
    jne .notFacingUp
    call EnableAutoTextBoxDrawing
    tx_pre_id IndigoPlateauHQText
    jmp PrintPredefTextID
.notFacingUp:
    ret
