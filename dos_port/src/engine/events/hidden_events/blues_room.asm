; blues_room.asm — Blue's room hidden-event handlers.
;
; Faithful translation of pret `engine/events/hidden_events/blues_room.asm`.
; Only PrintBookcaseText is ported here:
;   * BookcaseText and UnusedPredefText are Tier-1 DATA and are generated into
;     assets/predef_text.inc (via tools/generators/gen_predef_text.py), dispatched
;     through TextPredefs (src/data/text_predef_pointers.asm, ids $10 and $20).
;
; Register map: A=AL; GB memory at [EBP + addr].
;
; Build: nasm -f coff -I include/ -I . -o blues_room.o \
;            src/engine/events/hidden_events/blues_room.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "predef.inc"                   ; tx_pre_id
%include "assets/predef_text_ids.inc"    ; BookcaseText_id

global PrintBookcaseText

extern EnableAutoTextBoxDrawing         ; src/home/window.asm
extern PrintPredefTextID                ; src/home/predef_text.asm

section .text

; ─────────────────────────────────────────────────────────────────────────────
; PrintBookcaseText — pret engine/events/hidden_events/blues_room.asm:PrintBookcaseText
; ─────────────────────────────────────────────────────────────────────────────
PrintBookcaseText:
    call EnableAutoTextBoxDrawing
    tx_pre_id BookcaseText
    jmp PrintPredefTextID
