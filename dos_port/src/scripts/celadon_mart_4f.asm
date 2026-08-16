; CeladonMart4F.asm — translated from pret scripts/CeladonMart4F.asm by dos_port/tools/sm83xlat.
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


global CeladonMart4FCurrentFloorSignText
global CeladonMart4FSuperNerdText
global CeladonMart4FYoungsterText
global CeladonMart4F_Script
global CeladonMart4F_TextPointers

extern CeladonMart4FClerkText   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern _CeladonMart4FCurrentFloorSignText   ; NOT YET DEFINED IN THE PORT
extern _CeladonMart4FSuperNerdText   ; NOT YET DEFINED IN THE PORT
extern _CeladonMart4FYoungsterText   ; NOT YET DEFINED IN THE PORT

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

CeladonMart4F_Script:
    jmp EnableAutoTextBoxDrawing

CeladonMart4F_TextPointers:
    dd CeladonMart4FClerkText
    dd CeladonMart4FSuperNerdText
    dd CeladonMart4FYoungsterText
    dd CeladonMart4FCurrentFloorSignText
CeladonMart4FSuperNerdText:
    text_far _CeladonMart4FSuperNerdText
    text_end
CeladonMart4FYoungsterText:
    text_far _CeladonMart4FYoungsterText
    text_end
CeladonMart4FCurrentFloorSignText:
    text_far _CeladonMart4FCurrentFloorSignText
    text_end
