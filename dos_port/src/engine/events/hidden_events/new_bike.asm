; new_bike.asm — New bicycle hidden-event handler.
;
; Faithful translation of pret `engine/events/hidden_events/new_bike.asm`.
;
; Routines:
;   PrintNewBikeText: Enables auto text-box drawing and tail-jumps into predef
;     text NewBicycleText.
;
; Text streams:
;   NewBicycleText: Tier-1 predef text data generated into assets/predef_text.inc.
;
; Register map:
;   A = AL; GB memory at [EBP + addr].
;
; Build: nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 -o new_bike.o \
;            src/engine/events/hidden_events/new_bike.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "predef.inc"
%include "assets/predef_text_ids.inc"

section .text

extern EnableAutoTextBoxDrawing         ; src/home/window.asm
extern PrintPredefTextID                ; src/home/predef_text.asm

; ─────────────────────────────────────────────────────────────────────────────
; PrintNewBikeText — pret engine/events/hidden_events/new_bike.asm:PrintNewBikeText.
; ─────────────────────────────────────────────────────────────────────────────
global PrintNewBikeText
PrintNewBikeText:
    call EnableAutoTextBoxDrawing
    ; pret: `tx_pre_jump NewBicycleText`, which is tx_pre_id + jp. Spelled out
    ; because a jump-out macro AT A ROUTINE TAIL defeats the build-graph scanner —
    ; see the note in include/predef.inc.
    tx_pre_id NewBicycleText
    jmp PrintPredefTextID
