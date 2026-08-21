; magazines.asm — Magazines hidden-event handler.
;
; Faithful translation of pret `engine/events/hidden_events/magazines.asm`.
;
; Routines:
;   PrintMagazinesText: Enables auto text-box drawing and calls predef text
;     MagazinesText.
;
; Text streams:
;   MagazinesText: Tier-1 predef text data generated into assets/predef_text.inc.
;
; Register map:
;   A = AL; GB memory at [EBP + addr].
;
; Build: nasm -f coff -I include/ -I . -D BUG_FIX_LEVEL=0 -o magazines.o \
;            src/engine/events/hidden_events/magazines.asm

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "predef.inc"
%include "assets/predef_text_ids.inc"

section .text

extern EnableAutoTextBoxDrawing         ; src/home/window.asm
extern PrintPredefTextID                ; src/home/predef_text.asm

; ─────────────────────────────────────────────────────────────────────────────
; PrintMagazinesText — pret engine/events/hidden_events/magazines.asm:PrintMagazinesText.
; ─────────────────────────────────────────────────────────────────────────────
global PrintMagazinesText
PrintMagazinesText:
    call EnableAutoTextBoxDrawing
    tx_pre MagazinesText
    ret
