; FuchsiaMart.asm — translated from pret scripts/FuchsiaMart.asm by dos_port/tools/sm83xlat.
;
; ONE-SHOT OUTPUT, NOW HAND-MAINTAINED. The transpiler ran once at the SHA
; recorded in dos_port/tools/sm83xlat/README.md and is not re-run; this file is
; ordinary Tier-2 source and editing it is the normal way it changes. There is
; deliberately no DO NOT EDIT header.
;
; Every pret label is preserved verbatim so the file stays line-for-line
; cross-referenceable against the disassembly.
;
; Regions the tool could not lower WITH CERTAINTY are reproduced below as
; commented pret source under a `; BAIL[reason]` banner, and define NO symbol —
; so a reference to one is a link error rather than a plausible wrong lowering.

bits 32

%include "gb_memmap.inc"
%include "gb_constants.inc"
%include "gb_text.inc"
%include "events.inc"
%include "assets/event_constants.inc"


global FuchsiaMartCooltrainerFText
global FuchsiaMartMiddleAgedManText
global FuchsiaMart_Script
global FuchsiaMart_TextPointers

extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern FuchsiaMartClerkText   ; NOT YET DEFINED IN THE PORT
extern _FuchsiaMartCooltrainerFText   ; NOT YET DEFINED IN THE PORT
extern _FuchsiaMartMiddleAgedManText   ; NOT YET DEFINED IN THE PORT

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

FuchsiaMart_Script:
    call EnableAutoTextBoxDrawing
    ret

FuchsiaMart_TextPointers:
    dd FuchsiaMartClerkText
    dd FuchsiaMartMiddleAgedManText
    dd FuchsiaMartCooltrainerFText
FuchsiaMartMiddleAgedManText:
    text_far _FuchsiaMartMiddleAgedManText
    text_end
FuchsiaMartCooltrainerFText:
    text_far _FuchsiaMartCooltrainerFText
    text_end
