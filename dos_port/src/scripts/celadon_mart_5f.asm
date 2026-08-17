; CeladonMart5F.asm — translated from pret scripts/CeladonMart5F.asm by dos_port/tools/sm83xlat.
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


global CeladonMart5FCurrentFloorSignText
global CeladonMart5FGentlemanText
global CeladonMart5FSailorText
global CeladonMart5F_Script
global CeladonMart5F_TextPointers

extern CeladonMart5FClerk1Text   ; NOT YET DEFINED IN THE PORT
extern CeladonMart5FClerk2Text   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern _CeladonMart5FCurrentFloorSignText   ; NOT YET DEFINED IN THE PORT
extern _CeladonMart5FGentlemanText   ; NOT YET DEFINED IN THE PORT
extern _CeladonMart5FSailorText   ; NOT YET DEFINED IN THE PORT

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
CeladonMart5F_Script:
    call EnableAutoTextBoxDrawing
    ret

%assign event_byte -1
CeladonMart5F_TextPointers:
    dd CeladonMart5FGentlemanText
    dd CeladonMart5FSailorText
    dd CeladonMart5FClerk1Text
    dd CeladonMart5FClerk2Text
    dd CeladonMart5FCurrentFloorSignText
CeladonMart5FGentlemanText:
    text_far _CeladonMart5FGentlemanText
    text_end
CeladonMart5FSailorText:
    text_far _CeladonMart5FSailorText
    text_end
CeladonMart5FCurrentFloorSignText:
    text_far _CeladonMart5FCurrentFloorSignText
    text_end
