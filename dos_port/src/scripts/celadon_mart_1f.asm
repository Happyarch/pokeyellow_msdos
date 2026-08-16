; CeladonMart1F.asm — translated from pret scripts/CeladonMart1F.asm by dos_port/tools/sm83xlat.
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


global CeladonMart1FCurrentFloorSignText
global CeladonMart1FDirectorySignText
global CeladonMart1FReceptionistText
global CeladonMart1F_Script
global CeladonMart1F_TextPointers

extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern _CeladonMart1FCurrentFloorSignText   ; NOT YET DEFINED IN THE PORT
extern _CeladonMart1FDirectorySignText   ; NOT YET DEFINED IN THE PORT
extern _CeladonMart1FReceptionistText   ; NOT YET DEFINED IN THE PORT

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

CeladonMart1F_Script:
    call EnableAutoTextBoxDrawing
    ret

CeladonMart1F_TextPointers:
    dd CeladonMart1FReceptionistText
    dd CeladonMart1FDirectorySignText
    dd CeladonMart1FCurrentFloorSignText
CeladonMart1FReceptionistText:
    text_far _CeladonMart1FReceptionistText
    text_end
CeladonMart1FDirectorySignText:
    text_far _CeladonMart1FDirectorySignText
    text_end
CeladonMart1FCurrentFloorSignText:
    text_far _CeladonMart1FCurrentFloorSignText
    text_end
