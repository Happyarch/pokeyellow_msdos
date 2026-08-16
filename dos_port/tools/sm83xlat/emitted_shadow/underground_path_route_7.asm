; UndergroundPathRoute7.asm — translated from pret scripts/UndergroundPathRoute7.asm by dos_port/tools/sm83xlat.
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

%include "assets/map_dims.inc"

global UndergroundPathRoute7MiddleAgedManText
global UndergroundPathRoute7_Script
global UndergroundPathRoute7_TextPointers

extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern _UndergroundPathRoute7MiddleAgedManText   ; NOT YET DEFINED IN THE PORT

; pret RAM names the port still spells in SCREAMING_SNAKE. Guarded, so
; this file assembles both before and after the memmap rename lands.
%ifndef wLastMap
wLastMap                                       equ W_LAST_MAP
%endif

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

UndergroundPathRoute7_Script:
    mov al, ROUTE_7
    mov [ebp + wLastMap], al
    jmp EnableAutoTextBoxDrawing

UndergroundPathRoute7_TextPointers:
    dd UndergroundPathRoute7MiddleAgedManText
UndergroundPathRoute7MiddleAgedManText:
    text_far _UndergroundPathRoute7MiddleAgedManText
    text_end
