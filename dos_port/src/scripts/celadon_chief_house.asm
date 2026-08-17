; CeladonChiefHouse.asm — translated from pret scripts/CeladonChiefHouse.asm by dos_port/tools/sm83xlat.
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


global CeladonChiefHouseChiefText
global CeladonChiefHouseRocketText
global CeladonChiefHouseSailorText
global CeladonChiefHouse_Script
global CeladonChiefHouse_TextPointers

extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern _CeladonChiefHouseChiefText   ; NOT YET DEFINED IN THE PORT
extern _CeladonChiefHouseRocketText   ; NOT YET DEFINED IN THE PORT
extern _CeladonChiefHouseSailorText   ; NOT YET DEFINED IN THE PORT

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

%assign event_byte -1
%assign event_byte_a -1
CeladonChiefHouse_Script:
    call EnableAutoTextBoxDrawing
    ret

%assign event_byte -1
%assign event_byte_a -1
CeladonChiefHouse_TextPointers:
    dd CeladonChiefHouseChiefText
    dd CeladonChiefHouseRocketText
    dd CeladonChiefHouseSailorText
CeladonChiefHouseChiefText:
    text_far _CeladonChiefHouseChiefText
    text_end
CeladonChiefHouseRocketText:
    text_far _CeladonChiefHouseRocketText
    text_end
CeladonChiefHouseSailorText:
    text_far _CeladonChiefHouseSailorText
    text_end
