; CinnabarLabTradeRoom.asm — translated from pret scripts/CinnabarLabTradeRoom.asm by dos_port/tools/sm83xlat.
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


global CinnabarLabTradeRoomBeautyText
global CinnabarLabTradeRoomDoTrade
global CinnabarLabTradeRoomGrampsText
global CinnabarLabTradeRoomSuperNerdText
global CinnabarLabTradeRoom_Script
global CinnabarLabTradeRoom_TextPointers

extern DoInGameTradeDialogue   ; NOT YET DEFINED IN THE PORT
extern EnableAutoTextBoxDrawing   ; NOT YET DEFINED IN THE PORT
extern TextScriptEnd   ; NOT YET DEFINED IN THE PORT
extern _CinnabarLabTradeRoomSuperNerdText   ; NOT YET DEFINED IN THE PORT

; Code and data are emitted in pret's SOURCE ORDER, in one section.
; That is not cosmetic: a NASM local label binds to the last
; non-local label above it, so hoisting the text streams into a
; separate section rebound every `.Text` to the wrong parent.
section .text

CinnabarLabTradeRoom_Script:
    jmp EnableAutoTextBoxDrawing

CinnabarLabTradeRoom_TextPointers:
    dd CinnabarLabTradeRoomSuperNerdText
    dd CinnabarLabTradeRoomGrampsText
    dd CinnabarLabTradeRoomBeautyText
CinnabarLabTradeRoomSuperNerdText:
    text_far _CinnabarLabTradeRoomSuperNerdText
    text_end

CinnabarLabTradeRoomGrampsText:
    mov al, 7
    mov [ebp + wWhichTrade], al
    jmp CinnabarLabTradeRoomDoTrade

CinnabarLabTradeRoomBeautyText:
    mov al, 8
    mov [ebp + wWhichTrade], al
CinnabarLabTradeRoomDoTrade:
; DEVIATION{class=banking; pret=macros/predef.asm:predef; behavior=Predef dispatch replaced by a direct call, and the predef id is not left in A because no reader is live; evidence=PredefPointers is unported and the flat model needs no bank switch, dataflow shows A dead after this site; lifetime=retired when PredefPointers is ported}
    call DoInGameTradeDialogue
    jmp TextScriptEnd
